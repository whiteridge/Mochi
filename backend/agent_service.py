import os
import time
from typing import Dict, Any, List, Optional
from dotenv import load_dotenv
from google import genai
from google.genai import types
from google.genai import errors as genai_errors
from composio import Composio

from composio_gemini import GeminiProvider

load_dotenv()

class AgentService:
    def __init__(self):
        self.api_key = os.getenv("GOOGLE_API_KEY")
        if not self.api_key:
            raise ValueError("GOOGLE_API_KEY environment variable is required")
        self.client = genai.Client(api_key=self.api_key)
        
        # Initialize Composio
        # Note: API key for Composio is picked up from COMPOSIO_API_KEY env var by default if not passed
        self.composio = Composio(provider=GeminiProvider())

    def run_agent(self, user_input: str, user_id: str, chat_history: List[Dict[str, str]] = []):
        """
        Runs the agent with the given user input and user_id.
        Yields events:
        - {"type": "tool_status", "tool": "ToolName", "status": "searching"}
        - {"type": "proposal", "tool": "ToolName", "content": {...}}
        - {"type": "message", "content": "Final response"}
        """
        print(f"Running agent for user: {user_id} with input: {user_input}")
        
        # 1. Get tools for the user (Linear)
        try:
            composio_tools = self.composio.tools.get(
                user_id=user_id, 
                tools=[
                    "linear_create_linear_issue",
                    "linear_create_linear_issue_details",
                    "linear_create_linear_label",
                    "linear_create_linear_project",
                    "linear_delete_linear_issue",
                    "linear_get_all_linear_teams",
                    "linear_get_attachments",
                    "linear_get_current_user",
                    "linear_get_cycles_by_team_id",
                    "linear_get_linear_issue",
                    "linear_list_issue_drafts",
                    "linear_list_linear_cycles",
                    "linear_list_linear_issues",
                    "linear_list_linear_labels",
                    "linear_list_linear_projects",
                    "linear_list_linear_states",
                    "linear_list_linear_teams",
                    "linear_list_linear_users",
                    "linear_manage_draft",
                    "linear_remove_issue_label",
                    "linear_remove_reaction",
                    "linear_run_query_or_mutation",
                    "linear_update_issue",
                    "linear_update_linear_issue",
                    "linear_create_a_comment",
                    "linear_get_comments"
                ]
            )
            # DEBUG: Verify Available Tools
            tool_names = [t.function_declarations[0].name for t in composio_tools if t.function_declarations]
            print(f"DEBUG: Available tools for user {user_id}: {tool_names}")

        except Exception as e:
            yield {
                "type": "message",
                "content": f"Error fetching tools: {str(e)}. Please ensure you are connected to Linear.",
                "action_performed": None
            }
            return

        # 2. Convert to Gemini format
        gemini_tools = [
            types.Tool(function_declarations=[tool.function_declarations[0]])
            for tool in composio_tools
            if tool.function_declarations
        ]

        # 3. Configure Gemini
        system_instruction = """
    You are Caddy, an advanced autonomous agent capable of interacting with external apps (Linear, etc.) on behalf of the user.

    ### THE GOLDEN RULE: RESOLVE BEFORE YOU REJECT
    Users will almost NEVER provide technical IDs (like UUIDs or database keys). They will provide **Natural Language Names** (e.g., "The Marketing Project", "Blue Hexagon Ticket", "Meeting with Sarah").

    **Your Primary Directive is to map these Names to IDs automatically.**

    ### OPERATING PROCEDURE
    When a user asks for an action (e.g., "Create an issue in 'Mobile App' project"):

    1.  **Identify the Target Tool:** (e.g., `linear_create_issue`).
    2.  **Check Required Arguments:** Does this tool require an ID (e.g., `project_id`, `team_id`)?
    3.  **Check Your Context:** Do you have this ID?
        *   **YES:** Execute the tool immediately.
        *   **NO:** **STOP.** Do not complain. Look at your other tools.
    4.  **FIND THE ID:**
        *   Use a **Search Tool** (e.g., `linear_list_linear_issues`, `linear_list_linear_projects`, `linear_list_linear_teams`) using the name the user provided.
        *   Execute the search.
        *   Extract the ID from the result.
        *   **THEN** execute the original request using that ID.

    ### SUMMARIZATION & READ ACTIONS
    When reading content (Issues, Emails, Comments, etc.):
    *   **DO NOT** output raw JSON or long lists.
    *   **ALWAYS** provide a concise summary (max 2-3 sentences).
    *   Focus on the key details: Title, Status, Assignee, and latest update.

    ### WRITE ACTIONS & PROPOSALS
    When the user requests a modification (Create, Update, Delete):
    *   **DO NOT** execute the tool immediately if it is a significant change.
    *   Instead, output a Structured Proposal containing the title, description, and key fields.
    *   Wait for the user to confirm.

    ### TOOL MAPPING
    *   If you need to SEARCH for an issue, use `linear_list_linear_issues`.
    *   If you need to find a Project ID, use `linear_list_linear_projects`.
    *   If you need to find a User ID, use `linear_list_linear_users`.
    *   If you need to find a Team ID, use `linear_list_linear_teams`.

    ### EXAMPLE (Mental Chain of Thought)
    **User:** "Add a task 'Buy Milk' to the Personal project."
    **Bad Agent:** "I need a project ID to create a task."
    **Good Agent (YOU):**
    *   "I need to create a task, but I need the ID for 'Personal'."
    *   "I will call `linear_list_linear_projects(filter={'name': {'eq': 'Personal'}})`."
    *   "Result found: Project 'Personal' has ID 'abc-123'."
    *   "Now I will call `linear_create_linear_issue(title='Buy Milk', project_id='abc-123')`."

    ### HANDLING UI/VISUAL QUESTIONS
    If users ask about colors, button placements, or visual attributes:
    *   You cannot "see" the UI.
    *   However, you **CAN** read description text and comments.
    *   Search for the item -> Read its description -> Infer the visual details from the text.

    ### FINAL INSTRUCTION
    Be concise. Don't tell the user you are searching. Just do the search, get the ID, and do the work.
    """
        
        config = types.GenerateContentConfig(
            tools=gemini_tools,
            system_instruction=system_instruction
        )

        # 4. Start Chat
        chat = self.client.chats.create(
            model="gemini-2.5-flash", 
            config=config,
            history=chat_history
        )
        
        try:
            # Initial message
            response = chat.send_message(user_input)
            
            action_performed = None
            
            # Define Write Tools that require confirmation
            WRITE_TOOLS = [
                "linear_create_linear_issue",
                "linear_update_linear_issue",
                "linear_delete_linear_issue",
                "linear_create_a_comment"
            ]

            # 5. Handle Tool Execution Loop
            max_iterations = 5
            for _ in range(max_iterations):
                # Check if the model wants to call a function
                if response.candidates and response.candidates[0].content.parts:
                    for part in response.candidates[0].content.parts:
                        if part.function_call:
                            tool_name = part.function_call.name
                            args = part.function_call.args
                            print(f"DEBUG: Gemini calling tool: {tool_name} with args: {args}")
                            
                            # INTERCEPTION LOGIC
                            if tool_name in WRITE_TOOLS:
                                # Check if user has confirmed
                                if "CONFIRMED" in user_input:
                                    print(f"DEBUG: Action Confirmed. Executing {tool_name}")
                                    # Proceed to execution below
                                else:
                                    print(f"DEBUG: Intercepting {tool_name} for confirmation.")
                                    # Yield Proposal Event
                                    yield {
                                        "type": "proposal",
                                        "tool": tool_name,
                                        "content": args
                                    }
                                    # Stop execution here for this turn
                                    # We return a message to the model so it knows we are waiting
                                    # But we yield a 'proposal' to the frontend
                                    return

                            # YIELD TOOL STATUS EVENT
                            yield {
                                "type": "tool_status",
                                "tool": "Linear", # We can make this dynamic based on tool_name if needed
                                "status": "searching"
                            }

                try:
                    function_responses, executed = GeminiProvider.handle_response(response, composio_tools)
                except Exception as tool_error:
                    print(f"DEBUG: Tool Execution Failed: {tool_error}")
                    break

                if executed:
                    print(f"DEBUG: Tool Output: {function_responses}")
                    print("Tool executed. Sending results back to model.")
                    
                    # Send tool outputs back to Gemini
                    response = chat.send_message(function_responses)
                    
                    action_performed = "Linear Action Executed" 
                else:
                    # No more tool calls, we have the final text response
                    break
            
            # YIELD FINAL MESSAGE EVENT
            yield {
                "type": "message",
                "content": response.text,
                "action_performed": action_performed
            }

        except Exception as e:
            print(f"Error in agent execution: {e}")
            yield {
                "type": "message",
                "content": f"An error occurred: {str(e)}",
                "action_performed": None
            }
