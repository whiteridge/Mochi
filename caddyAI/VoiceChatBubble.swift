import SwiftUI
import Combine
import OSLog

struct VoiceChatBubble: View {
    @StateObject private var viewModel = AgentViewModel()
    @State private var viewID = 0
    @State private var contentHeight: CGFloat = 300 // Initialize with open size
    
    @Namespace private var animation

    @StateObject private var voiceRecorder = VoiceRecorder()
    private let transcriptionService = ParakeetTranscriptionService()
    private let logger = Logger(subsystem: "com.matteofari.caddyAI", category: "VoiceChatBubble")

    var body: some View {
        VStack {
            Spacer()
            // CONTENT (The ZStack with Pill/Chat)
            bubbleContent
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
    }
}

// MARK: - Content Builders

fileprivate extension VoiceChatBubble {
    @ViewBuilder
    var bubbleContent: some View {
        // Expand outwards from floating position
        ZStack(alignment: .bottom) {
            switch viewModel.state {
            case .idle, .recording:
                if viewModel.state == .recording {
                    recordingBubbleContent
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(
                            GlassBackground(cornerRadius: 30) // Capsule-ish
                                .matchedGeometryEffect(id: "background", in: animation)
                        )
                        .transition(.scale(scale: 1))
                }
                
            case .chat, .processing:
                // === EXPANDED STATE ===
                // Height Calculation: Content + Input Bar + Padding
                // Add generous buffer (100) to account for the input bar + top padding
                let cardAllowance: CGFloat = viewModel.proposal == nil ? 0 : 220
                let finalHeight = min(max(contentHeight + 100 + cardAllowance, 200), 600)
                
                ZStack(alignment: .bottom) {
                    chatPanelContent
                        .padding(22)
                        .frame(width: 400)
                        .frame(height: finalHeight, alignment: .bottom)
                        .animation(.interpolatingSpring(stiffness: 170, damping: 20), value: finalHeight)
                        .background(
                            GlassBackground(cornerRadius: 24)
                                .matchedGeometryEffect(id: "background", in: animation)
                        )
                        .transition(.scale(scale: 1))
                    
                    // Confirmation Card Removed from here
                }
                    
            case .success:
                // === SUCCESS STATE ===
                SuccessPill()
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        GlassBackground(cornerRadius: 30, tint: Color.green.opacity(0.2))
                            .matchedGeometryEffect(id: "background", in: animation)
                    )
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
            }
        }
        .overlay(alignment: .bottom) {
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.pink)
                    .padding(.horizontal, 12)
                    .padding(.bottom, -20) // Position below the bubble
                    .multilineTextAlignment(.center)
            }
        }
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
                .frame(width: 120, height: 28)

            // Right: Vibrant stop button
            VoiceActionButton(
                size: 44,
                isRecording: true,
                action: stopRecording
            )
            .matchedGeometryEffect(id: "actionButton", in: animation)
        }
    }

    var chatPanelContent: some View {
        VStack(spacing: 0) {
            // Top: Scrollable message area
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        if viewModel.messages.isEmpty {
                            Text("How can I help?")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundStyle(.white.opacity(0.6))
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.top, 40)
                        } else {
                            ForEach(viewModel.messages) { message in
                                chatBubble(for: message)
                                    .id(message.id)
                            }
                        }

                        // Show processing/thinking indicator inside the chat
                        if viewModel.isTranscribing {
                            processingIndicator(text: "Transcribing...")
                                .id("transcribing")
                        } else if viewModel.isThinking {
                            processingIndicator(text: "Thinking...")
                                .id("thinking")
                        }
                        
                        // Bottom anchor for scroll-to behavior
                        Color.clear
                            .frame(height: 1)
                            .id("bottomAnchor")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 25)
                    .padding(.bottom, 90)
                    .padding(.trailing, 20) // Compensate for negative padding
                    .background(
                        GeometryReader { geometry in
                            Color.clear
                                .preference(key: ViewHeightKey.self, value: geometry.size.height)
                        }
                    )
                }
                .scrollDisabled(contentHeight < 600)
                .padding(.trailing, -20) // Push scrollbar off-screen
                .scrollIndicators(.hidden)
                .scrollBounceBehavior(.basedOnSize)
                .frame(maxHeight: .infinity)
                .onPreferenceChange(ViewHeightKey.self) { height in
                    DispatchQueue.main.async {
                        contentHeight = height
                    }
                }
                .onChange(of: viewModel.messages.count) { _, _ in
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        proxy.scrollTo("bottomAnchor", anchor: .bottom)
                    }
                }
                .onChange(of: viewModel.proposal) { oldValue, newValue in
                    // When card appears/disappears, scroll to maintain bottom position
                    if newValue != nil || oldValue != nil {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                proxy.scrollTo("bottomAnchor", anchor: .bottom)
                            }
                        }
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 24)) // Clip the overflow
            
            // Tool Status Pill
            if let activeTool = viewModel.activeTool {
                ToolStatusView(toolName: activeTool.name, status: activeTool.status)
                    .padding(.bottom, 8)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            
            // Confirmation Card (Integrated into flow)
            if let proposal = viewModel.proposal {
                ConfirmationCardView(
                    proposal: proposal,
                    onConfirm: {
                        viewModel.confirmProposal()
                    },
                    onCancel: {
                        viewModel.cancelProposal()
                    }
                )
                .padding(.bottom, 6)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            
            // Bottom: Fixed input bar
            composer
                .padding(.top, 16)
                .padding(.bottom, 15)
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: viewModel.proposal)
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

    var composer: some View {
        HStack(spacing: 10) {
            // Logo icon with glass effect
            Circle()
                .fill(Color.white.opacity(0.06))
                .overlay(
                    Circle()
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.2),
                                    Color.white.opacity(0.04)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.5
                        )
                )
                .frame(width: 32, height: 32)
                .overlay(
                    Image(systemName: "waveform")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))
                )
            
            // Text field
            TextField("Type to Caddy", text: $viewModel.userInput, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: 15, weight: .regular, design: .default))
                .foregroundStyle(.white.opacity(0.9))
                .lineLimit(3)
                .onSubmit(sendManualMessage)
            
            Spacer()
            
            // Microphone button / Stop button
            VoiceActionButton(
                size: 28,
                isRecording: voiceRecorder.isRecording,
                action: voiceRecorder.isRecording ? stopRecording : startRecording
            )
            .matchedGeometryEffect(id: "actionButton", in: animation)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            ZStack {
                // Recessed background - darker than main glass
                Capsule()
                    .fill(Color.black.opacity(0.3))
                
                // Inner shadow effect (top darker, bottom lighter - inverted from main glass)
                Capsule()
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.black.opacity(0.4),    // Dark at top (shadow)
                                Color.white.opacity(0.0),    // Transition
                                Color.white.opacity(0.08)    // Light at bottom (catching light)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
            }
            .shadow(color: Color.black.opacity(0.3), radius: 4, x: 0, y: 1)
        )
    }

    @ViewBuilder
    func chatBubble(for message: ChatMessage) -> some View {
        let isUser = message.role == .user
        VStack(alignment: isUser ? .trailing : .leading, spacing: 8) {
            HStack {
                if isUser { Spacer(minLength: 40) }
                Text(message.content)
                    .font(.system(size: 15, weight: .regular, design: .default))
                    .foregroundStyle(.white.opacity(0.95))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        Group {
                            if isUser {
                                // User bubble - slightly lighter dark glass
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(Color.white.opacity(0.08))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                                            .strokeBorder(
                                                LinearGradient(
                                                    colors: [
                                                        Color.white.opacity(0.2),
                                                        Color.white.opacity(0.06)
                                                    ],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                ),
                                                lineWidth: 0.5
                                            )
                                    )
                            } else {
                                // Assistant bubble - glass effect
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(Color.white.opacity(0.06))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                                            .strokeBorder(
                                                LinearGradient(
                                                    colors: [
                                                        Color.white.opacity(0.15),
                                                        Color.white.opacity(0.04)
                                                    ],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                ),
                                                lineWidth: 0.5
                                            )
                                    )
                            }
                        }
                    )
                if !isUser { Spacer(minLength: 40) }
            }
        }
        .transition(.move(edge: isUser ? .trailing : .leading).combined(with: .opacity))
    }
}

