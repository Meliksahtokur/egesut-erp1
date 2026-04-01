# Altyapı ve Geliştirme Süreci Planı

**Tarih:** 2026-04-01
**Durum:** Faz 1 devam ediyor — 1a tamamlandı, 1b bekliyor

---

## Crash Recovery (Claude veya CLI çöktüğünde)

```bash
# 1. Claude'u başlat
claude

# 2. İlk mesaj:
.claude/knowledge/infrastructure-plan.md oku. Gwen session durumuna bak (gwen status), kaldığın yerden devam et.
```

**Gwen session kurtarma:**
```bash
source ~/.bashrc
gwen status          # hangi session vardı
gwen-recover         # dev + arge yeniden başlat
gwen-attach-arge     # ekrana bağlan, ne yaptığına bak
```

---

## Mimari Karar (2026-04-01)

**MCP sadece Context7** — Supabase ve GitHub MCP kapalı.
- Supabase işlemleri → `supabase` CLI veya direkt SQL (Bash)
- GitHub işlemleri → `gh` CLI (Bash)
- Context7 → tüm agentlar paylaşımlı

---

## Faz 1: Shared Infrastructure

### 1a. MCP temizliği — ✅ TAMAMLANDI
- GitHub + Supabase MCP devre dışı (`settings.json`)
- `defaultMode: bypassPermissions` → `acceptEdits` (root kısıtı aşıldı)
- Tüm tool'lar allow listesinde, Claude sormadan çalışıyor

### 1b. 2 Gwen session desteği — ⏳ BEKLIYOR
Script: `/root/egesut-erp1-main/.claude/gwen` → `/usr/local/bin/gwen` symlink'i

Yapılacak:
- `gwen` script'ini `basename $0` ile session adını otomatik alsın
- `gwen` → SESSION="gwen", WORKDIR="/root/egesut-erp1"
- `gwen-arge` → SESSION="gwen-arge", WORKDIR="/root/egesut-erp1"
- `/usr/local/bin/gwen-arge` → `/root/egesut-erp1-main/.claude/gwen` symlink oluştur

### 1c. Session crash recovery — ⏳ BEKLIYOR
- tmux zaten persist ediyor, yeterli
- task başında `git stash` checkpoint eklenecek (gwen script içine)

---

## Faz 1 Sonrası Test Listesi

### Supabase CLI testi — ✅ TAMAMLANDI
- `supabase --version` → 2.76.16
- `supabase projects list` → proje linked ✅
- Symlink: `/usr/local/bin/supabase` → `/root/egesut-erp1/node_modules/supabase/bin/supabase`
- NOT: Docker yok → local komutlar çalışmıyor, sadece `--linked` çalışıyor

### Realtime aktif — ✅ TAMAMLANDI (commit e3ba2c9)
- 7 tablo `supabase_realtime` publication'da
- `initRealtime()` WebSocket subscription api.js'de
- Bağlantı kurulunca 30sn polling duruyor, hata olursa fallback devreye giriyor

---

## Faz 2: Gwen Agent Setup

**Hedef:** Gwen'in kendi agent sistemini düzelt.
- gwen-arge session → Gwen self-improvement / R&D
- Sonuç: Gwen bağımsız çalışabilir, stuck olmaz

---

## Faz 3: UI + Backend Logging

- `islem_log` tablosu var → telemetry view ekle
- Supabase Realtime subscription → ekstra server YOK

---

## Faz 4: Bug Fixler (Gwen ERP session)

Sıralı:
- BUG-004: REST bypass (forms.js:765)
- BUG-005: REST bypass (forms.js:775)
- BUG-007: offline kuyruk bypass (ui.js:2745)
- BUG-008: UI refresh garantisiz
- BUG-009: tohSonuc REST PATCH (forms.js:640)

---

## Araç Kuralı

```
Context7 MCP  → doküman/API referansı
supabase CLI  → migration, DB yönetimi
gh CLI        → PR, issue
git           → versiyon kontrolü
```

---

## Önemli Notlar

- Qwen-içinde-Qwen YASAK — sistem çöker
- Her Gwen task'ı `DONE:` commit ile biter
- Gwen direkt `write()` kullanamaz — sadece RPC
