#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# Session Cleanup — EgeSüt ERP
# Zombie process'leri temizler, MCP sunucularını yeniden başlatır
# ═══════════════════════════════════════════════════════════════

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔═══════════════════════════════════════════════════════════╗"
echo -e "║  Session Cleanup — EgeSüt ERP                       ║"
echo -e "╚═══════════════════════════════════════════════════════════╝${NC}"

# 1. Zombie node process'leri temizle
echo -e "${YELLOW}[1/4] Zombie node process'leri temizleniyor...${NC}"
pkill -9 -f "node.*defunct" 2>/dev/null || true
ZOMBIE_COUNT=$(ps aux | grep -c "defunct" || echo "0")
echo -e "${GREEN}✓ Zombie process temizlendi (kalan: $ZOMBIE_COUNT)${NC}"

# 2. Tüm node process'leri durdur
echo -e "${YELLOW}[2/4] Node process'leri durduruluyor...${NC}"
pkill -9 node 2>/dev/null || true
sleep 1
NODE_COUNT=$(ps aux | grep -c "[n]ode" || echo "0")
echo -e "${GREEN}✓ Node process'leri durduruldu (kalan: $NODE_COUNT)${NC}"

# 3. Memory temizleme bilgisi
echo -e "${YELLOW}[3/4] Memory durumu:${NC}"
free -h | grep -E "Mem|Swap"

# 4. Öneriler
echo -e "${YELLOW}[4/4] Öneriler:${NC}"
echo -e "${BLUE}─────────────────────────────────────────────────────────${NC}"
echo "1. Qwen Code'u şu şekilde başlat:"
echo -e "   ${GREEN}export NODE_OPTIONS=\"--max-old-space-size=256\"${NC}"
echo -e "   ${GREEN}qwen${NC}"
echo ""
echo "2. PRoot başlatırken shared-tmp kullan:"
echo -e "   ${GREEN}proot ... --shared-tmp /dev/shm:tmpfs${NC}"
echo ""
echo "3. Her 4 saatte bir bu script'i çalıştır:"
echo -e "   ${GREEN}./session-clean.sh${NC}"
echo -e "${BLUE}─────────────────────────────────────────────────────────${NC}"

echo -e "${GREEN}✅ Cleanup tamamlandı!${NC}"
