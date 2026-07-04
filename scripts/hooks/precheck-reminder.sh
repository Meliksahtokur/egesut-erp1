#!/bin/bash
# PreToolUse hook — js/ veya supabase/migrations/ dosyası düzenlenmeden ÖNCE
# code-change-precheck hatırlatması (blast radius + LSP). Bloklamaz, sadece hatırlatır.
# stdin: tool call JSON (tool_input.file_path).
input=$(cat 2>/dev/null)
fp=$(printf '%s' "$input" | python3 -c "import sys,json
try: print(json.load(sys.stdin).get('tool_input',{}).get('file_path',''))
except Exception: print('')" 2>/dev/null)

case "$fp" in
  *js/*.js)
    echo "🔍 code-change-precheck (JS): değiştirmeden önce blast radius'a bak — gitnexus_impact({target,direction:'upstream'}) + LSP findReferences. HIGH/CRITICAL ise kullanıcıya bildir."
    ;;
  *supabase/migrations/*)
    echo "🔍 code-change-precheck (SQL): migration yazmadan önce → scripts/refresh_lsp_schema.sh (ayna taze mi) + postgrestools check / .sql LSP ile kolon-tablo doğrula. Referans canlı şema, ground_truth DEĞİL."
    ;;
esac
exit 0
