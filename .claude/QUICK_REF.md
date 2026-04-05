# ⚡ Hızlı Referans Kartı

## Orchestrator Çalıştır
```bash
unset CLAUDECODE && /opt/agent-framework/.venv/bin/python /root/agent-test/orchestrator.py
```

## Basit Test
```bash
unset CLAUDECODE && /opt/agent-framework/.venv/bin/python -c "
import asyncio
from agent_framework_claude import ClaudeAgent
async def t():
    a = ClaudeAgent(instructions='Türkçe 1 cümle selam.', default_options={
        'model': 'MiniMax-M2.7',
        'cli_path': '/opt/agent-framework/.venv/lib/python3.12/site-packages/claude_agent_sdk/_bundled/claude',
        'max_turns': 1
    })
    await a.start()
    print((await (await a.run('Selam'))).final_result)
    await a.stop()
asyncio.run(t())
"
```

## Import
```python
from agent_framework_claude import ClaudeAgent
```

## Agent Oluştur
```python
agent = ClaudeAgent(
    instructions="System prompt",
    default_options={
        "model": "MiniMax-M2.7",
        "cli_path": "/opt/.../claude",
        "permission_mode": "acceptEdits",
        "allowed_tools": ["Bash", "Read", "Agent"],
        "max_turns": 10,
        "agents": {
            "my-agent": {
                "description": "...",
                "prompt": "...",
                "tools": ["Bash"],
            }
        }
    }
)
```

## Çalıştır
```python
await agent.start()
response = await agent.run("Soru")
result = await response
print(result.final_result)
await agent.stop()
```

## Dosyalar
| Dosya | Açıklama |
|-------|----------|
| `.claude/AGENT_SYSTEM_GUIDE.md` | Tam doküman |
| `.claude/session-learnings.md` | Öğrenilenler |
| `/root/agent-test/orchestrator.py` | Ana script |
| `/root/agent-test/research/` | Araştırma |

## API
```
Base URL: https://api.minimax.io/anthropic
Model: MiniMax-M2.7
```

## MCP Server
```python
"mcp_servers": {
    "github": {"command": "npx", "args": ["-y", "@modelcontextprotocol/server-github"]},
    "supabase": {"command": "npx", "args": ["-y", "@modelcontextprotocol/server-supabase"]},
    "postgres": {"command": "npx", "args": ["-y", "@modelcontextprotocol/server-postgres"]},
}
```

## Bilinen Sorunlar
- ❌ `EOFError` → terminalden çalıştır
- ❌ Nested session → `unset CLAUDECODE`
- ❌ Tool runner uyumsuz → manual loop veya agent_framework_claude

---

## ⚠️ BİLİNEN SORUN (2026-04-05)

### agent_framework_claude.start() TAKILIYOR
`agent.start()` 30sn+ bekliyor, tamamlanamıyor. Claude Code subprocess
stream-json modunda MiniMax API'ye bağlanamıyor gibi görünüyor.

### ÇÖZÜM YOLLARI:
1. `claude_agent_sdk.query()` ile interaktif loop dene (en güvenli)
2. Direct `anthropic.Anthropic()` + manual loop (full kontrol)
3. CLI subprocess'i farklı modda spawn et

### DOĞRULANMIŞ ÇALIŞAN:
```bash
unset CLAUDECODE && python -c "
import asyncio
from claude_agent_sdk import query, ClaudeAgentOptions
async def t():
    async for msg in query('Selam', options=ClaudeAgentOptions(max_turns=1)):
        print(type(msg).__name__)
asyncio.run(t())
"
```

### Detaylar: .claude/tasks/agent-system/TASK-001-MULTIAGENT.md
