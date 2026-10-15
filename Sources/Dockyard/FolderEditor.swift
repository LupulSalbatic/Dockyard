import AppKit
import DockyardCore
import SwiftUI
import UniformTypeIdentifiers

struct FolderEditor: View {
    @Environment(Library.self) private var library
    let folderID: UUID
    @State private var name = ""
    @State private var appear = false
    @FocusState private var nameFocused: Bool

    private var folder: DockFolder? { library.folders.first { $0.id == folderID } }

    var body: some View {
        if let f = folder {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    hero(f).cascade(0, active: appear)
                    IconDesigner(folder: f).cascade(1, active: appear)
                    AppsCard(folder: f).cascade(2, active: appear)
                    DockPositionCard(folder: f).cascade(3, active: appear)
                }
                .padding(.horizontal, 34)
                .padding(.top, 44)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.never)
            .onAppear {
                name = f.name
                appear = true
                if library.focusTitleID == folderID {
                    nameFocused = true
                    library.focusTitleID = nil
                }
            }
        }
    }

    private func hero(_ f: DockFolder) -> some View {
        HStack(alignment: .center, spacing: 30) {
            FloatingIcon(folder: f, size: 150)

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    TextField("Nume folder", text: $name)
                        .textFieldStyle(.plain)
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .focused($nameFocused)
                        .fixedSize()
                        .onSubmit { library.rename(folderID, to: name) }
                        .onChange(of: nameFocused) { _, focused in if !focused { library.rename(folderID, to: name) } }
                        .onExitCommand {
                            name = f.name
                            nameFocused = false
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.white.opacity(nameFocused ? 0.08 : 0)))
                        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(Color(hexString: f.icon.colorA).opacity(nameFocused ? 0.7 : 0), lineWidth: 1.5))
                        .padding(.leading, -8)
                    if nameFocused {
                        IconButton(symbol: "checkmark", help: "Salvează numele (Enter)") {
                            library.rename(folderID, to: name)
                            nameFocused = false
                        }
                        .transition(.scale.combined(with: .opacity))
                    } else {
                        IconButton(symbol: "pencil", help: "Redenumește (⌘R)") { nameFocused = true }
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .animation(Theme.snappy, value: nameFocused)
                .onChange(of: library.focusTitleID) { _, id in
                    if id == folderID {
                        nameFocused = true
                        library.focusTitleID = nil
                    }
                }
                .onChange(of: f.name) { _, newName in if !nameFocused { name = newName } }
                HStack(spacing: 6) {
                    Chip(text: "\(f.apps.count) aplicații", symbol: "square.grid.2x2")
                    if let pos = library.dockPosition(of: f) {
                        Chip(text: "Poziția #\(pos + 1) în Dock", symbol: "dock.rectangle", tint: Color(hexString: f.icon.colorA))
                    } else {
                        Chip(text: library.state.enabled ? "Se adaugă în Dock…" : "Ascuns din Dock", symbol: "dock.rectangle", tint: .orange)
                    }
                    if library.isRunning(f) { Chip(text: "Activ", symbol: "circle.fill", tint: .green) }
                }
                HStack(spacing: 8) {
                    PillButton(title: "Deschide panoul", symbol: "rectangle.stack", palette: Palette(a: Color(hexString: f.icon.colorA), b: Color(hexString: f.icon.colorB))) {
                        library.showPanel(f.id)
                    }
                    PillButton(title: "Șterge folderul", symbol: "trash") { library.requestDelete(f.id) }
                }
            }
            Spacer()
        }
    }
}

/// Iconița mare care „plutește”, cu reflexie dedesubt — ca pe un raft de Dock.
struct FloatingIcon: View {
    @Environment(Library.self) private var library
    let folder: DockFolder
    let size: CGFloat
    @State private var float = false

