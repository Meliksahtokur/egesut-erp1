#!/bin/bash

# Renkler
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

SCRIPT_DIR="/root/egesut-erp1"
GWEN_MCP_SERVER="$SCRIPT_DIR/gwen-mcp-server.js"

# PID ve Log Dosyaları
PID_FILE="/tmp/gwen-mcp.pid"
WATCHDOG_PID_FILE="/tmp/gwen-watchdog.pid"
LOG_FILE="/var/log/gwen-mcp.log"

# ============================================================================
# LOG FONKSİYONU
# ============================================================================
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

# ============================================================================
# HEALTH CHECK FONKSİYONU
# ============================================================================
health_check() {
    local pid=$(cat "$PID_FILE" 2>/dev/null)
    
    # 1. PID kontrolü
    if [ -z "$pid" ] || ! kill -0 "$pid" 2>/dev/null; then
        return 1
    fi
    
    # 2. JSON-RPC ping (stdio)
    local response=$(echo '{"jsonrpc":"2.0","method":"ping","id":1}' | timeout 5 node "$GWEN_MCP_SERVER" 2>/dev/null)
    if echo "$response" | grep -q '"result"\|"id":1'; then
        return 0
    fi
    
    return 1
}

# ============================================================================
# WATCHDOG FONKSİYONU (INTERNAL - daemon olarak çalışır)
# ============================================================================
start_watchdog() {
    log "Watchdog başlatılıyor..."
    
    # Watchdog'u arka planda daemon olarak başlat
    nohup bash -c '
        while true; do
            PID_FILE="/tmp/gwen-mcp.pid"
            GWEN_MCP_SERVER="/root/egesut-erp1/gwen-mcp-server.js"
            LOG_FILE="/var/log/gwen-mcp.log"
            
            # Health check yap
            pid=$(cat "$PID_FILE" 2>/dev/null)
            healthy=false
            
            if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
                response=$(echo "{\"jsonrpc\":\"2.0\",\"method\":\"ping\",\"id\":1}" | timeout 5 node "$GWEN_MCP_SERVER" 2>/dev/null)
                if echo "$response" | grep -q "\"result\"\|\"id\":1"; then
                    healthy=true
                fi
            fi
            
            if [ "$healthy" = false ]; then
                echo "[$(date "+%Y-%m-%d %H:%M:%S")] ⚠️  MCP server down, restart ediliyor..." >> "$LOG_FILE"
                
                # MCPyi kill et
                if [ -n "$pid" ]; then
                    kill "$pid" 2>/dev/null
                fi
                
                # Yeniden başlat
                rm -f "$PID_FILE"
                nohup node "$GWEN_MCP_SERVER" >> "$LOG_FILE" 2>&1 &
                echo $! > "$PID_FILE"
                
                echo "[$(date "+%Y-%m-%d %H:%M:%S")] MCP server restart edildi (PID: $!)" >> "$LOG_FILE"
            fi
            
            sleep 30
        done
    ' > /dev/null 2>&1 &
    
    echo $! > "$WATCHDOG_PID_FILE"
    log "Watchdog başlatıldı (PID: $(cat "$WATCHDOG_PID_FILE"))"
}

stop_watchdog() {
    if [ -f "$WATCHDOG_PID_FILE" ] && kill -0 "$(cat "$WATCHDOG_PID_FILE")" 2>/dev/null; then
        kill "$(cat "$WATCHDOG_PID_FILE")"
        rm -f "$WATCHDOG_PID_FILE"
        log "Watchdog durduruldu"
    fi
}

# ============================================================================
# PROOT CLEANUP FONKSİYONU
# ============================================================================
cleanup_proot() {
    log "Eski proot prosesleri temizleniyor..."
    
    # 1 saatten eski proot proseslerini bul
    local old_proots=$(ps aux | grep "proot.*fedora" | grep -v grep | awk '$9 ~ /[0-9]+:[0-9]+/ && $9 > "01:00" {print $2}')
    
    if [ -z "$old_proots" ]; then
        log "Temizlenecek eski proot process bulunamadı"
        echo -e "${GREEN}✓ Temizlenecek eski proot process yok${NC}"
        return 0
    fi
    
    echo -e "${YELLOW}Bulunan eski proot prosesleri:${NC}"
    for pid in $old_proots; do
        echo "  PID: $pid"
        kill -9 "$pid" 2>/dev/null
        log "Eski proot process temizlendi (PID: $pid)"
    done
    
    echo -e "${GREEN}✓ Eski proot prosesleri temizlendi${NC}"
}

