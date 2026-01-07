import SwiftUI
import Foundation

struct ConfirmationCardView: View {
    let proposal: ProposalData
    let onConfirm: () -> Void
    let onCancel: () -> Void
    var rotatingLightNamespace: Namespace.ID
    let isExecuting: Bool
    let isFinalAction: Bool
    
    @State private var showButtonGlow: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            headerSection
            
            // Dynamic content based on app type
            if proposal.isSlackApp {
                slackContentSection
            } else {
                linearContentSection
            }
            
            actionButtonsSection
        }
        .padding(22)
        .background(cardBackground)
        .overlay(glowOverlay)
        .overlay(cardBorder)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: Color.black.opacity(0.45), radius: 20, x: 0, y: 14)
        .onChange(of: isExecuting) { _, newValue in
            if newValue {
                startButtonGlow()
            } else {
                endButtonGlow()
            }
        }
        .onChange(of: proposal.proposalIndex) { _, _ in
            endButtonGlow()
        }
    }
}

// MARK: - Sections

private extension ConfirmationCardView {
    var headerSection: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                if let summaryText = proposal.summaryText?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !summaryText.isEmpty {
                    Text(summaryText)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(Color.white.opacity(0.7))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            
            Spacer()
            
            Button(action: onCancel) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white.opacity(0.6))
                    .padding(8)
                    .background(
                        Circle()
                            .fill(Color.white.opacity(0.08))
                    )
            }
            .buttonStyle(.plain)
        }
    }
    
    // MARK: - Slack Content Section
    
    @ViewBuilder
    var slackContentSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Message preview - the main content for Slack
            if let messageText = proposal.messageText?.trimmingCharacters(in: .whitespacesAndNewlines),
               !messageText.isEmpty {
                Text(messageText)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(.white)
                    .lineLimit(5)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Divider()
                .background(Color.white.opacity(0.08))
                .padding(.vertical, 2)
            
            // Channel/recipient display
            if let channel = slackChannelDisplay {
                HStack(spacing: 8) {
                    Text("Send to")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(Color.white.opacity(0.55))
                    
                    Text(channel)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
        }
    }
    
    // MARK: - Linear Content Section
    
    @ViewBuilder
    var linearContentSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Title
            Text(titleDisplay)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
            
            // Description (if present)
            if let description = proposal.description?.trimmingCharacters(in: .whitespacesAndNewlines),
               !description.isEmpty {
                Text(description)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(Color.white.opacity(0.7))
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            // Only show metadata section if there are populated fields
            if hasAnyLinearMetadata {
                Divider()
                    .background(Color.white.opacity(0.08))
                    .padding(.vertical, 2)
                
                linearMetadataSection
            }
        }
    }
    
    // MARK: - Linear Metadata Section
    
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
    
    @ViewBuilder
    var linearMetadataSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // First row: Team & Project (only if at least one exists)
            if hasValidTeam || hasValidProject {
                HStack(spacing: 16) {
                    if hasValidTeam {
                        MetadataField(title: "Team", value: teamDisplay)
                    }
                    if hasValidProject {
                        MetadataField(title: "Project", value: projectDisplay)
                    }
                }
            }
            
            // Second row: Status, Priority, Assignee (only show populated ones)
            let secondRowFields = [
                hasValidStatus ? ("Status", statusDisplay) : nil,
                hasValidPriority ? ("Priority", priorityDisplay) : nil,
                hasValidAssignee ? ("Assignee", assigneeDisplay) : nil
            ].compactMap { $0 }
            
            if !secondRowFields.isEmpty {
                HStack(spacing: 16) {
                    ForEach(secondRowFields, id: \.0) { title, value in
                        MetadataField(title: title, value: value)
                    }
                }
            }
        }
    }
    
    // Helper to check if a field has a valid, non-placeholder value
    func hasValidValue(_ value: String, excluding defaults: [String] = []) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        return !defaults.contains(trimmed)
    }
    
    // MARK: - Action Buttons Section
    
    @ViewBuilder
    var actionButtonsSection: some View {
        if proposal.isSlackApp {
            slackActionButtons
        } else {
            actionButton
        }
    }
    
    var slackActionButtons: some View {
        HStack(spacing: 12) {
            // Primary "Send" button
            Button {
                NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)
                onConfirm()
            } label: {
                Text("Send")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .frame(height: 48)
                    .background(
                        RotatingLightBackground(
                            cornerRadius: 24,
                            shape: RotatingLightBackground.ShapeType.capsule,
                            rotationSpeed: 10.0,
                            glowColor: .green
                        )
                        .matchedGeometryEffect(id: "rotatingLight", in: rotatingLightNamespace)
                    )
            }
            .buttonStyle(.plain)
            
            // Secondary "Schedule message" button (only for scheduled message tool)
            if isScheduledMessage {
                Button {
                    // Schedule action - same as confirm for scheduled messages
                    NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)
                    onConfirm()
                } label: {
                    Text("Schedule message")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .frame(height: 48)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.1))
                        )
                        .overlay(
                            Capsule()
                                .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    var isScheduledMessage: Bool {
        proposal.tool.lowercased().contains("schedule")
    }
    
    var actionButton: some View {
        return Button {
            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)
            onConfirm()
        } label: {
            Text(confirmButtonTitle)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .frame(height: 48)
                .background(
                    // Rotating light background that will morph via matchedGeometryEffect
                    RotatingLightBackground(
                        cornerRadius: 24,
                        shape: RotatingLightBackground.ShapeType.capsule,
                        rotationSpeed: 10.0,
                        glowColor: .green
                    )
                    .matchedGeometryEffect(id: "rotatingLight", in: rotatingLightNamespace)
                )
        }
        .buttonStyle(.plain)
    }
    
    var cardBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.thickMaterial)
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.black.opacity(0.85))
        }
    }
    
    var cardBorder: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .strokeBorder(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.25),
                        Color.white.opacity(0.05)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1
            )
    }
    
    var glowOverlay: some View {
        // Use the new RotatingGradientFill - gradient rotates inside a fixed clipped shape
        // This avoids the "square rotating" artifact from the old rotationEffect approach
        RotatingGradientFill(
            shape: .roundedRect(cornerRadius: 24),
            rotationSpeed: 8.0,
            intensity: showButtonGlow ? (isFinalAction ? 0.18 : 0.14) : 0
        )
        .matchedGeometryEffect(id: "gradientFill", in: rotatingLightNamespace)
        .opacity(showButtonGlow ? 1 : 0)
        .animation(.easeOut(duration: 0.5), value: showButtonGlow)
        .allowsHitTesting(false)
    }
}

