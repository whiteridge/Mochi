"""Utility functions for converting Composio tools to Gemini format."""

from typing import Any, List, Dict
from google.genai import types


def clean_schema(obj: Any, is_property_definition: bool = False) -> Any:
    """
    Remove unsupported fields from JSON schema for Gemini API.
    
    Args:
        obj: The schema object to clean (dict, list, or primitive)
        is_property_definition: Whether this is a property definition (affects which fields to remove)
        
    Returns:
        The cleaned schema object
    """
    if isinstance(obj, dict):
        # Metadata fields that should be removed from property type definitions
        # but NOT from the properties dict itself (where they are property names)
        metadata_fields = {'additional_properties', 'additionalProperties', 'default', '$schema', 'nullable'}
        # 'title' is only a metadata field inside property definitions, not a property name
        if is_property_definition:
            metadata_fields.add('title')
        
        cleaned = {}
        
        # First pass: collect property names
        raw_properties = obj.get('properties', {})
        
        # Allowed keys for Gemini Schema
        allowed_keys = {
            "type", "format", "title", "description", "nullable",
            "default", "items", "minItems", "maxItems", "enum",
            "properties", "required", "minimum", "maximum",
            "minLength", "maxLength", "pattern", "example", "anyOf",
            "additionalProperties",
        }

        for key, value in obj.items():
            # Skip keys not in allowed set
            if key not in allowed_keys:
                continue
            
            # Skip metadata fields that shouldn't be in property definitions
            if key in metadata_fields:
                continue
            
            # Special handling for 'required' array - filter to only existing properties
            if key == 'required' and isinstance(value, list):
                valid_required = [r for r in value if r in raw_properties]
                if valid_required:
                    cleaned[key] = valid_required
                # Skip 'required' if empty or no valid fields
            # Convert type strings to lowercase for Gemini compatibility
            elif key == 'type' and isinstance(value, str):
                cleaned[key] = value.lower()
            # 'properties' contains property definitions - values should be cleaned as definitions
            elif key == 'properties' and isinstance(value, dict):
                cleaned_props = {}
                for prop_name, prop_def in value.items():
                    cleaned_props[prop_name] = clean_schema(prop_def, is_property_definition=True)
                cleaned[key] = cleaned_props
            # 'items' for array types is also a property definition
            elif key == 'items':
                cleaned[key] = clean_schema(value, is_property_definition=True)
            else:
                cleaned[key] = clean_schema(value, is_property_definition=False)
        
        return cleaned
    elif isinstance(obj, list):
        return [clean_schema(item, is_property_definition) for item in obj]
    else:
        return obj



def _sanitize_schema_dict(d: Dict[str, Any]) -> None:
    """
    In-place remove keys that the Gemini Schema proto does not support.
    Recursively cleans nested dictionaries and lists.
    """
    if not isinstance(d, dict):
        return

    # Remove known-bad keys
    # humanParameterDescription is the main culprit causing proto parsing errors
    keys_to_remove = ["humanParameterDescription"]
    for k in keys_to_remove:
        d.pop(k, None)

    # Recurse into nested dicts/lists
    for key, value in list(d.items()):
        if isinstance(value, dict):
            _sanitize_schema_dict(value)
        elif isinstance(value, list):
            for item in value:
                if isinstance(item, dict):
                    _sanitize_schema_dict(item)


def convert_to_gemini_tools(composio_tools: List[Any]) -> List[types.Tool]:
    """
    Convert Composio FunctionDeclarations to google-genai format.
    
    Args:
        composio_tools: List of tool objects from Composio
        
    Returns:
        List of google.genai.types.Tool objects
    """
    function_declarations = []
    
    for tool in composio_tools:
        try:
            tool_name = "unknown"
            description = ""
            params = {}
            
            # Case 1: Raw Dict (OpenAI format from Composio without provider)
            if isinstance(tool, dict):
                # Check if it's wrapped in {"type": "function", "function": {...}}
                if tool.get("type") == "function" and "function" in tool:
                    func_def = tool["function"]
                    tool_name = func_def.get("name", "unknown")
                    description = func_def.get("description", "")
                    raw_params = func_def.get("parameters", {})
                else:
                    # Maybe it's the function dict directly?
                    tool_name = tool.get("name", "unknown")
                    description = tool.get("description", "")
                    raw_params = tool.get("parameters", {})
                
                # Sanitize parameters
                _sanitize_schema_dict(raw_params)
                params = clean_schema(raw_params)
                
            # Case 2: FunctionDeclaration object (from VertexAI/GoogleProvider)
            elif hasattr(tool, 'to_dict'):
                # Convert to dict and then to google-genai format
                tool_dict = tool.to_dict()
                tool_name = tool_dict.get('name', 'unknown')
                
                # Clean the parameters to remove unsupported fields
                raw_params = tool_dict.get('parameters', {})
                _sanitize_schema_dict(raw_params)
                params = clean_schema(raw_params)
                
            # Case 3: Already in Tool format (google-genai)
            elif hasattr(tool, 'function_declarations'):
                # Already in Tool format, extract function declarations
                for fd in tool.function_declarations:
                    function_declarations.append(fd)
                continue
            else:
                print(f"DEBUG: Unknown tool format: {type(tool)}", flush=True)
                continue

            # Create a FunctionDeclaration in google-genai format
            func_decl = types.FunctionDeclaration(
                name=tool_name,
                description=description,
                parameters=params
            )
            function_declarations.append(func_decl)
            
        except Exception as tool_error:
            print(f"DEBUG: Failed to convert tool {tool_name if 'tool_name' in locals() else 'unknown'}: {tool_error}", flush=True)
            continue
    
    # Combine all function declarations into a single Tool
    if function_declarations:
        return [types.Tool(function_declarations=function_declarations)]
    
    return []



















