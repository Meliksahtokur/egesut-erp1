#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# EgeSüt Supabase Query Tool
# Kullanım: ./supa-query.sh "SELECT * FROM hayvanlar LIMIT 5"
# veya:     ./supa-query.sh -f query.sql
# ═══════════════════════════════════════════════════════════════

SUPABASE_ACCESS_TOKEN="sbp_235a8cfe38b40eb8c5f9bde9e31301d97cbc89c9"
PROJECT_REF="zqnexqbdfvbhlxzelzju"

# Renkli output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

ok()   { echo -e "${GREEN}✓${NC} $1"; }
fail() { echo -e "${RED}✗${NC} $1"; exit 1; }
info() { echo -e "${BLUE}→${NC} $1"; }

# İlk kez çalıştırmada link et
link_supabase() {
  if [ ! -f "$HOME/.supabase_linked_$PROJECT_REF" ]; then
    info "Supabase project linkleniyor..."
    SUPABASE_ACCESS_TOKEN=$SUPABASE_ACCESS_TOKEN npx supabase link \
      --project-ref $PROJECT_REF 2>/dev/null && \
    touch "$HOME/.supabase_linked_$PROJECT_REF" && \
    ok "Supabase linklendi ($PROJECT_REF)" || \
    warn "Link atlandı — mevcut link kullanılıyor"
  fi
}

# SQL çalıştır
run_query() {
  local sql="$1"
  
  info "SQL çalıştırılıyor: $sql"
  echo ""
  
  SUPABASE_ACCESS_TOKEN=$SUPABASE_ACCESS_TOKEN npx supabase db query \
    --linked -o table \
    "$sql" 2>&1
  
  echo ""
  ok "Sorgu tamamlandı"
}

# Dosyadan SQL çalıştır
run_query_file() {
  local file="$1"
  
  if [ ! -f "$file" ]; then
    fail "Dosya bulunamadı: $file"
  fi
  
  info "Dosyadan SQL çalıştırılıyor: $file"
  echo ""
  
  SUPABASE_ACCESS_TOKEN=$SUPABASE_ACCESS_TOKEN npx supabase db query \
    --linked -o table \
    < "$file" 2>&1
  
  echo ""
  ok "Dosya sorgusu tamamlandı"
}

# Ana program
main() {
  link_supabase
  
  if [ "$1" = "-f" ]; then
    if [ -z "$2" ]; then
      fail "Kullanım: $0 -f <query.sql>"
    fi
    run_query_file "$2"
  elif [ -z "$1" ]; then
    fail "Kullanım: $0 <SQL sorgusu> veya $0 -f <dosya.sql>"
  else
    run_query "$1"
  fi
}

main "$@"
