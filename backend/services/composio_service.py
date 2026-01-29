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

ACCOUNT_STATUS_PRIORITY = {
    "ACTIVE": 6,
    "INITIALIZING": 5,
    "INITIATED": 4,
    "PENDING": 4,
    "INACTIVE": 3,
    "EXPIRED": 2,
    "FAILED": 1,
}

ACCOUNT_STATUS_FILTERS = [
    "INITIALIZING",
    "INITIATED",
    "ACTIVE",
    "FAILED",
    "EXPIRED",
    "INACTIVE",
]

AUTH_ERROR_HINTS = (
    "auth",
    "unauthorized",
    "token",
    "expired",
    "invalid",
    "permission",
    "access denied",
    "forbidden",
    "oauth",
)


def _compact_dict(source: Dict[str, Any], keys: List[str]) -> Dict[str, Any]:
    return {key: source.get(key) for key in keys if key in source}


def _slim_slack_channel(channel: Dict[str, Any]) -> Dict[str, Any]:
    return _compact_dict(
        channel,
        ["id", "name", "name_normalized", "is_private", "is_member", "is_archived", "is_channel"],
    )


def _slim_linear_team(team: Dict[str, Any]) -> Dict[str, Any]:
    return _compact_dict(team, ["id", "key", "name"])


def _extract_account_items(accounts: Any) -> List[Any]:
    if hasattr(accounts, "items"):
        return accounts.items or []
    if isinstance(accounts, dict):
        return accounts.get("items", [])
    if isinstance(accounts, list):
        return accounts
    return []


def _extract_account_status(account: Any) -> Optional[str]:
    status = getattr(account, "status", None)
    if status is None and isinstance(account, dict):
        status = account.get("status")
    if status is None:
        return None
    return str(status).upper()


def _extract_account_id(account: Any) -> Optional[str]:
    account_id = getattr(account, "id", None)
    if account_id is None and isinstance(account, dict):
        account_id = account.get("id") or account.get("nanoid")
    return str(account_id) if account_id is not None else None


def _extract_toolkit_slug(account: Any) -> Optional[str]:
    toolkit = getattr(account, "toolkit", None)
    toolkit_slug = getattr(account, "toolkit_slug", None) or getattr(account, "toolkitSlug", None)
    if isinstance(account, dict):
        toolkit = account.get("toolkit", toolkit)
        toolkit_slug = account.get("toolkit_slug") or account.get("toolkitSlug") or toolkit_slug
    if toolkit:
        if isinstance(toolkit, dict):
            toolkit_slug = toolkit.get("slug") or toolkit_slug
        else:
            toolkit_slug = getattr(toolkit, "slug", toolkit_slug)
    if toolkit_slug is None:
        return None
    return str(toolkit_slug).lower()


