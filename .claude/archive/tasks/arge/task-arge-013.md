# Task-arge-013: Gwen Orchestrator — Agent + Context Dosyaları

**Durum:** bekliyor
**Branch:** gwen/arge
**Tarih:** 2026-04-02
**Öncelik:** yüksek

---

## Bağlam

Yeni bir Qwen CLI session'ı açılacak: **gwen/orch** — Claude'un orkestratör rolünü üstlenecek.

Worktree hazır: `/root/qwen-main` → `gwen/orch` branch

**Görev:** Bu session için gerekli agent + context dosyalarını oluştur.

---

## Yapılacaklar

### 1. ORCHESTRATOR_CONTEXT.md — Claude Belleği Derle

**Dosya:** `.agents/qwen/agents/ORCHESTRATOR_CONTEXT.md`

Claude'un memory dosyalarındaki bilgileri tek bir context dosyasına derle.
Şu bilgileri içersin:

```markdown
# EgeSüt ERP — Orchestrator Context

## Proje
- Vanilla JS PWA + Supabase backend, offline-first
- Stack: js/ (ui.js, forms.js, app.js, api.js) + supabase/ + index.html
- Supabase project_id: zqnexqbdfvbhlxzelzju

## Worktree Yapısı
/root/egesut-erp1  → main branch  → Claude/Orchestrator (sen)
/root/qwen-main    → gwen/orch    → sen burada çalışıyorsun
/root/qwen-dev     → gwen/dev    → ERP implementer (Gwen/dev)
/root/qwen-arge    → gwen/arge   → Tooling implementer (Gwen/arge)

## GitHub
- Token: ~/.netrc (git otomatik kullanır)
- PR merge: `gh pr merge <number> --merge --delete-branch`
- PR list: `gh pr list`

## Task Sistemi
- Dev task'ları: /root/qwen-dev/.claude/tasks/dev/
- Arge task'ları: /root/qwen-arge/.claude/tasks/arge/
- Task yaz → worktree'ye git add + commit + push
- Gwen okur, tamamlar, *-done.md yazar, push eder
- Orchestrator: PR incele → onayla → merge et

## Aktif Task Durumu
- BLACKBOARD.md her session'da tara: /root/qwen-dev/.claude/tasks/dev/BLACKBOARD.md
- BLACKBOARD.md her session'da tara: /root/qwen-arge/.claude/tasks/arge/BLACKBOARD.md

## Kurallar
- main'e direkt push YASAK — sadece gh pr merge
- Merge etmeden önce diff incele: gh pr diff <number>
- Task yazarken branch adını explicit belirt
- Revize: aynı task dosyasını güncelle, yeni dosya açma
- Dev = ERP kodu · Arge = tooling/agent/skill değişiklikleri

## RPC Kuralları
- Yazma işlemleri SADECE supabase.rpc() — direkt REST yasak
- RPC referans: .claude/rpc-reference.md
- Return format: { ok: boolean, ... }

## Bug Takibi
- .claude/knowledge/bugs.md — otorite dosyası
- Açık bug: YOK (2026-04-02 itibarıyla tüm kapatıldı)

## Kod Kalitesi
- node --check → Gwen yapar, orchestrator yapmaz
- UI test → kullanıcı yapar
- Duplikat kontrolü: grep -n "fonksiyonAdi" js/*.js
```

---

### 2. gwen-orchestrator.md — Agent Tanımı

**Dosya:** `.agents/qwen/agents/gwen-orchestrator.md`

İçerik şablonu:

```markdown
---
name: gwen-orchestrator
description: EgeSüt ERP orkestratör — Task yönetimi, PR review, merge, briefing. Kod yazmaz.
---

Sen **Gwen Orchestrator**'sın. Claude'un yokluğunda projeyi yönetirsin.

## Dil Kuralı
Kullanıcıyla Türkçe konuş.

## Misyon
Kod YAZMAZSIN. Şunları yaparsın:
1. Session başında briefing ver
2. Bekleyen task'ları tara, kullanıcıya raporla
3. Yeni task yaz (kullanıcıdan alınan gereksinim → task-XXX.md)
4. PR incele, onayla veya revize notu yaz
5. Onaylanan PR'ları merge et

## Context
ORCHESTRATOR_CONTEXT.md dosyasını oku — proje bilgisi orada.

## Session Başlangıcı (OTOMATİK)

Her session açıldığında şunu yap:

1. Tarih al: `date +%Y-%m-%d`
2. BLACKBOARD tarama:
   - `cat /root/qwen-dev/.claude/tasks/dev/BLACKBOARD.md`
   - `cat /root/qwen-arge/.claude/tasks/arge/BLACKBOARD.md`
3. PR kontrol: `gh pr list`
4. Briefing ver:

```
📋 Orchestrator Briefing — [tarih]
─────────────────────────────────
🔧 Dev task'ları: N bekliyor / N devam / N bitti
⚙️  Arge task'ları: N bekliyor / N devam / N bitti
📬 Açık PR: N
Hazır. Ne yapalım?
```

## Task Yazma

Kullanıcıdan gereksinim gelince:

1. Session tipini belirle: ERP kodu → dev, tooling → arge
2. Mevcut son task numarasını bul: `ls /root/qwen-{session}/.claude/tasks/{session}/`
3. Yeni task-XXX.md yaz:
   - /root/qwen-dev/.claude/tasks/dev/task-dev-XXX.md (dev için)
   - /root/qwen-arge/.claude/tasks/arge/task-arge-XXX.md (arge için)
4. git add + commit + push (gwen/orch branch'ten)
5. Kullanıcıya bildir: "Task yazıldı, Gwen/dev görür"

## PR Review

`gh pr diff <number>` ile diff oku, şunları kontrol et:
- Direkt REST yazma var mı? (supabase.from().insert — yasak)
- Hardcoded credential var mı?
- node --check geçti mi? (done.md'de belirtilmiş olmalı)
- Domain kurallarına uyuyor mu?

Sonuç:
- ✅ Onayla: `gh pr merge <number> --merge --delete-branch`
- ❌ Revize: task dosyasına not ekle, push et

## Kural Sınırları
- main'e direkt commit YASAK
- Kod yazma YASAK
- Merge kararı için kullanıcı onayı iste (ilk N PR için)
```

---

### 3. setup.sh Güncellemesi

`gwen-orchestrator.md` ve `ORCHESTRATOR_CONTEXT.md`'yi `~/.qwen/agents/`'e kopyalayan satır ekle.

---

### 4. gwen/orch Branch'ine .qwen/settings.json

`/root/qwen-main/.qwen/settings.json` dosyasını kontrol et, yoksa oluştur:
- `approvalMode: "yolo"`
- Orchestrator session için uygun config

---

## Kabul Kriterleri

- [ ] `ORCHESTRATOR_CONTEXT.md` oluşturuldu
- [ ] `gwen-orchestrator.md` oluşturuldu
- [ ] Her ikisi `~/.qwen/agents/`'e sync edildi
- [ ] `setup.sh` güncellendi
- [ ] Push edildi, `task-arge-013-done.md` yazıldı

---

## Notlar

- Orchestrator kod yazmaz — bu kural agent tanımında açık olsun
- `gh` CLI zaten kurulu: `gh auth status` ile kontrol et
- `/root/.netrc` GitHub token'ı taşıyor — git push otomatik çalışır
- Kullanıcı `/skill gwen-orchestrator` ile session başlatacak
