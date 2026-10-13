#if DEBUG
import AppKit
import SwiftUI
import VialetCore

/// Mode capture sans ecran (voir SnapshotRunner) : `Vialet -VialetSnapshot <dossier>
/// [-VialetSnapshotAppearance dark] [-VialetSnapshotOnly menu,icones]`. Ecrit `menu` (le menu avec
/// des apps fictives), `icones` (planche des trois propositions d'icone de barre des menus),
/// `settings`, `about` et `update` (`-sombre` en sombre) dans le dossier, puis quitte.
extension AppDelegate {
    func runSnapshotIfRequested() -> Bool {
        guard SnapshotRequest.parse(prefix: Brand.name, arguments: CommandLine.arguments) != nil else { return false }
        HubModel.shared.preview(SnapshotPreview.listing, updates: SnapshotPreview.updates)
        let standard = SnapshotRunner.standardScenarios(mainWindow: { nil }, identity: Brand.identity)
            .filter { ["about", "update"].contains($0.name) }
        let own = [
            SnapshotScenario("menu") {
                let window = SnapshotPreview.window(HubMenu(model: HubModel.shared).fontDesign(.rounded), margin: 0)
                window.orderFrontRegardless()
                try await Task.sleep(for: .milliseconds(600))
                return window
            },
            SnapshotScenario("icones") {
                let window = SnapshotPreview.imageWindow(IconSheet.render())
                window.orderFrontRegardless()
                try await Task.sleep(for: .milliseconds(300))
                return window
            },
            SnapshotScenario("settings") {
                SettingsWindow.show()
                try await Task.sleep(for: .seconds(1))
                return SettingsWindow.current
            },
        ]
        return SnapshotRunner.runIfRequested(prefix: Brand.name, scenarios: own + standard)
    }
}

/// Apps fictives des captures : les apps de vialet.app avec des actions d'exemple, deux mises a jour
/// en attente et une app a decouvrir. Aucune donnee personnelle (chaines en echappements ASCII).
@MainActor
enum SnapshotPreview {
    static func entry(_ name: String, _ display: String, _ version: String, _ palette: AccentPalette, glyph: String,
                      strokeDeep: Bool = false, actions: [AppAction], tagline: String) -> HubEntry {
        HubEntry(bundleIdentifier: "fr.vialet.\(name.lowercased())", name: name, displayName: display, version: version,
                 appURL: URL(fileURLWithPath: "/Applications/\(name).app"), scheme: name.lowercased(),
                 repository: "avialet/\(name.lowercased())", site: URL(string: "https://\(name.lowercased()).vialet.app"),
                 palette: palette, glyph: glyph, strokeDeep: strokeDeep, actions: actions, tagline: tagline)
    }

    static let listing = HubListing(apps: [
        entry("Pico", "Pico", "0.2.0",
              AccentPalette(accent: 0xF0A020, background: 0xF0A020, deep: 0x5F3D09, pale: 0xFFEFDC, night: 0x271701, nightInk: 0xF1D2AD),
              glyph: "M 22 54 L 44 76 L 80 28", strokeDeep: true,
              actions: [AppAction("new", title: "Nouvelle t\u{00E2}che", symbol: "plus", shortcut: "\u{2318}N"),
                        AppAction("today", title: "Aujourd'hui", symbol: "sun.max")],
              tagline: "Le gestionnaire de t\u{00E2}ches qui comprend vos phrases."),
        entry("Allege", "All\u{00E8}ge", "0.2.0",
              AccentPalette(accent: 0x2E9D6E, background: 0x2E9D6E, deep: 0x012B1A, pale: 0xE1F8EB, night: 0x032114, nightInk: 0xB6E4CB),
              glyph: "M 50 16 L 50 60 M 32 42 L 50 60 L 68 42 M 24 82 L 76 82",
              actions: [AppAction("ouvrir-images", title: "All\u{00E9}ger des images", symbol: "photo.stack")],
              tagline: "All\u{00E8}ge vos images sans les envoyer nulle part."),
        entry("Pince", "Pince", "0.2.1",
              AccentPalette(accent: 0x2F6FEB, background: 0x2F6FEB, deep: 0x00001F, pale: 0xEBF2FF, night: 0x0F1A2F, nightInk: 0xC4D8FD),
              glyph: "M 20 18 L 40 50 L 20 82 M 80 18 L 60 50 L 80 82",
              actions: [AppAction("historique", title: "Historique", symbol: "clock")],
              tagline: "Gardez plusieurs copies sous la main."),
        entry("Brouillon", "Brouillon", "0.3.0",
              AccentPalette(accent: 0x8B78E6, background: 0x8B78E6, deep: 0x261455, pale: 0xF1F0FF, night: 0x1A172E, nightInk: 0xD5D2FD),
              glyph: "M 18 70 C 28 34 40 34 50 54 C 60 74 72 74 82 40",
              actions: [AppAction("new", title: "Nouvelle note", symbol: "square.and.pencil", shortcut: "\u{2318}N")],
              tagline: "Le bloc-notes qui comprend ce que vous y collez."),
        entry("Chuchote", "Chuchote", "0.1.1",
              AccentPalette(accent: 0xD9486B, background: 0xD9486B, deep: 0x2F000D, pale: 0xFFEDEF, night: 0x2C1116, nightInk: 0xFCC8CE),
              glyph: "M 20 46 V 54 M 35 30 V 70 M 50 40 V 60 M 65 22 V 78 M 80 42 V 58",
              actions: [AppAction("dicter", title: "Dicter", symbol: "mic")],
              tagline: "Parlez, c'est \u{00E9}crit l\u{00E0} o\u{00F9} est le curseur."),
    ], discover: [
        CatalogEntry(name: "Prochaine app", brand: "Prochaine", url: URL(string: "https://vialet.app"),
                     tagline: "Une app fictive, pour l'aper\u{00E7}u.", status: "available"),
    ])

