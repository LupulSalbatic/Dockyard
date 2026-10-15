import AppKit
import Foundation

/// Fiecare folder din Dock este o mini-aplicație generată în „Dockyard Data/Tiles/<id>.app”.
/// Ea afișează iconița folderului și deschide panoul cu aplicații la click.
public enum TileFactory {
    public static func bundleURL(_ f: DockFolder, _ dataDir: URL) -> URL {
        Paths.tilesDir(dataDir).appendingPathComponent("\(f.shortID).app", isDirectory: true)
    }

    /// Creează sau actualizează bundle-ul. Întoarce true dacă s-a schimbat ceva.
    @discardableResult
    public static func build(_ f: DockFolder, dataDir: URL, helperBinary: URL, mainApp: URL) -> Bool {
        let fm = FileManager.default
        let app = bundleURL(f, dataDir)
        let macos = app.appendingPathComponent("Contents/MacOS", isDirectory: true)
        let res = app.appendingPathComponent("Contents/Resources", isDirectory: true)
        try? fm.createDirectory(at: macos, withIntermediateDirectories: true)
        try? fm.createDirectory(at: res, withIntermediateDirectories: true)

        var changed = false
        // semnarea modifică binarul copiat, așa că comparăm cu o amprentă a sursei
        let exe = macos.appendingPathComponent("DockyardFolder")
        let stampURL = res.appendingPathComponent("helper.stamp")
        let stamp = fingerprint(helperBinary)
        if !fm.fileExists(atPath: exe.path) || (try? String(contentsOf: stampURL, encoding: .utf8)) != stamp {
            try? fm.removeItem(at: exe)
            try? fm.copyItem(at: helperBinary, to: exe)
            try? stamp.write(to: stampURL, atomically: true, encoding: .utf8)
            changed = true
        }
        // binarul din Dockyard.app descărcat poartă „carantina” macOS → fără ea, Gatekeeper ar bloca folderul
        removexattr(exe.path, "com.apple.quarantine", 0)

        let info: [String: Any] = [
            "CFBundleIdentifier": f.bundleIdentifier,
            "CFBundleName": f.name,
            "CFBundleDisplayName": f.name,
            "CFBundleExecutable": "DockyardFolder",
            "CFBundleIconFile": "AppIcon",
            "CFBundlePackageType": "APPL",
            "CFBundleShortVersionString": "1.0",
            "CFBundleVersion": "1",
            "LSMinimumSystemVersion": "15.0",
            "NSHighResolutionCapable": true,
            "NSPrincipalClass": "NSApplication",
            "DYFolderID": f.id.uuidString,
            "DYDataDir": dataDir.path,
            "DYMainApp": mainApp.path,
        ]
        let infoURL = app.appendingPathComponent("Contents/Info.plist")
        if let data = try? PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0),
           (try? Data(contentsOf: infoURL)) != data {
            try? data.write(to: infoURL, options: .atomic)
            changed = true
        }

        let icns = ICNSWriter.data(for: f, dataDir: dataDir)
        let icnsURL = res.appendingPathComponent("AppIcon.icns")
        if (try? Data(contentsOf: icnsURL)) != icns {
            try? icns.write(to: icnsURL, options: .atomic)
            changed = true
        }

