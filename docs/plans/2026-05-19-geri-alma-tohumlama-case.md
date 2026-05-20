# Tohumlama + Cases Geri Alma — Implementation Plan

> ~~REQUIRED SUB-SKILL~~ → **✅ TAMAMLANDI (2026-05-20)**

**Goal:** Tohumlama ve cases (vaka) kayıtlarını tüm yan etkileriyle (stok, görev, tedavi) geri alınabilir hale getirmek.

**Architecture:** Mevcut `geri_al` RPC'si sadece islem_log snapshot'ına dayanır ve stok/treatment kayıtlarını geri alamaz. Bunun yerine her işlem tipi için **domain-specific** bir RPC yazılır — kendi tablolarını, stok hareketlerini, görevlerini ve trigger etkilerini bilir. Frontend'deki `islemGeriAl` fonksiyonu yeni RPC'leri çağıracak şekilde güncellenir.

**Tech Stack:** PostgreSQL (Supabase), Vanilla JS

---

## Mevcut Durum Analizi

### `geri_al(p_islem_id)` RPC'si (genel)
- islem_log snapshot'ındaki `olusturulan` kayıtları DELETE eder
- `guncellenen` kayıtları eski haline döndürür
- **EKSİK 1:** Stok hareketlerini geri almaz (tohumlama sperma kullandıysa, case ilaç kullandıysa stok ters kayıt gerekiyor)
- **EKSİK 2:** `treatment_days` ve `drug_administrations` gibi bağlı tabloları bilmez
- **EKSİK 3:** Trigger'ların yan etkilerini (gorev_log, kizginlik_log.cozuldu) geri almaz

### Tohumlama Kaydının Yan Etkileri
| Tablo | İşlem | Nasıl oluşur |
|-------|-------|-------------|
| `tohumlama` | INSERT | `tohumlama_kaydet` RPC |
| `gorev_log` | 2× INSERT | `trg_tohumlama_gebe_gorev` trigger (AFTER UPDATE sonuc='Gebe') |
| `kizginlik_log` | UPDATE cozuldu=true | `trg_tohumlama_kizginlik` trigger (AFTER INSERT) |
| `islem_log` | INSERT | `trg_islem_tohumlama_insert` trigger (AFTER INSERT) |
| `stok_hareket` | INSERT | `tohumlama_kaydet` RPC (sperma stok düşümü, opsiyonel) |

### Case Kaydının Yan Etkileri
| Tablo | İşlem | Nasıl oluşur |
|-------|-------|-------------|
| `cases` | INSERT | `create_case` RPC |
| `treatment_days` | INSERT | Manuel (case detayından) |
| `drug_administrations` | INSERT | Manuel (tedavi gününe bağlı) |
| `stok_hareket` | INSERT | `trg_ilac_stok_dus` trigger (AFTER INSERT on drug_administrations) |
| `kizginlik_log` | UPDATE cozuldu=true, tedavi_case_id | `kizginlik_tedavi_baglanti_kur` RPC |
| `islem_log` | INSERT | `trg_islem_case` trigger (AFTER INSERT) |

---

## Task 1: `tohumlama_geri_al` RPC

**TDD scenario:** Trivial change (SQL migration)

