"""GitHub-specific service for tool loading and write detection."""

from typing import Any, Dict, List
from .composio_service import ComposioService
from .composio_tool_aliases import normalize_tool_slug


class GitHubService:
    """Service for GitHub-specific operations."""

    GITHUB_TOOLKITS = ["GITHUB"]

    def __init__(self, composio_service: ComposioService):
        """
        Initialize GitHubService with a ComposioService instance.

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
        normalized_name = normalize_tool_slug(tool_name)
        tool_name_lower = normalized_name.lower()
        write_prefixes = (
            "github_create_",
            "github_update_",
            "github_delete_",
            "github_merge_",
            "github_close_",
            "github_add_",
            "github_remove_",
            "github_star_",
            "github_unstar_",
            "github_fork_",
            "github_unfork_",
            "github_lock_",
            "github_unlock_",
            "github_reopen_",
            "github_request_",
            "github_submit_",
            "github_dispatch_",
            "github_archive_",
            "github_unarchive_",
            "github_publish_",
            "github_rename_",
            "github_invite_",
        )
        if tool_name_lower.startswith(write_prefixes):
            print(f"DEBUG: Detected GITHUB WRITE action: {normalized_name}")
            return True

        print(f"DEBUG: Detected GITHUB READ action: {normalized_name}")
        return False

    def load_tools(self, user_id: str) -> List[Any]:
        """
        Load all GitHub tools for the user from the GitHub toolkit.

        Args:
            user_id: The user ID to load tools for

        Returns:
            List of tool objects
        """
        return self.composio_service.fetch_tools(
            user_id=user_id,
            toolkits=self.GITHUB_TOOLKITS,
        )

    def enrich_proposal(
        self, user_id: str, args: Dict[str, Any], tool_name: str = ""
    ) -> Dict[str, Any]:
        """
        Hook to enrich GitHub proposals; currently a passthrough.
        """
        return args
