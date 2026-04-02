# 🏗️ Yeni Mimari: Claude Orkestratör Sistemi

## Session Tipi Kilidi (KRİTİK)

Bu sistemde **İKİ FARKLI session tipi** vardır. Her session başlarken tipi belirlenir ve **değiştirilemez**:

| Session Tipi | Amaç | Branch | Yasak |
|--------------|------|--------|-------|
| **dev** | EgeSüt ERP geliştirme | `feature/gwen-*` | Arge işi YASAK |
| **arge** | Gwen/Qwen sistem geliştirme | `feature/gwen-arge` | ERP dev YASAK |

**Kural:** Session tipi başında belirlenir, sonuna kadar değişmez. İhlal yok.

---

## 📊 Hiyerarşi

```
Claude (orkestratör)
├── gwen-dev     → Developer Qwen (ERP geliştirme)
│                 ├── Paralel subagentlar (backend+frontend aynı anda)
│                 ├── Test runner kendi subagenti
│                 └── Sadece ERP geliştirme — arge işi yasak
└── gwen-arge    → AR-GE Qwen (sistem geliştirme)
                  ├── Qwen skills, agents, MCP geliştirme
                  ├── Workflow iyileştirme
                  └── Sadece AR-GE işleri — ERP dev yasak
```

### Sub-Orchestrator Kuralı
- **Claude** → tek orkestratör, Qwen spawn edebilir
- **Qwen** → subagent spawn edebilir (gwen-architect, gwen, general-purpose, Explore)
- **Subagent** → başka subagent spawn edemez (runner olarak çalışır)

### Runner Subagent Kuralı
- Runner subagent = aynı ekranda çalışır, ayrı ekran değil
- Paralel okuma/yazma için kullanılır
- **Aynı dosyaya paralel yazma YASAK** — çakışma önlenir

---

## 🚀 Gwen Script Kullanımı

### Session Başlatma

**Dev Session (ERP Geliştirme):**
```bash
gwen dev task "Tohumlama formuna tarih validasyonu ekle"
```

**Arge Session (Sistem Geliştirme):**
```bash
gwen arge task "Yeni session-rules skill'i oluştur"
```

### Script Davranışı

`gwen-cli.sh` otomatik olarak:
1. Session tipini belirler (dev/arge)
2. Doğru branch'e geçer (`feature/gwen-*` veya `feature/gwen-arge`)
3. MCP servers doğrular (`qwen mcp list`)
4. Qwen Code'u başlatır

---

## 📜 Session Kuralları

### Dev Session Kuralları

```
✅ Yapılabilir:
- Tohumlama, doğum, hayvan yönetimi geliştirme
- UI bug fix'leri (fix-ui skill)
- RPC/schema değişiklikleri
- Feature branch'lerde kod üretimi

❌ Yasak:
- Arge işleri (skill/agent/MCP geliştirme)
- .qwen/ dizininde değişiklik
- session-rules ihlali
```

### Arge Session Kuralları

```
✅ Yapılabilir:
- Qwen skills geliştirme (egesut-fullstack, fix-ui, gwen-self-improvement)
- Yeni agent/skill/MCP oluşturma
- Workflow iyileştirme
- .qwen/ dizininde değişiklik

❌ Yasak:
- ERP geliştirme (tohumlama, doğum, hayvan yönetimi)
- js/ dizininde değişiklik
- Domain koduna müdahale
```

---

## 🔄 Commit Kuralları

### Dev Session Commit
```bash
git add js/ supabase/
git commit -m "DONE: [feature/bug] — [açıklama]"
```

### Arge Session Commit
```bash
git add .qwen/
git commit -m "DONE: arge — [açıklama]"
```

**Kural:** Commit mesajı ilk satırı mutlaka `DONE:` ile başlar.

---

## 🛠️ MCP Servers

### Zorunlu MCP'ler (Her Session)

| MCP | Dosya | Sorumluluk |
|-----|-------|------------|
| `gwen-supabase` | `gwen-mcp-servers/supabase/index.js` | Database operations |
| `gwen-github` | `gwen-mcp-servers/github/index.js` | PR, issues, commits |
| `context7` | `gwen-mcp-servers/context7/index.js` | Documentation lookup |

### Doğrulama
```bash
qwen mcp list  # Her görev öncesi zorunlu
```

---

## 📚 Skills

### Mevcut Skills

| Skill | Session | Sorumluluk |
|-------|---------|------------|
| `egesut-fullstack` | dev | Tohumlama, doğum, hayvan yönetimi domain kuralları |
| `fix-ui` | dev | UI bug düzeltme — Systematic approach |
| `gwen-self-improvement` | arge | Gwen CLI, MCP, Agent, Skill geliştirme |
| `session-rules` | her ikisi | Dev/arge session kuralları, paralel subagent kuralları |

### Skill Kullanımı

**Dev Session:**
```
gwen dev task "..."
→ egesut-fullstack skill otomatik aktif
→ fix-ui skill (UI bug ise)
→ session-rules skill (her zaman)
```

