import SwiftUI

/// Liquid Glass on macOS 26, the closest classic look before. Every use of a macOS 26 API in
/// MenuBarKit goes through these helpers, so the package builds and runs on macOS 14.
extension View {
    /// A glass button on macOS 26, a bordered one before.
    @ViewBuilder
    func menuBarButtonStyle() -> some View {
        if #available(macOS 26.0, *) {
            buttonStyle(.glass)
        } else {
            buttonStyle(.bordered)
        }
    }

    /// A prominent glass button on macOS 26, a bordered prominent one before.
    @ViewBuilder
    func menuBarProminentButtonStyle() -> some View {
        if #available(macOS 26.0, *) {
            buttonStyle(.glassProminent)
        } else {
            buttonStyle(.borderedProminent)
        }
    }
}
