"""Linear-specific service for actions, queries, and enrichment."""

import json
import re
from typing import Dict, Any, List, Optional
from composio.exceptions import EnumMetadataNotFound
from .composio_service import ComposioService
from .linear_enricher import LinearEnricher


class LinearService:
    """Service for Linear-specific operations."""
    
    LINEAR_ACTION_SLUGS = [
        "LINEAR_CREATE_LINEAR_ISSUE",
        "LINEAR_CREATE_LINEAR_ISSUE_DETAILS",
        "LINEAR_CREATE_LINEAR_LABEL",
        "LINEAR_CREATE_LINEAR_PROJECT",
        "LINEAR_DELETE_LINEAR_ISSUE",
        "LINEAR_GET_ALL_LINEAR_TEAMS",
        "LINEAR_GET_ATTACHMENTS",
        "LINEAR_GET_CURRENT_USER",
        "LINEAR_GET_CYCLES_BY_TEAM_ID",
        "LINEAR_GET_LINEAR_ISSUE",
        "LINEAR_LIST_ISSUE_DRAFTS",
        "LINEAR_LIST_LINEAR_CYCLES",
        "LINEAR_LIST_LINEAR_ISSUES",
        "LINEAR_LIST_LINEAR_LABELS",
        "LINEAR_LIST_LINEAR_PROJECTS",
        "LINEAR_LIST_LINEAR_STATES",
        "LINEAR_LIST_LINEAR_TEAMS",
        "LINEAR_LIST_LINEAR_USERS",
        "LINEAR_MANAGE_DRAFT",
        "LINEAR_REMOVE_ISSUE_LABEL",
        "LINEAR_REMOVE_REACTION",
        "LINEAR_RUN_QUERY_OR_MUTATION",
        "LINEAR_UPDATE_ISSUE",
        "LINEAR_UPDATE_LINEAR_ISSUE",
        "LINEAR_CREATE_A_COMMENT",
        "LINEAR_GET_COMMENTS",
    ]
    
    def __init__(self, composio_service: ComposioService):
        """
        Initialize LinearService with a ComposioService instance.
        
        Args:
            composio_service: The ComposioService instance to use for execution
        """
        self.composio_service = composio_service
    
    def is_write_action(self, tool_name: str, tool_args: dict) -> bool:
        """
        Detect if a tool represents a Write action that requires user confirmation.
        Composio tool names are UPPERCASE (e.g., LINEAR_CREATE_LINEAR_ISSUE),
        so we need case-insensitive matching.
        
        Args:
            tool_name: The name of the tool
            tool_args: The arguments for the tool
            
        Returns:
            True if this is a write action, False otherwise
        """
        tool_name_lower = tool_name.lower()
        
        # Check for common write prefixes
        write_prefixes = ["create_", "update_", "delete_", "remove_", "manage_"]
        if any(prefix in tool_name_lower for prefix in write_prefixes):
            print(f"DEBUG: Detected WRITE action (prefix match): {tool_name}")
            return True
        
        # Special case: GraphQL mutations via run_query_or_mutation
        if "run_query_or_mutation" in tool_name_lower:
            query = tool_args.get("query_or_mutation", "").strip().lower()
            if query.startswith("mutation"):
                print(f"DEBUG: Detected WRITE action (mutation): {tool_name}")
                return True
        
        print(f"DEBUG: Detected READ action: {tool_name}")
        return False
    
    def _extract_missing_action_slug(self, error_message: str) -> Optional[str]:
        """
        Parse the missing action slug from EnumMetadataNotFound messages.
        
        Args:
            error_message: The error message to parse
            
        Returns:
            The extracted slug or None if not found
        """
        match = re.search(r"`([A-Z0-9_]+)`", error_message)
        return match.group(1) if match else None
    
    def load_tools(self, user_id: str) -> List[Any]:
        """
        Attempt to load the curated list of Linear tools for a user, skipping deprecated ones.
        
        Args:
            user_id: The user ID to load tools for
            
        Returns:
            List of tool objects
            
        Raises:
            RuntimeError: If no tools could be loaded
        """
        remaining = self.LINEAR_ACTION_SLUGS.copy()
        skipped: List[str] = []

        while remaining:
            try:
                tools = self.composio_service.fetch_tools(
                    user_id=user_id,
                    slugs=remaining,
                )
                if skipped:
                    print(f"DEBUG: Skipped deprecated Linear actions: {skipped}")
                return tools
            except EnumMetadataNotFound as enum_error:
                missing_slug = self._extract_missing_action_slug(str(enum_error))
                if missing_slug:
                    if missing_slug in remaining:
                        print(
                            f"DEBUG: Linear action {missing_slug} is unavailable in Composio. Skipping."
                        )
                        remaining = [slug for slug in remaining if slug != missing_slug]
                        skipped.append(missing_slug)
                        continue
                raise
            except Exception as e:
                # Handle other exceptions that might indicate missing tools
                error_str = str(e)
                if "not found" in error_str.lower() or "does not exist" in error_str.lower():
                    # Try to extract the problematic tool
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

        missing_list = ", ".join(skipped) if skipped else "unknown"
        raise RuntimeError(
            f"Unable to load any Linear tools from Composio. Missing actions: {missing_list}"
        )
    
    def execute_query(self, user_id: str, query: str) -> Optional[Dict[str, Any]]:
        """
        Execute a Linear GraphQL query via Composio and return the parsed data section.
        
        Args:
            user_id: The user ID executing the query
            query: The GraphQL query string
            
        Returns:
            The parsed data section from the query result, or None on error
        """
        try:
            result = self.composio_service.execute_action(
                action_slug="LINEAR_RUN_QUERY_OR_MUTATION",
                arguments={
                    "query_or_mutation": query,
                    "variables": {},
                },
                user_id=user_id,
            )
        except Exception as e:
            print(f"DEBUG: Failed to execute Linear query: {e}")
            return None

        data = result.get("data")
        if data is None:
            return None

        if isinstance(data, str):
            try:
                data = json.loads(data)
            except json.JSONDecodeError:
                print("DEBUG: Failed to parse Linear query string response as JSON.")
                return None

        # Keep unwrapping nested "data" keys until we reach actual content
        # Composio wraps GraphQL responses, which also have a "data" key
        while isinstance(data, dict) and "data" in data:
            inner = data.get("data")
            if isinstance(inner, dict):
                data = inner
            else:
                break

        return data if isinstance(data, dict) else None
    
    def enrich_proposal(self, user_id: str, args: Dict[str, Any], tool_name: str = "") -> Dict[str, Any]:
        """
        Enrich proposal args with human-readable names for IDs using cached lookups.
        """
        enricher = LinearEnricher(self)
        return enricher.enrich(user_id=user_id, args=args, tool_name=tool_name)

