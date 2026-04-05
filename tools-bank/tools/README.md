# 🛠️ Development Tools

Core tools and utilities for the AI Development Tools Bank.

## Available Tools

### Intelligence Core
- **intelligence_wrapper.py** - Main Python API interface
  - Memory search and management
  - Agent spawning and orchestration
  - System health monitoring
  - JSON API for programmatic access

- **intelligence_shortcuts.sh** - Bash convenience functions
  - `ai_search` - Quick memory search
  - `ai_spawn` - Agent spawning
  - `ai_smart_task` - Context-aware task execution
  - `ai_analyze` - Comprehensive analysis workflows

### Memory Tools
- Located in `../memory/` directory
- SQLite + FTS5 full-text search
- Vector embeddings with semantic search
- Knowledge graph operations
- Auto-categorization and quality scoring

### System Utilities
- Health monitors and diagnostics
- Performance benchmarking tools
- Setup and configuration scripts
- CLI utilities for common operations

## Quick Usage

### Python API
```python
# Direct Python integration
from intelligence_wrapper import memory_search, spawn_agent

# Search memory
results = memory_search("your query", category="optional")

# Spawn agent
agent = spawn_agent("your task description")
```

### Command Line
```bash
# Memory search
python3 intelligence_wrapper.py memory_search "query" "category"

# Agent spawning
python3 intelligence_wrapper.py spawn_agent "task description"

# System health
python3 intelligence_wrapper.py health
```

### Bash Shortcuts
```bash
# Load shortcuts
source intelligence_shortcuts.sh

# Use convenient functions
ai_search "your query"
ai_spawn "your task"
ai_smart_task "complex task with context"
ai_health
```

## Integration

Tools integrate with:
- **Memory Intelligence**: Instant knowledge access
- **Agent Orchestration**: Autonomous task execution
- **MCP Servers**: GitHub, Supabase, Context7
- **Claude Skills**: Native Claude integration
- **Background Execution**: Non-blocking operations

## Performance

- **Memory search**: <10ms response time
- **Agent spawn**: <2 seconds
- **System health**: <5 seconds
- **JSON API**: Real-time responses