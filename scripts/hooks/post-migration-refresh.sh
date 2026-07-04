#!/bin/bash
# PostToolUse hook — supabase_migrate ile DDL uygulandıysa Neon LSP şema aynasını
# ARKA PLANDA tazele. Böylece agentler düzenli/otomatik refresh yapmış olur (bayat ayna =
# SQL LSP yanlış-pozitifi). Sadece CREATE/ALTER/DROP içeren çağrılarda çalışır (SELECT'lerde değil).
# stdin: tool call JSON (tool_input.sql). Her zaman exit 0 — migration akışını bozma.
input=$(cat 2>/dev/null)
sql=$(printf '%s' "$input" | python3 -c "import sys,json
try: print(json.load(sys.stdin).get('tool_input',{}).get('sql',''))
except Exception: print('')" 2>/dev/null)

if printf '%s' "$sql" | grep -qiE "(create|alter|drop)[[:space:]]"; then
  REFRESH=/home/melik/egesut-erp1/scripts/refresh_lsp_schema.sh
  if [ -x "$REFRESH" ] || [ -f "$REFRESH" ]; then
    nohup bash "$REFRESH" >/tmp/lsp-autorefresh.log 2>&1 &
    echo "♻️ DDL algılandı → Neon LSP şema aynası arka planda tazeleniyor (log: /tmp/lsp-autorefresh.log)."
  fi
fi
exit 0
