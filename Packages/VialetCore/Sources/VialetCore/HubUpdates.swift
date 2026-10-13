import Foundation

/// Mises a jour des apps vues par Vialet : la derniere Release GitHub de chaque app, au lancement
/// puis toutes les 6 h, avec un plancher de 30 min (comme le kit). Vialet n'installe rien : il
/// signale, et l'app s'en charge (`<nom>://update`).
public enum HubUpdates {
    public static let interval: TimeInterval = 6 * 3600
    public static let floor: TimeInterval = 30 * 60

    public static func shouldCheck(now: Date, lastCheck: Date?) -> Bool {
        guard let lastCheck else { return true }
        let elapsed = now.timeIntervalSince(lastCheck)
        return elapsed < 0 || elapsed >= floor
    }

    public static func releaseURL(repository: String) -> URL {
        URL(string: "https://api.github.com/repos/\(repository)/releases/latest")!
    }

    /// Version a annoncer : la Release est complete pour cette app (DMG `<appName>-X.Y.Z.dmg` et son
    /// empreinte, ce que l'app pourra installer) et plus recente que la version installee.
    public static func available(installed: String, releaseJSON: Data, appName: String) -> SemanticVersion? {
        guard let current = SemanticVersion(string: installed),
              let release = ReleaseInfo.parse(json: releaseJSON, appName: appName),
              release.version > current else { return nil }
        return release.version
    }
}
