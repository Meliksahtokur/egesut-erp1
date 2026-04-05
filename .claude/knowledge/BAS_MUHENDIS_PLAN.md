# Baş Mühendis — Uygulama Planı
> **Tarih:** 2026-04-04  
> **Statü:** GÜNCEL  
> **Bağlam:** Kullanıcı geri bildirimi sonrası düzeltildi  

---

## GÖREV LİSTESİ

### [ ] 0. Agent Spawn Testi ⭐ KRİTİK ÖNKOŞUL
**Dosya:** `.claude/knowledge/AGENT_SPAWNING_RESEARCH.md`

Eğer agent spawn çalışmıyorsa, geri kalan hiçbir şeyin yapılmasına gerek yok.

Test yöntemi:
1. `/agent erp-explorer` — built-in agent çağır
2. veya "erp-explorer agent'ı kullan" de — Agent tool tetiklenmeli
3. MiniMax M2.7 konuşmasında çalışıyorsa → devam et
4. Çalışmıyorsa → model: sonnet fallback veya alternatif yol ara

---

### [x] 1. Antigravity Skills Tam Tarama ✅ (2026-04-04)
**Tüm 7 ilgili skill path tespit edildi:**

| Alan | Antigravity Skill | Path |
|------|------------------|------|
| GitHub Workflow | `git-pr-workflows-git-workflow` | `skills/git-pr-workflows-git-workflow/SKILL.md` |
| Onboarding | `git-pr-workflows-onboard` | `skills/git-pr-workflows-onboard/SKILL.md` |
| Frontend Dev | `frontend-developer` | `skills/frontend-developer/SKILL.md` (React tabanlı, adaptasyon gerekli) |
| GitHub Security | `gha-security-review` | `skills/gha-security-review/SKILL.md` |
| Backend Security | `backend-security-coder` | `skills/backend-security-coder/SKILL.md` |
| API Security | `api-security-best-practices` | `skills/api-security-best-practices/SKILL.md` |
| API Design | `api-design-principles` | `skills/api-design-principles/SKILL.md` |

RAW URL format: `https://raw.githubusercontent.com/sickn33/antigravity-awesome-skills/main/skills/<SKILL>/SKILL.md`

---

### [ ] 2. M27_ARCHITECTURE_PLAN.md Güncelleme
**Dosya:** `.claude/knowledge/M27_ARCHITECTURE_PLAN.md`

Güncellenecek bölümler:
- Agent takımı → 10'dan 13'e çıkacak:
  - + `erp-github-agent` — CI/CD, workflow, secret
  - + `erp-vanilla-js-agent` — Frontend'in Vanilla JS layer'ı
  - + `erp-security-agent` — Güvenlik, RLS, auth
- Skill paketi → 4'ten 7'ye çıkacak:
  - + Antigravity `git-workflow` adaptasyonu
  - + Antigravity `codebase-onboarding` adaptasyonu
  - + Antigravity `security-review` adaptasyonu
- Hook katmanı → security hook ekle
- Rol atama matrisine yeni agent'ları ekle

---

### [ ] 3. AGENTIC_ARCHITECTURE_PRESENTATION.md Güncelleme
**Dosya:** `.claude/knowledge/AGENTIC_ARCHITECTURE_PRESENTATION.md`

Yeni slide'lar:
- SLIDE (yeni) — GitHub Actions Uzmanı: Neden gerekli, ne yapacak
- SLIDE (yeni) — Vanilla JS Özel Adaptasyonu: frontend-patterns'tan nasıl alınacak
- SLIDE (yeni) — Security Review: Antigravity security-review nasıl kullanılacak
- SLIDE (yeni) — API Design Skill: RPC contract tasarımı için

---

### [ ] 4. Yeni Agent Dosyaları Oluştur

| Agent | Dosya | Kaynak |
|-------|-------|--------|
| erp-github-agent | `.claude/agents/erp-github-agent.md` | Antigravity git-workflow adaptasyonu |
| erp-vanilla-js-agent | `.claude/agents/erp-vanilla-js-agent.md` | VoltAgent frontend-dev + Antigravity frontend-patterns |
| erp-security-agent | `.claude/agents/erp-security-agent.md` | Antigravity security-review adaptasyonu |

---

### [ ] 5. Yeni Skill Dosyaları Oluştur

| Skill | Dosya | Kaynak |
|-------|-------|--------|
| erp-git-workflow | `.claude/skills/erp-git-workflow/SKILL.md` | Antigravity git-workflow adaptasyonu |
| erp-onboarding | `.claude/skills/erp-onboarding/SKILL.md` | Antigravity codebase-onboarding adaptasyonu |
| erp-security-check | `.claude/skills/erp-security-check/SKILL.md` | Antigravity security-review adaptasyonu |

---

### [ ] 6. Orchestrator Güncelle
**Dosya:** `.claude/agents/orchestrator.md`

Yeni agent'ları atama matrisine ekle.  
Yeni skill'leri kullanım rehberine ekle.

---

### [ ] 7. Pilot Görev Başlat
Seçenekler:
- A) "GitHub Actions workflow ekleme" → erp-github-agent test
- B) "Security audit" → erp-security-agent test
- C) "Vanilla JS yeni component" → erp-vanilla-js-agent test

---

## BAĞLAM KOPMAMASI İÇİN KURALLAR

### Her Oturum Başında
1. MEMORY.md oku — yeni kural var mı kontrol et
2. BAS_MUHENDIS_PLAN.md oku — hangi görevde kalınmış
3. Plan dosyalarını kontrol et — güncel mi?

### Yeni Kural/Karar Geldiğinde
1. MEMORY.md'ye HEMEN yaz (plan dosyasına DEĞİL)
2. İlgili plan dosyasını güncelle
3. Kullanıcıya doğrula

### Plan Dosyaları Arası Bağlantı
```
AGENTIC_ARCHITECTURE_PRESENTATION.md (sunum)
    ↓ içerik güncellenir
M27_ARCHITECTURE_PLAN.md (tam plan)
    ↓ referans verir
BAS_MUHENDIS_PLAN.md (uygulama takibi)
    ↓ güncellenir
MEMORY.md (gerçek çalışma durumu)
```

---

## PERFORMANS NOTLARI

- Antigravity full tarama → sadece ilk seferde, 30 dk
- Agent adaptasyonu → ~15 dk / agent
- Skill adaptasyonu → ~10 dk / skill
- Plan güncelleme → ~30 dk
- Toplam ek iş: ~3 saat

---

**Son Güncelleme:** 2026-04-04
**Güncellenen:** Task 1 tamamlandı ✅ — Antigravity skill'ler tespit edildi
