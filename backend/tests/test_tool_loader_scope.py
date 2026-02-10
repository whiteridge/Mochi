"""Unit tests for scoped tool loading."""

from unittest.mock import MagicMock

from backend.agent.tool_loader import load_composio_tools


def _empty_service():
    service = MagicMock()
    service.load_tools.return_value = []
    return service


def test_slack_scope_loads_minimal_tools():
    linear = _empty_service()
    slack = _empty_service()
    notion = _empty_service()
    github = _empty_service()
    gmail = _empty_service()
    calendar = _empty_service()

    slack.load_tools.return_value = ["SLACK_LIST_ALL_CHANNELS", "SLACK_SEND_MESSAGE"]

    tools, errors = load_composio_tools(
        linear,
        slack,
        notion,
        github,
        gmail,
        calendar,
        user_id="user-1",
        required_apps=["slack"],
        intent_scope={"slack": "send"},
    )

    assert errors == []
    assert tools == ["SLACK_LIST_ALL_CHANNELS", "SLACK_SEND_MESSAGE"]
    slack.load_tools.assert_called_once_with(user_id="user-1", scope="send")


def test_scope_loader_widens_to_full_when_scoped_set_empty():
    linear = _empty_service()
    slack = _empty_service()
    notion = _empty_service()
    github = _empty_service()
    gmail = _empty_service()
    calendar = _empty_service()

    scopes_seen = []

    def slack_loader(*, user_id: str, scope: str):
        scopes_seen.append(scope)
        if scope == "send":
            return []
        return ["SLACK_SEND_MESSAGE"]

    slack.load_tools.side_effect = slack_loader

    tools, errors = load_composio_tools(
        linear,
        slack,
        notion,
        github,
        gmail,
        calendar,
        user_id="user-1",
        required_apps=["slack"],
        intent_scope={"slack": "send"},
    )

    assert errors == []
    assert tools == ["SLACK_SEND_MESSAGE"]
    assert scopes_seen == ["send", "full"]
