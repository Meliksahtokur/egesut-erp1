# 🔌 MCP Integrations

Model Context Protocol server configurations and integrations.

## Available MCPs

### Production MCPs
- **GitHub MCP**: Repository automation, issues, PRs, code search
- **Supabase MCP**: Database operations, migrations, edge functions
- **Context7 MCP**: Documentation fetching and library references

### Development MCPs
- **TestSprite MCP**: Automated testing and test generation
- **Custom Domain MCPs**: Domain-specific protocol implementations

## MCP Configuration

Each MCP includes:
- `config.json` - Server configuration
- `setup.sh` - Installation and setup script
- `examples/` - Usage examples
- `docs/` - Integration documentation

## Quick Setup

```bash
# GitHub MCP
export GITHUB_PERSONAL_ACCESS_TOKEN="your_token"
claude-code --mcp-server github

# Supabase MCP
export SUPABASE_ACCESS_TOKEN="your_token"
claude-code --mcp-server supabase

# Context7 MCP (no auth needed)
claude-code --mcp-server context7
```

## Integration with Intelligence System

MCPs work seamlessly with:
- Memory intelligence for context-aware operations
- Agent orchestration for autonomous workflows
- Background task execution
- Knowledge graph relationships