import SwiftUI

enum SettingsSidebarItem: Identifiable {
	case section(SettingsSection)
	case separator
	
	var id: String {
		switch self {
		case .section(let section): return section.rawValue
		case .separator: return "separator"
		}
	}
	
	static var allItems: [SettingsSidebarItem] {
		[.section(.general), .section(.integrations), .separator, .section(.about)]
	}
}

enum SettingsSection: String, CaseIterable, Identifiable {
	case general, integrations, about
	var id: String { rawValue }
	var label: String {
		switch self {
		case .general: "General"
		case .integrations: "Integrations"
		case .about: "About"
		}
	}
	var icon: String {
		switch self {
		case .general: "gearshape"
		case .integrations: "link"
		case .about: "info.circle"
		}
	}
}

final class SettingsViewModel: ObservableObject {
	@Published var selectedSection: SettingsSection = .general
	@Published var slackToken: String = ""
	@Published var linearApiKey: String = ""
	@Published var linearTeamKey: String = ""
	@Published var apiKey: String = ""
	@Published var apiBaseURL: String = ""
	@Published var selectedProvider: ModelProvider = .google {
		didSet { syncProviderState() }
	}
	@Published var selectedModel: String = ModelCatalog.defaultModel(for: .google)
	@Published var customModelName: String = ""
	@Published var ollamaBaseURL: String = ModelProvider.ollama.defaultBaseURL ?? ""
	@Published var lmStudioBaseURL: String = ModelProvider.lmStudio.defaultBaseURL ?? ""
	@Published var customOpenAIBaseURL: String = ""
	@Published var slackWorkspaces: [SlackWorkspace] = []
	@Published var slackChannels: [SlackChannel] = []
	@Published var linearTeams: [LinearTeam] = []
	@Published var linearProjects: [LinearProject] = []
	@Published var apiTestMessage: String?
	@Published var apiTestSuccess: Bool?
	@Published var slackTestMessage: String?
	@Published var slackTestSuccess: Bool?
	@Published var linearTestMessage: String?
	@Published var linearTestSuccess: Bool?
	@Published var notionTestMessage: String?
	@Published var notionTestSuccess: Bool?
	@Published var githubTestMessage: String?
	@Published var githubTestSuccess: Bool?
	@Published var gmailTestMessage: String?
	@Published var gmailTestSuccess: Bool?
	@Published var googleCalendarTestMessage: String?
	@Published var googleCalendarTestSuccess: Bool?
	@Published var accentOptions: [AccentColorOption] = [
		AccentColorOption(id: "blue", name: "Blue", color: Color(red: 0.27, green: 0.54, blue: 0.98), hex: "#4688FA"),
		AccentColorOption(id: "green", name: "Green", color: Color(red: 0.25, green: 0.74, blue: 0.40), hex: "#3FBF66"),
		AccentColorOption(id: "pink", name: "Pink", color: Color(red: 0.91, green: 0.36, blue: 0.61), hex: "#E65C9B"),
		AccentColorOption(id: "orange", name: "Orange", color: Color(red: 0.98, green: 0.52, blue: 0.22), hex: "#FA8438")
	]
	
	private let preferences: PreferencesStore
	private let integrationService: IntegrationService
	private let credentialManager: CredentialManager
	
	init(preferences: PreferencesStore, integrationService: IntegrationService, credentialManager: CredentialManager = .shared) {
		self.preferences = preferences
		self.integrationService = integrationService
		self.credentialManager = credentialManager
		self.slackWorkspaces = integrationService.slackWorkspaces
		self.slackChannels = integrationService.slackChannels
		self.linearTeams = integrationService.linearTeams
		self.linearProjects = integrationService.linearProjects
	}
	
