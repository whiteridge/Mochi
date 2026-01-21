import SwiftUI
import Combine
import OSLog
import Foundation

// #region agent log
private func debugLog(hypothesisId: String, location: String, message: String, data: [String: String] = [:]) {
    let logPath = "/Users/matteofari/Desktop/projects/caddyAI/.cursor/debug.log"
    let timestamp = Int(Date().timeIntervalSince1970 * 1000)
    let dataJson = data.isEmpty ? "{}" : "{\(data.map { "\"\($0.key)\":\"\($0.value)\"" }.joined(separator: ","))}"
    let logEntry = "{\"hypothesisId\":\"\(hypothesisId)\",\"location\":\"\(location)\",\"message\":\"\(message)\",\"data\":\(dataJson),\"timestamp\":\(timestamp)}\n"
    if let handle = FileHandle(forWritingAtPath: logPath) {
        handle.seekToEndOfFile()
        handle.write(logEntry.data(using: .utf8)!)
        handle.closeFile()
    } else {
        FileManager.default.createFile(atPath: logPath, contents: logEntry.data(using: .utf8), attributes: nil)
    }
}
// #endregion

struct ConfirmButtonFrameKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

struct VoiceChatBubble: View {
    @EnvironmentObject private var preferences: PreferencesStore
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var viewModel = AgentViewModel()
    
    @Namespace private var animation
    @Namespace private var rotatingLightNamespace

    @StateObject private var voiceRecorder = VoiceRecorder()
    @State private var dragOffset: CGSize = .zero
    @GestureState private var dragTranslation: CGSize = .zero
    private let transcriptionService = ParakeetTranscriptionService()
    private let logger = Logger(subsystem: "com.matteofari.caddyAI", category: "VoiceChatBubble")

    private var palette: LiquidGlassPalette {
        LiquidGlassPalette(colorScheme: colorScheme, glassStyle: preferences.glassStyle)
    }

    private var errorBubbleShadowColor: Color {
        colorScheme == .dark ? Color.black.opacity(0.55) : Color.black.opacity(0.28)
    }

    private var errorBubbleShadowRadius: CGFloat {
        colorScheme == .dark ? 10 : 12
    }

    private var errorBubbleShadowY: CGFloat {
        colorScheme == .dark ? 6 : 8
    }

    var body: some View {
        mainContent
    }
    
