import Foundation
import Observation
import VialetCore

/// Etat partage de l'app.
@MainActor
@Observable
final class AppState {
    static let shared = AppState()
    private init() {}
}
