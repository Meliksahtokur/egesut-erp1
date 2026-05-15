> **✅ TAMAMLANDI** — Commit'ler: `6c1b038` (buzagi_sutten_kesme_kontrol RPC), `66159e5` (dashboard + sayaç). 60. gün otomatik sütten kesme görevi çalışıyor.

# 60. Gün Buzağı Sütten Kesme Uyarı/Görev Sistemi Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 60 günü dolduran süt içen buzağılar için otomatik sütten kesme uyarısı + transfer görevi oluşturmak.

**Architecture:** Mevcut `ileri_gebe_gorev_kontrol()` RPC pattern'ini takip eden yeni `buzagi_sutten_kesme_kontrol()` RPC. Doğum tarihinden 60 gün sonrasına sütten kesme + padok transfer görevi oluşturur. Frontend'de görevler mevcut görev sistemi üzerinden görünür (yeni UI gerekmez — `_katTipMap.bakim` zaten `SUTTEN_KESME` tipini destekliyor). Dashboard'a ileri gebe kontrolü gibi tek buton eklenir.

**Tech Stack:** PostgreSQL (Supabase migration), Vanilla JS (ui.js — sadece dashboard tetikleme butonu)

**Referans RPC:** `supabase/migrations/20260509000001_ileri_gebe_gorev.sql` — aynı pattern

---

### Task 1: Database Migration — `buzagi_sutten_kesme_kontrol` RPC

**Files:**
- Create: `supabase/migrations/YYYYMMDD000001_buzagi_sutten_kesme.sql`

- [ ] **Step 1: Migration dosyası yaz**

```sql
-- Migration: buzagi_sutten_kesme_kontrol RPC
-- Pattern: ileri_gebe_gorev_kontrol ile aynı yapı
-- Domain kuralı: 60 günden büyük "Süt İçen Buzağı" → sütten kesme görevi
-- İki görev üretir: (1) sütten kesme (2) padok transfer

BEGIN;

CREATE OR REPLACE FUNCTION public.buzagi_sutten_kesme_kontrol()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_olusturulan int := 0;
  v_sayac       int := 0;
  v_hayvan      record;
  v_gun         int;
  v_hedef       date;
  v_parent_id   text;
BEGIN
  -- "Süt İçen Buzağı" grubundaki aktif hayvanları tara
  FOR v_hayvan IN
    SELECT h.*
    FROM hayvanlar h
    WHERE h.durum = 'Aktif'
      AND h.grup ILIKE '%Süt İçen Buzağı%'
      AND h.dogum_tarihi IS NOT NULL
  LOOP
    v_gun := CURRENT_DATE - v_hayvan.dogum_tarihi;

    -- 60. gün: sütten kesme zamanı
    IF v_gun >= 60 THEN
      v_hedef := v_hayvan.dogum_tarihi + 60;
      v_parent_id := gen_random_uuid()::text;

      -- Ana görev: Sütten Kesme
      INSERT INTO gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi)
      SELECT v_parent_id, v_hayvan.id, 'SUTTEN_KESME',
             '🍼 Sütten kesme zamanı (' || v_gun || '. gün)',
             v_hedef, false
      WHERE NOT EXISTS (
        SELECT 1 FROM gorev_log
        WHERE hayvan_id = v_hayvan.id
          AND gorev_tipi = 'SUTTEN_KESME'
          AND NOT tamamlandi
      );
      GET DIAGNOSTICS v_sayac = ROW_COUNT;
      v_olusturulan := v_olusturulan + v_sayac;

      -- Alt görev: Padok Transfer (Buzağı Ahırı → Sütten Kesilmiş)
      IF v_sayac > 0 THEN
        INSERT INTO gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, parent_id, padok_hedef)
        VALUES (
          gen_random_uuid()::text, v_hayvan.id, 'PADOK_DEGISIM',
          '➡️ Padok transfer: Sütten Kesilmiş Buzağı padoğuna taşı',
          v_hedef, false, v_parent_id,
          (SELECT ad FROM padoklar WHERE ad ILIKE '%Sütten Kesilmiş%' LIMIT 1)
        );
        v_olusturulan := v_olusturulan + 1;
      END IF;

    END IF;

  END LOOP;

  RETURN jsonb_build_object('ok', true, 'olusturulan', v_olusturulan);
END;
$$;

END;
```

