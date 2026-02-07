import SwiftUI

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

// MARK: - About Settings View

struct AboutSettingsView: View {
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
						Text("mochi")
							.font(.title2.weight(.semibold))
						Text("Version \(appVersion)")
							.font(.caption)
							.foregroundStyle(.secondary)
					}
				}
				.padding(.top, 8)
				
				// Links
				HStack(spacing: 12) {
					LinkPill(title: "Website", icon: "globe", url: "https://mochi.app")
					LinkPill(title: "GitHub", icon: "chevron.left.forwardslash.chevron.right", url: "https://github.com/mochi")
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
						.buttonStyle(SettingsGlassButtonStyle(kind: .destructive(.red)))
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

struct LinkPill: View {
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
				LiquidGlassSurface(shape: .capsule, prominence: .subtle, shadowed: false, glassStyleOverride: .regular)
			)
		}
		.buttonStyle(.plain)
	}
}

// MARK: - Changelog Card

struct ChangelogCard: View {
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
			LiquidGlassSurface(shape: .roundedRect(12), prominence: .regular, glassStyleOverride: .regular)
		)
	}
}
