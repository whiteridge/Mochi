import SwiftUI

// MARK: - Rotating Gradient Fill (Full Background)

/// A subtle rotating gradient fill that can be used as a background overlay.
/// Uses an angular gradient clipped to the shape to avoid "square rotation" artifacts.
struct RotatingGradientFill: View {
    enum ShapeType {
        case capsule
        case roundedRect(cornerRadius: CGFloat)
    }
    
    var shape: ShapeType
    var rotationSpeed: Double = 8.0
    var intensity: Double = 0.12 // Base intensity (0.08-0.15 recommended for subtlety)
    
    @State private var rotation: Double = 0
    
    // Subtle dark green color palette
    private var gradientColors: [Color] {
        [
            Color(red: 0.04, green: 0.12, blue: 0.06).opacity(intensity * 0.3),
            Color(red: 0.06, green: 0.20, blue: 0.10).opacity(intensity * 0.6),
            Color(red: 0.12, green: 0.35, blue: 0.18).opacity(intensity),
            Color(red: 0.18, green: 0.50, blue: 0.28).opacity(intensity * 1.2),
            Color(red: 0.12, green: 0.35, blue: 0.18).opacity(intensity),
            Color(red: 0.06, green: 0.20, blue: 0.10).opacity(intensity * 0.6),
            Color(red: 0.04, green: 0.12, blue: 0.06).opacity(intensity * 0.3),
        ]
    }
    
    var body: some View {
        GeometryReader { geometry in
            // Calculate the diagonal to ensure full coverage during rotation
            let diagonal = sqrt(pow(geometry.size.width, 2) + pow(geometry.size.height, 2))
            
            ZStack {
                // Angular gradient that rotates - creates a smooth sweeping effect
                AngularGradient(
                    gradient: Gradient(colors: gradientColors),
                    center: .center,
                    angle: .degrees(rotation)
                )
                .frame(width: diagonal, height: diagonal)
                .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
            }
        }
        .clipShape(clipShape)
        .onAppear {
            withAnimation(.linear(duration: rotationSpeed).repeatForever(autoreverses: false)) {
                rotation = 360
            }
        }
    }
    
    private var clipShape: AnyShape {
        switch shape {
        case .capsule:
            return AnyShape(Capsule())
        case .roundedRect(let cornerRadius):
            return AnyShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
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
            ZStack {
                // Base fill
                shape
                    .fill(Color.black.opacity(0.2))
                
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
