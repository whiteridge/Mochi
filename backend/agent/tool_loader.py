"""Helper for loading Composio tools across apps."""

from typing import Dict, List, Optional, Tuple


def _normalize_app_name(app_name: str) -> str:
    normalized = app_name.lower().replace("-", "_").replace(" ", "_")
    if normalized in {"googlecalendar", "google_calendar", "calendar"}:
        return "google_calendar"
    if normalized in {"googlemail"}:
        return "gmail"
    return normalized


def load_composio_tools(
    linear_service,
    slack_service,
    notion_service,
    github_service,
    gmail_service,
    google_calendar_service,
    user_id: str,
    required_apps: Optional[List[str]] = None,
    intent_scope: Optional[Dict[str, str]] = None,
) -> Tuple[List, List[str]]:
    """
    Load Linear, Slack, Notion, GitHub, Gmail, and Google Calendar tools,
    collecting any errors.

    Returns:
        (tools, errors)
    """
    all_composio_tools: List = []
    errors: List[str] = []

    requested_apps = None
    if required_apps:
        requested_apps = {
            _normalize_app_name(app_name)
            for app_name in required_apps
            if app_name
        }
    normalized_intent_scope = {
        _normalize_app_name(app_name): scope
        for app_name, scope in (intent_scope or {}).items()
        if app_name
    }

    def should_load(app_name: str) -> bool:
        if requested_apps is None:
            return True
        return _normalize_app_name(app_name) in requested_apps

    def scope_for(app_name: str) -> str:
        normalized = _normalize_app_name(app_name)
        return normalized_intent_scope.get(normalized, "full")

    def load_with_fallback(app_name: str, loader) -> List:
        requested_scope = scope_for(app_name)
        try:
            tools = loader(requested_scope)
            if tools:
                return tools
            if requested_scope != "full":
                print(
                    f"DEBUG: No tools loaded for {app_name} scope={requested_scope}. "
                    "Retrying with full scope."
                )
                return loader("full")
            return tools
        except Exception as scoped_exc:  # noqa: BLE001
            if requested_scope != "full":
                print(
                    f"DEBUG: Scoped tool load failed for {app_name} "
                    f"(scope={requested_scope}): {scoped_exc}. Retrying full scope."
                )
                return loader("full")
            raise

    if should_load("linear"):
        try:
            linear_tools = load_with_fallback(
                "linear",
                lambda scope: linear_service.load_tools(user_id=user_id, scope=scope),
            )
            if linear_tools:
                all_composio_tools.extend(linear_tools)
                print(f"DEBUG: Loaded {len(linear_tools)} Linear tools")
        except Exception as exc:  # noqa: BLE001 - surfaced to caller via errors list
            print(f"DEBUG: Error fetching Linear tools: {exc}")
            errors.append(f"Linear: {str(exc)}")

    if should_load("slack"):
        try:
            slack_tools = load_with_fallback(
                "slack",
                lambda scope: slack_service.load_tools(user_id=user_id, scope=scope),
            )
            if slack_tools:
                all_composio_tools.extend(slack_tools)
                print(f"DEBUG: Loaded {len(slack_tools)} Slack tools")
        except Exception as exc:  # noqa: BLE001 - surfaced to caller via errors list
            print(f"DEBUG: Error fetching Slack tools: {exc}")
            errors.append(f"Slack: {str(exc)}")

    if should_load("notion"):
        try:
            notion_tools = load_with_fallback(
                "notion",
                lambda scope: notion_service.load_tools(user_id=user_id, scope=scope),
            )
            if notion_tools:
                all_composio_tools.extend(notion_tools)
                print(f"DEBUG: Loaded {len(notion_tools)} Notion tools")
        except Exception as exc:  # noqa: BLE001 - surfaced to caller via errors list
            print(f"DEBUG: Error fetching Notion tools: {exc}")
            errors.append(f"Notion: {str(exc)}")

    if should_load("github"):
        try:
            github_tools = load_with_fallback(
                "github",
                lambda scope: github_service.load_tools(user_id=user_id, scope=scope),
            )
            if github_tools:
                all_composio_tools.extend(github_tools)
                print(f"DEBUG: Loaded {len(github_tools)} GitHub tools")
        except Exception as exc:  # noqa: BLE001 - surfaced to caller via errors list
            print(f"DEBUG: Error fetching GitHub tools: {exc}")
            errors.append(f"GitHub: {str(exc)}")

    if should_load("gmail"):
        try:
            gmail_tools = load_with_fallback(
                "gmail",
                lambda scope: gmail_service.load_tools(user_id=user_id, scope=scope),
            )
            if gmail_tools:
                all_composio_tools.extend(gmail_tools)
                print(f"DEBUG: Loaded {len(gmail_tools)} Gmail tools")
        except Exception as exc:  # noqa: BLE001 - surfaced to caller via errors list
            print(f"DEBUG: Error fetching Gmail tools: {exc}")
            errors.append(f"Gmail: {str(exc)}")

    if should_load("google_calendar"):
        try:
            calendar_tools = load_with_fallback(
                "google_calendar",
                lambda scope: google_calendar_service.load_tools(
                    user_id=user_id, scope=scope
                ),
            )
            if calendar_tools:
                all_composio_tools.extend(calendar_tools)
                print(f"DEBUG: Loaded {len(calendar_tools)} Google Calendar tools")
        except Exception as exc:  # noqa: BLE001 - surfaced to caller via errors list
            print(f"DEBUG: Error fetching Google Calendar tools: {exc}")
            errors.append(f"Google Calendar: {str(exc)}")

    return all_composio_tools, errors
