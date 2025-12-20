import SwiftUI
import AVFoundation
import ApplicationServices

struct AppSettingsView: View {
	@EnvironmentObject private var preferences: PreferencesStore
	@EnvironmentObject private var integrationService: IntegrationService
	@EnvironmentObject private var viewModel: SettingsViewModel
	
	var body: some View {
		NavigationSplitView {
			List(selection: $viewModel.selectedSection) {
				ForEach(SettingsSection.allCases) { section in
					Label(section.label, systemImage: section.icon)
						.tag(section)
				}
			}
			.listStyle(.sidebar)
			.frame(minWidth: 200)
		} detail: {
			switch viewModel.selectedSection {
			case .general:
				GeneralSettingsView()
			case .api:
				APISettingsView()
			case .integrations:
				IntegrationsSettingsView()
			case .onboarding:
				OnboardingSettingsView()
			}
		}
		.tint(preferences.accentColor)
		.navigationTitle("Settings")
		.toolbar {
			// Suppress the default sidebar toggle/primary toolbar controls for a simpler window
			ToolbarItem(placement: .navigation) { EmptyView() }
			ToolbarItem(placement: .primaryAction) { EmptyView() }
		}
		.navigationSplitViewStyle(.balanced)
		.onAppear { viewModel.loadPersistedValues() }
	}
}

private struct GeneralSettingsView: View {
	@EnvironmentObject private var preferences: PreferencesStore
	@EnvironmentObject private var viewModel: SettingsViewModel
	
	var body: some View {
		ScrollView {
			VStack(alignment: .leading, spacing: 16) {
				Text("General")
					.font(.title2).bold()
				
				Divider()
				
				VStack(alignment: .leading, spacing: 12) {
					Text("Accent Color")
						.font(.headline)
					HStack {
						ForEach(viewModel.accentOptions) { option in
							Button {
								viewModel.selectAccent(option)
							} label: {
								Circle()
									.fill(option.color)
									.frame(width: 32, height: 32)
									.overlay(
										Circle().stroke(.white.opacity(preferences.accentColorHex == option.hex ? 0.9 : 0.2), lineWidth: 2)
									)
									.overlay {
										if preferences.accentColorHex == option.hex {
											Image(systemName: "checkmark.circle.fill")
												.font(.system(size: 16, weight: .semibold))
												.foregroundStyle(.white, Color.black.opacity(0.2))
										}
									}
							}
							.buttonStyle(.plain)
						}
					}
				}
				
				VStack(alignment: .leading, spacing: 12) {
					Text("Appearance")
						.font(.headline)
					
					HStack(spacing: 12) {
						ForEach(ThemePreference.allCases) { theme in
							Button {
								viewModel.selectTheme(theme)
							} label: {
								VStack {
									Image(systemName: themeIcon(theme))
										.font(.system(size: 18, weight: .semibold))
									Text(theme.label)
										.font(.caption)
								}
								.frame(maxWidth: .infinity)
								.padding()
								.background(
									RoundedRectangle(cornerRadius: 10, style: .continuous)
										.fill(preferences.theme == theme ? preferences.accentColor.opacity(0.12) : Color.clear)
								)
								.overlay {
									RoundedRectangle(cornerRadius: 10, style: .continuous)
										.stroke(preferences.theme == theme ? preferences.accentColor : Color.gray.opacity(0.3), lineWidth: 1)
								}
							}
							.buttonStyle(.plain)
						}
					}
				}
				
				PermissionsCard()
				
				Spacer()
			}
			.padding(24)
		}
	}
	
	private func themeIcon(_ theme: ThemePreference) -> String {
		switch theme {
		case .system: "aqi.medium"
		case .light: "sun.max.fill"
		case .dark: "moon.stars.fill"
		}
	}
}

private struct APISettingsView: View {
	@EnvironmentObject private var preferences: PreferencesStore
	@EnvironmentObject private var viewModel: SettingsViewModel
	@State private var saveMessage: String?
	
	var body: some View {
		Form {
			Section("LLM / Agent API") {
				Text("Paste your provider API key. If self-hosted, add the Base URL. We keep keys locally in Keychain.")
					.font(.footnote)
					.foregroundStyle(.secondary)
				
				TextField("API key", text: $viewModel.apiKey)
					.textFieldStyle(.roundedBorder)
				TextField("Base URL (optional)", text: $viewModel.apiBaseURL)
					.textFieldStyle(.roundedBorder)
				HStack {
					Button("Save") {
						viewModel.saveAPISettings()
						saveMessage = "Saved"
					}
					.buttonStyle(.borderedProminent)
					
					if let saveMessage {
						Text(saveMessage)
							.font(.caption)
							.foregroundStyle(.secondary)
					}
				}
				
				HStack(spacing: 12) {
					Button("Test connection") {
						viewModel.testAPI()
					}
					.buttonStyle(.bordered)
					
					if let status = viewModel.apiTestMessage {
						StatusLabel(text: status, success: viewModel.apiTestSuccess ?? false)
					}
				}
			}
			
			Section("Reset") {
				Button(role: .destructive) {
					viewModel.resetAll()
					saveMessage = "Reset to defaults"
				} label: {
					Label("Reset setup data", systemImage: "arrow.uturn.backward.circle")
				}
			}
		}
		.padding(24)
		.formStyle(.grouped)
		.navigationTitle("API & Accounts")
	}
}

