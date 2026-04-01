# Task-arge-006: Repo Temizliği — Root Dosyaları .agents/'a Taşı

**Durum:** bekliyor
**Branch:** gwen/arge
**Session:** arge

---

## Açıklama

Merge sonrası repo kökünde dağınık Gwen dosyaları var. Bunları `.agents/` altına taşı, kurulum için tek nokta olsun. Yeni cihazda `git clone` + `.agents/setup.sh` yeterli olacak.

---

## 1. Taşınacak Dosyalar

```bash
git mv QUICK_START.md .agents/QUICK_START.md
git mv SESSION_STABILITY.md .agents/SESSION_STABILITY.md
git mv "FULLSTACK_AGENT ihtiyaclar.md" ".agents/FULLSTACK_AGENT_ihtiyaclar.md"
git mv gwen-self-improvement-wrapper.sh .agents/gwen-self-improvement-wrapper.sh
```

`QWEN.md` root'ta kalabilir (Qwen Code otomatik okur) — taşıma.

---

## 2. .agents/setup.sh güncelle

Mevcut `setup.sh`'e şunları ekle/güncelle:

```bash
#!/bin/bash
# EgeSüt ERP — Yeni Cihaz Kurulumu
# Kullanım: bash .agents/setup.sh

echo "=== EgeSüt ERP Agent Kurulumu ==="

# 1. Qwen agents → global config
mkdir -p /root/.qwen/agents /root/.qwen/skills
cp .agents/qwen/agents/*.md /root/.qwen/agents/
cp -r .agents/qwen/skills/* /root/.qwen/skills/

# 2. Gwen wrapper script
cp .agents/gwen-self-improvement-wrapper.sh /root/egesut-erp1/
chmod +x /root/egesut-erp1/gwen-self-improvement-wrapper.sh

# 3. Git hooks (Gwen worktree)
# Not: hooks repo'da yok, manuel kurulumu gerekiyor
echo "⚠️  Git hooks için .claude/HOOK_SYSTEM.md'i oku"

echo "✅ Kurulum tamamlandı"
echo "Başlamak için: QUICK_START.md oku"
```

---

## 3. .agents/README.md güncelle (varsa) veya oluştur

```markdown
# .agents/ — Kurulum Paketi

Yeni cihazda kurulum:
\`\`\`bash
git clone <repo>
cd egesut-erp1-main
bash .agents/setup.sh
\`\`\`

## İçerik
- `setup.sh` — Otomatik kurulum scripti
- `qwen/agents/` — Gwen agent tanımları
- `qwen/skills/` — Gwen skill tanımları
- `QUICK_START.md` — Hızlı başlangıç rehberi
- `SESSION_STABILITY.md` — Session kararlılık kuralları
- `gwen-self-improvement-wrapper.sh` — Arge session wrapper
```

---

## Kabul Kriterleri

- [ ] Root'ta QUICK_START.md, SESSION_STABILITY.md, FULLSTACK_AGENT dosyası yok
- [ ] Bunlar `.agents/` altında var
- [ ] `setup.sh` güncel ve çalışır
- [ ] QWEN.md root'ta kaldı
- [ ] Branch: gwen/arge
- [ ] js/ dosyalarına dokunma
- [ ] Tamamlanınca `task-arge-006-done.md` yaz
