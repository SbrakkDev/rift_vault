import AppKit
import Foundation

struct IconSpec {
    let name: String
    let color: NSColor
    let draw: (CGContext, CGRect) -> Void
}

let outputRoot = URL(fileURLWithPath: "/Users/davidebusa/Documents/local/rift_vault/RuneShelf/Assets.xcassets")
let canvasSize = CGSize(width: 1024, height: 1024)

func makeBitmap(size: CGSize) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(size.width),
        pixelsHigh: Int(size.height),
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!
    rep.size = size
    return rep
}

func writePNG(named name: String, draw: (CGContext, CGRect) -> Void) throws {
    let dir = outputRoot.appendingPathComponent("\(name).imageset", isDirectory: true)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

    let rep = makeBitmap(size: canvasSize)
    guard let context = NSGraphicsContext(bitmapImageRep: rep)?.cgContext else {
        throw NSError(domain: "DomainIcons", code: 1)
    }

    let rect = CGRect(origin: .zero, size: canvasSize)
    context.setAllowsAntialiasing(true)
    context.setShouldAntialias(true)
    context.clear(rect)
    draw(context, rect)

    let imageURL = dir.appendingPathComponent("\(name).png")
    guard let pngData = rep.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "DomainIcons", code: 2)
    }
    try pngData.write(to: imageURL)

    let contents = """
    {
      "images" : [
        {
          "filename" : "\(name).png",
          "idiom" : "universal",
          "scale" : "1x"
        }
      ],
      "info" : {
        "author" : "xcode",
        "version" : 1
      },
      "properties" : {
        "preserves-vector-representation" : false
      }
    }
    """
    try contents.write(to: dir.appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)
}

func addPolygon(_ ctx: CGContext, points: [CGPoint]) {
    guard let first = points.first else { return }
    ctx.move(to: first)
    for point in points.dropFirst() {
        ctx.addLine(to: point)
    }
    ctx.closePath()
}

func addRoundedRect(_ ctx: CGContext, rect: CGRect, radius: CGFloat) {
    ctx.addPath(CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil))
}

func rotatedPoints(_ points: [CGPoint], angle: CGFloat, center: CGPoint) -> [CGPoint] {
    points.map { point in
        let translatedX = point.x - center.x
        let translatedY = point.y - center.y
        let x = translatedX * cos(angle) - translatedY * sin(angle) + center.x
        let y = translatedX * sin(angle) + translatedY * cos(angle) + center.y
        return CGPoint(x: x, y: y)
    }
}

func fillCircle(_ ctx: CGContext, center: CGPoint, radius: CGFloat) {
    ctx.fillEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
}

let fury = IconSpec(name: "DomainFury", color: NSColor(calibratedRed: 0.82, green: 0.12, blue: 0.17, alpha: 1)) { ctx, rect in
    let c = CGPoint(x: rect.midX, y: rect.midY)
    ctx.setFillColor(NSColor.clear.cgColor)
    ctx.setStrokeColor(NSColor.clear.cgColor)
    ctx.setFillColor(NSColor(calibratedRed: 0.82, green: 0.12, blue: 0.17, alpha: 1).cgColor)

    let baseBlade: [CGPoint] = [
        CGPoint(x: c.x - 65, y: c.y + 95),
        CGPoint(x: c.x - 10, y: c.y + 315),
        CGPoint(x: c.x + 28, y: c.y + 95),
        CGPoint(x: c.x + 145, y: c.y + 42),
        CGPoint(x: c.x + 55, y: c.y + 5),
        CGPoint(x: c.x + 12, y: c.y + 56)
    ]

    for angle in stride(from: 0.0, to: Double.pi * 2, by: Double.pi * 2 / 3) {
        addPolygon(ctx, points: rotatedPoints(baseBlade, angle: angle, center: c))
        ctx.fillPath()
    }

    let outerRing = CGMutablePath()
    outerRing.addEllipse(in: CGRect(x: c.x - 132, y: c.y - 132, width: 264, height: 264))
    outerRing.addEllipse(in: CGRect(x: c.x - 82, y: c.y - 82, width: 164, height: 164))
    ctx.addPath(outerRing)
    ctx.drawPath(using: .eoFill)
}

