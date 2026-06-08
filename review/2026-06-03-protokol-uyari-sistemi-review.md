# Protokol Uyarı Sistemi — Review Raporu

**Tarih:** 2026-06-03
**Reviewer:** DeepSeek TUI (bağımsız review ajanı)
**Kapsam:** Spec + Plan'a karşı tam implementasyon review

---

## SPEC UYUMU

| Bölüm | Durum | Not |
|-------|-------|-----|
| §3 — Etken kod sistemi | ✅ | `_etken_kod_bul` 6 kodu doğru eşleştiriyor (OKSITOSIN, PG, E_VIT, ADEMIN, KALSIYUM, ROTA). Drug_class + active_ingredient + stok_ad üzerinden marka bağımsız çalışıyor. |
| §3 — İkisi de NULL | ✅ | Her iki parametre NULL → NULL dönüyor (mig-01:69). |
| §4 — _gorev_dinle | ✅ | FIFO sıralaması doğru: `ORDER BY hedef_tarih ASC LIMIT 1` (mig-01:96-97). NULL guard var (mig-01:86-88). |
| §4 — kapatan_ref formatı | ✅ | Tutarlı: `vaccination_log:uuid`, `uygulama_log:uuid`, `drug_admin:uuid` (tümü `id::text`). |
| §4 — Trigger'lar (3 adet) | ✅ | `trg_dinle_vaccination` (mig-03:28), `trg_dinle_uygulama` (mig-03:42), `trg_dinle_drug_admin` (mig-03:67). drug_admin trigger'ı `treatment_days→cases→animal_id` zincirini doğru çözüyor (mig-03:58-62). |
| §4 — Backfill | ✅ | 6 etken_kod için doğru pattern eşleşmesi (mig-01:113-136). PG/Ademin çakışması `NOT ILIKE '%Ademin%'` ile önlenmiş. |
| §4 — dogum_kaydet etken_kod | ✅ | 9 anne görevinin hepsine etken_kod atanmış (mig-01:194-204). Kızgınlık görevi NULL (doğru). |
| §4 — fn_gebe_gorev_yarat | ✅ | 3 göreve ROTA/ADEMIN/E_VIT atanmış (mig-01:248-270). idempotent (WHERE NOT EXISTS). |
| §5 — uygulama_log tablosu | ✅ | Şema spec'e uygun: id uuid, hayvan_id text FK, etken_kod, doz/birim/rota NOT NULL, notlar NOT NULL (mig-02:12-19). CHECK constraint doğru (mig-02:17). |
| §5 — hizli_uygulama RPC | ✅ | etken_kod türetiyor (mig-02:69), stok_hareket INSERT (mig-02:75-77), trigger otomatik _gorev_dinle çağırır. Hayvan aktiflik kontrolü var. Not zorunlu. |
| §5 — hizli_uygulama_geri_al RPC | ✅ | Stok iade (mig-02:103-105) → görev restore (mig-02:108-111) → uygulama DELETE (mig-02:113). Sıra doğru. |
| §6 — protokol_eksik_tara (A: Doğum) | ⚠️ | 9 adım taranıyor. Ancak **53. gün E_VIT görevi dogum_kaydet'ta yok** — mig-01'de +53'te sadece ADEMIN görevi oluşturuluyor, E_VIT görevi +54'te. Scanner +53'te hem ADEMIN hem E_VIT tarıyor. ±3 günlük pencere sayesinde +54 E_VIT uygulaması +53 kontrolünde de yakalanabiliyor — çalışır durumda ama tutarsız. |
| §6 — protokol_eksik_tara (B: İleri Gebe) | ✅ | 3 adım (240/260/265), ROTA için vaccination_log kontrolü (mig-04:190-198), ADEMIN/E_VIT için standart kontrol sırası. |
| §6 — protokol_eksik_tara (C: Kızgınlık) | ⚠️ | Taranıyor ancak **tarih aralığı geniş**: spec "58-70 gün" derken WHERE `(v_today - d.tarih) BETWEEN 55 AND 75` (mig-04:254). Kabul edilebilir, ama spec'ten sapma. |
| §6 — Dönen format | ✅ | `durum`, `hedef_tarih`, `gecikme_gun`, `tamamlanma_tarihi`, `kapatan_ref` alanları doğru. `tamamlandi` durumu son 24 saat için (mig-04:125-126). |
| §6 — protokol_dismiss | ✅ | Tablo şeması spec'e uygun (mig-04:12-20). UNIQUE(hayvan_id, etken_kod, protokol). |
| §7 — Zil ikonu + badge | ✅ | index.html:368 — `#bellbtn` + `#bellbadge`. loadDash() içinde badge güncelleniyor (ui.js:293-300). Uyarı >99 ise "99+". |
| §7 — Protokol ekranı | ✅ | `_showProtokolEkran()` tam sayfa bottom-sheet (ui.js:705-750). Üç bölüm: gecikmiş (kırmızı), yaklaşan (sarı), tamamlanan (yeşil). Renk kodları doğru. |
| §7 — Uygula/Geri Al/Geçersiz butonları | ⚠️ | Üç buton da var (ui.js:734-736). Ancak **"Uygula" stok filtresi etken_kod'a göre yapılmıyor** — spec/plan etken_kod bazlı ön-filtreleme isterken, implementasyon sadece `kategori && !['Yem','Sperma']` filtresi yapıyor (ui.js:756). Plan'ın 1394-1399 satırlarındaki switch-case filtreleme uygulanmamış. |
| §7 — Geri Al akışı | ✅ | Onay dialogu var (ui.js:829). Sadece `uygulama_log:...` ref'leri için `hizli_uygulama_geri_al` çağrılıyor. Diğer kaynaklar için "geri alınamaz" toast (ui.js:843-845). |
| §8 — Hayvan kartı Hızlı Uygulama butonu | ✅ | `💉 Hızlı Uygulama` butonu var (ui.js:1145). `_hayvanHizliUygulama()` bottom-sheet formu (ui.js:847-878). |
| §8 — Uygulama geçmişi | ✅ | Hayvan detay Sağlık sekmesinde "💉 Hızlı Uygulamalar" bölümü (ui.js:1278-1291). Tarih, stok adı, doz, birim, rota, not gösteriliyor. `openDet()` içinde uygulama_log verisi çekiliyor (ui.js:1340). |

