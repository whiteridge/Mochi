"""Unit tests for GoogleCalendarService."""

from unittest.mock import MagicMock

from backend.services.google_calendar_service import GoogleCalendarService


def test_google_calendar_write_action_detection():
    service = GoogleCalendarService(MagicMock())

    assert service.is_write_action("GOOGLECALENDAR_CREATE_EVENT", {}) is True
    assert service.is_write_action("GOOGLECALENDAR_UPDATE_EVENT", {}) is True
    assert service.is_write_action("GOOGLECALENDAR_EVENTS_LIST", {}) is False


def test_google_calendar_load_tools_uses_slugs():
    composio_service = MagicMock()
    composio_service.fetch_tools.return_value = ["tool"]
    service = GoogleCalendarService(composio_service)

    tools = service.load_tools(user_id="user-1")

    composio_service.fetch_tools.assert_called_with(
        user_id="user-1",
        slugs=service.GOOGLE_CALENDAR_ACTION_SLUGS,
    )
    assert tools == ["tool"]
