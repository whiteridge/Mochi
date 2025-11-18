import SwiftUI
import Combine
import OSLog

enum VoiceChatState {
	case idle
	case recording
	case transcribing
	case processingContext
	case chat
}

struct ChatMessage: Identifiable {
	let id = UUID()
	let role: Role
	let content: String

	enum Role {
		case user
		case assistant
	}
}

struct VoiceChatBubble: View {
	@State private var state: VoiceChatState = .idle
	@State private var messages: [ChatMessage] = []
	@State private var userInput: String = ""
	@State private var isThinking = false
	@State private var errorMessage: String?
	@State private var viewID = 0
	
	@Namespace private var animation

	@StateObject private var voiceRecorder = VoiceRecorder()
	private let transcriptionService = ParakeetTranscriptionService()
	private let logger = Logger(subsystem: "com.matteofari.caddyAI", category: "VoiceChatBubble")
	private let geminiService = GeminiService.shared

	var body: some View {
		bubbleContent
			.padding(.horizontal, 16)
			.padding(.vertical, 20)
			.background(Color.clear)
			.onReceive(NotificationCenter.default.publisher(for: .voiceChatShouldStartRecording)) { _ in
				beginHotkeySession()
			}
			.onReceive(NotificationCenter.default.publisher(for: .voiceChatShouldStopSession)) { _ in
				cancelVoiceSession()
			}
			.onChange(of: state) { _, _ in
				NotificationCenter.default.post(name: .voiceChatLayoutNeedsUpdate, object: nil)
			}
			.onKeyPress(.return) {
				handleEnterKey()
				return .handled
			}
	}
}

// MARK: - Content Builders

