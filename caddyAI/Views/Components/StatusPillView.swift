import SwiftUI

struct StatusPillView: View {
    enum Status: Equatable {
        case thinking
        case searching(app: String)
        case transcribing
        
        var appName: String? {
            switch self {
            case .thinking: return "thinking"
            case .searching(let app): 
                // "Action" is an internal ID, display as "Conductor" or generic
                return app.lowercased() == "action" ? "Conductor" : app
            case .transcribing: return nil
            }
        }
        
        var displayPrefix: String {
            switch self {
            case .thinking: return "Thinking"
            case .searching: return "Searching"
            case .transcribing: return "Transcribing"
            }
        }
        
        /// Full display text for the status
        var fullDisplayText: String {
            switch self {
            case .thinking: return "Thinking"
            case .searching(let app):
                let displayApp = app.lowercased() == "action" ? "Conductor" : app
                return "Searching \(displayApp)"
            case .transcribing: return "Transcribing"
            }
        }
    }
    
    let status: Status
    var isCompact: Bool = false
    var morphNamespace: Namespace.ID? = nil
    @Environment(\.colorScheme) private var colorScheme

    private var palette: LiquidGlassPalette {
        LiquidGlassPalette(colorScheme: colorScheme)
    }
    
    // Check if this app has a custom asset icon
    private var customIconName: String? {
        guard let app = status.appName?.lowercased() else { return nil }
        switch app {
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
        guard let app = status.appName?.lowercased() else { return "waveform" }
        switch app {
        case "github":
            return "chevron.left.forwardslash.chevron.right"
        case "notion":
            return "doc.text"
        case "google":
            return "globe"
        case "thinking":
            return "brain"
        case "conductor":
            return "command"
        default:
            return "waveform"
        }
    }
    
    // Compact mode shows just the app name (e.g., "Linear")
    private var compactText: String? {
        guard isCompact else { return nil }
        if case .searching = status {
            return status.appName?.capitalized
        }
        return nil
    }

    var body: some View {
        HStack(spacing: isCompact ? 8 : 10) {
            // Circular icon at left edge
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
                .contentTransition(.symbolEffect(.replace))
            }
            
            // Compact mode: show app name only
            if isCompact {
                if let compactName = compactText {
                    Text(compactName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(palette.primaryText)
                        .lineLimit(1)
                }
            } else {
                // Full mode: show status text with smooth transitions + bouncing dots
                Text(status.fullDisplayText)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(palette.primaryText)
                    .lineLimit(1)
                    .contentTransition(.numericText())
                    // Slower animation - response 0.6 instead of 0.4
                    .animation(.spring(response: 0.6, dampingFraction: 0.75), value: status.fullDisplayText)
                
                // Bouncing dots using TimelineView - always animates
                ContinuousBouncingDotsView(dotColor: palette.primaryText)
            }
        }
        .padding(.leading, 5)
        .padding(.trailing, isCompact ? 12 : 14)
        .padding(.vertical, 5)
        .background(pillBackground)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(palette.subtleBorder, lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: status.appName)
        .animation(.easeInOut(duration: 0.3), value: isCompact)
    }

    @ViewBuilder
    private var pillBackground: some View {
        if let morphNamespace {
            LiquidGlassDockBackground()
                .matchedGeometryEffect(id: "background", in: morphNamespace)
        } else {
            GlassBackground(cornerRadius: 20, prominence: .subtle, shadowed: false)
        }
    }
}

extension StatusPillView {
    init(text: String, appName: String?, isCompact: Bool = false, morphNamespace: Namespace.ID? = nil) {
        let status: Status
        if text.lowercased().contains("thinking") || appName?.lowercased() == "thinking" {
            status = .thinking
        } else if text.lowercased().contains("transcribing") {
            status = .transcribing
        } else if let app = appName {
            status = .searching(app: app)
        } else {
            status = .searching(app: text)
        }
        self.init(status: status, isCompact: isCompact, morphNamespace: morphNamespace)
    }
}

// MARK: - Continuous Bouncing Dots using TimelineView

/// Bouncing dots that use TimelineView for continuous animation regardless of view updates
struct ContinuousBouncingDotsView: View {
    var dotColor: Color = .white

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.016)) { timeline in
            HStack(spacing: 3) {
                ForEach(0..<3, id: \.self) { index in
                    let time = timeline.date.timeIntervalSinceReferenceDate
                    // Each dot has a phase offset
                    let phase = time + Double(index) * 0.15
                    // Oscillate between 0 and 1 with period of 0.8 seconds (0.4 up, 0.4 down)
                    let normalizedPhase = phase.truncatingRemainder(dividingBy: 0.8) / 0.8
                    // Convert to smooth sine wave bounce
                    let bounce = sin(normalizedPhase * .pi)
                    
                    Circle()
                        .fill(dotColor)
                        .frame(width: 3, height: 3)
                        .offset(y: -3 * bounce)
                }
            }
            .offset(y: 1)
        }
    }
}

// Legacy support
struct BouncingDotsView: View, Equatable {
    var body: some View {
        ContinuousBouncingDotsView()
    }
    
    static func == (lhs: BouncingDotsView, rhs: BouncingDotsView) -> Bool {
        true
    }
}

struct PersistentBouncingDotsView: View {
    var body: some View {
        ContinuousBouncingDotsView()
    }
}
