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
            var didReceiveMessage = false
            
            for try await event in stream {
                if event.type == .message {
                    didReceiveMessage = true
                }
                await handleStreamEvent(event)
            }
            
            if !didReceiveMessage {
                await MainActor.run {
                    withAnimation(.easeOut(duration: 0.3)) {
                        isExecutingAction = false
                    }
                    
                    let previousAppId = proposal.appId
                    let hasNext = advanceProposalQueue(previousAppId: previousAppId)
                    if !hasNext {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                            proposalQueue.removeAll()
                            currentProposalIndex = 0
                            showStatusPill = false
                            activeTool = nil
                            
                            messages = messages.map { msg in
                                var copy = msg
                                copy.isAttachedToProposal = false
                                copy.isActionSummary = false
                                return copy
                            }
                        }
                        withAnimation(.easeInOut(duration: 0.25)) {
                            appSteps.removeAll()
                        }
                        state = .chat
                    }
                }
            }
        } catch {
            await MainActor.run {
                handleSendError(error: error, proposal: proposal)
            }
        }
    }
    
    /// Handle stream events (extracted for reuse)
    func handleStreamEvent(_ event: StreamEvent) async {
        await MainActor.run {
            switch event.type {
            case .proposal:
                if let tool = event.tool, let content = event.content?.value as? [String: Any] {
                    handleProposalEvent(event: event, tool: tool, content: content)
                }
                
            case .message:
                if let content = event.content?.value as? String {
                    messages.append(ChatMessage(role: .assistant, content: content))
                    isExecutingAction = false
                    
                    let previousAppId = proposal?.appId
                    let hasNext = advanceProposalQueue(previousAppId: previousAppId)
                    
                    if hasNext {
                        state = .processing
                        return
                    }
                    
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                        proposalQueue.removeAll()
                        currentProposalIndex = 0
                        showStatusPill = false  // Hide pill when operation completes
                        activeTool = nil
                        
                        // Clear proposal-related message flags
                        messages = messages.map { msg in
                            var copy = msg
                            copy.isAttachedToProposal = false
                            copy.isActionSummary = false
                            return copy
                        }
                    }
                    
                    let shouldShowSuccess = event.actionPerformed != nil || (!appSteps.isEmpty && proposalQueue.isEmpty)
                    
                    if shouldShowSuccess {
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
                    } else {
                        if proposalQueue.isEmpty {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                appSteps.removeAll()
                            }
                        }
                        state = .chat
                    }
                }
                
            default:
                break
            }
        }
    }
    
    /// Primary streaming logic for new user input
    func sendMessageToBackend(text: String) async {
        var didReceiveEvent = false
        do {
            let historyForRequest = messages.dropLast().map { msg in
                Message(role: msg.role == .user ? "user" : "assistant", content: msg.content)
            }
            
            let stream = await llmService.sendMessage(text: text, history: historyForRequest)
            
            for try await event in stream {
                didReceiveEvent = true
                switch event.type {
                case .earlySummary:
                    // Handle early summary from backend with fast typewriter effect
                    if let content = event.content?.value as? String,
                       let appId = event.appId {
                        let lowered = appId.lowercased()
                        // Skip pseudo action ids
                        if lowered.contains("action") { continue }
                        if !hasInsertedActionSummary {
                            hasInsertedActionSummary = true
                            isTypewriterActive = true
                            
                            // DON'T clear status - smoothly transition from "Thinking" to "Searching {app}"
                            // The StatusPillView will animate the text change
                            let formattedAppName = appId.capitalized
                            await MainActor.run {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    // Slide from "Thinking" to "Searching {app}" - pill stays visible
                                    currentStatus = .searching(appName: formattedAppName)
                                    showStatusPill = true  // Keep pill visible
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
                            }
                        }
                    }
                    
                case .thinking:
                     if let content = event.content?.value as? String {
                         await MainActor.run {
                             withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                 // Clean up content if needed
                                 let text = content.trimmingCharacters(in: .whitespacesAndNewlines)
                                 currentStatus = .thinking(text: text)
                                 showStatusPill = true  // Show pill when thinking starts
                             }
                         }
                     }
                    
                case .toolStatus:
                    if let toolName = event.tool, let status = event.status {
                        let lowerTool = toolName.lowercased()
                        if lowerTool.contains("action") { continue }
                        
                        let appName = formatAppName(from: toolName)
                        let appId = event.appId ?? appName.lowercased()
                        if appId.lowercased().contains("action") { continue }
                        
                        if !hasInsertedActionSummary && status == "searching" {
                            hasInsertedActionSummary = true
                            
                            await MainActor.run {
                                // DON'T clear status - smoothly transition from "Thinking" to "Searching {app}"
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    currentStatus = .searching(appName: appName)
                                    showStatusPill = true  // Ensure pill stays visible
                                    isThinking = false
                                }
                                
                                let summaryText = "I'll search \(appName) to help with your request."
                                messages.append(ChatMessage(role: .assistant, content: summaryText, isActionSummary: true))
                            }
                        }
                        
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
                                        // Keep other apps dim/waiting until their turn
                                        for idx in appSteps.indices where appSteps[idx].appId != appId && appSteps[idx].state != .done {
                                            appSteps[idx].state = .waiting
                                        }
                                        appSteps[index].state = .searching
                                        activeTool = ToolStatus(name: toolName, status: status)
                                        currentStatus = .searching(appName: appName)
                                        // Don't set showStatusPill = false, keep it visible
                                    case "done":
                                        appSteps[index].state = .waiting
                                        // Don't clear currentStatus - keep pill visible, just update state
                                        // Transition to thinking if we're waiting for next step
                                        if currentStatus == .searching(appName: appName) {
                                            currentStatus = .thinking(text: "Processing...")
                                        }
                                        activeTool = nil
                                    case "error":
                                        appSteps[index].state = .error
                                        // Don't clear currentStatus immediately
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
                        handleProposalEvent(event: event, tool: tool, content: content)
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
                        }
                        
                        // Progressive typewriter effect for assistant response
                        let trimmedContent = content.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                        let words = trimmedContent.split(separator: " ").map(String.init)
                        await typewriterDisplay(words: words, delay: 20_000_000)
                        
                        await MainActor.run {
                            messages.append(ChatMessage(role: .assistant, content: trimmedContent))
                            typewriterText = ""
                            
                            // Hide the pill when operation completes
                            withAnimation(.easeOut(duration: 0.35)) {
                                showStatusPill = false
                            }
                            
                            let shouldShowSuccess = event.actionPerformed != nil || (!appSteps.isEmpty && proposalQueue.isEmpty)
                            isExecutingAction = false
                            
                            if shouldShowSuccess {
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
                            } else {
                                if proposalQueue.isEmpty {
                                    withAnimation(.easeInOut(duration: 0.25)) {
                                        appSteps.removeAll()
                                    }
                                }
                                state = .chat
                            }
                        }
                    }
                }
            }
            
            // Fallback: if stream ends without yielding proposals/messages, clear waiting UI
            if !didReceiveEvent || (proposalQueue.isEmpty && proposal == nil) {
                await MainActor.run {
                    withAnimation(.easeOut(duration: 0.35)) {
                        showStatusPill = false  // Hide pill
                    }
                    activeTool = nil
                    isThinking = false
                    isExecutingAction = false
                    if !appSteps.isEmpty {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            for idx in appSteps.indices {
                                appSteps[idx].state = .done
                            }
                        }
                        withAnimation(.easeInOut(duration: 0.25)) {
                            appSteps.removeAll()
                        }
                    }
                    state = .chat
                }
            }
            
        } catch {
            await MainActor.run {
                handleSendError(error: error, proposal: proposal)
            }
        }
    }
    
    // MARK: - Proposal Helpers
    private func resolvedAppId(for tool: String, eventAppId: String?) -> String {
        return eventAppId ?? formatAppName(from: tool).lowercased()
    }
    
    private func normalizedArgsForSignature(_ args: [String: Any]) -> String {
        if JSONSerialization.isValidJSONObject(args),
           let data = try? JSONSerialization.data(withJSONObject: args, options: [.sortedKeys]),
           let string = String(data: data, encoding: .utf8) {
            return string
        }
        return "\(args)"
    }
    
    private func proposalSignature(tool: String, appId: String, args: [String: Any]) -> String {
        let argsString = normalizedArgsForSignature(args)
        return "\(tool.lowercased())|\(appId)|\(argsString)"
    }
    
    private func markAppStepAsError(appId: String) {
        if let idx = appSteps.firstIndex(where: { $0.appId == appId }) {
            appSteps[idx].state = .error
        }
    }
    
    @MainActor
    private func handleSendError(error: Error, proposal: ProposalData?) {
        let statusCode: Int?
        if case let LLMError.serverError(code) = error {
            statusCode = code
        } else {
            statusCode = nil
        }
        
        let currentAppId = proposal?.appId ?? appSteps.first(where: { $0.state == .active || $0.state == .searching })?.appId
        if let appId = currentAppId {
            markAppStepAsError(appId: appId)
        }
        
        self.proposal = nil
        proposalQueue.removeAll()
        currentProposalIndex = 0
        
        isThinking = false
        showStatusPill = false  // Hide pill on error
        isExecutingAction = false // Reset on error
        activeTool = nil
        if let code = statusCode, (code == 429 || code == 503) {
            errorMessage = "Service temporarily unavailable (status \(code)). Please try again."
        } else {
            errorMessage = error.localizedDescription
        }
        state = .chat // Fallback to chat on error so user can retry
    }
    
    @MainActor
    private func handleProposalEvent(event: StreamEvent, tool: String, content: [String: Any]) {
        let appId = resolvedAppId(for: tool, eventAppId: event.appId)
        let signature = proposalSignature(tool: tool, appId: appId, args: content)
        if seenProposalSignatures.contains(signature) {
            return
        }
        seenProposalSignatures.insert(signature)
        var queuedSignatures: Set<String> = [signature]
        
        let previousAppId = proposal?.appId
        
        // Flag messages from current interaction as attached to proposal
        messages = messages.map { msg in
            var copy = msg
            if (msg.role == .user && !msg.isHidden) || msg.isActionSummary {
                copy.isAttachedToProposal = true
            }
            return copy
        }
        
        var proposalData = ProposalData(tool: tool, args: content)
        proposalData.summaryText = event.summaryText
        proposalData.appId = appId
        proposalData.proposalIndex = event.proposalIndex ?? 0
        proposalData.totalProposals = event.totalProposals ?? 1
        
        // Build proposal queue with dedupe
        var nextQueue: [ProposalData] = [proposalData]
        if let remaining = event.remainingProposals {
            for rp in remaining {
                guard let rpTool = rp["tool"]?.value as? String else { continue }
                let rpAppId = rp["app_id"]?.value as? String ?? resolvedAppId(for: rpTool, eventAppId: nil)
                let rpArgs = rp["args"]?.value as? [String: Any] ?? [:]
                let rpSignature = proposalSignature(tool: rpTool, appId: rpAppId, args: rpArgs)
                guard !queuedSignatures.contains(rpSignature) else { continue }
                queuedSignatures.insert(rpSignature)
                
                var rpData = ProposalData(tool: rpTool, args: rpArgs)
                rpData.appId = rpAppId
                rpData.proposalIndex = nextQueue.count
                rpData.totalProposals = event.totalProposals ?? 1
                nextQueue.append(rpData)
            }
        }
        
        startProposalQueue(nextQueue, previousAppId: previousAppId)
        
        if let appIdValue = proposalData.appId {
            currentStatus = .searching(appName: appIdValue.capitalized)
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
