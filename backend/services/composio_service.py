"""Composio SDK service wrapper for tool fetching and action execution."""

import os
import time
import json
from typing import Dict, Any, List, Optional
from dotenv import load_dotenv
from composio import Composio
from .composio_tool_aliases import normalize_tool_slug
# from composio_google import GoogleProvider # Removed to avoid schema conversion issues

load_dotenv()

# Read-only tools that are safe to cache (5 min TTL)
READ_ONLY_CACHEABLE_TOOLS = {
    "LINEAR_GET_ALL_LINEAR_TEAMS",
    "LINEAR_LIST_LINEAR_TEAMS",
    "LINEAR_LIST_LINEAR_STATES",
    "LINEAR_LIST_LINEAR_LABELS",
    "SLACK_LIST_ALL_CHANNELS",
}


def _compact_dict(source: Dict[str, Any], keys: List[str]) -> Dict[str, Any]:
    return {key: source.get(key) for key in keys if key in source}


def _slim_slack_channel(channel: Dict[str, Any]) -> Dict[str, Any]:
    return _compact_dict(
        channel,
        ["id", "name", "name_normalized", "is_private", "is_member", "is_archived", "is_channel"],
    )


def _slim_linear_team(team: Dict[str, Any]) -> Dict[str, Any]:
    return _compact_dict(team, ["id", "key", "name"])


