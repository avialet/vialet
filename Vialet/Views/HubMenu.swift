import SwiftUI
import VialetCore

/// Le menu de Vialet : la plaque du hub et « vialet.app » en tete, une ligne par app installee
/// (sa plaque, son nom en Bricolage, ses actions rapides, sa mise a jour), les apps a decouvrir,
/// puis le site, les reglages et Quitter. Au papier et a l'encre de vialet.app.
struct HubMenu: View {
    static let width: CGFloat = 330
    /// Au-dela, la liste defile (hauteur fixe).
    static let maxRowsWithoutScroll = 8

    let model: HubModel
    var onSizeChange: () -> Void = {}
    @AppStorage(Brand.key("ShowDiscover")) private var showDiscover = true

    private var discover: [CatalogEntry] { showDiscover ? model.listing.discover : [] }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            UpdateBanner(updater: Updater.shared).padding(.horizontal, -6)
            list
            Divider().overlay(Theme.line).padding(.vertical, 6)
            footer
        }
        .padding(6)
        .frame(width: Self.width)
        .background(Theme.paper, in: shape)
        .overlay(shape.strokeBorder(Theme.line, lineWidth: 1))
        .clipShape(shape)
        .onChange(of: model.listing) { onSizeChange() }
        .onChange(of: model.updates) { onSizeChange() }
        .onChange(of: showDiscover) { onSizeChange() }
    }

    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: 14, style: .continuous) }

    // MARK: Tete

    private var header: some View {
        HStack(spacing: 9) {
            Image(nsImage: hubPlate).resizable().interpolation(.high).frame(width: 22, height: 22)
                .accessibilityHidden(true)
            Text(verbatim: "vialet.app")
                .font(Theme.display(17))
                .foregroundStyle(Theme.ink)
            Spacer(minLength: 8)
            let count = model.pendingUpdates.count
            if count > 0 {
                Text(count == 1 ? "1 mise \u{00E0} jour" : "\(count) mises \u{00E0} jour")
                    .font(Theme.ui(11.5, weight: .semibold))
                    .foregroundStyle(Theme.coral)
            }
        }
        .padding(.horizontal, 10)
        .padding(.top, 8)
        .padding(.bottom, 10)
    }

    /// Un secteur par app listee (comme le logo du hub) ; sans fiche connue, l'icone de Vialet.
    private var hubPlate: NSImage {
        let palettes = model.palettes
        return palettes.isEmpty ? PlateImage.cropped(NSApp.applicationIconImage, pixels: 44)
                                : HubPlate.image(palettes, pixels: 44)
    }

    // MARK: Liste

    @ViewBuilder
    private var list: some View {
        let rows = model.listing.apps.count + discover.count
        if rows > Self.maxRowsWithoutScroll {
            ScrollView { rowsStack }.frame(height: 470).scrollIndicators(.automatic)
        } else {
            rowsStack
        }
    }

    private var rowsStack: some View {
        VStack(alignment: .leading, spacing: 2) {
            if model.listing.apps.isEmpty {
                Text("Aucune app vialet.app sur ce Mac pour l'instant.")
                    .font(Theme.ui(12.5)).foregroundStyle(Theme.inkSoft)
                    .padding(.horizontal, 10).padding(.vertical, 8)
            }
            ForEach(model.listing.apps) { entry in
                AppRow(entry: entry, plate: model.plate(for: entry),
                       update: model.pendingUpdates.contains(entry) ? model.updates[entry.bundleIdentifier] : nil,
                       model: model)
            }
            if !discover.isEmpty {
                SectionHeader("\u{00C0} d\u{00E9}couvrir")
                    .padding(.horizontal, 10).padding(.top, 12).padding(.bottom, 4)
                ForEach(discover, id: \.brand) { DiscoverRow(entry: $0, model: model) }
            }
        }
    }

    // MARK: Pied

    private var footer: some View {
        VStack(alignment: .leading, spacing: 0) {
            MenuLine("Toutes les apps sur vialet.app", trailingSymbol: "arrow.up.right") {
                StatusItemController.shared.run { HubModel.shared.openSite(Brand.identity.siteURL) }
            }
            MenuLine("R\u{00E9}glages\u{2026}", shortcut: "\u{2318},") {
                StatusItemController.shared.run { SettingsWindow.show() }
            }
            .keyboardShortcut(",", modifiers: .command)
            MenuLine("Quitter Vialet", shortcut: "\u{2318}Q") { NSApp.terminate(nil) }
                .keyboardShortcut("q", modifiers: .command)
        }
    }
}

// MARK: - Ligne d'app

private struct AppRow: View {
    let entry: HubEntry
    let plate: NSImage
    let update: SemanticVersion?
    let model: HubModel
    @State private var hover = false

    var body: some View {
        HStack(alignment: .top, spacing: 11) {
            Image(nsImage: plate).resizable().interpolation(.high)
                .frame(width: 30, height: 30)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(entry.displayName)
                        .font(Theme.display(15.5))
                        .foregroundStyle(Theme.ink)
                    Spacer(minLength: 6)
                    Text(entry.version)
                        .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                        .foregroundStyle(Theme.inkFaint)
                }
                if !entry.actions.isEmpty {
                    FlowLayout(spacing: 5) {
                        ForEach(entry.actions, id: \.id) { action in
                            ActionChip(action: action, palette: entry.palette) {
                                StatusItemController.shared.run { HubModel.shared.perform(action, of: entry) }
                            }
                        }
                    }
                } else if let tagline = entry.tagline {
                    Text(tagline).font(Theme.ui(12)).foregroundStyle(Theme.inkSoft).lineLimit(1)
                }
                if let update {
                    UpdateLink(version: update) {
                        StatusItemController.shared.run { HubModel.shared.update(entry) }
                    }
                }
            }
            .padding(.top, 2)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.row, style: .continuous)
            .fill(hover ? rowTint : .clear))
        .contentShape(Rectangle())
        .onHover { hover = $0 }
        .onTapGesture { StatusItemController.shared.run { HubModel.shared.open(entry) } }
        .help("Ouvrir \(entry.displayName)")
        .accessibilityElement(children: .contain)
        .accessibilityLabel(entry.displayName)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(named: "Ouvrir \(entry.displayName)") { HubModel.shared.open(entry) }
    }

    /// Survol : le fond pale de l'app en clair, sa nuit en sombre (comme ses sites).
    private var rowTint: Color {
        guard let p = entry.palette else { return Theme.ink.opacity(0.06) }
        return Color(light: p.pale, dark: p.night)
    }
}

