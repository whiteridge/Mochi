"""Tests for Gemini provider response parsing."""

from backend.llm.providers.gemini import _parse_response


class DummyFunctionCall:
    def __init__(self, name: str, args: dict):
        self.name = name
        self.args = args


class DummyPart:
    def __init__(self, text=None, thought=False, function_call=None):
        self.text = text
        self.thought = thought
        self.function_call = function_call


class DummyContent:
    def __init__(self, parts):
        self.parts = parts


class DummyCandidate:
    def __init__(self, parts):
        self.content = DummyContent(parts)


class DummyResponse:
    def __init__(self, parts):
        self.candidates = [DummyCandidate(parts)]


def test_parse_response_ignores_thought_text():
    response = DummyResponse(
        [
            DummyPart(text="internal reasoning that must never be shown", thought=True),
            DummyPart(text="Final concise answer."),
        ]
    )

    parsed = _parse_response(response)

    assert parsed.text == "Final concise answer."
    assert parsed.thoughts == ["Thinking..."]
    assert parsed.tool_calls == []


def test_parse_response_collects_tool_calls_and_keeps_answer_text():
    response = DummyResponse(
        [
            DummyPart(
                function_call=DummyFunctionCall(
                    "SLACK_SEND_MESSAGE",
                    {"channel": "C123", "markdown_text": "hello"},
                )
            ),
            DummyPart(text="Done."),
        ]
    )

    parsed = _parse_response(response)

    assert parsed.text == "Done."
    assert len(parsed.tool_calls) == 1
    assert parsed.tool_calls[0].name == "SLACK_SEND_MESSAGE"
    assert parsed.tool_calls[0].args == {"channel": "C123", "markdown_text": "hello"}
