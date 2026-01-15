import SwiftUI

// MARK: - Settings Row Card

/// A card container with a title header for grouping related settings rows.
struct SettingsRowCard<Content: View>: View {
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

// MARK: - Settings Row

/// A horizontal row with a label and control, used within SettingsRowCard.
struct SettingsRow<Control: View>: View {
	let label: String
	let showDivider: Bool
	@ViewBuilder let control: Control
	@Environment(\.colorScheme) private var colorScheme
	@EnvironmentObject private var preferences: PreferencesStore
	
	private var palette: LiquidGlassPalette {
		LiquidGlassPalette(colorScheme: colorScheme, glassStyle: preferences.glassStyle)
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
