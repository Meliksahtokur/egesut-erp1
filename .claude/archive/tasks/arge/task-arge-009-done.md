# Task-arge-009 Tamamlandı

**Branch:** gwen/arge
**Tarih:** 2026-04-02
**Öncelik:** kritik

---

## Yapılanlar

### 1. Worktree İzolasyonu ✅

**Önceki Durum:**
- `/root/egesut-erp1/` tek klasör — dev ve arge aynı repoda branch değiştiriyor
- Branch switch → hook bypass gerekiyor → güvenlik delinmiş
- `.git` worktree yapısı bozuk

**Yeni Durum:**
```
/root/egesut-erp1/        ← Claude (main branch)
/root/qwen-dev/           ← Gwen dev (gwen/dev branch, kilitli)
/root/qwen-arge/          ← Gwen arge (gwen/arge branch, kilitli)
```

**İşlemler:**
1. Ana repository `/root/egesut-erp1/`'de git reset + fetch
2. `git worktree add /root/qwen-dev origin/gwen/dev` — yeni worktree
3. `git worktree add /root/qwen-arge origin/gwen/arge` — yeni worktree
4. Her worktree kendi branch'ine bağlandı

**Worktree Listesi:**
```
/root/egesut-erp1 c051e88 [main]
/root/qwen-arge   d8f4202 [gwen/arge]
/root/qwen-dev    a93afbd [gwen/dev]
```

---

### 2. .agents/QWEN.md — 4 Demir Kural Eklendi ✅

Dosyanın başına eklendi:

```markdown
## ⚠️ 4 DEMİR KURAL — İHLAL YASAK

### Kural 1: Task İzolasyonu
- gwen/dev (qwen-dev) → SADECE `.claude/tasks/dev/` klasörüne bak
- gwen/arge (qwen-arge) → SADECE `.claude/tasks/arge/` klasörüne bak
- Diğer klasörü aç**ma**, oku**ma**, yap**ma**

### Kural 2: Otonom Workflow (sıra değişmez)
1. .claude/tasks/{session}/ACTIVE.md yaz
2. Task uygula
3. node --check js/*.js (dev için)
4. git add + git commit -m "DONE: [session] — [açıklama]"
5. /review → gwen-reviewer
6. ✅ → git push + BLACKBOARD güncelle + done.md yaz + ACTIVE.md sil
7. ❌ → düzelt + commit + tekrar /review (max 3)
8. 3'te geçmezse → BLOCKED-[id].md yaz, dur

### Kural 3: Context7 Zorunlu
`.from()` `.rpc()` `.select()` `.insert()` `IndexedDB` `Service Worker` kullanmadan önce:
→ context7'den güncel doküman çek. "Biliyorum" demek YASAK.

### Kural 4: Task Bitişi Zorunlu Kontrol
Push sonrası HEPSI yapılmış olmalı:
- [ ] done.md oluşturuldu
- [ ] BLACKBOARD.md güncellendi
- [ ] ACTIVE.md silindi
- [ ] Claude'a bildirildi (BLACKBOARD'a "DONE: task-XXX" yaz)
```

**Worktree Paths Tablosu:**
```markdown
## Worktree Paths

| Session | Path | Branch |
|---------|------|--------|
| dev | `/root/qwen-dev` | `gwen/dev` |
| arge | `/root/qwen-arge` | `gwen/arge` |
| claude | `/root/egesut-erp1` | `main` |
```

---

### 3. CLAUDE.md — Path Güncellemeleri ✅

**Değişiklikler:**
- Worktree yapısı güncellendi (egesut-erp1 → qwen-dev/qwen-arge)
- Task path'leri: `.claude/gwen-tasks/` → `.claude/tasks/{session}/`
- Branch formatı: `gwen/task-XXX` → `gwen/{session}`
- Gwen task lookup: `.claude/gwen-tasks/` → `.claude/tasks/dev/` ve `.claude/tasks/arge/`

---

### 4. aktifbuglar.md Referansları ✅

**Kontrol:** `grep -r "aktifbuglar" .agents/ .qwen/ 2>/dev/null`

**Sonuç:** Referans bulunamadı — zaten temiz.

---

## Değiştirilen Dosyalar

| Dosya | Değişiklik |
|-------|-----------|
| `.agents/QWEN.md` | 4 Demir Kural + Worktree Paths eklendi |
| `CLAUDE.md` | Worktree paths + task lookup paths güncellendi |

---

## Test

```bash
# Worktree doğrulama
$ git worktree list
/root/egesut-erp1 c051e88 [main]
/root/qwen-arge   d8f4202 [gwen/arge]
/root/qwen-dev    a93afbd [gwen/dev]

# Branch doğrulama
$ cd /root/qwen-arge && git branch --show-current
gwen/arge

$ cd /root/qwen-dev && git branch --show-current
gwen/dev
```

---

## Sonraki Adımlar

- [x] done.md oluşturuldu
- [ ] BLACKBOARD.md güncellenecek
- [ ] Commit + Review + Push

---

**Task-arge-009:** Worktree izolasyonu + 4 Demir Kural ✅
