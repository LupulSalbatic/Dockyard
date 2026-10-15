import AppKit
import DockyardCore
import SwiftUI

/// Panoul care „răsare” din Dock cu aplicațiile folderului.
final class FolderPanelController {
    private weak var owner: FolderAppDelegate?
    private let panel: KeyPanel
    private let model = PanelModel()
    private var hosting: NSHostingView<PanelView>!

    init(owner: FolderAppDelegate) {
        self.owner = owner
        panel = KeyPanel(contentRect: .zero, styleMask: [.borderless], backing: .buffered, defer: true)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .popUpMenu
        panel.collectionBehavior = [.canJoinAllSpaces, .transient, .ignoresCycle]
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.onEscape = { [weak self] in self?.hide() }
        hosting = NSHostingView(rootView: PanelView(model: model, open: { [weak owner] path in owner?.open(path) },
                                                    edit: { [weak owner] in owner?.editInMain() }))
        hosting.wantsLayer = true
        panel.contentView = hosting
        refresh()
    }

    func refresh() {
        guard let owner, let folder = owner.folder else { return }
        model.folder = folder
        model.dataDir = owner.dataDir
    }

    var isShown: Bool { panel.isVisible && model.visible }

    private var lastHide = Date.distantPast
    /// Doar pentru testare: panoul nu se închide la pierderea focusului.
    var pinned = false

    func toggle(at mouse: NSPoint, force: Bool = false) {
        if isShown && !force { hide(); return }
        // click pe Dock cât panoul e deschis: panoul s-a închis deja la pierderea focusului, nu-l redeschidem
        if !force && Date().timeIntervalSince(lastHide) < 0.35 { return }
        show(at: mouse)
    }

    func show(at mouse: NSPoint) {
        refresh()
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main ?? NSScreen.screens[0]
        let edge = DockEdge.detect(on: screen)
        model.edge = edge
        model.visible = false
        hosting.layoutSubtreeIfNeeded()
        let size = hosting.fittingSize
        let vf = screen.visibleFrame, f = screen.frame
        var origin = NSPoint.zero
        switch edge {
        case .bottom:
            origin.x = min(max(mouse.x - size.width / 2, vf.minX + 8), vf.maxX - size.width - 8)
            origin.y = max(vf.minY, f.minY + 70) + 6
        case .left:
            origin.x = max(vf.minX, f.minX + 70) + 6
            origin.y = min(max(mouse.y - size.height / 2, vf.minY + 8), vf.maxY - size.height - 8)
        case .right:
            origin.x = min(vf.maxX, f.maxX - 70) - size.width - 6
            origin.y = min(max(mouse.y - size.height / 2, vf.minY + 8), vf.maxY - size.height - 8)
        }
        model.notchX = edge == .bottom ? mouse.x - origin.x : nil
        panel.setFrame(NSRect(origin: origin, size: size), display: true)
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        DispatchQueue.main.async {
            withAnimation(.spring(response: 0.38, dampingFraction: 0.78)) { self.model.visible = true }
        }
    }

    func hide() {
        guard panel.isVisible, !pinned else { return }
        lastHide = Date()
        withAnimation(.easeIn(duration: 0.16)) { model.visible = false }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { [weak self] in
            guard let self, !self.model.visible else { return }
            self.panel.orderOut(nil)
        }
    }
}

final class KeyPanel: NSPanel {
    var onEscape: (() -> Void)?
    override var canBecomeKey: Bool { true }
    override func cancelOperation(_ sender: Any?) { onEscape?() }
    override func resignKey() {
        super.resignKey()
        onEscape?()
    }
}

enum DockEdge {
    case bottom, left, right
    static func detect(on screen: NSScreen) -> DockEdge {
        let f = screen.frame, v = screen.visibleFrame
        let bottom = v.minY - f.minY, left = v.minX - f.minX, right = f.maxX - v.maxX
        if left > bottom && left > right { return .left }
        if right > bottom && right > left { return .right }
        return .bottom
    }
}

final class PanelModel: ObservableObject {
    @Published var folder: DockFolder?
    @Published var dataDir: URL = URL(fileURLWithPath: "/")
    @Published var visible = false
    @Published var edge: DockEdge = .bottom
    @Published var notchX: CGFloat?
}

