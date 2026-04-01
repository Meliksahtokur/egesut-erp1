#!/bin/bash
# Gwen Self-Improvement Wrapper Script
# Bu script, gwen-self-improvement skill çağrılmadan önce otomatik çalışır.
# Amaç: Doğru branch'te olduğundan emin olmak.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_BRANCH="gwen/arge"
STASH_NAME="gwen-self-improvement-auto-stash"

echo ""
echo "🔒 GWEN SELF-IMPROVEMENT BRANCH KİLİDİ"
echo "======================================="
echo ""

# Mevcut branch'i al
CURRENT_BRANCH=$(git symbolic-ref --short HEAD 2>/dev/null || echo "DETACHED")

echo "📍 Mevcut branch: $CURRENT_BRANCH"
echo "🎯 Hedef branch: $TARGET_BRANCH"
echo ""

# Eğer zaten doğru branch'teysek
if [ "$CURRENT_BRANCH" = "$TARGET_BRANCH" ]; then
    echo "✅ Zaten doğru branch'tesiniz ($TARGET_BRANCH)"
    echo ""
    echo "🚀 Gwen self-improvement skill hazır!"
    echo ""
    exit 0
fi

# Değişiklikleri kontrol et
CHANGED_FILES=$(git diff --name-only 2>/dev/null || echo "")
HAS_CHANGES=0

if [ -n "$CHANGED_FILES" ]; then
    HAS_CHANGES=1
    echo "📝 Değişiklikler tespit edildi:"
    echo "$CHANGED_FILES" | head -10
    echo ""
fi

# Untracked dosyaları kontrol et
UNTRACKED_FILES=$(git ls-files --others --exclude-standard 2>/dev/null || echo "")
if [ -n "$UNTRACKED_FILES" ]; then
    echo "📄 Untracked dosyalar tespit edildi:"
    echo "$UNTRACKED_FILES" | head -10
    echo ""
fi

# Değişiklikleri stash et
if [ $HAS_CHANGES -eq 1 ]; then
    echo "📦 Değişiklikler stash ediliyor..."
    git stash push -m "$STASH_NAME" 2>/dev/null
    if [ $? -eq 0 ]; then
        echo "✅ Değişiklikler stash edildi"
    else
        echo "⚠️  Stash başarısız, devam ediliyor..."
    fi
    echo ""
fi

# Branch değiştir
echo "🔄 Branch değiştiriliyor: $CURRENT_BRANCH → $TARGET_BRANCH"
git checkout "$TARGET_BRANCH" 2>/dev/null

if [ $? -eq 0 ]; then
    echo "✅ Branch değiştirildi: $TARGET_BRANCH"
    echo ""
    
    # Stash geri yükle
    if [ $HAS_CHANGES -eq 1 ]; then
        echo "📥 Değişiklikler geri yükleniyor..."
        git stash pop 2>/dev/null
        if [ $? -eq 0 ]; then
            echo "✅ Değişiklikler geri yüklendi"
        else
            echo "⚠️  Stash pop başarısız - manuel 'git stash pop' çalıştırın"
        fi
        echo ""
    fi
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "🎉 Gwen self-improvement skill hazır!"
    echo ""
    echo "📋 Şu anda: $TARGET_BRANCH branch'indesiniz"
    echo "🔒 Branch kilidi AKTİF - başka branch'e geçemezsiniz"
    echo ""
    echo "💡 İpucu: Skill kullanımı bittikten sonra"
    echo "   git checkout <branch> ile geri dönebilirsiniz."
    echo ""
else
    echo "❌ Branch değiştirme başarısız!"
    echo ""
    echo "Hata: git checkout $TARGET_BRANCH komutu başarısız oldu."
    echo ""
    
    # Stash geri yükle (başarısız durumda)
    if [ $HAS_CHANGES -eq 1 ]; then
        echo "📥 Değişiklikler geri yükleniyor (rollback)..."
        git stash pop 2>/dev/null
    fi
    
    exit 1
fi

exit 0
