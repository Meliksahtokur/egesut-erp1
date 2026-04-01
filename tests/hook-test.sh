#!/bin/bash
# Gwen Hook Test Suite
# 3 katmanlı hook sisteminin otomatik testleri

echo "🔒 Gwen Hook Test Suite"
echo "======================="
echo ""

TESTLER_GECTI=0
TESTLER_BASARISIZ=0

# Test 1: Pre-commit branch kontrolü (.qwen/ → gwen/dev = RED)
echo "Test 1: .qwen/ dosyası gwen/dev'de RED edilmeli"
echo "------------------------------------------------"

# Mevcut branch'i kaydet
ORIG_BRANCH=$(git symbolic-ref --short HEAD 2>/dev/null)

git checkout gwen/dev 2>/dev/null
echo "// test" > /tmp/test-qwen.md
cp /tmp/test-qwen.md .qwen/test-hook.md
git add .qwen/test-hook.md 2>/dev/null

COMMIT_OUTPUT=$(git commit -m "test" 2>&1)
COMMIT_STATUS=$?

if echo "$COMMIT_OUTPUT" | grep -q "SADECE gwen/arge"; then
    echo "✅ Test 1 geçti: .qwen/ dosyası gwen/dev'de RED edildi"
    TESTLER_GECTI=$((TESTLER_GECTI + 1))
else
    echo "❌ Test 1 başarısız: .qwen/ dosyası gwen/dev'de kabul edildi"
    echo "Çıktı: $COMMIT_OUTPUT"
    TESTLER_BASARISIZ=$((TESTLER_BASARISIZ + 1))
fi

# Temizlik
git reset HEAD .qwen/test-hook.md 2>/dev/null
rm -f .qwen/test-hook.md

# Orijinal branch'e dön
git checkout "$ORIG_BRANCH" 2>/dev/null

echo ""

# Test 2: Pre-commit branch kontrolü (.qwen/ → gwen/arge = Kabul)
echo "Test 2: .qwen/ dosyası gwen/arge'de kabul edilmeli"
echo "---------------------------------------------------"

git checkout gwen/arge 2>/dev/null
echo "// test" > .qwen/test-hook.md
git add .qwen/test-hook.md

COMMIT_OUTPUT=$(git commit -m "DONE: arge — hook test" 2>&1)
COMMIT_STATUS=$?

if [ $COMMIT_STATUS -eq 0 ]; then
    echo "✅ Test 2 geçti: .qwen/ dosyası gwen/arge'de kabul edildi"
    TESTLER_GECTI=$((TESTLER_GECTI + 1))
    
    # Commit'i geri al
    git reset --hard HEAD~1 2>/dev/null
else
    echo "❌ Test 2 başarısız: .qwen/ dosyası gwen/arge'de RED edildi"
    echo "Çıktı: $COMMIT_OUTPUT"
    TESTLER_BASARISIZ=$((TESTLER_BASARISIZ + 1))
fi

rm -f .qwen/test-hook.md

# Orijinal branch'e dön
git checkout "$ORIG_BRANCH" 2>/dev/null

echo ""

# Test 3: Pre-commit branch kontrolü (js/ → gwen/arge = RED)
echo "Test 3: js/ dosyası gwen/arge'de RED edilmeli"
echo "----------------------------------------------"

git checkout gwen/arge 2>/dev/null
echo "// test" > js/test-hook.js
git add js/test-hook.js

COMMIT_OUTPUT=$(git commit -m "test" 2>&1)
COMMIT_STATUS=$?

if echo "$COMMIT_OUTPUT" | grep -q "SADECE gwen/dev"; then
    echo "✅ Test 3 geçti: js/ dosyası gwen/arge'de RED edildi"
    TESTLER_GECTI=$((TESTLER_GECTI + 1))
else
    echo "❌ Test 3 başarısız: js/ dosyası gwen/arge'de kabul edildi"
    echo "Çıktı: $COMMIT_OUTPUT"
    TESTLER_BASARISIZ=$((TESTLER_BASARISIZ + 1))
fi

# Temizlik
git reset HEAD js/test-hook.js 2>/dev/null
rm -f js/test-hook.js

# Orijinal branch'e dön
git checkout "$ORIG_BRANCH" 2>/dev/null

echo ""

# Test 4: Pre-commit branch kontrolü (js/ → gwen/dev = Kabul)
echo "Test 4: js/ dosyası gwen/dev'de kabul edilmeli"
echo "-----------------------------------------------"

git checkout gwen/dev 2>/dev/null
echo "// test" > js/test-hook.js
git add js/test-hook.js

COMMIT_OUTPUT=$(git commit -m "DONE: dev — hook test" 2>&1)
COMMIT_STATUS=$?

if [ $COMMIT_STATUS -eq 0 ]; then
    echo "✅ Test 4 geçti: js/ dosyası gwen/dev'de kabul edildi"
    TESTLER_GECTI=$((TESTLER_GECTI + 1))
    
    # Commit'i geri al
    git reset --hard HEAD~1 2>/dev/null
else
    echo "❌ Test 4 başarısız: js/ dosyası gwen/dev'de RED edildi"
    echo "Çıktı: $COMMIT_OUTPUT"
    TESTLER_BASARISIZ=$((TESTLER_BASARISIZ + 1))
fi

rm -f js/test-hook.js

# Orijinal branch'e dön
git checkout "$ORIG_BRANCH" 2>/dev/null

echo ""

# Test 5: Pre-push DONE: mesajı kontrolü
echo "Test 5: DONE: mesajı olmayan commit RED edilmeli"
echo "-------------------------------------------------"

git checkout gwen/arge 2>/dev/null
echo "// test" > .qwen/test-hook.js
git add .qwen/test-hook.js
git commit -m "test mesajı" 2>/dev/null

# Pre-push hook'u manuel test et (push simülasyonu)
PRE_PUSH_OUTPUT=$(bash .git/hooks/pre-push origin 2>&1)

if echo "$PRE_PUSH_OUTPUT" | grep -q "DONE:"; then
    echo "✅ Test 5 geçti: DONE: mesajı kontrolü çalıştı"
    TESTLER_GECTI=$((TESTLER_GECTI + 1))
else
    echo "❌ Test 5 başarısız: DONE: mesajı kontrolü çalışmadı"
    TESTLER_BASARISIZ=$((TESTLER_BASARISIZ + 1))
fi

# Temizlik
git reset --hard HEAD~1 2>/dev/null
rm -f .qwen/test-hook.js

# Orijinal branch'e dön
git checkout "$ORIG_BRANCH" 2>/dev/null

echo ""
echo "======================="
echo "Test Sonuçları"
echo "======================="
echo "✅ Geçen testler: $TESTLER_GECTI"
echo "❌ Başarısız testler: $TESTLER_BASARISIZ"
echo ""

if [ $TESTLER_BASARISIZ -eq 0 ]; then
    echo "🎉 Tüm testler geçti!"
    exit 0
else
    echo "⚠️  Bazı testler başarısız oldu"
    exit 1
fi
