"""
Unit tests for Slack integration in AgentService.
"""
import pytest
from unittest.mock import MagicMock, patch
from backend.agent_service import AgentService
from backend.services.slack_service import SlackService

# Mock Google GenAI types
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
    def __init__(self, candidates, text=""):
        self.candidates = candidates
        self.text = text

@pytest.fixture
def mock_agent_service():
    with patch("backend.agent_service.genai.Client") as mock_client, \
         patch("backend.agent_service.ComposioService") as mock_composio, \
         patch("backend.agent_service.LinearService") as mock_linear, \
         patch("backend.agent_service.NotionService") as mock_notion, \
         patch("backend.agent_service.os.getenv", return_value="fake_key"):
        
        service = AgentService()
        service.slack_service = MagicMock(spec=SlackService)
        service.linear_service = MagicMock()
        service.notion_service = MagicMock()
        
        # Setup default behavior for services
        service.slack_service.load_tools.return_value = ["dummy_tool"]
        service.linear_service.load_tools.return_value = []
        service.notion_service.load_tools.return_value = []
        
        # CRITICAL: Configure is_write_action to return False by default
        # otherwise MagicMock objects are truthy!
        service.slack_service.is_write_action.return_value = False
        service.linear_service.is_write_action.return_value = False
        service.notion_service.is_write_action.return_value = False
        
        # Mock chat session
        mock_chat = MagicMock()
        service.client.chats.create.return_value = mock_chat
        
        return service, mock_chat

def test_slack_read_action(mock_agent_service):
    service, mock_chat = mock_agent_service
    
    # Setup: User asks for read action
    user_input = "Find messages about bug"
    user_id = "test_user"
    
    # Mock Gemini response: Call SLACK_SEARCH_MESSAGES
    tool_call = MockFunctionCall("SLACK_SEARCH_MESSAGES", {"query": "bug"})
    mock_response = MockResponse([MockCandidate(MockContent([MockPart(function_call=tool_call)]))])
    mock_chat.send_message.return_value = mock_response
    
    # Ensure is_write_action is False for both services
    service.slack_service.is_write_action.return_value = False
    service.linear_service.is_write_action.return_value = False
    
    # Run agent
    generator = service.run_agent(user_input, user_id)
    
    # Collect events
    events = list(generator)
    
    # Verify: Should execute tool (tool_status) and return message
    tool_status_events = [e for e in events if e["type"] == "tool_status"]
    assert len(tool_status_events) > 0
    assert tool_status_events[0]["status"] == "searching"
    
    # Verify execution happened
    service.composio_service.execute_tool.assert_called_with(
        slug="SLACK_SEARCH_MESSAGES",
        arguments={"query": "bug"},
        user_id=user_id
    )

def test_slack_write_action_interception(mock_agent_service):
    service, mock_chat = mock_agent_service
    
    # Setup: User asks for write action
    user_input = "Send message to #general"
    user_id = "test_user"
    
    # Mock Gemini response: Call SLACK_SEND_MESSAGE
    tool_call = MockFunctionCall("SLACK_SEND_MESSAGE", {"channel": "C123", "text": "Hello"})
    mock_response = MockResponse([MockCandidate(MockContent([MockPart(function_call=tool_call)]))])
    mock_chat.send_message.return_value = mock_response
    
    # Mock Slack Service to say it IS a write action
    service.slack_service.is_write_action.return_value = True
    service.linear_service.is_write_action.return_value = False
    
    service.slack_service.enrich_proposal.return_value = {
        "channel": "C123", 
        "text": "Hello", 
        "channelName": "#general"
    }
    
    # Run agent
    generator = service.run_agent(user_input, user_id)
    
    # Collect events
    events = list(generator)
    
    # Verify: Should yield PROPOSAL event
    proposal_events = [e for e in events if e["type"] == "proposal"]
    assert len(proposal_events) == 1
    proposal = proposal_events[0]
    assert proposal["tool"] == "SLACK_SEND_MESSAGE"
    assert proposal["content"]["channelName"] == "#general"
    
    # Verify: Should NOT execute tool
    service.composio_service.execute_tool.assert_not_called()


def test_slack_write_not_blocked_without_linear(mock_agent_service):
    """Slack-only write should not be gated by Linear when Linear is absent."""
    service, mock_chat = mock_agent_service

    user_input = "Send hello to the Slack general channel"
    user_id = "test_user"

    # Mock Gemini response: Call SLACK_SEND_MESSAGE (Slack-only scenario)
    tool_call = MockFunctionCall("SLACK_SEND_MESSAGE", {"channel": "C123", "text": "Hello"})
    mock_response = MockResponse([MockCandidate(MockContent([MockPart(function_call=tool_call)]))])
    mock_chat.send_message.return_value = mock_response

    # Slack write; Linear not involved
    service.slack_service.is_write_action.return_value = True
    service.linear_service.is_write_action.return_value = False

    events = list(service.run_agent(user_input, user_id))

    proposal_events = [e for e in events if e.get("type") == "proposal"]
    assert len(proposal_events) == 1, f"Expected proposal for Slack write, got events: {events}"
    assert proposal_events[0]["tool"] == "SLACK_SEND_MESSAGE"
    service.composio_service.execute_tool.assert_not_called()

