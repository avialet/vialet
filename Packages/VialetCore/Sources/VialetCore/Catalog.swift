import Foundation

/// Une app du catalogue du hub (https://vialet.app/apps.json).
public struct CatalogEntry: Equatable, Sendable {
    /// Nom affiche (accents permis).
    public let name: String
    /// Nom CamelCase ASCII (`Allege`) : bundle `fr.vialet.<brand minuscule>`.
    public let brand: String
    /// Site de l'app (https seulement) ; nil si absent ou invalide.
    public let url: URL?
    public let tagline: String
    /// `available` (defaut) ou autre (`soon`...).
    public let status: String

    public init(name: String, brand: String, url: URL?, tagline: String, status: String) {
        self.name = name; self.brand = brand; self.url = url; self.tagline = tagline; self.status = status
    }

    public var isAvailable: Bool { status == "available" }
    public var bundleIdentifier: String { "fr.vialet." + brand.lowercased() }
}

/// Catalogue du hub : ordre des apps dans le menu, apps a decouvrir. Lu au plus une fois par jour.
public enum Catalog {
    public static let url = URL(string: "https://vialet.app/apps.json")!
    /// Intervalle minimal entre deux lectures (24 h).
    public static let refreshInterval: TimeInterval = 24 * 3600

    /// `{"apps": [{name, brand, url, tagline, status}]}` ; nil si ce n'est pas cette forme.
    /// Une entree sans `brand` est ignoree ; un lien non https devient nil.
    public static func parse(_ data: Data) -> [CatalogEntry]? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let list = json["apps"] as? [[String: Any]] else { return nil }
        return list.compactMap { item in
            guard let brand = item["brand"] as? String, !brand.isEmpty else { return nil }
            let link = (item["url"] as? String).flatMap(URL.init(string:)).flatMap { $0.scheme == "https" ? $0 : nil }
            return CatalogEntry(name: item["name"] as? String ?? brand, brand: brand, url: link,
                                tagline: item["tagline"] as? String ?? "",
                                status: item["status"] as? String ?? "available")
        }
    }

    /// Lecture due : jamais lu, plus de 24 h, ou horloge reculee.
    public static func shouldRefresh(now: Date, lastFetch: Date?) -> Bool {
        guard let lastFetch else { return true }
        let elapsed = now.timeIntervalSince(lastFetch)
        return elapsed < 0 || elapsed >= refreshInterval
    }
}