	func loadPersistedValues() {
		credentialManager.loadCredentials()
		selectedProvider = preferences.modelProvider
		selectedModel = preferences.modelName
		customModelName = preferences.customModelName
		ollamaBaseURL = preferences.ollamaBaseURL
		lmStudioBaseURL = preferences.lmStudioBaseURL
		customOpenAIBaseURL = preferences.customOpenAIBaseURL
		migrateLegacyGoogleKeyIfNeeded()
		apiKey = apiKeyForProvider(selectedProvider)
		apiBaseURL = preferences.apiBaseURL
		slackToken = credentialManager.slackKey
		linearApiKey = credentialManager.linearKey
		linearTeamKey = "" // Not managed by CredentialManager yet? Spec only mentioned openai, linear, slack.
		syncProviderState()
	}
	
	func saveAPISettings() {
		saveProviderKey()
		credentialManager.saveCredentials()

		preferences.modelProvider = selectedProvider
		preferences.modelName = selectedModel
		preferences.customModelName = customModelName
		preferences.ollamaBaseURL = ollamaBaseURL
		preferences.lmStudioBaseURL = lmStudioBaseURL
		preferences.customOpenAIBaseURL = customOpenAIBaseURL

		preferences.updateAPI(key: "", baseURL: apiBaseURL) // Clear key from prefs if feasible, or just update base URL
	}

	var isCustomModelSelected: Bool {
		selectedModel == ModelCatalog.customModelId
	}

	var resolvedModelName: String {
		isCustomModelSelected ? customModelName : selectedModel
	}

	var providerBaseURL: String {
		get { baseURL(for: selectedProvider) }
		set { setBaseURL(newValue, for: selectedProvider) }
	}

	var isModelConfigValid: Bool {
		let trimmedModel = resolvedModelName.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !trimmedModel.isEmpty else { return false }
		if selectedProvider.requiresApiKey {
			return !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
		}
		if selectedProvider.supportsBaseURL {
			return !providerBaseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
		}
		return true
	}

	private func baseURL(for provider: ModelProvider) -> String {
		switch provider {
		case .ollama:
			return ollamaBaseURL
		case .lmStudio:
			return lmStudioBaseURL
		case .customOpenAI:
			return customOpenAIBaseURL
		default:
			return ""
		}
	}

	private func setBaseURL(_ value: String, for provider: ModelProvider) {
		switch provider {
		case .ollama:
			ollamaBaseURL = value
		case .lmStudio:
			lmStudioBaseURL = value
		case .customOpenAI:
			customOpenAIBaseURL = value
		default:
			break
		}
	}

	private func apiKeyForProvider(_ provider: ModelProvider) -> String {
		credentialManager.loadCredentials()
		switch provider {
		case .google:
			return credentialManager.googleKey
		case .openai:
			return credentialManager.openaiKey
		case .anthropic:
			return credentialManager.anthropicKey
		default:
			return ""
		}
	}

	private func saveProviderKey() {
		let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
		switch selectedProvider {
		case .google:
			credentialManager.googleKey = trimmedKey
		case .openai:
			credentialManager.openaiKey = trimmedKey
		case .anthropic:
			credentialManager.anthropicKey = trimmedKey
		case .ollama, .lmStudio, .customOpenAI:
			break
		}
	}

	private func syncProviderState() {
		let availableModels = ModelCatalog.models(for: selectedProvider)
		if !availableModels.contains(selectedModel) {
			selectedModel = ModelCatalog.defaultModel(for: selectedProvider)
		}
		if selectedProvider.supportsBaseURL,
		   providerBaseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
		   let defaultURL = selectedProvider.defaultBaseURL {
			providerBaseURL = defaultURL
		}
		apiKey = apiKeyForProvider(selectedProvider)
	}

	private func migrateLegacyGoogleKeyIfNeeded() {
		guard selectedProvider == .google else { return }
		if credentialManager.googleKey.isEmpty, !credentialManager.openaiKey.isEmpty {
			credentialManager.googleKey = credentialManager.openaiKey
			credentialManager.saveCredentials()
		}
	}
	
	func selectAccent(_ option: AccentColorOption) {
		preferences.updateAccentColor(hex: option.hex)
	}
	
	func selectTheme(_ theme: ThemePreference) {
		preferences.theme = theme
	}
	
	func connectSlack() {
		credentialManager.slackKey = slackToken
		credentialManager.saveCredentials()
		
		integrationService.connectSlack(token: slackToken)
		testSlack()
		slackToken = ""
		if integrationService.slackState.isConnected { preferences.hasCompletedSetup = true }
	}
	
