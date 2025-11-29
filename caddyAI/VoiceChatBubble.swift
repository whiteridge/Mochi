import SwiftUI
import Combine
import OSLog

struct ViewHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

struct InputViewHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

struct ConfirmButtonFrameKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

struct VoiceChatBubble: View {
        @StateObject private var viewModel = AgentViewModel()
    @State private var viewID = 0
    // Height state is no longer manually calculated for the frame, but we use GeometryReader in the new layout
    
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
                recordingBubbleContent
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
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 16) {
                        Spacer(minLength: 0)
                        
                        if viewModel.messages.isEmpty {
                            Text("How can I help?")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundStyle(.white.opacity(0.6))
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.top, 40)
                        } else {
                            ForEach(viewModel.messages.filter { !$0.isHidden }) { message in
                                ChatBubbleRow(message: message)
                                    .id(message.id)
                            }
                        }
                        
                        if viewModel.isTranscribing {
                            processingIndicator(text: "Transcribing...")
                                .id("transcribing")
                        } else if viewModel.isThinking {
                            processingIndicator(text: "Thinking...")
                                .id("thinking")
                        }
                        
                        if let tool = viewModel.activeTool {
                            ToolStatusView(tool: tool)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 8)
                                .transition(.opacity)
                        }
                        
                        if let proposal = viewModel.proposal {
                            ConfirmationCardView(
                                proposal: proposal,
                                onConfirm: { viewModel.confirmProposal() },
                                onCancel: { viewModel.cancelProposal() },
                                rotatingLightNamespace: rotatingLightNamespace
                            )
                            .padding(.top, 16)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                        
                        Color.clear.frame(height: 10).id("bottomAnchor")
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 24)
                    .padding(.bottom, 20)
                    .background(
                        GeometryReader { geo in
                            Color.clear.preference(key: ViewHeightKey.self, value: geo.size.height)
                        }
                    )
                }
                .onPreferenceChange(ViewHeightKey.self) { height in
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        scrollContentHeight = height
                    }
                }
                .onChange(of: viewModel.proposal) { _, newValue in
                    if newValue != nil {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 1.0)) {
                                proxy.scrollTo("bottomAnchor", anchor: .bottom)
                            }
                        }
                    }
                }
                .onChange(of: viewModel.messages.count) { _, _ in
                    withAnimation {
                        proxy.scrollTo("bottomAnchor", anchor: .bottom)
                    }
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
            InputBarView(
                text: $viewModel.userInput,
                isRecording: voiceRecorder.isRecording,
                startRecording: startRecording,
                stopRecording: stopRecording,
                sendAction: sendManualMessage
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
            .matchedGeometryEffect(id: "actionButton", in: animation, isSource: false)
            .background(
                GeometryReader { geo in
                    Color.clear.preference(key: InputViewHeightKey.self, value: geo.size.height)
                }
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
                SuccessPill()
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
                    GlassBackground(cornerRadius: 50, tint: Color.black.opacity(0.35))
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


    @ViewBuilder
    var recordingBubbleContent: some View {
        HStack(spacing: 12) {
            // Left: Circular logo/icon with glass effect
            Circle()
                .fill(Color.white.opacity(0.08))
                .overlay(
                    Circle()
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.25),
                                    Color.white.opacity(0.05)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .frame(width: 36, height: 36)
                .overlay(
                    Image(systemName: "waveform")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))
                )
                .matchedGeometryEffect(id: "appIcon", in: animation)
            
            AnimatedDotRow(count: 10)
                .frame(width: 84, height: 28)

            // Right: Vibrant stop button
            VoiceActionButton(
                size: 44,
                isRecording: true,
                action: stopRecording
            )
            .matchedGeometryEffect(id: "actionButton", in: animation)
        }
    }
    
    // Processing indicator shown inside the chat
    @ViewBuilder
    func processingIndicator(text: String) -> some View {
        HStack(spacing: 12) {
            // Interlocking circles (app icons)
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 24, height: 24)
                    .overlay(
                        Image(systemName: "number")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.7))
                    )
                    .offset(x: -5)
                
                Circle()
                    .fill(Color(nsColor: .controlAccentColor).opacity(0.3))
                    .frame(width: 24, height: 24)
                    .overlay(
                        Circle()
                            .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                    )
                    .overlay(
                        Image(systemName: "waveform")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white)
                            .matchedGeometryEffect(id: "appIcon", in: animation)
                    )
                    .offset(x: 5)
            }
            .frame(width: 34, height: 24)
            
            Text(text)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.75))
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.12),
                                    Color.white.opacity(0.03)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.5
                        )
                )
        )
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
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
                    viewModel.isTranscribing = true
                }
                
                let audioURL = try await voiceRecorder.stopRecording()
                let transcript = try await transcriptionService.transcribeFile(at: audioURL)
                
                await MainActor.run {
                    viewModel.errorMessage = nil
                    viewModel.isTranscribing = false
                    viewModel.processInput(text: transcript)
                }
            } catch {
                logger.error("Recording/Transcription failed: \(error.localizedDescription, privacy: .public)")
                await MainActor.run {
                    viewModel.errorMessage = error.localizedDescription
                    viewModel.isTranscribing = false
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

// MARK: - Supporting Views

private struct SuccessPill: View {
    var body: some View {
        HStack(spacing: 12) {
            // Icons
            HStack(spacing: -8) {
                Circle()
                    .fill(Color.white.opacity(0.15))
                    .frame(width: 26, height: 26)
                    .overlay(
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                    )
                    // 1. Add shadow to the icon group
                    .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
            }
            
            Text("Actions complete")
                .font(.system(size: 15, weight: .semibold)) // 2. Bump weight to Semibold
                .foregroundStyle(.white)
                // 3. Add a strong drop shadow to the text
                .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
    }
}



private struct AnimatedDotRow: View {
    let count: Int

    var body: some View {
        GeometryReader { proxy in
            let maxHeight = max(proxy.size.height, 1)
            let spacing: CGFloat = 3
            let totalSpacing = spacing * CGFloat(max(count - 1, 0))
            let availableWidth = max(proxy.size.width - totalSpacing, CGFloat(count))
            let barWidth = availableWidth / CGFloat(max(count, 1))

            TimelineView(.animation) { timeline in
                let phase = timeline.date.timeIntervalSinceReferenceDate.remainder(dividingBy: 1.4) / 1.4 * (.pi * 2)
                HStack(spacing: spacing) {
                    ForEach(0..<count, id: \.self) { index in
                        let relative = Double(index) / Double(max(count - 1, 1))
                        let distanceFromCenter = abs(relative - 0.5)
                        let envelope = 0.35 + (1 - distanceFromCenter * 2) * 0.65
                        let wave = (sin(phase + relative * .pi * 1.8) + 1) / 2
                        let height = max(3, CGFloat(wave) * maxHeight * CGFloat(envelope))

                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.85),
                                        Color.white.opacity(0.6)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(width: max(barWidth, 1), height: height)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            }
        }
        .frame(height: 32)
    }
}
