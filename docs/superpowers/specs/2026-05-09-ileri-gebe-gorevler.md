# İleri Gebe Görev Otomasyonu
Tarih: 2026-05-09  
Durum: pending

---

## Kapsam

1. **Backend RPC** — `ileri_gebe_gorev_kontrol`: tüm gebe hayvanları tarar, eşik geçilmişse görev oluşturur (idempotent)
2. **Backend fix** — `tohumlama_sonuc_gebe`: 'Bekliyor' zorunluluğunu kaldır, sadece "son tohumlama" şartı kalsın
3. **Frontend** — dashboard band + buton, hayvan detay chip, gebe liste sıralaması, app init tetikleyici

---

## Görev Eşikleri

| Gün | Başlık | Tip | Kime |
|-----|--------|-----|------|
| 240 | `💉 Rota-Corona Aşısı (1. doz)` | `ILERI_GEBE` | Tüm gebeler |
| 261 | `💉 Rota-Corona Aşısı (2. doz — düve)` | `ILERI_GEBE` | grup LIKE '%Düve%' |
| 260 | `💊 SC Ademin uygulaması` | `ILERI_GEBE` | Tüm gebeler |
| 265 | `💊 IM E Vitamini uygulaması` | `ILERI_GEBE` | Tüm gebeler |

Dedup: `gorev_log` içinde aynı `hayvan_id + aciklama` varsa (tamamlandi=false veya true) atla.

---

## Step 1 — Backend: `ileri_gebe_gorev_kontrol` RPC + `tohumlama_sonuc_gebe` fix [ ]

**Migration dosyası:** `supabase/migrations/YYYYMMDD_ileri_gebe_gorev.sql`

### `ileri_gebe_gorev_kontrol` RPC

```sql
CREATE OR REPLACE FUNCTION public.ileri_gebe_gorev_kontrol()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_olusturulan int := 0;
  v_toh record;
  v_hayvan record;
  v_gun int;
  v_hedef date;
BEGIN
  -- Aktif Gebe tohumlamalar (en son per hayvan)
  FOR v_toh IN
    SELECT DISTINCT ON (t.hayvan_id) t.hayvan_id, t.tarih, t.id
    FROM tohumlama t
    JOIN hayvanlar h ON h.id = t.hayvan_id AND h.durum = 'Aktif'
    WHERE t.sonuc = 'Gebe'
    ORDER BY t.hayvan_id, t.tarih DESC
  LOOP
    SELECT * INTO v_hayvan FROM hayvanlar WHERE id = v_toh.hayvan_id;
    v_gun := CURRENT_DATE - v_toh.tarih::date;

    -- 240. gün: Rota-Corona 1. doz (tüm gebeler)
    v_hedef := v_toh.tarih::date + 240;
    IF v_gun >= 240 THEN
      INSERT INTO gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi)
      SELECT gen_random_uuid(), v_toh.hayvan_id, 'ILERI_GEBE',
             '💉 Rota-Corona Aşısı (1. doz)', v_hedef, false
      WHERE NOT EXISTS (
        SELECT 1 FROM gorev_log
        WHERE hayvan_id = v_toh.hayvan_id
          AND aciklama = '💉 Rota-Corona Aşısı (1. doz)'
      );
      GET DIAGNOSTICS v_olusturulan = v_olusturulan + ROW_COUNT;
    END IF;

    -- 261. gün: Rota-Corona 2. doz (sadece düveler)
    v_hedef := v_toh.tarih::date + 261;
    IF v_gun >= 261 AND v_hayvan.grup ILIKE '%Düve%' THEN
      INSERT INTO gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi)
      SELECT gen_random_uuid(), v_toh.hayvan_id, 'ILERI_GEBE',
             '💉 Rota-Corona Aşısı (2. doz — düve)', v_hedef, false
      WHERE NOT EXISTS (
        SELECT 1 FROM gorev_log
        WHERE hayvan_id = v_toh.hayvan_id
          AND aciklama = '💉 Rota-Corona Aşısı (2. doz — düve)'
      );
      GET DIAGNOSTICS v_olusturulan = v_olusturulan + ROW_COUNT;
    END IF;

    -- 260. gün: SC Ademin (tüm gebeler)
    v_hedef := v_toh.tarih::date + 260;
    IF v_gun >= 260 THEN
      INSERT INTO gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi)
      SELECT gen_random_uuid(), v_toh.hayvan_id, 'ILERI_GEBE',
             '💊 SC Ademin uygulaması', v_hedef, false
      WHERE NOT EXISTS (
        SELECT 1 FROM gorev_log
        WHERE hayvan_id = v_toh.hayvan_id
          AND aciklama = '💊 SC Ademin uygulaması'
      );
      GET DIAGNOSTICS v_olusturulan = v_olusturulan + ROW_COUNT;
    END IF;

    -- 265. gün: IM E Vitamini (tüm gebeler)
    v_hedef := v_toh.tarih::date + 265;
    IF v_gun >= 265 THEN
      INSERT INTO gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi)
      SELECT gen_random_uuid(), v_toh.hayvan_id, 'ILERI_GEBE',
             '💊 IM E Vitamini uygulaması', v_hedef, false
      WHERE NOT EXISTS (
        SELECT 1 FROM gorev_log
        WHERE hayvan_id = v_toh.hayvan_id
          AND aciklama = '💊 IM E Vitamini uygulaması'
      );
      GET DIAGNOSTICS v_olusturulan = v_olusturulan + ROW_COUNT;
    END IF;

  END LOOP;

  RETURN jsonb_build_object('ok', true, 'olusturulan', v_olusturulan);
END;
$$;
```