	func connectLinear() {
		credentialManager.linearKey = linearApiKey
		credentialManager.saveCredentials()
		
		integrationService.connectLinear(apiKey: linearApiKey, teamKey: linearTeamKey)
		testLinear()
		if integrationService.linearState.isConnected {
			linearApiKey = ""
			linearTeamKey = ""
			preferences.hasCompletedSetup = true
		}
	}

	func connectViaComposio(appName: String) {
		Task {
			_ = await connectViaComposioAsync(appName: appName)
		}
	}
	
	/// Async version that returns an error message if failed, nil on success
	func connectViaComposioAsync(appName: String) async -> String? {
		do {
			let url = try await integrationService.fetchComposioConnectURL(for: appName)
			await MainActor.run {
				_ = NSWorkspace.shared.open(url)
			}
			
			// Poll for status after OAuth completes
			try? await Task.sleep(nanoseconds: 5 * 1_000_000_000)
			refreshStatus(appName: appName)
			return nil // Success
		} catch let error as IntegrationError {
			print("Error connecting via Composio: \(error)")
			return normalizeIntegrationError(error.localizedDescription, appName: appName)
		} catch let error as NSError {
			print("Error connecting via Composio: \(error)")
			
			if error.code == -1004 {
				return "Backend not running. Start with: cd backend && uvicorn main:app --reload"
			}
			return normalizeIntegrationError("Connection failed: \(error.localizedDescription)", appName: appName)
		}
	}

	private func normalizeIntegrationError(_ message: String, appName: String) -> String {
		let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
		let lower = trimmed.lowercased()
		let appLabel = IntegrationKind(rawValue: appName.lowercased())?.displayName ?? appName.capitalized
		let envVar = envVarName(for: appName)

		if lower.contains("auth config") && (lower.contains("not found") || lower.contains("notfound")) {
			if let envVar {
				return "Missing Composio auth config for \(appLabel). Set \(envVar) or create it in Composio."
			}
			return "Missing Composio auth config for \(appLabel). Create it in Composio and retry."
		}

		if lower.contains("multiple") && lower.contains("connected account") {
			return "Multiple \(appLabel) accounts connected. Disconnect extras in Composio and retry."
		}

		if lower.contains("rate limit") || lower.contains("quota") {
			return "Temporarily rate-limited. Please retry in a minute."
		}

		if lower.contains("backend not running") {
			return "Backend not running. Start with: cd backend && uvicorn main:app --reload"
		}

		if trimmed.contains("{") && trimmed.contains("}") {
			return "Connection failed. Check your Composio auth config and try again."
		}

		if trimmed.count > 140 {
			let prefix = trimmed.prefix(140)
			return "\(prefix)…"
		}

		return trimmed
	}

	private func envVarName(for appName: String) -> String? {
		switch appName.lowercased() {
		case "slack":
			return "COMPOSIO_SLACK_AUTH_CONFIG_ID"
		case "linear":
			return "COMPOSIO_LINEAR_AUTH_CONFIG_ID"
		case "notion":
			return "COMPOSIO_NOTION_AUTH_CONFIG_ID"
		case "github":
			return "COMPOSIO_GITHUB_AUTH_CONFIG_ID"
		default:
			return nil
		}
	}

	func refreshStatus(appName: String) {
		integrationService.refreshComposioStatus(for: appName)
	}
	
