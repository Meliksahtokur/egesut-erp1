# Protokol Uyarı Sistemi — Geliştirme Notları
**Tarih:** 2026-06-03
**Kapsam:** Review → Fix (Batch 1 DB + Batch 2 UI) → Bilinen Sorunlar

---

## 1. Başlangıç Durumu

Protokol Uyarı Sistemi (spec: `docs/superpowers/specs/2026-06-03-protokol-uyari-sistemi-design.md`, plan: `docs/superpowers/plans/2026-06-03-protokol-uyari-sistemi.md`) implementasyonu review edildi. Review raporu: `review/2026-06-03-protokol-uyari-sistemi-review.md`.

### Review sonucu: 23 ✅ / 6 ⚠️ / 0 ❌

6 iyileştirme noktasının 4'ü fixlendi, 2'si kozmetik/bilgi.

---

## 2. Review Fix'leri (Batch 0)

| # | Dosya | Değişiklik | Commit |
|---|-------|-----------|--------|
| 1 | `js/ui.js:756` | `_ETKEN_FILTERE` objesi + etken_kod bazlı stok filtreleme | `f5c6b07` |
| 2 | `mig-01` | `dogum_kaydet`'e `('53. Gün: Yeldif', E_VIT)` eklendi, görev 16→17 | `f5c6b07` |
| 3 | `mig-04` | Kızgınlık aralığı `BETWEEN 55 AND 75` → `55 AND 70` | `f5c6b07` |
| 4 | `mig-04` | `idx_dogum_anne_tarih` + `idx_tohumlama_hayvan_sonuc_tarih` | `f5c6b07` |
| 5 | `ground_truth` | Aynı değişiklikler ground_truth'a yansıtıldı | `a5474c3` |

---

## 3. Protokol Fix v2 — Batch 1 (DB)

Plan: `docs/superpowers/plans/2026-06-03-protokol-fix-v2.md`

### Task 1 — IDB Fix
- **Dosya:** `js/api.js`
- **Değişiklik:** TABLES dizisine `'uygulama_log'` eklendi, `DB_VER` 20→21
- **Commit:** `55f969d`

### Task 2 — uuid=text cast fix
- **Dosya:** `supabase/migrations/20260603000005_protokol_fix_v2.sql`
- **Değişiklik:** `ileri_gebe_asi_tamamla` fonksiyonunda `WHERE id = p_gorev_id::uuid` → `WHERE id = p_gorev_id`
- **Not:** `gorev_log.id` TEXT tipinde. `::uuid` cast'i `uuid = text` operatör hatası veriyordu.
- **Deploy:** `supabase_migrate` ile `$func$` delimiter kullanılarak başarıyla deploy edildi. `$$` delimiter Management API'de sessizce başarısız oluyor.

### Task 3 — Backfill
- **Etken_kod backfill:** Tamamlanmış görevlere 6 etken_kod UPDATE (OKSITOSIN, PG, ADEMIN, E_VIT, KALSIYUM, ROTA). PG/Ademin çakışması `NOT ILIKE` ile önlendi.
- **Dismiss backfill:** Son 4 buzağı (80,79,78,77) anneleri HARİÇ tüm eski doğumlar dismiss edildi. `ON CONFLICT DO NOTHING` ile idempotent.

### Task 4 — Scanner Fix + Deploy + Test
- **DISTINCT ON:** İkiz doğum yapan anneler için `SELECT DISTINCT ON (anne_id) * FROM dogum ORDER BY anne_id, tarih DESC` — aynı anne birden fazla kez taranmıyor.
- **E_VIT fix:** VALUES listesinden `(53, 'E_VIT')` kaldırıldı — sadece +54 Yeldif kaldı. `dogum_kaydet`'e +53 Yeldif görevi eklendiği için tutarlı.
- **Kızgınlık aralığı:** `BETWEEN 55 AND 70` (plan 55-75 istiyordu, kullanıcı 55-70 kararı verdi).
- **Index'ler:** `idx_dogum_anne_tarih` (DESC), `idx_tohumlama_hayvan_sonuc`.
- **Test:** RPC çağrısı başarılı — 901 duplikasyon yok, +53 E_VIT yok, dismiss backfill çalışıyor.

