"""Anthropic provider adapter."""

from __future__ import annotations

import json
from typing import Any, Dict, List, Optional

import httpx

from agent.gemini_config import SYSTEM_INSTRUCTION
from llm.types import LLMChat, LLMResponse, ToolCall


DEFAULT_BASE_URL = "https://api.anthropic.com"
DEFAULT_MODEL = "claude-sonnet-4-5-20250929"
DEFAULT_VERSION = "2023-06-01"


class AnthropicChat(LLMChat):
    def __init__(
        self,
        *,
        api_key: str,
        model: Optional[str],
        tools: List[Dict[str, Any]],
        history: List[Dict[str, str]],
        user_context: Optional[str] = None,
        base_url: Optional[str] = None,
    ) -> None:
        self._api_key = api_key
        self._model = model or DEFAULT_MODEL
        self._base_url = (base_url or DEFAULT_BASE_URL).rstrip("/")
        self._tools = [_convert_tool(t) for t in tools]
        self._messages: List[Dict[str, Any]] = []

        self._system = SYSTEM_INSTRUCTION
        if user_context:
            self._system = f"{SYSTEM_INSTRUCTION}\n\n### USER CONTEXT\n{user_context}"

        for msg in history:
            role = msg.get("role", "user")
            if role == "model":
                role = "assistant"
            content = msg.get("parts", "")
            if isinstance(content, list):
                content = " ".join([str(part) for part in content])
            self._messages.append({"role": role, "content": [{"type": "text", "text": content}]})

        self._client = httpx.Client(timeout=60.0)

    def send_user_message(self, text: str) -> LLMResponse:
        self._messages.append({"role": "user", "content": [{"type": "text", "text": text}]})
        response = self._post_messages()
        return self._handle_response(response)

    def send_tool_result(
        self,
        tool_name: str,
        result: Dict[str, Any],
        tool_call_id: Optional[str] = None,
    ) -> LLMResponse:
        content = json.dumps(result, ensure_ascii=True, default=str)
        tool_block = {
            "type": "tool_result",
            "tool_use_id": tool_call_id or tool_name,
            "content": content,
        }
        self._messages.append({"role": "user", "content": [tool_block]})
        response = self._post_messages()
        return self._handle_response(response)

    def _post_messages(self) -> Dict[str, Any]:
        url = f"{self._base_url}/v1/messages"
        headers = {
            "content-type": "application/json",
            "x-api-key": self._api_key,
            "anthropic-version": DEFAULT_VERSION,
        }
        payload: Dict[str, Any] = {
            "model": self._model,
            "max_tokens": 1024,
            "messages": self._messages,
            "system": self._system,
        }
        if self._tools:
            payload["tools"] = self._tools
        response = self._client.post(url, headers=headers, json=payload)
        response.raise_for_status()
        return response.json()

    def _handle_response(self, response: Dict[str, Any]) -> LLMResponse:
        content_blocks = response.get("content") or []
        text_parts: List[str] = []
        tool_calls: List[ToolCall] = []

        assistant_blocks: List[Dict[str, Any]] = []
        for block in content_blocks:
            block_type = block.get("type")
            if block_type == "text":
                text_parts.append(block.get("text", ""))
            elif block_type == "tool_use":
                tool_calls.append(
                    ToolCall(
                        name=block.get("name", "unknown"),
                        args=block.get("input") or {},
                        call_id=block.get("id"),
                    )
                )
            assistant_blocks.append(block)

        self._messages.append({"role": "assistant", "content": assistant_blocks})
        text = "\n".join([t for t in text_parts if t.strip()]) or None
        return LLMResponse(text=text, tool_calls=tool_calls, thoughts=[])


def _convert_tool(tool: Dict[str, Any]) -> Dict[str, Any]:
    """Convert OpenAI tool schema to Anthropic tool schema."""
    function = tool.get("function") or {}
    return {
        "name": function.get("name", "tool"),
        "description": function.get("description", ""),
        "input_schema": function.get("parameters") or {"type": "object", "properties": {}},
    }
