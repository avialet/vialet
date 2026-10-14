import Foundation
import VialetCore

/// Ce que Vialet attend du menu rassembleur du kit : comportement de la 0.1.1 garde.
private let vialet = AppIdentity(name: "Vialet", displayName: "Vialet", repository: "avialet/vialet",
                                 bundleIdentifier: "fr.vialet.vialet", palette: .sea, glyph: "",
                                 site: URL(string: "https://vialet.app")!)

let shellTests: (String, [Test]) = ("Shell", [
    Test("stateKeysUnchangedSince0_1_1") {
        MainActor.assumeIsolated {
            let model = HubModel(identity: vialet, updater: Updater(configuration: UpdaterConfiguration(vialet)),
                                 announcesOwnUpdate: true)
            expectEqual(model.defaultsKeys, ["VialetLastAppsCheck", "VialetCatalogFetched", "VialetAppUpdates", "VialetReleaseETags"])
            expectEqual(vialet.key("ShowDiscover"), "VialetShowDiscover")
        }
    },
    Test("vialetIsNeverListedAndAlwaysHosts") {
        let me = InstalledApp(bundleIdentifier: "fr.vialet.vialet", name: "Vialet", displayName: "Vialet", version: "0.1.2",
                              url: URL(fileURLWithPath: "/Applications/Vialet.app"), scheme: "vialet")
        let pico = InstalledApp(bundleIdentifier: "fr.vialet.pico", name: "Pico", displayName: "Pico", version: "0.2.0",
                                url: URL(fileURLWithPath: "/Applications/Pico.app"), scheme: "pico")
        expectEqual(HubListing.build(installed: [me, pico], manifests: [], catalog: nil).apps.map(\.name), ["Pico"])
        expectEqual(HubListing.hubBundleIdentifier, MenuBarPresence.hubBundleIdentifier)
        expectEqual(HubElection.role(me: "fr.vialet.pico", hubAppRunning: true, installed: ["fr.vialet.pico", "fr.vialet.allege"],
                                     runningHosts: ["fr.vialet.allege"]), .vialet)
    },
    Test("chuchoteDictationStaysInBackground") {
        expect(!HubModel.activates(bundleIdentifier: "fr.vialet.chuchote", action: "dicter"))
        expect(HubModel.activates(bundleIdentifier: "fr.vialet.pico", action: "new"))
    },
    Test("statusReplacesTaglineAndFiltersChips") {
        let e = HubEntry(bundleIdentifier: "fr.vialet.eveil", name: "Eveil", displayName: "\u{00C9}veil", version: "0.1.0",
                         appURL: URL(fileURLWithPath: "/Applications/Eveil.app"), scheme: "eveil", repository: "avialet/eveil",
                         site: nil, palette: nil, glyph: "", strokeDeep: false,
                         actions: [AppAction("1h", title: "1 h", symbol: "sun.max", visible: .idle),
                                   AppAction("arreter", title: "Arr\u{00EA}ter", symbol: "stop.circle", visible: .active)],
                         tagline: "Accroche", status: "Actif", active: true)
        expectEqual(e.subtitle, "Actif")
        expectEqual(e.visibleActions.map(\.id), ["arreter"])
    },
])
