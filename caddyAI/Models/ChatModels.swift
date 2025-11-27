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
    var isHidden: Bool = false
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
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues { $0.value }
        } else if let dict = try? container.decode([String: String].self) {
             value = dict
        } else if let dict = try? container.decode([String: Int].self) {
             value = dict
        } else {
             // Fallback for other types
             value = "Unknown content"
        }
    }
}

struct ProposalData: Equatable {
    let tool: String
    let args: [String: Any]
    
    // Computed properties for common Linear fields
    var title: String? {
        args["title"] as? String
    }
    
    var description: String? {
        args["description"] as? String
    }
    
    var priority: String? {
        if let priorityInt = args["priority"] as? Int {
            return ["Urgent", "High", "Medium", "Low", "No Priority"][safe: priorityInt] ?? "No Priority"
        }
        return args["priority"] as? String
    }
    
    var teamId: String? {
        args["team_id"] as? String ?? args["teamId"] as? String ?? args["team"] as? String
    }
    
    var projectId: String? {
        args["project_id"] as? String ?? args["projectId"] as? String ?? args["project"] as? String
    }
    
    var assigneeId: String? {
        args["assignee_id"] as? String ?? args["assigneeId"] as? String ?? args["assignee"] as? String
    }
    
    var status: String? {
        args["state_id"] as? String ?? args["status"] as? String
    }
    
    // Helper to check if field exists
    func hasField(_ key: String) -> Bool {
        return args[key] != nil
    }
    
    // Equatable conformance
    static func == (lhs: ProposalData, rhs: ProposalData) -> Bool {
        lhs.tool == rhs.tool && NSDictionary(dictionary: lhs.args).isEqual(to: rhs.args)
    }
}

// Safe array subscript extension
extension Array {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
