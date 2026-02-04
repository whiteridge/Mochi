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
    - "test 9" / "test nine" -> Demo flow (GitHub digest + Notion + Calendar)
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

MOCK_THINKING_DELAY_SEC = float(os.getenv("MOCK_THINKING_DELAY_SEC", "0.9"))
MOCK_SEARCHING_DELAY_SEC = float(os.getenv("MOCK_SEARCHING_DELAY_SEC", "1.4"))
MOCK_LONG_SEARCHING_DELAY_SEC = float(os.getenv("MOCK_LONG_SEARCHING_DELAY_SEC", "2.2"))
MOCK_PRE_PROPOSAL_DELAY_SEC = float(os.getenv("MOCK_PRE_PROPOSAL_DELAY_SEC", "0.5"))
MOCK_CONFIRM_EXEC_DELAY_SEC = float(os.getenv("MOCK_CONFIRM_EXEC_DELAY_SEC", "1.2"))


# --- Models (Same as main.py) ---


class ChatMessage(BaseModel):
    role: str
    content: str


class ChatRequest(BaseModel):
    messages: List[ChatMessage]
    user_id: str
    confirmed_tool: Optional[dict] = None
    user_timezone: Optional[str] = None
    api_key: Optional[str] = None


# --- Mock Agent Service ---


