# Fix Roadmap + İdle Omurgası — 2026-08-31

> **Kaynaklar:** `.claude/idle-reports/2026-08-31-bug-hunt.md` (B1–B37),
> `2026-08-31-docs-tutarlilik.md` (10 aksiyon), `2026-08-31-test-kapsam.md` (251 test + 14 şüpheli davranış).
> **Omurga:** Bu dosya. Fix'ler bu oturumda main üzerinde sıralı yapılır; idle işleri bu oturum
> sonunda worktree'lerde başlatılır. Fix worker'ları (paralel subagent) bu planda kasti olarak
> ATEŞLENMEZ — tek yazar orkestratördür.

## 0. Durum özeti (2026-08-31)

- `main` = origin/main + 1 (`6f3aa13` unit testler **push edilmemiş**) → P0'da push
- Bug envanteri: **7 HIGH · 15 MED · 12 LOW** (B1–B22 + B23–B37) — hepsi raporda satır satır doğrulanmış
- Docs envanteri: AGENTS.md ID tablosunda 3 ters kayıt (aktif yanıltıcı), rpc-reference'ta 73 eksik RPC + 4 bayat imza, domain-rules'ta 8 çelişki + 8 bayat, ReFactorRoadmap kök referansı kırık
- Test: 251 unit (vm loader altyapısı `tests/unit/support/loadModule.js`), 4 E2E spec, `test:demo`/`test:local` script'leri mevcut
- GitNexus indeksi ~180 satır bayat (bug-hunt raporu notu) → P1'de reindex
- Bilinen açık güvenlik bulgusu: **B1** demo credential + demo DB prod klonu (karar noktası, §4)

## 1. Preflight (fix'lerden önce, bu oturumda)

| # | İş | Araç / Not |
|---|---|---|
| P0 | `6f3aa13` push et | `git push` (repo kuralı: commit = iş kanıtı) |
| P1 | GitNexus reindex | `node .gitnexus/run.cjs analyze` — impact analizleri bundan sonra güvenilir olur |
| P2 | **B7 canlı teyit** (salt-okunur): `planli_tohumlama_kaydet`, `tedavi_sablon_tohumlama_gorev_ekle`, `vaka_tohumlama_ekle` var mı? + B6 `buildRpcParams` RPC'lerinin canlı imzaları | `pg_get_functiondef` — sonuç WP-5'in girdisi; eksik RPC bulunursa §4/KARAR-2'ye düşer |
| P3 | **Canlı şema snapshot'ı** → `.claude/schema-snapshots/2026-08-31-live-schema.sql` | Idle-A'nın tek girdisi; idle görev DB'ye dokunmayacak, dump'tan çalışacak |

## 2. Oturum Fix Paketleri (sıra ile, main üzerinde)

Her paketin ritüeli: **impact/okuma → fix → `npm run test:unit` → `detect_changes` → commit (+push)**.
Oturum kesilirse kalan paket bu dosyada işaretlenir ve worktree kuyruğuna devrolur.

