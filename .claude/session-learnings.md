# Session Learnings — EgeSüt ERP + Agent Sistemi

## Ana Gündem: İnteraktif Multi-Agent Orchestration Sistemi

**Hedef:** Tek komutla ayağa kalkan, MiniMax M2.7 ile çalışan, interaktif multi-agent sistemi.
**Mevcut Durum:** ✅ Temel altyapı test edildi ve çalışıyor.

---

## 2026-04-05 — Multi-Agent Sistem Araştırması

### Bulunan Hazır Çözümler

#### 1. `agent_framework_claude` — ANA ÇÖZÜM ⭐⭐⭐⭐⭐
**Kurulu:** `agent-framework-claude==1.0.0b260319` (/opt/agent-framework/.venv/lib/python3.12/site-packages/)

Microsoft Agent Framework'ün Claude entegrasyonu. **Bu bizim ana çözümümüz.**

```python
from agent_framework_claude import ClaudeAgent

agent = ClaudeAgent(
    instructions="Sen bir ERP koordinatörüsün...",
    default_options={
        "model": "MiniMax-M2.7",
        "cli_path": "/opt/agent-framework/.venv/lib/python3.12/site-packages/claude_agent_sdk/_bundled/claude",
        "permission_mode": "acceptEdits",
        "allowed_tools": ["Bash", "Read", "Glob", "Grep", "Agent"],
        "agents": {
            "db-analyst": {
                "description": "Veritabanı analizi yapar",
                "prompt": "...",
                "tools": ["Read", "Bash", "Glob"],
            },
            "code-analyst": {...},
        },
    }
)
await agent.start()
response = await agent.run("Soru")
result = await response
print(result.final_result)
await agent.stop()
```

**Özellikleri:**
- ✅ Interaktif loop — `while True: input()` + `agent.run()`
- ✅ Multi-turn session — her `run()` aynı session'da
- ✅ Subagent spawn — `agents` dict
- ✅ Built-in tools — Bash, Read, Glob, Grep, Edit, Write, WebSearch, WebFetch, Agent
- ✅ Permission modes — acceptEdits, bypassPermissions, plan
- ✅ MCP server desteği
- ✅ Model bağımsızlığı — arbitrary string

**Çalıştırma:**
```bash
unset CLAUDECODE && /opt/agent-framework/.venv/bin/python orchestrator.py
```

#### 2. `claude_agent_sdk` — Alternatif / Düşük Seviye
Claude Code CLI'yi Python'dan kontrol. Subagent spawn, MCP desteği var ama daha düşük seviye.

```python
from claude_agent_sdk import query, ClaudeAgentOptions, AgentDefinition

async for message in query(prompt, options=ClaudeAgentOptions(...)):
    if isinstance(message, ResultMessage):
        print(message.result)
```

### ÇALIŞMAYAN "Hazır Çözümler"
- ❌ `agent.start_interactive()` — YOK
- ❌ `ClaudeSDKClient.start_interactive()` — YOK
- ❌ `loop` CLI — Kurulu değil
- ❌ `agent_framework_claude` pip'ten ayrı — zaten kurulu, farklı path

---

## Önemli Teknik Notlar

### MiniMax M2.7 Entegrasyonu
```
base_url: https://api.minimax.io/anthropic     # (Agent SDK / Claude Code CLI)
API key:  sk-cp-4ErelSlnFkyo49Uc8H8RRZXr56LTT2jMrCRnWZp7aS0pmsJhfgNWn5VXX5aN9evd_XR5ExUknnFQSMBq6g4aeQrM2b5x2B1tuQARg076L81g3PBTJJmnH6A
```

### Nested Session Conflict
Claude Code içinde Claude Code çalışmaz. Çözüm:
```bash
unset CLAUDECODE && python script.py
```

### Response Handling (agent_framework_claude)
```python
# DOĞRU:
response = await agent.run("Soru")
result = await response
print(result.final_result)

# response bir ResponseStream coroutine döner
# await agent.run() → coroutine
# await coroutine → AgentResponse
# AgentResponse.final_result → string
```

