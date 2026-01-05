import SwiftUI

struct StatusPillView: View {
    enum Status: Equatable {
        case thinking
        case searching(app: String)
        case transcribing
        
        var appName: String? {
            switch self {
            case .thinking: return "thinking"
            case .searching(let app): return app
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
    }
    
    let status: Status
    var isCompact: Bool = false
    @Namespace private var animation
    
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
        default:
            return "waveform"
        }
    }
    
    // Display text - just app name when compact, full text otherwise
    private var displayText: String {
        if isCompact, let app = status.appName {
            return app
        }
        return status.displayPrefix
    }

    var body: some View {
        HStack(spacing: 10) {
            // Circular icon at left edge
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.15))
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
                            .foregroundStyle(.white)
                    }
                }
                .id(status.appName ?? "none") // Animate icon change
            }
            
            // Text area
            HStack(spacing: 0) {
                if !isCompact {
                    Text(displayText)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .id(displayText) // Trigger transition when text changes
                        .transition(.asymmetric(
                            insertion: .move(edge: .top).combined(with: .opacity),
                            removal: .move(edge: .bottom).combined(with: .opacity)
                        ))
                }
                
                // App name for searching
                if case .searching(let app) = status, !isCompact {
                    Text(" \(app)")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .id(app)
                        .transition(.asymmetric(
                            insertion: .move(edge: .top).combined(with: .opacity),
                            removal: .move(edge: .bottom).combined(with: .opacity)
                        ))
                }
                
                // Bouncing dots
                if !isCompact {
                    BouncingDotsView()
                        .padding(.leading, 2)
                        .offset(y: 1)
                        .transition(.opacity)
                }
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: status)
            .animation(.easeInOut(duration: 0.3), value: isCompact)
        }
        .padding(.leading, 5)
        .padding(.trailing, 14)
        .padding(.vertical, 5)
        .background(GlassBackground(cornerRadius: 20))
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

// Added back for backward compatibility if needed, though we'll update callers
extension StatusPillView {
    init(text: String, appName: String?, isCompact: Bool = false) {
        let status: Status
        if text.lowercased().contains("thinking") || appName?.lowercased() == "thinking" {
            status = .thinking
        } else if text.lowercased().contains("transcribing") {
            status = .transcribing
        } else if let app = appName {
            status = .searching(app: app)
        } else {
            status = .searching(app: text) // Fallback
        }
        self.init(status: status, isCompact: isCompact)
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