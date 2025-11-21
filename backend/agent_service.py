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

    def _is_write_action(self, tool_name: str, tool_args: dict) -> bool:
        """
        Detect if a tool represents a Write action that requires user confirmation.
        Composio tool names are UPPERCASE (e.g., LINEAR_CREATE_LINEAR_ISSUE),
        so we need case-insensitive matching.
        """
        tool_name_lower = tool_name.lower()
        
        # Check for common write prefixes
        write_prefixes = ["create_", "update_", "delete_", "remove_", "manage_"]
        if any(prefix in tool_name_lower for prefix in write_prefixes):
            print(f"DEBUG: Detected WRITE action (prefix match): {tool_name}")
            return True
        
        # Special case: GraphQL mutations via run_query_or_mutation
        if "run_query_or_mutation" in tool_name_lower:
            query = tool_args.get("query", "").strip().lower()
            if query.startswith("mutation"):
                print(f"DEBUG: Detected WRITE action (mutation): {tool_name}")
                return True
        
        print(f"DEBUG: Detected READ action: {tool_name}")
        return False

    def _format_history(self, history: List[Dict[str, str]]) -> List[types.Content]:
        """
        Formats the chat history into the structure expected by Gemini SDK.
        """
        formatted_history = []
        for msg in history:
            role = msg.get("role", "user")
            content = msg.get("parts", [])
            
            # Handle case where content might be a string (from simple dicts)
            if isinstance(content, str):
                parts = [types.Part(text=content)]
            elif isinstance(content, list):
                # Assuming list of strings or dicts, normalize to types.Part
                parts = []
                for part in content:
                    if isinstance(part, str):
                        parts.append(types.Part(text=part))
                    elif isinstance(part, dict) and "text" in part:
                        parts.append(types.Part(text=part["text"]))
            else:
                parts = [types.Part(text=str(content))]
                
            formatted_history.append(types.Content(role=role, parts=parts))
            
        return formatted_history

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
        *   **YES:** Proceed to step 4.
        *   **NO:** **STOP.** Do not complain. Look at your other tools.
    4.  **FIND THE ID (if needed):**
        *   Use a **Search Tool** (e.g., `linear_list_linear_issues`, `linear_list_linear_projects`, `linear_list_linear_teams`) using the name the user provided.
        *   Execute the search.
        *   Extract the ID from the result.
        *   **THEN** proceed to step 5.
    5.  **CALL THE TOOL:** Execute the action by calling the tool with all necessary arguments.

    ### PROACTIVE EXECUTION RULE - CRITICAL
    When the user implies a Write action (Create/Update/Delete):
    *   **DO NOT** ask "Shall I create this?" or "Would you like me to...?"
    *   **IMMEDIATELY** call the tool with your best inference of the arguments.
    *   The system has an automatic confirmation mechanism that will show a preview to the user.
    *   You will NEVER see this preview - it happens in the UI layer.
    *   Just focus on calling the tool correctly. The interception is handled for you.

    ### SUMMARIZATION & READ ACTIONS
    When reading content (Issues, Emails, Comments, etc.):
    *   **DO NOT** output raw JSON or long lists.
    *   **ALWAYS** provide a concise summary (max 2-3 sentences).
    *   Focus on the key details: Title, Status, Assignee, and latest update.

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
    Be concise. Don't tell the user you are searching. Just do the search, get the ID, and execute the tool.
    """
        
        config = types.GenerateContentConfig(
            tools=gemini_tools,
            system_instruction=system_instruction
        )

        # 4. Start Chat
        # Format history using the helper
        formatted_history = self._format_history(chat_history)
        
        chat = self.client.chats.create(
            model="gemini-2.5-flash", 
            config=config,
            history=formatted_history
        )
        
        try:
            # Initial message
            response = chat.send_message(user_input)
            
            action_performed = None
            
            # 5. Handle Tool Execution Loop
            max_iterations = 5
            for _ in range(max_iterations):
                # Track if this iteration has a write action
                has_write_action = False
                should_intercept = False
                
                # Check if the model wants to call a function
                if response.candidates and response.candidates[0].content.parts:
                    for part in response.candidates[0].content.parts:
                        if part.function_call:
                            tool_name = part.function_call.name
                            args = part.function_call.args
                            print(f"DEBUG: Gemini calling tool: {tool_name} with args: {args}")
                            
                            # INTERCEPTION LOGIC
                            is_write = self._is_write_action(tool_name, args)
                            has_write_action = is_write
                            
                            if is_write:
                                # Check if user has confirmed using the special token
                                # We use exact match to prevent false positives
                                # Frontend sends "__CONFIRMED__" when user clicks the confirm button
                                user_input_trimmed = user_input.strip()
                                
                                if user_input_trimmed == "__CONFIRMED__":
                                    print(f"DEBUG: Action Confirmed via token. Executing {tool_name}")
                                    # Clear the flag - allow execution to proceed
                                    should_intercept = False
                                else:
                                    print(f"DEBUG: Intercepting {tool_name} for confirmation.")
                                    # Set flag to prevent execution
                                    should_intercept = True
                                    
                                    # Yield Proposal Event with enriched metadata
                                    yield {
                                        "type": "proposal",
                                        "tool": tool_name,
                                        "content": args
                                    }
                                    # Do NOT yield a message - let the UI handle it
                                    # Stop execution here for this turn
                                    return
                            
                            # Only yield tool status for READ actions or confirmed WRITE actions
                            if not should_intercept:
                                yield {
                                    "type": "tool_status",
                                    "tool": "Linear", 
                                    "status": "searching"
                                }

                # Only execute tools if we didn't intercept
                if not should_intercept:
                    try:
                        function_responses, executed = GeminiProvider.handle_response(response, composio_tools)
                    except Exception as tool_error:
                        print(f"DEBUG: Tool Execution Failed: {tool_error}")
                        break

                    if executed:
                        print(f"DEBUG: Tool Output: {function_responses}")
                        print("Tool executed. Sending results back to model.")
                        
                        if has_write_action:
                            action_performed = "Linear Action Executed"
                        
                        # Send tool outputs back to Gemini
                        response = chat.send_message(function_responses)
                        
                    else:
                        # No more tool calls, we have the final text response
                        break
                else:
                    # We intercepted, stop the loop
                    return
            
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
