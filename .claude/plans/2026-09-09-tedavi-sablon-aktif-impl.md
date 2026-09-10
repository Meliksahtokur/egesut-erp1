# Aktif Vakaya Tedavi Şablonu Uygulama — Implementation Plan

> **REQUIRED SUB-SKILL:** Bu plan bir general-purpose subagent tarafından,
> görev görev (task-by-task) uygulanır. Tasarım/spec:
> `/home/melik/egesut-erp1/.claude/plans/2026-09-09-tedavi-sablon-aktif-design.md`

**Goal:** Aktif (açık) bir vakaya, kullanıcınn seçtiği tarihin "şablonun 1.
günü" sayıldığı bir tedavi şablonu uygulanabilsin.

**Architecture:** İki mevcut RPC'ye (`tedavi_sablon_uygula`,
`tedavi_sablon_tohumlama_gorev_ekle`) opsiyonel `p_baslangic_tarihi date
DEFAULT NULL` parametresi eklenir (geriye uyumlu; NULL ⇔ mevcut
`case.start_date` çapası). UI, vaka detayı modalında (m-case-det)
`cd-gun-bolum` içine bc-sablon-yukle (toplu vaka) deseninde katlanır bir alan
ekler; saf liste çekirdeği (`cdSablonListeBul`) ui.js'te DOM'suz test edilir.

**Tech Stack:** Vanilla JS (classic scripts, global scope), Supabase
PostgreSQL RPC (SECURITY DEFINER plpgsql), node:test + vm loader
(tests/unit/support/loadModule.js).

