import SwiftUI

/// A view that displays multiple app status pills in a horizontal row.
/// Completed apps collapse to just show the icon; the active app shows full text with glowing border.
struct MultiStatusPillView: View {
    let appSteps: [AppStep]
    let activeAppId: String?
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(appSteps) { step in
                AppPillView(
                    appId: step.appId,
                    state: step.state,
                    isActive: step.appId == activeAppId
                )
            }
        }
    }
}

/// Individual app pill that can be in different states
struct AppPillView: View {
    let appId: String
    let state: AppStepState
    let isActive: Bool
    @Environment(\.colorScheme) private var colorScheme

    private var palette: LiquidGlassPalette {
        LiquidGlassPalette(colorScheme: colorScheme)
    }
    
    // Check if this app has a custom asset icon
    private var customIconName: String? {
        switch appId.lowercased() {
        case "linear":
            return "linear-icon"
        case "slack":
            return "slack-icon"
        default:
            return nil
        }
    }
    
    // Fallback SF Symbol for apps without custom icons
    private var sfSymbolName: String {
        switch appId.lowercased() {
        case "github":
            return "chevron.left.forwardslash.chevron.right"
        case "notion":
            return "doc.text"
        case "google":
            return "globe"
        default:
            return "sparkles"
        }
    }
    
    /// Show full text for active/searching states, icon only when done
    private var showText: Bool {
        state != .done
    }
    
    /// Show bouncing dots when searching
    private var showDots: Bool {
        state == .searching
    }
    
    private var borderColor: Color {
        switch state {
        case .error:
            return .red.opacity(0.9)
        case .active, .searching:
            return palette.subtleBorder
        default:
            return palette.subtleBorder.opacity(0.7)
        }
    }
    
    var body: some View {
        HStack(spacing: showText ? 10 : 0) {
            // Circular icon
            ZStack {
                Circle()
                    .fill(palette.iconBackground)
                    .frame(width: 28, height: 28)
                
                Group {
                    if let customIcon = customIconName {
                        Image(customIcon)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 20, height: 20)
                            .clipShape(Circle())
                    } else {
                        Image(systemName: sfSymbolName)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(palette.iconPrimary)
                    }
                }
            }
            
            // Text area - only shown when not done
            if showText {
                HStack(spacing: 0) {
                    // "Searching " prefix - only when actively searching
                    if state == .searching {
                        Text("Searching ")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(palette.primaryText)
                    }
                    
                    // App name
                    Text(appId.capitalized)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(palette.primaryText)
                    
                    // Bouncing dots when searching
                    if showDots {
                        ContinuousBouncingDotsView(dotColor: palette.primaryText)
                            .padding(.leading, 2)
                            .offset(y: 1)
                    }
                }
            }
        }
        .padding(.leading, 5)
        .padding(.trailing, showText ? 14 : 5)
        .padding(.vertical, 5)
        .background(
            ZStack {
                GlassBackground(cornerRadius: 20, prominence: .subtle, shadowed: false)
                
                // Glowing effect for active state
                if isActive && (state == .searching || state == .active) {
                    RotatingLightBackground(
                        cornerRadius: 20,
                        shape: .capsule,
                        rotationSpeed: 5.0,
                        glowColor: .green
                    )
                    .padding(-1)
                }
            }
        )
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(borderColor, lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
        // Dim non-active, non-done pills
        .opacity(state == .waiting ? 0.6 : 1.0)
        .animation(.easeInOut(duration: 0.3), value: state)
        .animation(.easeInOut(duration: 0.3), value: showText)
    }
}

#Preview {
    VStack(spacing: 20) {
        // Multi-app: Linear active, Slack waiting
        MultiStatusPillView(
            appSteps: [
                AppStep(appId: "linear", state: .searching, proposalIndex: 0),
                AppStep(appId: "slack", state: .waiting, proposalIndex: 1)
            ],
            activeAppId: "linear"
        )
        
        // Multi-app: Linear done, Slack active
        MultiStatusPillView(
            appSteps: [
                AppStep(appId: "linear", state: .done, proposalIndex: 0),
                AppStep(appId: "slack", state: .active, proposalIndex: 1)
            ],
            activeAppId: "slack"
        )
    }
    .padding()
    .background(Color.black)
}
