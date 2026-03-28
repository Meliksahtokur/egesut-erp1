# Plan: Agent Organizasyon Restorasyonu
Tarih: 2026-03-27
Durum: bekliyor
Kaynak: 3 plan sentezi + askeri hiyerarşi prensipleri

---

## Temel Felsefe: Askeri Düzen

**Düşünme yetkisi → sadece Sonnet katmanda**
**Uygulama yetkisi → sadece Haiku katmanda**
**Haiku'nun skill'i = "seçenek bilinci" = düşünme başlar = loop = token israfı**

```
SONNET (beyin)   → planlar, karar verir, net emir yazar, denetler
HAIKU  (eller)   → emri alır, uygular, TAMAMLANDI veya ESCALATION der, çıkar
```

Haiku'ya skill vermiyoruz. Komutanlar olabildiğince spesifik emir yazar — saibaye yer yok.

---

## Mevcut Sorunlar

1. **commands/ yok** — her seferinde uzun prompt, workflow belirsiz
2. **CLAUDE.md monolitik** — herkes her şeyi okuyor, ilgisiz context
3. **Haiku'da skill var** — loop riski, gereksiz düşünme
4. **DB ve Frontend komutanı yok** — erp-architect tek başına her iki alanı planlıyor
5. **25 plugin aktif** — yarısı bu projede hiç kullanılmıyor
6. **Feedback formatı dağınık** — haiku'lar uzun raporlar yazıyor

---

## Hedef Mimari

```
SONNET KATMANI (beyin):
  orchestrator       → CEO, koordinasyon
  erp-planner        → strateji, brainstorming
  erp-architect      → genel mimari, cross-module kararlar
  erp-db-commander   → YENİ: DB uzman komutanı
  erp-frontend-commander → YENİ: Frontend uzman komutanı
  erp-debug-agent    → bug analizi, koordinasyon
  arge-analyst       → ArGe koordinasyonu
  dream-director     → sistem analizi

HAIKU KATMANI (eller) — SKILL YOK:
  erp-explorer           → okur, raporlar
  erp-db-implementer     → SQL/migration uygular (db-agent → rename)
  erp-frontend-implementer → JS uygular (frontend-dev → rename)
  erp-qa-agent           → test çalıştırır
  erp-git-agent          → git komutları
  arge-local-reader      → dosya okur
  arge-web-researcher    → web arar
  dream-reader           → feedback okur
  dream-writer           → agent dosyaları düzenler
```

---

## Uygulama Fazları

### FAZ 1 — Haiku Skill Temizliği (Hızlı, Kritik)

