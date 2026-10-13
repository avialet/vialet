import SwiftUI
import VialetKit

/// Reglages : raccourci facultatif qui ouvre le menu, ouverture a la connexion, mises a jour,
/// apparence, puis le contenu du menu. Pas de ligne « Icone dans la barre des menus » : Vialet
/// n'est que cette icone.
struct SettingsView: View {
    @AppStorage(Brand.key("HotKeyEnabled")) private var hotKeyEnabled = false
    @AppStorage(Brand.key("ShowDiscover")) private var showDiscover = true

    var body: some View {
        SettingsScreen(app: Brand.identity, hotKey: HotKeyController.shared, updater: Updater.shared,
                       menuBar: nil, hotKeyEnabled: $hotKeyEnabled,
                       hotKeyHint: "Depuis n'importe quelle app : ouvre le menu de Vialet.",
                       alwaysOnHint: "Vialet vit dans la barre des menus, sans fen\u{00EA}tre ni ic\u{00F4}ne dans le Dock. Quitter Vialet depuis son menu.",
                       updateNote: "\u{00C9}changes r\u{00E9}seau de Vialet : la derni\u{00E8}re version publi\u{00E9}e sur GitHub de Vialet et de vos apps vialet.app, et le catalogue de vialet.app une fois par jour. Aucune donn\u{00E9}e n'est envoy\u{00E9}e.") {
            SettingsCard(icon: "square.grid.2x2", color: Theme.sun, title: "Menu") {
                Toggle("Proposer les apps \u{00E0} d\u{00E9}couvrir", isOn: $showDiscover)
                Text("Les apps vialet.app masquent leur propre ic\u{00F4}ne quand Vialet est install\u{00E9}e. Pour la retrouver : R\u{00E9}glages de l'app \u{203A} Ic\u{00F4}ne dans la barre des menus.")
                    .font(Theme.ui(12)).foregroundStyle(Theme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .onChange(of: hotKeyEnabled) { _, on in VialetHotKey.apply(on) }
    }
}

/// Le raccourci global de Vialet, facultatif : ouvre ou ferme le menu.
@MainActor
enum VialetHotKey {
    static func apply(_ enabled: Bool) {
        if enabled {
            HotKeyController.shared.start { StatusItemController.shared.toggle() }
        } else {
            HotKeyController.shared.suspend()
        }
    }
}

/// Fenetre des reglages, ouverte depuis le menu (Vialet n'a pas de scene Settings : app de barre des menus).
@MainActor
enum SettingsWindow {
    private static var window: NSWindow?

    static func show() {
        let window = self.window ?? make()
        self.window = window
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }

    static var current: NSWindow? { window }

    private static func make() -> NSWindow {
        let host = NSHostingView(rootView: SettingsView())
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: host.fittingSize),
                              styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "R\u{00E9}glages de Vialet"
        window.identifier = NSUserInterfaceItemIdentifier("VialetSettings")
        window.isReleasedWhenClosed = false
        window.contentView = host
        window.setContentSize(host.fittingSize)
        window.center()
        return window
    }
}
