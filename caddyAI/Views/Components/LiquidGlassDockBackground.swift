import SwiftUI

struct LiquidGlassDockBackground: View {
    var refractionStrength: Float = 10.0
    var edgeWidth: Float = 26.0
    var rimWidth: CGFloat = 1.0
    var innerRimWidth: CGFloat = 0.7
    var shadowed: Bool = true

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    private var rimGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color.white.opacity(0.5),
                Color.white.opacity(0.0)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var tint: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.18)
            : Color.white.opacity(0.26)
    }

    private var ambientGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color.white.opacity(colorScheme == .dark ? 0.28 : 0.5),
                Color.clear
            ],
            startPoint: .top,
            endPoint: .center
        )
    }

    private var glossGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color.white.opacity(colorScheme == .dark ? 0.42 : 0.6),
                Color.white.opacity(colorScheme == .dark ? 0.12 : 0.2),
                Color.clear
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var bottomShade: LinearGradient {
        LinearGradient(
            colors: [
                Color.clear,
                Color.black.opacity(colorScheme == .dark ? 0.35 : 0.15)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var fallbackFill: Color {
        colorScheme == .dark ? Color.white.opacity(0.18) : Color.white.opacity(0.85)
    }

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let shape = Capsule()
            let minEdge = Float(max(min(size.width, size.height), 1))
            let adjustedEdgeWidth = min(edgeWidth, minEdge * 0.45)
            let adjustedStrength = min(refractionStrength, minEdge * 0.35)
            let baseStyle = reduceTransparency
                ? AnyShapeStyle(fallbackFill)
                : AnyShapeStyle(.ultraThinMaterial)

            if size.width > 0, size.height > 0 {
                let glassLayer = ZStack {
                    shape.fill(tint)
                    shape.fill(ambientGradient).opacity(0.38)
                    shape.fill(glossGradient).opacity(0.32)
                    shape.fill(bottomShade).opacity(0.32)
                }
                .frame(width: size.width, height: size.height)
                .background(baseStyle)
                .clipShape(shape)
                .compositingGroup()
                .distortionEffect(
                    ShaderLibrary.liquidCapsuleRefraction(
                        Shader.Argument.float2(Float(size.width), Float(size.height)),
                        Shader.Argument.float(adjustedStrength),
                        Shader.Argument.float(adjustedEdgeWidth)
                    ),
                    maxSampleOffset: CGSize(
                        width: CGFloat(adjustedStrength),
                        height: CGFloat(adjustedStrength)
                    )
                )

                glassLayer
                    .overlay(
                        shape
                            .strokeBorder(rimGradient, lineWidth: rimWidth)
                    )
                    .overlay(
                        shape
                            .strokeBorder(Color.white.opacity(colorScheme == .dark ? 0.35 : 0.25), lineWidth: innerRimWidth)
                            .blur(radius: 1.2)
                            .opacity(0.7)
                    )
                    .shadow(
                        color: shadowed ? Color.black.opacity(colorScheme == .dark ? 0.35 : 0.2) : .clear,
                        radius: shadowed ? (colorScheme == .dark ? 14 : 10) : 0,
                        x: 0,
                        y: shadowed ? (colorScheme == .dark ? 6 : 4) : 0
                    )
            } else {
                Color.clear
            }
        }
    }
}