Tüm Haiku agent'lardan skills bölümü kaldırılır.
**İstisna:** `erp-git-agent` → `commit-commands:commit-push-pr` kalır (bu skill git workflow'unu yönlendiriyor, düşünme değil prosedür).

Güncellenecek agent'lar:
- erp-explorer: `dispatching-parallel-agents`, `systematic-debugging` → KALDIR
- erp-frontend-dev: `verification-before-completion` → KALDIR
- erp-db-agent: `verification-before-completion` → KALDIR
- erp-qa-agent: `verification-before-completion` → KALDIR
- dream-reader: skills zaten yok ✓
- dream-writer: `verification-before-completion` → KALDIR
- arge-local-reader: skills yok ✓
- arge-web-researcher: skills yok ✓

---

### FAZ 2 — Haiku Feedback Format Standardizasyonu

Tüm Haiku agent talimatlarına eklenecek:

```
## Görev Tamamlama Kuralı (DEĞİŞTİRİLEMEZ)
- Başarıyla tamamladıysan:   TAMAMLANDI: [ne yapıldı, dosya/işlem]
- Engel varsa:               ESCALATION: [engel] — [hangi karara ihtiyaç var]
- Sorunsuz görevde:          feedback dosyasına HİÇBİR ŞEY YAZMA
- Uzun rapor YAZMA — tek satır yeterli
```

---

### FAZ 3 — DB ve Frontend Komutan Katmanı (YENİ AGENT'LAR)

**3.1 erp-db-commander (Sonnet)**
- Mevcut erp-architect genel mimari yapar; DB-specific Sonnet uzman eksik
- erp-db-commander: migration tasarımı, RPC contract, state machine kararları
- Sadece DB düşünür, SQL yazmaz — erp-db-implementer'a emir verir
- domain-rules.md bölüm 13'ü ezberler

**3.2 erp-frontend-commander (Sonnet)**
- ui.js 2804 satır — genel architect bunu tam bilemez
- erp-frontend-commander: ui-map.md'yi ezberler, hangi fonksiyon nerede bilir
- Duplikat kontrolünü kendisi yapar, implementer'a net satır aralığı verir
- JS yazmaz — erp-frontend-implementer'a atom emir verir

**3.3 Rename:**
- `erp-db-agent.md` → `erp-db-implementer.md` (haiku, sadece uygular)
- `erp-frontend-dev.md` → `erp-frontend-implementer.md` (haiku, sadece uygular)

**Komutan emir formatı (zorunlu):**
```
DOSYA: [path]
SATIR ARALIĞI: [X-Y]
DEĞİŞİKLİK: [tam olarak ne yapılacak, yorum yok]
BAĞLAM: [neden, varsa ilgili RPC/fonksiyon adı]
```

---

### FAZ 4 — commands/ Dizini

**4.1 `/plan`** → erp-planner spawn → erp-architect → `.claude/plans/` dosyası
**4.2 `/build`** → plan oku → komutanlar → implementer'lar → qa → git
**4.3 `/review`** → erp-explorer + erp-debug-agent → rapor
**4.4 `/ship`** → erp-qa son kontrol → erp-git-agent commit+push

---

### FAZ 5 — rules/ Dizini (CLAUDE.md Parçalanması)

CLAUDE.md'den taşınacaklar:
- Codebase Map + Data Access Pattern → `rules/03-frontend.md`
- Supabase/RPC kuralları → `rules/02-database.md`
- Agent hiyerarşi tablosu → `rules/01-agent-hierarchy.md`

CLAUDE.md'de kalacaklar:
- Sen kimsin (kimlik)
- Session başlangıç prosedürü
- `rules/` dizinine referans

Hedef: CLAUDE.md max 80 satır.

---

### FAZ 6 — Plugin Temizliği

**Kalacaklar (9):**
```
superpowers, hookify, commit-commands, coderabbit,
context7, supabase, github, frontend-design, feature-dev
```

**Kaldırılacaklar (16):**
```
sentry            → Sentry kullanmıyoruz
atlassian         → Jira/Confluence yok
linear            → Linear yok
playground        → gereksiz
learning-output-style    → gereksiz
explanatory-output-style → gereksiz
agent-sdk-dev     → agent SDK geliştirmiyoruz
plugin-dev        → plugin geliştirmiyoruz
pyright-lsp       → Python yok
typescript-lsp    → TypeScript yok (vanilla JS)
greptile          → paid, kullanılmıyor
pr-review-toolkit → coderabbit yeterli
claude-code-setup → kurulum bitti
claude-md-management → manuel yönetiyoruz
code-review       → coderabbit var
code-simplifier   → gereksiz
```

**İşlem:** `~/.claude/settings.json` yedekle → false yap → test → sil.

---

### FAZ 7 — .repomixignore

```
node_modules/
.git/
*.log
test-results/
playwright-report/
docs/superpowers/
.claude/feedback/
.claude/memory/
```

**Kural:** migration glob YAZMA — kritik dosyalar silinir.

---

### FAZ 8 — Startup-Check Güncellemesi

- Yeni agent sayısı: 17 (2 komutan + 2 rename)
- commands/ dizini kontrolü ekle
- rules/ dizini kontrolü ekle
- Plugin sayısı kontrolü ekle (> 10 ise uyarı)

---

## Uygulama Sırası

```
1. FAZ 1 — Haiku skill temizliği     (hızlı, kritik)
2. FAZ 2 — Feedback format           (hızlı)
3. FAZ 3 — DB/Frontend komutanları   (2 yeni agent + 2 rename)
4. FAZ 4 — commands/ dizini          (4 dosya)
5. FAZ 5 — rules/ + CLAUDE.md        (dikkatli yap)
6. FAZ 6 — Plugin temizliği          (yedekle, test et)
7. FAZ 7 — .repomixignore            (hızlı)
8. FAZ 8 — Startup-check             (son)
```

---

## Başarı Kriterleri

| Metrik | Ölçüm |
|---|---|
| Haiku skill sayısı | 0 (git hariç) |
| Haiku feedback | tek satır: TAMAMLANDI / ESCALATION |
| DB/Frontend komutanı | aktif ve emir formatına uyuyor |
| commands/ | /plan çalışıyor |
| CLAUDE.md | < 80 satır |
| Plugin sayısı | ≤ 9 |

---

## Riskler

| Risk | Önlem |
|---|---|
| Rename sonrası orchestrator eski adı çağırır | Orchestrator agent tablosunu güncelle |
| Plugin kaldırınca eksik yetenek | Önce false yap, bir oturum test et |
| CLAUDE.md parçalanması context kaybı | Önce rules/ yaz, sonra CLAUDE.md kısalt |
| Komutan emirleri hâlâ belirsizse | Komutan talimatına "emir formatı zorunlu" ekle |

---

## Geçersiz Kalan Fikirler (Uygulanmıyor)

- `skills/` dizini — Claude Code tanımıyor
- `tools`, `effort`, `maxTurns` frontmatter — geçersiz alan
- Git/QA Sonnet komutanı — mekanik işler, haiku yeterli
- Session ayrımı teknik zorunluluk — pratik değil
- JS modülarizasyonu — ayrı ürün planı
