import SwiftUI
import AVFoundation
import ApplicationServices
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

// MARK: - Changelog Data

struct ChangelogEntry: Identifiable {
	let id = UUID()
	let version: String
	let date: String
	let features: [String]
}

private let changelog: [ChangelogEntry] = [
	ChangelogEntry(
		version: "1.0.0",
		date: "January 8, 2026",
		features: [
			"Initial release",
			"Voice-activated AI assistant",
			"Slack and Linear integrations",
			"Customizable hotkey activation"
		]
	)
]

// MARK: - Main Settings View

struct AppSettingsView: View {
	@EnvironmentObject private var preferences: PreferencesStore
	@EnvironmentObject private var integrationService: IntegrationService
	@EnvironmentObject private var viewModel: SettingsViewModel
	
	var body: some View {
		HStack(spacing: 0) {
			// Sidebar with grouped sections
			sidebarView
			
			Divider()
			
			// Detail content
			detailView
				.frame(maxWidth: .infinity, maxHeight: .infinity)
		}
		.tint(preferences.accentColor)
		.onAppear { viewModel.loadPersistedValues() }
	}
	
	private var sidebarView: some View {
		VStack(alignment: .leading, spacing: 0) {
			List(selection: $viewModel.selectedSection) {
				// Main sections
				Label("General", systemImage: "gearshape")
					.tag(SettingsSection.general)
				Label("Integrations", systemImage: "link")
					.tag(SettingsSection.integrations)
				
				// Visual separator
				Section {
					Label("About", systemImage: "info.circle")
						.tag(SettingsSection.about)
				}
			}
			.listStyle(.sidebar)
		}
		.frame(width: 180)
	}
	
	@ViewBuilder
	private var detailView: some View {
		switch viewModel.selectedSection {
		case .general:
			GeneralSettingsView()
		case .integrations:
			IntegrationsSettingsView()
		case .about:
			AboutSettingsView()
		}
	}
}

// MARK: - Homerow-Style Row Card

private struct SettingsRowCard<Content: View>: View {
	let title: String
	@ViewBuilder let content: Content
	
	var body: some View {
		VStack(alignment: .leading, spacing: 12) {
			Text(title)
				.font(.subheadline.weight(.semibold))
				.foregroundStyle(.primary)
			
			VStack(spacing: 0) {
				content
			}
			.background(
				LiquidGlassSurface(shape: .roundedRect(12), prominence: .regular)
			)
		}
	}
}

private struct SettingsRow<Control: View>: View {
	let label: String
	let showDivider: Bool
	@ViewBuilder let control: Control
	@Environment(\.colorScheme) private var colorScheme
	
	private var palette: LiquidGlassPalette {
		LiquidGlassPalette(colorScheme: colorScheme)
	}
	
	init(label: String, showDivider: Bool = true, @ViewBuilder control: () -> Control) {
		self.label = label
		self.showDivider = showDivider
		self.control = control()
	}
	
	var body: some View {
		VStack(spacing: 0) {
			HStack {
				Text(label)
					.font(.body)
				Spacer()
				control
			}
			.padding(.horizontal, 16)
			.padding(.vertical, 12)
			
			if showDivider {
				Divider()
					.padding(.leading, 16)
					.foregroundStyle(palette.divider)
			}
		}
	}
}

// MARK: - General Settings View

private struct GeneralSettingsView: View {
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
									// #region agent log - FIX: Defer assignment to break out of view update context
									let capturedKey = key // Capture immediately
									print("[Settings] Button tapped for key: \(capturedKey.rawValue), current: \(preferences.voiceShortcutKey.rawValue)")
									DispatchQueue.main.async {
										print("[Settings] Deferred assignment: setting key to \(capturedKey.rawValue)")
										preferences.voiceShortcutKey = capturedKey
										print("[Settings] After assignment: rawValue is now \(preferences.voiceShortcutKeyRaw)")
									}
									// #endregion
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

// MARK: - Integrations Settings View

private struct IntegrationsSettingsView: View {
	@EnvironmentObject private var integrationService: IntegrationService
	@EnvironmentObject private var viewModel: SettingsViewModel
	@EnvironmentObject private var preferences: PreferencesStore
	
	@State private var slackLoading = false
	@State private var linearLoading = false
	@State private var slackError: String?
	@State private var linearError: String?
	@State private var showAdvanced = false
	@State private var showSaved = false
	@State private var refreshTimer: Timer?
	
