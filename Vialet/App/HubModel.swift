import AppKit
import Observation
import VialetCore

/// Ce que montre le menu : les apps installees (fiches publiees, Info.plist, catalogue), leurs mises
/// a jour en attente, et les apps du catalogue a decouvrir.
@MainActor
@Observable
final class HubModel {
    static let shared = HubModel()

    private(set) var listing: HubListing = .empty
    /// Version publiee plus recente que l'installee, par bundle id.
    private(set) var updates: [String: SemanticVersion] = [:]
    /// Plaques en couleur (32 pt a 2x), par bundle id ; icone de l'app sans fiche.
    @ObservationIgnored private var plateCache: [String: NSImage] = [:]

    /// Mises a jour a signaler pour les apps listees (une app deja a jour n'apparait plus).
    var pendingUpdates: [HubEntry] {
        listing.apps.filter { entry in
            guard let next = updates[entry.bundleIdentifier] else { return false }
            return SemanticVersion(string: entry.version).map { next > $0 } ?? false
        }
    }

    /// Point de la barre des menus : une app ou Vialet elle-meme attend une mise a jour.
    var hasPendingUpdate: Bool { !pendingUpdates.isEmpty || Updater.shared.announced != nil }

    /// Apercu (mode capture) : pas de reseau ni de fichier.
    @ObservationIgnored private var isPreview = false
    @ObservationIgnored private var catalog: [CatalogEntry]?
    @ObservationIgnored private var periodicTask: Task<Void, Never>?
    @ObservationIgnored private var reloadTask: Task<Void, Never>?

    private let defaults = UserDefaults.standard
    private var lastAppsCheckKey: String { Brand.key("LastAppsCheck") }
    private var catalogFetchedKey: String { Brand.key("CatalogFetched") }
    /// Mises a jour trouvees, gardees d'un lancement a l'autre (le plancher de 30 min s'applique aussi
    /// apres une relance).
    private var updatesKey: String { Brand.key("AppUpdates") }

    private static var supportDirectory: URL {
        HubManifest.directory.deletingLastPathComponent()
    }
    private static var catalogCacheURL: URL { supportDirectory.appendingPathComponent("catalog.json") }

    // MARK: Chargement

