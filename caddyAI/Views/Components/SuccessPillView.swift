import SwiftUI

struct SuccessPillView: View {
    // Namespace for matchedGeometryEffect to enable smooth morph from card
    var gradientNamespace: Namespace.ID
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var preferences: PreferencesStore

    private var iconBackground: Color {
        preferences.glassStyle == .clear ? Color.white.opacity(0.2) : Color.white.opacity(0.18)
    }

    private var gradientIntensity: Double {
        preferences.glassStyle == .clear ? 0.18 : 0.0
    }

    @ViewBuilder
    private var baseFill: some View {
        if preferences.glassStyle == .clear {
            LiquidGlassSurface(
                shape: .capsule,
                prominence: .strong,
                tint: ActionGlowPalette.glassTint(for: colorScheme),
                shadowed: false
            )
        } else {
            Capsule()
                .fill(ActionGlowPalette.fillGradient)
        }
    }
    
    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(iconBackground)
                .frame(width: 32, height: 32)
                .overlay(
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                )
                .shadow(color: Color.black.opacity(0.25), radius: 3, x: 0, y: 2)

            Text("Actions complete")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .shadow(color: Color.black.opacity(0.35), radius: 2, x: 0, y: 1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(
            ZStack {
                baseFill
                // Rotating gradient fill that morphs from the confirmation card
                RotatingGradientFill(
                    shape: .capsule,
                    rotationSpeed: 8.0,
                    intensity: gradientIntensity
                )
                .matchedGeometryEffect(id: "gradientFill", in: gradientNamespace)
            }
        )
        .clipShape(Capsule())
    }
}