let calm = IconSpec(name: "DomainCalm", color: NSColor(calibratedRed: 0.15, green: 0.69, blue: 0.48, alpha: 1)) { ctx, rect in
    let c = CGPoint(x: rect.midX, y: rect.midY + 10)
    ctx.setFillColor(NSColor(calibratedRed: 0.15, green: 0.69, blue: 0.48, alpha: 1).cgColor)

    let path = CGMutablePath()
    path.move(to: CGPoint(x: c.x, y: c.y + 390))
    path.addCurve(to: CGPoint(x: c.x - 360, y: c.y - 60), control1: CGPoint(x: c.x - 200, y: c.y + 300), control2: CGPoint(x: c.x - 360, y: c.y + 120))
    path.addCurve(to: CGPoint(x: c.x - 120, y: c.y - 330), control1: CGPoint(x: c.x - 360, y: c.y - 200), control2: CGPoint(x: c.x - 220, y: c.y - 330))
    path.addCurve(to: CGPoint(x: c.x, y: c.y - 420), control1: CGPoint(x: c.x - 45, y: c.y - 388), control2: CGPoint(x: c.x - 15, y: c.y - 412))
    path.addCurve(to: CGPoint(x: c.x + 120, y: c.y - 330), control1: CGPoint(x: c.x + 15, y: c.y - 412), control2: CGPoint(x: c.x + 45, y: c.y - 388))
    path.addCurve(to: CGPoint(x: c.x + 360, y: c.y - 60), control1: CGPoint(x: c.x + 220, y: c.y - 330), control2: CGPoint(x: c.x + 360, y: c.y - 200))
    path.addCurve(to: CGPoint(x: c.x, y: c.y + 390), control1: CGPoint(x: c.x + 360, y: c.y + 120), control2: CGPoint(x: c.x + 200, y: c.y + 300))
    path.closeSubpath()

    path.addEllipse(in: CGRect(x: c.x - 180, y: c.y - 210, width: 360, height: 360))
    path.move(to: CGPoint(x: c.x - 54, y: c.y - 120))
    path.addCurve(to: CGPoint(x: c.x - 26, y: c.y + 190), control1: CGPoint(x: c.x - 54, y: c.y + 18), control2: CGPoint(x: c.x - 44, y: c.y + 120))
    path.addLine(to: CGPoint(x: c.x + 26, y: c.y + 190))
    path.addCurve(to: CGPoint(x: c.x + 54, y: c.y - 120), control1: CGPoint(x: c.x + 44, y: c.y + 120), control2: CGPoint(x: c.x + 54, y: c.y + 18))
    path.closeSubpath()
    path.addEllipse(in: CGRect(x: c.x - 110, y: c.y - 100, width: 220, height: 220))

    ctx.addPath(path)
    ctx.drawPath(using: .eoFill)
}