private struct IntegrationsSettingsView: View {
	@EnvironmentObject private var integrationService: IntegrationService
	@EnvironmentObject private var viewModel: SettingsViewModel
	@EnvironmentObject private var preferences: PreferencesStore
	
	var body: some View {
		ScrollView {
			VStack(alignment: .leading, spacing: 20) {
				Text("Integrations")
					.font(.title2).bold()
				
				Divider()
				
				IntegrationCard(
					title: "Slack",
					description: "Connect Slack to post updates and receive alerts directly from caddyAI.",
					state: integrationService.slackState,
					connectAction: viewModel.connectSlack,
					disconnectAction: viewModel.disconnectSlack
				) {
					SecureField("Bot/User token (xoxb-…)", text: $viewModel.slackToken)
						.textFieldStyle(.roundedBorder)
						.textContentType(.password)
					Text("Tip: Create a Slack app → OAuth & Permissions → Bot token scopes, then copy the xoxb token.")
						.font(.footnote)
						.foregroundStyle(.secondary)
					HStack(spacing: 12) {
						Button("Test Slack") { viewModel.testSlack() }
							.buttonStyle(.bordered)
						if let status = viewModel.slackTestMessage {
							StatusLabel(text: status, success: viewModel.slackTestSuccess ?? false)
						}
					}
				}
				
				IntegrationCard(
					title: "Linear",
					description: "Sync with Linear to create issues and track status from the tray.",
					state: integrationService.linearState,
					connectAction: viewModel.connectLinear,
					disconnectAction: viewModel.disconnectLinear
				) {
					SecureField("API key", text: $viewModel.linearApiKey)
						.textFieldStyle(.roundedBorder)
					TextField("Team key", text: $viewModel.linearTeamKey)
						.textFieldStyle(.roundedBorder)
					Text("Tip: In Linear, go to Settings → API to generate a personal API key. Team key is the team URL slug.")
						.font(.footnote)
						.foregroundStyle(.secondary)
					HStack(spacing: 12) {
						Button("Test Linear") { viewModel.testLinear() }
							.buttonStyle(.bordered)
						if let status = viewModel.linearTestMessage {
							StatusLabel(text: status, success: viewModel.linearTestSuccess ?? false)
						}
					}
				}
			}
			.padding(24)
		}
	}
}

private struct OnboardingSettingsView: View {
	@EnvironmentObject private var preferences: PreferencesStore
	@EnvironmentObject private var viewModel: SettingsViewModel
	@EnvironmentObject private var integrationService: IntegrationService
	
	var body: some View {
		OnboardingView()
			.environmentObject(preferences)
			.environmentObject(integrationService)
			.environmentObject(viewModel)
	}
}

private struct PermissionsCard: View {
	@State private var microphoneStatus: AVAuthorizationStatus = .notDetermined
	
	var body: some View {
		VStack(alignment: .leading, spacing: 12) {
			Text("Permissions")
				.font(.headline)
			
			HStack(spacing: 12) {
				StatusPill(
					title: "Microphone",
					isOn: microphoneStatus == .authorized,
					action: requestMicrophone
				)
				
				StatusPill(
					title: "Accessibility",
					isOn: AXIsProcessTrusted(),
					action: openAccessibilityPrefs
				)
			}
			.font(.body)
			.onAppear {
				microphoneStatus = AVCaptureDevice.authorizationStatus(for: .audio)
			}
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

private struct IntegrationCard<Content: View>: View {
	let title: String
	let description: String
	let state: IntegrationState
	let connectAction: () -> Void
	let disconnectAction: () -> Void
	@ViewBuilder let content: Content
	
	var body: some View {
		VStack(alignment: .leading, spacing: 12) {
			HStack {
				Text(title)
					.font(.headline)
				Spacer()
				StatusBadge(state: state)
			}
			
			Text(description)
				.font(.subheadline)
				.foregroundStyle(.secondary)
			
			content
			
			HStack {
				Button("Connect") {
					connectAction()
				}
				.buttonStyle(.borderedProminent)
				
				Button("Disconnect", role: .destructive) {
					disconnectAction()
				}
				.buttonStyle(.bordered)
				.disabled(!state.isConnected)
				
				Spacer()
			}
		}
		.padding()
		.background(
			RoundedRectangle(cornerRadius: 12, style: .continuous)
				.fill(Color(NSColor.windowBackgroundColor))
		)
		.overlay {
			RoundedRectangle(cornerRadius: 12, style: .continuous)
				.stroke(Color.gray.opacity(0.15), lineWidth: 1)
		}
	}
}

private struct StatusBadge: View {
	let state: IntegrationState
	
	var body: some View {
		HStack(spacing: 8) {
			Circle()
				.fill(color)
				.frame(width: 10, height: 10)
			Text(state.label)
				.font(.caption)
				.foregroundStyle(.secondary)
		}
		.padding(.vertical, 6)
		.padding(.horizontal, 10)
		.background(
			RoundedRectangle(cornerRadius: 8, style: .continuous)
				.fill(color.opacity(0.12))
		)
	}
	
	private var color: Color {
		switch state {
		case .connected: .green
		case .disconnected: .gray
		case .error: .orange
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