/// Action rapide : pastille discrete, aux couleurs de l'affiche de l'app au survol.
private struct ActionChip: View {
    let action: AppAction
    let palette: AccentPalette?
    let perform: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: perform) {
            HStack(spacing: 4) {
                Image(systemName: action.symbol).font(.system(size: 10, weight: .bold))
                Text(action.title).font(Theme.ui(11.5, weight: .semibold))
            }
            .foregroundStyle(hover ? deep : Theme.inkSoft)
            .padding(.horizontal, 8).padding(.vertical, 3.5)
            .background(Capsule().fill(hover ? background : Theme.ink.opacity(0.06)))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
        .help(action.shortcut.map { "\(action.title) (\($0) dans l'app)" } ?? action.title)
    }

    /// La paire de l'affiche de l'app : texte `deep` sur `background` (contraste >= 4,5).
    private var background: Color { palette.map { Color(hex: $0.background) } ?? Theme.ink.opacity(0.12) }
    private var deep: Color { palette.map { Color(hex: $0.deep) } ?? Theme.ink }
}

/// « Mise a jour X.Y.Z disponible » : l'app la verifie et la propose (`<nom>://update`).
private struct UpdateLink: View {
    let version: SemanticVersion
    let perform: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: perform) {
            HStack(spacing: 6) {
                Circle().fill(Theme.coral).frame(width: 6, height: 6)
                Text("Mise \u{00E0} jour \(version.description) disponible")
                    .font(Theme.ui(11.5, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    .underline(hover)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
        .help("Ouvrir l'app et installer la mise \u{00E0} jour")
    }
}

// MARK: - A decouvrir

private struct DiscoverRow: View {
    let entry: CatalogEntry
    let model: HubModel
    @State private var hover = false

    var body: some View {
        HStack(alignment: .center, spacing: 11) {
            GhostPlate(initial: String(entry.name.prefix(1))).frame(width: 30, height: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.name).font(Theme.display(14.5, weight: .semibold)).foregroundStyle(Theme.inkSoft)
                if !entry.tagline.isEmpty {
                    Text(entry.tagline).font(Theme.ui(11.5)).foregroundStyle(Theme.inkFaint).lineLimit(1)
                }
            }
            Spacer(minLength: 6)
            Image(systemName: "arrow.up.right").font(.system(size: 10, weight: .bold)).foregroundStyle(Theme.inkFaint)
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.row, style: .continuous)
            .fill(hover ? Theme.ink.opacity(0.06) : .clear))
        .contentShape(Rectangle())
        .onHover { hover = $0 }
        .onTapGesture { StatusItemController.shared.run { HubModel.shared.openSite(entry.url) } }
        .help(entry.url.map { "Ouvrir \($0.host() ?? $0.absoluteString)" } ?? entry.name)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isLink)
    }
}

/// Plaque en pointilles d'une app pas encore installee, son initiale au centre.
private struct GhostPlate: View {
    let initial: String

    var body: some View {
        GeometryReader { geo in
            let side = geo.size.width
            ZStack {
                RoundedRectangle(cornerRadius: side * 185 / 824, style: .circular)
                    .strokeBorder(Theme.inkFaint, style: StrokeStyle(lineWidth: 1.2, dash: [3, 2.4]))
                Text(initial).font(Theme.display(side * 0.46)).foregroundStyle(Theme.inkFaint)
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Ligne de menu

private struct MenuLine: View {
    let title: String
    let shortcut: String?
    let trailingSymbol: String?
    let action: () -> Void
    @State private var hover = false

    init(_ title: String, shortcut: String? = nil, trailingSymbol: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.shortcut = shortcut
        self.trailingSymbol = trailingSymbol
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack {
                Text(title).font(Theme.ui(13)).foregroundStyle(Theme.ink)
                Spacer(minLength: 8)
                if let shortcut {
                    Text(shortcut).font(Theme.ui(12)).foregroundStyle(Theme.inkFaint)
                }
                if let trailingSymbol {
                    Image(systemName: trailingSymbol).font(.system(size: 10, weight: .bold)).foregroundStyle(Theme.inkFaint)
                }
            }
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(hover ? Theme.ink.opacity(0.07) : .clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
    }
}

// MARK: - Plaque recadree

enum PlateImage {
    /// Icone d'app (plaque a 824/1024 avec ombre) recadree a sa plaque, en `pixels` de cote.
    static func cropped(_ icon: NSImage, pixels: Int) -> NSImage {
        let side = CGFloat(pixels)
        let image = NSImage(size: NSSize(width: side, height: side), flipped: false) { rect in
            let radius = side * 185 / 824
            NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).addClip()
            let scale = 1024.0 / 824.0
            let drawn = rect.insetBy(dx: -side * (scale - 1) / 2, dy: -side * (scale - 1) / 2)
            icon.draw(in: drawn, from: .zero, operation: .sourceOver, fraction: 1)
            return true
        }
        return image
    }
}
