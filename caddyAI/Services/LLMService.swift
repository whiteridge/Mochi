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
    
    private let baseURL = "http://127.0.0.1:8000/api/chat"
    private let userId = "test_user_voice_app"
    
    private init() {}
    
    func sendMessage(text: String, history: [Message] = []) -> AsyncThrowingStream<StreamEvent, Error> {
        return AsyncThrowingStream { continuation in
            Task {
                guard let url = URL(string: baseURL) else {
                    continuation.finish(throwing: LLMError.invalidURL)
                    return
                }
                
                var fullMessages = history
                fullMessages.append(Message(role: "user", content: text))
                
                let requestPayload = ChatRequest(messages: fullMessages, userId: userId)
                
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
}
