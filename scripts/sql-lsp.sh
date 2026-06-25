#!/bin/bash
# SQL LSP launcher — Neon şema host için postgrestools stdio proxy
#
# .env'den NEON_LSP_URL parse eder, PGPASSWORD env'e inject eder,
# postgrestools lsp-proxy'yi başlatır (stdio). openclaude/Claude Code
# custom plugin bu script'i çağırır.
#
# Kullanım:
#   bash scripts/sql-lsp.sh start    # daemon modu (background log yazar)
#   bash scripts/sql-lsp.sh status   # process + bağlantı durumu
#   bash scripts/sql-lsp.sh stop     # daemon durdur
#   bash scripts/sql-lsp.sh env      # export edilen env'i göster (debug)

set -u
REPO="/root/egesut-erp1"
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
  URL=$(grep -E "^NEON_LSP_URL=" "$ENV_FILE" | cut -d= -f2- | tr -d '"' | tr -d "'")
  PGPASSWORD=$(python3 -c "import urllib.parse as u; p=u.urlparse('$URL'); print(p.password or '')")
  echo "PGHOST=$(python3 -c "import urllib.parse as u; p=u.urlparse('$URL'); print(p.hostname)")"
  echo "PGPORT=$(python3 -c "import urllib.parse as u; p=u.urlparse('$URL'); print(p.port or 5432)")"
  echo "PGUSER=$(python3 -c "import urllib.parse as u; p=u.urlparse('$URL'); print(p.username)")"
  echo "PGDATABASE=$(python3 -c "import urllib.parse as u; p=u.urlparse('$URL'); print(p.path.lstrip('/'))")"
  echo "PGPASSWORD=<hidden>"
  exit 0
fi

URL=$(grep -E "^NEON_LSP_URL=" "$ENV_FILE" | cut -d= -f2- | tr -d '"' | tr -d "'")
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
    if [ -f "$PID_FILE" ] && kill -0 "$(cat $PID_FILE)" 2>/dev/null; then
      echo "→ SQL LSP zaten çalışıyor (PID $(cat $PID_FILE))"
      exit 0
    fi
    # postgrestools read .env PGPASSWORD'ı zaten okuyamaz — postgrestools
    # config'deki password satırı boş, PGT_PG_PASSWORD veya PGPASSWORD env
    # üzerinden override edilir. tokio-postgres PGPASSWORD kullanır.
    # postgrestools internal logs ayrı klasöre (PGT_LOG_PATH zorunlu)
    mkdir -p /tmp/pg-logs
    export PGT_LOG_PATH=/tmp/pg-logs
    nohup postgrestools lsp-proxy --config-path="$REPO/postgres-language-server.jsonc" \
      --log-path=/tmp/pg-logs \
      > "$LOG" 2>&1 &
    echo $! > "$PID_FILE"
    sleep 1
    if kill -0 "$(cat $PID_FILE)" 2>/dev/null; then
      echo "✓ SQL LSP başlatıldı (PID $(cat $PID_FILE), log: $LOG)"
    else
      echo "❌ SQL LSP başlatılamadı — log:"
      tail -20 "$LOG"
      exit 1
    fi
    ;;
  status)
    if [ -f "$PID_FILE" ] && kill -0 "$(cat $PID_FILE)" 2>/dev/null; then
      PID=$(cat $PID_FILE)
      RSS=$(ps -o rss= -p "$PID" 2>/dev/null | tr -d ' ')
      echo "→ SQL LSP çalışıyor (PID $PID, RAM ${RSS}KB)"
      psql "$(grep -E '^NEON_LSP_URL=' $ENV_FILE | cut -d= -f2- | tr -d '"' | tr -d "'")" \
        -tA -c "SELECT 'Neon OK ('||count(*)||' public tables)' FROM information_schema.tables WHERE table_schema='public' AND table_type='BASE TABLE';" 2>&1 | sed 's/^/  /'
    else
      echo "→ SQL LSP çalışmıyor. Başlat: bash scripts/sql-lsp.sh start"
    fi
    ;;
  stop)
    if [ -f "$PID_FILE" ]; then
      PID=$(cat $PID_FILE)
      kill "$PID" 2>/dev/null && echo "✓ SQL LSP durduruldu (PID $PID)" || echo "  zaten durmuş"
      rm -f "$PID_FILE"
    else
      echo "→ PID dosyası yok — çalışmıyor"
    fi
    # postgrestools internal daemon da çalışıyor olabilir
    pkill -f "postgrestools lsp-proxy" 2>/dev/null
    ;;
  *)
    echo "Kullanım: $0 {start|status|stop|env}"
    exit 1
    ;;
esac
