import SwiftUI

struct ToolStatusView: View {
    let toolName: String
    let status: String
    
    var body: some View {
        HStack(spacing: 10) {
            // Tool Icon (Linear Logo Placeholder)
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 28, height: 28)
                
                // Use a specific icon for Linear if possible, else generic
                Image(systemName: toolName.lowercased().contains("linear") ? "checklist" : "network")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white)
            }
            
            HStack(spacing: 0) {
                Text("\(status.capitalized) \(toolName)")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))
                
                TypingEllipsis()
                    .padding(.leading, 2)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            GlassBackground(cornerRadius: 30)
        )
    }
}

// MARK: - Subcomponents

private struct TypingEllipsis: View {
    @State private var dotCount = 0
    
    var body: some View {
        Text(String(repeating: ".", count: dotCount))
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(.white.opacity(0.9))
            .frame(width: 12, alignment: .leading) // Fixed width to prevent jitter
            .onAppear {
                withAnimation(.easeInOut(duration: 0.5).repeatForever()) {
                    // This is a simple animation, but for a text-based one we need a timer
                }
            }
            .onReceive(Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()) { _ in
                dotCount = (dotCount + 1) % 4
            }
    }
}

private struct GlassBackground: View {
    var cornerRadius: CGFloat
    var tint: Color = Color.black.opacity(0.5)
    
    var body: some View {
        ZStack {
            // Base glass layer with material
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.ultraThinMaterial)
            
            // Dark tint overlay for depth
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(tint)
        }
        .overlay(
            // Primary rim light
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.4),
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
            // Inner glow
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
