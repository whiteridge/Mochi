"""Stream dispatcher for agent tool execution."""

import json
from typing import Dict, Generator, List, Optional
from google.genai import types

from .common import detect_apps_from_input, make_early_summary, map_tool_to_app


class AgentDispatcher:
    """Handles the agent streaming loop (reads, writes, proposals)."""

    def __init__(self, composio_service, linear_service, slack_service):
        self.composio_service = composio_service
        self.linear_service = linear_service
        self.slack_service = slack_service

    def run(
        self,
        chat,
        user_input: str,
        user_id: str,
        confirmed_tool: Optional[Dict] = None,
    ) -> Generator[Dict, None, None]:
        """Run the streaming loop and yield UI events."""
        try:
            # Initial message
            print(f"DEBUG: Sending user input to Gemini: {user_input[:100]}...")
            response = chat.send_message(user_input)

            # DEBUG: Log function calls in response
            if hasattr(response, "candidates") and response.candidates:
                candidate = response.candidates[0]
                if hasattr(candidate, "content") and candidate.content is not None:
                    if hasattr(candidate.content, "parts") and candidate.content.parts:
                        for part in candidate.content.parts:
                            if hasattr(part, "function_call") and part.function_call:
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
                        "involved_apps": involved_apps,
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
                yield {
                    "type": "early_summary",
                    "content": f"Executing your confirmed {app_id.capitalize()} action...",
                    "app_id": app_id,
                    "involved_apps": involved_apps,
                }
                early_summary_sent = True

                try:
                    result = self.composio_service.execute_tool(
                        slug=tool_name,
                        arguments=tool_args,
                        user_id=user_id,
                    )
                    print(f"DEBUG: Confirmed tool result: {result}", flush=True)

                    if hasattr(result, "data"):
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
                        response={"result": str(result_data)},
                    )
                    response = chat.send_message([function_response])

                except Exception as exec_error:  # noqa: BLE001 - emit error to stream
                    print(f"DEBUG: ❌ Confirmed tool execution error: {exec_error}", flush=True)
                    app_write_executing.discard(app_id)
                    app_read_status[app_id] = "error"
                    yield {
                        "type": "message",
                        "content": f"Error executing {app_id.capitalize()} action: {str(exec_error)}",
                        "action_performed": None,
                    }
                    return

            for iteration in range(max_iterations):
                # Track actions in this iteration
                read_actions_to_execute = pending_read_actions  # (tool_name, args, part, app_id)
                pending_read_actions = []
                write_actions_found = []  # (tool_name, args, app_id, is_linear_write, is_slack_write)
                found_function_call = False

                # Check if the model wants to call a function
                if (
                    hasattr(response, "candidates")
                    and response.candidates
                    and hasattr(response.candidates[0], "content")
                    and response.candidates[0].content is not None
                    and hasattr(response.candidates[0].content, "parts")
                    and response.candidates[0].content.parts
                ):
                    for part in response.candidates[0].content.parts:
                        if hasattr(part, "function_call") and part.function_call:
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
                                    "involved_apps": involved_apps,
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
                                # Gate Slack writes only when Linear is actually involved and unfinished
                                if app_id == "slack":
                                    linear_involved = (
                                        "linear" in app_read_status
                                        or "linear" in app_write_executing
                                    )
                                    if linear_involved:
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
                                    linear_involved = (
                                        "linear" in app_read_status
                                        or "linear" in app_write_executing
                                    )
                                    if linear_involved and (linear_state not in ("done", "error") or ("linear" in app_write_executing)):
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
                        "involved_apps": involved_apps,
                    }
                    last_searching_app_id = app_id

                    print(f"DEBUG: Executing READ: {tool_name}", flush=True)

                    try:
                        result = self.composio_service.execute_tool(
                            slug=tool_name,
                            arguments=tool_args,
                            user_id=user_id,
                        )
                        print(f"DEBUG: Tool execution result: {result}", flush=True)

                        if hasattr(result, "data"):
                            result_data = result.data
                            result_success = getattr(result, "successful", True)
                        else:
                            result_data = result
                            result_success = bool(getattr(result, "successful", True))

                        function_response = types.Part.from_function_response(
                            name=tool_name,
                            response={"result": str(result_data)},
                        )
                        status_after_read = "done" if result_success else "error"

                    except Exception as exec_error:  # noqa: BLE001 - emit error to stream
                        print(f"DEBUG: ❌ Tool execution error: {exec_error}", flush=True)
                        function_response = types.Part.from_function_response(
                            name=tool_name,
                            response={"error": str(exec_error)},
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
                        "involved_apps": involved_apps,
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

                        proposal_queue.append(
                            {
                                "tool": tool_name,
                                "args": enriched_args,
                                "app_id": app_id,
                                "summary_text": make_early_summary(app_id),
                            }
                        )

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
                            "involved_apps": involved_apps,
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
                    "active_app": proposal_queue[0]["app_id"],
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
                        {"tool": p["tool"], "app_id": p["app_id"], "args": p["args"]} for p in proposal_queue[1:]
                    ],
                }
                return

            if write_action_executed:
                action_performed = "Action Executed"

            final_text = response.text if hasattr(response, "text") else str(response)
            yield {
                "type": "message",
                "content": final_text,
                "action_performed": action_performed,
            }

        except Exception as exc:  # noqa: BLE001 - surface error to client
            print(f"Error in agent execution: {exc}")
            yield {
                "type": "message",
                "content": f"An error occurred: {str(exc)}",
                "action_performed": None,
            }