    var body: some View {
        let img = library.icon(folder, size: size)
        VStack(spacing: 0) {
            Image(nsImage: img)
                .resizable()
                .frame(width: size, height: size)
                .shadow(color: Color(hexString: folder.icon.colorA).opacity(0.55), radius: 30, y: 12)
                .offset(y: float ? -8 : 0)
                .contentTransition(.opacity)
                .id(library.iconVersion)
                .transition(.scale(scale: 0.85).combined(with: .opacity))
            Image(nsImage: img)
                .resizable()
                .frame(width: size, height: size * 0.35, alignment: .top)
                .clipped()
                .scaleEffect(x: 1, y: -1)
                .opacity(0.18)
                .mask(LinearGradient(colors: [.white, .clear], startPoint: .top, endPoint: .bottom))
                .offset(y: float ? 8 : 0)
                .blur(radius: 1)
        }
        .animation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true), value: float)
        .animation(.spring(response: 0.45, dampingFraction: 0.7), value: library.iconVersion)
        .onAppear { float = true }
    }
}

// MARK: - Designer iconiță

private struct IconDesigner: View {
    @Environment(Library.self) private var library
    let folder: DockFolder
    @State private var symbolQuery = ""
    @State private var dropTargeted = false

    static let symbols = [
        "square.grid.2x2.fill", "folder.fill", "star.fill", "heart.fill", "bolt.fill", "flame.fill", "sparkles", "wand.and.stars",
        "paintbrush.pointed.fill", "paintpalette.fill", "pencil.and.ruler.fill", "scissors", "camera.fill", "photo.fill", "film.fill", "music.note",
        "headphones", "gamecontroller.fill", "terminal.fill", "chevron.left.forwardslash.chevron.right", "hammer.fill", "wrench.and.screwdriver.fill", "gearshape.fill", "cpu.fill",
        "globe", "message.fill", "envelope.fill", "phone.fill", "briefcase.fill", "chart.bar.fill", "doc.text.fill", "book.fill",
        "graduationcap.fill", "cart.fill", "creditcard.fill", "house.fill", "leaf.fill", "cloud.fill", "moon.stars.fill", "sun.max.fill",
        "airplane", "car.fill", "figure.run", "dumbbell.fill", "cup.and.saucer.fill", "fork.knife", "pawprint.fill", "lock.fill",
    ]

