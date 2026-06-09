#!/bin/bash
# PreToolCall hook: blast radius flag kontrolü
# gitnexus_impact çalıştırılmışsa /tmp/blast-radius-done timestamp yazar.
# Bu script son 10 dakikada impact çalıştırılmamışsa Edit/Write'ı bloklar.

INPUT=$(cat)

FILE=$(echo "$INPUT" | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
    print(d.get('tool_input', {}).get('file_path', ''))
except:
    print('')
" 2>/dev/null)

# Sadece kritik JS dosyaları
if ! echo "$FILE" | grep -qE "js/(ui|api|forms|app|state)\.js$"; then
  exit 0
fi

FLAG="/tmp/blast-radius-done"
if [ -f "$FLAG" ]; then
  FLAG_TS=$(cat "$FLAG" 2>/dev/null)
  NOW=$(date +%s)
  if [ -n "$FLAG_TS" ] && [ $(( NOW - FLAG_TS )) -lt 600 ]; then
    exit 0  # Son 10 dakikada impact çalıştırıldı — geç
  fi
fi

echo "🎯 BLAST RADIUS ANALİZİ GEREKLİ"
echo ""
echo "  Dosya: $FILE"
echo ""
echo "  Editlemeden önce çalıştır:"
echo "    gitnexus_impact({target: \"FONKSIYON_ADI\", direction: \"upstream\"})"
echo ""
echo "  Impact tamamlanınca otomatik geçeceksin (10 dk geçerli)."
exit 2
