#!/usr/bin/env python3
"""
Claude Agent Intelligence Wrapper
=================================
Direct callable functions for Claude Agent memory and orchestration
"""

import subprocess
import json
import sys
from pathlib import Path

# Paths
MEMORY_TOOLS = "/root/opencode-dev/.claude/memory"
MINI_AGENT = "/root/.local/bin/mini-agent"
WORKSPACE = "/root/opencode-dev"

def memory_search(query, category=None, limit=5):
    """Smart memory search with optional filtering"""
    cmd = [
        "python3", f"{MEMORY_TOOLS}/search_tool.py",
        "--query", query,
        "--limit", str(limit),
        "--format", "json"
    ]

    if category:
        cmd.extend(["--category", category])

    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
        if result.returncode == 0:
            return json.loads(result.stdout)
        else:
            return {"error": result.stderr, "results": []}
    except Exception as e:
        return {"error": str(e), "results": []}

def knowledge_graph_query(entity, relation_target=None):
    """Query knowledge graph for entity relationships"""
    cmd = [
        "python3", f"{MEMORY_TOOLS}/knowledge_graph.py",
        "--query", entity
    ]

    if relation_target:
        cmd = [
            "python3", f"{MEMORY_TOOLS}/knowledge_graph.py",
            "--relate", entity, relation_target
        ]

    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
        return {"success": True, "output": result.stdout}
    except Exception as e:
        return {"success": False, "error": str(e)}

def semantic_search(query, limit=5):
    """Vector-based semantic search"""
    cmd = [
        "python3", f"{MEMORY_TOOLS}/embedding_service.py",
        "--search", query
    ]

    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=60)
        return {"success": True, "output": result.stdout}
    except Exception as e:
        return {"success": False, "error": str(e)}

def spawn_agent(task_description, workspace=None):
    """Spawn mini-agent for autonomous task execution"""
    ws = workspace or WORKSPACE
    cmd = [MINI_AGENT, "--workspace", ws, "--task", task_description]

    try:
        # Run in background
        process = subprocess.Popen(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True
        )
        return {
            "success": True,
            "pid": process.pid,
            "message": f"Agent spawned for task: {task_description}"
        }
    except Exception as e:
        return {"success": False, "error": str(e)}

def memory_stats():
    """Get memory system health and statistics"""
    cmd = ["python3", f"{MEMORY_TOOLS}/memory_stats.py", "--json"]

    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
        if result.returncode == 0:
            return json.loads(result.stdout)
        else:
            return {"error": result.stderr}
    except Exception as e:
        return {"error": str(e)}

def system_health():
    """Comprehensive system health check"""
    cmd = ["python3", "/root/.claude/skills/autonomous-ai/scripts/system_health.py"]

    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=60)
        return {"success": True, "output": result.stdout}
    except Exception as e:
        return {"success": False, "error": str(e)}

# CLI interface for direct usage
if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage:")
        print("  python3 intelligence_wrapper.py memory_search 'query' [category]")
        print("  python3 intelligence_wrapper.py semantic_search 'query'")
        print("  python3 intelligence_wrapper.py spawn_agent 'task description'")
        print("  python3 intelligence_wrapper.py knowledge_graph 'entity'")
        print("  python3 intelligence_wrapper.py health")
        print("  python3 intelligence_wrapper.py stats")
        sys.exit(1)

    command = sys.argv[1]

    if command == "memory_search":
        query = sys.argv[2]
        category = sys.argv[3] if len(sys.argv) > 3 else None
        result = memory_search(query, category)
        print(json.dumps(result, indent=2))

    elif command == "semantic_search":
        query = sys.argv[2]
        result = semantic_search(query)
        print(result["output"] if result["success"] else result["error"])

    elif command == "spawn_agent":
        task = sys.argv[2]
        result = spawn_agent(task)
        print(json.dumps(result, indent=2))

    elif command == "knowledge_graph":
        entity = sys.argv[2]
        relation = sys.argv[3] if len(sys.argv) > 3 else None
        result = knowledge_graph_query(entity, relation)
        print(result["output"] if result["success"] else result["error"])

    elif command == "health":
        result = system_health()
        print(result["output"] if result["success"] else result["error"])

    elif command == "stats":
        result = memory_stats()
        print(json.dumps(result, indent=2))

    else:
        print(f"Unknown command: {command}")
        sys.exit(1)