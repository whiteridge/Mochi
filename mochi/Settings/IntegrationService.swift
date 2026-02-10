import Foundation

enum IntegrationKind: String, CaseIterable, Identifiable {
	case slack
	case linear
	case notion
	case github
	case gmail
	case googleCalendar = "googlecalendar"
	var id: String { rawValue }
	var displayName: String {
		switch self {
		case .slack:
			return "Slack"
		case .linear:
			return "Linear"
		case .notion:
			return "Notion"
		case .github:
			return "GitHub"
		case .gmail:
			return "Gmail"
		case .googleCalendar:
			return "Google Calendar"
		}
	}
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
	@Published private(set) var notionState: IntegrationState = .disconnected
	@Published private(set) var githubState: IntegrationState = .disconnected
	@Published private(set) var gmailState: IntegrationState = .disconnected
	@Published private(set) var googleCalendarState: IntegrationState = .disconnected
	@Published private(set) var slackWorkspaces: [SlackWorkspace] = []
	@Published private(set) var slackChannels: [SlackChannel] = []
	@Published private(set) var linearTeams: [LinearTeam] = []
	@Published private(set) var linearProjects: [LinearProject] = []
	
	private let keychain: KeychainStore
	private let core: IntegrationCore
	private let credentialManager: CredentialManager
	private var backendBaseURL: String { BackendConfig.integrationsBaseURL }
	private var userId: String { BackendConfig.userId }
	private let statusCacheTTL: TimeInterval = 15
	private var statusLastRefreshAt: [String: Date] = [:]
	private var statusRequestsInFlight: Set<String> = []

	var hasAnyComposioConnection: Bool {
		slackState.isConnected
			|| linearState.isConnected
			|| notionState.isConnected
			|| githubState.isConnected
			|| gmailState.isConnected
			|| googleCalendarState.isConnected
	}
	
	init(keychain: KeychainStore, credentialManager: CredentialManager = .shared) {
		self.keychain = keychain
		self.credentialManager = credentialManager
		self.core = IntegrationCore(keychain: keychain)
		loadPersisted()
	}
	
	func loadPersisted() {
		let states = core.loadPersistedStates()
		slackState = states.slack
		linearState = states.linear
		notionState = .disconnected
		githubState = .disconnected
		gmailState = .disconnected
		googleCalendarState = .disconnected
	}
	
	func fetchComposioConnectURL(for appName: String) async throws -> URL {
		var components = URLComponents(string: "\(backendBaseURL)/connect/\(appName.lowercased())")
		components?.queryItems = [URLQueryItem(name: "user_id", value: userId)]
		
		guard let url = components?.url else { throw URLError(.badURL) }
		
		let (data, httpResponse) = try await URLSession.shared.data(from: url)
		
		// Check HTTP status code
		if let httpResponse = httpResponse as? HTTPURLResponse {
			if httpResponse.statusCode >= 400 {
				// Try to parse error response
				if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
					throw IntegrationError.serverError(errorResponse.detail)
				}
				throw IntegrationError.serverError("Server returned status \(httpResponse.statusCode)")
			}
		}
		
		let response = try JSONDecoder().decode(ConnectURLResponse.self, from: data)
		
		guard let redirectURL = URL(string: response.url) else { throw URLError(.badURL) }
		return redirectURL
	}
	
	private func normalizedAppName(_ appName: String) -> String {
		switch appName.lowercased() {
		case "googlecalendar", "google_calendar":
			return "googlecalendar"
		default:
			return appName.lowercased()
		}
	}

	func refreshComposioStatus(for appName: String, force: Bool = false) {
		let normalizedApp = normalizedAppName(appName)
		Task {
			let shouldStartRequest = await MainActor.run { () -> Bool in
				let now = Date()
				if !force,
				   let lastRefresh = statusLastRefreshAt[normalizedApp],
				   now.timeIntervalSince(lastRefresh) < statusCacheTTL {
					return false
				}
				if statusRequestsInFlight.contains(normalizedApp) {
					return false
				}
				statusRequestsInFlight.insert(normalizedApp)
				return true
			}

			guard shouldStartRequest else { return }
			defer {
				Task { @MainActor in
					statusRequestsInFlight.remove(normalizedApp)
					statusLastRefreshAt[normalizedApp] = Date()
				}
			}

			var components = URLComponents(string: "\(backendBaseURL)/status/\(normalizedApp)")
			components?.queryItems = [URLQueryItem(name: "user_id", value: userId)]
			
			guard let url = components?.url else { return }
			
			do {
				let (data, httpResponse) = try await URLSession.shared.data(from: url)
				
				// Check HTTP status
				if let httpResponse = httpResponse as? HTTPURLResponse, httpResponse.statusCode >= 400 {
					return
				}
				
				let response = try JSONDecoder().decode(StatusResponse.self, from: data)
				let normalizedStatus = response.status?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
				let actionRequired = response.actionRequired == true
				
				await MainActor.run {
					let newState: IntegrationState
					if response.connected {
						newState = .connected(Date())
					} else if actionRequired || normalizedStatus == "expired" || normalizedStatus == "failed" {
						newState = .error("Reconnect to refresh access.")
					} else if normalizedStatus == "inactive" {
						newState = .error("Access paused. Reconnect to enable.")
					} else if normalizedStatus == "initiated"
						|| normalizedStatus == "initializing"
						|| normalizedStatus == "pending" {
						newState = .error("Connection pending. Complete setup in browser.")
					} else {
						newState = .disconnected
					}

					switch normalizedApp {
					case "slack":
						self.slackState = newState
					case "linear":
						self.linearState = newState
					case "notion":
						self.notionState = newState
					case "github":
						self.githubState = newState
					case "gmail":
						self.gmailState = newState
					case "googlecalendar":
						self.googleCalendarState = newState
					default:
						break
					}
				}
			} catch {
				print("Error refreshing status for \(appName): \(error)")
			}
		}
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

	func disconnectNotion() {
		notionState = .disconnected
	}

	func disconnectGitHub() {
		githubState = .disconnected
	}

	func disconnectGmail() {
		gmailState = .disconnected
	}

	func disconnectGoogleCalendar() {
		googleCalendarState = .disconnected
	}
	
	func reset() {
		let states = core.resetAll()
		slackState = states.slack
		linearState = states.linear
		notionState = .disconnected
		githubState = .disconnected
		gmailState = .disconnected
		googleCalendarState = .disconnected
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

struct ConnectURLResponse: Codable {
	let url: String
}

struct StatusResponse: Codable {
	let connected: Bool
	let status: String?
	let actionRequired: Bool?

	enum CodingKeys: String, CodingKey {
		case connected
		case status
		case actionRequired = "action_required"
	}
}

struct ErrorResponse: Codable {
	let detail: String
}

enum IntegrationError: LocalizedError {
	case serverError(String)
	case networkError(String)
	case invalidResponse
	
	var errorDescription: String? {
		switch self {
		case .serverError(let detail):
			return detail
		case .networkError(let message):
			return message
		case .invalidResponse:
			return "Invalid response from server"
		}
	}
}
