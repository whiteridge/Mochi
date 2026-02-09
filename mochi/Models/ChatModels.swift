import Foundation

// MARK: - Request Models

struct ChatRequest: Codable {
    let messages: [Message]
    let userId: String
    let confirmedTool: ConfirmedToolData?
    let userTimezone: String?
    let apiKey: String?
    let model: ModelConfig?
    
    enum CodingKeys: String, CodingKey {
        case messages
        case userId = "user_id"
        case confirmedTool = "confirmed_tool"
        case userTimezone = "user_timezone"
        case apiKey = "api_key"
        case model
    }
    
    init(
        messages: [Message],
        userId: String,
        confirmedTool: ConfirmedToolData? = nil,
        userTimezone: String? = nil,
        apiKey: String? = nil,
        model: ModelConfig? = nil
    ) {
        self.messages = messages
        self.userId = userId
        self.confirmedTool = confirmedTool
        self.userTimezone = userTimezone
        self.apiKey = apiKey
        self.model = model
    }
}

struct ModelConfig: Codable {
    let model: String?
    let apiKey: String?

    enum CodingKeys: String, CodingKey {
        case model
        case apiKey = "api_key"
    }

    init(model: String?, apiKey: String?) {
        self.model = model
        self.apiKey = apiKey
    }
}

/// Data for confirmed tool execution in multi-app scenarios
struct ConfirmedToolData: Codable {
    let tool: String
    let args: [String: Any]
    let appId: String
    let toolCallId: String?
    
    enum CodingKeys: String, CodingKey {
        case tool
        case args
        case appId = "app_id"
        case toolCallId = "tool_call_id"
    }
    
    init(tool: String, args: [String: Any], appId: String, toolCallId: String? = nil) {
        self.tool = tool
        self.args = args
        self.appId = appId
        self.toolCallId = toolCallId
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        tool = try container.decode(String.self, forKey: .tool)
        appId = try container.decode(String.self, forKey: .appId)
        toolCallId = try container.decodeIfPresent(String.self, forKey: .toolCallId)
        
        // Decode args as AnyCodable dictionary then extract values
        let anyCodableArgs = try container.decode([String: AnyCodable].self, forKey: .args)
        args = anyCodableArgs.mapValues { $0.value }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(tool, forKey: .tool)
        try container.encode(appId, forKey: .appId)
        try container.encodeIfPresent(toolCallId, forKey: .toolCallId)
        
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
    case thinking
}

/// State of an app step in a multi-app workflow
enum AppStepState: String, Codable {
    case searching  // Currently searching/reading
    case active     // Has proposal pending confirmation
    case done       // Confirmed and executed
    case waiting    // Pending, not yet reached
    case error      // Read/action failed
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
    let toolCallId: String?   // For proposal events
    
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
        case toolCallId = "tool_call_id"
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
    var toolCallId: String?   // Tool call ID from model
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
    
    // MARK: - Slack Fields
    
    /// The channel name or ID for Slack messages
    var channel: String? {
        // Prefer enriched channelName, fall back to raw channel ID
        args["channelName"] as? String ?? args["channel_name"] as? String ?? args["channel"] as? String
    }
    
    /// The message text for Slack
    var messageText: String? {
        args["text"] as? String
            ?? args["markdown_text"] as? String
            ?? args["markdownText"] as? String
            ?? args["message"] as? String
    }
    
    /// The target user name for Slack DMs or ephemeral messages
    var userName: String? {
        args["userName"] as? String ?? args["user_name"] as? String ?? args["user"] as? String
    }
    
    /// Scheduled time for Slack scheduled messages (Unix timestamp)
    var scheduledTime: Int? {
        args["post_at"] as? Int ?? args["postAt"] as? Int ?? args["scheduled_time"] as? Int
    }

    // MARK: - Gmail Fields

    var emailTo: [String] {
        normalizedStringList(for: ["to", "to_emails", "toEmails", "recipient", "recipients", "email", "emails"])
    }

    var emailCc: [String] {
        normalizedStringList(for: ["cc", "cc_emails", "ccEmails"])
    }

    var emailBcc: [String] {
        normalizedStringList(for: ["bcc", "bcc_emails", "bccEmails"])
    }

    var emailSubject: String? {
        stringValue(for: ["subject", "title"])
    }

    var emailBody: String? {
        stringValue(for: ["body", "message", "text", "content"])
    }

    var emailThreadId: String? {
        stringValue(for: ["thread_id", "threadId", "thread"])
    }

    // MARK: - Notion Fields

    var notionTitle: String? {
        if let title = stringValue(for: ["title", "page_title", "name"]) {
            return title
        }
        if let properties = args["properties"] as? [String: Any] {
            return notionTitle(from: properties)
        }
        return nil
    }

    var notionContent: String? {
        stringValue(for: ["content", "body", "text", "description"])
    }

    var notionIcon: String? {
        if let icon = stringValue(for: ["icon"]) {
            return icon
        }
        if let iconDict = args["icon"] as? [String: Any] {
            return stringValue(from: iconDict)
        }
        return nil
    }

    var notionParentId: String? {
        stringValue(for: ["parent_id", "parentId", "parent"])
    }

    var notionPropertyPairs: [(String, String)] {
        guard let properties = args["properties"] as? [String: Any] else { return [] }
        let excludedKeys = Set(["title", "name"])
        let pairs = properties.compactMap { key, value -> (String, String)? in
            guard !excludedKeys.contains(key.lowercased()) else { return nil }
            guard let formatted = stringValue(from: value) else { return nil }
            return (key, formatted)
        }
        return pairs.sorted { $0.0.lowercased() < $1.0.lowercased() }
    }

