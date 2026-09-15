# P1 — Prod migration ölçümü — WIP (dondurma noktası)

> ## DEVAM NOTU — sahip dondurma emri (2026-09-15, ~09:03; iş 13:00'e kadar donduruldu)
>
> **Kaldığım adım:** 36 dosyanın nesne envanteri ve prod+demo canlı şema ölçümü TAMAM.
> Karşılaştırıcı (verdict.py) yerel olarak koştu; aşağıdaki tablo o sonucun WIP hali.
> Yeni prod sorgusu BAŞLATMADIM (emir); ölçüm için gereken tüm ham veri zaten
> `probe_prod.json` / `probe_demo.json` içinde — kalan iş onları yerel olarak çözümlemek.
>
> **Kalan iş (root 'devam' deyince):**
> 1. Prod'da gövdesi dosyayla eşleşmeyen fonksiyonların **hangi eski sürümün** prod'da
>    olduğunu saptamak: `verdict.py` içindeki `fn_versions` şu an yalnız 36 dosyayı
>    tarıyor; 20260830 öncesi migration'ları da taratıp prod gövdesini o sürümlerle
>    eşleştir (etkilenenler: `_guard_tohumlama_yas_cinsiyet`, `tohumlama_kaydet`,
>    `gebelik_kaydet_manual`, `tohumlama_tekrar_kaydet`, `fn_sperma_stok_dus`).
> 2. Demo'da 36 dosyada olmayan gövde sürümlerinin kaynağını saptamak
>    (`tohumlama_kaydet` md5 57c69264f4, `protokol_eksik_tara` md5 956bbd2f52 —
>    demo'da branch-dışı hotfix olabilir; hangi sürüm olduğunu tüm migration geçmişiyle
>    eşleştirerek söyle).
> 3. İki demo grant teyidi: `pedigree_subgraph`→authenticated EXECUTE ve
>    `sahip_sifresi_ayarla`→service_role EXECUTE neden FAIL göründü (probe_demo.json
>    routine_grants satırlarından elle doğrula — yeni sorgu gerekmez).
> 4. DML'li dosyalar için veri spot-probe'ları (bunlar YENİ salt-okunur sorgu gerektirir):
>    `20260902000001` (STOK-AŞI satırları + vaccines.stock_item_id), `20260909100000`
>    (std_dose dolu satır sayısı), `20260911000001` (buzagi_id dolu satır),
>    `20260911000003` (pedigree_nodes satır sayısı), `20260830000010/34` (abort_tarihi
>    backfill), `20260906000001` (postpartum gorev_log), `20260901000001` (dogum.olay_id
>    backfill).
> 5. "Prod'a uygulanacak sıralı liste", "riskler" ve "yedek planı" bölümlerini yaz; raporu
>    finalize et, `P1 teslim` commit'ini at.
>
> **Yöntem notu:** Tüm canlı sorgular `BEGIN READ ONLY; SELECT ...; ROLLBACK;` zarfında,
> Mgmt API üzerinden (kanıt: `queries.sql`). Token değerleri hiçbir çıktıya yazılmadı.
> Ayrıntılı süreç: alttaki ölçüm yöntemi bölümü.

## Özet (WIP)

| DB | CANLI | KISMİ | EKSİK | N/A (salt-DML) |
|---|---|---|---|---|
| **prod** | 17 | 16 | 2 | 1 |
| **demo** | 30 | 5 | 0 | 1 |

- Prod'un Ağustos-30 paketi (20260830000010–20260831000003) büyük ölçüde CANLI;
  **20260909100000 (dozaj seed) ve sonrası prod'da YOK** (EKSİK/KISMİ).
- L2 (20260913000001–03) ve L4 (20260914*) prod'da tamamen yok; demo'da CANLI.
- Beklenmedik bulgu: **demo'da bile** 20260913000001 (L2-F1) KISMİ — 39 tabloya
  `trg_degisim_log` trigger'ının bazı tablolarda eksik olması olası (ayrıntı devam işinde).

## Dosya × prod × demo durumu (WIP — kanıt kolonu kısaltılmış)

