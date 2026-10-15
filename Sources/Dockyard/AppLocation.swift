import AppKit

/// Dockyard își ține datele lângă aplicație, deci trebuie să ruleze dintr-un loc în care poate scrie.
/// O aplicație descărcată și pornită direct din „Descărcări” e rulată de macOS dintr-o copie temporară,
/// doar-citire („App Translocation”). În cazul ăsta, Dockyard se oferă să se mute singur în Aplicații.
@MainActor
enum AppLocation {
    static var isTranslocated: Bool { Bundle.main.bundlePath.contains("/AppTranslocation/") }

    static func canWrite(_ dataDir: URL) -> Bool {
        let fm = FileManager.default
        let target = fm.fileExists(atPath: dataDir.path) ? dataDir : dataDir.deletingLastPathComponent()
        return fm.isWritableFile(atPath: target.path)
    }

    /// Întoarce true dacă Dockyard poate porni normal de aici. Altfel propune mutarea și închide aplicația.
    static func check(dataDir: URL) -> Bool {
        if !isTranslocated && canWrite(dataDir) { return true }
        offerMove(dataDir: dataDir)
        return false
    }

    /// /Applications dacă se poate scrie acolo, altfel ~/Applications (utilizator fără drepturi de administrator).
    private static var destination: URL {
        let fm = FileManager.default
        var dir = URL(fileURLWithPath: "/Applications", isDirectory: true)
        if !fm.isWritableFile(atPath: dir.path) {
            dir = fm.homeDirectoryForCurrentUser.appendingPathComponent("Applications", isDirectory: true)
        }
        return dir.appendingPathComponent("Dockyard.app", isDirectory: true)
    }

    private static func offerMove(dataDir: URL) {
        let dest = destination
        let alert = NSAlert()
        alert.messageText = "Mută Dockyard în Aplicații"
        alert.informativeText = isTranslocated
            ? "Dockyard rulează direct din arhiva descărcată, iar macOS nu-l lasă să-și salveze folderele aici.\n\nApasă „Mută și repornește”: Dockyard se copiază în „\(dest.deletingLastPathComponent().path)” și pornește de acolo."
            : "Dockyard nu poate salva date în „\(dataDir.deletingLastPathComponent().path)”.\n\nApasă „Mută și repornește”: Dockyard se copiază în „\(dest.deletingLastPathComponent().path)” și pornește de acolo."
        alert.addButton(withTitle: "Mută și repornește")
        alert.addButton(withTitle: "Închide")
        NSApp.activate(ignoringOtherApps: true)

        if alert.runModal() == .alertFirstButtonReturn {
            do {
                try move(to: dest)
                relaunch(dest)
            } catch {
                let fail = NSAlert()
                fail.messageText = "Nu am putut muta Dockyard"
                fail.informativeText = "Trage manual Dockyard.app în dosarul Aplicații din Finder, apoi pornește-l de acolo.\n\n\(error.localizedDescription)"
                fail.runModal()
            }
        }
        NSApp.terminate(nil)
    }

    private static func move(to dest: URL) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: dest.deletingLastPathComponent(), withIntermediateDirectories: true)
        // copiem întâi lângă destinație: dacă există deja un Dockyard (o versiune veche), îl înlocuim abia la final
        let tmp = dest.deletingLastPathComponent().appendingPathComponent(".Dockyard-\(UUID().uuidString).app", isDirectory: true)
        do {
            try fm.copyItem(at: Bundle.main.bundleURL, to: tmp)
            stripQuarantine(tmp)
            if fm.fileExists(atPath: dest.path) {
                _ = try fm.replaceItemAt(dest, withItemAt: tmp)
            } else {
                try fm.moveItem(at: tmp, to: dest)
            }
        } catch {
            try? fm.removeItem(at: tmp)
            throw error
        }
    }

    /// Utilizatorul a aprobat deja aplicația (altfel nu rula), așa că scoatem „carantina” de pe copie,
    /// ca macOS să n-o mai ruleze din nou dintr-o copie temporară.
    private static func stripQuarantine(_ url: URL) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/xattr")
        p.arguments = ["-dr", "com.apple.quarantine", url.path]
        p.standardOutput = FileHandle.nullDevice
        p.standardError = FileHandle.nullDevice
        try? p.run()
        p.waitUntilExit()
    }

    /// Pornește copia după ce instanța curentă s-a închis.
    private static func relaunch(_ app: URL) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/sh")
        p.arguments = ["-c", "sleep 1; /usr/bin/open \"$0\"", app.path]
        try? p.run()
    }
}
