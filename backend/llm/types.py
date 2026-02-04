"""Provider-agnostic LLM types."""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any, Dict, List, Optional


@dataclass
class ToolCall:
    name: str
    args: Dict[str, Any]
    call_id: Optional[str] = None


@dataclass
class LLMResponse:
    text: Optional[str] = None
    tool_calls: List[ToolCall] = field(default_factory=list)
    thoughts: List[str] = field(default_factory=list)


class LLMChat:
    """Protocol-like base class for provider chat sessions."""

    def send_user_message(self, text: str) -> LLMResponse:  # pragma: no cover - interface
        raise NotImplementedError

    def send_tool_result(
        self,
        tool_name: str,
        result: Dict[str, Any],
        tool_call_id: Optional[str] = None,
    ) -> LLMResponse:  # pragma: no cover - interface
        raise NotImplementedError
