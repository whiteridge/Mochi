import SwiftUI

struct CancelledPillView: View {
    // Namespace for matchedGeometryEffect to enable smooth morph from card
    var gradientNamespace: Namespace.ID
    var morphNamespace: Namespace.ID? = nil
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var preferences: PreferencesStore

    private var palette: LiquidGlassPalette {
        LiquidGlassPalette(colorScheme: colorScheme, glassStyle: preferences.glassStyle)
    }

    private var iconBackground: Color {
        preferences.glassStyle == .clear ? Color.white.opacity(0.2) : Color.white.opacity(0.18)
    }

    private var cancelTint: Color {
        let base = Color(nsColor: .systemRed)
        let opacity: Double
        if preferences.glassStyle == .clear {
            opacity = colorScheme == .dark ? 0.22 : 0.14
        } else {
            opacity = colorScheme == .dark ? 0.12 : 0.08
        }
        return base.opacity(opacity)
    }

    private var cancelBorder: Color {
        Color(nsColor: .systemRed).opacity(colorScheme == .dark ? 0.35 : 0.25)
    }

    @ViewBuilder
    private var backgroundLayer: some View {
        LiquidGlassSurface(
            shape: .capsule,
            prominence: .subtle,
            tint: cancelTint,
            shadowed: false
        )
        .overlay(
            Capsule()
                .stroke(cancelBorder, lineWidth: 0.5)
        )
    }

    @ViewBuilder
    private var morphingBackground: some View {
        if let morphNamespace {
            backgroundLayer.matchedGeometryEffect(id: "background", in: morphNamespace)
        } else {
            backgroundLayer
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(iconBackground)
                .frame(width: 32, height: 32)
                .overlay(
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(cancelBorder)
                )
                .shadow(color: Color.black.opacity(0.25), radius: 3, x: 0, y: 2)

            Text("Action cancelled")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(palette.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .shadow(color: Color.black.opacity(0.35), radius: 2, x: 0, y: 1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(morphingBackground)
    }
}
