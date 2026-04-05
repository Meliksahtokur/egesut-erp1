#!/bin/bash
# Claude Agent Intelligence - Convenient Access Functions
# Source this file in your Claude Agent environment

# Wrapper path
WRAPPER="/root/.claude/intelligence_wrapper.py"

# Memory functions
ai_search() {
    echo "🧠 Memory search: $1"
    python3 "$WRAPPER" memory_search "$1" "$2"
}

ai_semantic() {
    echo "🔍 Semantic search: $1"
    python3 "$WRAPPER" semantic_search "$1"
}

ai_graph() {
    echo "🕸️  Knowledge graph: $1"
    python3 "$WRAPPER" knowledge_graph "$1" "$2"
}

# Agent orchestration
ai_spawn() {
    echo "🤖 Spawning agent for: $1"
    python3 "$WRAPPER" spawn_agent "$1"
}

# System monitoring
ai_health() {
    echo "🔧 System health check..."
    python3 "$WRAPPER" health
}

ai_stats() {
    echo "📊 Memory statistics..."
    python3 "$WRAPPER" stats
}

# Combined workflows
ai_analyze() {
    echo "🎯 Comprehensive analysis of: $1"
    echo "1. Searching memory for context..."
    ai_search "$1" | jq '.results[0].content // "No context found"'

    echo -e "\n2. Spawning detailed analysis agent..."
    ai_spawn "analyze '$1' with historical context and generate comprehensive report"

    echo -e "\n3. Knowledge graph relationships..."
    ai_graph "$1"
}

ai_smart_task() {
    local task="$1"
    echo "🚀 Intelligent task execution: $task"

    # Step 1: Memory context
    echo "Step 1: Gathering memory context..."
    local context=$(ai_search "$task" | jq -r '.results[0].content // "No prior context"')

    # Step 2: Enhanced task with context
    local enhanced_task="$task. Context from previous work: $context"

    # Step 3: Spawn agent
    echo "Step 2: Spawning intelligent agent..."
    ai_spawn "$enhanced_task"

    echo "✅ Intelligent task initiated with historical context"
}

# Quick demos
ai_demo() {
    echo "🎉 Claude Agent Intelligence Demo"
    echo "================================"

    echo "1. Memory Search Demo:"
    ai_search "RPC" "critical_rules"

    echo -e "\n2. Agent Spawn Demo:"
    ai_spawn "demonstrate system capabilities"

    echo -e "\n3. System Health:"
    ai_health | head -20

    echo -e "\nDemo complete! Try these commands:"
    echo "  ai_search 'your query'"
    echo "  ai_spawn 'your task'"
    echo "  ai_analyze 'your topic'"
    echo "  ai_smart_task 'your complex task'"
}

echo "🧠🤖 Claude Agent Intelligence shortcuts loaded"
echo "Available: ai_search, ai_spawn, ai_analyze, ai_smart_task, ai_health, ai_demo"