**Tasarım notları:**
- `NOT EXISTS` kontrolü idempotent yapar — aynı hayvan için tekrar görev açmaz
- `padok_hedef` alanı mevcut `doneTask()` fonksiyonuyla uyumlu — tamamlandığında otomatik padok yazar
- `gorev_tipi = 'SUTTEN_KESME'` → `_katTipMap.bakim` zaten bu tipi destekliyor, filtre çalışır
- `PADOK_DEGISIM` alt görev tipi de `_katTipMap.bakim` içinde

- [ ] **Step 2: Commit**

```bash
cd /root/egesut-erp1
git add supabase/migrations/*sutten_kesme*
git commit -m "migration: buzagi_sutten_kesme_kontrol RPC — 60. gün otomatik görev"
git push origin main
```

- [ ] **Step 3: GitHub Actions kontrol**

```bash
sleep 15 && gh run list --limit 3
```

---

### Task 2: Dashboard Tetikleme Butonu

**Files:**
- Modify: `js/ui.js` — `loadDash()` fonksiyonuna buzağı kontrol butonu ve çağrısı

- [ ] **Step 1: `loadDash()` içinde ileri gebe kontrol butonunu bul**

`js/ui.js` ~satır 135'te:

```javascript
const res=await rpc('ileri_gebe_gorev_kontrol');
```

Bu satırın hemen altına buzağı kontrolünü ekle:

```javascript
const resBuz=await rpc('buzagi_sutten_kesme_kontrol');
if(resBuz&&resBuz.olusturulan>0) toast(`🍼 ${resBuz.olusturulan} buzağı sütten kesme görevi oluşturuldu`);
```

Bu sayede dashboard her yüklendiğinde hem ileri gebe hem buzağı kontrolü otomatik çalışır.

- [ ] **Step 2: Dashboard band'ına buzağı sayacı ekle (opsiyonel)**

Dashboard'da ileri gebe bandının yanına sütten kesilmesi gereken buzağı sayacı:

```javascript
// loadDash() içinde, mevcut sayaçların yanına:
const sutBuzagi = _A.filter(a => a.grup && a.grup.includes('Süt İçen Buzağı') && a.dogum_tarihi && ((new Date() - new Date(a.dogum_tarihi)) / 86400000) >= 60);
if (sutBuzagi.length > 0) {
  // Mevcut dashboard band'ına ekle:
  // '🍼 ' + sutBuzagi.length + ' buzağı sütten kesilmeli'
}
```

Tam entegrasyon mevcut band HTML yapısına bağlı — mevcut `renderDash()` render pattern'ını takip et.

- [ ] **Step 3: Syntax check**

```bash
node --check /root/egesut-erp1/js/ui.js 2>&1 || echo "SYNTAX ERROR"
```

- [ ] **Step 4: Commit**

```bash
cd /root/egesut-erp1
git add js/ui.js
git commit -m "feat: dashboard — buzağı sütten kesme otomatik kontrol"
git push origin main
```

---

### Task 3: 210. Gün Laktasyon (Kuru Dönem) Uyarısı

**Files:**
- Modify: `supabase/migrations/YYYYMMDD000002_laktasyon_kuru_kontrol.sql`

**Not:** Bu görev mevcut `ileri_gebe_gorev_kontrol()` ile örtüşmüyor — o RPC gebe hayvanlar için. Bu RPC doğum yapmış ama hala sağmal padokta olan inekler için 210. gün uyarısı.

- [ ] **Step 1: Durumu kontrol et — zaten var mı?**