let order = IconSpec(name: "DomainOrder", color: NSColor(calibratedRed: 0.88, green: 0.72, blue: 0.00, alpha: 1)) { ctx, rect in
    let c = CGPoint(x: rect.midX, y: rect.midY + 20)
    ctx.setFillColor(NSColor(calibratedRed: 0.88, green: 0.72, blue: 0.00, alpha: 1).cgColor)

    addPolygon(ctx, points: [
        CGPoint(x: c.x, y: c.y + 250),
        CGPoint(x: c.x + 56, y: c.y + 160),
        CGPoint(x: c.x, y: c.y + 70),
        CGPoint(x: c.x - 56, y: c.y + 160)
    ])
    ctx.fillPath()

    addPolygon(ctx, points: [
        CGPoint(x: c.x - 300, y: c.y + 85),
        CGPoint(x: c.x - 80, y: c.y + 148),
        CGPoint(x: c.x - 145, y: c.y + 12),
        CGPoint(x: c.x - 350, y: c.y + 28)
    ])
    ctx.fillPath()

    addPolygon(ctx, points: [
        CGPoint(x: c.x + 300, y: c.y + 85),
        CGPoint(x: c.x + 80, y: c.y + 148),
        CGPoint(x: c.x + 145, y: c.y + 12),
        CGPoint(x: c.x + 350, y: c.y + 28)
    ])
    ctx.fillPath()

    addPolygon(ctx, points: [
        CGPoint(x: c.x - 245, y: c.y - 25),
        CGPoint(x: c.x - 80, y: c.y - 5),
        CGPoint(x: c.x - 120, y: c.y - 120),
        CGPoint(x: c.x - 290, y: c.y - 135)
    ])
    ctx.fillPath()

    addPolygon(ctx, points: [
        CGPoint(x: c.x + 245, y: c.y - 25),
        CGPoint(x: c.x + 80, y: c.y - 5),
        CGPoint(x: c.x + 120, y: c.y - 120),
        CGPoint(x: c.x + 290, y: c.y - 135)
    ])
    ctx.fillPath()

    let ribbon = CGMutablePath()
    ribbon.move(to: CGPoint(x: c.x - 100, y: c.y + 135))
    ribbon.addCurve(to: CGPoint(x: c.x - 18, y: c.y + 40), control1: CGPoint(x: c.x - 40, y: c.y + 135), control2: CGPoint(x: c.x - 64, y: c.y + 62))
    ribbon.addCurve(to: CGPoint(x: c.x + 80, y: c.y - 20), control1: CGPoint(x: c.x + 8, y: c.y + 20), control2: CGPoint(x: c.x + 38, y: c.y + 8))
    ribbon.addCurve(to: CGPoint(x: c.x + 126, y: c.y + 25), control1: CGPoint(x: c.x + 106, y: c.y - 5), control2: CGPoint(x: c.x + 118, y: c.y + 10))
    ribbon.addCurve(to: CGPoint(x: c.x + 18, y: c.y + 118), control1: CGPoint(x: c.x + 90, y: c.y + 58), control2: CGPoint(x: c.x + 54, y: c.y + 95))
    ribbon.addCurve(to: CGPoint(x: c.x - 90, y: c.y + 228), control1: CGPoint(x: c.x - 20, y: c.y + 142), control2: CGPoint(x: c.x - 46, y: c.y + 182))
    ribbon.addLine(to: CGPoint(x: c.x - 20, y: c.y + 270))
    ribbon.addCurve(to: CGPoint(x: c.x + 96, y: c.y + 140), control1: CGPoint(x: c.x + 34, y: c.y + 224), control2: CGPoint(x: c.x + 74, y: c.y + 186))
    ribbon.addCurve(to: CGPoint(x: c.x + 180, y: c.y + 70), control1: CGPoint(x: c.x + 126, y: c.y + 108), control2: CGPoint(x: c.x + 156, y: c.y + 92))
    ribbon.addCurve(to: CGPoint(x: c.x + 118, y: c.y - 70), control1: CGPoint(x: c.x + 200, y: c.y + 32), control2: CGPoint(x: c.x + 188, y: c.y - 28))
    ribbon.addCurve(to: CGPoint(x: c.x - 12, y: c.y - 30), control1: CGPoint(x: c.x + 48, y: c.y - 104), control2: CGPoint(x: c.x + 6, y: c.y - 92))
    ribbon.addCurve(to: CGPoint(x: c.x - 98, y: c.y + 46), control1: CGPoint(x: c.x - 32, y: c.y + 4), control2: CGPoint(x: c.x - 60, y: c.y + 34))
    ribbon.closeSubpath()
    ctx.addPath(ribbon)
    ctx.fillPath()
}

let chaos = IconSpec(name: "DomainChaos", color: NSColor(calibratedRed: 0.45, green: 0.31, blue: 0.65, alpha: 1)) { ctx, rect in
    let c = CGPoint(x: rect.midX, y: rect.midY)
    ctx.setFillColor(NSColor(calibratedRed: 0.45, green: 0.31, blue: 0.65, alpha: 1).cgColor)

    let blade: [CGPoint] = [
        CGPoint(x: c.x - 145, y: c.y + 150),
        CGPoint(x: c.x - 10, y: c.y + 210),
        CGPoint(x: c.x + 130, y: c.y + 152),
        CGPoint(x: c.x + 88, y: c.y + 72),
        CGPoint(x: c.x - 20, y: c.y + 112),
        CGPoint(x: c.x - 112, y: c.y + 62)
    ]

    for angle in stride(from: 0.0, to: Double.pi * 2, by: Double.pi / 2) {
        addPolygon(ctx, points: rotatedPoints(blade, angle: angle, center: c))
        ctx.fillPath()
    }

    addPolygon(ctx, points: [
        CGPoint(x: c.x, y: c.y + 82),
        CGPoint(x: c.x + 82, y: c.y),
        CGPoint(x: c.x, y: c.y - 82),
        CGPoint(x: c.x - 82, y: c.y)
    ])
    ctx.fillPath()
}

