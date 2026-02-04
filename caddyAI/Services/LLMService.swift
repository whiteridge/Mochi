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
                let legacyApiKey = modelConfig?.provider == ModelProvider.google.rawValue ? modelConfig?.apiKey : nil
                let requestPayload = ChatRequest(
                    messages: fullMessages,
                    userId: userId,
                    confirmedTool: confirmedTool,
                    userTimezone: userTimezone,
                    apiKey: legacyApiKey,
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
        let providerRaw = defaults.string(forKey: PreferencesStore.Keys.modelProvider) ?? ModelProvider.google.rawValue
        let provider = ModelProvider(rawValue: providerRaw) ?? .google

        let storedModel = defaults.string(forKey: PreferencesStore.Keys.modelName) ?? ModelCatalog.defaultModel(for: provider)
        let customModel = defaults.string(forKey: PreferencesStore.Keys.customModelName) ?? ""
        let resolvedModel = storedModel == ModelCatalog.customModelId ? customModel : storedModel

        let apiKey = apiKeyForProvider(provider)
        let baseURL = baseURLForProvider(provider, defaults: defaults)

        let trimmedModel = resolvedModel.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedKey = apiKey?.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedURL = baseURL?.trimmingCharacters(in: .whitespacesAndNewlines)

        return ModelConfig(
            provider: provider.rawValue,
            model: trimmedModel.isEmpty ? nil : trimmedModel,
            apiKey: (trimmedKey?.isEmpty ?? true) ? nil : trimmedKey,
            baseURL: (trimmedURL?.isEmpty ?? true) ? nil : trimmedURL
        )
    }

    private func apiKeyForProvider(_ provider: ModelProvider) -> String? {
        let credentials = CredentialManager.shared
        credentials.loadCredentials()
        switch provider {
        case .google:
            return credentials.googleKey
        case .openai:
            return credentials.openaiKey
        case .anthropic:
            return credentials.anthropicKey
        case .ollama, .lmStudio, .customOpenAI:
            return nil
        }
    }

    private func baseURLForProvider(_ provider: ModelProvider, defaults: UserDefaults) -> String? {
        switch provider {
        case .ollama:
            return defaults.string(forKey: PreferencesStore.Keys.ollamaBaseURL) ?? ModelProvider.ollama.defaultBaseURL
        case .lmStudio:
            return defaults.string(forKey: PreferencesStore.Keys.lmStudioBaseURL) ?? ModelProvider.lmStudio.defaultBaseURL
        case .customOpenAI:
            return defaults.string(forKey: PreferencesStore.Keys.customOpenAIBaseURL)
        default:
            return nil
        }
    }
}
