"""Shared helpers for agent orchestration."""

from typing import List


def map_tool_to_app(tool_name: str) -> str:
    """Map a tool name to its app identifier."""
    name_upper = tool_name.upper()
    if name_upper.startswith("LINEAR_"):
        return "linear"
    if name_upper.startswith("SLACK_"):
        return "slack"
    if name_upper.startswith("GITHUB_"):
        return "github"
    if name_upper.startswith("NOTION_"):
        return "notion"
    if name_upper.startswith("GMAIL_"):
        return "gmail"
    if name_upper.startswith("GOOGLECALENDAR_"):
        return "google_calendar"
    if name_upper.startswith("GOOGLE_CALENDAR_"):
        return "google_calendar"
    parts = tool_name.split("_")
    return parts[0].lower() if parts else tool_name.lower()


def format_app_name(app_id: str) -> str:
    """Format app IDs for user-facing messages."""
    display_names = {
        "github": "GitHub",
        "gmail": "Gmail",
        "google_calendar": "Google Calendar",
        "linear": "Linear",
        "notion": "Notion",
        "slack": "Slack",
    }
    if app_id in display_names:
        return display_names[app_id]
    return app_id.replace("_", " ").title()


def make_early_summary(app_id: str) -> str:
    """Generate a deterministic early summary for the given app."""
    templates = {
        "linear": "I'll search Linear to help with your request.",
        "slack": "I'll read Slack to help with your request.",
        "github": "I'll check GitHub to help with your request.",
        "notion": "I'll look in Notion to help with your request.",
        "gmail": "I'll check Gmail to help with your request.",
        "google_calendar": (
            "I'll check Google Calendar to help with your request."
        ),
    }
    if app_id in templates:
        return templates[app_id]
    return f"I'll look in {format_app_name(app_id)} to help with your request."


def detect_apps_from_input(user_input: str) -> List[str]:
    """Pre-detect likely apps from user input keywords."""
    user_lower = user_input.lower()
    detected: List[str] = []

    linear_keywords = [
        "linear",
        "issue",
        "ticket",
        "bug",
        "task",
        "file it",
        "file a",
        "urgent",
    ]
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

    github_keywords = [
        "github",
        "repo",
        "repository",
        "pr",
        "pull request",
        "commit",
    ]
    if any(kw in user_lower for kw in github_keywords):
        detected.append("github")

    notion_keywords = ["notion", "page", "database", "doc"]
    if any(kw in user_lower for kw in notion_keywords):
        detected.append("notion")

    gmail_keywords = ["gmail", "email", "inbox", "mail"]
    if any(kw in user_lower for kw in gmail_keywords):
        detected.append("gmail")

    calendar_keywords = [
        "calendar",
        "meeting",
        "schedule",
        "availability",
        "free busy",
    ]
    if any(kw in user_lower for kw in calendar_keywords):
        detected.append("google_calendar")

    return detected