fileprivate extension VoiceChatBubble {
	@ViewBuilder
	var bubbleContent: some View {
		VStack(alignment: .trailing, spacing: 8) {
			// Use ZStack to keep both views in hierarchy for matchedGeometryEffect
			ZStack(alignment: .bottomTrailing) {
				if state == .chat {
					// === EXPANDED STATE ===
					chatPanelContent
						.padding(22)
						.frame(width: 400)
						.frame(minHeight: 320)
						.background(
							GlassBackground(shape: .roundedRectangle)
								.matchedGeometryEffect(id: "backgroundShape", in: animation)
						)
						.transition(.opacity)
				} else if state == .recording || state == .transcribing {
					// === PILL STATE (Recording) ===
					recordingBubbleContent
						.padding(.horizontal, 14)
						.padding(.vertical, 10)
						.background(
							GlassBackground(shape: .capsule)
								.matchedGeometryEffect(id: "backgroundShape", in: animation)
						)
						.transition(.opacity)
				} else if state == .processingContext {
					// === PILL STATE (Context) ===
					contextReadingBubbleContent
						.padding(.horizontal, 14)
						.padding(.vertical, 10)
						.background(
							GlassBackground(shape: .capsule)
								.matchedGeometryEffect(id: "backgroundShape", in: animation)
						)
						.transition(.opacity)
				}
			}

			if let errorMessage {
				Text(errorMessage)
					.font(.caption)
					.foregroundStyle(.pink)
					.padding(.horizontal, 12)
					.multilineTextAlignment(.trailing)
			}
		}
	}

	@ViewBuilder
	var recordingBubbleContent: some View {
		let isTranscribing = state == .transcribing

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
			
			if isTranscribing {
				HStack(spacing: 8) {
					ProgressView()
						.controlSize(.small)
						.tint(.white.opacity(0.9))
					Text("Transcribing…")
						.font(.system(size: 15, weight: .medium, design: .default))
						.foregroundStyle(.white.opacity(0.85))
				}
				.transition(.opacity.animation(.easeInOut(duration: 0.2)))
			} else {
				AnimatedDotRow(count: 10)
					.frame(width: 120, height: 28)
					.transition(.opacity.animation(.easeInOut(duration: 0.2)))
			}

			// Right: Vibrant stop button
			Button(action: stopRecording) {
				RoundedRectangle(cornerRadius: 6, style: .continuous)
					.fill(.white)
					.frame(width: 16, height: 16)
			}
			.buttonStyle(.plain)
			.frame(width: 40, height: 40)
			.background(
				Circle()
					.fill(
						LinearGradient(
							colors: [Color(red: 1.0, green: 0.4, blue: 0.3), Color(red: 0.95, green: 0.25, blue: 0.2)],
							startPoint: .topLeading,
							endPoint: .bottomTrailing
						)
					)
			)
			.shadow(color: Color(red: 1.0, green: 0.3, blue: 0.2).opacity(0.4), radius: 8, x: 0, y: 4)
			.disabled(isTranscribing)
			.transition(.opacity.animation(.easeInOut(duration: 0.2)))
		}
	}

	var contextReadingBubbleContent: some View {
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
			
			// Center: Context indicator
			ContextIndicatorView()
				.transition(.opacity.combined(with: .scale(scale: 0.9)))
		}
	}

	var chatPanelContent: some View {
		VStack(alignment: .leading, spacing: 16) {
			HStack {
				Text("Voice Chat")
					.font(.system(size: 17, weight: .semibold, design: .default))
					.foregroundStyle(.white)
				Spacer()
				Button {
					resetConversation()
				} label: {
					Image(systemName: "xmark")
						.font(.system(size: 11, weight: .semibold))
						.foregroundStyle(.white.opacity(0.7))
						.frame(width: 28, height: 28)
						.background(
							Circle()
								.fill(Color.white.opacity(0.08))
								.overlay(
									Circle()
										.strokeBorder(
											LinearGradient(
												colors: [
													Color.white.opacity(0.2),
													Color.white.opacity(0.05)
												],
												startPoint: .topLeading,
												endPoint: .bottomTrailing
											),
											lineWidth: 0.5
										)
								)
						)
				}
				.buttonStyle(.plain)
			}
			.transition(.opacity.animation(.easeInOut(duration: 0.3).delay(0.1)))

			ScrollView {
				VStack(alignment: .leading, spacing: 14) {
					ForEach(messages) { message in
						chatBubble(for: message)
					}

					if isThinking {
						thinkingBubble
					}
				}
				.frame(maxWidth: .infinity, alignment: .leading)
				.padding(.vertical, 4)
			}
			.frame(maxHeight: 300)
			.transition(.opacity.animation(.easeInOut(duration: 0.3).delay(0.1)))

			Divider()
				.overlay(
					LinearGradient(
						colors: [Color.white.opacity(0.08), Color.white.opacity(0.02)],
						startPoint: .leading,
						endPoint: .trailing
					)
				)
				.transition(.opacity.animation(.easeInOut(duration: 0.3).delay(0.1)))

			composer
				.transition(.opacity.animation(.easeInOut(duration: 0.3).delay(0.1)))
		}
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
			TextField("Type to Caddy", text: $userInput, axis: .vertical)
				.textFieldStyle(.plain)
				.font(.system(size: 15, weight: .regular, design: .default))
				.foregroundStyle(.white.opacity(0.9))
				.lineLimit(3)
				.onSubmit(sendManualMessage)
			
			Spacer()
			
			// Microphone button
			Button(action: startRecording) {
				Image(systemName: "mic.fill")
					.font(.system(size: 16, weight: .medium))
					.foregroundStyle(.white.opacity(0.8))
			}
			.buttonStyle(.plain)
			.frame(width: 32, height: 32)
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
					.foregroundStyle(isUser ? Color(white: 0.1) : .white.opacity(0.95))
					.padding(.horizontal, 16)
					.padding(.vertical, 12)
					.background(
						Group {
							if isUser {
								// User bubble - bright white with shadow
								RoundedRectangle(cornerRadius: 18, style: .continuous)
									.fill(Color.white.opacity(0.95))
									.overlay(
										RoundedRectangle(cornerRadius: 18, style: .continuous)
											.strokeBorder(Color.white.opacity(0.3), lineWidth: 0.5)
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
					.shadow(
						color: isUser ? Color.black.opacity(0.08) : Color.clear,
						radius: 8,
						x: 0,
						y: 2
					)
				if !isUser { Spacer(minLength: 40) }
			}
		}
		.transition(.move(edge: isUser ? .trailing : .leading).combined(with: .opacity))
	}

	var thinkingBubble: some View {
		HStack(spacing: 10) {
			AnimatedDotRow(count: 4)
				.frame(width: 40, height: 20)
			Text("Thinking…")
				.font(.system(size: 14, weight: .medium, design: .default))
				.foregroundStyle(.white.opacity(0.65))
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
	}
}

// MARK: - Actions

@MainActor
private extension VoiceChatBubble {
	/// Handle Enter key press based on current state
	func handleEnterKey() {
		switch state {
		case .recording:
			// Enter during recording -> Stop recording
			logger.debug("Enter pressed: Stopping recording")
			stopRecording()
		case .chat:
			// Enter during chat -> Send message if input is not empty
			logger.debug("Enter pressed: Sending message")
			sendManualMessage()
		case .transcribing:
			// Do nothing during transcription
			logger.debug("Enter pressed during transcription: Ignoring")
		case .processingContext:
			// Do nothing while processing context
			logger.debug("Enter pressed during context processing: Ignoring")
		case .idle:
			// Do nothing in idle state
			logger.debug("Enter pressed in idle state: Ignoring")
		}
	}
	
	func beginHotkeySession() {
		guard state != .recording && state != .transcribing && state != .processingContext else { return }
		resetConversation(animate: false)
		startRecording()
	}

	func cancelVoiceSession() {
		Task {
			try? await voiceRecorder.stopRecording()
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
					errorMessage = nil
					viewID += 1
					withAnimation(.spring(response: 0.5, dampingFraction: 0.7, blendDuration: 0)) {
						state = .recording
					}
				}
			} catch {
				await MainActor.run {
					errorMessage = error.localizedDescription
				}
			}
		}
	}

	func stopRecording() {
		withAnimation(.spring(response: 0.5, dampingFraction: 0.7, blendDuration: 0)) {
			state = .transcribing
		}
		errorMessage = nil

		Task {
			do {
				let audioURL = try await voiceRecorder.stopRecording()
				let transcript = try await transcriptionService.transcribeFile(at: audioURL)
				await MainActor.run {
					errorMessage = nil
					appendUserMessage(transcript)
					withAnimation(.spring(response: 0.5, dampingFraction: 0.7, blendDuration: 0)) {
						state = .processingContext
					}
				}
				
				// Simulate context reading delay (2 seconds)
				try? await Task.sleep(nanoseconds: 2_000_000_000)
				
				await MainActor.run {
					withAnimation(.spring(response: 0.5, dampingFraction: 0.7, blendDuration: 0)) {
						state = .chat
					}
				}
				await fetchAssistantResponse()
			} catch {
				logger.error("Recording/Transcription failed: \(error.localizedDescription, privacy: .public)")
				await MainActor.run {
					self.errorMessage = error.localizedDescription
					// Use easeInOut for consistent animation
					withAnimation(.easeInOut(duration: 0.35)) {
						self.state = .idle
					}
				}
			}
		}
	}

	func appendUserMessage(_ text: String) {
		guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
		messages.append(ChatMessage(role: .user, content: text))
	}

	func sendManualMessage() {
		let trimmed = userInput.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !trimmed.isEmpty else { return }
		if state != .chat {
			withAnimation(.spring(response: 0.5, dampingFraction: 0.7, blendDuration: 0)) {
				state = .chat
			}
		}
		messages.append(ChatMessage(role: .user, content: trimmed))
		userInput = ""

		Task {
			await fetchAssistantResponse()
		}
	}

	func fetchAssistantResponse() async {
		await MainActor.run {
			isThinking = true
		}

		do {
			let reply = try await geminiService.generateResponse(for: messages)
			await MainActor.run {
				messages.append(ChatMessage(role: .assistant, content: reply))
				isThinking = false
				errorMessage = nil
			}
		} catch {
			await MainActor.run {
				isThinking = false
				errorMessage = error.localizedDescription
			}
		}
	}

	func resetConversation(animate: Bool = true) {
		if animate {
			// Use easeInOut with longer duration to see the shrink effect
			withAnimation(.easeInOut(duration: 0.35)) {
				state = .idle
			}
		} else {
			state = .idle
		}
		messages.removeAll()
		userInput = ""
		isThinking = false
		errorMessage = nil
		geminiService.resetConversation()
	}
}