	var body: some View {
		ScrollView {
			VStack(alignment: .leading, spacing: 24) {
				// Connections Section
				SettingsRowCard(title: "Connections") {
					// Slack Row
					IntegrationRow(
						name: "Slack",
						iconName: "slack-icon",
						fallbackIcon: "bubble.left.and.bubble.right.fill",
						state: integrationService.slackState,
						isLoading: slackLoading,
						errorMessage: slackError,
						accentColor: preferences.accentColor,
						onConnect: connectSlack,
						onDisconnect: disconnectSlack,
						showDivider: true
					)
					
					// Linear Row
					IntegrationRow(
						name: "Linear",
						iconName: "linear-icon",
						fallbackIcon: "checklist",
						state: integrationService.linearState,
						isLoading: linearLoading,
						errorMessage: linearError,
						accentColor: preferences.accentColor,
						onConnect: connectLinear,
						onDisconnect: disconnectLinear,
						showDivider: false
					)
				}
				
				// API Section
				SettingsRowCard(title: "API") {
					SettingsRow(label: "API Key") {
						HStack(spacing: 8) {
							SecureField("Enter key", text: $viewModel.apiKey)
								.textFieldStyle(.roundedBorder)
								.frame(width: 200)
							
							if let success = viewModel.apiTestSuccess {
								Image(systemName: success ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
									.foregroundStyle(success ? .green : .orange)
							}
						}
					}
					
					SettingsRow(label: "Base URL", showDivider: false) {
						HStack(spacing: 8) {
							TextField("Optional", text: $viewModel.apiBaseURL)
								.textFieldStyle(.roundedBorder)
								.frame(width: 160)
							
							Button {
								viewModel.saveAPISettings()
								withAnimation { showSaved = true }
								DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
									withAnimation { showSaved = false }
								}
							} label: {
								Text(showSaved ? "Saved" : "Save")
									.frame(width: 50)
							}
							.buttonStyle(.borderedProminent)
							.controlSize(.small)
							.tint(showSaved ? .green : preferences.accentColor)
						}
					}
				}
				
				// Advanced Section (collapsed by default)
				DisclosureGroup(isExpanded: $showAdvanced) {
					VStack(alignment: .leading, spacing: 16) {
						// Slack Manual
						VStack(alignment: .leading, spacing: 10) {
							Text("Slack (Manual)")
								.font(.subheadline.weight(.medium))
							SecureField("Bot/User token (xoxb-…)", text: $viewModel.slackToken)
								.textFieldStyle(.roundedBorder)
							HStack(spacing: 12) {
								Button("Save & Connect") { viewModel.connectSlack() }
									.buttonStyle(.bordered)
									.controlSize(.small)
								if let status = viewModel.slackTestMessage {
									StatusLabel(text: status, success: viewModel.slackTestSuccess ?? false)
								}
							}
						}
						
						Divider()
						
						// Linear Manual
						VStack(alignment: .leading, spacing: 10) {
							Text("Linear (Manual)")
								.font(.subheadline.weight(.medium))
							SecureField("API key", text: $viewModel.linearApiKey)
								.textFieldStyle(.roundedBorder)
							TextField("Team key", text: $viewModel.linearTeamKey)
								.textFieldStyle(.roundedBorder)
							HStack(spacing: 12) {
								Button("Save & Connect") { viewModel.connectLinear() }
									.buttonStyle(.bordered)
									.controlSize(.small)
								if let status = viewModel.linearTestMessage {
									StatusLabel(text: status, success: viewModel.linearTestSuccess ?? false)
								}
							}
						}
					}
					.padding(.top, 12)
				} label: {
					Label("Advanced Setup", systemImage: "wrench.and.screwdriver")
						.font(.subheadline)
						.foregroundStyle(.secondary)
				}
				.tint(.secondary)
				
				Spacer(minLength: 20)
			}
			.padding(28)
		}
		.onAppear { startAutoRefresh() }
		.onDisappear { stopAutoRefresh() }
	}
	
	// MARK: - Auto Refresh
	
	private func startAutoRefresh() {
		viewModel.refreshStatus(appName: "slack")
		viewModel.refreshStatus(appName: "linear")
		refreshTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
			viewModel.refreshStatus(appName: "slack")
			viewModel.refreshStatus(appName: "linear")
		}
	}
	
	private func stopAutoRefresh() {
		refreshTimer?.invalidate()
		refreshTimer = nil
	}
	
	// MARK: - Connect / Disconnect
	
