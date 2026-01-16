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
                    MetadataGrid(items: githubMetadataItems, columns: stageMetadataColumns)
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

    private var githubMetadataItems: [(String, String)] {
        var items: [(String, String)] = []
        if let repo = proposal.githubRepoFullName?.nilIfEmpty {
            items.append(("Repo", repo))
        }
        if let prNumber = proposal.githubPullNumber?.nilIfEmpty {
            items.append(("PR", "#\(prNumber)"))
        } else if let issueNumber = proposal.githubIssueNumber?.nilIfEmpty {
            items.append(("Issue", "#\(issueNumber)"))
        }
        if isPullRequest {
            if let base = proposal.githubBase?.nilIfEmpty {
                items.append(("Base", base))
            }
            if let head = proposal.githubHead?.nilIfEmpty {
                items.append(("Head", head))
            }
        }
        if isIssue {
            let labels = compactList(proposal.githubLabels)
            if let labels {
                items.append(("Labels", labels))
            }
            let assignees = compactList(proposal.githubAssignees)
            if let assignees {
                items.append(("Assignees", assignees))
            }
        }
        if isRepoCreation, let visibility = proposal.githubVisibility?.nilIfEmpty {
            items.append(("Visibility", visibility))
        }
        return items
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
