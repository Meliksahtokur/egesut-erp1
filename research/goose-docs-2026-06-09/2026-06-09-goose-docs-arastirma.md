# goose-docs.ai Araştırması — Skills & Extensions Envanteri

**Tarih:** 2026-06-09  
**Yazar:** Goose (Pi-new talebiyle)  
**Konum:** `/root/egesut-erp1/research/goose-docs-2026-06-09/`  
**Amaç:** https://goose-docs.ai/skills/ ve https://goose-docs.ai/extensions/ sayfalarını tarayıp, EgeSüt ERP'nin ihtiyacına uygun skill/extension kombinasyonlarını tespit etmek, `.claude/eksikler/` ile çapraz analiz yapmak.

---

## 1) Kaynak Haritası (indirilen dosyalar)

| Dosya | İçerik | Boyut |
|---|---|---|
| `llms.txt` | Goose kısa özet (LLM'ler için) | 2KB |
| `using-skills.html` | Skill sistemi dokümantasyonu | 86KB |
| `mcp-servers.html` | 70+ extension listesi ve özetleri | 95KB |
| `tut-playwright-skill.html` | Playwright CLI skill tutorial | 59KB |
| `tut-subagents.html` | Subagent orkestrasyon tutorial | 89KB |
| `tut-ralph-loop.html` | Ralph Loop (otonom iteratif geliştirme) | 107KB |
| `tut-subrecipes-in-parallel.html` | Paralel subrecipe çalıştırma | 66KB |
| `tut-headless-goose.html` | Headless mode (CI/CD) | 74KB |
| `tut-recipes-tutorial.html` | Recipe formatı detaylı | 59KB |
| `tut-mlflow.html` | MLflow observability | 35KB |
| `tut-langfuse.html` | Langfuse observability | 30KB |
| `tut-cicd.html` | CI/CD entegrasyonu | 71KB |
| `tut-custom-extensions.html` | Custom MCP extension yazma | 87KB |
| `tut-building-mcp-apps.html` | MCP Apps (UI rendering) | 307KB |
| `sitemap.xml` | 326 URL | — |

---

## 2) KRİTİK TESPİT — Mimari Değişiklik

### ⚠️ Skills Extension → **Summon Extension** Geçişi

> "This functionality requires the built-in **Summon extension**, available in **v1.25.0+**."

`Skills` extension'ı **deprecated**, yerini **Summon** aldı. Summon hem skill yükler hem subagent delege eder. EgeSüt'te:

- `extension_manager` ve `summon` aktif olmalı (zaten mevcut)
- `load_skill` artık Summon üzerinden çalışıyor — bizim orchestrator'ın bunu bilmesi gerek

**Aksiyon:** `tools-bank` MCP'nin `goose_start`/`goose_status`/`goose_stop` tool'ları zaten Summon-compatible. `egesut-erp-architecture` skill'i Summon farkındalığına güncellenmeli.

### 📁 Skill Lokasyon Standartları

| Yol | Kapsam |
|---|---|
| `~/.agents/skills/` (yeni standart) | Global |
| `.agents/skills/` (yeni standart) | Proje |
| `~/.agents/plugins/<plugin>/` | Plugin skill'leri |
| `.claude/skills/` (eski) | **Backward compat** — bizde kullanılan bu |
| `.goose/skills/` (eski) | **Backward compat** |

**EgeSüt mevcut:** `/root/egesut-erp1/.claude/skills/` → eski format, çalışıyor. Yeni standart `~/.agents/skills/`'e taşımak **opsiyonel**, gerekmez.

---

## 3) EgeSüt'te Yüklü Skill Seti (107 skill) — Kategorize

| Kategori | Skill Sayısı | Örnekler |
|---|---|---|
| **Google Workspace (gws-*)** | 45 | calendar, gmail, drive, docs, sheets, chat, meet, modelarmor |
| **Workspace Recipes (recipe-*)** | 33 | backup-sheet-as-csv, batch-invite-to-event, create-meet-space... |
| **Persona (persona-*)** | 9 | exec-assistant, project-manager, customer-support... |
| **GitNexus** | 7 | cli, debugging, exploring, guide, impact-analysis, pr-review, refactoring |
| **Mimari (egesut-erp-*)** | 2 | egesut-erp, egesut-erp-architecture |
| **Tools-Bank** | 2 | tools-bank, tools-bank-mcp |
| **Orkestrasyon** | 4 | kaz-cobani, goused, orchestrator-master, executing-plans |
| **Geliştirme** | 3 | feature-dev, session-update, memory-update |
| **Araştırma** | 2 | deerflow, duckduckgo-search, notebooklm, graphify, blackbox |
| **Diğer** | 5 | find-skills, todo, tom, docker-management, sonnet |

**Dağılım:** 45/107 (%42) Google Workspace, 33/107 (%31) Workspace Recipes → toplam %73 Workspace odaklı. EgeSüt-asıl işi yapan (egesut + gitnexus + tools-bank + orchestration) sadece ~18 skill.

---

## 4) Goose-docs.ai Extension Listesi (65 adet) — EgeSüt Kesişimi

### 🟢 ZATEN KULLANIYORUZ (veya eşdeğeri var)

| Goose Extension | EgeSüt'teki karşılığı | Durum |
|---|---|---|
| **Developer** (shell+edit+analyze) | `developer` extension aktif | ✅ |
| **Memory** | `memory_search`/`memory_add` tools-bank MCP | ✅ |
| **Todo** | `todo__todo_write` tool aktif | ✅ |
| **Chat Recall** | `chatrecall__chatrecall` extension aktif | ✅ |
| **Extension Manager** | `extensionmanager__*` aktif | ✅ |
| **Summon** (skill + subagent) | `tools-bank__goose_start` (ACP), `load_skill` | ✅ |
| **Repomix** | `repomix__*` extension aktif | ✅ |
| **Context7** (lib docs) | `tools-bank__context7_*` | ✅ |
| **GitHub** (PR/issue) | `tools-bank__github_code_search` (read-only) | ⚠️ Kısmi |
| **Supabase** | `tools-bank__supabase_*` (11 tool) | ✅ |
| **Knowledge Graph Memory** | `tools-bank__knowledge_graph_query` | ✅ |
| **Playwright** (MCP) | GitHub Actions'da CI | ✅ (CI-only, local yasak) |
| **Goose Docs** (self-doc) | `tools-bank__goose_*` (search/add/delete) | ✅ |
| **Sonar/Qube** (code quality) | `tools-bank__sonar_*` (9 tool) | ✅ |
| **Memory/Recall** | zaten yukarıda | ✅ |
| **Tutorial** | Skill mimarisi | ✅ |

### 🟡 YARARLI OLABİLİR (değerlendirilecek)

| Goose Extension | Ne işe yarar | EgeSüt'te potansiyel kullanım | Öncelik |
|---|---|---|---|
| **Auto Visualiser** | Veri otomatik görselleştirme | Dashboard widget'ları (süt verimi, reprodüksiyon chart) | 🟡 Orta |
| **Code Mode** | JS ile birden fazla MCP tool'u orkestre et | tools-bank'ın yaptığı iş — duplicate | ⛔ Düşük |
| **Container Use** | Container-Use MCP ile izole env | Test ortamı izolasyonu (PRoot alternatifi?) | 🟡 Orta |
| **Cognee** | Knowledge graph (RAG, hipotez çıkarma) | `.claude/domain-rules.md` + kural motoru için RAG | 🟡 Orta |
| **Cognee (zaten yukarıda)** | — | — | — |
| **DataHub** | DataHub metadata catalog | Gerek yok (bizde Supabase var) | ⛔ Düşük |
| **Exa Search** | Semantic web search | Deerflow alternatifi, daha kaliteli | 🟡 Orta |
| **Figma Dev Mode** | Figma tasarımlarını oku | **EgeSüt UI review için paha biçilmez** (Eksik #3) | 🔴 Yüksek |
| **Firecrawl** | Web scraping (LLM-ready) | deerflow/research veri toplama | 🟡 Orta |
| **GitMCP** | Git remote → MCP (herhangi bir repo) | Local GitNexus'a ek olarak public repo inceleme | 🟡 Orta |
| **JetBrains** | IDE entegrasyonu | Geliştirici deneyimi — UX, bizim için skip | ⛔ |
| **MongoDB** | Mongo sorgu | Kullanmıyoruz | ⛔ |
| **Netlify** | Deploy | GitHub Pages kullanıyoruz | ⛔ |
| **Neon** | Serverless Postgres | Supabase yeterli | ⛔ |
| **Rendex** | HTML→PDF/screenshot | UI snapshot, regression | 🟡 Orta |
| **Tavily** | Web search (LLM-optimized) | deerflow alternatifi | 🟡 Orta |
| **Vercel** | Deploy | GitHub Pages kullanıyoruz | ⛔ |

### 🔴 EKSİK / DEĞERLENDİRİLECEK (proje-özgü ihtiyaç)

| İhtiyaç | Goose Extension'ı | EgeSüt'te karşılığı | Efor |
|---|---|---|---|
| **UI/UX review** | Figma Dev Mode (tasarım kaynağı) + axe-core (a11y) + Rendex (screenshot) | ❌ Yok | 1-2 oturum |
| **Visual regression** | Playwright CLI (skill) + Rendex (screenshot) | ❌ Yok (sadece Playwright MCP var, PRoot'ta yasak) | 1 oturum |
| **Self-improving loop** | **Ralph Loop** (otonom iteratif + cross-model review) | ❌ Yok | 1 oturum (recipe) |
| **Subagent orkestrasyon** | **Subagents tutorial** (Planner/PM/Architect/Dev/QA/Writer) | ⚠️ Telsiz mimarisi var ama pattern eksik | 1 oturum (skill) |
| **CI/CD'de AI** | GitHub Actions + headless goose | ❌ Yok (PR workflow'da AI review yok) | 1 oturum (workflow) |
| **Observability** | Langfuse / MLflow (OTLP) | ❌ Yok (tools-bank memory var ama trace yok) | 1 oturum (altyapı) |

---

## 5) Çapraz Analiz — `.claude/eksikler/` × goose-docs.ai

### Eksik #1: Component kütüphanesi yok

| EgeSüt mevcut | Goose-docs önerisi | Kesişim |
|---|---|---|
| Modal/Toast/Autocomplete 4 kopya | — | EgeSüt-spesifik sorun, goose-docs çözüm sunmuyor |
| **Çözüm:** Vanilla JS component pattern + `js/components/*.js` | — | EgeSüt mimarisine uygun (no-bundler CDN) |

**Sonuç:** Goose-docs.ai bu eksik için doğrudan recipe/skill sunmuyor. Manuel mimari karar gerekli.

### Eksik #2: CSS + design tokens yok

| EgeSüt mevcut | Goose-docs önerisi | Kesişim |
|---|---|---|
| Tüm CSS `index.html` inline | — | EgeSüt-spesifik |
| **Çözüm:** `css/tokens.css` (CSS variables) + `js/design-tokens.js` | **Figma Dev Mode extension** (renk/spacing kaynağı) | İkisini birleştir: design tokens'ı Figma'dan sync et |

### Eksik #3: UI/UX review skill'i yok 🔴

| EgeSüt mevcut | Goose-docs önerisi | Kesişim |
|---|---|---|
| Spec-writer/reviewer kod odaklı | **Figma Dev Mode** extension (tasarım okuma) | ✅ Doğrudan çözüm |
| | **axe-core** (a11y, 3rd-party CDN) | ✅ Eklenecek |
| | **Rendex** extension (screenshot diff) | ✅ Görsel regresyon |
| | **playwright-cli skill** (otomatik UI test) | ✅ Skill olarak |

**Sonuç:** 4 araç birleşince tam kapsamlı bir `ui-review` skill'i yazılabilir. **1 oturum, yüksek değer.**

### Eksik #4: utils/ dizini yok

| EgeSüt mevcut | Goose-docs önerisi | Kesişim |
|---|---|---|
| g()/v()/cl() global | **Code Mode extension** (JS ile multi-tool orkestrasyon) | ⛔ Alakasız — refactor işi, tools-bank'ın yaptığı |

**Sonuç:** Goose-docs çözüm sunmuyor, vanilla refactor.

### Eksik #5: Render motoru hâlâ innerHTML

| EgeSüt mevcut | Goose-docs önerisi | Kesişim |
|---|---|---|
| innerHTML full replace | **lit-html (1.5KB) veya morphdom (3KB)** (önerilen) | EgeSüt-spesifik mimari karar |
| | **MCP Apps** (yeni feature, experimental) | 🟡 İleri seviye — bizim için overkill şu an |

**Sonuç:** lit-html/morphdom CDN ile 1-2 oturum. MCP Apps'i bekle.

### Eksik #6-11 (ikincil)

| # | Eksik | Goose-docs karşılığı | Not |
|---|---|---|---|
| 6 | a11y kontrolü | **axe-core** CDN + **playwright-cli skill** | 1 oturum |
| 7 | i18n | — | Çözüm yok, manuel |
| 8 | Storybook eşdeğeri | **dev-components.html** (basit, kendimiz) | Yarım oturum |
| 9 | Performance budget | **MLflow** veya **Langfuse** ile OTLP metrik toplama | 1 oturum (altyapı) |
| 10 | Mock fixtures | — | Manuel |
| 11 | Breakpoint standardı | — | ADR yaz |

---

## 6) goose-docs.ai Yeni Pattern'ler (EgeSüt'te Uygulanabilir)

### 🔴 Pattern 1: Ralph Loop — Otonom iteratif geliştirme

**Tanım:** Geoffrey Huntley'nin "Ralph Wiggum" tekniğinin goose implementasyonu. Her iterasyonda:
1. **Worker model** görevi yapar
2. **Reviewer model** (FARKLI model) review eder
3. Özet + feedback dosyalara yazılır
4. Yeni session eski context olmadan dosyalardan devam eder
5. **Max 10 iterasyon** (ayarlanabilir)

**EgeSüt'te kullanım:**
- `ReFactorRoadmap.md` Aşama 3.x'i (Modal sınıfları, render motoru) otonom yürüt
- Tech debt azaltma task'larını (todo işaretli 15 madde) gece-gündüz çalıştır
- Test yazımı + bug fix loop'u

**Efor:** 1 oturum (3 recipe dosyası: `ralph-loop.sh`, `ralph-work.yaml`, `ralph-review.yaml`)

**Kaynak:** `https://raw.githubusercontent.com/aaif-goose/goose/main/documentation/src/pages/recipes/data/recipes/ralph-loop.sh`

### 🔴 Pattern 2: Subagents (Planner/PM/Architect/Dev/QA/Writer)

**Tanım:** Recipe'in içinde `.goosehints` ile çoklu agent rolü tanımla, goose subagent'lara delege etsin.

**EgeSüt'te kullanım:**
- Bizim **telsiz mimarisi** (ADR-006) zaten multi-agent. Subagents pattern'ı bunu **standart recipe**'e çevirir.
- Yeni bir UI refactor'ı → Planner spec yazar → PM task'lara böler → Architect dosya yapısı kurar → Frontend/Backend Dev implement eder → QA test yazar → Tech Writer dökümante eder.

**Fark:** Telsiz (ACP) cross-process, subagents in-session. İkisini **beraber** kullanmak mümkün: subagent hızlı task'lar, telsiz uzun görevler.

**Efor:** 1 skill + 1 recipe (`egesut-subagents.yaml`)

### 🟡 Pattern 3: Subrecipes in Parallel (Experimental)

**Tanım:** Aynı subrecipe'i farklı parametrelerle paralel çalıştır (max 10 concurrent).

**EgeSüt'te kullanım:**
- 130+ hayvan için toplu transfer: her padok için paralel subrecipe
- Kod analizi: security/quality/performance üçü paralel
- Test: her modülün test'i paralel

**Efor:** Spec yaz, dene. (Experimental olduğu için dikkatli)

### 🟡 Pattern 4: MCP Apps (Interactive UI in Chat)

**Tanım:** MCP server `ui://` resourceUri döner, goose chat'te interactive HTML render eder.

**EgeSüt'te kullanım:**
- Claude/goose chat'inde hayvan arama form'u embed et
- "Bu hayvanı göster" → interaktif hayvan kartı

**Not:** Experimental, bizim için **sonraki aşama** (MVP'den sonra).

### 🟡 Pattern 5: Headless Goose + CI/CD

**Tanım:** `goose run --no-session -t "..."` ile non-interactive çalıştır.

**EgeSüt'te kullanım:**
- GitHub Actions'da **otomatik code review** workflow'u
- Her PR'da goose review yorumu yapıştırsın
- Migration diff'lerinde AI doğrulaması

**Efor:** 1 workflow dosyası (`.github/workflows/goose-review.yml`)

### 🟡 Pattern 6: Observability (Langfuse / MLflow)

**Tanım:** OTLP üzerinden LLM call/tool execution trace'lerini topla.

**EgeSüt'te kullanım:**
- tools-bank MCP'nin hangi sorguları ne kadar sürüyor izle
- Goose session'larının kalitesini ölç
- **Maliyet kontrolü** (her oturum kaç token)

**Efor:** 1 oturum (altyapı + dashboard)

### 🟡 Pattern 7: Playwright CLI Skill (PRoot alternatifi!)

**Tanım:** Playwright MCP yerine **Playwright CLI** + skill. Accessibility tree LOCAL'de tutulur (LLM'e gönderilmez → hız + maliyet).

**EgeSüt'te kullanım:**
- **Mevcut sorun:** `npx playwright test` PRoot'ta CPU krizi yapıyor (yasak)
- **Çözüm:** Playwright CLI skill → agent test yazsın, video+trace üretsin, **local'de çalışsın**
- visual regression için screenshot karşılaştırma

**Efor:** 1 skill kurulumu (`npx skills add https://github.com/microsoft/playwright-cli`)

---

## 7) Yeni Skills Marketplace vs Mevcut — Detay

`https://goose-docs.ai/skills/` sayfası (SPA, JS-rendered, scraper ile liste alınamadı) **community skills marketplace** gösteriyor. Bilinen kategoriler (sitemap'ten):

| Skill | Kaynak | EgeSüt'te yok |
|---|---|---|
| Playwright CLI | microsoft/playwright-cli | ❌ (PRoot yasağı çözer) |
| Cognee Usage | Topluluk | ❌ |
| Building MCP Apps | goose | ❌ (overkill) |
| Research → Plan → Implement | Topluluk | ⚠️ `feature-dev` benzeri |
| Subagents | goose | ❌ (telsiz var) |
| Spraay x402 | Topluluk | ❌ (ilgisiz) |

**Aksiyon:** `find-skills` tool'u ile local arama yapılabilir; yeni skill marketplace'i `npx skills` ile taranabilir.


---

## 8) ÖNERİLEN YENİ VARLIKLAR (Öncelik Sıralı)

### A. Yeni Skill'ler (EgeSüt-spesifik)

| # | Skill adı | Lokasyon | Çözdüğü | Efor | Öncelik |
|---|---|---|---|---|---|
| 1 | **`egesut-ralph-loop`** | `~/.agents/skills/egesut-ralph-loop/SKILL.md` | Otonom refactor (modal sınıfları, render motoru) | Yarım oturum | 🔴 1 |
| 2 | **`egesut-ui-review`** | `~/.agents/skills/egesut-ui-review/SKILL.md` | Görsel/UX review (Figma + axe + Rendex + playwright-cli) | 1 oturum | 🔴 2 |
| 3 | **`egesut-subagents`** | `~/.agents/skills/egesut-subagents/SKILL.md` | 6-rollü orkestrasyon pattern'i (Planner/PM/Arch/Dev/QA/Writer) | 1 oturum | 🔴 3 |
| 4 | **`egesut-ci-review`** | `~/.agents/skills/egesut-ci-review/SKILL.md` | Headless goose + GitHub Actions code review workflow | 1 oturum | 🟡 4 |
| 5 | **`egesut-observability`** | `~/.agents/skills/egesut-observability/SKILL.md` | Langfuse/MLflow ile tools-bank trace'leri | 1 oturum | 🟡 5 |

### B. Yeni Recipe'ler (EgeSüt-spesifik)

| # | Recipe adı | Lokasyon | Kullanım | Efor |
|---|---|---|---|---|
| 1 | `egesut-ralph-refactor.yaml` | `/root/tools-bank/recipes/` | Modal/Toast/Autocomplete'i otomatikle sınıfa dönüştür | 1 oturum |
| 2 | `egesut-subagents.yaml` | `/root/tools-bank/recipes/` | 6 rollü çoklu agent (subagents pattern) | 1 oturum |
| 3 | `egesut-headless-review.yaml` | `/root/tools-bank/recipes/` | CI'da `goose run --no-session` review | 1 oturum |

### C. Yeni Extension'lar (goose-docs.ai'den ekle)

| Extension | Kurulum | Kullanım | Efor |
|---|---|---|---|
| **Figma Dev Mode** | `extensionmanager__manage_extensions` | UI/UX review skill'ine besleme | 5 dk |
| **Rendex** | aynı | Screenshot diff (visual regression) | 5 dk |
| **Tavily** veya **Exa Search** | aynı | deerflow alternatifi (daha kaliteli) | 5 dk |
| **Firecrawl** | aynı | Web scraping (derin araştırma) | 5 dk |
| **Cognee** | aynı | `.claude/domain-rules.md` için RAG | Yarım oturum |

### D. Mimari Güncelleme (CLAUDE.md / .claude/architecture)

| Değişiklik | Neden |
|---|---|
| Skills Extension → **Summon** farkındalığı eklensin | v1.25.0+ ile deprecated |
| `ralph-loop` + `subagents` + `headless` pattern'ları mimariye yazılsın | yeni orkestrasyon imkanları |
| `find-skills` artık hem global hem marketplace'i tarar | yeni davranış |

---

## 9) EgeSüt'te 5 Dakikada Yapılabilecek Kazanımlar

Acil (kullanıcı onayı ile hemen):

```bash
# 1. Figma + Rendex + Tavily ekle (visual UI review altyapısı)
extensionmanager__manage_extensions action=enable extension_name=figma
extensionmanager__manage_extensions action=enable extension_name=rendex
extensionmanager__manage_extensions action=enable extension_name=tavily

# 2. Playwright CLI skill'i kur (PRoot yasağını çözer)
# npx skills add https://github.com/microsoft/playwright-cli --skill playwright-cli

# 3. Ralph Loop recipe'lerini indir
curl -sL https://raw.githubusercontent.com/aaif-goose/goose/main/documentation/src/pages/recipes/data/recipes/ralph-loop.sh -o ~/.config/goose/recipes/ralph-loop.sh
curl -sL https://raw.githubusercontent.com/aaif-goose/goose/main/documentation/src/pages/recipes/data/recipes/ralph-work.yaml -o ~/.config/goose/recipes/ralph-work.yaml
curl -sL https://raw.githubusercontent.com/aaif-goose/goose/main/documentation/src/pages/recipes/data/recipes/ralph-review.yaml -o ~/.config/goose/recipes/ralph-review.yaml
chmod +x ~/.config/goose/recipes/ralph-loop.sh
```

**Bu 3 adım:**
- Figma ile UI review
- Visual regression
- Otonom refactor

→ EgeSüt'te **anında 3 yeni kabiliyet** kazandırır.

---

## 10) Toplam Etki Matrisi

| Yatırım | Efor | Kazanım |
|---|---|---|
| Figma + Rendex + Tavily | 15 dk | UI/UX review, web search kalite↑ |
| Playwright CLI skill | 30 dk | PRoot'ta test, visual regression |
| Ralph Loop recipes | 30 dk | Otonom refactor (tech debt eritme) |
| egesut-ui-review skill | 1 oturum | Sistemli UI/UX review workflow |
| egesut-subagents recipe | 1 oturum | 6-rollü orkestrasyon standardı |
| egesut-ci-review workflow | 1 oturum | Her PR'da otomatik AI review |
| Langfuse/MLflow | 1 oturum | Maliyet/kalite metrikleri |
| **TOPLAM** | ~4 oturum | **8 yeni kabiliyet** |

---

## 11) Sonuç ve Aksiyon Planı

### Hemen Yapılacaklar (Kullanıcı onayı ile)

1. **Figma Dev Mode** + **Rendex** + **Tavily** extension'larını etkinleştir
2. **Playwright CLI skill**'i `npx skills` ile kur
3. **Ralph Loop recipe**'lerini indir ve `/root/tools-bank/recipes/`'e kopyala

### Kısa Vade (1-2 oturum)

4. `egesut-ui-review` skill'ini yaz (Eksik #3)
5. `egesut-subagents` recipe'sini yaz (telsiz mimarisini standartla)
6. `egesut-ci-review` workflow'unu yaz (GitHub Actions)

### Orta Vade (3-5 oturum)

7. `egesut-ralph-loop` skill'ini yaz (Modal sınıf refactor'unu otonom çalıştır)
8. `egesut-observability` skill'ini yaz (Langfuse entegrasyonu)
9. Cognee extension'ını değerlendir (domain-rules RAG)

### Mimari Güncelleme

10. `egesut-erp-architecture` skill'ini Summon farkındalığı ile güncelle
11. ADR: "Skills Extension → Summon geçişi" yaz
12. BLACKBOARD'a bu aksiyonları task olarak ekle

---

## 12) Kaynaklar

- 🟢 https://goose-docs.ai/skills/ — Skill sistemi
- 🟢 https://goose-docs.ai/extensions/ — Extension marketplace
- 🟢 https://goose-docs.ai/docs/mcp/summon-mcp — Summon
- 🟢 https://goose-docs.ai/docs/mcp/skills-mcp — Skills (deprecated)
- 🟢 https://goose-docs.ai/docs/guides/context-engineering/using-skills — Skill kullanımı
- 🟢 https://goose-docs.ai/docs/tutorials/playwright-skill — Playwright CLI
- 🟢 https://goose-docs.ai/docs/tutorials/subagents — Subagent orkestrasyon
- 🟢 https://goose-docs.ai/docs/tutorials/ralph-loop — Ralph Loop
- 🟢 https://goose-docs.ai/docs/tutorials/subrecipes-in-parallel — Paralel subrecipe
- 🟢 https://goose-docs.ai/docs/tutorials/headless-goose — Headless mode
- 🟢 https://goose-docs.ai/docs/tutorials/cicd — CI/CD
- 🟢 https://goose-docs.ai/docs/tutorials/mlflow — MLflow
- 🟢 https://goose-docs.ai/docs/tutorials/langfuse — Langfuse
- 🟢 https://goose-docs.ai/docs/mcp/extension-manager-mcp — Extension manager
- 🟢 https://goose-docs.ai/llms.txt — LLM özet

**Araştırma tamamlandı:** 2026-06-09  
**Toplam okunan sayfa:** 14 (tutorial + docs + sitemap)  
**Toplam veri:** ~1.4 MB HTML