### Claude Code CLI Path
```
/opt/agent-framework/.venv/lib/python3.12/site-packages/claude_agent_sdk/_bundled/claude
```

---

## MCP Kullanımı

### Supabase
```python
options={
    "mcp_servers": {
        "supabase": {
            "command": "npx",
            "args": ["-y", "@modelcontextprotocol/server-supabase"]
        }
    }
}
```

### GitHub
```python
options={
    "mcp_servers": {
        "github": {
            "command": "npx",
            "args": ["-y", "@modelcontextprotocol/server-github"],
            "env": {"GITHUB_TOKEN": os.environ["GITHUB_TOKEN"]}
        }
    }
}
```

### PostgreSQL
```python
options={
    "mcp_servers": {
        "postgres": {
            "command": "npx",
            "args": ["-y", "@modelcontextprotocol/server-postgres", database_url]
        }
    }
}
```

---

## Dosya Konumları

```
/root/agent-test/
├── orchestrator.py              ← Ana orchestrator script (çalışıyor)
├── test1.py                     ← Basit test
├── test2_spawn.py               ← Subagent test
└── research/
    └── INTERACTIVE_AGENT_SYSTEM_RESEARCH.md  ← Detaylı rapor
```

---

## MCP Durumu (Güncel)

| Tool | Durum |
|------|-------|
| `context7` | ✅ Plugin olarak |
| `github` | ✅ Plugin olarak |
| `TestSprite` | ✅ Plugin olarak |
| `supabase` | ✅ Plugin olarak |
| `ccm`, `chat`, `context7-mcp` | ❌ Kaldırıldı |

---

## Kullanılan Komutlar

```bash
# Agent Framework CLI çalıştırma
unset CLAUDECODE && /opt/agent-framework/.venv/bin/python script.py

# Python paketlerini listeleme
python -c "import importlib.metadata; print('\n'.join(sorted([f'{d.name}=={d.version}' for d in importlib.metadata.distributions()])))"

# Claude Code version
/opt/agent-framework/.venv/lib/python3.12/site-packages/claude_agent_sdk/_bundled/claude --version
```

---

## Sorunlar ve Çözümler

### "EOF when reading a line" — interaktif input()
input() TTY yoksa hata verir. Bu normal. Script terminalden çalıştırılmalı.

### Tool Runner Uyumsuzluğu
Direct Anthropic SDK'ın `tool_runner` Beta'sı MiniMax M2.7 ile çalışmıyor. Çözüm: Manual agentic loop veya `agent_framework_claude`.

### ClaudeSDKClient context manager nested conflict
`async with ClaudeSDKClient()` aynı session'da tekrar çalışmıyor. Çözüm: `agent_framework_claude` kullan.

---

## Ne Yapıldı / Ne Yapılacak

### ✅ Yapıldı
- [x] MiniMax M2.7 + Claude Agent SDK bağlantısı test edildi
- [x] `agent_framework_claude` keşfedildi ve test edildi
- [x] Subagent spawn çalıştı (3 paralel agent)
- [x] Manual tool loop çalıştı
- [x] İnteraktif loop potansiyeli doğrulandı
- [x] Araştırma raporu yazıldı

### 🔲 Yapılacak
- [ ] `orchestrator.py` dosyasını tamamlayıp test et
- [ ] MCP tool'ları entegre et (Supabase, GitHub)
- [ ] Konfigürasyon sistemi tasarla
- [ ] Kendi cihazında test et
- [ ] OpenAgents (oa) ile karşılaştır

---

## Kurallar

1. **Multi-agent orchestration her zaman gündemde olsun** — Ana işimiz bu
2. **Nested session kullanma** — `unset CLAUDECODE` şart
3. **agent_framework_claude birincil çözüm** — Sıfırdan yazma
4. **MCP server'ları dene** — Supabase, GitHub, Postgres
5. **Tool runner Beta'yı MiniMax ile kullanma** — Uyumsuz, manual loop kullan