// MARK: - Display Helpers

private extension ConfirmationCardView {
    
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
        
        // Check for user target (DM)
        if let userName = proposal.userName?.nilIfEmpty {
            if userName.hasPrefix("@") {
                return userName
            }
            // If it's a user ID (starts with U), skip
            if userName.hasPrefix("U") && userName.count > 8 {
                return nil
            }
            return "@\(userName)"
        }
        
        return nil
    }
    
    // MARK: - Shared Helpers
    
    // Helper function to detect UUID format
    private func isUUID(_ string: String) -> Bool {
        // UUID format: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx (8-4-4-4-12 hex digits)
        let uuidPattern = #"^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$"#
        let regex = try? NSRegularExpression(pattern: uuidPattern, options: .caseInsensitive)
        let range = NSRange(location: 0, length: string.utf16.count)
        return regex?.firstMatch(in: string, options: [], range: range) != nil
    }
    
    var confirmButtonTitle: String {
        let tool = proposal.tool.lowercased()
        
        // Slack-specific button titles
        if proposal.isSlackApp {
            if tool.contains("schedule") { return "Schedule message" }
            return "Send"
        }
        
        // Linear-specific button titles
        if tool.contains("create") { return "Create ticket" }
        if tool.contains("update") { return "Update ticket" }
        return "Confirm action"
    }
}

// MARK: - Metadata Field

private struct MetadataField: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.5))
            
            HStack(spacing: 8) {
                Text(value)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                
                Spacer(minLength: 4)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.22),
                                Color.white.opacity(0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.75
                    )
            )
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Extensions

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

// MARK: - Private Helpers

private extension ConfirmationCardView {
    func startButtonGlow() {
        withAnimation(.easeOut(duration: 0.5)) {
            showButtonGlow = true
        }
    }
    
    func endButtonGlow() {
        withAnimation(.easeOut(duration: 0.35)) {
            showButtonGlow = false
        }
    }
}
