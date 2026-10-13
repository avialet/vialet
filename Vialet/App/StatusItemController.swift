import AppKit
import SwiftUI
import VialetCore

/// L'icone de Vialet dans la barre des menus et son menu : un panneau sous l'icone, au papier de
/// vialet.app, ferme par Echap, un clic ailleurs ou un second clic sur l'icone.
@MainActor
final class StatusItemController {
    static let shared = StatusItemController()

    private var item: NSStatusItem?
    private let dot = CALayer()
    private var panel: FloatingPanel?
    private var host: NSHostingView<AnyView>?
    /// Fermeture par perte du focus juste avant un clic sur l'icone : ce clic ne rouvre pas.
    private var lastDismiss = Date.distantPast
    private var observation: Task<Void, Never>?

    var isOpen: Bool { panel?.isVisible == true }

    func install() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.behavior = []
        item.autosaveName = "Vialet"
        if let button = item.button {
            button.image = StatusIcon.image()
            button.imagePosition = .imageOnly
            button.toolTip = "vialet.app"
            button.setAccessibilityLabel("Vialet")
            button.target = self
            button.action = #selector(clicked)
            button.sendAction(on: [.leftMouseDown, .rightMouseDown])
            button.wantsLayer = true
            dot.backgroundColor = NSColor(hex: 0xEC6A5C).cgColor
            dot.cornerRadius = StatusIcon.dotDiameter / 2
            dot.isHidden = true
            button.layer?.addSublayer(dot)
        }
        self.item = item
        trackUpdates()
    }

    /// Point de mise a jour : l'icone s'encoche, un point corail s'y pose (`Theme.coral`, la couleur
    /// des mises a jour dans les reglages des apps).
    private func trackUpdates() {
        withObservationTracking {
            setDot(HubModel.shared.hasPendingUpdate)
        } onChange: {
            Task { @MainActor in StatusItemController.shared.trackUpdates() }
        }
    }

    private func setDot(_ on: Bool) {
        guard let button = item?.button else { return }
        button.image = StatusIcon.image(notched: on)
        button.setAccessibilityLabel(on ? "Vialet, mise \u{00E0} jour disponible" : "Vialet")
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        dot.isHidden = !on
        // L'image (18 pt) est centree dans le bouton ; le point suit son coin haut droit.
        let bounds = button.bounds
        let origin = CGPoint(x: (bounds.width - StatusIcon.pointSize) / 2, y: (bounds.height - StatusIcon.pointSize) / 2)
        let d = StatusIcon.dotDiameter
        let centerY = button.isFlipped ? origin.y + (StatusIcon.pointSize - StatusIcon.dotCenter.y)
                                       : origin.y + StatusIcon.dotCenter.y
        dot.frame = CGRect(x: origin.x + StatusIcon.dotCenter.x - d / 2, y: centerY - d / 2, width: d, height: d)
        CATransaction.commit()
    }

    @objc private func clicked() { toggle() }

    func toggle() {
        if isOpen { close(); return }
        guard Date().timeIntervalSince(lastDismiss) > 0.3 else { return }
        open()
    }

    func open() {
        HubModel.shared.reload()
        let panel = self.panel ?? makePanel()
        self.panel = panel
        resize()
        panel.alphaValue = 1
        panel.makeKeyAndOrderFront(nil)
        item?.button?.highlight(true)
    }

    func close() {
        guard let panel, panel.isVisible else { return }
        lastDismiss = Date()
        panel.orderOut(nil)
        item?.button?.highlight(false)
    }

    /// Ferme le menu, puis lance `action` (ouvrir une app, un lien...).
    func run(_ action: @escaping @MainActor () -> Void) {
        close()
        DispatchQueue.main.async { MainActor.assumeIsolated { action() } }
    }

    private func makePanel() -> FloatingPanel {
        let panel = FloatingPanel(size: CGSize(width: HubMenu.width, height: 200))
        panel.level = .popUpMenu
        panel.isMovableByWindowBackground = false
        panel.hasShadow = true
        panel.onDismiss = { [weak self] in self?.close() }
        let host = NSHostingView(rootView: AnyView(HubMenu(model: HubModel.shared, onSizeChange: { [weak self] in
            self?.resize()
        }).fontDesign(.rounded)))
        panel.contentView = host
        self.host = host
        return panel
    }

    /// Taille ideale du contenu, sous l'icone (bord gauche aligne, comme un menu), dans l'ecran.
    private func resize() {
        guard let panel, let host else { return }
        host.layoutSubtreeIfNeeded()
        let size = host.fittingSize
        var origin = CGPoint(x: 0, y: 0)
        if let window = item?.button?.window {
            let anchor = window.frame
            let screen = window.screen ?? NSScreen.main
            let visible = screen?.visibleFrame ?? anchor
            origin.x = min(max(anchor.minX - 6, visible.minX + 6), visible.maxX - size.width - 6)
            origin.y = max(anchor.minY - 5 - size.height, visible.minY + 6)
        } else if let visible = NSScreen.main?.visibleFrame {
            origin = CGPoint(x: visible.maxX - size.width - 12, y: visible.maxY - size.height - 6)
        }
        panel.setFrame(NSRect(origin: origin, size: size), display: true)
        panel.invalidateShadow()
    }
}
