#!/bin/bash
# MCP Watchdog - Düşen server'ları restart et

LOG="/var/log/mcp-watchdog.log"
SCREENS=("mcp-supabase" "mcp-github" "mcp-context7")
PATHS=(
    "/root/egesut-erp1/gwen-mcp-servers/supabase"
    "/root/egesut-erp1/gwen-mcp-servers/github"
    ""  # context7 için path yok
)
CMDS=(
    "node index.js"
    "node index.js"
    "npx -y @upstash/context7-mcp@latest"
)

echo "[$(date)] MCP Watchdog başlatıldı" >> $LOG

while true; do
    for i in "${!SCREENS[@]}"; do
        screen_name="${SCREENS[$i]}"
        if ! screen -ls | grep -q "$screen_name"; then
            echo "[$(date)] ⚠️ $screen_name çöktü, yeniden başlatılıyor..." >> $LOG
            if [ -n "${PATHS[$i]}" ]; then
                screen -dmS "$screen_name" bash -c "cd ${PATHS[$i]} && ${CMDS[$i]} 2>&1 | tee /var/log/$screen_name.log"
            else
                screen -dmS "$screen_name" bash -c "${CMDS[$i]} 2>&1 | tee /var/log/$screen_name.log"
            fi
            echo "[$(date)] ✅ $screen_name yeniden başlatıldı" >> $LOG
        fi
    done
    sleep 30
done
