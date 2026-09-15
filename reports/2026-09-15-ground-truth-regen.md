# G1 — Ground Truth Yenileme Raporu (2026-09-15 senkronu)

Görev zarfı: `.ss/tasks/G1-ground-truth-regen.md` (SALT OKUNUR prod, incremental,
format koru, pg_dump ile tam yeniden üretim YOK). Tarih etiketi zarf gereği
2026-09-15; çalışma 2026-09-16'da koşuldu.

## Yöntem

- Prod'a yalnız salt-okunur erişim: Mgmt API `/database/query`, her sorgu
  `BEGIN TRANSACTION READ ONLY; … ROLLBACK;` sarmalı. **Prod'a ve demo'ya yazma
  yok.** Mgmt API 2026-09-16 00:10–00:45 (GMT 21:15–21:45) arası planlı bakımda
  kapalıydı; beklenip ardından envanter çekildi.
- Kaynak: canlı envanter (45 tablo + kolon/constraint/index/policy/ACL, 13 view,
  233 fonksiyon tanımı `pg_get_functiondef`, 76 trigger `pg_get_triggerdef`,
  surum_gizli şeması). GT'nin el-yazısı bölüm düzeni ve formatı korundu;
  değişiklikler (1) yerinde değiştirme + (2) dosya sonuna tek "SENKRON
  2026-09-15 (G1)" bölümü olarak uygulandı.
- Karşılaştırma aracı: isim-düzeyi `scripts/ground-truth-audit.sh` + ek
  semantik düzey betikler (gövde/yorum/boşluk duyarlılığı ayıklanmış kanonik
  karşılaştırma — yanlış alarm eliminasyonu: 65→42 fonksiyon, sahte
  "eksik/gövde farkı" listeleri temizlendi).

## Audit sayıları (önce / sonra)

| Boyut | Canlı | GT önce | GT sonra | Önce fark | Sonra fark |
|---|---|---|---|---|---|
| Tablo (public) | 45 | 40 | 45 | 5 eksik | **0** |
| View | 13 | 13 | 13 | 0 | **0** |
| Fonksiyon (public) | 213 | 176 | 213 | 37 eksik | **0** |
| Trigger bağlantısı | 76 | 28 | 76 | 48 eksik | **0** (aşağıda) |
| audit betiği toplam | — | — | — | 90 FAIL | 40 (tamamı betik kısıtı, bkz. Bakiye) |

Elle/semantik doğrulama (sonra): fonksiyon gövdeleri 213/213 semantik eş,
view gövdeleri 13/13 semantik eş, trigger **bağlantı** düzeyi 76/76 (isim+tablo+
fonksiyon), surum_gizli 12/12 fonksiyon + 4/4 tablo eş, kolon düzeyi fark 0.

## Eklenen nesneler

**Yeni tablolar (5):** `degisim_log`, `pedigree_meta`, `pedigree_nodes`,
`pedigree_parentage`, `semen_catalog` — kolonlar, isimli
CHECK/UNIQUE/FK/PK kısıtları, non-constraint index'ler, RLS ENABLE, GRANT'lar ve
policy'leriyle (canlıdan; ör. `degisim_log_select`, `allow_all`).

**Yeni fonksiyonlar (37):** `_degisim_log_degistirilemez`, `_degisim_log_yaz`,
`_dogum_buzagi_backfill`, `_guard_dogum_ileri_tarih`,
`_guard_hayvanlar_cinsiyet_grup`, `_guard_tohumlama_yas_cinsiyet`,
`_islem_log_degisim_txid`, `_islem_log_geri_alindi_kapisi`,
`_pedigree_parent_set_core`, `_tohumlama_gorev_uygunluk`,
`_trg_pedigree_hayvan_insert`, `asi_gorev_planla`, `asi_planli_tamamla`,
`asi_toplu_planla`, `assert_is_operator`, `degisim_geri_al`, `degisim_listele`,
`degisim_onizle`, `fn_gorev_asip_iade`, `fn_sperma_stok_dus`,
`geri_alma_bileti_al`, `hayvan_kilo_guncelle`, `ilac_dozaj_guncelle`,
`pedigree_ensure_farm_node`, `pedigree_external_upsert`, `pedigree_farm_backfill`,
`pedigree_integrity_report`, `pedigree_is_ancestor`, `pedigree_parent_set`,
`pedigree_subgraph`, `pedigree_subgraph_for_animal`, `pedigree_try_timestamptz`,
`planli_tohumlama_kaydet`, `sahip_sifresi_ayarla`, `semen_catalog_upsert`,
`tedavi_sablon_tohumlama_gorev_ekle`, `vaka_tohumlama_ekle` — tümü canlı
`pg_get_functiondef` çıktısı.

