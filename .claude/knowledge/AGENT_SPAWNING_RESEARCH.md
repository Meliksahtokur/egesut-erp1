# Agent Spawning — Claude CLI + MiniMax M2.7 (GÜNCEL)
> Araştırma tarihi: 2026-04-04 (güncellendi)
> Araştırmacı: MiniMax M2.7 (me) + kullanıcı araştırması
> Durum: ✅ ÇALIŞIYOR — minimax:MiniMax-M2.7 formatı doğrulandı

---

## ÖZET — KRİTİK BULGU

```
✅ Agent spawn ÇALIŞIYOR!
✅ Model format: minimax:MiniMax-M2.7 (MiniMax prefix gerekiyor)
✅ CLI flag: --agents '{...,"model":"minimax:MiniMax-M2.7"...}'
✅ settings.json: ANTHROPIC_DEFAULT_SONNET_MODEL: MiniMax-M2.7 (model alias)
```

**Doğrulama:** `echo "msg" | claude --agents '{"test":{"model":"minimax:MiniMax-M2.7","prompt":"..."}}'`

**Agent dosyaları:** Frontmatter'da `model: minimax:MiniMax-M2.7` olarak güncellendi.

---

## 1. NASIL ÇALIŞIYOR — Doğrulandı (2026-04-04)

### Model Format: `minimax:MiniMax-M2.7`

MiniMax modeli için `minimax:` prefix'i gerekiyor. Bu Claude Code'a MiniMax API'sini kullanmasını söylüyor.

**Test sonucu:**
```
$ echo "test" | claude --agents '{"t":{"model":"minimax:MiniMax-M2.7","prompt":"..."}}'
MINIMAX_AGENT_SPAWNED  ✅
```

### settings.json Ayarları (güncellendi):

```json
"ANTHROPIC_BASE_URL": "https://api.minimax.io/anthropic",
"ANTHROPIC_MODEL": "MiniMax-M2.7",
"ANTHROPIC_DEFAULT_SONNET_MODEL": "MiniMax-M2.7",
"ANTHROPIC_SMALL_FAST_MODEL": "MiniMax-M2.7",
"ANTHROPIC_DEFAULT_OPUS_MODEL": "MiniMax-M2.7",
"ANTHROPIC_DEFAULT_HAIKU_MODEL": "MiniMax-M2.7"
```

### Agent Dosyaları (güncellendi):

| Dosya | Eski | Yeni |
|-------|------|------|
| orchestrator.md | `model: sonnet` | `model: minimax:MiniMax-M2.7` |
| erp-implementer.md | `model: sonnet` | `model: minimax:MiniMax-M2.7` |
| erp-explorer.md | `model: haiku` | `model: minimax:MiniMax-M2.7` |
| erp-qa-git.md | `model: haiku` | `model: minimax:MiniMax-M2.7` |

### MkXultra CCM/Chat MCP (ARTIK GEREKİ DEĞİL):

Chat + CCM MCP sunucuları multi-agent room iletişimi için kullanılıyordu.
Ama agent spawn için bunlar GEREKMİYOR — native `--agents` flag yeterli.

---

## 2. ÇÖZÜM: MCP SUNUCULARI YÜKLE

### settings.local.json'a eklenecek:

```json
{
  "mcpServers": {
    "chat": {
      "command": "npx",
      "args": ["agent-communication-mcp"],
      "cwd": "/root/opencode-dev"
    },
    "ccm": {
      "command": "npx",
      "args": ["@mkxultra/claude-code-mcp@latest"],
      "cwd": "/root/opencode-dev"
    }
  }
}
```

### Kurulum adımları:

```bash
# 1. settings.local.json oluştur/y düzenle
# 2. Yukarıdaki mcpServers ekle
# 3. Claude Code'u yeniden başlat
# 4. /mcp komutuyla doğrula — chat ve ccm görünmeli
```

### Alternatif: mcp_add.sh scripti

```bash
git clone https://github.com/mkXultra/claude_code_setup /tmp/claude_code_setup
ln -s /tmp/claude_code_setup /root/opencode-dev/guide
cd /root/opencode-dev
./guide/mcp_add.sh
```

---

## 3. MİNİMAX M2.7 AYARLARI (ZATEN ÇALIŞIYOR)

### Mevcut env değişkenleri (doğru):

