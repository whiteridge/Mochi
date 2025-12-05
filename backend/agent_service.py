import os
import json
from typing import Dict, List, Optional
from dotenv import load_dotenv
from google import genai
from google.genai import types

from services.composio_service import ComposioService
from services.linear_service import LinearService
from services.slack_service import SlackService
from utils.tool_converter import convert_to_gemini_tools
from utils.chat_utils import format_history

load_dotenv()


# --- Early Summary Helpers (no LLM call) ---

def map_tool_to_app(tool_name: str) -> str:
    """Map a tool name to its app identifier.
    
    Examples:
        LINEAR_CREATE_ISSUE -> "linear"
        SLACK_SEND_MESSAGE -> "slack"
    """
    name_upper = tool_name.upper()
    if name_upper.startswith("LINEAR_"):
        return "linear"
    if name_upper.startswith("SLACK_"):
        return "slack"
    if name_upper.startswith("GITHUB_"):
        return "github"
    if name_upper.startswith("NOTION_"):
        return "notion"
    # Fallback: extract first word before underscore
    parts = tool_name.split("_")
    return parts[0].lower() if parts else tool_name.lower()


def make_early_summary(app_id: str) -> str:
    """Generate a deterministic early summary for the given app.
    
    This is called as soon as the first tool call is detected, BEFORE
    any tool is executed. No LLM call is made.
    """
    templates = {
        "linear": "I'll search Linear to help with your request.",
        "slack": "I'll read Slack to help with your request.",
        "github": "I'll check GitHub to help with your request.",
        "notion": "I'll look in Notion to help with your request.",
    }
    return templates.get(app_id, f"I'll look in {app_id.capitalize()} to help with your request.")


