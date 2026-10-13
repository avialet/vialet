import SwiftUI
import VialetKit

/// Identite de l'app : le seul fichier Swift qui connait son nom, ses teintes et son glyphe.
enum Brand {
    static let name = "Vialet"
    static let displayName = "Vialet"
    /// Teintes de l'affiche (sites, plaques, DMG, interface), calculees par scripts/teintes.py :
    /// texte `deep` sur `background`. Une teinte par ligne `cle: 0x...` (lue par les scripts du socle).
    static let palette = AccentPalette(accent: 0x6A6E75, background: 0x73777E,
                                       deep: 0x05060B, pale: 0xEBF2FF,
                                       night: 0x0F1A2F, nightInk: 0xC4D8FD)
    /// Pictogramme de la plaque : sous-ensemble SVG absolu (M L H V C Q Z), boite 0-100, trait non rempli.
    /// Vide = initiale en repli. Dessiner le trace, verifier avec `swift ../scripts/plaque.swift planche`, puis `make icon`.
    static let glyph = ""
    /// Trait du glyphe en `deep` plutot qu'en blanc (accent trop clair pour un trait blanc).
    static let strokeDeep = false
    static let identity = AppIdentity(name: name, displayName: displayName, repository: "avialet/vialet",
                                      bundleIdentifier: "fr.vialet.vialet", palette: palette, glyph: glyph,
                                      strokeDeep: strokeDeep)
    static let updater = UpdaterConfiguration(identity)

    /// Cles UserDefaults, prefixees par le nom de l'app.
    static func key(_ suffix: String) -> String { identity.key(suffix) }
}

extension Updater {
    static let shared = Updater(configuration: Brand.updater)
}

extension HotKeyController {
    /// Choisir un raccourci libre : ⇧⌘Espace (Pico), ⌃⌥⌘Espace (Allege), ⌃⇧Espace (Pince) et ⌥⇧Espace (Brouillon)
    /// sont deja pris. Mettre a jour la ligne « Raccourci global » du README.
    static let shared = HotKeyController(defaultsKey: Brand.key("HotKey"), logName: Brand.displayName,
                                         initial: .space([.control, .option, .shift]))
}
