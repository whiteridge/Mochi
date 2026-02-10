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


def test_failed_confirmed_write_does_not_block_follow_up_proposals(mock_agent_service):
    service = mock_agent_service
    user_id = "test_user"

    # Confirmed Slack action fails (e.g. channel_not_found)
    confirmed_tool = {
        "tool": "SLACK_SEND_MESSAGE",
        "args": {"channel": "C_BAD", "markdown_text": "hello"},
        "app_id": "slack",
    }

    responses = [
        LLMResponse(tool_calls=[]),  # initial "Execute confirmed action" prompt
        LLMResponse(
            tool_calls=[
                ToolCall(
                    name="SLACK_SEND_MESSAGE",
                    args={"channel": "C0A101WM3T4", "markdown_text": "hello"},
                ),
                ToolCall(
                    name="LINEAR_CREATE_LINEAR_ISSUE",
                    args={"title": "blue bug", "priority": 1},
                ),
            ]
        ),
    ]
    stub_chat = StubChat(responses)

    service.composio_service.execute_tool.return_value = {
        "data": {"message": "Slack API error: channel_not_found"},
        "error": "Slack API error: channel_not_found",
        "successful": False,
    }
    service.slack_service.is_write_action.side_effect = (
        lambda tool_name, _args: tool_name == "SLACK_SEND_MESSAGE"
    )
    service.linear_service.is_write_action.side_effect = (
        lambda tool_name, _args: tool_name == "LINEAR_CREATE_LINEAR_ISSUE"
    )
    service.slack_service.enrich_proposal.side_effect = (
        lambda _user_id, args, _tool_name: args
    )
    service.linear_service.enrich_proposal.side_effect = (
        lambda _user_id, args, _tool_name: args
    )

    with patch("backend.agent_service.create_chat_session", return_value=(stub_chat, None)):
        events = list(
            service.run_agent(
                user_input="Execute confirmed action",
                user_id=user_id,
                confirmed_tool=confirmed_tool,
            )
        )

    proposal_events = [event for event in events if event["type"] == "proposal"]
    assert len(proposal_events) == 1
    proposal = proposal_events[0]
    assert proposal["total_proposals"] == 2
    queued_tools = {proposal["tool"]}
    queued_tools.update(item["tool"] for item in proposal["remaining_proposals"])
    assert queued_tools == {"SLACK_SEND_MESSAGE", "LINEAR_CREATE_LINEAR_ISSUE"}


def test_successful_confirmed_write_short_circuits_with_completion_message(
    mock_agent_service,
):
    service = mock_agent_service
    user_id = "test_user"

    confirmed_tool = {
        "tool": "SLACK_SEND_MESSAGE",
        "args": {"channel": "C0A101WM3T4", "markdown_text": "hello"},
        "app_id": "slack",
    }

    responses = [
        LLMResponse(tool_calls=[]),  # initial "Execute confirmed action" prompt
    ]
    stub_chat = StubChat(responses)

    service.composio_service.execute_tool.return_value = {
        "data": {"ok": True},
        "error": None,
        "successful": True,
    }

    with patch("backend.agent_service.create_chat_session", return_value=(stub_chat, None)):
        events = list(
            service.run_agent(
                user_input="Execute confirmed action",
                user_id=user_id,
                confirmed_tool=confirmed_tool,
            )
        )

    message_events = [event for event in events if event["type"] == "message"]
    assert len(message_events) == 1
    assert message_events[0]["content"] == "Slack action completed."
    assert message_events[0]["action_performed"] == "Slack action executed"
    assert not any(event["type"] == "proposal" for event in events)
    assert stub_chat.tool_results == []


def test_successful_confirmed_linear_write_short_circuits_with_completion_message(
    mock_agent_service,
):
    service = mock_agent_service
    user_id = "test_user"
    service.linear_service.load_tools.return_value = ["dummy_linear_tool"]

    confirmed_tool = {
        "tool": "LINEAR_CREATE_LINEAR_ISSUE",
        "args": {"team_id": "0f5f3de8", "priority": 4, "title": "blue bug"},
        "app_id": "linear",
    }

    responses = [
        LLMResponse(tool_calls=[]),
    ]
    stub_chat = StubChat(responses)

    service.composio_service.execute_tool.return_value = {
        "data": {"id": "issue-123"},
        "error": None,
        "successful": True,
    }

    with patch("backend.agent_service.create_chat_session", return_value=(stub_chat, None)):
        events = list(
            service.run_agent(
                user_input="Execute confirmed action",
                user_id=user_id,
                confirmed_tool=confirmed_tool,
            )
        )

    message_events = [event for event in events if event["type"] == "message"]
    assert len(message_events) == 1
    assert message_events[0]["content"] == "Linear action completed."
    assert message_events[0]["action_performed"] == "Linear action executed"
    assert not any(event["type"] == "proposal" for event in events)
    assert stub_chat.tool_results == []


def test_empty_final_model_text_emits_fallback_message(mock_agent_service):
    service = mock_agent_service
    user_id = "test_user"

    responses = [
        LLMResponse(text=""),
        LLMResponse(text=""),
    ]
    stub_chat = StubChat(responses)

    with patch("backend.agent_service.create_chat_session", return_value=(stub_chat, None)):
        events = list(
            service.run_agent(
                user_input="Thank you.",
                user_id=user_id,
            )
        )

    message_events = [event for event in events if event["type"] == "message"]
    assert len(message_events) == 1
    assert (
        message_events[0]["content"]
        == "I couldn't generate a complete response. Please try again."
    )
    assert message_events[0]["action_performed"] is None


def test_empty_model_response_retries_for_plain_text_once(mock_agent_service):
    service = mock_agent_service
    user_id = "test_user"

    responses = [
        LLMResponse(text="", thoughts=["Thinking..."]),
        LLMResponse(text="Hello!"),
    ]
    stub_chat = StubChat(responses)

    with patch("backend.agent_service.create_chat_session", return_value=(stub_chat, None)):
        events = list(
            service.run_agent(
                user_input="Say hi.",
                user_id=user_id,
            )
        )

    message_events = [event for event in events if event["type"] == "message"]
    assert len(message_events) == 1
    assert message_events[0]["content"] == "Hello!"
    assert len(stub_chat.user_messages) == 2
    assert "Do not call tools in this response." in stub_chat.user_messages[1]


def test_capabilities_query_returns_concise_static_message(mock_agent_service):
    service = mock_agent_service

    with patch("backend.agent_service.create_chat_session") as mock_create_chat:
        events = list(service.run_agent("what can you do?", "test_user"))

    message_events = [event for event in events if event["type"] == "message"]
    assert len(message_events) == 1
    assert (
        message_events[0]["content"]
        == "I can help across Slack, Linear, GitHub, Gmail, and Google Calendar: "
        "send/read Slack messages, create/update Linear issues, manage GitHub issues/PRs, "
        "draft/search emails, and create/update calendar events."
    )
    assert message_events[0]["action_performed"] is None
    mock_create_chat.assert_not_called()
