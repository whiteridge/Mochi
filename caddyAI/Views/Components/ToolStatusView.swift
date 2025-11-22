import SwiftUI

struct ToolStatusView: View {
    let tool: ToolStatus
    @State private var isAnimating = false
    
    var body: some View {
        HStack(spacing: 8) {
            // 1. The Icon (Linear Brand Style)
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "5E6AD2"), Color(hex: "C9C9FC")], // Linear Purples
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 16, height: 16)
                
                // Optional: Internal graphic if needed, otherwise just the orb looks good
            }
            
            // 2. The Text
            Text(tool.status)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.9))
            
            // 3. The Stable Animation (3 Dots)
            HStack(spacing: 3) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(Color.white.opacity(0.8))
                        .frame(width: 3, height: 3)
                        .opacity(isAnimating ? 1 : 0.3)
                        // Staggered animation
                        .animation(
                            Animation.easeInOut(duration: 0.6)
                                .repeatForever()
                                .delay(Double(index) * 0.2),
                            value: isAnimating
                        )
                }
            }
            .offset(y: 1) // Optical alignment with text baseline
        }
        // 4. Compact Styling
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial)
        .background(Color.black.opacity(0.3))
        .clipShape(Capsule())
        // 5. Glass Border
        .overlay(
            Capsule()
                .stroke(
                    LinearGradient(
                        colors: [.white.opacity(0.2), .white.opacity(0.05)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 0.5
                )
        )
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - Color Extension for Hex Support

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
