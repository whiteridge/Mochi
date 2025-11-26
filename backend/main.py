from fastapi import FastAPI, HTTPException
from fastapi.responses import StreamingResponse
from pydantic import BaseModel
from typing import List, Optional, Any
import json
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
        for event in agent_service.run_agent(user_input, request.user_id, chat_history=gemini_history):
            yield json.dumps(event) + "\n"

    return StreamingResponse(event_generator(), media_type="application/x-ndjson")

@app.get("/health")
def health_check():
    return {"status": "ok"}
