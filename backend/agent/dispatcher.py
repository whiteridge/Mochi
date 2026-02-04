"""Stream dispatcher for agent tool execution."""

import json
import re
import time
from dataclasses import dataclass, field
from enum import Enum
from typing import Any, Callable, Dict, Generator, List, Optional, Tuple

from .common import (
    detect_apps_from_input,
    format_app_name,
    looks_like_tool_request,
    make_early_summary,
    map_tool_to_app,
)


def _tool_status_name_for_app(app_id: str) -> str:
    normalized = app_id.lower().replace("-", "_").replace(" ", "_")
    if normalized in {"google_calendar", "calendar"}:
        return "CALENDAR_PRECHECK"
    if normalized in {"gmail", "googlemail"}:
        return "GMAIL_PRECHECK"
    if normalized == "github":
        return "GITHUB_PRECHECK"
    if normalized == "notion":
        return "NOTION_PRECHECK"
    if normalized == "slack":
        return "SLACK_PRECHECK"
    if normalized == "linear":
        return "LINEAR_PRECHECK"
    return f"{app_id.upper()}_PRECHECK"


def _is_rate_limit_error(exc: Exception) -> bool:
    message = str(exc).lower()
    return (
        "resource_exhausted" in message
        or "rate limit" in message
        or "quota" in message
        or "429" in message
    )


def _parse_retry_delay_seconds(exc: Exception) -> Optional[float]:
    match = re.search(r"retry in ([0-9.]+)s", str(exc), re.IGNORECASE)
    if not match:
        return None
    try:
        return float(match.group(1))
    except ValueError:
        return None


def _send_message_with_retry(
    send_fn: Callable[[], Any],
    *,
    max_retries: int = 2,
    base_delay: float = 1.0,
) -> Tuple[Optional[Any], Optional[Exception]]:
    last_exc: Optional[Exception] = None
    for attempt in range(max_retries + 1):
        try:
            return send_fn(), None
        except Exception as exc:  # noqa: BLE001 - surface model errors to caller
            last_exc = exc
            if not _is_rate_limit_error(exc) or attempt >= max_retries:
                break
            delay = _parse_retry_delay_seconds(exc) or (base_delay * (attempt + 1))
            print(
                f"DEBUG: Model provider rate-limited; retrying in {delay:.2f}s",
                flush=True,
            )
            time.sleep(delay)
    return None, last_exc


def _build_tool_response_payload(result_data: Any, max_chars: int = 12000) -> Dict[str, Any]:
    """Build a JSON-safe, size-limited response payload for tool results."""
    try:
        safe_data = json.loads(json.dumps(result_data, ensure_ascii=True, default=str))
    except (TypeError, ValueError):
        safe_data = str(result_data)

    if isinstance(safe_data, (dict, list)):
        serialized = json.dumps(safe_data, ensure_ascii=True)
        if len(serialized) > max_chars:
            return {"result": serialized[:max_chars] + "...[truncated]", "truncated": True}
        return {"result": safe_data}

    if isinstance(safe_data, str) and len(safe_data) > max_chars:
        return {"result": safe_data[:max_chars] + "...[truncated]", "truncated": True}

    return {"result": safe_data}


class DispatchPhase(Enum):
    PLANNING = "planning"
    EXECUTING_READ = "executing_read"
    AWAITING_CONFIRMATION = "awaiting_confirmation"
    FINISHED = "finished"


@dataclass
class DispatcherContext:
    user_input: str
    user_id: str
    max_iterations: int = 5
    iteration: int = 0
    response: Optional[Any] = None
    action_performed: Optional[str] = None
    write_action_executed: bool = False
    pending_read_actions: List[Tuple] = field(default_factory=list)
    pending_write_actions: List[Tuple] = field(default_factory=list)
    last_searching_app_id: Optional[str] = None
    completed_write_apps: set[str] = field(default_factory=set)
    app_read_status: Dict[str, str] = field(default_factory=dict)
    app_write_executing: set[str] = field(default_factory=set)
    executed_write_keys: set = field(default_factory=set)
    apps_with_tool_status: set[str] = field(default_factory=set)
    early_summary_sent: bool = False
    early_summary_text: Optional[str] = None
    tool_nudge_sent: bool = False
    should_nudge_for_tools: bool = False
    required_apps: List[str] = field(default_factory=list)
    missing_app_nudge_sent: bool = False
    involved_apps: List[str] = field(default_factory=list)
    called_apps: set[str] = field(default_factory=set)
    proposal_queue: List[Dict[str, Any]] = field(default_factory=list)
    current_read_action: Optional[Tuple] = None
    exit_early: bool = False