    private func set(_ change: @escaping (inout FolderIcon) -> Void) {
        library.update(folder.id) { change(&$0.icon) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("ICONIȚĂ").sectionLabel()
                Spacer()
                Toggle(isOn: Binding(get: { folder.icon.glossy }, set: { v in set { $0.glossy = v } })) {
                    Text("Luciu").font(.system(size: 12, weight: .medium))
                }
                .toggleStyle(.switch).controlSize(.small)
            }

            // stil
            HStack(spacing: 10) {
                StyleCard(title: "Mozaic", subtitle: "iconițele aplicațiilor", symbol: "square.grid.3x3.fill", selected: folder.icon.style == .mosaic) { set { $0.style = .mosaic } }
                StyleCard(title: "Simbol", subtitle: "simbol + gradient", symbol: "star.square.fill", selected: folder.icon.style == .symbol) { set { $0.style = .symbol } }
                StyleCard(title: "Imagine", subtitle: "orice poză a ta", symbol: "photo.fill", selected: folder.icon.style == .image) {
                    if folder.icon.imageFile == nil { pickImage() } else { set { $0.style = .image } }
                }
            }

            // culori
            VStack(alignment: .leading, spacing: 10) {
                Text("Culori").font(.system(size: 12.5, weight: .semibold)).foregroundStyle(Theme.text2)
                HStack(spacing: 8) {
                    ForEach(Array(Theme.presets.enumerated()), id: \.offset) { _, p in
                        let sel = folder.icon.colorA == p.0 && folder.icon.colorB == p.1
                        Circle()
                            .fill(LinearGradient(colors: [Color(hexString: p.0), Color(hexString: p.1)], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 28, height: 28)
                            .overlay(Circle().strokeBorder(.white.opacity(sel ? 0.95 : 0.15), lineWidth: sel ? 2.5 : 1))
                            .scaleEffect(sel ? 1.15 : 1)
                            .shadow(color: Color(hexString: p.0).opacity(sel ? 0.7 : 0), radius: 8)
                            .onTapGesture { withAnimation(Theme.snappy) { set { $0.colorA = p.0; $0.colorB = p.1 } } }
                    }
                    Divider().frame(height: 24).padding(.horizontal, 4)
                    ColorPicker("", selection: Binding(get: { Color(hexString: folder.icon.colorA) }, set: { c in set { $0.colorA = c.hexString } }), supportsOpacity: false)
                        .labelsHidden()
                    ColorPicker("", selection: Binding(get: { Color(hexString: folder.icon.colorB) }, set: { c in set { $0.colorB = c.hexString } }), supportsOpacity: false)
                        .labelsHidden()
                }
            }

            if folder.icon.style == .symbol {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Simbol").font(.system(size: 12.5, weight: .semibold)).foregroundStyle(Theme.text2)
                        Spacer()
                        HStack(spacing: 6) {
                            Image(systemName: "magnifyingglass").foregroundStyle(Theme.text3)
                            TextField("Caută sau scrie un nume SF Symbol", text: $symbolQuery).textFieldStyle(.plain).frame(width: 220)
                        }
                        .padding(.horizontal, 10).frame(height: 28)
                        .background(Capsule().fill(Color.white.opacity(0.06)))
                    }
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 12), spacing: 6) {
                        ForEach(filteredSymbols, id: \.self) { s in
                            let sel = folder.icon.symbol == s
                            Image(systemName: s)
                                .font(.system(size: 16, weight: .semibold))
                                .frame(width: 38, height: 38)
                                .background(RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(sel ? AnyShapeStyle(LinearGradient(colors: [Color(hexString: folder.icon.colorA), Color(hexString: folder.icon.colorB)], startPoint: .topLeading, endPoint: .bottomTrailing)) : AnyShapeStyle(Color.white.opacity(0.05))))
                                .scaleEffect(sel ? 1.08 : 1)
                                .onTapGesture { withAnimation(Theme.snappy) { set { $0.symbol = s } } }
                                .help(s)
                        }
                    }
                }
                .transition(.opacity.combined(with: .offset(y: -8)))
            }

            if folder.icon.style == .image {
                HStack(spacing: 14) {
                    Image(systemName: "photo.on.rectangle.angled").font(.system(size: 22)).foregroundStyle(Theme.text2)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Trage aici o imagine").font(.system(size: 13, weight: .semibold))
                        Text("PNG, JPG, HEIC, SVG, ICNS — se decupează automat pătrat").font(.system(size: 11)).foregroundStyle(Theme.text3)
                    }
                    Spacer()
                    PillButton(title: "Alege imagine…", symbol: "folder") { pickImage() }
                }
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
                    .foregroundStyle(dropTargeted ? Color(hexString: folder.icon.colorA) : Theme.text3))
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white.opacity(dropTargeted ? 0.08 : 0.02)))
                .scaleEffect(dropTargeted ? 1.02 : 1)
                .dropDestination(for: URL.self) { urls, _ in
                    guard let u = urls.first else { return false }
                    library.setImage(from: u, for: folder.id)
                    return true
                } isTargeted: { t in withAnimation(Theme.snappy) { dropTargeted = t } }
                .transition(.opacity.combined(with: .offset(y: -8)))
            }
        }
        .padding(20)
        .glass(22)
        .animation(.spring(response: 0.45, dampingFraction: 0.85), value: folder.icon.style)
    }

    private var filteredSymbols: [String] {
        let q = symbolQuery.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return Self.symbols }
        var list = Self.symbols.filter { $0.contains(q) }
        if NSImage(systemSymbolName: q, accessibilityDescription: nil) != nil, !list.contains(q) { list.insert(q, at: 0) }
        return list
    }

    private func pickImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.prompt = "Folosește ca iconiță"
        if panel.runModal() == .OK, let url = panel.url {
            library.setImage(from: url, for: folder.id)
        }
    }
}

