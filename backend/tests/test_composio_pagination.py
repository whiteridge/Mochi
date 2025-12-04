
import pytest
from unittest.mock import MagicMock, patch
from backend.services.composio_service import ComposioService

def test_slack_pagination_logic():
    # Patch the Composio class used in __init__
    with patch("backend.services.composio_service.Composio") as MockComposioSDK, \
         patch("backend.services.composio_service.os.getenv", return_value="fake_key"):
        
        # Initialize the service
        service = ComposioService()
        
        # Mock the tools.execute method
        mock_execute = MagicMock()
        service.composio.tools.execute = mock_execute
        
        # Setup: Mock Composio tool execution to return pages
        # Page 1: Returns "all-whiteridge" and next_cursor="cursor1"
        page1 = MagicMock()
        # We need to set data as a dict, and ensure the mock behaves like an object with .data
        page1.data = {
            "channels": [{"id": "C1", "name": "all-whiteridge"}],
            "response_metadata": {"next_cursor": "cursor1"}
        }
        # Make sure isinstance(page1, dict) is False, which it is for MagicMock by default
        
        # Page 2: Returns "general" and next_cursor=""
        page2 = MagicMock()
        page2.data = {
            "channels": [{"id": "C2", "name": "general"}],
            "response_metadata": {"next_cursor": ""}
        }
        
        # Configure mock to return page1 then page2
        mock_execute.side_effect = [page1, page2]
        
        # Execute the tool
        result = service.execute_tool(
            slug="slack_list_all_channels",
            arguments={"types": "public_channel"},
            user_id="test_user"
        )
        
        # Verify: execute was called twice
        assert mock_execute.call_count == 2
        
        # Verify arguments for second call included cursor
        call_args_list = mock_execute.call_args_list
        assert call_args_list[1].kwargs["arguments"]["cursor"] == "cursor1"
        
        # Verify: Result should contain both channels
        # result is page1 (the first return value), but modified in place
        assert len(result.data["channels"]) == 2
        assert result.data["channels"][0]["name"] == "all-whiteridge"
        assert result.data["channels"][1]["name"] == "general"
