"""Helper for loading Composio tools across apps."""

from typing import List, Tuple


def load_composio_tools(linear_service, slack_service, user_id: str) -> Tuple[List, List[str]]:
    """
    Load Linear and Slack tools, collecting any errors.

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

    return all_composio_tools, errors


