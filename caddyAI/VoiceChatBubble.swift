import SwiftUI
import Combine
import OSLog

enum VoiceChatState: Equatable {
	case idle
	case recording
	case chat
	case success    // New success state
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
	@State private var isTranscribing = false // Track transcription separately
	@State private var errorMessage: String?
	@State private var viewID = 0
	@State private var contentHeight: CGFloat = 300 // Initialize with open size
	
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
            // 1. Fix the Expansion Physics: specific animation curve
			.animation(.spring(response: 0.6, dampingFraction: 0.7, blendDuration: 0), value: state)
	}
}

// MARK: - Content Builders

fileprivate extension VoiceChatBubble {
	@ViewBuilder
	var bubbleContent: some View {
		// Expand outwards from floating position
		ZStack(alignment: .bottom) {
			if state == .chat {
				// === EXPANDED STATE ===
				// Height Calculation: Content + Input Bar + Padding
				// Add generous buffer (100) to account for the input bar + top padding
				let finalHeight = min(max(contentHeight + 100, 200), 600)
				
				chatPanelContent
					.transition(
						.asymmetric(
							insertion: .opacity.animation(.easeInOut(duration: 0.3).delay(0.1)),
							removal: .opacity.animation(.easeInOut(duration: 0.1))
						)
					)
					.padding(22)
					.frame(width: 400)
					.frame(height: finalHeight)
					.background(
						GlassBackground(cornerRadius: 24)
							.matchedGeometryEffect(id: "background", in: animation)
					)
					.animation(.spring(response: 0.5, dampingFraction: 0.75), value: contentHeight)
			} else if state == .recording {
				// === RECORDING STATE ===
				recordingBubbleContent
					.padding(.horizontal, 14)
					.padding(.vertical, 10)
					.transition(.opacity)
					.background(
						GlassBackground(cornerRadius: 30) // Capsule-ish
							.matchedGeometryEffect(id: "background", in: animation)
					)
			} else if state == .success {
				// === SUCCESS STATE ===
				SuccessPill()
					.padding(.horizontal, 14)
					.padding(.vertical, 10)
					.transition(.opacity)
					.background(
						GlassBackground(cornerRadius: 30, tint: Color.green.opacity(0.2))
							.matchedGeometryEffect(id: "background", in: animation)
					)
			}
		}
		.overlay(alignment: .bottomTrailing) {
			if let errorMessage {
				Text(errorMessage)
					.font(.caption)
					.foregroundStyle(.pink)
					.padding(.horizontal, 12)
					.padding(.bottom, -20) // Position below the bubble
					.multilineTextAlignment(.trailing)
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
		}
	}

	var chatPanelContent: some View {
		VStack(spacing: 0) {
			// Top: Scrollable message area
			ScrollViewReader { proxy in
				ScrollView {
					VStack(alignment: .leading, spacing: 14) {
						if messages.isEmpty {
							Text("How can I help?")
								.font(.system(size: 20, weight: .medium))
								.foregroundStyle(.white.opacity(0.6))
								.frame(maxWidth: .infinity, alignment: .center)
								.padding(.top, 40)
						} else {
							ForEach(messages) { message in
								chatBubble(for: message)
									.id(message.id)
							}
						}

						// Show processing/thinking indicator inside the chat
						if isTranscribing {
							processingIndicator(text: "Transcribing...")
								.id("transcribing")
						} else if isThinking {
							processingIndicator(text: "Thinking...")
								.id("thinking")
						}
					}
					.frame(maxWidth: .infinity, alignment: .leading)
					.padding(.top, 25)
					.padding(.bottom, 90)
					.background(
						GeometryReader { geometry in
							Color.clear
								.preference(key: ViewHeightKey.self, value: geometry.size.height)
						}
					)
				}
				.scrollDisabled(contentHeight < 600)
				.scrollIndicators(.hidden)
				.frame(maxHeight: .infinity)
				.onPreferenceChange(ViewHeightKey.self) { height in
					DispatchQueue.main.async {
						contentHeight = height
					}
				}
				.onChange(of: messages.count) { _, _ in
					if let lastId = messages.last?.id {
						withAnimation {
							proxy.scrollTo(lastId, anchor: .bottom)
						}
					}
				}
			}
			
			// Bottom: Fixed input bar
			composer
				.padding(.top, 16)
				.padding(.bottom, 15)
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
		switch state {
		case .recording:
			// Enter during recording -> Stop recording
			logger.debug("Enter pressed: Stopping recording")
			stopRecording()
		case .chat:
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
		guard state != .recording else { return }
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
					// Let the spring animation in body handle the transition
					state = .recording
				}
			} catch {
				await MainActor.run {
					errorMessage = error.localizedDescription
				}
			}
		}
	}

	func stopRecording() {
		errorMessage = nil

		Task {
			do {
				// Immediately expand to chat
				await MainActor.run {
					state = .chat
					isTranscribing = true
				}
				
				let audioURL = try await voiceRecorder.stopRecording()
				let transcript = try await transcriptionService.transcribeFile(at: audioURL)
				
				await MainActor.run {
					errorMessage = nil
					appendUserMessage(transcript)
					isTranscribing = false
				}
				
				await fetchAssistantResponse()
			} catch {
				logger.error("Recording/Transcription failed: \(error.localizedDescription, privacy: .public)")
				await MainActor.run {
					self.errorMessage = error.localizedDescription
					self.isTranscribing = false
					self.state = .idle
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
			state = .chat
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
		// Note: animation is handled by the .animation modifier on body
		state = .idle
		messages.removeAll()
		userInput = ""
		isThinking = false
		isTranscribing = false
		errorMessage = nil
		geminiService.resetConversation()
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