    // MARK: - GitHub Fields

    var githubOwner: String? {
        stringValue(for: ["owner", "org", "organization", "repo_owner", "repoOwner"])
    }

    var githubRepo: String? {
        stringValue(for: ["repo", "repository", "repo_name", "repoName", "name"])
    }

    var githubRepoFullName: String? {
        if let owner = githubOwner, let repo = githubRepo {
            return "\(owner)/\(repo)"
        }
        if let repo = githubRepo {
            return repo
        }
        return stringValue(for: ["full_name", "fullName", "repository_full_name", "repositoryFullName"])
    }

    var githubTitle: String? {
        stringValue(for: ["title", "subject"])
    }

    var githubBody: String? {
        stringValue(for: ["body", "description", "content", "text", "message"])
    }

    var githubHead: String? {
        stringValue(for: ["head", "head_ref", "headRef", "head_branch", "headBranch"])
    }

    var githubBase: String? {
        stringValue(for: ["base", "base_ref", "baseRef", "base_branch", "baseBranch"])
    }

    var githubIssueNumber: String? {
        stringValue(for: ["issue_number", "issueNumber", "issue", "number"])
    }

    var githubPullNumber: String? {
        stringValue(for: ["pull_number", "pullNumber", "pull_request_number", "pr_number", "prNumber"])
    }

    var githubLabels: [String] {
        normalizedStringList(for: ["labels", "label", "label_names", "labelNames"])
    }

    var githubAssignees: [String] {
        normalizedStringList(for: ["assignees", "assignee", "assignee_logins", "assigneeLogins"])
    }

    var githubVisibility: String? {
        if let isPrivate = args["private"] as? Bool {
            return isPrivate ? "Private" : "Public"
        }
        if let visibility = stringValue(for: ["visibility"]) {
            return visibility.capitalized
        }
        return nil
    }
    
    // MARK: - App Type Detection
    
    var isSlackApp: Bool {
        appId?.lowercased() == "slack" || tool.lowercased().contains("slack")
    }
    
    var isLinearApp: Bool {
        appId?.lowercased() == "linear" || tool.lowercased().contains("linear")
    }

    var isCalendarApp: Bool {
        let lowerTool = tool.lowercased()
        return appId?.lowercased() == "google_calendar"
            || lowerTool.contains("googlecalendar")
            || lowerTool.contains("google_calendar")
    }

    var isGmailApp: Bool {
        let lowerAppId = appId?.lowercased()
        return lowerAppId == "gmail"
            || lowerAppId == "googlemail"
            || tool.lowercased().contains("gmail")
    }

    var isNotionApp: Bool {
        appId?.lowercased() == "notion" || tool.lowercased().contains("notion")
    }

    var isGitHubApp: Bool {
        let lowerAppId = appId?.lowercased()
        return lowerAppId == "github" || tool.lowercased().contains("github")
    }
    
    // Helper to check if field exists
    func hasField(_ key: String) -> Bool {
        return args[key] != nil
    }

    // MARK: - Gmail Helpers

    private func stringValue(for keys: [String]) -> String? {
        for key in keys {
            if let value = args[key] as? String {
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    return trimmed
                }
            } else if let value = args[key] as? Int {
                return "\(value)"
            } else if let value = args[key] as? Double {
                return "\(value)"
            } else if let value = args[key] as? Bool {
                return value ? "true" : "false"
            }
        }
        return nil
    }

    private func stringValue(from value: Any) -> String? {
        if let string = value as? String {
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        if let number = value as? NSNumber {
            return number.stringValue
        }
        if let array = value as? [String] {
            let cleaned = array.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
            return cleaned.isEmpty ? nil : cleaned.joined(separator: ", ")
        }
        if let array = value as? [Any] {
            let parts = array.compactMap { stringValue(from: $0) }
            return parts.isEmpty ? nil : parts.joined(separator: ", ")
        }
        if let dict = value as? [String: Any] {
            let preferredKeys = ["name", "title", "plain_text", "content", "text", "value", "id"]
            for key in preferredKeys {
                if let nested = dict[key], let value = stringValue(from: nested) {
                    return value
                }
            }
            if JSONSerialization.isValidJSONObject(dict),
               let data = try? JSONSerialization.data(withJSONObject: dict, options: [.sortedKeys]),
               let string = String(data: data, encoding: .utf8) {
                return string
            }
        }
        return nil
    }

    private func notionTitle(from properties: [String: Any]) -> String? {
        let titleKeys = ["title", "name"]
        for key in titleKeys {
            if let value = properties[key], let title = stringValue(from: value) {
                return title
            }
        }
        return nil
    }

    private func normalizedStringList(for keys: [String]) -> [String] {
        for key in keys {
            if let values = args[key] as? [String] {
                let cleaned = values.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
                if !cleaned.isEmpty {
                    return cleaned
                }
            } else if let values = args[key] as? [Any] {
                let cleaned = values.compactMap { $0 as? String }
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                if !cleaned.isEmpty {
                    return cleaned
                }
            } else if let value = args[key] as? String {
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty {
                    continue
                }
                let parts = trimmed
                    .split { $0 == "," || $0 == ";" }
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                return parts.isEmpty ? [trimmed] : parts
            }
        }
        return []
    }
    
    // Equatable conformance
    static func == (lhs: ProposalData, rhs: ProposalData) -> Bool {
        lhs.tool == rhs.tool && 
        lhs.appId == rhs.appId &&
        lhs.proposalIndex == rhs.proposalIndex &&
        lhs.toolCallId == rhs.toolCallId &&
        NSDictionary(dictionary: lhs.args).isEqual(to: rhs.args)
    }
}

// Safe array subscript extension
extension Array {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
