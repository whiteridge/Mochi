"""
Multi-app agent tests covering sequential reads and multi-app write proposals.
"""
import pytest
from unittest.mock import MagicMock, patch
from backend.agent_service import AgentService


class MockFunctionCall:
    def __init__(self, name, args):
        self.name = name
        self.args = args


class MockPart:
    def __init__(self, function_call=None, text=None):
        self.function_call = function_call
        self.text = text


class MockContent:
    def __init__(self, parts):
        self.parts = parts


class MockCandidate:
    def __init__(self, content):
        self.content = content


class MockResponse:
    def __init__(self, candidates=None, text=""):
        self.candidates = candidates or []
        self.text = text


@pytest.fixture
def agent_setup():
    with patch("backend.agent_service.genai.Client") as mock_client, \
         patch("backend.agent_service.ComposioService") as mock_composio, \
         patch("backend.agent_service.LinearService") as mock_linear, \
         patch("backend.agent_service.SlackService") as mock_slack, \
         patch("backend.agent_service.os.getenv", return_value="fake_key"):

        service = AgentService()
        mock_chat = MagicMock()
        service.client.chats.create.return_value = mock_chat

        # Replace dependencies with controllable fakes
        service.composio_service = MagicMock()
        service.linear_service = MagicMock()
        service.slack_service = MagicMock()

        service.linear_service.load_tools.return_value = ["linear_tool"]
        service.slack_service.load_tools.return_value = ["slack_tool"]

        # Basic write detection for coverage
        service.linear_service.is_write_action.side_effect = (
            lambda name, args: "create_" in name.lower() or "update_" in name.lower()
        )
        service.slack_service.is_write_action.side_effect = (
            lambda name, args: "send_message" in name.lower()
        )

        service.linear_service.enrich_proposal.side_effect = (
            lambda user_id, args, tool_name="": args
        )
        service.slack_service.enrich_proposal.side_effect = (
            lambda user_id, args, tool_name="": args
        )

        return service, mock_chat


def test_sequential_reads_execute_one_per_iteration(agent_setup):
    service, mock_chat = agent_setup

    linear_call = MockFunctionCall("LINEAR_LIST_LINEAR_ISSUES", {"teamId": "T1"})
    slack_call = MockFunctionCall("SLACK_FETCH_CONVERSATION_HISTORY", {"channel": "C123"})

    # Initial model response queues two reads; dispatcher should run them one per iteration
    resp1 = MockResponse([MockCandidate(MockContent([MockPart(function_call=linear_call),
                                                     MockPart(function_call=slack_call)]))])
    resp2 = MockResponse([MockCandidate(MockContent([]))])  # after first read result is sent back
    resp3 = MockResponse([], text="Done")
    mock_chat.send_message.side_effect = [resp1, resp2, resp3]

    res_linear = MagicMock()
    res_linear.data = {"issues": []}
    res_slack = MagicMock()
    res_slack.data = {"messages": []}
    service.composio_service.execute_tool.side_effect = [res_linear, res_slack]

    events = list(service.run_agent("Check Linear and Slack", "user1"))

    searching = [e for e in events if e.get("type") == "tool_status" and e.get("status") == "searching"]
    assert [e["app_id"] for e in searching] == ["linear", "slack"], f"Unexpected search order: {searching}"

    calls = service.composio_service.execute_tool.call_args_list
    assert calls[0].kwargs["slug"] == "LINEAR_LIST_LINEAR_ISSUES"
    assert calls[1].kwargs["slug"] == "SLACK_FETCH_CONVERSATION_HISTORY"

    # No proposals should appear for pure reads
    assert not any(e.get("type") == "proposal" for e in events)


def test_multi_app_write_queue_and_proposals(agent_setup):
    service, mock_chat = agent_setup

    # Treat both calls as writes so they must be intercepted
    service.linear_service.is_write_action.return_value = True
    service.slack_service.is_write_action.return_value = True

    linear_write = MockFunctionCall("LINEAR_CREATE_LINEAR_ISSUE", {"title": "Bug"})
    slack_write = MockFunctionCall("SLACK_SEND_MESSAGE", {"channel": "C1", "text": "ping"})

    resp1 = MockResponse([MockCandidate(MockContent([MockPart(function_call=linear_write),
                                                     MockPart(function_call=slack_write)]))])
    mock_chat.send_message.return_value = resp1

    events = list(service.run_agent("Create issue and notify", "user1"))

    # Writes should be intercepted, not executed
    assert service.composio_service.execute_tool.call_count == 0

    multi_status = next(e for e in events if e["type"] == "multi_app_status")
    assert {app["app_id"] for app in multi_status["apps"]} == {"linear", "slack"}

    proposal = next(e for e in events if e["type"] == "proposal")
    assert proposal["total_proposals"] == 2
    assert proposal["tool"] == "LINEAR_CREATE_LINEAR_ISSUE"
    assert proposal["remaining_proposals"][0]["tool"] == "SLACK_SEND_MESSAGE"