    @ViewBuilder
    private var mainContent: some View {
        ZStack(alignment: .bottom) {
            // Root-level rotating light background that morphs based on state
            rotatingLightBackgroundLayer
            
            // Content layers - use UnifiedPillView for recording/thinking/searching
            contentLayer
                .overlay(alignment: .bottom) {
                    if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(Color(nsColor: .systemPink))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                GlassBackground(cornerRadius: 12, prominence: .subtle, shadowed: false)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(palette.subtleBorder.opacity(0.35), lineWidth: 0.45)
                            )
                            .shadow(color: errorBubbleShadowColor, radius: errorBubbleShadowRadius, x: 0, y: errorBubbleShadowY)
                            .padding(.bottom, -20)
                            .multilineTextAlignment(.center)
                    }
                }
                .offset(currentDragOffset)
                .simultaneousGesture(dragGesture)
        }
        .padding(.bottom, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .background(Color.clear)
        .onReceive(NotificationCenter.default.publisher(for: .voiceChatShouldStartRecording)) { _ in
            beginHotkeySession()
        }
        .onReceive(NotificationCenter.default.publisher(for: .voiceChatShouldStopSession)) { _ in
            cancelVoiceSession()
        }
        // Hold-to-talk: key pressed - start recording
        .onReceive(NotificationCenter.default.publisher(for: .voiceKeyDidPress)) { _ in
            handleHoldToTalkKeyPress()
        }
        // Hold-to-talk: key released - stop recording and process
        .onReceive(NotificationCenter.default.publisher(for: .voiceKeyDidRelease)) { _ in
            handleHoldToTalkKeyRelease()
        }
        // Toggle mode: toggle recording state
        .onReceive(NotificationCenter.default.publisher(for: .voiceToggleRequested)) { _ in
            handleToggleRequest()
        }
        // ESC key pressed - close panel
        .onReceive(NotificationCenter.default.publisher(for: .escapeKeyPressed)) { _ in
            handleEscapeKey()
        }
        .onChange(of: viewModel.state) { _, _ in
            NotificationCenter.default.post(name: .voiceChatLayoutNeedsUpdate, object: nil)
        }
        .onKeyPress(.return) {
            handleEnterKey()
            return .handled
        }
        .onKeyPress(.escape) {
            handleEscapeKey()
            return .handled
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.8, blendDuration: 0), value: viewModel.state)
        .animation(.spring(response: 0.5, dampingFraction: 0.8, blendDuration: 0), value: viewModel.isExecutingAction)
    }
    
    @ViewBuilder
    private var rotatingLightBackgroundLayer: some View {
        // The rotating light is rendered in different places:
        // - confirmation card: rendered by ConfirmationCardView button
        // - success state: rendered in SuccessPill
        // So this layer is empty - the rotating light is handled by the content views
        EmptyView()
    }

    @ViewBuilder
    private var contentLayer: some View {
        if let pillMode = unifiedPillMode {
            UnifiedPillView(
                mode: pillMode,
                morphNamespace: animation,
                stopRecording: stopRecording,
                cancelRecording: cancelVoiceSession
            )
            .transition(.scale(scale: 1))
        } else if viewModel.state == .idle {
            EmptyView()
        } else {
            compactFlowContent
        }
    }

    private var currentDragOffset: CGSize {
        CGSize(
            width: dragOffset.width + dragTranslation.width,
            height: dragOffset.height + dragTranslation.height
        )
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 1)
            .updating($dragTranslation) { value, state, _ in
                state = value.translation
            }
            .onEnded { value in
                dragOffset.width += value.translation.width
                dragOffset.height += value.translation.height
            }
    }
    
    // MARK: - Unified Pill Mode
    
    /// Computes the unified pill mode for recording/thinking/searching states.
    /// Returns nil when not in a pill-displayable state.
    private var unifiedPillMode: UnifiedPillMode? {
        switch viewModel.state {
        case .recording:
            return .recording(amplitude: voiceRecorder.normalizedAmplitude)
        case .processing, .chat:
            // Only show unified pill when status pill should be visible (no proposal active)
            guard viewModel.showStatusPill, viewModel.proposal == nil else { return nil }
            if let status = viewModel.currentStatus {
                switch status {
                case .thinking: return .thinking
                case .searching(let app): return .searching(app: app)
                }
            }
            return .thinking
        default:
            return nil
        }
    }
}

// MARK: - Content Builders

