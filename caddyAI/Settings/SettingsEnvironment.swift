import Foundation

/// Container for settings-related dependencies in the main app target.
final class SettingsEnvironment: ObservableObject {
	let preferences: PreferencesStore
	let integrationService: IntegrationService
	let viewModel: SettingsViewModel
	
	init() {
		let keychain = KeychainStore(service: "com.matteofari.caddyAI.settings")
		let preferences = PreferencesStore()
		let integrationService = IntegrationService(keychain: keychain)
		let viewModel = SettingsViewModel(preferences: preferences, integrationService: integrationService)
		
		self.preferences = preferences
		self.integrationService = integrationService
		self.viewModel = viewModel
		
		viewModel.loadPersistedValues()
	}
	
	func resetAll() {
		preferences.reset()
		integrationService.reset()
		viewModel.loadPersistedValues()
	}
}

