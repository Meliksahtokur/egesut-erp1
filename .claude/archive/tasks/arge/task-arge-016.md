## Resolution

Supabase MCP integration superseded by tools-bank supabase tools (tools-bank__supabase_query, tools-bank__supabase_rpc, etc.). The MCP-based supa-query approach was abandoned in favor of tools-bank's Supabase integration which provides richer functionality. This task is resolved as the underlying need is fulfilled through a different system.

**Status:** done
**resolved_date:** 2026-05-02

---

# Task-arge-016: supa-query Native Tool / Wrapper Script

**Durum:** bekliyor
**Branch:** gwen/arge
**Tarih:** 2026-04-02
**Öncelik:** yüksek

---

## Problem

Supabase CLI karmaşık: her seferinde `link`, token, `--linked` flag, yanlış subcommand.
Gwen ve Claude için tek satır SQL çalıştıracak basit bir araç gerekiyor.

---

## Seçenekler — İkisini de dene, hangisi native olarak kullanılabiliyorsa onu seç

### Seçenek A: Native Qwen Tool (Tercih Edilen)

Eğer Qwen Code custom native tool tanımlamayı destekliyorsa:

**Dosya:** `.agents/qwen/tools/supa-query.json` veya benzeri format

```json
{
  "name": "supa_query",
  "description": "EgeSüt Supabase DB'ye SQL sorgusu çalıştırır",
  "parameters": {
    "sql": "Çalıştırılacak SQL sorgusu"
  }
}
```

Qwen tool API'sini araştır — native tool mümkünse bu yolu seç.

---

### Seçenek B: Shell Script Wrapper (Fallback)

**Dosya:** `.claude/scripts/supa-query.sh`

```bash
#!/bin/bash
# EgeSüt Supabase Query Tool
# Kullanım: ./supa-query.sh "SELECT * FROM hayvanlar LIMIT 5"
# veya:     ./supa-query.sh -f query.sql

SUPABASE_ACCESS_TOKEN="sbp_235a8cfe38b40eb8c5f9bde9e31301d97cbc89c9"
PROJECT_REF="zqnexqbdfvbhlxzelzju"

# İlk kez çalıştırmada link et
if [ ! -f ~/.supabase_linked ]; then
  SUPABASE_ACCESS_TOKEN=$SUPABASE_ACCESS_TOKEN npx supabase link \
    --project-ref $PROJECT_REF 2>/dev/null
  touch ~/.supabase_linked
fi

# SQL çalıştır
if [ "$1" = "-f" ]; then
  SUPABASE_ACCESS_TOKEN=$SUPABASE_ACCESS_TOKEN npx supabase db query \
    --linked -o table < "$2"
else
  SUPABASE_ACCESS_TOKEN=$SUPABASE_ACCESS_TOKEN npx supabase db query \
    "$1" --linked -o table
fi
```

**chmod +x** ve çalışır duruma getir.

---

## Ek: Log Okuma Helper

**Dosya:** `.claude/scripts/supa-logs.sh`

Son N adet ui_log kaydını göster:

```bash
#!/bin/bash
# Kullanım: ./supa-logs.sh [limit]
LIMIT=${1:-20}
./supa-query.sh "SELECT level, source, message, created_at FROM ui_logs ORDER BY created_at DESC LIMIT $LIMIT"
```

---

## Kabul Kriterleri

- [ ] Seçenek A veya B çalışır durumda
- [ ] `./supa-query.sh "SELECT 1"` → sonuç döner
- [ ] `./supa-logs.sh` → ui_logs gösterir
- [ ] Script'ler `.gitignore`'a eklenmez (repo'da kalmalı)
- [ ] Token script içinde — `.mcp.json` gibi `.gitignore`'a eklenMEZ çünkü zaten public değil, ama dikkat et
- [ ] Push edildi, `task-arge-016-done.md` yazıldı

---

## Notlar

- Token: `sbp_235a8cfe38b40eb8c5f9bde9e31301d97cbc89c9`
- Project ref: `zqnexqbdfvbhlxzelzju`
- Native tool mümkünse shell script yazmaya gerek yok
- Output format: table (okunabilir) veya json (parse edilebilir)
