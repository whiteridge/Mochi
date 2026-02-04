"""OpenAI-compatible provider adapter (OpenAI, Ollama, LM Studio, custom)."""

from __future__ import annotations

import json
from typing import Any, Dict, List, Optional

import httpx

from agent.gemini_config import SYSTEM_INSTRUCTION
from llm.types import LLMChat, LLMResponse, ToolCall


DEFAULT_BASE_URL = "https://api.openai.com/v1"
DEFAULT_MODEL = "gpt-4o"


class OpenAICompatChat(LLMChat):
    def __init__(
        self,
        *,
        api_key: Optional[str],
        base_url: str,
        model: Optional[str],
        tools: List[Dict[str, Any]],
        history: List[Dict[str, str]],
        user_context: Optional[str] = None,
    ) -> None:
        self._api_key = api_key
        self._base_url = base_url.rstrip("/")
        self._model = model or DEFAULT_MODEL
        self._tools = tools
        self._messages: List[Dict[str, Any]] = []

        system_instruction = SYSTEM_INSTRUCTION
        if user_context:
            system_instruction = f"{SYSTEM_INSTRUCTION}\n\n### USER CONTEXT\n{user_context}"
        self._messages.append({"role": "system", "content": system_instruction})
        for msg in history:
            self._messages.append({"role": msg.get("role", "user"), "content": msg.get("parts", "")})

        self._client = httpx.Client(timeout=60.0)
        self._last_tool_calls: List[Dict[str, Any]] = []

    def send_user_message(self, text: str) -> LLMResponse:
        self._messages.append({"role": "user", "content": text})
        response = self._post_chat_completion()
        return self._handle_response(response)

    def send_tool_result(
        self,
        tool_name: str,
        result: Dict[str, Any],
        tool_call_id: Optional[str] = None,
    ) -> LLMResponse:
        tool_call_id = tool_call_id or self._find_tool_call_id(tool_name)
        payload = {
            "role": "tool",
            "tool_call_id": tool_call_id or "call_unknown",
            "content": json.dumps(result, ensure_ascii=True, default=str),
        }
        self._messages.append(payload)
        response = self._post_chat_completion()
        return self._handle_response(response)

    def _post_chat_completion(self) -> Dict[str, Any]:
        url = f"{self._base_url}/chat/completions"
        headers = {"Content-Type": "application/json"}
        if self._api_key:
            headers["Authorization"] = f"Bearer {self._api_key}"
        payload: Dict[str, Any] = {
            "model": self._model,
            "messages": self._messages,
        }
        if self._tools:
            payload["tools"] = self._tools
            payload["tool_choice"] = "auto"
        response = self._client.post(url, headers=headers, json=payload)
        response.raise_for_status()
        return response.json()

    def _handle_response(self, response: Dict[str, Any]) -> LLMResponse:
        choices = response.get("choices") or []
        message = choices[0].get("message") if choices else {}
        content = message.get("content")
        tool_calls = message.get("tool_calls") or []
        self._last_tool_calls = tool_calls
        self._messages.append(message)

        parsed_calls: List[ToolCall] = []
        for call in tool_calls:
            function = call.get("function") or {}
            args_raw = function.get("arguments") or "{}"
            try:
                args = json.loads(args_raw) if isinstance(args_raw, str) else args_raw
            except json.JSONDecodeError:
                args = {"_raw": args_raw}
            parsed_calls.append(
                ToolCall(
                    name=function.get("name", "unknown"),
                    args=args or {},
                    call_id=call.get("id"),
                )
            )

        return LLMResponse(text=content, tool_calls=parsed_calls, thoughts=[])

    def _find_tool_call_id(self, tool_name: str) -> Optional[str]:
        for call in self._last_tool_calls:
            function = call.get("function") or {}
            if function.get("name") == tool_name:
                return call.get("id")
        return None
