import Testing
import Foundation
@testable import mochi

struct CredentialManagerTests {
    
    let manager = CredentialManager()
    let keychain = KeychainService.shared
    
	@Test func testSaveAndLoad() {
		// Setup
		let testGoogle = "sk-test-google"
		let testLinear = "lin-test-linear"
		let testSlack = "xoxb-test-slack"
		
		manager.googleKey = testGoogle
		manager.linearKey = testLinear
		manager.slackKey = testSlack
        
        // Save
        manager.saveCredentials()
        
        // Reset manager to simulate app restart
        let newManager = CredentialManager()
        newManager.loadCredentials()
        
        // Verify (Should Fail initially as implementation is empty)
		#expect(newManager.googleKey == testGoogle)
		#expect(newManager.linearKey == testLinear)
		#expect(newManager.slackKey == testSlack)
        
        // Verify in Keychain directly
		#expect(keychain.read(key: CredentialManager.Keys.google) == testGoogle)
        
        // Cleanup
		try? keychain.delete(key: CredentialManager.Keys.google)
		try? keychain.delete(key: CredentialManager.Keys.linear)
		try? keychain.delete(key: CredentialManager.Keys.slack)
	}
}