fileprivate extension VoiceChatBubble {
    @ViewBuilder
    var compactFlowContent: some View {
        if viewModel.state == .success {
            SuccessPillView(
                gradientNamespace: rotatingLightNamespace,
                morphNamespace: animation
            )
        } else if viewModel.state == .cancelled {
            CancelledPillView(
                gradientNamespace: rotatingLightNamespace,
                morphNamespace: animation
            )
        } else if let proposal = viewModel.proposal {
            ConfirmationCardView(
                proposal: proposal,
                onConfirm: { viewModel.confirmProposal() },
                onCancel: { viewModel.cancelProposal() },
                rotatingLightNamespace: rotatingLightNamespace,
                morphNamespace: animation,
                isExecuting: viewModel.isExecutingAction,
                isFinalAction: viewModel.proposalQueue.count <= 1,
                appSteps: viewModel.appSteps,
                activeAppId: activeAppIdForHeader
            )
        } else if let message = latestAssistantMessageText {
            AssistantMessageBubbleView(text: message, morphNamespace: animation)
                .transition(.opacity)
        } else {
            EmptyView()
        }
    }
    
    private var resolvedStatusPill: StatusPillView.Status {
        if let status = viewModel.currentStatus {
            switch status {
            case .thinking:
                return .thinking
            case .searching(let app):
                return .searching(app: app)
            }
        }
        
        if let activeStep = viewModel.appSteps.first(where: { $0.state == .searching || $0.state == .active }) {
            return .searching(app: activeStep.appId.capitalized)
        }
        
        return .thinking
    }
    
    private var latestAssistantMessageText: String? {
        let typewriterText = viewModel.typewriterText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !typewriterText.isEmpty {
            return typewriterText
        }
        
        guard let message = viewModel.messages.last(where: { message in
            message.role == .assistant && !message.isHidden && !message.isActionSummary
        }) else {
            return nil
        }
        
        let trimmedMessage = message.content.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedMessage.isEmpty ? nil : trimmedMessage
    }
    
    private var activeAppIdForHeader: String? {
        if let activeAppId = viewModel.proposal?.appId {
            return activeAppId
        }
        return viewModel.appSteps.first(where: { $0.state == .active || $0.state == .searching })?.appId
    }
    
}

private struct AssistantMessageBubbleView: View {
    let text: String
    let morphNamespace: Namespace.ID
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var preferences: PreferencesStore
    
    private var palette: LiquidGlassPalette {
        LiquidGlassPalette(colorScheme: colorScheme, glassStyle: preferences.glassStyle)
    }
    
    private var maxMessageWidth: CGFloat {
        text.count > 220 ? 620 : 460
    }

    private var usesRoundedRect: Bool {
        text.count > 220
    }

    private var usesIntrinsicWidth: Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.count <= 60 && !trimmed.contains("\n")
    }

    private var messageCornerRadius: CGFloat {
        usesRoundedRect ? 18 : 999
    }

    private var paneFill: Color {
        GlassBackdropStyle.paneFill(for: preferences.glassStyle, colorScheme: colorScheme)
    }

    private var messageShadowColor: Color {
        colorScheme == .dark ? Color.black.opacity(0.5) : Color.black.opacity(0.28)
    }

    private var messageShadowRadius: CGFloat {
        colorScheme == .dark ? 10 : 14
    }

    private var messageShadowY: CGFloat {
        colorScheme == .dark ? 5 : 9
    }

    @ViewBuilder
    private var messageContent: some View {
        let baseText = Text(text)
            .font(.system(size: 15, weight: .regular))
            .foregroundStyle(palette.primaryText)
            .multilineTextAlignment(.leading)

        if usesIntrinsicWidth {
            baseText
                .fixedSize(horizontal: true, vertical: true)
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
        } else {
            baseText
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: maxMessageWidth, alignment: .leading)
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
        }
    }
    
    var body: some View {
        if #available(macOS 26.0, iOS 26.0, *) {
            if usesRoundedRect {
                Group {
                    messageContent
                        .background(AnyShapeStyle(paneFill), in: .rect(cornerRadius: messageCornerRadius))
                        .glassEffect(.clear, in: .rect(cornerRadius: messageCornerRadius))
                        .overlay(
                            GlassCloudOverlay(
                                RoundedRectangle(cornerRadius: messageCornerRadius, style: .continuous),
                                isEnabled: preferences.glassStyle == .regular
                            )
                        )
                }
                .matchedGeometryEffect(id: "background", in: morphNamespace)
                .shadow(color: messageShadowColor, radius: messageShadowRadius, x: 0, y: messageShadowY)
            } else {
                Group {
                    messageContent
                        .background(AnyShapeStyle(paneFill), in: .capsule)
                        .glassEffect(.clear, in: .capsule)
                        .overlay(GlassCloudOverlay(Capsule(), isEnabled: preferences.glassStyle == .regular))
                }
                .matchedGeometryEffect(id: "background", in: morphNamespace)
                .shadow(color: messageShadowColor, radius: messageShadowRadius, x: 0, y: messageShadowY)
            }
        } else {
            messageContent
                .background(
                    GlassBackground(cornerRadius: messageCornerRadius, prominence: .subtle, shadowed: false)
                        .matchedGeometryEffect(id: "background", in: morphNamespace)
                )
                .shadow(color: messageShadowColor, radius: messageShadowRadius, x: 0, y: messageShadowY)
        }
    }
}