class ComposioService:
    """Service for interacting with Composio SDK."""
    
    def __init__(self):
        """Initialize Composio."""
        try:
            # We do NOT use GoogleProvider because it attempts to convert tool schemas
            # to Vertex AI format internally, which fails on some fields (humanParameterDescription).
            # By omitting the provider, we get raw OpenAI-compatible schemas which we convert manually.
            self.composio = Composio(
                api_key=os.getenv("COMPOSIO_API_KEY")
            )
            print("DEBUG: Composio initialized successfully (Raw Mode)")
        except Exception as exc:
            raise RuntimeError(
                f"Failed to initialize Composio SDK: {exc}"
            ) from exc
        
        # In-memory cache for read-only tools
        self._cache: Dict[tuple, Dict[str, Any]] = {}
        self._cache_ttl_seconds = 300  # 5 minutes
    
    # --- Cache Helper Methods ---
    
    def _cache_key(self, tool_name: str, args: Dict[str, Any]) -> tuple:
        """Generate a cache key from tool name and arguments."""
        return (tool_name.upper(), json.dumps(args, sort_keys=True))
    
    def _get_cached(self, tool_name: str, args: Dict[str, Any]) -> Optional[Any]:
        """Get cached result if still valid (within TTL)."""
        key = self._cache_key(tool_name, args)
        entry = self._cache.get(key)
        if entry and time.time() - entry["ts"] < self._cache_ttl_seconds:
            print(f"DEBUG: Cache HIT for {tool_name}")
            return entry["value"]
        return None
    
    def _set_cached(self, tool_name: str, args: Dict[str, Any], value: Any) -> None:
        """Store result in cache with timestamp."""
        key = self._cache_key(tool_name, args)
        self._cache[key] = {"value": value, "ts": time.time()}
        print(f"DEBUG: Cached result for {tool_name}")
    
    def get_auth_url(self, app_name: str, user_id: str, callback_url: Optional[str] = None) -> str:
        """
        Initiate a connection flow and return the authorization URL.
        
        Args:
            app_name: Name of the app to connect (e.g., 'slack', 'linear')
            user_id: The user ID to link the connection to
            callback_url: Optional URL to redirect to after successful auth
            
        Returns:
            The authorization URL for the user to visit
        """
        app_name_lower = app_name.lower()
        auth_configs = {
            "slack": os.getenv("COMPOSIO_SLACK_AUTH_CONFIG_ID", "ac_VbAOnHEy6Cts"),
            "linear": os.getenv("COMPOSIO_LINEAR_AUTH_CONFIG_ID", "ac_ibulkWqBOyKQ"),
            "notion": os.getenv("COMPOSIO_NOTION_AUTH_CONFIG_ID"),
            "github": os.getenv("COMPOSIO_GITHUB_AUTH_CONFIG_ID"),
        }
        config_id = auth_configs.get(app_name_lower)

        if not config_id:
            config_id = self._find_auth_config_for_app(app_name)
        if not config_id:
            config_id = self._create_auth_config_for_app(app_name)
        if not config_id:
            extra_hint = ""
            if app_name_lower == "notion":
                extra_hint = " Set COMPOSIO_NOTION_AUTH_CONFIG_ID if you're enabling Notion."
            if app_name_lower == "github":
                extra_hint = " Set COMPOSIO_GITHUB_AUTH_CONFIG_ID if you're enabling GitHub."
            raise ValueError(
                f"No auth config found for app: {app_name}.{extra_hint} "
                "Please create one in the Composio dashboard at https://app.composio.dev"
            )
        request = self.composio.connected_accounts.initiate(
            user_id=user_id,
            auth_config_id=config_id,
            callback_url=callback_url
        )
        
        # SDK uses snake_case: redirect_url
        redirect_url = getattr(request, 'redirect_url', None) or getattr(request, 'redirectUrl', None)
        
        if not redirect_url:
            raise ValueError(f"No redirect URL in response")
        
        return redirect_url
    
    def _create_auth_config_for_app(self, app_name: str) -> Optional[str]:
        """Auto-create a Composio-managed auth config for the app."""
        try:
            # Use Composio's managed OAuth credentials
            result = self.composio.auth_configs.create(
                toolkit=app_name.lower(),
                options={"type": "use_composio_managed_auth"}
            )
            return getattr(result, 'id', None)
        except Exception:
            return None
    
    def _find_auth_config_for_app(self, app_name: str) -> Optional[str]:
        """Find an auth config ID for the given app name."""
        try:
            auth_configs = self.composio.auth_configs.list()
            
            for config in auth_configs.items:
                # Check toolkit slug
                toolkit = getattr(config, 'toolkit', None)
                toolkit_slug = getattr(toolkit, 'slug', '').lower() if toolkit else ''
                
                # Also check app_name attribute and name
                config_app = getattr(config, 'app_name', getattr(config, 'appName', '')).lower()
                config_name = getattr(config, 'name', '').lower()
                
                if toolkit_slug == app_name.lower() or config_app == app_name.lower() or app_name.lower() in config_name:
                    return config.id
            
            return None
        except Exception:
            return None

    def get_connection_status(self, app_name: str, user_id: str) -> bool:
        """
        Check if a user has an active connection for the given app.
        
        Args:
            app_name: Name of the app (e.g., 'slack', 'linear')
            user_id: The user ID to check
            
        Returns:
            True if connected, False otherwise
        """
        app_slug = app_name.lower()
        toolkit_slug_filters = [app_slug]
        app_slug_upper = app_slug.upper()
        if app_slug_upper != app_slug:
            toolkit_slug_filters.append(app_slug_upper)
        try:
            accounts = self.composio.connected_accounts.list(
                user_ids=[user_id],
                toolkit_slugs=toolkit_slug_filters,
            )
        except TypeError as exc:
            if "unexpected keyword argument" not in str(exc):
                raise
            accounts = self.composio.connected_accounts.list(
                user_id=user_id,
                app_names=toolkit_slug_filters,
            )

        items: List[Any] = []
        if hasattr(accounts, "items"):
            items = accounts.items or []
        elif isinstance(accounts, dict):
            items = accounts.get("items", [])
        elif isinstance(accounts, list):
            items = accounts

        for account in items:
            status = getattr(account, "status", None)
            if status is None and isinstance(account, dict):
                status = account.get("status")
            if status != "ACTIVE":
                continue

            toolkit_slug = None
            toolkit = getattr(account, "toolkit", None)
            if isinstance(account, dict):
                toolkit = account.get("toolkit", toolkit)
                toolkit_slug = account.get("toolkit_slug") or account.get("toolkitSlug")

            if toolkit:
                if isinstance(toolkit, dict):
                    toolkit_slug = toolkit.get("slug") or toolkit_slug
                else:
                    toolkit_slug = getattr(toolkit, "slug", toolkit_slug)

            normalized_toolkit_slug = None
            if toolkit_slug is not None:
                normalized_toolkit_slug = str(toolkit_slug).lower()

            if normalized_toolkit_slug and normalized_toolkit_slug != app_slug:
                continue
            return True

        return False

    def disconnect_app(self, app_name: str, user_id: str) -> int:
        """
        Disconnect all accounts for the given app.
        
        Args:
            app_name: Name of the app (e.g., 'slack', 'linear')
            user_id: The user ID (currently unused, disconnects all matching app accounts)
            
        Returns:
            Number of accounts disconnected
        """
        accounts = self.composio.connected_accounts.list()
        disconnected_count = 0
        
        for account in accounts.items:
            toolkit = getattr(account, 'toolkit', None)
            account_app = getattr(toolkit, 'slug', '').lower() if toolkit else ''
            
            if account_app == app_name.lower():
                try:
                    self.composio.connected_accounts.delete(id=account.id)
                    disconnected_count += 1
                except Exception:
                    pass  # Continue disconnecting other accounts
        
        return disconnected_count

    def fetch_tools(
        self,
        user_id: str,
        slugs: Optional[List[str]] = None,
        toolkits: Optional[List[str]] = None,
    ):
        """
        Fetch Composio tools for the given user and action slugs.
        
        Args:
            user_id: The user ID to fetch tools for
            slugs: List of action slugs to fetch
            toolkits: List of toolkit slugs to fetch (e.g., ["NOTION"])
            
        Returns:
            List of tool objects from Composio
        """
        if slugs:
            normalized_slugs = [normalize_tool_slug(slug) for slug in slugs]
            normalized_slugs = list(dict.fromkeys(normalized_slugs))
            return self.composio.tools.get(
                user_id=user_id,
                tools=normalized_slugs,
            )
        if toolkits:
            return self.composio.tools.get(user_id=user_id, toolkits=toolkits)
        raise ValueError("Must provide slugs or toolkits to fetch tools.")
    
    def execute_action(
        self,
        action_slug: str,
        arguments: Dict[str, Any],
        user_id: str,
    ) -> Dict[str, Any]:
        """
        Execute a Composio action directly.
        
        Args:
            action_slug: The action slug to execute
            arguments: Arguments for the action
            user_id: The user ID executing the action
            
        Returns:
            Dictionary with 'data' and 'successful' keys
        """
        normalized_slug = normalize_tool_slug(action_slug)
        if normalized_slug != action_slug:
            print(
                f"DEBUG: Normalized action slug {action_slug} -> {normalized_slug}"
            )
        result = self.composio.tools.execute(
            slug=normalized_slug,
            arguments=arguments,
            user_id=user_id,
            dangerously_skip_version_check=True,
        )
        # Convert result to dict format expected by the rest of the code
        if hasattr(result, 'data'):
            return {"data": result.data, "successful": result.successful}
        return {"data": result, "successful": True}
    
    def execute_tool(
        self,
        slug: str,
        arguments: Dict[str, Any],
        user_id: str,
    ):
        """
        Execute a Composio tool and return the raw result object.
        Used for tool execution in the agent loop.
        
        Args:
            slug: The tool slug to execute
            arguments: Arguments for the tool
            user_id: The user ID executing the tool
            
        Returns:
            Raw result object from Composio
        """
        normalized_slug = normalize_tool_slug(slug)
        if normalized_slug != slug:
            print(f"DEBUG: Normalized tool slug {slug} -> {normalized_slug}")
        slug = normalized_slug

        # Check cache first for read-only tools
        if slug.upper() in READ_ONLY_CACHEABLE_TOOLS:
            cached = self._get_cached(slug, arguments)
            if cached is not None:
                return cached
        
        result = self.composio.tools.execute(
            slug=slug,
            arguments=arguments,
            user_id=user_id,
            dangerously_skip_version_check=True,
        )
        
        # Handle pagination for slack_list_all_channels
        if slug.lower() == "slack_list_all_channels":
            try:
                data = result.get("data", {}) if isinstance(result, dict) else getattr(result, "data", {})
                channels = list(data.get("channels", []))
                
                meta = data.get("response_metadata") or {}
                next_cursor = meta.get("next_cursor")
                
                max_pages = 10
                pages = 1
                
                print(f"DEBUG: slack_list_all_channels page 1: {len(channels)} channels. Next cursor: {next_cursor}")
                
                while next_cursor and pages < max_pages:
                    print(f"DEBUG: Fetching page {pages + 1} with cursor {next_cursor}")
                    paged_args = {**arguments, "cursor": next_cursor}
                    
                    page_result = self.composio.tools.execute(
                        slug=slug,
                        arguments=paged_args,
                        user_id=user_id,
                        dangerously_skip_version_check=True,
                    )
                    
                    pdata = page_result.get("data", {}) if isinstance(page_result, dict) else getattr(page_result, "data", {})
                    new_channels = pdata.get("channels", [])
                    channels.extend(new_channels)
                    
                    meta = pdata.get("response_metadata") or {}
                    next_cursor = meta.get("next_cursor")
                    pages += 1
                    
                    print(f"DEBUG: Page {pages} added {len(new_channels)} channels. Total: {len(channels)}")
                
                # Update result with aggregated channels
                if isinstance(result, dict):
                    if "data" not in result:
                        result["data"] = {}
                    result["data"]["channels"] = channels
                    # Clear cursor to avoid confusion
                    if "response_metadata" in result["data"]:
                        result["data"]["response_metadata"]["next_cursor"] = ""
                else:
                    # If it's an object, we might need to be careful. 
                    # Assuming for now we can modify data if it's a dict, or we reconstruct.
                    # Based on logs, result seems to be an object with .data attribute which is a dict.
                    if hasattr(result, "data") and isinstance(result.data, dict):
                        result.data["channels"] = channels
                        if "response_metadata" in result.data:
                            result.data["response_metadata"]["next_cursor"] = ""
                            
            except Exception as e:
                print(f"DEBUG: Error handling Slack pagination: {e}")
                # Fallback to returning original result
                pass

        if slug.lower() in {"slack_list_all_channels", "slack_list_conversations"}:
            try:
                data = result.get("data", {}) if isinstance(result, dict) else getattr(result, "data", {})
                channels = data.get("channels") or data.get("conversations") or []
                slim_channels = [
                    _slim_slack_channel(channel) for channel in channels if isinstance(channel, dict)
                ]
                if isinstance(result, dict):
                    if "data" not in result:
                        result["data"] = {}
                    result["data"]["channels"] = slim_channels
                    result["data"].pop("conversations", None)
                    result["data"].pop("response_metadata", None)
                else:
                    if hasattr(result, "data") and isinstance(result.data, dict):
                        result.data["channels"] = slim_channels
                        result.data.pop("conversations", None)
                        result.data.pop("response_metadata", None)
            except Exception as e:
                print(f"DEBUG: Error slimming Slack channel list: {e}")

        if slug.lower() in {"linear_get_all_linear_teams", "linear_list_linear_teams"}:
            try:
                data = result.get("data", {}) if isinstance(result, dict) else getattr(result, "data", {})
                teams = data.get("teams", [])
                slim_teams = [_slim_linear_team(team) for team in teams if isinstance(team, dict)]
                if isinstance(result, dict):
                    if "data" not in result:
                        result["data"] = {}
                    result["data"]["teams"] = slim_teams
                else:
                    if hasattr(result, "data") and isinstance(result.data, dict):
                        result.data["teams"] = slim_teams
            except Exception as e:
                print(f"DEBUG: Error slimming Linear teams: {e}")
        
        # Handle post-processing for slack_fetch_conversation_history
        if slug.lower() == "slack_fetch_conversation_history":
            try:
                data = result.get("data", {}) if isinstance(result, dict) else getattr(result, "data", {})
                messages = data.get("messages", [])
                
                # Filter to essential fields to save context
                simplified = []
                for m in messages:
                    # Keep text messages, skip purely structural ones if needed
                    if "text" in m:
                        simplified.append({
                            "user": m.get("user"),
                            "text": m.get("text"),
                            "ts": m.get("ts"),
                            "subtype": m.get("subtype") # useful to know if it's a join/leave
                        })
                
                # Update result
                if isinstance(result, dict):
                    if "data" not in result:
                        result["data"] = {}
                    result["data"]["messages"] = simplified
                else:
                    if hasattr(result, "data") and isinstance(result.data, dict):
                        result.data["messages"] = simplified
                        
            except Exception as e:
                print(f"DEBUG: Error handling Slack history filtering: {e}")
                pass

        # Cache successful results for read-only tools
        if slug.upper() in READ_ONLY_CACHEABLE_TOOLS:
            # Only cache if result looks successful (has data)
            if hasattr(result, 'data') or (isinstance(result, dict) and result.get('data')):
                self._set_cached(slug, arguments, result)

        return result
