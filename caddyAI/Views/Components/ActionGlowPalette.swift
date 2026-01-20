import SwiftUI

enum ActionGlowPalette {
    static let glow = Color(red: 0.18, green: 0.84, blue: 0.60)
    static let fillTop = Color(red: 0.16, green: 0.68, blue: 0.48)
    static let fillBottom = Color(red: 0.05, green: 0.32, blue: 0.22)
    static let regularFillTop = Color(red: 0.26, green: 0.84, blue: 0.62)
    static let regularFillBottom = Color(red: 0.14, green: 0.52, blue: 0.38)
    static let solidFill = Color(red: 0.10, green: 0.54, blue: 0.38)
    static let gradientDark = Color(red: 0.14, green: 0.42, blue: 0.14)
    static let gradientMid = Color(red: 0.24, green: 0.62, blue: 0.22)
    static let gradientBright = Color(red: 0.36, green: 0.78, blue: 0.28)
    static let gradientHighlight = Color(red: 0.55, green: 0.92, blue: 0.32)

    static var fillGradient: LinearGradient {
        LinearGradient(
            colors: [regularFillTop, regularFillBottom],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static func glassTint(for colorScheme: ColorScheme) -> Color {
        let tintBase = fillTop
        return colorScheme == .dark ? tintBase.opacity(0.28) : tintBase.opacity(0.18)
    }
}
