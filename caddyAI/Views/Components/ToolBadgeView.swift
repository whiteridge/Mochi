import SwiftUI

struct ToolBadgeView: View {
    let iconName: String
    let displayName: String
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var preferences: PreferencesStore

    private var palette: LiquidGlassPalette {
        LiquidGlassPalette(colorScheme: colorScheme, glassStyle: preferences.glassStyle)
    }
    
    var body: some View {
        HStack(spacing: 6) {
            // Tool icon with subtle background
            ZStack {
                Circle()
                    .fill(Color(nsColor: .controlAccentColor).opacity(0.3))
                    .frame(width: 20, height: 20)
                    .overlay(
                        Circle()
                            .strokeBorder(palette.subtleBorder, lineWidth: 1)
                    )
                    .overlay(
                        Image(systemName: iconName)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(palette.iconPrimary)
                    )
            }
            
            Text(displayName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(palette.primaryText)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(GlassBackground(cornerRadius: 20, prominence: .subtle, shadowed: false))
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(palette.subtleBorder, lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}
