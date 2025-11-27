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
    @Published var activeTool: ToolStatus?
    @Published var proposal: ProposalData? // New: Proposal State
    @Published var messages: [ChatMessage] = []
    @Published var userInput: String = ""
    @Published var isThinking: Bool = false
    @Published var isTranscribing: Bool = false
    @Published var isExecutingAction: Bool = false
    @Published var errorMessage: String?
    
    // MARK: - Dependencies
    
    private let llmService = LLMService.shared
    
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
        state = .processing // This will trigger the thinking animation if handled in View
        isThinking = true
        errorMessage = nil
        activeTool = nil
        proposal = nil // Clear any previous proposal
        
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
        
        // Send special confirmation token to backend
        // This prevents false positives (e.g., user saying "yes" in conversation)
        processInput(text: "__CONFIRMED__")
        
        withAnimation {
            proposal = nil
        }
    }
    
    func cancelProposal() {
        withAnimation {
            proposal = nil
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
                case .toolStatus:
                    if let toolName = event.tool, let status = event.status {
                        withAnimation {
                            activeTool = ToolStatus(name: toolName, status: status)
                            isThinking = false // Stop generic thinking, show tool status
                        }
                    }
                    
                case .proposal:
                    if let tool = event.tool, let content = event.content?.value as? [String: Any] {
                        withAnimation {
                            proposal = ProposalData(tool: tool, args: content)
                            isThinking = false
                            activeTool = nil
                            // We stay in .processing or move to a specific .confirming state?
                            // Let's keep it simple: if proposal is not nil, the View shows the card.
                        }
                    }
                    
                case .message:
                    if let content = event.content?.value as? String {
                        isThinking = false
                        activeTool = nil // Clear tool status
                        
                        // Add assistant response to UI
                        messages.append(ChatMessage(role: .assistant, content: content))
                        
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
        isTranscribing = false
        isExecutingAction = false
        errorMessage = nil
        proposal = nil
    }
}
