"""Utility functions for chat history formatting."""

from typing import Dict, List
from google.genai import types


def format_history(history: List[Dict[str, str]]) -> List[types.Content]:
    """
    Formats the chat history into the structure expected by Gemini SDK.
    
    Args:
        history: List of message dictionaries with 'role' and 'parts' keys
        
    Returns:
        List of types.Content objects for Gemini SDK
    """
    formatted_history = []
    for msg in history:
        role = msg.get("role", "user")
        content = msg.get("parts", [])
        
        # Handle case where content might be a string (from simple dicts)
        if isinstance(content, str):
            parts = [types.Part(text=content)]
        elif isinstance(content, list):
            # Assuming list of strings or dicts, normalize to types.Part
            parts = []
            for part in content:
                if isinstance(part, str):
                    parts.append(types.Part(text=part))
                elif isinstance(part, dict) and "text" in part:
                    parts.append(types.Part(text=part["text"]))
        else:
            parts = [types.Part(text=str(content))]
            
        formatted_history.append(types.Content(role=role, parts=parts))
        
    return formatted_history







