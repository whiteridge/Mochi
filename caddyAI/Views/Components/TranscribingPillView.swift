import SwiftUI

/// A pill view shown while transcribing audio - same size as recording pill
struct TranscribingPillView: View {
    var body: some View {
        HStack(spacing: 6) {
            // Invisible spacer to match the left cancel button (32x32)
            Color.clear
                .frame(width: 32, height: 32)
            
            // Center: "Transcribing..." text with bouncing dots
            HStack(spacing: 3) {
                Text("Transcribing")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                BouncingDots()
            }
            .frame(width: 72, height: 22)
            
            // Invisible spacer to match the right stop button (32x32)
            Color.clear
                .frame(width: 32, height: 32)
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
                    .frame(width: 3, height: 3)
                    .offset(y: isAnimating ? -2 : 0)
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
