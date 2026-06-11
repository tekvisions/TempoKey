// Generates the TempoKey app icon set with CoreGraphics.
// Concept: light "paper" squircle + circle-of-fifths color wheel (key) + soft-blue tempo pulse (BPM).
// Usage: swift scripts/generate_icon.swift <output appiconset dir>
import AppKit
import CoreGraphics
import Foundation

func makeIcon(size S: CGFloat) -> CGImage {
    let w = Int(S), h = Int(S)
    let cs = CGColorSpaceCreateDeviceRGB()
    let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                        space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.setAllowsAntialiasing(true)
    ctx.interpolationQuality = .high

    let m = S * 0.045                       // transparent margin around the squircle
    let body = S - 2 * m
    let rect = CGRect(x: m, y: m, width: body, height: body)
    let corner = body * 0.2237              // macOS squircle corner radius
    let bg = CGPath(roundedRect: rect, cornerWidth: corner, cornerHeight: corner, transform: nil)

    // Paper gradient body
    ctx.saveGState()
    ctx.addPath(bg); ctx.clip()
    let paper = CGGradient(colorsSpace: cs,
                           colors: [CGColor(red: 1, green: 1, blue: 1, alpha: 1),
                                    CGColor(red: 0.949, green: 0.945, blue: 0.925, alpha: 1)] as CFArray,
                           locations: [0, 1])!
    ctx.drawLinearGradient(paper, start: CGPoint(x: 0, y: rect.maxY), end: CGPoint(x: 0, y: rect.minY), options: [])
    ctx.restoreGState()

    // Hairline edge for definition
    ctx.addPath(bg)
    ctx.setStrokeColor(CGColor(red: 0, green: 0, blue: 0, alpha: 0.06))
    ctx.setLineWidth(max(1, S * 0.004))
    ctx.strokePath()

    let c = CGPoint(x: S / 2, y: S / 2)
    let outerR = body * 0.40
    let ringW = body * 0.105
    let innerR = outerR - ringW
    let midR = outerR - ringW / 2

    // Circle-of-fifths wheel: 12 colored arcs (same hue mapping as the app's key ribbon)
    let gap: CGFloat = 1.5
    for i in 0..<12 {
        let hue = CGFloat(i) / 12.0
        ctx.setStrokeColor(NSColor(hue: hue, saturation: 0.60, brightness: 0.90, alpha: 1).cgColor)
        ctx.setLineWidth(ringW)
        ctx.setLineCap(.butt)
        let a0 = (90.0 - CGFloat(i) * 30.0 - gap / 2) * .pi / 180
        let a1 = (90.0 - CGFloat(i + 1) * 30.0 + gap / 2) * .pi / 180
        ctx.beginPath()
        ctx.addArc(center: c, radius: midR, startAngle: a0, endAngle: a1, clockwise: true)
        ctx.strokePath()
    }

    // Soft-blue tempo pulse through the paper center (echoes the Tempo timeline)
    let r = innerR
    ctx.setStrokeColor(NSColor(calibratedRed: 0.357, green: 0.616, blue: 1.0, alpha: 1).cgColor) // #5B9DFF
    ctx.setLineWidth(body * 0.052)
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)
    let pts = [
        CGPoint(x: c.x - r * 0.82, y: c.y),
        CGPoint(x: c.x - r * 0.34, y: c.y),
        CGPoint(x: c.x - r * 0.10, y: c.y + r * 0.60),
        CGPoint(x: c.x + r * 0.16, y: c.y - r * 0.50),
        CGPoint(x: c.x + r * 0.36, y: c.y),
        CGPoint(x: c.x + r * 0.82, y: c.y),
    ]
    ctx.beginPath()
    ctx.move(to: pts[0])
    for p in pts.dropFirst() { ctx.addLine(to: p) }
    ctx.strokePath()

    return ctx.makeImage()!
}

func writePNG(_ img: CGImage, to path: String) {
    let rep = NSBitmapImageRep(cgImage: img)
    let data = rep.representation(using: .png, properties: [:])!
    try! data.write(to: URL(fileURLWithPath: path))
}

let outDir = CommandLine.arguments[1]
let slots: [(String, CGFloat)] = [
    ("icon_16x16.png", 16), ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32), ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128), ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256), ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512), ("icon_512x512@2x.png", 1024),
]
for (name, s) in slots {
    writePNG(makeIcon(size: s), to: outDir + "/" + name)
    print("wrote \(name) @\(Int(s))px")
}
