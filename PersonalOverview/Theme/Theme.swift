import SwiftUI

enum AppTheme {
    static let navy = Color(red: 0.06, green: 0.10, blue: 0.18)
    static let navyCard = Color(red: 0.09, green: 0.14, blue: 0.24)
    static let navyElevated = Color(red: 0.12, green: 0.18, blue: 0.30)
    static let gold = Color(red: 0.85, green: 0.68, blue: 0.28)
    static let goldSoft = Color(red: 0.85, green: 0.68, blue: 0.28).opacity(0.85)
    static let textPrimary = Color.white.opacity(0.95)
    static let textSecondary = Color.white.opacity(0.55)
    static let positive = Color(red: 0.35, green: 0.78, blue: 0.55)
    static let negative = Color(red: 0.95, green: 0.40, blue: 0.40)
    static let border = Color.white.opacity(0.08)
}

struct CardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(AppTheme.navyCard)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(AppTheme.border, lineWidth: 1)
            )
    }
}

extension View {
    func appCard() -> some View {
        modifier(CardModifier())
    }
}
