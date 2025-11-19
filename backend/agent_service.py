import os
import time
from typing import Dict, Any, List, Optional
from dotenv import load_dotenv
from google import genai
from google.genai import types
from google.genai import errors as genai_errors
from composio import Composio
from composio_gemini import GeminiProvider

load_dotenv()

class AgentService:
    def __init__(self):
        self.api_key = os.getenv("GOOGLE_API_KEY")
        if not self.api_key:
            raise ValueError("GOOGLE_API_KEY environment variable is required")
        self.client = genai.Client(api_key=self.api_key)
        
        # Initialize Composio
        # Note: API key for Composio is picked up from COMPOSIO_API_KEY env var by default if not passed
        self.composio = Composio(provider=GeminiProvider())

    def run_agent(self, user_input: str, user_id: str) -> Dict[str, Any]:
        """
        Runs the agent with the given user input and user_id.
        Executes tools if necessary and returns the final response.
        """
        print(f"Running agent for user: {user_id} with input: {user_input}")
        
        # 1. Get tools for the user (Linear)
        # We assume the user is already connected.
        try:
            composio_tools = self.composio.tools.get(
                user_id=user_id, 
                toolkits=["LINEAR"]
            )
        except Exception as e:
            return {
                "response": f"Error fetching tools: {str(e)}. Please ensure you are connected to Linear.",
                "action_performed": None
            }

        # 2. Convert to Gemini format
        gemini_tools = [
            types.Tool(function_declarations=[tool.function_declarations[0]])
            for tool in composio_tools
            if tool.function_declarations
        ]

        # 3. Configure Gemini
        config = types.GenerateContentConfig(
            tools=gemini_tools,
        )

        # 4. Start Chat
        chat = self.client.chats.create(model="gemini-2.5-flash", config=config)
        
        try:
            # Initial message
            response = chat.send_message(user_input)
            
            action_performed = None
            
            # 5. Handle Tool Execution Loop
            # We allow a few iterations for multi-step actions if needed, but usually 1-2 is enough for "Create ticket"
            max_iterations = 5
            for _ in range(max_iterations):
                # Check if the model wants to call a function
                # The GeminiProvider.handle_response helper executes the tool and returns the result
                function_responses, executed = GeminiProvider.handle_response(response, composio_tools)
                
                if executed:
                    print("Tool executed. Sending results back to model.")
                    # Capture metadata about the action if available
                    # function_responses is a list of Part objects or similar, we might want to parse it for the UI
                    # For now, we'll just store that an action happened.
                    # In a real app, we might parse the 'result' from the tool execution to get the Issue URL.
                    # The 'executed' flag just means *some* tool ran.
                    
                    # We can try to inspect the last tool call result if we want specific metadata
                    # But for now, let's just proceed to get the final text.
                    
                    # Send tool outputs back to Gemini
                    response = chat.send_message(function_responses)
                    
                    # If we successfully executed a tool, we can try to extract info for the UI
                    # This is a simplification; ideally we'd look at the specific tool name and output.
                    action_performed = "Linear Action Executed" 
                else:
                    # No more tool calls, we have the final text response
                    break
            
            return {
                "response": response.text,
                "action_performed": action_performed
            }

        except Exception as e:
            print(f"Error in agent execution: {e}")
            return {
                "response": f"An error occurred: {str(e)}",
                "action_performed": None
            }