struct PanelView: View {
    @ObservedObject var model: PanelModel
    let open: (String) -> Void
    let edit: () -> Void

    private var apps: [AppRef] { model.folder?.apps ?? [] }
    private var columns: Int { min(max(apps.count, 1), apps.count > 12 ? 5 : 4) }
    private var accent: Color { Color(nsColor: NSColor(hexString: model.folder?.icon.colorA ?? "8B5CF6")) }
    private var accent2: Color { Color(nsColor: NSColor(hexString: model.folder?.icon.colorB ?? "22D3EE")) }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    if let f = model.folder {
                        Image(nsImage: IconRenderer.image(for: f, dataDir: model.dataDir, size: 64))
                            .resizable().frame(width: 26, height: 26)
                    }
                    Text(model.folder?.name ?? "")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                    Spacer(minLength: 20)
                    Button(action: edit) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 12, weight: .semibold))
                            .frame(width: 26, height: 26)
                            .background(Circle().fill(Color.white.opacity(0.1)))
                    }
                    .buttonStyle(.plain)
                    .help("Editează în Dockyard")
                }

                if apps.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "square.dashed").font(.system(size: 30, weight: .light))
                        Text("Folder gol").font(.system(size: 13, weight: .semibold))
                        Text("Adaugă aplicații din Dockyard.").font(.system(size: 11)).opacity(0.6)
                    }
                    .frame(width: 240, height: 120)
                } else {
                    LazyVGrid(columns: Array(repeating: GridItem(.fixed(84), spacing: 6), count: columns), spacing: 10) {
                        ForEach(Array(apps.enumerated()), id: \.element.id) { i, app in
                            AppCell(app: app, index: i, visible: model.visible, accent: accent) { open(app.path) }
                        }
                    }
                }
            }
            .padding(18)
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: 26, style: .continuous).fill(.ultraThinMaterial)
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .fill(LinearGradient(colors: [accent.opacity(0.22), accent2.opacity(0.10)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .strokeBorder(LinearGradient(colors: [.white.opacity(0.35), .white.opacity(0.05)], startPoint: .top, endPoint: .bottom), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.45), radius: 30, y: 14)
            }
            .overlay(alignment: .bottomLeading) {
                if let x = model.notchX {
                    Notch()
                        .fill(.ultraThinMaterial)
                        .frame(width: 22, height: 10)
                        .offset(x: max(x - 24 - 11, 22), y: 10)
                }
            }
        }
        .padding(24)
        .environment(\.colorScheme, .dark)
        .scaleEffect(model.visible ? 1 : 0.82, anchor: anchor)
        .opacity(model.visible ? 1 : 0)
        .offset(y: model.visible ? 0 : (model.edge == .bottom ? 24 : 0))
        .blur(radius: model.visible ? 0 : 6)
    }

    private var anchor: UnitPoint {
        switch model.edge {
        case .bottom: return .bottom
        case .left: return .leading
        case .right: return .trailing
        }
    }
}

private struct AppCell: View {
    let app: AppRef
    let index: Int
    let visible: Bool
    let accent: Color
    let action: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: app.path))
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 60, height: 60)
                    .shadow(color: hover ? accent.opacity(0.7) : .black.opacity(0.3), radius: hover ? 12 : 4, y: hover ? 2 : 3)
                    .scaleEffect(hover ? 1.1 : 1)
                    .opacity(app.exists ? 1 : 0.35)
                Text(app.name)
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(width: 80)
            }
            .padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.white.opacity(hover ? 0.1 : 0)))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!app.exists)
        .onHover { h in withAnimation(.spring(response: 0.3, dampingFraction: 0.65)) { hover = h } }
        // intrare în cascadă
        .scaleEffect(visible ? 1 : 0.5)
        .opacity(visible ? 1 : 0)
        .animation(.spring(response: 0.42, dampingFraction: 0.72).delay(visible ? 0.03 * Double(index) : 0), value: visible)
        .help(app.exists ? app.name : "\(app.name) — aplicația nu mai există")
    }
}

private struct Notch: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.minY))
        p.addQuadCurve(to: CGPoint(x: r.midX, y: r.maxY), control: CGPoint(x: r.midX - 3, y: r.minY + 2))
        p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.minY), control: CGPoint(x: r.midX + 3, y: r.minY + 2))
        p.closeSubpath()
        return p
    }
}
