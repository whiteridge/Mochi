import SwiftUI
import Combine
import OSLog

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
                    animation: animation
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
                messages: viewModel.messages,
                currentStatus: viewModel.currentStatus,
                proposal: viewModel.proposal,
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
                    ((NSScreen.main?.visibleFrame.height ?? 1000) * 0.92) - inputContentHeight
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
                SuccessPillView()
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
                        Color.black.opacity(0.2) // Darken the glass
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
            }
        }
    }

    func startRecording() {
        Task {
            do {
                try await voiceRecorder.startRecording()
                await MainActor.run {
                    viewModel.errorMessage = nil
                    viewID += 1
                    if viewModel.state != .chat {
                        viewModel.state = .recording
                    }
                }
            } catch {
                await MainActor.run {
                    viewModel.errorMessage = error.localizedDescription
                }
            }
        }
    }

    func stopRecording() {
        viewModel.errorMessage = nil

        Task {
            do {
                await MainActor.run {
                    viewModel.state = .chat
                    viewModel.currentStatus = .transcribing
                }
                
                let audioURL = try await voiceRecorder.stopRecording()
                let transcript = try await transcriptionService.transcribeFile(at: audioURL)
                
                await MainActor.run {
                    viewModel.errorMessage = nil
                    // currentStatus will be updated to .thinking in processInput
                    viewModel.processInput(text: transcript)
                }
            } catch {
                logger.error("Recording/Transcription failed: \(error.localizedDescription, privacy: .public)")
                await MainActor.run {
                    viewModel.errorMessage = error.localizedDescription
                    viewModel.currentStatus = nil
                    viewModel.state = .idle
                }
            }
        }
    }

    func sendManualMessage() {
        viewModel.processInput(text: viewModel.userInput)
    }

    func resetConversation(animate: Bool = true) {
        viewModel.reset()
    }
}
