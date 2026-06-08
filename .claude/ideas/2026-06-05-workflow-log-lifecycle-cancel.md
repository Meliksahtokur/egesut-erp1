# Workflow Log + Lifecycle Cancel Guarantee

**Tarih:** 2026-06-05  
**Durum:** Fikir — Brainstorm aşaması, implemente edilmedi  
**Öncelik:** Yüksek — BUG-051, BUG-013 gibi "stale görev" sorunlarının kök sebebi bu  
**Tahmini efor:** 1-2 oturum (DB migration + RPC güncelleme)

---

## Problem: Neden "kopukluk" hissediyoruz?

Mevcut sistemde `gorev_log` hem task storage hem de workflow state görevi görüyor — ama ikincisini yarım yapıyor.

```
gorev_log bugün:
├── hayvan_id
├── kaynak ('DOGUM-H000042')  ← informal group key, enforce edilmiyor
├── gorev_tipi
├── tamamlandi / iptal
└── hedef_tarih
```

### Eksik olan iki şey:

**1. Lifecycle kapanma garantisi**

Bir hayvan doğum yaptığında → bağlı BESLEME task'ları iptal edilmeli  
Bir hayvan satıldığında → TÜM bekleyen task'lar iptal edilmeli  
Bir hayvan öldüğünde → TÜM bekleyen task'lar iptal edilmeli  

Bu şu an ya yoktur, ya yarım uygulanmıştır, ya da migration overwrite ile düşmüştür (BUG-051 tam buydu).

**2. Protokol durumu sorgulanamıyor**

"Bu doğum protokolü tamamlandı mı?" sorusuna cevap vermek için gorev_log'u aggregate etmek gerekiyor. Bir `workflow_log` satırına bakarak cevap alınamıyor. Dashboard'a eklemek, rapor çıkarmak, uyarı üretmek zorlaşıyor.

---

## Mevcut Lifecycle Olayları ve Bugünkü Durumu

| Olay | RPC | Cancel yapıyor mu? | Eksik |
|---|---|---|---|
| Doğum | `dogum_kaydet` | ✅ BESLEME iptal (BUG-051 fix sonrası) | TOHUMLAMA_HAZIRLIK, diğerleri? |
| Tohumlama tekrar | `tohumlama_tekrar_kaydet` | ✅ Eski GEBELIK_KONTROL iptal | — |
| Hayvan satış/çıkış | `hayvan_cikis` (var mı?) | ❓ Bilinmiyor | TÜM pending task'lar |
| Hayvan ölüm | `hayvan_olum` (var mı?) | ❓ Bilinmiyor | TÜM pending task'lar |
| Tedavi kapatma | vaka kapanınca | ❓ Bilinmiyor | Tedaviye bağlı task'lar |

---

## Önerilen Çözüm

### Adım 1: `protokol_instance` tablosu (workflow_log)

```sql
CREATE TABLE public.protokol_instance (
  id            uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  hayvan_id     text NOT NULL REFERENCES public.hayvanlar(id),
  tip           text NOT NULL,        -- 'DOGUM', 'TOHUMLAMA', 'TEDAVI', 'BUZAGI', 'ILERI_GEBE'
  kaynak_ref    text NOT NULL UNIQUE,  -- gorev_log.kaynak ile eşleşen değer ('DOGUM-H000042')
  baslangic     date NOT NULL,
  bitis         date,                 -- protokol kaç günde bitmeli (NULL = süresiz)
  durum         text DEFAULT 'aktif', -- aktif | tamamlandi | iptal | aksadi
  kapandi_at    timestamptz,
  kapandi_sebep text,                 -- 'DOGUM', 'OLUM', 'SATIS', 'MANUEL', 'TAMAMLANDI'
  created_at    timestamptz DEFAULT now()
);

CREATE INDEX idx_protokol_instance_hayvan ON protokol_instance(hayvan_id, durum);
CREATE INDEX idx_protokol_instance_kaynak ON protokol_instance(kaynak_ref);
```

### Adım 2: `gorev_log.protokol_instance_id` FK ekle

```sql
ALTER TABLE public.gorev_log 
  ADD COLUMN protokol_instance_id uuid REFERENCES public.protokol_instance(id) ON DELETE SET NULL;

CREATE INDEX idx_gorev_log_protokol ON gorev_log(protokol_instance_id) WHERE protokol_instance_id IS NOT NULL;
```

Mevcut `kaynak` alanı korunur — geriye dönük uyumluluk için. `protokol_instance_id` yeni bir FK olarak eklenir.

### Adım 3: Lifecycle Cancel Helper Function

```sql
CREATE OR REPLACE FUNCTION public._protokol_kapat(
  p_kaynak_ref  text,
  p_sebep       text  -- 'DOGUM', 'OLUM', 'SATIS', 'MANUEL'
) RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  -- gorev_log'daki tüm bekleyenleri iptal et
  UPDATE public.gorev_log
  SET iptal = true
  WHERE kaynak = p_kaynak_ref
    AND tamamlandi = false
    AND iptal = false;

  -- protokol_instance durumunu güncelle
  UPDATE public.protokol_instance
  SET durum = 'iptal',
      kapandi_at = now(),
      kapandi_sebep = p_sebep
  WHERE kaynak_ref = p_kaynak_ref
    AND durum = 'aktif';
END;
$$;
```

