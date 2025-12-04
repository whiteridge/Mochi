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
    @Published var proposal: ProposalData? // New: Proposal State
    @Published var messages: [ChatMessage] = []
    @Published var userInput: String = ""
    @Published var isThinking: Bool = false
    @Published var isExecutingAction: Bool = false
    @Published var errorMessage: String?
    
    // MARK: - Private State
    
    private var hasInsertedActionSummary: Bool = false
    @Published var typewriterText: String = "" // For progressive text reveal
    private var isTypewriterActive: Bool = false
    
    // MARK: - Dependencies
    
    private let llmService = LLMService.shared
    
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
        hasInsertedActionSummary = false // Reset for new request
        
        Task {
            await sendMessageToBackend(text: trimmed)
        }
    }
    
    func confirmProposal() {
        guard let p = proposal else { return }
        
        // Set executing flag before processing
        isExecutingAction = true
        
        // Inject hidden context so the model knows what it proposed
        // This is critical because the backend is stateless and the original proposal
        // was intercepted and never added to history.
        let context = "I proposed to call \(p.tool) with arguments: \(p.args)"
        messages.append(ChatMessage(role: .assistant, content: context, isHidden: true))
        
        // Clear proposal-related flags and proposal with animation
        withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
            messages = messages.map { msg in
                var copy = msg
                copy.isAttachedToProposal = false
                copy.isActionSummary = false
                return copy
            }
            proposal = nil
        }
        
        // Send special confirmation token to backend
        // This prevents false positives (e.g., user saying "yes" in conversation)
        processInput(text: "__CONFIRMED__")
    }
    
    func cancelProposal() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
            proposal = nil
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
    
    private func sendMessageToBackend(text: String) async {
        do {
            // Construct history
            let historyForRequest = messages.dropLast().map { msg in
                Message(role: msg.role == .user ? "user" : "assistant", content: msg.content)
            }
            
            let stream = await llmService.sendMessage(text: text, history: historyForRequest)
            
            for try await event in stream {
                switch event.type {
                case .earlySummary:
                    // Handle early summary from backend with fast typewriter effect
                    if let content = event.content?.value as? String,
                       let appId = event.appId {
                        if !hasInsertedActionSummary {
                            hasInsertedActionSummary = true
                            isTypewriterActive = true
                            
                            // Clear any status so message area is clean
                            withAnimation(.easeOut(duration: 0.2)) {
                                currentStatus = nil
                                isThinking = false
                            }
                            
                            // Fast typewriter effect: reveal word by word
                            let words = content.split(separator: " ").map(String.init)
                            typewriterText = ""
                            
                            for (index, word) in words.enumerated() {
                                // First word appears immediately, delay only for subsequent words
                                if index > 0 {
                                    try? await Task.sleep(nanoseconds: 25_000_000) // 25ms per word
                                }
                                typewriterText += (index > 0 ? " " : "") + word
                            }
                            
                            // Convert typewriter text to permanent message
                            messages.append(ChatMessage(
                                role: .assistant,
                                content: content,
                                isActionSummary: true
                            ))
                            typewriterText = ""
                            isTypewriterActive = false
                            
                            // Show status pill after typewriter completes
                            let formattedAppName = appId.capitalized
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                currentStatus = .searching(appName: formattedAppName)
                            }
                        }
                    }
                    
                case .toolStatus:
                    // Tool status events - update the status pill if not already showing
                    if let toolName = event.tool, let status = event.status {
                        let appName = formatAppName(from: toolName)
                        
                        // If we haven't shown early summary yet (fallback), show a quick one
                        if !hasInsertedActionSummary {
                            hasInsertedActionSummary = true
                            
                            withAnimation(.easeOut(duration: 0.2)) {
                                currentStatus = nil
                                isThinking = false
                            }
                            
                            let summaryText = "I'll search \(appName) to help with your request."
                            messages.append(ChatMessage(role: .assistant, content: summaryText, isActionSummary: true))
                        }
                        
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            activeTool = ToolStatus(name: toolName, status: status)
                            currentStatus = .searching(appName: appName)
                        }
                    }
                    
                case .proposal:
                    if let tool = event.tool, let content = event.content?.value as? [String: Any] {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                            // Flag messages from current interaction as attached to proposal
                            messages = messages.map { msg in
                                var copy = msg
                                // Mark user messages and action summary as attached
                                if (msg.role == .user && !msg.isHidden) || msg.isActionSummary {
                                    copy.isAttachedToProposal = true
                                }
                                return copy
                            }
                            var proposalData = ProposalData(tool: tool, args: content)
                            proposalData.summaryText = event.summaryText  // Reuse early summary
                            proposal = proposalData
                            isThinking = false
                            activeTool = nil
                            currentStatus = nil // Clear status on proposal
                        }
                    }
                    
                case .message:
                    if let content = event.content?.value as? String {
                        isThinking = false
                        activeTool = nil // Clear tool status
                        currentStatus = nil // Clear status on message
                        
                        // Progressive typewriter effect for assistant response
                        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
                        let words = trimmedContent.split(separator: " ").map(String.init)
                        typewriterText = ""
                        
                        for (index, word) in words.enumerated() {
                            try? await Task.sleep(nanoseconds: 20_000_000) // 20ms per word (fast)
                            typewriterText += (index > 0 ? " " : "") + word
                        }
                        
                        // Convert typewriter to permanent message
                        messages.append(ChatMessage(role: .assistant, content: trimmedContent))
                        typewriterText = ""
                        
                        // Determine next state
                        if event.actionPerformed != nil {
                            print("DEBUG: Action Performed received. Switching to success state.")
                            isExecutingAction = false // Action complete
                            state = .success
                        } else {
                            isExecutingAction = false // No action performed, reset flag
                            state = .chat
                        }
                    }
                }
            }
            
        } catch {
            isThinking = false
            currentStatus = nil
            isExecutingAction = false // Reset on error
            activeTool = nil
            errorMessage = error.localizedDescription
            state = .chat // Fallback to chat on error so user can retry
        }
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
    }
    
    private func formatAppName(from toolName: String) -> String {
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
