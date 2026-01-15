import SwiftUI

// MARK: - Rotating Gradient Fill (Full Background)

/// A subtle rotating gradient fill that can be used as a background overlay.
/// Uses an angular gradient clipped to the shape to avoid "square rotation" artifacts.
struct RotatingGradientFill: View {
    enum ShapeType {
        case capsule
        case roundedRect(cornerRadius: CGFloat)
    }

    enum RenderStyle {
        case fill
        case ring(lineWidth: CGFloat)
        case cone(origin: UnitPoint)  // Cone emanating from a specific point
    }
    
    var shape: ShapeType
    var rotationSpeed: Double = 8.0
    var intensity: Double = 0.12 // Base intensity (0.08-0.15 recommended for subtlety)
    var renderStyle: RenderStyle = .fill
    var coneAngle: Double = 90 // Width of cone in degrees (for .cone style)
    
    @State private var rotation: Double = 0
    @Environment(\.colorScheme) private var colorScheme
    
    // Cool green color palette
    private var gradientColors: [Color] {
        let adjustedIntensity = colorScheme == .dark ? intensity : intensity * 0.6
        return [
            ActionGlowPalette.gradientDark.opacity(adjustedIntensity * 0.3),
            ActionGlowPalette.gradientMid.opacity(adjustedIntensity * 0.6),
            ActionGlowPalette.gradientBright.opacity(adjustedIntensity),
            ActionGlowPalette.gradientHighlight.opacity(adjustedIntensity * 1.2),
            ActionGlowPalette.gradientBright.opacity(adjustedIntensity),
            ActionGlowPalette.gradientMid.opacity(adjustedIntensity * 0.6),
            ActionGlowPalette.gradientDark.opacity(adjustedIntensity * 0.3),
        ]
    }
    
    // Cone gradient colors - bright in center, fading to edges
    private func coneGradientColors(adjustedIntensity: Double) -> [Color] {
        return [
            Color.clear,
            Color.clear,
            ActionGlowPalette.gradientMid.opacity(adjustedIntensity * 0.3),
            ActionGlowPalette.gradientBright.opacity(adjustedIntensity * 0.8),
            ActionGlowPalette.gradientHighlight.opacity(adjustedIntensity * 1.2),
            ActionGlowPalette.gradientBright.opacity(adjustedIntensity * 0.8),
            ActionGlowPalette.gradientMid.opacity(adjustedIntensity * 0.3),
            Color.clear,
            Color.clear,
        ]
    }
    
    var body: some View {
        GeometryReader { geometry in
            switch shape {
            case .capsule:
                gradientLayer(in: Capsule(), size: geometry.size)
            case .roundedRect(let cornerRadius):
                gradientLayer(
                    in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous),
                    size: geometry.size
                )
            }
        }
        .onAppear {
            withAnimation(.linear(duration: rotationSpeed).repeatForever(autoreverses: false)) {
                rotation = 360
            }
        }
    }

    @ViewBuilder
    private func gradientLayer<S: InsettableShape>(in shape: S, size: CGSize) -> some View {
        let diagonal = sqrt(pow(size.width, 2) + pow(size.height, 2))
        
        switch renderStyle {
        case .fill:
            let gradient = AngularGradient(
                gradient: Gradient(colors: gradientColors),
                center: .center,
                angle: .degrees(rotation)
            )
            .frame(width: diagonal, height: diagonal)
            .position(x: size.width / 2, y: size.height / 2)
            gradient.clipShape(shape)
            
        case .ring(let lineWidth):
            let gradient = AngularGradient(
                gradient: Gradient(colors: gradientColors),
                center: .center,
                angle: .degrees(rotation)
            )
            .frame(width: diagonal, height: diagonal)
            .position(x: size.width / 2, y: size.height / 2)
            gradient.mask(shape.strokeBorder(lineWidth: lineWidth))
            
        case .cone(let origin):
            // Cone gradient emanating from origin point, rotating
            let adjustedIntensity = colorScheme == .dark ? intensity : intensity * 0.6
            let centerX = origin.x * size.width
            let centerY = origin.y * size.height
            
            // Radial gradient for the diffuse fade from origin
            let radialGradient = RadialGradient(
                colors: [
                    ActionGlowPalette.gradientHighlight.opacity(adjustedIntensity * 1.5),
                    ActionGlowPalette.gradientBright.opacity(adjustedIntensity * 0.8),
                    ActionGlowPalette.gradientMid.opacity(adjustedIntensity * 0.4),
                    ActionGlowPalette.gradientDark.opacity(adjustedIntensity * 0.15),
                    Color.clear
                ],
                center: origin,
                startRadius: 0,
                endRadius: diagonal * 0.8
            )
            
            // Angular gradient for the cone shape, rotating
            let angularGradient = AngularGradient(
                gradient: Gradient(colors: coneGradientColors(adjustedIntensity: adjustedIntensity)),
                center: origin,
                angle: .degrees(rotation - 45) // Offset to point upward-right initially
            )
            
            ZStack {
                // Combine radial (distance fade) and angular (cone shape)
                radialGradient
                    .clipShape(shape)
                    .blendMode(.plusLighter)
                
                angularGradient
                    .clipShape(shape)
                    .blendMode(.plusLighter)
                    .blur(radius: 20)
            }
        }
    }
}

// Helper to erase shape type
struct AnyShape: Shape, @unchecked Sendable {
    private let _path: @Sendable (CGRect) -> Path
    
    init<S: Shape>(_ shape: S) {
        _path = { rect in shape.path(in: rect) }
    }
    
    func path(in rect: CGRect) -> Path {
        _path(rect)
    }
}

// MARK: - Rotating Light Background (Border Glow)

struct RotatingLightBackground: View {
    enum ShapeType {
        case capsule
        case roundedRect
    }
    
    var cornerRadius: CGFloat
    var shape: ShapeType
    var rotationSpeed: Double
    var glowColor: Color = .white
    
    @State private var rotation: Double = 0
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        switch shape {
        case .capsule:
            rotatingBackground(shape: Capsule())
        case .roundedRect:
            rotatingBackground(shape: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
    }
    
    @ViewBuilder
    private func rotatingBackground<S: InsettableShape>(shape: S) -> some View {
        GeometryReader { geometry in
            let baseFill = colorScheme == .dark ? Color.black.opacity(0.25) : Color.white.opacity(0.6)
            ZStack {
                // Base fill
                shape
                    .fill(baseFill)
                
                // Rotating gradient border/glow
                AngularGradient(
                    gradient: Gradient(colors: [
                        .clear,
                        glowColor.opacity(0.25),
                        glowColor.opacity(0.85),
                        glowColor.opacity(0.25),
                        .clear
                    ]),
                    center: .center,
                    angle: .degrees(rotation)
                )
                .mask(
                    shape
                        .strokeBorder(lineWidth: 3)
                )
                .blur(radius: 6)
            
                shape
                    .stroke(glowColor.opacity(0.25), lineWidth: 2)
                    .blur(radius: 10)
                
                // Optional: Add a subtle overlay for more "glass" feel if needed
                shape
                    .stroke(glowColor.opacity(0.2), lineWidth: 1)
            }
        }
        .onAppear {
            withAnimation(.linear(duration: rotationSpeed).repeatForever(autoreverses: false)) {
                rotation = 360
            }
        }
    }
}
