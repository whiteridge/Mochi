"""Slack-specific service for actions, queries, and enrichment."""

from typing import Dict, Any, List, Optional
from composio.exceptions import EnumMetadataNotFound
from .composio_service import ComposioService


class SlackService:
    """Service for Slack-specific operations."""
    
    SLACK_ACTION_SLUGS = [
        "SLACK_SEND_MESSAGE",
        "SLACK_SEND_EPHEMERAL_MESSAGE",
        "SLACK_SCHEDULE_MESSAGE",
        "SLACK_LIST_ALL_CHANNELS",
        "SLACK_LIST_CONVERSATIONS",
        "SLACK_LIST_ALL_USERS",
        "SLACK_SEARCH_MESSAGES",
        "SLACK_SEARCH_ALL",
        "SLACK_FETCH_CONVERSATION_HISTORY",
        "SLACK_ARCHIVE_CHANNEL",
        "SLACK_CREATE_CHANNEL",
        "SLACK_INVITE_USER_TO_CHANNEL",
        "SLACK_KICK_USER_FROM_CHANNEL",
        "SLACK_LEAVE_CHANNEL",
        "SLACK_RENAME_CHANNEL",
        "SLACK_SET_PURPOSE",
        "SLACK_SET_TOPIC",
    ]
    
    def __init__(self, composio_service: ComposioService):
        """
        Initialize SlackService with a ComposioService instance.
        
        Args:
            composio_service: The ComposioService instance to use for execution
        """
        self.composio_service = composio_service
    
    def is_write_action(self, tool_name: str, tool_args: dict) -> bool:
        """
        Detect if a tool represents a Write action that requires user confirmation.
        
        Args:
            tool_name: The name of the tool
            tool_args: The arguments for the tool
            
        Returns:
            True if this is a write action, False otherwise
        """
        tool_name_lower = tool_name.lower()
        
        # Explicit list of write actions
        write_actions = [
            "slack_send_message",
            "slack_send_ephemeral_message",
            "slack_schedule_message",
            "slack_archive_channel",
            "slack_create_channel",
            "slack_invite_user_to_channel",
            "slack_kick_user_from_channel",
            "slack_leave_channel",
            "slack_rename_channel",
            "slack_set_purpose",
            "slack_set_topic",
        ]
        
        if any(action in tool_name_lower for action in write_actions):
            print(f"DEBUG: Detected SLACK WRITE action: {tool_name}")
            return True
            
        print(f"DEBUG: Detected SLACK READ action: {tool_name}")
        return False
    
    def load_tools(self, user_id: str) -> List[Any]:
        """
        Attempt to load the curated list of Slack tools for a user.
        
        Args:
            user_id: The user ID to load tools for
            
        Returns:
            List of tool objects
        """
        remaining = self.SLACK_ACTION_SLUGS.copy()
        skipped: List[str] = []

        # Simple retry logic similar to LinearService to handle missing tools gracefully
        while remaining:
            try:
                tools = self.composio_service.fetch_tools(
                    user_id=user_id,
                    slugs=remaining,
                )
                if skipped:
                    print(f"DEBUG: Skipped unavailable Slack actions: {skipped}")
                return tools
            except EnumMetadataNotFound as enum_error:
                # Try to extract missing slug from error message if possible
                # This depends on Composio error message format
                error_str = str(enum_error)
                import re
                match = re.search(r"`([A-Z0-9_]+)`", error_str)
                missing_slug = match.group(1) if match else None
                
                if missing_slug and missing_slug in remaining:
                    print(f"DEBUG: Slack action {missing_slug} is unavailable. Skipping.")
                    remaining = [slug for slug in remaining if slug != missing_slug]
                    skipped.append(missing_slug)
                    continue
                raise
            except Exception as e:
                error_str = str(e)
                if "not found" in error_str.lower() or "does not exist" in error_str.lower():
                    for slug in remaining:
                        if slug.lower() in error_str.lower():
                            print(f"DEBUG: Tool {slug} not found. Skipping.")
                            remaining = [s for s in remaining if s != slug]
                            skipped.append(slug)
                            break
                    else:
                        raise
                else:
                    raise

        raise RuntimeError(f"Unable to load any Slack tools. Missing: {skipped}")

    def enrich_proposal(self, user_id: str, args: Dict[str, Any], tool_name: str = "") -> Dict[str, Any]:
        """
        Enriches proposal args with human-readable names for IDs.
        
        Args:
            user_id: The user ID for executing queries
            args: The original arguments dictionary
            tool_name: The name of the tool being called
            
        Returns:
            Enriched arguments dictionary
        """
        enriched_args = args.copy()
        
        try:
            # Enrich Channel Name
            channel_id = args.get("channel")
            if channel_id and isinstance(channel_id, str) and "channelName" not in enriched_args:
                # Try to resolve channel name
                # We can use SLACK_LIST_CONVERSATIONS or SLACK_LIST_ALL_CHANNELS
                # But since we don't have a direct "get_channel_info" tool easily accessible without listing,
                # we might rely on the fact that the agent usually searches first.
                # However, for a robust UI, we should try to fetch it.
                # Fetching ALL channels might be heavy if there are thousands.
                # Let's try to see if we can use a more targeted approach or just list conversations (usually smaller set of joined channels).
                
                print(f"DEBUG: Attempting to resolve Slack channel ID: {channel_id}")
                
                # We'll try listing conversations (joined channels) first as it's safer/smaller
                try:
                    result = self.composio_service.execute_action(
                        action_slug="SLACK_LIST_CONVERSATIONS",
                        arguments={"types": "public_channel,private_channel", "limit": 1000}, # Try to get enough
                        user_id=user_id
                    )
                    
                    channels = []
                    if result.get("successful"):
                        data = result.get("data", {})
                        if isinstance(data, dict):
                            channels = data.get("channels", [])
                    
                    found_channel = next((c for c in channels if c.get("id") == channel_id), None)
                    
                    if found_channel:
                        name = found_channel.get("name")
                        if name:
                            enriched_args["channelName"] = f"#{name}"
                            print(f"DEBUG: Resolved channel {channel_id} to #{name}")
                    else:
                        # Fallback: maybe it's a user DM? Or not in joined channels?
                        # Let's try LIST_ALL_USERS if it looks like a user ID (starts with U or W)
                        if channel_id.startswith("U") or channel_id.startswith("W"):
                             self._enrich_user_name(user_id, channel_id, enriched_args, "channelName")
                        
                except Exception as e:
                    print(f"DEBUG: Failed to resolve channel name: {e}")

            # Enrich User (if sending DM or ephemeral)
            user_target = args.get("user")
            if user_target and isinstance(user_target, str) and "userName" not in enriched_args:
                 self._enrich_user_name(user_id, user_target, enriched_args, "userName")

        except Exception as e:
            print(f"DEBUG: Error enriching Slack proposal: {e}")
            
        return enriched_args

    def _enrich_user_name(self, user_id: str, target_user_id: str, enriched_args: Dict[str, Any], key: str):
        """Helper to resolve user ID to name."""
        try:
            # We don't have a direct "get user" tool in the list I defined, 
            # but SLACK_LIST_ALL_USERS is there.
            # Again, listing all users might be heavy. 
            # But let's try it for now or assume the agent did it.
            # Actually, let's try to fetch it.
            
            print(f"DEBUG: Attempting to resolve Slack user ID: {target_user_id}")
            result = self.composio_service.execute_action(
                action_slug="SLACK_LIST_ALL_USERS",
                arguments={"limit": 1000}, 
                user_id=user_id
            )
            
            users = []
            if result.get("successful"):
                data = result.get("data", {})
                if isinstance(data, dict):
                    users = data.get("members", [])
            
            found_user = next((u for u in users if u.get("id") == target_user_id), None)
            
            if found_user:
                real_name = found_user.get("real_name") or found_user.get("name")
                if real_name:
                    enriched_args[key] = real_name
                    print(f"DEBUG: Resolved user {target_user_id} to {real_name}")
                    
        except Exception as e:
            print(f"DEBUG: Failed to resolve user name: {e}")
