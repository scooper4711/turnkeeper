import SwiftUI

extension EnvironmentValues {
    /// True while the board shows the ladder alone (`BoardArrangement.ladderOnly`), as on an iPhone: the top bar
    /// keeps to icons, the turn buttons sit at the bottom, and battle cards open in a sheet.
    @Entry var isCompactBoard = false
}

extension View {
    /// A sheet's minimum size on the Mac and the iPad. An iPhone's sheet is as wide as its screen, where a
    /// minimum wider than that would push the content off both edges, so it gets none.
    func sheetFrame(minWidth: CGFloat? = nil, minHeight: CGFloat? = nil) -> some View {
        modifier(SheetFrame(minWidth: minWidth, minHeight: minHeight))
    }

    /// On an iPhone, makes a short sheet (a number pad, a reminder) as tall as its content, so the board stays
    /// in view above it. The Mac and the iPad size their sheets to the content already.
    /// On its side the iPhone's sheet fills the screen and scrolls instead.
    func fittedSheet() -> some View {
        modifier(FittedSheet())
    }
}

private struct SheetFrame: ViewModifier {
    let minWidth: CGFloat?
    let minHeight: CGFloat?
    @Environment(\.horizontalSizeClass) private var sizeClass

    func body(content: Content) -> some View {
        if sizeClass == .compact {
            content
        } else {
            content.frame(minWidth: minWidth, minHeight: minHeight)
        }
    }
}

private struct FittedSheet: ViewModifier {
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @State private var height: CGFloat = 0

    func body(content: Content) -> some View {
        if verticalSizeClass == .compact {
            // An iPhone on its side is shorter than a number pad: the sheet takes the screen and scrolls.
            ScrollView { content }
        } else if sizeClass == .compact {
            content
                .fixedSize(horizontal: false, vertical: true)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height = $0 }
                .presentationDetents(height > 0 ? [.height(height)] : [.medium])
                .presentationDragIndicator(.visible)
        } else {
            content
        }
    }
}