private struct StyleCard: View {
    let title: String
    let subtitle: String
    let symbol: String
    let selected: Bool
    let action: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .font(.system(size: 18, weight: .semibold))
                    .symbolEffect(.bounce, value: selected)
                    .frame(width: 30)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).font(.system(size: 13.5, weight: .bold))
                    Text(subtitle).font(.system(size: 11)).foregroundStyle(selected ? .white.opacity(0.8) : Theme.text3)
                }
                Spacer(minLength: 0)
            }
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(selected ? AnyShapeStyle(Theme.brand.gradient.opacity(0.8)) : AnyShapeStyle(Color.white.opacity(hover ? 0.08 : 0.04))))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.white.opacity(selected ? 0.35 : 0.08)))
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .onHover { h in withAnimation(Theme.snappy) { hover = h } }
    }
}

// MARK: - Aplicații

private struct AppsCard: View {
    @Environment(Library.self) private var library
    let folder: DockFolder
    @State private var dropTargeted = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("APLICAȚII ÎN FOLDER").sectionLabel()
                Spacer()
                PillButton(title: "Adaugă aplicații", symbol: "plus", palette: Palette(a: Color(hexString: folder.icon.colorA), b: Color(hexString: folder.icon.colorB))) {
                    library.showPicker = true
                }
            }
            if folder.apps.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "arrow.down.app").font(.system(size: 28, weight: .light)).foregroundStyle(Theme.text2)
                    Text("Trage aplicații aici din Finder sau apasă „Adaugă aplicații”")
                        .font(.system(size: 12.5, weight: .medium)).foregroundStyle(Theme.text2)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 34)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
                    .foregroundStyle(dropTargeted ? Color(hexString: folder.icon.colorA) : Theme.text3))
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 10)], spacing: 12) {
                    ForEach(Array(folder.apps.enumerated()), id: \.element.id) { i, app in
                        AppTile(app: app, index: i, count: folder.apps.count, folderID: folder.id)
                            .transition(.scale(scale: 0.6).combined(with: .opacity))
                    }
                }
                .animation(.spring(response: 0.45, dampingFraction: 0.75), value: folder.apps)
            }
        }
        .padding(20)
        .glass(22, highlight: dropTargeted, tint: dropTargeted ? Color(hexString: folder.icon.colorA) : nil)
        .dropDestination(for: URL.self) { urls, _ in
            let apps = urls.filter { $0.pathExtension == "app" }.map { AppRef(path: $0.path, name: $0.deletingPathExtension().lastPathComponent) }
            guard !apps.isEmpty else { return false }
            library.addApps(apps, to: folder.id)
            return true
        } isTargeted: { t in withAnimation(Theme.snappy) { dropTargeted = t } }
    }
}

private struct AppTile: View {
    @Environment(Library.self) private var library
    let app: AppRef
    let index: Int
    let count: Int
    let folderID: UUID
    @State private var hover = false

    var body: some View {
        VStack(spacing: 6) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: app.path))
                .resizable().interpolation(.high)
                .frame(width: 56, height: 56)
                .scaleEffect(hover ? 1.08 : 1)
                .opacity(app.exists ? 1 : 0.35)
            Text(app.name).font(.system(size: 11, weight: .medium)).lineLimit(1).frame(width: 88)
        }
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.white.opacity(hover ? 0.08 : 0.03)))
        .overlay(alignment: .topTrailing) {
            if hover {
                Button {
                    library.update(folderID) { f in f.apps.removeAll { $0.path == app.path } }
                } label: {
                    Image(systemName: "xmark").font(.system(size: 9, weight: .black))
                        .frame(width: 20, height: 20)
                        .background(Circle().fill(Theme.danger.gradient))
                }
                .buttonStyle(PressableStyle(scale: 0.85))
                .offset(x: 5, y: -5)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .overlay(alignment: .bottom) {
            if hover && count > 1 {
                HStack(spacing: 2) {
                    if index > 0 { arrow("chevron.left", -1) }
                    Spacer()
                    if index < count - 1 { arrow("chevron.right", 1) }
                }
                .padding(4)
                .transition(.opacity)
            }
        }
        .onHover { h in withAnimation(Theme.snappy) { hover = h } }
        .help(app.exists ? app.path : "\(app.name) nu mai este instalată")
    }

    private func arrow(_ symbol: String, _ delta: Int) -> some View {
        Button {
            library.update(folderID) { f in
                let j = index + delta
                guard f.apps.indices.contains(j) else { return }
                f.apps.swapAt(index, j)
            }
        } label: {
            Image(systemName: symbol).font(.system(size: 9, weight: .bold))
                .frame(width: 18, height: 18)
                .background(Circle().fill(Color.white.opacity(0.15)))
        }
        .buttonStyle(PressableStyle(scale: 0.85))
        .help(delta < 0 ? "Mută la stânga" : "Mută la dreapta")
    }
}

