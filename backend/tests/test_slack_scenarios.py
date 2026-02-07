"""
Test suite for Slack Agent logic (Interception vs. Execution).
"""
import os

import pytest
import httpx
import json
from typing import List, Dict, Any

# These scenarios hit a live backend over HTTP.
if os.getenv("MOCHI_LIVE_TESTS") != "1":
    pytest.skip(
        "Live backend scenarios are skipped by default. Set MOCHI_LIVE_TESTS=1 to enable.",
        allow_module_level=True,
    )

# Base URL for the API
BASE_URL = "http://localhost:8000"


async def run_query(query_text: str, user_id: str = "test_user") -> List[Dict[str, Any]]:
    """
    Helper function to send a POST request to /api/chat and collect all events.
    """
    async with httpx.AsyncClient(timeout=60.0) as client:
        response = await client.post(
            f"{BASE_URL}/api/chat",
            json={
                "messages": [
                    {"role": "user", "content": query_text}
                ],
                "user_id": user_id
            }
        )
        response.raise_for_status()
        
        # Parse NDJSON stream
        events = []
        for line in response.text.strip().split("\n"):
            if line.strip():
                try:
                    event = json.loads(line)
                    events.append(event)
                except json.JSONDecodeError as e:
                    pytest.fail(f"Failed to parse JSON line: {line}\nError: {e}")
        
        return events


@pytest.mark.asyncio
@pytest.mark.parametrize("scenario_id,query,expected_type,should_have_proposal", [
    # Slack Write Actions (Expect type: "proposal" event)
    (1, "Send a message to #general saying Hello World", "proposal", True),
    (2, "Post 'Meeting starts now' in #announcements", "proposal", True),
    
    # Slack Read Actions (Expect type: "message" or "tool_status" event, NO proposal)
    (3, "What was the last message in #general?", "message", False),
    (4, "Find messages about 'login bug'", "message", False),
])
async def test_slack_scenario(scenario_id: int, query: str, expected_type: str, should_have_proposal: bool):
    """
    Parameterized test that runs specific Slack scenarios and validates the agent logic.
    """
    print(f"\nRunning Scenario {scenario_id}: {query}")
    events = await run_query(query)
    
    # Extract event types from the stream
    event_types = [event.get("type") for event in events]
    
    # Check for proposal events
    has_proposal = "proposal" in event_types
    
    # Check for message or tool_status events
    has_message = "message" in event_types
    has_tool_status = "tool_status" in event_types
    has_execution_event = has_message or has_tool_status
    
    # Write actions should have proposal
    if should_have_proposal:
        assert has_proposal, (
            f"Scenario {scenario_id} FAILED: Expected 'proposal' event for write action.\n"
            f"Query: {query}\n"
            f"Event types found: {event_types}\n"
            f"All events: {json.dumps(events, indent=2)}"
        )
        print(f"✓ Scenario {scenario_id}: Write action correctly intercepted (proposal found)")
        
        # Verify proposal content if possible
        proposal_event = next((e for e in events if e.get("type") == "proposal"), None)
        if proposal_event:
            content = proposal_event.get("content", {})
            print(f"  Proposal Content: {json.dumps(content, indent=2)}")
            # Ideally we check if channelName is enriched, but that depends on mock/real data
    
    # Read/Ambiguous actions should NOT have proposal
    else:
        assert not has_proposal, (
            f"Scenario {scenario_id} FAILED: Unexpected 'proposal' event for read/chat action.\n"
            f"Query: {query}\n"
            f"Event types found: {event_types}\n"
            f"All events: {json.dumps(events, indent=2)}"
        )
        assert has_execution_event, (
            f"Scenario {scenario_id} FAILED: Expected 'message' or 'tool_status' event for read/chat action.\n"
            f"Query: {query}\n"
            f"Event types found: {event_types}\n"
            f"All events: {json.dumps(events, indent=2)}"
        )
        print(f"✓ Scenario {scenario_id}: Read/Chat action correctly executed (no proposal, execution event found)")
