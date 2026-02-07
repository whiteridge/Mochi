import SwiftUI

struct StatusPill: View {
	let title: String
	let isOn: Bool
	var action: (() -> Void)? = nil
	@Environment(\.colorScheme) private var colorScheme
	@EnvironmentObject private var preferences: PreferencesStore
	
	private var palette: LiquidGlassPalette {
		LiquidGlassPalette(colorScheme: colorScheme, glassStyle: .regular)
	}
	
	var body: some View {
		HStack(spacing: 8) {
			Circle()
				.fill(isOn ? Color.green : Color.gray.opacity(0.5))
				.frame(width: 10, height: 10)
			Text(title)
				.font(.caption)
				.foregroundStyle(palette.primaryText)
			if let action {
				Button(isOn ? "Review" : "Enable", action: action)
					.buttonStyle(SettingsGlassButtonStyle(kind: .accent(preferences.accentColor)))
					.controlSize(.mini)
			}
		}
		.padding(.horizontal, 10)
		.padding(.vertical, 6)
		.background(
			LiquidGlassSurface(shape: .roundedRect(10), prominence: .subtle, shadowed: false, glassStyleOverride: .regular)
		)
	}
}
