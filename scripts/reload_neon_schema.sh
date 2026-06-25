#!/bin/bash
# Neon şema reload — LSP şema host (Docker'sız, yerel PG yok)
#
# ground_truth.sql'i Neon'a 3-geçişli yükler:
#   - Geçiş 1: roller (anon, authenticated, service_role) + ilk DDL forward-ref çözümü
#   - Geçiş 2-3: geriye kalan forward-ref'ler çözülür (function->table, view->function)
#   - Son aşama: dogum tablosunu canlı şemadan (ground_truth kanonik bozuk) CREATE et
#
# Çıktı: "33/33 tablo, 138/138 fonksiyon, 12/12 view" veya eksik raporu
#
# Kullanım:
#   .env'de NEON_LSP_URL olmalı (.env gitignore'da)
#   bash scripts/reload_neon_schema.sh

set -u
REPO="/root/egesut-erp1"
GROUND_TRUTH="$REPO/supabase/migrations/99999999999999_ground_truth.sql"
ENV_FILE="$REPO/.env"

# .env'den NEON_LSP_URL çek (commit edilmez)
if [ ! -f "$ENV_FILE" ]; then
  echo "❌ .env bulunamadı: $ENV_FILE"
  exit 1
fi
NEON_URL=$(grep -E "^NEON_LSP_URL=" "$ENV_FILE" | cut -d= -f2- | tr -d '"' | tr -d "'")
if [ -z "$NEON_URL" ]; then
  echo "❌ NEON_LSP_URL boş — .env'yi kontrol et"
  exit 1
fi

# psql kontrol
command -v psql >/dev/null || { echo "❌ psql yok — apt install postgresql-client"; exit 1; }

echo "→ Neon bağlantısı test ediliyor..."
psql "$NEON_URL" -c "SELECT version();" >/dev/null 2>&1 || { echo "❌ Neon'a bağlanılamıyor"; exit 1; }
echo "  ✓ Neon erişilebilir"

# ── Geçiş 1: Roller + ground_truth ilk yükleme ───────────────
echo "→ Geçiş 1/3: roller + ground_truth yükleme..."
psql "$NEON_URL" -v ON_ERROR_STOP=0 -q <<'SQL' 2>&1 | tail -5
DO $$ BEGIN
  CREATE ROLE anon NOLOGIN;
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE ROLE authenticated NOLOGIN;
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE ROLE service_role NOLOGIN;
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
SQL

# Geçiş 1, 2, 3: ground_truth'u 3 kez çalıştır (ileri-referans çözümü)
for pass in 1 2 3; do
  echo "→ Geçiş $pass/3: ground_truth.psql..."
  psql "$NEON_URL" -v ON_ERROR_STOP=0 -q -f "$GROUND_TRUTH" >/tmp/neon-pass-$pass.log 2>&1
done

# ── dogum tablosunu canlı şemadan CREATE (ground_truth bozuk) ─
echo "→ dogum tablosu canlı şemadan oluşturuluyor (ground_truth kanonik boş)..."
psql "$NEON_URL" -v ON_ERROR_STOP=1 -q <<'SQL' >/dev/null 2>&1
CREATE TABLE IF NOT EXISTS public.dogum (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  anne_id text,
  tarih date,
  yavru_cins text,
  yavru_kupe text,
  yavru_irk text,
  dogum_tipi text,
  dogum_kg numeric,
  baba_bilgi text,
  hekim_id text,
  created_at timestamptz DEFAULT now()
);
SQL
echo "  ✓ dogum (canlı şemadan, ground_truth drift — ayrı görev)"

# ── Sayım raporu ─────────────────────────────────────────────
echo ""
echo "═══════════════════════════════════════════════════════"
echo "Neon şema özeti:"
TABLE_COUNT=$(psql "$NEON_URL" -tA -c "SELECT count(*) FROM information_schema.tables WHERE table_schema='public' AND table_type='BASE TABLE';")
FUNC_COUNT=$(psql "$NEON_URL" -tA -c "SELECT count(*) FROM information_schema.routines WHERE routine_schema='public';")
VIEW_COUNT=$(psql "$NEON_URL" -tA -c "SELECT count(*) FROM information_schema.views WHERE table_schema='public';")
echo "  Tablolar:  $TABLE_COUNT / 33"
echo "  Fonksiyonlar: $FUNC_COUNT / 138"
echo "  View'lar:    $VIEW_COUNT / 12"
echo "═══════════════════════════════════════════════════════"

# ── Eksik objeler (varsa listele) ─────────────────────────────
echo ""
echo "Eksik tablolar (varsa):"
psql "$NEON_URL" -tA <<'SQL' | sed 's/^/  /'
SELECT table_name FROM information_schema.tables
 WHERE table_schema='public' AND table_type='BASE TABLE'
 ORDER BY table_name;
SQL

# ground_truth'ta olup Neon'da OLMAYAN tabloları bul
EXPECTED=$(grep -E "^CREATE TABLE IF NOT EXISTS public\." "$GROUND_TRUTH" | sed -E 's/.*public\.([a-z_]+).*/\1/' | sort -u)
PRESENT=$(psql "$NEON_URL" -tA -c "SELECT table_name FROM information_schema.tables WHERE table_schema='public' AND table_type='BASE TABLE';" | sort -u)
MISSING=$(comm -23 <(echo "$EXPECTED") <(echo "$PRESENT"))
if [ -n "$MISSING" ]; then
  echo "  ⚠ ground_truth'ta OLUP Neon'da OLMAYAN tablolar:"
  echo "$MISSING" | sed 's/^/    - /'
fi
