# Faz 0 — Dış Skill Kurulum Envanteri

**Tarih:** 2026-06-10
**Oturum:** Faz 0 başlangıç (yol haritası 07)
**Yürütücü:** Goose (kullanıcı direkt talimatı)

---

## 🎯 Amaç

`.claude/eksikler/07-onerilen-yol-haritasi.md` belgesindeki Faz 0'da tanımlanan
4 dış skill'i kurmak ve kurulumu belgelemek.

**Onay gerektirmez** — sadece `npx skills add` + envanter yazımı.

---

## 📦 Kurulan Skill'ler

| # | Skill Adı | Kaynak Repo | Boyut | Kurulum Yolu |
|---|-----------|-------------|-------|--------------|
| 0.1 | `frontend-design` | `anthropics/skills@frontend-design` | 522.6K ⭐ | `~/.agents/skills/frontend-design` |
| 0.2 | `accessibility` | `addyosmani/web-quality-skills@accessibility` | 26.7K | `~/.agents/skills/accessibility` |
| 0.3 | `ui-ux-pro-max` (ckm seti) | `nextlevelbuilder/ui-ux-pro-max-skill` | 26.9K | `~/.agents/skills/ckm-*` (6 dosya) |
| 0.4 | `impeccable` | `pbakaus/impeccable@impeccable` | 53.7K | `~/.agents/skills/impeccable` |

### Komutlar (sırayla)

```bash
# 0.1
npx skills add anthropics/skills@frontend-design -y -g

# 0.2
npx skills add addyosmani/web-quality-skills@accessibility -y -g

# 0.3
npx skills add nextlevelbuilder/ui-ux-pro-max-skill -y -g

# 0.4
npx skills add pbakaus/impeccable@impeccable -y -g
```

---

## ✅ Doğrulama

```bash
$ ls ~/.agents/skills/ | grep -E "frontend-design|accessibility|impeccable|ckm"
accessibility
ckm-banner-design
ckm-brand
ckm-design
ckm-design-system
ckm-slides
ckm-ui-styling
frontend-design
impeccable
```

Hedef 4 skill → toplam 9 klasör (ui-ux-pro-max 6 alt-skille genişledi).

---

## 🛠 Kurulum Detayları

### Symlink Yapısı (Goose)

`npx skills add` universal klasöre (`~/.agents/skills/`) kurar, ardından
desteklenen agent'lara symlink verir. Goose için symlink başarıyla oluştu:

```
symlinked: Claude Code, OpenClaw, Goose, Hermes Agent, Pi +1 more
```

### Bilinen Sorun

```
✗ frontend-design/accessibility/impeccable → PromptScript:
  PromptScript does not support global skill installation
```

Bu hata **kabul edilebilir** — PromptScript bizim agent stack'imizde yok,
Goose için kritik değil. Asıl kurulum (universal + Goose symlink) başarılı.

---

## 🔗 Kullanım

Kurulan skill'ler otomatik olarak Goose session'larında kullanılabilir. Faz A'da
ihtiyaç olunca:

```python
load_skill(name="frontend-design")       # UI tasarım review
load_skill(name="accessibility")         # a11y kontrol
load_skill(name="impeccable")            # Frontend best practice
load_skill(name="ckm-design-system")     # Tasarım sistemi kurulumu
```

---

## 🔁 Sonraki Adım

**Faz A — Hızlı Kazanımlar** (1-2 hafta, 4-5 oturum)

İlk iş: **A.1** → `utils/` dizini oluştur (UI/UX refactor için temel).

Yol haritası: `.claude/eksikler/07-onerilen-yol-haritasi.md`