| WP | Kapsam (bulgu) | Dosyalar | Risk |
|----|----------------|----------|------|
| **WP-1 Modal/router/history** | B2 (`.modal.on` ölü selector → `.mo.on`), B3 (backdrop-tap → `closeM` cleanup), B21 (proto sheet `closeProtoSheet` tek nokta), B22 (td2-tekrar/geri-al + openConfirm → attribute onclick + dataset) | app.js, utils/handlers.js, utils/modal.js, ui.js, index.html | MED — UI regression; modal.test.js güncellenir |
| **WP-2 Yerel tarih helper** | B4: `toISOString().split('T')[0]` → tek `bugun()` helper'ı (Europe/Istanbul yerel Y-M-D); `a-dt.max`, form default'ları, görev filtresi, `dAgo/dFwd` (~30 çağrı yeri) | utils/helpers.js, utils/modal.js, forms.js, ui.js, app.js | LOW-MED — mekanik ama geniş; unit test eklenir |
| **WP-3 forms.js doğruluk paketi** | B12 (`_ekUygulamalar` sızıntısı → açılış+kapanışta sıfırla), B13 (retry `submitInsem(btn)`), B14 (abort Cancel iptal + tarih aralığı), B15 (`devlet_kupe` lookup + eşleşmezse engelle), B29 (`p_concentration_unit`), B31 (öneri dalı rpc-kontratına göre), B32 (negatif sayı guard'ları), B33 (`res.hatalar`), B36 (kızgınlık ileri tarih) | forms.js (+ modal.js kancası) | LOW — cerrahi yamalar |
| **WP-4 api.js senkron katmanı** | B16 (dbUpdate null filtresi → yalnız `undefined` atla), B17 (syncNow skip-and-continue + retry/dead-letter), B18 (pullTables mutex → promise zinciri), B19 (pull hatalarını yüzeyle), B23 (rpc catch-all etiket), B27 (TABLES↔FETCHERS drift), B28 (PATCH/POST guard), B35+B37 (online handler tekilleştir) | api.js (+ app.js handler) | MED — senkron çekirdeği; `_trErr` unit testleri eklenir |
| **WP-5 buildRpcParams yeniden yazım** | B6 (6 RPC imza + POST `clean[0]`), B25 (DELETE dalı) — P2 canlı imzalarına göre | ui.js:6688-6812 | MED — tablo-testli unit test (extractFunctionSource) |
| **WP-6 UI doğruluk paketi** | B5 (loadRaporlar diseases/cases join), B11 (çift `bildirimKontrol` → forms.js:1450 sil), B20 (Gebe kartı `filterA` entegrasyonu), B24 (`more` sayacı), B30 (unbind `p_drug_id`), B34 (görev detayında stok adı) | ui.js, forms.js | LOW |
| **WP-7 Escape + Türkçe sweep** | B9 (~10 yer `escAttr`/dataset deseni), B10 (~8 yer `trLower`), test-rapor #2 (`band()` escape + `_dashBands`) | ui.js | LOW-MED; ui-pure testleri güncellenir |
| **WP-8 Ölü hata kontrolleri** | B8 (8 yer `const {error}` → try/catch + toast, `hekimDetSil` deseni) | ui.js | LOW |
| **WP-9 Test-rapor şüphelileri (kod)** | #1 `_kupeKontrolEt` fail-open → "kontrol yapılamadı" uyarısı + bilinçli devam; #4 `showDebug` bare `esc` bind; #3 `setBatch` asimetrisi → ya normalize ya sözleşme notu (karar: fix sırasında) | forms.js, utils/errorHandler.js, state.js | LOW — mevcut testler bilinçli güncellenir |
| **WP-SQL Backend guard paketi** (KARAR-2, P2 sonrası) | (a) erkek↔grup guard'ı (hayvan_ekle/guncelle/padok_degistir), (b) dişi <13 ay tohumlama yaş guard'ı (tohumlama satırı üreten tüm RPC'ler, v_eligible eşiğiyle), (c) dogum_kaydet ileri tarih reddi, (d) B7'de eksik çıkan RPC migration'larının deploy'u | supabase/migrations/ + deploy | MED — blast radius (pg_depend) + canlı şema doğrulaması zorunlu |
| **WP-D Docs hızlı paketi** | AGENTS.md ID tablosu (gorev_log→**uuid**, stok_hareket→**text**, islem_log→**text** + cast kılavuzu düzelt), AGENTS.md:196 ReFactorRoadmap referansı, `.claude/ReFactorRoadmap.md` ilerleme satırları (Aşama 3 delegation yapıldı vb.), `RefactorRoadmap.md`→archive, AGENTS.md'e idle-worktree istisna satırı, **B1 public-by-design notu** (api.js yorum + AGENTS.md güvenlik notu) | AGENTS.md, .claude/*, api.js (yalnız yorum) | LOW — rpc-reference/domain-rules/GT derin işi **Idle-A**'ya bırakılır |

**Bilinçli kapsam dışı (bu oturum):** B1 (ürün kararı, §4), B26 (VARSAYILAN_HEKIM — not düşülür, yapısal değişim değil), index.html:2096 self-XSS (ayrı tur), CLAUDE.md:299 (kullanıcı onayı/bizzat düzeltme).

## 3. Sonraki Üçlü İdle Görevler (derin · uzun · budaklanabilir)

Ortak guardrail: **Supabase'e hiçbir MCP çağrısı yok** (girdiler bu oturumun dump'ları),
**deploy yok**, **main'e push yok** (yalnız worktree commit), rapor `.claude/idle-reports/` altına,
kod yazımı yalnız görev tanımında açıkça izin verilen dosyalarla sınırlı.

### Idle-A — Canlı-şema doküman hattı (docs-only, sıfır kod riski)
- **Girdi:** P3 snapshot'ı (canlı DB'ye dokunmaz)
- **Çıktılar:**
  1. `.claude/rpc-reference.md` sıfırdan regen: ~120 RPC imza+dönüş+kullanım yeri; C1–C4 fix, 73 eksik ekleme, `geri_al` dedup, D1/D2 notları; **git'e işlenir** (şu an untracked)
  2. `supabase/migrations/99999999999999_ground_truth.sql` **GT v5** regen + audit sayıları (40/13/175 iddiaları netleştir)
  3. `.claude/domain-rules.md` 8 çelişki + 8 bayatlık düzeltmesi (16 görev, d2·d25·d39, E Vitamini, 'Pasif', islem_log/gorev_tipi listeleri, farm_id UUID tipografisi)
  4. `.claude/ui-map.md` yeniden üretim (memory'de askıda — satır aralıkları 2.8k satırlık dönemden)
- **Worktree:** `idle/docs-hatti`

### Idle-B — E2E demo-mode savunma hattı (tests/ only)
- **Girdi:** `test:demo` (PLAYWRIGHT_DEMO_MODE=1) + `test:local` (serve:local); demo DB klon olduğu için yazma güvenli; testler veri-agnostic yazılır (B1 kararı veri şeklini değiştirirse etkilenmesin)
- **Çıktılar (yeni spec'ler):**
  1. Modal router: Android geri tuşu (B2/B3/B22 fix kilitleri), backdrop-tap cleanup, proto-sheet history
  2. Gece penceresi 00:00–03:00 tarih senaryosu (Playwright clock ile; B4 kilidi)
  3. Tohumlama→doğum→sessiz liste kritik akışı
  4. Görev ekle→tamamla→geri al yaşam döngüsü
  5. Offline kuyruk: ağ kesinti→replay (B17 kilidi)
- **Worktree:** `idle/e2e-savunma` — bu oturumun fix'lerinin regresyon ağı olur

### Idle-C — UI altyapı + test derinleşme
- **Çıktılar:**
  1. **Aşama 3.4 toast kuyruğu** (roadmap): `toast()` kuyruk + tür renk/ikon; yalnız `js/utils/helpers.js` + unit test (loader altyapısı hazır) — kod yazımı açıkça izinli tek js dosyası
  2. **api.js unit derinleşme:** `_trErr` eşleme, `rpc()` arg doğrulama, `RPC_TABLES`, offline kuyruk mantığı — WP-4 fix'lerini kilitler
  3. **Aşama 3.1 ön çalışma (salt-okunur):** render benchmark ölçüm raporu (liste boyutları, innerHTML maliyeti, virtual scroll/pagination karar belgesi) → kod değişikliği yok, karar belgesi üretilir
- **Worktree:** `idle/ui-altyapi`

Üç görev dosya bazında ayrık (Idle-A: docs+GT · Idle-B: tests/*.spec.js · Idle-C: helpers.js+tests/unit) → merge çakışması minimal.

## 4. Karar Noktaları — KULLANICI CEVAPLANDI (2026-08-31)

1. **B1 — demo credential: PUBLIC-BY-DESIGN (kasıtlı).** Kullanıcı: demo, canlı test yapılan izole bir DB'dir (gerçek DB'ye bağlı değil, yalnızız klon) ve incelemek isteyenler için gerçekçi bir oyuncaktır. → Kod değişikliği YOK; WP-D'ye kısa dokümantasyon notu (api.js yorum + AGENTS.md güvenlik notu) eklenir. Rapor kapanır.
2. **Backend SQL guard'ları — ONAYLANDI (yaz + deploy, WP-SQL):**
   - **(a) Erkek↔grup guard'ı:** `hayvan_ekle`/`hayvan_guncelle`/`padok_degistir`'e cinsiyet↔grup kontrolü (frontend app.js:280-304'teki kuralın backend aynası — REST bypass'ını kapatır; kullanıcının "frontend zaten çalışıyor" sorusunun cevabı: anon key public olduğundan frontend atlanabilir, tek kilit backend).
   - **(b) YENİ — Tohumlama yaş guard'ı (kullanıcı bulgusu):** dişi hayvan **13 aydan küçükse** tohumlama kaydı backend'de reddedilmeli. (Kullanıcı canlıda 1 aylık hayvana tohumlama açıldığını tespit edip elle düzeltti; frontend guard var, backend yok.) Kapsam: tohumlama satırı üreten tüm RPC'ler (`tohumlama_kaydet`, `tohumlama_tekrar_kaydet`, `planli_tohumlama_kaydet`, `vaka_tohumlama_ekle` vb. — implementasyonda envanterlenecek). Yaş eşiği mevcut `v_eligible`/düve 13ay kuralıyla birebir hizalanacak (13ay+55g sessiz-liste kuralı ile karıştırılmaz: uygunluk noktası 13 ay).
   - **(c) `dogum_kaydet` ileri doğum tarihi kontrolü** (docs-rapor kod eksiği; frontend forms.js:155'in backend aynası).
   - **(d) B7 sonucu:** preflight'ta 3 RPC (`planli_tohumlama_kaydet` vb.) canlıda eksik çıkarsa Temmuz migration'ları da deploy edilir (aynı karar kapsamı).
3. **CLAUDE.md:299** bayat (kural gereği OMP dokunamaz) — kullanıcı bizzat düzeltir ya da açık onay verir. Bu planda flag'li.

## 5. Worktree Modeli (idle işleri)

- **Zamanlama:** Bu oturumun fix'leri main'e push edildikten **sonra** açılır (bayat temelden branch atmamak için). Şimdilik yalnız plan.
- **Yerleşim:** `../egesut-wt/<ad>` · branch `idle/<ad>` · ör. `git worktree add -b idle/docs-hatti ../egesut-wt/docs-hatti main`
- **İstisna:** AGENTS.md "main dışında branch YASAK" kuralı, kullanıcı onayıyla **yalnızca** `idle/*` worktree'leri için istisna tanır (WP-D'de AGENTS.md'e işlenir).
- **Merge protokolü (sabah incelemesi):** idle run → worktree'de commit (push yok) → `.claude/idle-reports/` raporu → orkestratör review (`git diff --stat` → hedefli diff → ana working tree'de test) → **merge main** veya **revize notu** (task'a geri). Merge sonrası worktree/branch temizlenir.

## 6. Oturum Sonucu (2026-08-31 — tamamlandı)

**Kullanıcı kararları:** B1 = public-by-design (kasıtlı, izole klon demo DB) · SQL guard'lar = tablo-seviyesi
trigger (kullanıcı bulgusu: RPC guard'ları doğrudan SQL seed'i atlıyor) · tohumlama eşik 365 gün KALDI.

| İş | Durum | Commit / Kanıt |
|----|-------|----------------|
| P0 push | ✅ | 6f3aa13 pushed |
| P1 reindex | ✅ | GitNexus analyze tamam |
| P2 B7 canlı teyit | ✅ | 3 RPC de canlıda MEVCUT — özellik sağlam, GT/rpc-reference bayat |
| P3 şema snapshot | ✅ | `.claude/schema-snapshots/2026-08-31-live-schema-imzalar.md` (195 fn + 44 tablo) |
| WP-SQL guard trigger'ları | ✅ | `20260831000003` — deploy + 3/3 fonksiyonel test (rollback'li sub-tx); canlı veri 6/6 ihlalsiz; commit `690b089` |
| WP-1 modal/router (B2+B3+B21+B22) | ✅ | `c096485` |
| WP-2 bugun() (B4) | ✅ | `45b41a1` — 41 çağrı yeri + 5 test |
| WP-3 forms paketi (B12-15, B29, B31-33, B36) | ✅ | `4b8a95d` |
| WP-4 api.js senkron (B16-19, B23, B27-28, B35, B37) | ✅ | `ef523c4` |
| WP-5 buildRpcParams (B6+B25) | ✅ | `202df1f` + 9 imza-testi |
| WP-6 UI doğruluk (B5, B11, B20, B24, B30, B34) | ✅ | `0785bc9` |
| WP-7 escape+türkçe (B9 kısmi + B10 tam) | ✅ | `62e87e5` — 20 arama noktası + ana onclick/innerHTML ihlalleri |
| WP-8 ölü hata kontrolleri (B8) | ✅ | `6610fd7` — 9 yer |
| WP-9 test şüphelileri | ✅ | `71b1588` + `41a36df` (3 kilit test bilinçli güncellendi) |
| WP-D docs hızlı paketi | ✅ | `5d78587` + AGENTS.md (yerel) — ID tablosu CANLI şemadan (stok_hareket/tohumlama uuid düzeltmesi dahil) |
| Unit testler | ✅ | 251 → **265** (264 pass + 1 skip) |
| 3 idle worktree + spec | ✅ | `../egesut-wt/{docs-hatti,e2e-savunma,ui-altyapi}` · `idle/*` branch'ler · IDLE-GOREV.md'ler yazılı |

**Bilinçli kapsam dışı kalan (sonraki turlar):**
- B9'un kalan düşük riskli iç noktaları (optgroup 3185-3190 eski numaralı bölge, 5955-58, 6596, 6846-47, 6941, 7018, 8243) — sweep idle'a uygun
- `if(res?.ok===false)` ölü-kod kalıntıları (rpc throw kontratı; zararsız) — temizlik adayı
- index.html:2096 hata paneli self-XSS — ayrı tur
- B26 VARSAYILAN_HEKIM yapısal kırılganlığı — yalnız not
- CLAUDE.md:299 bayat — kullanıcı bizzat düzeltmeli (kural)
- GT gövde-level v5 regen — denetimli oturum (Idle-A yalnız audit üretir)

## 6b. İdle 1. Tur Sonucu + Düzeltme Turu (2026-09-01)

**3 worktree işi review + merge edildi (main `eb4a097`):** (A) rpc-reference 185 fn kanonik + GT v5
audit (22 sapma) + domain-rules 16 düzeltme + ui-map taze; (B) 13 E2E stub-backend kilit testi;
(C) toast kuyruğu (Aşama 3.4 DONE) + api.js 24 unit + benchmark kararı (§3.1: N>150 pagination,
N>500 virtual scroll). Review metodu: rapor iddiaları bağımsız doğrulandı (302 unit + 13 E2E docker'da
bizzat koşuldu, docs sayımla). Tek düzeltme: rpc-reference'taki bayat buildRpcParams iddiası (818a057).
Worktree/branch temizlendi; eski dokümanlar `.claude/archive/2026-09-01-pre-merge/`.

**Merge sonrası TDZ regresyon turu (`f1e6273..97bcd8b`):** WP-2'nin toplu `bugun()` değişimi 4 yerde
`const bugun = bugun()` üretmiş → 'Tedavi Günleri Yüklenemedi' crash + renderCaseTimeline now-cursor
sessiz kırık + bildirimKontrol sabah hatırlatması sessiz kırık. **Ders: toplu sed değişiminde yerel
değişken-gölgeleme taraması zorunlu** (`const X = X()` + bare-identifier taraması).

**Demo teşhisi (çözüm kullanıcıda):** demo projesi `vtzqjmazsvurxdeondmi` Supabase **free-tier
otomatik-pause**: DNS NXDOMAIN (prod 401-yeşil ile karşılaştırma), e2e worker'ın 540 ölçümüyle
tutarcı. ~7 gün inactivity → pause. Kod tarafı fix imkânsız; Supabase Dashboard → Restore.
Restore sonrası E2E'ler spec değişikliği olmadan gerçek demo'ya koşar (şimdilik
`PLAYWRIGHT_STUB_BACKEND=1`).

**hekim_listesi (açıklandı, aksiyon önerili):** app.js:28 loadHekimler → canlıda OLMAYAN
`hekim_listesi` RPC'sini çağırıyor → catch → config fallback. Modallar sorunsuz çünkü gerçek
yükleme `loadHekimlerFromDB` (IndexedDB ← `db.from('hekimler')` tablo okuması, app.js:614/627).
Ölü çağrı temizliği önerilir (loadHekimler'deki rpc dalı); RPC'yi canlıya geri yükleme gereksiz.

**Canlı UI doğrulaması (2026-09-01, KULLANICI):** kullanıcı tedavi modalı dahil tüm fix'leri
canlıda test etti — "fixed all". B20/B5/B34/B10 + TDZ fix'leri onaylandı. Kalan tek kullanıcı
aksiyonu: demo Supabase Restore (gerçek demo E2E önkoşulu).

## 7. İdle 2. Jenerasyon Planı (2026-09-01 — kuruldu, ateşlenmedi)

**Kaynak map:** §6 "Bilinçli kapsam dışı kalan" + ReFactorRoadmap BEKLİYOR satırları + GT v5 audit
(17 madde). Üç görev dosya-alanı ayrık; ortak guardrail'ler 1. turla aynı (Supabase çağrısı yok,
push yok, tek commit, rapor idle-reports'ta, çalışma dizini worktree).

| Görev | Worktree / branch | Alan | Kapsam |
|---|---|---|---|
| **kod-temizlik** | `idle/kod-temizlik` | js/ + index.html | B9 kalan iç escape noktaları (pattern ile bul — eski satır numaraları bayat: onclick-string'te esc, ham innerHTML interpolasyonu); ölü `if(res?.ok===false)`/`{error}` kalıntıları; hekim_listesi ölü rpc dalı temizliği (app.js loadHekimler → getData); index.html hata paneli `e.msg` escape'siz innerHTML (self-XSS) |
| **e2e-gercek** | `idle/e2e-gercek` | tests/ | mevcut e2e.spec.js navTo çift-`#` bug fix; mevcut suite'in (smoke/sablon/sutten-kes) demo-mode uyumu; demo Restore edilmişse GERÇEK demo koşumu, edilmediyse stub-backend; 1. tur spec'leriyle (stub) birlikte tam suite koşumu |
| **gt-taslak** | `idle/gt-taslak` | .claude/gt-v5-taslak/ | GT v5 audit'in 17 maddesini denetimli oturuma hazır pakete çevir: migration TASLAĞI (canlı imzalar + migrations/'tan derlenmiş gövdeler, DEPLOY EDİLMEDEN) + hekim_listesi karar belgesi (geri yükle seçeneği: 20260308000009:321 orijinali) + GT/rpc-reference fark matrisi. Canlı DB'ye dokunmaz; deploy denetimli oturumda |

Merge protokolü 1. turla aynı: worktree commit → orkestratör review → kullanıcı onayı → main merge.
Kod-temizlik ve gt-taslak her koşumda güvenli; e2e-gercek gerçek-demo modu Restore'a bağlı.

**2. jenerasyon koşum durumu (2026-09-02):** worktree'ler paralel oturumların main ilerlemesi
(ikiz+kupe, e6d8782) nedeniyle yeniden kuruldu; spec'lere delta notları eklendi.
- **gt-taslak: merge EDİLDİ** (1fe4dad) — subagent review PASS-WITH-NOTES; 15 gövdeli CREATE + 2
  stub + 2 ALTER; transkripsiyon bağımsız doğrulandı; 4 yeni delta sapması → regen kapsamı 21 madde;
  hekim_listesi öneri: temizleme. WARN (GRANT coverage) denetimli oturumda kapanır.
- **kod-temizlik: merge EDİLDİ** (ebe20aa) — subagent review PASS-WITH-NOTES; 14+ escape noktası
  doğrulandı (dataset deseni, çift-escape yok), ölü hata-kontrol kaldırımları güvenli (yalnız
  rpc()/rpcOptimistic() sonuçları), hekim_listesi IDB yoluna çevrildi, self-XSS kapandı;
  344/344 → merge sonrası main'de 362/362. Takip (sonraki tur): ham id'li onclick kalıntıları
  (ui.js:1102,4894), B8 try/catch eksikleri, helpers.js:90 yorum notu.
- **e2e-gercek: merge EDİLDİ** (46fbb4d → merge a71b7a0, pushlu, Pages yayında) — rapor: 5 koşum,
  final GERÇEK demo modunda 64/0/3 (workers=1). navTo çift-# fix (~30 test kurtuldu), IGNORED_LOCATIONS
  (agent-telemetry 404 + demo_sema_diff/hekim_listesi), DB doğrulamaları demo oturumuyla (anon GRANT kaybı O1),
  sutten-kes veri-agnostic, kritik-akis 2 gerekçeli skip (demo tohumlama_sonuc RPC eski — O2).
  Worktree + branch silindi; tüm idle worktree/branch'leri temiz.
- **3. tur revize zarfları ÜRETİLDİ VE SUBAGENTLARLA KOŞULDU (2026-09-02) — 5/5 MERGE EDİLDİ:**
  - **REV-3 ci-saglamlastirma** (merge a4f8e24): demo health-check + stub fallback + workers=1 tek job;
    actionlint temiz; DEMO_ANON_KEY secret'ı yoksa key'siz dal (401 = ayakta). İlk push'ta canlı doğrulanır.
  - **REV-4 sessiz-9999-analiz** (merge 7ac781d): öneri (a) COALESCE restore; taslak
    `.claude/draft-migrations/20260902000000_stat_suru_ozet_sessiz_coalesce.sql` (otomatik-deploy
    emniyeti için migrations/ DIŞINDA — deploy emrinde taşınır). Yeni bulgu: `sessiz_hayvanlar_reconcile`
    da bilinçli COALESCE'siz (NULL'lara vet-kontrol görevi üretilmez).
  - **REV-2 kod-temizlik-2** (merge f404208): B9 2. dilim ~22 dönüşüm (8 sembol), B8 7 fonksiyon try/catch,
    agent-telemetry tag kaldırıldı (kök neden: Gwen deney hattı kalıntısı, a7f42e4), seed_defaults RPC_TABLES'a
    eklendi (canlıdan doğrulandı: drug_classes YAZMIYOR — ui-altyapi varsayımı kısmen yanlıştı).
    Review APPROVE; merge'de planli-asi ile renderTask satırında çakışma → iki değişiklik birleştirildi.
  - **REV-5 sessiz-ui** (merge 7020e53): det'tan sessiz listesine scroll-korunumlu dönüş (closeDet flag-guard),
    gruplu liste (_sessizGrupla, 7 yeni test), Android geri sheet'i kapatır (B21 sözleşmesi korundu).
    Review APPROVE. Kullanıcı UX şikâyetinin fix'i.
  - **REV-1 demo-sync** (merge aa5ceb8): demo'ya 31 migration + FDW refresh + 1 hotfix-çakışma ön-adımı;
    gövde farkı 22→3; kritik-akis 2 skip açıldı + B20 gizli hatası (navTo eksik) fix;
    GERÇEK demo koşumu **66/0/1**. **Önemli bulgular:** prod `gorev_tamamla`'da repoda olmayan dosyasız
    ASI_PLANLI muafiyet hotfix'i (GT regen kapsamına eklendi); demo'da prod'da olmayan 3 legacy fn;
    20260730000002 versiyon çakışması (2 dosya); "3 tablo drift" uyarısının kaynağı prod'dan silinmiş
    hayalet view'lar. **O1 önerisi: demo anon GRANT restore EDİLMESİN** (yalnız authenticated kalsın).
  Kullanıcı kararı bekleyenler: 9999 taslağı deploy emri, O1 onayı, GT v5 denetimli regen oturumu
  (artı REV-1 drift bulguları), CLAUDE.md:299.

## 7. Kabul Kriterleri (orijinal plan)

- [x] P0–P3 tamam; 6f3aa13 pushed; indeks taze; B7 canlıda net (mevcut); snapshot alınmış
- [x] WP-1…WP-9 + WP-D commit+push; 265 unit test yeşil
- [x] Karar 1–2 kullanıcı cevabı işlenmiş (B1 public-by-design + tablo-trigger guard'ları deploy)
- [x] 3 idle worktree açılmış + her birine görev spec'i (IDLE-GOREV.md) yerleştirilmiş
- [x] Bu dosya ilerleme işaretli; memory güncellendi
