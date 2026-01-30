"""Slack-specific service for actions, queries, and enrichment."""

import json
from typing import Dict, Any, List, Optional
from composio.exceptions import EnumMetadataNotFound
from .composio_tool_aliases import normalize_tool_slug
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
        "SLACK_CREATE_CHANNEL",
        "SLACK_INVITE_USER_TO_CHANNEL",
        "SLACK_REMOVE_A_USER_FROM_A_CONVERSATION",
        "SLACK_LEAVE_A_CONVERSATION",
        "SLACK_ARCHIVE_A_SLACK_CONVERSATION",
        "SLACK_RENAME_A_CONVERSATION",
        "SLACK_SET_A_CONVERSATION_S_PURPOSE",
        "SLACK_SET_THE_TOPIC_OF_A_CONVERSATION",
        "SLACK_UPDATES_A_SLACK_MESSAGE",
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
        normalized_name = normalize_tool_slug(tool_name)
        tool_name_lower = normalized_name.lower()
        
        # Explicit list of write actions
        write_actions = {
            "slack_send_message",
            "slack_send_ephemeral_message",
            "slack_schedule_message",
            "slack_create_channel",
            "slack_invite_user_to_channel",
            "slack_remove_a_user_from_a_conversation",
            "slack_leave_a_conversation",
            "slack_archive_a_slack_conversation",
            "slack_rename_a_conversation",
            "slack_set_a_conversation_s_purpose",
            "slack_set_the_topic_of_a_conversation",
            "slack_updates_a_slack_message",
        }

        if tool_name_lower in write_actions:
            print(f"DEBUG: Detected SLACK WRITE action: {normalized_name}")
            return True
            
        print(f"DEBUG: Detected SLACK READ action: {normalized_name}")
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
            channel_id = args.get("channel") or args.get("channel_id")
            if channel_id and isinstance(channel_id, str) and "channelName" not in enriched_args:
                # If already human readable, keep it.
                if channel_id.startswith("#") or channel_id.startswith("@"):
                    enriched_args["channelName"] = channel_id
                else:
                    print(f"DEBUG: Attempting to resolve Slack channel ID: {channel_id}")
                    resolved = self._resolve_channel_name(user_id, channel_id)
                    if resolved:
                        enriched_args["channelName"] = resolved
                    else:
                        # Fallback: maybe it's a user DM? Or not in joined channels?
                        if channel_id.startswith("U") or channel_id.startswith("W"):
                            self._enrich_user_name(user_id, channel_id, enriched_args, "channelName")

            # Enrich User (if sending DM or ephemeral)
            user_target = args.get("user")
            if user_target and isinstance(user_target, str) and "userName" not in enriched_args:
                 self._enrich_user_name(user_id, user_target, enriched_args, "userName")

        except Exception as e:
            print(f"DEBUG: Error enriching Slack proposal: {e}")
            
        return enriched_args

    def _resolve_channel_name(self, user_id: str, channel_id: str) -> Optional[str]:
        """Resolve a Slack channel ID to a human-readable name."""
        action_slugs = [
            ("SLACK_LIST_CONVERSATIONS", {"types": "public_channel,private_channel", "limit": 1000}),
            ("SLACK_LIST_ALL_CHANNELS", {"types": "public_channel,private_channel"}),
        ]

        for action_slug, arguments in action_slugs:
            try:
                result = self.composio_service.execute_action(
                    action_slug=action_slug,
                    arguments=arguments,
                    user_id=user_id,
                )
            except Exception as exc:
                print(f"DEBUG: Failed to resolve channel via {action_slug}: {exc}")
                continue

            if not result.get("successful"):
                continue

            data = result.get("data", {})
            if isinstance(data, str):
                try:
                    data = json.loads(data)
                except json.JSONDecodeError:
                    data = {}

            channels: List[Dict[str, Any]] = []
            if isinstance(data, list):
                channels = data
            elif isinstance(data, dict):
                for key in ("channels", "conversations", "items", "data"):
                    value = data.get(key)
                    if isinstance(value, list):
                        channels = value
                        break

            found = next((c for c in channels if c.get("id") == channel_id), None)
            if found:
                name = found.get("name")
                if name:
                    resolved = f"#{name}"
                    print(f"DEBUG: Resolved channel {channel_id} to {resolved}")
                    return resolved

        return None

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
