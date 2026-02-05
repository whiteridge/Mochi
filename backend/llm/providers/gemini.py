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
        self._chat = self._client.chats.create(
            model=model or DEFAULT_MODEL,
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