**Yeni trigger'lar (10 ad, 48 tablo-bağlantısı):** `trg_degisim_log` (41 tabloda),
`trg_degisim_log_immutable`, `trg_degisim_log_no_truncate`, `trg_dogum_guard`,
`trg_gorev_asip_iade`, `trg_hayvanlar_guard`, `trg_islem_log_degisim_txid`,
`trg_islem_log_geri_alindi_kapisi`, `trg_pedigree_hayvan_insert`,
`trg_tohumlama_guard`.

**Kolon eklemeleri (13 tablo, 40 ALTER):** `dogum.buzagi_id`;
`drug_products.std_dose/std_dose_min/std_dose_max/std_dose_unit`;
`drugs.description`; `gorev_log.created_at/ref_tohumlama_id/stok_dusuldu`;
`hastalik_log.created_at/kapanis_tarihi/veteriner_notu`;
`hayvanlar.abort_sayisi/cins/created_at/kesim_kg`;
`islem_log.degisim_txid/ref_tablo`; `kizginlik_log.cozuldu/tedavi_case_id`;
`stok.birim_turu/created_at/drug_product_id/maliyet/notlar/tur`;
`stok_hareket.created_at/referans_id/tarih`;
`tohumlama.abort_tarihi/created_at/deneme_sayisi/denemeler/gerceklesme_at/irk_bilgisi/kontrol_tarihi/tohumlayan`;
`treatment_days.tamamlanma_notu/tamamlanma_tarihi`;
`vaccination_log.erteleme_notu`. (`degisim_log.id` GENERATED ALWAYS AS IDENTITY
olarak aynalandı.)

**Eklenen FK'ler (4):** `dogum_buzagi_id_fkey`, `stok_drug_product_id_fkey`,
`kizginlik_log_tedavi_case_id_fkey`, `drug_administrations_seans_admin_id_fkey`.

**Eklenen index/unique'lar (10):** `dogum_buzagi_id_uidx`, `idx_gorev_log_etken`,
`idx_gorev_log_ref_tohumlama`, `idx_islem_log_degisim_txid`,
`idx_tohumlama_hayvan_sonuc`, `kizginlik_log_cozuldu_idx`,
`uq_gorev_rota_2doz_active`, `uq_hayvanlar_devlet_kupe`, `uq_hayvanlar_kupe_no`,
`hayvanlar_kupe_no_key`.

**Eklenen RLS ENABLE (9):** hayvanlar, gorev_log, hastalik_log, irk_esik,
islem_log, kizginlik_log, stok, stok_hareket, tohumlama.
**Eklenen policy (5):** `degisim_log_select`, `anon_read_drug_products_sel`,
`islem_log_select`, `service_insert`, `anon insert kizginlik_log`.

## Güncellenen nesneler

**Fonksiyon gövdesi tazeleme (42 ad, 46 occurrence — canlı tanımla):**
`_gorev_dinle`, `_islem_log_yaz`, `add_treatment_day_with_sessions`,
`asistan_hayvan_detay`, `besleme_tamam`, `cikis_yap`,
`close_case_with_remaining`, `dogum_kaydet`, `drug_administration_stok_dusum`,
`drug_ekle`, `drug_guncelle`, `fn_dinle_drug_admin`, `fn_dinle_uygulama`,
`fn_dinle_vaccination`, `gebelik_kaydet_manual`, `geri_al`,
`get_vaccination_schedule`, `gorev_guncelle`, `gorev_tamamla`, `hayvan_ekle`,
`hayvan_guncelle`, `hizli_uygulama`, `hizli_uygulama_geri_al`,
`ileri_gebe_asi_tamamla`, `ileri_gebe_gorev_kontrol`, `kategori_ekle`,
`kategori_guncelle`, `kupe_musait_mi`, `padok_degistir_toplu`,
`protokol_eksik_tara`, `seed_defaults`, `stat_suru_ozet`, `tedavi_guncelle`,
`tedavi_sablon_uygula`, `tedavi_sil`, `tohumlama_abort`, `tohumlama_kaydet`,
`tohumlama_sonuc_bekliyor`, `tohumlama_sonuc_gebe`, `tohumlama_tekrar_kaydet`,
`treatment_day_tamamla`, `vaccination_stok_dusum`. (Zarfta adı geçen
`tohumlama_kaydet`, `dogum_kaydet`, `gebelik_kaydet_manual` bu kümede; diğerleri
semantik karşılaştırmada çıktı.)