	private func connectSlack() {
		slackError = nil
		slackLoading = true
		Task {
			let error = await viewModel.connectViaComposioAsync(appName: "slack")
			await MainActor.run {
				if let error = error {
					slackError = error
					slackLoading = false
				} else {
					pollUntilConnected(app: "slack") { slackLoading = false }
				}
			}
		}
	}
	
	private func connectLinear() {
		linearError = nil
		linearLoading = true
		Task {
			let error = await viewModel.connectViaComposioAsync(appName: "linear")
			await MainActor.run {
				if let error = error {
					linearError = error
					linearLoading = false
				} else {
					pollUntilConnected(app: "linear") { linearLoading = false }
				}
			}
		}
	}
	
	private func disconnectSlack() {
		slackLoading = true
		Task {
			await disconnectViaBackend(app: "slack")
			await MainActor.run {
				integrationService.disconnectSlack()
				slackLoading = false
				viewModel.refreshStatus(appName: "slack")
			}
		}
	}
	
	private func disconnectLinear() {
		linearLoading = true
		Task {
			await disconnectViaBackend(app: "linear")
			await MainActor.run {
				integrationService.disconnectLinear()
				linearLoading = false
				viewModel.refreshStatus(appName: "linear")
			}
		}
	}
	
	private func disconnectViaBackend(app: String) async {
		let urlString = "http://127.0.0.1:8000/api/v1/integrations/disconnect/\(app)?user_id=caddyai-default"
		guard let url = URL(string: urlString) else { return }
		var request = URLRequest(url: url)
		request.httpMethod = "DELETE"
		_ = try? await URLSession.shared.data(for: request)
	}
	
	private func pollUntilConnected(app: String, completion: @escaping () -> Void) {
		Task {
			for _ in 0..<30 {
				try? await Task.sleep(nanoseconds: 2_000_000_000)
				viewModel.refreshStatus(appName: app)
				try? await Task.sleep(nanoseconds: 500_000_000)
				
				let connected = await MainActor.run {
					app == "slack"
						? integrationService.slackState.isConnected
						: integrationService.linearState.isConnected
				}
				
				if connected {
					await MainActor.run { completion() }
					return
				}
			}
			await MainActor.run { completion() }
		}
	}
}

// MARK: - Integration Row Component

private struct IntegrationRow: View {
	let name: String
	let iconName: String
	let fallbackIcon: String
	let state: IntegrationState
	let isLoading: Bool
	let errorMessage: String?
	let accentColor: Color
	let onConnect: () -> Void
	let onDisconnect: () -> Void
	let showDivider: Bool
	@Environment(\.colorScheme) private var colorScheme
	
	private var palette: LiquidGlassPalette {
		LiquidGlassPalette(colorScheme: colorScheme)
	}
	
	var body: some View {
		VStack(spacing: 0) {
			HStack(spacing: 12) {
				// App icon
				appIcon
					.frame(width: 32, height: 32)
				
				Text(name)
					.font(.body)
				
				Spacer()
				
				// Status / Action
				if isLoading {
					ProgressView()
						.scaleEffect(0.7)
				} else if state.isConnected {
					HStack(spacing: 8) {
						HStack(spacing: 4) {
							Circle()
								.fill(Color.green)
								.frame(width: 6, height: 6)
							Text("Connected")
								.font(.caption)
								.foregroundStyle(.green)
						}
						
						Button {
							onDisconnect()
						} label: {
							Image(systemName: "xmark.circle.fill")
								.foregroundStyle(.secondary.opacity(0.6))
						}
						.buttonStyle(.plain)
					}
				} else {
					Button("Connect") {
						onConnect()
					}
					.buttonStyle(.borderedProminent)
					.controlSize(.small)
					.tint(accentColor)
				}
			}
			.padding(.horizontal, 16)
			.padding(.vertical, 12)
			
			// Error message
			if let errorMessage {
				HStack(spacing: 6) {
					Image(systemName: "exclamationmark.triangle.fill")
						.font(.caption)
						.foregroundStyle(.orange)
					Text(errorMessage)
						.font(.caption)
						.foregroundStyle(.orange)
						.lineLimit(1)
				}
				.padding(.horizontal, 16)
				.padding(.bottom, 8)
			}
			
			if showDivider {
				Divider()
					.padding(.leading, 60)
					.foregroundStyle(palette.divider)
			}
		}
	}
	
