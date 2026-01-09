"""Unit tests for GitHubService."""

from unittest.mock import MagicMock

from backend.services.github_service import GitHubService


def test_github_write_action_detection():
    service = GitHubService(MagicMock())

    assert service.is_write_action("GITHUB_CREATE_ISSUE", {}) is True
    assert service.is_write_action("GITHUB_UPDATE_PULL_REQUEST", {}) is True
    assert service.is_write_action("GITHUB_SEARCH_REPOSITORIES", {}) is False


def test_github_load_tools_uses_toolkits():
    composio_service = MagicMock()
    composio_service.fetch_tools.return_value = ["tool"]
    service = GitHubService(composio_service)

    tools = service.load_tools(user_id="user-1")

    composio_service.fetch_tools.assert_called_with(
        user_id="user-1",
        toolkits=service.GITHUB_TOOLKITS,
    )
    assert tools == ["tool"]
