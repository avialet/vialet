import AppKit
import VialetCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        AppearanceChoice.current(defaultsKey: Brand.key("Appearance")).apply(defaultsKey: Brand.key("Appearance"))
        #if DEBUG
        // Mode capture : ni icone, ni raccourci, ni reseau.
        if runSnapshotIfRequested() { return }
        #endif
        StatusItemController.shared.install()
        HubModel.shared.start()
        if UserDefaults.standard.bool(forKey: Brand.key("HotKeyEnabled")) { VialetHotKey.apply(true) }
        // Les apps re-evaluent leur icone de barre des menus (masquee tant que Vialet est installee).
        MenuBarPresence.postHubChanged()
        // Laisse l'app s'afficher avant le moindre appel reseau.
        DispatchQueue.main.asyncAfter(deadline: .now() + 6) {
            MainActor.assumeIsolated {
                // Apres une mise a jour de Vialet, pas de bandeau de nouveautes (pas de fenetre) : vu.
                Updater.shared.acknowledgeUpdate()
                Updater.shared.checkAutomatically()
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        MenuBarPresence.postHubChanged()
    }

    /// Liens `vialet://` : ouvre le menu.
    func application(_ application: NSApplication, open urls: [URL]) {
        StatusItemController.shared.open()
    }

    /// Relancer Vialet deja ouverte (Finder, Spotlight) : ouvre le menu.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        StatusItemController.shared.open()
        return true
    }

    /// Menu de l'app (invisible pour une app de barre des menus) : ses raccourcis servent aux reglages.
    static func makeMainMenu() -> NSMenu {
        let main = NSMenu()
        let appItem = NSMenuItem()
        let appMenu = NSMenu(title: Brand.displayName)
        appMenu.addItem(withTitle: "\u{00C0} propos de Vialet", action: #selector(AppDelegate.showAbout), keyEquivalent: "")
        appMenu.addItem(withTitle: "R\u{00E9}glages\u{2026}", action: #selector(AppDelegate.showSettings), keyEquivalent: ",")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Fermer la fen\u{00EA}tre", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        appMenu.addItem(withTitle: "Quitter Vialet", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        main.addItem(appItem)
        return main
    }

    @objc func showAbout() { AboutPanel.show(Brand.identity) }
    @objc func showSettings() { SettingsWindow.show() }
}
