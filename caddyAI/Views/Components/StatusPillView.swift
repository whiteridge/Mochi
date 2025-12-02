import SwiftUI

struct StatusPillView: View {
    let text: String
    @Namespace private var animation

    var body: some View {
        HStack(spacing: 8) {
            // Use the existing icon for “Thinking…”
            ZStack {
                Circle()
                    .fill(Color(nsColor: .controlAccentColor).opacity(0.3))
                    .frame(width: 20, height: 20)
                    .overlay(
                        Circle()
                            .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                    )
                    .overlay(
                        Image(systemName: "waveform")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.white)
                    )
            }
            
            HStack(spacing: 0) {
                Text(text.replacingOccurrences(of: "...", with: ""))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                
                BouncingDotsView()
                    .padding(.leading, 2)
                    .offset(y: 1) // Optical alignment
            }
            .transition(.asymmetric(
                insertion: .move(edge: .bottom).combined(with: .opacity),
                removal: .move(edge: .top).combined(with: .opacity)
            ))
            .id(text) // Trigger transition on text change
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
        .animation(.easeInOut(duration: 0.25), value: text) // Animate text change
    }
}

struct BouncingDotsView: View {
    @State private var isAnimating = false
    
    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(Color.white)
                    .frame(width: 3, height: 3)
                    .offset(y: isAnimating ? -3 : 0)
                    .animation(
                        Animation.easeInOut(duration: 0.4)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.15),
                        value: isAnimating
                    )
            }
        }
        .onAppear {
            isAnimating = true
        }
    }
}