// MARK: - Actions

@MainActor
private extension VoiceChatBubble {
    /// Handle Enter key press based on current state
    func handleEnterKey() {
        switch viewModel.state {
        case .recording:
            // Enter during recording -> Stop recording
            logger.debug("Enter pressed: Stopping recording")
            stopRecording()
        case .chat, .processing:
            // Enter during chat -> Send message if input is not empty
            logger.debug("Enter pressed: Sending message")
            sendManualMessage()
        case .success:
            // Ignore
            break
        case .idle:
            // Do nothing in idle state
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
                    
                    // Logic Change:
                    // If state == .idle: Transition to .recording (Show Pill).
                    // If state == .chat: Stay in .chat. Do not transition to .recording.
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
                // Immediately expand to chat
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
        // Note: animation is handled by the .animation modifier on body
        viewModel.reset()
    }
}

// MARK: - Helpers

private struct SuccessPill: View {
    var body: some View {
        HStack(spacing: 12) {
            // Icons
            HStack(spacing: -8) {
                Circle()
                    .fill(Color.white.opacity(0.15))
                    .frame(width: 26, height: 26)
                    .overlay(Image(systemName: "checkmark").font(.system(size: 12, weight: .bold)).foregroundStyle(.white))
            }
            
            Text("Actions complete")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.white.opacity(0.95))
        }
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

// MARK: - Glass Background Component

private struct GlassBackground: View {
    // 1. Fix the Expansion Physics: Smooth corner radius animation
    var cornerRadius: CGFloat
    var tint: Color = Color.black.opacity(0.5)
    
    var body: some View {
        ZStack {
            // Base glass layer with material
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.ultraThinMaterial)
            
            // Dark tint overlay for depth
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(tint)
        }
        .overlay(
            // Primary rim light - simulates light catching the glass edge
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.4), // Slightly increased for visibility
                            Color.white.opacity(0.15),
                            Color.white.opacity(0.03)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .overlay(
            // Inner glow for glass thickness
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(
                    Color.white.opacity(0.08),
                    lineWidth: 0.5
                )
                .blur(radius: 1.5)
                .padding(1)
        )
        .shadow(color: Color.black.opacity(0.4), radius: 18, x: 0, y: 12)
    }
}

// MARK: - Preference Key for Height Measurement

private struct ViewHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