class AgentDispatcher:
    """Handles the agent streaming loop (reads, writes, proposals)."""

    def __init__(
        self,
        composio_service,
        linear_service,
        slack_service,
        notion_service,
        github_service,
        gmail_service,
        google_calendar_service,
    ):
        self.composio_service = composio_service
        self.linear_service = linear_service
        self.slack_service = slack_service
        self.notion_service = notion_service
        self.github_service = github_service
        self.gmail_service = gmail_service
        self.google_calendar_service = google_calendar_service

    def _send_initial_message(
        self,
        chat,
        context: DispatcherContext,
    ) -> Generator[Dict, None, Optional[Any]]:
        print(f"DEBUG: Sending user input to model: {context.user_input[:100]}...")
        response, send_error = _send_message_with_retry(
            lambda: chat.send_user_message(context.user_input)
        )
        if send_error is not None:  # noqa: BLE001 - surface rate limits to client
            if _is_rate_limit_error(send_error):
                yield {
                    "type": "message",
                    "content": (
                        "I'm temporarily rate-limited by the model provider. "
                        "Please retry in a minute."
                    ),
                    "action_performed": None,
                }
                return None
            raise send_error

        if hasattr(response, "thoughts") and response.thoughts:
            for thought in response.thoughts:
                if not thought:
                    continue
                print(f"DEBUG: Model Thought: {thought}", flush=True)
                yield {
                    "type": "thinking",
                    "content": thought,
                }

        return response

    def _emit_pre_detected_summary(
        self,
        context: DispatcherContext,
        enabled: bool,
    ) -> Generator[Dict, None, None]:
        if not enabled:
            return

        pre_detected_apps = detect_apps_from_input(context.user_input)
        if pre_detected_apps:
            context.required_apps = pre_detected_apps.copy()

        if len(pre_detected_apps) > 1:
            print(f"DEBUG: Pre-detected multiple apps from user input: {pre_detected_apps}")
            context.involved_apps = pre_detected_apps.copy()

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
                elif app == "gmail":
                    app_actions.append("check Gmail")
                elif app == "google_calendar":
                    app_actions.append("check Google Calendar")

            if len(app_actions) >= 2:
                summary_text = f"I'll {app_actions[0]} and {app_actions[1]}."
            else:
                summary_text = f"I'll {' and '.join(app_actions)}."

            context.early_summary_text = summary_text
            yield {
                "type": "early_summary",
                "content": summary_text,
                "app_id": pre_detected_apps[0],
                "involved_apps": context.involved_apps,
            }
            context.early_summary_sent = True
            print(f"DEBUG: Emitted combined early summary for {pre_detected_apps}")

        context.should_nudge_for_tools = bool(pre_detected_apps) and looks_like_tool_request(
            context.user_input
        )

    def _execute_confirmed_tool(
        self,
        chat,
        context: DispatcherContext,
        confirmed_tool: Dict,
    ) -> Generator[Dict, None, Optional[Any]]:
        tool_name = confirmed_tool.get("tool")
        tool_args = confirmed_tool.get("args", {})
        tool_call_id = confirmed_tool.get("tool_call_id")
        app_id = confirmed_tool.get("app_id", map_tool_to_app(tool_name))

        print(f"DEBUG: Executing CONFIRMED action: {tool_name}")
        context.involved_apps.append(app_id)
        executed_key = (tool_name, json.dumps(tool_args, sort_keys=True))
        context.executed_write_keys.add(executed_key)
        context.completed_write_apps.add(app_id)
        context.app_write_executing.add(app_id)

        app_display = format_app_name(app_id)
        yield {
            "type": "early_summary",
            "content": f"Executing your confirmed {app_display} action...",
            "app_id": app_id,
            "involved_apps": context.involved_apps,
        }
        context.early_summary_sent = True

        try:
            result = self.composio_service.execute_tool(
                slug=tool_name,
                arguments=tool_args,
                user_id=context.user_id,
            )
            print(f"DEBUG: Confirmed tool result: {result}", flush=True)

            if hasattr(result, "data"):
                result_data = result.data
            else:
                result_data = result

            context.write_action_executed = True
            context.action_performed = f"{app_display} action executed"
            context.app_write_executing.discard(app_id)
            context.app_read_status[app_id] = "done"

            response_payload = _build_tool_response_payload(result_data)
            response, send_error = _send_message_with_retry(
                lambda: chat.send_tool_result(tool_name, response_payload, tool_call_id)
            )
            if send_error is not None:  # noqa: BLE001 - surface model errors to client
                print(
                    f"DEBUG: ❌ Model follow-up error after {tool_name}: {send_error}",
                    flush=True,
                )
                if _is_rate_limit_error(send_error):
                    content = (
                        f"{app_display} action completed. "
                        "I'm temporarily rate-limited, so I couldn't continue the follow-up. "
                        "Please retry in a minute."
                    )
                else:
                    content = (
                        f"{app_display} action completed, but I couldn't continue the follow-up "
                        "due to a model error. Please retry."
                    )
                yield {
                    "type": "message",
                    "content": content,
                    "action_performed": f"{app_display} action executed",
                }
                return None
        except Exception as exec_error:  # noqa: BLE001 - emit error to stream
            print(f"DEBUG: ❌ Confirmed tool execution error: {exec_error}", flush=True)
            context.app_write_executing.discard(app_id)
            context.app_read_status[app_id] = "error"
            yield {
                "type": "message",
                "content": f"Error executing {app_display} action: {str(exec_error)}",
                "action_performed": None,
            }
            return None

        return response

    def _queue_pending_write_actions(self, context: DispatcherContext) -> None:
        if not context.pending_write_actions:
            return
        print(f"DEBUG: Emitting {len(context.pending_write_actions)} queued proposal(s)")

        for (
            tool_name,
            args,
            tool_call_id,
            app_id,
            is_linear_write,
            is_slack_write,
            is_notion_write,
            is_github_write,
            is_gmail_write,
            is_calendar_write,
        ) in context.pending_write_actions:
            enriched_args = args
            if is_linear_write:
                enriched_args = self.linear_service.enrich_proposal(context.user_id, args, tool_name)
            elif is_slack_write:
                enriched_args = self.slack_service.enrich_proposal(context.user_id, args, tool_name)
            elif is_notion_write:
                enriched_args = self.notion_service.enrich_proposal(context.user_id, args, tool_name)
            elif is_github_write:
                enriched_args = self.github_service.enrich_proposal(context.user_id, args, tool_name)
            elif is_gmail_write:
                enriched_args = self.gmail_service.enrich_proposal(context.user_id, args, tool_name)
            elif is_calendar_write:
                enriched_args = self.google_calendar_service.enrich_proposal(context.user_id, args, tool_name)

            context.proposal_queue.append(
                {
                    "tool": tool_name,
                    "args": enriched_args,
                    "app_id": app_id,
                    "tool_call_id": tool_call_id,
                    "summary_text": make_early_summary(app_id),
                }
            )

        context.pending_write_actions.clear()

    def _emit_proposal_queue(self, context: DispatcherContext) -> Generator[Dict, None, None]:
        if not context.proposal_queue:
            return

        total_proposals = len(context.proposal_queue)
        print(f"DEBUG: Emitting {total_proposals} queued proposal(s)")

        proposal_app_ids: List[str] = []
        for proposal in context.proposal_queue:
            app_id = proposal["app_id"]
            if app_id not in proposal_app_ids:
                proposal_app_ids.append(app_id)

        if len(proposal_app_ids) > 1:
            for app_id in proposal_app_ids:
                if app_id in context.apps_with_tool_status:
                    continue
                synthetic_tool = _tool_status_name_for_app(app_id)
                context.apps_with_tool_status.add(app_id)
                yield {
                    "type": "tool_status",
                    "tool": synthetic_tool,
                    "status": "searching",
                    "app_id": app_id,
                    "involved_apps": context.involved_apps,
                }
                yield {
                    "type": "tool_status",
                    "tool": synthetic_tool,
                    "status": "done",
                    "app_id": app_id,
                    "involved_apps": context.involved_apps,
                }

        yield {
            "type": "multi_app_status",
            "apps": [{"app_id": app, "state": "waiting"} for app in context.involved_apps],
            "active_app": context.proposal_queue[0]["app_id"],
        }

        first_proposal = context.proposal_queue[0]
        yield {
            "type": "proposal",
            "tool": first_proposal["tool"],
            "content": first_proposal["args"],
            "summary_text": first_proposal["summary_text"],
            "app_id": first_proposal["app_id"],
            "tool_call_id": first_proposal.get("tool_call_id"),
            "proposal_index": 0,
            "total_proposals": total_proposals,
            "remaining_proposals": [
                {
                    "tool": p["tool"],
                    "app_id": p["app_id"],
                    "args": p["args"],
                    "tool_call_id": p.get("tool_call_id"),
                }
                for p in context.proposal_queue[1:]
            ],
        }

    def _missing_required_apps(self, context: DispatcherContext) -> List[str]:
        if not context.required_apps:
            return []
        return [app for app in context.required_apps if app not in context.called_apps]

    def _missing_app_nudge(self, missing_apps: List[str]) -> str:
        app_list = ", ".join(format_app_name(app) for app in missing_apps)
        return (
            "Continue with the remaining requested apps: "
            f"{app_list}. "
            "Use the available tools to complete those actions. "
            "If IDs are required, call list/search tools to resolve them first. "
            "Respond with function calls only."
        )

    def _collect_actions_from_response(
        self,
        context: DispatcherContext,
        response: Any,
    ) -> Generator[Dict, None, Tuple[bool, List[Tuple], List[Tuple]]]:
        read_actions_to_execute = context.pending_read_actions
        context.pending_read_actions = []
        write_actions_found = []
        found_function_call = False

        if hasattr(response, "tool_calls") and response.tool_calls:
            for tool_call in response.tool_calls:
                found_function_call = True
                tool_name = tool_call.name
                args = tool_call.args or {}
                tool_call_id = tool_call.call_id
                print(f"DEBUG: Tool call: {tool_name}({args})", flush=True)

                app_id = map_tool_to_app(tool_name)
                is_new_app = app_id not in context.involved_apps
                if is_new_app:
                    context.involved_apps.append(app_id)
                context.called_apps.add(app_id)

                if not context.early_summary_sent:
                    summary_text = make_early_summary(app_id)
                    print(f"DEBUG: Emitting early summary for {app_id}: {summary_text}")
                    yield {
                        "type": "early_summary",
                        "content": summary_text,
                        "app_id": app_id,
                        "involved_apps": context.involved_apps,
                    }
                    context.early_summary_sent = True

                is_linear_write = self.linear_service.is_write_action(tool_name, args)
                is_slack_write = self.slack_service.is_write_action(tool_name, args)
                is_notion_write = self.notion_service.is_write_action(tool_name, args)
                is_github_write = self.github_service.is_write_action(tool_name, args)
                is_gmail_write = self.gmail_service.is_write_action(tool_name, args)
                is_calendar_write = self.google_calendar_service.is_write_action(tool_name, args)
                is_write = (
                    is_linear_write
                    or is_slack_write
                    or is_notion_write
                    or is_github_write
                    or is_gmail_write
                    or is_calendar_write
                )
                executed_key = (tool_name, json.dumps(args, sort_keys=True))

                if is_write:
                    if executed_key in context.executed_write_keys:
                        print(f"DEBUG: Skipping duplicate write proposal for {tool_name}")
                        continue
                    if app_id in context.completed_write_apps:
                        print(f"DEBUG: Skipping write for completed app {app_id}")
                        continue
                    if app_id == "slack":
                        linear_state = context.app_read_status.get("linear")
                        if (
                            "linear" in context.called_apps
                            and (
                                linear_state not in ("done", "error")
                                or ("linear" in context.app_write_executing)
                            )
                        ):
                            print("DEBUG: Gating Slack write until Linear read+write complete")
                            continue

                    print(f"DEBUG: Queueing {tool_name} for confirmation")
                    write_actions_found.append(
                        (
                            tool_name,
                            args,
                            tool_call_id,
                            app_id,
                            is_linear_write,
                            is_slack_write,
                            is_notion_write,
                            is_github_write,
                            is_gmail_write,
                            is_calendar_write,
                        )
                    )
                    context.executed_write_keys.add(executed_key)
                else:
                    if app_id == "slack":
                        linear_state = context.app_read_status.get("linear")
                        if (
                            "linear" in context.called_apps
                            and (
                                linear_state not in ("done", "error")
                                or ("linear" in context.app_write_executing)
                            )
                        ):
                            print("DEBUG: Gating Slack read until Linear read+write complete")
                            continue
                    read_actions_to_execute.append((tool_name, args, tool_call_id, app_id))

        return found_function_call, read_actions_to_execute, write_actions_found

    def _handle_planning(
        self,
        chat,
        context: DispatcherContext,
    ) -> Generator[Dict, None, DispatchPhase]:
        if context.iteration >= context.max_iterations:
            return DispatchPhase.FINISHED

        found_function_call, read_actions_to_execute, write_actions_found = yield from (
            self._collect_actions_from_response(context, context.response)
        )

        if not found_function_call and context.iteration == 0:
            print("DEBUG: Model responded with text only (no function calls)", flush=True)

        if write_actions_found:
            context.pending_write_actions.extend(write_actions_found)

        if read_actions_to_execute:
            context.current_read_action = read_actions_to_execute[0]
            if len(read_actions_to_execute) > 1:
                context.pending_read_actions.extend(read_actions_to_execute[1:])
            return DispatchPhase.EXECUTING_READ

        if context.pending_write_actions and not context.pending_read_actions:
            missing_apps = self._missing_required_apps(context)
            if (
                context.should_nudge_for_tools
                and missing_apps
                and not context.missing_app_nudge_sent
            ):
                context.missing_app_nudge_sent = True
                nudge_text = self._missing_app_nudge(missing_apps)
                response, send_error = _send_message_with_retry(
                    lambda: chat.send_user_message(nudge_text)
                )
                if send_error is not None:  # noqa: BLE001 - surface rate limits to client
                    if _is_rate_limit_error(send_error):
                        yield {
                            "type": "message",
                            "content": (
                                "I'm temporarily rate-limited by the model provider. "
                                "Please retry in a minute."
                            ),
                            "action_performed": None,
                        }
                        context.exit_early = True
                        return DispatchPhase.FINISHED
                    raise send_error

                context.response = response

                context.iteration += 1
                return DispatchPhase.PLANNING

            self._queue_pending_write_actions(context)
            return DispatchPhase.AWAITING_CONFIRMATION

        if not found_function_call:
            if context.should_nudge_for_tools and not context.tool_nudge_sent:
                context.tool_nudge_sent = True
                print(
                    "DEBUG: No function call detected; nudging model to use tools",
                    flush=True,
                )
                nudge_text = (
                    "Use the available tools to complete the user's request. "
                    "If IDs are required, call list/search tools to resolve them first. "
                    "Respond with function calls only."
                )
                response, send_error = _send_message_with_retry(
                    lambda: chat.send_user_message(nudge_text)
                )
                if send_error is not None:  # noqa: BLE001 - surface rate limits to client
                    if _is_rate_limit_error(send_error):
                        yield {
                            "type": "message",
                            "content": (
                                "I'm temporarily rate-limited by the model provider. "
                                "Please retry in a minute."
                            ),
                            "action_performed": None,
                        }
                        context.exit_early = True
                        return DispatchPhase.FINISHED
                    raise send_error

                context.response = response

                context.iteration += 1
                return DispatchPhase.PLANNING

            if context.last_searching_app_id:
                context.apps_with_tool_status.add(context.last_searching_app_id)
                yield {
                    "type": "tool_status",
                    "tool": "noop",
                    "status": "done",
                    "app_id": context.last_searching_app_id,
                    "involved_apps": context.involved_apps,
                }
            print("DEBUG: No function call in response, breaking loop")
            return DispatchPhase.FINISHED

        if not context.pending_write_actions and not context.pending_read_actions:
            print("DEBUG: No actions to process, breaking loop")
            return DispatchPhase.FINISHED

        return DispatchPhase.FINISHED

    def _handle_read(
        self,
        chat,
        context: DispatcherContext,
    ) -> Generator[Dict, None, DispatchPhase]:
        if not context.current_read_action and not context.pending_read_actions:
            return DispatchPhase.PLANNING

        read_actions: List[Tuple] = []
        if context.current_read_action:
            read_actions.append(context.current_read_action)
        if context.pending_read_actions:
            read_actions.extend(context.pending_read_actions)
        context.current_read_action = None
        context.pending_read_actions = []

        if len(read_actions) > 1:
            print(f"DEBUG: Executing {len(read_actions)} READ actions in batch", flush=True)

        response: Optional[Any] = None
        for tool_name, tool_args, tool_call_id, app_id in read_actions:
            context.apps_with_tool_status.add(app_id)
            yield {
                "type": "tool_status",
                "tool": tool_name,
                "status": "searching",
                "app_id": app_id,
                "involved_apps": context.involved_apps,
            }
            context.last_searching_app_id = app_id

            print(f"DEBUG: Executing READ: {tool_name}", flush=True)

            try:
                result = self.composio_service.execute_tool(
                    slug=tool_name,
                    arguments=tool_args,
                    user_id=context.user_id,
                )
                print(f"DEBUG: Tool execution result: {result}", flush=True)

                if hasattr(result, "data"):
                    result_data = result.data
                    result_success = getattr(result, "successful", True)
                else:
                    result_data = result
                    result_success = bool(getattr(result, "successful", True))

                response_payload = _build_tool_response_payload(result_data)
                status_after_read = "done" if result_success else "error"

            except Exception as exec_error:  # noqa: BLE001 - emit error to stream
                print(f"DEBUG: ❌ Tool execution error: {exec_error}", flush=True)
                response_payload = {"error": str(exec_error)}
                status_after_read = "error"

            context.app_read_status[app_id] = status_after_read
            context.apps_with_tool_status.add(app_id)
            yield {
                "type": "tool_status",
                "tool": tool_name,
                "status": status_after_read,
                "app_id": app_id,
                "involved_apps": context.involved_apps,
            }

            response, send_error = _send_message_with_retry(
                lambda: chat.send_tool_result(tool_name, response_payload, tool_call_id)
            )
            if send_error is not None:  # noqa: BLE001 - surface model errors to client
                print(
                    f"DEBUG: ❌ Model follow-up error after read batch: {send_error}",
                    flush=True,
                )
                if _is_rate_limit_error(send_error):
                    content = (
                        "I fetched the requested data, but I'm temporarily rate-limited "
                        "and couldn't continue. Please retry in a minute."
                    )
                else:
                    content = (
                        "I fetched the requested data, but couldn't continue due to a model error. "
                        "Please retry."
                    )
                if context.pending_write_actions:
                    self._queue_pending_write_actions(context)
                if context.proposal_queue:
                    yield from self._emit_proposal_queue(context)
                    context.exit_early = True
                    return DispatchPhase.FINISHED
                yield {
                    "type": "message",
                    "content": content,
                    "action_performed": None,
                }
                context.exit_early = True
                return DispatchPhase.FINISHED

        context.response = response
        context.iteration += 1
        return DispatchPhase.PLANNING

    def run(
        self,
        chat,
        user_input: str,
        user_id: str,
        confirmed_tool: Optional[Dict] = None,
    ) -> Generator[Dict, None, None]:
        """Run the streaming loop and yield UI events."""
        try:
            context = DispatcherContext(user_input=user_input, user_id=user_id)

            response = yield from self._send_initial_message(chat, context)
            if response is None:
                return
            context.response = response

            yield from self._emit_pre_detected_summary(context, confirmed_tool is None)

            if confirmed_tool:
                response = yield from self._execute_confirmed_tool(chat, context, confirmed_tool)
                if response is None:
                    return
                context.response = response

            phase = DispatchPhase.PLANNING
            while phase != DispatchPhase.FINISHED:
                if phase == DispatchPhase.PLANNING:
                    phase = yield from self._handle_planning(chat, context)
                elif phase == DispatchPhase.EXECUTING_READ:
                    phase = yield from self._handle_read(chat, context)
                elif phase == DispatchPhase.AWAITING_CONFIRMATION:
                    yield from self._emit_proposal_queue(context)
                    return
                else:
                    phase = DispatchPhase.FINISHED

                if context.exit_early:
                    return

            if context.exit_early:
                return

            if context.write_action_executed:
                context.action_performed = "Action Executed"

            if context.response is None:
                return

            if hasattr(context.response, "text"):
                final_text = context.response.text or ""
            else:
                final_text = str(context.response) if context.response is not None else ""
            yield {
                "type": "message",
                "content": final_text,
                "action_performed": context.action_performed,
            }

        except Exception as exc:  # noqa: BLE001 - surface error to client
            print(f"Error in agent execution: {exc}")
            yield {
                "type": "message",
                "content": f"An error occurred: {str(exc)}",
                "action_performed": None,
            }
