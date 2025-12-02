import os
from pathlib import Path

from dotenv import load_dotenv  # pip install python-dotenv
from composio import Composio

# 1. Load backend/.env so we get COMPOSIO_API_KEY
env_path = Path(__file__).parent / "backend" / ".env"
load_dotenv(env_path)

COMPOSIO_API_KEY = os.environ["COMPOSIO_API_KEY"]

# Single local user for now – this must match what you later use in the backend
USER_ID = "caddyai-default"

composio = Composio(api_key=COMPOSIO_API_KEY)


def get_or_create_slack_auth_config_id() -> str:
    """Return an auth_config_id for the Slack toolkit.

    If one already exists, reuse it; otherwise create a new one using
    Composio-managed OAuth (no custom Slack app needed for dev).
    """
    auth_configs = composio.auth_configs.list()

    # Look for an existing SLACK auth config
    for auth_config in auth_configs.items:
        # Different SDK versions may use "toolkit" like "SLACK" or "slack"
        if str(auth_config.toolkit).upper() == "SLACK":
            print(f"Using existing Slack auth config: {auth_config.id}")
            return auth_config.id

    # None found → create one using Composio managed auth
    print("No Slack auth config found. Creating one with managed auth...")
    new_auth_config = composio.auth_configs.create(
        toolkit="SLACK",  # if this ever fails, try "slack"
        options={
            "type": "use_composio_managed_auth",
        },
    )
    print(f"Created Slack auth config: {new_auth_config.id}")
    return new_auth_config.id


def authenticate_slack(user_id: str, auth_config_id: str) -> str:
    """Kick off OAuth for Slack and wait until you approve it in the browser."""
    connection_request = composio.connected_accounts.initiate(
        user_id=user_id,
        auth_config_id=auth_config_id,
    )

    print("\nVisit this URL to authenticate Slack:\n")
    print(connection_request.redirect_url)
    print("\nWaiting for you to complete the auth flow...")

    # Wait until OAuth flow is finished
    connection_request.wait_for_connection(timeout=300)

    connected = composio.connected_accounts.get(connection_request.id)
    print(f"\n✅ Slack connected! Connected account id: {connected.id}")
    return connected.id


if __name__ == "__main__":
    slack_auth_config_id = get_or_create_slack_auth_config_id()
    authenticate_slack(USER_ID, slack_auth_config_id)
