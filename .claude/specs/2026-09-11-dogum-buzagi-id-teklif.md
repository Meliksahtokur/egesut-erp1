# Teklif — `dogum.buzagi_id`: doğum→buzağı kimlik bağının sezgelden kolona alınması

**Durum:** Owner-kapılı teklif (karar bekliyor)  
**Tarih:** 2026-09-11 (Revizyon 3 ile, pedigree implementasyon planı D7)  
**Kaynak:** Bağımsız dış review + root değerlendirmesi  
**Dokunulan canlı yüzey:** `dogum` tablosu + `dogum_kaydet` RPC + (opsiyonel) `geri_al`

---

## 1. Problem

`dogum` satırı doğurduğu buzağıyı bugün yalnız `yavru_kupe` **metni** üzerinden
tanır. Küpe numaraları recycle edilebildiği için (domain kuralı: benzersizlik
yalnız aktif+dolu küpede) "bu doğum satırının gerçek yavrusu hangi
`hayvanlar` satırı?" sorusu deterministik OLMAZ; cevabın her yerde yeniden
üretilmesi gerekir. Pedigree planı bunu bugün üç yerde üretiyor:

1. **Task 2.3 integrity** — `dogum_anne_graph_dam_celiskisi` join'i: skaler
   alt sorguda 4 ölçütlü sıralama (`dogum_tarihi = dogum.tarih DESC NULLS LAST`,
   `durum='Aktif' DESC`, `dogum_tarihi DESC`, `h.id` kırbaçı).
2. **Task 9 maternal backfill** — anne_id'li hayvanların doğum edge'leri için
   4-koşullu EXISTS predikatı (tarih eşleşmesi dahil).
3. **Task 4.3/16 completeness** — buzağı node çözümü aynı sezgele bağlı.

Her biri kendi başına doğru yazılmış olsa da üç sonuç aynı sezgelinin üç
kopyasıdır; kolon olmadığı sürece yeni tüketiciler (ikiz görünümü, undo,
provenance) de sezgeliden beslenecek.

## 2. Teklif

```sql
ALTER TABLE public.dogum
  ADD COLUMN buzagi_id text NULL REFERENCES public.hayvanlar(id);
-- hayvanlar.id text (canlı, S4 kanıtı); boş bırakılabilir: legacy satırlar
CREATE INDEX ... ON dogum (anne_id, buzagi_id);
```

- **`dogum_kaydet`** buzağı `hayvanlar` satırını üretirken aynı transaction'da
  `buzagi_id`'yi yazar (maliyet ≈ 0 — id zaten elinde).
- **İkiz akışı** (`olay_id` modeli, 2026-09-01'de canlıda): her `dogum` satırı
  kendi yavrusunun id'sini taşır; kardeş eşleştirmesi `olay_id` üzerinden
  kalır, ikisi birlikte tam bilgi verir.
- **`geri_al`**: doğum geri alındığında buzağı `hayvanlar` satırı siliniyorsa
  FK (default NO ACTION değil — `ON DELETE SET NULL` değil) **kolonu da
  temizler**: `buzagi_id ... ON DELETE CASCADE` DEĞİL, kolon NULL'lanabilir
  yapıda bırakılıp geri_al akışı edge'lerle birlikte NULL'lar. (Kesin davranış
  implementasyonda `geri_al`'in mevcut DELETE zinciriyle hizalanır; canlı
  `geri_al` bu tabloya dokunmuyorsa kolon pasif kalır.)
- **Backfill**: mevcut satırlar için bugünkü Task 2.3 sıralaması TEK SEFER
  çalıştırılır; eşleşmeyen satırlar NULL kalır (sezgelinin "kupe eşleşmesi
  yok" durumuyla aynı). Backfill raporu eşleşme oranını yazar.

## 3. Kazanç

| Yüzey | Etki |
|---|---|
| dogum → calf kimliği | kesinleşir (sezgeliden kolona) |
| integrity join'leri | skaler alt sorgu → düz FK |
| maternal backfill | 4-koşullu EXISTS → `buzagi_id IS NOT NULL` |
| undo / geri_al | buzağı kapsamı açık |
| pedigree provenance | edge `evidence` alanına `dogum.buzagi_id` yazılır |
| küpe recycle | sorun olmaktan çıkar (tarihsel satırlar id ile bağlı) |

## 4. Risk ve maliyet

- **Canlı `dogum_kaydet`'e dokunur** (advisory lock'lu, `geri_al`
  entegrasyonlu üretilen RPC). Bu yüzden ayrı migration + ayrı test + demo
  ortamında davranış doğrulaması gerekir; pedigree fazının içine gömülmez,
  **kabul edilirse P1'in ilk task'ı** olur.
- Kolon NULL-able + additive: deploy geri alınabilir, mevcut okuma yolları
  kırılmaz.
- Backfill yanlış eşleştirme riski: bugünkü sezgelinin birebir aynısını tek
  sefer koştuğu için **yeni** hata üretmez; oranı rapora yazar.

## 5. Ret edilirse

Plan aynen yürür: sezgeli Task 2.3/9'da kalır, `buzagi_id` v2 bandına döner.
Hiçbir pedigree fazı bu teklife bağımlı DEĞİLDİR (join'ler bugün de çalışıyor).

## 6. Karar

- [ ] **KABUL** — P1 Task 0 olarak uygula (migration + dogum_kaydet + backfill + test)
- [ ] **RET** — v2 bandına bırak, plan değişmez
