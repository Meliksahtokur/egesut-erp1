# Plan: Agent Organizasyon Restorasyonu
Tarih: 2026-03-27
Durum: bekliyor
Kaynak: 3 plan sentezi (Askeri Hiyerarşi + İsveç Modeli + Analiz Raporu)

---

## Neden Bu Plan?

Mevcut sistem işlevsel ama verimsiz. Tespit edilen sorunlar:

1. **commands/ yok** — `/plan`, `/build`, `/ship` gibi workflow komutları tanımsız. Her seferinde uzun prompt yazmak gerekiyor.
2. **CLAUDE.md monolitik** — her şey tek dosyada, agent'lar ilgisiz kuralları da okuyor.
3. **Feedback formatı standart değil** — agent'lar uzun raporlar yazıyor, Haiku için gereksiz token.
4. **Plugin şişkinliği** — 25 plugin aktif, yarısı kullanılmıyor, her session'da yükleniyor.
5. **Organizasyon validate edilemiyor** — sistemin sağlığını kontrol eden tek kaynak startup-check.sh.

**Kapsamda OLMAYAN şeyler (ayrı plan):**
- JS modülarizasyonu (ui.js → features/) → ürün kodu, ayrı sprint
- SonarCloud issue'ları → ayrı sprint
- State management refactor → ayrı sprint

---

## Mimari Hedef

```
.claude/
├── agents/          ← Mevcut (15 agent, korunuyor)
├── commands/        ← YENİ: slash komut workflow'ları
│   ├── plan.md      → /plan
│   ├── build.md     → /build
│   ├── review.md    → /review
│   └── ship.md      → /ship
├── rules/           ← YENİ: CLAUDE.md'den ayrıştırılmış kurallar
│   ├── 01-agent-hierarchy.md   → agent hiyerarşi + delegation
│   ├── 02-database.md          → Supabase kuralları
│   └── 03-frontend.md          → JS/PWA kuralları
├── knowledge/       ← Mevcut
├── feedback/        ← Mevcut
├── memory/          ← Mevcut
├── scripts/         ← Mevcut
└── arch-decisions/  ← Mevcut

CLAUDE.md → sadece kimlik + session prosedürü (max 80 satır)
```

---

## Uygulama Adımları

### FAZ 1 — commands/ dizini (En Yüksek Değer)

**1.1 `/plan` komutu** → `.claude/commands/plan.md`
- Tetiklenme: kullanıcı "plan yap", "nasıl yapacağız", "/plan" dediğinde
- Akış: erp-planner spawn → erp-architect (gerekirse) → plan dosyası yaz → kullanıcıya sun
- Çıktı: `.claude/plans/YYYY-MM-DD-[konu].md`

**1.2 `/build` komutu** → `.claude/commands/build.md`
- Tetiklenme: "/build", "uygula", "yap" + mevcut plan dosyası varken
- Akış: planı oku → erp-architect contract → frontend-dev + db-agent paralel → qa → git
- Ön koşul: plan dosyası var olmalı

**1.3 `/review` komutu** → `.claude/commands/review.md`
- Tetiklenme: "/review", "incele", "kontrol et"
- Akış: erp-explorer kod okur → erp-qa syntax → erp-debug anti-pattern tarar → rapor

**1.4 `/ship` komutu** → `.claude/commands/ship.md`
- Tetiklenme: "/ship", "gönder", "commit-push"
- Akış: erp-qa son kontrol → erp-git-agent commit + push → rapor
- Ön koşul: qa onayı

---

### FAZ 2 — rules/ dizini (CLAUDE.md parçalanması)

**2.1 Mevcut CLAUDE.md analizi**
- "Sen Kimsin" bölümü → CLAUDE.md'de kalır
- "Codebase Map" → `rules/03-frontend.md`'e taşınır
- "Data Access Pattern" → `rules/02-database.md`'e taşınır
- "Project Conventions / Stack" → `rules/03-frontend.md`'e taşınır
- "Agent Hierarchy" → `rules/01-agent-hierarchy.md`'e taşınır
- Hedef: CLAUDE.md max 80 satır

**2.2 rules/ dosyaları otomatik yükleme**
Claude Code, `.claude/` altındaki dosyaları otomatik yüklemez.
Çözüm: CLAUDE.md'ye `@include` referansları ekle:
```
Kurallar için bak: .claude/rules/ (01-agent-hierarchy, 02-database, 03-frontend)
```

