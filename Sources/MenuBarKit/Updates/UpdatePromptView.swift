import AppKit
import SwiftUI

/// The "A new version is available" prompt: the versions, the release notes and the three
/// classic choices. Show it in a window or a sheet.
///
/// ```swift
/// UpdatePromptView(release: release, currentVersion: "1.2", appName: "Tempo") {
///     updates.download(release)
/// } onSkip: {
///     updates.skip(release)
/// } onRemindLater: {
///     updates.remindLater(release)
/// }
/// ```
///
/// A critical release has no "Skip This Version" button.
public struct UpdatePromptView: View {
    private let release: UpdateRelease
    private let currentVersion: SemanticVersion
    private let appName: String
    private let onDownload: () -> Void
    private let onSkip: () -> Void
    private let onRemindLater: () -> Void

    public init(
        release: UpdateRelease,
        currentVersion: SemanticVersion,
        appName: String = AboutInfo.fromBundle().appName,
        onDownload: @escaping () -> Void,
        onSkip: @escaping () -> Void,
        onRemindLater: @escaping () -> Void
    ) {
        self.release = release
        self.currentVersion = currentVersion
        self.appName = appName
        self.onDownload = onDownload
        self.onSkip = onSkip
        self.onRemindLater = onRemindLater
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                Image(nsImage: NSApplication.shared.applicationIconImage)
                    .resizable()
                    .frame(width: 64, height: 64)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text("A new version of \(appName) is available!")
                        .font(.title3.weight(.semibold))
                        .fixedSize(horizontal: false, vertical: true)
                    Text("\(appName) \(release.version.shortDescription) is available. You have \(currentVersion.shortDescription).")
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    if release.isCritical {
                        Label("Important security update", systemImage: "exclamationmark.shield.fill")
                            .font(.callout.weight(.medium))
                            .foregroundStyle(.orange)
                            .padding(.top, 2)
                    }
                }
            }

            if !release.notes.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("What's New")
                        .font(.headline)
                    ForEach(Array(release.notes.enumerated()), id: \.offset) { _, note in
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .accessibilityHidden(true)
                            Text(verbatim: note)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            HStack(spacing: 8) {
                if !release.isCritical {
                    Button("Skip This Version", action: onSkip)
                        .menuBarButtonStyle()
                }
                Spacer(minLength: 8)
                Button("Remind Me Later", action: onRemindLater)
                    .menuBarButtonStyle()
                Button("Download Update", action: onDownload)
                    .menuBarProminentButtonStyle()
                    .keyboardShortcut(.defaultAction)
            }
            .controlSize(.large)
        }
        .padding(20)
        .frame(width: 460)
    }
}

/// A compact "Update available" row for the top of a ``MenuBarPanel``. It shows nothing until
/// the checker finds a release.
public struct UpdateBanner: View {
    @ObservedObject private var checker: UpdateChecker
    private let onShowDetails: (() -> Void)?

    /// - Parameters:
    ///   - checker: The update checker.
    ///   - onShowDetails: Called by the Details button, for example to open a window with an
    ///     ``UpdatePromptView``. Without it the banner has Update and Later buttons only.
    public init(checker: UpdateChecker, onShowDetails: (() -> Void)? = nil) {
        self._checker = ObservedObject(wrappedValue: checker)
        self.onShowDetails = onShowDetails
    }

    public var body: some View {
        if let release = checker.availableRelease {
            HStack(spacing: 10) {
                MenuBarIcon(systemImage: "arrow.down.circle.fill", tint: release.isCritical ? .orange : .blue)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Version \(release.version.shortDescription) is available")
                        .font(.callout.weight(.medium))
                        .lineLimit(1)
                    if let onShowDetails {
                        Button("What's New", action: onShowDetails)
                            .buttonStyle(.link)
                            .font(.caption)
                    }
                }
                Spacer(minLength: 4)
                Button("Later") { checker.remindLater(release) }
                    .controlSize(.small)
                    .menuBarButtonStyle()
                Button("Update") { checker.download(release) }
                    .controlSize(.small)
                    .menuBarProminentButtonStyle()
            }
            .padding(10)
            .background(Color.accentColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }
}