// MARK: - Helpers

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

private enum GlassShape {
	case capsule
	case roundedRectangle
}

private struct GlassBackground: View {
	let shape: GlassShape
	
	var body: some View {
		Group {
			switch shape {
			case .capsule:
				glassMorphCapsule
			case .roundedRectangle:
				glassMorphRectangle
			}
		}
	}
	
	private var glassMorphCapsule: some View {
		ZStack {
			// Base glass layer with material
			Capsule()
				.fill(.ultraThinMaterial)
			
			// Dark tint overlay for depth
			Capsule()
				.fill(Color.black.opacity(0.5))
		}
		.overlay(
			// Primary rim light - simulates light catching the glass edge
			Capsule()
				.strokeBorder(
					LinearGradient(
						colors: [
							Color.white.opacity(0.35),
							Color.white.opacity(0.08),
							Color.white.opacity(0.02)
						],
						startPoint: .topLeading,
						endPoint: .bottomTrailing
					),
					lineWidth: 1
				)
		)
		.overlay(
			// Inner glow for glass thickness
			Capsule()
				.strokeBorder(
					Color.white.opacity(0.06),
					lineWidth: 0.5
				)
				.blur(radius: 1)
				.padding(1)
		)
		.shadow(color: Color.black.opacity(0.4), radius: 15, x: 0, y: 10)
	}
	
