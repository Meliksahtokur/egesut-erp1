# Task-arge-015 Tamamlandı: Gwen Orchestrator (Qwen Code için)

**Branch:** gwen/arge
**Tarih:** 2026-04-02
**Tip:** Agent + Context dosyaları

---

## Yapılanlar

### 1. ORCHESTRATOR_CONTEXT.md Oluşturuldu ✅

**Dosya:** `.agents/qwen/agents/ORCHESTRATOR_CONTEXT.md` → `~/.qwen/agents/`

**İçerik:**
- Proje özeti (Vanilla JS + Supabase, offline-first)
- Worktree yapısı (main, gwen/orch, gwen/dev, gwen/arge)
- GitHub komutları (gh pr merge, gh pr list)
- Task sistemi (dev/arge task yolları)
- RPC kuralları (direkt REST yasak)
- Bug takibi (bugs.md — açık bug YOK)
- Session başlangıcı briefing formatı

---

### 2. gwen-orchestrator.md Oluşturuldu ✅

**Dosya:** `.agents/qwen/agents/gwen-orchestrator.md` → `~/.qwen/agents/`

**Rol:** Kod YAZMAZ — yönetir

**Yetenekler:**
1. Session başında briefing ver
2. Bekleyen task'ları tara, raporla
3. Yeni task yaz (kullanıcı gereksinim → task-XXX.md)
4. PR incele, onayla veya revize notu yaz
5. Onaylanan PR'ları merge et

**Session Başlangıcı (otomatik):**
```
📋 Orchestrator Briefing — [tarih]
─────────────────────────────────
🔧 Dev task'ları: N bekliyor / N devam / N bitti
⚙️  Arge task'ları: N bekliyor / N devam / N bitti
📬 Açık PR: N
Hazır. Ne yapalım?
```

**Task Yazma:**
```
1. Session tipi belirle: ERP kodu → dev, tooling → arge
2. Son task numarasını bul: ls .claude/tasks/{session}/
3. task-XXX.md yaz
4. git add + commit + push (gwen/orch)
5. Bildir: "Task yazıldı, Gwen/dev görür"
```

**PR Review:**
```
gh pr diff <number> | grep -n "supabase.from.*insert"
→ Bulunan → ❌ REVIZE: "RPC kullan"
→ Yoksa → ✅ gh pr merge <number> --merge --delete-branch
```

**Kontroller:**
- Direkt REST yazma (yasak)
- Hardcoded credential (yasak)
- node --check (done.md'de belirtilmiş olmalı)
- Domain kuralları (yaş sınırı, state machine)

---

### 3. Setup.sh Güncellendi ✅

**Değişiklik:**
- Agent sayısı 9 → 10
- Yeni agent: gwen-orchestrator

```bash
required_agents=("gwen" "gwen-reviewer" "gwen-architect" "gwen-researcher" "gwen-analyst" "gwen-coder" "gwen-tester" "gwen-telemetry" "gwen-performance" "gwen-orchestrator")
ok "Agents mevcut (10/10): gwen · gwen-reviewer · gwen-architect · gwen-researcher · gwen-analyst · gwen-coder · gwen-tester · gwen-telemetry · gwen-performance · gwen-orchestrator"
```

---

### 4. qwen-main/.qwen/settings.json Kontrol ✅

**Dosya:** `/root/qwen-main/.qwen/settings.json`

**Durum:**
- ✅ `approvalMode: "yolo"` — zaten ayarlanmış
- ✅ Bash izinleri: git add/commit/push, gwen, qwen
- ✅ Read izinleri: ~/.qwen/**, ~/.claude/**
- ✅ MCP: context7 aktif

**Ekstra config gerekmez.**

---

## Agent Envanteri (TAM)

| # | Agent | Rol | Session |
|---|-------|-----|---------|
| 1 | gwen | OPERATOR — Takım lideri | dev/arge |
| 2 | gwen-researcher | Context yükleme | dev/arge |
| 3 | gwen-analyst | Kod analizi | dev/arge |
| 4 | gwen-coder | Kod yazma (RPC) | dev/arge |
| 5 | gwen-tester | Test (syntax+security) | dev/arge |
| 6 | gwen-reviewer | Push review | dev/arge |
| 7 | gwen-architect | Sistem geliştirme | arge |
| 8 | gwen-telemetry | Browser↔DB validation | dev/arge |
| 9 | gwen-performance | Performance optimization | dev/arge |
| 10 | **gwen-orchestrator** | **Task yönetimi, PR review, merge** | **orch** |

**Toplam:** 10 agent (9 temel + 1 orchestrator)

---

## Orchestrator Workflow

```
┌─────────────────────────────────────────────────────────┐
│  Gwen Orchestrator (gwen/orch session)                  │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  1. SESSION BAŞLANGICI                                  │
│     ├── date +%Y-%m-%d                                  │
│     ├── BLACKBOARD tarama (dev + arge)                 │
│     ├── gh pr list                                      │
│     └── Briefing ver                                    │
│                                                         │
│  2. TASK YAZMA                                          │
│     ├── Session tipi: ERP → dev, tooling → arge        │
│     ├── Son task no: ls .claude/tasks/{session}/       │
│     ├── task-XXX.md yaz                                 │
│     ├── git add + commit + push                         │
│     └── Bildir: "Task yazıldı, Gwen/X görür"           │
│                                                         │
│  3. PR REVIEW                                           │
│     ├── gh pr diff <number>                             │
│     ├── Kontrol: REST, credential, node-check, domain  │
│     ├── ✅ Onayla: gh pr merge --merge --delete-branch │
│     └── ❌ Revize: task dosyasına not ekle             │
│                                                         │
│  4. MERGE                                               │
│     └── gh pr merge <number> --merge --delete-branch   │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

---

## Session Başlatma

**Kullanıcı:**
```bash
# gwen/orch session başlat
cd /root/qwen-main
qwen
# /skill gwen-orchestrator
```

**Gwen Orchestrator:**
```
📋 Orchestrator Briefing — 2026-04-02
─────────────────────────────────
🔧 Dev task'ları: 2 bekliyor / 1 devam / 5 bitti
⚙️  Arge task'ları: 0 bekliyor / 0 devam / 14 bitti
📬 Açık PR: 0
Hazır. Ne yapalım?
```

---

## Kabul Kriterleri

- [x] `ORCHESTRATOR_CONTEXT.md` oluşturuldu
- [x] `gwen-orchestrator.md` oluşturuldu
- [x] Her ikisi `~/.qwen/agents/`'e sync edildi
- [x] `setup.sh` güncellendi (10 agent)
- [x] `qwen-main/.qwen/settings.json` kontrol edildi (yolo mode)
- [x] Push edildi, `task-arge-015-done.md` yazıldı

---

## Notlar

- ✅ Orchestrator kod yazmaz — bu kural agent tanımında açık
- ✅ `gh` CLI zaten kurulu
- ✅ `/root/.netrc` GitHub token'ı taşıyor
- ✅ Kullanıcı `/skill gwen-orchestrator` ile session başlatacak

---

**Task-arge-015 tamamlandı.** Gwen Orchestrator hazır! 🎯
