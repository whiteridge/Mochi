"""Router for selecting LLM providers."""

from __future__ import annotations

from dataclasses import dataclass
from typing import Any, Dict, List, Optional, Tuple
import os

from llm.types import LLMChat
from llm.providers.gemini import GeminiChat
from llm.providers.openai_compat import OpenAICompatChat, DEFAULT_BASE_URL as OPENAI_DEFAULT_BASE
from llm.providers.anthropic import AnthropicChat, DEFAULT_BASE_URL as ANTHROPIC_DEFAULT_BASE


DEFAULT_MODELS = {
    "google": "gemini-2.5-flash",
    "openai": "gpt-4o",
    "anthropic": "claude-3-5-sonnet",
    "ollama": "llama3",
    "lmstudio": "llama3",
    "custom_openai": "llama3",
}


@dataclass
class ResolvedModelConfig:
    provider: str
    model: str
    api_key: Optional[str]
    base_url: Optional[str]


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
    provider = resolved.provider

    if provider == "google":
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

    if provider in {"openai", "ollama", "lmstudio", "custom_openai"}:
        base_url = resolved.base_url
        if not base_url:
            raise ModelConfigError("Missing base URL for OpenAI-compatible provider")
        if provider == "openai" and not resolved.api_key:
            raise ModelConfigError("Missing OPENAI_API_KEY for OpenAI provider")
        return (
            OpenAICompatChat(
                api_key=resolved.api_key,
                base_url=base_url,
                model=resolved.model,
                tools=tools,
                history=history,
                user_context=user_context,
            ),
            resolved,
        )

    if provider == "anthropic":
        if not resolved.api_key:
            raise ModelConfigError("Missing ANTHROPIC_API_KEY for Anthropic provider")
        return (
            AnthropicChat(
                api_key=resolved.api_key,
                model=resolved.model,
                tools=tools,
                history=history,
                user_context=user_context,
                base_url=resolved.base_url,
            ),
            resolved,
        )

    raise ModelConfigError(f"Unsupported provider: {provider}")


def _resolve_model_config(
    model_config: Optional[Any],
    fallback_api_key: Optional[str],
) -> ResolvedModelConfig:
    if model_config is None:
        provider = "google"
        model = DEFAULT_MODELS[provider]
        api_key = fallback_api_key or os.getenv("GOOGLE_API_KEY")
        base_url = None
        return ResolvedModelConfig(provider, model, api_key, base_url)

    provider = (getattr(model_config, "provider", None) or "google").lower()
    provider = provider.replace(" ", "")
    if provider == "lmstudio":
        provider = "lmstudio"
    if provider == "customopenai":
        provider = "custom_openai"

    model = getattr(model_config, "model", None) or DEFAULT_MODELS.get(provider, "")
    api_key = getattr(model_config, "api_key", None)
    base_url = getattr(model_config, "base_url", None)

    if provider == "google":
        api_key = api_key or os.getenv("GOOGLE_API_KEY") or fallback_api_key
    elif provider == "openai":
        api_key = api_key or os.getenv("OPENAI_API_KEY")
        base_url = base_url or OPENAI_DEFAULT_BASE
    elif provider == "anthropic":
        api_key = api_key or os.getenv("ANTHROPIC_API_KEY")
        base_url = base_url or ANTHROPIC_DEFAULT_BASE
    elif provider == "ollama":
        base_url = base_url or "http://localhost:11434/v1"
    elif provider == "lmstudio":
        base_url = base_url or "http://localhost:1234/v1"
    elif provider == "custom_openai":
        base_url = base_url or None

    return ResolvedModelConfig(provider, model, api_key, base_url)
