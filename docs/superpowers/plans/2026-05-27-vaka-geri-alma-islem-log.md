# Vaka Geri Alma — islem_log Entegrasyonu

> Topoloji: Hierarchical | 5 task | 0 paralel blok
> Model: deepseek-chat (flash) — aksi belirtilmedi
> Soru varsa devam etmeden önce sor. DB değişikliklerinde onay bekle.

**Hedef:** Vaka açma ve tedavi günü ekleme işlemlerini `islem_log`'a kaydet; mevcut `geri_al` altyapısıyla geri alınabilir hale getir.
**Etkilenen dosyalar:** `supabase/migrations/`, `js/forms.js`, `js/ui.js`

---

## Başlamadan Önce

Sırayla oku:
1. `cat /root/egesut-erp1/supabase/migrations/99999999999999_ground_truth.sql`
2. `cat /root/egesut-erp1/.claude/rpc-reference.md`

Özellikle şu bölümleri not et:
- `create_case` RPC (satır ~2936) — islem_log INSERT yok
- `geri_al` RPC (satır ~3802) — olusturulan DELETE loop
- `add_treatment_day` RPC (en güncel versiyon — son migration'da)

---

## Mimari Karar (Önceden Alındı)

```
create_case → islem_log (VAKA_ACILDI) → olusturulan: [{tablo:'cases', id:uuid}]
add_treatment_day → islem_log (TEDAVI_GUN_EKLENDI) → olusturulan: [{tablo:'treatment_days',id:uuid},{tablo:'gorev_log',id:uuid}]

geri_al(islem_id):
  olusturulan[].tablo = 'cases' → DELETE FROM cases CASCADE → treatment_days + drug_administrations otomatik silinir
  olusturulan[].tablo = 'gorev_log' → gorev_log kaydı silinir
```

**FK Haritası (önceden doğrulandı):**
- `treatment_days.case_id` → `cases(id) ON DELETE CASCADE` ✅
- `drug_administrations.treatment_day_id` → `treatment_days(id) ON DELETE CASCADE` ✅
- `gorev_log` → FK yok → snapshot'a manuel eklenir

---

## Task 1 — `geri_al` RPC: UUID id desteği ekle

**Sorun:** `geri_al` içindeki DELETE loop `WHERE id = $1` ile text parametre kullanıyor.
`cases.id` ve `treatment_days.id` uuid — tip uyumsuzluğu → hata.

**Okuma:**
```bash
sed -n '3802,3870p' /root/egesut-erp1/supabase/migrations/99999999999999_ground_truth.sql
```

**Uygulama:**

`geri_al` fonksiyonundaki DELETE loop'u aşağıdakiyle değiştir:

```sql
CREATE OR REPLACE FUNCTION public.geri_al(p_islem_id text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_snapshot  jsonb;
  v_item      jsonb;
  v_tablo     text;
  v_pk        text;
  v_onceki    jsonb;
  v_col       text;
  v_val       text;
  v_set_parts text[] := '{}';
  v_sql       text;
BEGIN
  SELECT snapshot INTO v_snapshot
  FROM islem_log
  WHERE id = p_islem_id;

  IF v_snapshot IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'hata', 'islem bulunamadi');
  END IF;

  -- Oluşturulan kayıtları sil (text veya uuid id kolonuna göre)
  FOR v_item IN SELECT * FROM jsonb_array_elements(v_snapshot->'olusturulan')
  LOOP
    v_tablo := v_item->>'tablo';
    v_pk    := v_item->>'id';
    BEGIN
      EXECUTE format('DELETE FROM %I WHERE id = $1', v_tablo) USING v_pk;
    EXCEPTION WHEN others THEN
      -- text cast çalışmadıysa uuid olarak dene
      EXECUTE format('DELETE FROM %I WHERE id = $1::uuid', v_tablo) USING v_pk;
    END;
  END LOOP;

  -- Güncellenen kayıtları geri al
  FOR v_item IN SELECT * FROM jsonb_array_elements(v_snapshot->'guncellenen')
  LOOP
    v_tablo  := v_item->>'tablo';
    v_pk     := v_item->>'id';
    v_onceki := v_item->'onceki';
    v_set_parts := '{}';

    FOR v_col, v_val IN SELECT key, value #>> '{}' FROM jsonb_each(v_onceki)
    LOOP
      v_set_parts := array_append(
        v_set_parts,
        format('%I = %L', v_col, v_val)
      );
    END LOOP;

    IF array_length(v_set_parts, 1) > 0 THEN
      v_sql := format(
        'UPDATE %I SET %s WHERE id = $1',
        v_tablo,
        array_to_string(v_set_parts, ', ')
      );
      EXECUTE v_sql USING v_pk;
    END IF;
  END LOOP;

  UPDATE islem_log SET durum = 'geri_alindi' WHERE id = p_islem_id;
  RETURN jsonb_build_object('ok', true);
END;
$$;

GRANT EXECUTE ON FUNCTION public.geri_al(text) TO anon, authenticated;
```

Deploy et:
```
supabase_migrate({sql: "..."})
```

**Doğrulama:**
```
supabase_rpc({function_name: "geri_al", params: '{"p_islem_id":"OLMAYAN_ID"}'})
```
→ `{ok: false, hata: "islem bulunamadi"}` beklenir (hata vermez, çalışıyor demektir).

**Checkpoint:**
```
memory_add({content: "geri_al UUID fix: DELETE loop try/catch ile text ve uuid id kolonlarını destekliyor", category: "code_change", priority: "medium", tags: "geri_al,uuid,fix"})
```

---

## Task 2 — `create_case` RPC: islem_log snapshot ekle

**Okuma:**
```bash
grep -n "create_case" /root/egesut-erp1/supabase/migrations/99999999999999_ground_truth.sql
sed -n '2934,2972p' /root/egesut-erp1/supabase/migrations/99999999999999_ground_truth.sql
```

**Uygulama:**

`create_case` fonksiyonuna INSERT sonrası şu bloğu ekle (RETURN'den önce):

```sql
-- islem_log: geri alma için snapshot
INSERT INTO public.islem_log (id, tip, ana_hayvan_id, ref_id, ref_tablo, snapshot)
VALUES (
  gen_random_uuid()::text,
  'VAKA_ACILDI',
  p_animal_id,
  v_new_id::text,
  'cases',
  jsonb_build_object(
    'olusturulan', jsonb_build_array(
      jsonb_build_object('tablo', 'cases', 'id', v_new_id::text)
    ),
    'guncellenen', '[]'::jsonb
  )
);
```

Tam fonksiyonu `CREATE OR REPLACE` ile deploy et.

**Doğrulama:**
```
supabase_query({table: "islem_log", filters: "tip=eq.VAKA_ACILDI", limit: 3})
```
→ Yeni bir VAKA_ACILDI kaydı görünmeli (mevcut test vakası için yok, yeni case açınca gelecek).

---

## Task 3 — `add_treatment_day` RPC: islem_log snapshot ekle

**Okuma (güncel versiyonu bul):**
```bash
grep -n "add_treatment_day" /root/egesut-erp1/supabase/migrations/99999999999999_ground_truth.sql
```
Son `CREATE OR REPLACE FUNCTION public.add_treatment_day` bloğunu bul ve oku.

**Uygulama:**

`add_treatment_day` fonksiyonuna, gorev INSERT'ten sonra, RETURN'den önce şu bloğu ekle:

```sql
DECLARE
  v_gorev_id uuid;  -- DECLARE bölümüne ekle
  
-- ...mevcut kod...

-- gorev INSERT'i şu şekilde değiştir (RETURNING id al):
INSERT INTO public.gorev_log(id, gorev_tipi, hayvan_id, hedef_tarih, aciklama, tamamlandi)
VALUES (
  gen_random_uuid(),
  'TEDAVI_GUN',
  v_case.animal_id,
  p_date,
  jsonb_build_object(
    'day_id', v_day_id,
    'gun_no', v_day_no,
    'label',  'Gün ' || v_day_no || ' tedavisi — ' || to_char(p_date, 'DD.MM.YYYY')
  )::text,
  false
)
RETURNING id INTO v_gorev_id;

-- islem_log snapshot (geri alma için)
INSERT INTO public.islem_log (id, tip, ana_hayvan_id, ref_id, ref_tablo, snapshot)
VALUES (
  gen_random_uuid()::text,
  'TEDAVI_GUN_EKLENDI',
  v_case.animal_id,
  v_day_id::text,
  'treatment_days',
  jsonb_build_object(
    'olusturulan', jsonb_build_array(
      jsonb_build_object('tablo', 'treatment_days', 'id', v_day_id::text),
      jsonb_build_object('tablo', 'gorev_log',      'id', v_gorev_id::text)
    ),
    'guncellenen', '[]'::jsonb
  )
);
```

Tam fonksiyonu deploy et:
```
supabase_migrate({sql: "..."})
```

**Doğrulama:**

Yeni bir treatment day ekle (mevcut bir test vakasına):
```
supabase_rpc({function_name: "add_treatment_day", params: '{"p_case_id":"TEST_CASE_ID","p_date":"2026-05-31"}'})
```
```
supabase_query({table: "islem_log", filters: "tip=eq.TEDAVI_GUN_EKLENDI", limit: 3})
```
→ Kayıt görünmeli.

**Checkpoint:**
```
memory_add({content: "create_case + add_treatment_day islem_log entegrasyonu tamamlandı. VAKA_ACILDI + TEDAVI_GUN_EKLENDI tipleri eklendi.", category: "code_change", priority: "medium", tags: "islem_log,vaka,geri_al"})
```

---

## Task 4 — UI: `islemGeriAl` dispatch + vaka detay butonu

**Okuma:**
```bash
sed -n '1065,1110p' /root/egesut-erp1/js/forms.js
grep -n "VAKA_ACILDI\|TEDAVI_GUN_EKLENDI\|openGeriAl\|islemGeriAl\|islem_log\|HASTALIK_KAYDI" /root/egesut-erp1/js/ui.js | head -20
grep -n "openCaseDet\|cd-kapat\|vaka.*kapat\|geri.*al" /root/egesut-erp1/js/ui.js | head -15
```

### 4a — `forms.js` dispatch güncellemesi

`islemGeriAl` fonksiyonundaki dispatch bloğuna `VAKA_ACILDI` ve `TEDAVI_GUN_EKLENDI` tiplerini ekle:

```js
// forms.js içindeki islemGeriAl'da, mevcut if/else bloğuna ekle:
if (islem.tip === 'TOHUMLAMA' || islem.tip === 'TOHUMLAMA_GUNCELLENDI') {
  rpcName = 'tohumlama_geri_al';
  rpcParams = { p_tohumlama_id: islem.ref_id };
} else if (islem.tip === 'VAKA_ACILDI' || islem.tip === 'TEDAVI_GUN_EKLENDI') {
  // geri_al zaten uuid'yi handle ediyor (Task 1 fix)
  rpcName = 'geri_al';
  rpcParams = { p_islem_id: islemLogId };
} else {
  rpcName = 'geri_al';
  rpcParams = { p_islem_id: islemLogId };
}
```

`pullTables` listesine `cases` ve `treatment_days` ekle:
```js
await pullTables(['tohumlama','gorev_log','hayvanlar','kizginlik_log','cases','treatment_days','stok_hareket','islem_log']);
```
(Zaten bu listede olabilir — kontrol et, yoksa ekle.)

### 4b — Vaka detay ekranına "↩ Geri Al" butonu

`openCaseDet` fonksiyonunu oku (ui.js ~2701). `m-case-det` modal içinde, vaka açılışında islem_log'dan VAKA_ACILDI kaydını kontrol et:

```js
// openCaseDet içine, openM'den önce ekle:
const islemler = await idbGetAll('islem_log');
const vakaIslem = islemler.find(l => l.tip === 'VAKA_ACILDI' && l.ref_id === caseId);
const geriAlBtn = document.getElementById('cd-geri-al-btn');
if (geriAlBtn) {
  if (vakaIslem && aktif) {
    geriAlBtn.style.display = 'block';
    geriAlBtn.onclick = () => openGeriAl(vakaIslem.id, `Vaka geri alınacak: ${disease?.name || '?'} — tüm tedavi günleri silinir.`);
  } else {
    geriAlBtn.style.display = 'none';
  }
}
```

`index.html` — `m-case-det` modal içine buton ekle (`cd-kapat-bolum` yanına):
```html
<div id="cd-geri-al-btn" style="display:none;margin-top:8px">
  <button class="btn btn-sm btn-r" onclick="">↩ Vakayı Geri Al</button>
</div>
```
> NOT: `onclick` boş bırak — `openCaseDet` içinde dinamik atanıyor.

**Doğrulama:**
```bash
node --check /root/egesut-erp1/js/ui.js
node --check /root/egesut-erp1/js/forms.js
```

**Commit:**
```bash
git add js/ui.js js/forms.js index.html supabase/migrations/ && git commit -m "feat(vaka): islem_log entegrasyonu + geri alma — VAKA_ACILDI, TEDAVI_GUN_EKLENDI"
```

---

## Task 5 — Uçtan uca test

**Test senaryosu:**

1. Yeni bir hayvan için vaka aç (farklı hastalık)
```
supabase_query({table: "islem_log", filters: "tip=eq.VAKA_ACILDI", limit: 3, order: "created_at.desc"})
```
→ Kayıt görünmeli.

2. Vaka detayına git → "↩ Vakayı Geri Al" butonu görünmeli.

3. Geri Al'a tıkla → confirm → modal.

4. İşlem sonrası:
```
supabase_query({table: "cases", filters: "status=eq.active", limit: 5})
supabase_query({table: "treatment_days", limit: 5})
supabase_query({table: "gorev_log", filters: "gorev_tipi=eq.TEDAVI_GUN", limit: 5})
```
→ İlgili vaka + tedavi günleri + TEDAVI_GUN görevleri silinmiş olmalı.

---

## Son Task — Pattern Kayıt

```
memory_add({
  content: "Vaka geri alma: create_case + add_treatment_day RPC'lerine VAKA_ACILDI + TEDAVI_GUN_EKLENDI islem_log snapshot eklendi. geri_al RPC'ye uuid fallback eklendi (try text → catch → uuid cast). treatment_days CASCADE sayesinde tek DELETE yeterli. gorev_log manuel snapshot'a eklendi.",
  category: "code_change",
  priority: "medium",
  tags: "geri_al,vaka,islem_log,cascade"
})
```

---

## Referans

| Sembol | Dosya | Satır |
|--------|-------|-------|
| `create_case` RPC | `ground_truth.sql` | ~2936 |
| `geri_al` RPC | `ground_truth.sql` | ~3802 |
| `add_treatment_day` RPC | son migration | — |
| `islemGeriAl` UI | `js/forms.js` | 1071 |
| `openGeriAl` UI | `js/forms.js` | 1065 |
| `openCaseDet` UI | `js/ui.js` | ~2701 |
| `treatment_days` CASCADE | `ground_truth.sql` | ~2762 |
