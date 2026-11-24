import SwiftUI

/// How the voice initiative screen works. It opens before listening starts each time, until the GM chooses Don't
/// Show Again, and from the screen's help button at any time.
struct VoiceInitiativeHelp: View {
    /// Whether it opened by itself before listening, which offers Don't Show Again and Start Listening, or from the
    /// help button, which offers Done.
    let isIntroduction: Bool
    @Environment(\.dismiss) private var dismiss
    @AppStorage(Self.hiddenKey) private var isHidden = false

    /// The setting that stops it opening by itself. It belongs to the device, so it doesn't sync.
    static let hiddenKey = "hidesVoiceInitiativeHelp"

    private static let topics: [(title: String, text: String)] = [
        ("Say a number.", "It goes to the row outlined in yellow, then the next row without a number is outlined. "
            + "Turnkeeper waits until you finish, so “twenty-three” doesn't become 20."),
        ("Say a name.", "A character's or a player's name picks that row. “Sam seventeen” gives Sam 17."),
        ("Say “nat” and the roll.", "“Nat 14” or “natural 14” adds the better of Perception and Stealth for "
            + "creatures and players with a linked sheet. A natural 20 sparkles."),
        ("Got one wrong?", "Say the number again for that row, or tap the row first. Undo on the board works too."),
        ("Seating order.", "Drag players into the order they sit around the table, and Turnkeeper follows it. It's "
            + "saved with the party, and it doesn't change the initiative order."),
        ("Creatures.", "Show All adds them, sorted by Perception (hazards by Stealth). Select one to see what to add "
            + "to the die."),
        ("Privacy.", "Speech is recognized on your device when it can be, or by Apple otherwise. Turnkeeper keeps "
            + "only the numbers.")
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Just talk. Turnkeeper listens for names and numbers while this screen is open. As you go "
                         + "around the table, say each player's or character's name, then their initiative.")
                        .font(.title3)
                    ForEach(Self.topics, id: \.title) { topic in
                        (Text(topic.title).bold() + Text(" ") + Text(topic.text))
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle("Voice Initiative")
            .toolbar { buttons }
        }
        .sheetFrame(minWidth: 480, minHeight: 560)
        .interactiveDismissDisabled(isIntroduction)
        .accessibilityIdentifier("voiceHelp")
    }

    @ToolbarContentBuilder
    private var buttons: some ToolbarContent {
        if isIntroduction {
            // Not the cancellation slot: on the Mac, Escape presses that, and Escape mustn't hide this for good.
            ToolbarItem(placement: .navigation) {
                Button("Don't Show Again") {
                    isHidden = true
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) { Button("Start Listening") { dismiss() } }
        } else {
            ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
        }
    }
}
