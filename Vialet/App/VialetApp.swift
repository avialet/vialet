import AppKit
import VialetKit

/// Vialet n'est qu'une icone de barre des menus (LSUIElement) : pas de scene SwiftUI, une app AppKit
/// dont le delegue pose l'icone, le menu et les reglages.
@main
@MainActor
enum VialetApp {
    static func main() {
        // Teintes de vialet.app avant le premier rendu (et police Bricolage Grotesque des titres).
        Theme.configure(Brand.palette)
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.mainMenu = AppDelegate.makeMainMenu()
        withExtendedLifetime(delegate) { app.run() }
    }
}
