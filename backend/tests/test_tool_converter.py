from backend.utils.tool_converter import convert_to_gemini_tools


class FakeActionModel:
    def __init__(self):
        self.name = "SLACK_SEND_MESSAGE"
        self.description = "Send a message."
        self.parameters = {
            "type": "OBJECT",
            "properties": {
                "channel": {
                    "type": "STRING",
                    "humanParameterDescription": "Channel id",
                },
                "text": {"type": "STRING"},
            },
            "required": ["channel", "text"],
        }

    def model_dump(self):
        return {
            "name": self.name,
            "description": self.description,
            "parameters": self.parameters,
        }


class FakeAttrTool:
    def __init__(self):
        self.name = "LINEAR_LIST_LINEAR_TEAMS"
        self.description = "List teams."
        self.parameters = {
            "type": "object",
            "properties": {},
        }


def test_convert_supports_model_dump_action_model():
    tools = [FakeActionModel()]

    converted = convert_to_gemini_tools(tools)

    assert len(converted) == 1
    assert len(converted[0].function_declarations) == 1
    declaration = converted[0].function_declarations[0]
    assert declaration.name == "SLACK_SEND_MESSAGE"
    assert declaration.description == "Send a message."
    params_text = str(declaration.parameters)
    assert "humanParameterDescription" not in params_text


def test_convert_supports_attribute_style_tool():
    tools = [FakeAttrTool()]

    converted = convert_to_gemini_tools(tools)

    assert len(converted) == 1
    assert len(converted[0].function_declarations) == 1
    declaration = converted[0].function_declarations[0]
    assert declaration.name == "LINEAR_LIST_LINEAR_TEAMS"
