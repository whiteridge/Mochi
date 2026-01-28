from unittest.mock import MagicMock, patch

from backend.services.composio_service import ComposioService


def _make_accounts(items):
    response = MagicMock()
    response.items = items
    return response


def test_get_connection_details_prefers_active():
    with patch("backend.services.composio_service.Composio") as MockComposioSDK, \
         patch("backend.services.composio_service.os.getenv", return_value="fake_key"):
        service = ComposioService()

        accounts = _make_accounts([
            {"id": "acc_expired", "status": "EXPIRED", "toolkit": {"slug": "slack"}},
            {"id": "acc_active", "status": "ACTIVE", "toolkit": {"slug": "slack"}},
            {"id": "acc_other", "status": "ACTIVE", "toolkit": {"slug": "github"}},
        ])
        service.composio.connected_accounts.list.return_value = accounts

        details = service.get_connection_details("slack", "user_1")

        assert details["connected"] is True
        assert details["status"] == "ACTIVE"
        assert details["account_id"] == "acc_active"
        assert details["action_required"] is False


def test_get_connection_details_flags_action_required():
    with patch("backend.services.composio_service.Composio") as MockComposioSDK, \
         patch("backend.services.composio_service.os.getenv", return_value="fake_key"):
        service = ComposioService()

        accounts = _make_accounts([
            {"id": "acc_expired", "status": "EXPIRED", "toolkit": {"slug": "slack"}},
        ])
        service.composio.connected_accounts.list.return_value = accounts

        details = service.get_connection_details("slack", "user_1")

        assert details["connected"] is False
        assert details["status"] == "EXPIRED"
        assert details["account_id"] == "acc_expired"
        assert details["action_required"] is True
