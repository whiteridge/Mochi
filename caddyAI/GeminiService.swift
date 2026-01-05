import Foundation
import GoogleGenerativeAI

/// A service that handles communication with Google's Gemini AI model
@MainActor
class GeminiService: ObservableObject {
	// MARK: - Properties
	
	/// Shared singleton instance
	static let shared = GeminiService()
	
	/// The Gemini model instance
	private var model: GenerativeModel?
	
	/// Chat session for maintaining conversation context
	private var chat: Chat?
	
	/// System instruction that defines the AI's personality and behavior
	private let systemInstruction = """
	You are a helpful, concise voice assistant for macOS called "Caddy". 
	Keep your answers short and conversational, suitable for a floating chat bubble. 
	Do not use markdown formatting like bold/headers unless necessary.
	Be friendly, helpful, and direct. Respond as if you're having a natural conversation.
	"""
	
	// MARK: - Configuration Error
	
	enum GeminiError: LocalizedError {
		case missingAPIKey
		case invalidResponse
		case modelNotInitialized
		
		var errorDescription: String? {
			switch self {
			case .missingAPIKey:
				return "Please configure your Gemini API Key. Set GEMINI_API_KEY in your environment or update GeminiService.swift."
			case .invalidResponse:
				return "The AI returned an unexpected response. Please try again."
			case .modelNotInitialized:
				return "The AI model is not initialized. Please check your API key."
			}
		}
	}
	
	// MARK: - Initialization
	
	private init() {
		setupModel()
	}
	
	/// Sets up the Gemini model with the API key
	private func setupModel() {
		guard let apiKey = getAPIKey() else {
			print("⚠️ Gemini API Key not found. Please configure it.")
			return
		}
		
		// Initialize the model with gemini-3-flash-preview
		model = GenerativeModel(
			name: "gemini-3-flash-preview",
			apiKey: apiKey,
			systemInstruction: ModelContent(role: "system", parts: systemInstruction)
		)
		
		// Start a new chat session
		startNewChat()
		
		print("✅ Gemini Service initialized successfully")
	}
	
	/// Retrieves the API key from environment or configuration
	/// TODO: PASTE YOUR GEMINI API KEY HERE or set GEMINI_API_KEY environment variable
	private func getAPIKey() -> String? {
		// Option 1: Environment variable (recommended for development)
		if let envKey = ProcessInfo.processInfo.environment["GEMINI_API_KEY"],
		   !envKey.isEmpty {
			return envKey
		}
		
		// Option 2: Hardcode for quick testing (NOT recommended for production)
		// Uncomment the line below and paste your API key:
		// return "YOUR_API_KEY_HERE"
		
		return nil
	}
	
	// MARK: - Chat Management
	
	/// Starts a new chat session (resets conversation history)
	func startNewChat() {
		guard let model = model else { return }
		chat = model.startChat()
	}
	
	/// Generates a response based on the user's message
	/// - Parameter message: The user's input message
	/// - Returns: The AI's response text
	func generateResponse(for message: String) async throws -> String {
		guard model != nil else {
			throw GeminiError.modelNotInitialized
		}
		
		guard let chat = chat else {
			throw GeminiError.modelNotInitialized
		}
		
		do {
			// Send the message and get a response
			let response = try await chat.sendMessage(message)
			
			guard let text = response.text else {
				throw GeminiError.invalidResponse
			}
			
			return text.trimmingCharacters(in: .whitespacesAndNewlines)
		} catch {
			print("❌ Gemini API Error: \(error.localizedDescription)")
			throw error
		}
	}
	
	/// Generates a response with full conversation history
	/// - Parameter messages: Array of chat messages (user and assistant)
	/// - Returns: The AI's response text
	func generateResponse(for messages: [ChatMessage]) async throws -> String {
		guard model != nil else {
			throw GeminiError.modelNotInitialized
		}
		
		// Start a fresh chat for the conversation
		guard let model = model else {
			throw GeminiError.modelNotInitialized
		}
		
		_ = model.startChat()
		
		// Build history from previous messages (excluding the last user message)
		let historyMessages = messages.dropLast()
		var history: [ModelContent] = []
		
		for msg in historyMessages {
			let role = msg.role == .user ? "user" : "model"
			history.append(ModelContent(role: role, parts: msg.content))
		}
		
		// Get the last user message
		guard let lastMessage = messages.last, lastMessage.role == .user else {
			throw GeminiError.invalidResponse
		}
		
		do {
			// Send with history
			let chatWithHistory = model.startChat(history: history)
			let response = try await chatWithHistory.sendMessage(lastMessage.content)
			
			guard let text = response.text else {
				throw GeminiError.invalidResponse
			}
			
			// Update our main chat session to include this history
			self.chat = chatWithHistory
			
			return text.trimmingCharacters(in: .whitespacesAndNewlines)
		} catch {
			print("❌ Gemini API Error: \(error.localizedDescription)")
			throw error
		}
	}
	
	/// Resets the conversation (clears history)
	func resetConversation() {
		startNewChat()
	}
}