def _tool_slug_to_app_slug(slug: Optional[str]) -> Optional[str]:
    if not slug:
        return None
    normalized = normalize_tool_slug(slug)
    upper_slug = normalized.upper()
    if upper_slug.startswith("GOOGLECALENDAR_") or upper_slug.startswith("GOOGLE_CALENDAR_"):
        return "googlecalendar"
    prefix = upper_slug.split("_", 1)[0]
    mapping = {
        "SLACK": "slack",
        "LINEAR": "linear",
        "NOTION": "notion",
        "GITHUB": "github",
        "GMAIL": "gmail",
        "GOOGLE": "googlecalendar",
        "GOOGLECALENDAR": "googlecalendar",
    }
    return mapping.get(prefix, prefix.lower())


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

    def _list_connected_accounts(
        self,
        user_id: str,
        toolkit_slugs: List[str],
        statuses: Optional[List[str]] = None,
    ):
        try:
            if statuses is None:
                return self.composio.connected_accounts.list(
                    user_ids=[user_id],
                    toolkit_slugs=toolkit_slugs,
                )
            return self.composio.connected_accounts.list(
                user_ids=[user_id],
                toolkit_slugs=toolkit_slugs,
                statuses=statuses,
            )
        except TypeError:
            try:
                return self.composio.connected_accounts.list(
                    user_ids=[user_id],
                    toolkit_slugs=toolkit_slugs,
                )
            except TypeError:
                return self.composio.connected_accounts.list(
                    user_id=user_id,
                    app_names=toolkit_slugs,
                )

    def _toolkit_slugs_for_app(self, app_name: str) -> List[str]:
        slug = app_name.lower()
        slugs = [slug]
        if slug == "googlecalendar":
            slugs.append("google_calendar")
        slug_upper = slug.upper()
        if slug_upper != slug:
            slugs.append(slug_upper)
        return list(dict.fromkeys(slugs))

    def _list_accounts_for_app(self, user_id: str, app_name: str) -> List[Any]:
        toolkit_slugs = self._toolkit_slugs_for_app(app_name)
        try:
            accounts = self._list_connected_accounts(
                user_id=user_id,
                toolkit_slugs=toolkit_slugs,
                statuses=None,
            )
            items = _extract_account_items(accounts)
        except Exception as exc:  # noqa: BLE001 - treat lookup failures as empty
            print(f"DEBUG: Failed to list connected accounts for {app_name}: {exc}")
            return []

        allowed = {slug.lower() for slug in toolkit_slugs}
        return [
            account
            for account in items
            if (_extract_toolkit_slug(account) or "") in allowed
        ]

    def _select_best_account(self, accounts: List[Any]) -> Optional[Any]:
        best_account = None
        best_priority = -1
        for account in accounts:
            status = _extract_account_status(account)
            priority = ACCOUNT_STATUS_PRIORITY.get(status, 0) if status else 0
            if best_account is None or priority > best_priority:
                best_account = account
                best_priority = priority
        return best_account

    def _extract_error_message(self, result: Any) -> Optional[str]:
        if result is None:
            return None
        if isinstance(result, dict):
            for key in ("error", "message", "detail"):
                value = result.get(key)
                if value:
                    return str(value)
            data = result.get("data")
            if isinstance(data, dict):
                for key in ("error", "message", "detail"):
                    value = data.get(key)
                    if value:
                        return str(value)
            return None

        for attr in ("error", "message", "detail"):
            value = getattr(result, attr, None)
            if value:
                return str(value)
        data = getattr(result, "data", None)
        if isinstance(data, dict):
            for key in ("error", "message", "detail"):
                value = data.get(key)
                if value:
                    return str(value)
        return None

    def _is_auth_error(self, exc: Exception) -> bool:
        status_code = getattr(exc, "status_code", None) or getattr(exc, "status", None)
        if status_code in {401, 403}:
            return True
        message = str(exc).lower()
        return any(hint in message for hint in AUTH_ERROR_HINTS)

    def _result_indicates_auth_error(self, result: Any) -> bool:
        if result is None:
            return False
        if isinstance(result, dict):
            successful = result.get("successful", True)
        else:
            successful = getattr(result, "successful", True)
        if successful:
            return False
        message = self._extract_error_message(result)
        if not message:
            return False
        return any(hint in message.lower() for hint in AUTH_ERROR_HINTS)

    def _format_app_label(self, app_slug: str) -> str:
        mapping = {
            "googlecalendar": "Google Calendar",
            "gmail": "Gmail",
            "github": "GitHub",
            "slack": "Slack",
            "linear": "Linear",
            "notion": "Notion",
        }
        return mapping.get(app_slug, app_slug.title())

    def _attempt_auth_refresh(self, slug: str, user_id: str) -> Dict[str, Any]:
        app_slug = _tool_slug_to_app_slug(slug)
        if not app_slug:
            return {"refreshed": False, "action_required": False}

        details = self.get_connection_details(app_slug, user_id)
        account_id = details.get("account_id")
        if not account_id:
            return {"refreshed": False, "action_required": False}

        try:
            refresh_result = self.refresh_connection(account_id)
        except Exception as exc:  # noqa: BLE001 - keep auth refresh best-effort
            print(f"DEBUG: Failed to refresh auth for {app_slug}: {exc}")
            return {"refreshed": False, "action_required": False}

        redirect_url = refresh_result.get("redirect_url")
        if redirect_url:
            return {"refreshed": False, "action_required": True}

        return {"refreshed": True, "action_required": False}

    def _execute_with_auth_retry(
        self,
        slug: str,
        arguments: Dict[str, Any],
        user_id: str,
        allow_retry: bool = True,
    ):
        try:
            result = self.composio.tools.execute(
                slug=slug,
                arguments=arguments,
                user_id=user_id,
                dangerously_skip_version_check=True,
            )
        except Exception as exc:
            if not self._is_auth_error(exc) or not allow_retry:
                raise
            refresh_outcome = self._attempt_auth_refresh(slug, user_id)
            if refresh_outcome.get("refreshed"):
                return self._execute_with_auth_retry(slug, arguments, user_id, allow_retry=False)
            app_slug = _tool_slug_to_app_slug(slug) or "integration"
            raise RuntimeError(
                f"Authentication expired for {self._format_app_label(app_slug)}. "
                "Please reconnect in Settings."
            ) from exc

        if allow_retry and self._result_indicates_auth_error(result):
            refresh_outcome = self._attempt_auth_refresh(slug, user_id)
            if refresh_outcome.get("refreshed"):
                return self._execute_with_auth_retry(slug, arguments, user_id, allow_retry=False)
            app_slug = _tool_slug_to_app_slug(slug) or "integration"
            raise RuntimeError(
                f"Authentication expired for {self._format_app_label(app_slug)}. "
                "Please reconnect in Settings."
            )

        return result
    
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
        existing_accounts = self._list_accounts_for_app(user_id=user_id, app_name=app_name_lower)
        if existing_accounts:
            best_account = self._select_best_account(existing_accounts)
            best_id = _extract_account_id(best_account) if best_account else None

            if best_id and len(existing_accounts) > 1:
                for account in existing_accounts:
                    account_id = _extract_account_id(account)
                    if account_id and account_id != best_id:
                        self._delete_connected_account(account_id)

            if best_id:
                refreshed = self.refresh_connection(best_id)
                redirect_url = refreshed.get("redirect_url")
                if redirect_url:
                    return redirect_url

        auth_configs = {
            "slack": os.getenv("COMPOSIO_SLACK_AUTH_CONFIG_ID"),
            "linear": os.getenv("COMPOSIO_LINEAR_AUTH_CONFIG_ID"),
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

    def get_connection_details(self, app_name: str, user_id: str) -> Dict[str, Any]:
        """
        Fetch connection metadata for a given app and user.

        Returns a dict with:
        - connected: bool (ACTIVE)
        - status: Optional[str]
        - account_id: Optional[str]
        - action_required: bool (EXPIRED/FAILED)
        """
        app_slug = app_name.lower()
        toolkit_slug_filters = [app_slug]
        app_slug_upper = app_slug.upper()
        if app_slug_upper != app_slug:
            toolkit_slug_filters.append(app_slug_upper)

        statuses = ACCOUNT_STATUS_FILTERS
        try:
            accounts = self._list_connected_accounts(
                user_id=user_id,
                toolkit_slugs=toolkit_slug_filters,
                statuses=statuses,
            )
            items = _extract_account_items(accounts)
        except Exception as exc:  # noqa: BLE001 - treat lookup failures as disconnected
            message = str(exc)
            if "payload.statuses" in message or "Invalid enum value" in message:
                try:
                    accounts = self._list_connected_accounts(
                        user_id=user_id,
                        toolkit_slugs=toolkit_slug_filters,
                        statuses=None,
                    )
                    items = _extract_account_items(accounts)
                except Exception as retry_exc:  # noqa: BLE001 - treat lookup failures as disconnected
                    print(f"DEBUG: Failed to fetch connection status for {app_slug}: {retry_exc}")
                    return {
                        "connected": False,
                        "status": None,
                        "account_id": None,
                        "action_required": False,
                        "error": str(retry_exc),
                    }
            else:
                print(f"DEBUG: Failed to fetch connection status for {app_slug}: {exc}")
                return {
                    "connected": False,
                    "status": None,
                    "account_id": None,
                    "action_required": False,
                    "error": str(exc),
                }

        best_account = None
        best_priority = -1
        for account in items:
            status = _extract_account_status(account)
            if status is None:
                continue
            toolkit_slug = _extract_toolkit_slug(account)
            if toolkit_slug and toolkit_slug != app_slug:
                continue
            priority = ACCOUNT_STATUS_PRIORITY.get(status, 0)
            if priority > best_priority:
                best_priority = priority
                best_account = account

        if not best_account:
            return {
                "connected": False,
                "status": None,
                "account_id": None,
                "action_required": False,
            }

        status = _extract_account_status(best_account)
        account_id = _extract_account_id(best_account)
        connected = status == "ACTIVE"
        action_required = status in {"EXPIRED", "FAILED"}
        return {
            "connected": connected,
            "status": status,
            "account_id": account_id,
            "action_required": action_required,
        }

    def get_connection_status(self, app_name: str, user_id: str) -> bool:
        """Check if a user has an active connection for the given app."""
        details = self.get_connection_details(app_name, user_id)
        return bool(details.get("connected"))

    def refresh_connection(self, connected_account_id: str) -> Dict[str, Any]:
        """Attempt to refresh a connected account."""
        try:
            result = self.composio.connected_accounts.refresh(nanoid=connected_account_id)
        except TypeError:
            try:
                result = self.composio.connected_accounts.refresh(connected_account_id)
            except TypeError:
                result = self.composio.connected_accounts.refresh(
                    connected_account_id=connected_account_id
                )

        redirect_url = getattr(result, "redirect_url", None) or getattr(result, "redirectUrl", None)
        status = getattr(result, "status", None)
        return {
            "successful": True,
            "redirect_url": redirect_url,
            "status": status,
        }

    def disconnect_app(self, app_name: str, user_id: str) -> int:
        """
        Disconnect all accounts for the given app.
        
        Args:
            app_name: Name of the app (e.g., 'slack', 'linear')
            user_id: The user ID (currently unused, disconnects all matching app accounts)
            
        Returns:
            Number of accounts disconnected
        """
        app_slug = app_name.lower()
        toolkit_slugs = [app_slug]
        if app_slug == "googlecalendar":
            toolkit_slugs.append("google_calendar")
        app_slug_upper = app_slug.upper()
        if app_slug_upper != app_slug:
            toolkit_slugs.append(app_slug_upper)

        try:
            accounts = self._list_connected_accounts(
                user_id=user_id,
                toolkit_slugs=toolkit_slugs,
                statuses=None,
            )
            items = _extract_account_items(accounts)
        except Exception as exc:  # noqa: BLE001 - surface failure as zero disconnects
            print(f"DEBUG: Failed to list connected accounts for {app_slug}: {exc}")
            return 0

        disconnected_count = 0
        allowed_toolkits = {slug.lower() for slug in toolkit_slugs}

        for account in items:
            toolkit_slug = _extract_toolkit_slug(account)
            if toolkit_slug and toolkit_slug not in allowed_toolkits:
                continue
            account_id = _extract_account_id(account)
            if not account_id:
                continue
            if self._delete_connected_account(account_id):
                disconnected_count += 1

        return disconnected_count

    def _delete_connected_account(self, account_id: str) -> bool:
        """Delete a connected account using whichever SDK signature is available."""
        try:
            self.composio.connected_accounts.delete(id=account_id)
            return True
        except TypeError:
            try:
                self.composio.connected_accounts.delete(nanoid=account_id)
                return True
            except TypeError:
                try:
                    self.composio.connected_accounts.delete(account_id)
                    return True
                except TypeError:
                    try:
                        self.composio.connected_accounts.delete(connected_account_id=account_id)
                        return True
                    except Exception as exc:  # noqa: BLE001 - best-effort deletion
                        print(f"DEBUG: Failed to delete account {account_id}: {exc}")
                        return False
                except Exception as exc:  # noqa: BLE001 - best-effort deletion
                    print(f"DEBUG: Failed to delete account {account_id}: {exc}")
                    return False
        except Exception as exc:  # noqa: BLE001 - best-effort deletion
            print(f"DEBUG: Failed to delete account {account_id}: {exc}")
            return False

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
        result = self._execute_with_auth_retry(
            slug=normalized_slug,
            arguments=arguments,
            user_id=user_id,
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
        
        result = self._execute_with_auth_retry(
            slug=slug,
            arguments=arguments,
            user_id=user_id,
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
                    
                    page_result = self._execute_with_auth_retry(
                        slug=slug,
                        arguments=paged_args,
                        user_id=user_id,
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
