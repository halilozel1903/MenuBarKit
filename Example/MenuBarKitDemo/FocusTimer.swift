import AppKit
import Combine
import MenuBarKit
import SwiftUI

/// A small Pomodoro timer: the state behind the demo's menu bar panel.
@MainActor
final class FocusTimer: ObservableObject {
    enum Phase: String, CaseIterable {
        case focus, shortBreak, longBreak

        var duration: TimeInterval {
            switch self {
            case .focus: 25 * 60
            case .shortBreak: 5 * 60
            case .longBreak: 15 * 60
            }
        }

        var title: LocalizedStringKey {
            switch self {
            case .focus: "Focus"
            case .shortBreak: "Short Break"
            case .longBreak: "Long Break"
            }
        }

        var systemImage: String {
            switch self {
            case .focus: "brain.head.profile"
            case .shortBreak: "cup.and.saucer.fill"
            case .longBreak: "figure.walk"
            }
        }

        var tint: Color {
            switch self {
            case .focus: .orange
            case .shortBreak: .teal
            case .longBreak: .green
            }
        }
    }

    @Published private(set) var phase: Phase = .focus
    @Published private(set) var remaining: TimeInterval = Phase.focus.duration
    @Published private(set) var isRunning = false
    @Published private(set) var completedToday = 3
    @Published var playsSound = true
    @Published var doNotDisturb = true
    @Published var showsTimeInMenuBar = true

    private var ticker: Task<Void, Never>?

    /// `true` when a session was started and paused part of the way through.
    var isPaused: Bool { !isRunning && remaining < phase.duration }

    /// The text next to the menu bar icon: the time left while a session runs or is paused.
    var menuBarTitle: String {
        guard showsTimeInMenuBar, isRunning || remaining < phase.duration else { return "" }
        return StatusItemTitle.countdown(remaining)
    }

    /// The panel subtitle.
    var statusLine: String {
        if isRunning {
            return "\(StatusItemTitle.countdown(remaining)) left"
        }
        if isPaused {
            return "Paused · \(StatusItemTitle.countdown(remaining)) left"
        }
        return "Ready · \(completedToday) sessions today"
    }

    func start(_ phase: Phase) {
        self.phase = phase
        remaining = phase.duration
        resume()
    }

    /// Starts, pauses or resumes. The global shortcut calls this.
    func toggle() {
        isRunning ? pause() : resume()
    }

    func pause() {
        ticker?.cancel()
        ticker = nil
        isRunning = false
    }

    func reset() {
        pause()
        remaining = phase.duration
    }

    /// For the screenshots: a session paused part of the way through.
    func showPausedSession(remaining: TimeInterval) {
        pause()
        phase = .focus
        self.remaining = remaining
    }

    private func resume() {
        guard !isRunning else { return }
        isRunning = true
        ticker = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard let self, !Task.isCancelled else { return }
                self.tick()
            }
        }
    }

    private func tick() {
        remaining = max(0, remaining - 1)
        guard remaining == 0 else { return }
        pause()
        if phase == .focus { completedToday += 1 }
        if playsSound { NSSound(named: NSSound.Name("Glass"))?.play() }
        phase = phase == .focus ? (completedToday % 4 == 0 ? .longBreak : .shortBreak) : .focus
        remaining = phase.duration
    }
}
