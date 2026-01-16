import SwiftUI
import Foundation

struct SlackStageSection: View {
    let proposal: ProposalData
    let stageCornerRadius: CGFloat
    let stageMetadataColumns: [GridItem]
    
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var preferences: PreferencesStore
    
    private var palette: LiquidGlassPalette {
        LiquidGlassPalette(colorScheme: colorScheme, glassStyle: preferences.glassStyle)
    }
    
    var body: some View {
        stageContainer {
            VStack(alignment: .leading, spacing: 12) {
                if let messageText = slackMessageDisplay {
                    ScrollableTextArea(maxHeight: 140, indicatorColor: palette.subtleBorder.opacity(0.35)) {
                        if let markdown = slackAttributedText(from: messageText) {
                            Text(markdown)
                                .font(.system(size: 15, weight: .regular))
                                .foregroundStyle(palette.primaryText)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        } else {
                            Text(messageText)
                                .font(.system(size: 15, weight: .regular))
                                .foregroundStyle(palette.primaryText)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                
                if !slackMetadataItems.isEmpty {
					LazyVGrid(columns: stageMetadataColumns, alignment: .leading, spacing: 12) {
						ForEach(slackMetadataItems, id: \.title) { item in
							SlackMetadataGridItem(item: item)
						}
					}
                }
            }
        }
    }
    
    // MARK: - Stage Container
    
    @ViewBuilder
    private func stageContainer<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(16)
            .background(stageBackground)
            .clipShape(RoundedRectangle(cornerRadius: stageCornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: stageCornerRadius, style: .continuous)
                    .stroke(palette.subtleBorder.opacity(0.6), lineWidth: 0.5)
            )
    }
    
    @ViewBuilder
    private var stageBackground: some View {
        ZStack {
            LiquidGlassSurface(shape: .roundedRect(stageCornerRadius), prominence: .subtle, shadowed: false)
            if preferences.glassStyle == .clear {
                RoundedRectangle(cornerRadius: stageCornerRadius, style: .continuous)
                    .fill(Color.black.opacity(colorScheme == .dark ? 0.2 : 0.07))
            }
        }
    }
    
    // MARK: - Slack Display Helpers
    
    var slackChannelDisplay: String? {
        // Prefer enriched channelName from backend
        if let channelName = proposal.channel?.nilIfEmpty {
            // Ensure it has # prefix for channels
            let name = channelName.trimmingCharacters(in: .whitespacesAndNewlines)
            if name.hasPrefix("#") || name.hasPrefix("@") {
                return name
            }
            // If it's a channel ID (starts with C), just show generic text
            if name.hasPrefix("C") && name.count > 8 {
                return nil // Will be resolved by backend enrichment
            }
            return "#\(name)"
        }
        return nil
    }

    var slackRecipientDisplay: String? {
        guard let userName = proposal.userName?.nilIfEmpty else { return nil }
        if userName.hasPrefix("@") {
            return userName
        }
        if userName.hasPrefix("U") && userName.count > 8 {
            return nil
        }
        return "@\(userName)"
    }

    var slackScheduleDisplay: String? {
        guard let scheduledTime = proposal.scheduledTime else { return nil }
        let date = Date(timeIntervalSince1970: TimeInterval(scheduledTime))
        return Self.slackScheduleFormatter.string(from: date)
    }

	struct SlackMetadataItem {
		let title: String
		let value: String
		let tint: Color
	}

	private var slackChannelTint: Color {
		Color(red: 0.36, green: 0.58, blue: 0.96)
	}

	private var slackRecipientTint: Color {
		Color(red: 0.26, green: 0.74, blue: 0.62)
	}

	private var slackScheduleTint: Color {
		Color(red: 0.98, green: 0.7, blue: 0.34)
	}

    var slackMetadataItems: [SlackMetadataItem] {
        var items: [SlackMetadataItem] = []
        if let channel = slackChannelDisplay {
            items.append(SlackMetadataItem(title: "Channel", value: channel, tint: slackChannelTint))
        }
        if let recipient = slackRecipientDisplay {
            items.append(SlackMetadataItem(title: "Recipient", value: recipient, tint: slackRecipientTint))
        }
        if let schedule = slackScheduleDisplay {
            items.append(SlackMetadataItem(title: "Schedule", value: schedule, tint: slackScheduleTint))
        }
        return items
    }

    private var slackMessageDisplay: String? {
        guard let messageText = proposal.messageText?.trimmingCharacters(in: .whitespacesAndNewlines),
              !messageText.isEmpty else {
            return nil
        }
        var output = messageText
        output = output.replacingOccurrences(of: "\\r\\n", with: "\n")
        output = output.replacingOccurrences(of: "\\n", with: "\n")
        output = output.replacingOccurrences(of: "\\t", with: "\t")
        output = replaceSlackLinks(in: output)
        return output
    }

    private func slackAttributedText(from text: String) -> AttributedString? {
        let options = AttributedString.MarkdownParsingOptions(
            interpretedSyntax: .inlineOnlyPreservingWhitespace
        )
        return try? AttributedString(markdown: text, options: options)
    }

    private func replaceSlackLinks(in text: String) -> String {
        var output = text
        output = replaceRegex(in: output, pattern: #"<([^>|]+)\|([^>]+)>"#) { match, source in
            let url = source.substring(with: match.range(at: 1))
            let label = source.substring(with: match.range(at: 2))
            return "[\(label)](\(url))"
        }
        output = replaceRegex(in: output, pattern: #"<(https?://[^>]+)>"#) { match, source in
            let url = source.substring(with: match.range(at: 1))
            return "[\(url)](\(url))"
        }
        return output
    }

    private func replaceRegex(
        in text: String,
        pattern: String,
        replacement: (NSTextCheckingResult, NSString) -> String
    ) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return text
        }
        let source = text as NSString
        var output = text
        let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: source.length))
        for match in matches.reversed() {
            let value = replacement(match, source)
            output = (output as NSString).replacingCharacters(in: match.range, with: value)
        }
        return output
    }
    
    private static let slackScheduleFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}