    static let updates: [String: SemanticVersion] = [
        "fr.vialet.brouillon": SemanticVersion(0, 3, 1),
        "fr.vialet.chuchote": SemanticVersion(0, 2, 0),
    ]

    /// Fenetre transparente sans bord autour de `view` (coins arrondis du menu conserves).
    static func window<V: View>(_ view: V, margin: CGFloat) -> NSWindow {
        let host = NSHostingView(rootView: view.padding(margin))
        host.frame = NSRect(origin: .zero, size: host.fittingSize)
        let window = NSWindow(contentRect: host.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.backgroundColor = .clear
        window.isOpaque = false
        window.contentView = host
        window.setFrameOrigin(NSPoint(x: 80, y: 80))
        return window
    }

    static func imageWindow(_ image: NSImage) -> NSWindow {
        let view = NSImageView(image: image)
        view.imageScaling = .scaleNone
        view.frame = NSRect(origin: .zero, size: image.size)
        let window = NSWindow(contentRect: view.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.backgroundColor = .white
        window.contentView = view
        window.setFrameOrigin(NSPoint(x: 80, y: 80))
        return window
    }
}

/// Planche des icones de barre des menus : pour chaque proposition, barre claire puis sombre, sans
/// puis avec le point de mise a jour ; dans chaque case, 1x agrandi 4 fois (pixels), 2x agrandi 2 fois,
/// puis 2x et 1x a taille reelle. En bas, la retenue en situation, parmi des symboles systeme.
@MainActor
enum IconSheet {
    static let lightBar = NSColor(srgbRed: 0.93, green: 0.93, blue: 0.94, alpha: 1)
    static let darkBar = NSColor(srgbRed: 0.16, green: 0.16, blue: 0.17, alpha: 1)
    static let lightInk = NSColor(white: 0, alpha: 0.85)
    static let darkInk = NSColor(white: 1, alpha: 0.9)
    static let coral = NSColor(hex: 0xEC6A5C)

    /// Planche en points (rendue a 2x par la capture).
    static func render() -> NSImage {
        let variants = StatusIcon.Variant.allCases
        let rowH: CGFloat = 132, top: CGFloat = 56, situation: CGFloat = 150
        let width: CGFloat = 1240
        let height = top + rowH * CGFloat(variants.count) + situation
        return NSImage(size: NSSize(width: width, height: height), flipped: true) { _ in
            NSColor.white.setFill()
            NSRect(x: 0, y: 0, width: width, height: height).fill()
            text("Ic\u{00F4}ne de barre des menus : trois propositions", at: NSPoint(x: 24, y: 16), size: 20, weight: .bold)
            for (row, variant) in variants.enumerated() {
                let y = top + CGFloat(row) * rowH
                let chosen = variant == StatusIcon.Variant.chosen
                text(label(variant) + (chosen ? "  (retenue)" : ""), at: NSPoint(x: 24, y: y + 6), size: 14, weight: .semibold)
                var x: CGFloat = 24
                for dark in [false, true] {
                    for dot in [false, true] {
                        cell(variant, dark: dark, dot: dot, in: NSRect(x: x, y: y + 30, width: 290, height: 92))
                        x += 298
                    }
                }
            }
            let y = top + CGFloat(variants.count) * rowH
            text("En situation (taille r\u{00E9}elle)", at: NSPoint(x: 24, y: y + 6), size: 14, weight: .semibold)
            strip(dark: false, in: NSRect(x: 24, y: y + 34, width: 590, height: 30))
            strip(dark: true, in: NSRect(x: 626, y: y + 34, width: 590, height: 30))
            strip(dark: false, dot: true, in: NSRect(x: 24, y: y + 80, width: 590, height: 30))
            strip(dark: true, dot: true, in: NSRect(x: 626, y: y + 80, width: 590, height: 30))
            return true
        }
    }

    private static func label(_ v: StatusIcon.Variant) -> String {
        switch v {
        case .secteurs: "A. Secteurs (plaque d\u{00E9}coup\u{00E9}e)"
        case .tons: "B. Tons (plaque du hub en monochrome)"
        case .grille: "C. Grille de plaques"
        }
    }

    private static func cell(_ v: StatusIcon.Variant, dark: Bool, dot: Bool, in rect: NSRect) {
        (dark ? darkBar : lightBar).setFill()
        NSBezierPath(roundedRect: rect, xRadius: 8, yRadius: 8).fill()
        let ink = dark ? darkInk : lightInk
        let image = StatusIcon.image(v, notched: dot)
        let midY = rect.midY
        // 1x agrandi 4 fois, 2x agrandi 2 fois : 72 pt chacun.
        draw(image, scale: 1, ink: ink, dot: dot, in: NSRect(x: rect.minX + 12, y: midY - 36, width: 72, height: 72))
        draw(image, scale: 2, ink: ink, dot: dot, in: NSRect(x: rect.minX + 100, y: midY - 36, width: 72, height: 72))
        // Taille reelle : 18 pt (2x), puis le rendu 1x en 18 pt.
        draw(image, scale: 2, ink: ink, dot: dot, in: NSRect(x: rect.minX + 196, y: midY - 9, width: 18, height: 18))
        draw(image, scale: 1, ink: ink, dot: dot, in: NSRect(x: rect.minX + 240, y: midY - 9, width: 18, height: 18))
    }

    /// Rend le gabarit a `scale` pixels par point, le teinte comme la barre des menus, pose le point
    /// de mise a jour, puis l'affiche dans `rect` sans lissage (pixels visibles).
    private static func draw(_ image: NSImage, scale: Int, ink: NSColor, dot: Bool, in rect: NSRect) {
        let px = Int(StatusIcon.pointSize) * scale
        guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
                                         samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                                         bytesPerRow: 0, bitsPerPixel: 0) else { return }
        rep.size = NSSize(width: StatusIcon.pointSize, height: StatusIcon.pointSize)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        let r = NSRect(x: 0, y: 0, width: StatusIcon.pointSize, height: StatusIcon.pointSize)
        image.draw(in: r)
        ink.set()
        r.fill(using: .sourceIn)
        if dot {
            coral.setFill()
            let d = StatusIcon.dotDiameter
            NSBezierPath(ovalIn: NSRect(x: StatusIcon.dotCenter.x - d / 2, y: StatusIcon.dotCenter.y - d / 2, width: d, height: d)).fill()
        }
        NSGraphicsContext.restoreGraphicsState()
        let out = NSImage(size: rep.size)
        out.addRepresentation(rep)
        NSGraphicsContext.current?.imageInterpolation = .none
        out.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
        NSGraphicsContext.current?.imageInterpolation = .default
    }

    /// Bande de barre des menus : quelques symboles systeme puis l'icone retenue, a taille reelle.
    private static func strip(dark: Bool, dot: Bool = false, in rect: NSRect) {
        (dark ? darkBar : lightBar).setFill()
        rect.fill()
        let ink = dark ? darkInk : lightInk
        var x = rect.maxX - 16
        let symbols = ["clock", "magnifyingglass", "switch.2", "wifi", "battery.75percent"]
        for name in symbols {
            guard let symbol = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
                .withSymbolConfiguration(.init(pointSize: 14, weight: .regular)) else { continue }
            let size = symbol.size
            x -= size.width
            let tinted = NSImage(size: size, flipped: false) { r in
                symbol.draw(in: r); ink.set(); r.fill(using: .sourceIn); return true
            }
            tinted.draw(in: NSRect(x: x, y: rect.midY - size.height / 2, width: size.width, height: size.height),
                        from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
            x -= 18
        }
        x -= StatusIcon.pointSize
        let icon = StatusIcon.image(notched: dot)
        let tinted = NSImage(size: icon.size, flipped: false) { r in
            icon.draw(in: r); ink.set(); r.fill(using: .sourceIn)
            if dot {
                coral.setFill()
                let d = StatusIcon.dotDiameter
                NSBezierPath(ovalIn: NSRect(x: StatusIcon.dotCenter.x - d / 2, y: StatusIcon.dotCenter.y - d / 2, width: d, height: d)).fill()
            }
            return true
        }
        tinted.draw(in: NSRect(x: x, y: rect.midY - 9, width: 18, height: 18),
                    from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
        text(dark ? "sombre" : "clair", at: NSPoint(x: rect.minX + 10, y: rect.minY + 7), size: 11, weight: .medium,
             color: dark ? .lightGray : .darkGray)
    }

    private static func text(_ s: String, at point: NSPoint, size: CGFloat, weight: NSFont.Weight, color: NSColor = .black) {
        NSAttributedString(string: s, attributes: [.font: NSFont.systemFont(ofSize: size, weight: weight),
                                                   .foregroundColor: color]).draw(at: point)
    }
}
#endif