def detect_apps_from_input(user_input: str) -> List[str]:
    """Pre-detect which apps are likely involved based on user input keywords.
    
    This allows us to emit tool_status for all apps upfront, before Gemini
    even starts processing, so pills appear side-by-side immediately.
    """
    user_lower = user_input.lower()
    detected = []
    
    # Linear keywords
    linear_keywords = ["linear", "issue", "ticket", "bug", "task", "file it", "file a", "urgent"]
    if any(kw in user_lower for kw in linear_keywords):
        detected.append("linear")
    
    # Slack keywords  
    slack_keywords = ["slack", "message", "channel", "notify", "confirm with", "tell", "send to", "billing team", "team on slack"]
    if any(kw in user_lower for kw in slack_keywords):
        detected.append("slack")
    
    # GitHub keywords
    github_keywords = ["github", "repo", "repository", "pr", "pull request", "commit"]
    if any(kw in user_lower for kw in github_keywords):
        detected.append("github")
    
    # Notion keywords
    notion_keywords = ["notion", "page", "database", "doc"]
    if any(kw in user_lower for kw in notion_keywords):
        detected.append("notion")
    
    return detected


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

    def run_agent(self, user_input: str, user_id: str, chat_history: List[Dict[str, str]] = [], confirmed_tool: Dict = None):
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
            # Track pending actions to control sequencing (one read at a time)
            pending_read_actions: List[tuple] = []
            pending_write_actions: List[tuple] = []
            # Track last app that emitted a searching status (for cleanup)
            last_searching_app_id: Optional[str] = None
            # Track apps that have already completed a confirmed write to avoid re-proposing
            completed_write_apps: set[str] = set()
            # Track whether reads have completed (done/error) to gate next app
            app_read_status: Dict[str, str] = {}
            # Track apps currently executing a confirmed write (keeps pill expanded)
            app_write_executing: set[str] = set()
            # Track executed/queued writes to prevent duplicate proposals across iterations/confirmations
            executed_write_keys = set()
            
            # Early summary tracking (for fast first message)
            early_summary_sent = False
            early_summary_text = None
            
            # MULTI-APP SUPPORT: Track involved apps and queue proposals
            involved_apps = []  # List of app_ids found
            proposal_queue = []  # Queue of proposal dicts
            
            # PRE-DETECT APPS: Scan user input to prepare combined summary for multi-app requests
            # NOTE: We don't emit tool_status here - pills appear sequentially from actual Gemini tool calls
            pre_detected_apps = []
            if not confirmed_tool:  # Only on initial request, not confirmations
                pre_detected_apps = detect_apps_from_input(user_input)
                if len(pre_detected_apps) > 1:
                    print(f"DEBUG: Pre-detected multiple apps from user input: {pre_detected_apps}")
                    involved_apps = pre_detected_apps.copy()
                    
                    # Generate a COMBINED summary for multi-app scenarios
                    # e.g., "I'll create a ticket in Linear and notify the team on Slack."
                    app_actions = []
                    for app in pre_detected_apps:
                        if app == "linear":
                            app_actions.append("create a ticket in Linear")
                        elif app == "slack":
                            app_actions.append("notify the team on Slack")
                        elif app == "github":
                            app_actions.append("check GitHub")
                        elif app == "notion":
                            app_actions.append("look in Notion")
                    
                    if len(app_actions) >= 2:
                        early_summary_text = f"I'll {app_actions[0]} and {app_actions[1]}."
                    else:
                        early_summary_text = f"I'll {' and '.join(app_actions)}."
                    
                    yield {
                        "type": "early_summary",
                        "content": early_summary_text,
                        "app_id": pre_detected_apps[0],
                        "involved_apps": involved_apps
                    }
                    early_summary_sent = True
                    print(f"DEBUG: Emitted combined early summary for {pre_detected_apps}")
            
            # CONFIRMED TOOL EXECUTION: Execute the specific confirmed action first
            if confirmed_tool:
                tool_name = confirmed_tool.get("tool")
                tool_args = confirmed_tool.get("args", {})
                app_id = confirmed_tool.get("app_id", map_tool_to_app(tool_name))
                
                print(f"DEBUG: Executing CONFIRMED action: {tool_name}")
                involved_apps.append(app_id)
                # Record this write as already executed to avoid re-proposing it
                executed_key = (tool_name, json.dumps(tool_args, sort_keys=True))
                executed_write_keys.add(executed_key)
                completed_write_apps.add(app_id)
                app_write_executing.add(app_id)
                
                # Emit early summary for feedback
                early_summary_text = make_early_summary(app_id)
                yield {
                    "type": "early_summary",
                    "content": f"Executing your confirmed {app_id.capitalize()} action...",
                    "app_id": app_id,
                    "involved_apps": involved_apps
                }
                early_summary_sent = True
                
                try:
                    result = self.composio_service.execute_tool(
                        slug=tool_name,
                        arguments=tool_args,
                        user_id=user_id
                    )
                    print(f"DEBUG: Confirmed tool result: {result}", flush=True)
                    
                    if hasattr(result, 'data'):
                        result_data = result.data
                    else:
                        result_data = result
                    
                    write_action_executed = True
                    action_performed = f"{app_id.capitalize()} action executed"
                    app_write_executing.discard(app_id)
                    app_read_status[app_id] = "done"
                    
                    # Feed result back to Gemini to continue the conversation
                    function_response = types.Part.from_function_response(
                        name=tool_name,
                        response={"result": str(result_data)}
                    )
                    response = chat.send_message([function_response])
                    
                except Exception as exec_error:
                    print(f"DEBUG: ❌ Confirmed tool execution error: {exec_error}", flush=True)
                    app_write_executing.discard(app_id)
                    app_read_status[app_id] = "error"
                    yield {
                        "type": "message",
                        "content": f"Error executing {app_id.capitalize()} action: {str(exec_error)}",
                        "action_performed": None
                    }
                    return
            
            for iteration in range(max_iterations):
                
                # Track actions in this iteration
                read_actions_to_execute = pending_read_actions  # (tool_name, args, part, app_id)
                pending_read_actions = []
                write_actions_found = []  # (tool_name, args, app_id, is_linear_write, is_slack_write)
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
                            
                            # Track app involvement for multi-app display
                            app_id = map_tool_to_app(tool_name)
                            is_new_app = app_id not in involved_apps
                            if is_new_app:
                                involved_apps.append(app_id)
                            
                            # EARLY SUMMARY: Emit immediately on first tool call
                            if not early_summary_sent:
                                early_summary_text = make_early_summary(app_id)
                                print(f"DEBUG: Emitting early summary for {app_id}: {early_summary_text}")
                                yield {
                                    "type": "early_summary",
                                    "content": early_summary_text,
                                    "app_id": app_id,
                                    "involved_apps": involved_apps
                                }
                                early_summary_sent = True
                            
                            # Check if this is a write action
                            is_linear_write = self.linear_service.is_write_action(tool_name, args)
                            is_slack_write = self.slack_service.is_write_action(tool_name, args)
                            is_write = is_linear_write or is_slack_write
                            executed_key = (tool_name, json.dumps(args, sort_keys=True))
                            
                            if is_write:
                                # Skip already executed/queued writes
                                if executed_key in executed_write_keys:
                                    print(f"DEBUG: Skipping duplicate write proposal for {tool_name}")
                                    continue
                                # Skip writes for apps that already completed a confirmed write
                                if app_id in completed_write_apps:
                                    print(f"DEBUG: Skipping write for completed app {app_id}")
                                    continue
                                # Gate Slack writes until Linear read AND write are complete
                                if app_id == "slack":
                                    linear_state = app_read_status.get("linear")
                                    if linear_state not in ("done", "error") or ("linear" in app_write_executing):
                                        print("DEBUG: Gating Slack write until Linear read+write complete")
                                        continue
                                # Always queue writes for confirmation - we use confirmed_tool for execution
                                print(f"DEBUG: Queueing {tool_name} for confirmation")
                                write_actions_found.append((tool_name, args, app_id, is_linear_write, is_slack_write))
                                executed_write_keys.add(executed_key)
                            else:
                                # Read action - queue for execution (process one per iteration for sequential pills)
                                # Gate Slack read until Linear read+write complete or not involved
                                if app_id == "slack":
                                    linear_state = app_read_status.get("linear")
                                    if (linear_state not in ("done", "error") or ("linear" in app_write_executing)) and "linear" in involved_apps:
                                        print("DEBUG: Gating Slack read until Linear read+write complete")
                                        continue
                                read_actions_to_execute.append((tool_name, args, part, app_id))
                
                # Log if no function call was found
                if not found_function_call and iteration == 0:
                    print("DEBUG: Gemini responded with text only (no function calls)", flush=True)

                # Carry forward any writes we detected alongside reads
                if write_actions_found:
                    pending_write_actions.extend(write_actions_found)

                # Execute only ONE READ action per loop to enforce sequential pill display
                if read_actions_to_execute:
                    tool_name, tool_args, part, app_id = read_actions_to_execute[0]

                    # Re-queue remaining reads for subsequent iterations
                    if len(read_actions_to_execute) > 1:
                        pending_read_actions.extend(read_actions_to_execute[1:])

                    # Emit tool_status before execution (one per iteration)
                    yield {
                        "type": "tool_status",
                        "tool": tool_name, 
                        "status": "searching",
                        "app_id": app_id,
                        "involved_apps": involved_apps
                    }
                    last_searching_app_id = app_id
                    
                    print(f"DEBUG: Executing READ: {tool_name}", flush=True)
                    
                    try:
                        result = self.composio_service.execute_tool(
                            slug=tool_name,
                            arguments=tool_args,
                            user_id=user_id
                        )
                        print(f"DEBUG: Tool execution result: {result}", flush=True)
                        
                        if hasattr(result, 'data'):
                            result_data = result.data
                            result_success = getattr(result, "successful", True)
                        else:
                            result_data = result
                            result_success = bool(getattr(result, "successful", True))
                        
                        function_response = types.Part.from_function_response(
                            name=tool_name,
                            response={"result": str(result_data)}
                        )
                        status_after_read = "done" if result_success else "error"
                        
                    except Exception as exec_error:
                        print(f"DEBUG: ❌ Tool execution error: {exec_error}", flush=True)
                        function_response = types.Part.from_function_response(
                            name=tool_name,
                            response={"error": str(exec_error)}
                        )
                        status_after_read = "error"
                    
                    # Send single read result back; remaining reads will run in later iterations
                    response = chat.send_message([function_response])
                    
                    # Emit completion/error status to allow UI transitions and next app
                    app_read_status[app_id] = status_after_read
                    yield {
                        "type": "tool_status",
                        "tool": tool_name,
                        "status": status_after_read,
                        "app_id": app_id,
                        "involved_apps": involved_apps
                    }
                    continue
                
                # If we have write actions queued and no more reads pending, emit proposals
                if pending_write_actions and not read_actions_to_execute and not pending_read_actions:
                    print(f"DEBUG: Emitting {len(pending_write_actions)} queued proposal(s)")
                    
                    for tool_name, args, app_id, is_linear_write, is_slack_write in pending_write_actions:
                        # Enrich proposal with human-readable names
                        enriched_args = args
                        if is_linear_write:
                            enriched_args = self.linear_service.enrich_proposal(user_id, args, tool_name)
                        elif is_slack_write:
                            enriched_args = self.slack_service.enrich_proposal(user_id, args, tool_name)
                        
                        proposal_queue.append({
                            "tool": tool_name,
                            "args": enriched_args,
                            "app_id": app_id,
                            "summary_text": make_early_summary(app_id)
                        })
                    
                    pending_write_actions = []
                    break
                elif not found_function_call:
                    # If no new function call and nothing pending, send a cleanup status for last app
                    if last_searching_app_id:
                        yield {
                            "type": "tool_status",
                            "tool": "noop",
                            "status": "done",
                            "app_id": last_searching_app_id,
                            "involved_apps": involved_apps
                        }
                    print("DEBUG: No function call in response, breaking loop")
                    break
                elif not read_actions_to_execute and not pending_write_actions and not pending_read_actions:
                    print("DEBUG: No actions to process, breaking loop")
                    break
            
            # MULTI-APP: Emit queued proposals with index/total for progress tracking
            if proposal_queue:
                total_proposals = len(proposal_queue)
                print(f"DEBUG: Emitting {total_proposals} queued proposal(s)")
                
                # Emit multi_app_status to show all involved apps in UI
                yield {
                    "type": "multi_app_status",
                    "apps": [{"app_id": app, "state": "waiting"} for app in involved_apps],
                    "active_app": proposal_queue[0]["app_id"]
                }
                
                # Emit first proposal with queue metadata
                first_proposal = proposal_queue[0]
                yield {
                    "type": "proposal",
                    "tool": first_proposal["tool"],
                    "content": first_proposal["args"],
                    "summary_text": first_proposal["summary_text"],
                    "app_id": first_proposal["app_id"],
                    "proposal_index": 0,
                    "total_proposals": total_proposals,
                    "remaining_proposals": [
                        {"tool": p["tool"], "app_id": p["app_id"], "args": p["args"]} 
                        for p in proposal_queue[1:]
                    ]
                }
                return
            
            if write_action_executed:
                action_performed = "Action Executed"

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
