import json
import os
import re
from typing import Dict, Any, List, Optional
from dotenv import load_dotenv
from google import genai
from google.genai import types
from google.genai import errors as genai_errors

# New Composio SDK imports
from composio import Composio
from composio.exceptions import EnumMetadataNotFound
from composio_google import GoogleProvider

load_dotenv()

class AgentService:
    LINEAR_ACTION_SLUGS = [
        "LINEAR_CREATE_LINEAR_ISSUE",
        "LINEAR_CREATE_LINEAR_ISSUE_DETAILS",
        "LINEAR_CREATE_LINEAR_LABEL",
        "LINEAR_CREATE_LINEAR_PROJECT",
        "LINEAR_DELETE_LINEAR_ISSUE",
        "LINEAR_GET_ALL_LINEAR_TEAMS",
        "LINEAR_GET_ATTACHMENTS",
        "LINEAR_GET_CURRENT_USER",
        "LINEAR_GET_CYCLES_BY_TEAM_ID",
        "LINEAR_GET_LINEAR_ISSUE",
        "LINEAR_LIST_ISSUE_DRAFTS",
        "LINEAR_LIST_LINEAR_CYCLES",
        "LINEAR_LIST_LINEAR_ISSUES",
        "LINEAR_LIST_LINEAR_LABELS",
        "LINEAR_LIST_LINEAR_PROJECTS",
        "LINEAR_LIST_LINEAR_STATES",
        "LINEAR_LIST_LINEAR_TEAMS",
        "LINEAR_LIST_LINEAR_USERS",
        "LINEAR_MANAGE_DRAFT",
        "LINEAR_REMOVE_ISSUE_LABEL",
        "LINEAR_REMOVE_REACTION",
        "LINEAR_RUN_QUERY_OR_MUTATION",
        "LINEAR_UPDATE_ISSUE",
        "LINEAR_UPDATE_LINEAR_ISSUE",
        "LINEAR_CREATE_A_COMMENT",
        "LINEAR_GET_COMMENTS",
    ]
    
    def __init__(self):
        self.api_key = os.getenv("GOOGLE_API_KEY")
        if not self.api_key:
            raise ValueError("GOOGLE_API_KEY environment variable is required")
        self.client = genai.Client(api_key=self.api_key)
        
        # Initialize Composio with the GoogleProvider (correct provider for google-genai SDK)
        try:
            self.composio = Composio(
                provider=GoogleProvider(),
                api_key=os.getenv("COMPOSIO_API_KEY")
            )
            print("DEBUG: Composio initialized successfully with GoogleProvider")
        except Exception as exc:
            raise RuntimeError(
                f"Failed to initialize Composio SDK: {exc}"
            ) from exc

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
            query = tool_args.get("query_or_mutation", "").strip().lower()
            if query.startswith("mutation"):
                print(f"DEBUG: Detected WRITE action (mutation): {tool_name}")
                return True
        
        print(f"DEBUG: Detected READ action: {tool_name}")
        return False

    def _linear_action_slugs(self) -> List[str]:
        return self.LINEAR_ACTION_SLUGS

    def _fetch_composio_tools(self, user_id: str, slugs: List[str]):
        """
        Fetch Composio tools for the given user and action slugs.
        Uses the new SDK: composio.tools.get(user_id, tools=[...])
        """
        return self.composio.tools.get(user_id=user_id, tools=slugs)

    def _execute_composio_action(
        self,
        action_slug: str,
        arguments: Dict[str, Any],
        user_id: str,
    ) -> Dict[str, Any]:
        """
        Execute a Composio action directly.
        Uses the new SDK: composio.tools.execute(slug, arguments, user_id)
        """
        result = self.composio.tools.execute(
            slug=action_slug,
            arguments=arguments,
            user_id=user_id,
        )
        # Convert result to dict format expected by the rest of the code
        if hasattr(result, 'data'):
            return {"data": result.data, "successful": result.successful}
        return {"data": result, "successful": True}

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

    def _execute_linear_query(self, user_id: str, query: str) -> Optional[Dict[str, Any]]:
        """
        Helper to execute a Linear GraphQL query via Composio and return the parsed data section.
        """
        try:
            result = self._execute_composio_action(
                action_slug="LINEAR_RUN_QUERY_OR_MUTATION",
                arguments={
                    "query_or_mutation": query,
                    "variables": {},
                },
                user_id=user_id,
            )
        except Exception as e:
            print(f"DEBUG: Failed to execute Linear query: {e}")
            return None

        data = result.get("data")
        if data is None:
            return None

        if isinstance(data, str):
            try:
                data = json.loads(data)
            except json.JSONDecodeError:
                print("DEBUG: Failed to parse Linear query string response as JSON.")
                return None

        if isinstance(data, dict) and "data" in data:
            return data["data"]

        return data if isinstance(data, dict) else None

    def _enrich_proposal_with_names(self, user_id: str, args: Dict[str, Any]) -> Dict[str, Any]:
        """
        Enriches proposal args with human-readable names for IDs.
        Fetches team and state names when IDs are present using GraphQL queries.
        """
        enriched_args = args.copy()
        
        try:
            # Enrich team name if team_id is present
            team_id = args.get("team_id") or args.get("teamId")
            if team_id and isinstance(team_id, str) and "teamName" not in enriched_args:
                try:
                    query = f"""
                    {{
                      team(id: "{team_id}") {{
                        id
                        name
                      }}
                    }}
                    """
                    data = self._execute_linear_query(user_id, query)
                    team_data = None
                    if data and isinstance(data, dict):
                        team_data = data.get("team") or data.get("teams")

                    if isinstance(team_data, dict) and "name" in team_data:
                        enriched_args["teamName"] = team_data["name"]
                        print(f"DEBUG: Enriched team name: {team_data['name']}")
                    elif isinstance(team_data, list) and team_data:
                        team = team_data[0]
                        if isinstance(team, dict) and "name" in team:
                            enriched_args["teamName"] = team["name"]
                            print(f"DEBUG: Enriched team name: {team['name']}")
                            
                except Exception as e:
                    print(f"DEBUG: Failed to enrich team name: {e}")

            # Enrich state name if state_id is present
            state_id = (
                args.get("state_id")
                or args.get("stateId")
                or args.get("status")
            )
            if state_id and isinstance(state_id, str) and "stateName" not in enriched_args:
                try:
                    state_query = f"""
                    {{
                      workflowState(id: "{state_id}") {{
                        id
                        name
                      }}
                    }}
                    """
                    data = self._execute_linear_query(user_id, state_query)
                    workflow_state = None
                    if data and isinstance(data, dict):
                        workflow_state = (
                            data.get("workflowState")
                            or data.get("state")
                        )

                    if isinstance(workflow_state, dict) and "name" in workflow_state:
                        enriched_args["stateName"] = workflow_state["name"]
                        print(f"DEBUG: Enriched state name: {workflow_state['name']}")
                except Exception as e:
                    print(f"DEBUG: Failed to enrich state name: {e}")
                    
        except Exception as e:
            print(f"DEBUG: Error enriching proposal: {e}")
        
        return enriched_args

    def _extract_missing_action_slug(self, error_message: str) -> Optional[str]:
        """
        Parse the missing action slug from EnumMetadataNotFound messages.
        """
        match = re.search(r"`([A-Z0-9_]+)`", error_message)
        return match.group(1) if match else None

    def _load_linear_tools(self, user_id: str) -> List[Any]:
        """
        Attempt to load the curated list of Linear tools for a user, skipping deprecated ones.
        """
        remaining = self._linear_action_slugs()
        skipped: List[str] = []

        while remaining:
            try:
                tools = self._fetch_composio_tools(
                    user_id=user_id,
                    slugs=remaining,
                )
                if skipped:
                    print(f"DEBUG: Skipped deprecated Linear actions: {skipped}")
                return tools
            except EnumMetadataNotFound as enum_error:
                missing_slug = self._extract_missing_action_slug(str(enum_error))
                if missing_slug:
                    if missing_slug in remaining:
                        print(
                            f"DEBUG: Linear action {missing_slug} is unavailable in Composio. Skipping."
                        )
                        remaining = [slug for slug in remaining if slug != missing_slug]
                        skipped.append(missing_slug)
                        continue
                raise
            except Exception as e:
                # Handle other exceptions that might indicate missing tools
                error_str = str(e)
                if "not found" in error_str.lower() or "does not exist" in error_str.lower():
                    # Try to extract the problematic tool
                    for slug in remaining:
                        if slug.lower() in error_str.lower():
                            print(f"DEBUG: Tool {slug} not found. Skipping.")
                            remaining = [s for s in remaining if s != slug]
                            skipped.append(slug)
                            break
                    else:
                        raise
                else:
                    raise

        missing_list = ", ".join(skipped) if skipped else "unknown"
        raise RuntimeError(
            f"Unable to load any Linear tools from Composio. Missing actions: {missing_list}"
        )

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
            composio_tools = self._load_linear_tools(user_id=user_id)
            
            print(f"DEBUG: Loaded {len(composio_tools) if composio_tools else 0} tools for user {user_id}")

        except RuntimeError as e:
            print(f"DEBUG: RuntimeError fetching tools: {e}")
            yield {
                "type": "message",
                "content": f"Error fetching tools: {str(e)}. Please ensure you are connected to Linear.",
                "action_performed": None
            }
            return
        except Exception as e:
            print(f"DEBUG: Exception fetching tools: {e}")
            import traceback
            traceback.print_exc()
            yield {
                "type": "message",
                "content": f"Error fetching tools: {str(e)}. Please ensure you are connected to Linear.",
                "action_performed": None
            }
            return

        # 2. Convert tools to google-genai format
        # The GoogleProvider returns FunctionDeclaration objects from vertexai SDK
        # We need to convert them to google.genai.types format
        def clean_schema(obj, is_property_definition=False):
            """Remove unsupported fields from JSON schema for Gemini API"""
            if isinstance(obj, dict):
                # Metadata fields that should be removed from property type definitions
                # but NOT from the properties dict itself (where they are property names)
                metadata_fields = {'additional_properties', 'additionalProperties', 'default', '$schema', 'nullable'}
                # 'title' is only a metadata field inside property definitions, not a property name
                if is_property_definition:
                    metadata_fields.add('title')
                
                cleaned = {}
                
                # First pass: collect property names
                raw_properties = obj.get('properties', {})
                
                for key, value in obj.items():
                    # Skip metadata fields
                    if key in metadata_fields:
                        continue
                    
                    # Special handling for 'required' array - filter to only existing properties
                    if key == 'required' and isinstance(value, list):
                        valid_required = [r for r in value if r in raw_properties]
                        if valid_required:
                            cleaned[key] = valid_required
                        # Skip 'required' if empty or no valid fields
                    # Convert type strings to lowercase for Gemini compatibility
                    elif key == 'type' and isinstance(value, str):
                        cleaned[key] = value.lower()
                    # 'properties' contains property definitions - values should be cleaned as definitions
                    elif key == 'properties' and isinstance(value, dict):
                        cleaned_props = {}
                        for prop_name, prop_def in value.items():
                            cleaned_props[prop_name] = clean_schema(prop_def, is_property_definition=True)
                        cleaned[key] = cleaned_props
                    # 'items' for array types is also a property definition
                    elif key == 'items':
                        cleaned[key] = clean_schema(value, is_property_definition=True)
                    else:
                        cleaned[key] = clean_schema(value, is_property_definition=False)
                
                return cleaned
            elif isinstance(obj, list):
                return [clean_schema(item, is_property_definition) for item in obj]
            else:
                return obj
        
        gemini_tools = []
        function_declarations = []
        
        for tool in composio_tools:
            try:
                # Check if it's a FunctionDeclaration from vertexai
                if hasattr(tool, 'to_dict'):
                    # Convert to dict and then to google-genai format
                    tool_dict = tool.to_dict()
                    tool_name = tool_dict.get('name', 'unknown')
                    
                    # Clean the parameters to remove unsupported fields
                    raw_params = tool_dict.get('parameters', {})
                    params = clean_schema(raw_params)
                    
                    # Create a FunctionDeclaration in google-genai format
                    func_decl = types.FunctionDeclaration(
                        name=tool_name,
                        description=tool_dict.get('description', ''),
                        parameters=params
                    )
                    function_declarations.append(func_decl)
                elif hasattr(tool, 'function_declarations'):
                    # Already in Tool format, extract function declarations
                    for fd in tool.function_declarations:
                        function_declarations.append(fd)
            except Exception as tool_error:
                print(f"DEBUG: Failed to convert tool: {tool_error}", flush=True)
                continue
        
        # Combine all function declarations into a single Tool
        if function_declarations:
            gemini_tools = [types.Tool(function_declarations=function_declarations)]
        
        print(f"DEBUG: Passing {len(function_declarations)} function declarations to Gemini config", flush=True)

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
                                    
                                    # Enrich proposal with human-readable names
                                    enriched_args = self._enrich_proposal_with_names(user_id, args)
                                    
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
                                    "tool": "Linear", 
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
                                    result = self.composio.tools.execute(
                                        slug=tool_name,
                                        arguments=tool_args,
                                        user_id=user_id,
                                        dangerously_skip_version_check=True
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
                            action_performed = "Linear Action Executed"
                        
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
                action_performed = "Linear Action Executed"

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
