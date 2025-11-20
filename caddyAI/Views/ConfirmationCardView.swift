import SwiftUI

struct ConfirmationCardView: View {
    let proposal: ProposalData
    let onConfirm: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: iconName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
                    .frame(width: 32, height: 32)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Circle())
                
                Text(headerTitle)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                
                Spacer()
            }
            
            // Content
            VStack(alignment: .leading, spacing: 8) {
                if let title = proposal.args["title"] as? String {
                    Text(title)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white.opacity(0.9))
                }
                
                if let description = proposal.args["description"] as? String {
                    Text(description)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(.white.opacity(0.7))
                        .lineLimit(3)
                }
                
                // Key Fields (e.g. Priority, Assignee)
                HStack(spacing: 12) {
                    if let priority = proposal.args["priority"] {
                        TagView(text: "Priority: \(priority)", color: .orange)
                    }
                    if let assignee = proposal.args["assignee"] { // Assuming assignee ID or name
                        TagView(text: "Assignee: \(assignee)", color: .blue)
                    }
                }
                .padding(.top, 4)
            }
            .padding(12)
            .background(Color.black.opacity(0.2))
            .cornerRadius(12)
            
            // Actions
            HStack(spacing: 12) {
                Button(action: onCancel) {
                    Text("Cancel")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(10)
                }
                .buttonStyle(.plain)
                
                Button(action: onConfirm) {
                    Text(confirmButtonTitle)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            LinearGradient(
                                colors: [Color.green.opacity(0.8), Color.green.opacity(0.6)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .overlay(Color.black.opacity(0.4))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.3), radius: 10, x: 0, y: 5)
    }
    
    // MARK: - Helpers
    
    private var iconName: String {
        if proposal.tool.contains("create") { return "plus.circle.fill" }
        if proposal.tool.contains("update") { return "pencil.circle.fill" }
        if proposal.tool.contains("delete") { return "trash.circle.fill" }
        return "doc.text.fill"
    }
    
    private var headerTitle: String {
        if proposal.tool.contains("issue") {
            if proposal.tool.contains("create") { return "Create Issue" }
            if proposal.tool.contains("update") { return "Update Issue" }
        }
        return "Confirm Action"
    }
    
    private var confirmButtonTitle: String {
        if proposal.tool.contains("create") { return "Create Ticket" }
        if proposal.tool.contains("update") { return "Update Ticket" }
        return "Confirm"
    }
}

struct TagView: View {
    let text: String
    let color: Color
    
    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(color.opacity(0.9))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.15))
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(color.opacity(0.3), lineWidth: 0.5)
            )
    }
}
