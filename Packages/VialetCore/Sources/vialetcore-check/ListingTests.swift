import Foundation
import VialetCore

private func installed(_ name: String, display: String? = nil, version: String = "0.2.0", scheme: String? = nil) -> InstalledApp {
    InstalledApp(bundleIdentifier: "fr.vialet.\(name.lowercased())", name: name, displayName: display ?? name,
                 version: version, url: URL(fileURLWithPath: "/Applications/\(name).app"), scheme: scheme)
}

private let picoIdentity = AppIdentity(name: "Pico", displayName: "Pico", repository: "avialet/pico",
                                       bundleIdentifier: "fr.vialet.pico", palette: .sea, glyph: "M 20 50 L 80 50")

private let catalog = Catalog.parse(Data(catalogJSON.utf8))!

let listingTests: (String, [Test]) = ("Listing", [
    Test("ordersByCatalogThenAlphabetically") {
        let apps = [installed("Zebre"), installed("Chuchote"), installed("Allege", display: "All\u{00E8}ge"),
                    installed("Pico"), installed("Brouillon"), installed("Ane", display: "\u{00C2}ne")]
        let listing = HubListing.build(installed: apps, manifests: [], catalog: catalog)
        expectEqual(listing.apps.map(\.name), ["Pico", "Allege", "Chuchote", "Ane", "Brouillon", "Zebre"])
    },
    Test("alphabeticalWithoutCatalog") {
        let apps = [installed("Pico"), installed("Allege", display: "All\u{00E8}ge"), installed("Brouillon")]
        let listing = HubListing.build(installed: apps, manifests: [], catalog: nil)
        expectEqual(listing.apps.map(\.displayName), ["All\u{00E8}ge", "Brouillon", "Pico"])
        expectEqual(listing.discover, [])
    },
    Test("excludesVialetItself") {
        let listing = HubListing.build(installed: [installed("Vialet"), installed("Pico")], manifests: [], catalog: nil)
        expectEqual(listing.apps.map(\.name), ["Pico"])
    },
    Test("discoverListsAvailableCatalogAppsNotInstalled") {
        let listing = HubListing.build(installed: [installed("Pico")], manifests: [], catalog: catalog)
        expectEqual(listing.discover.map(\.brand), ["Allege", "Chuchote"])
    },
    Test("manifestEnrichesEntry") {
        let manifest = HubManifest(identity: picoIdentity, version: "0.2.0", appPath: "/Applications/Pico.app",
                                   scheme: "pico", actions: [AppAction("new", title: "Nouvelle t\u{00E2}che", symbol: "plus")])
        let listing = HubListing.build(installed: [installed("Pico", version: "0.2.1")], manifests: [manifest], catalog: catalog)
        let pico = listing.apps.first
        expectEqual(pico?.actions.map(\.id), ["new"])
        expectEqual(pico?.palette, AccentPalette.sea)
        expectEqual(pico?.glyph, "M 20 50 L 80 50")
        expectEqual(pico?.scheme, "pico")
        expectEqual(pico?.repository, "avialet/pico")
        expectEqual(pico?.version, "0.2.1", "la version installee prime sur celle de la fiche")
        expectEqual(pico?.tagline, "Le gestionnaire de t\u{00E2}ches.")
        expectEqual(pico?.site, URL(string: "https://pico.vialet.app"))
    },
    Test("defaultsWithoutManifest") {
        let listing = HubListing.build(installed: [installed("Allege", display: "All\u{00E8}ge", scheme: "allege")],
                                       manifests: [], catalog: nil)
        let allege = listing.apps.first
        expectEqual(allege?.actions, [])
        expectEqual(allege?.palette, nil)
        expectEqual(allege?.scheme, "allege")
        expectEqual(allege?.repository, "avialet/allege")
        expectEqual(allege?.site, URL(string: "https://allege.vialet.app"))
        expectEqual(allege?.tagline, nil)
    },
    Test("actionURLs") {
        let manifest = HubManifest(identity: picoIdentity, version: "0.2.0", appPath: "/Applications/Pico.app",
                                   scheme: "pico", actions: [AppAction("new", title: "Nouvelle", symbol: "plus")])
        let listing = HubListing.build(installed: [installed("Pico")], manifests: [manifest], catalog: nil)
        let pico = listing.apps[0]
        expectEqual(pico.url(for: "new"), URL(string: "pico://new"))
        expectEqual(pico.updateURL, URL(string: "pico://update"))
        let bare = HubListing.build(installed: [installed("Pince")], manifests: [], catalog: nil).apps[0]
        expectEqual(bare.updateURL, nil, "sans schema connu : pas d'URL")
    },
])