| Dosya | Prod | Demo | Eksik/farklı (kısa) |
|---|---|---|---|
| `20260830000010_abort_vwp_penceresi.sql` | CANLI | KISMİ | D: `public.tohumlama_kaydet(text,date,text,text,text,jsonb,boolean)` MISMATCH |
| `20260830000020_sessiz_vaka_filtresi_kaldir.sql` | CANLI | CANLI | — |
| `20260830000030_cift_abort_log_fix.sql` | CANLI | CANLI | — |
| `20260830000031_gebe_sonuc_mesaji.sql` | CANLI | CANLI | — |
| `20260830000032_geri_al_uuid_fallback.sql` | CANLI | CANLI | — |
| `20260830000033_geri_al_hardening.sql` | CANLI | CANLI | — |
| `20260830000034_review_fix_paketi.sql` | CANLI | KISMİ | D: `public.tohumlama_kaydet(text,date,text,text,text,jsonb,boolean)` MISMATCH |
| `20260831000001_sessiz_ankra_fixi.sql` | CANLI | CANLI | — |
| `20260831000002_duve_sessiz_13ay.sql` | CANLI | CANLI | — |
| `20260831000003_tablo_guard_triggerlari.sql` | KISMİ | CANLI | P: `public._guard_tohumlama_yas_cinsiyet()` MISMATCH |
| `20260901000001_ikiz_dogum_olay_id.sql` | CANLI | CANLI | — |
| `20260901000002_kupe_revizyon.sql` | CANLI | CANLI | — |
| `20260902000001_asi_stok_backfill.sql` | N/A | N/A | — |
| `20260902000002_asi_stok_serbest_dusum.sql` | CANLI | CANLI | — |
| `20260902000003_asi_planli_gorev.sql` | CANLI | CANLI | — |
| `20260902000004_asi_toplu_gorev.sql` | CANLI | CANLI | — |
| `20260906000001_postpartum_d53_e_vitamin_tek.sql` | CANLI | KISMİ | D: `public.protokol_eksik_tara()` MISMATCH |
| `20260906120000_vaka_toplu_ac.sql` | CANLI | CANLI | — |
| `20260909000001_sablon_aktif_vakaya_uygula.sql` | CANLI | CANLI | — |
| `20260909100000_dozaj_std_dose_seed.sql` | EKSİK | CANLI | P: `drug_products.std_dose` MISSING; P: `drug_products.std_dose_unit` MISSING; P: `drug_products_std_dose_unit_check` MISSING |
| `20260909110000_dozaj_helper_min_max_rpc.sql` | KISMİ | CANLI | P: `public.ilac_dozaj_guncelle(uuid,jsonb)` MISSING; P: `public.hayvan_kilo_guncelle(text,numeric)` MISSING; P: `drug_products.std_dose_min` MISSING |
| `20260910000001_planli_tohumlama_sperma_dus.sql` | KISMİ | CANLI | P: `public.fn_sperma_stok_dus(text,text)` MISSING |
| `20260910000002_sperma_eslesme_sertlestirme.sql` | KISMİ | KISMİ | P: `public.tohumlama_tekrar_kaydet(text,date,text,text,text)` MISMATCH; D: `public.tohumlama_kaydet(text,date,text,text,text,jsonb,boolean)` MISMATCH |
| `20260910000003_gebelik_kaydet_manual_42804_fix.sql` | KISMİ | CANLI | P: `public.gebelik_kaydet_manual(text,date,text)` MISMATCH |
| `20260911000001_dogum_buzagi_id_foundation.sql` | KISMİ | CANLI | P: `public._dogum_buzagi_backfill()` MISSING; P: `dogum.buzagi_id` MISSING; P: `dogum_buzagi_id_uidx` MISSING |
| `20260911000002_pedigree_foundation.sql` | KISMİ | CANLI | P: `public.assert_is_operator()` MISSING; P: `public.pedigree_ensure_farm_node(text)` MISSING; P: `public.pedigree_is_ancestor(uuid,uuid)` MISSING |
| `20260911000003_pedigree_farm_backfill.sql` | KISMİ | CANLI | P: `public.pedigree_try_timestamptz(text)` MISSING; P: `public.pedigree_farm_backfill()` MISSING; P: `public.pedigree_integrity_report()` MISSING |
| `20260911000004_pedigree_projection_rpc.sql` | KISMİ | CANLI | P: `public.pedigree_subgraph(uuid,integer,integer)` MISSING; P: `public.pedigree_subgraph_for_animal(text,integer,integer)` MISSING; P: `EXECUTE ON public.pedigree_subgraph(uuid, integer, integer) TO a` FAIL |
| `20260913000001_surum_gecmisi_f1_degisim_log.sql` | KISMİ | KISMİ | P: `public._degisim_log_degistirilemez()` MISSING; P: `public._degisim_log_yaz()` MISSING; P: `degisim_log` MISSING |
| `20260913000002_surum_gecmisi_f2_geri_alma.sql` | KISMİ | CANLI | P: `surum_gizli._cagiran()` MISSING; P: `surum_gizli._kapsamda(text)` MISSING; P: `surum_gizli._pk_kolonlar(text)` MISSING |
| `20260913000003_surum_gecmisi_f2_sahip_sifresi.sql` | KISMİ | CANLI | P: `public.sahip_sifresi_ayarla(text)` MISSING; P: `EXECUTE ON public.sahip_sifresi_ayarla(text) TO service_role;` FAIL |
| `20260913000004_luna_bilet_maske.sql` | EKSİK | CANLI | P: `public._degisim_log_yaz()` MISSING |
| `20260914000001_l4_islem_log_kopru.sql` | KISMİ | CANLI | P: `public._islem_log_degisim_txid()` MISSING; P: `islem_log.degisim_txid` MISSING; P: `trg_islem_log_degisim_txid ON islem_log` MISSING |
| `20260914000002_l4_geri_alma_zincir.sql` | KISMİ | CANLI | P: `surum_gizli._l4_zaman_txid(text,jsonb,text,bigint,text,timestamp` MISSING; P: `surum_gizli._degisim_plan(jsonb,text)` MISSING; P: `surum_gizli._l4_zincir(jsonb)` MISSING |
| `20260914000003_l4_onarim.sql` | KISMİ | CANLI | P: `public._islem_log_degisim_txid()` MISSING; P: `public._islem_log_geri_alindi_kapisi()` MISSING; P: `surum_gizli._l4_rehber_uyesi(jsonb)` MISSING |
| `20260914000004_l4_stok_uyari_txid.sql` | KISMİ | CANLI | P: `surum_gizli._degisim_plan(jsonb,text)` MISSING; P: `surum_gizli._l4_zincir(jsonb)` MISSING |

