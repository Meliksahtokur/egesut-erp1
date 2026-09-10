# Toplu Vaka Aç — Implementation Plan (G-20260906-TOPLU-VAKA)

> **Tarih:** 2026-09-06 · **Worktree:** `/home/melik/egesut-wt/toplu-vaka` · **Branch:** `idle/toplu-vaka`
> **Design brief:** owner onaylı 2026-09-06. Pattern refs: FORM-SUBMIT-01, MODAL-ROUTER-01, RPC-WRITE-01, TESTING-01 (`.harness/patterns/`).
> **Test komutu (worktree'de node_modules YOK):** `NODE_PATH=/home/melik/egesut-erp1/node_modules node --test tests/unit/*.test.js`
> **Referans plan tonu/ritüeli:** `.claude/plans/2026-09-01-buzagi-kupe-revizyon-impl.md`, `.claude/plans/2026-08-31-fix-roadmap-ve-idle-omurgasi.md`

**Goal:** Tek akışta N hayvana aynı vakayı aç: normal Vaka Aç (m-disease) akışının birebir kopyası + küpe çoklu-giriş (autocomplete + chip + paste), şablon tüm hayvanlara özdeş uygulanır. RPC: `vaka_toplu_ac(p_animal_ids text[], p_disease_id uuid, p_sablon_id uuid DEFAULT NULL, p_notes text DEFAULT NULL) → jsonb`.

## Bulunmuş Konvansiyonlar (STEP 1 kanıtları — plan buna uyar)

| Konu | Konvansiyon | Kanıt |
|---|---|---|
| **GT güncelleme** | RPC ekleyen/değiştiren migration commit'i **aynı commit'te** `supabase/migrations/99999999999999_ground_truth.sql`'i de günceller. Trigger-only migration GT dokunmaz. `rpc-reference.md` sync'i ayrı docs commit'i olabildiği gibi aynı commit'te de olur. | `85a6762` (migration+GT), `8a77888` (migration+GT), `5c3bfd0` (migration+GT+test.sql), `3f1e57f` (docs GT sync + rpc-reference), `690b089` (trigger-only, GT yok) |
| **Lokal serve** | Worktree'de `python3 -m http.server <ad-hoc port>` + tarayıcı Console'da `localStorage.EGESUT_DEMO='1'` → demo mod. Ana repoda `npm run serve:local` (= `python3 -m http.server 8080`, `test:local` bunu kullanır). | `.claude/idle-reports/2026-09-02-t3-suruden-cikan-filtre.md` §5; `package.json:19-21` |
| **Unit test** | `tests/unit/support/loadModule.js` vm loader: `loadBrowserModule('js/....js', {extra, dom})` + `makeDomStub().__setEl` + `makeDbStub(rpcHandlers)`; test dosyası başında sözleşme yorumu; `node --test`. Form-mantık örnekleri: `tests/unit/ac-hayvan.test.js` (autocomplete sandbox deseni), `tests/unit/forms-validation.test.js` (rpc mock'lu form akışı). | `tests/unit/support/loadModule.js:112-122` |
| **rpc() kontratı** | `rpc()` hata + `ok:false` gövdesinde **throw** eder (`err.data` taşır) → çağıran tarafında `if (!res.ok)` **ölü koddur**; `try/catch` + `getUserMessage(e)` deseni kullanılır. | `js/api.js:66-90`, `js/forms.js:592` yorumu |
| **Olay bağlama** | `registerActions` map'i (`js/utils/events.js:10`) + HTML'de `data-action` / `data-input` / `data-change` / `data-keydown` delegasyonu. Dinamik satırlarda **dataset + escAttr** — interpole string onclick YASAK. | `js/utils/events.js:24-47`, `js/utils/handlers.js` |
| **Migration ritüeli** | `BEGIN; ... NOTIFY pgrst, 'reload schema'; COMMIT;` + `GRANT EXECUTE ... TO anon, authenticated`. | GT bölümleri, `GT:4873` |

## Sabit Kurallar (tüm fazlar)

1. **PROD'e yazma YOK.** PROD'e yalnız salt-okunur şema probe'u (Phase 0); PROD migration/deploy **yalnız owner onayıyla, owner-gated**. Demo migration serbest.
2. **Demo DB satırları owner verisidir** — smoke/E2E'nin ürettiği vaka satırları silinmez; üretilen kayıt id'leri raporlanır.
3. Dinamik onclick'te interpole string yok: `data-action`/`data-input`/`data-keydown`/`data-change` + `el.dataset` (ESC-attr deseni).
4. `if (!res.ok)` yazılmaz — `rpc()` throw eder; `try/catch` + `toast(getUserMessage(e), true)`.
5. **m-disease (tek) akışı %100 değişmez** — her refactor varsayılan parametreyle eski davranışı korur; faz sonu regresyonu: tek Vaka Aç şablonlu + şabonsuz hâlâ çalışır.
6. Kapsam dışı (bu plan): matrix paneli, padok/filtre sekmeleri, süt yasağı, `bulk_ilac` çift-düşüm bug'ı (ayrı ertelenmiş iş).
7. Offline: özellik **online-only** (`navigator.onLine` guard, submitCase ile aynı).

---

## Phase 0 — Ön kontroller (root; kod YOK, salt-okunur)

### 0a. GitNexus impact pre-check — `repo: "egesut-erp1"` paramı ZORUNLU (iki repo indeksli)

`mcp__gitnexus__impact` (direction: upstream) şu sembollere — 2026-09-06'da root tarafından doğrulandı:

| Sembol | Konum | Beklenen (ölçülmüş) |
|---|---|---|
| `_renderSablonSecim` | js/forms.js:555 | **LOW**, 1 direkt çağıran (onDiseaseSelect) — container-parametrize refactor |
| `onDiseaseSelect` | js/forms.js:541 | **LOW**, 1 direkt çağıran — `bc-disease-id` için yeniden kullanım |
| `loadDiseasesDropdown` | js/forms.js:496 | `d-disease-id` hardcoded — container-parametrize edilecek; çağıranlarını listele |
| `acHayvan` | js/ui.js:7057 | **MEDIUM**, 9 direkt çağıran — tek-select kullanımları kırılmamalı; test kilidi: `tests/unit/ac-hayvan.test.js` |
| `openM` | js/utils/modal.js:4 | Ambiguous → `target_uid: "Function:js/utils/modal.js:openM"` ile sor; reset hook ekleniyor |
| `submitCase` | js/forms.js:583 | **DEĞİŞTİRİLMİYOR** — yalnız akış şablonu; impact-check referans |
| `RPC_TABLES` / `pullTables` | js/api.js:293 / :392 | RPC-WRITE-01 wrap zinciri; kayıt ekleme |

Sonuçlar goal raporuna işlenir. MEDIUM çıkan tek nokta `acHayvan` — faz 3'te regrosyon testi zorunlu.

### 0b. Canlı şema salt-okunur probe checklist (PROD — okuma YAZMA yok)

SQL console / read-only bağlantı ile (`pg_get_functiondef`, `pg_proc`):

1. `create_case(text, uuid, text)` imzası + gövde = GT:3569 birebir mi? (guard'lar: aktif hayvan, hastalık var, dup aktif vaka, `islem_log VAKA_ACILDI` snapshot GT:3605-3619)
2. `tedavi_sablon_uygula(uuid, uuid)` var + imza (GT:4802 ile kıyas)
3. `tedavi_sablon_tohumlama_gorev_ekle` var mı? (**GT'de yok** — canlıdan doğrulanmalı; yoksa bulk RPC'nin şablon dalında bu çağrı opsiyonelleşir ve rapora düşer)
4. `_tohumlama_gorev_uygunluk` **GT'de yok** (`.harness/references/rpc-reference.md` "Internal Helper'lar" bölümü flag'li) — canlıda var mı/not al
5. `add_drug_administration` imza paritesi (GT:893: `p_day_id uuid, p_drug_product_id uuid, p_stok_id text, p_dose numeric, p_unit text, p_route text DEFAULT NULL`)

**Bulgu protokolü:** Sapma varsa Phase 1 migration'ı canlı imzaya göre düzelt; PROD migration YOK (owner-gated), demo serbest.

**Phase 0 doğrulama:** Impact tablosu goal raporunda; probe çıktıları `.claude/idle-reports/` veya goal raporuna not; demo proje sağlıklı mı (free-tier auto-pause riski — DNS/health check; pause'luysa owner Supabase Dashboard → Restore, kanıt: 2026-08-31 raporu).

---

## Phase 1 — Migration: `supabase/migrations/20260906120000_vaka_toplu_ac.sql` (+ GT, aynı commit)

**Dispatch:** subagent **W1** (worktree'de; yalnız `supabase/migrations/*`).

`BEGIN; ... NOTIFY pgrst, 'reload schema'; COMMIT;` içinde:

1. **`_vaka_ac_tek` helper (internal):** GT:3569'daki kanonik `create_case` gövdesini **birebir** taşı — davranış-özdeş zorunlu: aktif-hayvan guard, hastalık guard, dup-aktif-vaka guard, `cases` INSERT ve **`islem_log VAKA_ACILDI` geri_al snapshot'ı** (GT:3605-3619 aynen; `geri_al` bu snapshot'ı tüketiyor — bozulursa undo kırılır). RETURN: `{ok:true, case_id}` / `{ok:false, mesaj}` (jsonb).
2. **`create_case` = ince wrapper:** imza/değer return değişmez (`SELECT public._vaka_ac_tek(p_animal_id, p_disease_id, p_notes)`). Neden: tek-vaka akışı + `_asistan_step_calistir` (GT:373 `create_case` çağırıyor) ve GT `DROP FUNCTION IF EXISTS public.create_case(text, uuid, text)` bloğu geçerli kalsın.
3. **`vaka_toplu_ac`:**
   ```sql
   CREATE OR REPLACE FUNCTION public.vaka_toplu_ac(
     p_animal_ids text[], p_disease_id uuid,
     p_sablon_id uuid DEFAULT NULL, p_notes text DEFAULT NULL)
   RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
   ```
   - Giriş guard: `p_animal_ids IS NULL OR array_length(...)=0` → `{ok:false, mesaj:'Hayvan listesi boş'}`; `cardinality(p_animal_ids) > 200` → `{ok:false, mesaj:'En fazla 200 hayvan'}`. Dup id girdide dedupe (sayı `toplam`a dedupe sonrası yazılır).
   - Döngü: her id için `_vaka_ac_tek`; `{ok:false}` → `atlanan := atlanan || jsonb_build_array(jsonb_build_object('kupe', <kupe>, 'mesaj', mesaj))` (dup-aktif-vaka buraya düşer — **server guard değişmez**, per-hayvan atlanır, işlem devam); exception → `hatalar` aynı yapıda. `ok:true` + şablon seçiliyse: `tedavi_sablon_uygula(p_case_id, p_sablon_id)` (+ canlıda varsa `tedavi_sablon_tohumlama_gorev_ekle`; Phase 0 bulgusuna göre) — şablon hatası tek hayvanı `hatalar`'a düşürür, döngü sürer.
   - Return: `{ok:true, toplam, basari, atlanan:[{kupe,mesaj}], hatalar:[{kupe,mesaj}]}` — `kupe` alanı `hayvanlar.kupe_no`'dan çözülür.
   - `GRANT EXECUTE ON FUNCTION public.vaka_toplu_ac(text[], uuid, uuid, text) TO anon, authenticated;` (+ `_vaka_ac_tek` için GRANT YOK — internal, `SECURITY DEFINER` sahibi çağırır).
4. **GT güncellemesi (AYNI COMMIT):** `99999999999999_ground_truth.sql`'e `_vaka_ac_tek` + `vaka_toplu_ac` bölümleri ekle, `create_case` gövdesini wrapper'la değiştir (konvansiyon: `85a6762`/`8a77888` deseni). `rpc-reference.md` satırı Phase 7 docs commit'inde (izin verilen varyant: `3f1e57f`).

**Doğrulama (demo DB — serbest):**
- Demo'ya uygula (tools-bank supabase MCP / demo konsol).
- Demo SQL console: `SELECT proname, pg_get_function_arguments(oid) FROM pg_proc WHERE proname IN ('vaka_toplu_ac','_vaka_ac_tek','create_case');` — imzalar tam.
- `SELECT has_function_privilege('anon','public.vaka_toplu_ac(text[],uuid,uuid,text)','execute'), has_function_privilege('authenticated', ... );` — ikisi de `t`.
- **create_case regresyon smoke (demo):** aktif demo hayvanı + demo hastalık ile `SELECT public.create_case(...);` → `ok:true`; **üretilen case_id rapora yazılır** (owner verisi — silinmez).
-Commit: `feat(db): vaka_toplu_ac RPC — create_case→_vaka_ac_tek refactor + GT sync`

---

## Phase 2 — `js/api.js` RPC_TABLES kaydı

**Dispatch:** W1 (Phase 1 ile aynı ajan, minik).

- `js/api.js:293` `RPC_TABLES`'a: `vaka_toplu_ac: ['cases','diseases','drugs','kizginlik_log','islem_log','treatment_days','treatment_day_uygulamalar','drug_administrations','stok','stok_hareket','gorev_log'],` (submitCase:612 pull setinin aynısı — RPC-WRITE-01).
- Doğrulama: `npm run test:unit` (ana repo) / worktree NODE_PATH komutu — mevcut api.test.js yeşil.
- Commit: `feat(api): RPC_TABLES — vaka_toplu_ac pull seti`

---

## Phase 3 — UI: modal, tile, form mantığı, handler'lar

**Dispatch:** subagent **W2** (W1 ile **paralel** — dosya alanları ayrık: W1=SQL+api.js satırı, W2=index.html+forms.js+ui.js+utils/*).

### 3a. `index.html`
- **Modal `m-bulk-case`:** m-disease bloğunun (index.html:1089-1122) kopyası, `bc-` önekli — index.html'de `bc-` çakışması YOK (doğrulandı). Farklar:
  - Küpe alanı: `bc-hid` input + `ac-bhid` dropdown + **chip satırı** (`bc-chips`) + **paste textarea** (`bc-paste`, `data-input="bc-paste"`, placeholder "Küpe listesi — satır/virgül/noktalı virgül ile") + sayaç (`bc-count`).
  - `bc-disease-id` select `data-change="bc-disease-select"`; `bc-sablon-blok`/`bc-sablon-list`; `bc-case-notes`; `bc-hekim` select; butonlar `data-action="submit-bulk-case"` / `close-bulk-case` (+ sonuç alanı `bc-sonuc`).
  - Tüm id/atır interpolasyonu escAttr ile; mevcut CSS sınıfları (`mo/modal/fg/flbl/fi/fsel/btn/ac-box`) — yeni ağır stil YOK.
- **Tile:** index.html:747 `open-disease-modal` (Vaka Aç) tile'ının **kardeşi** olarak `data-action="open-bulk-case"` tile'ı (ikon 🏥🏥 deseni — `open-bulk-vaccine` :752 gibi; `pg-log` sayfası).

### 3b. `js/forms.js` — container-parametrize refactor (m-disease davranışı %100 korunur)
- `_renderSablonSecim(diseaseId, opts={})`: blok/list/radio-name parametrik — default `d-sablon-blok`/`d-sablon-list`/`d-sablon` (mevcut); bulk `bc-sablon-blok`/`bc-sablon-list`/`bc-sablon`. Radio onchange hedefi de parametrik: default `globalThis._seciliSablonId` (submitCase aynen), bulk `globalThis._bcSeciliSablonId`. **Default "Şablonsuz"** radio checked kuralı aynen (forms.js:573-575).
- `onDiseaseSelect(selId='d-disease-id')`: kategori etiketi + şablon render'ı parametrik; `disease-select` handler argsız çağırır → m-disease aynı.
- `loadDiseasesDropdown(selId='d-disease-id')` (forms.js:496): select hedefi parametrik; bulk açılışında `loadDiseasesDropdown('bc-disease-id')`.
- Yeni `submitBulkCase(btn)` iskeletini 3c'ye bırak; burada yalnız form okuma yardımcıları.

### 3c. `js/utils/handlers.js` + `js/utils/modal.js`
- ACTIONS: `'open-bulk-case': () => openM('m-bulk-case')` (:121 deseni), `'close-bulk-case': () => closeM('m-bulk-case')`, `'submit-bulk-case': (el) => submitBulkCase(el)` (:204 deseni), `'bc-disease-select': () => onDiseaseSelect('bc-disease-id')`, `'bc-paste': () => bcPasteEkle()`, chip ekle/temizle aksiyonları (`bc-chip-ekle`, `bc-chip-sil` — `el.dataset.kupe`).
- `openM` reset hook (modal.js:4, `m-disease` hook deseni — :48-53): `m-bulk-case` için chips/notes/paste temizle, `_bcSeciliSablonId=null`, `bc-sonuc` gizle, `loadDiseasesDropdown('bc-disease-id')`, `bc-disease-cat` gizle. Hekim: `bc-hekim`'i `populateHekimSelects` listesine ekle (js/app.js:187).
- Klavye: `bc-hid`'e `data-keydown="bc-keydown"` (Enter → chip ekle; `acNav` autocomplete gezinme aynen `disease-keydown` :201-203 deseni).

### 3d. `js/ui.js` — acHayvan çoklu-giriş uzantısı
- `acHayvan` kaynak dalına `ac-bhid` ekle (ui.js:7067 deseni): `src = _activeAnimalsOnly()` (ui.js:7053).
- Satır tıklaması bulk dalında chip ekler: `ac-bhid` satırları `data-kupe` + `data-action` delegasyonuyla `bcSecHayvan(kupe)` çağırır (interpole onclick YOK; mevcut satır deseni dataset.kupe kullanıyor — ui.js:7097). `selHayvan` (tek-select) **hiç dokunulmaz**; `ac-dhid`/`ac-ihid`/`ac-khid` dalları aynen.
- Doğrulama: `NODE_PATH=... node --test tests/unit/ac-hayvan.test.js` yeşil (tek-select kilidi) + elle: d-hid autocomplete davranışı değişmedi.
- Commit: `feat(ui): m-bulk-case modalı + tile + bc-* form mantığı (G-20260906-TOPLU-VAKA)`

---

## Phase 4 — Mükerrer ön-kontrol + toplu submit + sonuç render

**Dispatch:** subagent **W3** (W2'den **sonra** — aynı dosyalar: forms.js, handlers.js).

1. **Mükerrer ön-kontrol (UI):** seçili hayvan id'leri × `bc-disease-id` × `status='active'` sorgusu IndexedDB `cases` üzerinden (`idbGetAll('cases')` — forms.js:561 `idbGetAll` deseni). Eşleşenleri `openConfirm('Mükerrer Vaka', '<liste> zaten aktif — atlanacak, devam?', ...)` ile göster (js/ui.js:1076 deseni). Server guard'a dokunulmaz — çifte emniyet.
2. **`submitBulkCase(btn)`** (FORM-SUBMIT-01 zinciri, submitCase:583 aynası):
   - `navigator.onLine` guard (online-only) → chip listesi boş/hastalık boş guard → **tek** `rpc('vaka_toplu_ac', {p_animal_ids, p_disease_id, p_sablon_id: _bcSeciliSablonId||null, p_notes})` → `try/catch` + `toast(getUserMessage(e), true)` (`if (!res.ok)` YASAK — rpc throw eder).
   - Sonuç render `bc-sonuc`: `basari` adet + atlanan/hatalar satır satır **kırmızı**, başarılı hayvanlar **yeşil** özet (kupe bazlı satır haritası: atlanan+başarı listesi).
   - `pullTables(['cases','diseases','drugs','kizginlik_log','islem_log','treatment_days','treatment_day_uygulamalar','drug_administrations','stok','stok_hareket','gorev_log'])` + `_drugsCache=[]; loadDrugsCache();` (submitCase:612-614 deseni). openDet/openCaseDet **yok** (N hayvan — özet ekranı yeter).
   - 200 limiti UI'da da: >200 chip'te submit engel + uyarı.
3. Commit: `feat(vaka): mükerrer ön-kontrol + submitBulkCase + sonuç render`

---

## Phase 5 — Unit testler (RED-FIRST, TESTING-01)

**Dispatch:** subagent **W4** (W3'ten sonra). Yeni dosya: `tests/unit/toplu-vaka.test.js` — `loadModule.js` konvansiyonu; örnekler: `ac-hayvan.test.js` (sandbox+`__setEl`), `forms-validation.test.js` (rpc mock — `makeDbStub` **throw eden** stub: rpc failure = reject, `ok:false` response DEĞİL).

**Sıra:** (1) saf helper'ları planla → testleri yaz → **FAIL gör**; (2) Phase 4 inline mantığını saf fonksiyonlara çek (forms.js üst-seviye `function`, vm loader görür) → **PASS**:

- `bcKupeParse(metin)`: newline/virgül/noktalı virgül ayrımı, trim, boş at, dedupe (string eşleşme — `02`≠`2` normalizasyon YOK, domain kuralı).
- `bcChipEkle/bcChipSil`: ekleme, dedupe, sayaç; chip silme listeden düşer.
- `bcCozumle(girilen, animals)`: küpe→id çözümü, **çözülemeyenler kırmızı liste** olarak ayrışır (aktif-önce: `hayvanByKupeRef` sözleşmesi).
- `bcMukerrerFiltre(ids, cases, diseaseId)`: `status='active'` + disease eşleşenleri ayırır.
- `bcSonucSatirlari(res)`: `atlanan` vs başarı satır haritası (render mapping — DOM stub ile `bc-sonuc` innerHTML iddiası).
- Regresyon kilidi: `ac-hayvan.test.js` ve mevcut tüm suite yeşil kalır (`m-disease` akışı değişmedi kanıtı).

**Doğrulama:** `NODE_PATH=/home/melik/egesut-erp1/node_modules node --test tests/unit/*.test.js` → tümü PASS (önce kırmızı kanıtı raporda).
Commit: `test(toplu-vaka): bc saf helper'lar — parse/chip/mükerrer/sonuc haritası (RED→GREEN)`

---

## Phase 6 — Demo migration + lokal serve + manuel E2E

**Dispatch:** W1 demo apply; serve + E2E checklist'i **root çalıştırır, owner doğrular**.

1. Demo health check (free-tier pause riski) → gerekirse owner Restore. Demo'ya `20260906120000_vaka_toplu_ac.sql` uygula (agent serbest).
2. Serve (konvansiyon): `cd /home/melik/egesut-wt/toplu-vaka && python3 -m http.server 8093` → tarayıcı Console: `localStorage.EGESUT_DEMO='1'`.
3. **Manuel E2E checklist:**
   - [ ] Dashboard'da yeni tile → modal açılır; ESC/geri tuşu modalı kapatır (MODAL-ROUTER-01).
   - [ ] Autocomplete ile 2 küpe chip + paste kutusuyla 3 küpe (satır/virgül/noktalı virgül karışık) — sayaç 5; tekrar aynı küpe → dedupe.
   - [ ] Çözülemeyen küpe kırmızı listede; mükerrer aktif-vakalı hayvan openConfirm'de listelenir, devamda sonuçta atlanan satırı.
   - [ ] Şablonlu hastalık akışı: şablon radio'ları bc-sablon-list'te, default "Şablonsuz"; şablonlu submit → tüm başarılı hayvanlara treatment_days + stok_hareket **her ilaç × her hayvan için tam 1 kayıt** (serbest düşüm — demo SQL console ile sayım).
   - [ ] Şablonsuz akış: sadece vakalar açılır.
   - [ ] Sonuç ekranı: yeşil/kırmızı satırlar; modal kapanınca liste temiz başlar.
   - [ ] **Regresyon:** tek Vaka Aç (m-disease) şablonlu + şablonsuz hâlâ çalışır; `geri_al` ile E2E'de açılan vakalardan biri geri alınır (islem_log VAKA_ACILDI snapshot'ı çalışıyor).
   - [ ] Üretilen tüm demo kayıt id'leri rapora yazılır (owner verisi).
4. Commit (varsa küçük fix'ler ayrı): `fix(toplu-vaka): E2E bulguları`

---

## Phase 7 — Root review + kapanış (owner-gated)

1. Root review: `git -C /home/melik/egesut-wt/toplu-vaka diff --stat main...` → hedefli diff okuma; her fazın doğrulama kanıtı.
2. `mcp__gitnexus__detect_changes` — **`worktree: "/home/melik/egesut-wt/toplu-vaka"`** paramıyla (server ana repodan çalışıyor), scope `all`; beklenmeyen etkilenen akış yoksa devam.
3. `rpc-reference.md` + (gerekirse) `ui-map.md`/`domain-rules.md` sync commit'i: `docs(toplu-vaka): rpc-reference — vaka_toplu_ac/_vaka_ac_tek`.
4. Goal checkpoint/rapor: `.harness/reports/2026/G-20260906-TOPLU-VAKA.md` güncelle (faz kanıtları, Phase 0 probe bulguları, demo smoke id'leri).
5. **Owner gates:** merge `idle/toplu-vaka` → `main` + push (Pages yayını), PROD migration deploy — **hepsi yalnız owner onayıyla**. Merge sonrası worktree/branch temizliği.

## Dispatch Map (özet)

| Faz | Ajan | Zamanlama | Root arası review |
|---|---|---|---|
| 0 | root (salt-okunur) | ilk | — (bulgular goal raporuna) |
| 1+2 | W1 (db) | W2 ile paralel | migration+GT diff, demo imza/GRANT çıktısı |
| 3 | W2 (ui) | W1 ile paralel | ac-hayvan test kilidi + tek-vaka regresyon |
| 4 | W3 (flow) | W2 sonrası sıralı | submit akışı + RPC_TABLES tutarlılığı |
| 5 | W4 (test) | W3 sonrası sıralı | RED kanıtı + full suite yeşil |
| 6 | W1 apply + root | W4 sonrası | E2E checklist işaretli |
| 7 | root | en son | — (owner onayına sunum) |

## Rollback

- SQL: `DROP FUNCTION IF EXISTS public.vaka_toplu_ac(text[], uuid, uuid, text);` + `create_case`'i GT:3569 gövdesiyle `CREATE OR REPLACE` (wrapper geri alınabilir).
- JS: merge revert; GT satırları revert'lenebilir (migration+GT aynı commit → tek revert).

## Root'un Faz 0'dan Önce Kararlayacağı Açık Sorular

1. **PROD probe erişim yolu:** Salt-okunur SQL probe'unu (0b) kim/how çalıştıracak — agent (tools-bank supabase read key) mı, yoksa owner mı konsoldan koşup çıktıyı mı verecek? (PROD'e yazma yok kuralı değişmez.)
2. **Goal dosyası:** `.harness/goals/2026/G-20260906-TOPLU-VAKA.md` repo'da görünmüyor (son goal'ler G-20260903-*) — Full mode sözleşmesi "yazmadan önce aktif goal'ı oku" dediğinden root ya dosyayı oluşturmalı ya da brief'in goal id'siyle var olduğunu teyit etmeli.
3. **Demo apply exactörü:** Migration'ı agent mı uygulayacak (tools-bank supabase, demo projesi) yoksa owner mı? Ayrıca demo free-tier pause ise owner Restore aksiyonu Phase 6 öncesinde.
4. **Demo smoke satırları:** Phase 1 smoke + Phase 6 E2E'nin açtığı vaka satırları owner verisi olarak kalır (silme onaysız yasak) — owner bu kayıtların demo'da kalmasını önceden onaylar.