// MARK: - Actions

@MainActor
private extension VoiceChatBubble {
    func handleEnterKey() {
        switch viewModel.state {
        case .recording:
            logger.debug("Enter pressed: Stopping recording")
            stopRecording()
        case .chat, .processing, .success, .cancelled:
            break
        case .idle:
            logger.debug("Enter pressed in idle state: Ignoring")
        }
    }
    
    func handleEscapeKey() {
        // Always cancel any pending recording to ensure clean state
        // This prevents voiceRecorder.isRecording from blocking future recordings
        if voiceRecorder.isRecording {
            voiceRecorder.cancelRecording()
        }
        
        switch viewModel.state {
        case .recording:
            // Cancel recording and close
            logger.debug("Escape pressed: Cancelling recording")
            viewModel.state = .idle
            resetConversation(animate: false)
            NotificationCenter.default.post(name: .voiceChatShouldDismissPanel, object: nil)
        case .chat, .processing, .success, .cancelled:
            // Close the panel
            logger.debug("Escape pressed: Closing panel")
            viewModel.reset()
            viewModel.state = .idle
            NotificationCenter.default.post(name: .voiceChatShouldDismissPanel, object: nil)
        case .idle:
            // Already idle, just make sure panel is dismissed
            NotificationCenter.default.post(name: .voiceChatShouldDismissPanel, object: nil)
        }
    }
    
    func beginHotkeySession() {
        guard viewModel.state != .recording && viewModel.state != .processing else { return }
        if viewModel.state == .idle || viewModel.state == .success || viewModel.state == .cancelled {
            resetConversation(animate: false)
        }
        startRecording()
    }

    func cancelVoiceSession() {
        // Guard: Only cancel if we're actually recording
        guard viewModel.state == .recording || voiceRecorder.isRecording else {
            // Already cancelled or not recording - do nothing to prevent loop
            return
        }
        
        print("VoiceChatBubble: cancelVoiceSession called")
        
        // Cancel the recording (stops recorder, deletes temp file, sets wasCancelled = true)
        voiceRecorder.cancelRecording()
        
        // Reset state
        viewModel.state = .idle
        resetConversation(animate: false)
        
        // Dismiss the panel
        NotificationCenter.default.post(name: .voiceChatShouldDismissPanel, object: nil)
    }
    
    // MARK: - Hold-to-Talk Handlers
    
    func handleHoldToTalkKeyPress() {
        logger.debug("Hold-to-talk: Key pressed")
        // Allow recording if not currently recording (idle, success, cancelled, OR chat states)
        // Block only if already recording or processing
        guard viewModel.state != .recording && viewModel.state != .processing && !voiceRecorder.isRecording else {
            logger.debug("Hold-to-talk: Ignoring press, recording or processing (state: \(String(describing: viewModel.state)))")
            return
        }
        if viewModel.state == .idle || viewModel.state == .success || viewModel.state == .cancelled {
            resetConversation(animate: false)
        }
        startRecording()
    }
    
    func handleHoldToTalkKeyRelease() {
        logger.debug("Hold-to-talk: Key released")
        // Only stop if we're actually recording
        guard viewModel.state == .recording && voiceRecorder.isRecording else {
            logger.debug("Hold-to-talk: Ignoring release, not recording (state: \(String(describing: viewModel.state)), isRecording: \(voiceRecorder.isRecording))")
            return
        }
        stopRecording()
    }
    
    // MARK: - Toggle Mode Handler
    
