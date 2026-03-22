import SwiftUI

// MARK: - Design Tokens

/// Icon background opacity values — single source of truth for all tinted icon badges.
/// Use `iconBgOpacity(for:)` rather than branching on colorScheme at each call site.
enum DesignTokens {
    static let iconBgOpacityLight: Double = 0.10
    static let iconBgOpacityDark:  Double = 0.20
}

extension ColorScheme {
    var iconBgOpacity: Double {
        self == .dark ? DesignTokens.iconBgOpacityDark : DesignTokens.iconBgOpacityLight
    }
}

// MARK: - Card Style

/// Clean card surface that adapts to system light/dark theme.
struct CardModifier: ViewModifier {
    var cornerRadius: CGFloat = 12
    var shadowRadius: CGFloat = 2

    func body(content: Content) -> some View {
        content
            .background(Color(.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Color(.separatorColor), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.06), radius: shadowRadius, y: 1)
    }
}

extension View {
    func cardStyle(cornerRadius: CGFloat = 12, shadowRadius: CGFloat = 2) -> some View {
        modifier(CardModifier(cornerRadius: cornerRadius, shadowRadius: shadowRadius))
    }
}
