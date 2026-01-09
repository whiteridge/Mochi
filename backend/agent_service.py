import os
from typing import Dict, List
from dotenv import load_dotenv
from google import genai

from agent.dispatcher import AgentDispatcher
from agent.gemini_config import build_gemini_tools, create_chat
from agent.tool_loader import load_composio_tools
from services.composio_service import ComposioService
from services.github_service import GitHubService
from services.gmail_service import GmailService
from services.google_calendar_service import GoogleCalendarService
from services.linear_service import LinearService
from services.notion_service import NotionService
from services.slack_service import SlackService

load_dotenv()


class AgentService:
    """Main agent service for orchestrating conversations with Composio tools."""
    
    def __init__(self):
        """Initialize the agent service with Gemini client and service dependencies."""
        self.api_key = os.getenv("GOOGLE_API_KEY")
        if not self.api_key:
            raise ValueError("GOOGLE_API_KEY environment variable is required")
        self.client = genai.Client(api_key=self.api_key)
        
        # Initialize services
        self.composio_service = ComposioService()
        self.linear_service = LinearService(self.composio_service)
        self.slack_service = SlackService(self.composio_service)
        self.notion_service = NotionService(self.composio_service)
        self.github_service = GitHubService(self.composio_service)
        self.gmail_service = GmailService(self.composio_service)
        self.google_calendar_service = GoogleCalendarService(
            self.composio_service
        )

    def run_agent(
        self,
        user_input: str,
        user_id: str,
        chat_history: List[Dict[str, str]] = [],
        confirmed_tool: Dict = None,
    ):
        """
        Runs the agent with the given user input and user_id.
        
        Args:
            confirmed_tool: If provided, executes ONLY this specific action:
                            {"tool": "TOOL_NAME", "args": {...}, "app_id": "linear"}
                            Then queues any subsequent write actions for next confirmation.
        
        Yields events:
        - {"type": "tool_status", "tool": "ToolName", "status": "searching", "involved_apps": [...]}
        - {"type": "multi_app_status", "apps": [...], "active_app": "..."}
        - {"type": "proposal", "tool": "ToolName", "content": {...}, "proposal_index": 0, "total_proposals": 2}
        - {"type": "message", "content": "Final response"}
        """
        print(f"Running agent for user: {user_id} with input: {user_input}")

        # 1. Get tools for the user (Linear, Slack, Notion, GitHub, Gmail, Calendar)
        all_composio_tools, errors = load_composio_tools(
            self.linear_service,
            self.slack_service,
            self.notion_service,
            self.github_service,
            self.gmail_service,
            self.google_calendar_service,
            user_id,
        )

        if not all_composio_tools:
            error_msg = "Error fetching tools. " + "; ".join(errors)
            yield {
                "type": "message",
                "content": f"{error_msg}. Please ensure you are connected to your apps.",
                "action_performed": None,
            }
            return

        # 2. Convert tools and configure Gemini
        gemini_tools, _ = build_gemini_tools(all_composio_tools)

        # 3. Start Chat
        chat = create_chat(self.client, gemini_tools, chat_history)

        # 4. Delegate streaming loop
        dispatcher = AgentDispatcher(
            composio_service=self.composio_service,
            linear_service=self.linear_service,
            slack_service=self.slack_service,
            notion_service=self.notion_service,
            github_service=self.github_service,
            gmail_service=self.gmail_service,
            google_calendar_service=self.google_calendar_service,
        )
        yield from dispatcher.run(
            chat=chat,
            user_input=user_input,
            user_id=user_id,
            confirmed_tool=confirmed_tool,
        )
