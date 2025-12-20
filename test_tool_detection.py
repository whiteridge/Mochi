#!/usr/bin/env python3
"""
Test to verify _is_write_action works with uppercase tool names
"""

def _is_write_action(tool_name: str, tool_args: dict) -> bool:
    """
    Detect if a tool represents a Write action that requires user confirmation.
    Composio tool names are UPPERCASE (e.g., LINEAR_CREATE_LINEAR_ISSUE),
    so we need case-insensitive matching.
    """
    tool_name_lower = tool_name.lower()
    
    # Check for common write prefixes
    write_prefixes = ["create_", "update_", "delete_", "remove_", "manage_"]
    if any(prefix in tool_name_lower for prefix in write_prefixes):
        print(f"✅ Detected WRITE action (prefix match): {tool_name}")
        return True
    
    # Special case: GraphQL mutations via run_query_or_mutation
    if "run_query_or_mutation" in tool_name_lower:
        query = tool_args.get("query", "").strip().lower()
        if query.startswith("mutation"):
            print(f"✅ Detected WRITE action (mutation): {tool_name}")
            return True
    
    print(f"📖 Detected READ action: {tool_name}")
    return False

def test_tool_detection():
    """Test various tool names"""
    print("=== Testing Tool Detection ===\n")
    
    test_cases = [
        # (tool_name, args, expected_result, description)
        ("LINEAR_CREATE_LINEAR_ISSUE", {}, True, "Uppercase CREATE"),
        ("linear_create_linear_issue", {}, True, "Lowercase create"),
        ("LINEAR_UPDATE_ISSUE", {}, True, "Uppercase UPDATE"),
        ("LINEAR_DELETE_ISSUE", {}, True, "Uppercase DELETE"),
        ("LINEAR_LIST_LINEAR_TEAMS", {}, False, "Uppercase LIST (read)"),
        ("LINEAR_GET_ISSUE", {}, False, "Uppercase GET (read)"),
        ("LINEAR_RUN_QUERY_OR_MUTATION", {"query": "mutation { createIssue }"}, True, "Mutation via GraphQL"),
        ("LINEAR_RUN_QUERY_OR_MUTATION", {"query": "query { issues }"}, False, "Query via GraphQL"),
    ]
    
    passed = 0
    failed = 0
    
    for tool_name, args, expected, description in test_cases:
        result = _is_write_action(tool_name, args)
        status = "✅ PASS" if result == expected else "❌ FAIL"
        
        if result == expected:
            passed += 1
        else:
            failed += 1
            
        print(f"{status}: {description}")
        print(f"   Tool: {tool_name}")
        print(f"   Expected: {'WRITE' if expected else 'READ'}, Got: {'WRITE' if result else 'READ'}")
        print()
    
    print(f"\nResults: {passed}/{len(test_cases)} passed")
    
    if failed == 0:
        print("🎉 All tests passed!")
        return 0
    else:
        print(f"⚠️  {failed} test(s) failed")
        return 1

if __name__ == "__main__":
    exit(test_tool_detection())