let mind = IconSpec(name: "DomainMind", color: NSColor(calibratedRed: 0.20, green: 0.52, blue: 0.68, alpha: 1)) { ctx, rect in
    let c = CGPoint(x: rect.midX + 30, y: rect.midY)
    ctx.setFillColor(NSColor(calibratedRed: 0.20, green: 0.52, blue: 0.68, alpha: 1).cgColor)

    let ring = CGMutablePath()
    ring.addEllipse(in: CGRect(x: c.x - 315, y: c.y - 315, width: 630, height: 630))
    ring.addEllipse(in: CGRect(x: c.x - 245, y: c.y - 245, width: 490, height: 490))
    ctx.addPath(ring)
    ctx.drawPath(using: .eoFill)

    let orbit = CGMutablePath()
    orbit.addEllipse(in: CGRect(x: c.x - 185, y: c.y - 185, width: 370, height: 370))
    orbit.addEllipse(in: CGRect(x: c.x - 125, y: c.y - 125, width: 250, height: 250))
    ctx.addPath(orbit)
    ctx.drawPath(using: .eoFill)

    fillCircle(ctx, center: c, radius: 74)
    fillCircle(ctx, center: CGPoint(x: c.x - 215, y: c.y), radius: 46)
    fillCircle(ctx, center: CGPoint(x: c.x - 355, y: c.y), radius: 24)

    addPolygon(ctx, points: [
        CGPoint(x: c.x, y: c.y + 355),
        CGPoint(x: c.x + 18, y: c.y + 315),
        CGPoint(x: c.x, y: c.y + 280),
        CGPoint(x: c.x - 18, y: c.y + 315)
    ])
    ctx.fillPath()
    addPolygon(ctx, points: [
        CGPoint(x: c.x, y: c.y - 355),
        CGPoint(x: c.x + 18, y: c.y - 315),
        CGPoint(x: c.x, y: c.y - 280),
        CGPoint(x: c.x - 18, y: c.y - 315)
    ])
    ctx.fillPath()
    addPolygon(ctx, points: [
        CGPoint(x: c.x + 355, y: c.y),
        CGPoint(x: c.x + 315, y: c.y + 18),
        CGPoint(x: c.x + 280, y: c.y),
        CGPoint(x: c.x + 315, y: c.y - 18)
    ])
    ctx.fillPath()
    addPolygon(ctx, points: [
        CGPoint(x: c.x - 5, y: c.y + 8),
        CGPoint(x: c.x - 15, y: c.y),
        CGPoint(x: c.x - 5, y: c.y - 8)
    ])
    ctx.fillPath()
}

let body = IconSpec(name: "DomainBody", color: NSColor(calibratedRed: 0.95, green: 0.50, blue: 0.00, alpha: 1)) { ctx, rect in
    let c = CGPoint(x: rect.midX, y: rect.midY)
    ctx.setFillColor(NSColor(calibratedRed: 0.95, green: 0.50, blue: 0.00, alpha: 1).cgColor)

    addPolygon(ctx, points: [
        CGPoint(x: c.x, y: c.y + 370),
        CGPoint(x: c.x + 165, y: c.y + 88),
        CGPoint(x: c.x, y: c.y - 340),
        CGPoint(x: c.x - 165, y: c.y + 88)
    ])
    ctx.fillPath()

    ctx.setBlendMode(.clear)
    addPolygon(ctx, points: [
        CGPoint(x: c.x, y: c.y + 300),
        CGPoint(x: c.x + 86, y: c.y + 98),
        CGPoint(x: c.x, y: c.y - 230),
        CGPoint(x: c.x - 86, y: c.y + 98)
    ])
    ctx.fillPath()
    ctx.setBlendMode(.normal)
    ctx.setFillColor(NSColor(calibratedRed: 0.95, green: 0.50, blue: 0.00, alpha: 1).cgColor)

    addPolygon(ctx, points: [
        CGPoint(x: c.x - 430, y: c.y + 105),
        CGPoint(x: c.x - 250, y: c.y + 285),
        CGPoint(x: c.x - 136, y: c.y + 170),
        CGPoint(x: c.x - 315, y: c.y - 5)
    ])
    ctx.fillPath()
    addPolygon(ctx, points: [
        CGPoint(x: c.x + 430, y: c.y + 105),
        CGPoint(x: c.x + 250, y: c.y + 285),
        CGPoint(x: c.x + 136, y: c.y + 170),
        CGPoint(x: c.x + 315, y: c.y - 5)
    ])
    ctx.fillPath()
    addPolygon(ctx, points: [
        CGPoint(x: c.x - 430, y: c.y - 105),
        CGPoint(x: c.x - 250, y: c.y - 285),
        CGPoint(x: c.x - 136, y: c.y - 170),
        CGPoint(x: c.x - 315, y: c.y + 5)
    ])
    ctx.fillPath()
    addPolygon(ctx, points: [
        CGPoint(x: c.x + 430, y: c.y - 105),
        CGPoint(x: c.x + 250, y: c.y - 285),
        CGPoint(x: c.x + 136, y: c.y - 170),
        CGPoint(x: c.x + 315, y: c.y + 5)
    ])
    ctx.fillPath()
}

let specs = [fury, calm, order, chaos, mind, body]

for spec in specs {
    try writePNG(named: spec.name, draw: spec.draw)
}

print("Generated \(specs.count) domain icons in \(outputRoot.path)")