---

## KOD KALİTESİ

- **[✅] SQL injection**: Tüm frontend çağrıları `rpc()` üzerinden parametreli. `protokol_dismiss` Supabase client `insert()` kullanıyor. Raw SQL concatenation yok.
- **[✅] XSS**: Template'lerde `esc()` kullanılıyor: kupe_no, grup, adim, etken_kod, stok adı, notlar. `kapatan_ref` onclick içinde `esc()` ile korunuyor. `esc()` fonksiyonu `js/utils/helpers.js:23`'te `textContent` tabanlı, güvenli.
- **[✅] SECURITY DEFINER**: Tüm yeni RPC'ler (`_etken_kod_bul`, `_gorev_dinle`, `dogum_kaydet`, `fn_gebe_gorev_yarat`, `hizli_uygulama`, `hizli_uygulama_geri_al`, `protokol_eksik_tara`) SECURITY DEFINER ile tanımlanmış.
- **[✅] RLS policy**: `uygulama_log` (mig-02:34-38) ve `protokol_dismiss` (mig-04:24-30) için `anon_all_*` policy'leri mevcut. GRANT doğru.
- **[⚠️] Index'ler**: Temel index'ler mevcut (`idx_gorev_log_etken`, `idx_uygulama_log_hayvan`, `idx_uygulama_log_tarih`). Scanner sorguları için ek index'ler faydalı olabilir: `dogum(anne_id, tarih)`, `tohumlama(hayvan_id, sonuc, tarih)`. Mevcut haliyle çalışır, performans riski düşük.
- **[⚠️] `_etken_kod_bul` JOIN mantığı**: `drug_administrations` üzerinden `drug_product_id` bulma (mig-01:52-56) + `brand_name` fallback (mig-01:57) karmaşık. Eğer hiç `drug_administration` yoksa sadece brand_name eşleşmesine kalır. Stok ürünleri için bu yeterli.