	private var glassMorphRectangle: some View {
		ZStack {
			// Base glass layer with material
			RoundedRectangle(cornerRadius: 24, style: .continuous)
				.fill(.ultraThinMaterial)
			
			// Dark tint overlay for depth
			RoundedRectangle(cornerRadius: 24, style: .continuous)
				.fill(Color.black.opacity(0.5))
		}
		.overlay(
			// Primary rim light - simulates light catching the glass edge
			RoundedRectangle(cornerRadius: 24, style: .continuous)
				.strokeBorder(
					LinearGradient(
						colors: [
							Color.white.opacity(0.4),
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
			RoundedRectangle(cornerRadius: 24, style: .continuous)
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

// MARK: - Context Indicator Component

private struct ContextIndicatorView: View {
	@State private var animationPhase: CGFloat = 0
	
	var body: some View {
		HStack(spacing: 8) {
			// App icons with overlapping effect
			ZStack {
				// Slack icon (background)
				Image(systemName: "number")
					.font(.system(size: 12, weight: .semibold))
					.foregroundStyle(.white.opacity(0.7))
					.frame(width: 20, height: 20)
					.background(
						Circle()
							.fill(Color.white.opacity(0.1))
					)
					.offset(x: -4)
				
				// Linear icon (foreground)
				Image(systemName: "tray.full.fill")
					.font(.system(size: 12, weight: .semibold))
					.foregroundStyle(.white.opacity(0.8))
					.frame(width: 20, height: 20)
					.background(
						Circle()
							.fill(Color.white.opacity(0.12))
					)
					.offset(x: 4)
			}
			.frame(width: 32, height: 20)
			
			// Animated text
			Text("Reading context...")
				.font(.system(size: 14, weight: .medium, design: .default))
				.foregroundStyle(.white.opacity(0.75 + animationPhase * 0.25))
		}
		.padding(.horizontal, 14)
		.padding(.vertical, 8)
		.background(
			// Glassmorphic capsule background
			ZStack {
				Capsule()
					.fill(.ultraThinMaterial)
				
				Capsule()
					.fill(Color.black.opacity(0.6))
			}
			.overlay(
				// Subtle white gradient stroke
				Capsule()
					.strokeBorder(
						LinearGradient(
							colors: [
								Color.white.opacity(0.3),
								Color.white.opacity(0.08),
								Color.white.opacity(0.02)
							],
							startPoint: .topLeading,
							endPoint: .bottomTrailing
						),
						lineWidth: 0.5
					)
			)
		)
		.onAppear {
			// Pulse animation for the text
			withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
				animationPhase = 1.0
			}
		}
	}
}

