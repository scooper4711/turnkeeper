// The icon of a `.turnkeeper` file: a page with the app icon on it.
import AppKit

/// A sheet of paper with its top right corner folded down, the app icon on it and the app's name below.
func drawDocument(_ context: CGContext) {
    let page = CGRect(x: 200, y: 96, width: 624, height: 832)
    let (fold, corner): (CGFloat, CGFloat) = (190, 44)
    let sheet = CGMutablePath()
    sheet.move(to: CGPoint(x: page.minX + corner, y: page.minY))
    sheet.addArc(tangent1End: CGPoint(x: page.maxX, y: page.minY), tangent2End: CGPoint(x: page.maxX, y: page.maxY),
                 radius: corner)
    sheet.addLine(to: CGPoint(x: page.maxX, y: page.maxY - fold))
    sheet.addLine(to: CGPoint(x: page.maxX - fold, y: page.maxY))
    sheet.addArc(tangent1End: CGPoint(x: page.minX, y: page.maxY), tangent2End: CGPoint(x: page.minX, y: page.minY),
                 radius: corner)
    sheet.addArc(tangent1End: CGPoint(x: page.minX, y: page.minY), tangent2End: CGPoint(x: page.maxX, y: page.minY),
                 radius: corner)
    sheet.closeSubpath()
    fillShadowed(context, sheet, hex: 0xE4E8EE, shadow: Shadow(offset: CGSize(width: 0, height: -14), blur: 34))
    fillGradient(context, in: sheet, from: 0xFFFFFF, to: 0xE1E6ED)

    let flap = CGMutablePath()
    flap.move(to: CGPoint(x: page.maxX - fold, y: page.maxY))
    flap.addArc(tangent1End: CGPoint(x: page.maxX - fold, y: page.maxY - fold),
                tangent2End: CGPoint(x: page.maxX, y: page.maxY - fold), radius: 30)
    flap.addLine(to: CGPoint(x: page.maxX, y: page.maxY - fold))
    flap.closeSubpath()
    fillShadowed(context, flap, hex: 0xD3D9E2, shadow: Shadow(offset: CGSize(width: -8, height: -10), blur: 18))
    fillGradient(context, in: flap, from: 0xF7F9FC, to: 0xC6CDD8)

    let emblem = CGRect(x: 297, y: 268, width: 430, height: 430)
    fillShadowed(context, CGPath(roundedRect: emblem, cornerWidth: 97, cornerHeight: 97, transform: nil),
                 hex: 0x0E131B, shadow: Shadow(offset: CGSize(width: 0, height: -10), blur: 22))
    drawIcon(context, padRect: emblem, corner: 97)
    drawText(context, "TURNKEEPER", center: CGPoint(x: page.midX, y: 182), style: Lettering(size: 56, hex: 0x8B94A3))
}

/// Where a soft shadow falls and how far it spreads.
struct Shadow {
    var offset: CGSize
    var blur: CGFloat
}

/// Fills a shape in one color with a soft shadow under it, for a gradient to go over.
func fillShadowed(_ context: CGContext, _ path: CGPath, hex: UInt32, shadow: Shadow) {
    context.saveGState()
    context.setShadow(offset: shadow.offset, blur: shadow.blur, color: color(0x000000, alpha: 0.32))
    context.addPath(path)
    context.setFillColor(color(hex))
    context.fillPath()
    context.restoreGState()
}
