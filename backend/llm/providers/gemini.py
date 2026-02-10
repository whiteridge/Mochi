"""Gemini provider adapter."""

from __future__ import annotations

from typing import Any, Dict, List, Optional

from google import genai
from google.genai import types

from agent.gemini_config import SYSTEM_INSTRUCTION
from utils.chat_utils import format_history
from utils.tool_converter import convert_to_gemini_tools
from llm.types import LLMChat, LLMResponse, ToolCall


DEFAULT_MODEL = "gemini-3-flash-preview"
FALLBACK_MODELS = (
    "gemini-3-flash-preview",
    "gemini-2.5-flash",
    "gemini-2.5-flash-lite",
    "gemini-2.5-pro",
)
MODEL_ALIAS_MAP = {
    "gemini-3-flash": "gemini-3-flash-preview",
}
NON_CHAT_MODEL_KEYWORDS = (
    "embedding",
    "imagen",
    "veo",
    "tts",
    "native-audio",
    "live",
)


def build_tools(composio_tools: List[Any]) -> List[types.Tool]:
    return convert_to_gemini_tools(composio_tools)


class GeminiChat(LLMChat):
    def __init__(
        self,
        *,
        api_key: str,
        model: Optional[str],
        tools: List[Any],
        history: List[Dict[str, str]],
        user_context: Optional[str] = None,
    ) -> None:
        self._client = genai.Client(api_key=api_key)
        tool_defs = build_tools(tools)
        system_instruction = SYSTEM_INSTRUCTION
        if user_context:
            system_instruction = f"{SYSTEM_INSTRUCTION}\n\n### USER CONTEXT\n{user_context}"
        config = types.GenerateContentConfig(
            tools=tool_defs,
            system_instruction=system_instruction,
            thinking_config=types.ThinkingConfig(include_thoughts=True),
        )
        formatted_history = format_history(history)
        requested_model = _normalize_model_name(model or DEFAULT_MODEL)
        self._chat = _create_chat_with_model_fallback(
            client=self._client,
            requested_model=requested_model,
            config=config,
            history=formatted_history,
        )

    def send_user_message(self, text: str) -> LLMResponse:
        response = self._chat.send_message(text)
        return _parse_response(response)

    def send_tool_result(
        self,
        tool_name: str,
        result: Dict[str, Any],
        tool_call_id: Optional[str] = None,
    ) -> LLMResponse:
        function_response = types.Part.from_function_response(
            name=tool_name,
            response=result,
        )
        response = self._chat.send_message([function_response])
        return _parse_response(response)


def _parse_response(response: Any) -> LLMResponse:
    text_parts: List[str] = []
    tool_calls: List[ToolCall] = []
    thoughts: List[str] = []

    if hasattr(response, "candidates") and response.candidates:
        candidate = response.candidates[0]
        if hasattr(candidate, "content") and candidate.content is not None:
            if hasattr(candidate.content, "parts") and candidate.content.parts:
                for part in candidate.content.parts:
                    if hasattr(part, "function_call") and part.function_call:
                        args = dict(part.function_call.args) if part.function_call.args else {}
                        tool_calls.append(
                            ToolCall(name=part.function_call.name, args=args)
                        )
                    if hasattr(part, "thought") and part.thought:
                        thoughts.append(part.thought)
                    if hasattr(part, "text") and part.text:
                        text_parts.append(part.text)

    text = "\n".join([t for t in text_parts if t.strip()]) or None
    return LLMResponse(text=text, tool_calls=tool_calls, thoughts=thoughts)


def _normalize_model_name(model_name: Optional[str]) -> str:
    name = (model_name or DEFAULT_MODEL).strip()
    if name.startswith("models/"):
        name = name[len("models/") :]
    return MODEL_ALIAS_MAP.get(name, name)


def _create_chat_with_model_fallback(
    *,
    client: genai.Client,
    requested_model: str,
    config: types.GenerateContentConfig,
    history: List[types.Content],
):
    try:
        return client.chats.create(
            model=requested_model,
            config=config,
            history=history,
        )
    except Exception as exc:  # noqa: BLE001 - provider errors must be surfaced
        if not _is_model_not_found_error(exc):
            raise

        fallback_model = _pick_fallback_model(client, requested_model)
        if not fallback_model or fallback_model == requested_model:
            raise

        print(
            f"DEBUG: Requested model '{requested_model}' unavailable, falling back to '{fallback_model}'",
            flush=True,
        )
        return client.chats.create(
            model=fallback_model,
            config=config,
            history=history,
        )


def _is_model_not_found_error(exc: Exception) -> bool:
    message = str(exc).lower()
    return (
        "not found for api version" in message
        or "404_not_found" in message
        or "status': 'not_found'" in message
        or '"status": "not_found"' in message
        or '"status":"not_found"' in message
    )


def _pick_fallback_model(client: genai.Client, requested_model: str) -> Optional[str]:
    available_models = _list_generate_content_models(client)
    if not available_models:
        return None

    for candidate in (_normalize_model_name(requested_model), *FALLBACK_MODELS):
        normalized_candidate = _normalize_model_name(candidate)
        if normalized_candidate in available_models:
            return normalized_candidate

    for model_name in available_models:
        lower = model_name.lower()
        if not lower.startswith("gemini-"):
            continue
        if any(keyword in lower for keyword in NON_CHAT_MODEL_KEYWORDS):
            continue
        if "flash" in lower:
            return model_name

    for model_name in available_models:
        lower = model_name.lower()
        if lower.startswith("gemini-") and not any(
            keyword in lower for keyword in NON_CHAT_MODEL_KEYWORDS
        ):
            return model_name

    return available_models[0]


def _list_generate_content_models(client: genai.Client) -> List[str]:
    model_names: List[str] = []
    try:
        for model in client.models.list():
            name = _normalize_model_name(getattr(model, "name", ""))
            if not name:
                continue
            supported_actions = getattr(model, "supported_actions", []) or []
            actions = [str(action).lower() for action in supported_actions]
            supports_generate = any(
                "generatecontent" in action or "generate_content" in action
                for action in actions
            )
            if supports_generate:
                model_names.append(name)
    except Exception as exc:  # noqa: BLE001 - fallback to static models on API failures
        print(f"DEBUG: Could not list Gemini models for fallback: {exc}", flush=True)
        return []

    return sorted(set(model_names))
