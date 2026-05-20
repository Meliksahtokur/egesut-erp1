# Design: DeerFlow MCP Genişletme + Global Tools-Bank Skill

**Tarih:** 2026-05-20  
**Durum:** Onaylandı

---

## Özet

İki paralel geliştirme:

1. **DeerFlow MCP araçları genişletme** — thread yönetimi (stateful/stateless), memory okuma/yazma, agent listeleme ve hedefleme
2. **Global tools-bank skill** — mevcut `mem-tools` skill'i genişletilir, canonical konum tools-bank repo'sunda, `/root/.claude/skills/` altına symlink ile global erişim sağlanır

---

## Bölüm 1 — DeerFlow MCP Araçları

### Mevcut araçlar (değişmiyor)

| Araç | Açıklama |
|------|----------|
| `deerflow_health` | Gateway sağlık kontrolü |
| `deerflow_list_models` | Yapılandırılmış LLM listesi |
| `deerflow_list_skills` | Yüklü skill listesi |
| `deerflow_research(query, mode)` | Stateless araştırma — SSE streaming |

### Yeni araçlar

#### `deerflow_research` güncelleme
`agent_id: str = "lead_agent"` parametresi eklenir. Varsayılan davranış değişmez; override edilince seçilen agent'a gönderir.

#### `deerflow_chat(message, thread_id=None, agent_id="lead_agent")`
Stateful konuşma aracı.

- `thread_id=None` → yeni thread açar (`POST /api/threads`)
- `thread_id` verilirse → mevcut thread'e mesaj ekler
- SSE streaming ile yanıt toplar (research ile aynı mekanizma)
- Her zaman `{"thread_id": "...", "response": "..."}` döndürür
- Claude thread_id'yi saklayıp sonraki çağrıda geçebilir → stateful conversation

#### `deerflow_threads(limit=10)`
Son N thread'i listeler.

- `GET /api/threads?limit=N`
- Dönen bilgi: thread_id, oluşturulma tarihi, son mesaj özeti

#### `deerflow_agents()`
Mevcut agent'ları listeler.

- `GET /api/assistants`
- Dönen isimler `deerflow_chat` ve `deerflow_research`'e `agent_id` olarak geçilebilir

#### `deerflow_memory(action, query=None, content=None, category=None)`
DeerFlow'un kendi memory sistemi için hafif okuma/yazma arayüzü.

| action | Endpoint | Açıklama |
|--------|----------|----------|
| `"list"` | `GET /api/memory` | Son kayıtları listele |
| `"search"` | `GET /api/memory?q=...` | Query ile ara |
| `"add"` | `POST /api/memory` | content + category ile yaz |

> ⚠️ **Implementation notu:** DeerFlow memory endpoint path'i kesin değil. Implementation'da `GET /api/memory`, `/api/memories`, `/api/store` denenecek; bulunamazsa bu araç atlanır.

Silme dahil değil — DeerFlow kendi yönetir.

### Dosya
`/root/tools-bank/mcp_server/server.py` — DeerFlow araçları bölümüne eklenir.

### Güvenlik notu
`DEERFLOW_ADMIN_PASSWORD` default değeri (`"DeerFlow2026!"`) kaldırılır — env var yoksa `""` döner, login hata verir, kullanıcı bilgilendirilir.

---

## Bölüm 2 — Global Tools-Bank Skill

### Canonical konum
```
/root/tools-bank/skills/tools-bank/SKILL.md
```
Tools-bank repo'sunda yaşar — git geçmişi, review, değişiklik takibi burada olur.

### Global erişim — symlink
```bash
mkdir -p /root/.claude/skills/tools-bank
ln -sf /root/tools-bank/skills/tools-bank/SKILL.md \
        /root/.claude/skills/tools-bank/SKILL.md
```
Kaynak değişince symlink üzerinden tüm erişimler otomatik güncellenir.

### Global CLAUDE.md referansı
`/root/.claude/CLAUDE.md`'ye eklenir:
```markdown
# tools-bank-mcp
@/root/.claude/skills/tools-bank/SKILL.md
```

### Skill içerik yapısı

```
name: tools-bank-mcp
description: tools-bank MCP araç rehberi — memory, DeerFlow araştırma,
  agent telsiz, supabase. Trigger: "tools-bank", "memory ara", 
  "deerflow", "araştır", "tui+", "deepseek tui"
```

**Bölümler:**

1. **Karar tablosu** — hangi araç ne zaman
2. **Memory araçları** — `memory_search`, `memory_add`, `semantic_search`, `memory_stats`
3. **DeerFlow MCP araçları** — tüm yeni + mevcut araçlar, mod açıklamaları (flash/standard/pro/ultra), agent hedefleme
4. **DeepSeek TUI** — ne zaman MCP yerine TUI kullan, nasıl başlatılır
5. **Agent telsiz** — `agent_send`, `agent_receive`
6. **Supabase** — kısa referans, canonical dosyaya pointer
7. **CLI fallback** — MCP yoksa ne yapılır

### DeepSeek TUI bölümü

```
# DeepSeek TUI

MCP araçları programatik erişim sağlar. TUI interaktif terminal UI'ı.

## Ne zaman TUI tercih et
- Uzun araştırma (MCP timeout riski)
- İnteraktif multi-turn sohbet
- Gateway'i başlatman gerektiğinde

## Başlatma
tui+                  # Gateway + TUI tek komutla
tui+ --status         # Servis durumu
tui+ --stop           # Durdur

Script: /root/deer-flow/scripts/tui+.sh
Gateway port: 8001
```

### Eski `mem-tools` skill
`/root/tools-bank/skills/mem-tools/SKILL.md` silinir. İçeriği yeni skill'e taşınır.

---

## Uygulama Sırası

1. `server.py` — 5 DeerFlow aracı ekle/güncelle
2. Yeni skill dosyası yaz: `/root/tools-bank/skills/tools-bank/SKILL.md`
3. Symlink oluştur → `/root/.claude/skills/tools-bank/SKILL.md`
4. `/root/.claude/CLAUDE.md` güncelle
5. Eski `mem-tools` sil
6. MCP server'ı yeniden başlat, araçları test et
7. Commit

---

## Başarı Kriterleri

- [ ] `deerflow_chat` çağrılınca thread_id döndürür
- [ ] Aynı thread_id ile ikinci çağrı önceki context'i hatırlar
- [ ] `deerflow_agents()` mevcut agent listesini döndürür
- [ ] `deerflow_research(query, agent_id="X")` doğru agent'a gider
- [ ] `/root` dışı dizinden Claude açıldığında tools-bank-mcp skill yüklü gelir
- [ ] `tui+` komutu skill içinde doğru açıklanmış
