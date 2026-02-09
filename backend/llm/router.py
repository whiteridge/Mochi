"""Gemini-only LLM router."""

from __future__ import annotations

from dataclasses import dataclass
from typing import Any, Dict, List, Optional, Tuple
import os

from llm.types import LLMChat
from llm.providers.gemini import GeminiChat


DEFAULT_PROVIDER = "google"
DEFAULT_MODEL = "gemini-3-flash"


@dataclass
class ResolvedModelConfig:
    provider: str
    model: str
    api_key: Optional[str]


class ModelConfigError(ValueError):
    pass


def create_chat_session(
    *,
    model_config: Optional[Any],
    fallback_api_key: Optional[str],
    tools: List[Dict[str, Any]],
    history: List[Dict[str, str]],
    user_context: Optional[str] = None,
) -> Tuple[LLMChat, ResolvedModelConfig]:
    resolved = _resolve_model_config(model_config, fallback_api_key)
    if not resolved.api_key:
        raise ModelConfigError("Missing GOOGLE_API_KEY for Gemini")
    return (
        GeminiChat(
            api_key=resolved.api_key,
            model=resolved.model,
            tools=tools,
            history=history,
            user_context=user_context,
        ),
        resolved,
    )


def _resolve_model_config(
    model_config: Optional[Any],
    fallback_api_key: Optional[str],
) -> ResolvedModelConfig:
    api_key = (
        _get_field(model_config, "api_key")
        if model_config is not None
        else None
    ) or fallback_api_key or os.getenv("GOOGLE_API_KEY")

    requested_model = (
        _get_field(model_config, "model")
        if model_config is not None
        else None
    )
    model = requested_model.strip() if requested_model else DEFAULT_MODEL
    if model != DEFAULT_MODEL:
        model = DEFAULT_MODEL

    return ResolvedModelConfig(
        provider=DEFAULT_PROVIDER,
        model=model,
        api_key=api_key,
    )


def _get_field(model_config: Any, field: str) -> Optional[str]:
    if isinstance(model_config, dict):
        return model_config.get(field)
    return getattr(model_config, field, None)
