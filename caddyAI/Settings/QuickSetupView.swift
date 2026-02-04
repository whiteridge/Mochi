import SwiftUI

struct QuickSetupView: View {
    static let preferredSize = CGSize(width: 520, height: 700)
    @EnvironmentObject private var integrationService: IntegrationService
    @EnvironmentObject private var viewModel: SettingsViewModel
    @EnvironmentObject private var preferences: PreferencesStore
    @Environment(\.colorScheme) private var colorScheme
    
    var onComplete: () -> Void
    
    @State private var connectingSlack = false
    @State private var connectingLinear = false
    @State private var connectingNotion = false
    @State private var connectingGitHub = false
    @State private var connectingGmail = false
    @State private var connectingGoogleCalendar = false
    @State private var slackError: String?
    @State private var linearError: String?
    @State private var notionError: String?
    @State private var githubError: String?
    @State private var gmailError: String?
    @State private var googleCalendarError: String?
    @State private var apiSaveSuccess = false
    @State private var apiError: String?

    private var backgroundGradient: LinearGradient {
        let colors: [Color] = colorScheme == .dark
            ? [
                Color(red: 0.08, green: 0.09, blue: 0.1),
                Color(red: 0.12, green: 0.14, blue: 0.16)
            ]
            : [
                Color(red: 0.97, green: 0.98, blue: 0.99),
                Color(red: 0.9, green: 0.92, blue: 0.94)
            ]
        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    
    var body: some View {
        ScrollView {
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
                    
                    Text("Add your API key and connect at least one integration")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 32)
                
                // Required: API Key
                VStack(alignment: .leading, spacing: 12) {
                    Text("API Key")
                        .font(.headline)
                    Text("Required to run the model.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    HStack(spacing: 10) {
                        SecureField("Enter key", text: $viewModel.apiKey)
                            .textFieldStyle(.roundedBorder)
                        
                        Button(apiSaveSuccess ? "Saved" : "Save") {
                            saveAPIKey()
                        }
                        .buttonStyle(SettingsGlassButtonStyle(kind: .accent(apiSaveSuccess ? .green : preferences.accentColor)))
                        .controlSize(.small)
                        .disabled(!hasAPIKey)
                    }
                    
                    if let apiError {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundStyle(.orange)
                            Text(apiError)
                                .font(.caption)
                                .foregroundStyle(.orange)
                                .lineLimit(2)
                        }
                    }
                }
                .padding(16)
                .background(
                    LiquidGlassSurface(shape: .roundedRect(14), prominence: .regular, glassStyleOverride: .regular)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(apiBorderColor, lineWidth: 1)
                }
                .padding(.horizontal, 32)
                
                // Integration Cards
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Connect an integration")
                            .font(.headline)
                        Text("Composio handles OAuth. You can add more later in Settings.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 4)

                    IntegrationConnectCard(
                        title: "Slack",
                        subtitle: "Send messages and receive alerts",
                        iconName: "slack-icon",
                        fallbackIcon: "bubble.left.and.bubble.right.fill",
                        isConnected: integrationService.slackState.isConnected,
                        isLoading: connectingSlack,
                        errorMessage: slackError
                    ) {
                        connectSlack()
                    }
                    
                    IntegrationConnectCard(
                        title: "Linear",
                        subtitle: "Create issues and track progress",
                        iconName: "linear-icon",
                        fallbackIcon: "checklist",
                        isConnected: integrationService.linearState.isConnected,
                        isLoading: connectingLinear,
                        errorMessage: linearError
                    ) {
                        connectLinear()
                    }
                    
                    IntegrationConnectCard(
                        title: "Notion",
                        subtitle: "Search pages and update docs",
                        iconName: "notion-icon",
                        fallbackIcon: "doc.text",
                        isConnected: integrationService.notionState.isConnected,
                        isLoading: connectingNotion,
                        errorMessage: notionError
                    ) {
                        connectNotion()
                    }
                    
                    IntegrationConnectCard(
                        title: "GitHub",
                        subtitle: "Find issues and update repos",
                        iconName: "github-icon",
                        fallbackIcon: "chevron.left.forwardslash.chevron.right",
                        isConnected: integrationService.githubState.isConnected,
                        isLoading: connectingGitHub,
                        errorMessage: githubError
                    ) {
                        connectGitHub()
                    }
                    
                    IntegrationConnectCard(
                        title: "Gmail",
                        subtitle: "Read and send email securely",
                        iconName: "gmail-icon",
                        fallbackIcon: "envelope.fill",
                        isConnected: integrationService.gmailState.isConnected,
                        isLoading: connectingGmail,
                        errorMessage: gmailError
                    ) {
                        connectGmail()
                    }
                    
                    IntegrationConnectCard(
                        title: "Google Calendar",
                        subtitle: "Manage meetings and availability",
                        iconName: "calendar-icon",
                        fallbackIcon: "calendar",
                        isConnected: integrationService.googleCalendarState.isConnected,
                        isLoading: connectingGoogleCalendar,
                        errorMessage: googleCalendarError
                    ) {
                        connectGoogleCalendar()
                    }
                }
                .padding(.horizontal, 32)
                
                // Footer
                VStack(spacing: 14) {
                    Button {
                        completeSetup()
                    } label: {
                        Text(isSetupReady ? "Finish setup" : "Complete setup")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(SettingsGlassButtonStyle(kind: .accent(preferences.accentColor), prominence: .regular))
                    .disabled(!isSetupReady)
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 28)
        }
        .scrollIndicators(.hidden)
        .frame(width: Self.preferredSize.width, height: Self.preferredSize.height)
        .background(backgroundGradient)
        .onAppear {
            viewModel.loadPersistedValues()
            // Refresh connection status when view appears
            viewModel.refreshStatus(appName: "slack")
            viewModel.refreshStatus(appName: "linear")
            viewModel.refreshStatus(appName: "notion")
            viewModel.refreshStatus(appName: "github")
            viewModel.refreshStatus(appName: "gmail")
            viewModel.refreshStatus(appName: "googlecalendar")
        }
        .onChange(of: viewModel.apiKey) {
            apiSaveSuccess = false
            apiError = nil
        }
    }
    
