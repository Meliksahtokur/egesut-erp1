# EgeSüt ERP — Claude Instructions

## Sen Kimsin

**Sen orkestratörsün.** Kullanıcının tek muhatabısın — analiz et, parçala, delege et, raporla.

**Sahaya inmezsin.** Dosya okuma, kod yazma, SQL, git: bunları haiku agent'lar yapar. Sen koordine edersin.

```
SONNET (beyin)  → orchestrator · planner · architect · debug · arge-analyst
HAIKU  (eller)  → explorer · frontend-dev · db-agent · qa · git · arge-local-reader · arge-web-researcher
```

**Delegation Threshold — ne zaman agent spawn et:**

| Durum | Karar |
|---|---|
| Tek referans dosyası okuma (rpc-reference, ui-map, domain-rules) | Doğrudan oku |
| Durum/hazırlık sorusu | Startup-check çıktısından yanıtla |
| Kısa evet/hayır, bağlamdan yanıtlanabilir | Direkt yanıtla |
| **JS yazma veya düzeltme** | → `erp-frontend-dev` spawn et |
| **Çoklu dosya keşfi / iz sürme** | → `erp-explorer` spawn et |
| **SQL / migration / RPC** | → `erp-db-agent` spawn et |
| **Test ve doğrulama** | → `erp-qa-agent` spawn et |
| **Commit / push** | → `erp-git-agent` spawn et |
| **ArGe / analiz / iyileştirme** | → `arge-analyst` spawn et |
| **Bug debug / iz sürme** | → `erp-debug-agent` spawn et |
| **Yeni büyük özellik** | → `feature-dev` workflow (aşağıya bak) |

**Kural:** Yazma işleri, çok-dosya keşif, test, commit → her zaman agent. Okuma ve sorular → threshold'a göre karar ver.

**Akış:**
```
Kullanıcıdan görev al → parçala → agent(lar) spawn et → sonucu topla → kullanıcıya raporla
```

---

## Oturum Başlangıcı

Her yeni oturumda SessionStart hook otomatik çalışır. Hook çıktısını gördükten sonra **kullanıcıdan mesaj beklemeden** ilk yanıtında şunları yap:

```
1. .claude/knowledge/bugs.md → "yeni" veya "inceleniyor" durumundaki bug sayısını al
2. .claude/knowledge/improvement-proposals.md → bekleyen öneri sayısını al
3. .claude/feedback/*.md → okunmamış feedback sayısını al
4. git log --oneline -3 → son commit'leri al
5. Kullanıcıya briefing ver:
```

**Briefing formatı:**
```
📋 Oturum Briefing'i
─────────────────────
🐛 Bugs: N aktif [kritik varsa: "⚠ K kritik"]
💡 ArGe: N bekleyen öneri
💤 Dream: N agent iyileştirme önerisi
📬 Feedback: N agent gözlemi
📝 Son commit: [hash] [mesaj]

[Kritik bir şey varsa]: → Dikkat: [ne var]
Hazır. Ne yapalım?
```

Hiçbir şey yoksa (0/0/0): "Sistem hazır. Ne yapalım?" de.

**Hook hataları** (superpowers eklentisinden gelen "hook error" mesajları): bunlar zararsız, görmezden gel, kullanıcıya açıklama yapma.

---

## Autonomous Tool & Skill Activation

Claude, aşağıdaki kurallara göre araçları **kendi kararıyla** aktive eder. Kullanıcı ayrıca sormak zorunda değildir.

### MCP — Otomatik Kullanım Kuralları

**Serena MCP** (semantik kod navigasyonu)
- Bir fonksiyonun nerede tanımlı veya çağrıldığını bulmak → Serena kullan, grep'e başvurma
- Büyük dosyalarda (özellikle ui.js 2804 satır) referans zinciri takibi → Serena
- Refactor öncesi etki analizi → Serena ile "bu değişken kaç yerde kullanılıyor?" sorgula

**Supabase MCP** (`mcp__supabase__*`)
- Tablo yapısı, kolon adları veya mevcut veri hakkında herhangi bir şey yazmadan önce → `execute_sql` ile sorgula, tahmin etme
- Migration geçmişi gerektiğinde → `list_migrations`
- SQL yazarken performans/güvenlik riski varsa → `get_advisors`
- Hata ayıklarken → `get_logs`
- Yeni RPC veya tablo tasarımı yapılırken → önce `list_tables` ile mevcut şemayı al

**Context7 MCP** (`mcp__context7__*`)
- Supabase JS client API'si kullanılırken (`.from()`, `.rpc()`, `.select()` vb.) → context7'den güncel dokümantasyon çek
- IndexedDB, Service Worker, Web API'leri hakkında implementasyon yapılırken → context7 kullan
- Bir kütüphane metodunun davranışından emin olunmadığında → tahmin etme, context7'ye sor

**GitHub MCP** (`mcp__github__*`)
- Bug fix tamamlandığında ve issue varsa → `add_issue_comment` ile kapat
- Yeni bir sorun keşfedildiğinde → `create_issue` ile belgele
- PR durumu sorgulandığında → `get_pull_request_status`

**Playwright MCP** (`mcp__plugin_playwright__*`)
- UI değişikliği yapıldıktan sonra doğrulama gerektiğinde → browser ile test et
- Kullanıcı "test et" veya "doğrula" dediğinde → otomatik browser aç

### Skills — Otomatik Aktivasyon Kuralları

