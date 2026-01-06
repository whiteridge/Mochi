"""Notion-specific service for tool loading and write detection."""

from typing import Any, Dict, List
from .composio_service import ComposioService


class NotionService:
    """Service for Notion-specific operations."""

    NOTION_TOOLKITS = ["NOTION"]

    def __init__(self, composio_service: ComposioService):
        """
        Initialize NotionService with a ComposioService instance.

        Args:
            composio_service: The ComposioService instance to use for execution
        """
        self.composio_service = composio_service

    def is_write_action(self, tool_name: str, tool_args: Dict[str, Any]) -> bool:
        """
        Detect if a tool represents a write action that requires user confirmation.

        Args:
            tool_name: The name of the tool
            tool_args: The arguments for the tool (unused today)

        Returns:
            True if this is a write action, False otherwise
        """
        tool_name_lower = tool_name.lower()
        write_prefixes = (
            "notion_create_",
            "notion_update_",
            "notion_delete_",
            "notion_archive_",
            "notion_append_",
            "notion_add_",
            "notion_remove_",
        )
        if tool_name_lower.startswith(write_prefixes):
            print(f"DEBUG: Detected NOTION WRITE action: {tool_name}")
            return True

        print(f"DEBUG: Detected NOTION READ action: {tool_name}")
        return False

    def load_tools(self, user_id: str) -> List[Any]:
        """
        Load all Notion tools for the user from the Notion toolkit.

        Args:
            user_id: The user ID to load tools for

        Returns:
            List of tool objects
        """
        return self.composio_service.fetch_tools(
            user_id=user_id,
            toolkits=self.NOTION_TOOLKITS,
        )

    def enrich_proposal(self, user_id: str, args: Dict[str, Any], tool_name: str = "") -> Dict[str, Any]:
        """
        Hook to enrich Notion proposals; currently a passthrough.
        """
        return args
