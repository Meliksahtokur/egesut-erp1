# NotebookLM Entegrasyonu — Kaldığımız Yer (2026-05-22)

## Durum: ✅ Kurulum tamam, 🔲 Auth kaldı

### Yapılanlar
- [x] `notebooklm-mcp-cli-0.6.10` kuruldu (`/tmp/nlm-venv/bin/`)
- [x] Skill oluşturuldu: `/root/.deepseek/skills/notebooklm/SKILL.md`
- [x] MCP entry eklendi: `/root/.deepseek/mcp.json` → `notebooklm` server
- [x] `.bashrc` alias: `nlm` + `nlm-mcp`
- [x] Proje symlink: `.claude/skills/notebooklm`

### Kalan (Auth — bir kere yapılacak)
NotebookLM MCP server'ı çalıştırmak için Google session cookie'si lazım:

**Seçenek 1 — Tablet ile (Kiwi Browser + Cookie-Editor):**
1. Kiwi Browser yükle
2. Cookie-Editor eklentisi ekle
3. `notebooklm.google.com`'a gir, oturum aç
4. Cookie-Editor → Export JSON → kopyala
5. Bir dosyaya kaydet: `cat > /tmp/nlm-cookies.json` (yapıştır, Ctrl+D)
6. `/tmp/nlm-venv/bin/nlm login --manual --file /tmp/nlm-cookies.json`

**Seçenek 2 — Geçici VPS/Codespaces'de Playwright ile:**
1. `pip install notebooklm-mcp-cli && nlm login`
2. Çıkan `~/.notebooklm-mcp/auth.json`'u tablete kopyala

### Auth başarılı olursa
- DeepSeek TUI'yi yeniden başlat → notebooklm MCP tool'ları otomatik gelir
- `chat_with_notebook`, `search_notebook`, `list_notebooks` vb. 31 tool hazır

### Referans
- Skill: `/skill:notebooklm`
- CLI: `nlm notebook list`
- MCP: `notebooklm-mcp --transport stdio`
