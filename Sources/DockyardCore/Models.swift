import Foundation

public struct AppRef: Codable, Hashable, Identifiable {
    public var path: String
    public var name: String
    public var id: String { path }

    public init(path: String, name: String) {
        self.path = path
        self.name = name
    }

    public var exists: Bool { FileManager.default.fileExists(atPath: path) }
}

public enum IconStyle: String, Codable, CaseIterable, Identifiable {
    case mosaic, symbol, image
    public var id: String { rawValue }
}

public struct FolderIcon: Codable, Hashable {
    public var style: IconStyle = .mosaic
    public var colorA: String = "8B5CF6"
    public var colorB: String = "22D3EE"
    public var symbol: String = "square.grid.2x2.fill"
    public var imageFile: String?
    public var glossy: Bool = true

    public init() {}
}

public struct DockFolder: Codable, Identifiable, Hashable {
    public var id: UUID
    public var name: String
    public var apps: [AppRef]
    public var icon: FolderIcon
    /// Poziția în lista de aplicații din Dock (persistent-apps). nil = la final.
    public var dockIndex: Int?

    public init(name: String, apps: [AppRef] = [], icon: FolderIcon = FolderIcon()) {
        id = UUID()
        self.name = name
        self.apps = apps
        self.icon = icon
    }

    public var shortID: String { id.uuidString.lowercased().replacingOccurrences(of: "-", with: "") }
    public var bundleIdentifier: String { "com.andrei.dockyard.folder.\(shortID)" }
}

public struct LibraryState: Codable {
    public var folders: [DockFolder] = []
    public var enabled: Bool = true
    public init() {}
}

// MARK: - Căi (totul stă lângă aplicație, în „Dockyard Data”)

public enum Paths {
    public static let mainBundleID = "com.andrei.dockyard"
    public static let helperPrefix = "com.andrei.dockyard.folder."

    public static func dataDir(nextTo bundleURL: URL) -> URL {
        bundleURL.deletingLastPathComponent().appendingPathComponent("Dockyard Data", isDirectory: true)
    }
    public static func stateFile(_ dir: URL) -> URL { dir.appendingPathComponent("folders.json") }
    public static func iconsDir(_ dir: URL) -> URL { dir.appendingPathComponent("Icons", isDirectory: true) }
    public static func tilesDir(_ dir: URL) -> URL { dir.appendingPathComponent("Tiles", isDirectory: true) }
}

public enum StateIO {
    public static func load(_ dir: URL) -> LibraryState {
        guard let data = try? Data(contentsOf: Paths.stateFile(dir)),
              let s = try? JSONDecoder().decode(LibraryState.self, from: data) else { return LibraryState() }
        return s
    }

    public static func save(_ state: LibraryState, _ dir: URL) {
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? enc.encode(state) {
            try? data.write(to: Paths.stateFile(dir), options: .atomic)
        }
    }
}

// MARK: - Comunicare între Dockyard și folderele din Dock

public enum Signal {
    public static let changed = Notification.Name("com.andrei.dockyard.changed")
    public static let quit = Notification.Name("com.andrei.dockyard.quit")
    public static let edit = Notification.Name("com.andrei.dockyard.edit")
    public static let show = Notification.Name("com.andrei.dockyard.show")

    public static func post(_ name: Notification.Name, _ object: String? = nil) {
        DistributedNotificationCenter.default().postNotificationName(name, object: object, userInfo: nil, deliverImmediately: true)
    }
}

// MARK: - Fără urme în ~/Library

public enum LeaveNoTrace {
    /// Șterge fișierele pe care macOS le creează automat pentru o aplicație (preferințe, stare salvată, cache).
    public static func clean(bundleID: String) {
        UserDefaults.standard.removePersistentDomain(forName: bundleID)
        CFPreferencesAppSynchronize(bundleID as CFString)
        let lib = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library")
        let paths = ["Preferences/\(bundleID).plist", "Saved Application State/\(bundleID).savedState",
                     "Caches/\(bundleID)", "HTTPStorages/\(bundleID)"].map { lib.appendingPathComponent($0).path }
        for p in paths { try? FileManager.default.removeItem(atPath: p) }
        // cfprefsd mai scrie o dată fișierul (gol) după închidere → îl ștergem și după
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/sh")
        p.arguments = ["-c", "for i in $(seq 1 20); do sleep 1; rm -rf " + paths.map { "'\($0)'" }.joined(separator: " ") + "; done"]
        try? p.run()
    }
}
