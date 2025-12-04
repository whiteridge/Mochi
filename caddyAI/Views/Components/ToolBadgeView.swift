import SwiftUI

struct ToolBadgeView: View {
    let iconName: String
    let displayName: String
    
    var body: some View {
        HStack(spacing: 6) {
            // Tool icon with subtle background
            ZStack {
                Circle()
                    .fill(Color(nsColor: .controlAccentColor).opacity(0.3))
                    .frame(width: 20, height: 20)
                    .overlay(
                        Circle()
                            .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                    )
                    .overlay(
                        Image(systemName: iconName)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.white)
                    )
            }
            
            Text(displayName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(GlassBackground(cornerRadius: 20))
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}
