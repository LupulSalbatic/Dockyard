import AppKit
import DockyardCore
import SwiftUI

struct ContentView: View {
    @Environment(Library.self) private var library
    @Environment(\.openWindow) private var openWindow

    private var palette: Palette {
        guard let f = library.selected else { return Theme.brand }
        return Palette(a: Color(hexString: f.icon.colorA), b: Color(hexString: f.icon.colorB))
    }

    var body: some View {
        ZStack {
            AuroraBackground(palette: palette)
            HStack(spacing: 0) {
                Sidebar().frame(width: 280)
                ZStack {
                    if let f = library.selected {
                        FolderEditor(folderID: f.id)
                            .id(f.id)
                            .transition(.asymmetric(insertion: .opacity.combined(with: .offset(y: 20)), removal: .opacity))
                    } else {
                        EmptyState()
                            .transition(.opacity.combined(with: .scale(scale: 0.96)))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .animation(.spring(response: 0.5, dampingFraction: 0.85), value: library.selectedID)
            }
            .blur(radius: library.showPicker || library.confirmDeleteID != nil ? 10 : 0)
            .allowsHitTesting(!library.showPicker && library.confirmDeleteID == nil)

            if let id = library.confirmDeleteID, let f = library.folders.first(where: { $0.id == id }) {
                DeleteConfirm(folder: f)
                    .transition(.opacity.combined(with: .scale(scale: 0.92)))
                    .zIndex(6)
            }

            if library.showPicker, let id = library.selectedID {
                AppPicker(folderID: id)
                    .transition(.opacity.combined(with: .scale(scale: 0.94)))
                    .zIndex(5)
            }

            VStack {
                if let t = library.toast {
                    HStack(spacing: 9) {
                        Image(systemName: t.symbol).font(.system(size: 13, weight: .bold)).symbolEffect(.bounce, value: t.id)
                        Text(t.text).font(.system(size: 13, weight: .semibold))
                    }
                    .padding(.horizontal, 16)
                    .frame(height: 38)
                    .background(Capsule().fill(.regularMaterial))
                    .overlay(Capsule().strokeBorder(Color.white.opacity(0.15)))
                    .shadow(color: .black.opacity(0.35), radius: 18, y: 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .id(t.id)
                }
                Spacer()
            }
            .padding(.top, 14)
            .allowsHitTesting(false)
            .zIndex(10)
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.85), value: library.showPicker)
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: library.confirmDeleteID)
        .frame(minWidth: 980, minHeight: 680)
        .preferredColorScheme(.dark)
        .ignoresSafeArea()
        .background(NoFrameAutosave())
        .onAppear {
            // păstrăm acțiunea ca fereastra să poată fi redeschisă din fundal
            library.openMainWindow = { [openWindow] in openWindow(id: "main") }
        }
    }
}

// MARK: - Sidebar

struct Sidebar: View {
    @Environment(Library.self) private var library
    @Namespace private var ns
    @State private var appear = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                LogoMark(size: 30)
                VStack(alignment: .leading, spacing: 0) {
                    Text("Dockyard").font(.system(size: 18, weight: .bold, design: .rounded))
                    Text("Foldere în Dock").font(.system(size: 11, weight: .medium)).foregroundStyle(Theme.text3)
                }
                Spacer()
            }
            .padding(.top, 50)
            .padding(.horizontal, 18)
            .padding(.bottom, 18)

            LiveToggle()
                .padding(.horizontal, 12)
                .padding(.bottom, 18)

            HStack {
                Text("FOLDERE").sectionLabel()
                Spacer()
                Text("\(library.folders.count)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .contentTransition(.numericText())
                    .padding(.horizontal, 7).frame(height: 18)
                    .background(Capsule().fill(Color.white.opacity(0.1)))
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 8)

            ScrollView {
                VStack(spacing: 6) {
                    ForEach(Array(library.folders.enumerated()), id: \.element.id) { i, f in
                        FolderRow(folder: f, selected: library.selectedID == f.id, ns: ns)
                            .onTapGesture { withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) { library.selectedID = f.id } }
                            .cascade(i, active: appear)
                            .transition(.asymmetric(insertion: .scale(scale: 0.6).combined(with: .opacity), removal: .scale(scale: 0.8).combined(with: .opacity)))
                    }
                }
                .padding(.horizontal, 10)
            }
            .scrollIndicators(.never)

            Spacer(minLength: 0)

            CloseOptions()
                .padding(.horizontal, 12)

