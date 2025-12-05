import SwiftUI
import Foundation

struct ConfirmationCardView: View {
    let proposal: ProposalData
    let onConfirm: () -> Void
    let onCancel: () -> Void
    var rotatingLightNamespace: Namespace.ID
    let isExecuting: Bool
    let isFinalAction: Bool
    
    @State private var rotation: Double = 0
    @State private var buttonFrame: CGRect = .zero
    @State private var cardSize: CGSize = .zero
    @State private var showButtonGlow: Bool = false
    @State private var buttonGlowScale: CGFloat = 0.05
    @State private var glowRotation: Double = 0
    
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
        .background(cardSizeReader)
        .background(cardBackground)
        .overlay(glowOverlay)
        .overlay(cardBorder)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: Color.black.opacity(0.45), radius: 20, x: 0, y: 14)
        .coordinateSpace(name: "cardSpace")
        .onPreferenceChange(ConfirmButtonFrameKey.self) { value in
            buttonFrame = value
        }
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
                .background(
                    GeometryReader { geo in
                        Color.clear
                            .preference(key: ConfirmButtonFrameKey.self, value: geo.frame(in: .named("cardSpace")))
                    }
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
        GeometryReader { proxy in
            let size = proxy.size
            let anchor = anchorPoint(for: size)
            let gradientColors = [
                Color(red: 0.03, green: 0.18, blue: 0.07),
                Color(red: 0.08, green: 0.32, blue: 0.12),
                Color(red: 0.22, green: 0.7, blue: 0.35),
                Color(red: 0.08, green: 0.32, blue: 0.12),
                Color(red: 0.03, green: 0.18, blue: 0.07)
            ]
            
            let gradient = LinearGradient(
                colors: gradientColors,
                startPoint: .leading,
                endPoint: .trailing
            )
            
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(gradient)
                .opacity(showButtonGlow ? (isFinalAction ? 0.52 : 0.44) : 0)
                .scaleEffect(showButtonGlow ? buttonGlowScale : 0.05, anchor: anchor)
                .rotationEffect(.degrees(glowRotation))
                .blur(radius: 32)
                .frame(width: size.width + 160, height: size.height + 160)
                .animation(.easeOut(duration: 0.55), value: showButtonGlow)
                .animation(.easeOut(duration: 0.55), value: buttonGlowScale)
                .animation(.linear(duration: 4.0).repeatForever(autoreverses: false), value: glowRotation)
                .position(x: size.width / 2, y: size.height / 2)
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Display Helpers

private extension ConfirmationCardView {
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
    var cardSizeReader: some View {
        GeometryReader { proxy in
            Color.clear
                .onAppear {
                    cardSize = proxy.size
                }
                .onChange(of: proxy.size) { _, newValue in
                    cardSize = newValue
                }
        }
    }
    
    func startButtonGlow() {
        buttonGlowScale = 0.05
        glowRotation = 0
        withAnimation(.easeOut(duration: 0.55)) {
            showButtonGlow = true
            buttonGlowScale = 1.08
        }
        withAnimation(.linear(duration: 4.0).repeatForever(autoreverses: false)) {
            glowRotation = 360
        }
    }
    
    func endButtonGlow() {
        withAnimation(.easeOut(duration: 0.35)) {
            showButtonGlow = false
        }
        glowRotation = 0
    }
    
    func anchorPoint(for size: CGSize) -> UnitPoint {
        let x = Double(min(max(buttonFrame.midX / max(size.width, 1), 0), 1))
        let y = Double(min(max(buttonFrame.midY / max(size.height, 1), 0), 1))
        return UnitPoint(x: x, y: y)
    }
}
