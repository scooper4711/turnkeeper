import Bestiary
import Foundation
import SharedLibraries

/// Art pasted in for a creature, shown everywhere in place of the bundled art. The library only points to
/// the image; the file lives in the `ArtStore`, and packages carry its bytes alongside the library.
public struct CustomArt: LibraryRecord, Hashable {
    public var id = UUID()
    /// The creature the art is for: a bestiary key or a custom creature's `custom.<id>` key.
    public var subject: String
    /// The image file in the `ArtStore`, such as `<id>.jpg`.
    public var fileName: String
    public var byteCount: Int
    /// The name and size of the creature the art shows, for an app without the bestiary: Pawn Shop prints the art
    /// as a pawn under them (shared libraries R4.11, whose `ArtSubjectLabel` reads these two keys). Nil for a
    /// custom creature's or a character's art, whose names the library has, and until `labelArtSubjects` runs.
    public var subjectName: String?
    public var subjectSize: CreatureSize?
    public var modifiedAt = Date()
    public var deletedAt: Date?
    public var sharedVersion: Date?
    public var sharedVersions: [Date]?

    /// Art paths starting with this are pasted art in the `ArtStore`, not bundled art.
    public static let pathPrefix = "Pasted/"

    public init(subject: String, fileName: String, byteCount: Int) {
        self.subject = subject
        self.fileName = fileName
        self.byteCount = byteCount
    }

    /// The path the art views load, such as `Pasted/<id>.jpg`.
    public var path: String { Self.pathPrefix + fileName }

    /// The creature the art shows, when the art says.
    public var subjectLabel: ArtSubjectLabel? {
        subjectName.map { ArtSubjectLabel(name: $0, size: subjectSize) }
    }
}

public extension Library {
    /// Saves with each pasted picture the name and size of the creature it shows (R3.5c1), which `label` gives
    /// from the creature's key, or nil for a creature this app doesn't know. Art is stamped as changed only when
    /// its name or size differs. A custom creature's and a character's art are left alone.
    mutating func labelArtSubjects(_ label: (String) -> ArtSubjectLabel?) {
        for index in customArt.indices {
            let art = customArt[index]
            guard !art.isDeleted, !CustomCreature.isCustomKey(art.subject), !PlayerCharacter.isKey(art.subject),
                  let label = label(art.subject), art.subjectLabel != label else { continue }
            customArt[index].subjectName = label.subjectName
            customArt[index].subjectSize = label.subjectSize
            customArt[index].modifiedAt = ChangeClock.now()
        }
    }
}

public extension ArtReference {
    /// The same art references with pasted art taking the place of the portrait, token and thumbnail. The card
    /// back is cleared, so the player view frames the pasted art in a drawn card back.
    func replacing(with art: CustomArt) -> ArtReference {
        var replaced = self
        replaced.portrait = art.path
        replaced.token = art.path
        replaced.cardBack = ""
        return replaced
    }
}