            Button { library.addFolder() } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus.rectangle.on.folder.fill")
                    Text("Folder nou").font(.system(size: 13, weight: .semibold))
                    Spacer()
                    Text("⌘N").font(.system(size: 11, weight: .medium, design: .rounded)).foregroundStyle(.white.opacity(0.6))
                }
                .padding(.horizontal, 14)
                .frame(height: 42)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.brand.gradient))
                .shadow(color: Theme.brand.b.opacity(0.45), radius: 12, y: 4)
            }
            .buttonStyle(PressableStyle())
            .padding(12)
        }
        .background {
            Rectangle().fill(.ultraThinMaterial).opacity(0.7)
                .overlay(alignment: .trailing) { Rectangle().fill(Theme.stroke).frame(width: 1) }
        }
        .onAppear { appear = true }
    }
}

private struct LiveToggle: View {
    @Environment(Library.self) private var library
    @State private var pulse = false

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle().fill(library.state.enabled ? Color.green : Color.gray).frame(width: 8, height: 8)
                if library.state.enabled {
                    Circle().stroke(Color.green, lineWidth: 1.5).frame(width: 8, height: 8)
                        .scaleEffect(pulse ? 2.6 : 1).opacity(pulse ? 0 : 0.8)
                        .animation(.easeOut(duration: 1.6).repeatForever(autoreverses: false), value: pulse)
                }
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(library.state.enabled ? "Live în Dock" : "Ascunse din Dock").font(.system(size: 12.5, weight: .semibold))
                Text(library.dryRun ? "mod test · Dock-ul nu e modificat" : "dispar când închizi Dockyard")
                    .font(.system(size: 10.5)).foregroundStyle(Theme.text3)
            }
            Spacer()
            Toggle("", isOn: Binding(get: { library.state.enabled }, set: { library.setEnabled($0) }))
                .toggleStyle(.switch).labelsHidden().controlSize(.small)
        }
        .padding(12)
        .glass(14)
        .onAppear { pulse = true }
    }
}

private struct FolderRow: View {
    @Environment(Library.self) private var library
    let folder: DockFolder
    let selected: Bool
    let ns: Namespace.ID
    @State private var hover = false
    @State private var draft = ""
    @FocusState private var editing: Bool

    private var isRenaming: Bool { library.renamingID == folder.id }

    private func commit() {
        library.rename(folder.id, to: draft)
        library.renamingID = nil
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(nsImage: library.icon(folder, size: 44))
                .resizable().frame(width: 44, height: 44)
                .scaleEffect(hover ? 1.08 : 1)
                .id(library.iconVersion)
            VStack(alignment: .leading, spacing: 3) {
                if isRenaming {
                    TextField("Nume", text: $draft)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13.5, weight: .semibold))
                        .focused($editing)
                        .onSubmit(commit)
                        .onExitCommand { library.renamingID = nil }
                        .onChange(of: editing) { _, e in if !e && isRenaming { commit() } }
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.1)))
                        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color(hexString: folder.icon.colorA).opacity(0.8)))
                        .padding(.horizontal, -6)
                        .onAppear {
                            draft = folder.name
                            DispatchQueue.main.async { editing = true }
                        }
                } else {
                    Text(folder.name).font(.system(size: 13.5, weight: .semibold)).lineLimit(1)
                        .onTapGesture(count: 2) { library.renamingID = folder.id }
                }
                HStack(spacing: 4) {
                    Text("\(folder.apps.count) aplicații")
                    if let pos = library.dockPosition(of: folder) {
                        Text("·")
                        Text("#\(pos + 1) în Dock")
                    }
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Theme.text2)
            }
            Spacer(minLength: 0)
        }
        .padding(8)
        .background {
            if selected {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.09))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Color(hexString: folder.icon.colorA).opacity(0.5)))
                    .matchedGeometryEffect(id: "sel", in: ns)
            } else if hover {
                RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white.opacity(0.04))
            }
        }
        .contentShape(Rectangle())
        .onHover { h in withAnimation(Theme.snappy) { hover = h } }
        .contextMenu {
            Button("Redenumește", systemImage: "pencil") {
                library.selectedID = folder.id
                library.renamingID = folder.id
            }
            Button("Deschide panoul", systemImage: "rectangle.stack") { library.showPanel(folder.id) }
            Divider()
            Button("Șterge folderul…", systemImage: "trash", role: .destructive) { library.requestDelete(folder.id) }
        }
    }
}

// MARK: - Ascunde din Dock / Închide complet

private struct CloseOptions: View {
    @Environment(Library.self) private var library

    var body: some View {
        HStack(spacing: 8) {
            CloseButton(title: "Ascunde din Dock", detail: "rulează în fundal", symbol: "eye.slash.fill", tint: Theme.brand.a) {
                library.enterBackground()
            }
            .help("Dockyard dispare din Dock, folderele rămân. Îl redeschizi din bara de meniu (sus). ⌘W")
            CloseButton(title: "Închide complet", detail: "folderele dispar", symbol: "power", tint: Theme.danger.a) {
                library.quitCompletely()
            }
            .help("Oprește Dockyard și scoate folderele din Dock. ⌘Q")
        }
    }
}