## 2026-04-05 — Context7 Doğrulama Sonuçları

### ❌ NofX Araştırması Hatalı
Gerçek NofX crypto trading OS — yazılımla ilgisi yok.

### ✅ Kilo Code — EN İYİ
- MiniMax M2.5/M2.7 **native** (Settings → Providers → MiniMax)
- Orchestrator mode + Agent Manager
- Parallel Mode (git worktree)
- Auto Balanced: code/build/explore → MiniMax M2.5

### ✅ Cline — İKİNCİ
- MiniMax **native** (provider config)
- CLI: `npm install -g cline`
- Subagent: read-only paralel agent'lar

### 🟡 Roo Code — ÜÇÜNCÜ
- OpenRouter/custom provider ile MiniMax
- MCP server JSON config

### ⚠️ agent_framework_claude Durumu
- Subprocess spawn takılıyor (MiniMax API timeout/iletişim)
- Henüz çözülmedi
- Alternatif: Kilo Code veya Cline ile devam et

## 2026-04-05 — VS Code + Kilo Code Kurulumu

### Code-Server
- `/root/.npm-global/bin/code-server` → symlink bozuktu
- Kullanıcı kendisi kurdu: http://localhost:8080
- Status: ✅ Çalışıyor (302 redirect)
- Şifre: `22a0ad0fa576b622f04c45c0`

### ⚠️ code-server Android Limitasyonu
- Microsoft marketplace'e erişemiyor → kapalı kaynak extensions çalışmaz
- Sadece **Open VSX** marketplace açık
- Kilo Code açık kaynak olduğu için çalışıyor
- GitHub Copilot çalışmaz — Microsoft marketplace gerekli

