"""
Mock Backend for CaddyAI UI Testing.

This backend mimics the real API endpoints but uses deterministic scenario
detection instead of LLM calls. Great for UI development and testing confirmation
flows without burning tokens.

Usage:
    uvicorn mock_main:app --reload --port 8000

Test scenarios:
    - "test 1" / "test one" -> Linear ticket proposal
    - "test 2" / "test two" -> Slack message proposal
    - "test 3" / "test three" -> Multi-app flow (Linear + Slack)
    - "test 4" / "test four" -> Triple-app flow (Linear + Slack + Calendar)
    - "test 5" / "test five" -> Calendar event
    - "test 6" / "test six" -> GitHub PR
    - "test 7" / "test seven" -> Gmail email
    - "test 8" / "test eight" -> Notion page
    - anything else -> Help message
"""

import asyncio
import json
import os
from typing import Any, AsyncGenerator, Dict, List, Optional

from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException
from fastapi.responses import StreamingResponse
from pydantic import BaseModel

# Import ComposioService for optional real execution
try:
    from services.composio_service import ComposioService
except ImportError:
    print("Warning: Could not import ComposioService. Execution will be mocked.")
    ComposioService = None

load_dotenv()

app = FastAPI(title="CaddyAI Mock Backend")


# --- Models (Same as main.py) ---


class ChatMessage(BaseModel):
    role: str
    content: str


class ChatRequest(BaseModel):
    messages: List[ChatMessage]
    user_id: str
    confirmed_tool: Optional[dict] = None
    user_timezone: Optional[str] = None


# --- Mock Agent Service ---


