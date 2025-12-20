"""
Test suite for Agent logic (Interception vs. Execution).

This test suite ensures that:
- Write/Destructive actions yield "proposal" events (interception)
- Read/Safe actions yield "message" or "tool_status" events (execution)
- Ambiguous/Chat queries yield "message" events (no proposal)
"""
import pytest
import httpx
import json
from typing import List, Dict, Any


# Base URL for the API (adjust if needed)
BASE_URL = "http://localhost:8000"


async def run_query(query_text: str, user_id: str = "test_user") -> List[Dict[str, Any]]:
    """
    Helper function to send a POST request to /api/chat and collect all events.
    
    Args:
        query_text: The user query to send
        user_id: The user ID for the request
        
    Returns:
        List of parsed event dictionaries from the NDJSON stream
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
    # Write/Destructive Actions (Expect type: "proposal" event)
    (1, "Create a bug report for the login crash in the Mobile App team", "proposal", True),
    (3, "Create a task 'Buy Milk' for the Personal project", "proposal", True),
    (7, "Change the priority of ticket MAT-23 to Urgent", "proposal", True),
    (4, "Create two tickets: one for fixing the button color and one for the alignment issue", "proposal", True),
    
    # Read/Safe Actions (Expect type: "message" or "tool_status" event, NO proposal)
    (5, "Show me the ticket about login crash", "message", False),
    
    # Ambiguous/Chat (Expect type: "message" event)
    (6, "What about the payment issue?", "message", False),
])
async def test_scenario(scenario_id: int, query: str, expected_type: str, should_have_proposal: bool):
    """
    Parameterized test that runs specific scenarios and validates the agent logic.
    
    For Write actions: Asserts that the stream contains an event with type == "proposal"
    For Read actions: Asserts that the stream contains "message" or "tool_status", but NOT "proposal"
    """
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


@pytest.mark.asyncio
async def test_all_scenarios_summary():
    """
    Run all scenarios and print a summary of pass/fail results.
    """
    scenarios = [
        (1, "Create a bug report for the login crash in the Mobile App team", True),
        (3, "Create a task 'Buy Milk' for the Personal project", True),
        (7, "Change the priority of ticket MAT-23 to Urgent", True),
        (4, "Create two tickets: one for fixing the button color and one for the alignment issue", True),
        (5, "Show me the ticket about login crash", False),
        (6, "What about the payment issue?", False),
    ]
    
    results = []
    
    for scenario_id, query, should_have_proposal in scenarios:
        try:
            events = await run_query(query)
            event_types = [event.get("type") for event in events]
            has_proposal = "proposal" in event_types
            has_message = "message" in event_types
            has_tool_status = "tool_status" in event_types
            has_execution_event = has_message or has_tool_status
            
            if should_have_proposal:
                passed = has_proposal
                expected = "proposal"
            else:
                passed = not has_proposal and has_execution_event
                expected = "message/tool_status (no proposal)"
            
            results.append({
                "scenario": scenario_id,
                "query": query[:50] + "..." if len(query) > 50 else query,
                "passed": passed,
                "expected": expected,
                "found": event_types
            })
        except Exception as e:
            results.append({
                "scenario": scenario_id,
                "query": query[:50] + "..." if len(query) > 50 else query,
                "passed": False,
                "expected": "proposal" if should_have_proposal else "message/tool_status",
                "error": str(e)
            })
    
    # Print summary
    print("\n" + "="*80)
    print("TEST SCENARIOS SUMMARY")
    print("="*80)
    
    passed_count = sum(1 for r in results if r.get("passed", False))
    total_count = len(results)
    
    for result in results:
        status = "✓ PASS" if result.get("passed", False) else "✗ FAIL"
        print(f"\nScenario {result['scenario']}: {status}")
        print(f"  Query: {result['query']}")
        print(f"  Expected: {result['expected']}")
        if "error" in result:
            print(f"  Error: {result['error']}")
        else:
            print(f"  Found: {result['found']}")
    
    print("\n" + "="*80)
    print(f"Total: {passed_count}/{total_count} scenarios passed")
    print("="*80 + "\n")
    
    # Assert that all scenarios passed
    assert passed_count == total_count, f"Only {passed_count}/{total_count} scenarios passed"

