import SwiftUI

struct SuccessPillView: View {
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
                    // 1. Add shadow to the icon group
                    .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
            }
            
            Text("Actions complete")
                .font(.system(size: 15, weight: .semibold)) // 2. Bump weight to Semibold
                .foregroundStyle(.white)
                // 3. Add a strong drop shadow to the text
                .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
    }
}