---

## TUTARLILIK

- **[✅] kapatan_ref formatı**: Üç trigger da aynı formatta: `table_name:uuid`. `vaccination_log:uuid`, `uygulama_log:uuid`, `drug_admin:uuid`.
- **[✅] etken_kod değerleri**: Backfill UPDATE'ler (mig-01:113-136), `_etken_kod_bul` (mig-01:25-71), scanner VALUES (mig-04:57-65, 164-168) hep aynı 6 kodu kullanıyor.
- **[✅] dogum_kaydet görev sayısı**: 9 anne + 1 buzağı ana + 6 buzağı alt = 16. RETURN'de `'gorev_sayisi', 16` (mig-01:230).
- **[✅] Fonksiyon parametreleri**: Frontend `hizli_uygulama` çağrısı `p_hayvan_id, p_stok_id, p_doz, p_birim, p_rota, p_notlar` — DB imzasıyla birebir eşleşiyor. `hizli_uygulama_geri_al` için `p_uygulama_id` — uyumlu.
- **[⚠️] Scanner vs dogum_kaydet görev eşleşmesi**: Yukarıda belirtildiği gibi 53. gün E_VIT görevi dogum_kaydet'ta +54'te, scanner'da +53'te aranıyor. ±3 günlük tolerans sayesinde kopmaz ama ideal değil.

---

## EDGE CASE'LER

- **[✅] _etken_kod_bul: ikisi de NULL**: `p_stok_id` ve `p_vaccine_id` NULL → en sondaki `RETURN NULL` çalışır (mig-01:69).
- **[✅] _gorev_dinle: birden fazla eşleşme**: `ORDER BY hedef_tarih ASC LIMIT 1` ile en yakın tarihli olan kapanır. FIFO doğru.
- **[✅] Scanner: 70+ gün sınırı**: `WHERE d.tarih >= v_today - 70` (mig-04:67) ile son 70 günde doğum yapan anneler taranıyor. Gün +58 adımları doğumdan 58-70 gün sonrasına denk gelir. 70 gün sonra tarama durur — spec'e uygun. `v_hedef > v_today + 7` filtresiyle gelecek 7 gün içindeki adımlar da gösterilir — doğru.
- **[✅] Scanner: gebe→doğum**: `dogum_kaydet` RPC'si `tohumlama.sonuc`'u `'Doğum Yaptı'` olarak günceller. Scanner B bölümü `WHERE t.sonuc = 'Gebe'` ile filtreler — doğum yapan hayvan ileri gebe protokolünde çıkmaz.
- **[✅] Geri al: kapatan_ref olmayan görevler**: `_protokolGeriAl` (ui.js:828) sadece `uygulama_log:...` ref'lerini işler. Diğerleri için "Bu işlem geri alınamaz" toast. Güvenli.
- **[✅] _gorev_dinle: p_etken_kod NULL guard**: `IF p_etken_kod IS NULL OR p_hayvan_id IS NULL THEN RETURN;` (mig-01:86-88) — null etken_kod ile gereksiz UPDATE denenmez.
- **[✅] Kızgınlık takibi dismiss**: `etken_kod` NULL olan kızgınlık görevi için dismiss `'MANUAL'` olarak insert edilir. Scanner dismiss kontrolü `pd.protokol = 'KIZGINLIK_TAKIP'` ile etken_kod'suz çalışır — uyumlu.
- **[✅] hizli_uygulama: stok ID tipi**: `stok_hareket.id` text, INSERT'te `gen_random_uuid()::text` kullanılmış. `dogum_kaydet` içindeki `gorev_log.id` için `gen_random_uuid()` (castsiz) kullanılmış — PostgreSQL implicit cast ile çalışır. Kozmetik fark, işlevsel sorun yok.

