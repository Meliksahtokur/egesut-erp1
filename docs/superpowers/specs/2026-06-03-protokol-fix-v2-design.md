# Protokol Uyarı Sistemi — Fix v2 Design Spec

## Amaç

Protokol uyarı sisteminin ilk implementasyonu mevcut altyapıyı (görev modalları, IDB, tip sistemi) tanımadan sıfırdan yazılmış. Bu spec, kırık parçaları düzeltir ve sistemi mevcut altyapıya entegre eder.

## Kapsam

4 ana alan:
1. **Bug fix'ler** — IDB crash, uuid=text, duplikasyon, eski doğum yanlış pozitifleri
2. **UI entegrasyonu** — protokol ekranı ↔ görev altyapısı ↔ hayvan kartı bağlantısı
3. **Scanner düzeltmeleri** — E_VIT tutarsızlığı, stok ön-filtreleme, index'ler
4. **ground_truth.sql sync** — canonical referans güncellemesi

---

## §1 Bug Fix'ler

### §1.1 IDB Store Eksik

**Sorun:** `uygulama_log` tablosu `api.js` TABLES listesinde yok. `openDet()` içinde `pullTables(['...uygulama_log'])` çağrılıyor → IDB store bulunamıyor → hayvan kartı açılmıyor.

**Çözüm:**
- `api.js:10-13` TABLES dizisine `'uygulama_log'` ekle
- `DB_VER` 20 → 21 bump et
- `protokol_dismiss` IDB'ye eklenmeyecek — sadece RPC ile kullanılıyor

### §1.2 uuid = text Tip Uyumsuzluğu

**Sorun:** Trigger zincirinde (`trg_dinle_vaccination` → `_etken_kod_bul` → `_gorev_dinle`) uuid ve text tipleri karışıyor. Aşı yapılamıyor.

**Çözüm:** Tüm trigger fonksiyonlarında ve `_gorev_dinle` / `_etken_kod_bul` içindeki karşılaştırmalarda tip uyumunu doğrula. Gerekli yerlere `::text` cast ekle. Spesifik olarak:
- `vaccination_log.id` (uuid) → `'vaccination_log:' || NEW.id::text` — mevcut, kontrol et
- `_gorev_dinle` WHERE clause: `gorev_log.hayvan_id` (text) = `p_hayvan_id` (text) — uyumlu olmalı
- `_etken_kod_bul` içinde `drug_products.id` (uuid) ile `drug_administrations.drug_product_id` (uuid) karşılaştırması — kontrol et
- `vaccination_log.vaccine_id` (uuid) → `_etken_kod_bul(NULL, NEW.vaccine_id)` parametre tipi uuid — uyumlu olmalı

Implementasyon sırasında her trigger'ı test edip kesin hatayı bulmak gerekecek. Root cause `EXPLAIN` veya hata mesajından tespit edilecek.

### §1.3 Duplike Doğum (İkiz)

**Sorun:** 901 numaralı hayvanın dogum tablosunda aynı tarihte 2 kayıt var (ikiz doğum). Scanner her doğum kaydı × her adım = her adım çift çıkıyor.

**Çözüm:** Scanner'da (`protokol_eksik_tara`) Bölüm A (doğum sonrası) sorgusuna `DISTINCT ON (d.anne_id)` ekle — aynı anne için sadece en son doğum kaydını al.

```sql
-- ÖNCE:
FROM public.dogum d
JOIN public.hayvanlar h ON h.id = d.anne_id AND h.durum = 'Aktif'

-- SONRA:
FROM (
  SELECT DISTINCT ON (anne_id) *
  FROM public.dogum
  ORDER BY anne_id, tarih DESC
) d
JOIN public.hayvanlar h ON h.id = d.anne_id AND h.durum = 'Aktif'
```

