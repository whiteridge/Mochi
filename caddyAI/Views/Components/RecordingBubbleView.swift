import SwiftUI

struct RecordingBubbleView: View {
    let stopRecording: () -> Void
    let cancelRecording: () -> Void
    let animation: Namespace.ID
    var amplitude: CGFloat = 0.5
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var preferences: PreferencesStore

    private var palette: LiquidGlassPalette {
        LiquidGlassPalette(colorScheme: colorScheme)
    }

    private var adaptiveIconColor: Color {
        preferences.glassStyle == .clear ? .white : .primary
    }

    private var adaptiveBlendMode: BlendMode {
        preferences.glassStyle == .clear ? .difference : .normal
    }
    
    var body: some View {
        HStack(spacing: 6) {
            // Left: Cancel button (X)
            Button(action: cancelRecording) {
                Circle()
                    // Use Color.primary to ensure system adaptation matches the dots
                    .fill(Color.primary.opacity(0.1))
                    .overlay(
                        Circle()
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        Color.primary.opacity(0.3),
                                        Color.primary.opacity(0.1)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                    .frame(width: 32, height: 32)
                    .overlay(
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(adaptiveIconColor)
                            .blendMode(adaptiveBlendMode)
                    )
            }
            .buttonStyle(.plain)
            .matchedGeometryEffect(id: "appIcon", in: animation)
            
            AnimatedDotRow(count: 10, amplitude: amplitude)
                .frame(width: 72, height: 22)

            // Right: Vibrant stop button
            VoiceActionButton(
                size: 32,
                isRecording: true,
                action: stopRecording
            )
            .matchedGeometryEffect(id: "actionButton", in: animation)
        }
    }
}

struct AnimatedDotRow: View {
    let count: Int
    var amplitude: CGFloat = 0.5  // Default to mid-range for backwards compatibility
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var preferences: PreferencesStore

    private var palette: LiquidGlassPalette {
        LiquidGlassPalette(colorScheme: colorScheme)
    }

    private var adaptiveWaveColors: [Color] {
        let baseColor: Color = preferences.glassStyle == .clear ? .white : .primary
        return [
            baseColor.opacity(0.85),
            baseColor.opacity(0.55)
        ]
    }

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
                        
                        // Scale height based on amplitude with stronger visual response:
                        // - amplitude 0: flat bars (minimum height)
                        // - amplitude 1: full wave animation
                        // Boost amplitude for more dramatic visual response
                        let minHeight: CGFloat = 3
                        let boostedAmplitude = min(1.0, amplitude * 1.5) // Boost by 50% for stronger response
                        let baseHeight = minHeight + (CGFloat(wave) * maxHeight * CGFloat(envelope) - minHeight) * boostedAmplitude
                        let height = max(minHeight, baseHeight)

                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: adaptiveWaveColors,
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(width: max(barWidth, 1), height: height)
                            .animation(.linear(duration: 0.1), value: amplitude)
                    }
                }
                .blendMode(preferences.glassStyle == .clear ? .difference : .normal)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            }
        }
        .frame(height: 22)
    }
}
