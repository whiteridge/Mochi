from fastapi import FastAPI, HTTPException
from fastapi.responses import StreamingResponse
from pydantic import BaseModel
from typing import List, Optional, Any
import json
import os
from agent_service import AgentService

app = FastAPI(title="CaddyAI Backend")

# Initialize Agent Service
# We initialize it once at startup
try:
    agent_service = AgentService()
except Exception as e:
    print(f"Warning: Failed to initialize AgentService: {e}")
    agent_service = None

class ChatMessage(BaseModel):
    role: str
    content: str

class ChatRequest(BaseModel):
    messages: List[ChatMessage]
    user_id: str
    confirmed_tool: Optional[dict] = None  # For multi-app: {"tool": "...", "args": {...}, "app_id": "..."}
    user_timezone: Optional[str] = None

# ChatResponse model is no longer used for the return type of the endpoint directly, 
# but the events yielded will match the structure we want.
# We'll keep it for reference or if we want to document the event structure.

@app.post("/api/chat")
async def chat_endpoint(request: ChatRequest):
    if not agent_service:
        raise HTTPException(status_code=500, detail="Agent service not initialized (check API keys)")
    
    # Extract the latest user message
    user_input = next((m.content for m in reversed(request.messages) if m.role == "user"), None)
    
    if not user_input:
        raise HTTPException(status_code=400, detail="No user message found")

    # Construct History (All messages EXCEPT the last one, which is user_input)
    # We assume the last message is the current one we are processing.
    history_messages = request.messages[:-1]
    
    gemini_history = []
    for msg in history_messages:
        role = "user" if msg.role == "user" else "model"
        gemini_history.append({
            "role": role,
            "parts": [msg.content]
        })

    # Create a generator that yields JSON strings followed by a newline
    def event_generator():
        # Use configured user_id if available (for dev/single-user mode), otherwise use request user_id
        effective_user_id = os.getenv("COMPOSIO_USER_ID", request.user_id)
        print(f"DEBUG: Using effective user_id: {effective_user_id}")
        
        for event in agent_service.run_agent(
            user_input,
            effective_user_id,
            chat_history=gemini_history,
            confirmed_tool=request.confirmed_tool,
            user_timezone=request.user_timezone,
        ):
            yield json.dumps(event) + "\n"

    return StreamingResponse(event_generator(), media_type="application/x-ndjson")

@app.get("/api/v1/integrations/connect/{app_name}")
async def get_connect_url(app_name: str, user_id: str):
    """Get the Composio authorization URL for the specified app."""
    if not agent_service:
        raise HTTPException(status_code=500, detail="Agent service not initialized")
        
    try:
        # We can pass a callback_url if we want the user to be redirected back 
        # to a web page or deep link. For now, we'll let Composio use its default.
        url = agent_service.composio_service.get_auth_url(app_name, user_id)
        return {"url": url}
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

@app.get("/api/v1/integrations/status/{app_name}")
async def get_integration_status(app_name: str, user_id: str):
    """Check if the user is connected to the specified app via Composio."""
    if not agent_service:
        raise HTTPException(status_code=500, detail="Agent service not initialized")
        
    try:
        is_connected = agent_service.composio_service.get_connection_status(app_name, user_id)
        return {"connected": is_connected}
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

@app.delete("/api/v1/integrations/disconnect/{app_name}")
async def disconnect_integration(app_name: str, user_id: str):
    """Disconnect the user from the specified app via Composio."""
    if not agent_service:
        raise HTTPException(status_code=500, detail="Agent service not initialized")
        
    try:
        count = agent_service.composio_service.disconnect_app(app_name, user_id)
        return {"disconnected": True, "accounts_removed": count}
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

@app.get("/health")
def health_check():
    return {"status": "ok"}
