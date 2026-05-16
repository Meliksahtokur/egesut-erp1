#!/usr/bin/env python3
"""
Tools-Bank MCP Server
=====================
Exposes memory/embedding + GitNexus tools via MCP protocol to DeepSeek TUI / Claude Code
"""

import sys
import json
import os
import subprocess
from pathlib import Path

# Supabase config for entity_graph and memory_notes
SB_URL = "https://zqnexqbdfvbhlxzelzju.supabase.co"
SB_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpxbmV4cWJkZnZiaGx4emVsemp1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzIzMDE4OTksImV4cCI6MjA4Nzg3Nzg5OX0.VggKv3KsmXm7C1LqBxCJaMj2yLQh10iRwSXMtuC4cmc"
SB_HEADERS = {"apikey": SB_KEY, "Authorization": f"Bearer {SB_KEY}"}
import urllib.request, urllib.parse

# Paths
TOOLSBANK_ROOT = "/root/egesut-erp1/tools-bank"
MEMORY_TOOLS = f"{TOOLSBANK_ROOT}/memory"
MEMORY_DB = f"{TOOLSBANK_ROOT}/memory/memory.db"
REPO_ROOT = "/root/egesut-erp1"

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


# ── GitNexus generic runner ──────────────────────────────────────────────────

def run_gitnexus(args, timeout=30):
    """Generic GitNexus CLI runner. Returns (stdout, stderr) or raises."""
    cmd = args.get("_cmd", [])
    if not cmd:
        return {"content": [{"type": "text", "text": "Error: _cmd not provided"}]}
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout, cwd=REPO_ROOT)
        if result.returncode == 0:
            return {"content": [{"type": "text", "text": result.stdout}]}
        return {"content": [{"type": "text", "text": f"Error (exit {result.returncode}): {result.stderr or result.stdout}"}]}
    except subprocess.TimeoutExpired:
        return {"content": [{"type": "text", "text": f"Error: gitnexus command timed out ({timeout}s). Run 'npx gitnexus analyze' first in terminal."}]}
    except Exception as e:
        return {"content": [{"type": "text", "text": f"Error: {str(e)}"}]}


def call_gn_list_repos(args):
    return run_gitnexus({"_cmd": ["npx", "gitnexus", "list"]})

def call_gn_query(args):
    cmd = ["npx", "gitnexus", "query", args.get("query", "")]
    if args.get("repo"): cmd.extend(["--repo", args["repo"]])
    cmd.extend(["--limit", str(args.get("limit", 10))])
    return run_gitnexus({"_cmd": cmd})

def call_gn_cypher(args):
    cmd = ["npx", "gitnexus", "cypher", args.get("query", "")]
    if args.get("repo"): cmd.extend(["--repo", args["repo"]])
    return run_gitnexus({"_cmd": cmd})

def call_gn_context(args):
    cmd = ["npx", "gitnexus", "context", args.get("symbol", "")]
    if args.get("repo"): cmd.extend(["--repo", args["repo"]])
    return run_gitnexus({"_cmd": cmd})

def call_gn_detect_changes(args):
    cmd = ["npx", "gitnexus", "detect-changes"]
    if args.get("scope"): cmd.extend(["--scope", args["scope"]])
    if args.get("base_ref"): cmd.extend(["--base-ref", args["base_ref"]])
    if args.get("repo"): cmd.extend(["--repo", args["repo"]])
    return run_gitnexus({"_cmd": cmd})

def call_gn_impact(args):
    cmd = ["npx", "gitnexus", "impact", args.get("target", "")]
    if args.get("direction"): cmd.extend(["--direction", args["direction"]])
    if args.get("repo"): cmd.extend(["--repo", args["repo"]])
    if args.get("depth"): cmd.extend(["--depth", str(args["depth"])])
    if args.get("includeTests") == True: cmd.append("--include-tests")
    return run_gitnexus({"_cmd": cmd})

