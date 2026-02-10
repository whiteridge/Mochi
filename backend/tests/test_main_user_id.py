"""Unit tests for chat user-id resolution."""

from backend.main import _resolve_effective_user_id


def test_resolve_effective_user_id_prefers_request(monkeypatch):
    monkeypatch.setenv("COMPOSIO_USER_ID", "env-user")
    effective, source = _resolve_effective_user_id("request-user")

    assert effective == "request-user"
    assert source == "request"


def test_resolve_effective_user_id_falls_back_to_env(monkeypatch):
    monkeypatch.setenv("COMPOSIO_USER_ID", "env-user")
    effective, source = _resolve_effective_user_id("   ")

    assert effective == "env-user"
    assert source == "fallback"
