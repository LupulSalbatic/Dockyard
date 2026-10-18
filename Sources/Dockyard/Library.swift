import AppKit
import DockyardCore
import Observation
import SwiftUI

@MainActor @Observable
final class Library {
    var state: LibraryState
    var selectedID: UUID?
    var dockTiles: [DockController.Tile] = []
    var toast: Toast?
    var showPicker = false
    var iconVersion = 0
    /// Folderul redenumit direct în sidebar.
    var renamingID: UUID?
    /// Cere editorului să pună cursorul în titlu (redenumire).
    var focusTitleID: UUID?
    /// Folderul pentru care se cere confirmarea ștergerii.
    var confirmDeleteID: UUID?
    /// Dockyard rulează în fundal: fără iconiță în Dock, cu iconiță în bara de meniu.
    var inBackground = false
    /// Acțiunea SwiftUI care (re)deschide fereastra principală.
    @ObservationIgnored var openMainWindow: (() -> Void)?

    let dataDir: URL
    /// DOCKYARD_DRY_RUN=1: interfața funcționează, dar Dock-ul nu este modificat.
    let dryRun = ProcessInfo.processInfo.environment["DOCKYARD_DRY_RUN"] == "1"

    @ObservationIgnored private var pollTimer: Timer?
    @ObservationIgnored private var applyTask: Task<Void, Never>?
    @ObservationIgnored private var toastTask: Task<Void, Never>?
    @ObservationIgnored private var iconCache: [String: NSImage] = [:]
    @ObservationIgnored private var started = false
    /// false cât timp Dockyard nu rulează dintr-un loc potrivit (vezi AppLocation).
    @ObservationIgnored private var active = false
    @ObservationIgnored private var applyPending = false
    /// O iconiță s-a schimbat: la următoarea aplicare Dock-ul trebuie repornit ca s-o recitească.
    @ObservationIgnored private var iconsDirty = false
    /// O aplicare în așteptare trebuie să pornească și folderele (nu se pierde dacă vine alta peste ea).
    @ObservationIgnored private var launchPending = false

    init() {
        dataDir = Paths.dataDir(nextTo: Bundle.main.bundleURL)
        state = StateIO.load(dataDir)
        selectedID = state.folders.first?.id
    }

    var folders: [DockFolder] { state.folders }
    var selected: DockFolder? { state.folders.first { $0.id == selectedID } }

    // MARK: Pornire / oprire

