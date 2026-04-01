# Task-arge-002: Workflow Kalite Kapıları

**Durum:** bekliyor
**Branch:** gwen/arge
**Session:** arge

---

## Açıklama

Operator yükünü düşürmek için 3 kalite kapısı eklenecek. Amaç: syntax hatalı veya eksik iş Claude'a ulaşmasın, Claude sadece merge kararı versin.

---

## Yapılacaklar (sırasıyla)

### 1. pre-commit'e `node --check` ekle

Dosya: `/root/egesut-erp1/.git/hooks/pre-commit`

Mevcut hook sadece branch kontrolü yapıyor. Aşağıdaki bloğu branch kontrolünden **sonra** ekle:

```bash
# JS Syntax Kontrolü
JS_FILES=$(git diff --cached --name-only --diff-filter=ACM | grep "^js/.*\.js$")

if [ -n "$JS_FILES" ]; then
    echo "🔍 JS syntax kontrolü..."
    for FILE in $JS_FILES; do
        if ! node --check "$FILE" 2>&1; then
            echo "❌ Syntax hatası: $FILE — commit bloke edildi"
            exit 1
        fi
    done
    echo "✅ Syntax OK"
fi
```

### 2. done.md şablonunu güncelle

Dosya: `/root/.qwen/agents/gwen.md`

`Task Queue` bölümündeki done.md formatını şu şekilde güncelle — `Syntax Check` zorunlu alan olarak ekle:

```
# Task-XXX Tamamlandı
**Branch:** gwen/dev (veya gwen/arge)
**Yapılanlar:** ...
**Değiştirilen dosyalar:** ...
**Syntax Check:** PASS — node --check js/*.js
**Test notu:** [ne test edildi veya "syntax only"]
```

Aynı güncellemeyi `/root/egesut-erp1/.qwen/QWEN.md` içindeki done.md şablonuna da yap.

### 3. STATUS.md mekanizması ekle

**3a. Dosya oluştur:** `/root/egesut-erp1-main/.claude/STATUS.md`

```markdown
# Sistem Durumu

> Bu dosya Gwen tarafından her task geçişinde güncellenir. Claude tek bakış noktası olarak kullanır.

## DEV
**Task:** —
**Durum:** boşta
**Son güncelleme:** —

## ARGE
**Task:** —
**Durum:** boşta
**Son güncelleme:** —

## Son Merge
**Task:** —
**Tarih:** —
```

**3b. gwen.md'de STATUS güncelleme adımı ekle:**

`Çalışma Akışı` bölümüne şu adımları ekle:
- Adım 1 (TASK AL) sonrası: `STATUS.md`'de ilgili session satırını `devam ediyor` yap
- Adım 7 (REVIEW BİLDİR) sonrası: `STATUS.md`'de ilgili session satırını `test bekliyor — [task adı]` yap

Aynı güncellemeyi `/root/egesut-erp1/.qwen/QWEN.md` içine de yap.

---

## Kabul Kriterleri

- [ ] pre-commit hook JS syntax check içeriyor — staged js/ dosyası syntax hatalıysa commit bloke
- [ ] gwen.md done.md şablonunda `Syntax Check: PASS` alanı var
- [ ] QWEN.md done.md şablonunda `Syntax Check: PASS` alanı var
- [ ] STATUS.md dosyası oluşturuldu
- [ ] gwen.md çalışma akışında STATUS güncelleme adımları var
- [ ] Branch: gwen/arge — js/ dosyalarına dokunma

---

## Notlar

- Bu task sadece `.git/hooks/`, `/root/.qwen/agents/`, `/root/egesut-erp1/.qwen/`, ve `.claude/STATUS.md` dosyalarını değiştirir
- js/ dizinine dokunma
- Tamamlanınca `task-arge-002-done.md` yaz
