#!/bin/bash
# typescript-lsp overhead yönetim scripti
# egesut-erp1 — OpenClaude plugin LSP instance kontrolü
#
# Kullanım:
#   ./scripts/lsp-ctl.sh start             — BOŞ (plugin otomatik spawn eder, tool çağrısı tetikler)
#   ./scripts/lsp-ctl.sh stop-openclaude   — plugin instance'ını kapat (505 MB RAM serbest)
#   ./scripts/lsp-ctl.sh status            — PID + CPU/RAM durumu
#   ./scripts/lsp-ctl.sh measure           — hızlı overhead ölçümü
#   ./scripts/lsp-ctl.sh trigger           — LSP tool çağır → plugin otomatik spawn etsin
#
# Mimari notu:
#   typescript-language-server --stdio modunda çalışır (stdin/stdout pipe üzerinden
#   LSP protocol mesajlaşır). Standalone `nohup ... &` ile çalıştırılamaz — stdin
#   bağlı değilse hemen çıkar. Sadece OpenClaude plugin stdio pipe ile spawn edebilir.

set -e

LOG_DIR="/tmp/lsp-logs"
mkdir -p "$LOG_DIR"

cmd_status() {
  echo "── typescript-lsp süreçleri ──"
  PIDS=$(pgrep -f "typescript-language-server --stdio" 2>/dev/null | tr '\n' ',' | sed 's/,$//')
  if [ -n "$PIDS" ]; then
    ps -o pid,pcpu,pmem,rss,etime,comm -p "$PIDS" 2>/dev/null
  else
    echo "  (kapalı)"
  fi
  echo
  echo "── ilişkili tsserver / typingsInstaller ──"
  PIDS=$(pgrep -f "tsserver.js\|typingsInstaller.js" 2>/dev/null | tr '\n' ',' | sed 's/,$//')
  if [ -n "$PIDS" ]; then
    ps -o pid,pcpu,pmem,rss,etime,comm -p "$PIDS" 2>/dev/null
  else
    echo "  (yok)"
  fi
}

cmd_measure() {
  echo "── MEMORY ÖLÇÜMÜ ──"
  RAM_KB=$(pgrep -f "typescript-language-server --stdio|tsserver.js|typingsInstaller.js" 2>/dev/null | xargs -r ps -o rss= 2>/dev/null | awk '{s+=$1} END {print s+0}')
  CPU_PCT=$(pgrep -f "typescript-language-server --stdio|tsserver.js|typingsInstaller.js" 2>/dev/null | xargs -r ps -o pcpu= 2>/dev/null | awk '{s+=$1} END {printf "%.1f", s+0}')
  PROC_COUNT=$(pgrep -cf "typescript-language-server --stdio|tsserver.js|typingsInstaller.js" 2>/dev/null || echo 0)
  echo "  Süreç sayısı:  $PROC_COUNT"
  echo "  Toplam RAM:    $((RAM_KB/1024)) MB"
  echo "  Toplam CPU:    ${CPU_PCT}%"
  echo "  Sistem free:   $(free -m | awk '/^Mem:/ {print $7}') MB"
  echo "  Sistem used:   $(free -m | awk '/^Mem:/ {print $3}') MB"
}

cmd_stop_openclaude() {
  echo "■ OpenClaude plugin LSP instance'ı kapatılıyor..."
  pkill -f "typescript-language-server --stdio" 2>/dev/null || true
  pkill -f "tsserver.js" 2>/dev/null || true
  pkill -f "typingsInstaller.js" 2>/dev/null || true
  sleep 1
  pkill -9 -f "typescript-language-server --stdio" 2>/dev/null || true
  pkill -9 -f "tsserver.js" 2>/dev/null || true
  echo "✓ tüm lsp süreçleri öldürüldü"
}

cmd_trigger() {
  echo "▶ LSP tool çağrısı tetikleniyor (plugin otomatik spawn edecek)..."
  echo "  (Bu komut sadece bilgi amaçlı — LSP tool'u kendin çağır)"
  echo "  Örnek: openclaude'da LSP({operation: 'documentSymbol', filePath: 'js/api.js', line: 1, character: 1})"
}

case "${1:-status}" in
  start)
    echo "Bu komut boş — typescript-lsp OpenClaude plugin tarafından yönetilir."
    echo "LSP tool çağrısı (örn. documentSymbol) otomatik spawn eder."
    echo "Kapatmak için: $0 stop-openclaude"
    ;;
  stop)
    cmd_stop_openclaude
    ;;
  stop-openclaude) cmd_stop_openclaude ;;
  status)          cmd_status ;;
  measure)         cmd_measure ;;
  trigger)         cmd_trigger ;;
  *)
    echo "Kullanım: $0 {start|stop|stop-openclaude|status|measure|trigger}"
    exit 1
    ;;
esac
