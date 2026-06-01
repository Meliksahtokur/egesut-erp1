# Postpartum Gözlem Kızgınlığı (55-Gün Kuralı) — Plan A

> Topoloji: Hierarchical | 3 task | 0 paralel blok
> Model: deepseek-chat (flash)
> Soru varsa devam etmeden önce sor. DB değişikliklerinde onay bekle.

**Hedef:** Doğumdan sonra 55 gün içindeki kızgınlıklar `sonuc='POSTPARTUM_GOZLEM'` olarak kaydedilir; UI'da "👁 Gözlem" badge'i gösterilir, "💉 Tohumla" butonu kalır ama gorev oluşturmaz (zaten oluşmuyor).

**Etkilenen dosyalar:**
- `supabase/migrations/99999999999999_ground_truth.sql`
- Yeni migration: `supabase/migrations/20260526000001_postpartum_gozlem.sql`
- `js/ui.js` → `_uremeKizginlik` fonksiyonu

---

## Başlamadan Önce

Sırayla oku:
```bash
sed -n '783,820p' /root/egesut-erp1/supabase/migrations/99999999999999_ground_truth.sql
# kizginlik_kaydet RPC'nin tamamını gör

sed -n '194,201p' /root/egesut-erp1/supabase/migrations/99999999999999_ground_truth.sql
# kizginlik_log tablo yapısı

sed -n '5623,5660p' /root/egesut-erp1/supabase/migrations/99999999999999_ground_truth.sql
# sonuc kolonu + kizginlik_yok_kaydet

sed -n '1293,1352p' /root/egesut-erp1/js/ui.js
# _uremeKizginlik fonksiyonu — badge ve buton mantığı
```

Sonra planı oku, net olmayan şey varsa sor.

---

## Task 1 — Migration: kizginlik_kaydet RPC Güncelle

**Uygulama:**

Yeni migration dosyası oluştur ve deploy et:

```sql
-- Migration: postpartum_gozlem_kizginlik
-- kizginlik_kaydet: doğumdan <55 gün içindeyse sonuc='POSTPARTUM_GOZLEM' set et

CREATE OR REPLACE FUNCTION public.kizginlik_kaydet(
  p_hayvan_id  text,
  p_tarih      date,
  p_belirti    text    DEFAULT NULL,
  p_notlar     text    DEFAULT NULL
) RETURNS jsonb AS $$
DECLARE
  v_hayvan       record;
  v_yas_gun      integer;
  v_son_dogum    date;
  v_dogum_gun    integer := NULL;
  v_sonuc        text := 'GOZLEMLENDI';
BEGIN
  SELECT * INTO v_hayvan FROM public.hayvanlar WHERE id = p_hayvan_id AND durum = 'Aktif';
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Hayvan bulunamadı');
  END IF;

  IF v_hayvan.cinsiyet = 'Erkek' THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Erkek hayvanlarda kızgınlık kaydı yapılamaz');
  END IF;

  IF v_hayvan.dogum_tarihi IS NOT NULL THEN
    v_yas_gun := CURRENT_DATE - v_hayvan.dogum_tarihi;
    IF v_yas_gun < 365 THEN
      RETURN jsonb_build_object(
        'ok', false,
        'mesaj', 'Hayvan 12 aydan küçük — kızgınlık kaydı yapılamaz',
        'oneri', 'Hayvan kartındaki Notlar bölümüne ekleyin'
      );
    END IF;
  END IF;

  -- Son doğum tarihini kontrol et (dogum tablosundan)
  SELECT MAX(d.tarih) INTO v_son_dogum
  FROM public.dogum d
  WHERE d.anne_id = p_hayvan_id;

  IF v_son_dogum IS NOT NULL THEN
    v_dogum_gun := p_tarih - v_son_dogum;
    IF v_dogum_gun >= 0 AND v_dogum_gun < 55 THEN
      v_sonuc := 'POSTPARTUM_GOZLEM';
    END IF;
  END IF;

  INSERT INTO public.kizginlik_log (id, hayvan_id, tarih, belirti, notlar, sonuc)
  VALUES (gen_random_uuid()::text, p_hayvan_id, p_tarih, p_belirti, p_notlar, v_sonuc);

  RETURN jsonb_build_object(
    'ok', true,
    'postpartum', v_sonuc = 'POSTPARTUM_GOZLEM',
    'dogum_gun', v_dogum_gun
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.kizginlik_kaydet(text, date, text, text) TO anon, authenticated;
```

