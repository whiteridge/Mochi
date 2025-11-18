import Foundation

struct LLMService {
	enum ServiceError: LocalizedError {
		case invalidResponse

		var errorDescription: String? {
			switch self {
			case .invalidResponse:
				return "The LLM service returned an unexpected response."
			}
		}
	}

	private let endpoint = URL(string: "https://api.openai.com/v1/chat/completions")!
	private let model = "gpt-4o-mini"

	func sendToLLM(messages: [ChatMessage]) async throws -> String {
		if ProcessInfo.processInfo.environment["OPENAI_API_KEY"]?.isEmpty ?? true {
			// TODO: Set the OPENAI_API_KEY environment variable or swap in your preferred provider.
			try await Task.sleep(nanoseconds: 1_000_000_000)
			return "Stubbed assistant reply. Provide OPENAI_API_KEY to call the live model."
		}

		var request = URLRequest(url: endpoint)
		request.httpMethod = "POST"
		request.addValue("application/json", forHTTPHeaderField: "Content-Type")
		request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

		let payload = ChatCompletionRequest(
			model: model,
			messages: messages.map { ChatCompletionRequest.Message(role: $0.role.apiValue, content: $0.content) },
			temperature: 0.2
		)

		request.httpBody = try JSONEncoder().encode(payload)

		let (data, response) = try await URLSession.shared.data(for: request)

		guard
			let httpResponse = response as? HTTPURLResponse,
			200 ..< 300 ~= httpResponse.statusCode
		else {
			throw ServiceError.invalidResponse
		}

		let completion = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
		guard let content = completion.choices.first?.message.content else {
			throw ServiceError.invalidResponse
		}

		return content.trimmingCharacters(in: .whitespacesAndNewlines)
	}

	private var apiKey: String {
		ProcessInfo.processInfo.environment["OPENAI_API_KEY"] ?? ""
	}
}

private extension ChatMessage.Role {
	var apiValue: String {
		switch self {
		case .user:
			return "user"
		case .assistant:
			return "assistant"
		}
	}
}

private struct ChatCompletionRequest: Encodable {
	let model: String
	let messages: [Message]
	let temperature: Double

	struct Message: Encodable {
		let role: String
		let content: String
	}
}

private struct ChatCompletionResponse: Decodable {
	let choices: [Choice]

	struct Choice: Decodable {
		let message: Message
	}

	struct Message: Decodable {
		let content: String
	}
}

