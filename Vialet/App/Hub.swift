import AppKit
import VialetCore

/// Le menu rassembleur vient du kit (VialetKit/Hub) : Vialet le tient pour toutes les apps, avec son
/// propre bandeau de mise a jour, ses reglages et Quitter. Memes cles UserDefaults qu'en 0.1.1
/// (`VialetLastAppsCheck`, `VialetAppUpdates`, `VialetReleaseETags`, `VialetCatalogFetched`,
/// `VialetShowDiscover`).
extension HubModel {
    static let shared = HubModel(identity: Brand.identity, updater: .shared, announcesOwnUpdate: true)
}

extension HubStatusItem {
    static let shared = HubStatusItem(model: .shared, options: Brand.menuOptions)
}

extension Brand {
    @MainActor
    static var menuOptions: HubMenuOptions {
        HubMenuOptions(updater: .shared, openSettings: { SettingsWindow.show() }, quitTitle: "Quitter Vialet")
    }
}
