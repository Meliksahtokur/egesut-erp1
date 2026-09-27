# F1 Çoklu Kaydırma — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Görevler ekranında çoklu seçilen tedavi görevlerinin bağlı aktif vakalarını tek işlemde +N gün kaydırmak (DB çoklu RPC + checkbox UI).

**Architecture:** Yeni SECDEF RPC `vaka_kalan_gunleri_kaydir_coklu(p_gorev_ids uuid[], p_gun int)` — görev→vaka çözümlemesini DB'de yapar, dedup eder, her vaka için MEVCUT tekli `vaka_kalan_gunleri_kaydir`'ı çağırır (gövde kopyası yok), partial-success jsonb döner. UI: Görevler ekranında açık TEDAVI_GUN/SEANS kartlarına checkbox + seçim çubuğu + confirm + bantlı sonuç (vaka_toplu_ac/bcSonucBantlari deseni).

**Tech Stack:** PostgreSQL (SECDEF plpgsql RPC), Vanilla JS (ui/forms/api), node --test unit, Playwright (yalnız glmf demo kapısında).

**Spec:** `docs/plans/2026-09-27-coklu-kaydirma-SPEC.md` (bu plan spec'i uygular; spec ile çelişkide spec kazanır → dur, sor).

## Global Constraints

- Business rules DB'de kalır; frontend raw SQL YAZMAZ, yalnız RPC çağırır (AGENTS.md invariant).
- Yeni RPC: `REVOKE ALL ... FROM PUBLIC, anon` + `GRANT EXECUTE ... TO authenticated` ZORUNLU.
- Client-side kural/çözümleme kopyası YASAK — görev→vaka çözümü DB'de.
- Çevrimdışında çubuk gizli, tetiklenirse RPC ÇAĞRILMAZ (E6 kuralı).
- HTML'e değer gömme yok; dataset taşıması (escAttr-inline yasağı).
- `?v=` damga index.html'de TEK değer (güncel değerden +1, tüm referanslar aynı anda); damga testleri **değer-bağımsız** tek-ayrık-değer iddiasına çevrilir (Task 5 sweep — plan-review Critical fix).
- SQL task adımlarında lokal-PG davranış duman testi ZORUNLU adımdır (db-validate yalnız statik kapı — davranış koşmaz; Task 1'de implementer uyguladı, kalıcı kural).
- Migration dosya adı: `supabase/migrations/20260927000001_vaka_kalan_gunleri_kaydir_coklu.sql`.
- Mevcut tekli RPC `vaka_kalan_gunleri_kaydir` gövdesi DEĞİŞMEZ (S2 kırmızı çizgi).
- Unit testler prod/demo DB'ye DOKUNMAZ (mock/pure JS); `node --test tests/unit/*.test.js`.
- Türkçe UI metinleri; mevcut modal/router pattern'leri korunur.

## Review Focus

1. **Dedup hatası:** Aynı vakaya bağlı 2 görev seçilirse vaka İKİ KEZ kayarsa zincir bozulur → beklenen: tek kaydırma, `detaylar`'da 1 satır. (Test: Task 4 band + Task 1 SQL dedup)
2. **Sessiz başarı:** Kapalı/çözülemeyen vakaya bağlı görev seçilirse kaybolursa kullanıcı fark etmez → beklenen: `hatalar`/`atlanan` listesinde görünür satır. (Test: Task 1 + Task 4)
3. **Çift-gönderim:** Bant gösterilmeden ikinci tık = ikinci +N → beklenen: onaydan bandın kapanışına kadar buton `disabled`. (Test: Task 4)
4. **Çevrimdışı sızıntı:** offline'da RPC çağrılırsa yarım kaydırma riski → beklenen: çağrı yok + toast. (Test: Task 4)
5. **Tekli-buton regresyonu:** mevcut `cdKaydirAc` akışı bozulursa prod akışı kırılır → beklenen: mevcut erteleme-kaydir-ui.test.js aynen PASS. (Test: Task 6 tam koşum)

---

### Task 1: DB — `vaka_kalan_gunleri_kaydir_coklu` migration

**Files:**
- Create: `supabase/migrations/20260927000001_vaka_kalan_gunleri_kaydir_coklu.sql`

**Interfaces:**
- Consumes: `public.vaka_kalan_gunleri_kaydir(p_case_id uuid, p_gun integer)` (mevcut, DEĞİŞMEZ — 20260925100001)
- Produces: `public.vaka_kalan_gunleri_kaydir_coklu(p_gorev_ids uuid[], p_gun integer) RETURNS jsonb` →
  `{ok: true, toplam: int, kaydirilan: int, atlanan: int, hatalar: [{gorev_id?, case_id?, sebep: text}], detaylar: [{case_id, ilk_tarih, son_tarih, tasinan_gun_satiri, tasinan_gorev, tasinan_seans, tasinan_uygulama_satiri, tai}]}`

- [x] **Step 1: Migration dosyasını yaz** — yapı: `BEGIN; SET LOCAL lock_timeout='5s'; SET LOCAL statement_timeout='30s';` … `COMMIT;`. Gövde:
  1. Fail-fast guard'lar: `p_gorev_ids IS NULL OR array_length(...,1) IS NULL` → `RAISE EXCEPTION 'VAKA_KAYDIRILAMAZ:%', jsonb_build_object('sebep','BOS_LISTE')`; `p_gun IS NULL OR p_gun < 1 OR p_gun > 31` → `GECERSIZ_GUN`; `cardinality(p_gorev_ids) > 200` → `LIMIT_ASIM`.
  2. Geçici tabloya (veya CTE) DISTINCT sıralı çözümleme: her `gorev_id` için `LEFT JOIN public.gorev_log g ON g.id = gid AND g.gorev_tipi IN ('TEDAVI_GUN','TEDAVI_SEANS') AND COALESCE(g.tamamlandi,false)=false AND COALESCE(g.iptal,false)=false AND left(g.aciklama,1)='{'` → `public.treatment_days td ON td.id::text = g.aciklama::jsonb->>'day_id'` → `case_id`. Çözülemeyen her görev → `hatalar` dizisine `{gorev_id, sebep:'GOREV_CÖZÜLEMEDI'}` (ASCII başlık: `GOREV_COZULEMEDI`).
  3. DISTINCT sıralı vaka kümesi üzerinde döngü: `BEGIN … PERFORM public.vaka_kalan_gunleri_kaydir(v_case_id, p_gun) … EXCEPTION WHEN OTHERS THEN hatalar += {case_id, sebep: SQLERRM} END;` — başarılıysa dönen jsonb `detaylar`'a eklenir, `kaydirilan++`; `VAKA_ACIK_DEGIL` yakalanan → `atlanan++`.
  4. Audit: tek `islem_log` kaydı, tip `'VAKA_KAYDIR_TOPLU'`, `ref_tablo 'cases'`, payload: toplam/kaydirilan/atlanan/hatalar + p_gun. (vaka-başına VAKA_KAYDIR iç RPC'den gelir — ikinci kez yazma.)
  5. Dönüş jsonb (Interfaces'taki şema).
  6. Kapı: `REVOKE ALL ON FUNCTION … FROM PUBLIC, anon; GRANT EXECUTE … TO authenticated;`
  Başlık yorumu: amaç, kapsam, geri-alma (`DROP FUNCTION …` — veri yazmaz, tekli RPC veriyi taşır), kaynak spec/plan yolu.

- [x] **Step 2: db-validate kapısını koştur**

Run: `bash scripts/db-validate.sh supabase/migrations/20260927000001_vaka_kalan_gunleri_kaydir_coklu.sql` (betiğin gerçek çağrı biçimi `scripts/db-validate.sh --help`'ten; --priors bayrağı varsa kullan)
Expected: `PASS` + rapor `reports/db-validation-2026-09-27-*.md`. FAIL → düzelt, tekrar koştur.

- [x] **Step 3: Commit**

```bash
git add supabase/migrations/20260927000001_vaka_kalan_gunleri_kaydir_coklu.sql reports/db-validation-2026-09-27-*.md
git commit -m "feat(db): vaka_kalan_gunleri_kaydir_coklu — gorev listesinden coklu vaka +N kaydirma (partial success)"
```

### Task 2: api.js — RPC erişimi + pull seti

**Files:**
- Modify: `js/api.js` (RPC_INVALidation_MAP bloğu ~315-351 ve RPC çağrı yardımcılarının bulunduğu bölüm)
- Test: `tests/unit/coklu-kaydir-ui.test.js` (Create — Task 3/4 de bu dosyaya ekler)

**Interfaces:**
- Consumes: Task 1 RPC imzası.
- Produces: `apiCokluKaydir(gorevIds, gun) → Promise<{ok, toplam, kaydirilan, atlanan, hatalar, detaylar}>` — mevcut RPC çağırma pattern'iyle AYNI biçimde (submitBulkCase'in `vaka_toplu_ac` çağrısı forms.js:2615 hangi yardımcıyı kullanıyorsa o); `RPC_TABLES['vaka_kalan_gunleri_kaydir_coklu'] = ['gorev_log','treatment_days','treatment_day_uygulamalar','islem_log']` (api.js:293; offline `RPC_MAP`'e EKLENMEZ — online-only, vaka_toplu_ac ile aynı).

- [x] **Step 1: Başarısız testi yaz** — `tests/unit/coklu-kaydir-ui.test.js` içine (mevcut erteleme-kaydir-ui.test.js'in modül-yükleme pattern'i kopyalanır):

```js
test('apiCokluKaydir pull seti tanimli', () => {
  assert.deepEqual(RPC_TABLES['vaka_kalan_gunleri_kaydir_coklu'],
    ['gorev_log', 'treatment_days', 'treatment_day_uygulamalar', 'islem_log']);
});
test('apiCokluKaydir parametre sirasi dogru', async () => {
  // rpc mock: (fn, params) kaydeder; apiCokluKaydir(['g1','g2'], 3)
  // → rpc('vaka_kalan_gunleri_kaydir_coklu', { p_gorev_ids: ['g1','g2'], p_gun: 3 })
});
```

- [x] **Step 2: Testi koştur — FAIL doğrula**

Run: `node --test tests/unit/coklu-kaydir-ui.test.js`
Expected: FAIL (apiCokluKaydir / MAP anahtarı yok)

- [x] **Step 3: api.js'e uygula** — `apiCokluKaydir` yardımcı + MAP satırı (mevcut biçime birebir uyumlu).

- [x] **Step 4: Testi koştur — PASS**

Run: `node --test tests/unit/coklu-kaydir-ui.test.js`
Expected: PASS

- [x] **Step 5: Commit**

```bash
git add js/api.js tests/unit/coklu-kaydir-ui.test.js
git commit -m "feat(api): apiCokluKaydir yardimcisi + coklu-kaydir pull seti"
```

### Task 3: ui.js — checkbox + seçim çubuğu

**Files:**
- Modify: `js/ui.js` (renderTask ~1461 + görev listesi render/loadTasks bloğu)
- Test: `tests/unit/coklu-kaydir-ui.test.js` (Append)

**Interfaces:**
- Consumes: yok (saf UI + durum).
- Produces: `window._ckSecilenGorevler` (Set<string>, **sessionStorage senkronlu** — anahtar `ege_coklu_secim`); `_cokluSecimToggle(gorevId, checked)`; `_cokluSecimTemizle()`; `_cokluSecimBarGuncelle()`; `_cokluSecimYukle()` (render öncesi Set'i sessionStorage'dan geri yükler); checkbox markup: `<input type="checkbox" class="task-sec-kutu" data-gorev-id="…" ${Set'te ise checked}>`; çubuk id'leri: konteyner `k-coklu-bar`, sayaç `k-coklu-sayac`, sayı girişi `k-coklu-gun`, onay `k-coklu-onayla`, temizle `k-coklu-temizle`. Checkbox YALNIZ `gorev_tipi ∈ {TEDAVI_GUN, TEDAVI_SEANS} && !tamamlandi && !iptal` kartlarında çizilir (fail-closed). **Seans mini-kartları (`renderSeansGorevKart`) DA checkbox alır** — seans'ı olan günlerde TEDAVI_GUN kartı gizlendiğinden bu kartlar tek seçim girişidir (plan-review sonrası fix-loop 1 düzeltmesi; spec §4 şartı).

- [x] **Step 1: Başarısız testleri yaz** — (a) TEDAVI_GUN açık kartta checkbox var, ILAC kartında yok; (b) tamamlanmış TEDAVI_GUN'de yok; (c) `_cokluSecimToggle` Set'i günceller + `_cokluSecimBarGuncelle` sayacı "2 görev seçili" yapar; (d) `navigator.onLine=false` mock'unda çubuk `hidden` / onay çağrılmaz; (e) **kalıcılık:** toggle sonrası sessionStorage'da `ege_coklu_secim` günceldir; Set temizlenip `_cokluSecimYukle()` çağrılınca seçimler geri döner (tab geçişi simülasyonu); temizle sessionStorage'ı da boşaltır.
- [x] **Step 2: Koştur — FAIL doğrula** (`node --test tests/unit/coklu-kaydir-ui.test.js`)
- [x] **Step 3: ui.js'e uygula** — renderTask'a (ui.js:1461) checkbox dalı + seçim fonksiyonları + çubuk render'ı (`k-coklu-bar` konteyneri görev listesi başında; index.html'e Task 5'te statik konteyner eklenecek, ui.js doldurur). Çubuk içeriği SPEC §4'e birebir: "N görev seçili" sayacı + hızlı chip'ler **1 · 2 · 3 · 7** (tık → `k-coklu-gun` değerini doldurur) + sayı girişi + onay + temizle. Değerler `dataset.gorevId` ile taşınır, innerHTML'e id interpolasyonu yapılmaz. Görev listesi her render'da `_cokluSecimYukle()` çağırır ve checkbox'ları Set'e göre işaretler.
- [x] **Step 4: Koştur — PASS** + `npm run test:unit` (mevcut suite regression: erteleme-kaydir-ui.test.js vs. PASS)
- [x] **Step 5: Commit**

```bash
git add js/ui.js tests/unit/coklu-kaydir-ui.test.js
git commit -m "feat(ui): gorev kartlarina coklu-secim checkbox + kaydirma cubugu (offline guardli)"
```

### Task 4: forms.js — onay + submit + bantlı sonuç

**Files:**
- Modify: `js/forms.js` (bcSonucBantlari ~2475 / submitBulkCase ~2537 deseni çevresi)
- Test: `tests/unit/coklu-kaydir-ui.test.js` (Append)

**Interfaces:**
- Consumes: `apiCokluKaydir` (Task 2), `window._ckSecilenGorevler` + `_cokluSecimTemizle` (Task 3), mevcut `openConfirm`.
- Produces: `cokluKaydirBaslat()` (Set boşsa çıkış; N doğrulama: tam sayı 1-31, değilse toast + çıkış; openConfirm "N görev +N gün kaydırılacak…"); `cokluKaydirOnayla()` (butonu `disabled` → `apiCokluKaydir` → bant: Kaydırılan M vaka / Atlanan / Hatalar satırları → pull → `renderSafe` → `_cokluSecimTemizle()` → buton `enabled`). Bant: yeni `_cokluKaydirBanti(sonuc)` fonksiyonu — görsel desen `bcSonucBantlari`'ndan alınır ama KENDİ şemasıyla (kaydirilan/atlanan/hatalar satırları); mevcut `_topluSonucModal` (applied/blocked/requires_ack) ve `bcSonucBantlari` (acilan/kupe) başka yanıt şemalarına sıkı bağlı olduğundan REUSE UYGUN DEĞİL (plan-review bulgusu).

- [x] **Step 1: Başarısız testleri yaz** — (a) N=0/boş/31 üstü/nedizali → RPC çağrılmaz, toast; (b) başarılı 2-vaka yanıtında bant metni `2 vaka kaydirildi`, Set temizlenir; (c) `atlanan`/`hatalar` doluysa satırlar görünür (sessiz başarı yok); (d) RPC koşusu sırasında ikinci çağrı gitmez (disabled mock); (e) RPC reject olursa buton tekrar `enabled` ve hata bandı gösterilir (kilitli kalmaz).
- [x] **Step 2: Koştur — FAIL doğrula**
- [x] **Step 3: forms.js'e uygula** — iki fonksiyon + `_cokluKaydirBanti` + bağlama (`k-coklu-onayla` click → `cokluKaydirBaslat`, confirm onayı → `cokluKaydirOnayla`); pull tetikleme `RPC_TABLES` kaydıyla mevcut pull akışından (api.js) gelir.
- [x] **Step 4: Koştur — PASS** + tam unit suite
- [x] **Step 5: Commit**

```bash
git add js/forms.js tests/unit/coklu-kaydir-ui.test.js
git commit -m "feat(forms): coklu kaydirma onay+submit akisi — partial-success bantli, cift-gonderim kilitli"
```

### Task 5: index.html — çubuk konteyneri + damga

**Files:**
- Modify: `index.html` (görevler görünümü bloğu + `<head>`/damga satırı — şu an `?v=20260926-08`)
- Modify: `tests/unit/vaka-toplu-ac.test.js` (4 sabit damga iddiası değer-bağımsıza çevrilir — plan-review Critical fix)

**Interfaces:**
- Consumes: `k-coklu-bar` id (Task 3 üretir).
- Produces: statik konteyner `<div id="k-coklu-bar" hidden></div>` görev listesi başlığının hemen altında; damga güncel değerden +1'e bump (dosyada TEK değer — değer-bağımsız testle korunur).

- [x] **Step 1: Başarısız test yaz** — **değer-bağımsız** damga testi: `index.html`'de tüm `?v=` referansları TEK AYRIK değerde (hangi değer olduğuna bağlı değil — bump artık test kırmaz), `id="k-coklu-bar"` tam 1 kez; `vaka-toplu-ac.test.js`'teki 4 eski sabit-damga iddiası (satır ~2286/2321/2658/2660) aynı değer-bağımsız biçime çevrilir (plan-review Critical kök fix).
- [x] **Step 2: Koştur — FAIL doğrula**
- [x] **Step 3: Uygula** — konteyner div + damga bump'ı (tek değer, tüm referanslar) + `vaka-toplu-ac.test.js` sweep.
- [x] **Step 4: Koştur — PASS**
- [x] **Step 5: Commit**

```bash
git add index.html tests/unit/coklu-kaydir-ui.test.js tests/unit/vaka-toplu-ac.test.js
git commit -m "chore(release): damga bumbu (tek deger) + coklu-kaydir cubuk konteyneri + damga testleri deger-bagimsiz"
```

### Task 6: Tam doğrulama + teslim hazırlığı

**Files:**
- Modify: `docs/plans/2026-09-27-coklu-kaydirma-PLAN.md` (bu dosya — işaretlenir), `.harness/references/rpc-reference.md` (yeni RPC satırı), `BUGS.md` gerekmiyorsa dokunma.

**Interfaces:**
- Consumes: Task 1-5 tamamı.
- Produces: glmf demo test zarfı içeriği (aşağıdaki 8 madde).

- [x] **Step 1: Tam unit koşumu** — Run: `npm run test:unit` Expected: tümü PASS (Review Focus 5: erteleme-kaydir-ui.test.js dahil).
- [x] **Step 2: Final db-validate** — migration üzerinde PASS (zaten Task 1'de; migration değiştiyse tekrar).
- [x] **Step 3: rpc-reference kaydı** — `.harness/references/rpc-reference.md`'ye `vaka_kalan_gunleri_kaydir_coklu` satırı (imza, dönüş, guard'lar, spec/plan yolu).
- [x] **Step 4: glmf demo test listesi zarfını hazırla** (koşum YAPILMAZ — glmf-max koltuğunda ayrı tur; prod/demo DB'ye dokunulmaz):
  1. 3 vakadan 1'er görev seç → +1 kaydır → 3 vakada tüm açık günler/görevler/seanslar +1, tamamlanmış sabit (demo SQL/ekran kanıtı)
  2. Aynı vakadan 2 görev seç → vaka 1 kez kayar, bant "1 vaka" der
  3. Kapalı vakaya bağlı görev dahil edilirse → Atlanan bandında görünür, diğerleri kayar
  4. Çevrimdışı (devtools offline) → çubuk gizli; zorla tetiklenirse "İnternet yok", RPC çağrılmaz
  5. Saatler (10:00/18:00) ve görev etiketleri doğru tazelenir
  6. Planlı tohumlama (TAI) görevi +N taşınır
  7. N girişi: 0, 32, "abc" → toast, çağrı yok; 1/2/3/7 chip'leri doldurur
  8. Mevcut tek-vaka "⏩ Kalan Günleri Kaydır" butonu aynen çalışır (regresyon)
  9. Sekme içi tab geçişi (Görevler→Üreme→Görevler) sonrası seçimler korunur; "Temizle" hepsini düşürür
- [x] **Step 5: Commit**

```bash
git add docs/plans/2026-09-27-coklu-kaydirma-PLAN.md .harness/references/rpc-reference.md
git commit -m "docs(plan): coklu-kaydirma plan isaretleri + rpc-reference kaydi"
```

## Teslim Sonrası (bu planın DIŞI, sıra sabit)

1. glmf-max koltuğunda 8 maddelik demo testi → hepsi PASS.
2. Sahibin kapısı: demo + test listesi sunulur; prod DB apply (migration Management API/runbook) ve merge AYRI sahip onayı.
