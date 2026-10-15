import AppKit

/// Desenează iconița unui folder (în grila de iconițe macOS: corp 824/1024 cu umbră).
public enum IconRenderer {
    public static func image(for folder: DockFolder, dataDir: URL, size: CGFloat = 512) -> NSImage {
        let rep = bitmap(for: folder, dataDir: dataDir, pixels: Int(size))
        let img = NSImage(size: NSSize(width: size, height: size))
        img.addRepresentation(rep)
        return img
    }

    public static func png(for folder: DockFolder, dataDir: URL, pixels: Int) -> Data? {
        bitmap(for: folder, dataDir: dataDir, pixels: pixels).representation(using: .png, properties: [:])
    }

    public static func bitmap(for folder: DockFolder, dataDir: URL, pixels: Int) -> NSBitmapImageRep {
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8,
                                   samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                                   bytesPerRow: 0, bitsPerPixel: 0)!
        rep.size = NSSize(width: pixels, height: pixels)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        draw(folder, dataDir: dataDir, in: CGFloat(pixels))
        NSGraphicsContext.restoreGraphicsState()
        return rep
    }

    static func draw(_ folder: DockFolder, dataDir: URL, in size: CGFloat) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let s = size / 1024
        let body = CGRect(x: 100 * s, y: 100 * s, width: 824 * s, height: 824 * s)
        let radius = 185 * s
        let path = CGPath(roundedRect: body, cornerWidth: radius, cornerHeight: radius, transform: nil)
        let icon = folder.icon
        let a = NSColor(hexString: icon.colorA), b = NSColor(hexString: icon.colorB)

        // umbră
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: -12 * s), blur: 30 * s, color: NSColor.black.withAlphaComponent(0.35).cgColor)
        ctx.addPath(path)
        ctx.setFillColor(a.cgColor)
        ctx.fillPath()
        ctx.restoreGState()

        ctx.saveGState()
        ctx.addPath(path)
        ctx.clip()

        // fundal
        let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [a.cgColor, b.cgColor] as CFArray, locations: [0, 1])!
        ctx.drawLinearGradient(grad, start: CGPoint(x: body.minX, y: body.maxY), end: CGPoint(x: body.maxX, y: body.minY), options: [])

        switch icon.style {
        case .image:
            if let file = icon.imageFile,
               let img = NSImage(contentsOf: Paths.iconsDir(dataDir).appendingPathComponent(file)) {
                drawAspectFill(img, in: body)
            } else {
                drawSymbol("photo", in: body, scale: s)
            }
        case .symbol:
            drawSymbol(icon.symbol, in: body, scale: s)
        case .mosaic:
            let apps = folder.apps.filter(\.exists)
            if apps.isEmpty {
                drawSymbol("plus", in: body, scale: s)
            } else {
                drawMosaic(apps, in: body, scale: s)
            }
        }

        if icon.glossy {
            let gloss = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                   colors: [NSColor.white.withAlphaComponent(0.28).cgColor, NSColor.white.withAlphaComponent(0).cgColor] as CFArray,
                                   locations: [0, 1])!
            ctx.drawLinearGradient(gloss, start: CGPoint(x: body.midX, y: body.maxY), end: CGPoint(x: body.midX, y: body.midY), options: [])
        }
        ctx.restoreGState()

        // contur interior fin
        ctx.addPath(path)
        ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.16).cgColor)
        ctx.setLineWidth(3 * s)
        ctx.strokePath()
    }

    private static func drawMosaic(_ apps: [AppRef], in body: CGRect, scale s: CGFloat) {
        let shown = Array(apps.prefix(9))
        let n = shown.count <= 1 ? 1 : (shown.count <= 4 ? 2 : 3)
        let inset: CGFloat = (n == 1 ? 150 : 95) * s
        let gap: CGFloat = (n == 3 ? 26 : 36) * s
        let area = body.insetBy(dx: inset, dy: inset)
        let cell = (area.width - gap * CGFloat(n - 1)) / CGFloat(n)
        for (i, app) in shown.enumerated() {
            let row = i / n, col = i % n
            let r = CGRect(x: area.minX + CGFloat(col) * (cell + gap),
                           y: area.maxY - CGFloat(row + 1) * cell - CGFloat(row) * gap,
                           width: cell, height: cell)
            let icon = NSWorkspace.shared.icon(forFile: app.path)
            // iconițele macOS au deja margine transparentă; le mărim ușor ca să umple celula
            icon.draw(in: r.insetBy(dx: -cell * 0.08, dy: -cell * 0.08), from: .zero, operation: .sourceOver, fraction: 1)
        }
    }

    private static func drawSymbol(_ name: String, in body: CGRect, scale s: CGFloat) {
        let config = NSImage.SymbolConfiguration(pointSize: 380 * s, weight: .semibold)
            .applying(NSImage.SymbolConfiguration(paletteColors: [.white]))
        guard let sym = NSImage(systemSymbolName: name, accessibilityDescription: nil)?.withSymbolConfiguration(config) else { return }
        let maxSide = body.width * 0.52
        let ratio = min(maxSide / sym.size.width, maxSide / sym.size.height)
        let w = sym.size.width * ratio, h = sym.size.height * ratio
        let r = CGRect(x: body.midX - w / 2, y: body.midY - h / 2, width: w, height: h)
        let ctx = NSGraphicsContext.current!.cgContext
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: -8 * s), blur: 20 * s, color: NSColor.black.withAlphaComponent(0.25).cgColor)
        sym.draw(in: r)
        ctx.restoreGState()
    }

    private static func drawAspectFill(_ img: NSImage, in rect: CGRect) {
        let sz = img.size
        guard sz.width > 0, sz.height > 0 else { return }
        let ratio = max(rect.width / sz.width, rect.height / sz.height)
        let w = sz.width * ratio, h = sz.height * ratio
        img.draw(in: CGRect(x: rect.midX - w / 2, y: rect.midY - h / 2, width: w, height: h))
    }
}

/// Scrie un fișier .icns (PNG-uri la 128…1024 px).
public enum ICNSWriter {
    public static func data(for folder: DockFolder, dataDir: URL) -> Data {
        let entries: [(String, Int)] = [("ic07", 128), ("ic08", 256), ("ic09", 512), ("ic10", 1024)]
        var body = Data()
        for (type, px) in entries {
            guard let png = IconRenderer.png(for: folder, dataDir: dataDir, pixels: px) else { continue }
            body.append(contentsOf: Array(type.utf8))
            body.append(bigEndian: UInt32(png.count + 8))
            body.append(png)
        }
        var out = Data("icns".utf8)
        out.append(bigEndian: UInt32(body.count + 8))
        out.append(body)
        return out
    }
}

extension Data {
    mutating func append(bigEndian v: UInt32) {
        var be = v.bigEndian
        Swift.withUnsafeBytes(of: &be) { append(contentsOf: $0) }
    }
}

extension NSColor {
    public convenience init(hexString: String) {
        let clean = hexString.trimmingCharacters(in: CharacterSet(charactersIn: "# "))
        let v = UInt32(clean, radix: 16) ?? 0x8B5CF6
        self.init(srgbRed: CGFloat((v >> 16) & 0xFF) / 255, green: CGFloat((v >> 8) & 0xFF) / 255, blue: CGFloat(v & 0xFF) / 255, alpha: 1)
    }
}
