import Foundation

// MARK: - Request Models

struct ChatRequest: Codable {
    let messages: [Message]
    let userId: String
    
    enum CodingKeys: String, CodingKey {
        case messages
        case userId = "user_id"
    }
}

struct Message: Codable {
    let role: String
    let content: String
}

// MARK: - UI Models

struct ChatMessage: Identifiable, Equatable {
    let id = UUID()
    let role: ChatRole
    let content: String
}

enum ChatRole {
    case user
    case assistant
}

// MARK: - Response Models

struct ChatResponse: Codable {
    let response: String
    let actionPerformed: String?
    
    enum CodingKeys: String, CodingKey {
        case response
        case actionPerformed = "action_performed"
    }
}

// MARK: - Streaming Models

enum StreamEventType: String, Codable {
    case toolStatus = "tool_status"
    case message
    case proposal
}

struct StreamEvent: Decodable {
    let type: StreamEventType
    // Tool Status fields
    let tool: String?
    let status: String?
    
    // Message fields
    let content: AnyCodable? // Changed to AnyCodable to handle both String and Dict
    let actionPerformed: String?
    
    enum CodingKeys: String, CodingKey {
        case type, tool, status, content
        case actionPerformed = "action_performed"
    }
}

// Helper to handle dynamic content (String for message, Dict for proposal)
struct AnyCodable: Decodable {
    let value: Any
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) {
            value = string
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues { $0.value }
        } else if let dict = try? container.decode([String: String].self) {
             value = dict
        } else if let dict = try? container.decode([String: Int].self) {
             value = dict
        } else {
             // Fallback for other types if needed, or just store as is if possible
             // For now, we mainly expect String or Dictionary
             value = "Unknown content"
        }
    }
}

struct ProposalData {
    let tool: String
    let args: [String: Any]
}
