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
    @StateObject private var viewModel = AgentViewModel()
    @State private var viewID = 0
    
    @Namespace private var animation
    @Namespace private var rotatingLightNamespace

    @StateObject private var voiceRecorder = VoiceRecorder()
    @State private var scrollContentHeight: CGFloat = 100
    @State private var inputContentHeight: CGFloat = 0
    private let transcriptionService = ParakeetTranscriptionService()
    private let logger = Logger(subsystem: "com.matteofari.caddyAI", category: "VoiceChatBubble")

    var body: some View {
        ZStack(alignment: .bottom) {
            // Root-level rotating light background that morphs based on state
            rotatingLightBackgroundLayer
            
            // Content layers
            switch viewModel.state {
            case .recording:
                RecordingBubbleView(
                    stopRecording: stopRecording,
                    cancelRecording: cancelVoiceSession,
                    animation: animation,
                    amplitude: voiceRecorder.normalizedAmplitude
                )
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    GlassBackground(cornerRadius: 30)
                        .matchedGeometryEffect(id: "background", in: animation)
                )
                .transition(.scale(scale: 1))
                    
            case .idle:
                EmptyView()
                
            case .chat, .processing, .success:
                // === CHAT & SUCCESS STATE ===
                chatAndSuccessWrapper
            }
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
        .onChange(of: viewModel.state) { _, _ in
            NotificationCenter.default.post(name: .voiceChatLayoutNeedsUpdate, object: nil)
        }
        .onKeyPress(.return) {
            handleEnterKey()
            return .handled
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.8, blendDuration: 0), value: viewModel.state)
        .animation(.spring(response: 0.5, dampingFraction: 0.8, blendDuration: 0), value: viewModel.isExecutingAction)
        // Error overlay
        .overlay(alignment: .bottom) {
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.pink)
                    .padding(.horizontal, 12)
                    .padding(.bottom, -20)
                    .multilineTextAlignment(.center)
            }
        }
    }
    
    @ViewBuilder
    private var rotatingLightBackgroundLayer: some View {
        // The rotating light is rendered in different places:
        // - chat state with proposal: rendered by ConfirmationCardView button
        // - processing state with isExecutingAction: rendered in expandedChatContent overlay
        // - success state: rendered in SuccessPill
        // So this layer is empty - the rotating light is handled by the content views
        EmptyView()
    }
}

// MARK: - Content Builders

