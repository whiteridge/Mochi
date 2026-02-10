from types import SimpleNamespace
from unittest.mock import MagicMock, patch

from backend.services.composio_service import ComposioService


def test_execute_tool_uses_entity_execute_for_client_api():
    with patch("backend.services.composio_service.Composio"), patch(
        "backend.services.composio_service.os.getenv", return_value="fake_key"
    ):
        service = ComposioService()

    fake_entity = MagicMock()
    fake_entity.execute.return_value = {"data": {"teams": []}, "successful": True}

    fake_actions = MagicMock()
    fake_client = SimpleNamespace(
        actions=fake_actions,
        get_entity=MagicMock(return_value=fake_entity),
    )
    service.composio = fake_client

    with patch.object(service, "_resolve_client_action", return_value="ACTION_OBJ"):
        result = service.execute_tool(
            slug="linear_list_linear_teams",
            arguments={},
            user_id="u-123",
        )

    service.composio.get_entity.assert_called_once_with(id="u-123")
    fake_entity.execute.assert_called_once_with(action="ACTION_OBJ", params={})
    assert not fake_actions.execute.called
    assert result["data"]["teams"] == []
