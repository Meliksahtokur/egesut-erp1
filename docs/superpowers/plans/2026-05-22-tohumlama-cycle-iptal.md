# Tohumlama Cycle State Machine — Implementasyon Planı

> Soru varsa devam etmeden önce sor. DB değişikliklerinde onay bekle.

**Hedef:** Yeni tohumlama başlayınca veya gebelik kapanınca önceki cycle'ın görevleri otomatik iptal edilsin. `ref_tohumlama_id` ile her görev hangi cycle'a ait olduğunu bilsin. Guard trigger ile stale görev oluşumu engele alınsın.

**Etkilenen dosyalar:**
- `supabase/migrations/20260522000002_tohumlama_cycle_iptal.sql` (YENİ)

**Etkilenen tablolar:** `gorev_log`, `tohumlama`  
**Etkilenen RPC'ler:** `gebelik_protokol_kontrol`, `tohumlama_kaydet`

---

## Başlamadan Önce

Sırayla oku:
```bash
cat /root/egesut-erp1/supabase/migrations/99999999999999_ground_truth.sql
cat /root/egesut-erp1/.claude/rpc-reference.md
cat /root/egesut-erp1/.claude/domain-rules.md
```

Sonra bu planı oku. Net olmayan bir adım varsa sor.

---

## Task 1 — Schema: `gorev_log.ref_tohumlama_id` Kolonu

**Okuma:**
```bash
# gorev_log şemasını doğrula
supabase_query({
  table: "information_schema.columns",
  filters: "table_name=eq.gorev_log",
  select: "column_name,data_type",
  limit: 50
})
```

**ONAY GEREKLİ:**
```
ALTER TABLE public.gorev_log ADD COLUMN IF NOT EXISTS ref_tohumlama_id text;
CREATE INDEX IF NOT EXISTS idx_gorev_log_ref_tohumlama
  ON public.gorev_log(ref_tohumlama_id) WHERE ref_tohumlama_id IS NOT NULL;

Etkilenen: gorev_log (DDL — veri kaybı yok, sadece kolon ekleme)
Onaylıyor musunuz?
```

**Uygulama:**
```
supabase_migrate({sql: `
ALTER TABLE public.gorev_log
  ADD COLUMN IF NOT EXISTS ref_tohumlama_id text;

CREATE INDEX IF NOT EXISTS idx_gorev_log_ref_tohumlama
  ON public.gorev_log(ref_tohumlama_id)
  WHERE ref_tohumlama_id IS NOT NULL;
`})
```

**Doğrulama:**
```
supabase_query({
  table: "information_schema.columns",
  filters: "table_name=eq.gorev_log&column_name=eq.ref_tohumlama_id",
  select: "column_name,data_type"
})
```
Beklenen: `{"column_name":"ref_tohumlama_id","data_type":"text"}` dönmeli.

**Commit:**
```bash
git add supabase/migrations/20260522000002_tohumlama_cycle_iptal.sql
git commit -m "feat(db): gorev_log.ref_tohumlama_id kolonu + index"
```

---

## Task 2 — Trigger: Tohumlama Cycle Geçişinde Görev İptali

