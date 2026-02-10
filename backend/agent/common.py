"""Shared helpers for agent orchestration."""

from typing import Dict, List, Optional


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


def detect_intent_scope(
    user_input: str,
    required_apps: Optional[List[str]] = None,
) -> Dict[str, str]:
    """Infer a minimal tool scope per app from user input."""
    user_lower = user_input.lower()
    apps = required_apps.copy() if required_apps else detect_apps_from_input(user_input)
    scopes: Dict[str, str] = {}
    if not apps:
        return scopes

    read_keywords = (
        "show",
        "list",
        "find",
        "search",
        "read",
        "check",
        "what",
        "which",
        "status",
        "history",
    )
    write_keywords = (
        "create",
        "make",
        "send",
        "post",
        "tell",
        "say",
        "notify",
        "schedule",
        "update",
        "edit",
        "change",
        "delete",
        "remove",
        "archive",
        "reply",
        "forward",
    )

    has_read = any(keyword in user_lower for keyword in read_keywords)
    has_write = any(keyword in user_lower for keyword in write_keywords)

    if has_read and has_write:
        base_scope = "mixed"
    elif has_write:
        base_scope = "write"
    else:
        base_scope = "read"

    slack_schedule_keywords = ("schedule", "later", "tomorrow", "tonight")
    slack_dm_keywords = (
        "dm",
        "direct message",
        "private message",
        "message @",
        "to @",
    )
    slack_send_keywords = (
        "send",
        "post",
        "say",
        "tell",
        "notify",
        "message",
        "channel",
    )
    slack_read_keywords = ("search", "find", "history", "list")

    for app in apps:
        normalized_app = app.lower().replace("-", "_")
        if normalized_app == "slack":
            if any(keyword in user_lower for keyword in slack_schedule_keywords):
                scopes[normalized_app] = "schedule"
            elif any(keyword in user_lower for keyword in slack_dm_keywords):
                scopes[normalized_app] = "dm"
            elif any(keyword in user_lower for keyword in slack_read_keywords) and not any(
                keyword in user_lower for keyword in slack_send_keywords
            ):
                scopes[normalized_app] = "read"
            elif any(keyword in user_lower for keyword in slack_send_keywords):
                scopes[normalized_app] = "send"
            elif base_scope == "mixed":
                scopes[normalized_app] = "mixed"
            elif base_scope == "write":
                scopes[normalized_app] = "send"
            else:
                scopes[normalized_app] = "read"
            continue

        if normalized_app in {"googlecalendar", "google_calendar"}:
            normalized_app = "google_calendar"

        scopes[normalized_app] = base_scope

    return scopes


def looks_like_tool_request(user_input: str) -> bool:
    """Heuristic to decide whether the input likely needs tool calls."""
    user_lower = user_input.lower()
    intent_keywords = [
        "create",
        "make",
        "add",
        "schedule",
        "book",
        "plan",
        "send",
        "message",
        "notify",
        "email",
        "post",
        "update",
        "edit",
        "change",
        "delete",
        "remove",
        "assign",
        "file",
        "open",
        "close",
        "summarize",
        "check",
        "look",
        "find",
        "search",
        "list",
        "fetch",
    ]
    return any(keyword in user_lower for keyword in intent_keywords)


def is_capabilities_query(user_input: str) -> bool:
    """Detect short capability/help prompts that should return a concise static answer."""
    text = " ".join(user_input.lower().strip().split())
    if not text:
        return False

    direct_matches = {
        "help",
        "help?",
        "what can you do",
        "what can you do?",
        "what can u do",
        "what can u do?",
        "what do you do",
        "what do you do?",
        "capabilities",
        "your capabilities",
        "what are your capabilities",
        "what are your capabilities?",
        "list commands",
        "list commands?",
        "what commands do you have",
        "what commands do you have?",
    }
    if text in direct_matches:
        return True

    capability_phrases = (
        "what can you do",
        "what can u do",
        "what do you do",
        "what are your capabilities",
        "list your capabilities",
        "list your commands",
    )
    return any(phrase in text for phrase in capability_phrases)


def capability_summary_message() -> str:
    """A deterministic, concise capability summary for help/capability prompts."""
    return (
        "I can help across Slack, Linear, GitHub, Gmail, and Google Calendar: "
        "send/read Slack messages, create/update Linear issues, manage GitHub issues/PRs, "
        "draft/search emails, and create/update calendar events."
    )
