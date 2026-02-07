import SwiftUI

struct ActionGlowButton: View {
    let title: String
    let isExecuting: Bool
    let action: () -> Void
    var height: CGFloat = 48
    var horizontalPadding: CGFloat = 24
    var gradientNamespace: Namespace.ID? = nil

    var body: some View {
        Button(action: action) {
            ActionGlowButtonLabel(title: title, isExecuting: isExecuting)
                .padding(.horizontal, horizontalPadding)
                .frame(height: height)
                .background(ActionGlowCapsuleBackground(showRing: isExecuting, gradientNamespace: gradientNamespace))
        }
        .buttonStyle(.plain)
    }
}

private struct ActionGlowButtonLabel: View {
    let title: String
    let isExecuting: Bool
    
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var preferences: PreferencesStore
    
    private var palette: LiquidGlassPalette {
        LiquidGlassPalette(colorScheme: colorScheme, glassStyle: preferences.glassStyle)
    }
    
    private var labelColor: Color {
        palette.primaryText
    }

    var body: some View {
        ZStack {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(labelColor)
                .offset(y: isExecuting ? 12 : 0)
                .opacity(isExecuting ? 0 : 1)

            ActionBouncingDotsView(dotColor: labelColor, dotSize: 4)
                .offset(y: isExecuting ? 0 : -12)
                .opacity(isExecuting ? 1 : 0)
        }
        .frame(height: 20)
        .clipped()
        .animation(.spring(response: 0.35, dampingFraction: 0.82), value: isExecuting)
    }
}

private struct ActionBouncingDotsView: View {
    var dotColor: Color = .white
    var dotSize: CGFloat = 4

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.016)) { timeline in
            HStack(spacing: dotSize) {
                ForEach(0..<3, id: \.self) { index in
                    let time = timeline.date.timeIntervalSinceReferenceDate
                    let phase = time + Double(index) * 0.15
                    let normalizedPhase = phase.truncatingRemainder(dividingBy: 0.8) / 0.8
                    let bounce = sin(normalizedPhase * .pi)
                    
                    Circle()
                        .fill(dotColor)
                        .frame(width: dotSize, height: dotSize)
                        .offset(y: -4 * bounce)
                }
            }
            .offset(y: 1)
        }
    }
}