private struct SlackMetadataGridItem: View {
	let item: SlackStageSection.SlackMetadataItem
	@Environment(\.colorScheme) private var colorScheme
	@EnvironmentObject private var preferences: PreferencesStore

	private var palette: LiquidGlassPalette {
		LiquidGlassPalette(colorScheme: colorScheme, glassStyle: preferences.glassStyle)
	}

	private var glowOpacity: Double {
		colorScheme == .dark ? 0.45 : 0.28
	}

	private var glowWidth: CGFloat {
		120
	}

	private var glowBlur: CGFloat {
		12
	}

	private var strokeOpacity: Double {
		colorScheme == .dark ? 0.35 : 0.22
	}

	private var barOpacity: Double {
		colorScheme == .dark ? 0.85 : 0.65
	}

	private var barShadowOpacity: Double {
		colorScheme == .dark ? 0.45 : 0.3
	}

	private var valueOpacity: Double {
		colorScheme == .dark ? 0.9 : 0.85
	}

	var body: some View {
		HStack(alignment: .top, spacing: 12) {
			RoundedRectangle(cornerRadius: 2, style: .continuous)
				.fill(item.tint.opacity(barOpacity))
				.frame(width: 4)
				.padding(.vertical, 4)
				.shadow(color: item.tint.opacity(barShadowOpacity), radius: 6, x: 0, y: 0)

			VStack(alignment: .leading, spacing: 4) {
				Text(item.title.uppercased())
					.font(.system(size: 10, weight: .medium))
					.foregroundStyle(palette.tertiaryText)

				Text(item.value)
					.font(.system(size: 13, weight: .semibold))
					.foregroundStyle(item.tint.opacity(valueOpacity))
					.lineLimit(1)
			}
		}
		.padding(.vertical, 8)
		.padding(.horizontal, 10)
		.frame(maxWidth: .infinity, alignment: .leading)
		.background(
			ZStack(alignment: .leading) {
				LiquidGlassSurface(shape: .roundedRect(12), prominence: .subtle, shadowed: false)
				Rectangle()
					.fill(
						LinearGradient(
							colors: [
								item.tint.opacity(glowOpacity),
								item.tint.opacity(0)
							],
							startPoint: .leading,
							endPoint: .trailing
						)
					)
					.frame(width: glowWidth)
					.blur(radius: glowBlur)
			}
		)
		.clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
		.overlay(
			RoundedRectangle(cornerRadius: 12, style: .continuous)
				.stroke(item.tint.opacity(strokeOpacity), lineWidth: 0.6)
		)
	}
}

// MARK: - Slack Action Buttons

struct SlackActionButtons: View {
    let proposal: ProposalData
    let isExecuting: Bool
    let onConfirm: () -> Void
    var gradientNamespace: Namespace.ID? = nil
    
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var preferences: PreferencesStore
    
    private var palette: LiquidGlassPalette {
        LiquidGlassPalette(colorScheme: colorScheme, glassStyle: preferences.glassStyle)
    }
    
    var isScheduledMessage: Bool {
        proposal.tool.lowercased().contains("schedule")
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Primary "Send" button
            ActionGlowButton(
                title: "Send",
                isExecuting: isExecuting,
                action: {
                    NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)
                    onConfirm()
                },
                gradientNamespace: gradientNamespace
            )
            
            // Secondary "Schedule message" button (only for scheduled message tool)
            if isScheduledMessage {
                Button {
                    // Schedule action - same as confirm for scheduled messages
                    NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)
                    onConfirm()
                } label: {
                    Text("Schedule message")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(palette.primaryText)
                        .padding(.horizontal, 20)
                        .frame(height: 48)
                        .background(
                            LiquidGlassSurface(shape: .capsule, prominence: .subtle, shadowed: false)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - String Extension

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

private extension Optional where Wrapped == String {
    var nilIfEmpty: String? {
        switch self {
        case .some(let value):
            return value.nilIfEmpty
        case .none:
            return nil
        }
    }
}
