#!/bin/bash
# Claude Agent Intelligence System - Quick Setup Script
# ====================================================
# Automated setup for the complete intelligence framework

set -e  # Exit on any error

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m' # No Color

print_header() {
    echo -e "\n${BOLD}${BLUE}================================${NC}"
    echo -e "${BOLD}${BLUE} $1 ${NC}"
    echo -e "${BOLD}${BLUE}================================${NC}"
}

print_step() {
    echo -e "${CYAN}➤ $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Header
echo -e "${BOLD}${CYAN}Claude Agent Intelligence System${NC}"
echo -e "${DIM}Quick Setup & Configuration Script${NC}"
echo -e "${DIM}Version 1.0 - 2026-04-05${NC}\n"

# Check prerequisites
print_header "CHECKING PREREQUISITES"

# Check if running as root or with proper permissions
if [[ $EUID -ne 0 ]] && [[ ! -w /root/.claude ]]; then
    print_error "This script requires root access or write permission to /root/.claude"
    exit 1
fi
print_success "Permission check passed"

# Check Python 3
if command -v python3 &> /dev/null; then
    PYTHON_VERSION=$(python3 --version | cut -d' ' -f2)
    print_success "Python 3 found (version $PYTHON_VERSION)"
else
    print_error "Python 3 is required but not found"
    exit 1
fi

# Check required Python modules
print_step "Checking Python modules..."
for module in sqlite3 json pathlib datetime; do
    if python3 -c "import $module" 2>/dev/null; then
        print_success "Python module: $module"
    else
        print_error "Required Python module missing: $module"
        exit 1
    fi
done

# Check mini-agent
if command -v mini-agent &> /dev/null; then
    AGENT_VERSION=$(mini-agent --version 2>/dev/null || echo "unknown")
    print_success "mini-agent found ($AGENT_VERSION)"
else
    print_warning "mini-agent not found - some features will be limited"
    echo -e "${DIM}  To install: pip install mini-agent${NC}"
fi

# Setup directory structure
print_header "SETTING UP DIRECTORY STRUCTURE"

# Create main directories
print_step "Creating directory structure..."
mkdir -p /root/.claude/skills/{memory-intelligence,agent-orchestration,autonomous-ai}/{scripts,config,docs}
mkdir -p /root/opencode-dev/.claude/memory
mkdir -p /root/.mini-agent/{config,log}
mkdir -p /tmp/claude-intelligence

print_success "Directory structure created"

# Setup memory system
print_header "CONFIGURING MEMORY SYSTEM"

# Check if memory databases exist
MEMORY_DB="/root/opencode-dev/.claude/memory/memory.db"
GRAPH_DB="/root/opencode-dev/.claude/memory/knowledge_graph.db"

if [[ -f "$MEMORY_DB" ]]; then
    print_success "Memory database exists"
else
    print_step "Initializing memory database..."
    # Initialize memory database if sqlite3 is available
    if command -v sqlite3 &> /dev/null; then
        sqlite3 "$MEMORY_DB" "CREATE TABLE IF NOT EXISTS notes (
            id INTEGER PRIMARY KEY,
            timestamp TEXT,
            category TEXT,
            content TEXT,
            priority TEXT,
            tags TEXT,
            confidence REAL,
            source TEXT
        );"
        print_success "Memory database initialized"
    else
        print_warning "sqlite3 not available - memory database not initialized"
    fi
fi

if [[ -f "$GRAPH_DB" ]]; then
    print_success "Knowledge graph database exists"
else
    print_step "Initializing knowledge graph database..."
    if command -v sqlite3 &> /dev/null; then
        sqlite3 "$GRAPH_DB" "CREATE TABLE IF NOT EXISTS entities (
            id INTEGER PRIMARY KEY,
            name TEXT UNIQUE,
            type TEXT,
            count INTEGER DEFAULT 1,
            first_seen TEXT,
            last_seen TEXT
        );"
        sqlite3 "$GRAPH_DB" "CREATE TABLE IF NOT EXISTS relationships (
            id INTEGER PRIMARY KEY,
            entity1_id INTEGER,
            entity2_id INTEGER,
            relationship_type TEXT,
            weight REAL DEFAULT 1.0,
            FOREIGN KEY (entity1_id) REFERENCES entities(id),
            FOREIGN KEY (entity2_id) REFERENCES entities(id)
        );"
        print_success "Knowledge graph database initialized"
    else
        print_warning "sqlite3 not available - knowledge graph not initialized"
    fi
fi

# Configure API keys
print_header "CONFIGURING API KEYS"

# Check existing API keys
if [[ -n "$MINIMAX_API_KEY" && "$MINIMAX_API_KEY" != "your_minimax_api_key_here" ]]; then
    print_success "MiniMax API key configured"
