#!/usr/bin/env python3
"""
Tools-Bank MCP Server
=====================
Exposes memory/embedding tools via MCP protocol to Claude Code
"""

import sys
import json
import os
from pathlib import Path

# Set API key from hardcoded value
os.environ["MINIMAX_API_KEY"] = "sk-cp-4ErelSlnFkyo49Uc8H8RRZXr56LTT2jMrCRnWZp7aS0pmsJhfgNWn5VXX5aN9evd_XR5ExUknnFQSMBq6g4aeQrM2b5x2B1tuQARg076L81g3PBTJJmnH6A"

# Supabase config for entity_graph and memory_notes
SB_URL = "https://zqnexqbdfvbhlxzelzju.supabase.co"
SB_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpxbmV4cWJkZnZiaGx4emVsemp1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzIzMDE4OTksImV4cCI6MjA4Nzg3Nzg5OX0.VggKv3KsmXm7C1LqBxCJaMj2yLQh10iRwSXMtuC4cmc"
SB_HEADERS = {"apikey": SB_KEY, "Authorization": f"Bearer {SB_KEY}"}
import urllib.request, urllib.parse

# Paths
TOOLSBANK_ROOT = "/root/egesut-erp1/tools-bank"
MEMORY_TOOLS = f"{TOOLSBANK_ROOT}/memory"
MEMORY_DB = f"{TOOLSBANK_ROOT}/memory/memory.db"
KNOWLEDGE_GRAPH_DB = f"{TOOLSBANK_ROOT}/memory/knowledge_graph.db"

# Protocol version
PROTOCOL_VERSION = "2024-11-05"

def log(msg):
    """Debug logging to stderr"""
    print(msg, file=sys.stderr, flush=True)

def send_response(req_id, result):
    """Send JSON-RPC success response"""
    response = {"jsonrpc": "2.0", "id": req_id, "result": result}
    print(json.dumps(response), flush=True)

def send_error(req_id, code, message):
    """Send JSON-RPC error response"""
    response = {"jsonrpc": "2.0", "id": req_id, "error": {"code": code, "message": message}}
    print(json.dumps(response), flush=True)

def get_supabase(table, filters="", select="*", limit=20):
    """Supabase REST GET with urllib (no external deps)"""
    url = f"{SB_URL}/rest/v1/{table}?select={urllib.parse.quote(select)}"
    if filters:
        url += f"&{filters}"
    url += f"&limit={limit}"
    req = urllib.request.Request(url, headers=SB_HEADERS)
    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            data = json.loads(resp.read().decode())
            return {"content": [{"type": "text", "text": json.dumps(data, ensure_ascii=False, indent=2)}]}
    except Exception as e:
        return {"content": [{"type": "text", "text": f"Supabase error: {str(e)}"}]}

def call_memory_search(args):
    """Search memory_notes table in Supabase (fallback: old SQLite)"""
    query = args.get("query", "")
    category = args.get("category")
    limit = args.get("limit", 10)

    # Build Supabase filter: content ILIKE %query% + optional category filter
    filters = f"content=ilike.%{urllib.parse.quote(query)}%"
    if category:
        filters += f"&category=eq.{urllib.parse.quote(category)}"

    result = get_supabase("memory_notes", filters=filters, select="id,category,priority,tags,source,substring(content,1,200) as preview", limit=limit)
    # If Supabase returns empty, fallback to old SQLite
    text = result["content"][0]["text"]
    if text == "[]" or '"count":0' in text:
        return call_legacy_memory_search(args)
    return result

def call_legacy_memory_search(args):
    """Fallback: old SQLite memory search via subprocess"""
    import subprocess
    query = args.get("query", "")
    category = args.get("category")
    limit = args.get("limit", 5)

    cmd = ["python3", f"{MEMORY_TOOLS}/search_tool.py", "--query", query, "--limit", str(limit), "--format", "json", "--db", MEMORY_DB]
    if category:
        cmd.extend(["--category", category])
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
        if result.returncode == 0:
            return {"content": [{"type": "text", "text": result.stdout}]}
        else:
            return {"content": [{"type": "text", "text": f"Error: {result.stderr}"}]}
    except subprocess.TimeoutExpired:
        return {"content": [{"type": "text", "text": "Error: Timeout (30s)"}]}
    except Exception as e:
        return {"content": [{"type": "text", "text": f"Error: {str(e)}"}]}

def call_semantic_search(args):
    """Call MiniMax embo-01 semantic search via subprocess"""
    import subprocess
    query = args.get("query", "")
    limit = args.get("limit", 5)

    cmd = [
        "python3", f"{MEMORY_TOOLS}/embedding_service.py",
        "--search", query,
        "--db", MEMORY_DB
    ]

    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=60)
        return {"content": [{"type": "text", "text": result.stdout}]}
    except subprocess.TimeoutExpired:
        return {"content": [{"type": "text", "text": "Error: Timeout (60s)"}]}
    except Exception as e:
        return {"content": [{"type": "text", "text": f"Error: {str(e)}"}]}