    /// Au lancement : catalogue en cache, liste, puis (si la recherche automatique est permise)
    /// catalogue du jour et mises a jour des apps, toutes les 6 h ensuite.
    func start() {
        catalog = (try? Data(contentsOf: Self.catalogCacheURL)).flatMap(Catalog.parse)
        let saved = defaults.dictionary(forKey: updatesKey) as? [String: String] ?? [:]
        updates = saved.compactMapValues(SemanticVersion.init(string:))
        reload()
        observe()
        Task {
            try? await Task.sleep(for: .seconds(6))
            refreshCatalogIfNeeded()
            checkAppsIfNeeded()
        }
        periodicTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(HubUpdates.interval))
                self?.checkAppsIfNeeded()
                self?.refreshCatalogIfNeeded()
            }
        }
    }

    /// Relit les apps installees et leurs fiches (hors du fil principal).
    func reload() {
        guard !isPreview else { return }
        let catalog = self.catalog
        reloadTask?.cancel()
        reloadTask = Task.detached(priority: .utility) {
            let listing = Self.scan(catalog: catalog)
            await MainActor.run { [weak self] in
                guard let self, !Task.isCancelled else { return }
                if listing != self.listing {
                    self.listing = listing
                    self.plateCache = [:]
                }
            }
        }
    }

    private nonisolated static func scan(catalog: [CatalogEntry]?) -> HubListing {
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser
        var installed = InstalledApp.scan(directories: [URL(fileURLWithPath: "/Applications"),
                                                         home.appendingPathComponent("Applications")])
        let manifests = HubManifest.loadAll(from: HubManifest.directory)
        func add(_ url: URL?) {
            guard let url, !url.pathComponents.contains(where: { $0 == ".Trash" || $0 == ".Trashes" }),
                  let app = InstalledApp.read(bundleURL: url),
                  !installed.contains(where: { $0.bundleIdentifier == app.bundleIdentifier }) else { return }
            installed.append(app)
        }
        // Apps rangees ailleurs : la fiche publiee, puis LaunchServices pour le catalogue.
        for m in manifests { add(URL(fileURLWithPath: m.appPath)) }
        for entry in catalog ?? [] {
            add(NSWorkspace.shared.urlForApplication(withBundleIdentifier: entry.bundleIdentifier))
        }
        return HubListing.build(installed: installed, manifests: manifests, catalog: catalog)
    }

    private func observe() {
        let center = DistributedNotificationCenter.default()
        center.addObserver(forName: HubManifest.appsChangedNotification, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { HubModel.shared.reload() }
        }
        let workspace = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didTerminateApplicationNotification] {
            workspace.addObserver(forName: name, object: nil, queue: .main) { note in
                let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
                guard app?.bundleIdentifier?.hasPrefix(InstalledApp.bundlePrefix) == true else { return }
                MainActor.assumeIsolated { HubModel.shared.reload() }
            }
        }
    }

    // MARK: Catalogue

    private func refreshCatalogIfNeeded() {
        guard !isPreview, Updater.shared.autoCheck,
              Catalog.shouldRefresh(now: Date(), lastFetch: defaults.object(forKey: catalogFetchedKey) as? Date)
        else { return }
        Task {
            var request = URLRequest(url: Catalog.url)
            request.timeoutInterval = 15
            guard let (data, response) = try? await URLSession.shared.data(for: request),
                  (response as? HTTPURLResponse)?.statusCode == 200,
                  let entries = Catalog.parse(data) else { return }
            try? FileManager.default.createDirectory(at: Self.supportDirectory, withIntermediateDirectories: true)
            try? data.write(to: Self.catalogCacheURL, options: .atomic)
            defaults.set(Date(), forKey: catalogFetchedKey)
            catalog = entries
            reload()
        }
    }

    // MARK: Mises a jour

    /// Derniere Release de chaque app listee, si la recherche automatique est permise et que la
    /// derniere verification date d'au moins 30 min.
    func checkAppsIfNeeded() {
        guard !isPreview, Updater.shared.autoCheck,
              HubUpdates.shouldCheck(now: Date(), lastCheck: defaults.object(forKey: lastAppsCheckKey) as? Date)
        else { return }
        checkApps()
    }

    func checkApps() {
        let apps = listing.apps
        guard !apps.isEmpty else { return }
        Task {
            var found: [String: SemanticVersion] = [:]
            var anySuccess = false
            for app in apps {
                guard let repository = app.repository, let url = HubUpdates.releaseURL(repository: repository) else { continue }
                var request = URLRequest(url: url)
                request.timeoutInterval = 15
                request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
                request.setValue(Brand.name, forHTTPHeaderField: "User-Agent")
                guard let (data, response) = try? await URLSession.shared.data(for: request),
                      let status = (response as? HTTPURLResponse)?.statusCode else { continue }
                if status == 403 || status == 429 { break } // quota GitHub : on reessaiera plus tard
                anySuccess = true
                if status == 200, let next = HubUpdates.available(installed: app.version, releaseJSON: data, appName: app.name) {
                    found[app.bundleIdentifier] = next
                }
            }
            guard anySuccess else { return }
            defaults.set(Date(), forKey: lastAppsCheckKey)
            defaults.set(found.mapValues(\.description), forKey: updatesKey)
            updates = found
        }
    }

    // MARK: Actions

    func open(_ entry: HubEntry) {
        NSWorkspace.shared.openApplication(at: entry.appURL, configuration: NSWorkspace.OpenConfiguration())
    }

    /// `<scheme>://<id>` adresse a cette app precisement (pas a une autre copie).
    func perform(_ action: AppAction, of entry: HubEntry) {
        guard let url = entry.url(for: action.id) else { return open(entry) }
        NSWorkspace.shared.open([url], withApplicationAt: entry.appURL, configuration: NSWorkspace.OpenConfiguration())
    }

    /// L'app verifie et propose sa mise a jour (`<scheme>://update`) ; sans schema, elle s'ouvre
    /// (sa verification de lancement s'en charge).
    func update(_ entry: HubEntry) {
        guard let url = entry.updateURL else { return open(entry) }
        NSWorkspace.shared.open([url], withApplicationAt: entry.appURL, configuration: NSWorkspace.OpenConfiguration())
    }

    func openSite(_ url: URL?) {
        if let url { NSWorkspace.shared.open(url) }
    }

    /// Plaque de l'app (fiche : plaque plate du kit ; sinon icone du bundle).
    func plate(for entry: HubEntry) -> NSImage {
        if let cached = plateCache[entry.bundleIdentifier] { return cached }
        let image: NSImage
        if let palette = entry.palette {
            image = GlyphImage.plate(palette, glyph: entry.glyph, pixels: 64, strokeDeep: entry.strokeDeep)
        } else {
            image = NSWorkspace.shared.icon(forFile: entry.appURL.path)
        }
        plateCache[entry.bundleIdentifier] = image
        return image
    }

    /// Teintes des apps listees, pour la plaque du hub en tete du menu.
    var palettes: [AccentPalette] { listing.apps.compactMap(\.palette) }

    // MARK: Apercu

    #if DEBUG
    /// Mode capture : liste et mises a jour fictives, sans reseau.
    func preview(_ listing: HubListing, updates: [String: SemanticVersion], plates: [String: NSImage] = [:]) {
        isPreview = true
        self.listing = listing
        self.updates = updates
        plateCache = plates
    }
    #endif
}
