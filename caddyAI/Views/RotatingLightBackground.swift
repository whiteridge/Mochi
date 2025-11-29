import SwiftUI

struct RotatingLightBackground: View {
    enum ShapeType {
        case capsule
        case roundedRect
    }
    
    var cornerRadius: CGFloat
    var shape: ShapeType
    var rotationSpeed: Double
    
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
                        .white.opacity(0.1),
                        .white.opacity(0.4),
                        .white.opacity(0.1),
                        .clear
                    ]),
                    center: .center,
                    angle: .degrees(rotation)
                )
                .mask(
                    shape
                        .strokeBorder(lineWidth: 2)
                )
                .blur(radius: 2)
                
                // Optional: Add a subtle overlay for more "glass" feel if needed
                shape
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            }
        }
        .onAppear {
            withAnimation(.linear(duration: rotationSpeed).repeatForever(autoreverses: false)) {
                rotation = 360
            }
        }
    }
}
