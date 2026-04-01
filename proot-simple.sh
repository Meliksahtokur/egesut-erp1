#!/bin/bash
# Basit Proot Başlatıcı - EgeSüt ERP

FEDORA_ROOT="/data/data/com.termux/files/usr/var/lib/proot-distro/installed-rootfs/fedora"
LOCK_FILE="/tmp/fedora-proot.pid"
SESSION_FILE="/tmp/fedora-proot.session"

# Tek instance kontrolü
if [ -f "$LOCK_FILE" ] && kill -0 "$(cat "$LOCK_FILE")" 2>/dev/null; then
    echo "⚠️ Fedora PRoot zaten çalışıyor (PID: $(cat "$LOCK_FILE"))"
    echo "Bağlanmak için: proot --pid=$(cat "$LOCK_FILE")"
    exit 0
fi

# Rootfs kontrolü
if [ ! -d "$FEDORA_ROOT" ]; then
    echo "❌ Fedora rootfs bulunamadı: $FEDORA_ROOT"
    exit 1
fi

echo "🚀 Fedora PRoot başlatılıyor..."

# Basit ve temiz proot başlat
proot \
    --rootfs="$FEDORA_ROOT" \
    --bind=/data/data/com.termux/files/usr \
    --bind=/dev \
    --bind=/proc \
    --bind=/sys \
    --cwd=/root \
    --change-id=0:0 \
    /bin/bash -l &

PROOT_PID=$!
echo $PROOT_PID > "$LOCK_FILE"
echo $PROOT_PID > "$SESSION_FILE"

echo "✅ Fedora PRoot başlatıldı (PID: $PROOT_PID)"
echo "📁 Session: $SESSION_FILE"

# Proot'u bekle
wait $PROOT_PID
