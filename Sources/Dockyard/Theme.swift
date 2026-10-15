import AppKit
import SwiftUI

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB, red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
    }
    init(hexString: String) {
        self.init(hex: UInt32(hexString.trimmingCharacters(in: CharacterSet(charactersIn: "# ")), radix: 16) ?? 0x8B5CF6)
    }
    var hexString: String {
        guard let c = NSColor(self).usingColorSpace(.sRGB) else { return "8B5CF6" }
        return String(format: "%02X%02X%02X", Int((c.redComponent * 255).rounded()), Int((c.greenComponent * 255).rounded()), Int((c.blueComponent * 255).rounded()))
    }
}

struct Palette: Hashable {
    let a: Color
    let b: Color
    var gradient: LinearGradient { LinearGradient(colors: [a, b], startPoint: .topLeading, endPoint: .bottomTrailing) }
}

enum Theme {
    static let bg = Color(hex: 0x07070D)
    static let surface = Color.white.opacity(0.045)
    static let stroke = Color.white.opacity(0.09)
    static let text2 = Color.white.opacity(0.62)
    static let text3 = Color.white.opacity(0.38)
    static let brand = Palette(a: Color(hex: 0x22D3EE), b: Color(hex: 0x8B5CF6))
    static let danger = Palette(a: Color(hex: 0xFF4D6D), b: Color(hex: 0xFF8A3D))
    static let spring = Animation.spring(response: 0.5, dampingFraction: 0.8)
    static let snappy = Animation.spring(response: 0.32, dampingFraction: 0.75)

    /// Gradiente sugerate pentru iconițe.
    static let presets: [(String, String)] = [
        ("8B5CF6", "EC4899"), ("22D3EE", "6366F1"), ("F59E0B", "F43F5E"), ("34D399", "0EA5E9"),
        ("A3E635", "14B8A6"), ("F472B6", "A78BFA"), ("FB7185", "FBBF24"), ("0F172A", "475569"),
        ("1E3A8A", "06B6D4"), ("FFFFFF", "CBD5E1"), ("111111", "3F3F46"), ("7C2D12", "EA580C"),
    ]
}

extension View {
    func glass(_ radius: CGFloat = 22, highlight: Bool = false, tint: Color? = nil) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        return background {
            ZStack {
                shape.fill(.ultraThinMaterial)
                shape.fill(Theme.surface)
                if let tint { shape.fill(tint.opacity(0.08)) }
            }
        }
        .overlay {
            shape.strokeBorder(LinearGradient(colors: [Color.white.opacity(highlight ? 0.3 : 0.16), Color.white.opacity(0.03), Color.white.opacity(0.07)],
                                              startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
        }
        .clipShape(shape)
    }

    func sectionLabel() -> some View {
        font(.system(size: 11, weight: .semibold)).tracking(1.4).foregroundStyle(Theme.text3)
    }

    func cascade(_ index: Int, active: Bool) -> some View {
        opacity(active ? 1 : 0)
            .offset(y: active ? 0 : 16)
            .blur(radius: active ? 0 : 5)
            .animation(.spring(response: 0.6, dampingFraction: 0.82).delay(Double(index) * 0.05), value: active)
    }
}

struct PressableStyle: ButtonStyle {
    var scale: CGFloat = 0.96
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .animation(Theme.snappy, value: configuration.isPressed)
    }
}

struct PillButton: View {
    let title: String
    let symbol: String
    var palette: Palette? = nil
    let action: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: symbol).font(.system(size: 12, weight: .semibold)).symbolEffect(.bounce, value: hover)
                Text(title).font(.system(size: 12.5, weight: .semibold))
            }
            .foregroundStyle(.white.opacity(palette == nil && !hover ? 0.85 : 1))
            .padding(.horizontal, 14)
            .frame(height: 32)
            .background {
                if let palette {
                    Capsule().fill(palette.gradient).shadow(color: palette.a.opacity(hover ? 0.6 : 0.35), radius: hover ? 14 : 8, y: 4)
                } else {
                    Capsule().fill(Color.white.opacity(hover ? 0.14 : 0.07))
                }
            }
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.12), lineWidth: 1))
            .contentShape(Capsule())
        }
        .buttonStyle(PressableStyle())
        .onHover { h in withAnimation(Theme.snappy) { hover = h } }
    }
}