Bu trigger iki durumda ateşlenir:
1. **INSERT** — yeni tohumlama girilince → hayvanın TÜM açık gebelik görevlerini iptal et (hepsi önceki cycle'a ait)
2. **UPDATE sonuc → Boş/Abort** — gebelik boş/düşük çıkınca → bu cycle'ın açık görevlerini iptal et

**Okuma:**
```bash
# Mevcut tohumlama trigger var mı kontrol et
grep -n "tohumlama_cycle\|cycle_iptal\|gorevcil_iptal" \
  /root/egesut-erp1/supabase/migrations/99999999999999_ground_truth.sql
```

**ONAY GEREKLİ:**
```
Yeni trigger: tohumlama_cycle_iptal_trigger
  AFTER INSERT OR UPDATE OF sonuc ON tohumlama
  → gorev_log'da ILERI_GEBE, ILERI_GEBE_ASI, PADOK_DEGISIM, BESLEME, TOHUMLAMA_HAZIRLIK
    tipindeki açık görevleri iptal eder

Etkilenen: gorev_log (UPDATE iptal=true), trigger ekleme
Risk: yok — sadece açık+iptal=false görevlere dokunur
Onaylıyor musunuz?
```

**Uygulama — migration dosyasına ekle:**
```
supabase_migrate({sql: `
-- ── Tohumlama cycle geçişinde görev iptali ──────────────────────────────
CREATE OR REPLACE FUNCTION public.tohumlama_cycle_gorevcil_iptal()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  -- Yeni tohumlama INSERT → tüm önceki cycle gebelik görevleri iptal
  IF TG_OP = 'INSERT' THEN
    UPDATE public.gorev_log
    SET iptal = true
    WHERE hayvan_id = NEW.hayvan_id
      AND tamamlandi = false
      AND iptal = false
      AND gorev_tipi IN (
        'ILERI_GEBE', 'ILERI_GEBE_ASI', 'PADOK_DEGISIM',
        'BESLEME', 'TOHUMLAMA_HAZIRLIK'
      );
    RETURN NEW;
  END IF;

  -- UPDATE: sonuc Boş veya Abort oldu → bu cycle görevleri iptal
  IF TG_OP = 'UPDATE'
     AND OLD.sonuc IN ('Bekliyor', 'Gebe')
     AND NEW.sonuc IN ('Boş', 'Abort') THEN
    UPDATE public.gorev_log
    SET iptal = true
    WHERE hayvan_id = NEW.hayvan_id
      AND tamamlandi = false
      AND iptal = false
      AND gorev_tipi IN (
        'ILERI_GEBE', 'ILERI_GEBE_ASI', 'PADOK_DEGISIM',
        'BESLEME', 'TOHUMLAMA_HAZIRLIK'
      )
      AND (ref_tohumlama_id IS NULL OR ref_tohumlama_id = NEW.id::text);
    RETURN NEW;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS tohumlama_cycle_iptal_trigger ON public.tohumlama;
CREATE TRIGGER tohumlama_cycle_iptal_trigger
  AFTER INSERT OR UPDATE OF sonuc ON public.tohumlama
  FOR EACH ROW EXECUTE FUNCTION public.tohumlama_cycle_gorevcil_iptal();
`})
```

**Doğrulama:**
```
supabase_query({
  table: "information_schema.triggers",
  filters: "trigger_name=eq.tohumlama_cycle_iptal_trigger",
  select: "trigger_name,event_manipulation,event_object_table"
})
```
Beklenen: trigger satırı dönmeli.

**Commit:**
```bash
git add supabase/migrations/20260522000002_tohumlama_cycle_iptal.sql
git commit -m "feat(db): tohumlama cycle trigger — cycle geçişinde gebelik görevleri iptal"
```

---

## Task 3 — Guard Trigger: gorev_log INSERT Anomali Koruması

Bu trigger BEFORE INSERT ON gorev_log ateşlenir. Eğer yeni görev bir `ref_tohumlama_id` taşıyorsa ve o tohumlama artık aktif değilse (`sonuc NOT IN ('Bekliyor','Gebe')`) → görevi `iptal=true` olarak ekle. Stale veri hiç görünmez.

**Okuma:**
```bash
grep -n "gorev_log.*trigger\|BEFORE INSERT.*gorev" \
  /root/egesut-erp1/supabase/migrations/99999999999999_ground_truth.sql | head -10
```

**ONAY GEREKLİ:**
```
BEFORE INSERT trigger: gorev_log_cycle_guard_trigger
  ref_tohumlama_id varsa → tohumlama sonucu kontrol et
  Aktif değilse (Boş/Abort/Doğum Yaptı) → NEW.iptal = true set et

Etkilenen: gorev_log INSERT behavior
Risk: düşük — sadece ref_tohumlama_id dolu satırları etkiler (null olanlara dokunmaz)
Onaylıyor musunuz?
```

**Uygulama:**
```
supabase_migrate({sql: `
-- ── gorev_log INSERT guard — stale cycle koruması ───────────────────────
CREATE OR REPLACE FUNCTION public.gorev_log_cycle_guard()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  IF NEW.ref_tohumlama_id IS NOT NULL THEN
    IF NOT EXISTS (
      SELECT 1 FROM public.tohumlama
      WHERE id::text = NEW.ref_tohumlama_id
        AND sonuc IN ('Bekliyor', 'Gebe')
    ) THEN
      NEW.iptal := true;
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS gorev_log_cycle_guard_trigger ON public.gorev_log;
CREATE TRIGGER gorev_log_cycle_guard_trigger
  BEFORE INSERT ON public.gorev_log
  FOR EACH ROW EXECUTE FUNCTION public.gorev_log_cycle_guard();
`})
```

**Doğrulama:**
```
supabase_query({
  table: "information_schema.triggers",
  filters: "trigger_name=eq.gorev_log_cycle_guard_trigger",
  select: "trigger_name,action_timing,event_object_table"
})
```

**Commit:**
```bash
git add supabase/migrations/20260522000002_tohumlama_cycle_iptal.sql
git commit -m "feat(db): gorev_log guard trigger — stale cycle koruması"
```

---

## Task 4 — RPC Güncelleme: `ref_tohumlama_id` Set Et

`gebelik_protokol_kontrol` ve `tohumlama_kaydet` yeni görev oluştururken `ref_tohumlama_id` set etmeli. Böylece guard trigger ve cycle trigger doğru çalışır.

**Okuma:**
```bash
# gebelik_protokol_kontrol son halini oku (ground_truth değil, son migration)
cat /root/egesut-erp1/supabase/migrations/20260521000001_gebelik_protokol_kontrol_hayvan_listesi.sql \
  | grep -n "INSERT INTO.*gorev_log" | head -10

# tohumlama_kaydet ground_truth'ta
grep -n "INSERT INTO.*gorev_log\|v_gorev1_id\|v_gorev2_id" \
  /root/egesut-erp1/supabase/migrations/99999999999999_ground_truth.sql | head -10
```

Sonra her fonksiyonun tam `INSERT INTO gorev_log` satırlarını bul.

**ONAY GEREKLİ:**
```
gebelik_protokol_kontrol: tüm INSERT INTO gorev_log ifadelerine
  kolon listesine `ref_tohumlama_id` ekle,
  değer olarak `v_toh.id::text` geç

tohumlama_kaydet: gorev1_id + gorev2_id INSERT'lerine
  kolon listesine `ref_tohumlama_id` ekle,
  değer olarak `v_toh_id::text` geç

Her ikisi CREATE OR REPLACE ile deploy edilecek.
SQL taslağını önce göster, onay bekle.
```

**Uygulama:**
- `gebelik_protokol_kontrol` için: 20260521000001 migration'daki tam fonksiyonu oku, INSERT INTO gorev_log satırlarına `ref_tohumlama_id` ekle, `supabase_migrate` ile REPLACE et.
- `tohumlama_kaydet` için: ground_truth'taki 3700. satır civarındaki fonksiyonu oku (satır 3700-3840), INSERT satırlarına `ref_tohumlama_id` ekle, `supabase_migrate` ile REPLACE et.

Her deploy sonrası `supabase_rpc` ile fonksiyonu test et.

**Doğrulama — gebelik_protokol_kontrol:**
```
supabase_rpc({function_name: "gebelik_protokol_kontrol", params: "{}"})
```
Sonra:
```
supabase_query({
  table: "gorev_log",
  filters: "gorev_tipi=eq.ILERI_GEBE&ref_tohumlama_id=not.is.null",
  select: "id,ref_tohumlama_id,hedef_tarih",
  limit: 3
})
```
Beklenen: `ref_tohumlama_id` dolu satırlar görünmeli.

**Doğrulama — tohumlama_kaydet (canlı hayvan üzerinde test yok, RPC imzasını kontrol et):**
```bash
grep -n "besleme_tamam\|tohumlama_kaydet\|gebelik_protokol_kontrol" \
  /root/egesut-erp1/.claude/rpc-reference.md
```

**Commit:**
```bash
git add supabase/migrations/20260522000002_tohumlama_cycle_iptal.sql
git commit -m "feat(db): gebelik_protokol_kontrol + tohumlama_kaydet ref_tohumlama_id set"
```

---

## Task 5 — Mevcut Stale Görevleri Temizle (Tek Seferlik)

Şu an DB'de aktif tohumlaması olmayan hayvanlara ait açık gebelik görevleri var (hayvan 195 dahil). Bunları iptal et.

**Okuma — stale görevleri say:**
```
supabase_query({
  table: "gorev_log",
  filters: "tamamlandi=eq.false&iptal=eq.false&gorev_tipi=in.(ILERI_GEBE,ILERI_GEBE_ASI,PADOK_DEGISIM,BESLEME)",
  select: "id,hayvan_id,gorev_tipi,hedef_tarih,ref_tohumlama_id",
  limit: 50
})
```

Kaç tane etkilenecek gör, ardından onay al.

**ONAY GEREKLİ:**
```sql
UPDATE public.gorev_log
SET iptal = true
WHERE tamamlandi = false
  AND iptal = false
  AND gorev_tipi IN ('ILERI_GEBE', 'ILERI_GEBE_ASI', 'PADOK_DEGISIM', 'BESLEME')
  AND NOT EXISTS (
    SELECT 1 FROM public.tohumlama
    WHERE tohumlama.hayvan_id = gorev_log.hayvan_id
      AND tohumlama.sonuc = 'Gebe'
  );

Etkilenen: aktif gebeliği olmayan hayvanlara ait gebelik görevleri
Risk: geri alınabilir (iptal=false ile restore edilebilir)
Onaylıyor musunuz?
```

**Uygulama:**
```
supabase_migrate({sql: `
UPDATE public.gorev_log
SET iptal = true
WHERE tamamlandi = false
  AND iptal = false
  AND gorev_tipi IN ('ILERI_GEBE', 'ILERI_GEBE_ASI', 'PADOK_DEGISIM', 'BESLEME')
  AND NOT EXISTS (
    SELECT 1 FROM public.tohumlama
    WHERE tohumlama.hayvan_id = gorev_log.hayvan_id
      AND tohumlama.sonuc = 'Gebe'
  );
`})
```

**Doğrulama:**
```
supabase_query({
  table: "gorev_log",
  filters: "tamamlandi=eq.false&iptal=eq.false&gorev_tipi=in.(ILERI_GEBE,ILERI_GEBE_ASI,PADOK_DEGISIM,BESLEME)",
  select: "id,hayvan_id,gorev_tipi",
  limit: 10
})
```
Beklenen: sadece aktif gebeler dönmeli (0 veya az satır).

**Commit:**
```bash
git add supabase/migrations/20260522000002_tohumlama_cycle_iptal.sql
git commit -m "fix(db): stale gebelik görevleri temizlendi — aktif gebeliği olmayan hayvanlar"
```

---

## Task 6 — Push + Son Doğrulama

**Push:**
```bash
git push origin main
```

**Doğrulama — hayvan 195:**
```
supabase_query({
  table: "gorev_log",
  filters: "hayvan_id=eq.a4c61f97-64d4-403c-b6d2-878195020a44&tamamlandi=eq.false&iptal=eq.false",
  select: "gorev_tipi,aciklama,hedef_tarih",
  limit: 10
})
```
Beklenen: ILERI_GEBE/ILERI_GEBE_ASI görünmemeli. Sadece yeni tohumlama cycle'ına ait görevler (TOHUMLAMA_HAZIRLIK 21/35. gün) dönmeli.

**Tamamlanma raporu:**
```
TAMAMLANDI

Task 1 — Schema: ✅ [commit hash]
Task 2 — Cycle trigger: ✅ [commit hash]
Task 3 — Guard trigger: ✅ [commit hash]
Task 4 — RPC ref_tohumlama_id: ✅ [commit hash]
Task 5 — Stale temizlik: ✅ [commit hash]
Task 6 — Push: ✅

Hayvan 195 DB doğrulama: [sorgu sonucu]
Açık soru: [varsa yaz]
```