**View tazeleme (13 view, 15 occurrence — canlı `pg_get_viewdef`):** 9 içerik
farklı: `gebelik_ozet_view`, `hastalik_istatistik_view`, `hayvan_durum_view`,
`hayvan_timeline_view`, `stok_tuketim_view`, `tedavi_view`,
`tohumlanabilir_hayvanlar`, `treatment_timeline`, `v_ureme_dongusu`; 4 yalnız
parantez-biçim farklı (ayna sadakati için yine de canlı metne çekildi):
`cozulmemis_kizginlik_view`, `v_eligible`, `v_gorev_log_sync`, `v_orphan_gorev`.

## surum_gizli kapsamı

Yeni bölüm: `CREATE SCHEMA IF NOT EXISTS surum_gizli` + 4 tablo
(`geri_alma_bileti`, `geri_alma_kullanim` [IDENTITY], `l4_rehber_adimlari`
[IDENTITY], `sahip_sifresi`) + 12 fonksiyon (`_cagiran`, `_degisim_plan`,
`_degisim_uygula`, `_ekle_bagli`, `_guncel_satir`, `_kapsamda`,
`_l4_rehber_uyesi`, `_l4_zaman_txid`, `_l4_zincir`, `_pk_gorunum`, `_pk_json`,
`_pk_kolonlar`) + index'ler. **Yalnız YAPI — satır verisi, şifre hash, bilet
verisi girilmedi.** Identity kaynaklı sequence'lar ayrıca CREATE edilmedi
(çakışma üretir; IDENTITY tanımı üretir).

## Yetki (S1)

GT yetki taşıdığı için (94 `GRANT EXECUTE … TO anon, authenticated` satırı) S1
kuralı gereği yansıtıldı: bölüm sonuna `20260915000001_anon_execute_geri_al.sql`
in genel kalkanları eklendi (`REVOKE ALL ON ALL FUNCTIONS IN SCHEMA public FROM
anon, PUBLIC` + iki `ALTER DEFAULT PRIVILEGES` + `GRANT EXECUTE … TO
authenticated`). Etkin durum canlıyla eş: anon 0 fonksiyon, authenticated tam.
Fonksiyon-tek REVOKE listesi ayrıca migration dosyasında duruyor.

## Bakiye / bilinen kısıtlar

1. **audit betiği kısıtı — kalan 40 "fark":** (a) betik `surum_gizli.tablo`
   biçimli satırlarda şema adını nesne adı sanıyor → "fazla tablo/fn:
   surum_gizli" (2); (b) betiğin dosya-tarafı trigger sözlüğü isim başına tek
   bağlantı tutuyor; `trg_degisim_log` 41 tabloya tek isim olduğundan 38
   bağlantı asla görülemez. İkisi de betik sınırı; bağlantı düzeyi elle
   doğrulama 76/76 = 0 fark. Betik düzeltmesi bu görevin dosya setinde
   (GT + yedek + rapor) olmadığından yapılmadı; raporlanır.
2. **Constraint ad karşılaştırması yöntemsel olarak sınırlı:** GT mevcut
   tablolarda kısıtları çoğunlukla isimsiz inline tanımlar; canlıdaki
   sistem-üretimi adlar (`*_pkey`, `*_fkey`) ile ad-düzeyi eşleşmez. İçerik
   eşlenişi kolon/FK düzeyinde ayrıca doğrulandı (eklenen kolonların FK'leri
   eklendi). Yeni tablolarda kısıt adları birebir taşındı.
3. **Önceden var olan `$` etiketi düzensizliği:** dosyada el-yazısı bölgelerde
   tekil `$$` kalıntısı (orijinalde satır 11307, yenisinde 11869; sayım aynı) —
   bu görevde eklenmedi, GT çalıştırılmadığı için etkisiz.
4. **Yalnız biçim farkı kalan 4 view:** canlı metne çekildi (yukarıda) — artık
   fark yok.
5. Infra nesneleri (tools-bank tablo/fn/index/policy) audit kuralına uyarak
   bilinçli olarak GT dışında tutuldu.

## Dosyalar

- `supabase/migrations/99999999999999_ground_truth.sql` — 11992 → 16346 satır
- `supabase/migrations/backup/99999999999999_ground_truth-PRE-REGEN-2026-09-15.sql` — geri dönüş kopyası
- `reports/2026-09-15-ground-truth-regen.md` — bu rapor

Prod/demo yazma kanıtı: oturumdaki tüm DB erişimleri Mgmt API SELECT'leri,
`BEGIN TRANSACTION READ ONLY … ROLLBACK;` sarmalı. Yardımcı betikler ve canlı
envanter kopyaları makine-geçici dizinde (`~/tmp/g1/`), repoda değil.
