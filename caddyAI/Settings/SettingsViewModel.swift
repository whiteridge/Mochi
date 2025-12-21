import SwiftUI

enum SettingsSection: String, CaseIterable, Identifiable {
	case general, api, integrations, onboarding
	var id: String { rawValue }
	var label: String {
		switch self {
		case .general: "General"
		case .api: "API & Accounts"
		case .integrations: "Integrations"
		case .onboarding: "Setup"
		}
	}
	var icon: String {
		switch self {
		case .general: "gearshape"
		case .api: "key"
		case .integrations: "rectangle.connected.to.line.below"
		case .onboarding: "sparkles"
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
		apiKey = credentialManager.openaiKey
		apiBaseURL = preferences.apiBaseURL
		slackToken = credentialManager.slackKey
		linearApiKey = credentialManager.linearKey
		linearTeamKey = "" // Not managed by CredentialManager yet? Spec only mentioned openai, linear, slack.
	}
	
	func saveAPISettings() {
		credentialManager.openaiKey = apiKey
		credentialManager.saveCredentials()
		
		preferences.updateAPI(key: "", baseURL: apiBaseURL) // Clear key from prefs if feasible, or just update base URL
		preferences.hasCompletedSetup = true
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
		slackToken = ""
		if integrationService.slackState.isConnected { preferences.hasCompletedSetup = true }
	}
	
	func connectLinear() {
		credentialManager.linearKey = linearApiKey
		credentialManager.saveCredentials()
		
		integrationService.connectLinear(apiKey: linearApiKey, teamKey: linearTeamKey)
		if integrationService.linearState.isConnected {
			linearApiKey = ""
			linearTeamKey = ""
			preferences.hasCompletedSetup = true
		}
	}

	func connectViaComposio(appName: String) {
		Task {
			do {
				let url = try await integrationService.fetchComposioConnectURL(for: appName)
				await MainActor.run {
					NSWorkspace.shared.open(url)
				}
				
				// Poll for status or just wait a bit and refresh
				try? await Task.sleep(nanoseconds: 5 * 1_000_000_000)
				refreshStatus(appName: appName)
			} catch {
				print("Error connecting via Composio: \(error)")
			}
		}
	}

	func refreshStatus(appName: String) {
		integrationService.refreshComposioStatus(for: appName)
	}
	
	func disconnectSlack() { integrationService.disconnectSlack() }
	func disconnectLinear() { integrationService.disconnectLinear() }
	
	func testAPI() {
		guard !apiKey.isEmpty else {
			apiTestSuccess = false
			apiTestMessage = "Add an API key before testing."
			return
		}
		apiTestSuccess = true
		apiTestMessage = "Key saved. Test request simulated locally."
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