### Batch 1 Commit'leri
```
55f969d  fix: add uygulama_log to IDB TABLES, bump DB_VER to 21
697d970  fix: uuid cast, etken_kod backfill, dismiss backfill, scanner DISTINCT ON + E_VIT fix
```

---

## 4. Protokol Fix v2 — Batch 2 (UI)

### Task 5 — Satır Tıklama + İş Detay
- **Dosya:** `js/ui.js`
- **`_satirHtml` değişikliği:** Satır div'ine `cursor:pointer` + `onclick="_showProtokolDetay(...)"`, buton container'a `onclick="event.stopPropagation()"`
- **`_showProtokolDetay(hayvanId, protokol, activeIdx)`:** Yeni fonksiyon — tüm adımları timeline olarak gösterir, her adımda ikon + butonlar, hayvan küpe no'su link (hayvan kartına gider), `history.pushState` ile stack'e ekler.
- **`_protoDetayHayvanGit(hayvanId)`:** Detay + protokol bottom-sheet'leri gizler, `openDet(hayvanId)` ile hayvan kartını açar.
- **Commit:** `a203de6`

### Task 6 — popstate Stack
- **`js/ui.js`:** `_showProtokolEkran`'da `history.pushState({protokol:true}, '', '');`
- **`js/app.js` popstate handler:**
  ```
  proto-detay-bs açık → kapat, protokol-bs'yi göster
  hayvan kartı (det.on) açık → kapat, protokol ekranlarını göster
  diğer → goTo(e.state?.pg || 'dash')
  ```
- **Commit:** `a15ebbf` (Task 6+7 birlikte)

### Task 7 — İşlem Sonrası Yerinde Güncelleme
- **3 fonksiyon değişti:** `_protokolUygulaKaydet`, `_protokolDismiss`, `_protokolGeriAl`
- **Eski:** `document.getElementById('protokol-bs')?.remove(); loadDash();`
- **Yeni:**
  1. `rpc('protokol_eksik_tara')` çağır → `window.__protokolUyarilar` güncelle
  2. Badge güncelle (bellbadge)
  3. Proto-detay-bs açıksa yeniden oluştur
  4. Protokol-bs'i yeniden oluştur (`_showProtokolEkran()`)
- **Commit:** `a15ebbf`

---

## 5. Kritik Bug Fix'leri (Batch 2 sonrası)

### 5.1 Dismiss Butonu Çalışmıyor
- **Kök neden:** `js/api.js`'de `const db = createClient(...)` block-scoped → `ui.js`'ten erişilemiyor.
- **Fix:** `window.db = db` eklendi (`js/api.js:20`).
- **Ek fix:** `db.from(...).insert(...)` yanıtında `{ error }` kontrolü eklendi.
- **Commit:** `bc8294a`

### 5.2 "x gün kaldı" Hep 0
- **Kök neden:** Scanner RPC `GREATEST(v_gecikme, 0)` — negatif değerleri (gelecek günler) 0'a çekiyor.
- **Fix:** `GREATEST(v_gecikme, 0)` → `v_gecikme` (ham değer). Frontend `Math.abs()` ile pozitif gösteriyor.
- **Etkilenen:** Scanner'da 3 bölüm (A/B/C), 3 migration dosyası (`00004`, `00005`, `ground_truth`).
- **Commit:** `e757959`

### 5.3 İlaç Uygulama Butonu İşlevsiz (DEVAM EDİYOR)
- **Kök neden:** `_ETKEN_FILTERE` regex'leri stok `urun_adi` ile eşleşmiyor. Stok'ta marka isimleri var (Antepsin, Ketojezik, Enrolen...), regex etken isimleri arıyor (Oksitosin, PG, Ademin...).
- **Veritabanı zinciri:** `stok → drug_products (brand_name) → drug_classes (active_ingredient)` — bu zincir frontend'de yok.
- **Çözüm seçenekleri:**
  - **A)** `stok_etken_kod_bul(p_etken_kod)` RPC oluştur — eşleşen stok ID'lerini döndür.
  - **B)** IDB stok store'una `drug_class` / `active_ingredient` alanlarını join ile ekle.