	/// Polls the connection status for an app until connected or timeout
	/// - Parameters:
	///   - appName: The app name ("slack" or "linear")
	///   - intervalSeconds: Polling interval in seconds (default 2)
	///   - maxAttempts: Maximum number of polling attempts (default 30 = 60 seconds)
	///   - onStatusChange: Called on each poll with current connection status
	/// - Returns: True if connection was successful, false if timed out
	@discardableResult
	func pollConnectionStatus(
		appName: String,
		intervalSeconds: Double = 2.0,
		maxAttempts: Int = 30,
		onStatusChange: ((Bool) -> Void)? = nil
	) async -> Bool {
		for _ in 0..<maxAttempts {
			try? await Task.sleep(nanoseconds: UInt64(intervalSeconds * 1_000_000_000))
			
			// Refresh status from backend
			integrationService.refreshComposioStatus(for: appName)
			
			// Small delay to let the state update propagate
			try? await Task.sleep(nanoseconds: 300_000_000)
			
			let isConnected: Bool = await MainActor.run {
				switch appName.lowercased() {
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
			
			await MainActor.run {
				onStatusChange?(isConnected)
			}
			
			if isConnected {
				return true
			}
		}
		return false
	}
	
	func disconnectSlack() { integrationService.disconnectSlack() }
	func disconnectLinear() { integrationService.disconnectLinear() }
	func disconnectNotion() { integrationService.disconnectNotion() }
	func disconnectGitHub() { integrationService.disconnectGitHub() }
	func disconnectGmail() { integrationService.disconnectGmail() }
	func disconnectGoogleCalendar() { integrationService.disconnectGoogleCalendar() }
	
	func testAPI() {
		guard isModelConfigValid else {
			apiTestSuccess = false
			apiTestMessage = "Add a valid model configuration before testing."
			return
		}
		apiTestSuccess = true
		apiTestMessage = "Model settings saved. Test request simulated locally."
		preferences.hasCompletedSetup = true
	}
	
	func testSlack() {
		if integrationService.slackState.isConnected {
			slackTestSuccess = true
			slackTestMessage = "Slack token present. Ready to send."
		} else {
			slackTestSuccess = false
			slackTestMessage = "Connect Slack first, then test."
		}
	}
	
	func testLinear() {
		if integrationService.linearState.isConnected {
			linearTestSuccess = true
			linearTestMessage = "Linear token present. Ready to create issues."
		} else {
			linearTestSuccess = false
			linearTestMessage = "Connect Linear first, then test."
		}
	}

	func testNotion() {
		if integrationService.notionState.isConnected {
			notionTestSuccess = true
			notionTestMessage = "Notion connected. Ready to access pages."
		} else {
			notionTestSuccess = false
			notionTestMessage = "Connect Notion first, then test."
		}
	}

	func testGitHub() {
		if integrationService.githubState.isConnected {
			githubTestSuccess = true
			githubTestMessage = "GitHub connected. Ready to access repositories."
		} else {
			githubTestSuccess = false
			githubTestMessage = "Connect GitHub first, then test."
		}
	}

	func testGmail() {
		if integrationService.gmailState.isConnected {
			gmailTestSuccess = true
			gmailTestMessage = "Gmail connected. Ready to read or send mail."
		} else {
			gmailTestSuccess = false
			gmailTestMessage = "Connect Gmail first, then test."
		}
	}

	func testGoogleCalendar() {
		if integrationService.googleCalendarState.isConnected {
			googleCalendarTestSuccess = true
			googleCalendarTestMessage = "Calendar connected. Ready to manage events."
		} else {
			googleCalendarTestSuccess = false
			googleCalendarTestMessage = "Connect Google Calendar first, then test."
		}
	}
	
	func resetAll() {
		preferences.reset()
		integrationService.reset()
		loadPersistedValues()
	}
	
	// MARK: - Slack selection
	func fetchSlackMetadata() {
		integrationService.fetchSlackMetadata()
		slackWorkspaces = integrationService.slackWorkspaces
		slackChannels = integrationService.slackChannels
	}
	
	// MARK: - Linear selection
	func fetchLinearMetadata() {
		integrationService.fetchLinearMetadata()
		linearTeams = integrationService.linearTeams
		linearProjects = integrationService.linearProjects
	}
	
	// Helpers for filtered lists
	func slackChannelsFiltered(for workspaceId: String) -> [SlackChannel] {
		guard !workspaceId.isEmpty else { return [] }
		return slackChannels.filter { $0.workspaceId == workspaceId }
	}
	
	func linearProjectsFiltered(for teamId: String) -> [LinearProject] {
		guard !teamId.isEmpty else { return [] }
		return linearProjects.filter { $0.teamId == teamId }
	}
}