---

### FAZ 3 — Feedback Format Standardizasyonu

Tüm Haiku agent'lara minimal feedback formatı:

```
Başarılıysa:   "TAMAMLANDI: [dosya/işlem]"
Başarısızsa:   "ESCALATION: [hata] — [beklenen talimat]"
Sorunsuzsa:    feedback dosyasına YAZMA
```

Güncellenecek agent'lar: erp-explorer, erp-frontend-dev, erp-db-agent, erp-qa-agent, erp-git-agent, dream-reader, dream-writer

---

### FAZ 4 — Plugin Temizliği

Mevcut: 25 aktif plugin
Hedef: Gerçekten kullanılan 8-10

**Kesinlikle tutulacaklar:**
- superpowers, hookify, commit-commands, coderabbit
- context7, supabase, github, frontend-design, feature-dev

**Kaldırılacaklar (bu proje için anlamsız):**
- sentry (Sentry yok)
- atlassian (Jira/Confluence yok)
- linear (Linear yok)
- playground
- learning-output-style, explanatory-output-style
- agent-sdk-dev, plugin-dev (plugin geliştirmiyoruz)
- pyright-lsp (Python yok)
- typescript-lsp (TypeScript yok, vanilla JS)
- greptile (paid, kullanılmıyor)

**Dikkat:** settings.local.json gitignore'da → global settings.json'ı düzenle.
Önce mevcut settings.json'ı yedekle.

---

### FAZ 5 — .repomixignore

Repomix ile kod analizi yapılacaksa context filtreleme:

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

**Dahil ETMEYECEKLERİMİZ (diğer planların hataları):**
- `supabase/migrations/` glob → migration'lar kritik, silme riski var
- `file-history/`, `backups/` → bu projede bu dizinler yok

---

### FAZ 6 — Organizasyon Sağlık Kontrolü

`validate-organization.sh` scripti → startup-check.sh'e entegre:

```bash
# Kontrol edilecekler:
- commands/ dizini var mı? (4 dosya)
- rules/ dizini var mı? (3 dosya)
- CLAUDE.md 80 satır altında mı?
- Aktif plugin sayısı 10 altında mı?
```

---

## Uygulama Sırası

```
1. FAZ 1 — commands/ (en değerli, hemen kullanılabilir)
2. FAZ 3 — feedback format (hızlı, tüm haiku güncellemesi)
3. FAZ 2 — rules/ (CLAUDE.md parçalama, dikkatli yap)
4. FAZ 4 — plugin temizliği (settings.json yedekle, sonra kaldır)
5. FAZ 5 — .repomixignore (hızlı)
6. FAZ 6 — validate script (startup-check entegrasyonu)
```

---

## Başarı Kriterleri

| Metrik | Ölçüm |
|---|---|
| commands/ aktif | /plan komutu çalışıyor |
| CLAUDE.md boyutu | < 80 satır |
| Plugin sayısı | ≤ 10 |
| Haiku feedback | "TAMAMLANDI: X" formatında |
| Startup-check | 15 agent + commands + rules kontrolü |

---

## Riskler

| Risk | Önlem |
|---|---|
| CLAUDE.md parçalanması context kaybı | Önce rules/ yaz, sonra CLAUDE.md'yi kısalt |
| Plugin kaldırınca eksik yetenek | Önce disable et, bir oturum test et, sonra kaldır |
| commands/ Claude Code'da yanlış çalışma | Önce 1 komut test et, sonra diğerlerini yaz |

---

## Notlar

**İsveç Modelinin geçersiz fikirleri (uygulanmıyor):**
- `skills/` dizini — Claude Code bu yapıyı tanımıyor
- `tools`, `effort`, `maxTurns` frontmatter — geçersiz alan
- session ayrımı zorunluluğu — pratik değil
- 3 plugin limiti — çok agresif

**Analiz Raporunun hataları:**
- `file-history/`, `backups/` bu projede yok → token israfı değil
- 45K token iddiası — doğrulanamaz, muhtemelen yanlış
- JS modülarizasyonu (ui.js bölme) → ayrı ürün planı, buraya karıştırılmıyor