## Demo'da KISMİ görünen dosyaların maddeleri (WIP — teyit devam işi)

- `20260830000010_abort_vwp_penceresi.sql`: public.tohumlama_kaydet(text,date,text,text,text,jsonb,boolean): MISMATCH (gövde hiçbir dosya sürümüyle eşleşmedi (md5 57c69264f4; son tanım 20260910000002_sperma_es)
- `20260830000034_review_fix_paketi.sql`: public.tohumlama_kaydet(text,date,text,text,text,jsonb,boolean): MISMATCH (gövde hiçbir dosya sürümüyle eşleşmedi (md5 57c69264f4; son tanım 20260910000002_sperma_es)
- `20260906000001_postpartum_d53_e_vitamin_tek.sql`: public.protokol_eksik_tara(): MISMATCH (gövde hiçbir dosya sürümüyle eşleşmedi (md5 956bbd2f52; son tanım 20260906000001_postpartu)
- `20260910000002_sperma_eslesme_sertlestirme.sql`: public.tohumlama_kaydet(text,date,text,text,text,jsonb,boolean): MISMATCH (gövde hiçbir dosya sürümüyle eşleşmedi (md5 57c69264f4; son tanım 20260910000002_sperma_es)
- `20260913000001_surum_gecmisi_f1_degisim_log.sql`: REVOKE ALL ON public.degisim_log TO PUBLIC, anon, authenticated;: FAIL (public:OK-yok, anon:OK-yok, authenticated:HÂLÂ VAR:SELECT)

## Ölçüm yöntemi

1. `parse_migrations.py` — 36 dosyadan nesne envanteri (`inventory.json`): fonksiyon
   tanımları, tablo/kolon/trigger/policy/index/constraint/grant/RLS/DML. Dinamik SQL
   (DO-blok EXECUTE format ile 39 tabloya `trg_degisim_log`, koşullu buzagi_id ALTER'ı,
   DO içindeki `tohumlama_kaydet`) dosyalar elle okunarak override eklendi.
2. `probe.py` — canlı katalog sorguları (fonksiyon tanımları `pg_get_functiondef`,
   kolonlar, trigger'lar, policy'ler, index'ler, constraint'ler, tablo/routine ACL'leri,
   view'lar, şema/extension), prod ve demo'ya karşı. Her istek
   `BEGIN READ ONLY; SELECT ...; ROLLBACK;` zarfında. Ham çıktılar: `probe_prod.json`,
   `probe_demo.json`; sorgu metinleri: `queries.sql`.
3. `verdict.py` — envanter × canlı karşılaştırma. Fonksiyon için: imza eşleşmesi
   (tip normalizasyonu ile) + gövde karşılaştırması (whitespace-collapse sonra md5).
   "Son tanım kuralı": aynı fonksiyonun 36 dosya içindeki son tanımı esas; prod hangi
   sürümdeyse kanıtta belirtilir. Grant'lerde sonraki dosyanın REVOKE/GRANT'i
   geçersiz kıldığı maddeler ARA-DURUM'a alınır (final-state ile karışmasın).
   Sonuç: `verdicts.json`.

## WIP'te bilinen sınırlar

- Prod/demo KISMİ satırlarındaki MISMATCH maddeleri "dosyadaki hiçbir sürümle
  eşleşmiyor" demek; prod'daki gerçek sürümün hangi eski migration olduğunun
  saptanması devam işinin 1. maddesi.
- `20260902000001_asi_stok_backfill.sql` nesne yaratmaz (salt DML) → N/A; veri düzeyi
  doğrulama yeni sorgu gerektirdiğinden dondurmaya kadar bekletiliyor.
- Demo'da 20260913000001 KISMİ kök nedeni henüz açıklanmadı (maddeler yukarıda).

## Etikler

- Prod'a karşı toplam 2×11 sorgu bloğu (prod+demo), tümü salt-okunur; DDL/DML/GRANT yok.
- Ham çıktılar bu dizinde: `probe_prod.json`, `probe_demo.json`, `queries.sql`,
  `inventory.json`, `inventory_flat.txt`, `verdicts.json`, script'ler.
- Token değerleri bu rapora ve ham çıktılara yazılmadı (yalnız .env dosya adları).
