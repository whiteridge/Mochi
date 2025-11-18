import SwiftUI

struct CaddyView: View {
	@State private var showView = false
	@StateObject private var audioService = AudioCaptureService()

	var body: some View {
		ZStack {
			if showView {
				HStack(spacing: 12) {
					ZStack {
						Circle()
							.strokeBorder(.white.opacity(0.15), lineWidth: 1.5)
							.frame(width: 28, height: 28)
						Image(systemName: "waveform.circle.fill")
							.symbolRenderingMode(.palette)
							.foregroundStyle(.white.opacity(0.9), .white.opacity(0.25))
							.font(.system(size: 16, weight: .semibold))
					}

					WaveformBars(amplitude: audioService.normalizedAmplitude)
						.frame(width: 160, height: 20)

					ZStack {
						Circle()
							.fill(Color(red: 0.98, green: 0.35, blue: 0.26))
							.frame(width: 28, height: 28)
							.shadow(color: .red.opacity(0.35), radius: 6, x: 0, y: 3)
						RoundedRectangle(cornerRadius: 3, style: .continuous)
							.fill(Color.white)
							.frame(width: 11, height: 11)
					}
				}
				.padding(.horizontal, 18)
				.padding(.vertical, 12)
				.background(
					ZStack {
						VisualEffectView(material: .hudWindow)
							.clipShape(Capsule())
						// Subtle glass edge and gloss
						Capsule()
							.stroke(.white.opacity(0.08), lineWidth: 1)
						Capsule()
							.fill(
								LinearGradient(
									colors: [
										.white.opacity(0.12),
										.clear
									],
									startPoint: .top,
									endPoint: .center
								)
							)
							.blur(radius: 6)
							.allowsHitTesting(false)
					}
				)
				.clipShape(Capsule())
				.shadow(color: .black.opacity(0.45), radius: 16, x: 0, y: 12)
				.transition(.move(edge: .bottom).combined(with: .opacity))
			}
		}
		.frame(width: 360, height: 64)
		.onAppear {
			withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
				showView = true
			}
			// Start audio capture
			audioService.startCapture()
		}
		.onDisappear {
			audioService.stopCapture()
		}
	}
}

private struct WaveformBars: View {
	let amplitude: CGFloat
	@State private var phase: CGFloat = 0

	var body: some View {
		GeometryReader { proxy in
			let count = 20
			let spacing: CGFloat = 6
			let barWidth = (proxy.size.width - CGFloat(count - 1) * spacing) / CGFloat(count)

			HStack(spacing: spacing) {
				ForEach(0..<count, id: \.self) { i in
					let t = (CGFloat(i) / CGFloat(count - 1)) * .pi
					// When amplitude is 0, make it flat (min height)
					let base = amplitude > 0 ? sin(t) * 0.8 + 0.2 : 0.1
					let wave = amplitude > 0 ? (sin(t * 3 + phase) + 1) / 2 : 0.1
					let height = max(2, (base * 0.6 + wave * 0.4) * amplitude * proxy.size.height)
					RoundedRectangle(cornerRadius: 1.5, style: .continuous)
						.fill(.white.opacity(0.9))
						.frame(width: barWidth, height: height)
						.animation(.linear(duration: 0.18), value: phase)
				}
			}
			.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
			.onAppear {
				if amplitude > 0 {
					withAnimation(.linear(duration: 0.18).repeatForever(autoreverses: false)) {
						phase = .pi * 2
					}
				}
			}
			.onChange(of: amplitude) { newValue in
				if newValue > 0 {
					withAnimation(.linear(duration: 0.18).repeatForever(autoreverses: false)) {
						phase = .pi * 2
					}
				}
			}
		}
	}
}


