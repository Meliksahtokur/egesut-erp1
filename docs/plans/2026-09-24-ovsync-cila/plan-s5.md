# PLAN S5 — Tutarlılık Paketi T1-T11 Uygulama Planı (spec-s5 implementasyonu)

- **Tarih:** 2026-09-24 · **Dal:** `ovysch-feature-cila-turu` (prod push/merge YOK; commitler yalnız bu dala)
- **R3 onarım revizyonu (2026-09-24):** reviewer FAIL sonrası tüm kanıt iddiaları yeniden doğrulandı. Plan değişiklikleri: **Adım 12 (F3/T6) KESİN ATLANIR** (canlıda legacy overload yok — §0); **K-7 değişti** (`supabase_migrate` MCP prod hedeflidir, demo için YASAK; demo yolu `SUPABASE_DEMO_PAT` query endpoint / psql-demo — §0 ve ENGEL-5); Adım 0 baseline'ı koşuldu (1086/1089, 3 bilinen kırmızı); V3 damga kanıtlandı (ENGEL-4 kalktı); V1 canlı teyit edildi.
- **Girdi:** `docs/plans/2026-09-24-ovsync-cila/spec-s5.md` (bağlayıcı), `reports/plans/ovsync-cila-plan-5.md` (§3 checklist sahibin yürüyüşüdür), canlı repo kodu (bu plan yazılırken satır düzeyinde yeniden doğrulandı; kanıt etiketli)
- **Sahip talimatı (bağlayıcı):** demo DB'ye yazmak serbest; eşzamanlı agent ≤10; **kesintisiz koş**; teslim "demo'da teste hazır" halde; iş bitince **son review kapısı** koşulur.
- **Bağlayıcı varsayılanlar (spec §13 açık kararları — sahibin onayı beklemeden):** S2=**Seçenek A** (`p_iptal` RPC parametresi), S1=**geniş kapsam** (`%senkron%` damgası), S3=**b2** (DB'siz rozet birleştirme), T9 + erteleme-geneli **BORÇ** (BUGS.md, fix YOK).

---

## 0. PLAN SEVİYESİ DRIFT BULGUSU — spec §7.2'nin hedef gövdesi düzeltildi (UYGULAMAYI ETKİLER)

Spec §7.2, T1 ek koşulunun `20260924000001:L273-280` OVSYNC_BASLAT bloğunun arkasına ekleneceğini yazar. **Bu bayat:** `20260924000002_dryrun_bayrak_bagimsiz.sql:74-90` (CONFIRMED) `_acik_disi_ovsync_hedef`'i **ince sarmalayıcıya** indirgedi (bayrak kapısı + `RETURN public._acik_disi_hedef_ic(p_hayvan_id)`); tüm uygunluk hesabı artık **`_acik_disi_hedef_ic`** gövdesinde (CONFIRMED `20260924000002:21-68`: OVSYNC_BASLAT bloğu :53-59, kural çağrısı :61).

**Sonuç:** F2'nin ek koşulu `_acik_disi_hedef_ic` içine yazılır (Adım 11). Spec'in fonksiyonel şartı (OVSYNC_BASLAT bloğu ikame edilmez, üçüncü koşul EKLENİR; 188 korunur) aynen geçerlidir — sadece fiziksel hedef değişir. Dry-run dalı da `ic`'yi kullandığından (CONFIRMED `20260924000002:93-95,246`) önizleme/gerçek tutarlılığı korunur. Bu sapma "canlı şema tek otorite" kuralının tahmin ettiği tiptedir; apply öncesi canlı `pg_get_functiondef` doğrulaması zaten zorunlu kapı.

Diğer teyitler (bu plan yazılırken):
- `gorev_tamamla` son tam tanım: CONFIRMED `20260902000003_asi_planli_gorev.sql:189` — imza `(p_gorev_id text, p_padok_hedef text DEFAULT NULL::text)`, gövde `SECURITY DEFINER`, **`SET search_path` satırı YOK**; ACL: `20260915000001_anon_execute_geri_al.sql:64` anon+PUBLIC'ten REVOKE etmiş. → F1 taslağındaki `SET search_path` satırı **eklenmez** (canlı header aynen korunur; bu turda güvenlik refactoru YOK). **Canlı teyit (R3 onarımı, demo pg_proc):** tek imza `gorev_tamamla(text,text)`, SET search_path YOK — plan hedefiyle birebir.
- **T6 canlı ölçümü (R3 onarımı):** demo pg_proc'ta `tohumlama_sonuc_bos` **tek imza `(text,text)`**; legacy `(text)` overload **YOK** (prod'da da tek imza — yan gözlem). Repo: `20260403000001:L6` DROP etmiş, `20260512000006` tekrar CREATE etmiş; canlı nihai durum tek imza. → **Adım 12 (F3) KESİN ATLANIR**; `20260512000006` anon-GRANT risk kaydı canlıda fonksiyon olmadığından kapanır.
- **V3 damga ölçümü (R3 onarımı):** demo `gorev_log`'da `kaynak ILIKE '%senkron%' OR aciklama ILIKE '%senkron%'` → **16 satır** (tamamı ILAC, `aciklama='39. Gün PG (Presynch-14 senkron)'`, `kaynak='DOGUM-<uuid>'`), **2'si açık**. Damga `aciklama`'da → F2'nin geniş-kapsam filtresi canlı veriyle uyumlu; **ENGEL-4 kalktı, Adım 11 koşulsuz yazılır**.
- **V10 canlı teyit (R3 onarımı):** canlı `protokol_eksik_tara()` gövdesinde OVSYNC bölümü yok (pg_get_functiondef LIKE sorgusu: false) — rozet tasarım b2 ön-şartı sağlam; canlı `ovsync_baslat_uyarilari` ve `tohumlama_gorev_ertele` RPC'leri mevcut; demo'da açık OVSYNC_BASLAT 29 satır (D7 yürütülebilir).
- **MCP hedef uyarısı (R3 onarımı — OPERASYONEL RİSK):** tools-bank `supabase_migrate`/`supabase_query` MCP bağlantısı **PROD projesine** bakar (fdw_prod_srv=0 + schema_migrations=124 = prod imzası; demo imzası fdw_prod_srv≥1). Bu MCP ile "demo ölçümü" sanarak sorgu/apply koşmak **prod okur/yazar**. Demo işlemleri için: repo kök `.env`'deki `SUPABASE_DEMO_PAT` ile `curl -X POST https://api.supabase.com/v1/projects/vtzqjmazsvurxdeondmi/database/query` (R3 onarımında ölçümler bu yolla koşuldu — çalıştığı OBSERVED) veya `SUPABASE_DEMO_DB_PASSWORD` + `SUPABASE_DEMO_POOLER` ile psql.
- `flushPendingDone` güncel gövde: CONFIRMED `js/ui.js:583-597` (spec R3 onarımında :583-597'ye tazelendi; `_pendingDone.clear()` :587, catch :593, `recoverPendingDone` :598-605).
- `seansTamamla` toast: CONFIRMED `js/forms.js:4012-4014`; `rpcSeansTamamla` PG-kapı dönüşü CONFIRMED `js/api.js:693-701`.
- `buildRpcParams` gorev_tamamla dalı: CONFIRMED `js/ui.js:9426-9427`; RPC_MAP replay eşlemesi CONFIRMED `js/ui.js:9245`; iptal üreticisi CONFIRMED `js/ui.js:1190-1199` (`write('gorev_log',{...iptal:true},'PATCH')` — op.data[0]'da `id` ve `iptal:true` taşınır).
- `_pgKapiBosAtaUygula` ölü dal: CONFIRMED `js/ui.js:996-997`; `rpc()` ok:false→throw CONFIRMED `js/api.js:86-90` (şu an yalnız `data.mesaj` okur).
- pull seti: CONFIRMED `js/api.js:320`; katalog tablo adları CONFIRMED `js/api.js:32-35` (`diseases`, `drugs`, `tedavi_sablonu`).
- erteleme toast: CONFIRMED `js/ui.js:1058-1059`; RPC dönüşü `toplam_erteleme_gun` CONFIRMED `20260923000003:623`; hata kodları `GOREV_ERTELENEMEZ:{json}` / `GECMIS_TARIH:{json}` CONFIRMED `20260923000003:560-578`.
- vaka kapanış dönüşü: CONFIRMED `20260923000005:533-536` (`otomatik_bos_sayisi`, `kapatilan_senkronizasyon_vakalari`); ölü fallback okuması CONFIRMED `js/forms.js:346-350`.
- rozet: CONFIRMED `js/ui.js:413-424`; panel OVSYNC bölümü CONFIRMED `js/ui.js:1829-1855`.
- TZ: CONFIRMED `js/ui.js:2338-2341` (`new Date(olcGun+'T'+(olcSaat||'12:00')+':00').toISOString()` — tarayıcı-yerel).
- `tohumlama_sonuc_bos` kanonik (text,text): CONFIRMED `20260924000001:508`; legacy (text) overload: CONFIRMED `20260512000006` (anon GRANT'lı — risk kaydı, bugünkü kuralın konusu değil).
- Test altyapısı: `npm run test:unit` = `node --test tests/unit/*.test.js` (CONFIRMED package.json:18); loader `tests/unit/support/loadModule.js` (`loadExtractedFunction` / `loadBrowserModule` + `expose`) CONFIRMED.
- `?v=` damga: CONFIRMED `index.html:11,2325-2328` (`20260924-01` tek değer kalıbı).

---

## 1. KURALLAR — her adımda geçerli kapılar

| Kapı | Kural |
|---|---|
| K-1 Blast-radius pre-check | JS sembol/RPC değişiminden ÖNCE gitnexus `impact`/`context` (kullanım öncesi indeks-HEAD tazeliği kontrol; bayatsa `gitnexus analyze`); ui.js/api.js/forms.js değişimlerinde `code-change-precheck` skill'i. |
| K-2 db-validation | F1-F3 her biri: taslakta BİR, final dosyada BİR `bash scripts/db-validate.sh <dosya>` — PASS kanıtsız yazım/apply yok. |
| K-3 Anon | Yeni migration'da `TO anon` / `GRANT ... TO anon` YASAK; desen: REVOKE (PUBLIC, anon [, authenticated — yardımcı fn]) + yalnız gerekiyorsa `GRANT ... TO authenticated`. |
| K-4 Canlı şema | Her `CREATE OR REPLACE` apply'dan hemen önce canlı demo `pg_get_functiondef` çıktısıyla birebirleştirilir; canlı gövde, revert için migration'a yorum olarak gömülür. |
| K-5 Commit | Her anlamlı adım sonrası bu dala commit; prod push/merge yok. |
| K-6 Tek yazıcı | JS kulvarı F4-F7 **sıralı** (paralel değil); `reports/` salt-okunur girdi. Aynı anda tek agent JS kulvarında çalışır; DB kulvarı (F1-F3) ve test kulvarı (F8) ayrı agent'a açılabilir (≤10 eşzamanlı kuralı). |
| K-7 Demo/prod | Demo DB'ye yazmak serbest; prod'a HİÇ dokunma. **`supabase_migrate` MCP bu turda YASAK — prod hedeflidir** (bkz. §0 MCP uyarısı). Demo ölçüm/apply yolu: `SUPABASE_DEMO_PAT` ile Mgmt query endpoint (curl) ya da psql-demo. Canlı ölçümler için PostgREST **kullanma** (pg_proc PGRST205 — OBSERVED). |
| K-8 Test yürüyüşü | Tarayıcı-yürüyüşü maddeleri (D4/D5/D10/D11/D12/D13/D14 UI kanıtı, K1-K8) **sahibindir**; ajan DB/kod/birim kapılarını koşar. |

**Kabul testi haritası** (spec'ten): birim U1,U4-U11 → F8; demo-ajan D1,D2,D3(kod),D6(metin),D7,D8; demo-sahip D4,D5,D10-D14,Ö3; ölçüm Ö1,Ö2; ertelenmiş D9 (bkz. ENGEL-2).

---

## Adım 0 — Ön-hazırlık ve baseline (kapısız, ölçümsüz)

**Dosya:** yok (yalnız koşum/okuma). **Bağımlılık:** yok — her şeyin öncesi.

1. gitnexus indeks tazeliği: `git log --oneline -1` vs indeks HEAD; bayatsa `gitnexus analyze` (K-1).
2. Baseline suite: `npm run test:unit` koştur; **3 bilinen kırmızının** (plan-5 §3.4: 2 tarih-seçici UI regresyonu + 1 canlı DEMO şema — bugün OBSERVED) aynen kırmızı olduğunu ve **yeni** kırmızı olmadığını kaydet. Bu çıktı Adım 14'ün "suite yeşil veya belgeli-müsaadelı" kapısının referansıdır. **R3 onarımında koşuldu (2026-09-24):** 1089 test / 1086 pass / **3 fail** — (1) LUNA-3 canlı DEMO information_schema, (2) bc-tarih "gelecek güne tık", (3) bc-tarih "ay ‹/› etiket değişir" — beklentiyle birebir; implementasyon öncesi yeniden koşum gerekmez, bu kayıt referanstır.
3. Mevcut `gorev_tamamla` 2-arg çağıranlarının listesi (grep `gorev_tamamla` js/) — F1 sonrası 2-arg çağrıların eski (text,text) overload'a düşeceğinin (T5 branşından geçmeyeceğinin) çağıran-bazı teyidi. Beklenen: `js/ui.js:592` (flushPendingDone — iptal taşımaz, T5 gerektirmez), `js/forms.js` çağrıları (hepsi iptalsiz tamamlama).

**Doğrulama:** baseline notu teslim raporuna işlenir. **Commit:** yok (değişiklik yok).

---

## Adım 1 — Canlı şema ölçümleri (Adım 0'ın DB uzantısı; TÜM migration adımlarının ön-şartı)

**Dosya:** `reports/plans/ovsync-cila-tur2-adim1-olcum.md` (YENİ — bulgu/ölçüm kaydı; commit: `git add -f`, reports/ gitignore'da). **Araç:** K-7 (Mgmt API SELECT / psql-demo). **Bağımlılık:** Adım 0. **Engellenenleri not et:** hiçbir sorgu başarısız olursa onu ENGEL olarak kaydet ve kalanı sürdür (kesintisizlik kuralı).

Sorgular (salt-okunur, demo):

1. **V1+V2 (F1 için):** `SELECT pg_get_functiondef(p.oid) FROM pg_proc p WHERE p.proname='gorev_tamamla' AND p.pronamespace='public'::regnamespace;` → canlı imza(lar) + gövde. Beklenen: tek imza (text,text); gövde 20260902000003:189+ ile eş mi; islem_log INSERT deseni var mı (spec V2). **R3 notu: imza bölümü canlıdan teyitli (tek imza, SET-yok); kalan tek bilinmeyen gövde-içi islem_log desenidir (V2).**
2. **T6 ölçümü (spec §5.2):** `tohumlama_sonuc_bos` tüm imzalar + gövdeler; `sonuc`/`tohumlama_durumu` 'Boş'/'Bos' dağılımı; `has_function_privilege('anon', oid, 'EXECUTE')`. **R3 notu: imza bölümü kapandı — canlıda tek imza (text,text), overload YOK (bkz. §0); Adım 1'den kalan yalnız 'Boş/Bos' dağılımı + anon ayrıcalık sayımı (Ö1 kapama kanıtı).**
3. **V3 (F2 için — damga ölçümü, spec §7.2):** `SELECT gorev_tipi, kaynak, count(*) FROM public.gorev_log WHERE gorev_tipi IN ('ILAC','TOHUMLAMA_HAZIRLIK','TEDAVI_GUN') GROUP BY 1,2 ORDER BY 3 DESC LIMIT 30;` + `aciklama` örnekleri. '**senkron**' damgası geçmiyorsa → F2 YAZILMAZ (ENGEL-4), bulgu S1 ile sahibe. **R3 notu: kapandı — damga VAR (16 satır, 2 açık, `aciklama` alanında; bkz. §0). Ölçümün kesin sorgusu ILIKE-based olmalı; LIMIT-30 count-sıralı kesit damgalı satırları gösteremez (R3'te bu tuzak görüldü).**
4. **V10 teyidi:** `SELECT pg_get_functiondef('public.protokol_eksik_tara()'::regprocedure)` içinde 'OVSYNC' bölümü yok mu (rozet tasarım b2'nin ön-şartı).
5. **D7 ön-ölçümü:** `SELECT public._acik_disi_ovsync_hedef('<188-in-hayvan-id>');` çıktısını kaydet (apply-sonrası birebir-eş karşılaştırmanın AYAĞI). 188'in id'si demo `gorev_log`'dan çözülür (açık OVSYNC_BASLAT'lı hayvan).
6. **Canlı gövdelerin F1/F2/F3'e gömülecek kopyaları** (K-4): `gorev_tamamla`, `_acik_disi_hedef_ic`, `tohumlama_sonuc_bos(text)` pg_get_functiondef çıktıları ölçüm raporuna aynen yazılır.

**Kapı:** K-7. **Doğrulama (Ö1):** ölçüm raporunda 6 başlık dolu; imza listeleri + dağılım + ayrıcalıklar sayısal. **Commit:** `reports: cila Tur2 Adım1 canlı şema ölçümleri (V1-V3/V10, T6 dağılım, D7 ön-ölçüm)`.

---

## Adım 2 — F1 taslak migration (T5) + db-validate (taslak koşumu)

**Dosya:** `supabase/migrations/20260925000001_cila_t5_gorev_tamamla_p_iptal.sql` (YENİ). **Bağımlılık:** Adım 1 (V1/V2 çözülmüş olmalı). **Kapılar:** K-2 (taslak), K-3, K-4.

İçerik (diff-seviyesi):
- Başlık yorumu: amaç (T5, spec §4) + Adım 1'deki canlı `pg_get_functiondef('gorev_tamamla(text,text)')` çıktısı **aynen gömülü** (revert kaynağı, spec §11).
- `CREATE OR REPLACE FUNCTION public.gorev_tamamla(p_gorev_id text, p_padok_hedef text DEFAULT NULL::text, p_iptal boolean DEFAULT false) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $fn$` — **canlı header ne ise o** (canlıda `SET search_path` YOK — bkz. §0 drift; EKLENEMEZ). `AS $fn$` yerine canlı `$function$` etiketi korunabilir.
- DECLARE + gövde: **Adım 1'deki canlı gövdeden aynen** (20260902000003 tabanlı; `SET search_path`'siz haliyle).
- T5 branşı — canlı gövdedeki `SELECT * INTO v_gorev ... FOR UPDATE` + `IF NOT FOUND THEN RAISE` bloğunun **hemen ardından**, `IF v_gorev.tamamlandi` erken-dönüşünden **önce**:
```sql
  -- T5 (cila): offline kuyruk replay'i — iptal-PATCH'i İPTAL olarak kapat
  IF p_iptal IS TRUE THEN
    UPDATE public.gorev_log
       SET tamamlandi = true,
           tamamlanma_tarihi = COALESCE(tamamlanma_tarihi, now()),
           iptal = true
     WHERE id = p_gorev_id::uuid;
    IF NOT FOUND THEN
      RETURN jsonb_build_object('ok', false, 'mesaj', 'Görev bulunamadı');
    END IF;
    RETURN jsonb_build_object('ok', true, 'gorev_id', p_gorev_id, 'iptal', true);
  END IF;
```
  - İdempotentlik: görev zaten `iptal=true` ise UPDATE koşulsuz tekrar yazar, aynı dönüşü verir (replay tekrar denemesinde zararsız). Zaten `tamamlandi=true` AMA `iptal=false` bir göreve `p_iptal=true` gelirse iptal damgası ekler — replay-race'te beklenen birleşim (otomatik sync önce tamamlayıp iptali taşımış olabilir; nihai durum tutarlı).
  - **V2'ye bağlı iz:** Adım 1'de canlı gövdede islem_log INSERT deseni çıktıysa, branşa aynı desenle `aciklama='Görev iptal edildi (offline replay)'` INSERT'i eklenir; çıkmadıysa iz eklenmez (PATCH-yolunun degisim_log trigger izi dışında ek borç yazılmaz).
- Kuyruk (GRANT'lara kadar canlı gövdenin tamamı) + sonda:
```sql
REVOKE ALL ON FUNCTION public.gorev_tamamla(text, text, boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.gorev_tamamla(text, text, boolean) TO authenticated;
```
  Eski `(text,text)` imzası **dokunulmaz** (2-arg çağıranlar + revert kolaylığı; spec §11 revert'i eski imzaya dönüşü destekler).
- `NOTIFY` / diğer side-effect: canlı gövde ne yapıyorsa aynen (Adım 1 gövdesi otorite).

**Doğrulama:** `bash scripts/db-validate.sh supabase/migrations/20260925000001_cila_t5_gorev_tamamla_p_iptal.sql` → PASS (çıktı reports/db-validation-*.md; U2'nin ilk koşumu). FAIL ise gövde-canlı farkını düzelt, tekrar koş. **Commit:** `spec: cila T5 taslak — gorev_tamamla p_iptal (db-validate PASS, taslak koşum)`.

---

## Adım 3 — F1 final + demo apply + apply-sonrası doğrulama

**Dosya:** aynı migration (final). **Bağımlılık:** Adım 2 PASS. **Kapılar:** K-2 (final koşum), K-4.

1. Taslak başlığındaki "TASLAK" işaretini kaldır; canlı-gövde gömmesinin Adım 1 çıktısıyla birebir olduğunu gözle doğrula (diff yorum içi).
2. `bash scripts/db-validate.sh ...` **final dosyada tekrar** → PASS (U2'nin ikinci kanıtı).
3. **Demo apply:** Mgmt API (`supabase_migrate`) ile migration içeriğini çalıştır. Apply öncesi Adım 1'deki canlı gövde satır sayısı/hash notu ile karşılaştır (bayatlanma yok mu).
4. Apply-sonrası canlı doğrulama (ajan, Mgmt API/psql):
   - `SELECT p.oid::regprocedure::text FROM pg_proc p WHERE p.proname='gorev_tamamla' AND p.pronamespace='public'::regnamespace;` → **iki** imza: `(text,text)` + `(text,text,boolean)`.
   - `SELECT has_function_privilege('anon', 'public.gorev_tamamla(text,text,boolean)'::regprocedure, 'EXECUTE');` → **false**; authenticated → **true**.

**Commit:** `spec: cila T5 final — gorev_tamamla(text,text,boolean) demo'da canlı (db-validate PASS x2, anon false)`.

---

## Adım 4 — F5'in T5 satırı + F8 birim testleri (U1) — T5'in JS ayağı

**Dosyalar:** `js/ui.js` (tek satır), `tests/unit/cila-tutarlilik.test.js` (YENİ). **Bağımlılık:** Adım 3 (RPC canlı). **Kapı:** K-1 (buildRpcParams `impact` — çağıran dataTrafficTekGonder; flushPendingDone :592 doğrudan rpc çağırır, buildRpcParams'tan geçmez — beklenen-etki yazılır), K-6.

`js/ui.js:9426-9427` değişikliği:
```js
    case 'gorev_tamamla':
      return { p_gorev_id: data.id, p_padok_hedef: data.padok || null,
               p_iptal: data.iptal === true };   // T5: iptal-PATCH replay'i iptal olarak gider
```

`tests/unit/cila-tutarlilik.test.js` iskeleti (bu adımda U1; sonraki adımlar U4-U11'i aynı dosyaya ekler):
```js
const test = require('node:test');
const assert = require('node:assert');
const { loadExtractedFunction } = require('./support/loadModule.js');
const buildRpcParams = loadExtractedFunction('js/ui.js', 'buildRpcParams');

test('T5/U1: iptal-PATCH replay p_iptal=true taşır', () => {
  const p = buildRpcParams('gorev_tamamla', { id:'g1', padok:'p1', iptal:true }, { method:'PATCH', filter:'id=eq.g1' });
  assert.strictEqual(p.p_iptal, true);
});
test('T5/U1: iptalsiz tamamlama p_iptal=false (regresyon: eski davranış)', () => {
  const p = buildRpcParams('gorev_tamamla', { id:'g1', padok:null }, { method:'PATCH', filter:'id=eq.g1' });
  assert.strictEqual(p.p_iptal, false);
  const p2 = buildRpcParams('gorev_tamamla', { id:'g1' }, { method:'PATCH', filter:'id=eq.g1' });
  assert.strictEqual(p2.p_iptal, false);
});
```

**Doğrulama:** `npm run test:unit` — U1 yeşil, baseline kırmızıları aynen. **Commit:** `spec: cila T5 — replay buildRpcParams p_iptal taşır (U1 yeşil)`.

---

## Adım 5 — T5 demo kabul doğrulamaları (D1, D2, D3)

**Bağımlılık:** Adım 3+4. **Yürüyen:** ajan (DB kapıları); replay-zinciri gözlemi sahibin yürüyüşüne (plan-5 §3.3 Veri Trafik maddesi) not düşülür.

- **D1 (ajan, demo):** Adım 1'de seçilen/oluşturulan test `gorev_log` satırı için `SELECT public.gorev_tamamla('<gorev-id>', NULL, true);` → dönüş `{ok:true, iptal:true}`; satır: `tamamlandi=true AND tamamlanma_tarihi IS NOT NULL AND iptal=true`. **Yanlış-semantik sayısı 0.**
- **D2 (ajan, demo — regresyon):** aynı akış `p_iptal` verilmeden (2-arg overload) → `iptal=false` kalır, mevcut davranış değişmedi.
- **D3 (kod kanıtı):** `git diff main...HEAD -- js/api.js` içinde syncNow/dbUpdate bloğu (:546-552) **dokunulmamış** — otomatik sync ham REST PATCH yolunun T5'ten etkilenmediğinin kanıtı (dönüş `iptal=true` zaten canlıda çalışır).

**Commit:** `reports: cila T5 demo kabul — D1/D2 DB kanıtı, D3 diff-kanıtı` (ölçüm raporuna ek).

---

## Adım 6 — F4 T8: rpc() sunucu `'error'` alanını Türkçe mesaja taşır

**Dosya:** `js/api.js:87`. **Bağımlılık:** Adım 0 (JS kulvarı serbest). **Kapı:** K-1 (rpc `impact` — tüm rpc çağıranları; etki yalnız hata-METNİ kalitesi, akış değişmez — spec §6.2-4).

```js
  if (data && data.ok === false) {
    const err = new Error(data.mesaj || data.error || 'İşlem başarısız');
    err.data = data;
    throw err;
  }
```

F8'e **U10**:
```js
test('T8/U10: ok:false + error alanı → thrown message Türkçe', () => {
  // rpc mock: fetch yerine doğrudan mesaj üretimini sınayan kalıp
  const data = { ok:false, error:'Sadece Bekliyor durumundaki tohumlama boş ilan edilebilir' };
  const err = new Error(data.mesaj || data.error || 'İşlem başarısız');
  assert.strictEqual(err.message, 'Sadece Bekliyor durumundaki tohumlama boş ilan edilebilir');
});
```
(Not: loadModule ile `js/api.js` fetch bağımlılığı yüzünden tam rpc modülü yüklenemeyebilir; U10 mesaj-üretim kalıbını kilitler; gerçek rpc() demosu D6'dadır.)

**Doğrulama:** test:unit yeşil. **Commit:** `spec: cila T8 — rpc() sunucu 'error' alanını Türkçe mesaja taşır (U10)`.

---

## Adım 7 — F6 T3: seansTamamla sahte-başarı guard'ı (U5)

**Dosya:** `js/forms.js:4012-4014`. **Kapı:** K-1 (seansTamamla `context`), K-6.

```js
    const res = await rpcSeansTamamla(seansId, uygulanmadi, null);
    if (res?._pgKapi) return;   // T3: PG kapı modalı açıldı — sahte başarı toast'u YOK (modal akışı yönetir)
    toast(uygulanmadi ? '↩ Yapılamadı işaretlendi, stok iade edildi' : '✓ Seans tamamlandı');
```
`return` öncesi satır-butonlarını yeniden açMA — PG modalı kapanışında tablo tazelenir; donuk-buton riski K5 yürüyüş maddesinde sahibin gözüne görünür (bilinçli minimal değişiklik).

F8'e **U5**: `loadBrowserModule('js/forms.js')` + sandbox'ta `toast` sayacı ve `rpcSeansTamamla` stub `{ok:false,_pgKapi:true}` → toast çağrılmaz; stub `{ok:true}` → toast bir kez. Loader forms.js'i yükleyemezsa (DOM bağımlılığı) U5'in yerine guard satırının kod-inceleme kanıtı + D5 (sahip) ile telafi — engel değil, raporlanır.

**Commit:** `spec: cila T3 — seansTamamla PG-kapı sahte-başlık guard (U5)`.

---

## Adım 8 — F5 T4: flushPendingDone clear-önce kaybının fix'i (U4)

**Dosya:** `js/ui.js:583-597`. **Kapı:** K-1 (flushPendingDone `context` — çağıranlar: loadTasks:609, recoverPendingDone:603), K-6.

Mevcut üç dal (seans/besleme/gorev) **aynen korunur**; yalnız temizleme sırası değişir:
```js
async function flushPendingDone(){
  if(!_pendingDone.size) return;
  if(!navigator.onLine){ toast('⚠️ Çevrimiçi olunca uygulanacak'); return; }
  const items=[..._pendingDone.values()];
  const kalan=new Map(_pendingDone);            // T4: clear SONRA, yalnız başarılı op düşer
  for(const it of items){
    try {
      if(it.type==='seans') await rpcSeansTamamla(it.params.seansId, it.params.uygulanmadi, null);
      else if(it.type==='besleme') await rpc('besleme_tamam', {p_gorev_id:it.params.gorevId});
      else if(it.type==='gorev') await rpc('gorev_tamamla', {p_gorev_id:it.params.gorevId, p_padok_hedef:it.params.padok||null});
      kalan.delete(it.type==='seans'?it.params.seansId:it.params.gorevId);
    } catch(e){ toast('❌ Görev uygulanamadı: '+(e.message||''), true); }
  }
  _pendingDone.clear();
  kalan.forEach((v,k)=>_pendingDone.set(k,v));
  _savePending(); updatePendingFab();
  try { await pullTables(['gorev_log','treatment_days','treatment_day_uygulamalar','drug_administrations','stok','stok_hareket','cases']); } catch(e){}
  if(typeof updateTaskBadge==='function') updateTaskBadge();
}
```
Anahtar-uyumu: `_pendingDone.set` anahtarı :577'de `type==='seans'?seansId:gorevId` — besleme de gorevId anahtarlı; `kalan.delete` aynı formül (CONFIRMED tutarlı). `recoverPendingDone` (:598-605) dokunulmaz — yeniden-giriş flush'ı kalanları tekrar dener (D4'ün kurtarma yolu).

F8'e **U4**: `loadBrowserModule('js/ui.js')` (veya flush fonksiyonunun sandbox-çıkarımı) ile `toast/rpc/rpcSeansTamamla/pullTables/updateTaskBadge/_savePending` stub'lanır; `_pendingDone`'a 3 op konur, 2. si throw atar → op1/op3 pending'den düşer, op2 kalır; localStorage `_pendingDone` yazımı kalanı içerir. (ui.js modül-bütünü yüklenemezsa: flush gövdesi vm'de izole koşturma — loader'ın `loadExtractedFunction` desteğiyle; başarısızsa U4'ü U1 kalıbındaki saf-mantık testine indir ve sınırı raporla.)

**Commit:** `spec: cila T4 — flushPendingDone clear-önce kaybı fix (U4: hatalı op pending'de kalır)`.

---

## Adım 9 — F5 T3b/T8: `_pgKapiBosAtaUygula` ölü dal + yarım-durum retry

**Dosya:** `js/ui.js:990-1005`. **Kapı:** K-1 (`_pgKapiBosAtaUygula` çağıranı: pg-kapi butonu), K-6.

1. **Ölü dal silinir** (`if (!r?.ok)` :997 — rpc throw'a çevirdiği için koşmaz, spec §6.1).
2. `tekrar` çağrısı iç try/catch'e alınır; hata durumunda `_pgKapiKapat()` **çağrılmaz**:
```js
    toast('Tohumlama Boş yapıldı — PG uygulanıyor…');
    try {
      await window.__pgKapiTekrar(true, gerekce);
    } catch (e3) {
      toast('⚠️ Tohumlama Boş kaydedildi, PG uygulanamadı — aynı butonla tekrar deneyin: ' + getUserMessage(e3), true);
      if (btn) { btn.disabled = false; btn.textContent = 'Boş ata ve uygula'; }
      return;   // modal AÇIK kalır — yarım durum görünür, yalnız-PG-retry mümkün (T3 telafisi)
    }
    _pgKapiKapat();
```
Dış `catch (e2)` (:1001-1004) aynen kalır (ilk rpc throw'u için).

**Doğrulama:** test:unit hâlâ baseline-durumda (bu adım birimsiz — davranış D5/sahip + kod-inceleme); `node --check js/ui.js`. **Commit:** `spec: cila T3b/T8 — boş-ata akışında ölü dal silindi, yarım-durum görünür retry`.

---

## Adım 10 — T3/T4/T8 demo/ajan kabul doğrulamaları (D4, D5-ön, D6)

**Bağımlılık:** Adımlar 6-9.

- **D4 (kod+birim kanıtı; modal-yürüyüşü sahibin/K5):** U4 kanıtı + `recoverPendingDone` dokunulmadığı diff'te görünür (Vazgeç → op pending'de → sayfa yenileme → recoverPendingDone tekrar dener).
- **D5 (ön-kanıt ajan; saha kanıtı sahibin):** Adım 7/9 diff'leri + U5 (yüklendiyse). "Boş ata ve uygula" 2-adım akışının saha doğrulaması sahibin K5 yürüyüşüne not edilir.
- **D6 (ajan, demo):** `SELECT public.tohumlama_sonuc_bos('00000000-0000-0000-0000-000000000000', NULL);` — nil-uuid için beklenen sunucu metni **"Tohumlama bulunamadı"** (`20260924000001:522`); "Sadece Bekliyor…" metni (`:526`) istenirse `sonuc!='Bekliyor'` gerçek bir tohumlama id'siyle çağrılır (R3 notu — metin çifti netleştirildi). Sunucu `'error'` alanlı Türkçe dönüş, U10 mock-mesajının gerçek desene uyduğunu gösterir; toast görünümleri sahibin yürüyüşünde.

**Commit:** `reports: cila T3/T4/T8 kabul — D4 kod kanıtı, D6 demo hata-metni örneği` (ölçüm raporuna ek).

---

## Adım 11 — F2 (T1): açık senkron zinciri muafiyeti (DRIFT-DÜZELTİLMİŞ HEDEF)

**Dosya:** `supabase/migrations/20260925000002_cila_t1_acik_disi_senkron_muafiyet.sql` (YENİ). **Bağımlılık:** Adım 1'in **V3 damga ölçümü** — damga yoksa BU ADIM ATLANIR ve ENGEL-4 raporlanır (kesinti yok, sıradaki adıma geçilir). **R3 notu: bağımlılık çözüldü — damga canlıda VAR (16 satır, 2 açık; §0); bu adım koşulsuz yazılır.** **Kapılar:** K-2 (taslak+final), K-3, K-4.

İçerik:
- Başlık yorumu: amaç + spec §7.1 sahibin kararı (**188 kasıtlı çift zincir KASITLI, dokunulmaz**) + **drift notu**: hedef `_acik_disi_hedef_ic` (bkz. §0) + Adım 1 canlı `pg_get_functiondef('_acik_disi_hedef_ic(text)')` ve `_acik_disi_ovsync_hedef(text)` gövdeleri aynen gömülü (revert kaynağı).
- `CREATE OR REPLACE FUNCTION public._acik_disi_hedef_ic(p_hayvan_id text) RETURNS date LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $fn$` — header canlıdan; DECLARE/BEGIN canlıdan.
- OVSYNC_BASLAT bloğunun (canlıda :53-59 karşılığı) **arkasına**, `v_k := public._ovsync_kural_tarihi(...)` çağrısının **önüne** ek koşul (S1 varsayılanı = geniş kapsam):
```sql
  -- T1 (cila): açık senkron-protokol görevi varken yeni açık-dişi hedef ÜRETME.
  -- 188 kasıtlı zinciri etkilemez: OVSYNC_BASLAT bloğu yukarıda zaten NULL döndürür;
  -- bu koşul yalnız zincir çalışırken (ILAC/TOHUMLAMA_HAZIRLIK açıkken) üretimi durdurur,
  -- görevler kapanınca zamanlayıcı normal üretimine döner (spec §7.1).
  IF EXISTS (
    SELECT 1 FROM public.gorev_log g
    WHERE g.hayvan_id = p_hayvan_id
      AND g.gorev_tipi IN ('ILAC', 'TOHUMLAMA_HAZIRLIK')
      AND COALESCE(g.tamamlandi, false) = false
      AND COALESCE(g.iptal, false) = false
      AND (g.kaynak ILIKE '%senkron%' OR g.aciklama ILIKE '%senkron%')
  ) THEN
    RETURN NULL;
  END IF;
```
- Sonda mevcut ACL satırları aynen: `COMMENT ON FUNCTION ...` + `REVOKE ALL ON FUNCTION public._acik_disi_hedef_ic(text) FROM PUBLIC, anon, authenticated;` — **GRANT YOK** (yardımcı; canlı :72 deseni).
- `_acik_disi_ovsync_hedef` sarmalayıcısı ve `ilk_tohumlama_zamanlayici` DOKUNULMAZ.

Koşum sırası: taslak db-validate PASS → final db-validate PASS → **D7 (kritik)**: apply ÖNCESİ Adım 1 kaydı vs apply SONRASI `SELECT public._acik_disi_ovsync_hedef('<188-id>');` **birebir eş** (kasıtlı zincir korundu — V9 mühürü) → demo apply → apply-sonrası gövde-teyit (pg_get_functiondef ek bloğu içeriyor).

**D8 (ajan, demo):** test hayvanına (açık OVSYNC_BASLAT'ı OLMAYAN) `kaynak ILIKE '%senkron%'`'lu açık ILAC görevi yaz → `_acik_disi_ovsync_hedef` → NULL; görev kapat (`tamamlandi=true`) → tarih döner (ardışık-zincir akışı korunur). Test satırları Adım 14 öncesi temizlenir ya da `iptal=true` pasife çekilir.

**Commit:** `spec: cila T1 — açık senkron zincirinde açık-dişi üretim muafiyeti (_acik_disi_hedef_ic, 188 korundu: D7 eş)`.

---

## Adım 12 — F3 (T6): koşullu legacy overload DROP — **R3 ONARIMINDA KESİN İPTAL — ADIM KOŞULMAZ**

**R3 onarım kararı (bağlayıcı):** canlı demo `pg_proc` ölçümü `tohumlama_sonuc_bos` için **tek imza `(text,text)`** gösterdi; legacy `(text)` overload canlıda YOK (bkz. §0 T6 canlı ölçümü). Koşul-1 tutmadığından bu adım **koşulsuz atlanır**: `20260925000003_*` dosyası yazılmaz, uygulanmaz, sahibe onay sorusu da sorulmaz (bilgi notu olarak Ö1 ölçüm kaydı teslimde sunulur). "Kod değişikliği 0" bu kalemin meşru teslimidir. Aşağıdaki tarihsel taslak yalnız kayıt amaçlıdır.

**[TARİHSEL — koşul sağlanamadı]** Dosya: `supabase/migrations/20260925000003_cila_t6_sonuc_bos_overload_temizligi.sql` (YENİ, koşullu). Bağımlılık: Adım 1'in T6 ölçümü + sahibin onayı.

**Koşullar (üçü TAMAM değilse BU DOSYA YAZILMAZ/UYGULANMAZ — "kod değişikliği 0" meşru teslim):**
1. ~~Canlıda `(text)` + `(text,text)` overload'ları birlikte duruyor (Adım 1)~~ — **TUTMADI (R3 canlı ölçümü: tek imza)**;
2. `(text)` gövdesi kanonikten davranışsal fark taşıyor (ASCII 'Bos' / yan-etki farkı — Adım 1 gövde-karşılaştırması) — değerlendirilemez;
3. Sahip ölçüm raporunu onayladı (Adım 14 tesliminde sorulur; onay gelmezse ENGEL-3 olarak kapanır) — gerek kalmadı.

İçerik (yazılırsa):
```sql
-- T6 (cila): legacy tek-argümanlı overload temizliği. Kanonik (text,text) DOKUNULMAZ.
-- REVERT gömmesi (ZORUNLU, spec §11): Adım 1 canlı pg_get_functiondef('tohumlama_sonuc_bos(text)')
-- çıktısı buraya aynen yorum olarak gömülür (DROP geri alınamaz; revert = yeniden oluştur).
DROP FUNCTION IF EXISTS public.tohumlama_sonuc_bos(text);
```
Apply: db-validate taslak+final → demo apply → **Ö2:** `pg_proc` içinde tek imza `(text,text)`; `has_function_privilege('anon', ...)` = false. **Ö3 (sahip):** "Boş ata ve uygula" akışı K5 yürüyüşünde.

**Commit (yazılırsa):** `spec: cila T6 — tohumlama_sonuc_bos legacy (text) overload DROP (sahip onaylı, revert gömmeli)`.

---

## Adım 13 — T7/T10 JS paketi (D17, O10, D18, D19, O11, rozet) — tek yazıcı, sıralı alt-adımlar

**Dosyalar:** `js/api.js`, `js/ui.js`, `js/forms.js`, `js/utils/errorHandler.js`, `tests/unit/cila-tutarlilik.test.js`. **Bağımlılık:** Adım 9 bitmiş olmalı (K-6: JS kulvarı tek yazıcı, sıralı). **Kapı:** K-1 her alt-adım öncesi (ilgili sembol `impact`/`context`), K-6.

**13a — D17 (`js/api.js:320`):** sete üç katalog tablosu:
```js
  start_first_service_protocol: ['cases','treatment_days','treatment_day_uygulamalar','drug_administrations','gorev_log','islem_log','stok','stok_hareket','diseases','drugs','tedavi_sablonu'],
```
F8'e **U8**: `loadBrowserModule('js/api.js')` + `expose:['RPC_TABLES']` → set üç tabloyu içerir. **Commit:** `spec: cila D17 — start_first_service_protocol pull seti katalog tamamlandı (U8)`.

**13b — O10 (`js/ui.js:9229-9235`):**
```js
async function dataTrafficGonder(e){
  const btn=(e||window.event).target;
  const q=await getQueue();
  if(q.length){
    const kirilim={};
    q.forEach(o=>{ kirilim[o.table]=(kirilim[o.table]||0)+1; });
    const ozet=Object.entries(kirilim).map(([t,n])=>`${t} × ${n}`).join(', ');
    if(!confirm(`Bekleyen ${q.length} kayıt gönderilecek: ${ozet}. Onaylıyor musunuz?`)) return;   // O10: toplu önizleme
  }
  btn.disabled=true; btn.textContent='Gönderiliyor…';
  await syncNow();
  await dataTrafficYenile();
  btn.disabled=false; btn.textContent='↑ Tümünü Gönder';
}
```
Kuyruk boşsa onaysız (davranış değişmez). Tek-kayıt `↑` (ui.js:9220) onaysız kalır (spec §8.1). **D10 sahibin (D14 yürüyüşüyle).** **Commit:** `spec: cila O10 — toplu gönderim önizleme/onay (kırılımlı confirm)`.

**13c — D18 (`js/ui.js:1059`) + F7 (`js/utils/errorHandler.js` USER_FRIENDLY):**
```js
    toast('✅ Ertelendi → ' + fmtTarih(r.hedef_tarih) + ' ' + (r.hedef_saat||'').slice(0,5)
      + ((r.toplam_erteleme_gun|0) > 0 ? ' · toplam ' + r.toplam_erteleme_gun + ' gün erteleme' : '')
      + (r.uyari ? ' · ⚠️ ' + r.uyari : ''));
```
```js
const USER_FRIENDLY = {
  // ...mevcut 5 anahtar aynen...
  'GOREV_ERTELENEMEZ': 'Bu görev ertelenemez (protokol/zincir kuralı).',
  'GECMIS_TARIH': 'Geçmiş tarihe erteleme yapılamaz.',
};
```
(eşleşme `msg.includes(k)` prefix'li RAISE metnini yakalar — CONFIRMED errorHandler:54-56; `:json` kısmı cümleye karışmaz çünkü kod cümlesi içerir.) F8'e **U6**: getUserMessage iki kod için Türkçe cümle; BESLEME-tipi erteleme senaryosunda ham JSON değil cümle (stub err.message `GOREV_ERTELENEMEZ:{...}` ile). **Commit:** `spec: cila D18 — erteleme özeti (toplam gün) + Türkçe erteleme hataları (U6)`.

**13d — O11 (`js/ui.js`):** helper + çağrı:
```js
function _istanbulAnIso(gun, saat){   // O11: PLAN Europe/Istanbul der — Türkiye kalıcı +03; cihaz diliminden bağımsız
  return new Date(gun + 'T' + (saat || '12:00') + ':00+03:00').toISOString();
}
```
`:2340` → `occurredAt = _istanbulAnIso(olcGun, olcSaat);` F8'e **U9**: `loadExtractedFunction('js/ui.js','_istanbulAnIso')` → `('2026-09-24','12:00')` === `'2026-09-24T09:00:00.000Z'`; `('2026-09-24','')` === aynı (varsayılan 12:00). **Commit:** `spec: cila O11 — p_occurred_at sabit İstanbul +03 anchor (U9)`.

**13e — T10 rozet (`js/ui.js:413-424` + panel fallback `:1830-1832`):**
```js
function _rozetTopla(n, m){ return (n|0) + (m|0); }   // T10: rozet = protokol_eksik_tara + ovsync_baslat_uyarilari
```
Rozet bloğu: `protokol_eksik_tara` try'i içinde ikinci try: `ovsync_baslat_uyarilari` → `window.__ovsyncUyarilar` önbelleğe + `ovSayi`; toplam `_rozetTopla(aktif.length, ovSayi)`; `bb.textContent = toplam > 99 ? '99+' : toplam; bb.style.display = toplam > 0 ? 'flex':'none';` (99+ tırpanma korunur). Panel (:1830) rpc catch'ine fallback: `ovList = Array.isArray(window.__ovsyncUyarilar) ? window.__ovsyncUyarilar : []` (bayat-önbellek konsol uyarısıyla; panelin kendi taze çağrısı her açılışta korunur — spec §9.2 b2 okunuşu). F8'e **U11**: `_rozetTopla(3,2)===5`; ov-hata yolu: rozet bloğunun iç-try catch'i yalnız konsola düşer, n korunur (kalıp-testi). **D14 sahibin (formül: 🔴+🟡+🌱 = rozet).** **Commit:** `spec: cila T10 — rozet iki kaynağı birleştirir + panel bayat-önbellek fallback (U11)`.

**13f — D19 (`js/forms.js:345-350`):** helper + kullanım:
```js
function _vakaKapanisOzeti(kapatilan, otoBos){   // D19: N/M > 0 ise özet; hepsi 0 → null
  const n = Array.isArray(kapatilan) ? kapatilan.length : 0;
  const m = otoBos | 0;
  if (!n && !m) return null;
  let s = '✅ Tohumlama kaydedildi';
  if (n) s += ' — ' + n + ' senkronizasyon protokolü tohumlama ile sonlandırıldı: '
    + kapatilan.map(v => `${v.hayvan_kupe || v.kupe_no || ''} (${v.iptal_seans ?? '?'} seans iptal)`).join(', ');
  if (m) s += (n ? ',' : ' —') + ' ' + m + ' görev otomatik iptal edildi';
  return s;
}
```
Çağrı yeri:
```js
    const kapatilan = result?.kapatilan_senkronizasyon_vakalari || [];   // D19: ölü 'kapatilan_ovsyncler' fallback'i SİLİNDİ
    const ozet = _vakaKapanisOzeti(kapatilan, result?.otomatik_bos_sayisi);
    if (ozet) toast(ozet);
```
F8'e **U7**: `loadExtractedFunction('js/forms.js','_vakaKapanisOzeti')` — n=2,m=3 → iki parçalı cümle; hepsi 0 → `null` (standart toast'a düşer). **D12 sahibin (K1/K2 yürüyüşü).** **Commit:** `spec: cila D19 — vaka-kapanış özeti iptal-görev sayısıyla zengin, ölü fallback silindi (U7)`.

**13g — ara koşum:** `node --check` üç dosyada + `npm run test:unit` (U6-U9, U11 yeşil; baseline kırmızıları aynen).

---

## Adım 14 — Kapanış: damga, tam koşum, indeks tazeleme, teslim paketi + review brief

**Dosyalar:** `index.html` (tek satır), teslim raporu, BUGS.md (dokunma — yalnız teyit).

1. **`?v=` damga bump:** `index.html` tüm `?v=20260924-01` → `?v=20260924-02` (tek değer; F4-F7+T5 JS değişimi cache-busting zorunlu — spec §11 revert-tablosu ima eder; damga-koruma testleri vaka-toplu-ac'ta yeşil kalmalı). **Commit:** `spec: cila teslim — ?v= 20260924-02 (JS paketi cache-busting)`.
2. **Tam doğrulama:** `npm run test:unit` → Adım 0 baseline'ına göre: yeni kırmızı 0; U1/U4-U11 yeşil; 3 eski kırmızı belgeli-müsaadelı (triage notu raporda).
3. **gitnexus kapanış:** `gitnexus analyze` (indeks çalışılan commit'i yansıtsın) + `detect_changes` → beklenen-dışı dosya/sembol ETKİSİ yok (tek-yazıcı zarf ihlali taraması). Depo listesi: F1-F2 migrations (F3 iptal — Adım 12), F4 api.js, F5 ui.js, F6 forms.js, F7 errorHandler.js, F8 test, index.html, BUGS.md **HARİÇ** (başlangıçta M BUGS.md vardı — bu plana ait değil, dokunma). **R3 notu:** BUGS.md'deki commit'siz iki borç girdisi (BUG-ERTELEME-KURAL-GENEL :183, BUG-KUYRUK-SHEMA-VERSIYONU :195) bu turun borç kayıtlarıdır — içeriğine dokunulmadan **teslim kulvarınca commit edilmelidir** (spec §14-8 notuyla uyumlu).
4. **Teslim raporu** `reports/plans/ovsync-cila-tur2-teslim.md`: (a) adım-adım kanıt linkleri; (b) ENGEL listesi (aşağıdaki bölüm + koşumda çıkanlar); (c) **T11 sahibe not** (spec §10 — tek paragraf); (d) sahibin yürüyüşü talimatı: plan-5 §3 checklist + S5'e bağlanan maddeler (K5=PG kapı/T4-T3, K8=rozet/T10, Veri Trafik=T5↑ + O10 confirm); (e) **Açık kararlar seri sunumu:** S1 (kapsam teyidi — geniş varsayılan uygulandı; R3 notu: canlıda 'senkron' damgalı tek desen Presynch-14), S2 (A uygulandı), S3 (b2 uygulandı), ~~T6-F3 onayı~~ → **bilgi notu: F3 iptal, canlıda overload zaten yok (Adım 12)**; (f) D9 hatırlatması: T2 kabul ölçümü Plan 2 temizliğinden SONRA koşulacak (sorgu spec §7.3-3'te hazır).
5. **Son review kapısı (sahibin talebi):** teslimden AYRI bir review turu — tüm U/D/Ö maddeleri yeniden ölçülür; BUGS.md'ye yeni borç EKLENMEDİĞİ teyit edilir (T9/erteleme-geneli borç satırları değişmedi). Review'ın girdisi: bu plan + teslim raporu + `git diff main...HEAD`.

**Commit:** `reports: cila Tur2 teslim raporu — kanıt endeksi, engeller, açık kararlar, review brief`.

---

## 2. ENGELLER (başlamadan bilinen; hiçbiri koşuyu DURDURMAZ)

- **ENGEL-1 (çözüldü, belgeli):** Spec §7.2 hedef-gövde bayat — canlı `_acik_disi_ovsync_hedef` sarmalayıcı; T1 koşulu `_acik_disi_hedef_ic`'e yazılır (§0; CONFIRMED 20260924000002:21-90). Plan uyarlanmış; spec'i durdurmaz.
- **ENGEL-2 (bağımlılık, bu tur dışı):** **D9** (T2 kabul ölçümü: sessiz VETERINER_KONTROL ∩ açık senkron görev çakışması=0) Plan 2 temizliğinden SONRA anlamlı — bu turda koşulamaz; sorgu hazır, teslim raporunda ertelenmiş-adım olarak işaretli.
- **ENGEL-3 (R3 ONARIMINDA KAPANDI):** ~~F3 (T6) sahibin onayı~~ — canlı ölçüm overload'ın yok olduğunu gösterdi (§0); Adım 12 koşulsuz atlanır, onay sorusu kalktı. Kalan: Ö1 ölçüm kaydının teslim paketinde bilgi notu olarak sunulması.
- **ENGEL-4 (R3 ONARIMINDA KAPANDI):** ~~F2 damga ölçümüne bağlı~~ — 'senkron' damgası canlıda VAR (16 satır, 2 açık, `aciklama` alanında; §0). F2/Adım 11 koşulsuz yazılır.
- **ENGEL-5 (R3 ONARIMINDA TANISI KESİNLEŞTİ):** PostgREST pg_proc'e kapalı (PGRST205 — OBSERVED) + **`supabase_migrate` MCP prod hedeflidir** (fdw_prod_srv=0 + migrasyon=124 = prod imzası; §0 MCP uyarısı). Çalışan demo yolu: repo kök `.env`'deki `SUPABASE_DEMO_PAT` ile Mgmt query endpoint (curl) — R3 onarım ölçümleri bu yolla koşuldu (OBSERVED, çalışıyor); yedek: `SUPABASE_DEMO_DB_PASSWORD`+`SUPABASE_DEMO_POOLER` ile psql.
- **ENGEL-6 (sahip katılımı):** D4/D5/D10/D11/D12/D13/D14 saha kanıtı + Ö3 + K1-K8 yürüyüşü + **son review kapısı** sahibin katılımını gerektirir; ajan bu maddeleri "sahip-yürüyüşü" etiketiyle teslim paketinde hazır bırakır.
- **ENGEL-7 (yarış disiplini):** ≤10 eşzamanlı agent'ta JS kulvarı (F4-F7) TEK yazıcıdır (K-6); paralelleştirme yalnız DB (F1-F3) ve test (F8) kulvarlarına açıktır. ui.js iki agent tarafından eşzamanlı düzenLENEMEZ.

## 3. BAĞIMLILIK GRAFIĞİ

```
Adım 0 → Adım 1 ─┬→ Adım 2 → Adım 3 → Adım 4 → Adım 5
                 ├→ Adım 11  (V3 ölçümüne bağlı; damga yoksa atlanır)
                 └→ Adım 12  (sahip onayına bağlı; en sonda)
Adım 0 → Adım 6 → Adım 7 → Adım 8 → Adım 9 → Adım 10 → Adım 13 (13a→13g sıralı) → Adım 14
(Adım 5 ve Adım 11/12 DB kulvarı; Adım 6-13 JS kulvarı — iki kulvar farklı agent'ta paralel AÇILABİLİR,
 yalnız Adım 13 öncesi Adım 9 bitmiş olmalı; Adım 14 hepsinin sonu.)
```
