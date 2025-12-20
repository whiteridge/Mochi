from composio import ComposioToolSet
from composio_gemini import GeminiProvider
from dotenv import load_dotenv
load_dotenv()

try:
    toolset = ComposioToolSet()
    print("ComposioToolSet initialized")
    print(f"Instance has get_tools: {hasattr(toolset, 'get_tools')}")

    tools_req = ["linear_create_linear_issue"]
    
    # Try get_action_schemas
    if hasattr(toolset, 'get_action_schemas'):
        schemas = toolset.get_action_schemas(actions=tools_req)
        print(f"Got schemas: {len(schemas)}")
        
        # Try wrapping
        if hasattr(GeminiProvider, 'wrap_tools'):
            gemini_tools = GeminiProvider.wrap_tools(schemas)
            print(f"Wrapped tools: {len(gemini_tools)}")
            print(f"Tool type: {type(gemini_tools[0])}")
            print(f"Tool content: {gemini_tools[0]}")
        else:
            print("GeminiProvider has no wrap_tools")
            
    else:
        print("ComposioToolSet has no get_action_schemas")

except Exception as e:
    print(f"Error: {e}")
