import Testing
import Foundation
@testable import caddyAI

struct CredentialManagerTests {
    
    let manager = CredentialManager()
    let keychain = KeychainService.shared
    
	@Test func testSaveAndLoad() {
		// Setup
		let testOpenAI = "sk-test-openai"
		let testGoogle = "sk-test-google"
		let testAnthropic = "sk-test-anthropic"
		let testLinear = "lin-test-linear"
		let testSlack = "xoxb-test-slack"
		
		manager.openaiKey = testOpenAI
		manager.googleKey = testGoogle
		manager.anthropicKey = testAnthropic
		manager.linearKey = testLinear
		manager.slackKey = testSlack
        
        // Save
        manager.saveCredentials()
        
        // Reset manager to simulate app restart
        let newManager = CredentialManager()
        newManager.loadCredentials()
        
        // Verify (Should Fail initially as implementation is empty)
		#expect(newManager.openaiKey == testOpenAI)
		#expect(newManager.googleKey == testGoogle)
		#expect(newManager.anthropicKey == testAnthropic)
		#expect(newManager.linearKey == testLinear)
		#expect(newManager.slackKey == testSlack)
        
        // Verify in Keychain directly
		#expect(keychain.read(key: CredentialManager.Keys.openai) == testOpenAI)
		#expect(keychain.read(key: CredentialManager.Keys.google) == testGoogle)
		#expect(keychain.read(key: CredentialManager.Keys.anthropic) == testAnthropic)
        
        // Cleanup
		try? keychain.delete(key: CredentialManager.Keys.openai)
		try? keychain.delete(key: CredentialManager.Keys.google)
		try? keychain.delete(key: CredentialManager.Keys.anthropic)
		try? keychain.delete(key: CredentialManager.Keys.linear)
		try? keychain.delete(key: CredentialManager.Keys.slack)
	}
}