elif [[ -n "$ANTHROPIC_API_KEY" ]]; then
    print_step "Setting MiniMax API key from Anthropic key..."
    export MINIMAX_API_KEY="$ANTHROPIC_API_KEY"
    if ! grep -q "MINIMAX_API_KEY" ~/.bashrc; then
        echo "export MINIMAX_API_KEY=\"$ANTHROPIC_API_KEY\"" >> ~/.bashrc
    fi
    print_success "MiniMax API key configured from Anthropic key"
else
    print_warning "No API keys found - some features will be limited"
    echo -e "${DIM}  Set MINIMAX_API_KEY or ANTHROPIC_API_KEY environment variable${NC}"
fi

# Configure mini-agent MCP servers
print_header "CONFIGURING AGENT SYSTEM"

MCP_CONFIG="/root/.mini-agent/config/mcp.json"
if [[ -f "$MCP_CONFIG" ]]; then
    print_success "MCP configuration exists"
else
    print_step "Creating MCP configuration..."
    cat > "$MCP_CONFIG" << 'EOF'
{
    "mcpServers": {
        "github": {
            "description": "GitHub - Issues, PRs, repos",
            "command": "node",
            "args": ["/usr/local/sbin/mcp-server-github"],
            "disabled": false
        }
    }
}
EOF
    print_success "MCP configuration created"
fi

# Verify skill files
print_header "VERIFYING SKILL INSTALLATION"

SKILLS=(
    "/root/.claude/skills/memory-intelligence/SKILL.md"
    "/root/.claude/skills/agent-orchestration/SKILL.md"
    "/root/.claude/skills/autonomous-ai/SKILL.md"
    "/root/.claude/skills/CLAUDE_AGENT_INTELLIGENCE_GUIDE.md"
)

for skill in "${SKILLS[@]}"; do
    if [[ -f "$skill" ]]; then
        print_success "Skill available: $(basename $(dirname $skill))"
    else
        print_warning "Skill missing: $(basename $(dirname $skill))"
    fi
done

# Create helper scripts
print_header "CREATING HELPER SCRIPTS"

# Dashboard script
cat > /root/.claude/skills/autonomous-ai/scripts/dashboard.sh << 'EOF'
#!/bin/bash
# Intelligence System Dashboard
echo "🧠 Claude Intelligence Dashboard"
echo "================================"

# Memory stats
echo "💾 Memory System:"
if [[ -f "/root/opencode-dev/.claude/memory/memory.db" ]]; then
    NOTE_COUNT=$(sqlite3 /root/opencode-dev/.claude/memory/memory.db "SELECT COUNT(*) FROM notes;" 2>/dev/null || echo "0")
    echo "  Notes: $NOTE_COUNT"
else
    echo "  Status: Not initialized"
fi

# Agent stats
echo "🤖 Agent System:"
ACTIVE_AGENTS=$(pgrep mini-agent | wc -l)
echo "  Active agents: $ACTIVE_AGENTS"

if [[ -d "/root/.mini-agent/log" ]]; then
    RECENT_RUNS=$(find /root/.mini-agent/log -name "*.log" -mtime -7 | wc -l)
    echo "  Recent runs: $RECENT_RUNS (last 7 days)"
fi

# System resources
echo "🖥️  Resources:"
MEMORY_USAGE=$(free | awk 'NR==2{printf "%.0f%%", $3*100/$2}')
echo "  Memory: $MEMORY_USAGE"

DISK_USAGE=$(df /root | awk 'NR==2{print $5}')
echo "  Disk: $DISK_USAGE"

echo "================================"
EOF

chmod +x /root/.claude/skills/autonomous-ai/scripts/dashboard.sh
print_success "Dashboard script created"

# Quick test script
cat > /root/.claude/skills/autonomous-ai/scripts/quick_test.sh << 'EOF'
#!/bin/bash
# Quick system test
echo "🧪 Quick Intelligence System Test"
echo "=================================="

# Test memory search
echo "Testing memory search..."
if python3 /root/opencode-dev/.claude/memory/search_tool.py --query "test" --limit 1 >/dev/null 2>&1; then
    echo "✅ Memory search: OK"
else
    echo "❌ Memory search: FAILED"
fi

# Test mini-agent
echo "Testing agent system..."
if command -v mini-agent >/dev/null 2>&1; then
    echo "✅ Mini-agent: Available"
    # Quick agent test
    if timeout 30 mini-agent --workspace /root/opencode-dev --task "echo 'test successful'" >/dev/null 2>&1; then
        echo "✅ Agent execution: OK"
    else
        echo "⚠️  Agent execution: Limited (MCP issues or timeout)"
    fi
else
    echo "❌ Mini-agent: Not available"
fi

