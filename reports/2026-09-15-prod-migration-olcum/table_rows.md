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