private struct CloseButton: View {
    let title: String
    let detail: String
    let symbol: String
    let tint: Color
    let action: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: symbol)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(tint)
                    .symbolEffect(.bounce, value: hover)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).font(.system(size: 11.5, weight: .semibold)).lineLimit(1)
                    Text(detail).font(.system(size: 10)).foregroundStyle(Theme.text3).lineLimit(1)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(tint.opacity(hover ? 0.16 : 0.07)))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(tint.opacity(hover ? 0.45 : 0.15)))
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .onHover { h in withAnimation(Theme.snappy) { hover = h } }
    }
}

// MARK: - Confirmare ștergere

struct DeleteConfirm: View {
    @Environment(Library.self) private var library
    let folder: DockFolder
    @State private var shake: CGFloat = 0

    var body: some View {
        ZStack {
            Color.black.opacity(0.5).ignoresSafeArea().onTapGesture { cancel() }
            VStack(spacing: 18) {
                ZStack {
                    Image(nsImage: library.icon(folder, size: 84))
                        .resizable().frame(width: 84, height: 84)
                        .rotationEffect(.degrees(sin(Double(shake) * Double.pi * 4) * 6))
                    Image(systemName: "trash.circle.fill")
                        .font(.system(size: 30))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, Theme.danger.a)
                        .offset(x: 34, y: 30)
                }
                VStack(spacing: 6) {
                    Text("Ștergi „\(folder.name)”?").font(.system(size: 20, weight: .bold, design: .rounded))
                    Text("Folderul dispare din Dock. Aplicațiile din el (\(folder.apps.count)) NU sunt șterse de pe Mac.")
                        .font(.system(size: 12.5)).foregroundStyle(Theme.text2).multilineTextAlignment(.center)
                }
                HStack(spacing: 10) {
                    Button(action: cancel) {
                        Text("Anulează").font(.system(size: 13.5, weight: .semibold))
                            .frame(maxWidth: .infinity).frame(height: 40)
                            .background(Capsule().fill(Color.white.opacity(0.1)))
                    }
                    .buttonStyle(PressableStyle())
                    .keyboardShortcut(.cancelAction)
                    Button { library.deleteFolder(folder.id) } label: {
                        Label("Șterge", systemImage: "trash.fill").font(.system(size: 13.5, weight: .semibold))
                            .frame(maxWidth: .infinity).frame(height: 40)
                            .background(Capsule().fill(Theme.danger.gradient))
                            .shadow(color: Theme.danger.a.opacity(0.5), radius: 12, y: 4)
                    }
                    .buttonStyle(PressableStyle())
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding(26)
            .frame(width: 400)
            .glass(26, highlight: true, tint: Theme.danger.a)
            .background(RoundedRectangle(cornerRadius: 26, style: .continuous).fill(Color(hex: 0x0D0D16).opacity(0.8)))
            .shadow(color: .black.opacity(0.6), radius: 40, y: 20)
        }
        .onAppear { withAnimation(.linear(duration: 0.5)) { shake = 1 } }
    }

    private func cancel() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { library.confirmDeleteID = nil }
    }
}

// MARK: - Stare goală

struct EmptyState: View {
    @Environment(Library.self) private var library
    @State private var bob = false

    var body: some View {
        VStack(spacing: 26) {
            // un mic Dock ilustrat
            HStack(alignment: .bottom, spacing: 12) {
                ForEach(0..<5, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(i == 2 ? AnyShapeStyle(Theme.brand.gradient) : AnyShapeStyle(Color.white.opacity(0.08)))
                        .overlay {
                            if i == 2 {
                                Image(systemName: "square.grid.2x2.fill").font(.system(size: 24, weight: .semibold)).foregroundStyle(.white)
                            }
                        }
                        .frame(width: 60, height: 60)
                        .offset(y: i == 2 && bob ? -14 : 0)
                        .shadow(color: i == 2 ? Theme.brand.b.opacity(0.6) : .clear, radius: 16)
                        .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: bob)
                }
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(.ultraThinMaterial))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(Theme.stroke))

            VStack(spacing: 10) {
                Text("Primul tău folder în Dock").font(.system(size: 30, weight: .bold, design: .rounded))
                Text("Grupează aplicații într-un singur loc din Dock, cu iconița pe care o vrei.\nFolderele trăiesc cât timp Dockyard e deschis.")
                    .font(.system(size: 14)).multilineTextAlignment(.center).foregroundStyle(Theme.text2).lineSpacing(4)
            }
            PillButton(title: "Creează un folder", symbol: "plus", palette: Theme.brand) { library.addFolder() }
        }
        .onAppear { bob = true }
    }
}
