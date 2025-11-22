import SwiftUI

struct ConfirmationCardView: View {
    let proposal: ProposalData
    let onConfirm: () -> Void
    let onCancel: () -> Void
    
    @State private var rotation: Double = 0
    
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
        let mossGreen = Color(red: 90/255, green: 140/255, blue: 90/255) // Desaturated Olive

        return Button {
            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)
            onConfirm()
        } label: {
            Text(confirmButtonTitle)
                .font(.system(size: 15, weight: .semibold)) // Slightly bolder text
                .foregroundColor(.white)
                .padding(.horizontal, 24) // Match "Type to Caddy" length approximately
                .frame(height: 48) // Fixed height for perfect pill shape
                .background(
                    ZStack {
                        // Layer 1: Dark Base
                        Color.black.opacity(0.5)
                        
                        // Layer 2: The "Spotlight" (Top-Center Radial)
                        GeometryReader { geo in
                            let size = geo.size.width
                            ZStack {
                                RadialGradient(
                                    colors: [
                                        mossGreen.opacity(0.6), // Core highlight
                                        mossGreen.opacity(0.1), // Fade
                                        Color.clear             // End
                                    ],
                                    center: UnitPoint(x: 0.5, y: 0.15), // Offset to orbit around edge
                                    startRadius: 0,
                                    endRadius: size * 0.4 // Tighter spread
                                )
                                .frame(width: size, height: size)
                                .rotationEffect(.degrees(rotation))
                            }
                            .frame(width: geo.size.width, height: geo.size.height, alignment: .center)
                        }
                    }
                )
                .clipShape(Capsule()) // Perfect semicircular ends
                .onAppear {
                    withAnimation(.linear(duration: 10).repeatForever(autoreverses: false)) {
                        rotation = 360
                    }
                }
                // Layer 3: The "Glass Edge" (Rim Light)
                .overlay(
                    Capsule()
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.3), // Bright Top Rim
                                    Color.white.opacity(0.1), // Fading sides
                                    Color.white.opacity(0.02) // Invisible Bottom
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 1
                        )
                )
                // Layer 4: Subtle Outer Bloom
                .shadow(color: mossGreen.opacity(0.2), radius: 12, x: 0, y: 4)
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
