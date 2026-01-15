import SwiftUI
import AVFoundation
import ApplicationServices

// MARK: - General Settings View

struct GeneralSettingsView: View {
	@EnvironmentObject private var preferences: PreferencesStore
	@EnvironmentObject private var viewModel: SettingsViewModel
	@State private var microphoneStatus: AVAuthorizationStatus = .notDetermined
	@State private var accessibilityEnabled: Bool = false
	
	var body: some View {
		ScrollView {
			VStack(alignment: .leading, spacing: 24) {
				// Voice Section
				SettingsRowCard(title: "Voice") {
					SettingsRow(label: "Activation Key") {
						HStack(spacing: 8) {
							ForEach(VoiceShortcutKey.allCases) { key in
								KeyPillButton(
									label: key.label,
									isSelected: preferences.voiceShortcutKey == key,
									accentColor: preferences.accentColor
								) {
									let capturedKey = key
									DispatchQueue.main.async {
										preferences.voiceShortcutKey = capturedKey
									}
								}
							}
						}
					}
					
					SettingsRow(label: "Activation Mode", showDivider: false) {
						let activationModeBinding = Binding(
							get: { preferences.voiceActivationMode },
							set: { newValue in
								DispatchQueue.main.async {
									preferences.voiceActivationMode = newValue
								}
							}
						)
						Picker("", selection: activationModeBinding) {
							ForEach(VoiceActivationMode.allCases) { mode in
								Text(mode.label).tag(mode)
							}
						}
						.pickerStyle(.segmented)
						.frame(width: 180)
					}
				}
				
				// Appearance Section
				SettingsRowCard(title: "Appearance") {
					SettingsRow(label: "Theme") {
						HStack(spacing: 8) {
							ForEach(ThemePreference.allCases) { theme in
								ThemePillButton(
									theme: theme,
									isSelected: preferences.theme == theme,
									accentColor: preferences.accentColor
								) {
									viewModel.selectTheme(theme)
								}
							}
						}
					}
					
					SettingsRow(label: "Accent Color", showDivider: false) {
						HStack(spacing: 10) {
							ForEach(viewModel.accentOptions) { option in
								Button {
									viewModel.selectAccent(option)
								} label: {
									Circle()
										.fill(option.color.gradient)
										.frame(width: 24, height: 24)
										.overlay {
											if preferences.accentColorHex == option.hex {
												Circle()
													.stroke(.white, lineWidth: 2)
													.padding(2)
											}
										}
								}
								.buttonStyle(.plain)
							}
						}
					}
					
					if #available(macOS 26.0, iOS 26.0, *) {
						SettingsRow(label: "Glass Style", showDivider: false) {
							let glassStyleBinding = Binding(
								get: { preferences.glassStyle },
								set: { newValue in
									DispatchQueue.main.async {
										preferences.glassStyle = newValue
									}
								}
							)
							Picker("", selection: glassStyleBinding) {
								ForEach(GlassStyle.allCases) { style in
									Text(style.label).tag(style)
								}
							}
							.pickerStyle(.segmented)
							.frame(width: 160)
						}
					}
				}
				
				// Permissions Section
				SettingsRowCard(title: "Permissions") {
					SettingsRow(label: "Microphone") {
						if microphoneStatus == .authorized {
							Image(systemName: "checkmark.circle.fill")
								.foregroundStyle(.green)
						} else {
							Button("Enable") {
								requestMicrophone()
							}
							.buttonStyle(.borderedProminent)
							.controlSize(.small)
							.tint(preferences.accentColor)
						}
					}
					
					SettingsRow(label: "Accessibility", showDivider: false) {
						if accessibilityEnabled {
							Image(systemName: "checkmark.circle.fill")
								.foregroundStyle(.green)
						} else {
							Button("Enable") {
								openAccessibilityPrefs()
							}
							.buttonStyle(.borderedProminent)
							.controlSize(.small)
							.tint(preferences.accentColor)
						}
					}
				}
				
				Spacer(minLength: 20)
			}
			.padding(28)
		}
		.onAppear {
			microphoneStatus = AVCaptureDevice.authorizationStatus(for: .audio)
			accessibilityEnabled = AXIsProcessTrusted()
		}
	}
	
	private func requestMicrophone() {
		AVCaptureDevice.requestAccess(for: .audio) { _ in
			DispatchQueue.main.async {
				microphoneStatus = AVCaptureDevice.authorizationStatus(for: .audio)
			}
		}
	}
	
	private func openAccessibilityPrefs() {
		if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
			NSWorkspace.shared.open(url)
		}
	}
}

// MARK: - Key Pill Button

struct KeyPillButton: View {
	let label: String
	let isSelected: Bool
	let accentColor: Color
	let action: () -> Void
	
	var body: some View {
		Button(action: action) {
			Text(label)
				.font(.caption.weight(.medium))
				.padding(.horizontal, 12)
				.padding(.vertical, 6)
				.background(
					ZStack {
						LiquidGlassSurface(shape: .roundedRect(6), prominence: .subtle, shadowed: false)
						if isSelected {
							RoundedRectangle(cornerRadius: 6, style: .continuous)
								.fill(accentColor.opacity(0.18))
						}
					}
				)
				.overlay {
					RoundedRectangle(cornerRadius: 6, style: .continuous)
						.stroke(isSelected ? accentColor : Color.gray.opacity(0.2), lineWidth: 1)
				}
				.foregroundStyle(isSelected ? accentColor : .primary)
		}
		.buttonStyle(.plain)
	}
}

// MARK: - Theme Pill Button

struct ThemePillButton: View {
	let theme: ThemePreference
	let isSelected: Bool
	let accentColor: Color
	let action: () -> Void
	
	var body: some View {
		Button(action: action) {
			HStack(spacing: 6) {
				Image(systemName: themeIcon)
					.font(.caption)
				Text(theme.label)
					.font(.caption.weight(.medium))
			}
			.padding(.horizontal, 12)
			.padding(.vertical, 6)
			.background(
				ZStack {
					LiquidGlassSurface(shape: .roundedRect(6), prominence: .subtle, shadowed: false)
					if isSelected {
						RoundedRectangle(cornerRadius: 6, style: .continuous)
							.fill(accentColor.opacity(0.18))
					}
				}
			)
			.overlay {
				RoundedRectangle(cornerRadius: 6, style: .continuous)
					.stroke(isSelected ? accentColor : Color.gray.opacity(0.2), lineWidth: 1)
			}
			.foregroundStyle(isSelected ? accentColor : .primary)
		}
		.buttonStyle(.plain)
	}
	
	private var themeIcon: String {
		switch theme {
		case .system: "circle.lefthalf.filled"
		case .light: "sun.max.fill"
		case .dark: "moon.fill"
		}
	}
}