---

## ÖZET

**Toplam: 23 ✅ / 6 ⚠️ / 0 ❌**

### Kritik sorun yok
Implementasyon çalışır durumda. Tüm RPC'ler, trigger'lar ve UI bileşenleri spec'in ana hatlarını karşılıyor. Hiçbir kırık (❌) bulgu yok.

### İyileştirme önerileri (⚠️)

1. **Stok ön-filtreleme eksik** (Orta): `_protokolUygula()` fonksiyonu etken_kod'a göre stok filtrelemiyor (ui.js:756). Plan'da belirtilen switch-case filtreleme uygulanmalı. Kullanıcı şu anda protokol ekranından "Uygula" dediğinde tüm ilaç stokları geliyor, oysa spec sadece ilgili etken_kod ürünlerinin listelenmesini istiyor.

2. **Scanner — 53. gün E_VIT görev eksikliği** (Düşük): `dogum_kaydet` +53'te sadece ADEMIN görevi oluşturuyor, E_VIT yok. Scanner'da +53'te E_VIT de taranıyor. ±3 günlük pencere sayesinde kırılmaz, ama tutarlılık için `dogum_kaydet`'e `('53. Gün: Yeldif', p_tarih+53, ..., 'E_VIT')` eklenebilir veya scanner'dan +53 E_VIT kaldırılıp sadece +54 bırakılabilir.

3. **Scanner kızgınlık aralığı** (Düşük): 55-75 gün yerine spec'teki 58-70 kullanılabilir.

4. **Ek index'ler** (Düşük): Scanner performansı için `dogum(anne_id, tarih)` ve `tohumlama(hayvan_id, sonuc, tarih)` composite index'leri düşünülebilir.

5. **ground_truth.sql güncellenmemiş** (Bilgi): Task 17 bekliyor — bu beklenen bir durum, ❌ değil.

6. **`gen_random_uuid()` castsiz kullanım** (Kozmetik — ✅ işlevsel sorun yok): `dogum_kaydet` içinde `gorev_log.id` için `gen_random_uuid()` castsiz, `stok_hareket.id` için `::text`'li. PostgreSQL implicit cast ile çalışır. Düzeltme öncelikli değil.

---

## Referans Verilen Dosyalar

| Dosya | Satır(lar) |
|-------|-----------|
| `supabase/migrations/20260603000001_protokol_etken_kod.sql` | 12-19 (Task 1), 25-71 (Task 2), 77-107 (Task 3), 113-136 (Task 4), 142-274 (Task 5) |
| `supabase/migrations/20260603000002_uygulama_log.sql` | 12-38 (Task 6), 40-89 (Task 7), 91-118 (Task 8) |
| `supabase/migrations/20260603000003_dinleme_trigger.sql` | 17-31 (vaccination), 35-45 (uygulama), 51-70 (drug_admin) |
| `supabase/migrations/20260603000004_protokol_scanner.sql` | 12-30 (Task 10), 36-328 (Task 11) |
| `js/ui.js` | 293-300 (zil badge), 705-750 (protokol ekranı), 752-807 (Uygula), 809-826 (Dismiss), 828-846 (Geri Al), 847-900 (hayvan hızlı uygulama), 1145 (buton), 1278-1291 (uygulama geçmişi), 1340 (veri çekme) |
| `index.html` | 368 (bell button + badge) |
| `supabase/migrations/99999999999999_ground_truth.sql` | 63-98 (yeni tablolar eklenmiş, RPC/trigger'lar Task 17 bekliyor) |
| `js/utils/helpers.js` | 23 (esc fonksiyonu) |
