import SwiftUI

@main
struct MenuBarApp: App {
	@StateObject private var environment = MenuBarEnvironment()
	@NSApplicationDelegateAdaptor(MenuBarAppDelegate.self) private var appDelegate
	
	init() {
		MenuBarAppDelegate.environment = environment
	}
	
	var body: some Scene {
		Settings {
			SettingsContainerView()
				.environmentObject(environment.preferences)
				.environmentObject(environment.integrationService)
				.environmentObject(environment.settingsViewModel)
		}
	}
}

/// Container for all shared services used by the menu bar target.
final class MenuBarEnvironment: ObservableObject {
	let preferences: PreferencesStore
	let integrationService: IntegrationService
	let settingsViewModel: SettingsViewModel
	
	init() {
		let keychain = KeychainStore(service: "com.matteofari.caddyAI.menu")
		let preferences = PreferencesStore()
		let integrationService = IntegrationService(keychain: keychain)
		let settingsViewModel = SettingsViewModel(preferences: preferences, integrationService: integrationService)
		
		self.preferences = preferences
		self.integrationService = integrationService
		self.settingsViewModel = settingsViewModel
		
		settingsViewModel.loadPersistedValues()
	}
	
	func resetAll() {
		preferences.reset()
		integrationService.reset()
		settingsViewModel.loadPersistedValues()
	}
}


