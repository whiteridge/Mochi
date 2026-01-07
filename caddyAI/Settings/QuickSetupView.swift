import SwiftUI

// #region agent log helper
private func debugLog(location: String, message: String, data: [String: Any], hypothesisId: String) {
    let logPath = "/Users/matteofari/Desktop/projects/caddyAI/.cursor/debug.log"
    let timestamp = Int(Date().timeIntervalSince1970 * 1000)
    var jsonData = data
    jsonData["hypothesisId"] = hypothesisId
    let entry: [String: Any] = [
        "location": location,
        "message": message,
        "data": jsonData,
        "timestamp": timestamp,
        "sessionId": "debug-session"
    ]
    if let jsonString = try? JSONSerialization.data(withJSONObject: entry),
       let line = String(data: jsonString, encoding: .utf8) {
        let fileURL = URL(fileURLWithPath: logPath)
        try? FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        if let handle = try? FileHandle(forWritingTo: fileURL) {
            handle.seekToEndOfFile()
            handle.write((line + "\n").data(using: .utf8)!)
            handle.closeFile()
        } else {
            try? (line + "\n").write(toFile: logPath, atomically: true, encoding: .utf8)
        }
    }
}
// #endregion

struct QuickSetupView: View {
    @EnvironmentObject private var integrationService: IntegrationService
    @EnvironmentObject private var viewModel: SettingsViewModel
    @EnvironmentObject private var preferences: PreferencesStore
    
    var onComplete: () -> Void
    
    @State private var connectingSlack = false
    @State private var connectingLinear = false
    
    var body: some View {
        VStack(spacing: 32) {
            // Header
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [preferences.accentColor.opacity(0.2), preferences.accentColor.opacity(0.05)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 88, height: 88)
                    
                    Image(systemName: "sparkles")
                        .font(.system(size: 36, weight: .medium))
                        .foregroundStyle(preferences.accentColor)
                }
                
                Text("Welcome to caddyAI")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                
                Text("Connect your tools to get started")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 32)
            
            // Integration Cards
            VStack(spacing: 16) {
                IntegrationConnectCard(
                    title: "Slack",
                    subtitle: "Send messages and receive alerts",
                    iconName: "slack-icon",
                    fallbackIcon: "bubble.left.and.bubble.right.fill",
                    isConnected: integrationService.slackState.isConnected,
                    isLoading: connectingSlack
                ) {
                    connectSlack()
                }
                
                IntegrationConnectCard(
                    title: "Linear",
                    subtitle: "Create issues and track progress",
                    iconName: "linear-icon",
                    fallbackIcon: "checklist",
                    isConnected: integrationService.linearState.isConnected,
                    isLoading: connectingLinear
                ) {
                    connectLinear()
                }
            }
            .padding(.horizontal, 32)
            
            Spacer()
            
            // Footer
            VStack(spacing: 14) {
                Button {
                    completeSetup()
                } label: {
                    Text(allConnected ? "Get Started" : "Continue")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .tint(preferences.accentColor)
                .disabled(!hasAnyConnection)
                
                Button("Skip for now") {
                    preferences.hasCompletedSetup = true
                    onComplete()
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .font(.subheadline)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 28)
        }
        .frame(width: 420, height: 540)
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    private var allConnected: Bool {
        integrationService.slackState.isConnected && integrationService.linearState.isConnected
    }
    
    private var hasAnyConnection: Bool {
        integrationService.slackState.isConnected || integrationService.linearState.isConnected
    }
    
    private func connectSlack() {
        // #region agent log
        debugLog(location: "QuickSetupView:connectSlack", message: "Connect Slack button pressed", data: [:], hypothesisId: "D")
        // #endregion
        connectingSlack = true
        viewModel.connectViaComposio(appName: "slack")
        pollStatus(app: "slack") {
            connectingSlack = false
        }
    }
    
    private func connectLinear() {
        // #region agent log
        debugLog(location: "QuickSetupView:connectLinear", message: "Connect Linear button pressed", data: [:], hypothesisId: "D")
        // #endregion
        connectingLinear = true
        viewModel.connectViaComposio(appName: "linear")
        pollStatus(app: "linear") {
            connectingLinear = false
        }
    }
    
    private func pollStatus(app: String, completion: @escaping () -> Void) {
        Task {
            // Poll every 2 seconds for up to 60 seconds
            for _ in 0..<30 {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                viewModel.refreshStatus(appName: app)
                
                // Small delay to let the state update
                try? await Task.sleep(nanoseconds: 500_000_000)
                
                let connected = await MainActor.run {
                    app == "slack"
                        ? integrationService.slackState.isConnected
                        : integrationService.linearState.isConnected
                }
                
                if connected {
                    await MainActor.run { completion() }
                    return
                }
            }
            await MainActor.run { completion() }
        }
    }
    
    private func completeSetup() {
        preferences.hasCompletedSetup = true
        onComplete()
    }
}

// MARK: - Integration Connect Card

private struct IntegrationConnectCard: View {
    let title: String
    let subtitle: String
    let iconName: String
    let fallbackIcon: String
    let isConnected: Bool
    let isLoading: Bool
    let action: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            // App icon
            Group {
                if let nsImage = NSImage(named: iconName) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.gray.opacity(0.15))
                        Image(systemName: fallbackIcon)
                            .font(.system(size: 22))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(width: 48, height: 48)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            if isConnected {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.green)
                    Text("Connected")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            } else if isLoading {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("Waiting...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                Button("Connect") {
                    action()
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(NSColor.controlBackgroundColor))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(isConnected ? Color.green.opacity(0.4) : Color.gray.opacity(0.15), lineWidth: 1)
        }
        .animation(.easeInOut(duration: 0.2), value: isConnected)
        .animation(.easeInOut(duration: 0.2), value: isLoading)
    }
}

#Preview {
    let keychain = KeychainStore(service: "com.caddyai.preview")
    let prefs = PreferencesStore()
    let integrationService = IntegrationService(keychain: keychain)
    return QuickSetupView(onComplete: {})
        .environmentObject(prefs)
        .environmentObject(integrationService)
        .environmentObject(SettingsViewModel(
            preferences: prefs,
            integrationService: integrationService
        ))
}