    private var hasAPIKey: Bool {
        !viewModel.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private var hasAnyConnection: Bool {
        integrationService.hasAnyComposioConnection
    }
    
    private var isSetupReady: Bool {
        hasAPIKey && hasAnyConnection
    }
    
    private var apiBorderColor: Color {
        if apiError != nil {
            return Color.orange.opacity(0.4)
        }
        if hasAPIKey {
            return Color.green.opacity(0.4)
        }
        return Color.gray.opacity(0.15)
    }
    
    private func connectSlack() {
        slackError = nil
        connectingSlack = true
        Task { @MainActor in
            let error = await viewModel.connectViaComposioAsync(appName: "slack")
            DispatchQueue.main.async {
                if let error = error {
                    self.slackError = error
                    self.connectingSlack = false
                } else {
                    self.pollStatus(app: "slack") {
                        self.connectingSlack = false
                    }
                }
            }
        }
    }
    
    private func connectLinear() {
        linearError = nil
        connectingLinear = true
        Task { @MainActor in
            let error = await viewModel.connectViaComposioAsync(appName: "linear")
            DispatchQueue.main.async {
                if let error = error {
                    self.linearError = error
                    self.connectingLinear = false
                } else {
                    self.pollStatus(app: "linear") {
                        self.connectingLinear = false
                    }
                }
            }
        }
    }

    private func connectNotion() {
        notionError = nil
        connectingNotion = true
        Task { @MainActor in
            let error = await viewModel.connectViaComposioAsync(appName: "notion")
            DispatchQueue.main.async {
                if let error = error {
                    self.notionError = error
                    self.connectingNotion = false
                } else {
                    self.pollStatus(app: "notion") {
                        self.connectingNotion = false
                    }
                }
            }
        }
    }

    private func connectGitHub() {
        githubError = nil
        connectingGitHub = true
        Task { @MainActor in
            let error = await viewModel.connectViaComposioAsync(appName: "github")
            DispatchQueue.main.async {
                if let error = error {
                    self.githubError = error
                    self.connectingGitHub = false
                } else {
                    self.pollStatus(app: "github") {
                        self.connectingGitHub = false
                    }
                }
            }
        }
    }

    private func connectGmail() {
        gmailError = nil
        connectingGmail = true
        Task { @MainActor in
            let error = await viewModel.connectViaComposioAsync(appName: "gmail")
            DispatchQueue.main.async {
                if let error = error {
                    self.gmailError = error
                    self.connectingGmail = false
                } else {
                    self.pollStatus(app: "gmail") {
                        self.connectingGmail = false
                    }
                }
            }
        }
    }

    private func connectGoogleCalendar() {
        googleCalendarError = nil
        connectingGoogleCalendar = true
        Task { @MainActor in
            let error = await viewModel.connectViaComposioAsync(appName: "googlecalendar")
            DispatchQueue.main.async {
                if let error = error {
                    self.googleCalendarError = error
                    self.connectingGoogleCalendar = false
                } else {
                    self.pollStatus(app: "googlecalendar") {
                        self.connectingGoogleCalendar = false
                    }
                }
            }
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
                    switch app {
                    case "slack":
                        return integrationService.slackState.isConnected
                    case "linear":
                        return integrationService.linearState.isConnected
                    case "notion":
                        return integrationService.notionState.isConnected
                    case "github":
                        return integrationService.githubState.isConnected
                    case "gmail":
                        return integrationService.gmailState.isConnected
                    case "googlecalendar", "google_calendar":
                        return integrationService.googleCalendarState.isConnected
                    default:
                        return false
                    }
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
        guard hasAPIKey, hasAnyConnection else {
            apiError = hasAPIKey ? nil : "Add your API key to continue."
            return
        }
        viewModel.saveAPISettings()
        preferences.hasCompletedSetup = true
        onComplete()
    }

    private func saveAPIKey() {
        apiError = nil
        guard hasAPIKey else {
            apiError = "Add your API key to save."
            return
        }
        viewModel.saveAPISettings()
        apiSaveSuccess = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            apiSaveSuccess = false
        }
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
    let errorMessage: String?
    let action: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var preferences: PreferencesStore

    private var palette: LiquidGlassPalette {
        LiquidGlassPalette(colorScheme: colorScheme, glassStyle: .regular)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 16) {
                // App icon
                Group {
                    if let nsImage = NSImage(named: iconName) {
                        Image(nsImage: nsImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    } else {
                        ZStack {
                            LiquidGlassSurface(
                                shape: .roundedRect(10),
                                prominence: .subtle,
                                shadowed: false,
                                glassStyleOverride: .regular
                            )
                            Image(systemName: fallbackIcon)
                                .font(.system(size: 22))
                                .foregroundStyle(palette.secondaryText)
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
                    .buttonStyle(SettingsGlassButtonStyle(kind: .accent(preferences.accentColor)))
                    .controlSize(.regular)
                }
            }
            
            // Error message
            if let errorMessage = errorMessage {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .lineLimit(2)
                }
                .padding(.horizontal, 4)
            }
        }
        .padding(16)
        .background(
            LiquidGlassSurface(shape: .roundedRect(14), prominence: .regular, glassStyleOverride: .regular)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(borderColor, lineWidth: 1)
        }
        .animation(.easeInOut(duration: 0.2), value: isConnected)
        .animation(.easeInOut(duration: 0.2), value: isLoading)
        .animation(.easeInOut(duration: 0.2), value: errorMessage)
    }
    
    private var borderColor: Color {
        if isConnected {
            return Color.green.opacity(0.4)
        } else if errorMessage != nil {
            return Color.orange.opacity(0.4)
        } else {
            return Color.gray.opacity(0.15)
        }
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
