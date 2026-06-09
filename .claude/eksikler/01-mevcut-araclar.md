# Mevcut Araçlar — Detaylı Envanter

## 1) Recipes — `/root/tools-bank/recipes/` (9 adet)

| Recipe | UI/Refactor işinde rolü | Ne zaman kullan |
|---|---|---|
| `egesut.yaml` | **Ana worker** — EgeSüt-spesifik context gömülü (state.js, renderFromLocal, modüler yapı, MVP domain'leri) | Doğrudan UI implementasyonu |
| `egesut-telsiz.yaml` | Aynısı + telsiz protokolü (multi-agent) | Birden fazla paralel worker gereken UI işleri |
| `worker.yaml` | Generic code worker (proje-agnostik) | EgeSüt-spesifik context gerekmeyen basit görevler |
| `spec-writer.yaml` | "Kullanıcı X istiyor" → spec yaz, implement etme | Önce spec, sonra implement gereken işler |
| `reviewer.yaml` | Type-aware review (code/migration/docs) + self-repair | Refactor/UI değişikliği sonrası kalite kontrol |
| `tester.yaml` | Spec'teki test adımlarını koşturur, rapor yazar (Playwright atlanır) | Her implementasyon sonrası |
| `orchestrator.yaml` | Karmaşık refactor'ı adımlara böler, recipe atar, çıkar | Çok adımlı UI refactor planlaması |
| `conductor.yaml` | Spec'i okur, worker'ları sırayla başlatır, crash-safe | orchestrator'ın tasarladığı spec'i çalıştırma |
| `goose-ops.yaml` | Handoff/worker script işleri | UI işi için değil |

**Kombinasyon: en sık UI iş akışı**
```
orchestrator (planla) → conductor (çalıştır)
   → worker (egesut) — implement
   → tester — test
   → reviewer — kabul/ret
```

## 2) Skills — `/root/.claude/skills/` (toplam 99, UI için 11 ilgili)

### Doğrudan UI/Tasarım/Refactor'a yönelik

| Skill | İşlevi | Ne zaman yükle |
|---|---|---|
| `feature-dev` | **en uygun** — explore → clarify → design → implement → test → review | Yeni UI feature geliştirirken |
| `executing-plans` | Spec/plan checkpoint'li implementasyon | Uzun refactor görevleri |
| `session-update` | Oturum sonunda memory/handoff/spec güncelle | Refactor task'larından sonra (kritik) |
| `find-skills` | Eksik UI skill'lerini keşfet | "Bunu yapan bir skill var mı?" sorusu |
| `gitnexus-refactoring` | **doğrudan** — rename/extract/split/move call graph ile | Refactor kararı öncesi/sonrası |
| `gitnexus-impact-analysis` | "Bu UI fonksiyonunu değiştirsem ne kırılır?" | Refactor öncesi blast radius |
| `gitnexus-pr-review` | UI PR'larını gözden geçir | PR review aşaması |
| `gitnexus-exploring` | "X nasıl çalışıyor?" | UI kodunu anlamak |
| `gitnexus-debugging` | Bug trace | UI bug'ı |
| `gitnexus-cli` | İndeks/re-analyze | Index stale ise |
| `gitnexus-guide` | Hangi tool ne zaman | GitNexus tool seçim kararsızlığı |

### Mevcut ama UI işine uygun değil

- `gws-*` (Google Workspace — ilgisiz)
- `persona-*` (insan rolleri — UI işine uygun değil)
- `recipes` (Workspace recipe'leri)

## 3) tools-bank MCP Tool'ları (55+ tool)

### Tasarım/refactor için elzem

| Tool | UI/Refactor'da ne işe yarar |
|---|---|
| `gitnexus_query` | "modal nasıl açılıyor?", "render motoru nereden tetikleniyor?" — execution flow keşfi |
| `gitnexus_context(symbol)` | Bir UI fonksiyonunun 360° görünümü — callers/callees/refactor'da önce bu |
| `gitnexus_impact(target)` | **refactor öncesi şart** — bir fonksiyonu sil/taşırsak ne kırılır |
| `gitnexus_detect_changes()` | Commit öncesi scope doğrulama |
| `gitnexus_detect_changes(compare, base_ref=main)` | Branch karşılaştırma |
| `ast_grep_search` | `renderAnimals($$$)` gibi yapısal arama — 3000 satırlık ui.js'de cımbız |
| `semantic_search` | "modal yönetimi" gibi kavramsal arama |
| `sonar_issues` | Duplikasyon, code smell — refactor adaylarını bul |
| `sonar_duplications` | `js/ui.js` içinde kopyala-yapıştır blokları |
| `sonar_hotspots` | Güvenlik/kalite hotspot'ları |
| `sonar_coverage` | Test edilmemiş UI kodu |
| `memory_search` | Geçmiş refactor kararları ("neden AppState'e geçtik?") |
| `task_create/list/get/complete/review` | BlackBoard — refactor task'ları burada yaşar |
| `file_read/write/list` | Spec/handoff dosyalarını DB'de tutma |
| `supabase_query/rpc` | UI'ın arkasındaki veri davranışını anlamak |

### Yardımcı (sık kullanılan)

| Tool | İşlevi |
|---|---|
| `file_list` | DB'deki dosyaları pattern ile listele |
| `file_commit` | Review approved sonrası commit + push (sadece Claude çağırır) |
| `file_flush` | DB dosyalarını diske yaz + test (sadece Claude) |
| `deerflow_research` | Web araştırması (UI pattern, library research) |
| `goose_search` | Goose dokümantasyonunda semantik arama |
| `knowledge_graph_query` | Domain kavramları arası ilişki |

## 4) Proje-İçi Varlıklar — `/root/egesut-erp1/.claude/`

| Dosya/dizin | İçerik | UI işinde kullanım |
|---|---|---|
| `ReFactorRoadmap.md` | 3 aşamalı refactor yol haritası (1.1-3.4) | Refactor planlamada kaynak doküman |
| `ui-map.md` | 2804 satırlık ui.js bölüm haritası, paralel subagent dispatch rehberi | **Çok değerli** — ui.js'e dokunmadan önce oku |
| `ideas/` | 9 fikir dosyası (api-katmanı-refactor, ureme-zeka, kural-motoru, dashboard-aktif-vakalar vb.) | Yeni feature brainstorming |
| `arch-decisions/ADR-006` | Telsiz mimarisi (Agent Communication Protocol) | Multi-agent UI işi |
| `arch-decisions/ADR-007` | Multi-tier goose orchestration | Karmaşık refactor orkestrasyonu |
| `domain-rules.md` | Domain kuralları (gebelik, laktasyon, kuru dönem vb.) | İş kuralları doğrulama |
| `rpc-reference.md` | Mevcut RPC fonksiyonları referansı | RPC parametrelerini öğrenme |
| `tasks/dev/` | 7 mevcut task (örn. `task-040-hastalik-tanimlama.md`) | Format örneği |
| `tasks/arge/` | 2 arge task'ı (istatistik modülü/motoru) | Format örneği |
| `specs/2026-03-26-arge-department-design.md` | Spec örneği | Spec formatı |
| `hookify.blast-radius-guard.local.md` | Refactor sırasında blast radius uyarısı | Otomatik guard |
| `hookify.block-direct-writes.local.md` | Doğrudan DB yazma engeli | SQL onay gate |
| `hookify.check-duplicates.local.md` | Duplikasyon kontrolü | Refactor sırasında |
| `hookify.protect-critical-files.local.md` | Kritik dosya koruma | Mimari dosyalara yanlışlıkla dokunmayı engeller |
| `BLACKBOARD.md` | Aktif task'lar, notlar | Mevcut durum |
| `session-learnings.md` | Oturum dersleri | Geçmiş hatalardan öğrenme |
| `knowledge/` | 9 envanter/durum dosyası (infrastructure-plan, sonar-issues, bugs vb.) | Genel bilgi tabanı |

## 5) Kod Tarafı Varlıklar

| Dosya | Satır (yaklaşık) | UI/Refactor'da not |
|---|---|---|
| `js/ui.js` | 2804 | **En büyük dosya** — refactor hedefi #1 (Aşama 3) |
| `js/forms.js` | ~2000 | Form/modals — refactor hedefi (Aşama 1.3 yarım) |
| `js/api.js` | ~? | Supabase API, IDB sync (Aşama 2 hedefi) |
| `js/app.js` | ~? | Ana orchestrator |
| `js/state.js` | küçük | AppState, EventEmitter (1.1 kısmen tamam) |
| `js/config.js` | küçük | Sabitler (1.2 kısmen tamam) |
| `index.html` | tek sayfa | Tüm UI burada — CSS inline |
| `css/` dizini | **YOK** | Tüm stiller index.html içinde |
| `js/components/` dizini | **YOK** | Component kütüphanesi yok |
| `js/utils/` dizini | **YOK** | Helper'lar ui.js içinde dağınık |
| `js/design-tokens.js` | **YOK** | Token sistemi yok |
