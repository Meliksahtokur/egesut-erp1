# Task-arge-006: Root Dosyaları .agents/'a Taşı

**Durum:** bekliyor
**Branch:** gwen/arge
**Session:** arge

---

## Açıklama

Root dizininde dağınık dokümantasyon dosyaları var. Bunları `.agents/` klasörüne taşıyarak düzen sağla.

---

## Taşınacak Dosyalar

```
ROOT'teki dağınık dosyalar:
- QUICK_START.md
- QWEN.md
- SESSION_STABILITY.md
- FULLSTACK_AGENT ihtiyaclar.md
- gwen-self-improvement-wrapper.sh

HEDEF: .agents/ klasörü
```

---

## Yapılacaklar

### 1. .agents/ Klasörü Oluştur

```bash
mkdir -p /root/egesut-erp1/.agents
```

### 2. Dosyaları Taşı

```bash
# Dokümantasyon
mv /root/egesut-erp1/QUICK_START.md /root/egesut-erp1/.agents/
mv /root/egesut-erp1/QWEN.md /root/egesut-erp1/.agents/
mv /root/egesut-erp1/SESSION_STABILITY.md /root/egesut-erp1/.agents/
mv "/root/egesut-erp1/FULLSTACK_AGENT ihtiyaclar.md" /root/egesut-erp1/.agents/

# Script
mv /root/egesut-erp1/gwen-self-improvement-wrapper.sh /root/egesut-erp1/.agents/
```

### 3. .gitignore Güncelle

`.agents/` klasörünü gitignore'a ekle (eğer değilse):
```
.agents/
```

### 4. README.md Güncelle (Opsiyonel)

Eğer root'ta README.md varsa, dosya konumlarını güncelle.

### 5. Commit + Review + Push

```bash
git add .agents/
git add .gitignore  # Eğer değiştiyse
git commit -m "DONE: arge — task-arge-006: Root dosyaları .agents/'a taşındı"
/review
# ✅ PUSH ONAYLI → git push origin gwen/arge
```

---

## Kabul Kriterleri

- [ ] .agents/ klasörü oluşturuldu
- [ ] 5 dosya taşındı (QUICK_START, QWEN, SESSION_STABILITY, FULLSTACK_AGENT, wrapper)
- [ ] .gitignore güncellendi
- [ ] Branch: gwen/arge
- [ ] js/ dosyalarına dokunma
- [ ] Tamamlanınca `task-arge-006-done.md` yaz

---

## Notlar

- Dosya içeriklerini DEĞİŞTİRME — sadece taşı
- .agents/ klasörü git'e commit edilmeyecek (gitignore)
- Review zorunlu!
