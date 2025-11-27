"""Linear-specific service for actions, queries, and enrichment."""

import json
import re
from typing import Dict, Any, List, Optional
from composio.exceptions import EnumMetadataNotFound
from .composio_service import ComposioService


class LinearService:
    """Service for Linear-specific operations."""
    
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
    
    def __init__(self, composio_service: ComposioService):
        """
        Initialize LinearService with a ComposioService instance.
        
        Args:
            composio_service: The ComposioService instance to use for execution
        """
        self.composio_service = composio_service
    
    def is_write_action(self, tool_name: str, tool_args: dict) -> bool:
        """
        Detect if a tool represents a Write action that requires user confirmation.
        Composio tool names are UPPERCASE (e.g., LINEAR_CREATE_LINEAR_ISSUE),
        so we need case-insensitive matching.
        
        Args:
            tool_name: The name of the tool
            tool_args: The arguments for the tool
            
        Returns:
            True if this is a write action, False otherwise
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
    
    def _extract_missing_action_slug(self, error_message: str) -> Optional[str]:
        """
        Parse the missing action slug from EnumMetadataNotFound messages.
        
        Args:
            error_message: The error message to parse
            
        Returns:
            The extracted slug or None if not found
        """
        match = re.search(r"`([A-Z0-9_]+)`", error_message)
        return match.group(1) if match else None
    
    def load_tools(self, user_id: str) -> List[Any]:
        """
        Attempt to load the curated list of Linear tools for a user, skipping deprecated ones.
        
        Args:
            user_id: The user ID to load tools for
            
        Returns:
            List of tool objects
            
        Raises:
            RuntimeError: If no tools could be loaded
        """
        remaining = self.LINEAR_ACTION_SLUGS.copy()
        skipped: List[str] = []

        while remaining:
            try:
                tools = self.composio_service.fetch_tools(
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
    
    def execute_query(self, user_id: str, query: str) -> Optional[Dict[str, Any]]:
        """
        Execute a Linear GraphQL query via Composio and return the parsed data section.
        
        Args:
            user_id: The user ID executing the query
            query: The GraphQL query string
            
        Returns:
            The parsed data section from the query result, or None on error
        """
        try:
            result = self.composio_service.execute_action(
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
    
    def enrich_proposal(self, user_id: str, args: Dict[str, Any], tool_name: str = "") -> Dict[str, Any]:
        """
        Enriches proposal args with human-readable names for IDs.
        Fetches team and state names when IDs are present using GraphQL queries.
        For UPDATE actions, also fetches the original issue details to display.
        
        Args:
            user_id: The user ID for executing queries
            args: The original arguments dictionary
            tool_name: The name of the tool being called
            
        Returns:
            Enriched arguments dictionary with human-readable names added
        """
        enriched_args = args.copy()
        
        try:
            # For UPDATE operations, fetch the original issue details
            is_update = "update" in tool_name.lower()
            issue_id = args.get("issue_id") or args.get("issueId") or args.get("id")
            
            if is_update and issue_id and isinstance(issue_id, str):
                try:
                    issue_query = f"""
                    {{
                      issue(id: "{issue_id}") {{
                        id
                        title
                        description
                        priority
                        team {{
                          id
                          name
                        }}
                        project {{
                          id
                          name
                        }}
                        assignee {{
                          id
                          name
                        }}
                        state {{
                          id
                          name
                        }}
                      }}
                    }}
                    """
                    data = self.execute_query(user_id, issue_query)
                    issue_data = None
                    if data and isinstance(data, dict):
                        issue_data = data.get("issue")
                    
                    if isinstance(issue_data, dict):
                        # Copy original issue data if not being updated
                        if "title" not in enriched_args and issue_data.get("title"):
                            enriched_args["title"] = issue_data["title"]
                            print(f"DEBUG: Enriched from issue - title: {issue_data['title']}")
                        
                        if "description" not in enriched_args and issue_data.get("description"):
                            enriched_args["description"] = issue_data["description"]
                        
                        # Team info
                        team_info = issue_data.get("team")
                        if isinstance(team_info, dict):
                            if "teamName" not in enriched_args and team_info.get("name"):
                                enriched_args["teamName"] = team_info["name"]
                                print(f"DEBUG: Enriched from issue - teamName: {team_info['name']}")
                            if "team_id" not in enriched_args and "teamId" not in enriched_args:
                                enriched_args["teamId"] = team_info.get("id")
                        
                        # Project info
                        project_info = issue_data.get("project")
                        if isinstance(project_info, dict):
                            if "projectName" not in enriched_args and project_info.get("name"):
                                enriched_args["projectName"] = project_info["name"]
                                print(f"DEBUG: Enriched from issue - projectName: {project_info['name']}")
                        
                        # Assignee info
                        assignee_info = issue_data.get("assignee")
                        if isinstance(assignee_info, dict):
                            if "assigneeName" not in enriched_args and assignee_info.get("name"):
                                enriched_args["assigneeName"] = assignee_info["name"]
                                print(f"DEBUG: Enriched from issue - assigneeName: {assignee_info['name']}")
                        
                        # State info - use original if not being updated
                        state_info = issue_data.get("state")
                        if isinstance(state_info, dict):
                            # Only use original state if we're not updating the state
                            if not any(k in args for k in ["state_id", "stateId", "status"]):
                                if "stateName" not in enriched_args and state_info.get("name"):
                                    enriched_args["stateName"] = state_info["name"]
                                    print(f"DEBUG: Enriched from issue - stateName: {state_info['name']}")
                        
                        # Priority - map to human readable
                        # Only use original priority if we're not updating it
                        if "priority" not in args and issue_data.get("priority") is not None:
                            enriched_args["priority"] = issue_data.get("priority")
                            
                except Exception as e:
                    print(f"DEBUG: Failed to fetch issue details: {e}")
            
            # Enrich team name if team_id is present (and not already set)
            # Check multiple possible field names for team ID
            team_id = (
                args.get("team_id") 
                or args.get("teamId") 
                or args.get("team")  # Some actions use just "team" for the ID
            )
            print(f"DEBUG: Looking for team ID in args: {list(args.keys())}, found: {team_id}")
            
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
                    print(f"DEBUG: Executing team query for ID: {team_id}")
                    data = self.execute_query(user_id, query)
                    print(f"DEBUG: Team query result: {data}")
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
                    else:
                        print(f"DEBUG: Could not extract team name from data: {team_data}")
                            
                except Exception as e:
                    print(f"DEBUG: Failed to enrich team name: {e}")
                    import traceback
                    traceback.print_exc()

            # Enrich state name if state_id is present (and not already set)
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
                    data = self.execute_query(user_id, state_query)
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
            
            # Enrich project name if project_id is present (and not already set)
            project_id = (
                args.get("project_id") 
                or args.get("projectId") 
                or args.get("project")
            )
            if project_id and isinstance(project_id, str) and "projectName" not in enriched_args:
                try:
                    project_query = f"""
                    {{
                      project(id: "{project_id}") {{
                        id
                        name
                      }}
                    }}
                    """
                    print(f"DEBUG: Executing project query for ID: {project_id}")
                    data = self.execute_query(user_id, project_query)
                    project_data = None
                    if data and isinstance(data, dict):
                        project_data = data.get("project")

                    if isinstance(project_data, dict) and "name" in project_data:
                        enriched_args["projectName"] = project_data["name"]
                        print(f"DEBUG: Enriched project name: {project_data['name']}")
                except Exception as e:
                    print(f"DEBUG: Failed to enrich project name: {e}")
            
            # Enrich assignee name if assignee_id is present (and not already set)
            assignee_id = (
                args.get("assignee_id") 
                or args.get("assigneeId") 
                or args.get("assignee")
            )
            if assignee_id and isinstance(assignee_id, str) and "assigneeName" not in enriched_args:
                try:
                    assignee_query = f"""
                    {{
                      user(id: "{assignee_id}") {{
                        id
                        name
                      }}
                    }}
                    """
                    print(f"DEBUG: Executing assignee query for ID: {assignee_id}")
                    data = self.execute_query(user_id, assignee_query)
                    user_data = None
                    if data and isinstance(data, dict):
                        user_data = data.get("user")

                    if isinstance(user_data, dict) and "name" in user_data:
                        enriched_args["assigneeName"] = user_data["name"]
                        print(f"DEBUG: Enriched assignee name: {user_data['name']}")
                except Exception as e:
                    print(f"DEBUG: Failed to enrich assignee name: {e}")
            
            # Enrich priority to human-readable name
            priority_value = enriched_args.get("priority")
            if priority_value is not None and "priorityName" not in enriched_args:
                priority_map = {0: "No Priority", 1: "Urgent", 2: "High", 3: "Medium", 4: "Low"}
                if isinstance(priority_value, int) and priority_value in priority_map:
                    enriched_args["priorityName"] = priority_map[priority_value]
                    print(f"DEBUG: Enriched priorityName: {priority_map[priority_value]}")
                    
        except Exception as e:
            print(f"DEBUG: Error enriching proposal: {e}")
        
        return enriched_args

