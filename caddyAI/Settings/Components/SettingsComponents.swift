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
				LiquidGlassSurface(shape: .roundedRect(12), prominence: .regular, glassStyleOverride: .regular)
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
		LiquidGlassPalette(colorScheme: colorScheme, glassStyle: .regular)
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

// MARK: - Settings Glass Button Style

struct SettingsGlassButtonStyle: ButtonStyle {
	enum Kind {
		case neutral
		case accent(Color)
		case destructive(Color)
	}

	var kind: Kind = .neutral
	var prominence: LiquidGlassProminence = .subtle
	var cornerRadius: CGFloat = 10

	@Environment(\.colorScheme) private var colorScheme
	@Environment(\.controlSize) private var controlSize
	@Environment(\.isEnabled) private var isEnabled

	func makeBody(configuration: Configuration) -> some View {
		configuration.label
			.padding(.horizontal, horizontalPadding)
			.padding(.vertical, verticalPadding)
			.background(
				LiquidGlassSurface(
					shape: .roundedRect(cornerRadius),
					prominence: prominence,
					tint: tintColor,
					shadowed: false,
					glassStyleOverride: .regular
				)
			)
			.overlay(
				RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
					.stroke(borderColor, lineWidth: 1)
			)
			.foregroundStyle(foregroundColor)
			.opacity(isEnabled ? (configuration.isPressed ? 0.82 : 1) : 0.5)
	}

	private var horizontalPadding: CGFloat {
		switch controlSize {
		case .mini: 8
		case .small: 10
		case .regular: 14
		case .large: 16
		@unknown default: 14
		}
	}

	private var verticalPadding: CGFloat {
		switch controlSize {
		case .mini: 4
		case .small: 6
		case .regular: 8
		case .large: 10
		@unknown default: 8
		}
	}

	private var borderColor: Color {
		switch kind {
		case .accent(let color):
			return color.opacity(0.55)
		case .destructive(let color):
			return color.opacity(0.5)
		case .neutral:
			return colorScheme == .dark ? Color.white.opacity(0.18) : Color.black.opacity(0.16)
		}
	}

	private var tintColor: Color? {
		switch kind {
		case .accent(let color):
			return color.opacity(0.12)
		case .destructive(let color):
			return color.opacity(0.1)
		case .neutral:
			return nil
		}
	}

	private var foregroundColor: Color {
		switch kind {
		case .accent(let color):
			return color
		case .destructive(let color):
			return color
		case .neutral:
			return .primary
		}
	}
}
