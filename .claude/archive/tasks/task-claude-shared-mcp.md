# Task-Claude-SharedMCP: Ortak MCP Sunucuları

**Durum:** done
**resolved_date:** 2026-05-02
**resolution_note:** tools-bank repo achieved MCP integration independently via separate system. Supabase MCP tools (supabase_query, supabase_rpc, supabase_migrate, etc.) are available via tools-bank extension. Shared MCP server approach via supergateway was not pursued; each system uses its own MCP configuration.

**Durum:** bekliyor
**Tarih:** 2026-04-04
**Branch:** fix/tech-debt
**Atanan:** Claude

## Hedef

Supabase, GitHub, Context7, TestSprite MCP sunucularını HTTP/SSE modunda
tek bir yerden başlat. Tüm agent'lar (Claude, OpenCode, Gwen) aynı instance'a bağlansın.

## Yapılacaklar

### Adım 1 — Başlatma scripti

`~/.egesut-mcp/start-mcps.sh`:
```bash
#!/bin/bash
# Token'lar ~/.bashrc'den veya .claude/CREDENTIALS.md'den al
SUPA_TOKEN="$SUPABASE_ACCESS_TOKEN"
GH_TOKEN="$GITHUB_TOKEN"

# Zaten çalışıyorsa durdur
pkill -f "supergateway.*310" 2>/dev/null; sleep 1

npx supergateway --port 3101 --stdio "mcp-server-supabase --access-token $SUPA_TOKEN" &
npx supergateway --port 3102 --stdio "mcp-server-github" &
npx supergateway --port 3103 --stdio "context7-mcp" &
npx supergateway --port 3104 --stdio "npx @testsprite/testsprite-mcp@latest" &

echo "✅ MCP sunucuları başlatıldı"
echo "  3101 → supabase | 3102 → github | 3103 → context7 | 3104 → testsprite"
```

### Adım 2 — Claude Code yapılandırması

`.claude.json`'dan stdio tanımlarını kaldır, HTTP URL ile değiştir:
```json
"supabase":  { "url": "http://localhost:3101/sse" }
"github":    { "url": "http://localhost:3102/sse" }
"context7":  { "url": "http://localhost:3103/sse" }
"TestSprite":{ "url": "http://localhost:3104/sse" }
```

### Adım 3 — OpenCode yapılandırması

`/root/opencode-dev/opencode.json`'a MCP bölümü ekle:
```json
"mcp": {
  "supabase":  { "url": "http://localhost:3101/sse" },
  "github":    { "url": "http://localhost:3102/sse" },
  "context7":  { "url": "http://localhost:3103/sse" }
}
```

### Adım 4 — Gwen yapılandırması

`.agents/qwen/settings.template.json`'a ekle:
```json
"mcpServers": {
  "supabase": { "url": "http://localhost:3101/sse" },
  "github":   { "url": "http://localhost:3102/sse" },
  "context7": { "url": "http://localhost:3103/sse" }
}
```

### Adım 5 — Otomatik başlatma

`~/.bashrc`'ye ekle:
```bash
~/.egesut-mcp/start-mcps.sh
```

### Adım 6 — Test

```bash
# Sunucular canlı mı?
curl -s http://localhost:3101/sse | head -3  # supabase
curl -s http://localhost:3102/sse | head -3  # github

# Claude'da test
claude mcp list  # hepsinin connected göstermesi lazım
```

## Kabul Kriterleri

- [ ] 4 MCP sunucusu HTTP/SSE modunda ayakta
- [ ] Claude Code HTTP modundan bağlanıyor
- [ ] OpenCode MCP tool'larını görüyor
- [ ] Gwen HTTP MCP'ye bağlanabiliyor
- [ ] ~/.bashrc'de otomatik başlatma aktif

## Notlar

- Token'lar `.claude/CREDENTIALS.md` ve `~/.bashrc`'de mevcut (repoya yazılmaz)
- supergateway zaten kurulu (`npx -y supergateway` çalışıyor)
- GitHub MCP için env: `GITHUB_PERSONAL_ACCESS_TOKEN` → `~/.bashrc`'den gelir
