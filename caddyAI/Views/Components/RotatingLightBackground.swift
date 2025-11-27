import SwiftUI

/// A morphing background with a rotating conic gradient and glass blur overlay.
/// Used for the confirm button → full background → success pill transition.
struct RotatingLightBackground: View {
    enum ShapeType {
        case capsule
        case roundedRect
    }
    
    let shapeType: ShapeType
    let cornerRadius: CGFloat
    let rotationSpeed: Double
    let colors: [Color]
    
    @State private var rotation: Double = 0
    
    init(
        cornerRadius: CGFloat = 30,
        shape: ShapeType = .capsule,
        rotationSpeed: Double = 10,
        colors: [Color] = [
            Color(red: 0.25, green: 0.85, blue: 0.35), // Vibrant green
            Color(red: 0.15, green: 0.65, blue: 0.25), // Mid green
            Color(red: 0.35, green: 0.95, blue: 0.45), // Highlight green
            Color(red: 0.10, green: 0.55, blue: 0.20), // Deep green
            Color(red: 0.25, green: 0.85, blue: 0.35)  // Loop
        ]
    ) {
        self.shapeType = shape
        self.cornerRadius = cornerRadius
        self.rotationSpeed = rotationSpeed
        self.colors = colors
    }
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Layer 1: Dark base for depth
                Color.black.opacity(0.6)
                
                // Layer 2: Rotating Conic/Angular Gradient
                AngularGradient(
                    gradient: Gradient(colors: colors),
                    center: .center,
                    startAngle: .degrees(0),
                    endAngle: .degrees(360)
                )
                .rotationEffect(.degrees(rotation))
                .blur(radius: 60) // Diffuse the gradient for a soft glow
                .opacity(0.8) // Less completely filled with color
                .scaleEffect(1.5) // Scale up so blur doesn't show edges
                
                // Layer 3: Glass material overlay
                glassOverlay(size: geo.size)
            }
            .clipShape(RoundedRectangle(cornerRadius: effectiveCornerRadius(for: geo.size), style: .continuous))
            .overlay(rimLight(size: geo.size))
        }
        .onAppear {
            startRotation()
        }
        .onChange(of: rotationSpeed) { _, _ in
            // Restart animation with new duration when it changes
            rotation = 0
            startRotation()
        }
    }
    
    private func startRotation() {
        withAnimation(.linear(duration: rotationSpeed).repeatForever(autoreverses: false)) {
            rotation = 360
        }
    }
    
    private func effectiveCornerRadius(for size: CGSize) -> CGFloat {
        switch shapeType {
        case .capsule:
            return size.height / 2
        case .roundedRect:
            return cornerRadius
        }
    }
    
    @ViewBuilder
    private func glassOverlay(size: CGSize) -> some View {
        RoundedRectangle(cornerRadius: effectiveCornerRadius(for: size), style: .continuous)
            .fill(.ultraThinMaterial)
            .opacity(0.7)
    }
    
    @ViewBuilder
    private func rimLight(size: CGSize) -> some View {
        RoundedRectangle(cornerRadius: effectiveCornerRadius(for: size), style: .continuous)
            .strokeBorder(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.4),
                        Color.white.opacity(0.15),
                        Color.white.opacity(0.05)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1
            )
    }
}

#Preview {
    ZStack {
        Color.black
        
        VStack(spacing: 40) {
            // Capsule preview (button state)
            RotatingLightBackground(shape: .capsule, rotationSpeed: 10)
                .frame(width: 180, height: 48)
            
            // Rounded rect preview (expanded state)
            RotatingLightBackground(cornerRadius: 24, shape: .roundedRect, rotationSpeed: 10)
                .frame(width: 300, height: 200)
            
            // Fast rotation preview (success state)
            RotatingLightBackground(shape: .capsule, rotationSpeed: 2)
                .frame(width: 200, height: 60)
        }
    }
}
