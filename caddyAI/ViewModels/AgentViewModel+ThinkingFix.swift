import Foundation
import SwiftUI

extension AgentViewModel {
    /// Replacement for processInput that sets thinking state immediately
    func processInputWithThinking(text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        // Don't show the special __CONFIRMED__ token in the UI
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
            // FIX: Show thinking status immediately for responsiveness
            isThinking = true
            currentStatus = .thinking()
            
            errorMessage = nil
            activeTool = nil
            proposal = nil // Clear any previous proposal
            proposalQueue.removeAll()
            currentProposalIndex = 0
            appSteps.removeAll()
            seenProposalSignatures.removeAll()
            hasInsertedActionSummary = false // Reset for new request
            
            await sendMessageToBackend(text: trimmed)
        }
    }
}
