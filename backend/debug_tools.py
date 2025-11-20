from composio import Composio, App
import os
from dotenv import load_dotenv

load_dotenv()

def search_tools():
    try:
        print("Initializing Composio...")
        composio = Composio()
        
        print("Fetching ALL actions (limit 10000)...")
        try:
            # Try passing limit
            actions = composio.actions.get(limit=10000)
            print(f"Fetched {len(actions)} actions.")
            
            linear = [a for a in actions if 'linear' in a.name.lower()]
            print(f"Found {len(linear)} Linear actions:")
            for a in linear:
                print(a.name)
                
        except Exception as e:
            print(f"Error fetching with limit: {e}")
            
            # Fallback: try to iterate?
            # No iterator exposed.

    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    search_tools()
