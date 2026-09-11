# Teklif — `dogum.buzagi_id`: doğum→buzağı kimlik bağının sezgelden kolona alınması

**Durum:** Dış review KABUL (2026-09-11) + 3 düzeltme uygulandı — owner'ın nihai onayı bekliyor  
**Tarih:** 2026-09-11 (Revizyon 3 ile, pedigree implementasyon planı D7; aynı gün Rev 2 düzeltmeleri)  
**Kaynak:** Bağımsız dış review + root değerlendirmesi  
**Dokunulan canlı yüzey:** `dogum` tablosu + `dogum_kaydet` RPC + `geri_al` uyumu

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
  ADD COLUMN buzagi_id text NULL
    REFERENCES public.hayvanlar(id) ON DELETE SET NULL;

CREATE UNIQUE INDEX dogum_buzagi_id_uidx
  ON public.dogum (buzagi_id)
  WHERE buzagi_id IS NOT NULL;
```

**`ON DELETE SET NULL` (Rev 2 — dış review düzeltmesi 1):** `dogum` tarihsel
bir olaydır; bir nedenle calf satırı silinirse doğum kaydı **kalmalı**, yalnız
`buzagi_id` NULL olmalı. `CASCADE` tarihsel doğum kaydını istemeden
uçurabilirdi; elle null'lama gereksiz prosedürel bağımlılık üretirdi; default
`NO ACTION` ise calf DELETE'ini bloklardı. `SET NULL` tam istenen FK
semantiği: `geri_al` doğum geri alımında `calf DELETE → FK otomatik NULL →
(geri_al siliyorsa) dogum DELETE` sırası veya tersi — ikisi de sorunsuz.

**Partial UNIQUE (Rev 2 — dış review düzeltmesi 2):** bir buzağı biyolojik
olarak en fazla bir doğum satırının yavrusudur (ikizler = `olay_id` paylaşan
ayrı `dogum` satırları — her biri kendi yavrusunu taşır). `WHERE buzagi_id IS
NOT NULL` kısmi unique, iki `dogum` satırının aynı calf'i claim etmesini DDL
seviyesinde engeller; calf→dogum lookup'ı da bu index'le çözülür. (İlk
taslakta önerilen `(anne_id, buzagi_id)` index'i kaldırıldı: öncü kolon
`anne_id` olduğundan `buzagi_id = ?` sorgusunda B-tree fayda vermez;
`anne_id` bazlı sorgular gerekiyorsa mevcut/ayrı index ile yürür.)

- **`dogum_kaydet`** buzağı `hayvanlar` satırını üretirken aynı transaction'da
  yazar; mevcut RPC sırası `dogum` önce ise sorun yok:
  `INSERT dogum (..., buzagi_id=NULL) RETURNING id` → `INSERT hayvanlar ...
  RETURNING id` → `UPDATE dogum SET buzagi_id=... WHERE id=...` — hepsi tek
  transaction, atomicity korunur.
- **İkiz akışı** (`olay_id` modeli, 2026-09-01'de canlıda): her `dogum`
  satırı kendi yavrusunun id'sini taşır; kardeş eşleştirmesi `olay_id`
  üzerinden kalır — `anne_id + olay_id + buzagi_id` üçlüsü tam model:
  DAM / sibling-event / CALF.
- **Backfill**: bkz §2b (konservatif kural).

### 2b. Backfill — konservatif kural (Rev 2 — dış review düzeltmesi 3)

İlk taslak "bugünkü 4 kriterli sıralamayı tek sefer koş, yeni hata üretmez"
diyordu; **yanlıştı.** Sıralama-sezgeli "en muhtemel buzağıyı BUL" için
yazılmıştı; sonucunu FK kolonuna yazdığın an "muhtemelen bu" → "biyolojik
olarak BU"ya terfi eder — yanlış tahmin artık yalnız yanlış UI sonucu değil,
**authoritative identity corruption** olur. Kural:

```text
kupe exact eşleşme + dogum.tarih == hayvanlar.dogum_tarihi + TEK aday
    → AUTO BACKFILL (yaz)
çok aday / tarih uyumsuz / aday yok
    → NULL bırak + backfill raporunda warning satırı
```

**Yanlış FK yazmaktansa NULL bırak** — pedigree tasarımının kendi
disiplini (fuzzy semen merge yok, unresolved kalabilir) burada da geçerli.
Eski 4 kriterli ranking ancak `suggested_candidate` (UI önerisi / manuel
düzeltim yardımcısı) olarak yaşayabilir; authoritative backfill için
kullanılmaz. Backfill raporu auto / cok-aday / tarih-uyumsuz / aday-yok
sayaçlarını yazar; NULL kalan satırlar sahip çıkılmayan doğum kaydı olarak
integrity raporunda görünür kalır.

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
- **Backfill yanlış eşleştirme riski:** konservatif kural (yalnız exact+unique
  ise yaz, gerisi NULL+warning) yanlış FK yazımını yapısal olarak kapatır —
  sezgelinin riskli eşleşmeleri kolona hiç girmez (§2b).

## 5. Ret edilirse

Plan aynen yürür: sezgeli Task 2.3/9'da kalır, `buzagi_id` v2 bandına döner.
Hiçbir pedigree fazı bu teklife bağımlı DEĞİLDİR (join'ler bugün de çalışıyor).

## 6. Sıra ve karar

Dış review'un onayladığı sıralama (pedigree migration'ına gömme, ayrı task):

```text
P1 / Task 0 — dogum.buzagi_id foundation (migration + dogum_kaydet + unique index)
        ↓
P1 / Task 1 — pedigree foundation
        ↓
P1 / Task 2 — konservatif backfill + integrity entegrasyonu
```

- [ ] **KABUL** — P1 Task 0 olarak uygula (dış review KABUL etti, 3 Rev-2
      düzeltmesi işlendi: SET NULL + partial unique + konservatif backfill;
      nihai onay owner'ın)
- [ ] **RET** — v2 bandına bırak, plan değişmez
