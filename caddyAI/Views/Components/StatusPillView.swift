import SwiftUI

struct StatusPillView: View {
    let text: String
    let appName: String?  // Optional app name for dynamic icon
    var isCompact: Bool = false  // When true, shows just app name (no "Searching", no dots)
    @Namespace private var animation
    
    // Check if this app has a custom asset icon
    private var customIconName: String? {
        guard let app = appName?.lowercased() else { return nil }
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
        guard let app = appName?.lowercased() else { return "waveform" }
        switch app {
        case "github":
            return "chevron.left.forwardslash.chevron.right"
        case "notion":
            return "doc.text"
        case "google":
            return "globe"
        default:
            return "waveform"
        }
    }
    
    // Display text - just app name when compact, full text otherwise
    private var displayText: String {
        if isCompact, let app = appName {
            return app
        }
        return text.replacingOccurrences(of: "...", with: "")
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
                            .clipShape(Circle()) // Clip to circle, hides square edges
                    } else {
                        Image(systemName: sfSymbolName)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                }
            }
            
            // Text area - "Searching" prefix animates separately from app name
            HStack(spacing: 0) {
                // "Searching " prefix - slides up and fades when compact
                if !isCompact {
                    Text("Searching ")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .transition(.asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .move(edge: .top).combined(with: .opacity)
                        ))
                }
                
                // App name - stays in place
                if let app = appName {
                    Text(app)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                }
                
                // Bouncing dots - fade out when compact
                if !isCompact {
                    BouncingDotsView()
                        .padding(.leading, 2)
                        .offset(y: 1)
                        .transition(.opacity)
                }
            }
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