        if changed { sign(app) }
        return changed
    }

    public static func remove(_ f: DockFolder, _ dataDir: URL) {
        try? FileManager.default.removeItem(at: bundleURL(f, dataDir))
    }

    static func sign(_ app: URL) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
        p.arguments = ["--force", "--sign", "-", app.path]
        p.standardOutput = FileHandle.nullDevice
        p.standardError = FileHandle.nullDevice
        try? p.run()
        p.waitUntilExit()
    }

    private static func fingerprint(_ url: URL) -> String {
        let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
        let size = (attrs?[.size] as? Int) ?? 0
        let date = (attrs?[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0
        return "\(size)-\(Int(date))"
    }
}

/// Citește și scrie lista de aplicații din Dock (domeniul com.apple.dock, cheia persistent-apps).
public enum DockController {
    static let domain = "com.apple.dock" as CFString
    static let key = "persistent-apps" as CFString

    public struct Tile: Identifiable {
        public let id: Int
        public let path: String?
        public let label: String
        public let folderID: UUID?

        public init(id: Int, path: String?, label: String, folderID: UUID?) {
            self.id = id
            self.path = path
            self.label = label
            self.folderID = folderID
        }
    }

    public static func persistentApps() -> [[String: Any]] {
        CFPreferencesAppSynchronize(domain)
        return CFPreferencesCopyAppValue(key, domain) as? [[String: Any]] ?? []
    }

    static func write(_ apps: [[String: Any]]) {
        CFPreferencesSetAppValue(key, apps as CFArray, domain)
        CFPreferencesAppSynchronize(domain)
    }

    public static func restartDock() {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
        p.arguments = ["Dock"]
        try? p.run()
        p.waitUntilExit()
    }

    static func path(of tile: [String: Any]) -> String? {
        guard let td = tile["tile-data"] as? [String: Any],
              let fd = td["file-data"] as? [String: Any],
              let s = fd["_CFURLString"] as? String else { return nil }
        if s.hasPrefix("file://") { return URL(string: s)?.standardizedFileURL.path }
        return s
    }

    static func folderID(of tile: [String: Any], tilesDir: URL) -> UUID? {
        guard let p = path(of: tile), p.hasPrefix(tilesDir.standardizedFileURL.path) else { return nil }
        let short = URL(fileURLWithPath: p).deletingPathExtension().lastPathComponent
        guard short.count == 32 else { return nil }
        var s = short.uppercased()
        for i in [8, 13, 18, 23] { s.insert("-", at: s.index(s.startIndex, offsetBy: i)) }
        return UUID(uuidString: s)
    }

    static func tile(for f: DockFolder, dataDir: URL) -> [String: Any] {
        [
            "tile-type": "file-tile",
            "tile-data": [
                "file-label": f.name,
                "bundle-identifier": f.bundleIdentifier,
                "file-type": 41,
                "file-data": [
                    "_CFURLString": TileFactory.bundleURL(f, dataDir).absoluteString,
                    "_CFURLStringType": 15,
                ],
            ] as [String: Any],
        ]
    }

    /// Lista Dock dorită: aplicațiile utilizatorului + folderele noastre la pozițiile salvate.
    public static func merged(current: [[String: Any]], folders: [DockFolder], dataDir: URL) -> [[String: Any]] {
        let tiles = Paths.tilesDir(dataDir)
        var base = current.filter { folderID(of: $0, tilesDir: tiles) == nil }
        let ordered = folders.enumerated().sorted {
            ($0.element.dockIndex ?? Int.max, $0.offset) < ($1.element.dockIndex ?? Int.max, $1.offset)
        }.map(\.element)
        for f in ordered {
            let idx = min(max(f.dockIndex ?? base.count, 0), base.count)
            base.insert(tile(for: f, dataDir: dataDir), at: idx)
        }
        return base
    }

    private static func signature(_ apps: [[String: Any]]) -> [String] {
        apps.map { t in
            let td = t["tile-data"] as? [String: Any]
            return (path(of: t) ?? "?") + "|" + ((td?["file-label"] as? String) ?? "")
        }
    }

    /// Aplică folderele în Dock. Întoarce true dacă Dock-ul a fost repornit.
    @discardableResult
    public static func apply(_ folders: [DockFolder], dataDir: URL) -> Bool {
        let current = persistentApps()
        let next = merged(current: current, folders: folders, dataDir: dataDir)
        guard signature(next) != signature(current) else { return false }
        write(next)
        restartDock()
        return true
    }

    /// Scoate toate folderele Dockyard din Dock.
    @discardableResult
    public static func removeAll(dataDir: URL) -> Bool { apply([], dataDir: dataDir) }

    /// Pozițiile curente ale folderelor noastre (dacă utilizatorul le-a mutat cu mouse-ul în Dock).
    public static func indices(dataDir: URL) -> [UUID: Int] {
        let tiles = Paths.tilesDir(dataDir)
        var out: [UUID: Int] = [:]
        for (i, t) in persistentApps().enumerated() {
            if let id = folderID(of: t, tilesDir: tiles) { out[id] = i }
        }
        return out
    }

    /// Conținutul Dock-ului, pentru previzualizare.
    public static func tiles(dataDir: URL) -> [Tile] {
        let dir = Paths.tilesDir(dataDir)
        return persistentApps().enumerated().map { i, t in
            let td = t["tile-data"] as? [String: Any]
            return Tile(id: i, path: path(of: t), label: (td?["file-label"] as? String) ?? "", folderID: folderID(of: t, tilesDir: dir))
        }
    }
}

/// Catalogul aplicațiilor instalate (doar citire): dosarele standard + tot ce găsește Spotlight.
public enum AppCatalog {
    public static func installed() -> [AppRef] {
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser.path
        var paths: [String] = []

        // 1. dosarele standard (merg și fără Spotlight)
        let dirs = ["/Applications", "/Applications/Utilities", "/System/Applications", "/System/Applications/Utilities", home + "/Applications"]
        for d in dirs {
            for item in (try? fm.contentsOfDirectory(atPath: d)) ?? [] where item.hasSuffix(".app") {
                paths.append((d as NSString).appendingPathComponent(item))
            }
        }

        // 2. Spotlight: aplicații aflate oriunde (Descărcări, Desktop, subdosare din Aplicații…)
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/mdfind")
        p.arguments = ["kMDItemContentType == 'com.apple.application-bundle'"]
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = FileHandle.nullDevice
        if (try? p.run()) != nil {
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            p.waitUntilExit()
            paths += String(decoding: data, as: UTF8.self).split(separator: "\n").map(String.init)
        }

        var seenPaths = Set<String>()
        var out: [AppRef] = []
        for path in paths where seenPaths.insert(path).inserted && isUserFacing(path) {
            out.append(AppRef(path: path, name: fm.displayName(atPath: path).replacingOccurrences(of: ".app", with: "")))
        }
        return out.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// Exclude aplicațiile interne ale sistemului, ajutoarele din alte aplicații și folderele Dockyard.
    static func isUserFacing(_ path: String) -> Bool {
        guard path.hasSuffix(".app"), FileManager.default.fileExists(atPath: path) else { return false }
        let inner = (path as NSString).deletingLastPathComponent
        let blocked = ["/Library/", "/System/Library/", "/private/", "/.Trash/", "/Volumes/", "Dockyard Data/Tiles", "/Dockyard.app",
                       "/.build/", "/DerivedData/", "/node_modules/"]
        if blocked.contains(where: { path.contains($0) }) { return false }
        if inner.contains(".app/") || inner.hasSuffix(".app") { return false }   // aplicații ascunse în alte aplicații
        return true
    }

    /// Unde se află aplicația, pentru afișare (nil pentru dosarele standard).
    public static func location(of path: String) -> String? {
        let parent = (path as NSString).deletingLastPathComponent
        if ["/Applications", "/System/Applications", "/Applications/Utilities", "/System/Applications/Utilities"].contains(parent) { return nil }
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        var p = parent.hasPrefix(home) ? "~" + parent.dropFirst(home.count) : parent
        for (en, ro) in [("~/Downloads", "Descărcări"), ("~/Desktop", "Desktop"), ("~/Documents", "Documente"), ("~/Applications", "Aplicațiile mele")] where p.hasPrefix(en) {
            p = ro + p.dropFirst(en.count)
        }
        return p
    }
}