    func handleToggleRequest() {
        logger.debug("Toggle: Requested")
        // #region agent log
        debugLog(hypothesisId: "A", location: "VoiceChatBubble.handleToggleRequest", message: "toggle_request_entry", data: ["viewModelState": "\(viewModel.state)", "isRecording": "\(voiceRecorder.isRecording)"])
        // #endregion
        if viewModel.state == .recording || voiceRecorder.isRecording {
            // Currently recording - stop
            // #region agent log
            debugLog(hypothesisId: "A", location: "VoiceChatBubble.handleToggleRequest", message: "stopping_recording", data: ["reason": "state_is_recording_or_voiceRecorder_isRecording"])
            // #endregion
            stopRecording()
        } else if viewModel.state == .idle || viewModel.state == .success || viewModel.state == .cancelled || viewModel.state == .chat {
            // Not recording - start
            // #region agent log
            debugLog(hypothesisId: "A", location: "VoiceChatBubble.handleToggleRequest", message: "starting_recording", data: ["reason": "state_is_idle_or_success_or_cancelled_or_chat"])
            // #endregion
            if viewModel.state == .idle || viewModel.state == .success || viewModel.state == .cancelled {
                resetConversation(animate: false)
            }
            startRecording()
        } else {
            // #region agent log
            debugLog(hypothesisId: "A", location: "VoiceChatBubble.handleToggleRequest", message: "toggle_ignored", data: ["reason": "state_is_processing", "currentState": "\(viewModel.state)"])
            // #endregion
        }
        // If in processing state, ignore toggle
    }

    func startRecording() {
        // #region agent log
        debugLog(hypothesisId: "D", location: "VoiceChatBubble.startRecording", message: "start_recording_called", data: ["currentState": "\(viewModel.state)", "isRecording": "\(voiceRecorder.isRecording)"])
        // #endregion
        
        // IMMEDIATELY set state to recording to prevent duplicate calls
        // This runs synchronously before any async work
        guard viewModel.state != .recording else {
            // #region agent log
            debugLog(hypothesisId: "D", location: "VoiceChatBubble.startRecording", message: "already_recording_state_guard", data: ["currentState": "\(viewModel.state)"])
            // #endregion
            return
        }
        viewModel.state = .recording
        
        Task {
            do {
                try await voiceRecorder.startRecording()
                await MainActor.run {
                    viewModel.errorMessage = nil
                    // #region agent log
                    debugLog(hypothesisId: "D", location: "VoiceChatBubble.startRecording", message: "recorder_started_success", data: ["currentState": "\(viewModel.state)"])
                    // #endregion
                }
            } catch {
                // #region agent log
                debugLog(hypothesisId: "D", location: "VoiceChatBubble.startRecording", message: "start_recording_error", data: ["error": "\(error.localizedDescription)"])
                // #endregion
                await MainActor.run {
                    viewModel.errorMessage = error.localizedDescription
                    // Reset state on failure
                    viewModel.state = .idle
                }
            }
        }
    }

