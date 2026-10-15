import AppKit
import DockyardCore
import SwiftUI

/// Mini-aplicația unui folder din Dock. Rulează cât timp Dockyard rulează.
final class FolderAppDelegate: NSObject, NSApplicationDelegate {
    let folderID: UUID
    let dataDir: URL
    let mainApp: URL
    var folder: DockFolder?
    var panel: FolderPanelController?
    private var quitRequested = false

    override init() {
        let info = Bundle.main.infoDictionary ?? [:]
        folderID = UUID(uuidString: info["DYFolderID"] as? String ?? "") ?? UUID()
        dataDir = URL(fileURLWithPath: info["DYDataDir"] as? String ?? Bundle.main.bundleURL.deletingLastPathComponent().deletingLastPathComponent().path)
        mainApp = URL(fileURLWithPath: info["DYMainApp"] as? String ?? "")
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Dacă Dockyard nu rulează (ex. tile rămas după o oprire forțată), pornim Dockyard și ieșim.
        if !mainIsRunning {
            if FileManager.default.fileExists(atPath: mainApp.path) {
                let cfg = NSWorkspace.OpenConfiguration()
                cfg.addsToRecentItems = false
                NSWorkspace.shared.openApplication(at: mainApp, configuration: cfg) { _, _ in
                    DispatchQueue.main.async { NSApp.terminate(nil) }
                }
            } else {
                NSApp.terminate(nil)
            }
            return
        }

        reload()
        panel = FolderPanelController(owner: self)
        if ProcessInfo.processInfo.environment["DOCKYARD_SHOW_PANEL"] == "1", let screen = NSScreen.main {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                self?.panel?.pinned = true
                self?.panel?.show(at: NSPoint(x: screen.frame.midX, y: screen.frame.minY + 30))
            }
        }

        let dnc = DistributedNotificationCenter.default()
        dnc.addObserver(forName: Signal.changed, object: nil, queue: .main) { [weak self] _ in self?.reload() }
        dnc.addObserver(forName: Signal.quit, object: nil, queue: .main) { [weak self] _ in
            self?.quitRequested = true
            NSApp.terminate(nil)
        }
        dnc.addObserver(forName: Signal.show, object: folderID.uuidString, queue: .main) { [weak self] _ in
            self?.panel?.toggle(at: NSEvent.mouseLocation, force: true)
        }
        // Dacă Dockyard se oprește brusc, curățăm Dock-ul și ieșim.
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main) { [weak self] n in
            guard let self, let app = n.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  app.bundleIdentifier == Paths.mainBundleID else { return }
            if !self.quitRequested { self.emergencyCleanup() }
            NSApp.terminate(nil)
        }
    }

    var mainIsRunning: Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: Paths.mainBundleID).isEmpty
    }

    func reload() {
        let state = StateIO.load(dataDir)
        folder = state.folders.first { $0.id == folderID }
        guard let folder else {
            NSApp.terminate(nil)
            return
        }
        NSApp.applicationIconImage = IconRenderer.image(for: folder, dataDir: dataDir, size: 512)
        panel?.refresh()
    }

    /// Click pe iconița din Dock.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        panel?.toggle(at: NSEvent.mouseLocation)
        return false
    }

    func applicationDidResignActive(_ notification: Notification) {
        panel?.hide()
    }

    /// Click-dreapta pe iconița din Dock: meniu rapid cu aplicațiile.
    func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
        let menu = NSMenu()
        for app in folder?.apps ?? [] {
            let item = NSMenuItem(title: app.name, action: #selector(openFromMenu(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = app.path
            let icon = NSWorkspace.shared.icon(forFile: app.path)
            icon.size = NSSize(width: 16, height: 16)
            item.image = icon
            item.isEnabled = app.exists
            menu.addItem(item)
        }
        if !(folder?.apps.isEmpty ?? true) { menu.addItem(.separator()) }
        let edit = NSMenuItem(title: "Editează în Dockyard…", action: #selector(editInMain), keyEquivalent: "")
        edit.target = self
        menu.addItem(edit)
        let rename = NSMenuItem(title: "Redenumește…", action: #selector(renameInMain), keyEquivalent: "")
        rename.target = self
        menu.addItem(rename)
        let delete = NSMenuItem(title: "Șterge folderul…", action: #selector(deleteInMain), keyEquivalent: "")
        delete.target = self
        menu.addItem(delete)
        return menu
    }

    @objc func openFromMenu(_ sender: NSMenuItem) {
        guard let path = sender.representedObject as? String else { return }
        open(path)
    }

    @objc func renameInMain() { openMain(action: "rename") }
    @objc func deleteInMain() { openMain(action: "delete") }
    @objc func editInMain() { openMain(action: nil) }

    func openMain(action: String?) {
        panel?.hide()
        Signal.post(Signal.edit, folderID.uuidString + (action.map { ":\($0)" } ?? ""))
        // deschiderea unei aplicații deja pornite îi trimite „reopen” → Dockyard își arată fereastra
        let cfg = NSWorkspace.OpenConfiguration()
        cfg.addsToRecentItems = false
        NSWorkspace.shared.openApplication(at: mainApp, configuration: cfg)
    }

    func open(_ path: String) {
        NSWorkspace.shared.openApplication(at: URL(fileURLWithPath: path), configuration: NSWorkspace.OpenConfiguration())
        panel?.hide()
    }

    private func emergencyCleanup() {
        // Un singur folder face curățenia (blocare pe fișier în folderul de date).
        let lockPath = dataDir.appendingPathComponent(".cleanup.lock").path
        let fd = Darwin.open(lockPath, O_CREAT | O_RDWR, 0o644)
        guard fd >= 0 else { return }
        defer { Darwin.close(fd) }
        guard flock(fd, LOCK_EX | LOCK_NB) == 0 else { return }
        var state = StateIO.load(dataDir)
        let idx = DockController.indices(dataDir: dataDir)
        for i in state.folders.indices { if let p = idx[state.folders[i].id] { state.folders[i].dockIndex = p } }
        StateIO.save(state, dataDir)
        DockController.removeAll(dataDir: dataDir)
        flock(fd, LOCK_UN)
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let id = Bundle.main.bundleIdentifier { LeaveNoTrace.clean(bundleID: id) }
    }
}

let app = NSApplication.shared
let delegate = FolderAppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
