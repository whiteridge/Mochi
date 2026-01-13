"""Unit tests for NotionService."""

from unittest.mock import MagicMock

from backend.services.notion_service import NotionService


def test_notion_write_action_detection():
    service = NotionService(MagicMock())

    assert service.is_write_action("NOTION_CREATE_PAGE", {}) is True
    assert service.is_write_action("NOTION_UPDATE_PAGE", {}) is True
    assert service.is_write_action("NOTION_DELETE_PAGE", {}) is True
    assert service.is_write_action("NOTION_ARCHIVE_PAGE", {}) is True
    assert service.is_write_action("NOTION_SEARCH", {}) is False


def test_notion_load_tools_uses_toolkit_filter():
    composio_service = MagicMock()
    composio_service.fetch_tools.return_value = ["tool"]
    service = NotionService(composio_service)

    tools = service.load_tools(user_id="user-1")

    composio_service.fetch_tools.assert_called_with(
        user_id="user-1",
        toolkits=["NOTION"],
    )
    assert tools == ["tool"]
