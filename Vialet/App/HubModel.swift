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
    /// ETag de la derniere Release lue, par depot (requetes conditionnelles).
    private var etagsKey: String { Brand.key("ReleaseETags") }
    @ObservationIgnored private var isCheckingApps = false
    /// Une verification a deja abouti : le resultat garde (aucune mise a jour) vaut pour un 304.
    private var lastAppsCheckKnown: Bool { defaults.object(forKey: lastAppsCheckKey) != nil }

    private static var supportDirectory: URL {
        HubManifest.directory.deletingLastPathComponent()
    }
    private static var catalogCacheURL: URL { supportDirectory.appendingPathComponent("catalog.json") }

    // MARK: Chargement

    /// Au lancement : catalogue en cache, liste, puis (si la recherche automatique est permise)
    /// catalogue du jour et mises a jour des apps, toutes les 6 h ensuite.
    func start() {
        catalog = Catalog.load(from: Self.catalogCacheURL)
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
        // Racines /Applications et ~/Applications ; un .app ou dossier en lien qui en sort est ecarte.
        let roots = HubManifest.applicationRoots(home: home)
        var installed = InstalledApp.scan(directories: roots) { HubSafety.isAcceptableAppURL($0, roots: roots) }
        let manifests = HubManifest.loadAll(from: HubManifest.directory)
        /// Une app d'un sous-dossier plus profond (fiche, LaunchServices), retenue seulement dans les racines
        /// et si son Info.plist porte le bundle attendu.
        func add(_ url: URL?, expecting bundleIdentifier: String) {
            guard let url, HubSafety.isAcceptableAppURL(url, roots: roots),
                  let app = InstalledApp.read(bundleURL: url), app.bundleIdentifier == bundleIdentifier,
                  !installed.contains(where: { $0.bundleIdentifier == app.bundleIdentifier }) else { return }
            installed.append(app)
        }
        // Fiches (non fiables) : chemin d'app dans un dossier Applications seulement.
        for m in manifests where HubSafety.isAcceptableAppPath(m.appPath, home: home) {
            add(URL(fileURLWithPath: m.appPath), expecting: m.bundleIdentifier)
        }
        // Catalogue : LaunchServices.
        for entry in catalog ?? [] {
            add(NSWorkspace.shared.urlForApplication(withBundleIdentifier: entry.bundleIdentifier),
                expecting: entry.bundleIdentifier)
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
                  HubSafety.isAcceptableResponse(byteCount: data.count, expectedLength: response.expectedContentLength),
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
        guard !apps.isEmpty, !isCheckingApps else { return }
        isCheckingApps = true
        Task {
            defer { isCheckingApps = false }
            var found: [String: SemanticVersion] = [:]
            var checked = Set<String>()
            var stopped = false
            var etags = defaults.dictionary(forKey: etagsKey) as? [String: String] ?? [:]
            for app in apps {
                guard let repository = app.repository, let url = HubUpdates.releaseURL(repository: repository) else { continue }
                var request = URLRequest(url: url)
                request.timeoutInterval = 15
                request.cachePolicy = .reloadIgnoringLocalCacheData
                request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
                request.setValue(Brand.name, forHTTPHeaderField: "User-Agent")
                // ETag : une Release inchangee repond 304, sans compter dans le quota de GitHub.
                if let etag = etags[repository], updates[app.bundleIdentifier] != nil || lastAppsCheckKnown {
                    request.setValue(etag, forHTTPHeaderField: "If-None-Match")
                }
                guard let (data, response) = try? await URLSession.shared.data(for: request),
                      let http = response as? HTTPURLResponse,
                      HubSafety.isAcceptableResponse(byteCount: data.count, expectedLength: http.expectedContentLength)
                else { continue }
                switch HubUpdates.outcome(status: http.statusCode) {
                case .result:
                    checked.insert(app.bundleIdentifier)
                    etags[repository] = http.value(forHTTPHeaderField: "ETag")
                    if http.statusCode == 200,
                       let next = HubUpdates.available(installed: app.version, releaseJSON: data, appName: app.name) {
                        found[app.bundleIdentifier] = next
                    }
                case .unchanged:
                    checked.insert(app.bundleIdentifier)
                    if let previous = updates[app.bundleIdentifier] { found[app.bundleIdentifier] = previous }
                case .stop:
                    stopped = true
                case .skip:
                    break
                }
                if stopped { break }
            }
            defaults.set(etags, forKey: etagsKey)
            let merged = HubUpdates.merge(previous: updates, found: found, checked: checked)
            defaults.set(merged.mapValues(\.description), forKey: updatesKey)
            updates = merged
            // Horodatage seulement pour une verification complete : coupee par le quota, on reessaiera.
            if !stopped, !checked.isEmpty { defaults.set(Date(), forKey: lastAppsCheckKey) }
        }
    }

    // MARK: Actions

    /// Le bundle de l'entree, relu juste avant de l'ouvrir : un `.app` dans /Applications ou
    /// ~/Applications (liens symboliques resolus) dont l'Info.plist porte toujours le bundle attendu ;
    /// nil sinon (rien n'est ouvert).
    private func verifiedAppURL(_ entry: HubEntry) -> URL? {
        let url = entry.appURL
        let roots = HubManifest.applicationRoots(home: FileManager.default.homeDirectoryForCurrentUser)
        guard HubSafety.isAcceptableAppURL(url, roots: roots),
              InstalledApp.read(bundleURL: url)?.bundleIdentifier == entry.bundleIdentifier else {
            reload()
            return nil
        }
        return url
    }

    func open(_ entry: HubEntry) {
        guard let app = verifiedAppURL(entry) else { return }
        NSWorkspace.shared.openApplication(at: app, configuration: NSWorkspace.OpenConfiguration())
    }

    /// `<scheme>://<id>` adresse a cette app precisement (pas a une autre copie). Sans activation :
    /// l'app au premier plan le reste (une dictee doit se coller la ou l'on etait) ; l'app ciblee
    /// s'active elle-meme si son action ouvre une fenetre.
    func perform(_ action: AppAction, of entry: HubEntry) {
        guard let url = entry.url(for: action.id) else { return open(entry) }
        guard let app = verifiedAppURL(entry) else { return }
        NSWorkspace.shared.open([url], withApplicationAt: app, configuration: Self.inBackground)
    }

    private static var inBackground: NSWorkspace.OpenConfiguration {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false
        return configuration
    }

    /// L'app verifie et propose sa mise a jour (`<scheme>://update`) ; sans schema, elle s'ouvre
    /// (sa verification de lancement s'en charge).
    func update(_ entry: HubEntry) {
        guard let url = entry.updateURL else { return open(entry) }
        guard let app = verifiedAppURL(entry) else { return }
        NSWorkspace.shared.open([url], withApplicationAt: app, configuration: NSWorkspace.OpenConfiguration())
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
