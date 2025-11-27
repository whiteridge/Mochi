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
        return self.composio.tools.execute(
            slug=slug,
            arguments=arguments,
            user_id=user_id,
            dangerously_skip_version_check=True,
        )

