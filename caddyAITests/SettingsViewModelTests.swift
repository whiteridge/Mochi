import Testing
import Foundation
@testable import caddyAI

struct SettingsViewModelTests {
    
    @Test func testGoogleKeyUpdatesCredentialManager() {
        // Setup dependencies
        // Note: We are using real instances for now. In a strict unit test, we'd mock.
        // But CredentialManager is lightweight logic.
        
        // We need to use a clean keychain for this test or unique keys, but CredentialManager uses hardcoded keys.
        // So we are integration testing against real Keychain via CredentialManager.
        // Ideally we should inject a MockKeychainService into CredentialManager.
        
        // Let's rely on CredentialManager's behavior.
        
        let keychain = KeychainService.shared
        let credManager = CredentialManager(keychain: keychain)
        let preferences = PreferencesStore()
        
        // IntegrationService is complex to init (needs KeychainStore).
        // We might need to stub it or just provide it.
        // For this test, we want to verify SettingsViewModel interacts with CredentialManager.
        // If we can't easily init SettingsViewModel due to dependencies, we should refactor or mock.
        
        // existing init: init(preferences: PreferencesStore, integrationService: IntegrationService)
        // We will change it to: init(preferences: ..., integrationService: ..., credentialManager: ...)
        
        // Since I can't compile if I change signature in test but not code, 
        // AND I can't init without IntegrationService.
        
        // I will attempt to init with existing signature to fail, then fix.
        // But to make it meaningful, I'll mock IntegrationService? No, it's a final class.
        
        // I'll create the dependencies.
        let oldKeychainStore = KeychainStore(service: "test")
        let integrationService = IntegrationService(keychain: oldKeychainStore)
        
        // This will fail to compile because I will try to pass credentialManager
        // OR if I don't pass it, I can't test the new logic.
        
        // I will write the test assuming the NEW signature.
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
        
        // Clean up
        try? keychain.delete(key: CredentialManager.Keys.google)
    }
}
