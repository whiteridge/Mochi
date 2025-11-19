import os
from dotenv import load_dotenv
from composio import ComposioToolSet, App

# 1. Setup
load_dotenv()
api_key = os.getenv("COMPOSIO_API_KEY")
if not api_key:
    print("❌ Error: COMPOSIO_API_KEY not found in .env")
    exit(1)

print("--- Initializing Composio ToolSet ---")
toolset = ComposioToolSet(api_key=api_key)

user_id = "test_user_voice_app"
entity = toolset.get_entity(id=user_id)
print(f"--- Selected User: {user_id} ---")

try:
    print(f"--- Requesting Linear Auth link... ---")
    
    # Initiate the connection
    response = entity.initiate_connection(app_name="linear")
    
    # 🔍 DEBUG: Print the raw object so we can see the fields
    print(f"\n--- Raw Response Object ---")
    print(response)
    print(f"---------------------------\n")

    # 🛠️ AUTO-FIX: Try to find the URL in common fields
    url = None
    if hasattr(response, 'redirectUrl'):
        url = response.redirectUrl
    elif hasattr(response, 'redirect_url'):
        url = response.redirect_url
    elif hasattr(response, 'url'):
        url = response.url
    
    if url:
        print("\n✅ SUCCESS! Click the link below to authorize:")
        print("---------------------------------------------------")
        print(url)
        print("---------------------------------------------------\n")
    else:
        print("⚠️  Could not auto-detect the URL field name.")
        print("Please look at the 'Raw Response Object' printed above and copy the link manually.")

except Exception as e:
    print(f"\n❌ FAILED: {e}")