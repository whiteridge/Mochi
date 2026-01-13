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
			return error.localizedDescription
		} catch let error as NSError {
			print("Error connecting via Composio: \(error)")
			
			if error.code == -1004 {
				return "Backend not running. Start with: cd backend && uv run uvicorn main:app"
			}
			return "Connection failed: \(error.localizedDescription)"
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

