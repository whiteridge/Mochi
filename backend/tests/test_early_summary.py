"""
Unit tests for early summary helpers and caching behavior.
"""
import pytest
import time
from unittest.mock import MagicMock, patch

# Test early summary helpers
from backend.agent.common import map_tool_to_app, make_early_summary


class TestMapToolToApp:
    """Tests for the map_tool_to_app helper function."""
    
    def test_linear_tools(self):
        """LINEAR_ prefix should map to 'linear'."""
        assert map_tool_to_app("LINEAR_CREATE_ISSUE") == "linear"
        assert map_tool_to_app("LINEAR_LIST_LINEAR_TEAMS") == "linear"
        assert map_tool_to_app("linear_get_issue") == "linear"  # case insensitive
    
    def test_slack_tools(self):
        """SLACK_ prefix should map to 'slack'."""
        assert map_tool_to_app("SLACK_SEND_MESSAGE") == "slack"
        assert map_tool_to_app("SLACK_LIST_ALL_CHANNELS") == "slack"
        assert map_tool_to_app("slack_fetch_conversation_history") == "slack"
    
    def test_github_tools(self):
        """GITHUB_ prefix should map to 'github'."""
        assert map_tool_to_app("GITHUB_CREATE_PR") == "github"
        assert map_tool_to_app("github_list_repos") == "github"
    
    def test_notion_tools(self):
        """NOTION_ prefix should map to 'notion'."""
        assert map_tool_to_app("NOTION_CREATE_PAGE") == "notion"

    def test_gmail_tools(self):
        """GMAIL_ prefix should map to 'gmail'."""
        assert map_tool_to_app("GMAIL_SEND_EMAIL") == "gmail"
        assert map_tool_to_app("gmail_fetch_emails") == "gmail"

    def test_google_calendar_tools(self):
        """GOOGLECALENDAR_ prefix should map to 'google_calendar'."""
        assert map_tool_to_app("GOOGLECALENDAR_CREATE_EVENT") == "google_calendar"
        assert map_tool_to_app("googlecalendar_events_list") == "google_calendar"
    
    def test_unknown_tool_fallback(self):
        """Unknown tools should use first word before underscore."""
        assert map_tool_to_app("JIRA_CREATE_ISSUE") == "jira"
        assert map_tool_to_app("custom_tool_action") == "custom"


class TestMakeEarlySummary:
    """Tests for the make_early_summary helper function."""
    
    def test_linear_summary(self):
        """Linear app should get specific summary."""
        summary = make_early_summary("linear")
        assert "Linear" in summary
        assert "search" in summary.lower()
    
    def test_slack_summary(self):
        """Slack app should get specific summary."""
        summary = make_early_summary("slack")
        assert "Slack" in summary
        assert "read" in summary.lower()
    
    def test_github_summary(self):
        """GitHub app should get specific summary."""
        summary = make_early_summary("github")
        assert "GitHub" in summary
    
    def test_unknown_app_fallback(self):
        """Unknown app should get generic summary with capitalized name."""
        summary = make_early_summary("jira")
        assert "Jira" in summary  # Should be capitalized
        assert "help with your request" in summary

    def test_gmail_summary(self):
        """Gmail app should get specific summary."""
        summary = make_early_summary("gmail")
        assert "Gmail" in summary

    def test_google_calendar_summary(self):
        """Google Calendar app should get specific summary."""
        summary = make_early_summary("google_calendar")
        assert "Google Calendar" in summary


class TestComposioServiceCaching:
    """Tests for the caching behavior in ComposioService."""
    
    def test_cache_hit(self):
        """Second call to cached tool should return cached result."""
        with patch("backend.services.composio_service.Composio") as MockComposio, \
             patch("backend.services.composio_service.os.getenv", return_value="fake_key"):
            
            from backend.services.composio_service import ComposioService
            
            service = ComposioService()
            mock_execute = MagicMock()
            service.composio.tools.execute = mock_execute
            
            # Mock a successful result
            result1 = MagicMock()
            result1.data = {"teams": [{"id": "1", "name": "Team A"}]}
            mock_execute.return_value = result1
            
            # First call - should execute
            r1 = service.execute_tool("LINEAR_LIST_LINEAR_TEAMS", {}, "user1")
            assert mock_execute.call_count == 1
            
            # Second call - should hit cache
            r2 = service.execute_tool("LINEAR_LIST_LINEAR_TEAMS", {}, "user1")
            assert mock_execute.call_count == 1  # Still 1, used cache
            assert r2 == r1  # Same result
    
    def test_cache_miss_different_args(self):
        """Different arguments should not hit cache."""
        with patch("backend.services.composio_service.Composio") as MockComposio, \
             patch("backend.services.composio_service.os.getenv", return_value="fake_key"):
            
            from backend.services.composio_service import ComposioService
            
            service = ComposioService()
            mock_execute = MagicMock()
            service.composio.tools.execute = mock_execute
            
            result = MagicMock()
            result.data = {"channels": []}
            mock_execute.return_value = result
            
            # First call
            service.execute_tool("SLACK_LIST_ALL_CHANNELS", {"types": "public"}, "user1")
            
            # Second call with different args - should not hit cache
            service.execute_tool("SLACK_LIST_ALL_CHANNELS", {"types": "private"}, "user1")
            
            assert mock_execute.call_count == 2  # Both executed
    
    def test_non_cacheable_tool_not_cached(self):
        """Non-cacheable tools should always execute."""
        with patch("backend.services.composio_service.Composio") as MockComposio, \
             patch("backend.services.composio_service.os.getenv", return_value="fake_key"):
            
            from backend.services.composio_service import ComposioService
            
            service = ComposioService()
            mock_execute = MagicMock()
            service.composio.tools.execute = mock_execute
            
            result = MagicMock()
            result.data = {"ok": True}
            mock_execute.return_value = result
            
            # SLACK_SEND_MESSAGE is a write action, not cacheable
            service.execute_tool("SLACK_SEND_MESSAGE", {"channel": "C1"}, "user1")
            service.execute_tool("SLACK_SEND_MESSAGE", {"channel": "C1"}, "user1")
            
            assert mock_execute.call_count == 2  # Both executed
