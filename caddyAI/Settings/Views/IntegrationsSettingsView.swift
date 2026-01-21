import SwiftUI

// MARK: - Integrations Settings View

struct IntegrationsSettingsView: View {
	@EnvironmentObject private var integrationService: IntegrationService
	@EnvironmentObject private var viewModel: SettingsViewModel
	@EnvironmentObject private var preferences: PreferencesStore
	
	@State private var slackLoading = false
	@State private var linearLoading = false
	@State private var notionLoading = false
	@State private var githubLoading = false
	@State private var gmailLoading = false
	@State private var googleCalendarLoading = false
	@State private var slackError: String?
	@State private var linearError: String?
	@State private var notionError: String?
	@State private var githubError: String?
	@State private var gmailError: String?
	@State private var googleCalendarError: String?
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
						showDivider: true
					)
					
					// Notion Row
					IntegrationRow(
						name: "Notion",
						iconName: "notion-icon",
						fallbackIcon: "doc.text",
						state: integrationService.notionState,
						isLoading: notionLoading,
						errorMessage: notionError,
						accentColor: preferences.accentColor,
						onConnect: connectNotion,
						onDisconnect: disconnectNotion,
						showDivider: true
					)
					
					// GitHub Row
					IntegrationRow(
						name: "GitHub",
						iconName: "github-icon",
						fallbackIcon: "chevron.left.forwardslash.chevron.right",
						state: integrationService.githubState,
						isLoading: githubLoading,
						errorMessage: githubError,
						accentColor: preferences.accentColor,
						onConnect: connectGitHub,
						onDisconnect: disconnectGitHub,
						showDivider: true
					)
					
					// Gmail Row
					IntegrationRow(
						name: "Gmail",
						iconName: "gmail-icon",
						fallbackIcon: "envelope.fill",
						state: integrationService.gmailState,
						isLoading: gmailLoading,
						errorMessage: gmailError,
						accentColor: preferences.accentColor,
						onConnect: connectGmail,
						onDisconnect: disconnectGmail,
						showDivider: true
					)
					
					// Google Calendar Row
					IntegrationRow(
						name: "Google Calendar",
						iconName: "calendar-icon",
						fallbackIcon: "calendar",
						state: integrationService.googleCalendarState,
						isLoading: googleCalendarLoading,
						errorMessage: googleCalendarError,
						accentColor: preferences.accentColor,
						onConnect: connectGoogleCalendar,
						onDisconnect: disconnectGoogleCalendar,
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
		viewModel.refreshStatus(appName: "notion")
		viewModel.refreshStatus(appName: "github")
		viewModel.refreshStatus(appName: "gmail")
		viewModel.refreshStatus(appName: "googlecalendar")
		refreshTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
			viewModel.refreshStatus(appName: "slack")
			viewModel.refreshStatus(appName: "linear")
			viewModel.refreshStatus(appName: "notion")
			viewModel.refreshStatus(appName: "github")
			viewModel.refreshStatus(appName: "gmail")
			viewModel.refreshStatus(appName: "googlecalendar")
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

	private func connectNotion() {
		notionError = nil
		notionLoading = true
		Task {
			let error = await viewModel.connectViaComposioAsync(appName: "notion")
			await MainActor.run {
				if let error = error {
					notionError = error
					notionLoading = false
				} else {
					pollUntilConnected(app: "notion") { notionLoading = false }
				}
			}
		}
	}

	private func connectGitHub() {
		githubError = nil
		githubLoading = true
		Task {
			let error = await viewModel.connectViaComposioAsync(appName: "github")
			await MainActor.run {
				if let error = error {
					githubError = error
					githubLoading = false
				} else {
					pollUntilConnected(app: "github") { githubLoading = false }
				}
			}
		}
	}

	private func connectGmail() {
		gmailError = nil
		gmailLoading = true
		Task {
			let error = await viewModel.connectViaComposioAsync(appName: "gmail")
			await MainActor.run {
				if let error = error {
					gmailError = error
					gmailLoading = false
				} else {
					pollUntilConnected(app: "gmail") { gmailLoading = false }
				}
			}
		}
	}

	private func connectGoogleCalendar() {
		googleCalendarError = nil
		googleCalendarLoading = true
		Task {
			let error = await viewModel.connectViaComposioAsync(appName: "googlecalendar")
			await MainActor.run {
				if let error = error {
					googleCalendarError = error
					googleCalendarLoading = false
				} else {
					pollUntilConnected(app: "googlecalendar") { googleCalendarLoading = false }
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

	private func disconnectNotion() {
		notionLoading = true
		Task {
			await disconnectViaBackend(app: "notion")
			await MainActor.run {
				integrationService.disconnectNotion()
				notionLoading = false
				viewModel.refreshStatus(appName: "notion")
			}
		}
	}

	private func disconnectGitHub() {
		githubLoading = true
		Task {
			await disconnectViaBackend(app: "github")
			await MainActor.run {
				integrationService.disconnectGitHub()
				githubLoading = false
				viewModel.refreshStatus(appName: "github")
			}
		}
	}

	private func disconnectGmail() {
		gmailLoading = true
		Task {
			await disconnectViaBackend(app: "gmail")
			await MainActor.run {
				integrationService.disconnectGmail()
				gmailLoading = false
				viewModel.refreshStatus(appName: "gmail")
			}
		}
	}

	private func disconnectGoogleCalendar() {
		googleCalendarLoading = true
		Task {
			await disconnectViaBackend(app: "googlecalendar")
			await MainActor.run {
				integrationService.disconnectGoogleCalendar()
				googleCalendarLoading = false
				viewModel.refreshStatus(appName: "googlecalendar")
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
					switch app {
					case "slack":
						return integrationService.slackState.isConnected
					case "linear":
						return integrationService.linearState.isConnected
					case "notion":
						return integrationService.notionState.isConnected
					case "github":
						return integrationService.githubState.isConnected
					case "gmail":
						return integrationService.gmailState.isConnected
					case "googlecalendar", "google_calendar":
						return integrationService.googleCalendarState.isConnected
					default:
						return false
					}
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

struct IntegrationRow: View {
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
	@EnvironmentObject private var preferences: PreferencesStore
	
	private var palette: LiquidGlassPalette {
		LiquidGlassPalette(colorScheme: colorScheme, glassStyle: .regular)
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
				LiquidGlassSurface(shape: .roundedRect(6), prominence: .subtle, shadowed: false, glassStyleOverride: .regular)
				Image(systemName: fallbackIcon)
					.font(.system(size: 14))
					.foregroundStyle(.secondary)
			}
		}
	}
}

// MARK: - Status Label

struct StatusLabel: View {
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
