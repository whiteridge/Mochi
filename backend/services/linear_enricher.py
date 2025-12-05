"""Helper class to enrich Linear proposals with human-readable metadata."""

from typing import Any, Dict, Optional


class LinearEnricher:
    """Provides cached lookups for Linear entities to enrich proposals."""

    def __init__(self, linear_service: "LinearService"):
        self.linear_service = linear_service
        self._cache: Dict[str, Any] = {}

    def enrich(self, user_id: str, args: Dict[str, Any], tool_name: str = "") -> Dict[str, Any]:
        enriched_args = args.copy()

        try:
            self._enrich_from_issue_if_update(user_id, tool_name, enriched_args, args)
            self._enrich_team(user_id, enriched_args, args)
            self._enrich_state(user_id, enriched_args, args)
            self._enrich_project(user_id, enriched_args, args)
            self._enrich_assignee(user_id, enriched_args, args)
            self._enrich_priority(enriched_args)
        except Exception as exc:  # noqa: BLE001 - best-effort enrichment
            print(f"DEBUG: Error enriching proposal: {exc}")

        return enriched_args

    # --- Core enrichment helpers ---

    def _enrich_from_issue_if_update(
        self, user_id: str, tool_name: str, enriched_args: Dict[str, Any], args: Dict[str, Any]
    ) -> None:
        is_update = "update" in tool_name.lower()
        issue_id = args.get("issue_id") or args.get("issueId") or args.get("id")

        if not (is_update and issue_id and isinstance(issue_id, str)):
            return

        issue_data = self._fetch_issue(user_id, issue_id)
        if not isinstance(issue_data, dict):
            return

        if "title" not in enriched_args and issue_data.get("title"):
            enriched_args["title"] = issue_data["title"]
            print(f"DEBUG: Enriched from issue - title: {issue_data['title']}")

        if "description" not in enriched_args and issue_data.get("description"):
            enriched_args["description"] = issue_data["description"]

        team_info = issue_data.get("team")
        if isinstance(team_info, dict):
            if "teamName" not in enriched_args and team_info.get("name"):
                enriched_args["teamName"] = team_info["name"]
                print(f"DEBUG: Enriched from issue - teamName: {team_info['name']}")
            if "team_id" not in enriched_args and "teamId" not in enriched_args:
                enriched_args["teamId"] = team_info.get("id")

        project_info = issue_data.get("project")
        if isinstance(project_info, dict):
            if "projectName" not in enriched_args and project_info.get("name"):
                enriched_args["projectName"] = project_info["name"]
                print(f"DEBUG: Enriched from issue - projectName: {project_info['name']}")

        assignee_info = issue_data.get("assignee")
        if isinstance(assignee_info, dict):
            if "assigneeName" not in enriched_args and assignee_info.get("name"):
                enriched_args["assigneeName"] = assignee_info["name"]
                print(f"DEBUG: Enriched from issue - assigneeName: {assignee_info['name']}")

        state_info = issue_data.get("state")
        if isinstance(state_info, dict) and not any(k in args for k in ["state_id", "stateId", "status"]):
            if "stateName" not in enriched_args and state_info.get("name"):
                enriched_args["stateName"] = state_info["name"]
                print(f"DEBUG: Enriched from issue - stateName: {state_info['name']}")

        if "priority" not in args and issue_data.get("priority") is not None:
            enriched_args["priority"] = issue_data.get("priority")

    def _enrich_team(self, user_id: str, enriched_args: Dict[str, Any], args: Dict[str, Any]) -> None:
        team_id = args.get("team_id") or args.get("teamId") or args.get("team")
        if not (team_id and isinstance(team_id, str) and "teamName" not in enriched_args):
            return

        query = f"""
        {{
          team(id: "{team_id}") {{
            id
            name
          }}
        }}
        """
        print(f"DEBUG: Executing team query for ID: {team_id}")
        data = self.linear_service.execute_query(user_id, query)
        print(f"DEBUG: Team query result: {data}")
        team_data = self._first_dict(data, "team", "teams")

        if team_data and "name" in team_data:
            enriched_args["teamName"] = team_data["name"]
            print(f"DEBUG: Enriched team name: {team_data['name']}")

    def _enrich_state(self, user_id: str, enriched_args: Dict[str, Any], args: Dict[str, Any]) -> None:
        state_id = args.get("state_id") or args.get("stateId") or args.get("status")
        if not (state_id and isinstance(state_id, str) and "stateName" not in enriched_args):
            return

        state_query = f"""
        {{
          workflowState(id: "{state_id}") {{
            id
            name
          }}
        }}
        """
        data = self.linear_service.execute_query(user_id, state_query)
        workflow_state = self._first_dict(data, "workflowState", "state")

        if workflow_state and "name" in workflow_state:
            enriched_args["stateName"] = workflow_state["name"]
            print(f"DEBUG: Enriched state name: {workflow_state['name']}")

    def _enrich_project(self, user_id: str, enriched_args: Dict[str, Any], args: Dict[str, Any]) -> None:
        project_id = args.get("project_id") or args.get("projectId") or args.get("project")
        if not (project_id and isinstance(project_id, str) and "projectName" not in enriched_args):
            return

        project_query = f"""
        {{
          project(id: "{project_id}") {{
            id
            name
          }}
        }}
        """
        print(f"DEBUG: Executing project query for ID: {project_id}")
        data = self.linear_service.execute_query(user_id, project_query)
        project_data = self._first_dict(data, "project")

        if project_data and "name" in project_data:
            enriched_args["projectName"] = project_data["name"]
            print(f"DEBUG: Enriched project name: {project_data['name']}")

    def _enrich_assignee(self, user_id: str, enriched_args: Dict[str, Any], args: Dict[str, Any]) -> None:
        assignee_id = args.get("assignee_id") or args.get("assigneeId") or args.get("assignee")
        if not (assignee_id and isinstance(assignee_id, str) and "assigneeName" not in enriched_args):
            return

        assignee_query = f"""
        {{
          user(id: "{assignee_id}") {{
            id
            name
          }}
        }}
        """
        print(f"DEBUG: Executing assignee query for ID: {assignee_id}")
        data = self.linear_service.execute_query(user_id, assignee_query)
        user_data = self._first_dict(data, "user")

        if user_data and "name" in user_data:
            enriched_args["assigneeName"] = user_data["name"]
            print(f"DEBUG: Enriched assignee name: {user_data['name']}")

    def _enrich_priority(self, enriched_args: Dict[str, Any]) -> None:
        priority_value = enriched_args.get("priority")
        if priority_value is None or "priorityName" in enriched_args:
            return

        priority_map = {0: "No Priority", 1: "Urgent", 2: "High", 3: "Medium", 4: "Low"}
        if isinstance(priority_value, int) and priority_value in priority_map:
            enriched_args["priorityName"] = priority_map[priority_value]
            print(f"DEBUG: Enriched priorityName: {priority_map[priority_value]}")

    # --- Queries with caching ---

    def _fetch_issue(self, user_id: str, issue_id: str) -> Optional[Dict[str, Any]]:
        cache_key = f"issue:{issue_id}"
        if cache_key in self._cache:
            return self._cache[cache_key]

        issue_query = f"""
        {{
          issue(id: "{issue_id}") {{
            id
            title
            description
            priority
            team {{ id name }}
            project {{ id name }}
            assignee {{ id name }}
            state {{ id name }}
          }}
        }}
        """
        data = self.linear_service.execute_query(user_id, issue_query)
        issue_data = data.get("issue") if isinstance(data, dict) else None
        self._cache[cache_key] = issue_data
        return issue_data

    # --- Utility helpers ---

    @staticmethod
    def _first_dict(data: Optional[Dict[str, Any]], *keys: str) -> Optional[Dict[str, Any]]:
        if not data or not isinstance(data, dict):
            return None
        for key in keys:
            value = data.get(key)
            if isinstance(value, dict):
                return value
            if isinstance(value, list) and value:
                candidate = value[0]
                if isinstance(candidate, dict):
                    return candidate
        return None


