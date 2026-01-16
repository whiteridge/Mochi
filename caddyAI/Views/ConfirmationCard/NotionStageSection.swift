import SwiftUI
import Foundation

struct NotionStageSection: View {
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
                Text(titleDisplay)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(palette.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
                
                if let content = notionContentDisplay {
                    ScrollableTextArea(maxHeight: 160, indicatorColor: palette.subtleBorder.opacity(0.35)) {
                        if let markdown = notionAttributedText(from: content) {
                            Text(markdown)
                                .font(.system(size: 14, weight: .regular))
                                .foregroundStyle(palette.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        } else {
                            Text(content)
                                .font(.system(size: 14, weight: .regular))
                                .foregroundStyle(palette.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                } else {
                    Text("No page content provided.")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(palette.tertiaryText)
                }
                
                if !notionMetadataItems.isEmpty {
					LazyVGrid(columns: stageMetadataColumns, alignment: .leading, spacing: 12) {
						ForEach(Array(notionMetadataItems.enumerated()), id: \.offset) { _, item in
							NotionMetadataGridItem(item: item)
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
    
    // MARK: - Notion Display Helpers
    
    private var titleDisplay: String {
        if let title = proposal.notionTitle?.trimmingCharacters(in: .whitespacesAndNewlines),
           !title.isEmpty {
            return title
        }
        return "Untitled Page"
    }
    
    private var contentPreview: String? {
        if let content = proposal.notionContent?.trimmingCharacters(in: .whitespacesAndNewlines),
           !content.isEmpty {
            return content
        }
        return nil
    }

    private var notionContentDisplay: String? {
        guard let content = contentPreview else { return nil }
        var output = content
        output = output.replacingOccurrences(of: "\\r\\n", with: "\n")
        output = output.replacingOccurrences(of: "\\n", with: "\n")
        output = output.replacingOccurrences(of: "\\t", with: "\t")
        return output
    }

    private func notionAttributedText(from text: String) -> AttributedString? {
        let options = AttributedString.MarkdownParsingOptions(
            interpretedSyntax: .inlineOnlyPreservingWhitespace
        )
        return try? AttributedString(markdown: text, options: options)
    }
    
	struct NotionMetadataItem {
		let title: String
		let value: String
		let tint: Color
	}

	private var notionParentTint: Color {
		Color(red: 0.45, green: 0.6, blue: 0.9)
	}

	private var notionIconTint: Color {
		Color(red: 0.98, green: 0.72, blue: 0.32)
	}

	private var notionStatusTint: Color {
		Color(red: 0.34, green: 0.6, blue: 0.96)
	}

	private var notionNeutralTint: Color {
		Color(red: 0.52, green: 0.6, blue: 0.76)
	}

	private var notionTagTint: Color {
		Color(red: 0.3, green: 0.66, blue: 0.84)
	}

	private var notionPeopleTint: Color {
		Color(red: 0.24, green: 0.72, blue: 0.62)
	}

	private var notionDateTint: Color {
		Color(red: 0.72, green: 0.52, blue: 0.95)
	}

	private var notionPriorityHighTint: Color {
		Color(red: 0.96, green: 0.38, blue: 0.36)
	}

	private var notionPriorityMediumTint: Color {
		Color(red: 0.98, green: 0.62, blue: 0.32)
	}

	private var notionPriorityLowTint: Color {
		Color(red: 0.26, green: 0.74, blue: 0.52)
	}

    private var notionMetadataItems: [NotionMetadataItem] {
        var items: [NotionMetadataItem] = []
        
        if let parent = proposal.notionParentId?.trimmingCharacters(in: .whitespacesAndNewlines),
           !parent.isEmpty {
            items.append(NotionMetadataItem(title: "Parent", value: parent, tint: notionParentTint))
        }
        
        if let icon = proposal.notionIcon?.trimmingCharacters(in: .whitespacesAndNewlines),
           !icon.isEmpty,
           icon.count <= 3 {
            items.append(NotionMetadataItem(title: "Icon", value: icon, tint: notionIconTint))
        }
        
        items.append(contentsOf: proposal.notionPropertyPairs.map { title, value in
			NotionMetadataItem(title: title, value: value, tint: notionTint(for: title, value: value))
		})
        return Array(items.prefix(4))
    }

	private func notionTint(for title: String, value: String) -> Color {
		let key = title.lowercased()
		let val = value.lowercased()

		if key.contains("status") || key.contains("state") {
			return notionStatusTint(for: val)
		}
		if key.contains("priority") || key.contains("urgency") {
			return notionPriorityTint(for: val)
		}
		if key.contains("due") || key.contains("date") || key.contains("deadline") {
			return notionDateTint
		}
		if key.contains("owner") || key.contains("assignee") || key.contains("person") || key.contains("people") {
			return notionPeopleTint
		}
		if key.contains("tag") || key.contains("label") || key.contains("category") {
			return notionTagTint
		}
		return notionNeutralTint
	}

	private func notionStatusTint(for value: String) -> Color {
		if value.contains("done") || value.contains("complete") || value.contains("closed") || value.contains("resolved") {
			return notionPriorityLowTint
		}
		if value.contains("blocked") || value.contains("stuck") || value.contains("error") {
			return notionPriorityHighTint
		}
		if value.contains("progress") || value.contains("doing") || value.contains("active") || value.contains("review") {
			return notionStatusTint
		}
		if value.contains("todo") || value.contains("backlog") || value.contains("planned") {
			return notionNeutralTint
		}
		return notionStatusTint
	}

	private func notionPriorityTint(for value: String) -> Color {
		if value.contains("high") || value.contains("urgent") || value.contains("critical") || value.contains("p0") || value.contains("p1") {
			return notionPriorityHighTint
		}
		if value.contains("medium") || value.contains("p2") {
			return notionPriorityMediumTint
		}
		if value.contains("low") || value.contains("p3") || value.contains("p4") {
			return notionPriorityLowTint
		}
		return notionPriorityMediumTint
	}
}

private struct NotionMetadataGridItem: View {
	let item: NotionStageSection.NotionMetadataItem
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