    func start() {
        guard !started else { return }
        started = true
        guard AppLocation.check(dataDir: dataDir) else { return }
        active = true
        try? FileManager.default.createDirectory(at: Paths.tilesDir(dataDir), withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: Paths.iconsDir(dataDir), withIntermediateDirectories: true)
        removeOrphanTiles()
        for f in folders { buildTile(f) }
        if state.enabled { publishToDock(launch: true) }
        refreshDockTiles()

        // hook pentru teste: DOCKYARD_TEST=delete|rename|title
        if let t = ProcessInfo.processInfo.environment["DOCKYARD_TEST"], let id = folders.first?.id {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                switch t {
                case "delete": self?.requestDelete(id)
                case "rename": self?.renamingID = id
                case "title": self?.focusTitleID = id
                case "background": self?.enterBackground()
                default: break
                }
            }
        }
        pollTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.syncFromDock() }
        }
        DistributedNotificationCenter.default().addObserver(forName: Signal.edit, object: nil, queue: .main) { [weak self] n in
            // obiectul e „<id>” sau „<id>:rename” / „<id>:delete” (din meniul folderului din Dock)
            guard let s = n.object as? String else { return }
            let parts = s.split(separator: ":").map(String.init)
            guard let id = UUID(uuidString: parts[0]) else { return }
            let action = parts.count > 1 ? parts[1] : ""
            Task { @MainActor in
                guard let self else { return }
                self.selectedID = id
                self.bringToFront()
                try? await Task.sleep(for: .milliseconds(350))
                if action == "rename" { self.focusTitleID = id }
                if action == "delete" { self.requestDelete(id) }
            }
        }
    }

    /// Apelat la închiderea aplicației: salvează pozițiile și scoate folderele din Dock.
    func shutdown() {
        guard active else { return }
        pollTimer?.invalidate()
        captureDockPositions()
        StateIO.save(state, dataDir)
        if !dryRun { DockController.removeAll(dataDir: dataDir) }
        Signal.post(Signal.quit)
        for f in folders { terminateHelper(f) }
        for f in folders { LeaveNoTrace.clean(bundleID: f.bundleIdentifier) }
    }

    // MARK: Dock

    private var helperBinary: URL {
        let inBundle = Bundle.main.bundleURL.appendingPathComponent("Contents/Helpers/DockyardFolder")
        if FileManager.default.fileExists(atPath: inBundle.path) { return inBundle }
        return Bundle.main.executableURL!.deletingLastPathComponent().appendingPathComponent("DockyardFolder")
    }

    @discardableResult
    private func buildTile(_ f: DockFolder) -> Bool {
        TileFactory.build(f, dataDir: dataDir, helperBinary: helperBinary, mainApp: Bundle.main.bundleURL)
    }

    private func publishToDock(launch: Bool) {
        if !dryRun {
            let reload = iconsDirty
            iconsDirty = false
            let restarted = DockController.apply(state.enabled ? folders : [], dataDir: dataDir, reloadIcons: reload)
            if restarted { showToast("dock.rectangle", "Dock actualizat") }
        }
        if launch && state.enabled {
            // lăsăm Dock-ul să repornească înainte de a porni folderele
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { [weak self] in self?.launchHelpers() }
        }
        refreshDockTiles()
    }

    private func scheduleDockApply(launch: Bool = false, delay: Duration = .milliseconds(700)) {
        applyTask?.cancel()
        applyPending = true
        launchPending = launchPending || launch
        applyTask = Task {
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            let launch = launchPending
            launchPending = false
            publishToDock(launch: launch)
            applyPending = false
        }
    }

    private func launchHelpers() {
        guard state.enabled else { return }
        for f in folders where !isRunning(f) {
            let cfg = NSWorkspace.OpenConfiguration()
            cfg.activates = false
            cfg.addsToRecentItems = false
            // hook pentru teste: DOCKYARD_SHOW_PANEL=1 deschide panoul primului folder
            if ProcessInfo.processInfo.environment["DOCKYARD_SHOW_PANEL"] == "1", f.id == folders.first?.id {
                cfg.environment = ["DOCKYARD_SHOW_PANEL": "1"]
            }
            NSWorkspace.shared.openApplication(at: TileFactory.bundleURL(f, dataDir), configuration: cfg)
        }
    }

    func isRunning(_ f: DockFolder) -> Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: f.bundleIdentifier).isEmpty
    }

    private func terminateHelper(_ f: DockFolder) {
        NSRunningApplication.runningApplications(withBundleIdentifier: f.bundleIdentifier).forEach { $0.terminate() }
    }

    private func removeOrphanTiles() {
        let dir = Paths.tilesDir(dataDir)
        let known = Set(folders.map { "\($0.shortID).app" })
        for item in (try? FileManager.default.contentsOfDirectory(atPath: dir.path)) ?? [] where !known.contains(item) {
            try? FileManager.default.removeItem(at: dir.appendingPathComponent(item))
        }
    }

    func refreshDockTiles() {
        dockTiles = DockController.tiles(dataDir: dataDir)
    }

    private func captureDockPositions() {
        let idx = DockController.indices(dataDir: dataDir)
        for i in state.folders.indices {
            if let p = idx[state.folders[i].id] { state.folders[i].dockIndex = p }
        }
    }

    /// Dacă utilizatorul a tras un folder în altă poziție direct în Dock, o memorăm.
    private func syncFromDock() {
        // cât timp o mutare din aplicație așteaptă să fie aplicată, Dock-ul real e încă în urmă
        guard !applyPending, state.enabled else { return }
        let before = state.folders.map(\.dockIndex)
        captureDockPositions()
        if state.folders.map(\.dockIndex) != before { StateIO.save(state, dataDir) }
        refreshDockTiles()
    }

    func dockPosition(of f: DockFolder) -> Int? {
        dockTiles.first { $0.folderID == f.id }?.id
    }

    func move(_ id: UUID, by delta: Int) {
        guard let i = index(of: id) else { return }
        let current = dockPosition(of: state.folders[i]) ?? state.folders[i].dockIndex ?? dockTiles.count
        let others = dockTiles.filter { $0.folderID != id }.count
        let next = min(max(current + delta, 0), others)
        guard next != current else { return }
        state.folders[i].dockIndex = next
        // previzualizarea se mută imediat; Dock-ul real după o scurtă pauză
        var preview = dockTiles.filter { $0.folderID != id }
        let mine = DockController.Tile(id: 0, path: nil, label: state.folders[i].name, folderID: id)
        preview.insert(mine, at: min(next, preview.count))
        dockTiles = preview.enumerated().map { DockController.Tile(id: $0.offset, path: $0.element.path, label: $0.element.label, folderID: $0.element.folderID) }
        StateIO.save(state, dataDir)
        scheduleDockApply()
    }

    func setEnabled(_ on: Bool) {
        if !on { captureDockPositions() }
        state.enabled = on
        StateIO.save(state, dataDir)
        if on {
            publishToDock(launch: true)
        } else {
            if !dryRun { DockController.removeAll(dataDir: dataDir) }
            for f in folders { terminateHelper(f) }
            refreshDockTiles()
        }
    }

    // MARK: Editare foldere

    func index(of id: UUID) -> Int? { state.folders.firstIndex { $0.id == id } }

    func addFolder() {
        var f = DockFolder(name: "Folder \(folders.count + 1)")
        let palettes: [(String, String)] = [("8B5CF6", "EC4899"), ("22D3EE", "6366F1"), ("F59E0B", "F43F5E"), ("34D399", "0EA5E9"), ("A3E635", "14B8A6")]
        let p = palettes[folders.count % palettes.count]
        f.icon.colorA = p.0
        f.icon.colorB = p.1
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            state.folders.append(f)
            selectedID = f.id
        }
        StateIO.save(state, dataDir)
        buildTile(f)
        if state.enabled { scheduleDockApply(launch: true) }
    }

    func requestDelete(_ id: UUID) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { confirmDeleteID = id }
    }

    func deleteFolder(_ id: UUID) {
        confirmDeleteID = nil
        guard let i = index(of: id) else { return }
        let f = state.folders[i]
        terminateHelper(f)
        withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
            state.folders.remove(at: i)
            if selectedID == id { selectedID = state.folders.first?.id }
        }
        StateIO.save(state, dataDir)
        if !dryRun { DockController.apply(state.enabled ? folders : [], dataDir: dataDir) }
        TileFactory.remove(f, dataDir)
        if let file = f.icon.imageFile { try? FileManager.default.removeItem(at: Paths.iconsDir(dataDir).appendingPathComponent(file)) }
        LeaveNoTrace.clean(bundleID: f.bundleIdentifier)
        refreshDockTiles()
        showToast("trash", "„\(f.name)” a fost șters")
    }

    /// Schimbări de conținut sau iconiță. Panoul se actualizează live; dacă s-a schimbat iconița,
    /// Dock-ul repornește după o scurtă pauză ca s-o recitească din bundle.
    func update(_ id: UUID, _ change: (inout DockFolder) -> Void) {
        guard let i = index(of: id) else { return }
        change(&state.folders[i])
        iconVersion += 1
        StateIO.save(state, dataDir)
        if buildTile(state.folders[i]) && state.enabled {
            iconsDirty = true
            // pauză mai lungă: cât timp utilizatorul încearcă iconițe, Dock-ul nu repornește
            scheduleDockApply(delay: .milliseconds(1500))
        }
        Signal.post(Signal.changed)
    }

    /// Redenumirea necesită repornirea folderului și a Dock-ului (eticheta e citită de Dock).
    func rename(_ id: UUID, to name: String) {
        let clean = name.trimmingCharacters(in: .whitespaces)
        guard let i = index(of: id), !clean.isEmpty, state.folders[i].name != clean else { return }
        state.folders[i].name = clean
        StateIO.save(state, dataDir)
        let f = state.folders[i]
        terminateHelper(f)
        buildTile(f)
        if state.enabled { scheduleDockApply(launch: true) }
    }

    func addApps(_ apps: [AppRef], to id: UUID) {
        update(id) { f in
            for a in apps where !f.apps.contains(where: { $0.path == a.path }) { f.apps.append(a) }
        }
    }

    func setImage(from url: URL, for id: UUID) {
        guard let img = NSImage(contentsOf: url), let i = index(of: id) else {
            showToast("exclamationmark.triangle.fill", "Imaginea nu a putut fi citită")
            return
        }
        // salvăm o copie pătrată de 1024 px în folderul de date
        let side = 1024
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: side, pixelsHigh: side, bitsPerSample: 8, samplesPerPixel: 4,
                                   hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        let s = img.size
        let ratio = max(CGFloat(side) / max(s.width, 1), CGFloat(side) / max(s.height, 1))
        let w = s.width * ratio, h = s.height * ratio
        img.draw(in: CGRect(x: (CGFloat(side) - w) / 2, y: (CGFloat(side) - h) / 2, width: w, height: h))
        NSGraphicsContext.restoreGraphicsState()
        guard let png = rep.representation(using: .png, properties: [:]) else { return }
        let name = "\(state.folders[i].shortID)-\(Int(Date().timeIntervalSince1970)).png"
        let dest = Paths.iconsDir(dataDir).appendingPathComponent(name)
        try? png.write(to: dest)
        let old = state.folders[i].icon.imageFile
        update(id) { f in
            f.icon.imageFile = name
            f.icon.style = .image
        }
        if let old { try? FileManager.default.removeItem(at: Paths.iconsDir(dataDir).appendingPathComponent(old)) }
    }

    func showPanel(_ id: UUID) {
        Signal.post(Signal.show, id.uuidString)
    }

    // MARK: Iconițe (cu cache)

    func icon(_ f: DockFolder, size: CGFloat) -> NSImage {
        var h = Hasher()
        h.combine(f.icon)
        h.combine(f.apps)
        let key = "\(f.id)-\(h.finalize())-\(Int(size))"
        if let img = iconCache[key] { return img }
        let img = IconRenderer.image(for: f, dataDir: dataDir, size: size * 2)
        img.size = NSSize(width: size, height: size)
        if iconCache.count > 200 { iconCache.removeAll() }
        iconCache[key] = img
        return img
    }

    // MARK: Fundal / prim-plan

    /// Ascunde Dockyard din Dock; aplicația și folderele continuă să funcționeze.
    func enterBackground() {
        guard !inBackground else { return }
        inBackground = true
        for w in NSApp.windows where w.isVisible && w.canBecomeMain { w.orderOut(nil) }
        NSApp.setActivationPolicy(.accessory)
    }

    /// Readuce Dockyard în Dock și îi deschide fereastra.
    func bringToFront() {
        inBackground = false
        NSApp.setActivationPolicy(.regular)
        if let w = NSApp.windows.first(where: { $0.canBecomeMain && $0.identifier?.rawValue.contains("main") == true }) {
            w.makeKeyAndOrderFront(nil)
        } else {
            openMainWindow?()
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    func quitCompletely() {
        NSApp.terminate(nil)
    }

    // MARK: Toast

    func showToast(_ symbol: String, _ text: String) {
        toastTask?.cancel()
        withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) { toast = Toast(symbol: symbol, text: text) }
        toastTask = Task {
            try? await Task.sleep(for: .seconds(2.4))
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.3)) { toast = nil }
        }
    }
}

struct Toast: Identifiable, Equatable {
    let id = UUID()
    let symbol: String
    let text: String
}

extension Notification.Name {
    static let showMainWindow = Notification.Name("dockyard.showMainWindow")
}
