"""Gmail-specific service for actions, queries, and write detection."""

from typing import Any, Dict, List
from .composio_service import ComposioService
from .composio_tool_aliases import normalize_tool_slug


class GmailService:
    """Service for Gmail-specific operations."""

    GMAIL_ACTION_SLUGS = [
        "GMAIL_FETCH_EMAILS",
        "GMAIL_FETCH_MESSAGE_BY_MESSAGE_ID",
        "GMAIL_FETCH_MESSAGE_BY_THREAD_ID",
        "GMAIL_LIST_THREADS",
        "GMAIL_LIST_LABELS",
        "GMAIL_LIST_DRAFTS",
        "GMAIL_LIST_HISTORY",
        "GMAIL_GET_PROFILE",
        "GMAIL_GET_ATTACHMENT",
        "GMAIL_SEND_EMAIL",
        "GMAIL_CREATE_EMAIL_DRAFT",
        "GMAIL_SEND_DRAFT",
        "GMAIL_REPLY_TO_THREAD",
        "GMAIL_FORWARD_MESSAGE",
        "GMAIL_ADD_LABEL_TO_EMAIL",
        "GMAIL_MODIFY_THREAD_LABELS",
        "GMAIL_MOVE_TO_TRASH",
        "GMAIL_DELETE_MESSAGE",
        "GMAIL_BATCH_MODIFY_MESSAGES",
        "GMAIL_BATCH_DELETE_MESSAGES",
        "GMAIL_CREATE_LABEL",
        "GMAIL_PATCH_LABEL",
        "GMAIL_DELETE_LABEL",
        "GMAIL_DELETE_DRAFT",
    ]

    def __init__(self, composio_service: ComposioService):
        """
        Initialize GmailService with a ComposioService instance.

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
            "gmail_send_",
            "gmail_reply_",
            "gmail_forward_",
            "gmail_create_",
            "gmail_delete_",
            "gmail_patch_",
            "gmail_modify_",
            "gmail_add_",
            "gmail_move_",
            "gmail_batch_",
        )
        if tool_name_lower.startswith(write_prefixes):
            print(f"DEBUG: Detected GMAIL WRITE action: {normalized_name}")
            return True

        print(f"DEBUG: Detected GMAIL READ action: {normalized_name}")
        return False

    def load_tools(self, user_id: str) -> List[Any]:
        """
        Load the curated list of Gmail tools for the user.

        Args:
            user_id: The user ID to load tools for

        Returns:
            List of tool objects
        """
        return self.composio_service.fetch_tools(
            user_id=user_id,
            slugs=self.GMAIL_ACTION_SLUGS,
        )

    def enrich_proposal(
        self, user_id: str, args: Dict[str, Any], tool_name: str = ""
    ) -> Dict[str, Any]:
        """
        Hook to enrich Gmail proposals; currently a passthrough.
        """
        return args
