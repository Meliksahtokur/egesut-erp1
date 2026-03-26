#!/bin/bash
# ArGe Dirty Flag — git commit/push sonrası tetiklenir
# Eğer commit yapıldıysa flag dosyası oluşturur

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_input',{}).get('command',''))" 2>/dev/null)

# Sadece git commit veya push komutlarında tetikle
if echo "$COMMAND" | grep -qE "^git (commit|push)"; then
  CURRENT_HASH=$(git -C /root/egesut-erp1 rev-parse HEAD 2>/dev/null)
  echo "$CURRENT_HASH" > /root/egesut-erp1/.claude/arge-pending.flag
fi

exit 0
