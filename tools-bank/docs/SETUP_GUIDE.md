# 🚀 Setup Guide

Complete setup instructions for the AI Development Tools Bank.

## Quick Start (5 minutes)

```bash
# 1. Clone the repository
git clone https://github.com/yourusername/brainstorm.git
cd brainstorm

# 2. Test the system
python3 tools/intelligence_wrapper.py health

# 3. Search memory
python3 tools/intelligence_wrapper.py memory_search "test"

# 4. Load shortcuts
source tools/intelligence_shortcuts.sh

# 5. Try a demo
ai_demo
```

## Full Installation

### Prerequisites

```bash
# Python 3.11+
python3 --version

# SQLite with FTS5
python3 -c "import sqlite3; print('FTS5 available' if 'fts5' in sqlite3.compile_options else 'FTS5 missing')"

# Git
git --version
```

### Environment Setup

```bash
# 1. Set up Python environment
python3 -m venv brainstorm-env
source brainstorm-env/bin/activate
pip install --upgrade pip

# 2. Install dependencies
pip install sqlite3 numpy requests beautifulsoup4

# 3. Set environment variables
export MINIMAX_API_KEY="your_minimax_key"
export GITHUB_TOKEN="your_github_token"
export SUPABASE_ACCESS_TOKEN="your_supabase_token"
```

### MCP Server Setup

#### GitHub MCP
```bash
# 1. Generate Personal Access Token
# Go to GitHub → Settings → Developer settings → Personal access tokens

# 2. Set environment variable
export GITHUB_PERSONAL_ACCESS_TOKEN="your_token"

# 3. Test connection
python3 -c "
from tools.intelligence_wrapper import *
result = memory_search('GitHub integration test')
print(result)
"
```

#### Supabase MCP
```bash
# 1. Get Supabase Access Token
# Go to Supabase Dashboard → Settings → API

# 2. Set environment variable
export SUPABASE_ACCESS_TOKEN="your_token"

# 3. Test connection
python3 tools/intelligence_wrapper.py memory_search "database"
```

### Memory System Initialization

```bash
# 1. Check memory databases
ls -la memory/*.db

# 2. Initialize if needed
python3 memory/sqlite_backend.py --init

# 3. Test search functionality
python3 memory/search_tool.py --query "test" --format json

# 4. Test embeddings (requires MiniMax API)
python3 memory/embedding_service.py --search "semantic test"

# 5. Check knowledge graph
python3 memory/knowledge_graph.py --query "system"
```

### Agent System Setup

```bash
# 1. Verify mini-agent installation
which mini-agent || echo "Install mini-agent from Claude Code"

# 2. Test agent spawning
python3 tools/intelligence_wrapper.py spawn_agent "test task"

# 3. Check agent logs
ls /root/.mini-agent/log/agent_run_*.log | tail -3

# 4. Monitor agent processes
ps aux | grep mini-agent
```

### Skills Integration

```bash
# 1. Verify skills are available
ls skills/*/SKILL.md

# 2. Load memory intelligence skill
# In Claude: /skill memory-intelligence

# 3. Load agent orchestration skill
# In Claude: /skill agent-orchestration

# 4. Load autonomous AI skill
# In Claude: /skill autonomous-ai
```

## Configuration

### Memory Configuration
Edit `memory/config.json`:
```json
{
  "database_path": "memory/memory.db",
  "embedding_model": "minimax",
  "search_limit": 10,
  "quality_threshold": 0.7
}
```

### Agent Configuration
Edit `agents/config.json`:
```json
{
  "max_concurrent_agents": 5,
  "default_timeout": 300,
  "log_level": "INFO",
  "workspace_path": "/workspace"
}
```

### MCP Configuration
Edit `mcps/config.json`:
```json
{
  "github": {
    "enabled": true,
    "timeout": 30
  },
  "supabase": {
    "enabled": true,
    "timeout": 60
  }
}
```

## Verification

### System Health Check
```bash
python3 tools/intelligence_wrapper.py health
```

**Expected Output:**
```
✅ Memory system: 156KB, 16 notes
✅ Search performance: 9.4ms average
✅ Knowledge graph: 321 entities
✅ Agent system: Ready
✅ MCP servers: GitHub, Supabase connected
✅ Skills: 3 loaded
```

### Performance Benchmarks
```bash
# Memory search speed
time python3 memory/search_tool.py --query "performance test"

# Agent spawn time
time python3 tools/intelligence_wrapper.py spawn_agent "benchmark test"

# Full system demo
source tools/intelligence_shortcuts.sh && ai_demo
```

## Troubleshooting

### Common Issues

#### "FTS5 not available"
```bash
# Install SQLite with FTS5
sudo apt-get install sqlite3 libsqlite3-dev
# or brew install sqlite3
```

#### "MiniMax API error"
```bash
# Check API key
echo $MINIMAX_API_KEY
# Verify connectivity
curl -H "Authorization: Bearer $MINIMAX_API_KEY" https://api.minimax.chat/v1/models
```

#### "Agent spawn failed"
```bash
# Check mini-agent installation
mini-agent --version
# Check permissions
ls -la /root/.mini-agent/
```

#### "GitHub MCP failed"
```bash
# Verify token
echo $GITHUB_PERSONAL_ACCESS_TOKEN
# Test API access
curl -H "Authorization: token $GITHUB_PERSONAL_ACCESS_TOKEN" https://api.github.com/user
```

### Debug Mode

```bash
# Enable verbose logging
export DEBUG=1

# Run with debug output
python3 -u tools/intelligence_wrapper.py health 2>&1 | tee debug.log
```

## Production Deployment

### Docker Setup
```dockerfile
FROM python:3.11-slim
WORKDIR /app
COPY . .
RUN pip install -r requirements.txt
CMD ["python3", "tools/intelligence_wrapper.py", "health"]
```

### Environment Variables
```bash
# Required
MINIMAX_API_KEY=your_key
GITHUB_PERSONAL_ACCESS_TOKEN=your_token
SUPABASE_ACCESS_TOKEN=your_token

# Optional
DEBUG=0
LOG_LEVEL=INFO
WORKSPACE=/workspace
```

### Monitoring
```bash
# Health check endpoint
curl http://localhost:8080/health

# Metrics endpoint
curl http://localhost:8080/metrics

# Status dashboard
open http://localhost:8080/dashboard
```

## Next Steps

1. **Explore Examples**: Check `examples/` for real-world usage patterns
2. **Customize Agents**: Modify `agents/` configurations for your needs
3. **Add MCPs**: Integrate additional MCP servers
4. **Monitor Performance**: Set up production monitoring
5. **Scale System**: Consider multi-instance deployment

## Getting Help

- **Documentation**: Check `docs/` directory
- **Examples**: Real implementations in `examples/`
- **Issues**: GitHub issues for bug reports
- **Community**: Join discussions and share patterns