"""Unit tests for SlackService enrichment behavior."""

from unittest.mock import MagicMock

from backend.services.slack_service import SlackService


def test_enrich_proposal_adds_channel_display_when_resolved():
    composio_service = MagicMock()
    composio_service.execute_tool.return_value = {
        "data": {
            "channels": [
                {"id": "C0A101WM3T4", "name": "general"},
            ]
        }
    }
    service = SlackService(composio_service)

    enriched = service.enrich_proposal(
        user_id="user-1",
        args={"channel": "C0A101WM3T4", "markdown_text": "Hello!"},
        tool_name="SLACK_SEND_MESSAGE",
    )

    assert enriched["channelName"] == "#general"
    assert enriched["channelDisplay"] == "#general (C0A101WM3T4)"
    composio_service.execute_tool.assert_called_once_with(
        slug="SLACK_LIST_ALL_CHANNELS",
        arguments={"types": "public_channel,private_channel"},
        user_id="user-1",
    )


def test_enrich_proposal_uses_pretty_fallback_when_unresolved():
    composio_service = MagicMock()
    composio_service.execute_tool.return_value = {"data": {"channels": []}}
    service = SlackService(composio_service)

    enriched = service.enrich_proposal(
        user_id="user-1",
        args={"channel": "C1234567890", "markdown_text": "Hello!"},
        tool_name="SLACK_SEND_MESSAGE",
    )

    assert enriched["channelDisplay"] == "Channel (C1234567890)"
    assert "channelName" not in enriched


def test_channel_name_lookup_uses_cache_for_repeated_ids():
    composio_service = MagicMock()
    composio_service.execute_tool.return_value = {
        "data": {
            "channels": [
                {"id": "C0A101WM3T4", "name": "general"},
            ]
        }
    }
    service = SlackService(composio_service)

    first = service.enrich_proposal(
        user_id="user-1",
        args={"channel": "C0A101WM3T4"},
        tool_name="SLACK_SEND_MESSAGE",
    )
    second = service.enrich_proposal(
        user_id="user-1",
        args={"channel": "C0A101WM3T4"},
        tool_name="SLACK_SEND_MESSAGE",
    )

    assert first["channelDisplay"] == "#general (C0A101WM3T4)"
    assert second["channelDisplay"] == "#general (C0A101WM3T4)"
    assert composio_service.execute_tool.call_count == 1
