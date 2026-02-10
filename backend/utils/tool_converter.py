"""Utility functions for converting Composio tools to Gemini format."""

from typing import Any, Dict, List, Optional
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


def _coerce_parameters(raw_params: Any) -> Dict[str, Any]:
    """Convert tool parameter payloads into a plain dict."""
    if raw_params is None:
        return {}
    if isinstance(raw_params, dict):
        return raw_params

    if hasattr(raw_params, "model_dump"):
        try:
            dumped = raw_params.model_dump()
            if isinstance(dumped, dict):
                return dumped
        except Exception:
            pass

    if hasattr(raw_params, "to_dict"):
        try:
            dumped = raw_params.to_dict()
            if isinstance(dumped, dict):
                return dumped
        except Exception:
            pass

    return {}


def _extract_tool_spec(tool: Any) -> Optional[Dict[str, Any]]:
    """
    Normalize heterogeneous Composio tool objects into:
    {"name": str, "description": str, "parameters": dict}
    """
    if isinstance(tool, dict):
        if tool.get("type") == "function" and "function" in tool:
            func_def = tool.get("function", {})
            return {
                "name": func_def.get("name", "unknown"),
                "description": func_def.get("description", "") or "",
                "parameters": _coerce_parameters(func_def.get("parameters", {})),
            }

        return {
            "name": tool.get("name", "unknown"),
            "description": tool.get("description", "") or "",
            "parameters": _coerce_parameters(tool.get("parameters", {})),
        }

    if hasattr(tool, "function_declarations"):
        return {"function_declarations": list(tool.function_declarations)}

    if hasattr(tool, "to_dict"):
        try:
            dumped = tool.to_dict()
            if isinstance(dumped, dict):
                return {
                    "name": dumped.get("name", "unknown"),
                    "description": dumped.get("description", "") or "",
                    "parameters": _coerce_parameters(dumped.get("parameters", {})),
                }
        except Exception:
            pass

    # composio.client ActionModel and similar Pydantic-style objects
    if hasattr(tool, "model_dump"):
        try:
            dumped = tool.model_dump()
            if isinstance(dumped, dict):
                return {
                    "name": dumped.get("name", getattr(tool, "name", "unknown")),
                    "description": dumped.get(
                        "description",
                        getattr(tool, "description", ""),
                    )
                    or "",
                    "parameters": _coerce_parameters(
                        dumped.get("parameters", getattr(tool, "parameters", {}))
                    ),
                }
        except Exception:
            pass

    if hasattr(tool, "name") and hasattr(tool, "parameters"):
        return {
            "name": getattr(tool, "name", "unknown"),
            "description": getattr(tool, "description", "") or "",
            "parameters": _coerce_parameters(getattr(tool, "parameters", {})),
        }

    return None


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
            spec = _extract_tool_spec(tool)
            if spec is None:
                print(f"DEBUG: Unknown tool format: {type(tool)}", flush=True)
                continue

            existing_fds = spec.get("function_declarations")
            if existing_fds is not None:
                for fd in existing_fds:
                    function_declarations.append(fd)
                continue

            tool_name = spec.get("name", "unknown")
            description = spec.get("description", "")
            raw_params = _coerce_parameters(spec.get("parameters", {}))
            _sanitize_schema_dict(raw_params)
            params = clean_schema(raw_params)

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


















