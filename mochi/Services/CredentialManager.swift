import Foundation
import Combine

class CredentialManager: ObservableObject {
    @Published var googleKey: String = ""
    @Published var linearKey: String = ""
    @Published var slackKey: String = ""
    
    static let shared = CredentialManager()
    
    private let keychain: KeychainService
    
    init(keychain: KeychainService = .shared) {
        self.keychain = keychain
    }
    
    struct Keys {
        static let google = "google_api_key"
        static let linear = "linear_api_key"
        static let slack = "slack_api_key"
    }
    
    func saveCredentials() {
        persist(googleKey, for: Keys.google)
        persist(linearKey, for: Keys.linear)
        persist(slackKey, for: Keys.slack)
    }
    
    func loadCredentials() {
        googleKey = keychain.read(key: Keys.google) ?? ""
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
