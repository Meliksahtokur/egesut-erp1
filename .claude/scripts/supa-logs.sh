#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# EgeSüt Supabase UI Logs Viewer
# Kullanım: ./supa-logs.sh [limit]
# Varsayılan: Son 20 ui_log kaydı
# ═══════════════════════════════════════════════════════════════

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIMIT=${1:-20}

# Renkli header
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo ""
echo -e "${BLUE}╔══════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║${NC}  EgeSüt UI Logs — Son $LIMIT kayıt"
echo -e "${BLUE}╚══════════════════════════════════════════════╝${NC}"
echo ""

# SQL sorgusu
SQL="SELECT level, source, message, created_at FROM ui_logs ORDER BY created_at DESC LIMIT $LIMIT"

# supa-query.sh çalıştır
"$SCRIPT_DIR/supa-query.sh" "$SQL"