```
ANTHROPIC_BASE_URL=https://api.minimax.io/anthropic
ANTHROPIC_API_KEY=sk-cp-...           ← MiniMax API key (çalışıyor!)
ANTHROPIC_MODEL=MiniMax-M2.7
ANTHROPIC_DEFAULT_SONNET_MODEL=MiniMax-M2.7
ANTHROPIC_DEFAULT_HAIKU_MODEL=MiniMax-M2.7
MINIMAX_API_KEY=sk-cp-...             ← Aynı key
```

**Bu ayarlar zaten doğru. Değişiklik gerekmiyor.**

### Agent dosyalarında model formatı:

```yaml
# İki format da çalışır:
model: inherit              # Ana session modeli (MiniMax-M2.7) kullanır
model: minimax:MiniMax-M2.7         # Explicit MiniMax-M2.7
model: minimax:MiniMax-M2.7  # Alternatif format
```

---

## 4. mkXultra/claude_code_setup REPOSU

**URL:** `https://github.com/mkXultra/claude_code_setup`

### İçerdiği:

| Bileşen | Açıklama |
|---------|----------|
| `mcp_add.sh` | Chat + CCM + Playwright MCP kurulum scripti |
| `guide/multi-agent-bug-fix-workflow.md` | 4-agentlı bug fix workflow |
| `guide/multi-agent-investigation-workflow.md` | Çoklu araştırma workflow |

### Multi-Agent Bug Fix Workflow Agent'ları:
1. **Investigation Agent** — Bug analizi
2. **Implementation Agent** — Düzeltme uygulama
3. **Review Agent** — Kod review
4. **Debug Agent** — Hata giderme

---

## 5. KULLANICI ARAŞTIRMASI NOTLARI

Kullanıcının bulduğu kritik bilgiler:

1. **Doğru API URL:** `https://api.minimax.io/anthropic` (çalışıyor)
2. **API Key format:** `sk-cp-...` (MiniMax formatı)
3. **Agent model format:** `minimax:MiniMax-M2.7`
4. **settings.json'da env:** API key ve URL zaten doğru ayarlanmış
5. **eksik olan:** Chat + CCM MCP sunucuları

---

## 6. ŞU AN YAPILACAKLAR

```
ADIM 1 ──────────────────────────────────────────────────────────
│  settings.local.json oluştur/y düzenle
│  → mcpServers: chat + ccm ekle
│  → permissions ve diğer ayarlar korunur
│
ADIM 2 ──────────────────────────────────────────────────────────
│  Claude Code'u yeniden başlat
│  → /mcp komutuyla chat + ccm doğrula
│
ADIM 3 ──────────────────────────────────────────────────────────
│  Agent tool test et
│  → "erp-explorer agent'ı kullan" de
│  → Agent spawn edilmeli
│
ADIM 4 ──────────────────────────────────────────────────────────
│  Çalışıyorsa:
│  → Paralel agent spawn test et
│  → Agent dosyalarını oluştur
│
ADIM 5 ──────────────────────────────────────────────────────────
│  Çalışmıyorsa:
│  → mkXultra repo'dan mcp_add.sh dene
│  → Alternatif: claude-code-setup plugin'ini etkinleştir
```

---

## 7. settings.local.json ŞABLONU

```json
{
  "env": {},
  "permissions": {
    "allow": [
      "Bash(*)",
      "Read(*)",
      "Write(*)",
      "Edit(*)",
      "Glob(*)",
      "Grep(*)",
      "WebFetch(*)",
      "WebSearch(*)"
    ],
    "defaultMode": "acceptEdits",
    "additionalDirectories": [
      "/root/.claude",
      "/root/egesut-erp1",
      "/tmp"
    ]
  },
  "mcpServers": {
    "chat": {
      "command": "npx",
      "args": ["agent-communication-mcp"],
      "cwd": "/root/opencode-dev"
    },
    "ccm": {
      "command": "npx",
      "args": ["@mkxultra/claude-code-mcp@latest"],
      "cwd": "/root/opencode-dev"
    }
  }
}
```

---

## 8. KAYNAKLAR

- mkXultra repo: `https://github.com/mkXultra/claude_code_setup`
- Kurulum scripti: `mcp_add.sh` (repo içinde)
- Workflow dosyaları: `guide/multi-agent-*.md`
- MCP ekleme: `claude mcp add-json <name> '{"command":"npx","args":[...]}'`

---

## 9. SONRAKI ADIM

**Kullanıcı onayı gerekli:**
1. settings.local.json oluşturulsun mu?
2. Chat + CCM MCP eklensin mi?
3. Sonra Agent spawn test edilsin mi?
