import AppKit
import DockyardCore
import SwiftUI
import UniformTypeIdentifiers

struct AppPicker: View {
    @Environment(Library.self) private var library
    let folderID: UUID
    @State private var all: [AppRef] = []
    @State private var query = ""
    @State private var picked: Set<String> = []
    @State private var loading = true
    @FocusState private var searchFocused: Bool

    private var folder: DockFolder? { library.folders.first { $0.id == folderID } }
    private var existing: Set<String> { Set(folder?.apps.map(\.path) ?? []) }
    private var shown: [AppRef] {
        let q = query.trimmingCharacters(in: .whitespaces)
        return q.isEmpty ? all : all.filter { $0.name.localizedCaseInsensitiveContains(q) || $0.path.localizedCaseInsensitiveContains(q) }
    }
    private var palette: Palette {
        Palette(a: Color(hexString: folder?.icon.colorA ?? "22D3EE"), b: Color(hexString: folder?.icon.colorB ?? "8B5CF6"))
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea().onTapGesture { close() }

            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Adaugă aplicații").font(.system(size: 21, weight: .bold, design: .rounded))
                        Text("în „\(folder?.name ?? "")” · \(picked.count) selectate").font(.system(size: 12)).foregroundStyle(Theme.text2)
                            .contentTransition(.numericText())
                    }
                    Spacer()
                    IconButton(symbol: "xmark", help: "Închide (Esc)") { close() }
                }
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass").foregroundStyle(Theme.text3)
                    TextField("Caută aplicații…", text: $query).textFieldStyle(.plain).font(.system(size: 14)).focused($searchFocused)
                }
                .padding(.horizontal, 14).frame(height: 40)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.white.opacity(0.07)))

                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 8)], spacing: 8) {
                        ForEach(shown) { app in
                            PickCell(app: app, inFolder: existing.contains(app.path), picked: picked.contains(app.path), palette: palette) {
                                guard !existing.contains(app.path) else { return }
                                withAnimation(Theme.snappy) {
                                    if picked.contains(app.path) { picked.remove(app.path) } else { picked.insert(app.path) }
                                }
                            }
                        }
                    }
                    .padding(2)
                }
                .scrollIndicators(.never)

                HStack {
                    Text(loading ? "Caut aplicații…" : "\(all.count) aplicații găsite pe Mac").font(.system(size: 11.5)).foregroundStyle(Theme.text3)
                    Spacer()
                    PillButton(title: "Alege din Finder…", symbol: "folder") { chooseInFinder() }
                    PillButton(title: picked.isEmpty ? "Gata" : "Adaugă \(picked.count)", symbol: picked.isEmpty ? "checkmark" : "plus", palette: palette) {
                        let apps = all.filter { picked.contains($0.path) }
                        if !apps.isEmpty { library.addApps(apps, to: folderID) }
                        close()
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding(24)
            .frame(width: 720, height: 560)
            .glass(28, highlight: true)
            .background(RoundedRectangle(cornerRadius: 28, style: .continuous).fill(Color(hex: 0x0D0D16).opacity(0.75)))
            .shadow(color: .black.opacity(0.6), radius: 40, y: 20)
        }
        .task {
            searchFocused = true
            all = await Task.detached(priority: .userInitiated) { AppCatalog.installed() }.value
            loading = false
        }
        .onExitCommand { close() }
    }

    /// Pentru aplicații aflate oriunde pe disc.
    private func chooseInFinder() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.applicationBundle]
        panel.allowsMultipleSelection = true
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.prompt = "Adaugă în folder"
        guard panel.runModal() == .OK else { return }
        let apps = panel.urls.map { AppRef(path: $0.path, name: $0.deletingPathExtension().lastPathComponent) }
        library.addApps(apps, to: folderID)
        library.showToast("checkmark.circle.fill", apps.count == 1 ? "„\(apps[0].name)” adăugată" : "\(apps.count) aplicații adăugate")
        close()
    }

    private func close() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { library.showPicker = false }
    }
}

private struct PickCell: View {
    let app: AppRef
    let inFolder: Bool
    let picked: Bool
    let palette: Palette
    let action: () -> Void
    @State private var hover = false

    var body: some View {
        VStack(spacing: 6) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: app.path))
                .resizable().interpolation(.high)
                .frame(width: 50, height: 50)
                .scaleEffect(hover && !inFolder ? 1.08 : 1)
            Text(app.name).font(.system(size: 10.5, weight: .medium)).lineLimit(1).frame(width: 84)
            if let loc = AppCatalog.location(of: app.path) {
                Text(loc).font(.system(size: 9)).foregroundStyle(Theme.text3).lineLimit(1).truncationMode(.head).frame(width: 84)
            }
        }
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(picked ? AnyShapeStyle(palette.gradient.opacity(0.55)) : AnyShapeStyle(Color.white.opacity(hover ? 0.07 : 0.025))))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.white.opacity(picked ? 0.45 : 0.05)))
        .overlay(alignment: .topTrailing) {
            if picked || inFolder {
                Image(systemName: inFolder ? "checkmark.circle" : "checkmark.circle.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white.opacity(inFolder ? 0.5 : 1))
                    .padding(6)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .opacity(inFolder ? 0.45 : 1)
        .contentShape(Rectangle())
        .onTapGesture(perform: action)
        .onHover { h in withAnimation(Theme.snappy) { hover = h } }
        .help(inFolder ? "Deja în folder" : app.path)
    }
}