# Test skills
echo "Testing skills..."
for skill in memory-intelligence agent-orchestration autonomous-ai; do
    if [[ -f "/root/.claude/skills/$skill/SKILL.md" ]]; then
        echo "✅ Skill $skill: Available"
    else
        echo "❌ Skill $skill: Missing"
    fi
done

echo "=================================="
echo "Test completed. See details above."
EOF

chmod +x /root/.claude/skills/autonomous-ai/scripts/quick_test.sh
print_success "Quick test script created"

# Final setup steps
print_header "FINALIZING SETUP"

# Create quick access aliases
cat > /root/.claude/skills/autonomous-ai/config/aliases.sh << 'EOF'
#!/bin/bash
# Claude Intelligence System Aliases

alias ci-health="python3 /root/.claude/skills/autonomous-ai/scripts/system_health.py"
alias ci-dashboard="bash /root/.claude/skills/autonomous-ai/scripts/dashboard.sh"
alias ci-test="bash /root/.claude/skills/autonomous-ai/scripts/quick_test.sh"
alias ci-memory="python3 /root/opencode-dev/.claude/memory/search_tool.py"
alias ci-graph="python3 /root/opencode-dev/.claude/memory/knowledge_graph.py"
alias ci-agent="mini-agent --workspace /root/opencode-dev"

# Quick skill access
alias skill-memory="cat /root/.claude/skills/memory-intelligence/SKILL.md"
alias skill-agent="cat /root/.claude/skills/agent-orchestration/SKILL.md"
alias skill-ai="cat /root/.claude/skills/autonomous-ai/SKILL.md"
alias skill-guide="cat /root/.claude/skills/CLAUDE_AGENT_INTELLIGENCE_GUIDE.md"

echo "Claude Intelligence System aliases loaded"
echo "Available commands: ci-health, ci-dashboard, ci-test, ci-memory, ci-graph, ci-agent"
echo "Skill docs: skill-memory, skill-agent, skill-ai, skill-guide"
EOF

# Add aliases to bashrc if not already present
if ! grep -q "Claude Intelligence System aliases" ~/.bashrc; then
    echo "source /root/.claude/skills/autonomous-ai/config/aliases.sh" >> ~/.bashrc
    print_success "Shell aliases configured"
else
    print_success "Shell aliases already configured"
fi

# Create welcome message
cat > /root/.claude/skills/WELCOME.md << 'EOF'
# Welcome to Claude Agent Intelligence System! 🧠🤖

## Quick Start Commands

```bash
# System health check
ci-health

# View dashboard
ci-dashboard

# Quick test
ci-test

# Memory search
ci-memory --query "your_search_term"

# Spawn agent
ci-agent --task "your_task_description"
```

## Available Skills

- `/skill memory-intelligence` - Advanced memory and knowledge graph
- `/skill agent-orchestration` - Multi-agent coordination
- `/skill autonomous-ai` - Unified intelligent automation

## Documentation

- **Complete Guide:** `cat /root/.claude/skills/CLAUDE_AGENT_INTELLIGENCE_GUIDE.md`
- **Individual Skills:** `skill-memory`, `skill-agent`, `skill-ai`

## Next Steps

1. Run `ci-health` to verify system status
2. Try `ci-test` for a quick functionality test
3. Explore the complete guide for advanced usage patterns

Happy AI development! 🚀
EOF

print_success "Welcome documentation created"

# Run final health check
print_header "FINAL SYSTEM VERIFICATION"

print_step "Running health check..."
if python3 /root/.claude/skills/autonomous-ai/scripts/system_health.py >/dev/null 2>&1; then
    print_success "System health check passed"
else
    print_warning "System health check had issues - run ci-health for details"
fi

# Setup complete
print_header "SETUP COMPLETE"

echo -e "${BOLD}${GREEN}🎉 Claude Agent Intelligence System setup complete!${NC}\n"

echo -e "${BOLD}Quick Actions:${NC}"
echo -e "${DIM}• Health check: ${NC}ci-health"
echo -e "${DIM}• Dashboard: ${NC}ci-dashboard"
echo -e "${DIM}• Quick test: ${NC}ci-test"
echo -e "${DIM}• Usage guide: ${NC}skill-guide"

echo -e "\n${BOLD}Example Usage:${NC}"
echo -e "${DIM}# Search memory${NC}"
echo -e "ci-memory --query 'RPC patterns'"
echo -e "\n${DIM}# Spawn intelligent agent${NC}"
echo -e "ci-agent --task 'analyze code quality with historical context'"
echo -e "\n${DIM}# Full autonomous workflow${NC}"
echo -e "/skill autonomous-ai execute 'optimize system performance'"

echo -e "\n${CYAN}💡 Tip: Source your bashrc to activate aliases: ${BOLD}source ~/.bashrc${NC}"

print_success "Setup completed successfully! Welcome to the future of AI assistance."