**ÇALIŞMA ORTAMI (ZORUNLU):**
- Worktree: `/home/melik/egesut-wt/tedavi-sablon-aktif`, branch
  `idle/tedavi-sablon-aktif` (main 88b311b'den). TÜM dosya yolları bu köke
  göredir. Ana repo `/home/melik/egesut-erp1`'e YAZMA.
- Başlangıçta `git -C /home/melik/egesut-wt/tedavi-sablon-aktif status --short`
  → boş olmalı. Değilse DUR ve raporla.
- Edit aracı olarak sed DEĞİL, Edit/Write kullan (repo kuralı: onclick
  escAttr-inline ölüyor; dataset deseni ZORUNLU — bu planda verilen kod
  zaten dataset kullanıyor).
- `git add` yalnız bu görevde değişen dosyalarla sınırlı (bulk add YASAK).
- Merge/push/deploy YOK. Local DB erişimi YOK (migration sadece dosya olarak
  yazılır; deploy root'un ayrı kapısıdır).
- Hook uyarıları (`js_edit_guard`, `sql_migration_guard`) gelirse oku;
  sql_migration_guard postgrestools check'i çalışsın (atlamak için
  ZCODE_GUARD_SKIP_LSP kullanma; ~0.4 sn sürer).
- Pattern refs (contract attestation): RPC-WRITE-01, MODAL-ROUTER-01,
  FORM-SUBMIT-01, TESTING-01.
- Commit mesajları repo tarzında kısa Türkçe conventional
  (`feat(tedavi): ...`).

**Test komutu:** `npm run test:unit` (worktree kökünde;
`node --test tests/unit/*.test.js`). Mevcut taban 676 test —
sadece YENİ testler eklenir, hiçbiri değiştirilmez/silinmez.

---

### Task 1: Migration — iki RPC'ye opsiyonel çapa tarihi

**TDD scenario:** Trivial change — SQL yerel test altyapısı yok; doğrulama
sql_migration_guard (postgrestools check) + görsel diff.

**Files:**
- Create: `supabase/migrations/20260909000001_sablon_aktif_vakaya_uygula.sql`

**Step 1.1: Migration dosyasını yaz** — tam içerik:

```sql
-- 20260909000001_sablon_aktif_vakaya_uygula.sql
-- Aktif vakaya şablon uygulama: iki şablon RPC'sine opsiyonel çapa tarihi.
-- p_baslangic_tarihi NULL ⇔ eski davranış (case.start_date çapası) — geriye
-- uyumlu: submitCase (forms.js) ve vaka_toplu_ac'un 2-argümanlı çağrıları
-- DEFAULT üzerinden aynı davranışa bağlanır (PL/pgSQL çağrıları plan-anında
-- isimle çözümlenir; DROP+CREATE sonrası iç çağrılar yeniden bağlanır).
-- Gövdeler: tedavi_sablon_uygula = GT/20260613000009 birebir;
-- tohumlama = 20260730000002 birebir. Yalnız v_date çapası COALESCE'e bağlandı.

-- 1) tedavi_sablon_uygula — gün kalemlerini çapadan dizer
DROP FUNCTION IF EXISTS public.tedavi_sablon_uygula(uuid, uuid);
CREATE FUNCTION public.tedavi_sablon_uygula(
  p_case_id          uuid,
  p_sablon_id        uuid,
  p_baslangic_tarihi date DEFAULT NULL
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_case         record;
  v_gun_no       smallint;
  v_date         date;
  v_sessions     jsonb;
  v_atlanan      jsonb := '[]'::jsonb;
  v_gun_atlanan  jsonb;
  v_gun_sayisi   int := 0;
  v_seans_sayisi int := 0;
BEGIN
  SELECT * INTO v_case FROM public.cases WHERE id = p_case_id;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'mesaj', 'Vaka bulunamadı'); END IF;
  IF v_case.status = 'closed' THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Kapalı vakaya şablon uygulanamaz');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.tedavi_sablonu WHERE id = p_sablon_id) THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Şablon bulunamadı');
  END IF;

  FOR v_gun_no IN
    SELECT DISTINCT gun_no FROM public.tedavi_sablonu_kalem
    WHERE sablon_id = p_sablon_id ORDER BY gun_no
  LOOP
    v_date := COALESCE(p_baslangic_tarihi, v_case.start_date) + (v_gun_no - 1);

    SELECT COALESCE(jsonb_agg(jsonb_build_object(
             'planned_time',    to_char(k.planned_time,'HH24:MI'),
             'stok_id',         k.stok_id,
             'drug_product_id', k.drug_product_id,
             'dose',            k.dose,
             'unit',            k.unit,
             'route',           k.route
           ) ORDER BY k.planned_time), '[]'::jsonb)
    INTO v_sessions
    FROM public.tedavi_sablonu_kalem k
    WHERE k.sablon_id = p_sablon_id AND k.gun_no = v_gun_no
      AND (k.drug_product_id IS NULL OR EXISTS (SELECT 1 FROM public.drug_products dp WHERE dp.id = k.drug_product_id))
      AND (k.stok_id IS NULL OR EXISTS (SELECT 1 FROM public.stok s WHERE s.id = k.stok_id));

    SELECT COALESCE(jsonb_agg(jsonb_build_object(
             'gun_no', k.gun_no,
             'planned_time', to_char(k.planned_time,'HH24:MI'),
             'neden', 'silinmiş ilaç/stok')), '[]'::jsonb)
    INTO v_gun_atlanan
    FROM public.tedavi_sablonu_kalem k
    WHERE k.sablon_id = p_sablon_id AND k.gun_no = v_gun_no
      AND ((k.drug_product_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public.drug_products dp WHERE dp.id = k.drug_product_id))
        OR (k.stok_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public.stok s WHERE s.id = k.stok_id)));
    IF jsonb_array_length(v_gun_atlanan) > 0 THEN
      v_atlanan := v_atlanan || v_gun_atlanan;
    END IF;

    IF jsonb_array_length(v_sessions) > 0 THEN
      PERFORM public.add_treatment_day_with_sessions(p_case_id, v_date, v_sessions, NULL);
      v_gun_sayisi   := v_gun_sayisi + 1;
      v_seans_sayisi := v_seans_sayisi + jsonb_array_length(v_sessions);
    END IF;
  END LOOP;

  RETURN jsonb_build_object('ok', true,
    'gun_sayisi', v_gun_sayisi, 'seans_sayisi', v_seans_sayisi, 'atlanan', v_atlanan);
END;
$$;

GRANT EXECUTE ON FUNCTION public.tedavi_sablon_uygula(uuid, uuid, date) TO anon, authenticated;

-- 2) tedavi_sablon_tohumlama_gorev_ekle — planlı tohumlamayı çapadan dizer
DROP FUNCTION IF EXISTS public.tedavi_sablon_tohumlama_gorev_ekle(uuid, uuid);
CREATE FUNCTION public.tedavi_sablon_tohumlama_gorev_ekle(
  p_case_id          uuid,
  p_sablon_id        uuid,
  p_baslangic_tarihi date DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
  v_plan  jsonb;
  v_case  record;
  v_sebep text;
  v_id    uuid;
  v_date  date;
  v_time  time;
BEGIN
  -- nullif(...,'null'::jsonb): kolonda jsonb 'null' skaleri duruyor olabilir.
  SELECT nullif(tohumlama_plani, 'null'::jsonb) INTO v_plan
  FROM public.tedavi_sablonu WHERE id = p_sablon_id;
  IF v_plan IS NULL THEN
    RETURN jsonb_build_object('ok', true, 'olustu', false);
  END IF;
  IF (v_plan->>'gun_ofset') IS NULL OR nullif(v_plan->>'planned_time','') IS NULL THEN
    RETURN jsonb_build_object('ok', true, 'olustu', false, 'sebep', 'Şablondaki tohumlama planı eksik');
  END IF;

  SELECT * INTO v_case FROM public.cases WHERE id = p_case_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Vaka bulunamadı'; END IF;

  IF EXISTS (SELECT 1 FROM public.gorev_log
             WHERE kaynak = 'TEDAVI_SABLON_TOHUMLAMA:' || p_case_id::text || ':' || p_sablon_id::text) THEN
    RETURN jsonb_build_object('ok', true, 'olustu', false);
  END IF;

  v_date := COALESCE(p_baslangic_tarihi, v_case.start_date) + (v_plan->>'gun_ofset')::integer;
  v_time := (v_plan->>'planned_time')::time;

  -- Uygun değilse vaka açılışı patlamaz; görev açılmaz, sebep UI'a döner.
  v_sebep := public._tohumlama_gorev_uygunluk(v_case.animal_id, v_date);
  IF v_sebep IS NOT NULL THEN
    RETURN jsonb_build_object('ok', true, 'olustu', false, 'sebep', v_sebep);
  END IF;

  INSERT INTO public.gorev_log(id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, hedef_saat, tamamlandi, kaynak)
  VALUES(gen_random_uuid(), v_case.animal_id, 'TOHUMLAMA_PLANLI', 'Planlı tohumlama', v_date, v_time, false,
          'TEDAVI_SABLON_TOHUMLAMA:' || p_case_id::text || ':' || p_sablon_id::text)
  RETURNING id INTO v_id;
  RETURN jsonb_build_object('ok', true, 'olustu', true, 'gorev_id', v_id);
END;
$function$;

GRANT EXECUTE ON FUNCTION public.tedavi_sablon_tohumlama_gorev_ekle(uuid, uuid, date) TO anon, authenticated;
```

**Step 1.2: Guard doğrulaması** — dosya yazımında `sql_migration_guard`
hook'u `postgrestools check` çalıştırır; DENY gelirse hatayı oku ve düzelt
(beklenen: geçer).

**Step 1.3: Commit**

```bash
cd /home/melik/egesut-wt/tedavi-sablon-aktif
git add supabase/migrations/20260909000001_sablon_aktif_vakaya_uygula.sql
git commit -m "feat(tedavi): sablon RPC'lerine opsiyonel baslangic tarihi (aktif vaka zemini)"
```

---

### Task 2: Saf çekirdek `cdSablonListeBul` — TDD

**TDD scenario:** New feature — full TDD cycle.

**Files:**
- Test (create): `tests/unit/tedavi-sablon-aktif.test.js`
- Modify: `js/ui.js` (fonksiyon, Task 3'teki UI bloğuyla AYNI bölgeye)

**Step 2.1: failing test'i yaz** — tam dosya:

```js
// tests/unit/tedavi-sablon-aktif.test.js
// Aktif vakaya şablon uygulama — saf çekirdek birim testleri.
// cdSablonListeBul: bcSablonYukleListeRender (forms.js) satır hesabının
// DOM'suz aynası — gun = unique gun_no sayısı, seans = kalem sayısı,
// tohumVar = tohumlama_plani tam mı (gun_ofset + planned_time).
const test = require('node:test');
const assert = require('node:assert');
const { loadBrowserModule } = require('./support/loadModule.js');

const { sandbox } = loadBrowserModule('js/ui.js');
const { cdSablonListeBul } = sandbox;

const E = (sablon_id, disease_id) => ({ sablon_id, disease_id });
const S = (id, ad, tohumlama_plani) => ({ id, ad, tohumlama_plani: tohumlama_plani ?? null });
const K = (sablon_id, gun_no) => ({ sablon_id, gun_no });

test('hastaliga bagli sablon: gun=unique gun_no, seans=kalem sayisi, tohum=false', () => {
  const r = cdSablonListeBul(
    [E('s1', 'd1')],
    [S('s1', 'Mantar')],
    [K('s1', 1), K('s1', 1), K('s1', 3)],
    'd1'
  );
  assert.deepStrictEqual(r, [
    { id: 's1', ad: 'Mantar', gun: 2, seans: 3, tohumVar: false },
  ]);
});

test('tohumlama_plani tam ise tohumVar=true; eksik parcali planlarda false', () => {
  const sablonlar = [
    S('s1', 'Tam', { gun_ofset: 2, planned_time: '09:00' }),
    S('s2', 'OfsetYok', { planned_time: '09:00' }),
    S('s3', 'SaatYok', { gun_ofset: 2 }),
    S('s4', 'Null', null),
  ];
  const eslem = [E('s1', 'd1'), E('s2', 'd1'), E('s3', 'd1'), E('s4', 'd1')];
  const r = cdSablonListeBul(eslem, sablonlar, [], 'd1');
  assert.strictEqual(r[0].tohumVar, true);
  assert.strictEqual(r[1].tohumVar, false);
  assert.strictEqual(r[2].tohumVar, false);
  assert.strictEqual(r[3].tohumVar, false);
});

test('baska hastaliga eslenmis sablon ve eslemsiz sablon listelenmez', () => {
  const r = cdSablonListeBul(
    [E('s1', 'd2'), E('yok', 'd1')],
    [S('s1', 'Baska'), S('yoksablon', 'Yetim')],
    [K('s1', 1)],
    'd1'
  );
  assert.deepStrictEqual(r, []); // 'yok' eslemi sablon bulunamadigi icin duser
});

test('coklu sablon eslem sirasi korunur', () => {
  const r = cdSablonListeBul(
    [E('s2', 'd1'), E('s1', 'd1')],
    [S('s1', 'A'), S('s2', 'B')],
    [],
    'd1'
  );
  assert.deepStrictEqual(r.map(x => x.ad), ['B', 'A']);
});

test('bos/eksik girdi → [] (patlama yok)', () => {
  assert.deepStrictEqual(cdSablonListeBul(null, null, null, 'd1'), []);
  assert.deepStrictEqual(cdSablonListeBul([], [], [], 'd1'), []);
});
```

**Step 2.2: Testin FAIL olduğun doğrula**

Run: `cd /home/melik/egesut-wt/tedavi-sablon-aktif && node --test tests/unit/tedavi-sablon-aktif.test.js`
Expected: FAIL — `cdSablonListeBul` undefined (sandbox'ta yok).
NOT: `loadBrowserModule('js/ui.js')` yüklemesi patlarsa (ui.js zaten
ui-pure.test.js'de çıplak yüklenebiliyor — oraya bak), ui-pure.test.js'in
yükleme bloğunu aynen uygula (`extra: { esc, escAttr, fmtTarih }` aynaları).

**Step 2.3: Minimal implementasyon** — `js/ui.js`'te `caseGunEkleOnayla`
fonksiyonunun bittiği yerin hemen sonrasına (≈ satır 6362, `caseTohumlamaEkleAc`
tanımından ÖNCE) ekle:

```js
// ═══ AKTİF VAKAYA ŞABLON UYGULAMA (2026-09-09) ═══
// Desen: bc-sablon-yukle (forms.js:1382) katlanır alanı + submitCase
// (forms.js:616-629) çift-RPC akışı. Çapa: cd-sablon-tarih = şablonun
// 1. günü (RPC'de tarih = çapa + (gun_no − 1)); p_baslangic_tarihi NULL
// ⇔ açılıştaki start_date çapası.

// Saf çekirdek — tests/unit/tedavi-sablon-aktif.test.js yeşil kilidi.
// bcSablonYukleListeRender (forms.js:1413-1421) satır hesabının DOM'suz aynası.
function cdSablonListeBul(eslem, sablonlar, kalemler, diseaseId){
  const list = (eslem || []).filter(e => e.disease_id === diseaseId)
    .map(e => (sablonlar || []).find(s => s.id === e.sablon_id)).filter(Boolean);
  return list.map(s => {
    const sk = (kalemler || []).filter(k => k.sablon_id === s.id);
    const tp = s.tohumlama_plani;
    return { id: s.id, ad: s.ad,
             gun: new Set(sk.map(k => k.gun_no)).size,
             seans: sk.length,
             tohumVar: !!(tp && typeof tp === 'object' && tp.gun_ofset != null && tp.planned_time) };
  });
}
```

**Step 2.4: Testin PASS olduğun doğrula**

Run: `node --test tests/unit/tedavi-sablon-aktif.test.js`
Expected: 5 test PASS.

**Step 2.5: Commit**

```bash
git add tests/unit/tedavi-sablon-aktif.test.js js/ui.js
git commit -m "feat(tedavi): cdSablonListeBul saf cekirdek + birim testleri"
```

---

### Task 3: UI bloğu — index.html + ui.js akışı + router + ?v= bump

**TDD scenario:** Modifying tested code — önce `npm run test:unit` tam
koşulu yeşil bilmeli (Task 2 sonrası öyle), sonra UI eklenir ve tekrar tam
koşulur. UI DOM akışı birim testine girmiyor (ui-pure.test.js kapsam
yorumu: sadece saf/hesaplanabilir fonksiyonlar).

**Files:**
- Modify: `index.html` (`cd-gun-bolum` bloğu, ≈ satır 2053-2058)
- Modify: `js/ui.js` (Task 2'deki bloğun devamı)
- Modify: `js/utils/handlers.js` (≈ satır 339-340 çevresi)

**Step 3.1: index.html — buton + katlanır alan**

Mevcut blok (satır ~2053):

```html
      <div id="cd-gun-bolum">
        <button class="btn" style="background:var(--blue);color:#fff;width:100%;margin-bottom:6px"
          data-action="case-gun-ekle">➕ Tedavi Günü Ekle</button>
        <button class="btn" style="background:none;border:1.5px solid var(--green);color:var(--green);width:100%;margin-bottom:10px"
          data-action="case-tohumlama-ekle">🐄 Planlı Tohumlama Ekle</button>
      </div>
```

`case-tohumlama-ekle` butonundan SONRA, `</div>`'den önce ekle:

```html
        <button class="btn" style="background:none;border:1.5px solid var(--blue);color:var(--blue);width:100%;margin-bottom:6px"
          data-action="cd-sablon-toggle">📋 Şablondan Plan Ekle ▾</button>
        <div id="cd-sablon-alan" style="display:none;background:var(--card2);border:1px solid var(--card3);border-radius:10px;padding:10px;margin-bottom:10px">
          <label style="display:block;font-size:.74rem;font-weight:700;color:var(--ink2);margin-bottom:4px">Şablonun ilk günü</label>
          <input id="cd-sablon-tarih" class="fi" type="date" style="width:100%">
          <div id="cd-sablon-list" style="margin-top:8px;max-height:180px;overflow-y:auto"></div>
        </div>
```

**Step 3.2: ?v= damgası bump (TEK ORTAK DEĞER)**

index.html'de 15 adet `v=20260908-1` var (bir adet `?v=` yalnız yorumda,
satır ~2200 — dokunma). Tümünü `v=20260909-1` yap:

```bash
cd /home/melik/egesut-wt/tedavi-sablon-aktif
grep -c 'v=20260908-1' index.html   # → 15 (önce)
sed -i 's/v=20260908-1/v=20260909-1/g' index.html
grep -c 'v=20260908-1' index.html   # → 0
grep -c 'v=20260909-1' index.html   # → 15 (sonra)
```

(Kısmi bump YASAK — hafıza kuralı: damga testi kısmi bump'ta kırılır.)

**Step 3.3: ui.js — akış fonksiyonları** (Task 2'deki `cdSablonListeBul`'ün
hemen ardına):

```js
function caseSablonToggle(){
  const alan = document.getElementById('cd-sablon-alan');
  if(!alan) return;
  const aciliyor = alan.style.display !== 'block';
  alan.style.display = aciliyor ? 'block' : 'none';
  if(aciliyor){
    const tarihEl = document.getElementById('cd-sablon-tarih');
    if(tarihEl && !tarihEl.value) tarihEl.value = bugun();
    caseSablonListeRender();
  }
}

async function caseSablonListeRender(){
  const list = document.getElementById('cd-sablon-list');
  if(!list || !_curCase) return;
  // Yalnız VAKANIN hastalığına bağlı şablonlar — açılış listesiyle aynı
  // kaynak (sablon_hastalik_eslem; bcSablonYukleListeRender deseni).
  const [eslem, sablonlar, kalemler] = await Promise.all([
    idbGetAll('sablon_hastalik_eslem'), idbGetAll('tedavi_sablonu'), idbGetAll('tedavi_sablonu_kalem')
  ]);
  const liste = cdSablonListeBul(eslem, sablonlar, kalemler, _curCase.disease_id);
  if(!liste.length){
    list.innerHTML = '<div style="font-size:.74rem;color:var(--ink3);padding:4px 0">Bu hastalık için kayıtlı şablon yok.</div>';
    return;
  }
  list.innerHTML = liste.map(s =>
    '<div style="display:flex;align-items:center;gap:8px;padding:5px 0;font-size:.8rem;border-bottom:1px solid var(--card3)">' +
    '<span style="flex:1;min-width:0;font-weight:600;color:var(--ink)">' + esc(s.ad) +
    '<span style="color:var(--ink2);font-size:.72rem;font-weight:400"> — ' + s.gun + ' gün · ' + s.seans + ' seans' +
    (s.tohumVar ? ' · 🐄 tohumlama' : '') + '</span></span>' +
    '<button type="button" class="ek-chip" data-action="cd-sablon-uygula" data-sablon-id="' + escAttr(s.id) +
    '" style="font-weight:700;color:var(--blue);border-color:rgba(42,107,181,.4)">Uygula</button></div>'
  ).join('');
}

async function caseSablonUygula(sablonId){
  if(!sablonId || !_curCase) return;
  if(!navigator.onLine){ toast('⚠️ İnternet bağlantısı gerekli', true); return; }
  const tarih = v('cd-sablon-tarih');
  if(!tarih){ toast('Şablonun ilk gününü seçin', true); return; }
  try {
    const r = await rpc('tedavi_sablon_uygula',
      { p_case_id: _curCase.id, p_sablon_id: sablonId, p_baslangic_tarihi: tarih });
    let tohumMsg = '';
    // submitCase (forms.js:620-624) toast dili birebir; ikinci RPC ayrı
    // try'da — günler zaten eklendi, tazeleme atlanmamalı.
    try {
      const planli = await rpc('tedavi_sablon_tohumlama_gorev_ekle',
        { p_case_id: _curCase.id, p_sablon_id: sablonId, p_baslangic_tarihi: tarih });
      if(planli?.sebep) toast(`ℹ️ Planlı tohumlama görevi açılmadı: ${planli.sebep}`, true);
      if(planli?.olustu) tohumMsg = ' + tohumlama';
    } catch(e) { toast('Şablon günleri eklendi ama planlı tohumlama açılamadı: ' + e.message, true); }
    if(r?.atlanan?.length) toast(`⚠️ ${r.atlanan.length} kalem atlandı (silinmiş ilaç)`, true);
    toast(`✅ Şablon uygulandı (${r?.gun_sayisi||0} gün)${tohumMsg}`);
    const alan = document.getElementById('cd-sablon-alan');
    if(alan) alan.style.display = 'none';
    await pullTables(['cases','treatment_days','treatment_day_uygulamalar','drug_administrations','stok','stok_hareket','gorev_log','islem_log']);
    _drugsCache = [];
    await loadDrugsCache();
    await renderCaseTimeline(_curCase.id);
    _updateKapatBtn(_curCase.id);
  } catch(e) { toast(getUserMessage(e), true); }
}
```

(Yardımcılar global scope'tan gelir: `v`, `esc`, `escAttr`, `toast`,
`bugun`, `idbGetAll`, `rpc`, `pullTables`, `getUserMessage` —
ui.js zaten hepsini kullanıyor; klasik script'ler global lexical scope
paylaşır.)

**Step 3.4: handlers.js — router kayıtları**

`js/utils/handlers.js` ≈ satır 339-340'taki bloğa, `'case-tohumlama-ekle'`
satırından sonra ekle:

```js
  'cd-sablon-toggle':      () => caseSablonToggle(),
  'cd-sablon-uygula':      (el) => caseSablonUygula(el.dataset.sablonId),
```

**Step 3.5: Tam unit koşusu**

Run: `npm run test:unit`
Expected: TÜM testler PASS (mevcut taban + Task 2'nin 5 yeni testi;
hiçbir mevcut test değişmemeli). Başarısızlık olursa DÜZELT — regresyon
bırakma.

**Step 3.6: Bare-identifier tutarlılık taraması** (repo disiplini):

```bash
rg -n "cdSablonListeBul|caseSablonToggle|caseSablonListeRender|caseSablonUygula|cd-sablon" js/ index.html
```
Expected: her sembol hem tanım hem kullanım yerleriyle tutarlı; yazım
farkı yok.

**Step 3.7: Commit**

```bash
git add index.html js/ui.js js/utils/handlers.js
git commit -m "feat(tedavi): aktif vakaya sablon uygulama UI'i (vaka detayi + ?v= bump)"
```

---

### Task 4: Final doğrulama + rapor

**Step 4.1:**

```bash
cd /home/melik/egesut-wt/tedavi-sablon-aktif
git status --short          # → boş (her şey commit'li)
git log --oneline main..HEAD # → 3 commit (migration, saf çekirdek, UI)
npm run test:unit            # → full PASS, test sayısını not et
```

**Step 4.2: Rapor** (subagent çıktısı — İngilizce, contract gereği):
- değişen dosyalar + satır sayıları,
- test sonucu (toplam/pass),
- guard/hook uyarıları varsa ne dedikleri,
- bilinçli sapmalar (yoksa "none").

**Bilinçli olarak YOK (subagent bunları yapmaz):** canlı/demo DB'ye
migration uygulama, merge/push, docs-update, .harness referans güncellemesi,
submitCase/toplu-vaka çağrıcılarında değişiklik (geriye uyumluluk DEFAULT
ile korunur — çağrıcılara DOKUNMA).
