import SwiftUI

struct OnboardingView: View {
	@EnvironmentObject private var preferences: PreferencesStore
	@EnvironmentObject private var integrationService: IntegrationService
	@EnvironmentObject private var viewModel: SettingsViewModel
	@State private var step: Int = 0
	
	private let steps = [
		"Set your accent color and theme.",
		"Choose your model provider and key.",
		"Connect your integrations (Slack, Linear, Notion, GitHub, Gmail, Google Calendar)."
	]
	
	var body: some View {
		VStack(alignment: .leading, spacing: 16) {
			HStack {
				VStack(alignment: .leading, spacing: 6) {
					Text("Setup Wizard")
						.font(.title2).bold()
					Text("Complete the steps to finish configuring caddyAI from the menu bar.")
						.font(.subheadline)
						.foregroundStyle(.secondary)
				}
				Spacer()
				StatusPill(title: preferences.hasCompletedSetup ? "Ready" : "Needs setup", isOn: preferences.hasCompletedSetup)
			}
			
			Divider()
			
			VStack(alignment: .leading, spacing: 12) {
				ForEach(Array(steps.enumerated()), id: \.offset) { index, text in
					HStack(alignment: .top, spacing: 10) {
						Circle()
							.fill(index <= step ? preferences.accentColor : Color.gray.opacity(0.2))
							.frame(width: 26, height: 26)
							.overlay {
								Text("\(index + 1)")
									.font(.footnote.weight(.semibold))
									.foregroundStyle(index <= step ? .white : .primary)
							}
						Text(text)
							.font(.body)
							.foregroundStyle(index <= step ? .primary : .secondary)
					}
				}
			}
			
			Spacer()
			
			HStack {
				Button("Back") {
					step = max(step - 1, 0)
				}
				.buttonStyle(SettingsGlassButtonStyle())
				.disabled(step == 0)
				
				Spacer()
				
				Button(primaryButtonTitle) {
					advance()
				}
				.buttonStyle(SettingsGlassButtonStyle(kind: .accent(preferences.accentColor), prominence: .regular))
			}
		}
		.padding(24)
		.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
	}
	
	private var primaryButtonTitle: String {
		step == steps.count - 1 ? "Finish" : "Continue"
	}
	
	private func advance() {
		switch step {
		case 0:
			preferences.hasCompletedSetup = false
			step += 1
		case 1:
			viewModel.saveAPISettings()
			step += 1
		default:
			preferences.hasCompletedSetup = true
		}
	}
}
