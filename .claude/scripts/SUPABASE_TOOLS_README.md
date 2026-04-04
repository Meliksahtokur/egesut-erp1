# EgeSüt Supabase Query Tools

## Kurulum

```bash
# Supabase CLI kurulu olmalı
npm install -g supabase

# Veya npx ile çalışır
npx supabase --version
```

## supa-query.sh

Basit SQL sorguları çalıştırır.

**Kullanım:**
```bash
# SQL sorgusu
./.claude/scripts/supa-query.sh "SELECT * FROM hayvanlar LIMIT 5"

# Dosyadan
./.claude/scripts/supa-query.sh -f query.sql
```

**Token Ayarı:**
Script içinde hardcoded token var. Kendi token'ınızı kullanmak için:
```bash
export SUPABASE_ACCESS_TOKEN="sbp_xxx"
export PROJECT_REF="zqnexqbdfvbhlxzelzju"
```

## supa-logs.sh

UI logs gösterir.

**Kullanım:**
```bash
# Son 20 kayıt
./.claude/scripts/supa-logs.sh

# Son 50 kayıt
./.claude/scripts/supa-logs.sh 50
```

## Alternatif: Supabase Dashboard

https://zqnexqbdfvbhlxzelzju.supabase.co

## Alternatif: MCP Supabase

Qwen Code'da:
```
mcp__supabase__execute_sql
```