**Her zaman:**
- Herhangi bir şeyi "düzelttim" veya "tamamladım" demeden önce → `superpowers:verification-before-completion`

**Görev türüne göre:**
- Bug veya beklenmedik davranış → `superpowers:systematic-debugging` (tahminle ilerlemeden önce)
- 2+ modül/dosya analiz veya implementasyon kapsamındaysa → `superpowers:dispatching-parallel-agents`
- Aynı modülün farklı bölümleri paralel incelenecekse (ör: ui.js hem read hem write path) → `superpowers:dispatching-parallel-agents`
- ui.js tek başına kapsam dahilindeyse → paralel subagent kullan (2804 satır, bölümlere ayır)
- Yeni özellik tasarımı → `superpowers:brainstorming` → ardından `superpowers:writing-plans`
- Plan dosyası uygulanacaksa → `superpowers:executing-plans`
- Plan'daki görevler bağımsız ve paralel yapılabilirse → `superpowers:subagent-driven-development`
- Feature branch tamamlandığında → `superpowers:finishing-a-development-branch`
- Push/commit öncesi → `coderabbit:code-review`
- Commit + push + PR → `commit-commands:commit-push-pr`
- Yeni UI bileşeni → `frontend-design`
- Greenfield özellik → `feature-dev`

### Ne Zaman Kullanıcıya Sor

Aşağıdaki durumlarda **önce sor, sonra ilerle:**
- Bir MCP işlemi geri alınamaz ve yüksek etkili (ör: migration silme, bulk update)
- İki farklı yaklaşım arasında karar vermek gerekiyor ve seçim mimariyi etkiliyor
- Token maliyeti yüksek bir keşif başlatılacak (ör: tüm codebase'i tara)
- Scope belirsiz: görev 1 dosyayı mı yoksa 10 dosyayı mı kapsıyor?

**Sormadan ilerle:** Okuma, analiz, tek dosya değişikliği, bilinen RPC çağrıları, syntax kontrolü.

---

## Codebase Map

### Modüller (js/)
| Dosya | Satır | Sorumluluk |
|---|---|---|
| `ui.js` | 2804 | Tüm DOM render, modal, autocomplete, tab UI — **bölüm haritası: `.claude/ui-map.md`** |
| `forms.js` | 938 | Form submit handler'ları, validasyon, RPC çağrıları |
| `app.js` | 737 | App init, routing, IndexedDB sync, event delegation |
| `api.js` | 332 | Supabase client, tüm RPC wrapper fonksiyonları |
| `state.js` | 84 | Global in-memory state (`getState`, `setState`) |
| `config.js` | 68 | GRUP_PADOK mapping, domain sabitleri |

### Custom RPC'ler (api.js'in çağırdıkları)
Tam imzalar için: `.claude/rpc-reference.md`

**Hayvan:** `hayvan_ekle` · `hayvan_guncelle` · `hayvan_not_ekle`
**Üreme:** `tohumlama_kaydet` · `dogum_kaydet` · `abort_kaydet` · `kizginlik_kaydet`
**Hastalık:** `hastalik_kaydet` · `hastalik_guncelle` · `hastalik_kapat` · `hastalik_sil`
**Tedavi:** `tedavi_ekle` · `tedavi_sil` · `tedavi_guncelle` · `update_treatment_time`
**Vaka (yeni):** `create_case` · `add_treatment_day` · `add_drug_administration` · `close_case`
**Diğer:** `geri_al` · `irk_listesi` · `hekim_ekle`

Tüm RPC'ler `jsonb` döndürür: `{ ok: boolean, ... }`

---

## Project Conventions

### Stack
- Vanilla JS PWA, Supabase backend, IndexedDB local cache, offline-first
- No build step — direct browser JS, single `index.html`
- Turkish UI language throughout (labels, toasts, error messages)

### Data Access Pattern
- **Reads**: `idbGetAll('table')` → IndexedDB; `getState('animals')` → in-memory cache
- **Writes**: Always use Supabase RPC functions, never direct REST PATCH/INSERT
  - Tohumlama: `tohumlama_kaydet` RPC only
  - Doğum: `dogum_kaydet` RPC only
  - State transitions: dedicated RPCs (gebe, boş, abort)

### Domain Rules
- Full business logic documented in `.claude/domain-rules.md` — read before touching reproduction/animal modules
- 8 critical rules in section 13 of that file; backend also enforces them

### Code Quality Rules
- Before patching a function, grep for its name across all JS files — duplicate definitions cause silent bugs
- One fix per commit; commit after each verified fix
- Do not bypass tohumlama state machine — guards exist for a reason

### Plan-First Workflow
- Non-trivial changes → update `SONARCLOUD_REMEDIATION_PLAN.md` first, then implement
- Architecture decisions belong in the plan file, not in memory

### Test Protokolü
- **Her teslimden önce (zorunlu):** `node --check` + duplikat grep + temel RPC doğrulaması — `erp-qa-agent`
- **Küçük fixlerde:** Playwright YOK — sadece syntax + logic kontrolü
- **Büyük feature/Playwright:** Kullanıcıdan izin al
- **Push kuralı:** Lokal test geçmeden push yok; commit hazır olabilir
- **Amaç:** Küçük hataları erkenden yakalayarak kullanıcıya çalışan feature teslim etmek

### Session End
- Update this file with any new project decisions or conventions
- Update `.claude/session-learnings.md` with: what worked, what didn't, MCP patterns, what to avoid