struct IconButton: View {
    let symbol: String
    var help: String = ""
    let action: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(hover ? 1 : 0.7))
                .frame(width: 30, height: 30)
                .background(Circle().fill(Color.white.opacity(hover ? 0.12 : 0.05)))
                .contentShape(Circle())
        }
        .buttonStyle(PressableStyle(scale: 0.9))
        .onHover { h in withAnimation(Theme.snappy) { hover = h } }
        .help(help)
    }
}

struct Chip: View {
    let text: String
    var symbol: String? = nil
    var tint: Color = .white
    var body: some View {
        HStack(spacing: 5) {
            if let symbol { Image(systemName: symbol).font(.system(size: 10, weight: .bold)) }
            Text(text).font(.system(size: 11, weight: .semibold))
        }
        .foregroundStyle(tint.opacity(0.9))
        .padding(.horizontal, 9)
        .frame(height: 22)
        .background(Capsule().fill(tint.opacity(0.1)))
        .overlay(Capsule().strokeBorder(tint.opacity(0.16), lineWidth: 1))
    }
}

/// Fundal viu, nuanțat după folderul selectat.
struct AuroraBackground: View {
    var palette: Palette
    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30)) { ctx in
            let t = Float(ctx.date.timeIntervalSinceReferenceDate)
            MeshGradient(
                width: 3, height: 3,
                points: [
                    [0, 0], [0.5 + 0.1 * sin(t * 0.21), 0], [1, 0],
                    [0, 0.5 + 0.12 * cos(t * 0.17)], [0.5 + 0.18 * sin(t * 0.13), 0.5 + 0.16 * cos(t * 0.19)], [1, 0.5 + 0.12 * sin(t * 0.23)],
                    [0, 1], [0.5 + 0.12 * cos(t * 0.15), 1], [1, 1],
                ],
                colors: [
                    Theme.bg, palette.a.opacity(0.32), Theme.bg,
                    palette.b.opacity(0.18), Color(hex: 0x10101C), palette.a.opacity(0.14),
                    Theme.bg, palette.b.opacity(0.26), Theme.bg,
                ]
            )
            .blur(radius: 40)
            .background(Theme.bg)
        }
        .animation(.easeInOut(duration: 1.2), value: palette)
        .ignoresSafeArea()
    }
}

struct LogoMark: View {
    var size: CGFloat
    var body: some View {
        TimelineView(.animation) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            ZStack {
                RoundedRectangle(cornerRadius: size * 0.3, style: .continuous).fill(Theme.brand.gradient)
                // trei „tile-uri” care plutesc ca într-un Dock
                HStack(alignment: .bottom, spacing: size * 0.07) {
                    ForEach(0..<3, id: \.self) { i in
                        RoundedRectangle(cornerRadius: size * 0.06, style: .continuous)
                            .fill(.white.opacity(i == 1 ? 1 : 0.75))
                            .frame(width: size * 0.18, height: size * 0.18)
                            .offset(y: i == 1 ? -size * 0.06 * CGFloat(abs(sin(t * 2.2))) : 0)
                    }
                }
                .offset(y: size * 0.12)
                Capsule().fill(.white.opacity(0.5)).frame(width: size * 0.66, height: size * 0.05).offset(y: size * 0.27)
            }
            .frame(width: size, height: size)
            .shadow(color: Theme.brand.b.opacity(0.5), radius: 8)
        }
    }
}

/// Oprește salvarea automată a poziției ferestrei (pe care macOS o scrie în ~/Library/Preferences).
struct NoFrameAutosave: NSViewRepresentable {
    final class Hook: NSView {
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            window?.setFrameAutosaveName("")
            window?.isRestorable = false
        }
    }
    func makeNSView(context: Context) -> NSView { Hook() }
    func updateNSView(_ nsView: NSView, context: Context) {}
}
