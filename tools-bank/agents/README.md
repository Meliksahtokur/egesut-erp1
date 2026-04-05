# 🤖 Agents

Production-ready agent implementations for various workflows.

## Available Agents

### Core Intelligence Agents
- **Memory Agent**: Advanced memory operations and search
- **Orchestrator Agent**: Multi-agent coordination
- **Explorer Agent**: Codebase exploration and analysis

### Domain-Specific Agents
- **ERP Agent**: Business workflow automation
- **Dev Agent**: Development assistance and automation
- **QA Agent**: Quality assurance and testing

## Agent Configuration

Each agent has:
- `config.json` - Agent configuration and parameters
- `prompts/` - System prompts and instructions
- `tools/` - Agent-specific tool configurations
- `examples/` - Usage examples and test cases

## Quick Start

```bash
# Spawn a memory agent
python3 ../tools/intelligence_wrapper.py spawn_agent "search memory for patterns"

# Use with mini-agent
mini-agent --config memory-agent-config.json --task "your task"
```

## Integration

Agents integrate with:
- Memory Intelligence system
- MCP servers
- Claude Skills
- Background execution framework