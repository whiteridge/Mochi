from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from typing import List, Optional, Any
from backend.agent_service import AgentService

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

class ChatResponse(BaseModel):
    response: str
    action_performed: Optional[str] = None

@app.post("/api/chat", response_model=ChatResponse)
async def chat_endpoint(request: ChatRequest):
    if not agent_service:
        raise HTTPException(status_code=500, detail="Agent service not initialized (check API keys)")
    
    # Extract the latest user message
    # In a real chat, we might send the whole history, but for now the agent logic takes a single string
    user_input = next((m.content for m in reversed(request.messages) if m.role == "user"), None)
    
    if not user_input:
        raise HTTPException(status_code=400, detail="No user message found")

    result = agent_service.run_agent(user_input, request.user_id)
    
    return ChatResponse(
        response=result["response"],
        action_performed=result["action_performed"]
    )

@app.get("/health")
def health_check():
    return {"status": "ok"}
