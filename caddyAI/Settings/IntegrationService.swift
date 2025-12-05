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
		if let api = keychain.value(for: linearApiKey),
		   let team = keychain.value(for: linearTeamKey),
		   !api.isEmpty, !team.isEmpty {
			linearState = .connected(Date())
		}
	}
	
	func connectSlack(token: String) {
		guard !token.isEmpty else { slackState = .error("Token required"); return }
		keychain.set(token, for: slackTokenKey)
		slackState = .connected(Date())
	}
	
	func disconnectSlack() {
		keychain.delete(slackTokenKey)
		slackState = .disconnected
	}
	
	func connectLinear(apiKey: String, teamKey: String) {
		guard !apiKey.isEmpty, !teamKey.isEmpty else { linearState = .error("API key and team key are required."); return }
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

