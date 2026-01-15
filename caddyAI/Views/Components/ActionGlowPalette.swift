import SwiftUI

enum ActionGlowPalette {
    static let glow = Color(red: 0.18, green: 0.84, blue: 0.60)
    static let fillTop = Color(red: 0.16, green: 0.68, blue: 0.48)
    static let fillBottom = Color(red: 0.05, green: 0.32, blue: 0.22)
    static let gradientDark = Color(red: 0.04, green: 0.14, blue: 0.12)
    static let gradientMid = Color(red: 0.07, green: 0.26, blue: 0.21)
    static let gradientBright = Color(red: 0.12, green: 0.42, blue: 0.31)
    static let gradientHighlight = Color(red: 0.20, green: 0.62, blue: 0.46)

    static var fillGradient: LinearGradient {
        LinearGradient(
            colors: [fillTop, fillBottom],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static func glassTint(for colorScheme: ColorScheme) -> Color {
        let tintBase = fillTop
        return colorScheme == .dark ? tintBase.opacity(0.35) : tintBase.opacity(0.22)
    }
}
