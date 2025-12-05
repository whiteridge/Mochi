import Foundation

struct IntegrationCore {
    private let keychain: KeychainStore
    private let slackTokenKey = "slack.token"
    private let linearApiKey = "linear.apiKey"
    private let linearTeamKey = "linear.teamKey"
    
    init(keychain: KeychainStore) {
        self.keychain = keychain
    }
    
    // MARK: - State loaders
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
    
    // MARK: - Slack
    func connectSlack(token: String) -> IntegrationState {
        guard !token.isEmpty else { return .error("Token required") }
        keychain.set(token, for: slackTokenKey)
        return .connected(Date())
    }
    
    func disconnectSlack() -> IntegrationState {
        keychain.delete(slackTokenKey)
        return .disconnected
    }
    
    // MARK: - Linear
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
    
    // MARK: - Reset
    func resetAll() -> (slack: IntegrationState, linear: IntegrationState) {
        keychain.removeAll()
        return (.disconnected, .disconnected)
    }
}


