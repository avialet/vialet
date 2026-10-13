import SwiftUI
import VialetKit

/// Identite de l'app : le seul fichier Swift qui connait son nom, ses teintes et son glyphe.
enum Brand {
    static let name = "Vialet"
    static let displayName = "Vialet"
    /// Teintes de vialet.app elle-meme : papier et encre du hub (fond #F7F3EC, texte #1E2227 ; en sombre
    /// #14161B et #EDE9E2), les couleurs restant aux plaques des apps. Accent : l'encre douce #6A6E75,
    /// neutre et lisible en clair comme en sombre (contraste 4,6 sur le papier, 3,0 sur une carte sombre),
    /// la ou l'encre #1E2227 disparaitrait en sombre (1,1). Une teinte par ligne `cle: 0x...`.
    static let palette = AccentPalette(accent: 0x6A6E75, background: 0xF7F3EC,
                                       deep: 0x1E2227, pale: 0xF7F3EC,
                                       night: 0x14161B, nightInk: 0xEDE9E2)
    /// Pas de glyphe : l'icone de Vialet est la plaque du hub (un secteur par app, `make icon`).
    static let glyph = ""
    static let strokeDeep = false
    static let identity = AppIdentity(name: name, displayName: displayName, repository: "avialet/vialet",
                                      bundleIdentifier: "fr.vialet.vialet", palette: palette, glyph: glyph,
                                      strokeDeep: strokeDeep, site: URL(string: "https://vialet.app")!)
    static let updater = UpdaterConfiguration(identity)

    /// Cles UserDefaults, prefixees par le nom de l'app.
    static func key(_ suffix: String) -> String { identity.key(suffix) }
}

extension Updater {
    static let shared = Updater(configuration: Brand.updater)
}

extension HotKeyController {
    /// Raccourci facultatif (coupe par defaut) qui ouvre le menu. Deja pris : ⇧⌘Espace (Pico), ⌃⌥⌘Espace
    /// (Allege), ⌃⇧Espace (Pince), ⌥⇧Espace (Brouillon), ⌃⌥Espace (Chuchote).
    static let shared = HotKeyController(defaultsKey: Brand.key("HotKey"), logName: Brand.displayName,
                                         initial: .space([.control, .option, .shift]))
}
