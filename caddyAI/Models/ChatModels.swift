import Foundation

// MARK: - Request Models

struct ChatRequest: Codable {
    let messages: [Message]
    let userId: String
    let confirmedTool: ConfirmedToolData?
    
    enum CodingKeys: String, CodingKey {
        case messages
        case userId = "user_id"
        case confirmedTool = "confirmed_tool"
    }
    
    init(messages: [Message], userId: String, confirmedTool: ConfirmedToolData? = nil) {
        self.messages = messages
        self.userId = userId
        self.confirmedTool = confirmedTool
    }
}

/// Data for confirmed tool execution in multi-app scenarios
struct ConfirmedToolData: Codable {
    let tool: String
    let args: [String: Any]
    let appId: String
    
    enum CodingKeys: String, CodingKey {
        case tool
        case args
        case appId = "app_id"
    }
    
    init(tool: String, args: [String: Any], appId: String) {
        self.tool = tool
        self.args = args
        self.appId = appId
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        tool = try container.decode(String.self, forKey: .tool)
        appId = try container.decode(String.self, forKey: .appId)
        
        // Decode args as AnyCodable dictionary then extract values
        let anyCodableArgs = try container.decode([String: AnyCodable].self, forKey: .args)
        args = anyCodableArgs.mapValues { $0.value }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(tool, forKey: .tool)
        try container.encode(appId, forKey: .appId)
        
        // Encode args using AnyCodable wrapper
        let anyCodableArgs = args.mapValues { AnyCodable($0) }
        try container.encode(anyCodableArgs, forKey: .args)
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
    var isActionSummary: Bool = false
    var isAttachedToProposal: Bool = false
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
    case earlySummary = "early_summary"  // Early summary before tool execution
    case multiAppStatus = "multi_app_status"  // Multi-app status update
}

/// State of an app step in a multi-app workflow
enum AppStepState: String, Codable {
    case searching  // Currently searching/reading
    case active     // Has proposal pending confirmation
    case done       // Confirmed and executed
    case waiting    // Pending, not yet reached
}

/// Represents a single app in a multi-step workflow
struct AppStep: Identifiable, Equatable, Codable {
    var id: String { appId }
    let appId: String
    var state: AppStepState
    var proposalIndex: Int?  // Index in proposal queue if has pending proposal
    
    init(appId: String, state: AppStepState = .waiting, proposalIndex: Int? = nil) {
        self.appId = appId
        self.state = state
        self.proposalIndex = proposalIndex
    }
}

struct StreamEvent: Decodable {
    let type: StreamEventType
    // Tool Status fields
    let tool: String?
    let status: String?
    
    // Message fields
    let content: AnyCodable? // Changed to AnyCodable to handle both String and Dict
    let actionPerformed: String?
    
    // Early summary / proposal fields
    let appId: String?        // For early_summary events
    let summaryText: String?  // For proposal events (reuse of early summary)
    
    // Multi-app fields
    let involvedApps: [String]?      // List of app IDs involved
    let proposalIndex: Int?          // Current proposal index (0-based)
    let totalProposals: Int?         // Total number of proposals
    let remainingProposals: [[String: AnyCodable]]?  // Remaining proposals in queue
    let apps: [[String: AnyCodable]]?  // For multi_app_status event
    let activeApp: String?           // Currently active app
    
    enum CodingKeys: String, CodingKey {
        case type, tool, status, content, apps
        case actionPerformed = "action_performed"
        case appId = "app_id"
        case summaryText = "summary_text"
        case involvedApps = "involved_apps"
        case proposalIndex = "proposal_index"
        case totalProposals = "total_proposals"
        case remainingProposals = "remaining_proposals"
        case activeApp = "active_app"
    }
}

// Helper to handle dynamic content (String for message, Dict for proposal)
struct AnyCodable: Codable {
    let value: Any
    
    init(_ value: Any) {
        self.value = value
    }
    
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
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch value {
        case let string as String:
            try container.encode(string)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let bool as Bool:
            try container.encode(bool)
        case let array as [Any]:
            let codableArray = array.map { AnyCodable($0) }
            try container.encode(codableArray)
        case let dict as [String: Any]:
            let codableDict = dict.mapValues { AnyCodable($0) }
            try container.encode(codableDict)
        default:
            try container.encode(String(describing: value))
        }
    }
}

struct ProposalData: Equatable {
    let tool: String
    let args: [String: Any]
    var summaryText: String?  // Reused from early summary as card header
    var appId: String?        // App identifier (linear, slack, etc.)
    var proposalIndex: Int = 0      // Index in multi-proposal queue
    var totalProposals: Int = 1     // Total proposals in queue
    var remainingProposals: [[String: Any]]?  // Remaining proposals for UI decoration
    
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
        lhs.tool == rhs.tool && 
        lhs.appId == rhs.appId &&
        lhs.proposalIndex == rhs.proposalIndex &&
        NSDictionary(dictionary: lhs.args).isEqual(to: rhs.args)
    }
}

// Safe array subscript extension
extension Array {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