**Files:**
- Modify: `supabase/migrations/20260519000002_kizginlik_tedavi_sil.sql` (yeni RPC'yi ekle)
- Veya yeni migration: `supabase/migrations/20260520000001_tohumlama_case_geri_al.sql`

**RPC taslağı:**

```sql
CREATE OR REPLACE FUNCTION public.tohumlama_geri_al(
  p_tohumlama_id text
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_tohumlama  record;
  v_stok_id    text;
  v_stok_miktar numeric;
BEGIN
  -- 1. Tohumlama kaydını oku
  SELECT * INTO v_tohumlama FROM public.tohumlama WHERE id = p_tohumlama_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'hata', 'Tohumlama kaydı bulunamadı');
  END IF;

  -- 2. Kızgınlık log'u geri al (cozuldu -> false, sadece bu tohumlama ile kapatılmışsa)
  UPDATE public.kizginlik_log
  SET cozuldu = false
  WHERE hayvan_id = v_tohumlama.hayvan_id
    AND tarih <= v_tohumlama.tarih
    AND cozuldu = true
    AND NOT EXISTS (
      SELECT 1 FROM public.tohumlama t2
      WHERE t2.hayvan_id = v_tohumlama.hayvan_id
        AND t2.id != p_tohumlama_id
        AND t2.tarih >= v_tohumlama.tarih
    );

  -- 3. Sperma stok reverse (varsa)
  IF v_tohumlama.sperma IS NOT NULL AND v_tohumlama.sperma != '' THEN
    -- Stok id bul
    SELECT id INTO v_stok_id FROM public.stok
    WHERE urun_adi ILIKE '%' || v_tohumlama.sperma || '%'
      AND kategori = 'Sperma'
    LIMIT 1;

    IF v_stok_id IS NOT NULL THEN
      -- Stok hareketi reverse (negatif miktar = ekleme)
      SELECT COALESCE(SUM(miktar), 0) INTO v_stok_miktar
      FROM public.stok_hareket
      WHERE stok_id = v_stok_id
        AND referans_tipi = 'tohumlama'
        AND referans_id = p_tohumlama_id
        AND NOT iptal;

      IF v_stok_miktar > 0 THEN
        INSERT INTO public.stok_hareket (stok_id, miktar, referans_tipi, referans_id, aciklama, iptal)
        VALUES (v_stok_id, -v_stok_miktar, 'tohumlama_geri_al', p_tohumlama_id, 'Tohumlama geri alındı: ' || p_tohumlama_id, false);
      END IF;
    END IF;
  END IF;

  -- 4. Tohumlama kaydını sil (cascade + trigger'lar çalışır)
  DELETE FROM public.tohumlama WHERE id = p_tohumlama_id;

  -- 5. islem_log'u işaretle
  UPDATE public.islem_log
  SET durum = 'geri_alindi', geri_alma_tarihi = now()
  WHERE ref_tablo = 'tohumlama' AND ref_id = p_tohumlama_id;

  RETURN jsonb_build_object('ok', true);
END;
$$;

GRANT EXECUTE ON FUNCTION public.tohumlama_geri_al(text) TO anon, authenticated;
```

**NOT:** `DELETE FROM tohumlama` → tohumlama kaydı silinince trigger'lar: `trg_deneme_no` (BEFORE INSERT — bu tetiklenmez, DELETE), `trg_islem_tohumlama_insert` (AFTER INSERT — tetiklenmez, bu DELETE). PostgreSQL'de AFTER DELETE trigger'ları da var mı kontrol et. Ama tohumlama üzerinde AFTER DELETE trigger'ı yok (ground truth'da sadece AFTER INSERT ve AFTER UPDATE var). İyi.

---

## Task 2: `case_geri_al` RPC (Soft Delete)

**TDD scenario:** Trivial change (SQL migration)

**RPC taslağı:**

```sql
CREATE OR REPLACE FUNCTION public.case_geri_al(
  p_case_id uuid
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_case       record;
  v_da_count   integer;
BEGIN
  -- 1. Case kaydını oku
  SELECT * INTO v_case FROM public.cases WHERE id = p_case_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'hata', 'Case bulunamadı');
  END IF;

  -- 2. Kızgınlık bağlantısını geri al (eğer bu case'e bağlıysa)
  UPDATE public.kizginlik_log
  SET tedavi_case_id = NULL,
      cozuldu = false
  WHERE tedavi_case_id = p_case_id;

  -- 3. Drug administrations ve stok reverse
  SELECT COUNT(*) INTO v_da_count FROM public.drug_administrations da
  JOIN public.treatment_days td ON td.id = da.treatment_day_id
  WHERE td.case_id = p_case_id;

  -- Stok reverse: drug_administrations'daki her ilaç için stok hareketi reverse
  INSERT INTO public.stok_hareket (stok_id, miktar, referans_tipi, referans_id, aciklama, iptal)
  SELECT
    da.drug_product_id,
    -da.dose,  -- reverse: negatif = stok iade
    'case_geri_al',
    p_case_id::text,
    'Case geri alındı: ' || p_case_id::text,
    false
  FROM public.drug_administrations da
  JOIN public.treatment_days td ON td.id = da.treatment_day_id
  WHERE td.case_id = p_case_id;

  -- 4. Drug administrations ve treatment days sil (cascade)
  DELETE FROM public.drug_administrations da
  USING public.treatment_days td
  WHERE td.id = da.treatment_day_id AND td.case_id = p_case_id;

  DELETE FROM public.treatment_days WHERE case_id = p_case_id;

  -- 5. Case soft delete
  UPDATE public.cases
  SET status = 'closed', closed_at = now(), notes = COALESCE(notes || ' | ', '') || 'Geri alındı: ' || now()::text
  WHERE id = p_case_id;

  -- 6. islem_log'u işaretle
  UPDATE public.islem_log
  SET durum = 'geri_alindi', geri_alma_tarihi = now()
  WHERE ref_tablo = 'cases' AND ref_id = p_case_id::text;

  RETURN jsonb_build_object(
    'ok', true,
    'silinen_ilac_kaydi', v_da_count,
    'kizginlik_baglantisi_koptu', (SELECT COUNT(*) FROM kizginlik_log WHERE tedavi_case_id = p_case_id) = 0
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.case_geri_al(uuid) TO anon, authenticated;
```

**Tartışma:** `DROP TABLE ... CASCADE` ile silme yerine `UPDATE cases SET status = 'closed'` ile soft-delete. Neden?
- Case'e bağlı `drug_administrations` ve `treatment_days` silinir ama case kaydı kalır (audit)
- Case kaydı status='closed' ve notes'a "Geri alındı" notu eklenir
- Stok hareketleri reverse entry ile düzeltilir (hiçbir stok_hareket asla silinmez — mimari kural)

---

## Task 3: js/forms.js — islemGeriAl fonksiyonunu güncelle

**TDD scenario:** Trivial change

**Files:**
- Modify: `js/forms.js:960-975`

**Şu anki kod:**

```js
// Mevcut: genel geri_al RPC'sini çağırıyor
await rpc('geri_al', { p_islem_id: islemLogId });
```

**Değişiklik:** İşlem tipine göre domain-specific RPC çağır:

```js
async function islemGeriAl(btn, islemLogId) {
  if (!navigator.onLine) { toast('⚠️ Geri alma için internet gerekli', true); return; }
  if (btn) { btn.disabled = true; btn.textContent = 'Geri alınıyor…'; }

  // İşlem tipini bul
  const islem = await idbGet('islem_log', islemLogId);
  if (!islem) { toast('⚠️ İşlem bulunamadı', true); return; }

  try {
    let rpcName = 'geri_al';  // default: genel RPC
    let rpcParams = { p_islem_id: islemLogId };

    if (islem.tip === 'TOHUMLAMA' || islem.tip === 'TOHUMLAMA_GUNCELLENDI') {
      rpcName = 'tohumlama_geri_al';
      rpcParams = { p_tohumlama_id: islem.ref_id };
    } else if (islem.tip === 'HASTALIK_KAYDI') {
      // Cases tablosunda animal_id + disease_id ile case bul
      const caseId = islem.snapshot?.case_id || islem.ref_id;
      rpcName = 'case_geri_al';
      rpcParams = { p_case_id: caseId };
    }

    const res = await rpc(rpcName, rpcParams);
    if (!res?.ok) throw new Error(res?.hata || 'Geri alma başarısız');

    toast('✅ İşlem geri alındı');
    closeM('m-geri-al');
    closeM('m-toh-det');
    await pullTables(['tohumlama','gorev_log','hayvanlar','kizginlik_log','cases','treatment_days','stok_hareket','islem_log']);
    renderSafe();
  } catch (e) {
    toast('❌ Geri alma başarısız: ' + getUserMessage(e), true);
  } finally {
    if (btn) { btn.disabled = false; btn.textContent = 'İşlemi Geri Al'; }
  }
}
```

---

## Task 4: js/api.js — versiyon güncelleme

**TDD scenario:** Trivial change

**Files:**
- Modify: `js/api.js`

**Değişiklikler:**
- `DB_VER` 17 → 18
- `RPC_TABLES`'a yeni RPC'leri ekle:
  ```js
  tohumlama_geri_al: ['tohumlama','gorev_log','kizginlik_log','stok_hareket'],
  case_geri_al:      ['cases','treatment_days','drug_administrations','stok_hareket','kizginlik_log'],
  ```

---

## Task 5: js/app.js — geri alma route

**TDD scenario:** Trivial change

**Files:**
- Modify: `js/app.js` (opsiyonel)

Mevcut `islemGeriAl` zaten `forms.js`'de tanımlı. Sadece routing'den çağrıldığı yeri kontrol et.

---

## Task 6: Deploy

**Sıra:**
1. Migration deploy: `supabase_migrate` MCP ile yeni RPC'leri gönder
2. Frontend push: GitHub Actions otomatik deploy

---

## Commit Planı

| Task | Commit | Durum |
|------|--------|-------|
| Task 1 + 2 — RPC'ler | `ffaaa1d` | ✅ |
| Task 3 + 4 — Frontend | `ffaaa1d` + `78fc454` + `fecc173` + `6176e8a` | ✅ |
| Task 5 — Deploy | Supabase + GitHub Pages | ✅ |

**Not:** Sub-agent `idbGet` hatası (`6176e8a`), `getUserMessage` generic mesaj sorunu (`78fc454`), null ref_id koruması (`fecc173`) ve `HASTALIK_KAYDI` yönlendirme düzeltmesi (`d6bd420`) ayrı commitlerle fixlendi. Planın asıl RPC'leri ve UI değişiklikleri `ffaaa1d` ile geldi.

---

## Test Senaryoları

| Senaryo | Beklenen |
|---------|----------|
| Tohumlama geri al → kızgınlık aktif olur | kizginlik_log.cozuldu = false |
| Tohumlama geri al → sperma stok düzelir | stok_hareket reverse entry |
| Case geri al → kızgınlık bağlantısı kopar | tedavi_case_id = null, cozuldu = false |
| Case geri al → ilaç stok düzelir | stok_hareket reverse entry |
| Case geri al → case soft-delete | status = closed, notes = "Geri alındı" |
| Zaman aşımı (>7 gün) | Hata: eski kayıtlar geri alınamaz |