def call_knowledge_graph_query(args):
    """Query entity_graph table in Supabase (fallback: old SQLite)"""
    entity = args.get("entity", "")
    relation_target = args.get("relation_target")

    filters = f"entity=ilike.%{urllib.parse.quote(entity)}%"
    if relation_target:
        filters += f"&relationships=cs.%{urllib.parse.quote(relation_target)}%"

    result = get_supabase("entity_graph", filters=filters, select="*", limit=10)
    text = result["content"][0]["text"]
    if text == "[]":
        return {"content": [{"type": "text", "text": f"'{entity}' için graph verisi yok."}]}
    return result

def call_memory_stats(args):
    """Call memory stats via subprocess"""
    import subprocess
    cmd = ["python3", f"{MEMORY_TOOLS}/embedding_service.py", "--stats", "--db", MEMORY_DB]

    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
        return {"content": [{"type": "text", "text": result.stdout}]}
    except subprocess.TimeoutExpired:
        return {"content": [{"type": "text", "text": "Error: Timeout (30s)"}]}
    except Exception as e:
        return {"content": [{"type": "text", "text": f"Error: {str(e)}"}]}

# Tool definitions
TOOLS = [
    {
        "name": "memory_search",
        "description": "Memory'de FTS5 tabanlı arama - kategori ve limit desteği",
        "inputSchema": {
            "type": "object",
            "properties": {
                "query": {"type": "string", "description": "Arama sorgusu"},
                "category": {"type": "string", "description": "Filtre: rpc_reference, database_schema, vs"},
                "limit": {"type": "integer", "default": 5}
            }
        }
    },
    {
        "name": "semantic_search",
        "description": "MiniMax embo-01 ile vektor-based semantic search",
        "inputSchema": {
            "type": "object",
            "properties": {
                "query": {"type": "string", "description": "Semantik arama sorgusu"},
                "limit": {"type": "integer", "default": 5}
            }
        }
    },
    {
        "name": "knowledge_graph_query",
        "description": "Entity ve relationship sorgulama",
        "inputSchema": {
            "type": "object",
            "properties": {
                "entity": {"type": "string", "description": "Entity adı"},
                "relation_target": {"type": "string", "description": "İlişki hedefi (opsiyonel)"}
            }
        }
    },
    {
        "name": "memory_stats",
        "description": "Memory sistemi istatistikleri ve sağlık durumu",
        "inputSchema": {"type": "object", "properties": {}}
    }
]

def handle_initialize(req_id, params):
    """Handle initialize request"""
    result = {
        "protocolVersion": PROTOCOL_VERSION,
        "capabilities": {"tools": {}},
        "serverInfo": {
            "name": "tools-bank-mcp-server",
            "version": "1.0.0"
        }
    }
    send_response(req_id, result)

def handle_tools_list(req_id):
    """Handle tools/list request"""
    send_response(req_id, {"tools": TOOLS})

def handle_tools_call(req_id, params):
    """Handle tools/call request"""
    tool_name = params.get("name")
    arguments = params.get("arguments", {})

    if tool_name == "memory_search":
        result = call_memory_search(arguments)
    elif tool_name == "semantic_search":
        result = call_semantic_search(arguments)
    elif tool_name == "knowledge_graph_query":
        result = call_knowledge_graph_query(arguments)
    elif tool_name == "memory_stats":
        result = call_memory_stats(arguments)
    else:
        send_error(req_id, -32602, f"Unknown tool: {tool_name}")
        return

    send_response(req_id, result)

def handle_shutdown(req_id):
    """Handle shutdown request"""
    send_response(req_id, {"success": True})
    sys.exit(0)

def main():
    """Main MCP server loop - read JSON-RPC from stdin, write to stdout"""
    while True:
        try:
            line = sys.stdin.readline()
            if not line:
                break

            request = json.loads(line.strip())
            method = request.get("method")
            req_id = request.get("id")
            params = request.get("params", {})

            if method == "initialize":
                handle_initialize(req_id, params)
            elif method == "tools/list":
                handle_tools_list(req_id)
            elif method == "tools/call":
                handle_tools_call(req_id, params)
            elif method == "shutdown":
                handle_shutdown(req_id)
            else:
                send_error(req_id, -32601, f"Method not found: {method}")

        except json.JSONDecodeError as e:
            # Try to send error for parse error - but we need an id
            print(json.dumps({"jsonrpc": "2.0", "error": {"code": -32700, "message": f"Parse error: {e}"}}), flush=True)
        except Exception as e:
            log(f"Error: {e}")

if __name__ == "__main__":
    main()