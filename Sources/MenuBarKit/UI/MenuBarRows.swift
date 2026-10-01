import SwiftUI

/// A group of rows with an optional small caps title, like a section of a menu.
public struct MenuBarSection<Content: View>: View {
    private let title: LocalizedStringKey?
    private let content: Content

    public init(_ title: LocalizedStringKey? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let title {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .padding(.horizontal, 10)
                    .padding(.bottom, 2)
                    .accessibilityAddTraits(.isHeader)
            }
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// The icon tile at the start of a row: a white SF Symbol on a rounded square in the tint.
struct MenuBarIcon: View {
    let systemImage: String
    let tint: Color
    var size: CGFloat = 24

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
            .fill(tint.gradient)
            .frame(width: size, height: size)
            .overlay {
                Image(systemName: systemImage)
                    .font(.system(size: size * 0.5, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .accessibilityHidden(true)
    }
}

/// A clickable row with an icon, a title, an optional subtitle and an optional trailing value,
/// highlighted on hover like a menu item.
///
/// ```swift
/// MenuBarRow("Start Focus", systemImage: "play.fill", tint: .orange, value: "25 min") {
///     timer.start()
/// }
/// ```
public struct MenuBarRow: View {
    private let title: LocalizedStringKey
    private let subtitle: LocalizedStringKey?
    private let systemImage: String
    private let tint: Color
    private let value: String?
    private let action: () -> Void

    @State private var isHovered = false

    public init(
        _ title: LocalizedStringKey,
        subtitle: LocalizedStringKey? = nil,
        systemImage: String,
        tint: Color = .accentColor,
        value: String? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.tint = tint
        self.value = value
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                MenuBarIcon(systemImage: systemImage, tint: tint)
                MenuBarRowTitle(title: title, subtitle: subtitle)
                Spacer(minLength: 8)
                if let value {
                    Text(verbatim: value)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isHovered ? Color.primary.opacity(0.08) : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

/// A row with an icon, a title and a switch.
///
/// ```swift
/// MenuBarToggleRow("Do Not Disturb", systemImage: "moon.fill", tint: .indigo, isOn: $dnd)
/// ```
public struct MenuBarToggleRow: View {
    private let title: LocalizedStringKey
    private let subtitle: LocalizedStringKey?
    private let systemImage: String
    private let tint: Color
    @Binding private var isOn: Bool

    public init(
        _ title: LocalizedStringKey,
        subtitle: LocalizedStringKey? = nil,
        systemImage: String,
        tint: Color = .accentColor,
        isOn: Binding<Bool>
    ) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.tint = tint
        self._isOn = isOn
    }

    public var body: some View {
        HStack(spacing: 10) {
            MenuBarIcon(systemImage: systemImage, tint: tint)
            MenuBarRowTitle(title: title, subtitle: subtitle)
            Spacer(minLength: 8)
            Toggle(isOn: $isOn) {
                Text(title)
            }
            .toggleStyle(.switch)
            .controlSize(.small)
            .labelsHidden()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .accessibilityElement(children: .combine)
    }
}

struct MenuBarRowTitle: View {
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey?

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title)
                .lineLimit(1)
            if let subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }
}