	@ViewBuilder
	private var appIcon: some View {
		if let nsImage = NSImage(named: iconName) {
			Image(nsImage: nsImage)
				.resizable()
				.aspectRatio(contentMode: .fit)
				.clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
		} else {
			ZStack {
				LiquidGlassSurface(shape: .roundedRect(6), prominence: .subtle, shadowed: false)
				Image(systemName: fallbackIcon)
					.font(.system(size: 14))
					.foregroundStyle(.secondary)
			}
		}
	}
}

// MARK: - About Settings View

private struct AboutSettingsView: View {
	@EnvironmentObject private var preferences: PreferencesStore
	@EnvironmentObject private var viewModel: SettingsViewModel
	
	private var appVersion: String {
		Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
	}
	
	var body: some View {
		ScrollView {
			VStack(spacing: 24) {
				// App Header
				VStack(spacing: 16) {
					// App Icon
					if let nsImage = NSImage(named: NSImage.applicationIconName) {
						Image(nsImage: nsImage)
							.resizable()
							.frame(width: 80, height: 80)
							.clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
							.shadow(color: .black.opacity(0.15), radius: 8, y: 4)
					}
					
					VStack(spacing: 4) {
						Text("caddyAI")
							.font(.title2.weight(.semibold))
						Text("Version \(appVersion)")
							.font(.caption)
							.foregroundStyle(.secondary)
					}
				}
				.padding(.top, 8)
				
				// Links
				HStack(spacing: 12) {
					LinkPill(title: "Website", icon: "globe", url: "https://caddyai.app")
					LinkPill(title: "GitHub", icon: "chevron.left.forwardslash.chevron.right", url: "https://github.com/caddyai")
				}
				
				// Changelog
				VStack(alignment: .leading, spacing: 16) {
					ForEach(changelog) { entry in
						ChangelogCard(entry: entry)
					}
				}
				.frame(maxWidth: .infinity, alignment: .leading)
				
				// Reset Section
				SettingsRowCard(title: "Reset") {
					SettingsRow(label: "Clear all settings", showDivider: false) {
						Button(role: .destructive) {
							viewModel.resetAll()
						} label: {
							Text("Reset")
						}
						.buttonStyle(.bordered)
						.tint(.red)
						.controlSize(.small)
					}
				}
				
				Spacer(minLength: 20)
			}
			.padding(28)
		}
	}
}

// MARK: - Link Pill

private struct LinkPill: View {
	let title: String
	let icon: String
	let url: String
	
	var body: some View {
		Button {
			if let url = URL(string: url) {
				NSWorkspace.shared.open(url)
			}
		} label: {
			HStack(spacing: 6) {
				Image(systemName: icon)
					.font(.caption.weight(.medium))
				Text(title)
					.font(.caption.weight(.medium))
			}
			.padding(.horizontal, 14)
			.padding(.vertical, 8)
			.background(
				LiquidGlassSurface(shape: .capsule, prominence: .subtle, shadowed: false)
			)
		}
		.buttonStyle(.plain)
	}
}

// MARK: - Changelog Card

private struct ChangelogCard: View {
	let entry: ChangelogEntry
	
	var body: some View {
		VStack(alignment: .leading, spacing: 12) {
			HStack {
				HStack(spacing: 6) {
					Text("📦")
					Text("Version \(entry.version)")
						.font(.subheadline.weight(.semibold))
				}
				Spacer()
				Text(entry.date)
					.font(.caption)
					.foregroundStyle(.secondary)
			}
			
			VStack(alignment: .leading, spacing: 6) {
				Text("FEATURES")
					.font(.caption2.weight(.semibold))
					.foregroundStyle(.secondary)
				
				ForEach(entry.features, id: \.self) { feature in
					HStack(alignment: .top, spacing: 8) {
						Text("•")
							.foregroundStyle(.secondary)
						Text(feature)
							.font(.subheadline)
					}
				}
			}
		}
		.padding(16)
		.frame(maxWidth: .infinity, alignment: .leading)
		.background(
			LiquidGlassSurface(shape: .roundedRect(12), prominence: .regular)
		)
	}
}

// MARK: - Helper Components

private struct KeyPillButton: View {
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

private struct ThemePillButton: View {
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

private struct StatusLabel: View {
	let text: String
	let success: Bool
	
	var body: some View {
		HStack(spacing: 6) {
			Circle()
				.fill(success ? Color.green : Color.orange)
				.frame(width: 8, height: 8)
			Text(text)
				.font(.caption)
				.foregroundStyle(.secondary)
		}
	}
}
