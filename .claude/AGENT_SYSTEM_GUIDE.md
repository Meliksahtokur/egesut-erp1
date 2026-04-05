# 🤖 Multi-Agent Orchestration Sistemi — Kullanım Kılavuzu

> **Ana Gündem:** Bu dosya her zaman güncel tutulmalı. Yeni bir şey öğrenildiğinde buraya ekle.

---

## Hızlı Başlangıç

### Orchestrator'ı Çalıştır
```bash
cd /root/agent-test
unset CLAUDECODE && /opt/agent-framework/.venv/bin/python orchestrator.py
```

### Yeni Orchestrator Scripti Yaz
```python
from agent_framework_claude import ClaudeAgent
import asyncio

async def main():
    agent = ClaudeAgent(
        instructions="Sen bir [ROL] agent'sın...",
        default_options={
            "model": "MiniMax-M2.7",
            "cli_path": "/opt/agent-framework/.venv/lib/python3.12/site-packages/claude_agent_sdk/_bundled/claude",
            "permission_mode": "acceptEdits",
            "allowed_tools": ["Bash", "Read", "Glob", "Grep", "Agent"],
            "max_turns": 10,
            "agents": {
                "agent-adi": {
                    "description": "Ne yapar",
                    "prompt": "Agent sistem promptu",
                    "tools": ["Bash", "Read"],
                }
            }
        }
    )
    await agent.start()
    
    # Interaktif loop
    while True:
        user_input = input("> ")
        if user_input.lower() in ["exit", "quit"]:
            break
        response = await agent.run(user_input)
        result = await response
        print(result.final_result)
    
    await agent.stop()

asyncio.run(main())
```

---

## Kurulu Paketler

```
agent-framework==1.0.0rc5          ← Ana framework
agent-framework-claude==1.0.0b260319  ← Claude entegrasyonu (BİZİM ÇÖZÜMÜMÜZ)
agent-framework-core==1.0.0rc5
claude-agent-sdk (bundled)        ← Claude Code CLI + SDK
```

### Python Path
```
/opt/agent-framework/.venv/bin/python
```

### Claude Code CLI Path
```
/opt/agent-framework/.venv/lib/python3.12/site-packages/claude_agent_sdk/_bundled/claude
```

---

## API Bilgileri

```
MiniMax Base URL:  https://api.minimax.io/anthropic
MiniMax API Key:   sk-cp-4ErelSlnFkyo49Uc8H8RRZXr56LTT2jMrCRnWZp7aS0pmsJhfgNWn5VXX5aN9evd_XR5ExUknnFQSMBq6g4aeQrM2b5x2B1tuQARg076L81g3PBTJJmnH6A
Model:            MiniMax-M2.7
```

---

## Bileşen Referansı

### agent_framework_claude.ClaudeAgent

**Import:**
```python
from agent_framework_claude import ClaudeAgent
```

**Ana Parametreler:**

| Parametre | Tip | Açıklama |
|-----------|-----|----------|
| `instructions` | str | System prompt |
| `default_options` | dict | ClaudeAgentOptions |
| `default_options.model` | str | "MiniMax-M2.7" |
| `default_options.cli_path` | str | Claude CLI yolu |
| `default_options.permission_mode` | str | "acceptEdits" |
| `default_options.allowed_tools` | list | Tool isimleri |
| `default_options.agents` | dict | Subagent tanımları |
| `default_options.mcp_servers` | dict | MCP server configs |
| `default_options.max_turns` | int | Max tur sayısı |
| `default_options.cwd` | str | Çalışma dizini |

**Allowed Tools Listesi:**
```python
["Bash", "Read", "Write", "Edit", "Glob", "Grep", "WebSearch", "WebFetch", "Agent", "TodoWrite", "Notebook"]
```

**Subagent Tanımı:**
```python
"agents": {
    "agent-adi": {
        "description": "Açıklama (ne zaman çağrılacağı)",
        "prompt": "System prompt",
        "tools": ["Bash", "Read", "Glob"],
        "model": "MiniMax-M2.7",  # opsiyonel
        "max_turns": 5,           # opsiyonel
    }
}
```

### Response Handling

```python
# agent.run() her zaman coroutine döner
response_coro = agent.run("Soru")

# ResponseStream'i await et
response_stream = await response_coro

# AgentResponse'dan final_result al
result = await response_stream
print(result.final_result)  # ← asıl metin

# AgentResponse attributes:
# - final_result: str
# - messages: list
# - usage: UsageInfo
```

