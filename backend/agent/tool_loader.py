"""Helper for loading Composio tools across apps."""

from typing import List, Tuple


def load_composio_tools(
    linear_service,
    slack_service,
    notion_service,
    github_service,
    gmail_service,
    google_calendar_service,
    user_id: str,
) -> Tuple[List, List[str]]:
    """
    Load Linear, Slack, Notion, GitHub, Gmail, and Google Calendar tools,
    collecting any errors.

    Returns:
        (tools, errors)
    """
    all_composio_tools: List = []
    errors: List[str] = []

    try:
        linear_tools = linear_service.load_tools(user_id=user_id)
        if linear_tools:
            all_composio_tools.extend(linear_tools)
            print(f"DEBUG: Loaded {len(linear_tools)} Linear tools")
    except Exception as exc:  # noqa: BLE001 - surfaced to caller via errors list
        print(f"DEBUG: Error fetching Linear tools: {exc}")
        errors.append(f"Linear: {str(exc)}")

    try:
        slack_tools = slack_service.load_tools(user_id=user_id)
        if slack_tools:
            all_composio_tools.extend(slack_tools)
            print(f"DEBUG: Loaded {len(slack_tools)} Slack tools")
    except Exception as exc:  # noqa: BLE001 - surfaced to caller via errors list
        print(f"DEBUG: Error fetching Slack tools: {exc}")
        errors.append(f"Slack: {str(exc)}")

    try:
        notion_tools = notion_service.load_tools(user_id=user_id)
        if notion_tools:
            all_composio_tools.extend(notion_tools)
            print(f"DEBUG: Loaded {len(notion_tools)} Notion tools")
    except Exception as exc:  # noqa: BLE001 - surfaced to caller via errors list
        print(f"DEBUG: Error fetching Notion tools: {exc}")
        errors.append(f"Notion: {str(exc)}")

    try:
        github_tools = github_service.load_tools(user_id=user_id)
        if github_tools:
            all_composio_tools.extend(github_tools)
            print(f"DEBUG: Loaded {len(github_tools)} GitHub tools")
    except Exception as exc:  # noqa: BLE001 - surfaced to caller via errors list
        print(f"DEBUG: Error fetching GitHub tools: {exc}")
        errors.append(f"GitHub: {str(exc)}")

    try:
        gmail_tools = gmail_service.load_tools(user_id=user_id)
        if gmail_tools:
            all_composio_tools.extend(gmail_tools)
            print(f"DEBUG: Loaded {len(gmail_tools)} Gmail tools")
    except Exception as exc:  # noqa: BLE001 - surfaced to caller via errors list
        print(f"DEBUG: Error fetching Gmail tools: {exc}")
        errors.append(f"Gmail: {str(exc)}")

    try:
        calendar_tools = google_calendar_service.load_tools(user_id=user_id)
        if calendar_tools:
            all_composio_tools.extend(calendar_tools)
            print(f"DEBUG: Loaded {len(calendar_tools)} Google Calendar tools")
    except Exception as exc:  # noqa: BLE001 - surfaced to caller via errors list
        print(f"DEBUG: Error fetching Google Calendar tools: {exc}")
        errors.append(f"Google Calendar: {str(exc)}")

    return all_composio_tools, errors
