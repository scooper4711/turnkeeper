#if os(iOS)
import UIKit

/// The system's share sheet for a file. It is given the file's URL itself, not a promise of one: only then does
/// it offer the apps that open the file's type, such as Pawn Shop for a sheet (seen in a simulator, 2026-11-27).
@MainActor
enum ShareSheet {
    /// Shows the share sheet over whatever the app's own window has in front. On an iPad it sits in the middle
    /// of the window, since the menu item that asked for it is gone by then.
    static func present(_ file: URL) {
        guard let presenter = frontViewController else { return }
        let sheet = UIActivityViewController(activityItems: [file], applicationActivities: nil)
        if let popover = sheet.popoverPresentationController {
            popover.sourceView = presenter.view
            popover.sourceRect = CGRect(x: presenter.view.bounds.midX, y: presenter.view.bounds.midY,
                                        width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        presenter.present(sheet, animated: true)
    }

    /// The view controller in front in the app's window, not in the player screen's on a second display.
    private static var frontViewController: UIViewController? {
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            .first { $0.session.role == .windowApplication && $0.activationState == .foregroundActive }
        var front = scene?.keyWindow?.rootViewController
        while let presented = front?.presentedViewController { front = presented }
        return front
    }
}
#endif
