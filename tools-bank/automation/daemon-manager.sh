#!/bin/bash
# Daemon manager — nohup + pidfile + crash recovery
# Usage:
#   daemon-manager.sh start   — daemon başlat
#   daemon-manager.sh stop    — daemon durdur
#   daemon-manager.sh status  — çalışıyor mu?
#   daemon-manager.sh restart — restart et
#   daemon-manager.sh check   — sadece kontrol et (cron için)

TOOLSBANK="/root/egesut-erp1/tools-bank"
WATCHER="$TOOLSBANK/automation/code_change_watcher.py"
PIDFILE="/tmp/egesut-daemon.pid"
LOG="/tmp/egesut-daemon.log"
NAME="egesut-memory-watcher"

is_running() {
    if [ -f "$PIDFILE" ]; then
        pid=$(cat "$PIDFILE")
        # Process var mı kontrol et
        if kill -0 "$pid" 2>/dev/null; then
            return 0
        else
            # Ölü pidfile, temizle
            rm -f "$PIDFILE"
        fi
    fi
    return 1
}

start() {
    if is_running; then
        pid=$(cat "$PIDFILE")
        echo "✓ $NAME zaten çalışıyor (PID: $pid)"
        return 0
    fi

    echo "▶ $NAME başlatılıyor..."
    nohup python3 "$WATCHER" --daemon >> "$LOG" 2>&1 &
    pid=$!
    echo "$pid" > "$PIDFILE"
    sleep 1

    if is_running; then
        echo "✓ $NAME başladı (PID: $pid)"
        echo "   Log: $LOG"
    else
        echo "✗ $NAME başlatılamadı"
        return 1
    fi
}

stop() {
    if ! is_running; then
        echo "✗ $NAME çalışmıyor"
        return 0
    fi

    pid=$(cat "$PIDFILE")
    echo "◼ $NAME durduruluyor (PID: $pid)..."
    kill "$pid" 2>/dev/null
    rm -f "$PIDFILE"
    echo "✓ $NAME durdu"
}

status_cmd() {
    if is_running; then
        pid=$(cat "$PIDFILE")
        echo "✓ $NAME çalışıyor (PID: $pid)"
        if [ -f "$LOG" ]; then
            echo "   Son log satırı:"
            tail -1 "$LOG" | sed 's/^/   /'
        fi
    else
        echo "✗ $NAME çalışmıyor"
    fi
}

check_and_restart() {
    # Cron'dan çağrılır — daemon ölü ise yeniden başlat
    if ! is_running; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Daemon ölü bulundu, restart ediliyor..." >> "$LOG"
        start >> "$LOG" 2>&1
    fi
}

case "${1:-}" in
    start)   start ;;
    stop)    stop ;;
    restart) stop; sleep 1; start ;;
    status)  status_cmd ;;
    check)   check_and_restart ;;
    *)       echo "Usage: $0 {start|stop|restart|status|check}" ;;
esac