# ============================================================================
# START SERVER
# ============================================================================
start_server() {
    log "MCP server başlatılıyor..."
    
    echo -e "${BLUE}Gwen MCP sunucusu başlatılıyor...${NC}"
    if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
        echo -e "${YELLOW}⚠️  Gwen MCP zaten çalışıyor (PID: $(cat "$PID_FILE"))${NC}"
        log "MCP server zaten çalışıyor (PID: $(cat "$PID_FILE"))"
        return 0
    fi
    if [ ! -f "$GWEN_MCP_SERVER" ]; then
        echo -e "${RED}❌ gwen-mcp-server.js bulunamadı!${NC}"
        log "HATA: gwen-mcp-server.js bulunamadı"
        return 1
    fi
    rm -f "$PID_FILE"
    nohup node "$GWEN_MCP_SERVER" > "$SCRIPT_DIR/gwen-mcp.log" 2>&1 &
    echo $! > "$PID_FILE"
    sleep 1
    if kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
        echo -e "${GREEN}✅ Gwen MCP sunucusu başlatıldı (PID: $(cat "$PID_FILE"))${NC}"
        log "MCP server başlatıldı (PID: $(cat "$PID_FILE"))"
        
        # Watchdog'u başlat
        start_watchdog
    else
        echo -e "${RED}❌ Sunucu başlatılamadı!${NC}"
        log "HATA: MCP server başlatılamadı"
        rm -f "$PID_FILE"
        return 1
    fi
}

# ============================================================================
# STOP SERVER
# ============================================================================
stop_server() {
    log "MCP server durduruluyor..."
    
    echo -e "${BLUE}Gwen MCP sunucusu durduruluyor...${NC}"
    
    # Önce watchdog'u durdur
    stop_watchdog
    
    # Sonra MCP server'ı durdur
    if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
        kill "$(cat "$PID_FILE")"
        rm -f "$PID_FILE"
        echo -e "${GREEN}✅ Sunucu durduruldu${NC}"
        log "MCP server durduruldu"
    else
        echo -e "${YELLOW}○ Sunucu zaten duruyor${NC}"
        rm -f "$PID_FILE"
        log "MCP server zaten duruyordu"
    fi
}

# ============================================================================
# CHECK STATUS (Geliştirilmiş)
# ============================================================================
check_status() {
    echo -e "${CYAN}🔹 Gwen MCP Server Durumu${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━"
    
    local mcp_pid=$(cat "$PID_FILE" 2>/dev/null)
    local watchdog_pid=$(cat "$WATCHDOG_PID_FILE" 2>/dev/null)
    
    # MCP Server durumu
    if [ -n "$mcp_pid" ] && kill -0 "$mcp_pid" 2>/dev/null; then
        echo -e "Server:  ${GREEN}🟢 Çalışıyor${NC} (PID: $mcp_pid)"
    else
        echo -e "Server:  ${RED}🔴 Çalışmıyor${NC}"
        rm -f "$PID_FILE"
    fi
    
    # Watchdog durumu
    if [ -n "$watchdog_pid" ] && kill -0 "$watchdog_pid" 2>/dev/null; then
        echo -e "Watchdog: ${GREEN}🟢 Çalışıyor${NC} (PID: $watchdog_pid)"
    else
        echo -e "Watchdog: ${RED}🔴 Çalışmıyor${NC}"
        rm -f "$WATCHDOG_PID_FILE"
    fi
    
    # Health check (eğer MCP çalışıyorsa)
    if [ -n "$mcp_pid" ] && kill -0 "$mcp_pid" 2>/dev/null; then
        if health_check; then
            echo -e "Health:  ${GREEN}✅ Sağlıklı${NC} (son kontrol: şimdi)"
        else
            echo -e "Health:  ${RED}❌ Down${NC}"
        fi
    fi
    
    echo ""
    echo -e "${CYAN}🔹 Aktif PRoot Session'ları${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${BLUE}PID     Başlangıç   Komut${NC}"
    
    local proot_procs=$(ps aux | grep "proot" | grep -v grep)
    if [ -n "$proot_procs" ]; then
        echo "$proot_procs" | awk '{printf "%-8s %-12s %s\n", $2, $9, $11}'
    else
        echo "Aktif proot session yok"
    fi
}

