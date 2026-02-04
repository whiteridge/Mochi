import Foundation

enum BackendConfig {
    private static let apiBaseURLKey = "apiBaseURL"
    private static let composioUserIdKey = "composioUserId"
    private static let defaultBaseURL = "http://127.0.0.1:8000"
    private static let defaultUserId = "caddyai-default"

    static var baseURL: String {
        let stored = UserDefaults.standard.string(forKey: apiBaseURLKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let stored, !stored.isEmpty {
            var normalized = stored
            while normalized.hasSuffix("/") {
                normalized.removeLast()
            }
            return normalized.isEmpty ? defaultBaseURL : normalized
        }
        return defaultBaseURL
    }

    static var chatURL: URL? {
        URL(string: "\(baseURL)/api/chat")
    }

    static var integrationsBaseURL: String {
        "\(baseURL)/api/v1/integrations"
    }

    static var userId: String {
        let stored = UserDefaults.standard.string(forKey: composioUserIdKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let stored, !stored.isEmpty {
            return stored
        }
        return defaultUserId
    }

    static func loadModelApiKey() -> String? {
        let credentials = CredentialManager.shared
        credentials.loadCredentials()
        let key = credentials.googleKey.trimmingCharacters(in: .whitespacesAndNewlines)
        return key.isEmpty ? nil : key
    }
}