```bash
grep -r "210\|kuru.*donem\|laktasyon.*gun" /root/egesut-erp1/supabase/migrations/*.sql | head -10
```

Eğer 210. gün kontrolü mevcut `ileri_gebe_gorev_kontrol()` içinde varsa, bu task'ı atla.

Yoksa yeni RPC yaz:

```sql
BEGIN;

CREATE OR REPLACE FUNCTION public.laktasyon_kuru_kontrol()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_olusturulan int := 0;
  v_sayac       int := 0;
  v_rec         record;
  v_gun         int;
  v_hedef       date;
BEGIN
  -- Son doğumundan 210+ gün geçmiş, hala "Sağmal" grubundaki inekleri bul
  FOR v_rec IN
    SELECT h.id, h.kupe_no, h.grup, h.padok,
           MAX(d.tarih) AS son_dogum_tarihi
    FROM hayvanlar h
    JOIN dogum d ON d.anne_id = h.id
    WHERE h.durum = 'Aktif'
      AND h.grup ILIKE '%Sağmal%'
      AND h.grup NOT ILIKE '%Kuru%'
    GROUP BY h.id, h.kupe_no, h.grup, h.padok
    HAVING CURRENT_DATE - MAX(d.tarih) >= 210
  LOOP
    v_gun := CURRENT_DATE - v_rec.son_dogum_tarihi;
    v_hedef := v_rec.son_dogum_tarihi + 210;

    INSERT INTO gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, padok_hedef)
    SELECT gen_random_uuid()::text, v_rec.id, 'PADOK_DEGISIM',
           '⚠️ Kuru döneme geçiş zamanı (' || v_gun || '. gün laktasyon) — Kuru/Gebe padoğuna transfer',
           v_hedef, false,
           (SELECT ad FROM padoklar WHERE ad ILIKE '%Kuru%' LIMIT 1)
    WHERE NOT EXISTS (
      SELECT 1 FROM gorev_log
      WHERE hayvan_id = v_rec.id
        AND gorev_tipi = 'PADOK_DEGISIM'
        AND aciklama ILIKE '%Kuru döneme%'
        AND NOT tamamlandi
    );
    GET DIAGNOSTICS v_sayac = ROW_COUNT;
    v_olusturulan := v_olusturulan + v_sayac;

  END LOOP;

  RETURN jsonb_build_object('ok', true, 'olusturulan', v_olusturulan);
END;
$$;

END;
```

- [ ] **Step 2: Dashboard'a laktasyon kontrolü ekle**

`js/ui.js` — `loadDash()` içinde ileri gebe ve buzağı kontrollerinin yanına:

```javascript
const resLak=await rpc('laktasyon_kuru_kontrol');
if(resLak&&resLak.olusturulan>0) toast(`⚠️ ${resLak.olusturulan} inek kuru döneme geçirilmeli`);
```

- [ ] **Step 3: Commit**

```bash
cd /root/egesut-erp1
git add supabase/migrations/*laktasyon* js/ui.js
git commit -m "feat: 210. gün laktasyon kuru dönem kontrol RPC + dashboard"
git push origin main
```

---

## Acceptance Criteria

1. `buzagi_sutten_kesme_kontrol()` RPC çalışıyor — 60+ günlük Süt İçen Buzağı'lar için görev oluşturuyor
2. `laktasyon_kuru_kontrol()` RPC çalışıyor — 210+ gün laktasyondaki sağmal inekler için transfer görevi oluşturuyor
3. Her iki RPC idempotent — aynı hayvan için tekrar görev açmaz
4. Dashboard yüklendiğinde her iki kontrol otomatik çalışır
5. Oluşturulan görevler mevcut görev panelinde "Bakım" kategorisinde görünür
6. `SUTTEN_KESME` ve `PADOK_DEGISIM` tipleri `_katTipMap.bakim` içinde zaten tanımlı — filtre çalışır
7. `doneTask()` çağrıldığında `padok_hedef` otomatik padok günceller (mevcut altyapı)
