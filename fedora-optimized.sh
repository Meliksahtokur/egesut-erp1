#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# Fedora PRoot Optimized Başlatıcı — EgeSüt ERP
# Memory ve CPU optimizasyonlu PRoot başlatma
# ═══════════════════════════════════════════════════════════════

set -e

# Renkler
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔═══════════════════════════════════════════════════════════╗"
echo -e "║  Fedora PRoot Optimized — EgeSüt ERP                ║"
echo -e "╚═══════════════════════════════════════════════════════════╝${NC}"

# Değişkenler
FEDORA_ROOT="/data/data/com.termux/files/usr/var/lib/proot-distro/installed-rootfs/fedora"
SHARED_TMP="/dev/shm"

# Memory optimizasyonları
echo -e "${YELLOW}[1/4] Memory optimizasyonları ayarlanıyor...${NC}"
export NODE_OPTIONS="--max-old-space-size=256"
export V8_MAX_OLD_SPACE_SIZE=256

# PRoot parametreleri
echo -e "${YELLOW}[2/4] PRoot parametreleri hazırlanıyor...${NC}"
PROOT_OPTS=(
  "--bind=/data/data/com.termux/files/usr"
  "--bind=/linkerconfig/com.android.art/ld.config.txt"
  "--bind=/linkerconfig/ld.config.txt"
  "--bind=/vendor"
  "--bind=/system_ext"
  "--bind=/system"
  "--bind=/product"
  "--bind=/odm"
  "--bind=/apex"
  "--bind=/storage/self/primary:/storage/self/primary"
  "--bind=/storage/self/primary:/storage/emulated/0"
  "--bind=/storage/self/primary:/sdcard"
  "--bind=/data/data/com.termux/files/home"
  "--bind=/data/data/com.termux/cache"
  "--bind=/data/misc/apexdata/com.android.art/dalvik-cache"
  "--bind=/data/dalvik-cache"
  "--bind=/data/app"
  # Optimizasyon: /tmp → tmpfs (RAM'de)
  "--bind=${FEDORA_ROOT}/tmp:/dev/shm"
  # Sysctl bind'leri
  "--bind=${FEDORA_ROOT}/proc/.sysctl_inotify_max_user_watches:/proc/sys/fs/inotify/max_user_watches"
  "--bind=${FEDORA_ROOT}/proc/.sysctl_entry_cap_last_cap:/proc/sys/kernel/cap_last_cap"
  "--bind=${FEDORA_ROOT}/proc/.vmstat:/proc/vmstat"
  "--bind=${FEDORA_ROOT}/proc/.version:/proc/version"
  "--bind=${FEDORA_ROOT}/proc/.uptime:/proc/uptime"
  "--bind=${FEDORA_ROOT}/proc/.stat:/proc/stat"
  "--bind=${FEDORA_ROOT}/proc/.loadavg:/proc/loadavg"
  # SELinux boş
  "--bind=${FEDORA_ROOT}/sys/.empty:/sys/fs/selinux"
  # Standard bind'ler
  "--bind=/proc/self/fd/2:/dev/stderr"
  "--bind=/proc/self/fd/1:/dev/stdout"
  "--bind=/proc/self/fd/0:/dev/stdin"
  "--bind=/proc/self/fd:/dev/fd"
  "--bind=/dev/urandom:/dev/random"
  "--bind=/sys"
  "--bind=/proc"
  "--bind=/dev"
)

# Kernel ve environment
KERNEL_RELEASE="Linux localhost 6.17.0-PRoot-Distro #1 SMP PREEMPT_DYNAMIC Fri, 10 Oct 2025 00:00:00 +0000 aarch64 localdomain"

ENV_VARS=(
  "PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/local/games:/usr/games:/data/data/com.termux/files/usr/bin:/system/bin:/system/xbin"
  "ANDROID_ART_ROOT=/apex/com.android.art"
  "ANDROID_DATA=/data"
  "ANDROID_I18N_ROOT=/apex/com.android.i18n"
  "ANDROID_ROOT=/system"
  "ANDROID_TZDATA_ROOT=/apex/com.android.tzdata"
  "BOOTCLASSPATH=/apex/com.android.art/javalib/core-oj.jar:/apex/com.android.art/javalib/core-libart.jar:/apex/com.android.art/javalib/okhttp.jar:/apex/com.android.art/javalib/bouncycastle.jar:/apex/com.android.art/javalib/apache-xml.jar:/system/framework/framework.jar:/system/framework/framework-graphics.jar:/system/framework/ext.jar:/system/framework/telephony-common.jar:/system/framework/voip-common.jar:/system/framework/ims-common.jar:/apex/com.android.i18n/javalib/core-icu4j.jar:/system/framework/radio_interactor_common.jar:/system/framework/unisoc_ims_common.jar:/system/framework/unisoc-framework.jar:/apex/com.android.appsearch/javalib/framework-appsearch.jar:/apex/com.android.conscrypt/javalib/conscrypt.jar:/apex/com.android.ipsec/javalib/android.net.ipsec.ike.jar:/apex/com.android.media/javalib/updatable-media.jar:/apex/com.android.mediaprovider/javalib/framework-mediaprovider.jar:/apex/com.android.mediaprovider/javalib/framework-pdf.jar:/apex/com.android.mediaprovider/javalib/framework-photopicker.jar:/apex/com.android.os.statsd/javalib/framework-statsd.jar:/apex/com.android.permission/javalib/framework-permission.jar:/apex/com.android.permission/javalib/framework-permission-s.jar:/apex/com.android.scheduling/javalib/framework-scheduling.jar:/apex/com.android.sdkext/javalib/framework-sdkextensions.jar:/apex/com.android.tethering/javalib/framework-connectivity.jar:/apex/com.android.tethering/javalib/framework-tethering.jar:/apex/com.android.wifi/javalib/framework-wifi.jar"
  "DEX2OATBOOTCLASSPATH=/apex/com.android.art/javalib/core-oj.jar:/apex/com.android.art/javalib/core-libart.jar:/apex/com.android.art/javalib/okhttp.jar:/apex/com.android.art/javalib/bouncycastle.jar:/apex/com.android.art/javalib/apache-xml.jar:/system/framework/framework.jar:/system/framework/framework-graphics.jar:/system/framework/ext.jar:/system/framework/telephony-common.jar:/system/framework/voip-common.jar:/system/framework/ims-common.jar:/apex/com.android.i18n/javalib/core-icu4j.jar:/system/framework/radio_interactor_common.jar:/system/framework/unisoc_ims_common.jar:/system/framework/unisoc-framework.jar"
  "COLORTERM=truecolor"
  "HOME=/root"
  "USER=root"
  "TERM=xterm-256color"
  "NODE_OPTIONS=--max-old-space-size=256"
)

# Başlat
echo -e "${YELLOW}[3/4] PRoot başlatılıyor...${NC}"
echo -e "${GREEN}✓ Memory limit: 256MB (Node.js)${NC}"
echo -e "${GREEN}✓ Shared TMP: /dev/shm (RAM disk)${NC}"

exec proot \
  "${PROOT_OPTS[@]}" \
  -L \
  --kernel-release="$KERNEL_RELEASE" \
  --sysvipc \
  --link2symlink \
  --kill-on-exit \
  --cwd=/root \
  --rootfs="$FEDORA_ROOT" \
  --change-id=0:0 \
  /usr/bin/env "${ENV_VARS[@]}" \
  /bin/bash -l
