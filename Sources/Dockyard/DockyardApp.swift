import AppKit
import DockyardCore
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    var library: Library?
    private var terminating = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        // Închiderea ferestrei principale = Dockyard trece în fundal (dispare din Dock, folderele rămân).
        NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: nil, queue: .main) { [weak self] n in
            guard let self, !self.terminating, let w = n.object as? NSWindow, w.canBecomeMain else { return }
            MainActor.assumeIsolated { self.library?.enterBackground() }
        }
    }

    /// Închiderea ferestrei NU oprește aplicația: folderele rămân în Dock cât timp Dockyard rulează.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    /// Pornirea Dockyard când rulează deja (Spotlight, Finder, meniul unui folder) îl readuce în față.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        MainActor.assumeIsolated { library?.bringToFront() }
        return false
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        terminating = true
        MainActor.assumeIsolated { library?.shutdown() }
        return .terminateNow
    }

    func applicationWillTerminate(_ notification: Notification) {
        LeaveNoTrace.clean(bundleID: Paths.mainBundleID)
    }
}

@main
struct DockyardApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @State private var library = Library()

    var body: some Scene {
        Window("Dockyard", id: "main") {
            ContentView()
                .environment(library)
                .task {
                    delegate.library = library
                    library.start()
                }
        }

        // Iconița din bara de meniu, vizibilă cât timp Dockyard rulează în fundal.
        MenuBarExtra(isInserted: Binding(get: { library.inBackground }, set: { _ in })) {
            BackgroundMenu().environment(library)
        } label: {
            Image(systemName: "square.grid.2x2.fill")
        }
        .menuBarExtraStyle(.menu)
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        .defaultSize(width: 1180, height: 780)
        .restorationBehavior(.disabled)
        .commands {
            CommandGroup(replacing: .appTermination) {
                Button("Ascunde din Dock (rulează în fundal)") { library.enterBackground() }
                Button("Închide complet Dockyard") { library.quitCompletely() }
                    .keyboardShortcut("q")
            }
            CommandGroup(replacing: .newItem) {
                Button("Folder nou") { library.addFolder() }.keyboardShortcut("n")
                Divider()
                Button("Redenumește folderul") {
                    if let id = library.selectedID { library.focusTitleID = id }
                }
                .keyboardShortcut("r")
                .disabled(library.selectedID == nil)
                Button("Șterge folderul…") {
                    if let id = library.selectedID { library.requestDelete(id) }
                }
                .keyboardShortcut(.delete, modifiers: .command)
                .disabled(library.selectedID == nil)
            }
        }
    }
}

/// Meniul din bara de meniu când Dockyard rulează în fundal.
struct BackgroundMenu: View {
    @Environment(Library.self) private var library

    var body: some View {
        Button("Deschide Dockyard") { library.bringToFront() }
        Divider()
        if library.folders.isEmpty {
            Text("Niciun folder")
        } else {
            Section("Foldere în Dock") {
                ForEach(library.folders) { f in
                    Button {
                        library.showPanel(f.id)
                    } label: {
                        Label {
                            Text(f.name)
                        } icon: {
                            Image(nsImage: library.icon(f, size: 18))
                        }
                    }
                }
            }
        }
        Divider()
        Button("Închide complet Dockyard") { library.quitCompletely() }
            .keyboardShortcut("q")
    }
}