// MARK: - Poziția în Dock

private struct DockPositionCard: View {
    @Environment(Library.self) private var library
    let folder: DockFolder

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("POZIȚIA ÎN DOCK").sectionLabel()
                Spacer()
                HStack(spacing: 8) {
                    PillButton(title: "Stânga", symbol: "chevron.left") { library.move(folder.id, by: -1) }
                    PillButton(title: "Dreapta", symbol: "chevron.right") { library.move(folder.id, by: 1) }
                }
                .disabled(!library.state.enabled)
                .opacity(library.state.enabled ? 1 : 0.4)
            }

            ScrollViewReader { proxy in
                ScrollView(.horizontal) {
                    HStack(alignment: .bottom, spacing: 8) {
                        ForEach(library.dockTiles) { t in
                            DockTileView(tile: t, isCurrent: t.folderID == folder.id)
                                .id(t.folderID?.uuidString ?? "\(t.id)")
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, 22)
                    .padding(.bottom, 12)
                    .animation(.spring(response: 0.45, dampingFraction: 0.78), value: library.dockTiles.map { $0.folderID?.uuidString ?? $0.path ?? "" })
                }
                .scrollIndicators(.never)
                .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(.ultraThinMaterial))
                .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Theme.stroke))
                .onAppear { proxy.scrollTo(folder.id.uuidString, anchor: .center) }
                .onChange(of: library.dockTiles.map(\.id)) { _, _ in
                    withAnimation { proxy.scrollTo(folder.id.uuidString, anchor: .center) }
                }
            }

            HStack(spacing: 8) {
                Image(systemName: "hand.draw.fill").foregroundStyle(Color(hexString: folder.icon.colorA))
                Text("Poți trage folderul și direct în Dock — Dockyard ține minte poziția și îl pune la loc data viitoare.")
                    .font(.system(size: 11.5)).foregroundStyle(Theme.text2)
            }
        }
        .padding(20)
        .glass(22)
    }
}

private struct DockTileView: View {
    @Environment(Library.self) private var library
    let tile: DockController.Tile
    let isCurrent: Bool
    @State private var bounce = false

    var body: some View {
        VStack(spacing: 5) {
            Group {
                if let id = tile.folderID, let f = library.folders.first(where: { $0.id == id }) {
                    Image(nsImage: library.icon(f, size: 46)).resizable()
                } else if let p = tile.path {
                    Image(nsImage: NSWorkspace.shared.icon(forFile: p)).resizable()
                } else {
                    RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.1))
                }
            }
            .frame(width: 46, height: 46)
            .scaleEffect(isCurrent ? 1.18 : 1, anchor: .bottom)
            .offset(y: isCurrent && bounce ? -6 : 0)
            .shadow(color: isCurrent ? .white.opacity(0.35) : .clear, radius: 10)
            Circle().fill(isCurrent ? Color.white : Color.clear).frame(width: 4, height: 4)
        }
        .opacity(tile.folderID == nil ? 0.75 : 1)
        .help(tile.label)
        .onAppear { if isCurrent { withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) { bounce = true } } }
    }
}
