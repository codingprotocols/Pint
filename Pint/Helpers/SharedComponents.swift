import SwiftUI

// MARK: - Type Badge

/// Formula / cask label used across DashboardView, InstalledView, UpgradesView, PackageDetailView.
struct TypeBadge: View {
    let type: PackageType
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let (label, color): (String, Color) = type == .formula ? ("formula", .green) : ("cask", .purple)
        Text(label)
            .font(.system(.caption2, design: .rounded, weight: .semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Capsule().fill(color.opacity(colorScheme.iconBgOpacity)))
    }
}

// MARK: - Filter Chip

/// Pill-shaped toggle chip used in InstalledView and SearchView filter bars.
struct FilterChip: View {
    let label: String
    let isSelected: Bool
    var color: Color = .accentColor
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .foregroundStyle(isSelected ? color : .secondary)
                .background(
                    Capsule()
                        .fill(isSelected ? color.opacity(0.12) : Color(.controlColor).opacity(0.7))
                )
                .overlay(
                    Capsule().stroke(isSelected ? color.opacity(0.3) : Color(.separatorColor), lineWidth: 0.5)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Section Card

/// Card with a labelled header row and arbitrary content below a divider.
struct SectionCard<Content: View>: View {
    let icon: String
    let iconColor: Color
    let title: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(iconColor)
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()
            content()
        }
        .cardStyle()
    }
}

/// Card with a header row that includes a count/status badge on the trailing edge.
struct SectionCardWithBadge<Badge: View, Content: View>: View {
    let icon: String
    let iconColor: Color
    let title: String
    @ViewBuilder var badge: () -> Badge
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(iconColor)
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                badge()
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color(.controlColor)))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()
            content()
        }
        .cardStyle()
    }
}
