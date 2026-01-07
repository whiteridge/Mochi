import SwiftUI

struct SuccessPillView: View {
    // Namespace for matchedGeometryEffect to enable smooth morph from card
    var gradientNamespace: Namespace.ID
    
    var body: some View {
        HStack(spacing: 12) {
            // Icons
            HStack(spacing: -8) {
                Circle()
                    .fill(Color.white.opacity(0.15))
                    .frame(width: 26, height: 26)
                    .overlay(
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                    )
                    .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
            }
            
            Text("Actions complete")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(
            // Rotating gradient fill that morphs from the confirmation card
            RotatingGradientFill(
                shape: .capsule,
                rotationSpeed: 8.0,
                intensity: 0.18
            )
            .matchedGeometryEffect(id: "gradientFill", in: gradientNamespace)
        )
    }
}
