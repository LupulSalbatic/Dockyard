// Iconița Dockyard: squircle cyan→violet cu un mini-Dock și un folder care „sare”.
import AppKit

func render(_ px: Int) -> Data {
    let s = CGFloat(px)
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8, samplesPerPixel: 4,
                               hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let ctx = NSGraphicsContext.current!.cgContext
    let body = CGRect(x: s * 0.1, y: s * 0.1, width: s * 0.8, height: s * 0.8)
    let sq = CGPath(roundedRect: body, cornerWidth: body.width * 0.225, cornerHeight: body.width * 0.225, transform: nil)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -s * 0.012), blur: s * 0.035, color: NSColor.black.withAlphaComponent(0.4).cgColor)
    ctx.addPath(sq); ctx.setFillColor(NSColor.black.cgColor); ctx.fillPath()
    ctx.restoreGState()
    ctx.saveGState(); ctx.addPath(sq); ctx.clip()
    let g = CGGradient(colorsSpace: nil, colors: [NSColor(red: 0.13, green: 0.83, blue: 0.93, alpha: 1).cgColor,
                                                  NSColor(red: 0.55, green: 0.36, blue: 0.96, alpha: 1).cgColor] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(g, start: CGPoint(x: body.minX, y: body.maxY), end: CGPoint(x: body.maxX, y: body.minY), options: [])
    // raftul Dock-ului
    let shelf = CGRect(x: body.minX + body.width * 0.12, y: body.minY + body.height * 0.16, width: body.width * 0.76, height: body.height * 0.2)
    ctx.addPath(CGPath(roundedRect: shelf, cornerWidth: shelf.height * 0.35, cornerHeight: shelf.height * 0.35, transform: nil))
    ctx.setFillColor(NSColor.white.withAlphaComponent(0.28).cgColor); ctx.fillPath()
    // trei tile-uri, cel din mijloc ridicat (folderul)
    let t = body.width * 0.17, gap = body.width * 0.06
    let startX = body.midX - (3 * t + 2 * gap) / 2
    for i in 0..<3 {
        let lift: CGFloat = i == 1 ? body.height * 0.2 : 0
        let r = CGRect(x: startX + CGFloat(i) * (t + gap), y: shelf.minY + shelf.height * 0.22 + lift, width: t, height: t)
        ctx.addPath(CGPath(roundedRect: r, cornerWidth: t * 0.25, cornerHeight: t * 0.25, transform: nil))
        ctx.setFillColor(NSColor.white.withAlphaComponent(i == 1 ? 1 : 0.7).cgColor); ctx.fillPath()
        if i == 1 {
            // mozaic 2x2 în folder
            let c = t * 0.26, p = t * 0.16
            for k in 0..<4 {
                let rr = CGRect(x: r.minX + p + CGFloat(k % 2) * (c + t * 0.06), y: r.minY + p + CGFloat(k / 2) * (c + t * 0.06), width: c, height: c)
                ctx.addPath(CGPath(roundedRect: rr, cornerWidth: c * 0.3, cornerHeight: c * 0.3, transform: nil))
                ctx.setFillColor(NSColor(red: 0.45, green: 0.45, blue: 0.95, alpha: 0.9).cgColor); ctx.fillPath()
            }
        }
    }
    let gloss = CGGradient(colorsSpace: nil, colors: [NSColor.white.withAlphaComponent(0.3).cgColor, NSColor.white.withAlphaComponent(0).cgColor] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(gloss, start: CGPoint(x: body.midX, y: body.maxY), end: CGPoint(x: body.midX, y: body.midY), options: [])
    ctx.restoreGState()
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let out = CommandLine.arguments[1]
try? FileManager.default.createDirectory(atPath: out, withIntermediateDirectories: true)
for (name, px) in [("16x16", 16), ("16x16@2x", 32), ("32x32", 32), ("32x32@2x", 64), ("128x128", 128), ("128x128@2x", 256),
                   ("256x256", 256), ("256x256@2x", 512), ("512x512", 512), ("512x512@2x", 1024)] {
    try! render(px).write(to: URL(fileURLWithPath: "\(out)/icon_\(name).png"))
}
