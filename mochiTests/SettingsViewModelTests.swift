import Testing
import Foundation
@testable import mochi

private final class InMemoryCredentialManager: CredentialManager {
	override func saveCredentials() {}
	override func loadCredentials() {}
}

struct SettingsViewModelTests {
    
    @Test func testGoogleKeyUpdatesCredentialManager() {
		let credManager = InMemoryCredentialManager()
        let preferences = PreferencesStore()
        let oldKeychainStore = KeychainStore(service: "test")
        let integrationService = IntegrationService(keychain: oldKeychainStore)

        let viewModel = SettingsViewModel(
            preferences: preferences,
            integrationService: integrationService,
            credentialManager: credManager
        )
        
        viewModel.selectedProvider = .google
        viewModel.apiKey = "sk-test-vm-key"
        
        // Trigger save (assuming saveAPISettings saves credentials)
        viewModel.saveAPISettings()
        
        // Verify
        #expect(credManager.googleKey == "sk-test-vm-key")
    }
}