    func stopRecording() {
        // #region agent log
        debugLog(hypothesisId: "E", location: "VoiceChatBubble.stopRecording", message: "stop_recording_called", data: ["currentState": "\(viewModel.state)", "isRecording": "\(voiceRecorder.isRecording)"])
        // #endregion
        
        // Guard: Only stop if we're actually in recording state AND recorder is active
        guard viewModel.state == .recording || voiceRecorder.isRecording else {
            logger.debug("stopRecording: Ignoring, not in recording state")
            return
        }
        
        // Move immediately into a compact thinking/searching pill
        viewModel.state = .processing
        viewModel.errorMessage = nil
        viewModel.isThinking = true
        viewModel.currentStatus = .thinking()
        viewModel.showStatusPill = true
        
        // Track start time to ensure minimum display duration for the processing pill
        let processingStartTime = Date()
        let minimumDisplayDuration: TimeInterval = 0.5 // 500ms minimum

        Task {
            do {
                await MainActor.run {
                    // #region agent log
                    debugLog(hypothesisId: "E", location: "VoiceChatBubble.stopRecording", message: "processing_recording", data: ["currentState": "\(viewModel.state)"])
                    // #endregion
                }
                
                let audioURL = try await voiceRecorder.stopRecording()
                
                // Check if session was cancelled while we were stopping
                if voiceRecorder.wasCancelled {
                    print("VoiceChatBubble: Session was cancelled, aborting transcription")
                    await MainActor.run {
                        viewModel.currentStatus = nil
                        viewModel.showStatusPill = false
                        viewModel.isThinking = false
                        viewModel.state = .idle
                        NotificationCenter.default.post(name: .voiceChatShouldDismissPanel, object: nil)
                    }
                    return
                }
                
                // #region agent log
                debugLog(hypothesisId: "E", location: "VoiceChatBubble.stopRecording", message: "recording_stopped_got_url", data: ["url": "\(audioURL.lastPathComponent)"])
                // #endregion
                let transcript = try await transcriptionService.transcribeFile(at: audioURL)
                
                // Check again after transcription (could have been cancelled during transcription)
                if voiceRecorder.wasCancelled {
                    print("VoiceChatBubble: Session was cancelled after transcription, discarding result")
                    await MainActor.run {
                        viewModel.currentStatus = nil
                        viewModel.showStatusPill = false
                        viewModel.isThinking = false
                        viewModel.state = .idle
                        NotificationCenter.default.post(name: .voiceChatShouldDismissPanel, object: nil)
                    }
                    return
                }
                
                // Ensure minimum display time for the processing pill
                let elapsed = Date().timeIntervalSince(processingStartTime)
                if elapsed < minimumDisplayDuration {
                    let remainingTime = minimumDisplayDuration - elapsed
                    try? await Task.sleep(nanoseconds: UInt64(remainingTime * 1_000_000_000))
                }
                
                // Check if transcript is empty - if so, close without showing chat
                let trimmedTranscript = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmedTranscript.isEmpty {
                    print("VoiceChatBubble: Transcription is empty, closing panel")
                    await MainActor.run {
                        viewModel.currentStatus = nil
                        viewModel.showStatusPill = false
                        viewModel.isThinking = false
                        viewModel.state = .idle
                        NotificationCenter.default.post(name: .voiceChatShouldDismissPanel, object: nil)
                    }
                    return
                }
                
                await MainActor.run {
                    viewModel.errorMessage = nil
                    viewModel.processInputWithThinking(text: transcript)
                }
            } catch {
                logger.error("Recording/Transcription failed: \(error.localizedDescription, privacy: .public)")
                // #region agent log
                debugLog(hypothesisId: "E", location: "VoiceChatBubble.stopRecording", message: "recording_or_transcription_failed", data: ["error": "\(error.localizedDescription)"])
                // #endregion
                
                // Ensure minimum display time even on error
                let elapsed = Date().timeIntervalSince(processingStartTime)
                if elapsed < minimumDisplayDuration {
                    let remainingTime = minimumDisplayDuration - elapsed
                    try? await Task.sleep(nanoseconds: UInt64(remainingTime * 1_000_000_000))
                }
                
                // On error, just dismiss the panel - don't show chat
                await MainActor.run {
                    // #region agent log
                    debugLog(hypothesisId: "E", location: "VoiceChatBubble.stopRecording", message: "dismissing_panel_after_error", data: ["error": "\(error.localizedDescription)"])
                    // #endregion
                    viewModel.currentStatus = nil
                    viewModel.showStatusPill = false
                    viewModel.isThinking = false
                    viewModel.state = .idle
                    NotificationCenter.default.post(name: .voiceChatShouldDismissPanel, object: nil)
                }
            }
        }
    }

    func resetConversation(animate: Bool = true) {
        viewModel.reset()
    }
}
