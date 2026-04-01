# Gwen Hook Sistemi

## 3 Katmanlı Güvenlik

Gwen agent'ının branch izolasyonunu ve review zorunluluğunu sağlayan 3 katmanlı hook sistemi.

---

## 1. Post-Checkout Hook

**Dosya:** `.git/hooks/post-checkout`

**Tetiklenme:** Her `git checkout` işleminden sonra

### İşlevi

- Branch değişimini yakala
- **gwen-self-improvement skill kilidi:**
  - Skill aktifse → SADECE `gwen/arge` branch'ine izin ver
  - Yanlış branch → Otomatik `gwen/arge`'e geç
  - Değişiklikleri stash → geri yükle

### Akış

```bash
git checkout gwen/dev
# ↓
Post-checkout hook çalışır
# ↓
gwen-self-improvement skill var mı? → EVET
# ↓
Mevcut branch gwen/arge mi? → HAYIR
# ↓
✅ Otomatik düzeltme:
  1. git stash push -m "Pre-hook stash"
  2. git checkout gwen/arge
  3. git stash pop
```

### Kod Özeti

```bash
# Gwen self-improvement skill aktif mi kontrol et
QWEN_SKILL_FILE="/root/.qwen/skills/gwen-self-improvement/SKILL.md"

if [ -f "$QWEN_SKILL_FILE" ]; then
    # İzin verilen branch'ler: gwen/arge, gwen/task-arge
    # Yanlış branch → otomatik düzeltme + stash
fi
```

---

## 2. Pre-Commit Hook

**Dosya:** `.git/hooks/pre-commit`

**Tetiklenme:** Her `git commit` işleminden önce

### İşlevi

- Commit öncesi branch kontrolü
- **Dosya tipi → branch eşleştirme:**
  - `.qwen/` dosyaları → SADECE `gwen/arge`
  - `js/` dosyaları → SADECE `gwen/dev`
  - `.git/hooks/` → Her iki branch'te serbest
- Yanlış branch → **RED** (exit 1)

### Kurallar

| Dosya Yolu | İzin Verilen Branch |
|------------|---------------------|
| `.qwen/*` | `gwen/arge` |
| `js/*` | `gwen/dev` |
| `.git/hooks/*` | Her ikisi |

### Akış

```bash
# Test 1: Yanlış branch
git checkout gwen/dev
git add .qwen/QWEN.md
git commit -m "test"
# ↓
Pre-commit hook çalışır
# ↓
.qwen/ dosyası tespit edildi
# ↓
Branch gwen/arge mi? → HAYIR
# ↓
❌ RED: ".qwen/ dosyaları SADECE gwen/arge branch'inde commit edilebilir!"
```

### Kod Özeti

```bash
CURRENT_BRANCH=$(git symbolic-ref --short HEAD)
CHANGED_FILES=$(git diff --cached --name-only)

# .qwen/ → SADECE gwen/arge
if echo "$CHANGED_FILES" | grep -q "^\.qwen/"; then
    if [ "$CURRENT_BRANCH" != "gwen/arge" ]; then
        echo "❌ HATA: .qwen/ dosyaları SADECE gwen/arge branch'inde!"
        exit 1
    fi
fi

# js/ → SADECE gwen/dev
if echo "$CHANGED_FILES" | grep -q "^js/"; then
    if [ "$CURRENT_BRANCH" != "gwen/dev" ]; then
        echo "❌ HATA: js/ dosyaları SADECE gwen/dev branch'inde!"
        exit 1
    fi
fi
```

---

## 3. Pre-Push Hook

**Dosya:** `.git/hooks/pre-push`

**Tetiklenme:** Her `git push` işleminden önce

### İşlevi

- **DONE: commit mesajı kontrolü**
  - Format: `DONE: [dev|arge] — [açıklama]`
  - Yanlış format → RED