### ✅ Kilo Code Durumu (2026-04-04 güncellendi)
- **Kurulu:** `kilocode.kilo-code-7.1.20-linux-arm64` (Open VSX)
- **Çalışıyor:** 11 `kilo serve` process'i aktif
- **Port:** 0 (random port — code-server'a bağlı)
- **Açık kaynak:** Open VSX marketplace'den geliyor — code-server'da çalışıyor!
- **MiniMax desteği:** Var
- **Orchestrator mode:** Var

### Kilo Code CLI
```bash
/root/.local/share/code-server/extensions/kilocode.kilo-code-7.1.20-linux-arm64/bin/kilo --help
```

### Alternatifler
- Cline: `npm install -g cline` (npm cache bozuktu, düzeltilmeli)
- code-server binary: manuel indirilebilir

---

## 2026-04-05 — MiniMax M2.7 + Agent Sistemi Güncelleme

### Araştırma Sonuçları

#### 1. MiniMax Official: Mini Agent
- **Repo:** github.com/MiniMax-AI/mini-agent
- **Model:** M2.5/M2.1 tabanlı, M2.7 uyumluluğu TEST EDİLDİ ✅
- **Mimari:** Direct HTTP API (subprocess yok!)
- **Kurulum:** `uv tool install git+https://github.com/MiniMax-AI/Mini-Agent.git`
- **Config:** `~/.mini-agent/config/config.yaml`
- **MCP:** `~/.mini-agent/config/mcp.json`
- **Kullanım:** `mini-agent --workspace /path`
- **Tool'lar:** ReadTool, WriteTool, EditTool, BashTool
- **Skills:** 15 hazır skill (PDF, DOCX, XLSX, PPTX, Canvas, MCP-Builder, etc.)
- **⚠️ Kritik:** Multi-agent yok — tek instance, subagent spawn yok

#### 2. ClawTeam — Framework-Agnostic Agent Coordinator
- **Repo:** PyPI: clawteam (v0.2.0)
- **Kurulum:** `pip install clawteam`
- **Özellikler:**
  - `spawn` — agent başlatma (tmux veya subprocess backend)
  - `board` — canlı dashboard (live, serve web UI)
  - `team` — ekip yönetimi (spawn-team, status, snapshot)
  - `session` — persistence (resume, snapshot/restore)
  - `task` — görev kuyruğu
  - `lifecycle` — agent lifecycle management
  - `template` — hazır team template'leri (software-dev, code-review, etc.)
- **Komut:** `clawteam spawn --backend subprocess --command "..."`
- **⚠️ Kritik:** Varsayılan Claude CLI kullanıyor, `--command` ile MiniMax'e yönlendirilebilir

### Test Sonuçları

#### MiniMax M2.7 + Mini Agent ✅
```
Test 1: Basit query
- Süre: 10.6 saniye
- Sonuç: ✅ Çalışıyor

Test 2: Tool kullanımı (write_file + bash)
- Süre: 15.8 saniye (4 adım)
- Sonuç: ✅ Çalışıyor, self-correction da çalışıyor
```

#### ClawTeam + MiniMax (test edilmedi henüz)
- Kuruldu ✅
- CLI anlaşıldı ✅
- MiniMax ile entegrasyon: **TEST EDİLMEDİ**

### Mimari Önerileri (Karar Bekliyor)

#### Yol A: ClawTeam + MiniMax
```
SEN (orchestrator)
  └── ClawTeam (agent coordinator)
        ├── Mini Agent #1 (worker)
        ├── Mini Agent #2 (worker)
        └── Mini Agent #3 (worker)
```
- ✅ Hazır, kuruldu
- ✅ Board/dashboard var
- ✅ Session persistence var
- ⚠️ MiniMax entegrasyonu test edilmedi

#### Yol B: Mini Agent Base + Custom Multi-Agent Layer
```
MiniMax M2.7 (direct HTTP)
  └── Mini Agent (base)
        └── Custom Layer (biz yazacağız)
              ├── Agent Pool
              ├── Task Router
              └── Result Aggregator
```
- ✅ Direct API, subprocess yok
- ✅ Tam kontrol
- ❌ Baştan yazmak gerekiyor (8-12 gün)

### Karar Bekleyen Konular
1. ClawTeam + MiniMax entegrasyonu test edilecek
2. Board web UI test edilecek
3. Multi-agent team oluşturulacak
4. Fail recovery test edilecek

### Öğrenilen Dersler
- Kritik kararlarda (kurulum, mimari değişikliği) ÖNCE kullanıcıya danış
- Araştırma sonuçlarını paylaş, kararı birlikte ver
- Memory'yi güncelle — öğrenilenleri kaydet

---

## 2026-04-05 — Araç Karşılaştırması Güncelleme

### Araştırılan / Test Edilen Araçlar

| Araç | Tip | MiniMax Uyumu | Durum |
|------|-----|---------------|-------|
| **ClawTeam** | CLI | ⚠️ `--command` ile yönlendirilebilir | ✅ Kuruldu, test edilmedi |
| **Animus** | ML Experiment Framework | ❌ Uyumsuz | ❌ Yanlış seçim — ML için, agent coordination değil |
| **Strands Agents** | Python SDK | ✅ Python ile entegre edilebilir | ✅ Kuruldu, test edilmedi |
| **agent_framework_claude** | Python SDK | ✅ Claude Code CLI wrapper | ✅ Kuruldu, timeout sorunu var |

### Önemli Not
- Araştırma sonuçlarına göre kurulum yapmadan önce TÜM seçenekleri test et
- Sadece ilk bulunanı değil, hepsini karşılaştır
- Kritik kararlarda kullanıcıya danış

### Strands Agents Özellikleri (İnceleme Bekliyor)
- AWS açık kaynak agent SDK
- Python native
- `Agent` class + tool/function calling
- MCP desteği olabilir
- MiniMax M2.7 ile direct API kullanılabilir mi test edilmeli

### Sonraki Adım
1. Strands Agents + MiniMax M2.7 test et
2. ClawTeam + MiniMax test et  
3. Karşılaştır, karar ver
