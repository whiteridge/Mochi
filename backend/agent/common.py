"""Shared helpers for agent orchestration."""

from typing import List, Optional


def map_tool_to_app(tool_name: Optional[str]) -> str:
    """Map a tool name to its app identifier."""
    if not tool_name:
        return "unknown"

    name_upper = tool_name.upper()
    if name_upper.startswith("LINEAR_"):
        return "linear"
    if name_upper.startswith("SLACK_"):
        return "slack"
    if name_upper.startswith("GITHUB_"):
        return "github"
    if name_upper.startswith("NOTION_"):
        return "notion"
    parts = tool_name.split("_")
    return parts[0].lower() if parts else tool_name.lower()


def make_early_summary(app_id: str) -> str:
    """Generate a deterministic early summary for the given app."""
    templates = {
        "linear": "I'll search Linear to help with your request.",
        "slack": "I'll read Slack to help with your request.",
        "github": "I'll check GitHub to help with your request.",
        "notion": "I'll look in Notion to help with your request.",
    }
    return templates.get(app_id, f"I'll look in {app_id.capitalize()} to help with your request.")


def detect_apps_from_input(user_input: str) -> List[str]:
    """Pre-detect likely apps from user input keywords."""
    user_lower = user_input.lower()
    detected: List[str] = []

    linear_keywords = ["linear", "issue", "ticket", "bug", "task", "file it", "file a", "urgent"]
    if any(kw in user_lower for kw in linear_keywords):
        detected.append("linear")

    slack_keywords = [
        "slack",
        "message",
        "channel",
        "notify",
        "confirm with",
        "tell",
        "send to",
        "billing team",
        "team on slack",
    ]
    if any(kw in user_lower for kw in slack_keywords):
        detected.append("slack")

    github_keywords = ["github", "repo", "repository", "pr", "pull request", "commit"]
    if any(kw in user_lower for kw in github_keywords):
        detected.append("github")

    notion_keywords = ["notion", "page", "database", "doc"]
    if any(kw in user_lower for kw in notion_keywords):
        detected.append("notion")

    return detected


