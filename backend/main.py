from fastapi import FastAPI, HTTPException
from fastapi.responses import StreamingResponse
from pydantic import BaseModel
from typing import List, Optional, Any
import json
import os
from agent_service import AgentService
from services.composio_service import ComposioService

app = FastAPI(title="CaddyAI Backend")

# Initialize Composio Service (for integrations)
try:
    composio_service = ComposioService()
except Exception as e:
    print(f"Warning: Failed to initialize ComposioService: {e}")
    composio_service = None

# Initialize Agent Service
try:
    agent_service = AgentService(composio_service=composio_service)
except Exception as e:
    print(f"Warning: Failed to initialize AgentService: {e}")
    agent_service = None

class ChatMessage(BaseModel):
    role: str
    content: str

class ModelConfig(BaseModel):
    provider: Optional[str] = None
    model: Optional[str] = None
    api_key: Optional[str] = None
    base_url: Optional[str] = None

class ChatRequest(BaseModel):
    messages: List[ChatMessage]
    user_id: str
    confirmed_tool: Optional[dict] = None  # For multi-app: {"tool": "...", "args": {...}, "app_id": "..."}
    user_timezone: Optional[str] = None
    api_key: Optional[str] = None
    model: Optional[ModelConfig] = None

# ChatResponse model is no longer used for the return type of the endpoint directly, 
# but the events yielded will match the structure we want.
# We'll keep it for reference or if we want to document the event structure.

def _resolve_agent_service() -> AgentService | None:
    return agent_service


@app.post("/api/chat")
async def chat_endpoint(request: ChatRequest):
    service = _resolve_agent_service()
    if not service:
        raise HTTPException(
            status_code=500,
            detail="Agent service not initialized (check COMPOSIO_API_KEY)",
        )
    
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
            "parts": msg.content
        })

    print(
        "DEBUG: Incoming chat request",
        {
            "user_id": request.user_id,
            "has_confirmed_tool": request.confirmed_tool is not None,
            "confirmed_tool": request.confirmed_tool,
        },
        flush=True,
    )

    # Create a generator that yields JSON strings followed by a newline
    def event_generator():
        # Use configured user_id if available (for dev/single-user mode), otherwise use request user_id
        effective_user_id = os.getenv("COMPOSIO_USER_ID", request.user_id)
        print(f"DEBUG: Using effective user_id: {effective_user_id}")
        
        for event in service.run_agent(
            user_input,
            effective_user_id,
            chat_history=gemini_history,
            confirmed_tool=request.confirmed_tool,
            user_timezone=request.user_timezone,
            model_config=request.model,
            fallback_api_key=request.api_key,
        ):
            yield json.dumps(event) + "\n"

    return StreamingResponse(event_generator(), media_type="application/x-ndjson")

@app.get("/api/v1/integrations/connect/{app_name}")
async def get_connect_url(app_name: str, user_id: str):
    """Get the Composio authorization URL for the specified app."""
    if not composio_service:
        raise HTTPException(status_code=500, detail="Composio service not initialized")
        
    try:
        # We can pass a callback_url if we want the user to be redirected back 
        # to a web page or deep link. For now, we'll let Composio use its default.
        url = composio_service.get_auth_url(app_name, user_id)
        return {"url": url}
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

@app.get("/api/v1/integrations/status/{app_name}")
async def get_integration_status(app_name: str, user_id: str):
    """Check if the user is connected to the specified app via Composio."""
    if not composio_service:
        raise HTTPException(status_code=500, detail="Composio service not initialized")
        
    try:
        details = composio_service.get_connection_details(app_name, user_id)
        return {
            "connected": details.get("connected", False),
            "status": details.get("status"),
            "action_required": details.get("action_required", False),
        }
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

@app.delete("/api/v1/integrations/disconnect/{app_name}")
async def disconnect_integration(app_name: str, user_id: str):
    """Disconnect the user from the specified app via Composio."""
    if not composio_service:
        raise HTTPException(status_code=500, detail="Composio service not initialized")
        
    try:
        count = composio_service.disconnect_app(app_name, user_id)
        return {"disconnected": True, "accounts_removed": count}
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

@app.get("/health")
def health_check():
    return {"status": "ok"}
