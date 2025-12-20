import Foundation

enum IntegrationKind: String, CaseIterable, Identifiable {
	case slack, linear
	var id: String { rawValue }
	var displayName: String { rawValue.capitalized }
}

enum IntegrationState: Equatable {
	case disconnected
	case connected(Date)
	case error(String)
	
	var label: String {
		switch self {
		case .disconnected:
			return "Not connected"
		case .connected:
			return "Connected"
		case .error:
			return "Action needed"
		}
	}
	
	var description: String {
		switch self {
		case .disconnected:
			return "Connect to enable workspace automation."
		case .connected(let date):
			let df = DateFormatter()
			df.dateStyle = .medium
			df.timeStyle = .short
			return "Connected • Updated \(df.string(from: date))"
		case .error(let message):
			return message
		}
	}
	
	var isConnected: Bool { if case .connected = self { return true } else { return false } }
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
		guard !token.isEmpty else { return .error("Token required") }
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

struct SlackWorkspace: Identifiable, Hashable {
	let id: String
	let name: String
}

struct SlackChannel: Identifiable, Hashable {
	let id: String
	let name: String
	let workspaceId: String
}

struct LinearTeam: Identifiable, Hashable {
	let id: String
	let name: String
	let key: String
}

struct LinearProject: Identifiable, Hashable {
	let id: String
	let name: String
	let teamId: String
}

final class IntegrationService: ObservableObject {
	@Published private(set) var slackState: IntegrationState = .disconnected
	@Published private(set) var linearState: IntegrationState = .disconnected
	@Published private(set) var slackWorkspaces: [SlackWorkspace] = []
	@Published private(set) var slackChannels: [SlackChannel] = []
	@Published private(set) var linearTeams: [LinearTeam] = []
	@Published private(set) var linearProjects: [LinearProject] = []
	
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
		slackState = core.connectSlack(token: token)
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
	
	// MARK: - Metadata placeholders (empty until real API wired)
	func fetchSlackMetadata() {
		slackWorkspaces = []
		slackChannels = []
	}
	
	func fetchLinearMetadata() {
		linearTeams = []
		linearProjects = []
	}
}

