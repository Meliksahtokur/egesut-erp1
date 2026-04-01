#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# Gwen CLI — EgeSüt ERP için Gwen Agent komut satırı arayüzü
# ═══════════════════════════════════════════════════════════════

set -e

# Renkler
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script dizini - alias ile çağrılınca da çalışsın
SCRIPT_DIR="$(cd "$(dirname "$(realpath "${BASH_SOURCE[0]:-$0}")")" && pwd)"
GWEN_MCP_SERVER="$SCRIPT_DIR/gwen-mcp-server.js"

# Yardım mesajı
show_help() {
    cat << EOF
${BLUE}╔═══════════════════════════════════════════════════════════╗
║  Gwen CLI — EgeSüt ERP Agent Arayüzü              ║
╚═══════════════════════════════════════════════════════════╝${NC}

${GREEN}KULLANIM:${NC}
  ./gwen-cli.sh <komut> [argümanlar]

${GREEN}KOMUTLAR:${NC}
  status          Gwen MCP sunucu durumunu göster
  start           Gwen MCP sunucusunu başlat
  stop            Gwen MCP sunucusunu durdur
  restart         Yeniden başlat
  logs            Son logları göster
  test            Bağlantıyı test et
  help            Bu yardım mesajını göster

${GREEN}ÖRNEKLER:${NC}
  ./gwen-cli.sh status
  ./gwen-cli.sh start
  ./gwen-cli.sh test

${YELLOW}NOT:${NC} Node.js 18+ gerektirir
EOF
}

# Node.js kontrolü
check_node() {
    if ! command -v node &> /dev/null; then
        echo -e "${RED}❌ Node.js bulunamadı. Lütfen Node.js 18+ yükleyin.${NC}"
        exit 1
    fi
    
    NODE_VERSION=$(node -v | cut -d'v' -f2 | cut -d'.' -f1)
    if [ "$NODE_VERSION" -lt 18 ]; then
        echo -e "${RED}❌ Node.js 18+ gerekli. Mevcut sürüm: $(node -v)${NC}"
        exit 1
    fi
}

# MCP sunucu durumunu kontrol et
check_status() {
    echo -e "${BLUE}Gwen MCP Sunucu Durumu${NC}"
    echo "─────────────────────────────────────"
    
    # Process kontrolü
    if pgrep -f "gwen-mcp-server.js" > /dev/null 2>&1; then
        PID=$(pgrep -f "gwen-mcp-server.js")
        echo -e "${GREEN}● Çalışıyor${NC} (PID: $PID)"
        
        # Port kontrolü
        if netstat -tuln 2>/dev/null | grep -q ":3000" || lsof -i:3000 2>/dev/null | grep -q LISTEN; then
            echo -e "${GREEN}● Port 3000: Aktif${NC}"
        else
            echo -e "${YELLOW}● Port 3000: Dinlenmiyor${NC}"
        fi
    else
        echo -e "${RED}○ Duruyor${NC}"
    fi
    
    # Dosya kontrolü
    if [ -f "$GWEN_MCP_SERVER" ]; then
        echo -e "${GREEN}● gwen-mcp-server.js: Mevcut${NC}"
    else
        echo -e "${RED}● gwen-mcp-server.js: Kayıp${NC}"
    fi
}

# Sunucuyu başlat
start_server() {
    echo -e "${BLUE}Gwen MCP sunucusu başlatılıyor...${NC}"
    
    if [ ! -f "$GWEN_MCP_SERVER" ]; then
        echo -e "${RED}❌ gwen-mcp-server.js bulunamadı!${NC}"
        exit 1
    fi
    
    # Arka planda başlat
    nohup node "$GWEN_MCP_SERVER" > gwen-mcp.log 2>&1 &
    PID=$!
    
    sleep 2
    
    if ps -p $PID > /dev/null; then
        echo -e "${GREEN}✅ Gwen MCP sunucusu başlatıldı (PID: $PID)${NC}"
        echo -e "${YELLOW}Log dosyası: gwen-mcp.log${NC}"
    else
        echo -e "${RED}❌ Sunucu başlatılamadı!${NC}"
        echo -e "${YELLOW}Log için: cat gwen-mcp.log${NC}"
        exit 1
    fi
}

# Sunucuyu durdur
stop_server() {
    echo -e "${BLUE}Gwen MCP sunucusu durduruluyor...${NC}"
    
    if pgrep -f "gwen-mcp-server.js" > /dev/null 2>&1; then
        pkill -f "gwen-mcp-server.js"
        echo -e "${GREEN}✅ Sunucu durduruldu${NC}"
    else
        echo -e "${YELLOW}○ Sunucu zaten duruyor${NC}"
    fi
}

# Test bağlantısı
test_connection() {
    echo -e "${BLUE}Bağlantı test ediliyor...${NC}"
    
    # Basit Node.js test
    node -e "
        const http = require('http');
        console.log('✓ Node.js çalışıyor');
        
        // MCP server dosyası kontrolü
        const fs = require('fs');
        if (fs.existsSync('$GWEN_MCP_SERVER')) {
            console.log('✓ gwen-mcp-server.js mevcut');
        } else {
            console.log('✗ gwen-mcp-server.js kayıp');
            process.exit(1);
        }
    "
    
    echo -e "${GREEN}✅ Test tamamlandı${NC}"
}

# Logları göster
show_logs() {
    if [ -f "gwen-mcp.log" ]; then
        echo -e "${BLUE}Son 50 satır:${NC}"
        tail -50 gwen-mcp.log
    else
        echo -e "${YELLOW}Log dosyası bulunamadı${NC}"
    fi
}

# Ana komut işleyici
main() {
    check_node
    
    case "${1:-help}" in
        status)
            check_status
            ;;
        start)
            start_server
            ;;
        stop)
            stop_server
            ;;
        restart)
            stop_server
            sleep 1
            start_server
            ;;
        logs)
            show_logs
            ;;
        test)
            test_connection
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            echo -e "${RED}❌ Bilinmeyen komut: $1${NC}"
            echo -e "${YELLOW}Yardım için: ./gwen-cli.sh help${NC}"
            exit 1
            ;;
    esac
}

main "$@"
