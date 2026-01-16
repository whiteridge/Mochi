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
                    
                    if hasValidPriority {
                        Text(priorityDisplay)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(ActionGlowPalette.glow)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(ActionGlowPalette.glow.opacity(0.14))
                            )
                    }
                    
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
                    MetadataGrid(items: linearMetadataItems, columns: stageMetadataColumns)
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
    
    var linearMetadataItems: [(String, String)] {
        var items: [(String, String)] = []
        if hasValidTeam { items.append(("Team", teamDisplay)) }
        if hasValidProject { items.append(("Project", projectDisplay)) }
        if hasValidStatus { items.append(("Status", statusDisplay)) }
        if hasValidPriority { items.append(("Urgency", priorityDisplay)) }
        if hasValidAssignee { items.append(("Assignee", assigneeDisplay)) }
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
    
    // Helper function to detect UUID format
    private func isUUID(_ string: String) -> Bool {
        // UUID format: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx (8-4-4-4-12 hex digits)
        let uuidPattern = #"^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$"#
        let regex = try? NSRegularExpression(pattern: uuidPattern, options: .caseInsensitive)
        let range = NSRange(location: 0, length: string.utf16.count)
        return regex?.firstMatch(in: string, options: [], range: range) != nil
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
