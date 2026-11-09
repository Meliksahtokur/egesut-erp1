# DM1 adım 4 — anon / authenticated EXECUTE ölçümü (demo vtzqjmazsvurxdeondmi, seri 001..008 uygulandıktan sonra)

- Ölçüm: 2026-11-09T16:20:15Z, Management API read_only SELECT; sorgu: `has_function_privilege('<rol>', p.oid, 'EXECUTE')`, seride CREATE edilen 40 adın public şemadaki TÜM overload'ları (eski imza kalmadı: 40 ad → 40 satır).
- Beklenen: anon = false (hepsi); authenticated = migration metnindeki son GRANT/REVOKE durumu (dışa açık RPC true, iç yardımcı false). Kaynak: seri dosyalarının GRANT/REVOKE satırları (ayrıştırıcı ~/tmp/dm1, MEASURED).
- Sonuç: **40/40 OK, sapma 0** (MEASURED). `_vaka_ac_tek` uygulama öncesi demo'da authenticated=X idi; seri bilerek kapattı (D4-review-report: js/'de doğrudan çağrı yok, çağıranlar SECURITY DEFINER).

| # | imza (canlı regprocedure) | tür | anon EXECUTE | authenticated EXECUTE | beklenen anon/auth | sonuç |
|---|---|---|---|---|---|---|
| 1 | `_acik_disi_gorev_kur(text,boolean)` | iç yardımcı | false | false | false/false | OK |
| 2 | `_acik_disi_hedef_ic(text)` | iç yardımcı | false | false | false/false | OK |
| 3 | `_ovsync_asama(uuid)` | iç yardımcı | false | false | false/false | OK |
| 4 | `_ovsync_baslat_gorev_kur(text,date,text,date,boolean)` | iç yardımcı | false | false | false/false | OK |
| 5 | `_ovsync_gorev_mu(uuid)` | iç yardımcı | false | false | false/false | OK |
| 6 | `_ovsync_ic_ac()` | iç yardımcı | false | false | false/false | OK |
| 7 | `_ovsync_ic_mi()` | iç yardımcı | false | false | false/false | OK |
| 8 | `_ovsync_kilit_gorev(uuid)` | iç yardımcı | false | false | false/false | OK |
| 9 | `_ovsync_kilit_vaka(uuid)` | iç yardımcı | false | false | false/false | OK |
| 10 | `_ovsync_pg1_kayma(uuid)` | iç yardımcı | false | false | false/false | OK |
| 11 | `_ovsync_tren_aktif()` | iç yardımcı | false | false | false/false | OK |
| 12 | `_ovsync_tren_ayar()` | iç yardımcı | false | false | false/false | OK |
| 13 | `_ovsync_tren_ertele_plan(date,integer)` | iç yardımcı | false | false | false/false | OK |
| 14 | `_ovsync_tren_gunu_ic(date,date,integer,date)` | iç yardımcı | false | false | false/false | OK |
| 15 | `_ovsync_tren_gunu_mu(date)` | iç yardımcı | false | false | false/false | OK |
| 16 | `_ovsync_tren_gunu(date)` | iç yardımcı | false | false | false/false | OK |
| 17 | `_ovsync_tren_uye_vaka(uuid,integer)` | iç yardımcı | false | false | false/false | OK |
| 18 | `_vaka_ac_tek(text,uuid,text,date)` | iç yardımcı | false | false | false/false | OK |
| 19 | `dogum_kaydet(text,date,text,text,text,numeric,text,text)` | dışa açık RPC | false | true | false/true | OK |
| 20 | `dogum_sonrasi_pg_hatirlatma()` | dışa açık RPC | false | true | false/true | OK |
| 21 | `gorev_ertele(uuid,date,time without time zone)` | dışa açık RPC | false | true | false/true | OK |
| 22 | `ovsync_baslat_uyarilari()` | dışa açık RPC | false | true | false/true | OK |
| 23 | `ovsync_bastan_baslat(uuid,boolean,text,date)` | dışa açık RPC | false | true | false/true | OK |
| 24 | `ovsync_hastalik_gunu_ekle(uuid,uuid,date,integer,jsonb,boolean,text)` | dışa açık RPC | false | true | false/true | OK |
| 25 | `ovsync_hayvan_ertele(text,integer)` | dışa açık RPC | false | true | false/true | OK |
| 26 | `ovsync_pg48_tohumla(uuid)` | dışa açık RPC | false | true | false/true | OK |
| 27 | `ovsync_tren_ayar_guncelle(boolean,date)` | dışa açık RPC | false | true | false/true | OK |
| 28 | `ovsync_tren_ertele_onizle(date,integer)` | dışa açık RPC | false | true | false/true | OK |
| 29 | `ovsync_tren_ertele(date,integer,jsonb)` | dışa açık RPC | false | true | false/true | OK |
| 30 | `ovsync_tren_listele()` | dışa açık RPC | false | true | false/true | OK |
| 31 | `ovsync_tren_onizle(text)` | dışa açık RPC | false | true | false/true | OK |
| 32 | `ovsync_tren_yeniden_hedefle(boolean,date)` | dışa açık RPC | false | true | false/true | OK |
| 33 | `protokol_iptal(uuid,boolean,text)` | dışa açık RPC | false | true | false/true | OK |
| 34 | `seans_tamamla(uuid,boolean,text,boolean,text,boolean)` | dışa açık RPC | false | true | false/true | OK |
| 35 | `start_first_service_protocol(uuid,boolean,boolean)` | dışa açık RPC | false | true | false/true | OK |
| 36 | `tedavi_sablon_uygula(uuid,uuid,date,boolean,text)` | dışa açık RPC | false | true | false/true | OK |
| 37 | `tohumlama_bos_ve_devam(text,uuid,text,text,numeric,integer,time without time zone,text,boolean)` | dışa açık RPC | false | true | false/true | OK |
| 38 | `tohumlama_gorev_ertele(uuid,date,time without time zone)` | dışa açık RPC | false | true | false/true | OK |
| 39 | `vaka_kalan_gunleri_kaydir_coklu(uuid[],integer)` | dışa açık RPC | false | true | false/true | OK |
| 40 | `vaka_kalan_gunleri_kaydir(uuid,integer)` | dışa açık RPC | false | true | false/true | OK |
