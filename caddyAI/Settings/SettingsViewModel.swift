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
	@Published var accentOptions: [AccentColorOption] = [
		AccentColorOption(id: "blue", name: "Blue", color: Color(red: 0.27, green: 0.54, blue: 0.98), hex: "#4688FA"),
		AccentColorOption(id: "green", name: "Green", color: Color(red: 0.25, green: 0.74, blue: 0.40), hex: "#3FBF66"),
		AccentColorOption(id: "pink", name: "Pink", color: Color(red: 0.91, green: 0.36, blue: 0.61), hex: "#E65C9B"),
		AccentColorOption(id: "orange", name: "Orange", color: Color(red: 0.98, green: 0.52, blue: 0.22), hex: "#FA8438")
	]
	
	private let preferences: PreferencesStore
	private let integrationService: IntegrationService
	
	init(preferences: PreferencesStore, integrationService: IntegrationService) {
		self.preferences = preferences
		self.integrationService = integrationService
	}
	
	func loadPersistedValues() {
		apiKey = preferences.apiKey
		apiBaseURL = preferences.apiBaseURL
		slackToken = ""
		linearApiKey = ""
		linearTeamKey = ""
	}
	
	func saveAPISettings() {
		preferences.updateAPI(key: apiKey, baseURL: apiBaseURL)
		preferences.hasCompletedSetup = true
	}
	
	func selectAccent(_ option: AccentColorOption) {
		preferences.updateAccentColor(hex: option.hex)
	}
	
	func selectTheme(_ theme: ThemePreference) {
		preferences.theme = theme
	}
	
	func connectSlack() {
		integrationService.connectSlack(token: slackToken)
		slackToken = ""
		if integrationService.slackState.isConnected { preferences.hasCompletedSetup = true }
	}
	
	func connectLinear() {
		integrationService.connectLinear(apiKey: linearApiKey, teamKey: linearTeamKey)
		if integrationService.linearState.isConnected {
			linearApiKey = ""
			linearTeamKey = ""
			preferences.hasCompletedSetup = true
		}
	}
	
	func disconnectSlack() { integrationService.disconnectSlack() }
	func disconnectLinear() { integrationService.disconnectLinear() }
	
	func resetAll() {
		preferences.reset()
		integrationService.reset()
		loadPersistedValues()
	}
}

