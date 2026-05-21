# TASK-026 — Gebelik / deneme_no Düzeltmesi

**Durum:** ✅ TAMAMLANDI — tüm değişiklikler zaten uygulanmış  
**Öncelik:** Yüksek  
**Tarih:** 2026-05-21

---

## Problem

Doğum yapıp tekrar tohumlanan hayvanlar yeni laktasyon siklusunda `deneme_no` sıfırlanmadığı için `5. Tohumlama` olarak görünüyor. Ayrıca doğum kaydedilmeden 260+ gün geçmiş 'Gebe' hayvanlar yeniden tohumlanmak istendiğinde sistem bloklıyor.

---

## Araştırma Bulguları (Claude tarafından)

### Bug 1 — deneme_no lifetime counter

`tohumlama_kaydet` RPC (ground_truth line ~3740) ve `set_deneme_no()` trigger aynı hatalı mantığı kullanıyor:

```sql
-- HATALI: tüm zamanların MAX'ı
SELECT COALESCE(MAX(deneme_no), 0) + 1 INTO v_deneme 
FROM public.tohumlama WHERE hayvan_id = p_hayvan_id;
```

**Olması gereken:** Son 'Doğum Yaptı' veya 'Abort' tarihinden SONRA kaç tohumlama yapıldı + 1

### Bug 2 — 260 gün sonrası auto-close yok

`tohumlama_kaydet` (line ~3730):
```sql
IF EXISTS (SELECT 1 FROM tohumlama WHERE hayvan_id=... AND sonuc='Gebe') THEN
  RETURN 'Hayvan zaten gebe'  -- her zaman blokluyor, 260 günü gözetmiyor
```

### Mevcut Fonksiyonlar

| Fonksiyon | Dosya | Notlar |
|---|---|---|
| `tohumlama_kaydet` | ground_truth ~3696 | DROP + RECREATE |
| `set_deneme_no()` | ground_truth ~164 | Trigger function |
| `trg_deneme_no` | ground_truth ~176 | BEFORE INSERT trigger |
| `dogum_kaydet` | ground_truth ~3435 | Referans — baba_bilgi mantığına bak |

### Önemli Kısıtlar

- `hayvanlar` tablosunda `dogum_sayisi` kolonu YOK — laktasyon sayısı `dogum` tablosundan türetiliyor
- `dogum_kaydet` buzağı bilgisi olmadan çağrılamaz — auto-close sadece tohumlama.sonuc günceller
- Tüm referans: `supabase/migrations/99999999999999_ground_truth.sql`

---

## İstenen Değişiklikler

### Değişiklik 1 — `set_deneme_no()` trigger düzelt

```sql
-- PER-CYCLE sayım: son 'Doğum Yaptı' veya 'Abort'tan sonraki kayıt sayısı + 1
SELECT COALESCE(COUNT(*), 0) + 1 INTO NEW.deneme_no
FROM public.tohumlama
WHERE hayvan_id = NEW.hayvan_id
  AND tarih > COALESCE(
    (SELECT MAX(tarih) FROM public.tohumlama 
     WHERE hayvan_id = NEW.hayvan_id AND sonuc IN ('Doğum Yaptı', 'Abort')),
    '1900-01-01'::date
  );
```

### Değişiklik 2 — `tohumlama_kaydet` RPC güncelle

a) `deneme_no` hesabını trigger ile tutarlı hale getir (return value için)

b) 'Gebe' kontrolünü güncelle:
```sql
-- 'Gebe' varsa → kaç gün geçmiş bak
IF (CURRENT_DATE - v_gebe_toh.tarih::date) > 260 THEN
  -- Otomatik kapat
  UPDATE tohumlama SET sonuc='Doğum Yaptı' WHERE id = v_gebe_toh.id;
  INSERT INTO islem_log (..., tip='DOGUM_OTOMATIK', ...);
  -- devam et — uyarı return'e ekle
ELSE
  RETURN 'Hayvan zaten gebe — önce gebeliği kapatın'
END IF
```

c) Return value'ya `uyari` alanı ekle (auto-close olunca):
```json
{"ok": true, "uyari": "Aktif gebelik 260+ gün geçtiği için otomatik kapatıldı — doğum kaydı manuel tamamlanmalı"}
```

---

## Görev Akışı

1. **[GOOSE]** Araştır: ground_truth'tan exact fonksiyonları oku, trigger'ın hâlâ aktif olup olmadığını doğrula, son migration numarasını bul
2. **[GOOSE]** Plan yaz: migration dosya adı, tam SQL, test sorguları
3. **[CLAUDE ONAY]** `approval_req` gönder — plan review bekle
4. **[GOOSE]** Onayland ıktan sonra migration yaz + commit
5. **[GOOSE]** Self-review: migration syntax, ground_truth güncel mi
6. **[CLAUDE]** Final review

---

## Kabul Kriterleri

- [ ] Doğum yapmış ineğin yeni tohumlaması `deneme_no=1` ile başlıyor
- [ ] 'Gebe' + 260+ gün → yeni tohumlama geçiyor, uyarı dönüyor
- [ ] 'Gebe' + <260 gün → hâlâ blokluyor
- [ ] `trg_deneme_no` ve RPC tutarlı
- [ ] `ground_truth.sql` güncellendi
- [ ] Commit mesajı: `fix(db): tohumlama deneme_no per-cycle sıfırlama + 260-gün auto-close`
