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

        # The Proposal - MAXED OUT with all Linear metadata
        yield {
            "type": "proposal",
            "tool": "LINEAR_CREATE_LINEAR_ISSUE",
            "content": {
                "title": "Fix the navigation bug on Settings page",
                "description": "User reported that the navigation menu disappears when scrolling on the Settings page. This affects both light and dark mode. Steps to reproduce:\n\n1. Open Settings\n2. Scroll down to 'Advanced' section\n3. Navigation menu disappears\n\nExpected: Navigation should remain visible at all times.",
                "teamId": "b0c33658-525d-4f71-a029-775796016149",
                "teamName": "Mobile App",
                "projectId": "a1b2c3d4-5678-90ab-cdef-123456789012",
                "projectName": "Q1 Bug Fixes",
                "priority": 1,
                "priorityName": "High",
                "stateId": "state-uuid-here",
                "stateName": "In Progress",
                "assigneeId": "user-uuid-here",
                "assigneeName": "Sarah Chen",
                "labels": ["bug", "ui", "settings"],
                "dueDate": "2024-01-25",
            },
            "summary_text": "I'll create a high-priority Linear ticket for the navigation bug.",
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

        # The Proposal - MAXED OUT with all Slack metadata
        yield {
            "type": "proposal",
            "tool": "SLACK_SENDS_A_MESSAGE_TO_A_SLACK_CHANNEL",
            "content": {
                "channel": "C12345678",
                "channelName": "#engineering",
                "text": "🚨 **Build Failed** 🚨\n\nThe CI pipeline failed on the `main` branch.\n\n**Failed Job:** Unit Tests\n**Commit:** `abc1234` by @sarah\n**Error:**\n```\nAssertionError: Expected 200 but got 500\n```\n\n<https://ci.example.com/build/1234|View Build Logs>",
                "userName": "@build-bot",
                "thread_ts": "1234567890.123456",
                "reply_broadcast": False,
                "mrkdwn": True,
            },
            "summary_text": "I'll send a detailed build failure notification to #engineering.",
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

        # Proposal 1 (Linear) with remaining proposals - MAXED OUT
        yield {
            "type": "proposal",
            "tool": "LINEAR_CREATE_LINEAR_ISSUE",
            "content": {
                "title": "Database performance degradation on prod",
                "description": "We're seeing slow query times (>2s) for user dashboards during peak hours.\\n\\n**Affected queries:**\\n- `getUserDashboard()`\\n- `getRecentActivity()`\\n\\n**Impact:** ~500 users affected, page load times 5x slower than normal.",
                "teamId": "b0c33658-525d-4f71-a029-775796016149",
                "teamName": "Backend",
                "projectName": "Infrastructure",
                "priority": 0,
                "priorityName": "Urgent",
                "stateName": "Triage",
                "assigneeName": "Mike Johnson",
                "labels": ["performance", "database", "production"],
            },
            "summary_text": "First, I'll create an urgent ticket for the performance issue.",
            "app_id": "linear",
            "proposal_index": 0,
            "total_proposals": 2,
            "remaining_proposals": [
                {
                    "tool": "SLACK_SENDS_A_MESSAGE_TO_A_SLACK_CHANNEL",
                    "app_id": "slack",
                    "args": {
                        "channelName": "#backend-alerts",
                        "text": "🚨 **URGENT: Database Performance Issue**\\n\\nNew ticket created: Database performance degradation on prod\\n\\n• Priority: Urgent\\n• Assigned: Mike Johnson\\n• Team: Backend\\n\\n<https://linear.app/ticket/BACK-123|View in Linear>",
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

        # The Proposal - MAXED OUT with all Calendar metadata
        yield {
            "type": "proposal",
            "tool": "GOOGLECALENDAR_CREATE_EVENT",
            "content": {
                "summary": "Q1 Roadmap Planning Session",
                "description": "## Agenda\n\n1. **Review Q4 results** (15 min)\n   - OKR completion status\n   - Lessons learned\n\n2. **Q1 Priorities** (30 min)\n   - Voice command improvements\n   - New app integrations\n   - Performance optimizations\n\n3. **Resource allocation** (15 min)\n\n---\n\n📎 Pre-read: [Q1 Roadmap Draft](https://docs.google.com/document/...)",
                "start": {"dateTime": "2024-01-22T14:00:00", "timeZone": "America/Los_Angeles"},
                "end": {"dateTime": "2024-01-22T15:30:00", "timeZone": "America/Los_Angeles"},
                "location": "Conference Room A / https://meet.google.com/abc-defg-hij",
                "attendees": [
                    {"email": "sarah.chen@acme.com", "displayName": "Sarah Chen"},
                    {"email": "mike.johnson@acme.com", "displayName": "Mike Johnson"},
                    {"email": "lisa.wong@acme.com", "displayName": "Lisa Wong"},
                    {"email": "alex.kumar@acme.com", "displayName": "Alex Kumar"},
                ],
                "reminders": {
                    "useDefault": False,
                    "overrides": [
                        {"method": "email", "minutes": 60},
                        {"method": "popup", "minutes": 15},
                    ]
                },
                "conferenceData": {
                    "conferenceId": "abc-defg-hij",
                    "conferenceSolution": {"name": "Google Meet"}
                },
                "colorId": "9",  # Blueberry
                "visibility": "default",
                "guestsCanModify": False,
                "guestsCanInviteOthers": True,
            },
            "summary_text": "I'll schedule the Q1 Roadmap Planning Session for Monday 2-3:30 PM.",
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

        # Proposal 1 (Linear) with remaining proposals for Slack and Calendar - MAXED OUT
        yield {
            "type": "proposal",
            "tool": "LINEAR_CREATE_LINEAR_ISSUE",
            "content": {
                "title": "Customer-reported: Checkout flow broken on Safari",
                "description": "A VIP customer reported that they cannot complete checkout on Safari 17.\n\n**Steps to reproduce:**\n1. Add items to cart\n2. Click 'Proceed to Checkout'\n3. Page hangs on payment step\n\n**Browser:** Safari 17.2 on macOS Sonoma\n**Account:** enterprise-vip-123",
                "teamId": "b0c33658-525d-4f71-a029-775796016149",
                "teamName": "Frontend",
                "projectName": "Customer Issues",
                "priority": 0,
                "priorityName": "Urgent",
                "stateName": "Backlog",
                "assigneeName": "Lisa Wong",
                "labels": ["bug", "safari", "checkout", "customer-reported"],
            },
            "summary_text": "First, I'll create an urgent ticket for the Safari checkout bug.",
            "app_id": "linear",
            "proposal_index": 0,
            "total_proposals": 3,
            "remaining_proposals": [
                {
                    "tool": "SLACK_SENDS_A_MESSAGE_TO_A_SLACK_CHANNEL",
                    "app_id": "slack",
                    "args": {
                        "channelName": "#customer-escalations",
                        "text": "🔥 **VIP Customer Issue - Checkout Broken**\n\n**Ticket:** FRONT-456\n**Customer:** Enterprise VIP Account\n**Browser:** Safari 17.2\n**Assigned:** Lisa Wong\n**Priority:** Urgent\n\nPlease prioritize. Customer is waiting.\n\n<https://linear.app/ticket/FRONT-456|View Ticket>",
                    },
                },
                {
                    "tool": "GOOGLECALENDAR_CREATE_EVENT",
                    "app_id": "google_calendar",
                    "args": {
                        "summary": "Urgent: Safari Bug Triage",
                        "description": "Quick sync to triage the Safari checkout bug reported by VIP customer.\\n\\n• Linear ticket: FRONT-456\\n• Must resolve before EOD",
                        "start": {"dateTime": "2024-01-20T15:00:00", "timeZone": "America/New_York"},
                        "end": {"dateTime": "2024-01-20T15:30:00", "timeZone": "America/New_York"},
                        "location": "https://meet.google.com/xyz-abcd-efg",
                        "attendees": [
                            {"email": "lisa.wong@acme.com", "displayName": "Lisa Wong"},
                            {"email": "tech-lead@acme.com", "displayName": "Tech Lead"},
                        ],
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
                "owner": "acme-corp",
                "repo": "caddyai-frontend",
                "title": "feat: Implement voice command confirmation UI",
                "body": "## Summary\n\nThis PR adds a new confirmation card component for voice commands.\n\n## Changes\n\n- Added `ConfirmationCardView.swift` with glassmorphism styling\n- Implemented animated status pills for multi-app workflows\n- Added haptic feedback on confirm/cancel actions\n\n## Testing\n\n- Tested with Linear, Slack, and Calendar integrations\n- Verified animations run at 60fps on M1 MacBook\n\n## Screenshots\n\nSee attached Figma designs for reference.",
                "head": "feature/confirmation-ui",
                "base": "main",
            },
            "summary_text": "I'll create a PR to merge feature/confirmation-ui into main.",
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
                "to": "engineering-team@acme.com",
                "cc": "product@acme.com",
                "subject": "[Action Required] Q1 Sprint Planning - Please Review",
                "body": "Hi Team,\n\nI hope this email finds you well. As we wrap up the current sprint, I wanted to share the priorities for Q1 planning.\n\n**Key Priorities:**\n1. Complete the voice command integration with remaining apps\n2. Improve response latency by 40%\n3. Add enterprise SSO support\n\n**Action Items:**\n- Please review the attached roadmap document by Friday\n- Add your estimates to the shared spreadsheet\n- Flag any blockers in the #planning channel\n\nLet me know if you have any questions or concerns.\n\nBest regards,\nCaddy AI Assistant",
            },
            "summary_text": "I'll send an email to engineering-team@acme.com about Q1 planning.",
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
                "parent_id": "workspace-docs-123",
                "title": "Weekly Team Sync - January 16, 2024",
                "properties": {
                    "Status": "In Progress",
                    "Attendees": ["@alice", "@bob", "@charlie"],
                    "Tags": ["meeting", "weekly", "engineering"]
                },
                "content": "# Agenda\n\n## 1. Sprint Review (15 min)\n- Demo of voice command confirmation cards\n- Review pull request feedback\n- Discuss performance metrics\n\n## 2. Blockers & Dependencies (10 min)\n- Waiting on design approval for Settings page\n- Need API keys for Gmail integration\n\n## 3. Upcoming Work (10 min)\n- [ ] Finalize multi-app workflow animations\n- [ ] Write unit tests for proposal parsing\n- [ ] Update documentation\n\n---\n\n# Notes\n\n*Notes will be added during the meeting...*",
            },
            "summary_text": "I'll create a Weekly Team Sync page in Notion.",
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