def call_gn_group_list(args):
    cmd = ["npx", "gitnexus", "group", "list"]
    if args.get("name"): cmd.extend(["--name", args["name"]])
    return run_gitnexus({"_cmd": cmd})

def call_gn_group_sync(args):
    cmd = ["npx", "gitnexus", "group", "sync", args.get("name", "")]
    if args.get("skipEmbeddings") == True: cmd.append("--skip-embeddings")
    if args.get("exactOnly") == True: cmd.append("--exact-only")
    return run_gitnexus({"_cmd": cmd})


# ── Legacy tools-bank tools ───────────────────────────────────────────────────

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

MEMORY_TOOLS = "/root/egesut-erp1/tools-bank/memory"
MEMORY_DB = f"{MEMORY_TOOLS}/memory.db"

def call_memory_search(args):
    """Search local SQLite memory_notes (FTS5) with Supabase fallback"""
    query = args.get("query", "")
    category = args.get("category")
    limit = args.get("limit", 10)

    # Try local SQLite first
    cmd = ["python3", f"{MEMORY_TOOLS}/search_tool.py", "--query", query, "--limit", str(limit), "--json"]
    if category:
        cmd.extend(["--category", category])
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=20)
        if result.returncode == 0:
            return {"content": [{"type": "text", "text": result.stdout}]}
    except:
        pass

    # Fallback: Supabase memory_notes (if table exists)
    filters = f"content=ilike.%{urllib.parse.quote(query)}%"
    if category:
        filters += f"&category=eq.{urllib.parse.quote(category)}"
    sb_result = get_supabase("memory_notes", filters=filters, select="id,category,priority,tags,source,substring(content,1,200) as preview", limit=limit)
    text = sb_result["content"][0]["text"]
    if text != "[]" and '"count":0' not in text:
        return sb_result
    return {"content": [{"type": "text", "text": json.dumps({"results": [], "total": 0, "message": "No results found."})}]}

def call_semantic_search(args):
    """Semantic search via local ONNX embedding (all-MiniLM-L6-v2). Zero API cost."""
    query = args.get("query", "")
    limit = args.get("limit", 5)
    cmd = ["python3", f"{MEMORY_TOOLS}/embedding_service.py", "--search", query]
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
        if result.returncode == 0:
            return {"content": [{"type": "text", "text": result.stdout}]}
        return {"content": [{"type": "text", "text": f"Error: {result.stderr}"}]}
    except subprocess.TimeoutExpired:
        return {"content": [{"type": "text", "text": "Error: embedding timeout (120s)"}]}
    except Exception as e:
        return {"content": [{"type": "text", "text": f"Error: {str(e)}"}]}

def call_memory_add(args):
    """Add a new note to memory"""
    content = args.get("content", "")
    if not content:
        return {"content": [{"type": "text", "text": json.dumps({"error": "content is required"})}]}
    category = args.get("category", "general")
    priority = args.get("priority", "medium")
    tags = args.get("tags", "")
    source = args.get("source", "mcp")

    cmd = ["python3", f"{MEMORY_TOOLS}/search_tool.py", "--add", "--content", content,
           "--category", category, "--priority", priority]
    if tags:
        cmd.extend(["--tags", tags])
    cmd.extend(["--source", source])
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=20)
        if result.returncode == 0:
            return {"content": [{"type": "text", "text": result.stdout}]}
        return {"content": [{"type": "text", "text": f"Error: {result.stderr}"}]}
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
    cmd = ["python3", f"{MEMORY_TOOLS}/embedding_service.py", "--stats", "--db", MEMORY_DB]
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
        return {"content": [{"type": "text", "text": result.stdout}]}
    except subprocess.TimeoutExpired:
        return {"content": [{"type": "text", "text": "Error: Timeout (30s)"}]}
    except Exception as e:
        return {"content": [{"type": "text", "text": f"Error: {str(e)}"}]}


# ── Tool definitions ─────────────────────────────────────────────────────────

