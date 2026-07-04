#!/bin/bash
# SQL LSP launcher — yerel Postgres (bu makine) şema host için postgrestools stdio proxy
#
# .env'den LOCAL_LSP_URL parse eder, PGPASSWORD env'e inject eder,
# postgrestools lsp-proxy'yi başlatır (stdio). openclaude/Claude Code
# custom plugin bu script'i çağırır.
#
# Kullanım:
#   bash scripts/sql-lsp.sh start    # daemon modu (background log yazar)
#   bash scripts/sql-lsp.sh status   # process + bağlantı durumu
#   bash scripts/sql-lsp.sh stop     # daemon durdur
#   bash scripts/sql-lsp.sh env      # export edilen env'i göster (debug)

set -u
REPO="/home/melik/egesut-erp1"
ENV_FILE="$REPO/.env"
LOG="/tmp/sql-lsp.log"
PID_FILE="/tmp/sql-lsp.pid"
ACTION="${1:-status}"

if [ ! -f "$ENV_FILE" ]; then
  echo "❌ .env bulunamadı: $ENV_FILE"
  exit 1
fi
command -v postgrestools >/dev/null || { echo "❌ postgrestools yok — npm i -g @postgres-language-server/cli"; exit 1; }

# .env → PGPASSWORD
if [ "$ACTION" = "env" ]; then
  URL=$(grep -E "^LOCAL_LSP_URL=" "$ENV_FILE" | cut -d= -f2- | tr -d '"' | tr -d "'")
  PGPASSWORD=$(python3 -c "import urllib.parse as u; p=u.urlparse('$URL'); print(p.password or '')")
  echo "PGHOST=$(python3 -c "import urllib.parse as u; p=u.urlparse('$URL'); print(p.hostname)")"
  echo "PGPORT=$(python3 -c "import urllib.parse as u; p=u.urlparse('$URL'); print(p.port or 5432)")"
  echo "PGUSER=$(python3 -c "import urllib.parse as u; p=u.urlparse('$URL'); print(p.username)")"
  echo "PGDATABASE=$(python3 -c "import urllib.parse as u; p=u.urlparse('$URL'); print(p.path.lstrip('/'))")"
  echo "PGPASSWORD=<hidden>"
  exit 0
fi

URL=$(grep -E "^LOCAL_LSP_URL=" "$ENV_FILE" | cut -d= -f2- | tr -d '"' | tr -d "'")
PGHOST=$(python3 -c "import urllib.parse as u; p=u.urlparse('$URL'); print(p.hostname)")
PGPORT=$(python3 -c "import urllib.parse as u; p=u.urlparse('$URL'); print(p.port or 5432)")
PGUSER=$(python3 -c "import urllib.parse as u; p=u.urlparse('$URL'); print(p.username)")
PGDATABASE=$(python3 -c "import urllib.parse as u; p=u.urlparse('$URL'); print(p.path.lstrip('/'))")
PGPASSWORD=$(python3 -c "import urllib.parse as u; p=u.urlparse('$URL'); print(p.password or '')")

export PGHOST PGPORT PGUSER PGDATABASE PGPASSWORD

case "$ACTION" in
  stdio)
    # Plugin çağrısı: foreground stdio proxy (lspServers entry buraya yönlendirir)
    mkdir -p /tmp/pg-logs
    export PGT_LOG_PATH=/tmp/pg-logs
    exec postgrestools lsp-proxy \
      --config-path="$REPO/postgres-language-server.jsonc" \
      --log-path=/tmp/pg-logs
    ;;
  start)
    # NOT (2026-07-04, doğrulandı): `postgrestools lsp-proxy` internal olarak
    # --stop-on-disconnect ile bir daemon spawn eder — proxy client kopunca
    # daemon da kendini kapatır, bu yüzden asla kalıcı olamıyordu. Gerçek
    # kalıcı daemon komutu `postgrestools start`dır; `lsp-proxy` (stdio
    # action) zaten çalışan bu daemon'a bağlanır, kopsa da daemon ayakta kalır.
    if pgrep -f "postgrestools __run_server" >/dev/null 2>&1; then
      echo "→ SQL LSP daemon zaten çalışıyor (PID $(pgrep -f 'postgrestools __run_server' | paste -sd, -))"
      exit 0
    fi
    mkdir -p /tmp/pg-logs
    export PGT_LOG_PATH=/tmp/pg-logs
    nohup postgrestools start --config-path="$REPO/postgres-language-server.jsonc" \
      --log-path=/tmp/pg-logs \
      > "$LOG" 2>&1 &
    disown
    sleep 1
    if pgrep -f "postgrestools __run_server" >/dev/null 2>&1; then
      echo "✓ SQL LSP daemon başlatıldı (PID $(pgrep -f 'postgrestools __run_server' | paste -sd, -), log: $LOG)"
    else
      echo "❌ SQL LSP daemon başlatılamadı — log:"
      tail -20 "$LOG"
      exit 1
    fi
    ;;
  status)
    if pgrep -f "postgrestools __run_server" >/dev/null 2>&1; then
      PID=$(pgrep -f "postgrestools __run_server" | head -1)
      RSS=$(ps -o rss= -p "$PID" 2>/dev/null | tr -d ' ')
      echo "→ SQL LSP daemon çalışıyor (PID $PID, RAM ${RSS}KB)"
      psql "$(grep -E '^LOCAL_LSP_URL=' $ENV_FILE | cut -d= -f2- | tr -d '"' | tr -d "'")" \
        -tA -c "SELECT 'Yerel Postgres OK ('||count(*)||' public tables)' FROM information_schema.tables WHERE table_schema='public' AND table_type='BASE TABLE';" 2>&1 | sed 's/^/  /'
    else
      echo "→ SQL LSP daemon çalışmıyor. Başlat: bash scripts/sql-lsp.sh start"
    fi
    ;;
  stop)
    postgrestools stop 2>/dev/null && echo "✓ SQL LSP daemon durduruldu" || echo "  zaten durmuş"
    rm -f "$PID_FILE"
    ;;
  *)
    echo "Kullanım: $0 {start|status|stop|env}"
    exit 1
    ;;
esac
