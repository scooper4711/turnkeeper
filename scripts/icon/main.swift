// Draws the icons and writes them: Resources/AppIcon.icns for the Mac, the full-bleed
// ios/App/Assets.xcassets/AppIcon.appiconset/icon-1024.png for the iPad and the iPhone, and
// Resources/DocumentIcon.icns for `.turnkeeper` files.
// Usage: make icon
import AppKit

func render(size: CGFloat, draw: (CGContext) -> Void) -> NSBitmapImageRep {
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size), bitsPerSample: 8, samplesPerPixel: 4,
        hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    ), let context = NSGraphicsContext(bitmapImageRep: bitmap)?.cgContext else {
        fatalError("Drawing the icon failed: no bitmap context")
    }
    context.scaleBy(x: size / canvas, y: size / canvas)
    draw(context)
    return bitmap
}

func write(_ bitmap: NSBitmapImageRep, to path: String) throws {
    guard let data = bitmap.representation(using: .png, properties: [:]) else {
        throw CocoaError(.fileWriteUnknown)
    }
    try data.write(to: URL(fileURLWithPath: path))
}

/// Writes `Resources/<name>.icns` with every size the Mac asks for, and says whether that worked.
func writeIcns(_ name: String, draw: (CGContext) -> Void) throws -> Bool {
    let iconset = "tmp/\(name).iconset"
    try? FileManager.default.removeItem(atPath: iconset)
    try FileManager.default.createDirectory(atPath: iconset, withIntermediateDirectories: true)
    for points in [16, 32, 128, 256, 512] {
        for scale in [1, 2] {
            let file = scale == 1 ? "icon_\(points)x\(points).png" : "icon_\(points)x\(points)@2x.png"
            try write(render(size: CGFloat(points * scale), draw: draw), to: "\(iconset)/\(file)")
        }
    }
    let iconutil = Process()
    iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
    iconutil.arguments = ["-c", "icns", iconset, "-o", "Resources/\(name).icns"]
    try iconutil.run()
    iconutil.waitUntilExit()
    try? FileManager.default.removeItem(atPath: iconset)
    return iconutil.terminationStatus == 0
}

try FileManager.default.createDirectory(atPath: "Resources", withIntermediateDirectories: true)

// iPad: full bleed; the system applies the rounded mask.
let fullBleed = CGRect(x: 0, y: 0, width: canvas, height: canvas)
try write(render(size: 1024) { drawIcon($0, padRect: fullBleed, corner: 0) },
          to: "ios/App/Assets.xcassets/AppIcon.appiconset/icon-1024.png")

// Mac: the rounded square sits inside the standard 1024 grid with margins for the shadow.
let macPad = CGRect(x: 100, y: 100, width: 824, height: 824)
let wroteApp = try writeIcns("AppIcon") { drawIcon($0, padRect: macPad, corner: 185) }
let wroteDocument = try writeIcns("DocumentIcon", draw: drawDocument)
print(wroteApp && wroteDocument ? "Wrote the Mac, iPad and document icons." : "iconutil failed.")
