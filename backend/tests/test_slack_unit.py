"""
Unit tests for Slack integration in AgentService.
"""
import pytest
from unittest.mock import MagicMock, patch

from backend.agent_service import AgentService
from backend.services.slack_service import SlackService
from llm.types import LLMResponse, ToolCall


class StubChat:
    def __init__(self, responses):
        self._responses = list(responses)
        self.user_messages = []
        self.tool_results = []

    def send_user_message(self, text):
        self.user_messages.append(text)
        return self._responses.pop(0)

    def send_tool_result(self, tool_name, result, tool_call_id=None):
        self.tool_results.append((tool_name, result, tool_call_id))
        return self._responses.pop(0)


@pytest.fixture
def mock_agent_service():
    with patch("backend.agent_service.ComposioService") as mock_composio, \
         patch("backend.agent_service.LinearService") as mock_linear, \
         patch("backend.agent_service.NotionService") as mock_notion, \
         patch("backend.agent_service.GitHubService") as mock_github:

        service = AgentService(composio_service=mock_composio.return_value)
        service.slack_service = MagicMock(spec=SlackService)
        service.linear_service = MagicMock()
        service.notion_service = MagicMock()
        service.github_service = MagicMock()
        service.gmail_service = MagicMock()
        service.google_calendar_service = MagicMock()

        # Setup default behavior for services
        service.slack_service.load_tools.return_value = ["dummy_tool"]
        service.linear_service.load_tools.return_value = []
        service.notion_service.load_tools.return_value = []
        service.github_service.load_tools.return_value = []
        service.gmail_service.load_tools.return_value = []
        service.google_calendar_service.load_tools.return_value = []

        # Configure write checks to be False by default
        service.slack_service.is_write_action.return_value = False
        service.linear_service.is_write_action.return_value = False
        service.notion_service.is_write_action.return_value = False
        service.github_service.is_write_action.return_value = False
        service.gmail_service.is_write_action.return_value = False
        service.google_calendar_service.is_write_action.return_value = False

        return service


def test_slack_read_action(mock_agent_service):
    service = mock_agent_service

    # Setup: User asks for read action
    user_input = "Find messages about bug"
    user_id = "test_user"

    tool_call = ToolCall(name="SLACK_SEARCH_MESSAGES", args={"query": "bug"})
    responses = [
        LLMResponse(tool_calls=[tool_call]),
        LLMResponse(text="Found messages"),
    ]
    stub_chat = StubChat(responses)

    with patch("backend.agent_service.create_chat_session", return_value=(stub_chat, None)):
        # Run agent
        generator = service.run_agent(user_input, user_id)
        events = list(generator)

    tool_status_events = [e for e in events if e["type"] == "tool_status"]
    assert len(tool_status_events) > 0
    assert tool_status_events[0]["status"] == "searching"

    service.composio_service.execute_tool.assert_called_with(
        slug="SLACK_SEARCH_MESSAGES",
        arguments={"query": "bug"},
        user_id=user_id,
    )
    service.slack_service.is_write_action.assert_called_once_with(
        "SLACK_SEARCH_MESSAGES",
        {"query": "bug"},
    )
    service.linear_service.is_write_action.assert_not_called()
    service.notion_service.is_write_action.assert_not_called()
    service.github_service.is_write_action.assert_not_called()
    service.gmail_service.is_write_action.assert_not_called()
    service.google_calendar_service.is_write_action.assert_not_called()


def test_slack_write_action_interception(mock_agent_service):
    service = mock_agent_service

    user_input = "Send message to #general"
    user_id = "test_user"

    tool_call = ToolCall(name="SLACK_SEND_MESSAGE", args={"channel": "C123", "text": "Hello"})
    responses = [LLMResponse(tool_calls=[tool_call])]
    stub_chat = StubChat(responses)

    service.slack_service.is_write_action.return_value = True
    service.linear_service.is_write_action.return_value = False

    service.slack_service.enrich_proposal.return_value = {
        "channel": "C123",
        "text": "Hello",
        "channelName": "#general",
    }

    with patch("backend.agent_service.create_chat_session", return_value=(stub_chat, None)):
        generator = service.run_agent(user_input, user_id)
        events = list(generator)

    proposal_events = [e for e in events if e["type"] == "proposal"]
    assert len(proposal_events) == 1
    proposal = proposal_events[0]
    assert proposal["tool"] == "SLACK_SEND_MESSAGE"
    assert proposal["content"]["channelName"] == "#general"
    service.slack_service.is_write_action.assert_called_once_with(
        "SLACK_SEND_MESSAGE",
        {"channel": "C123", "text": "Hello"},
    )
    service.linear_service.is_write_action.assert_not_called()
    service.notion_service.is_write_action.assert_not_called()
    service.github_service.is_write_action.assert_not_called()
    service.gmail_service.is_write_action.assert_not_called()
    service.google_calendar_service.is_write_action.assert_not_called()
