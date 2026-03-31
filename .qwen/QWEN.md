## 📌 KRİTİK: İki Ofis Sistemi

Bu projede **İKİ FARKLI ofis** çalışıyor. Sen **Gwen/Qwen Ofisi**'ndesin (Mühendislik).

### Ofis Hiyerarşisi

```
┌─────────────────────────────────────────────────────────┐
│  CLAUDE OFİSİ (Üst / İdari / Yönetim)                   │
│  - Proje üretimi, task yönetimi, merge yetkisi          │
│  - Senin ÜSSÜN - senin kodunda düzenleme yapabilir      │
│  - 15 agent'ı (haiku/sonnet) koordine eder              │
└─────────────────────────────────────────────────────────┘
                          │
                          │ (yönetir)
                          ▼
┌─────────────────────────────────────────────────────────┐
│  GWEN/QWEN OFİSİ (Mühendislik / Kod Üretimi)            │
│  - Sadece kod üretimi, feature geliştirme               │
│  - Claude'da düzenleme YAPAMAZSIN (tek yönlü koruma)    │
│  - Feature branch'lerde çalışır, PR ile merge eder      │
└─────────────────────────────────────────────────────────┘
```

### Yetki Sınırların

| Yapabilirsin ✅ | Yapamazsın ❌ |
|----------------|---------------|
| `.qwen/` dizininde çalış | `.claude/` dizinini DEĞİŞTİRME |
| `feature/gwen-*` branch'lerde kod üret | CLAUDE.md'yi DEĞİŞTİRME |
| MCP servers kullan | Claude agent'larını spawn ETME |
| Gwen native agent'larını spawn et | main branch'e direkt PUSH YAP |
| PR aç (Claude merge eder) | Claude orkestrasyonuna MÜDAHALE ET |

**Detaylı hiyerarşi:** `.qwen/AGENT_HIERARCHY.md`

---

## 🛠️ Session Yönetimi (Termux/PRoot)

### Memory Limit
```bash
export NODE_OPTIONS="--max-old-space-size=256"  # .bashrc'ye eklendi
```

### Zombie Process Temizliği
```bash
./session-clean.sh  # Her 4 saatte bir çalıştır
```

### MCP Server Doğrulama
```bash
qwen mcp list  # Her görev öncesi
```

---

## MCP Server Usage
**Before using any MCP server, verify it's properly configured by running `qwen mcp list` and test with a simple query first.**

This prevents hallucinations and ensures tools are actually available before relying on them.

## UI Changes Verification
**After making UI changes, always verify the fix works before considering the task complete.**

Don't just apply the fix and commit - run the app, test the functionality, and confirm the issue is resolved.

## Shell Command Best Practices
**When shell commands fail, try breaking complex commands into separate simpler commands.**

Example: Instead of `cat file1 file2 file3`, run separate commands to see each file's contents individually.

## MCP Server Protection Rules (CRITICAL)

### Never Delete MCP Configurations
**Under NO circumstances should you:**
- Run `qwen mcp remove <server>` unless explicitly requested by user
- Modify `/root/.qwen/settings.json` to remove MCP server configurations
- Overwrite MCP server `env` variables with empty values
- Use any command that would disconnect active MCP servers

### Required MCP Servers for EgeSüt ERP Project
These MCP servers MUST always remain configured:

1. **gwen-supabase** - Database operations
   - Command: `node`
   - Args: `/root/egesut-erp1/gwen-mcp-servers/supabase/index.js`
   - Env: `SUPABASE_KEY`

2. **gwen-github** - PR, issues, commits
   - Command: `node`
   - Args: `/root/egesut-erp1/gwen-mcp-servers/github/index.js`
   - Env: `GITHUB_TOKEN`

3. **context7** - Documentation lookup
   - Command: `npx`
   - Args: `-y @upstash/context7-mcp@latest`
   - Env: `CONTEXT7_API_KEY`

### MCP Restore Procedure
If any MCP server becomes disconnected or is accidentally removed:

1. **Check current status:**
   ```bash
   qwen mcp list
   ```

2. **If removed, restore by editing /root/.qwen/settings.json:**
   
   Add/fix the `mcpServers` section:
   ```json
   "mcpServers": {
     "gwen-supabase": {
       "command": "node",
       "args": ["/root/egesut-erp1/gwen-mcp-servers/supabase/index.js"],
       "cwd": "/root/egesut-erp1/gwen-mcp-servers/supabase",
       "env": {"SUPABASE_KEY": "sbp_8d52cb7f589f54575d9599fe0edfa126666a32f1"},
       "trust": true
     },
     "gwen-github": {
       "command": "node",
       "args": ["/root/egesut-erp1/gwen-mcp-servers/github/index.js"],
       "cwd": "/root/egesut-erp1/gwen-mcp-servers/github",
       "env": {"GITHUB_TOKEN": "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"},
       "trust": true
     },
     "context7": {
       "command": "npx",
       "args": ["-y", "@upstash/context7-mcp@latest"],
       "env": {"CONTEXT7_API_KEY": "ctx7sk-3690ea35-9122-479a-b65b-d4fe04478ff1"},
       "trust": true
     }
   }
   ```

3. **Verify restoration:**
   ```bash
   qwen mcp list
   ```
   All servers should show "Connected" status.

4. **If Qwen Code session doesn't pick up changes:**
   - User must restart Qwen Code session

### Agent Responsibility
All agents (gwen-architect, gwen, general-purpose, Explore) MUST:
- Use MCP servers for their intended purposes (database queries, GitHub operations, documentation)
- Never attempt to remove or disable MCP servers
- Report MCP connection issues immediately
- Test MCP connectivity before starting complex tasks