# ============================================================================
# HEALTH KOMUTU
# ============================================================================
do_health() {
    echo -e "${BLUE}Health check yapılıyor...${NC}"
    
    local pid=$(cat "$PID_FILE" 2>/dev/null)
    
    # PID kontrolü
    if [ -z "$pid" ]; then
        echo -e "${RED}🔴 Down${NC} (PID dosyası yok)"
        log "Health check: Down (PID dosyası yok)"
        return 1
    fi
    
    if ! kill -0 "$pid" 2>/dev/null; then
        echo -e "${RED}🔴 Down${NC} (Process çalışmıyor)"
        log "Health check: Down (Process çalışmıyor - PID: $pid)"
        rm -f "$PID_FILE"
        return 1
    fi
    
    # JSON-RPC ping
    echo "  → JSON-RPC ping gönderiliyor..."
    local response=$(echo '{"jsonrpc":"2.0","method":"ping","id":1}' | timeout 5 node "$GWEN_MCP_SERVER" 2>/dev/null)
    
    if echo "$response" | grep -q '"result"\|"id":1'; then
        echo -e "${GREEN}✅ Sağlıklı${NC}"
        log "Health check: Sağlıklı (PID: $pid)"
        return 0
    else
        echo -e "${RED}🔴 Down${NC} (Ping yanıt alınamadı)"
        log "Health check: Down (Ping yanıt alınamadı - PID: $pid)"
        return 1
    fi
}

# ============================================================================
# LOGS KOMUTU
# ============================================================================
show_logs() {
    if [ -f "$LOG_FILE" ]; then
        echo -e "${BLUE}Son 50 satır:$NC"
        tail -50 "$LOG_FILE"
    elif [ -f "$SCRIPT_DIR/gwen-mcp.log" ]; then
        echo -e "${YELLOW}Eski log dosyası bulundu:$NC"
        tail -50 "$SCRIPT_DIR/gwen-mcp.log"
    else
        echo "Log dosyası yok"
    fi
}

show_logs_follow() {
    if [ -f "$LOG_FILE" ]; then
        tail -f "$LOG_FILE"
    elif [ -f "$SCRIPT_DIR/gwen-mcp.log" ]; then
        tail -f "$SCRIPT_DIR/gwen-mcp.log"
    else
        echo "Log dosyası yok"
    fi
}

# ============================================================================
# TEST CONNECTION
# ============================================================================
test_connection() {
    echo -e "${BLUE}Bağlantı test ediliyor...${NC}"
    command -v node >/dev/null && echo -e "${GREEN}✓ Node.js çalışıyor${NC}" || echo -e "${RED}✗ Node.js yok${NC}"
    [ -f "$GWEN_MCP_SERVER" ] && echo -e "${GREEN}✓ gwen-mcp-server.js mevcut${NC}" || echo -e "${RED}✗ gwen-mcp-server.js kayıp${NC}"
    echo -e "${GREEN}✅ Test tamamlandı${NC}"
}

# ============================================================================
# HELP
# ============================================================================
show_help() {
    echo -e "${BLUE}Gwen CLI — EgeSüt ERP Agent Arayüzü${NC}"
    echo ""
    echo -e "${GREEN}KULLANIM:${NC}"
    echo "  gwen <komut>"
    echo ""
    echo -e "${GREEN}KOMUTLAR:${NC}"
    echo "  start      - MCP sunucuyu başlat (watchdog ile)"
    echo "  stop       - MCP sunucuyu durdur (watchdog ile)"
    echo "  restart    - Yeniden başlat"
    echo "  status     - Detaylı durum bilgisi"
    echo "  health     - Health check yap"
    echo "  cleanup    - Eski proot proseslerini temizle"
    echo "  logs       - Son 50 satır log göster"
    echo "  logs -f    - Logları canlı izle"
    echo "  test       - Bağlantıyı test et"
    echo "  help       - Bu mesaj"
}

# ============================================================================
# MAIN
# ============================================================================
case "${1:-help}" in
    status) check_status ;;
    start) start_server ;;
    stop) stop_server ;;
    restart) stop_server; sleep 1; start_server ;;
    health) do_health ;;
    cleanup) cleanup_proot ;;
    logs)
        if [ "$2" = "-f" ]; then
            show_logs_follow
        else
            show_logs
        fi
        ;;
    test) test_connection ;;
    help) show_help ;;
    *) echo "Bilinmeyen komut: $1"; show_help ;;
esac
