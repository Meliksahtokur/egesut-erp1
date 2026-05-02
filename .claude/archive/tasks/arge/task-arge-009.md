# Task-arge-009: Worktree İzolasyonu + 4 Demir Kural

**Durum:** bekliyor
**Branch:** gwen/arge
**Tarih:** 2026-04-02
**Öncelik:** kritik

---

## Problem

1. `/root/egesut-erp1/` tek klasör — dev ve arge aynı repoda branch değiştiriyor
2. Branch switch → hook bypass gerekiyor → güvenlik delinmiş
3. `.agents/qwen/QWEN.md`'de 4 Demir Kural yok — task-arge-008'den kalan eksik

---

## Yapılacaklar

### 1. Worktree İzolasyonu (git komutları)

```bash
# gwen/dev branch'i yoksa oluştur
git -C /root/egesut-erp1-main branch gwen/dev origin/gwen/dev 2>/dev/null || true

# Yeni worktree'ler oluştur
git -C /root/egesut-erp1-main worktree add /root/qwen-dev gwen/dev
git -C /root/egesut-erp1-main worktree add /root/qwen-arge gwen/arge

# Eski worktree'yi kaldır
git -C /root/egesut-erp1-main worktree remove /root/egesut-erp1 --force 2>/dev/null || \
  git -C /root/egesut-erp1-main worktree prune
```

**Sonuç yapısı:**
```
/root/egesut-erp1-main/  ← Claude (main)
/root/qwen-dev/           ← Gwen dev (gwen/dev, kilitli)
/root/qwen-arge/          ← Gwen arge (gwen/arge, kilitli)
```

---

### 2. gwen-cli.sh Güncelle

`.agents/gwen-cli.sh` (veya `gwen-cli.sh` neredeyse) içindeki path'leri güncelle:

```bash
# Eski:
WORKTREE="/root/egesut-erp1"

# Yeni (session tipine göre):
if [ "$SESSION" = "dev" ]; then
  WORKTREE="/root/qwen-dev"
elif [ "$SESSION" = "arge" ]; then
  WORKTREE="/root/qwen-arge"
fi
```

---

### 3. QWEN.md — 4 Demir Kural Ekle

**Dosya:** `.agents/qwen/QWEN.md` (bu dosya git'te takip ediliyor, `.qwen/` değil)

Dosyanın EN BAŞINA (ilk başlıktan önce) ekle:

```markdown
## ⚠️ 4 DEMİR KURAL — İHLAL YASAK

### Kural 1: Task İzolasyonu
- gwen/dev (qwen-dev) → SADECE `.claude/tasks/dev/` klasörüne bak
- gwen/arge (qwen-arge) → SADECE `.claude/tasks/arge/` klasörüne bak
- Diğer klasörü aç**ma**, oku**ma**, yap**ma**

### Kural 2: Otonom Workflow (sıra değişmez)
```
1. .claude/tasks/{session}/ACTIVE.md yaz
2. Task uygula
3. node --check js/*.js (dev için)
4. git add + git commit -m "DONE: [session] — [açıklama]"
5. /review → gwen-reviewer
6. ✅ → git push + BLACKBOARD güncelle + done.md yaz + ACTIVE.md sil
7. ❌ → düzelt + commit + tekrar /review (max 3)
8. 3'te geçmezse → BLOCKED-[id].md yaz, dur
```

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

---

### 4. Worktree Path'lerini QWEN.md'ye Yaz

```markdown
## Worktree Paths

| Session | Path | Branch |
|---------|------|--------|
| dev | `/root/qwen-dev` | `gwen/dev` |
| arge | `/root/qwen-arge` | `gwen/arge` |
| claude | `/root/egesut-erp1-main` | `main` |
```

---

### 5. Task Lookup Path'lerini Güncelle

`GWEN_OTONOM_WORKFLOW.md` veya ilgili skill dosyalarında task path'leri güncelle:
```
Eski: .claude/gwen-tasks/
Yeni (dev): .claude/tasks/dev/
Yeni (arge): .claude/tasks/arge/
```

---

## Kabul Kriterleri

- [ ] `/root/qwen-dev` worktree var, `gwen/dev` branch'inde kilitli
- [ ] `/root/qwen-arge` worktree var, `gwen/arge` branch'inde kilitli
- [ ] `/root/egesut-erp1` kaldırıldı (veya worktree listesinden çıkarıldı)
- [ ] gwen-cli.sh path'leri güncellendi
- [ ] `.agents/qwen/QWEN.md` başında 4 Demir Kural var
- [ ] QWEN.md'de worktree path tablosu var
- [ ] GWEN_OTONOM_WORKFLOW.md'de task path'leri güncellendi
- [ ] `aktifbuglar.md` referansları kaldırıldı, `.claude/knowledge/bugs.md` yazıldı
- [ ] Push edildi, `arge/task-arge-009-done.md` yazıldı

---

### 6. aktifbuglar.md Referanslarını Temizle

`.agents/qwen/` ve `.qwen/` altındaki tüm dosyalarda `aktifbuglar.md` referansı varsa kaldır/düzelt:

```bash
grep -r "aktifbuglar" .agents/ .qwen/ 2>/dev/null
```

Bulunan her referansı → `.claude/knowledge/bugs.md` olarak güncelle.

---

## Notlar

- `git worktree add` başarısız olursa branch'in remote'da olduğundan emin ol
- Eski `/root/egesut-erp1` klasörü `--force` ile kaldırılabilir
- Bu task bittikten sonra Claude CLAUDE.md ve memory'yi güncelleyecek
