"""Composio SDK service wrapper for tool fetching and action execution."""

import os
from typing import Dict, Any, List
from dotenv import load_dotenv
from composio import Composio
from composio_google import GoogleProvider

load_dotenv()


class ComposioService:
    """Service for interacting with Composio SDK."""
    
    def __init__(self):
        """Initialize Composio with GoogleProvider."""
        try:
            self.composio = Composio(
                provider=GoogleProvider(),
                api_key=os.getenv("COMPOSIO_API_KEY")
            )
            print("DEBUG: Composio initialized successfully with GoogleProvider")
        except Exception as exc:
            raise RuntimeError(
                f"Failed to initialize Composio SDK: {exc}"
            ) from exc
    
    def fetch_tools(self, user_id: str, slugs: List[str]):
        """
        Fetch Composio tools for the given user and action slugs.
        
        Args:
            user_id: The user ID to fetch tools for
            slugs: List of action slugs to fetch
            
        Returns:
            List of tool objects from Composio
        """
        return self.composio.tools.get(user_id=user_id, tools=slugs)
    
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
        result = self.composio.tools.execute(
            slug=action_slug,
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

        return result