### Adım 4: Hayvan çıkış/ölüm RPC'si — TÜM pending task'ları iptal et

```sql
-- hayvan_cikis veya hayvan_olum RPC içinde:
UPDATE public.gorev_log
SET iptal = true
WHERE hayvan_id = p_hayvan_id
  AND tamamlandi = false
  AND iptal = false;

UPDATE public.protokol_instance
SET durum = 'iptal', kapandi_at = now(), kapandi_sebep = p_sebep
WHERE hayvan_id = p_hayvan_id
  AND durum = 'aktif';
```

---

## Mevcut RPC'lerde Değişmesi Gerekenler

| RPC | Değişiklik |
|---|---|
| `dogum_kaydet` | Yeni `protokol_instance` satırı ekle (tip='DOGUM', kaynak_ref='DOGUM-{anne_id}') + yavru için (tip='BUZAGI') |
| `tohumlama_kaydet` | tip='TOHUMLAMA', kaynak_ref='TOH-{hayvan_id}-{toh_id}' instance ekle |
| `hayvan_cikis` / `hayvan_olum` | Tüm aktif instanceları kapat + tüm pending task'ları iptal et |
| `dogum_kaydet` (anne için) | BESLEME cancel zaten var; TOHUMLAMA protokol instance'ını da kapat |
| `tedavi_protokol_baslat` | tip='TEDAVI' instance ekle |

---

## Frontend Kazanımları

```javascript
// Şu an: Her hayvan için pending task count hesaplamak için gorev_log aggregate gerekiyor
const pendingTasks = await supabase.rpc('hayvan_gorev_ozet', { p_hayvan_id: id });

// Sonra: Doğrudan protokol durumu görülebilir
const activeProtocols = await supabase
  .from('protokol_instance')
  .select('tip, durum, baslangic, bitis')
  .eq('hayvan_id', id)
  .eq('durum', 'aktif');

// Dashboard: "Bugün aksayan protokoller" sorgusu
const aksayanlar = await supabase
  .from('protokol_instance')
  .select('*, hayvanlar(kupe_no, padok)')
  .eq('durum', 'aksadi');
```

---

## Göç Stratejisi (Mevcut Veri)

1. **Migration 1:** Tablo oluştur + index
2. **Migration 2:** Mevcut `kaynak` değerlerinden backfill — `gorev_log`'da `DOGUM-*`, `TOH-*`, `BUZAGI-*` gibi kaynak değerlerini tarayarak `protokol_instance` satırları üret. Durumu mevcut task'lardan derive et (hepsi tamamlandıysa 'tamamlandi', iptal varsa 'iptal', yoksa 'aktif').
3. **Migration 3:** `gorev_log.protokol_instance_id` FK ekle + backfill
4. **Migration 4:** RPC'leri güncelle (dogum_kaydet, tohumlama_kaydet, hayvan_cikis vb.)

---

## Açık Sorular (Implement öncesi netleşmeli)

1. **`hayvan_cikis` / `hayvan_olum` RPC'leri mevcut mu?** Yoksa önce oluşturulmalı mı?
2. **TEDAVI protokolleri:** `cases` tablosu mu, ayrı bir şey mi? Bağlantı nasıl kurulacak?
3. **Aksadı tespiti nasıl olacak?** Cron job mu (daily check), RPC call sırasında mı, yoksa sadece query-time hesaplama mı? Önerim: query-time (hedef_tarih < today AND tamamlandi=false → aksadı, persist etme)
4. **`kaynak_ref` UNIQUE constraint:** Bir hayvana birden fazla tohumlama olabileceğinden TOH için ID eklemek şart. Mevcut format tutarlı mı?
5. **Buzağı protokolleri:** Anne doğum instance'ından ayrı mı tutulsun, yoksa aynı instance'a mı bağlansın?

---

## Risk Analizi

| Risk | Olasılık | Etki | Önlem |
|---|---|---|---|
| Backfill migration yanlış durum türetirse | Orta | Düşük — sadece yeni tablo | Backfill'i conservative yap (şüpheliyse 'aktif' bırak) |
| RPC güncelleme sırasında atlanmış nokta | Yüksek | Orta | Her RPC için integration test senaryosu yaz |
| `protokol_instance_id` NULL kalırsa | Yüksek (eski veri) | Düşük — nullable FK | Eski veriler NULL kalabilir, sorun değil |

---

## Implement Sırası (Önerim)

1. Tablo oluştur (migration)
2. `_protokol_kapat` helper function
3. `dogum_kaydet` güncelle (en kritik + en çok test edilmiş)
4. `tohumlama_kaydet` güncelle
5. Hayvan çıkış/ölüm lifecycle (yeni veya mevcut RPC)
6. Backfill migration (mevcut veri)
7. Frontend: protokol durumu gösterimi
