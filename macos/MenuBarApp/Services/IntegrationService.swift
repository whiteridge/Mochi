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

final class IntegrationService: ObservableObject {
	@Published private(set) var slackState: IntegrationState = .disconnected
	@Published private(set) var linearState: IntegrationState = .disconnected
	
	private let keychain: KeychainStore
	private let slackTokenKey = "slack.token"
	private let linearApiKey = "linear.apiKey"
	private let linearTeamKey = "linear.teamKey"
	
	init(keychain: KeychainStore) {
		self.keychain = keychain
		loadPersisted()
	}
	
	func loadPersisted() {
		if let token = keychain.value(for: slackTokenKey), !token.isEmpty {
			slackState = .connected(Date())
		}
		
		if let apiKey = keychain.value(for: linearApiKey),
		   let teamKey = keychain.value(for: linearTeamKey),
		   !apiKey.isEmpty, !teamKey.isEmpty {
			linearState = .connected(Date())
		}
	}
	
	func connectSlack(token: String) {
		guard !token.isEmpty else {
			slackState = .error("Token required to connect Slack.")
			return
		}
		keychain.set(token, for: slackTokenKey)
		slackState = .connected(Date())
	}
	
	func disconnectSlack() {
		keychain.delete(slackTokenKey)
		slackState = .disconnected
	}
	
	func connectLinear(apiKey: String, teamKey: String) {
		guard !apiKey.isEmpty, !teamKey.isEmpty else {
			linearState = .error("API key and team key are required.")
			return
		}
		keychain.set(apiKey, for: linearApiKey)
		keychain.set(teamKey, for: linearTeamKey)
		linearState = .connected(Date())
	}
	
	func disconnectLinear() {
		keychain.delete(linearApiKey)
		keychain.delete(linearTeamKey)
		linearState = .disconnected
	}
	
	func reset() {
		keychain.removeAll()
		slackState = .disconnected
		linearState = .disconnected
	}
}


