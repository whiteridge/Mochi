"""Google Calendar-specific service for actions and write detection."""

from typing import Any, Dict, List
from .composio_service import ComposioService
from .composio_tool_aliases import normalize_tool_slug


class GoogleCalendarService:
    """Service for Google Calendar-specific operations."""

    GOOGLE_CALENDAR_ACTION_SLUGS = [
        "GOOGLECALENDAR_LIST_CALENDARS",
        "GOOGLECALENDAR_GET_CALENDAR",
        "GOOGLECALENDAR_LIST_SETTINGS",
        "GOOGLECALENDAR_COLORS_GET",
        "GOOGLECALENDAR_EVENTS_LIST",
        "GOOGLECALENDAR_EVENTS_LIST_ALL_CALENDARS",
        "GOOGLECALENDAR_EVENTS_GET",
        "GOOGLECALENDAR_EVENTS_INSTANCES",
        "GOOGLECALENDAR_FIND_EVENT",
        "GOOGLECALENDAR_FIND_FREE_SLOTS",
        "GOOGLECALENDAR_FREE_BUSY_QUERY",
        "GOOGLECALENDAR_GET_CURRENT_DATE_TIME",
        "GOOGLECALENDAR_CREATE_EVENT",
        "GOOGLECALENDAR_UPDATE_EVENT",
        "GOOGLECALENDAR_PATCH_EVENT",
        "GOOGLECALENDAR_DELETE_EVENT",
        "GOOGLECALENDAR_QUICK_ADD",
        "GOOGLECALENDAR_EVENTS_IMPORT",
        "GOOGLECALENDAR_EVENTS_MOVE",
        "GOOGLECALENDAR_REMOVE_ATTENDEE",
        "GOOGLECALENDAR_CLEAR_CALENDAR",
        "GOOGLECALENDAR_CALENDARS_UPDATE",
        "GOOGLECALENDAR_PATCH_CALENDAR",
        "GOOGLECALENDAR_CALENDARS_DELETE",
        "GOOGLECALENDAR_CALENDAR_LIST_LIST",
        "GOOGLECALENDAR_CALENDAR_LIST_INSERT",
        "GOOGLECALENDAR_CALENDAR_LIST_UPDATE",
        "GOOGLECALENDAR_CALENDAR_LIST_PATCH",
        "GOOGLECALENDAR_CALENDAR_LIST_DELETE",
        "GOOGLECALENDAR_LIST_ACL_RULES",
        "GOOGLECALENDAR_ACL_INSERT",
        "GOOGLECALENDAR_ACL_PATCH",
        "GOOGLECALENDAR_ACL_DELETE",
    ]

    GOOGLE_CALENDAR_READ_CORE_SLUGS = [
        "GOOGLECALENDAR_LIST_CALENDARS",
        "GOOGLECALENDAR_EVENTS_LIST",
        "GOOGLECALENDAR_EVENTS_GET",
        "GOOGLECALENDAR_FIND_EVENT",
        "GOOGLECALENDAR_FIND_FREE_SLOTS",
        "GOOGLECALENDAR_FREE_BUSY_QUERY",
        "GOOGLECALENDAR_GET_CURRENT_DATE_TIME",
    ]

    GOOGLE_CALENDAR_WRITE_CORE_SLUGS = [
        "GOOGLECALENDAR_CREATE_EVENT",
        "GOOGLECALENDAR_UPDATE_EVENT",
        "GOOGLECALENDAR_PATCH_EVENT",
        "GOOGLECALENDAR_DELETE_EVENT",
        "GOOGLECALENDAR_QUICK_ADD",
    ]

    def __init__(self, composio_service: ComposioService):
        """
        Initialize GoogleCalendarService with a ComposioService instance.

        Args:
            composio_service: The ComposioService instance to use for execution
        """
        self.composio_service = composio_service

    def is_write_action(
        self,
        tool_name: str,
        tool_args: Dict[str, Any],
    ) -> bool:
        """
        Detect if a tool represents a write action that requires
        user confirmation.

        Args:
            tool_name: The name of the tool
            tool_args: The arguments for the tool (unused today)

        Returns:
            True if this is a write action, False otherwise
        """
        tool_name_lower = normalize_tool_slug(tool_name).lower()
        write_tokens = (
            "create_",
            "update_",
            "patch_",
            "delete_",
            "quick_add",
            "remove_",
            "move",
            "import",
            "duplicate_",
            "clear_",
            "insert",
        )
        if any(token in tool_name_lower for token in write_tokens):
            return True

        return False

    def _slugs_for_scope(self, scope: str) -> List[str]:
        if scope == "read":
            selected = self.GOOGLE_CALENDAR_READ_CORE_SLUGS
        elif scope == "write":
            selected = self.GOOGLE_CALENDAR_WRITE_CORE_SLUGS
        elif scope == "mixed":
            selected = (
                self.GOOGLE_CALENDAR_READ_CORE_SLUGS
                + self.GOOGLE_CALENDAR_WRITE_CORE_SLUGS
            )
        else:
            selected = self.GOOGLE_CALENDAR_ACTION_SLUGS
        return list(dict.fromkeys(selected))

    def load_tools(self, user_id: str, scope: str = "full") -> List[Any]:
        """
        Load the curated list of Google Calendar tools for the user.

        Args:
            user_id: The user ID to load tools for

        Returns:
            List of tool objects
        """
        return self.composio_service.fetch_tools(
            user_id=user_id,
            slugs=self._slugs_for_scope(scope),
        )

    def enrich_proposal(
        self, user_id: str, args: Dict[str, Any], tool_name: str = ""
    ) -> Dict[str, Any]:
        """
        Hook to enrich Google Calendar proposals; currently a passthrough.
        """
        enriched = dict(args)
        if "calendar_id" not in enriched and "calendarId" not in enriched:
            enriched["calendar_id"] = "primary"
        return enriched