class MockAgentService:
    """Mock service that returns deterministic responses based on keywords."""

    def __init__(self):
        # Initialize real service for execution if available
        self.composio_service = ComposioService() if ComposioService else None

    async def run_mock_flow(
        self,
        user_input: str,
        user_id: str,
        confirmed_tool: Optional[dict] = None,
    ) -> AsyncGenerator[Dict[str, Any], None]:
        """
        Determines the flow based on user_input keywords or executes a confirmed tool.

        Yields events in the same format as the real backend:
        - early_summary: Initial status message
        - tool_status: Tool searching/done states
        - multi_app_status: Multi-app workflow state
        - proposal: Action requiring confirmation
        - message: Final response
        """

        # CASE 1: HANDLE CONFIRMED TOOL (Execute it)
        if confirmed_tool:
            async for event in self._handle_execution(confirmed_tool, user_id):
                yield event
            return

        # CASE 2: GENERATE PROPOSAL (Based on keywords)
        user_input_lower = user_input.lower()
        
        # DEBUG: Log received input
        print("")
        print("=" * 60)
        print(f"[MOCK DEBUG] Received user input: '{user_input}'")
        print(f"[MOCK DEBUG] Lowercased: '{user_input_lower}'")
        print(f"[MOCK DEBUG] Contains 'test 1': {'test 1' in user_input_lower}")
        print(f"[MOCK DEBUG] Contains 'test 2': {'test 2' in user_input_lower}")
        print(f"[MOCK DEBUG] Contains 'test 3': {'test 3' in user_input_lower}")
        print(f"[MOCK DEBUG] Contains 'test 4': {'test 4' in user_input_lower}")
        print(f"[MOCK DEBUG] Contains 'test 5': {'test 5' in user_input_lower}")
        print("=" * 60)

        # Scenario A: Linear (test 1 / test one)
        if any(k in user_input_lower for k in ["test 1", "test one", "testone"]) or ("linear" in user_input_lower and "test" not in user_input_lower):
            print("[MOCK DEBUG] -> Matched: Linear scenario")
            async for event in self._linear_scenario():
                yield event

        # Scenario B: Slack (test 2 / test two)
        elif any(k in user_input_lower for k in ["test 2", "test two", "testtwo"]) or ("slack" in user_input_lower and "test" not in user_input_lower):
            print("[MOCK DEBUG] -> Matched: Slack scenario")
            async for event in self._slack_scenario():
                yield event

        # Scenario C: Multi-App (test 3 / test three)
        elif any(k in user_input_lower for k in ["test 3", "test three", "testthree"]):
            print("[MOCK DEBUG] -> Matched: Multi-app scenario")
            async for event in self._multi_app_scenario():
                yield event

        # Scenario D: Triple-App (test 4 / test four)
        elif any(k in user_input_lower for k in ["test 4", "test four", "testfour"]):
            print("[MOCK DEBUG] -> Matched: Triple-app scenario")
            async for event in self._triple_app_scenario():
                yield event

        # Scenario E: Calendar (test 5 / test five)
        elif any(k in user_input_lower for k in ["test 5", "test five", "testfive"]) or ("calendar" in user_input_lower and "test" not in user_input_lower):
            print("[MOCK DEBUG] -> Matched: Calendar scenario")
            async for event in self._calendar_scenario():
                yield event

        # Scenario F: GitHub (test 6 / test six)
        elif any(k in user_input_lower for k in ["test 6", "test six", "testsix"]) or ("github" in user_input_lower and "test" not in user_input_lower):
            print("[MOCK DEBUG] -> Matched: GitHub scenario")
            async for event in self._github_scenario():
                yield event

        # Scenario G: Gmail (test 7 / test seven)
        elif any(k in user_input_lower for k in ["test 7", "test seven", "testseven"]) or ("gmail" in user_input_lower and "test" not in user_input_lower):
            print("[MOCK DEBUG] -> Matched: Gmail scenario")
            async for event in self._gmail_scenario():
                yield event

        # Scenario H: Notion (test 8 / test eight)
        elif any(k in user_input_lower for k in ["test 8", "test eight", "testeight"]) or ("notion" in user_input_lower and "test" not in user_input_lower):
            print("[MOCK DEBUG] -> Matched: Notion scenario")
            async for event in self._notion_scenario():
                yield event

        # Default: Help message
        else:
            yield {
                "type": "message",
                "content": (
                    "🧪 **Mock Backend Active**\n\n"
                    "Try saying:\n"
                    "- `test 1` → Linear\n"
                    "- `test 2` → Slack\n"
                    "- `test 3` → Multi-app (Linear+Slack)\n"
                    "- `test 4` → Triple-app (+Calendar)\n"
                    "- `test 5` → Calendar\n"
                    "- `test 6` → GitHub\n"
                    "- `test 7` → Gmail\n"
                    "- `test 8` → Notion"
                ),
                "action_performed": None,
            }

    async def _handle_execution(
        self,
        confirmed_tool: dict,
        user_id: str,
    ) -> AsyncGenerator[Dict[str, Any], None]:
        """Handle confirmed tool execution."""
        tool_name = confirmed_tool.get("tool", "unknown_tool")
        args = confirmed_tool.get("args", {})
        app_id = confirmed_tool.get("app_id", "unknown")

        # 1. Emit executing status
        yield {
            "type": "early_summary",
            "content": f"Executing {app_id.capitalize()} action...",
            "app_id": app_id,
            "involved_apps": [app_id],
        }

        # 2. Simulate processing delay
        await asyncio.sleep(1.0)

        # 3. Execute (real or mock)
        try:
            if self.composio_service:
                # Actually run it with the real service
                result = self.composio_service.execute_tool(tool_name, args, user_id)
                if hasattr(result, "data"):
                    result_text = json.dumps(result.data, indent=2)[:500]
                else:
                    result_text = str(result)[:500]
            else:
                # Fake execution
                await asyncio.sleep(0.5)
                result_text = "Mock execution successful. (ComposioService not loaded)"

            # 4. Success message
            yield {
                "type": "message",
                "content": f"✅ Action completed successfully!\n\n```json\n{result_text}\n```",
                "action_performed": f"{app_id.capitalize()} Action Executed",
            }
        except Exception as e:
            yield {
                "type": "message",
                "content": f"❌ Error executing action: {str(e)}",
                "action_performed": None,
            }

    async def _linear_scenario(self) -> AsyncGenerator[Dict[str, Any], None]:
        """Simulate Linear ticket creation flow."""
        # Early summary
        yield {
            "type": "early_summary",
            "content": "I'll create a ticket in Linear for you.",
            "app_id": "linear",
            "involved_apps": ["linear"],
        }

        # Tool status: searching
        yield {
            "type": "tool_status",
            "tool": "LINEAR_LIST_LINEAR_TEAMS",
            "status": "searching",
            "app_id": "linear",
        }

        await asyncio.sleep(0.8)

        # Tool status: done
        yield {
            "type": "tool_status",
            "tool": "LINEAR_LIST_LINEAR_TEAMS",
            "status": "done",
            "app_id": "linear",
        }

        await asyncio.sleep(0.3)

        # The Proposal
        yield {
            "type": "proposal",
            "tool": "LINEAR_CREATE_LINEAR_ISSUE",
            "content": {
                "title": "Fix the navigation bug",
                "description": "User reported navigation issues on the settings page. This was reported via voice command.",
                "teamId": "b0c33658-525d-4f71-a029-775796016149",
                "priority": 2,
            },
            "summary_text": "I'll create a Linear ticket for the navigation bug.",
            "app_id": "linear",
            "proposal_index": 0,
            "total_proposals": 1,
        }

    async def _slack_scenario(self) -> AsyncGenerator[Dict[str, Any], None]:
        """Simulate Slack message flow."""
        # Early summary
        yield {
            "type": "early_summary",
            "content": "Drafting a message to the team...",
            "app_id": "slack",
            "involved_apps": ["slack"],
        }

        await asyncio.sleep(0.5)

        # The Proposal
        yield {
            "type": "proposal",
            "tool": "SLACK_SENDS_A_MESSAGE_TO_A_SLACK_CHANNEL",
            "content": {
                "channel": "C12345678",
                "channelName": "#engineering",
                "text": "Hey team, the build is broken. Can someone take a look?",
            },
            "summary_text": "I'll send a message to #engineering.",
            "app_id": "slack",
            "proposal_index": 0,
            "total_proposals": 1,
        }

    async def _multi_app_scenario(self) -> AsyncGenerator[Dict[str, Any], None]:
        """Simulate multi-app flow (Linear + Slack)."""
        apps = ["linear", "slack"]

        # Early summary
        yield {
            "type": "early_summary",
            "content": "I'll create a ticket and notify the team.",
            "app_id": "linear",
            "involved_apps": apps,
        }

        # Multi-app status
        yield {
            "type": "multi_app_status",
            "apps": [
                {"app_id": "linear", "state": "waiting"},
                {"app_id": "slack", "state": "waiting"},
            ],
            "active_app": "linear",
        }

        await asyncio.sleep(0.5)

        # Proposal 1 (Linear) with remaining proposals
        yield {
            "type": "proposal",
            "tool": "LINEAR_CREATE_LINEAR_ISSUE",
            "content": {
                "title": "Multi-app test ticket",
                "description": "Testing the multi-app flow.",
                "teamId": "b0c33658-525d-4f71-a029-775796016149",
                "priority": 3,
            },
            "summary_text": "First, I'll create the ticket in Linear.",
            "app_id": "linear",
            "proposal_index": 0,
            "total_proposals": 2,
            "remaining_proposals": [
                {
                    "tool": "SLACK_SENDS_A_MESSAGE_TO_A_SLACK_CHANNEL",
                    "app_id": "slack",
                    "args": {
                        "channelName": "#updates",
                        "text": "📋 New ticket created: Multi-app test ticket",
                    },
                }
            ],
        }

    async def _calendar_scenario(self) -> AsyncGenerator[Dict[str, Any], None]:
        """Simulate Google Calendar event creation flow."""
        # Early summary
        yield {
            "type": "early_summary",
            "content": "I'll schedule a meeting for you.",
            "app_id": "google_calendar",
            "involved_apps": ["google_calendar"],
        }

        await asyncio.sleep(0.5)

        # The Proposal
        yield {
            "type": "proposal",
            "tool": "GOOGLECALENDAR_CREATE_EVENT",
            "content": {
                "summary": "Team Sync Meeting",
                "description": "Weekly team sync to discuss progress and blockers.",
                "start": {"dateTime": "2024-01-20T10:00:00", "timeZone": "UTC"},
                "end": {"dateTime": "2024-01-20T11:00:00", "timeZone": "UTC"},
            },
            "summary_text": "I'll create a Team Sync Meeting on the calendar.",
            "app_id": "google_calendar",
            "proposal_index": 0,
            "total_proposals": 1,
        }

    async def _triple_app_scenario(self) -> AsyncGenerator[Dict[str, Any], None]:
        """Simulate triple-app flow (Linear + Slack + Calendar)."""
        apps = ["linear", "slack", "google_calendar"]

        # Early summary
        yield {
            "type": "early_summary",
            "content": "I'll create a ticket, notify the team, and schedule a follow-up meeting.",
            "app_id": "linear",
            "involved_apps": apps,
        }

        # Multi-app status
        yield {
            "type": "multi_app_status",
            "apps": [
                {"app_id": "linear", "state": "waiting"},
                {"app_id": "slack", "state": "waiting"},
                {"app_id": "google_calendar", "state": "waiting"},
            ],
            "active_app": "linear",
        }

        await asyncio.sleep(0.5)

        # Proposal 1 (Linear) with remaining proposals for Slack and Calendar
        yield {
            "type": "proposal",
            "tool": "LINEAR_CREATE_LINEAR_ISSUE",
            "content": {
                "title": "Triple-app test ticket",
                "description": "Testing the 3-app workflow.",
                "teamId": "b0c33658-525d-4f71-a029-775796016149",
                "priority": 2,
            },
            "summary_text": "First, I'll create the ticket in Linear.",
            "app_id": "linear",
            "proposal_index": 0,
            "total_proposals": 3,
            "remaining_proposals": [
                {
                    "tool": "SLACK_SENDS_A_MESSAGE_TO_A_SLACK_CHANNEL",
                    "app_id": "slack",
                    "args": {
                        "channelName": "#engineering",
                        "text": "📋 New ticket: Triple-app test ticket",
                    },
                },
                {
                    "tool": "GOOGLECALENDAR_CREATE_EVENT",
                    "app_id": "google_calendar",
                    "args": {
                        "summary": "Follow-up: Triple-app test",
                        "description": "Discuss the new ticket.",
                        "start": {"dateTime": "2024-01-20T14:00:00", "timeZone": "UTC"},
                        "end": {"dateTime": "2024-01-20T15:00:00", "timeZone": "UTC"},
                    },
                },
            ],
        }

    async def _github_scenario(self) -> AsyncGenerator[Dict[str, Any], None]:
        """Simulate GitHub PR creation flow."""
        # Early summary
        yield {
            "type": "early_summary",
            "content": "I'll create a pull request on GitHub.",
            "app_id": "github",
            "involved_apps": ["github"],
        }

        # Tool status
        yield {
            "type": "tool_status",
            "tool": "GITHUB_LIST_REPOS",
            "status": "searching",
            "app_id": "github",
        }

        await asyncio.sleep(0.6)

        yield {
            "type": "tool_status",
            "tool": "GITHUB_LIST_REPOS",
            "status": "done",
            "app_id": "github",
        }

        await asyncio.sleep(0.3)

        # The Proposal
        yield {
            "type": "proposal",
            "tool": "GITHUB_CREATE_PULL_REQUEST",
            "content": {
                "owner": "your-org",
                "repo": "your-repo",
                "title": "feat: Add new feature",
                "body": "This PR implements the new feature as discussed.",
                "head": "feature-branch",
                "base": "main",
            },
            "summary_text": "I'll create a PR from feature-branch to main.",
            "app_id": "github",
            "proposal_index": 0,
            "total_proposals": 1,
        }

    async def _gmail_scenario(self) -> AsyncGenerator[Dict[str, Any], None]:
        """Simulate Gmail email composition flow."""
        # Early summary
        yield {
            "type": "early_summary",
            "content": "I'll draft an email for you.",
            "app_id": "gmail",
            "involved_apps": ["gmail"],
        }

        await asyncio.sleep(0.5)

        # The Proposal
        yield {
            "type": "proposal",
            "tool": "GMAIL_SEND_EMAIL",
            "content": {
                "to": "team@example.com",
                "subject": "Project Update",
                "body": "Hi team,\n\nHere's the latest update on the project.\n\nBest regards",
            },
            "summary_text": "I'll send an email to team@example.com.",
            "app_id": "gmail",
            "proposal_index": 0,
            "total_proposals": 1,
        }

    async def _notion_scenario(self) -> AsyncGenerator[Dict[str, Any], None]:
        """Simulate Notion page creation flow."""
        # Early summary
        yield {
            "type": "early_summary",
            "content": "I'll create a page in Notion.",
            "app_id": "notion",
            "involved_apps": ["notion"],
        }

        await asyncio.sleep(0.5)

        # The Proposal
        yield {
            "type": "proposal",
            "tool": "NOTION_CREATE_PAGE",
            "content": {
                "parent_id": "database-123",
                "title": "Meeting Notes - Jan 16",
                "content": "# Discussion Points\n\n- Item 1\n- Item 2\n\n# Action Items\n\n- [ ] Follow up on...",
            },
            "summary_text": "I'll create a new Notion page for meeting notes.",
            "app_id": "notion",
            "proposal_index": 0,
            "total_proposals": 1,
        }


