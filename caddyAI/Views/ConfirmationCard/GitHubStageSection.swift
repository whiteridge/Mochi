import SwiftUI

struct GitHubStageSection: View {
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

                if let bodyPreview {
                    ScrollableTextArea(maxHeight: 140, indicatorColor: palette.subtleBorder.opacity(0.35)) {
                        Text(bodyPreview)
                            .font(.system(size: 14, weight: .regular))
                            .foregroundStyle(palette.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                } else if showsBodyPlaceholder {
                    Text("No description provided.")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(palette.tertiaryText)
                }

                if !githubMetadataItems.isEmpty {
                    GitHubMetadataGrid(items: githubMetadataItems, columns: stageMetadataColumns)
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
                    .stroke(palette.subtleBorder.opacity(0.45), lineWidth: 0.45)
            )
    }

    @ViewBuilder
    private var stageBackground: some View {
        let stageOpacity = preferences.glassStyle == .regular ? 0.75 : 0.9
        ZStack {
            LiquidGlassSurface(shape: .roundedRect(stageCornerRadius), prominence: .subtle, shadowed: false)
                .opacity(stageOpacity)
            if preferences.glassStyle == .clear {
                RoundedRectangle(cornerRadius: stageCornerRadius, style: .continuous)
                    .fill(Color.black.opacity(colorScheme == .dark ? 0.2 : 0.07))
            }
        }
    }

    // MARK: - GitHub Display Helpers

    private var lowerTool: String {
        proposal.tool.lowercased()
    }

    private var isPullRequest: Bool {
        lowerTool.contains("pull_request") || lowerTool.contains("pullrequest")
    }

    private var isIssue: Bool {
        lowerTool.contains("issue") && !isPullRequest
    }

    private var isComment: Bool {
        lowerTool.contains("comment")
    }

    private var isRepoCreation: Bool {
        (lowerTool.contains("repo") || lowerTool.contains("repository")) && lowerTool.contains("create")
    }

    private var titleDisplay: String {
        if isRepoCreation {
            return proposal.githubRepo ?? "New repository"
        }
        if isComment {
            return "Comment"
        }
        if isPullRequest {
            return proposal.githubTitle?.nilIfEmpty ?? "Untitled pull request"
        }
        if isIssue {
            return proposal.githubTitle?.nilIfEmpty ?? "Untitled issue"
        }
        return proposal.githubTitle?.nilIfEmpty ?? "GitHub action"
    }

    private var bodyPreview: String? {
        let body = proposal.githubBody?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (body?.isEmpty == false) ? body : nil
    }

    private var showsBodyPlaceholder: Bool {
        isPullRequest || isIssue || isComment
    }

    private var githubMetadataItems: [GitHubMetadataItem] {
        var items: [GitHubMetadataItem] = []
        if let repo = proposal.githubRepoFullName?.nilIfEmpty {
            items.append(GitHubMetadataItem(title: "Repo", value: repo, accent: nil))
        }
        if let prNumber = proposal.githubPullNumber?.nilIfEmpty {
            items.append(GitHubMetadataItem(title: "PR", value: "#\(prNumber)", accent: nil))
        } else if let issueNumber = proposal.githubIssueNumber?.nilIfEmpty {
            items.append(GitHubMetadataItem(title: "Issue", value: "#\(issueNumber)", accent: nil))
        }
        if isPullRequest {
            if let base = proposal.githubBase?.nilIfEmpty {
                items.append(GitHubMetadataItem(title: "Base", value: base, accent: nil))
            }
            if let head = proposal.githubHead?.nilIfEmpty {
                items.append(GitHubMetadataItem(title: "Head", value: head, accent: nil))
            }
        }
        if isIssue {
            let labels = compactList(proposal.githubLabels)
            if let labels {
                items.append(GitHubMetadataItem(title: "Labels", value: labels, accent: nil))
            }
            let assignees = compactList(proposal.githubAssignees)
            if let assignees {
                items.append(GitHubMetadataItem(title: "Assignees", value: assignees, accent: nil))
            }
        }
        if isRepoCreation, let visibility = proposal.githubVisibility?.nilIfEmpty {
            items.append(GitHubMetadataItem(title: "Visibility", value: visibility, accent: accentForVisibility(visibility)))
        }
        return items
    }

    private var visibilityAccentColor: Color {
        Color(red: 0.62, green: 0.66, blue: 0.72)
    }

    private func accentForVisibility(_ visibility: String) -> Color {
        let normalized = visibility.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if normalized.contains("public") {
            return Color(red: 0.32, green: 0.82, blue: 0.54)
        }
        if normalized.contains("private") {
            return Color(red: 0.93, green: 0.38, blue: 0.41)
        }
        if normalized.contains("internal") {
            return Color(red: 0.94, green: 0.71, blue: 0.34)
        }
        return visibilityAccentColor
    }

    private func compactList(_ values: [String]) -> String? {
        let cleaned = values.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        guard !cleaned.isEmpty else { return nil }
        if cleaned.count <= 2 {
            return cleaned.joined(separator: ", ")
        }
        return "\(cleaned[0]), \(cleaned[1]) +\(cleaned.count - 2)"
    }
}

private struct GitHubMetadataItem {
    let title: String
    let value: String
    let accent: Color?
}

private struct GitHubMetadataGrid: View {
    let items: [GitHubMetadataItem]
    let columns: [GridItem]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
            ForEach(items, id: \.title) { item in
                GitHubMetadataGridItem(item: item)
            }
        }
    }
}

private struct GitHubMetadataGridItem: View {
    let item: GitHubMetadataItem
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var preferences: PreferencesStore

    private var palette: LiquidGlassPalette {
        LiquidGlassPalette(colorScheme: colorScheme, glassStyle: preferences.glassStyle)
    }

    private var accentFill: Color {
        guard let accent = item.accent else { return .clear }
        return accent.opacity(colorScheme == .dark ? 0.2 : 0.12)
    }

    private var accentStroke: Color {
        guard let accent = item.accent else { return palette.subtleBorder.opacity(0.35) }
        return accent.opacity(colorScheme == .dark ? 0.38 : 0.28)
    }

    private var accentTag: Color {
        guard let accent = item.accent else { return .clear }
        return accent.opacity(colorScheme == .dark ? 0.7 : 0.55)
    }

    private var valueColor: Color {
        item.accent ?? palette.primaryText
    }

    var body: some View {
        let boxOpacity = preferences.glassStyle == .regular ? 0.45 : 0.75
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
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            ZStack {
                LiquidGlassSurface(shape: .roundedRect(12), prominence: .subtle, shadowed: false)
                    .opacity(boxOpacity)
                if item.accent != nil {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(accentFill)
                }
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(accentStroke, lineWidth: 0.45)
        )
        .overlay(alignment: .leading) {
            if item.accent != nil {
                Capsule()
                    .fill(accentTag)
                    .frame(width: 3)
                    .padding(.leading, 6)
                    .padding(.vertical, 10)
            }
        }
    }
}

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