fileprivate extension VoiceChatBubble {
    
    var expandedChatContent: some View {
        VStack(spacing: 0) {
            // 1. CHAT HISTORY (Flexible)
            ChatHistoryView(
                viewModel: viewModel,
                messages: viewModel.messages,
                currentStatus: viewModel.currentStatus,
                proposal: viewModel.proposal,
                typewriterText: viewModel.typewriterText,
                isProcessing: viewModel.state == .processing,
                onConfirmProposal: { viewModel.confirmProposal() },
                onCancelProposal: { viewModel.cancelProposal() },
                rotatingLightNamespace: rotatingLightNamespace,
                animation: animation
            )
            .onPreferenceChange(ViewHeightKey.self) { height in
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    scrollContentHeight = height
                }
            }
            .frame(
                height: min(
                    max(scrollContentHeight, 0),
                    ((NSScreen.main?.visibleFrame.height ?? 1000) * 0.66) - inputContentHeight
                )
            )
            .layoutPriority(1)
            
            // 2. INPUT BAR
            ChatInputSection(
                text: $viewModel.userInput,
                isRecording: voiceRecorder.isRecording,
                startRecording: startRecording,
                stopRecording: stopRecording,
                sendAction: sendManualMessage,
                animation: animation
            )
            .onPreferenceChange(InputViewHeightKey.self) { height in
                inputContentHeight = height
            }
        }
    }

    @ViewBuilder
    var chatAndSuccessWrapper: some View {
        let isSuccess = viewModel.state == .success
        
        VStack(spacing: 0) {
            if isSuccess {
                SuccessPillView(gradientNamespace: rotatingLightNamespace)
                    .transition(.opacity.combined(with: .scale(scale: 0.8)))
            } else {
                expandedChatContent
                    .transition(.opacity)
            }
        }
        // Animate the frame width: 650 for chat, intrinsic for pill
        .frame(width: isSuccess ? nil : 650)
        .background(
            ZStack {
                // Glass background (fade out in success to emphasize the light, or keep it?)
                // The original SuccessPill didn't have glass, so let's fade it out.
                // Glass background
                if isSuccess {
                    // Success state: Darker glass pill
                    GlassBackground(cornerRadius: 50)
                        .transition(.opacity)
                } else {
                    // Chat state: Dark glass window
                    ZStack {
                        VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                        Color.black.opacity(0.7) // Darken the glass
                    }
                    .transition(.opacity)
                }
                
                // Rotating Light
                // In Chat: visible only if processing & executing.
                // In Success: always visible.
                if (viewModel.isExecutingAction && viewModel.state == .processing) || isSuccess {
                    RotatingLightBackground(
                        cornerRadius: isSuccess ? 50 : 24,
                        shape: isSuccess ? .capsule : .roundedRect,
                        rotationSpeed: isSuccess ? 0.8 : 10.0
                    )
                    // We don't need matchedGeometryEffect here because it's the same view instance (conditionally present)
                    // But to ensure smooth transition from "processing" to "success", we want it to be the SAME view.
                    // The condition `(processing) || isSuccess` ensures it stays alive during the switch.
                    .opacity(isSuccess ? 1.0 : 0.6)
                }
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: isSuccess ? 50 : 24, style: .continuous))
        // Animate layout changes
        .animation(.spring(response: 0.5, dampingFraction: 0.8, blendDuration: 0), value: isSuccess)
        .animation(.easeOut(duration: 0.3), value: viewModel.isExecutingAction)
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
        case .chat, .processing:
            logger.debug("Enter pressed: Sending message")
            sendManualMessage()
        case .success:
            break
        case .idle:
            logger.debug("Enter pressed in idle state: Ignoring")
        }
    }
    
    func beginHotkeySession() {
        guard viewModel.state != .recording else { return }
        resetConversation(animate: false)
        startRecording()
    }

    func cancelVoiceSession() {
        Task {
             _ = try? await voiceRecorder.stopRecording()
            await MainActor.run {
                resetConversation(animate: false)
                // Dismiss the panel
                NotificationCenter.default.post(name: .voiceChatShouldDismissPanel, object: nil)
            }
        }
    }
    
    // MARK: - Hold-to-Talk Handlers
    
    func handleHoldToTalkKeyPress() {
        logger.debug("Hold-to-talk: Key pressed")
        // If already recording or in chat, don't restart
        guard viewModel.state == .idle || viewModel.state == .success else {
            logger.debug("Hold-to-talk: Ignoring press, current state: \(String(describing: viewModel.state))")
            return
        }
        resetConversation(animate: false)
        startRecording()
    }
    
    func handleHoldToTalkKeyRelease() {
        logger.debug("Hold-to-talk: Key released")
        // Only stop if we're actually recording
        guard viewModel.state == .recording || voiceRecorder.isRecording else {
            logger.debug("Hold-to-talk: Ignoring release, not recording")
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
        } else if viewModel.state == .idle || viewModel.state == .success {
            // Not recording - start
            // #region agent log
            debugLog(hypothesisId: "A", location: "VoiceChatBubble.handleToggleRequest", message: "starting_recording", data: ["reason": "state_is_idle_or_success"])
            // #endregion
            resetConversation(animate: false)
            startRecording()
        } else {
            // #region agent log
            debugLog(hypothesisId: "A", location: "VoiceChatBubble.handleToggleRequest", message: "toggle_ignored", data: ["reason": "state_is_chat_or_processing", "currentState": "\(viewModel.state)"])
            // #endregion
        }
        // If in chat/processing state, ignore toggle
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
        viewID += 1
        
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
        viewModel.errorMessage = nil

        Task {
            do {
                await MainActor.run {
                    // #region agent log
                    debugLog(hypothesisId: "E", location: "VoiceChatBubble.stopRecording", message: "setting_state_to_chat", data: ["previousState": "\(viewModel.state)"])
                    // #endregion
                    viewModel.state = .chat
                    // Don't show any status pill - it will appear when tools are invoked
                    viewModel.showStatusPill = false
                }
                
                let audioURL = try await voiceRecorder.stopRecording()
                // #region agent log
                debugLog(hypothesisId: "E", location: "VoiceChatBubble.stopRecording", message: "recording_stopped_got_url", data: ["url": "\(audioURL.lastPathComponent)"])
                // #endregion
                let transcript = try await transcriptionService.transcribeFile(at: audioURL)
                
                await MainActor.run {
                    viewModel.errorMessage = nil
                    viewModel.processInputWithThinking(text: transcript)
                }
            } catch {
                logger.error("Recording/Transcription failed: \(error.localizedDescription, privacy: .public)")
                // #region agent log
                debugLog(hypothesisId: "E", location: "VoiceChatBubble.stopRecording", message: "recording_or_transcription_failed", data: ["error": "\(error.localizedDescription)"])
                // #endregion
                await MainActor.run {
                    viewModel.errorMessage = error.localizedDescription
                    viewModel.showStatusPill = false
                    // #region agent log
                    debugLog(hypothesisId: "E", location: "VoiceChatBubble.stopRecording", message: "setting_state_to_idle_after_error", data: ["previousState": "\(viewModel.state)"])
                    // #endregion
                    viewModel.state = .idle
                }
            }
        }
    }

    func sendManualMessage() {
        viewModel.processInputWithThinking(text: viewModel.userInput)
    }

    func resetConversation(animate: Bool = true) {
        viewModel.reset()
    }
}
