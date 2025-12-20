import XCTest
@testable import MenuBarApp

final class IntegrationServiceTests: XCTestCase {
	func testSlackConnectAndDisconnectUpdatesState() {
		let keychain = KeychainStore(service: "com.matteofari.caddyAI.menu.tests.slack")
		keychain.removeAll()
		let service = IntegrationService(keychain: keychain)
		
		service.connectSlack(token: "xoxb-test")
		XCTAssertTrue(service.slackState.isConnected)
		
		service.disconnectSlack()
		XCTAssertEqual(service.slackState, .disconnected)
		keychain.removeAll()
	}
	
	func testLinearConnectRequiresBothFields() {
		let keychain = KeychainStore(service: "com.matteofari.caddyAI.menu.tests.linear")
		keychain.removeAll()
		let service = IntegrationService(keychain: keychain)
		
		service.connectLinear(apiKey: "", teamKey: "")
		if case .error = service.linearState {
			// expected
		} else {
			XCTFail("Expected validation error when missing credentials")
		}
		
		service.connectLinear(apiKey: "lin_test", teamKey: "team_test")
		XCTAssertTrue(service.linearState.isConnected)
		keychain.removeAll()
	}
}