---

## MCP Server Entegrasyonu

### Supabase
```python
"mcp_servers": {
    "supabase": {
        "command": "npx",
        "args": ["-y", "@modelcontextprotocol/server-supabase"]
    }
}
```

### GitHub
```python
import os
"mcp_servers": {
    "github": {
        "command": "npx",
        "args": ["-y", "@modelcontextprotocol/server-github"],
        "env": {"GITHUB_TOKEN": os.environ["GITHUB_TOKEN"]}
    }
}
```

### PostgreSQL
```python
"mcp_servers": {
    "postgres": {
        "command": "npx",
        "args": ["-y", "@modelcontextprotocol/server-postgres", database_url]
    }
}
```

### MCP Tool Kullanımı
```python
# allowed_tools'a MCP tool'unu ekle
"allowed_tools": [
    "mcp__github__list_issues",
    "mcp__supabase__execute_sql",
    "mcp__postgres__query"
]
```

---

## Bilinen Sorunlar ve Çözümler

### 1. Nested Session Conflict
**Hata:** `Command failed with exit code 1` — Claude Code içinde Claude Code çalışmaya çalışıyor.

**Çözüm:**
```bash
unset CLAUDECODE
```

### 2. EOF When Reading Line
**Hata:** `EOFError` — input() TTY yok (script arkada çalışıyor).

**Çözüm:** Terminalden/interaktif olarak çalıştır. Bu beklenen bir durum, script değil terminal aç.

### 3. Tool Runner Uyumsuzluğu
**Durum:** `client.beta.messages.tool_runner()` MiniMax M2.7 ile çalışmıyor.

**Çözüm:** `agent_framework_claude` veya manual agentic loop kullan.

### 4. Response Type Confusion
**Hata:** `TypeError: object AgentResponse can't be used in 'await' expression`

**Doğru:**
```python
result = await (await agent.run("Soru"))
```

---

## Test Komutları

```bash
# Basit test
unset CLAUDECODE && /opt/agent-framework/.venv/bin/python -c "
import asyncio
from agent_framework_claude import ClaudeAgent
async def t():
    a = ClaudeAgent(instructions='Türkçe 1 cümle selam ver.', default_options={'model': 'MiniMax-M2.7', 'cli_path': '/opt/agent-framework/.venv/lib/python3.12/site-packages/claude_agent_sdk/_bundled/claude', 'max_turns': 1})
    await a.start()
    r = await (await a.run('Selam'))
    print(r.final_result)
    await a.stop()
asyncio.run(t())
"

# Paket listesi
/opt/agent-framework/.venv/bin/python -c "import importlib.metadata; [print(f'{d.name}=={d.version}') for d in importlib.metadata.distributions() if 'agent' in d.name.lower()]"

# Claude version
/opt/agent-framework/.venv/lib/python3.12/site-packages/claude_agent_sdk/_bundled/claude --version
```

---

## Dosya Yapısı

```
/root/agent-test/
├── orchestrator.py              ← Ana orchestrator (çalışıyor)
├── orchestrator_simple.py       ← Basit versiyon
├── test_*.py                    ← Çeşitli testler
└── research/
    └── INTERACTIVE_AGENT_SYSTEM_RESEARCH.md  ← Detaylı araştırma

/root/opencode-dev/.claude/
├── session-learnings.md          ← Bu oturumun notları
└── AGENT_SYSTEM_GUIDE.md        ← Bu kılavuz (kalıcı referans)
```

---

## Sonraki Adımlar

```
Priority 1:
  [ ] orchestrator.py dosyasını test et ve iyileştir
  [ ] Kendi cihazında test et

Priority 2:
  [ ] MCP tool'ları entegre et (Supabase, GitHub)
  [ ] Konfigürasyon sistemi (agent-config.json)

Priority 3:
  [ ] OpenAgents (oa) ile karşılaştır
  [ ] Farklı modelleri test et (Claude Opus, Sonnet)
  [ ] Production deployment planı yap
```

---

## Kaynaklar

| Kaynak | URL/Not |
|--------|---------|
| Claude Agent SDK Docs | platform.claude.com/docs/en/agent-sdk |
| MCP Servers | github.com/modelcontextprotocol/servers |
| agent_framework_claude | /opt/agent-framework/.venv/lib/python3.12/site-packages/agent_framework_claude/ |
| MiniMax API | api.minimax.io/anthropic/v1 |
