import Foundation

enum IntegrationKind: String, CaseIterable, Identifiable {
	case slack
	case linear
	
	var id: String { rawValue }
	
	var displayName: String {
		switch self {
		case .slack: "Slack"
		case .linear: "Linear"
		}
	}
	
	var documentationURL: URL? {
		switch self {
		case .slack:
			URL(string: "https://api.slack.com/authentication/oauth-v2")
		case .linear:
			URL(string: "https://developers.linear.app/docs/graphql/get-started")
		}
	}
}

enum IntegrationState: Equatable {
	case disconnected
	case connected(Date)
	case error(String)
	
	var label: String {
		switch self {
		case .disconnected: "Not connected"
		case .connected: "Connected"
		case .error: "Action needed"
		}
	}
	
	var description: String {
		switch self {
		case .disconnected:
			return "Connect to enable workspace automation."
		case .connected(let date):
			let formatter = DateFormatter()
			formatter.dateStyle = .medium
			formatter.timeStyle = .short
			return "Connected • Updated \(formatter.string(from: date))"
		case .error(let message):
			return message
		}
	}
	
	var isConnected: Bool {
		if case .connected = self { return true }
		return false
	}
}

// Local integration core to avoid missing-type issues when shared modules are excluded.
private struct IntegrationCore {
	private let keychain: KeychainStore
	private let slackTokenKey = "slack.token"
	private let linearApiKey = "linear.apiKey"
	private let linearTeamKey = "linear.teamKey"
	
	init(keychain: KeychainStore) {
		self.keychain = keychain
	}
	
	func loadPersistedStates() -> (slack: IntegrationState, linear: IntegrationState) {
		var slackState: IntegrationState = .disconnected
		var linearState: IntegrationState = .disconnected
		
		if let token = keychain.value(for: slackTokenKey), !token.isEmpty {
			slackState = .connected(Date())
		}
		
		if let api = keychain.value(for: linearApiKey),
		   let team = keychain.value(for: linearTeamKey),
		   !api.isEmpty, !team.isEmpty {
			linearState = .connected(Date())
		}
		
		return (slackState, linearState)
	}
	
	func connectSlack(token: String) -> IntegrationState {
		guard !token.isEmpty else { return .error("Token required to connect Slack.") }
		keychain.set(token, for: slackTokenKey)
		return .connected(Date())
	}
	
	func disconnectSlack() -> IntegrationState {
		keychain.delete(slackTokenKey)
		return .disconnected
	}
	
	func connectLinear(apiKey: String, teamKey: String) -> IntegrationState {
		guard !apiKey.isEmpty, !teamKey.isEmpty else { return .error("API key and team key are required.") }
		keychain.set(apiKey, for: linearApiKey)
		keychain.set(teamKey, for: linearTeamKey)
		return .connected(Date())
	}
	
	func disconnectLinear() -> IntegrationState {
		keychain.delete(linearApiKey)
		keychain.delete(linearTeamKey)
		return .disconnected
	}
	
	func resetAll() -> (slack: IntegrationState, linear: IntegrationState) {
		keychain.removeAll()
		return (.disconnected, .disconnected)
	}
}

final class IntegrationService: ObservableObject {
	@Published private(set) var slackState: IntegrationState = .disconnected
	@Published private(set) var linearState: IntegrationState = .disconnected
	
	private let keychain: KeychainStore
	private let core: IntegrationCore
	
	init(keychain: KeychainStore) {
		self.keychain = keychain
		self.core = IntegrationCore(keychain: keychain)
		loadPersisted()
	}
	
	func loadPersisted() {
		let states = core.loadPersistedStates()
		slackState = states.slack
		linearState = states.linear
	}
	
	func connectSlack(token: String) {
		let state = core.connectSlack(token: token)
		slackState = state
	}
	
	func disconnectSlack() {
		slackState = core.disconnectSlack()
	}
	
	func connectLinear(apiKey: String, teamKey: String) {
		linearState = core.connectLinear(apiKey: apiKey, teamKey: teamKey)
	}
	
	func disconnectLinear() {
		linearState = core.disconnectLinear()
	}
	
	func reset() {
		let states = core.resetAll()
		slackState = states.slack
		linearState = states.linear
	}
}


