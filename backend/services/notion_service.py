"""Notion-specific service for tool loading and write detection."""

from typing import Any, Dict, List
from .composio_service import ComposioService
from .composio_tool_aliases import normalize_tool_slug


class NotionService:
    """Service for Notion-specific operations."""

    NOTION_TOOLKITS = ["NOTION"]
    NOTION_READ_PREFIXES = (
        "notion_get_",
        "notion_list_",
        "notion_search",
        "notion_query",
        "notion_fetch_",
        "notion_retrieve_",
    )
    NOTION_WRITE_PREFIXES = (
        "notion_create_",
        "notion_update_",
        "notion_delete_",
        "notion_archive_",
        "notion_append_",
        "notion_add_",
        "notion_remove_",
    )

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
        tool_name_lower = normalize_tool_slug(tool_name).lower()
        if tool_name_lower.startswith(self.NOTION_WRITE_PREFIXES):
            return True

        return False

    def _tool_slug(self, tool: Any) -> str:
        if isinstance(tool, dict):
            for key in ("name", "slug", "tool_name"):
                value = tool.get(key)
                if isinstance(value, str):
                    return value
        for attr in ("name", "slug", "tool_name"):
            value = getattr(tool, attr, None)
            if isinstance(value, str):
                return value
        return ""

    def _filter_tools_by_scope(self, tools: List[Any], scope: str) -> List[Any]:
        if scope == "full":
            return tools
        if scope == "write":
            prefixes = self.NOTION_WRITE_PREFIXES
        elif scope == "mixed":
            prefixes = self.NOTION_WRITE_PREFIXES + self.NOTION_READ_PREFIXES
        else:
            prefixes = self.NOTION_READ_PREFIXES

        filtered: List[Any] = []
        for tool in tools:
            slug = self._tool_slug(tool)
            if not slug:
                continue
            normalized_slug = normalize_tool_slug(slug).lower()
            if normalized_slug.startswith(prefixes):
                filtered.append(tool)
        return filtered

    def load_tools(self, user_id: str, scope: str = "full") -> List[Any]:
        """
        Load all Notion tools for the user from the Notion toolkit.

        Args:
            user_id: The user ID to load tools for

        Returns:
            List of tool objects
        """
        tools = self.composio_service.fetch_tools(
            user_id=user_id,
            toolkits=self.NOTION_TOOLKITS,
        )
        filtered = self._filter_tools_by_scope(tools, scope)
        if not filtered and scope != "full":
            print(f"DEBUG: No Notion tools available after filtering scope={scope}.")
        return filtered

    def enrich_proposal(self, user_id: str, args: Dict[str, Any], tool_name: str = "") -> Dict[str, Any]:
        """
        Hook to enrich Notion proposals; currently a passthrough.
        """
        return args
