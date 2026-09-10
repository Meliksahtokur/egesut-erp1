# Task-arge-005: Hook Sistemi Dokümantasyonu

**Durum:** bekliyor
**Branch:** gwen/arge
**Session:** arge

---

## Açıklama

Hook sistemi tamamlandı (post-checkout, pre-commit, pre-push). Şimdi dokümantasyon + test protokolü ekle.

---

## Yapılacaklar

### 1. HOOK_SYSTEM.md Oluştur

Dosya: `/root/egesut-erp1-main/.claude/HOOK_SYSTEM.md`

```markdown
# Gwen Hook Sistemi

## 3 Katmanlı Güvenlik

### 1. Post-Checkout Hook
- Branch değişimini yakala
- .qwen/ → gwen/arge zorla
- js/ → gwen/dev zorla
- Otomatik düzeltme + stash

### 2. Pre-Commit Hook
- Commit öncesi branch kontrolü
- .qwen/ dosyaları → SADECE gwen/arge
- js/ dosyaları → SADECE gwen/dev
- Yanlış branch → RED

### 3. Pre-Push Hook
- DONE: commit mesajı kontrolü
- .review-status.json kontrolü
- Review < 10 dk → ✅ PUSH
- Review yok/Eski → ⚠️ UYARI

## Test Protokolü

### Test 1: Yanlış Branch
```bash
git checkout gwen/dev
git add .qwen/QWEN.md
git commit -m "test"
# Beklenen: ❌ RED (.qwen/ sadece gwen/arge'de)
```

### Test 2: Review Olmadan Push
```bash
git commit -m "DONE: arge — test"
git push
# Beklenen: ⚠️ UYARI (review hatırlatma)
```

### Test 3: Review ONAYLI + Push
```bash
/review → ✅ PUSH ONAYLI
git push
# Beklenen: ✅ Push devam eder
```
```

### 2. Hook Test Script Oluştur

Dosya: `/root/egesut-erp1/tests/hook-test.sh`

```bash
#!/bin/bash
# Hook Test Suite

echo "Test 1: Yanlış branch'te .qwen/ commit"
git checkout gwen/dev
echo "test" > .qwen/test.md
git add .qwen/test.md
git commit -m "test" 2>&1 | grep -q "SADECE gwen/arge"
if [ $? -eq 0 ]; then
    echo "✅ Test 1 geçti"
else
    echo "❌ Test 1 başarısız"
fi

# Temizlik
git checkout .qwen/test.md
rm -f .qwen/test.md

echo "Test 2: Doğru branch'te .qwen/ commit"
git checkout gwen/arge
echo "test" > .qwen/test.md
git add .qwen/test.md
git commit -m "test" 2>&1
if [ $? -eq 0 ]; then
    echo "✅ Test 2 geçti"
else
    echo "❌ Test 2 başarısız"
fi

# Temizlik
git reset --hard HEAD~1
rm -f .qwen/test.md
```

### 3. BLACKBOARD.md Güncelle

Hook test adımlarını ekle.

---

## Kabul Kriterleri

- [ ] HOOK_SYSTEM.md oluşturuldu
- [ ] tests/hook-test.sh oluşturuldu
- [ ] Test çalıştırıldı → Tüm testler geçti
- [ ] BLACKBOARD.md güncellendi
- [ ] Branch: gwen/arge
- [ ] Tamamlanınca `task-arge-005-done.md` yaz

---

## Notlar

- js/ dosyalarına dokunma
- Hook'ları test etmeden push etme
- Review zorunlu!
