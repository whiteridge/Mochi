import Foundation
import SwiftUI

extension AgentViewModel {
    /// Send a confirmed proposal to backend for execution
    func sendWithConfirmedTool(proposal: ProposalData) async {
        let confirmedTool = ConfirmedToolData(
            tool: proposal.tool,
            args: proposal.args,  // Pass args directly, ConfirmedToolData handles encoding
            appId: proposal.appId ?? proposal.tool.split(separator: "_").first.map(String.init)?.lowercased() ?? "unknown"
        )
        
        do {
            let historyForRequest = messages.dropLast().map { msg in
                Message(role: msg.role == .user ? "user" : "assistant", content: msg.content)
            }
            
            let stream = await llmService.sendMessage(text: "Execute confirmed action", history: historyForRequest, confirmedTool: confirmedTool)
            
            for try await event in stream {
                await handleStreamEvent(event)
            }
            
            // Mark execution complete
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.3)) {
                    isExecutingAction = false
                }
                
                // Fallback: if all proposals are processed and we still have app steps, mark completion
                if proposalQueue.isEmpty && !appSteps.isEmpty {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        for idx in appSteps.indices {
                            appSteps[idx].state = .done
                        }
                    }
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 800_000_000)
                        withAnimation(.easeInOut(duration: 0.3)) {
                            appSteps.removeAll()
                        }
                    }
                    state = .success
                }
            }
        } catch {
            await MainActor.run {
                isExecutingAction = false
                errorMessage = error.localizedDescription
            }
        }
    }
    
    /// Handle stream events (extracted for reuse)
    func handleStreamEvent(_ event: StreamEvent) async {
        await MainActor.run {
            switch event.type {
            case .proposal:
                // Backend found another write action - show new proposal card
                if let tool = event.tool, let content = event.content?.value as? [String: Any] {
                    var proposalData = ProposalData(tool: tool, args: content)
                    proposalData.summaryText = event.summaryText
                    proposalData.appId = event.appId
                    proposalData.proposalIndex = event.proposalIndex ?? 0
                    proposalData.totalProposals = event.totalProposals ?? 1
                    
                    // Slide current card left, new card comes from right
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                        cardTransitionDirection = .trailing
                        proposal = proposalData
                        
                        // Mark this app as active
                        if let appId = event.appId,
                           let index = appSteps.firstIndex(where: { $0.appId == appId }) {
                            appSteps[index].state = .active
                        }
                    }
                }
                
            case .message:
                // Final response after all actions - clear the card and show message
                if let content = event.content?.value as? String {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                        // Clear the proposal card
                        proposal = nil
                        proposalQueue.removeAll()
                        currentProposalIndex = 0
                        currentStatus = nil
                        activeTool = nil
                        appSteps.removeAll()
                        
                        // Clear proposal-related message flags
                        messages = messages.map { msg in
                            var copy = msg
                            copy.isAttachedToProposal = false
                            copy.isActionSummary = false
                            return copy
                        }
                    }
                    messages.append(ChatMessage(role: .assistant, content: content))
                }
                
            default:
                break
            }
        }
    }
    
    /// Primary streaming logic for new user input
    func sendMessageToBackend(text: String) async {
        do {
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
                            await MainActor.run {
                                withAnimation(.easeOut(duration: 0.2)) {
                                    currentStatus = nil
                                    isThinking = false
                                }
                            }
                            
                            // Fast typewriter effect: reveal word by word
                            let words = content.split(separator: " ").map(String.init)
                            await typewriterDisplay(words: words, delay: 25_000_000)
                            
                            // Convert typewriter text to permanent message
                            await MainActor.run {
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
                    }
                    
                case .toolStatus:
                    // Tool status events - update the status pill and track apps
                    if let toolName = event.tool, let status = event.status {
                        let appName = formatAppName(from: toolName)
                        let appId = event.appId ?? appName.lowercased()
                        
                        // If we haven't shown early summary yet (fallback), show a quick one
                        if !hasInsertedActionSummary && status == "searching" {
                            hasInsertedActionSummary = true
                            
                            await MainActor.run {
                                withAnimation(.easeOut(duration: 0.2)) {
                                    currentStatus = nil
                                    isThinking = false
                                }
                                
                                let summaryText = "I'll search \(appName) to help with your request."
                                messages.append(ChatMessage(role: .assistant, content: summaryText, isActionSummary: true))
                            }
                        }
                        
                        // Ensure app step exists
                        await MainActor.run {
                            if !appSteps.contains(where: { $0.appId == appId }) {
                                let newStep = AppStep(appId: appId, state: .waiting, proposalIndex: appSteps.count)
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    appSteps.append(newStep)
                                }
                            }
                            
                            if let index = appSteps.firstIndex(where: { $0.appId == appId }) {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    switch status {
                                    case "searching":
                                        appSteps[index].state = .searching
                                        activeTool = ToolStatus(name: toolName, status: status)
                                        currentStatus = .searching(appName: appName)
                                    case "done":
                                        // Keep text+icon (waiting) until the write completes; do not collapse yet
                                        appSteps[index].state = .waiting
                                        if currentStatus == .searching(appName: appName) {
                                            currentStatus = nil
                                        }
                                        activeTool = nil
                                    case "error":
                                        appSteps[index].state = .error
                                        if currentStatus == .searching(appName: appName) {
                                            currentStatus = nil
                                        }
                                        activeTool = nil
                                        errorMessage = "Encountered an error with \(appName)."
                                    default:
                                        break
                                    }
                                }
                            }
                        }
                    }
                    
                case .proposal:
                    if let tool = event.tool, let content = event.content?.value as? [String: Any] {
                        // Track the currently visible card before switching
                        let previousAppId = proposal?.appId
                        
                        await MainActor.run {
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
                                proposalData.summaryText = event.summaryText
                                proposalData.appId = event.appId
                                proposalData.proposalIndex = event.proposalIndex ?? 0
                                proposalData.totalProposals = event.totalProposals ?? 1
                                
                                // Build proposal queue from remaining proposals
                                proposalQueue = [proposalData]
                                if let remaining = event.remainingProposals {
                                    for rp in remaining {
                                        if let rpTool = rp["tool"]?.value as? String,
                                           let rpAppId = rp["app_id"]?.value as? String {
                                            var rpArgs: [String: Any] = [:]
                                            if let argsDict = rp["args"]?.value as? [String: Any] {
                                                rpArgs = argsDict
                                            }
                                            var rpData = ProposalData(tool: rpTool, args: rpArgs)
                                            rpData.appId = rpAppId
                                            rpData.proposalIndex = proposalQueue.count
                                            rpData.totalProposals = event.totalProposals ?? 1
                                            proposalQueue.append(rpData)
                                        }
                                    }
                                }
                                
                                currentProposalIndex = proposalData.proposalIndex
                                proposal = proposalData
                                isThinking = false
                                activeTool = nil
                                
                                // Mark previous app as done when advancing to the next proposal
                                if let prev = previousAppId,
                                   prev != event.appId,
                                   let idx = appSteps.firstIndex(where: { $0.appId == prev }) {
                                    appSteps[idx].state = .done
                                }
                                
                                // Mark only the proposal's app as active; earlier apps collapse to done
                                for index in appSteps.indices {
                                    if appSteps[index].appId == event.appId {
                                        appSteps[index].state = .active
                                    } else if let stepIndex = appSteps[index].proposalIndex,
                                              stepIndex < proposalData.proposalIndex {
                                        appSteps[index].state = .done
                                    } else {
                                        appSteps[index].state = .waiting
                                    }
                                }

                                // Keep currentStatus showing the app name for single-pill mode
                                if let appId = event.appId {
                                    currentStatus = .searching(appName: appId.capitalized)
                                }
                            }
                        }
                    }
                    
                case .multiAppStatus:
                    if let apps = event.apps {
                        var steps: [AppStep] = []
                        for (idx, appDict) in apps.enumerated() {
                            if let appId = appDict["app_id"]?.value as? String,
                               let stateStr = appDict["state"]?.value as? String,
                               let state = AppStepState(rawValue: stateStr) {
                                steps.append(AppStep(appId: appId, state: state, proposalIndex: idx))
                            }
                        }
                        await MainActor.run {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                appSteps = steps
                                // Mark active app as searching initially
                                if let activeId = event.activeApp,
                                   let index = appSteps.firstIndex(where: { $0.appId == activeId }) {
                                    appSteps[index].state = .searching
                                    currentStatus = .searching(appName: activeId.capitalized)
                                }
                            }
                        }
                    }
                    
                case .message:
                    if let content = event.content?.value as? String {
                        await MainActor.run {
                            isThinking = false
                            activeTool = nil // Clear tool status
                            currentStatus = nil // Clear status on message
                        }
                        
                        // Progressive typewriter effect for assistant response
                        let trimmedContent = content.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                        let words = trimmedContent.split(separator: " ").map(String.init)
                        await typewriterDisplay(words: words, delay: 20_000_000)
                        
                        await MainActor.run {
                            // Convert typewriter to permanent message
                            messages.append(ChatMessage(role: .assistant, content: trimmedContent))
                            typewriterText = ""
                            
                            // Determine next state
                            if event.actionPerformed != nil {
                                print("DEBUG: Action Performed received. Switching to success state.")
                                isExecutingAction = false // Action complete
                                
                                // Mark all app pills as done, then fade them out after a short delay
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    for idx in appSteps.indices {
                                        appSteps[idx].state = .done
                                    }
                                }
                                Task { @MainActor in
                                    try? await Task.sleep(nanoseconds: 800_000_000) // 0.8s
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        appSteps.removeAll()
                                    }
                                }
                                
                                state = .success
                            } else {
                                isExecutingAction = false // No action performed, reset flag
                                state = .chat
                                
                                // If there are no proposals queued, clear any lingering app pills
                                if proposalQueue.isEmpty {
                                    withAnimation(.easeInOut(duration: 0.25)) {
                                        appSteps.removeAll()
                                    }
                                }
                            }
                        }
                    }
                }
            }
            
        } catch {
            await MainActor.run {
                isThinking = false
                currentStatus = nil
                isExecutingAction = false // Reset on error
                activeTool = nil
                errorMessage = error.localizedDescription
                state = .chat // Fallback to chat on error so user can retry
            }
        }
    }
    
    // MARK: - Typewriter helper
    private func typewriterDisplay(words: [String], delay: UInt64) async {
        await MainActor.run {
            typewriterText = ""
            isTypewriterActive = true
        }
        
        for (index, word) in words.enumerated() {
            if index > 0 {
                try? await Task.sleep(nanoseconds: delay)
            }
            await MainActor.run {
                typewriterText += (index > 0 ? " " : "") + word
            }
        }
        
        await MainActor.run {
            isTypewriterActive = false
        }
    }
}


