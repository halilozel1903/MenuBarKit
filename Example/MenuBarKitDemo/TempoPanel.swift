import MenuBarKit
import SwiftUI

/// The window that opens from the menu bar item.
struct TempoPanel: View {
    let model: AppModel
    @ObservedObject private var timer: FocusTimer
    @ObservedObject private var updates: UpdateChecker
    @ObservedObject private var toggleShortcut: GlobalShortcut

    init(model: AppModel) {
        self.model = model
        self._timer = ObservedObject(wrappedValue: model.timer)
        self._updates = ObservedObject(wrappedValue: model.updates)
        self._toggleShortcut = ObservedObject(wrappedValue: model.toggleShortcut)
    }

    var body: some View {
        MenuBarPanel("Tempo", subtitle: "\(timer.statusLine)", systemImage: "timer", tint: .orange) {
            UpdateBanner(checker: updates) {
                if let release = updates.availableRelease {
                    UpdatePromptWindow.show(release, checker: updates)
                }
            }

            MenuBarSection("Timer") {
                MenuBarRow(
                    timer.isRunning ? "Pause" : (timer.isPaused ? "Resume" : "Start Focus"),
                    subtitle: toggleShortcut.shortcut.map { LocalizedStringKey($0.displayString) },
                    systemImage: timer.isRunning ? "pause.fill" : "play.fill",
                    tint: .orange,
                    value: StatusItemTitle.countdown(timer.remaining)
                ) {
                    if timer.isRunning || timer.isPaused {
                        timer.toggle()
                    } else {
                        timer.start(.focus)
                    }
                }
                MenuBarRow("Short Break", systemImage: FocusTimer.Phase.shortBreak.systemImage, tint: .teal, value: "5 min") {
                    timer.start(.shortBreak)
                }
                MenuBarRow("Long Break", systemImage: FocusTimer.Phase.longBreak.systemImage, tint: .green, value: "15 min") {
                    timer.start(.longBreak)
                }
            }

            MenuBarSection("Options") {
                MenuBarToggleRow("Do Not Disturb", subtitle: "While a focus session runs", systemImage: "moon.fill", tint: .indigo, isOn: $timer.doNotDisturb)
                MenuBarToggleRow("Play Sound", systemImage: "speaker.wave.2.fill", tint: .pink, isOn: $timer.playsSound)
                MenuBarToggleRow("Time in Menu Bar", systemImage: "menubar.rectangle", tint: .blue, isOn: $timer.showsTimeInMenuBar)
            }
        } accessory: {
            Text(verbatim: "\(timer.completedToday)")
                .font(.caption.weight(.semibold))
                .monospacedDigit()
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.orange.opacity(0.18), in: Capsule())
                .foregroundStyle(.orange)
                .help(Text("Focus sessions today"))
                .accessibilityLabel(Text("\(timer.completedToday) focus sessions today"))
        }
    }
}