- **Durum:** 🔴 Bekliyor

---

## 6. Teknik Notlar

### 6.1 `supabase_migrate` Davranışı
- Basit SQL (SELECT, basit CREATE FUNCTION single-quote body) → çalışır
- `$$` delimiter'lı kompleks fonksiyon → `[]` döner ama deploy etmez (Management API sessiz başarısız)
- `$func$` delimiter → çalışır ✅
- Hata mesajı dönmez, her zaman `[]` döner

### 6.2 `gorev_log.id` Tipi
- **Tip:** TEXT (UUID formatında string saklar)
- **INSERT:** `gen_random_uuid()` veya `gen_random_uuid()::text` — ikisi de çalışır (implicit cast)
- **WHERE karşılaştırma:** `WHERE id = p_gorev_id` (text=text) — `::uuid` YAPMA
- **uuid kolona INSERT:** `gen_random_uuid()` kullan, `::text` YAPMA

### 6.3 `ileri_gebe_asi_tamamla` — İki Versiyon
- ground_truth'ta 2 versiyon var: satır 4852 (eski) ve satır 6922 (yeni — `_gorev_dinle` trigger kullanır)
- Canlıda hangisi aktif bilinmiyor. Fix'imiz satır 6356'daki orta versiyonu hedef aldı (ground_truth'taki referans buydu).

### 6.4 Scanner DISTINCT ON
- `SELECT DISTINCT ON (anne_id) * FROM dogum ORDER BY anne_id, tarih DESC`
- İkiz doğum yapan anneler için sadece en son doğum kaydı alınır
- A ve C bölümlerinde uygulandı

### 6.5 Kızgınlık Aralığı
- **Plan:** `BETWEEN 55 AND 75`
- **Kullanıcı kararı:** `BETWEEN 55 AND 70`
- **Gerekçe:** Spec §6 "58-70 gün" diyor, 55-70 spec'e daha yakın

---

## 7. Dosya Değişiklik Özeti

| Dosya | Batch | Değişiklik |
|-------|-------|-----------|
| `js/api.js` | 1 | `window.db = db`, TABLES + uygulama_log, DB_VER=21 |
| `js/ui.js` | 1+2+Bug | `_ETKEN_FILTERE`, satır tıklama, detay bottom-sheet, popstate, yerinde güncelleme, dismiss hata kontrolü |
| `js/app.js` | 2 | popstate handler — protokol stack desteği |
| `mig-01` | 0 | `dogum_kaydet` +53 Yeldif, 16→17 |
| `mig-04` | 0 | 55→70 range, index'ler, GREATEST fix |
| `mig-05` | 1 | uuid cast, backfill, scanner DISTINCT ON, scanner GREATEST fix |
| `ground_truth` | 0+Bug | Tüm değişiklikler senkronize edildi |

---

## 8. Bilinen Açık Sorunlar

| # | Sorun | Önem | Durum |
|---|-------|------|-------|
| 1 | İlaç uygulama butonu — stok filtreleme eşleşmiyor | 🔴 Kritik | Çözüm bekliyor |
| 2 | Dismiss butonu — `window.db` fix test edilmedi | 🟡 Orta | Canlıda test bekliyor |
| 3 | Aşı uygulama (ileri_gebe_asi_tamamla) — deploy test edilmedi | 🟡 Orta | Canlıda test bekliyor |
| 4 | ground_truth'ta `ileri_gebe_asi_tamamla` 3 versiyon var — hangisi canlıda? | 🟠 Düşük | Araştırma gerek |

---

## 9. Sonraki Adımlar

1. **İlaç uygulama butonu fix:** `stok_etken_kod_bul` RPC oluştur veya IDB join yap
2. **Canlı test:** Dismiss + aşı uygulama butonlarını test et
3. **Task 8-9:** Plan'da kalan UI iyileştirmeleri + ground_truth final sync
4. **Memory güncelle:** `tools-bank` memory'sine kritik kuralları ekle