TOOLS = [
    # Legacy tools-bank tools
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
        "name": "memory_add",
        "description": "Yeni bir not ekle. Kullanım: oturum boyunca öğrendiğin kritik bilgileri, kararları, hataları kaydet. content zorunlu, category/priority/tags opsiyonel.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "content": {"type": "string", "description": "Not içeriği (Türkçe/İngilizce)"},
                "category": {"type": "string", "description": "Kategori: critical_rules, rpc_reference, domain_rules, code_change, tech_stack, general", "default": "general"},
                "priority": {"type": "string", "enum": ["high", "medium", "low"], "default": "medium", "description": "Öncelik"},
                "tags": {"type": "string", "description": "Virgülle ayrılmış etiketler (örn: 'rpc,hayvan,kritik')"},
                "source": {"type": "string", "description": "Kaynak (default: mcp)"}
            },
            "required": ["content"]
        }
    },
    {
        "name": "memory_stats",
        "description": "Memory sistemi istatistikleri ve sağlık durumu",
        "inputSchema": {"type": "object", "properties": {}}
    },
    # GitNexus tools — CLI wrapper, npx gitnexus <komut> çalıştırır
    {
        "name": "gitnexus_list_repos",
        "description": "Indekslenmiş repoları listeler. Her repo için ad, yol, indeks tarihi, son commit ve istatistik döner. İlk adım: hangi repoların indekslendiğini görmek için.",
        "inputSchema": {"type": "object", "properties": {}}
    },
    {
        "name": "gitnexus_query",
        "description": "Kod knowledge graph'ında bir konseptle ilgili execution flow'ları sorgular. Process (call chain) grupları, semboller ve dosya konumları döner. Hybrid ranking: BM25 + semantic. Kullanım: kod anlamak, execution flow keşfetmek, sembol bağımlılıkları bulmak.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "query": {"type": "string", "description": "Doğal dil veya keyword sorgu (örn: 'tohumlama sonuc işleme akışı', 'loadTasks function')"},
                "repo": {"type": "string", "description": "Repo adı (opsiyonel, tek repo varsa gerekmez)"},
                "limit": {"type": "integer", "default": 10, "description": "Max sonuç sayısı"}
            },
            "required": ["query"]
        }
    },
    {
        "name": "gitnexus_cypher",
        "description": "Knowledge graph'a ham Cypher sorgusu çalıştırır. Karmaşık yapısal sorgular için. Şema için: gitnexus://repo/{name}/schema resource.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "query": {"type": "string", "description": "Cypher sorgusu (örn: MATCH (f:Function)-[:CodeRelation {type:'CALLS'}]->(g:Function) RETURN f.name, g.name LIMIT 20)"},
                "repo": {"type": "string", "description": "Repo adı (opsiyonel)"}
            },
            "required": ["query"]
        }
    },
    {
        "name": "gitnexus_context",
        "description": "Bir kod sembolünün 360 derece görünümü: categorized refs (calls, imports, extends, implements), katıldığı process'ler, dosya lokasyonu. Kullanım: bir fonksiyon/değişkenin tüm bağlamını anlamak.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "symbol": {"type": "string", "description": "Sembol adı (örn: 'loadTasks', 'hayvan_ekle', '_katTipMap')"},
                "repo": {"type": "string", "description": "Repo adı (opsiyonel)"}
            },
            "required": ["symbol"]
        }
    },
    # NOTE: gitnexus_rename is MCP-only in GitNexus, not a CLI command. Omitted.
    {
        "name": "gitnexus_detect_changes",
        "description": "Commit edilmemiş git değişikliklerini analiz eder ve etkilenen execution flow'ları gösterir. Git diff hunk'larını indekslenmiş sembollere eşler. Kullanım: 'Ne değiştirdim ve neleri etkiler?'",
        "inputSchema": {
            "type": "object",
            "properties": {
                "scope": {"type": "string", "description": "Kapsam: 'unstaged' (varsayılan), 'staged', 'all'"},
                "base_ref": {"type": "string", "description": "Karşılaştırma branch'i/ref'i (örn: 'main')"},
                "repo": {"type": "string", "description": "Repo adı (opsiyonel)"}
            }
        }
    },
    {
        "name": "gitnexus_impact",
        "description": "Bir sembolü değiştirirsen nelerin kırılacağını analiz eder — blast radius. Depth seviyelerine göre gruplanmış etkilenen semboller, risk değerlendirmesi, test coverage bilgisi döner. Kullanım: refactor öncesi güvenlik kontrolü.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "target": {"type": "string", "description": "Hedef sembol adı (örn: 'rpcOptimistic', 'hayvan_guncelle')"},
                "direction": {"type": "string", "description": "Yön: 'upstream' (kullanıcılar, default), 'downstream' (çağırdıkları)", "default": "upstream"},
                "depth": {"type": "integer", "description": "Maksimum ilişki derinliği (default: 3)", "default": 3},
                "includeTests": {"type": "boolean", "description": "Test dosyalarını dahil et (default: false)", "default": False},
                "repo": {"type": "string", "description": "Repo adı (opsiyonel)"}
            },
            "required": ["target"]
        }
    },
    # NOTE: route_map, tool_map, shape_check, api_impact are MCP-only tools
    # in GitNexus — not available as CLI commands. They still work when called
    # via tools/call from the GitNexus MCP server (npx gitnexus mcp).
    # We omit them here since we wrap CLI only.
    {
        "name": "gitnexus_group_list",
        "description": "Yapılandırılmış repo gruplarını listeler veya bir grubun detayını (repos, manifest links) döner. Kullanım: cross-index etki analizi için grupları keşfetme.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "name": {"type": "string", "description": "Grup adı (opsiyonel, boşsa tüm gruplar)"}
            }
        }
    },
    {
        "name": "gitnexus_group_sync",
        "description": "Bir grup için Contract Registry'yi (contracts.json) yeniden oluşturur: HTTP contract'ları çıkarır, manifest link'lerini uygular, exact-match cross-link'leri yapar. Kullanım: group.yaml değişikliği veya re-index sonrası.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "name": {"type": "string", "description": "Grup adı"},
                "skipEmbeddings": {"type": "boolean", "description": "Embedding'leri atla (sadece BM25 + exact)", "default": False},
                "exactOnly": {"type": "boolean", "description": "Sadece exact match kullan", "default": False}
            },
            "required": ["name"]
        }
    }
]


