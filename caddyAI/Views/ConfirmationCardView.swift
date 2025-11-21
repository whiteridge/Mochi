import SwiftUI

struct ConfirmationCardView: View {
    let proposal: ProposalData
    let onConfirm: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            headerSection
            
            if let description = proposal.description?.trimmingCharacters(in: .whitespacesAndNewlines),
               !description.isEmpty {
                Text(description)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(Color.white.opacity(0.7))
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Divider()
                .background(Color.white.opacity(0.08))
                .padding(.vertical, 4)
            
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 16) {
                    MetadataField(title: "Team", value: teamDisplay)
                    MetadataField(title: "Project", value: projectDisplay)
                }
                
                HStack(spacing: 16) {
                    MetadataField(title: "Status", value: statusDisplay)
                    MetadataField(title: "Priority", value: priorityDisplay)
                    MetadataField(title: "Assignee", value: assigneeDisplay)
                }
            }
            
            actionButton
        }
        .padding(22)
        .background(cardBackground)
        .overlay(cardBorder)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: Color.black.opacity(0.45), radius: 20, x: 0, y: 14)
    }
}

// MARK: - Sections

private extension ConfirmationCardView {
    var headerSection: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(titleDisplay)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
                
                Text("I'll create an urgent ticket and notify the right teams.")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(Color.white.opacity(0.55))
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
    
    var actionButton: some View {
        Button {
            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)
            onConfirm()
        } label: {
            Text(confirmButtonTitle)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    LinearGradient(
                        colors: [
                            Color(hex: "29A35F"),
                            Color.black
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .cornerRadius(24)
                )
                .shadow(
                    color: Color(hex: "29A35F").opacity(0.55),
                    radius: 16,
                    x: 0,
                    y: 10
                )
        }
        .buttonStyle(.plain)
    }
    
    var cardBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.black.opacity(0.75))
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
}

// MARK: - Display Helpers

private extension ConfirmationCardView {
    var titleDisplay: String {
        proposal.title?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? "Untitled Issue"
    }
    
    var priorityDisplay: String {
        proposal.priority?.nilIfEmpty ?? "Select"
    }
    
    var statusDisplay: String {
        proposal.status?.nilIfEmpty ?? "Todo"
    }
    
    var assigneeDisplay: String {
        let name = proposal.args["assigneeName"] as? String
        return name?.nilIfEmpty
            ?? (proposal.args["assignee"] as? String)?.nilIfEmpty
            ?? proposal.assigneeId?.nilIfEmpty
            ?? "Unassigned"
    }
    
    var teamDisplay: String {
        let name = proposal.args["teamName"] as? String
        return name?.nilIfEmpty
            ?? (proposal.args["team"] as? String)?.nilIfEmpty
            ?? proposal.teamId?.nilIfEmpty
            ?? "Select"
    }
    
    var projectDisplay: String {
        let name = proposal.args["projectName"] as? String
        return name?.nilIfEmpty
            ?? (proposal.args["project"] as? String)?.nilIfEmpty
            ?? proposal.projectId?.nilIfEmpty
            ?? "None"
    }
    
    var confirmButtonTitle: String {
        let tool = proposal.tool.lowercased()
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
                
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.4))
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

private extension Color {
    init(hex: String) {
        let sanitized = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: sanitized).scanHexInt64(&int)
        
        let r, g, b: UInt64
        switch sanitized.count {
        case 3: // RGB (12-bit)
            (r, g, b) = (
                ((int >> 8) * 17),
                ((int >> 4) & 0xF) * 17,
                (int & 0xF) * 17
            )
        case 6: // RGB (24-bit)
            (r, g, b) = (
                (int >> 16) & 0xFF,
                (int >> 8) & 0xFF,
                int & 0xFF
            )
        default:
            (r, g, b) = (1, 1, 1)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255
        )
    }
}
