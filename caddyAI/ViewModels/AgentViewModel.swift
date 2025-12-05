import Foundation
import Combine
import SwiftUI

public enum VoiceChatState: Equatable {
    case idle
    case recording
    case processing
    case chat
    case success
}

struct ToolStatus: Equatable {
    let name: String
    let status: String
}

public enum AgentStatus: Equatable, Identifiable {
    case thinking
    case transcribing
    case searching(appName: String)

    public var id: String {
        switch self {
        case .thinking:
            return "thinking"
        case .transcribing:
            return "transcribing"
        case .searching(let app):
            return "search-\(app)"
        }
    }

    var labelText: String {
        switch self {
        case .thinking:
            return "Thinking..."
        case .transcribing:
            return "Transcribing..."
        case .searching(let appName):
            return "Searching \(appName)..."
        }
    }
    
    /// App name for icon display (nil for non-app-specific statuses)
    var appName: String? {
        switch self {
        case .searching(let name):
            return name
        default:
            return nil
        }
    }
}

// Tool info structure for display
struct ToolInfo {
    let displayName: String
    let iconName: String // SF Symbol name
}

@MainActor
class AgentViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var state: VoiceChatState = .idle {
        didSet {
            if state == .success {
                Task {
                    try? await Task.sleep(nanoseconds: 2 * 1_000_000_000) // 2 seconds
                    await MainActor.run {
                        // Only reset if we are still in the success state (re-entrancy check)
                        if state == .success {
                            withAnimation(.easeInOut(duration: 0.5)) {
                                state = .idle
                            }
                            // Dismiss the panel after the success animation completes
                            NotificationCenter.default.post(name: .voiceChatShouldDismissPanel, object: nil)
                        }
                    }
                }
            }
        }
    }
    @Published var currentStatus: AgentStatus? = nil
    @Published var activeTool: ToolStatus?
    @Published var proposal: ProposalData? = nil
    @Published var proposalQueue: [ProposalData] = []  // Multi-app proposal queue
    @Published var currentProposalIndex: Int = 0       // Index in queue
    @Published var appSteps: [AppStep] = []            // App status tracking
    @Published var messages: [ChatMessage] = []
    @Published var userInput: String = ""
    @Published var isThinking: Bool = false
    @Published var isExecutingAction: Bool = false
    @Published var errorMessage: String?
    @Published var cardTransitionDirection: Edge = .bottom  // For card slide animation
    
    // MARK: - Private State
    
    var hasInsertedActionSummary: Bool = false
    @Published var typewriterText: String = "" // For progressive text reveal
    var isTypewriterActive: Bool = false
    
    // MARK: - Dependencies
    
    let llmService = LLMService.shared
    
    // MARK: - Tool Display Info
    
    /// Maps tool name prefix to display info (name + icon)
    private static let toolInfoMap: [String: ToolInfo] = [
        "linear": ToolInfo(displayName: "Linear", iconName: "line.3.horizontal.circle"),
        "slack": ToolInfo(displayName: "Slack", iconName: "number.square"),
        "github": ToolInfo(displayName: "GitHub", iconName: "chevron.left.forwardslash.chevron.right"),
        "notion": ToolInfo(displayName: "Notion", iconName: "doc.text"),
        "google": ToolInfo(displayName: "Google", iconName: "globe"),
    ]
    
    /// Active tool display name derived from proposal
    var activeToolDisplayName: String {
        guard let proposal = proposal else { return "Action" }
        let prefix = proposal.tool.split(separator: "_").first.map(String.init) ?? ""
        return Self.toolInfoMap[prefix.lowercased()]?.displayName ?? "Action"
    }
    
    /// Active tool icon derived from proposal
    var activeToolIconName: String {
        guard let proposal = proposal else { return "sparkles" }
        let prefix = proposal.tool.split(separator: "_").first.map(String.init) ?? ""
        return Self.toolInfoMap[prefix.lowercased()]?.iconName ?? "sparkles"
    }
    
    // MARK: - Actions
    
    func processInput(text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        // Don't show the special __CONFIRMED__ token in the UI
        // It's an internal protocol message for the backend
        let isConfirmationToken = trimmed == "__CONFIRMED__"
        
        // Dispatch state changes to avoid "Publishing changes from within view updates" warning
        Task { @MainActor in
            // Add user message to UI (unless it's the confirmation token)
            if !isConfirmationToken {
                messages.append(ChatMessage(role: .user, content: trimmed))
            }
            userInput = ""
            
            // Update state
            state = .processing
            // Don't show thinking status immediately - wait for tool events or response
            isThinking = false
            currentStatus = nil
            errorMessage = nil
            activeTool = nil
            proposal = nil // Clear any previous proposal
            proposalQueue.removeAll()
            currentProposalIndex = 0
            appSteps.removeAll()
            hasInsertedActionSummary = false // Reset for new request
            
            await sendMessageToBackend(text: trimmed)
        }
    }
    
    func confirmProposal() {
        guard let p = proposal else { return }
        
        // Set executing flag - keeps current card visible during execution
        isExecutingAction = true
        
        // Inject hidden context so the model knows what it proposed
        let context = "I proposed to call \(p.tool) with arguments: \(p.args)"
        messages.append(ChatMessage(role: .assistant, content: context, isHidden: true))
        
        // Execute the action and WAIT for backend response before transitioning
        // The card stays visible until we get a new proposal or completion
        Task {
            await sendWithConfirmedTool(proposal: p)
        }
    }
    
    func cancelProposal() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
            proposal = nil
            proposalQueue.removeAll()
            currentProposalIndex = 0
            appSteps.removeAll()
            // Clear proposal-related flags
            messages = messages.map { msg in
                var copy = msg
                copy.isAttachedToProposal = false
                return copy
            }
            state = .chat // Return to chat state
        }
        messages.append(ChatMessage(role: .assistant, content: "Action cancelled."))
    }
    
    
    func reset() {
        state = .idle
        messages.removeAll()
        userInput = ""
        isThinking = false
        currentStatus = nil
        isExecutingAction = false
        errorMessage = nil
        proposal = nil
        proposalQueue.removeAll()
        currentProposalIndex = 0
        appSteps.removeAll()
        cardTransitionDirection = .bottom
    }
    
    func formatAppName(from toolName: String) -> String {
        // Tool names are typically "appname_action_name" (e.g. "linear_get_issue", "slack_send_message")
        // We want to extract "Linear" or "Slack"
        
        let components = toolName.split(separator: "_")
        guard let first = components.first else { return toolName.capitalized }
        
        let appName = String(first).capitalized
        
        // Handle special cases or typos if needed (e.g. "Zlack" -> "Slack" if that was a real issue, but assuming user typo)
        // For now, standard capitalization should work for "linear" -> "Linear", "slack" -> "Slack", "google_calendar" -> "Google"
        
        return appName
    }
}
