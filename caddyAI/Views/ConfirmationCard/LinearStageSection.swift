import SwiftUI
import Foundation

struct LinearStageSection: View {
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
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(titleDisplay)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(palette.primaryText)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer(minLength: 0)
                }
                
                if let description = linearDescriptionDisplay {
                    ScrollableTextArea(maxHeight: 140, indicatorColor: palette.subtleBorder.opacity(0.35)) {
                        if let markdown = linearAttributedText(from: description) {
                            Text(markdown)
                                .font(.system(size: 14, weight: .regular))
                                .foregroundStyle(palette.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        } else {
                            Text(description)
                                .font(.system(size: 14, weight: .regular))
                                .foregroundStyle(palette.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                
                if hasAnyLinearMetadata {
                    LinearMetadataGrid(items: linearMetadataItems, columns: stageMetadataColumns)
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
    
    // MARK: - Linear Metadata
    
    var hasAnyLinearMetadata: Bool {
        hasValidTeam || hasValidProject || hasValidStatus || hasValidPriority || hasValidAssignee
    }
    
    var hasValidTeam: Bool {
        hasValidValue(teamDisplay, excluding: ["Select", "Select Team"])
    }
    
    var hasValidProject: Bool {
        hasValidValue(projectDisplay, excluding: ["None"])
    }
    
    var hasValidStatus: Bool {
        // Show status if it's not the default "Todo"
        hasValidValue(statusDisplay, excluding: ["Todo"])
    }
    
    var hasValidPriority: Bool {
        hasValidValue(priorityDisplay, excluding: ["No Priority"])
    }
    
    var hasValidAssignee: Bool {
        hasValidValue(assigneeDisplay, excluding: ["Unassigned"])
    }
    
    private var linearMetadataItems: [LinearMetadataItem] {
        var items: [LinearMetadataItem] = []
        if hasValidTeam { items.append(LinearMetadataItem(title: "Team", value: teamDisplay, accent: nil)) }
        if hasValidProject { items.append(LinearMetadataItem(title: "Project", value: projectDisplay, accent: nil)) }
        if hasValidStatus { items.append(LinearMetadataItem(title: "Status", value: statusDisplay, accent: statusAccentColor)) }
        if hasValidPriority { items.append(LinearMetadataItem(title: "Urgency", value: priorityDisplay, accent: priorityAccentColor)) }
        if hasValidAssignee { items.append(LinearMetadataItem(title: "Assignee", value: assigneeDisplay, accent: nil)) }
        return items
    }

    private var linearDescriptionDisplay: String? {
        guard let description = proposal.description?.trimmingCharacters(in: .whitespacesAndNewlines),
              !description.isEmpty else {
            return nil
        }
        var output = description
        output = output.replacingOccurrences(of: "\\r\\n", with: "\n")
        output = output.replacingOccurrences(of: "\\n", with: "\n")
        output = output.replacingOccurrences(of: "\\t", with: "\t")
        return output
    }

    private func linearAttributedText(from text: String) -> AttributedString? {
        let options = AttributedString.MarkdownParsingOptions(
            interpretedSyntax: .inlineOnlyPreservingWhitespace
        )
        return try? AttributedString(markdown: text, options: options)
    }
    
    // Helper to check if a field has a valid, non-placeholder value
    func hasValidValue(_ value: String, excluding defaults: [String] = []) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        return !defaults.contains(trimmed)
    }
    
    // MARK: - Linear Display Helpers
    
    var titleDisplay: String {
        proposal.title?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? "Untitled Issue"
    }
    
    var priorityDisplay: String {
        // First check for enriched priorityName from backend
        if let priorityName = (proposal.args["priorityName"] as? String)?.nilIfEmpty {
            return priorityName
        }
        return proposal.priority?.nilIfEmpty ?? "No Priority"
    }

    private var priorityAccentColor: Color {
        accentForPriority(priorityDisplay)
    }
    
    var statusDisplay: String {
        let stateName = proposal.args["stateName"] as? String
        if let name = stateName?.nilIfEmpty {
            return name
        }
        if let statusArg = (proposal.args["status"] as? String)?.nilIfEmpty {
            return statusArg
        }
        if let statusValue = proposal.status?.nilIfEmpty {
            if isUUID(statusValue) {
                return "Todo"
            }
            return statusValue
        }
        return "Todo"
    }

    private var statusAccentColor: Color {
        accentForStatus(statusDisplay)
    }
    
    var assigneeDisplay: String {
        // First check for enriched assignee name from backend
        if let name = (proposal.args["assigneeName"] as? String)?.nilIfEmpty {
            return name
        }
        // Fall back to assigneeId, but show user-friendly message if it's a UUID
        if let assigneeId = proposal.assigneeId?.nilIfEmpty {
            if isUUID(assigneeId) {
                return "Unassigned"
            }
            return assigneeId
        }
        return "Unassigned"
    }
    
    var teamDisplay: String {
        // First check for enriched team name from backend
        if let name = (proposal.args["teamName"] as? String)?.nilIfEmpty {
            return name
        }
        // Fall back to teamId, but show user-friendly message if it's a UUID
        if let teamId = proposal.teamId?.nilIfEmpty {
            if isUUID(teamId) {
                return "Select Team"
            }
            return teamId
        }
        return "Select"
    }
    
    var projectDisplay: String {
        // First check for enriched project name from backend
        if let name = (proposal.args["projectName"] as? String)?.nilIfEmpty {
            return name
        }
        // Fall back to projectId, but show user-friendly message if it's a UUID
        if let projectId = proposal.projectId?.nilIfEmpty {
            if isUUID(projectId) {
                return "None"
            }
            return projectId
        }
        return "None"
    }

    private func accentForStatus(_ status: String) -> Color {
        let normalized = status.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if normalized.contains("progress") || normalized.contains("doing") || normalized.contains("review") {
            return Color(red: 0.34, green: 0.62, blue: 0.98)
        }
        if normalized.contains("blocked") || normalized.contains("stuck") || normalized.contains("on hold") {
            return Color(red: 0.93, green: 0.38, blue: 0.41)
        }
        if normalized.contains("done") || normalized.contains("complete") || normalized.contains("closed") {
            return Color(red: 0.32, green: 0.82, blue: 0.54)
        }
        if normalized.contains("backlog") || normalized.contains("todo") || normalized.contains("triage") {
            return Color(red: 0.62, green: 0.66, blue: 0.72)
        }
        return Color(red: 0.34, green: 0.62, blue: 0.98)
    }

    private func accentForPriority(_ priority: String) -> Color {
        let normalized = priority.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if normalized.contains("urgent") || normalized.contains("p0") {
            return Color(red: 0.95, green: 0.31, blue: 0.36)
        }
        if normalized.contains("high") || normalized.contains("p1") {
            return Color(red: 0.96, green: 0.55, blue: 0.27)
        }
        if normalized.contains("medium") || normalized.contains("p2") {
            return Color(red: 0.96, green: 0.75, blue: 0.32)
        }
        if normalized.contains("low") || normalized.contains("p3") {
            return Color(red: 0.45, green: 0.66, blue: 0.96)
        }
        return Color(red: 0.62, green: 0.66, blue: 0.72)
    }
    
    // Helper function to detect UUID format
    private func isUUID(_ string: String) -> Bool {
        // UUID format: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx (8-4-4-4-12 hex digits)
        let uuidPattern = #"^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$"#
        let regex = try? NSRegularExpression(pattern: uuidPattern, options: .caseInsensitive)
        let range = NSRange(location: 0, length: string.utf16.count)
        return regex?.firstMatch(in: string, options: [], range: range) != nil
    }
}

private struct LinearMetadataItem {
    let title: String
    let value: String
    let accent: Color?
}

private struct LinearMetadataGrid: View {
    let items: [LinearMetadataItem]
    let columns: [GridItem]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
            ForEach(items, id: \.title) { item in
                LinearMetadataGridItem(item: item)
            }
        }
    }
}

private struct LinearMetadataGridItem: View {
    let item: LinearMetadataItem
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

	private var valueColor: Color {
		guard let accent = item.accent else { return palette.primaryText }
		return accent.opacity(valueOpacity)
	}

	private var strokeColor: Color {
		guard let accent = item.accent else { return palette.subtleBorder.opacity(0.5) }
		return accent.opacity(strokeOpacity)
	}

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(item.title.uppercased())
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(palette.tertiaryText)

            Text(item.value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(valueColor)
                .lineLimit(1)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .padding(.leading, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
			ZStack(alignment: .leading) {
				LiquidGlassSurface(shape: .roundedRect(12), prominence: .subtle, shadowed: false)
				Rectangle()
					.fill(
						LinearGradient(
							colors: [
								item.accent.opacity(glowOpacity),
								item.accent.opacity(0)
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
                .stroke(item.accent.opacity(strokeOpacity), lineWidth: 0.6)
        )
        .overlay(alignment: .leading) {
			RoundedRectangle(cornerRadius: 2, style: .continuous)
				.fill(item.accent.opacity(barOpacity))
				.frame(width: 3)
				.padding(.leading, 6)
				.padding(.vertical, 10)
				.shadow(color: item.accent.opacity(barShadowOpacity), radius: 6, x: 0, y: 0)
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