**Arge Session:**
```
gwen arge task "..."
→ gwen-self-improvement skill otomatik aktif
→ session-rules skill (her zaman)
```

---

## 🎯 Paralel Subagent Kuralları

### Paralel Okuma
✅ Aynı anda birden fazla dosya okunabilir:
```
gwen-architect → .qwen/QWEN.md oku
gwen → .qwen/AGENT_HIERARCHY.md oku
```

### Paralel Yazma
⚠️ **Farklı dosyalara** paralel yazılabilir:
```
gwen-architect → .qwen/QWEN.md güncelle
gwen → .qwen/skills/session-rules/SKILL.md oluştur
```

❌ **Aynı dosyaya** paralel yazma YASAK:
```
gwen-architect → .qwen/QWEN.md düzenle
gwen → .qwen/QWEN.md düzenle  ← YASAK!
```

---

## 🚨 MCP Koruma Kuralları

### Asla Yapılma
- ❌ `qwen mcp remove <server>` çalıştırma
- ❌ `/root/.qwen/settings.json`'dan MCP silme
- ❌ MCP `env` değişkenlerini boşaltma

### Restore Prosedürü

MCP koparsa veya silinirse:

1. **Durum kontrolü:**
   ```bash
   qwen mcp list
   ```

2. **Settings.json düzelt:**
   ```json
   "mcpServers": {
     "gwen-supabase": {
       "command": "node",
       "args": ["/root/egesut-erp1/gwen-mcp-servers/supabase/index.js"],
       "cwd": "/root/egesut-erp1/gwen-mcp-servers/supabase",
       "env": {"SUPABASE_KEY": "..."},
       "trust": true
     },
     "gwen-github": {
       "command": "node",
       "args": ["/root/egesut-erp1/gwen-mcp-servers/github/index.js"],
       "cwd": "/root/egesut-erp1/gwen-mcp-servers/github",
       "env": {"GITHUB_TOKEN": "..."},
       "trust": true
     },
     "context7": {
       "command": "npx",
       "args": ["-y", "@upstash/context7-mcp@latest"],
       "env": {"CONTEXT7_API_KEY": "..."},
       "trust": true
     }
   }
   ```

3. **Doğrulama:**
   ```bash
   qwen mcp list
   ```

---

## 📋 UI Değişiklikleri Doğrulama

**Kural:** UI değişikliği yaptıktan sonra test etmeden commit YASAK.

```
1. Değişikliği uygula
2. Tarayıcıda test et (index.html aç)
3. Fonksiyonelliği doğrula
4. Console'da hata yok mu kontrol et (F12)
5. Sonra commit et
```

---

## 🔧 Shell Command Best Practices

**Kural:** Karmaşık komutları basit parçalara böl.

❌ **Yanlış:**
```bash
cat file1 file2 file3
```

✅ **Doğru:**
```bash
cat file1
cat file2
cat file3
```

---

## 📖 Referans Dosyalar

| Dosya | Açıklama |
|-------|----------|
| `.qwen/QWEN.md` | Bu dosya — workflow kuralları |
| `.qwen/AGENT_HIERARCHY.md` | Agent hiyerarşisi, sub-orchestrator kuralları |
| `.qwen/settings.json` | MCP konfigürasyonu, permissions |
| `gwen-cli.sh` | Gwen CLI arayüzü |
| `gwen-self-improvement-wrapper.sh` | Arge session wrapper |

---

## 🔒 4 DEMİR KURAL (Gwen Workflow)

### Kural 1: Task İzolasyonu
- **gwen/arge** → SADECE `.claude/tasks/arge/*` task'larını yapar
- **gwen/dev** → SADECE `.claude/tasks/dev/*` task'larını yapar
- ❌ ASLA diğer departmanın task'ına müdahale etme

### Kural 2: Otonom Workflow Zorunluluğu
Her task'ta:
1. ✅ Task dosyasını oku (`.claude/tasks/{departman}/task-*.md`)
2. ✅ Plan hazırla (en az 3 adım)
3. ✅ Adım adım uygula
4. ✅ Her adımda doğrula
5. ✅ `.claude/tasks/{departman}/task-xxx-done.md` raporu oluştur
6. ✅ Commit + Push yap
7. ✅ DONE raporu ver

### Kural 3: Context7 MCP Kullanımı
Yeni library/framework kullanmadan ÖNCE:
1. ✅ `mcp__context7__resolve-library-id` ile library ID bul
2. ✅ `mcp__context7__query-docs` ile güncel dokümantasyon al
3. ❌ ASLA eski bilgiyle kod yazma

### Kural 4: DONE Raporu Zorunluluğu
Her task bitiminde:
1. ✅ `task-xxx-done.md` dosyası oluştur
2. ✅ Yapılan değişiklikleri listele
3. ✅ Commit mesajı hazırla (format: `DONE: {departman} — {açıklama}`)
4. ✅ git add + commit + push
5. ✅ Kullanıcıya özet rapor ver

---

**Son Güncelleme:** 2026-04-02 — Task izolasyonu + blackboard sistemi (TASK-ARGE-008)
