import Foundation
import Combine

class CredentialManager: ObservableObject {
    @Published var openaiKey: String = ""
    @Published var googleKey: String = ""
    @Published var anthropicKey: String = ""
    @Published var linearKey: String = ""
    @Published var slackKey: String = ""
    
    static let shared = CredentialManager()
    
    private let keychain: KeychainService
    
    init(keychain: KeychainService = .shared) {
        self.keychain = keychain
    }
    
    struct Keys {
        static let openai = "openai_api_key"
        static let google = "google_api_key"
        static let anthropic = "anthropic_api_key"
        static let linear = "linear_api_key"
        static let slack = "slack_api_key"
    }
    
    func saveCredentials() {
        persist(openaiKey, for: Keys.openai)
        persist(googleKey, for: Keys.google)
        persist(anthropicKey, for: Keys.anthropic)
        persist(linearKey, for: Keys.linear)
        persist(slackKey, for: Keys.slack)
    }
    
    func loadCredentials() {
        openaiKey = keychain.read(key: Keys.openai) ?? ""
        googleKey = keychain.read(key: Keys.google) ?? ""
        anthropicKey = keychain.read(key: Keys.anthropic) ?? ""
        linearKey = keychain.read(key: Keys.linear) ?? ""
        slackKey = keychain.read(key: Keys.slack) ?? ""
    }
    
    private func persist(_ value: String, for key: String) {
        if value.isEmpty {
            try? keychain.delete(key: key)
            return
        }
        
        do {
            try keychain.save(value, for: key)
        } catch KeychainError.duplicateEntry {
            try? keychain.update(value, for: key)
        } catch {
            print("Error saving credential for \(key): \(error)")
        }
    }
}