def test_slack_write_action_confirmed(mock_agent_service):
    service, mock_chat = mock_agent_service
    
    # Setup: User CONFIRMS action
    user_input = "__CONFIRMED__"
    user_id = "test_user"
    
    # Mock Gemini response: Call SLACK_SEND_MESSAGE
    tool_call = MockFunctionCall("SLACK_SEND_MESSAGE", {"channel": "C123", "text": "Hello"})
    mock_response = MockResponse([MockCandidate(MockContent([MockPart(function_call=tool_call)]))])
    mock_chat.send_message.return_value = mock_response
    
    # Mock Slack Service to say it IS a write action
    service.slack_service.is_write_action.return_value = True
    service.linear_service.is_write_action.return_value = False
    
    # Run agent
    confirmed_tool = {
        "tool": "SLACK_SEND_MESSAGE",
        "args": {"channel": "C123", "text": "Hello"},
        "app_id": "slack",
    }
    generator = service.run_agent(user_input, user_id, confirmed_tool=confirmed_tool)
    
    # Collect events
    events = list(generator)
    
    # Verify: Should execute tool
    service.composio_service.execute_tool.assert_called_with(
        slug="SLACK_SEND_MESSAGE",
        arguments={"channel": "C123", "text": "Hello"},
        user_id=user_id
    )
    
    # Verify: Should yield message event with action_performed
    message_events = [e for e in events if e["type"] == "message"]
    assert len(message_events) > 0
    assert message_events[-1]["action_performed"] == "Action Executed"



def test_slack_channel_summary_flow(mock_agent_service):
    service, mock_chat = mock_agent_service
    
    # Setup: User asks for summary
    user_input = "Summarize the general channel"
    user_id = "test_user"
    
    # Mock Gemini response sequence:
    # 1. Call slack_list_all_channels
    # 2. Call slack_fetch_conversation_history
    # 3. Return summary text
    
    # Step 1: Model calls list channels
    call1 = MockFunctionCall("slack_list_all_channels", {"types": "public_channel"})
    resp1 = MockResponse([MockCandidate(MockContent([MockPart(function_call=call1)]))])
    
    # Step 2: Model calls fetch history (after getting channel ID)
    call2 = MockFunctionCall("slack_fetch_conversation_history", {"channel": "C_GENERAL"})
    resp2 = MockResponse([MockCandidate(MockContent([MockPart(function_call=call2)]))])
    
    # Step 3: Model returns summary
    resp3 = MockResponse([], text="Here is a summary of the general channel...")
    
    mock_chat.send_message.side_effect = [resp1, resp2, resp3]
    
    # Mock Composio execution results
    # Result 1: Channel list
    res1 = MagicMock()
    res1.data = {"channels": [{"id": "C_GENERAL", "name": "general"}]}
    
    # Result 2: History
    res2 = MagicMock()
    res2.data = {"messages": [{"user": "U1", "text": "Hello", "ts": "123.456"}]}
    
    service.composio_service.execute_tool.side_effect = [res1, res2]
    
    # Run agent
    generator = service.run_agent(user_input, user_id)
    events = list(generator)
    
    # Verify tool calls
    assert service.composio_service.execute_tool.call_count == 2
    
    # Check first call
    args1 = service.composio_service.execute_tool.call_args_list[0]
    assert args1.kwargs["slug"] == "slack_list_all_channels"
    
    # Check second call
    args2 = service.composio_service.execute_tool.call_args_list[1]
    assert args2.kwargs["slug"] == "slack_fetch_conversation_history"
    assert args2.kwargs["arguments"]["channel"] == "C_GENERAL"
    

    
    # Verify final message
    message_events = [e for e in events if e["type"] == "message"]
    assert len(message_events) > 0
    assert "summary" in message_events[-1]["content"]

def test_sanitize_schema_dict():
    from backend.utils.tool_converter import _sanitize_schema_dict
    
    bad_schema = {
        "type": "object",
        "properties": {
            "is_private": {
                "type": "boolean",
                "humanParameterDescription": "Is the channel private?"
            },
            "nested": {
                "type": "object",
                "properties": {
                    "inner": {
                        "type": "string",
                        "humanParameterDescription": "Inner param"
                    }
                }
            }
        }
    }
    
    _sanitize_schema_dict(bad_schema)
    
    # Check top level
    assert "humanParameterDescription" not in bad_schema["properties"]["is_private"]
    
    # Check nested
    assert "humanParameterDescription" not in bad_schema["properties"]["nested"]["properties"]["inner"]
