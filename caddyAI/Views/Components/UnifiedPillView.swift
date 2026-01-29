import SwiftUI

/// Unified pill component that handles both recording and thinking/searching states.
/// This enables smooth morphing animations between states instead of view replacement.
enum UnifiedPillMode: Equatable {
    case recording(amplitude: CGFloat)
    case thinking
    case searching(app: String)
    
    var isRecording: Bool {
        if case .recording = self { return true }
        return false
    }
    
    var appName: String? {
        switch self {
        case .recording: return nil
        case .thinking: return "thinking"
        case .searching(let app): return app.lowercased() == "action" ? "Conductor" : app
        }
    }
}

struct UnifiedPillView: View {
    let mode: UnifiedPillMode
    let morphNamespace: Namespace.ID
    
    // Actions for recording mode
    var stopRecording: (() -> Void)?
    var cancelRecording: (() -> Void)?
    
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var preferences: PreferencesStore
    @State private var hasSettledFromAppear: Bool = false
    
    private var palette: LiquidGlassPalette {
        LiquidGlassPalette(colorScheme: colorScheme, glassStyle: preferences.glassStyle)
    }
    
    // MARK: - Icon Configuration
    
    private var normalizedAppName: String {
        guard let app = mode.appName?.lowercased() else { return "" }
        return app
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: "-", with: "")
    }
    
    private var customIconName: String? {
        switch normalizedAppName {
        case "linear": return "linear-icon"
        case "slack": return "slack-icon"
        case "notion": return "notion-icon"
        case "gmail", "googlemail": return "gmail-icon"
        case "calendar", "googlecalendar", "google": return "calendar-icon"
        case "github": return "github-icon"
        default: return nil
        }
    }
    
    private var sfSymbolName: String {
        switch normalizedAppName {
        case "github": return "chevron.left.forwardslash.chevron.right"
        case "notion": return "doc.text"
        case "gmail", "googlemail": return "envelope"
        case "calendar", "googlecalendar", "google": return "calendar"
        case "thinking": return "brain"
        case "action", "conductor": return "command"
        default: return "waveform"
        }
    }
    
    private var displayAppName: String? {
        guard let app = mode.appName else { return nil }
        switch normalizedAppName {
        case "linear": return "Linear"
        case "slack": return "Slack"
        case "notion": return "Notion"
        case "gmail", "googlemail": return "Gmail"
        case "calendar", "googlecalendar", "google": return "Calendar"
        case "github": return "GitHub"
        case "action", "conductor": return "Conductor"
        default:
            return app
                .replacingOccurrences(of: "_", with: " ")
                .replacingOccurrences(of: "-", with: " ")
                .split(separator: " ")
                .map { $0.capitalized }
                .joined(separator: " ")
        }
    }
    
    private var statusText: String {
        switch mode {
        case .recording: return ""
        case .thinking: return "Thinking"
        case .searching:
            let appName = displayAppName ?? "App"
            return "Searching \(appName)"
        }
    }

    private var bubbleShadowColor: Color {
        colorScheme == .dark ? Color.black.opacity(0.5) : Color.black.opacity(0.28)
    }

    private var bubbleShadowRadius: CGFloat {
        colorScheme == .dark ? 10 : 14
    }

    private var bubbleShadowY: CGFloat {
        colorScheme == .dark ? 5 : 9
    }
    
    // MARK: - Body
    
    var body: some View {
        if #available(macOS 26.0, iOS 26.0, *) {
            nativeBody
        } else {
            legacyBody
        }
    }
    
    @available(macOS 26.0, iOS 26.0, *)
    private var nativeBody: some View {
        let paneFill = GlassBackdropStyle.paneFill(for: preferences.glassStyle, colorScheme: colorScheme)
        
        return pillContent
            .padding(.horizontal, 8)
            .padding(.vertical, 7)
            .background(AnyShapeStyle(paneFill), in: .capsule)
            .glassEffect(.clear, in: .capsule)
            .overlay(GlassCloudOverlay(Capsule(), isEnabled: preferences.glassStyle == .regular))
            .matchedGeometryEffect(id: "background", in: morphNamespace)
            .shadow(color: bubbleShadowColor, radius: bubbleShadowRadius, x: 0, y: bubbleShadowY)
            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: mode)
            .scaleEffect(hasSettledFromAppear ? 1.0 : 1.08)
            .onAppear {
                guard !hasSettledFromAppear else { return }
                withAnimation(.spring(response: 0.25, dampingFraction: 0.55, blendDuration: 0)) {
                    hasSettledFromAppear = true
                }
            }
    }
    
    private var legacyBody: some View {
        pillContent
            .padding(.horizontal, 8)
            .padding(.vertical, 7)
            .background(
                LiquidGlassDockBackground()
                    .matchedGeometryEffect(id: "background", in: morphNamespace)
            )
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(palette.subtleBorder, lineWidth: 0.5)
            )
            .shadow(color: bubbleShadowColor, radius: bubbleShadowRadius, x: 0, y: bubbleShadowY)
            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: mode)
            .scaleEffect(hasSettledFromAppear ? 1.0 : 1.08)
            .onAppear {
                guard !hasSettledFromAppear else { return }
                withAnimation(.spring(response: 0.25, dampingFraction: 0.55, blendDuration: 0)) {
                    hasSettledFromAppear = true
                }
            }
    }
    
    // MARK: - Content
    
    private var pillContent: some View {
        HStack(spacing: 6) {
            // Left button: Cancel (X) for recording, App icon for thinking/searching
            leftButton
                .matchedGeometryEffect(id: "appIcon", in: morphNamespace)
            
            // Center content: Wave bars for recording, Status text for thinking/searching
            centerContent
                .frame(minWidth: 72, alignment: .center)
            
            // Right button: Action button (stop for recording, dots indicator for thinking)
            if mode.isRecording {
                rightButton
                    .matchedGeometryEffect(id: "actionButton", in: morphNamespace)
            }
        }
    }
    
    @ViewBuilder
    private var leftButton: some View {
        if mode.isRecording {
            // Cancel button (X)
            Button(action: { cancelRecording?() }) {
                Circle()
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
                            .foregroundStyle(palette.iconPrimary)
                    )
            }
            .buttonStyle(.plain)
        } else {
            // App icon circle
            ZStack {
                Circle()
                    .fill(palette.iconBackground)
                    .frame(width: 32, height: 32)
                
                Group {
                    if let customIcon = customIconName {
                        Image(customIcon)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 22, height: 22)
                            .clipShape(Circle())
                    } else {
                        Image(systemName: sfSymbolName)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(palette.iconPrimary)
                    }
                }
                .contentTransition(.symbolEffect(.replace))
            }
        }
    }
    
    @ViewBuilder
    private var centerContent: some View {
        switch mode {
        case .recording(let amplitude):
            // Animated wave bars
            AnimatedDotRow(count: 10, amplitude: amplitude)
                .frame(width: 72, height: 22)
                .transition(.opacity.combined(with: .scale(scale: 0.8)))
        case .thinking, .searching:
            // Status text + bouncing dots
            HStack(spacing: 10) {
                Text(statusText)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(palette.primaryText)
                    .lineLimit(1)
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.6, dampingFraction: 0.75), value: statusText)
                
                ContinuousBouncingDotsView(dotColor: palette.primaryText)
                    .padding(.trailing, 4)
            }
            .transition(.opacity.combined(with: .scale(scale: 0.8)))
        }
    }
    
    @ViewBuilder
    private var rightButton: some View {
        // Stop button
        VoiceActionButton(
            size: 32,
            isRecording: true,
            action: { stopRecording?() }
        )
    }
}
