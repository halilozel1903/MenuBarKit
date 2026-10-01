import MenuBarKit
import SwiftUI

/// The settings window: General, Shortcuts and About.
struct TempoSettings: View {
    let model: AppModel
    var selection: SettingsTab = .general
    @ObservedObject private var timer: FocusTimer
    @AppStorage("focusMinutes") private var focusMinutes = 25
    @AppStorage("checksForUpdates") private var checksForUpdates = true

    init(model: AppModel, selection: SettingsTab = .general) {
        self.model = model
        self.selection = selection
        self._timer = ObservedObject(wrappedValue: model.timer)
    }

    var body: some View {
        SettingsPane(selection: selection, about: DemoContent.about) {
            Section("Timer") {
                Stepper("Focus length: \(focusMinutes) min", value: $focusMinutes, in: 5...90, step: 5)
                Toggle("Play a sound when a session ends", isOn: $timer.playsSound)
                Toggle("Show the time in the menu bar", isOn: $timer.showsTimeInMenuBar)
            }
            Section("Updates") {
                Toggle("Check for updates automatically", isOn: $checksForUpdates)
                Button("Check Now") {
                    Task { await model.updates.checkForUpdates(userInitiated: true) }
                }
            }
        } shortcuts: {
            ShortcutSettingRow("Start or pause the timer", shortcut: model.toggleShortcut)
            ShortcutSettingRow("Reset the timer", shortcut: model.resetShortcut)
        }
    }
}
