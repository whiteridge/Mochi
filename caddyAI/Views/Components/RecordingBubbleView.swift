import SwiftUI

struct RecordingBubbleView: View {
    let stopRecording: () -> Void
    let animation: Namespace.ID
    
    var body: some View {
        HStack(spacing: 12) {
            // Left: Circular logo/icon with glass effect
            Circle()
                .fill(Color.white.opacity(0.08))
                .overlay(
                    Circle()
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.25),
                                    Color.white.opacity(0.05)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .frame(width: 36, height: 36)
                .overlay(
                    Image(systemName: "waveform")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))
                )
                .matchedGeometryEffect(id: "appIcon", in: animation)
            
            AnimatedDotRow(count: 10)
                .frame(width: 84, height: 28)

            // Right: Vibrant stop button
            VoiceActionButton(
                size: 44,
                isRecording: true,
                action: stopRecording
            )
            .matchedGeometryEffect(id: "actionButton", in: animation)
        }
    }
}

struct AnimatedDotRow: View {
    let count: Int

    var body: some View {
        GeometryReader { proxy in
            let maxHeight = max(proxy.size.height, 1)
            let spacing: CGFloat = 3
            let totalSpacing = spacing * CGFloat(max(count - 1, 0))
            let availableWidth = max(proxy.size.width - totalSpacing, CGFloat(count))
            let barWidth = availableWidth / CGFloat(max(count, 1))

            TimelineView(.animation) { timeline in
                let phase = timeline.date.timeIntervalSinceReferenceDate.remainder(dividingBy: 1.4) / 1.4 * (.pi * 2)
                HStack(spacing: spacing) {
                    ForEach(0..<count, id: \.self) { index in
                        let relative = Double(index) / Double(max(count - 1, 1))
                        let distanceFromCenter = abs(relative - 0.5)
                        let envelope = 0.35 + (1 - distanceFromCenter * 2) * 0.65
                        let wave = (sin(phase + relative * .pi * 1.8) + 1) / 2
                        let height = max(3, CGFloat(wave) * maxHeight * CGFloat(envelope))

                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.85),
                                        Color.white.opacity(0.6)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(width: max(barWidth, 1), height: height)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            }
        }
        .frame(height: 32)
    }
}