class MockAgentService:
    """Mock service that returns deterministic responses based on keywords."""

    def __init__(self):
        # Initialize real service for execution if available
        self.composio_service = ComposioService() if ComposioService else None

    async def _emit_thinking(self, text: str = "Thinking...") -> AsyncGenerator[Dict[str, Any], None]:
        yield {
            "type": "thinking",
            "content": text,
        }
        await asyncio.sleep(MOCK_THINKING_DELAY_SEC)

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
        print(f"[MOCK DEBUG] Contains 'test 9': {'test 9' in user_input_lower}")
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

        # Scenario I: Demo (test 9 / test nine)
        elif any(k in user_input_lower for k in ["test 9", "test nine", "testnine"]):
            print("[MOCK DEBUG] -> Matched: Demo full-flow scenario")
            async for event in self._demo_flow_scenario():
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
                    "- `test 8` → Notion\n"
                    "- `test 9` → Demo (GitHub + Notion + Calendar)"
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

        async for event in self._emit_thinking():
            yield event

        # 1. Emit executing status
        yield {
            "type": "early_summary",
            "content": f"Executing {app_id.capitalize()} action...",
            "app_id": app_id,
            "involved_apps": [app_id],
        }

        # 2. Pause before searching state
        await asyncio.sleep(MOCK_PRE_PROPOSAL_DELAY_SEC)

        # 3. Show searching state
        yield {
            "type": "tool_status",
            "tool": tool_name,
            "status": "searching",
            "app_id": app_id,
            "involved_apps": [app_id],
        }

        await asyncio.sleep(MOCK_CONFIRM_EXEC_DELAY_SEC)

        # 4. Execute (real or mock)
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
                result_text = "Mock execution successful. (ComposioService not loaded)"

            yield {
                "type": "tool_status",
                "tool": tool_name,
                "status": "done",
                "app_id": app_id,
                "involved_apps": [app_id],
            }

            await asyncio.sleep(MOCK_PRE_PROPOSAL_DELAY_SEC)

            # 5. Success message
            yield {
                "type": "message",
                "content": f"✅ Action completed successfully!\n\n```json\n{result_text}\n```",
                "action_performed": f"{app_id.capitalize()} Action Executed",
            }
        except Exception as e:
            yield {
                "type": "tool_status",
                "tool": tool_name,
                "status": "error",
                "app_id": app_id,
                "involved_apps": [app_id],
            }
            yield {
                "type": "message",
                "content": f"❌ Error executing action: {str(e)}",
                "action_performed": None,
            }

    async def _linear_scenario(self) -> AsyncGenerator[Dict[str, Any], None]:
        """Simulate Linear ticket creation flow."""
        async for event in self._emit_thinking():
            yield event

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

        await asyncio.sleep(MOCK_SEARCHING_DELAY_SEC)

        # Tool status: done
        yield {
            "type": "tool_status",
            "tool": "LINEAR_LIST_LINEAR_TEAMS",
            "status": "done",
            "app_id": "linear",
        }

        await asyncio.sleep(MOCK_PRE_PROPOSAL_DELAY_SEC)

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
        async for event in self._emit_thinking():
            yield event

        # Early summary
        yield {
            "type": "early_summary",
            "content": "Drafting a message to the team...",
            "app_id": "slack",
            "involved_apps": ["slack"],
        }

        await asyncio.sleep(MOCK_PRE_PROPOSAL_DELAY_SEC)

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

        async for event in self._emit_thinking():
            yield event

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

        # Simulate searching each app before proposals (skip "done" to avoid thinking between searches)
        for app_id, tool in [
            ("linear", "LINEAR_PRECHECK"),
            ("slack", "SLACK_PRECHECK"),
        ]:
            yield {
                "type": "tool_status",
                "tool": tool,
                "status": "searching",
                "app_id": app_id,
                "involved_apps": apps,
            }
            await asyncio.sleep(MOCK_LONG_SEARCHING_DELAY_SEC)

        await asyncio.sleep(MOCK_PRE_PROPOSAL_DELAY_SEC)

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
        """Simulate Google Calendar upcoming events flow."""
        async for event in self._emit_thinking():
            yield event

        # Early summary
        yield {
            "type": "early_summary",
            "content": "I'll fetch your upcoming events for the next 6 hours.",
            "app_id": "google_calendar",
            "involved_apps": ["google_calendar"],
        }

        # Tool status: searching upcoming events
        yield {
            "type": "tool_status",
            "tool": "GOOGLECALENDAR_EVENTS_LIST",
            "status": "searching",
            "app_id": "google_calendar",
        }

        await asyncio.sleep(MOCK_SEARCHING_DELAY_SEC)

        # Tool status: done
        yield {
            "type": "tool_status",
            "tool": "GOOGLECALENDAR_EVENTS_LIST",
            "status": "done",
            "app_id": "google_calendar",
        }

        await asyncio.sleep(MOCK_PRE_PROPOSAL_DELAY_SEC)

        # The Proposal - upcoming events snapshot
        yield {
            "type": "proposal",
            "tool": "GOOGLECALENDAR_EVENTS_LIST",
            "content": {
                "summary": "Upcoming events (next 6 hours)",
                "description": (
                    "- 9:00 AM-9:30 AM  Daily Standup\n"
                    "- 11:00 AM-12:00 PM  Product Sync\n"
                    "- 1:30 PM-2:00 PM  Design Review"
                ),
                "start": {"dateTime": "2024-01-22T09:00:00", "timeZone": "America/Los_Angeles"},
                "end": {"dateTime": "2024-01-22T15:00:00", "timeZone": "America/Los_Angeles"},
                "calendar_id": "primary",
            },
            "summary_text": "Here's what's coming up in the next 6 hours.",
            "app_id": "google_calendar",
            "proposal_index": 0,
            "total_proposals": 1,
        }

    async def _triple_app_scenario(self) -> AsyncGenerator[Dict[str, Any], None]:
        """Simulate triple-app flow (Linear + Slack + Calendar)."""
        apps = ["linear", "slack", "google_calendar"]

        async for event in self._emit_thinking():
            yield event

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

        # Simulate searching each app before proposals (skip "done" to avoid thinking between searches)
        for app_id, tool in [
            ("linear", "LINEAR_PRECHECK"),
            ("slack", "SLACK_PRECHECK"),
            ("google_calendar", "CALENDAR_PRECHECK"),
        ]:
            yield {
                "type": "tool_status",
                "tool": tool,
                "status": "searching",
                "app_id": app_id,
                "involved_apps": apps,
            }
            await asyncio.sleep(MOCK_LONG_SEARCHING_DELAY_SEC)

        await asyncio.sleep(MOCK_PRE_PROPOSAL_DELAY_SEC)

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

    async def _demo_flow_scenario(self) -> AsyncGenerator[Dict[str, Any], None]:
        """Simulate demo flow (GitHub digest + Notion + Calendar)."""
        apps = ["github", "notion", "google_calendar"]

        async for event in self._emit_thinking():
            yield event

        yield {
            "type": "early_summary",
            "content": "I'll summarize your GitHub notifications, log it in Notion, and block time to review.",
            "app_id": "github",
            "involved_apps": apps,
        }

        yield {
            "type": "multi_app_status",
            "apps": [
                {"app_id": "github", "state": "waiting"},
                {"app_id": "notion", "state": "waiting"},
                {"app_id": "google_calendar", "state": "waiting"},
            ],
            "active_app": "github",
        }

        for app_id, tool in [
            ("github", "GITHUB_LIST_NOTIFICATIONS"),
            ("notion", "NOTION_PRECHECK"),
            ("google_calendar", "CALENDAR_PRECHECK"),
        ]:
            yield {
                "type": "tool_status",
                "tool": tool,
                "status": "searching",
                "app_id": app_id,
                "involved_apps": apps,
            }
            await asyncio.sleep(MOCK_LONG_SEARCHING_DELAY_SEC)

        await asyncio.sleep(MOCK_PRE_PROPOSAL_DELAY_SEC)

        yield {
            "type": "proposal",
            "tool": "GITHUB_CREATE_ISSUE",
            "content": {
                "owner": "acme-corp",
                "repo": "triage",
                "title": "GitHub Notifications Digest - Jan 30",
                "body": (
                    "Summary of new GitHub notifications (last 24h):\n\n"
                    "1) PR #428 - \"Improve onboarding quick setup\" (review requested)\n"
                    "2) Issue #512 - \"Auth config missing for Slack\" (needs triage)\n"
                    "3) PR #417 - \"Fix calendar invite parsing\" (ready to merge)\n\n"
                    "Suggested next steps:\n"
                    "- Review PR #428 and leave feedback\n"
                    "- Triage Issue #512 and assign owner\n"
                    "- Merge PR #417 after CI passes"
                ),
                "labels": ["digest", "triage"],
                "assignees": ["matteo"],
            },
            "summary_text": "Here's a clean digest of your GitHub notifications.",
            "app_id": "github",
            "proposal_index": 0,
            "total_proposals": 3,
            "remaining_proposals": [
                {
                    "tool": "NOTION_CREATE_PAGE",
                    "app_id": "notion",
                    "args": {
                        "parent_id": "workspace-digest-001",
                        "title": "GitHub Daily Digest - Jan 30",
                        "properties": {
                            "Status": "Ready",
                            "Owner": "Matteo",
                            "Tags": ["github", "triage", "daily"]
                        },
                        "content": (
                            "## Highlights\n"
                            "- 3 high-signal notifications\n"
                            "- 1 urgent auth issue\n"
                            "- 1 PR ready to merge\n\n"
                            "## Action Items\n"
                            "- Review PR #428\n"
                            "- Assign Issue #512\n"
                            "- Merge PR #417\n\n"
                            "## Notes\n"
                            "- Keep an eye on Slack auth errors in staging."
                        ),
                    },
                },
                {
                    "tool": "GOOGLECALENDAR_CREATE_EVENT",
                    "app_id": "google_calendar",
                    "args": {
                        "summary": "GitHub Triage (Daily Digest)",
                        "description": "Quick review of today's GitHub digest and action items.",
                        "start": {"dateTime": "2026-01-30T16:00:00", "timeZone": "America/Los_Angeles"},
                        "end": {"dateTime": "2026-01-30T16:30:00", "timeZone": "America/Los_Angeles"},
                        "location": "https://meet.google.com/triage-room",
                    },
                },
            ],
        }

    async def _github_scenario(self) -> AsyncGenerator[Dict[str, Any], None]:
        """Simulate GitHub PR creation flow."""
        async for event in self._emit_thinking():
            yield event

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

        await asyncio.sleep(MOCK_SEARCHING_DELAY_SEC)

        yield {
            "type": "tool_status",
            "tool": "GITHUB_LIST_REPOS",
            "status": "done",
            "app_id": "github",
        }

        await asyncio.sleep(MOCK_PRE_PROPOSAL_DELAY_SEC)

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
        async for event in self._emit_thinking():
            yield event

        # Early summary
        yield {
            "type": "early_summary",
            "content": "I'll draft an email for you.",
            "app_id": "gmail",
            "involved_apps": ["gmail"],
        }

        await asyncio.sleep(MOCK_PRE_PROPOSAL_DELAY_SEC)

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
        async for event in self._emit_thinking():
            yield event

        # Early summary
        yield {
            "type": "early_summary",
            "content": "I'll create a page in Notion.",
            "app_id": "notion",
            "involved_apps": ["notion"],
        }

        await asyncio.sleep(MOCK_PRE_PROPOSAL_DELAY_SEC)

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
            details = mock_service.composio_service.get_connection_details(app_name, user_id)
            return {
                "connected": details.get("connected", False),
                "status": details.get("status"),
                "action_required": details.get("action_required", False),
            }
        except Exception:
            pass
    # Default to connected in mock mode for easier testing
    return {"connected": True, "status": "ACTIVE", "action_required": False}


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
