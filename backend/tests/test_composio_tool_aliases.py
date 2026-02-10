"""Tests for Composio tool slug aliasing and write detection."""

from unittest.mock import MagicMock

from backend.services.composio_tool_aliases import normalize_tool_slug
from backend.services.slack_service import SlackService


def test_normalize_tool_slug_maps_legacy():
    assert normalize_tool_slug("linear_update_linear_issue") == "LINEAR_UPDATE_ISSUE"
    assert normalize_tool_slug("SLACK_SET_TOPIC") == (
        "SLACK_SET_THE_TOPIC_OF_A_CONVERSATION"
    )
    assert normalize_tool_slug("NOTION_CREATE_PAGE") == "NOTION_CREATE_NOTION_PAGE"


def test_normalize_tool_slug_passthrough():
    assert normalize_tool_slug("SLACK_SEND_MESSAGE") == "SLACK_SEND_MESSAGE"


def test_normalize_tool_slug_uppercases_unknown_slug():
    assert normalize_tool_slug("linear_list_linear_teams") == "LINEAR_LIST_LINEAR_TEAMS"


def test_slack_write_action_aliases():
    service = SlackService(MagicMock())

    assert service.is_write_action("SLACK_SET_TOPIC", {}) is True
    assert service.is_write_action("SLACK_UPDATES_A_SLACK_MESSAGE", {}) is True
    assert service.is_write_action("SLACK_SEARCH_MESSAGES", {}) is False