# Initialize Mock Service
mock_service = MockAgentService()


# --- API Endpoints ---


@app.post("/api/chat")
async def chat_endpoint(request: ChatRequest):
    """Main chat endpoint - streams mock events based on keywords."""
    # Extract the last user message
    user_input = next(
        (m.content for m in reversed(request.messages) if m.role == "user"),
        "",
    )

    async def event_generator():
        effective_user_id = os.getenv("COMPOSIO_USER_ID", request.user_id)

        async for event in mock_service.run_mock_flow(
            user_input,
            effective_user_id,
            request.confirmed_tool,
        ):
            yield json.dumps(event) + "\n"

    return StreamingResponse(event_generator(), media_type="application/x-ndjson")


@app.get("/api/v1/integrations/connect/{app_name}")
async def get_connect_url(app_name: str, user_id: str):
    """Get the authorization URL for connecting an app."""
    if mock_service.composio_service:
        try:
            url = mock_service.composio_service.get_auth_url(app_name, user_id)
            return {"url": url}
        except Exception as e:
            return {"url": f"https://composio.dev/connect/{app_name}?error={str(e)}"}
    return {"url": f"https://composio.dev/connect/{app_name}"}


@app.get("/api/v1/integrations/status/{app_name}")
async def get_integration_status(app_name: str, user_id: str):
    """Check if user is connected to an app. Returns True in mock mode."""
    if mock_service.composio_service:
        try:
            is_connected = mock_service.composio_service.get_connection_status(
                app_name, user_id
            )
            return {"connected": is_connected}
        except Exception:
            pass
    # Default to connected in mock mode for easier testing
    return {"connected": True}


@app.delete("/api/v1/integrations/disconnect/{app_name}")
async def disconnect_integration(app_name: str, user_id: str):
    """Disconnect from an app."""
    if mock_service.composio_service:
        try:
            count = mock_service.composio_service.disconnect_app(app_name, user_id)
            return {"disconnected": True, "accounts_removed": count}
        except Exception as e:
            raise HTTPException(status_code=400, detail=str(e))
    return {"disconnected": True, "accounts_removed": 0}


@app.get("/health")
def health_check():
    """Health check endpoint."""
    return {
        "status": "ok",
        "mode": "mock",
        "composio_available": mock_service.composio_service is not None,
    }