# ── RPC dispatch ──────────────────────────────────────────────────────────────

HANDLER_MAP = {
    "memory_search": call_memory_search,
    "memory_add": call_memory_add,
    "semantic_search": call_semantic_search,
    "knowledge_graph_query": call_knowledge_graph_query,
    "memory_stats": call_memory_stats,
    "gitnexus_list_repos": call_gn_list_repos,
    "gitnexus_query": call_gn_query,
    "gitnexus_cypher": call_gn_cypher,
    "gitnexus_context": call_gn_context,
    "gitnexus_detect_changes": call_gn_detect_changes,
    "gitnexus_impact": call_gn_impact,
    "gitnexus_group_list": call_gn_group_list,
    "gitnexus_group_sync": call_gn_group_sync,
}


def handle_initialize(req_id, params):
    """Handle initialize request"""
    result = {
        "protocolVersion": PROTOCOL_VERSION,
        "capabilities": {"tools": {}},
        "serverInfo": {
            "name": "tools-bank-mcp-server",
            "version": "2.0.0"
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

    handler = HANDLER_MAP.get(tool_name)
    if handler:
        result = handler(arguments)
        send_response(req_id, result)
    else:
        send_error(req_id, -32602, f"Unknown tool: {tool_name}")


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
            print(json.dumps({"jsonrpc": "2.0", "error": {"code": -32700, "message": f"Parse error: {e}"}}), flush=True)
        except Exception as e:
            log(f"Error: {e}")


if __name__ == "__main__":
    main()
