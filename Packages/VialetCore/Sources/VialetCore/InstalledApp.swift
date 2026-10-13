import Foundation

/// Une app vialet.app installee, lue dans son Info.plist (sans la lancer).
public struct InstalledApp: Equatable, Sendable {
    public static let bundlePrefix = "fr.vialet."

    public let bundleIdentifier: String
    /// CFBundleName : nom ASCII (`Allege`), nom du DMG `<name>-X.Y.Z.dmg`.
    public let name: String
    public let displayName: String
    /// CFBundleShortVersionString.
    public let version: String
    public let url: URL
    /// Premier CFBundleURLSchemes ; nil sans schema.
    public let scheme: String?

    public init(bundleIdentifier: String, name: String, displayName: String, version: String, url: URL, scheme: String?) {
        self.bundleIdentifier = bundleIdentifier; self.name = name; self.displayName = displayName
        self.version = version; self.url = url; self.scheme = scheme
    }

    /// nil si le bundle est illisible ou n'est pas une app vialet.app (`fr.vialet.*`).
    public static func read(bundleURL: URL) -> InstalledApp? {
        let plist = bundleURL.appendingPathComponent("Contents/Info.plist")
        guard let data = try? Data(contentsOf: plist),
              let info = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let id = info["CFBundleIdentifier"] as? String, id.hasPrefix(bundlePrefix) else { return nil }
        let name = info["CFBundleName"] as? String ?? bundleURL.deletingPathExtension().lastPathComponent
        let types = info["CFBundleURLTypes"] as? [[String: Any]] ?? []
        let scheme = types.lazy.compactMap { ($0["CFBundleURLSchemes"] as? [String])?.first }.first
        return InstalledApp(bundleIdentifier: id, name: name,
                            displayName: info["CFBundleDisplayName"] as? String ?? name,
                            version: info["CFBundleShortVersionString"] as? String ?? "0.0.0",
                            url: bundleURL, scheme: scheme)
    }

    /// Les apps vialet.app des dossiers donnes et de leurs sous-dossiers directs, sans doublon de
    /// bundle (le premier dossier l'emporte).
    public static func scan(directories: [URL]) -> [InstalledApp] {
        let fm = FileManager.default
        var found: [InstalledApp] = []
        var seen = Set<String>()
        func add(_ url: URL) {
            guard let app = read(bundleURL: url), !seen.contains(app.bundleIdentifier) else { return }
            seen.insert(app.bundleIdentifier)
            found.append(app)
        }
        for dir in directories {
            let items = ((try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.isDirectoryKey],
                                                       options: [.skipsHiddenFiles])) ?? [])
                .sorted { $0.lastPathComponent < $1.lastPathComponent }
            for item in items {
                if item.pathExtension == "app" {
                    add(item)
                } else if (try? item.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true {
                    let inner = (try? fm.contentsOfDirectory(at: item, includingPropertiesForKeys: nil,
                                                             options: [.skipsHiddenFiles])) ?? []
                    for app in inner.sorted(by: { $0.lastPathComponent < $1.lastPathComponent })
                    where app.pathExtension == "app" { add(app) }
                }
            }
        }
        return found
    }
}
