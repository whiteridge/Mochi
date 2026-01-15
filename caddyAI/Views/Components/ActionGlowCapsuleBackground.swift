import SwiftUI

struct ActionGlowCapsuleBackground: View {
    var rotationSpeed: Double = 8.0
    var intensity: Double? = nil
    var ringWidth: CGFloat? = nil
    var shadowed: Bool = true
    var showRing: Bool = true
    var gradientNamespace: Namespace.ID? = nil
    var gradientId: String = "gradientFill"

    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var preferences: PreferencesStore

    private var ringIntensity: Double {
        if let intensity {
            return intensity
        }
        return showRing ? (preferences.glassStyle == .clear ? 0.34 : 0.28) : 0
    }

    private var ringStroke: CGFloat {
        if let ringWidth {
            return ringWidth
        }
        return preferences.glassStyle == .clear ? 3.2 : 3.8
    }

    private var glowOpacity: Double {
        preferences.glassStyle == .clear ? 0.22 : 0.28
    }

    private var glowRadius: CGFloat {
        preferences.glassStyle == .clear ? 10 : 14
    }

    private var glowY: CGFloat {
        preferences.glassStyle == .clear ? 4 : 6
    }

    private var ringOpacity: Double {
        showRing ? (preferences.glassStyle == .clear ? 0.9 : 0.8) : 0
    }

    private var ringBlur: CGFloat {
        showRing ? (preferences.glassStyle == .clear ? 3.5 : 4.5) : 0
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
                .opacity(0.7)
        }
    }

    @ViewBuilder
    private var ringOverlay: some View {
        let ring = RotatingGradientFill(
            shape: .capsule,
            rotationSpeed: rotationSpeed,
            intensity: ringIntensity,
            renderStyle: .ring(lineWidth: ringStroke)
        )
        .blendMode(preferences.glassStyle == .clear ? .screen : .plusLighter)
        .blur(radius: ringBlur)
        .opacity(ringOpacity)
        .drawingGroup()
        .animation(.easeOut(duration: 0.25), value: showRing)

        if let gradientNamespace {
            ring.matchedGeometryEffect(id: gradientId, in: gradientNamespace)
        } else {
            ring
        }
    }

    var body: some View {
        ZStack {
            baseFill
            ringOverlay
        }
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(ActionGlowPalette.glow.opacity(0.25), lineWidth: 1)
        )
        .shadow(
            color: shadowed ? ActionGlowPalette.glow.opacity(glowOpacity) : .clear,
            radius: shadowed ? glowRadius : 0,
            x: 0,
            y: shadowed ? glowY : 0
        )
    }
}
