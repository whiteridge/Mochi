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
    
    @Environment(\.colorScheme) private var colorScheme
    
    private var adjustedIntensity: Double {
        intensity * (colorScheme == .dark ? 1.0 : 0.85)
    }
    
    private var adjustedRotationSpeed: Double {
        guard rotationSpeed > 0 else { return 0 }
        let multiplier = colorScheme == .dark ? 1.0 : 0.75
        return rotationSpeed * multiplier
    }
    
    // Cool green color palette
    private var gradientColors: [Color] {
        return [
            ActionGlowPalette.gradientMid.opacity(adjustedIntensity * 0.5),
            ActionGlowPalette.gradientBright.opacity(adjustedIntensity * 0.85),
            ActionGlowPalette.gradientHighlight.opacity(adjustedIntensity * 1.2),
            ActionGlowPalette.gradientBright.opacity(adjustedIntensity),
            ActionGlowPalette.gradientMid.opacity(adjustedIntensity * 0.7),
            ActionGlowPalette.gradientBright.opacity(adjustedIntensity * 0.9),
            ActionGlowPalette.gradientHighlight.opacity(adjustedIntensity * 1.1),
        ]
    }
    
    // Cone gradient stops - broad, soft sweep with no hard dark gaps
    private func coneGradientStops(adjustedIntensity: Double) -> [Gradient.Stop] {
        [
            .init(color: ActionGlowPalette.gradientMid.opacity(adjustedIntensity * 0.35), location: 0),
            .init(color: ActionGlowPalette.gradientBright.opacity(adjustedIntensity * 0.45), location: 0.2),
            .init(color: ActionGlowPalette.gradientBright.opacity(adjustedIntensity * 0.6), location: 0.4),
            .init(color: ActionGlowPalette.gradientHighlight.opacity(adjustedIntensity * 0.85), location: 0.56),
            .init(color: ActionGlowPalette.gradientBright.opacity(adjustedIntensity * 0.7), location: 0.7),
            .init(color: ActionGlowPalette.gradientMid.opacity(adjustedIntensity * 0.5), location: 0.86),
            .init(color: ActionGlowPalette.gradientMid.opacity(adjustedIntensity * 0.4), location: 1)
        ]
    }
    
    private func rotationAngle(for date: Date) -> Double {
        guard adjustedRotationSpeed > 0 else { return 0 }
        let time = date.timeIntervalSinceReferenceDate
        let progress = (time / adjustedRotationSpeed).truncatingRemainder(dividingBy: 1)
        return progress * 360
    }

    var body: some View {
        GeometryReader { geometry in
            TimelineView(.animation) { timeline in
                let angle = rotationAngle(for: timeline.date)
                switch shape {
                case .capsule:
                    gradientLayer(in: Capsule(), size: geometry.size, rotationAngle: angle)
                case .roundedRect(let cornerRadius):
                    gradientLayer(
                        in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous),
                        size: geometry.size,
                        rotationAngle: angle
                    )
                }
            }
        }
    }

    @ViewBuilder
    private func gradientLayer<S: InsettableShape>(in shape: S, size: CGSize, rotationAngle: Double) -> some View {
        let diagonal = sqrt(pow(size.width, 2) + pow(size.height, 2))
        
        switch renderStyle {
        case .fill:
            let gradient = AngularGradient(
                gradient: Gradient(colors: gradientColors),
                center: .center,
                angle: .degrees(rotationAngle)
            )
            .frame(width: diagonal, height: diagonal)
            .position(x: size.width / 2, y: size.height / 2)
            gradient.clipShape(shape)
            
        case .ring(let lineWidth):
            let gradient = AngularGradient(
                gradient: Gradient(colors: gradientColors),
                center: .center,
                angle: .degrees(rotationAngle)
            )
            .frame(width: diagonal, height: diagonal)
            .position(x: size.width / 2, y: size.height / 2)
            gradient.mask(shape.strokeBorder(lineWidth: lineWidth))
            
        case .cone(let origin):
            // Cone gradient emanating from origin point, rotating
            let adjustedIntensity = self.adjustedIntensity
            
            // Radial gradient for the diffuse fade from origin
            let radialGradient = RadialGradient(
                colors: [
                    ActionGlowPalette.gradientHighlight.opacity(adjustedIntensity * 0.9),
                    ActionGlowPalette.gradientBright.opacity(adjustedIntensity * 0.6),
                    ActionGlowPalette.gradientMid.opacity(adjustedIntensity * 0.45),
                    ActionGlowPalette.gradientMid.opacity(adjustedIntensity * 0.32)
                ],
                center: origin,
                startRadius: 0,
                endRadius: diagonal * 0.8
            )
            
            // Angular gradient for the cone shape, rotating
            let angularGradient = AngularGradient(
                gradient: Gradient(stops: coneGradientStops(adjustedIntensity: adjustedIntensity)),
                center: origin,
                angle: .degrees(rotationAngle - 45) // Offset to point upward-right initially
            )
            
            ZStack {
                // Combine radial (distance fade) and angular (cone shape)
                radialGradient
                    .clipShape(shape)
                    .blendMode(.plusLighter)
                
            angularGradient
                .clipShape(shape)
                .blendMode(.plusLighter)
                .blur(radius: 28)
                .opacity(0.85)
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
    
    private var adjustedRotationSpeed: Double {
        guard rotationSpeed > 0 else { return 0 }
        let multiplier = colorScheme == .dark ? 1.0 : 0.75
        return rotationSpeed * multiplier
    }
    
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
            withAnimation(.linear(duration: adjustedRotationSpeed).repeatForever(autoreverses: false)) {
                rotation = 360
            }
        }
    }
}
