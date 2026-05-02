# Task-arge-001 Revize

**Durum:** revize
**Branch:** gwen/arge-001 (aynı branch'te devam et)

---

Code review bulguları. 3 düzeltme:

## 1. Branch naming standartlaştır

`gwen/task-XXX` formatı resmi kural (CLAUDE.md). Ama bazı dosyalar `feature/gwen-*` diyor.

Şu dosyalarda `feature/gwen-*` geçen her yeri `gwen/task-XXX` olarak güncelle:
- `/root/.qwen/agents/gwen.md`
- `/root/.qwen/skills/egesut-fullstack/SKILL.md`
- Diğer skill dosyaları varsa onlar da

## 2. `session-rules/SKILL.md` tamamla

`/root/.qwen/skills/session-rules/SKILL.md` dosyası 261. satırda yarım kesiyor. ASCII art summary box tamamlanmamış.

Dosyayı oku, yarım kalan bölümü mantıklı şekilde tamamla veya yarım kalan bölümü tamamen sil — ikisi de kabul edilir.

## 3. `.gitignore`'a `.qwen-backup/` ekle

`/root/egesut-erp1/.gitignore` dosyasına şu satırı ekle:
```
.qwen-backup/
```

---

## Kabul Kriterleri

- [ ] Hiçbir dosyada `feature/gwen-*` branch referansı kalmadı
- [ ] `session-rules/SKILL.md` temiz bitiyor (yarım ASCII art yok)
- [ ] `.gitignore`'da `.qwen-backup/` var
- [ ] `gwen/arge-001` branch'ine commit edildi

## Tamamlandığında

`/root/egesut-erp1-main/.claude/gwen-tasks/task-arge-001-done.md` yaz.
