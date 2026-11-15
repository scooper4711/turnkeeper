import CoreGraphics
import Foundation
import TurnkeeperKit

/// Stand-in creature art for the demo library (`--demo-art`), drawn here: a plain figure in a color of its own
/// for each creature, kept as pasted art. It lets the demo, the UI tests and screenshots show art, on strips,
/// card backs and a shared player screen, without anyone's pawn PDFs.
enum DemoArt {
    static var isWanted: Bool { ProcessInfo.processInfo.arguments.contains("--demo-art") }

    /// Gives each of the model's planned creatures a figure.
    @MainActor
    static func add(to model: AppModel) {
        guard let store = model.artStore else { return }
        let keys = Set(model.library.encounters.flatMap(\.variants).flatMap(\.slots).map(\.creatureKey))
        for (index, key) in keys.sorted().enumerated() {
            guard let image = figure(hue: Double(index) / Double(max(keys.count, 1))),
                  let file = ImageFile.png(image), let art = try? store.add(file, for: key) else { continue }
            model.library.save(art)
        }
    }

    /// A head, two ears and a body on a clear background, like a pawn cut from its sheet.
    static func figure(hue: Double) -> CGImage? {
        let size = CGSize(width: 480, height: 640)
        guard let context = CGContext(data: nil, width: Int(size.width), height: Int(size.height),
                                      bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        let color = rgb(hue: hue)
        context.setFillColor(CGColor(red: color[0], green: color[1], blue: color[2], alpha: 1))
        context.setStrokeColor(CGColor(red: 0.1, green: 0.1, blue: 0.12, alpha: 1))
        context.setLineWidth(10)
        let body = CGPath(roundedRect: CGRect(x: 120, y: 40, width: 240, height: 320), cornerWidth: 90,
                          cornerHeight: 90, transform: nil)
        let head = CGPath(ellipseIn: CGRect(x: 140, y: 340, width: 200, height: 200), transform: nil)
        let ears = CGMutablePath()
        ears.addLines(between: [CGPoint(x: 150, y: 470), CGPoint(x: 40, y: 560), CGPoint(x: 170, y: 520)])
        ears.addLines(between: [CGPoint(x: 330, y: 470), CGPoint(x: 440, y: 560), CGPoint(x: 310, y: 520)])
        for path in [ears, body, head] {
            context.addPath(path)
            context.drawPath(using: .fillStroke)
        }
        context.setFillColor(CGColor(red: 1, green: 0.95, blue: 0.6, alpha: 1))
        context.fillEllipse(in: CGRect(x: 185, y: 440, width: 36, height: 36))
        context.fillEllipse(in: CGRect(x: 259, y: 440, width: 36, height: 36))
        return context.makeImage()
    }

    /// A strong color around the wheel, as red, green and blue.
    private static func rgb(hue: Double) -> [CGFloat] {
        [0, 1.0 / 3, 2.0 / 3].map { offset in
            let position = (hue + offset).truncatingRemainder(dividingBy: 1) * 6
            return CGFloat(0.25 + 0.6 * min(max(abs(position - 3) - 1, 0), 1))
        }
    }
}
