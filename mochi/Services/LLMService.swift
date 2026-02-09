import Foundation

enum LLMError: LocalizedError {
    case invalidURL
    case serverError(statusCode: Int)
    case decodingError
    case networkError(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL configuration."
        case .serverError(let statusCode):
            return "Server returned an error (Status: \(statusCode))."
        case .decodingError:
            return "Failed to decode server response."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}

actor LLMService {
    static let shared = LLMService()

    private var chatURL: URL? {
        BackendConfig.chatURL
    }

    private var userId: String {
        BackendConfig.userId
    }
    
    private init() {}
    
    func sendMessage(text: String, history: [Message] = [], confirmedTool: ConfirmedToolData? = nil) -> AsyncThrowingStream<StreamEvent, Error> {
        return AsyncThrowingStream { continuation in
            Task {
                guard let url = chatURL else {
                    continuation.finish(throwing: LLMError.invalidURL)
                    return
                }
                
                var fullMessages = history
                fullMessages.append(Message(role: "user", content: text))
                
                let userTimezone = TimeZone.current.identifier
                let modelConfig = buildModelConfig()
                let requestPayload = ChatRequest(
                    messages: fullMessages,
                    userId: userId,
                    confirmedTool: confirmedTool,
                    userTimezone: userTimezone,
                    apiKey: modelConfig?.apiKey,
                    model: modelConfig
                )
                
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                
                do {
                    request.httpBody = try JSONEncoder().encode(requestPayload)
                    
                    let (bytes, response) = try await URLSession.shared.bytes(for: request)
                    
                    guard let httpResponse = response as? HTTPURLResponse else {
                        continuation.finish(throwing: LLMError.networkError(NSError(domain: "Invalid Response", code: -1)))
                        return
                    }
                    
                    guard (200...299).contains(httpResponse.statusCode) else {
                        continuation.finish(throwing: LLMError.serverError(statusCode: httpResponse.statusCode))
                        return
                    }
                    
                    for try await line in bytes.lines {
                        if let data = line.data(using: .utf8) {
                            let event = try JSONDecoder().decode(StreamEvent.self, from: data)
                            continuation.yield(event)
                        }
                    }
                    
                    continuation.finish()
                    
                } catch let error as LLMError {
                    continuation.finish(throwing: error)
                } catch {
                    continuation.finish(throwing: LLMError.networkError(error))
                }
            }
        }
    }

    private func buildModelConfig() -> ModelConfig? {
        let defaults = UserDefaults.standard
        let storedModel = defaults.string(forKey: PreferencesStore.Keys.modelName) ?? ModelCatalog.defaultModel(for: .google)
        let resolvedModel = ModelCatalog.models(for: .google).contains(storedModel)
            ? storedModel
            : ModelCatalog.defaultModel(for: .google)
        let apiKey = googleAPIKey()

        let trimmedModel = resolvedModel.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedKey = apiKey?.trimmingCharacters(in: .whitespacesAndNewlines)

        return ModelConfig(
            model: trimmedModel.isEmpty ? nil : trimmedModel,
            apiKey: (trimmedKey?.isEmpty ?? true) ? nil : trimmedKey
        )
    }

    private func googleAPIKey() -> String? {
        let credentials = CredentialManager.shared
        credentials.loadCredentials()
        return credentials.googleKey
    }
}