### `tohumlama_sonuc_gebe` fix
Mevcut RPC'deki `IF v_toh.sonuc != 'Bekliyor'` bloğunu kaldır (import'tan Boş gelen kayıtlar da gebe yapılabilsin). Sadece "son tohumlama" şartı kalsın.

---

## Step 2 — Frontend: Dashboard band + buton + sıralama [ ]

**Dosya:** `js/ui.js` — `loadDash()` içinde

### 210+ gün band
`gebeTohs` listesinden 210+ gün olanları hesapla, `_dashBands()` çağrısından önce band HTML'i oluştur:

```js
const ileriGebeler = gebeTohs
  .map(t => ({ ...t, gun: Math.floor((Date.now() - new Date(t.tarih)) / 86400000) }))
  .filter(t => t.gun >= 210)
  .sort((a, b) => b.gun - a.gun);
```

Band içeriği: her hayvan için `kupe_no · XXX. gün` satırı.

### Gebe liste sıralaması
`nearBirth` ve dashboard'daki gebe listesi gebelik gününe göre azalan sıra.

### "İleri Gebe Kontrol" butonu
Dashboard'a buton ekle: tıklandığında `rpc('ileri_gebe_gorev_kontrol')` → toast `"X yeni görev oluşturuldu"`.

---

## Step 3 — Frontend: App init + hayvan detay chip [ ]

**App init:** `js/app.js` veya `js/ui.js` içinde `loadData()` tamamlandıktan sonra:
```js
rpc('ileri_gebe_gorev_kontrol').catch(console.warn); // sessiz, fire-and-forget
```

**Hayvan detay chip:** `openDet()` içinde gebelik günü hesapla:
- `tohs` içinde `sonuc='Gebe'` olan son tohumlama
- `gun = Math.floor((Date.now() - new Date(gebe.tarih)) / 86400000)`
- chip: `🤰 ${gun}. gün · Tahmini: ${dFwd(gebe.tarih, 280)}`
- Mevcut `🤰 Gebe` chip'ini bu ile değiştir

---

## Tamamlananlar
Step 1: [ ] Step 2: [ ] Step 3: [ ]