- **Review durumu kontrolü**
  - `.review-status.json` var mı?
  - Review < 10 dk → ✅ PUSH
  - Review yok/Eski → ⚠️ UYARI (push'a izin ver, hatırlat)

### Review Durumları

| Durum | Aksiyon |
|-------|---------|
| ✅ PUSH ONAYLI | Push devam eder |
| ❌ PUSH BLOKE | Push reddedilir |
| ⚠️ UYARI | Hatırlatma, push devam eder |

### Akış

```bash
# Test: Review ONAYLI + Push
/review
# ↓
gwen-reviewer çalışır
# ↓
.review-status.json oluşturulur:
{ "status": "ONAYLI", "timestamp": "..." }
# ↓
git push
# ↓
Pre-push hook çalışır
# ↓
Review < 10 dk + ONAYLI
# ↓
✅ Push devam eder
```

### Kod Özeti

```bash
# DONE: commit mesajı kontrolü
LAST_COMMIT=$(git log -1 --format="%s")
if [[ ! "$LAST_COMMIT" =~ ^DONE: ]]; then
    echo "❌ HATA: Commit mesajı 'DONE:' ile başlamalı!"
    exit 1
fi

# Review durumu kontrolü
REVIEW_STATUS_FILE="/root/egesut-erp1/.review-status.json"
if [ -f "$REVIEW_STATUS_FILE" ]; then
    FILE_AGE=$(( $(date +%s) - $(stat -c %Y "$REVIEW_STATUS_FILE") ))
    if [ $FILE_AGE -lt 600 ]; then  # 10 dakika
        REVIEW_STATUS=$(cat "$REVIEW_STATUS_FILE" | grep -o '"status":"[^"]*"' | cut -d'"' -f4)
        if [ "$REVIEW_STATUS" = "ONAYLI" ]; then
            echo "✅ Review yapılmış: PUSH ONAYLI"
            exit 0
        fi
    fi
fi

# Review yok/eски → Uyarı ama push'a izin ver
echo "⚠️  REVIEW HATIRLATMA"
echo "Push öncesi /review komutunu çalıştırın"
exit 0  # İleride exit 1 yapılabilir
```

---

## Test Protokolü

### Test 1: Yanlış Branch (.qwen/ → gwen/dev)

```bash
git checkout gwen/dev
echo "// test" > .qwen/test-hook.md
git add .qwen/test-hook.md
git commit -m "test"
# ❌ RED (.qwen/ sadece gwen/arge'de)
```

**Beklenen Çıktı:**
```
🔒 GWEN BRANCH KİLİDİ
====================
Mevcut branch: gwen/dev

❌ HATA: .qwen/ dosyaları SADECE gwen/arge branch'inde commit edilebilir!

Değiştirilen dosyalar:
.qwen/test-hook.md

✅ Çözüm:
   git checkout gwen/arge
```

---

### Test 2: Doğru Branch (.qwen/ → gwen/arge)

```bash
git checkout gwen/arge
echo "// test" > .qwen/test-hook.md
git add .qwen/test-hook.md
git commit -m "DONE: arge — hook test"
# ✅ Kabul edildi
```

**Beklenen Çıktı:**
```
🔒 GWEN BRANCH KİLİDİ
====================
Mevcut branch: gwen/arge

✅ .qwen/ dosyaları - gwen/arge branch'inde

✅ Branch kontrolü geçti
```

---

### Test 3: Review Olmadan Push

```bash
git commit -m "DONE: arge — test"
git push
# ⚠️ UYARI (review hatırlatma)
```

**Beklenen Çıktı:**
```
🔍 GWEN REVIEW KONTROLÜ
=======================

✅ Commit mesajı doğru: DONE: arge — test

⚠️  Review dosyası bulunamadı veya eski

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

⚠️  REVIEW HATIRLATMA

Push yapmadan önce /review komutunu çalıştırın:

  /review

Bu komut gwen-reviewer agent'ını çalıştırır...

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

### Test 4: Review ONAYLI + Push

```bash
/review
# ✅ PUSH ONAYLI
git push
# ✅ Push devam eder
```

**Beklenen Çıktı:**
```
🔍 GWEN REVIEW KONTROLÜ
=======================

✅ Commit mesajı doğru: DONE: arge — test

✅ Review yapılmış: PUSH ONAYLI

🚀 Push devam ediyor...
```

---

## Özet

| Hook | Tetiklenme | Kontrol | Sonuç |
|------|------------|---------|-------|
| **post-checkout** | `git checkout` | gwen-self-improvement branch kilidi | Otomatik düzeltme + stash |
| **pre-commit** | `git commit` | Dosya tipi → branch eşleştirme | RED veya Kabul |
| **pre-push** | `git push` | DONE: mesajı + review durumu | RED / UYARI / Kabul |

---

## Güvenlik Katmanları

```
┌─────────────────────────────────────────────────┐
│  1. Post-Checkout: Branch değişimini yakala     │
│     → gwen-self-improvement kilidi              │
└─────────────────────────────────────────────────┘
                      ↓
┌─────────────────────────────────────────────────┐
│  2. Pre-Commit: Dosya tipi → branch kontrolü    │
│     → .qwen/ → gwen/arge                        │
│     → js/ → gwen/dev                            │
└─────────────────────────────────────────────────┘
                      ↓
┌─────────────────────────────────────────────────┐
│  3. Pre-Push: Review zorunluluğu                │
│     → DONE: mesajı                              │
│     → .review-status.json (< 10 dk)             │
└─────────────────────────────────────────────────┘
```

---

**Son Güncelleme:** 2026-04-01
**Branch:** gwen/arge
