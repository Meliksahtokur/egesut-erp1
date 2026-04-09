#!/bin/bash
# Real-time file watcher — inotifywait tabanlı
# Her kod dosyası değiştiğinde otomatik memory update
# NOT: Bu sadece diskte değişiklik olanları yakalar, git commit ZORUNLU

TOOLSBANK="/root/egesut-erp1/tools-bank"
REPO="/root/egesut-erp1"
LOG="/tmp/egesut-file-watcher.log"
WATCH_DIRS="js supabase migrations"

# Debounce: aynı dosya için 5 saniye bekle
DEBOUNCE=5

echo "👁  File watcher started — watching: $WATCH_DIRS" >> "$LOG"
echo "   $(date)" >> "$LOG"

# inotifywait - dosya değişikliğini bekle
exec inotifywait -m -r \
  --exclude '(\.git|node_modules|\.temp|workflows|examples|docs|skills|agents|mcps)' \
  -e modify,create,move \
  $REPO/$WATCH_DIRS \
  2>/dev/null | while read dir action file; do
  # Sadece önemli extensions
  ext="${file##*.}"
  case "$ext" in
    js|py|sql|ts|html|css|json|md|yaml|yml) ;;
    *) continue ;;
  esac

  filepath="$dir/$file"
  echo "[$(date '+%H:%M:%S')] $action: $file" >> "$LOG"

  # Debounce: aynı dosya için bekle
  lockfile="/tmp/egesut-watcher-$(echo $file | tr '/' '-').lock"
  if [ -f "$lockfile" ]; then
    age=$(($(date +%s) - $(stat -c %Y "$lockfile" 2>/dev/null || echo 0)))
    if [ "$age" -lt "$DEBOUNCE" ]; then
      continue
    fi
  fi
  touch "$lockfile"

  # Memory update
  cd "$TOOLSBANK" && python3 automation/code_change_watcher.py --once >> "$LOG" 2>&1
done