İkiz doğum tam desteği (dogum_kaydet'in aynı anneye aynı gün 2. çağrıda anne görevlerini tekrar oluşturmaması) ayrı bir backlog item'ı olarak `.claude/ideas/ikiz-dogum-destegi.md` dosyasına kaydedildi.

### §1.4 Eski Doğum Dismiss Backfill

**Sorun:** Migration öncesi doğumlarda protokol görevleri yoktu. Scanner bu doğumları tarayınca hiçbir veri kaynağında tamamlanma bulamıyor → yanlış pozitif "eksik" gösteriyor.

**Çözüm:** Bir defaya mahsus `protokol_dismiss` backfill. Son 4 buzağı (küpe_no: 80, 79, 78, 77) anneleri HARİÇ, 70 gün içindeki tüm doğumlar için her protokol adımı için dismiss kaydı oluştur.

```sql
INSERT INTO protokol_dismiss (hayvan_id, etken_kod, protokol, neden)
SELECT d.anne_id, a.ek, 'DOGUM_PROTOKOL', 'Otomatik: migration öncesi doğum'
FROM dogum d
CROSS JOIN (VALUES
  ('OKSITOSIN'), ('ADEMIN'), ('KALSIYUM'), ('PG'), ('E_VIT')
) AS a(ek)
WHERE d.tarih >= CURRENT_DATE - 70
  AND d.tarih <= CURRENT_DATE
  AND d.yavru_kupe NOT IN ('80','79','78','77')
ON CONFLICT (hayvan_id, etken_kod, protokol) DO NOTHING;
```

Kızgınlık takibi için de aynı mantıkla:
```sql
INSERT INTO protokol_dismiss (hayvan_id, etken_kod, protokol, neden)
SELECT d.anne_id, 'MANUAL', 'KIZGINLIK_TAKIP', 'Otomatik: migration öncesi doğum'
FROM dogum d
WHERE (CURRENT_DATE - d.tarih) BETWEEN 55 AND 75
  AND d.yavru_kupe NOT IN ('80','79','78','77')
ON CONFLICT (hayvan_id, etken_kod, protokol) DO NOTHING;
```

### §1.5 Tamamlanmış Görevlere etken_kod Backfill

**Sorun:** İlk backfill (mig-01) sadece `tamamlandi=false` görevlere etken_kod yazdı. Scanner `g.tamamlandi = true AND g.etken_kod = v_rec.ek` arıyor → eski tamamlanmış görevler eşleşmiyor.

**Çözüm:**
```sql
UPDATE gorev_log SET etken_kod = 'OKSITOSIN'
WHERE etken_kod IS NULL AND tamamlandi = true AND aciklama ILIKE '%Oksitosin%';

UPDATE gorev_log SET etken_kod = 'PG'
WHERE etken_kod IS NULL AND tamamlandi = true AND aciklama ILIKE '%PG%' AND aciklama NOT ILIKE '%Ademin%';

UPDATE gorev_log SET etken_kod = 'ADEMIN'
WHERE etken_kod IS NULL AND tamamlandi = true AND (aciklama ILIKE '%Ademin%' AND aciklama NOT ILIKE '%Yeldif%' AND aciklama NOT ILIKE '%E Vit%');

UPDATE gorev_log SET etken_kod = 'E_VIT'
WHERE etken_kod IS NULL AND tamamlandi = true AND (aciklama ILIKE '%Yeldif%' OR aciklama ILIKE '%E Vit%');

UPDATE gorev_log SET etken_kod = 'KALSIYUM'
WHERE etken_kod IS NULL AND tamamlandi = true AND aciklama ILIKE '%Kalsiyum%';

UPDATE gorev_log SET etken_kod = 'ROTA'
WHERE etken_kod IS NULL AND tamamlandi = true AND aciklama ILIKE '%Rota%';
```

---

## §2 UI Entegrasyonu

### §2.1 Ekran Stack Mimarisi

```
Katman 0: Dashboard (zil ikonu + badge)
Katman 1: Protokol ekranı (tam sayfa bottom-sheet, z-index:300)
Katman 2: İş detay bottom-sheet (üzerine açılır, z-index:350)
Katman 3: Hayvan kartı (openDet, z-index:400) VEYA aksiyon formu (z-index:380)
```

**Geri tuşu davranışı:** Her katman kapanınca alttaki katman state'ini korur. `popstate` veya benzeri mekanizma ile Android geri tuşu desteklenir.

**İşlem sonrası:** Uygula/dismiss/geri al sonrası sadece ilgili satır güncellenir. Tüm liste yeniden yüklenmez. `window.__protokolUyarilar` array'i mutate edilir.

### §2.2 Satır Tıklama → İş Detay Bottom-Sheet

Protokol listesindeki her satırın tamamı tıklanabilir. Mevcut butonlar (`💉 Uygula`, `✕`) satır içinde kalır ama satırın geri kalanına tıklayınca iş detay açılır.

**İş detay içeriği (timeline görünümü):**
- Başlık: hayvan küpe no (tıklanabilir → openDet) + grup
- O hayvanın o protokoldeki TÜM adımlarının listesi:
  - Her adım: ikon (✅/🔴/🟡) + adım adı + hedef tarih + gecikme/kalan gün
  - Tamamlanmış: kapatan_ref bilgisi (hangi kayıtla kapandı)
  - Eksik: "💉 Uygula" + "✕ Geçersiz Kıl" butonları
  - Yaklaşan: "💉 Uygula" butonu (erken uygulama)

**Veri kaynağı:** `window.__protokolUyarilar` array'inden `hayvan_id + protokol` filtresiyle.

### §2.3 Aksiyon Butonları

#### ROTA aşısı (etken_kod = 'ROTA')
1. gorev_log'da eşleşen görev ara: `hayvan_id + etken_kod='ROTA' + tamamlandi=false`
2. Görev varsa → `_curTaskDet` olarak set et → mevcut `m-task-det` modalını aç → `td-asi-form` göster
3. Görev yoksa → `hizli_uygulama` ile stok bazlı form (Rota aşısı filtrelenmiş)

#### İlaç görevleri (OKSITOSIN, PG, ADEMIN, E_VIT, KALSIYUM)
1. `hizli_uygulama` RPC kullanılır
2. Stok listesi etken_kod'a göre ön-filtrelenir (§3.2'deki `_ETKEN_FILTERE` kullanılır)
3. Form: iş detay bottom-sheet içinde mini form (mevcut `proto-mini` pattern'i refactor edilir)

#### Kızgınlık takibi (etken_kod = NULL)
- "Uygula" butonu YOK (manuel görev)
- Sadece "✅ Tamamla" (gorev_log'daki kızgınlık görevini tamamlar) ve "✕ Geçersiz Kıl" (dismiss)

### §2.4 Hayvan Kartı Navigasyonu

İş detay bottom-sheet'indeki hayvan küpe numarası tıklanabilir link (mavi, underline). Tıklayınca:
1. İş detay bottom-sheet gizlenir (remove değil, `display:none`)
2. `openDet(hayvan_id)` çağrılır
3. Android geri tuşuyla hayvan kartı kapanır → iş detay tekrar `display:block`

---

## §3 Scanner Düzeltmeleri

### §3.1 E_VIT Tutarsızlığı

Scanner VALUES listesinden +53 E_VIT satırını kaldır. Son hali:
```sql
(53, 'ADEMIN',    '53. Gün: Ademin'),
(54, 'E_VIT',     '54. Gün: Yeldif')
```
Önceki: +53'te hem ADEMIN hem E_VIT vardı, +54'te de E_VIT vardı. Ademin ve E Vitamini ayrı uygulamalar, aralarında birkaç gün olması yeterli.

### §3.2 Stok Ön-Filtreleme

`_protokolUygula` formunda stok listesi etken_kod'a göre filtrelenir. `ui.js:752`'de başlanmış `_ETKEN_FILTERE` objesi tamamlanır ve kullanılır:

```javascript
const _ETKEN_FILTERE = {
  'OKSITOSIN': s => /oksitosin/i.test(s.urun_adi),
  'PG':        s => /pg\b|pgf|cloprostenol|dalmazin/i.test(s.urun_adi),
  'E_VIT':     s => /yeldif|e.?vit|selenyum/i.test(s.urun_adi),
  'ADEMIN':    s => /ademin/i.test(s.urun_adi),
  'KALSIYUM':  s => /kalsiyum|calcium/i.test(s.urun_adi),
};
```

Eşleşen stok sayısı 0 ise → `toast('Bu etken madde için stok bulunamadı', true)` gösterilir, form açılmaz.

### §3.3 Ek Index'ler

Yeni migration ile:
```sql
CREATE INDEX IF NOT EXISTS idx_dogum_anne_tarih ON public.dogum(anne_id, tarih DESC);
CREATE INDEX IF NOT EXISTS idx_tohumlama_hayvan_sonuc ON public.tohumlama(hayvan_id, sonuc, tarih);
```

### §3.4 Kızgınlık Aralığı

Değişiklik yok. Mevcut `BETWEEN 55 AND 75` kalır. Geniş aralık daha güvenli.

---

## §4 ground_truth.sql Sync

Tüm fix'ler tamamlandıktan sonra `99999999999999_ground_truth.sql` güncellenir. Eklenmesi gereken tanımlar:

**Yeni tablolar:**
- `uygulama_log` — tablo + RLS + index'ler
- `protokol_dismiss` — tablo + RLS

**Yeni fonksiyonlar:**
- `_etken_kod_bul(text, uuid)` — etken kod helper
- `_gorev_dinle(text, text, text)` — görev dinleme
- `hizli_uygulama(text, text, numeric, text, text, text)` — hızlı uygulama RPC
- `hizli_uygulama_geri_al(uuid)` — geri alma RPC
- `protokol_eksik_tara()` — scanner (düzeltilmiş versiyon)

**Yeni trigger'lar:**
- `fn_dinle_vaccination` + `trg_dinle_vaccination`
- `fn_dinle_uygulama` + `trg_dinle_uygulama`
- `fn_dinle_drug_admin` + `trg_dinle_drug_admin`

**Güncellenmiş fonksiyonlar:**
- `dogum_kaydet` — 9 anne görevi + etken_kod
- `fn_gebe_gorev_yarat` — etken_kod'lu

**Güncellenen tablo tanımları:**
- `gorev_log` — `etken_kod text`, `kapatan_ref text` kolonları + `idx_gorev_log_etken` index

---

## Kapsam Dışı

- İkiz doğum tam desteği (backlog: `.claude/ideas/ikiz-dogum-destegi.md`)
- Görev sekmesi ↔ protokol birleştirme (Yaklaşım B — gelecek iterasyon)
- Protokol ekranı push notification entegrasyonu
