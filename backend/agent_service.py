import os
from typing import Dict, List
from dotenv import load_dotenv
from google import genai
from google.genai import types

from services.composio_service import ComposioService
from services.linear_service import LinearService
from services.slack_service import SlackService
from utils.tool_converter import convert_to_gemini_tools
from utils.chat_utils import format_history

load_dotenv()


class AgentService:
    """Main agent service for orchestrating conversations with Linear and Slack tools."""
    
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

    def run_agent(self, user_input: str, user_id: str, chat_history: List[Dict[str, str]] = []):
        """
        Runs the agent with the given user input and user_id.
        Yields events:
        - {"type": "tool_status", "tool": "ToolName", "status": "searching"}
        - {"type": "proposal", "tool": "ToolName", "content": {...}}
        - {"type": "message", "content": "Final response"}
        """
        print(f"Running agent for user: {user_id} with input: {user_input}")
        
        # 1. Get tools for the user (Linear + Slack)
        all_composio_tools = []
        errors = []

        # Load Linear Tools
        try:
            linear_tools = self.linear_service.load_tools(user_id=user_id)
            if linear_tools:
                all_composio_tools.extend(linear_tools)
                print(f"DEBUG: Loaded {len(linear_tools)} Linear tools")
        except Exception as e:
            print(f"DEBUG: Error fetching Linear tools: {e}")
            errors.append(f"Linear: {str(e)}")

        # Load Slack Tools
        try:
            slack_tools = self.slack_service.load_tools(user_id=user_id)
            if slack_tools:
                all_composio_tools.extend(slack_tools)
                print(f"DEBUG: Loaded {len(slack_tools)} Slack tools")
        except Exception as e:
            print(f"DEBUG: Error fetching Slack tools: {e}")
            errors.append(f"Slack: {str(e)}")

        if not all_composio_tools:
            error_msg = "Error fetching tools. " + "; ".join(errors)
            yield {
                "type": "message",
                "content": f"{error_msg}. Please ensure you are connected to your apps.",
                "action_performed": None
            }
            return

        # 2. Convert tools to google-genai format
        gemini_tools = convert_to_gemini_tools(all_composio_tools)
        

        num_declarations = 0
        if gemini_tools and gemini_tools[0].function_declarations:
            declarations = gemini_tools[0].function_declarations
            num_declarations = len(declarations)
            
            # Log available Slack tools
            slack_tool_names = [d.name for d in declarations if d.name.lower().startswith("slack_")]
            print(f"DEBUG: Slack tools available to Gemini: {slack_tool_names}", flush=True)
            
        print(f"DEBUG: Passing {num_declarations} function declarations to Gemini config", flush=True)

        # 3. Configure Gemini
        system_instruction = """
    You are Caddy, an advanced autonomous agent capable of interacting with external apps (Linear, Slack, etc.) on behalf of the user.

    ### THE GOLDEN RULE: RESOLVE BEFORE YOU REJECT
    Users will almost NEVER provide technical IDs (like UUIDs or database keys). They will provide **Natural Language Names** (e.g., "The Marketing Project", "Blue Hexagon Ticket", "#eng channel", "DM to Alice").

    **Your Primary Directive is to map these Names to IDs automatically.**
    
    For Slack, when a user asks to send a message to a channel (e.g. '#general' or 'general'), always prefer a channel whose name or name_normalized exactly matches the requested name, rather than defaulting to other channels such as the workspace's default general channel.

    ### OPERATING PROCEDURE
    When a user asks for an action (e.g., "Create an issue in 'Mobile App' project" or "Send a message to #general"):

    1.  **Identify the Target Tool:** (e.g., `linear_create_issue`, `slack_send_message`).
    2.  **Check Required Arguments:** Does this tool require an ID (e.g., `project_id`, `channel`)?
    3.  **Check Your Context:** Do you have this ID?
        *   **YES:** Proceed to step 4.
        *   **NO:** **STOP.** Do not complain. Look at your other tools.
    4.  **FIND THE ID (if needed):**
        *   **Linear:** Use `linear_list_linear_issues`, `linear_list_linear_projects`, `linear_list_linear_teams`.
        *   **Slack:** Use `slack_list_all_channels` (or `slack_list_conversations`) for channels, `slack_list_all_users` for people.
        *   Execute the search.
        *   Extract the ID from the result.
        *   **THEN** proceed to step 5.
    5.  **CALL THE TOOL:** Execute the action by calling the tool with all necessary arguments.

    ### PROACTIVE EXECUTION RULE - CRITICAL
    When the user implies a Write action (Create/Update/Delete/Send):
    *   **DO NOT** ask "Shall I create this?" or "Would you like me to...?"
    *   **IMMEDIATELY** call the tool with your best inference of the arguments.
    *   The system has an automatic confirmation mechanism that will show a preview to the user.
    *   You will NEVER see this preview - it happens in the UI layer.
    *   Just focus on calling the tool correctly. The interception is handled for you.

    ### SUMMARIZATION & READ ACTIONS
    When reading content (Issues, Emails, Comments, Messages):
    *   **DO NOT** output raw JSON or long lists.
    *   **ALWAYS** provide a concise summary (max 2-3 sentences).
    *   Focus on the key details: Title, Status, Assignee, Content, and latest update.

    ### TOOL MAPPING
    **Linear:**
    *   Search Issue: `linear_list_linear_issues`
    *   Find Project ID: `linear_list_linear_projects`
    *   Find User ID: `linear_list_linear_users`
    *   Find Team ID: `linear_list_linear_teams`

    **Slack:**
    *   Find Channel ID: `slack_list_all_channels` or `slack_list_conversations` (filter by name)
    *   Find User ID: `slack_list_all_users` (filter by name/email)
    *   Find User ID: `slack_list_all_users` (filter by name/email)
    *   Send Message: `slack_send_message` (requires channel ID)
    *   Read History: `slack_fetch_conversation_history` (requires channel ID)

    ### SLACK SUMMARIZATION
    When the user asks about the contents of a channel (e.g. "Summarize #general" or "What's been happening in the General channel?"), you must:
    1.  Use Slack tools to resolve the channel name to a channel ID (e.g. `slack_list_all_channels`).
    2.  Use Slack conversation history tools (such as `slack_fetch_conversation_history`) to fetch recent messages.
    3.  Read and summarize those messages.
    
    You are not allowed to say that the tools cannot retrieve Slack messages unless you have tried the history tool and it fails with an error.

    ### EXAMPLE (Mental Chain of Thought - Slack)
    **User:** "Send a message to #random saying Hello"
    **Bad Agent:** "I need a channel ID for #random."
    **Good Agent (YOU):**
    *   "I need to send a message, but I need the ID for '#random'."
    *   "I will call `slack_list_all_channels(types='public_channel,private_channel')`."
    *   "Result found: Channel '#random' has ID 'C12345'."
    *   "Now I will call `slack_send_message(channel='C12345', text='Hello')`."

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
        formatted_history = format_history(chat_history)
        
        chat = self.client.chats.create(
            model="gemini-2.5-flash", 
            config=config,
            history=formatted_history
        )
        
        try:
            # Initial message
            print(f"DEBUG: Sending user input to Gemini: {user_input[:100]}...")
            response = chat.send_message(user_input)
            
            # DEBUG: Log function calls in response
            if hasattr(response, 'candidates') and response.candidates:
                candidate = response.candidates[0]
                if hasattr(candidate, 'content') and candidate.content is not None:
                    if hasattr(candidate.content, 'parts') and candidate.content.parts:
                        for part in candidate.content.parts:
                            if hasattr(part, 'function_call') and part.function_call:
                                print(f"DEBUG: Gemini calling tool: {part.function_call.name}", flush=True)
            
            action_performed = None
            
            # 5. Handle Tool Execution Loop
            max_iterations = 5
            write_action_executed = False
            
            for iteration in range(max_iterations):
                
                # Track if this iteration has a write action
                has_write_action = False
                should_intercept = False
                found_function_call = False
                
                # Check if the model wants to call a function
                if (hasattr(response, 'candidates') and response.candidates and 
                    hasattr(response.candidates[0], 'content') and response.candidates[0].content is not None and
                    hasattr(response.candidates[0].content, 'parts') and response.candidates[0].content.parts):
                    for part in response.candidates[0].content.parts:
                        if hasattr(part, 'function_call') and part.function_call:
                            found_function_call = True
                            tool_name = part.function_call.name
                            args = dict(part.function_call.args) if part.function_call.args else {}
                            print(f"DEBUG: Tool call: {tool_name}({args})", flush=True)
                            
                            # INTERCEPTION LOGIC
                            # Check Linear
                            is_linear_write = self.linear_service.is_write_action(tool_name, args)
                            # Check Slack
                            is_slack_write = self.slack_service.is_write_action(tool_name, args)
                            
                            is_write = is_linear_write or is_slack_write
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
                                    
                                    # Enrich proposal with human-readable names
                                    enriched_args = args
                                    if is_linear_write:
                                        enriched_args = self.linear_service.enrich_proposal(user_id, args, tool_name)
                                    elif is_slack_write:
                                        enriched_args = self.slack_service.enrich_proposal(user_id, args, tool_name)
                                    
                                    # Yield Proposal Event with enriched metadata
                                    yield {
                                        "type": "proposal",
                                        "tool": tool_name,
                                        "content": enriched_args
                                    }
                                    # Do NOT yield a message - let the UI handle it
                                    # Stop execution here for this turn
                                    return
                            
                            # Only yield tool status for READ actions or confirmed WRITE actions
                            if not should_intercept:
                                yield {
                                    "type": "tool_status",
                                    "tool": tool_name, 
                                    "status": "searching"
                                }
                
                # Log if no function call was found
                if not found_function_call and iteration == 0:
                    print("DEBUG: Gemini responded with text only (no function calls)", flush=True)

                # Only execute tools if we didn't intercept
                if not should_intercept and found_function_call:
                    # Manually execute tools since GoogleProvider doesn't have handle_tool_calls
                    function_responses = []
                    executed = False
                    
                    try:
                        # Extract all function calls from the response
                        for part in response.candidates[0].content.parts:
                            if hasattr(part, 'function_call') and part.function_call:
                                tool_name = part.function_call.name
                                tool_args = dict(part.function_call.args) if part.function_call.args else {}
                                
                                print(f"DEBUG: Executing: {tool_name}", flush=True)
                                
                                # Execute the tool via Composio
                                try:
                                    result = self.composio_service.execute_tool(
                                        slug=tool_name,
                                        arguments=tool_args,
                                        user_id=user_id
                                    )
                                    print(f"DEBUG: Tool execution result: {result}", flush=True)
                                    
                                    # Convert result to string for Gemini
                                    if hasattr(result, 'data'):
                                        result_data = result.data
                                    else:
                                        result_data = result
                                    
                                    # Create a function response part for Gemini
                                    function_response = types.Part.from_function_response(
                                        name=tool_name,
                                        response={"result": str(result_data)}
                                    )
                                    function_responses.append(function_response)
                                    executed = True
                                    
                                except Exception as exec_error:
                                    print(f"DEBUG: ❌ Tool execution error: {exec_error}", flush=True)
                                    # Still create a response indicating failure
                                    function_response = types.Part.from_function_response(
                                        name=tool_name,
                                        response={"error": str(exec_error)}
                                    )
                                    function_responses.append(function_response)
                                    executed = True  # Still need to send response back
                                    
                    except Exception as tool_error:
                        print(f"DEBUG: ❌ Tool Execution Failed: {tool_error}", flush=True)
                        import traceback
                        traceback.print_exc()
                        break

                    if executed and function_responses:
                        if has_write_action:
                            write_action_executed = True
                            action_performed = "Action Executed"
                        
                        # Send tool outputs back to Gemini
                        response = chat.send_message(function_responses)
                        
                    else:
                        break
                elif should_intercept:
                    # We intercepted, stop the loop
                    print("DEBUG: Write action intercepted for confirmation, returning")
                    return
                else:
                    # No function call found, break the loop
                    print("DEBUG: No function call in response, breaking loop")
                    break
            
            # Ensure action_performed is set if a write action was executed in any iteration
            if write_action_executed:
                action_performed = "Action Executed"

            # YIELD FINAL MESSAGE EVENT
            final_text = response.text if hasattr(response, 'text') else str(response)
            yield {
                "type": "message",
                "content": final_text,
                "action_performed": action_performed
            }

        except Exception as e:
            print(f"Error in agent execution: {e}")
            yield {
                "type": "message",
                "content": f"An error occurred: {str(e)}",
                "action_performed": None
            }
