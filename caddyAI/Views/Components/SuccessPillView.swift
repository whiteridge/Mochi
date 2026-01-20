import SwiftUI

struct SuccessPillView: View {
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

    private var glowIntensity: Double {
        colorScheme == .dark ? 0.32 : 0.52
    }

    private var glowOpacity: Double {
        colorScheme == .dark ? 0.8 : 0.95
    }

    @ViewBuilder
    private var backgroundLayer: some View {
        ZStack {
            LiquidGlassSurface(shape: .capsule, prominence: .regular, shadowed: true)

            RotatingGradientFill(
                shape: .capsule,
                rotationSpeed: 0.6,
                intensity: glowIntensity,
                renderStyle: .cone(origin: .center)
            )
            .blendMode(colorScheme == .dark ? .plusLighter : .screen)
            .opacity(glowOpacity)
            .clipShape(Capsule())

            Capsule()
                .stroke(palette.subtleBorder, lineWidth: 1)
        }
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
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(palette.primaryText)
                )
                .shadow(color: Color.black.opacity(0.25), radius: 3, x: 0, y: 2)

            Text("Actions complete")
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
