import os
from composio import Composio

API_KEY = os.environ["COMPOSIO_API_KEY"]
USER_ID = os.environ.get("COMPOSIO_USER_ID", "caddyai-default")

client = Composio(api_key=API_KEY)

# 1. Get or create an auth config for Linear (using Composio's default OAuth)
def get_or_create_linear_auth_config_id() -> str:
    existing = client.auth_configs.list(app="linear")
    if existing.data:
        return existing.data[0].id

    created = client.auth_configs.create(app="linear")
    return created.id


auth_config_id = get_or_create_linear_auth_config_id()

# 2. Create a connection request for this user + auth config
connection_request = client.connected_accounts.link(
    user_id=USER_ID,
    auth_config_id=auth_config_id,
)

print("👉 Open this URL in your browser to connect Linear:")
print(connection_request.redirect_url)

# (optional) wait until the user finishes the OAuth flow
try:
    connected_account = connection_request.wait_for_connection()
    print("✅ Linear connected! Connected account id:", connected_account.id)
except Exception as e:
    print("Waiting for connection failed (you can ignore this if you already finished OAuth):", e)
