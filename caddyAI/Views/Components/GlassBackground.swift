import SwiftUI

struct GlassBackground: View {
    var cornerRadius: CGFloat
    var tint: Color = Color.black.opacity(0.85)
    
    var body: some View {
        ZStack {
            // Base glass layer with material
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.thickMaterial)
            
            // Dark tint overlay for depth
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(tint)
        }
        .overlay(
            // Primary rim light - simulates light catching the glass edge
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.4), // Slightly increased for visibility
                            Color.white.opacity(0.15),
                            Color.white.opacity(0.03)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .overlay(
            // Inner glow for glass thickness
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(
                    Color.white.opacity(0.08),
                    lineWidth: 0.5
                )
                .blur(radius: 1.5)
                .padding(1)
        )
        .shadow(color: Color.black.opacity(0.4), radius: 18, x: 0, y: 12)
    }
}




