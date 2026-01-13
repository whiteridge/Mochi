import SwiftUI

/// A pill view shown while transcribing audio - same size as recording pill
struct TranscribingPillView: View {
    var body: some View {
        HStack(spacing: 12) {
            // Invisible spacer to match the left cancel button (36x36)
            Color.clear
                .frame(width: 36, height: 36)
            
            // Center: "Transcribing..." text with bouncing dots
            HStack(spacing: 3) {
                Text("Transcribing")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.85))
                BouncingDots()
            }
            .frame(width: 84, height: 28)
            
            // Invisible spacer to match the right stop button (44x44)
            Color.clear
                .frame(width: 44, height: 44)
        }
    }
}

/// Bouncing dots animation for loading indicator
private struct BouncingDots: View {
    @State private var isAnimating = false
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(Color.white.opacity(0.85))
                    .frame(width: 4, height: 4)
                    .offset(y: isAnimating ? -3 : 0)
                    .animation(
                        .easeInOut(duration: 0.4)
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