`supabase_migrate({sql: "<yukarıdaki SQL>"})` ile deploy et.

**Doğrulama:**
```
supabase_rpc({
  function_name: "kizginlik_kaydet",
  params: '{"p_hayvan_id":"TEST_POSTPARTUM_ID","p_tarih":"2026-05-26"}'
})
```
→ `{"ok": true, "postpartum": true, "dogum_gun": 42}` (55 günden kısa doğum yapan hayvan için)

---

## Task 2 — ground_truth.sql Güncelle

**Uygulama:**

`supabase/migrations/99999999999999_ground_truth.sql` dosyasında 783–820 satır aralığındaki `kizginlik_kaydet` fonksiyonunu Task 1'deki yeni versiyon ile değiştir.

**Doğrulama:**
```bash
grep -n "POSTPARTUM_GOZLEM" /root/egesut-erp1/supabase/migrations/99999999999999_ground_truth.sql
# 2 satır dönmeli (INSERT + IF kontrolü)
```

**Commit:**
```bash
git add supabase/migrations/20260526000001_postpartum_gozlem.sql \
        supabase/migrations/99999999999999_ground_truth.sql
git commit -m "feat(db): kizginlik postpartum gözlem — 55-gün kuralı, POSTPARTUM_GOZLEM sonuc"
git push origin main
```

---

## Task 3 — UI: _uremeKizginlik Badge Güncelleme

**Okuma:**
```bash
sed -n '1316,1341p' /root/egesut-erp1/js/ui.js
# card() fonksiyonu — badge ve buton satırları
```

**Uygulama:**

`_uremeKizginlik` içindeki `card()` fonksiyonunda `hist-title` satırını güncelle:

Mevcut badge mantığı (cozulduMi için) zaten var. **Aktif (çözülmemiş) kızgınlıklar için** `sonuc` bilgisine göre gözlem badge'i ekle:

```js
// hist-title satırındaki badge hesabını şöyle güncelle:
const badge = cozulduMi
  ? k.tedavi_case_id
    ? `<span style="font-size:.6rem;color:var(--red2);background:rgba(192,50,26,.1);border-radius:4px;padding:1px 5px;margin-left:4px">🏥 Tedavi</span>`
    : `<span style="font-size:.6rem;color:var(--blue);background:rgba(52,152,219,.1);border-radius:4px;padding:1px 5px;margin-left:4px">💉 Tohumlandı</span>`
  : k.sonuc === 'POSTPARTUM_GOZLEM'
    ? `<span style="font-size:.6rem;color:var(--ink3);background:var(--card2);border-radius:4px;padding:1px 5px;margin-left:4px">👁 Gözlem</span>`
  : '';
```

**Syntax kontrolü:**
```bash
node --check /root/egesut-erp1/js/ui.js
```

**Commit:**
```bash
git add js/ui.js
git commit -m "feat(ui): kizginlik postpartum gözlem badge — 55-gün sonrası kaydlar için 👁 Gözlem etiketi"
git push origin main
```

---

## Son Task — Pattern Kayıt

```
memory_add({
  content: "Plan-A tamamlandı: kizginlik_kaydet RPC dogum tablosundan son doğum tarihini okur, <55 gün ise sonuc=POSTPARTUM_GOZLEM set eder. UI'da badge ayrımı yapıldı. Gorev zaten oluşmuyordu — RPC değişikliği sadece sonuc flag'i için gerekti.",
  category: "code_change",
  priority: "medium",
  tags: "kizginlik,postpartum,rpc,ui"
})
```
