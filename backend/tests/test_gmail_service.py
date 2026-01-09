"""Unit tests for GmailService."""

from unittest.mock import MagicMock

from backend.services.gmail_service import GmailService


def test_gmail_write_action_detection():
    service = GmailService(MagicMock())

    assert service.is_write_action("GMAIL_SEND_EMAIL", {}) is True
    assert service.is_write_action("GMAIL_DELETE_MESSAGE", {}) is True
    assert service.is_write_action("GMAIL_FETCH_EMAILS", {}) is False


def test_gmail_load_tools_uses_slugs():
    composio_service = MagicMock()
    composio_service.fetch_tools.return_value = ["tool"]
    service = GmailService(composio_service)

    tools = service.load_tools(user_id="user-1")

    composio_service.fetch_tools.assert_called_with(
        user_id="user-1",
        slugs=service.GMAIL_ACTION_SLUGS,
    )
    assert tools == ["tool"]
