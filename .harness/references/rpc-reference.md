# RPC Quick Reference (harness reference)

> **Provenance:** curated 2026-09-03 for the harness from
> `.claude/rpc-reference.md` (regenerated 2026-09-01 from the PROD live-schema
> signature snapshot `.claude/schema-snapshots/2026-08-31-live-schema-imzalar.md`,
> call sites grepped from code) including its pending 2026-09-02 working-copy
> additions (asi_toplu_planla). A tracked reference is never live-schema
> truth: signatures must be verified against the separately authorized
> live-schema probe before DB work. The Phase 4 audit notes at the end of this
> file record the wrapper-stack and call-site findings measured on
> 2026-09-03.

> imza düzeyi. Dosya başlığı "195 giriş" der; fiziksel imza satırı **189**, benzersiz ad **185**
> (fark raporda not edildi). Çağrı yerleri `idle/docs-hatti` worktree kodundan grep (2026-09-01).
> Gövde niyeti için: `supabase/migrations/` (kanonik sırada son kazanan) — GT (ground_truth) bazı
> imzalarda canlıdan ESKİDİR, bkz `.claude/schema-snapshots/2026-09-01-gt-v5-audit.md`.

## Çağrı Kontratı (D1/D2 notları)

- **DB düzeyi:** yazma RPC'leri `SECURITY DEFINER` + `jsonb` döner: `{ ok: boolean, mesaj?, ... }`.
  `ok:false` gövdesi iş hatasıdır (oneri/detay gibi ek alanlar taşabilir).
- **D2 — `rpc()` sarmalayıcısı (api.js:66):** `ok:false`'ı **asla döndürmez** → `Error` fırlatır;
  gövde `err.data`'ya taşınır (api.js:86-89). Dolayısıyla `rpc()` sonrası `if (!res.ok)` desenleri
  ölü koddur. `rpcOptimistic` (api.js:457) aynı kontrat + toast/pull sarmalayıcıdır.
- **D1 — yazma yolları:** online yazma RPC iledir; **offline kuyruk replay**'i ikiye ayrılır:
  otomatik `syncNow` (api.js:497) `db.from` PATCH/POST kullanır (`dbUpdate` api.js:203 / `dbInsert`
  api.js:220), manuel "Gönder" replay'i (ui.js:6789 `buildRpcParams`) RPC kullanır.
  NOT (review düzeltmesi 2026-09-01): docs-tutarlilik §1.6'daki replay imza sapmaları (`p_grup_id`,
  `p_hayvan_id` vb.) commit `202df1f` ile DÜZELTİLDİ — buildRpcParams artık canlı imzalarla yazıldı
  ve tests/unit/buildRpcParams.test.js ile kilitli; bu sapmalar artık bug değil, tarihsel kayıttır.
- `?` işareti parametrenin DEFAULT'lu/opsiyonel olduğunu gösterir (snapshot imza düzeyi DEFAULT
  değeri göstermez; DEFAULT için migrations/GT'e bak).

---

## Hayvan Yönetimi

**`hayvan_ekle(p_kupe_no?, p_devlet_kupe?, p_irk?, p_cinsiyet?, p_dogum_tarihi?, p_grup?, p_padok?, p_dogum_kg?, p_anne_id?, p_baba_bilgi?, p_canli_agirlik?, p_boy?, p_renk?, p_ayirici_ozellik?)`** → jsonb
→ Yeni hayvan kaydı; otomatik ID (text). Çağrı: forms.js:128 (p_padok_id'li overload'a yönelir).

**`hayvan_ekle(…14 aynı alan…, p_padok_id uuid?)`** → jsonb *(overload 2 — C1 düzeltmesi)*
→ Padok ID ile ekleme. Çağrı: forms.js:123-128 `p_padok_id` iletir; GT:7124.
→ **2026-09-01 küpe revizyonu:** gövde başında `kupe_musait_mi(p_kupe_no, p_devlet_kupe)` kontrolü var
(migration 20260901000002) — aktif çakışma/devlet çakışması → `ok:false`.

**`hayvan_guncelle(p_id, p_kupe_no?, p_devlet_kupe?, p_irk?, p_cinsiyet?, p_dogum_tarihi?, p_grup?, p_padok?, p_dogum_kg?, p_canli_agirlik?, p_boy?, p_renk?, p_ayirici_ozellik?)`** → jsonb
→ Temel güncelleme (14 param).

**`hayvan_guncelle(…13 aynı… + p_baba_bilgi?, p_notlar?, p_anne_id?, p_padok_id uuid?)`** → jsonb *(overload 2 — C2)*
→ forms.js:90,94 `p_padok_id` iletir; GT:8218.

**`hayvan_guncelle(…18 aynı… + p_kisir boolean?)`** → jsonb *(overload 3 — C2)*
→ Kısırlık işareti dahil geniş güncelleme; forms.js:99 `p_kisir` iletir.
→ **2026-09-01 küpe revizyonu:** küpe/devlet değişiyorsa `kupe_musait_mi(p_kupe_no, p_devlet_kupe, p_id)`
kontrolü (kendi kaydı hariç, migration 20260901000002).

**`hayvan_kisir_isaretle(p_hayvan_id, p_kisir)`** → jsonb
→ Kısırlık bayrağı. Çağrı: js'te yok — `hayvan_guncelle` overload 3 üzerinden kullanılıyor (RPC olarak kullanılmıyor, DB'de duruyor).

**`hayvan_not_ekle(p_hayvan_id, p_not)`** → jsonb
→ forms.js:658.

**`hayvan_genc_anne_isaretle(p_hayvan_id, p_genc_anne boolean)`** → jsonb
→ forms.js:115.

**`hayvan_genc_anne_isaretle_toplu(p_ids text[], p_genc_anne boolean)`** → jsonb
→ ui.js:1032 (belirsiz üreme ekranı).

**`hayvan_belirsiz_ureme_listele()`** → TABLE(hayvan_id, kupe_no, grup, padok, dogum_sayisi, tohumlama_sayisi, son_tohumlama)
→ ui.js:976, 1036 (belirsiz üreme listesi/modal).

**`cikis_yap(p_hayvan_id, p_cikis_tipi, p_cikis_tarihi?, p_cikis_sebebi?, p_satis_fiyati?)`** → jsonb
→ Çıkış kaydı; durum değerleri: Ölü/Satıldı/Kesildi/Kayıp ('Pasif' DEĞİL — domain-rules §10).
Çağrı: forms.js:704.

**`kupe_musait_mi(p_kupe_no?, p_devlet_kupe?, p_hayvan_id?)`** → jsonb
→ Küpe çakışma kontrolü. Çağrı: forms.js `_kupeKontrolEt` (a-kupe/a-devlet **ve b-kupe** blur).
→ **2026-09-01 küpe revizyonu (migration 20260901000002):** işletme küpesi kontrolü yalnız
`durum='Aktif'` hayvanlarda (recycle K1); devlet küpesi GLOBAL (TURKVET, K2). Dönüşe yeni alanlar:
`kupe_gecmis_id` + `kupe_gecmis_durum` (numara çıkmış hayvanda kullanılmışsa bilgi amaçlı — engel değil).
DB savunma katmanı: partial unique index **`hayvanlar_kupe_no_key`** (`hayvanlar(kupe_no) WHERE durum='Aktif' AND kupe_no IS NOT NULL AND kupe_no <> ''` — string-bazlı, "002"≠"02").

**`padok_degistir(p_hayvan_id, p_yeni_padok_id uuid, p_not?)`** → jsonb
→ Tekli padok transferi (görev uzlaştırması trigger ile). Çağrı: ui.js:7811.

**`padok_degistir_toplu(p_hayvan_ids text[], p_yeni_padok_id uuid, p_etiketler text[], p_yeni_grup?)`** → jsonb
→ Toplu transfer. Çağrı: ui.js:7654, 7670, 7684, 7819.

---

## Üreme & Tohumlama

**`tohumlama_kaydet(p_hayvan_id, p_tarih, p_sperma, p_hekim_id?, p_irk_bilgisi?, p_ek_uygulamalar jsonb?, p_vwp_override boolean?)`** → jsonb
→ Tohumlama kaydı; state machine: Bekliyor → Gebe/Boş.
→ **VWP kapısı (2026-08-30):** `GREATEST(son_dogum, son_abort)` 55 gün dolmadan
  `VWP_VIOLATION:gun:55` / `ABORT_VWP_VIOLATION:gun:55` RAISE; frontend confirm → `p_vwp_override=true`
  (forms.js submitInsem; ABORT dalı regex alt-dize tuzağı yüzünden ÖNCE test edilir).
→ Yaş ≥365g + erkek engeli + aktif gebelik engeli + ileri tarih engeli RPC'de.
→ Çağrı: forms.js:295 (ternary); offline replay: ui.js:6789.

**`planli_tohumlama_kaydet(p_gorev_id uuid, p_hayvan_id, p_tarih, p_sperma, p_hekim_id?, p_irk_bilgisi?, p_ek_uygulamalar jsonb?, p_vwp_override?)`** → jsonb
→ Planlı tohumlama görevinden kayıt (görev kapanır). Çağrı: forms.js:295 (aynı ternary).
→ **GT'de YOK** (canlıda var — audit tablosu).

**`tohumlama_tekrar_kaydet(p_hayvan_id, p_tarih, p_sperma, p_hekim_id?, p_irk_bilgisi?)`** → jsonb
→ Tekrar tohumlama. Çağrı: forms.js:379; replay: ui.js:6789.

**`tohumlama_sonuc_gebe(p_tohumlama_id)`** → jsonb
→ Sonuç Gebe; hayvan durumu Gebe. Abort edilmiş kayıtta `{ok:false, mesaj:'Bu tohumlama kaydı abort edildi — tekrar gebe işaretlenemez. Yeni bir tohumlama kaydı girin.'}` (20260830000031). Çağrı: ui.js:2768, 6579.

**`tohumlama_sonuc_bos(p_tohumlama_id)`** → jsonb
→ Sonuç Boş. Çağrı: forms.js:1271.

**`tohumlama_sonuc_bekliyor(p_tohumlama_id)`** → jsonb
→ Hatalı kayıt düzeltme → Bekliyor. Çağrı: forms.js:1275.

**`tohumlama_abort(p_tohumlama_id, p_notlar?, p_abort_tarihi date?)`** → jsonb *(canlı ana imza — 3 param)*
→ Abort kaydı; `abort_tarihi` (default bugün, geriye dönük girilebilir) VWP çapasıdır.
  islem_log'a TEK `ABORT_KAYDI` yazar (trigger UPDATE kolu sessizleştirildi, 20260830000030).
  Snapshot `onceki.abort_tarihi` içerir → `geri_al` undo çalışır. Çağrı: forms.js:638.

**`tohumlama_abort(p_tohumlama_id, p_notlar?)`** → jsonb *(eski 2-param overload canlıda duruyor — GT'deki tek imza bu)*

**`abort_kaydet(p_tohumlama_id, p_notlar?)`** → jsonb
→ **Legacy** — frontend kullanmaz (forms.js:612 `abortKaydet` fonksiyonu `tohumlama_abort` RPC'sini çağırır).

**`tohumlama_geri_al(p_tohumlama_id)`** → jsonb
→ Tohumlama kaydını SİLER (abort geri-alma değil!). Çağrı: forms.js:1323; replay: ui.js:6789.

**`gebelik_kaydet_manual(p_hayvan_id, p_tarih, p_sperma?)`** → jsonb
→ Manuel gebelik kaydı (tohumlamasız). Çağrı: forms.js:1473.

**`gebelik_protokol_kontrol()`** → jsonb
→ Gebelik kontrol görevi üreticisi (21/35. gün); eşikler `_ayar()`'dan. Çağrı: app.js:621, ui.js:163.

**`ileri_gebe_gorev_kontrol()`** → jsonb
→ İleri gebe aşı görevleri (d39 Evit vb.). Çağrı: js'te yok — cron/bakım (dashboard dolaylı).

**`ileri_gebe_asi_tamamla(p_gorev_id, p_vaccine_id uuid, p_tarih, p_doz?)`** → jsonb
→ İleri gebe aşısı görev tamamla. Çağrı: ui.js:4945.

**`asi_gorev_planla(p_hayvan_id, p_vaccine_id uuid, p_doz numeric, p_tarih, p_aciklama?)`** → jsonb
→ Planlı aşı görevi yaratır (ASI_PLANLI, stok_id+miktar dolu) ve stok rezerve eder
  (stok_hareket, referans_tipi='asi_plan'). 20260902000003. Çağrı: forms.js submitTaskAdd.

**`asi_toplu_planla(p_hayvan_id, p_tarih, p_items jsonb, p_aciklama?)`** → jsonb
→ Toplu planlı aşı: 1 parent ASI_PLANLI + her aşıya alt görev + rezervasyonlar (atomik).
  Aynı hayvan+aşı+gün açık görevi varsa DUPLICATE döner. 20260902000004. Çağrı: forms.js submitTaskAdd.
  (asi_gorev_planla da DUPLICATE koruması içerir.)

**`asi_planli_tamamla(p_gorev_id, p_tarih, p_doz?, p_vaccine_id?)`** → jsonb
→ Planlı görevi tamamlar: add_vaccination (sonra GorevID notu yazılır — gorev_geri_al uyumu,
  rapel kararı etkilenmez) → rezervasyon flip (iptal=true) → görev kapanır. Tek net düşüm.
  Çağrı: ui.js asiUygulaVeTamamla (ASI_PLANLI dalı).

**`fn_gorev_asip_iade()`** — trigger fn (trg_gorev_asip_iade, gorev_log.iptal TRUE geçişi)
→ Planlı görev iptalinde 'asi_plan' rezervasyonunu iade eder (iptal=true flip). 20260902000003.
Not: gorev_tamamla ASI_PLANLI görevlerde stok yazmaz (muafiyet koşulu) — çift düşüm kilidi.

**`vaka_tohumlama_ekle(p_case_id uuid, p_tarih, p_saat time?)`** → jsonb
→ Vakaya planlı tohumlama günü ekle. Çağrı: ui.js:5718. **GT'de YOK** (audit).

**`hayvan_tohumlanabilir_onayla(p_hayvan_id)`** → jsonb
→ forms.js:858.

**`hayvan_tohumlama_ertele(p_hayvan_id, p_ay integer)`** → jsonb
→ forms.js:871.

---

## Doğum

**`dogum_kaydet(p_anne_id, p_tarih, p_kupe, p_cins?, p_tip?, p_kg?, p_baba?, p_hekim_id?)`** → jsonb
→ Doğum + buzağı kaydı + **ikiz olay modeli** (olay_id, 10g pencere, 60g anne guard; 2026-09-01 ikiz deploy). Görev sayısı: anne yan-etki 10 + buzağı 7 = 17 (yakın doğum varsa anne ayağı atlanır → 7).
→ İleri tarih kontrolü frontend'de (forms.js:155); **backend'de yok** (2026-08-31 guard'ı `hayvanlar`/`tohumlama` tablolarında, `dogum_kaydet` RPC'sinde değil — rapor notu).
→ **2026-09-01 küpe revizyonu (migration 20260901000002):** (1) dup check işletme küpesinde yalnız
`durum='Aktif'` filtreli (recycle K1; devlet küpesi GLOBAL kalır), (2) erkek buzağı + sayısal küpe
500-599 dışı → `ok:false` red (K5 sunucu kuralı; JS tarafı `submitBirth` de sert engeller).
→ Çağrı: forms.js:177; replay: ui.js:6738, 6862.

---

## Kızgınlık

**`kizginlik_kaydet(p_hayvan_id, p_tarih, p_belirti?, p_notlar?)`** → jsonb
→ forms.js:432; replay: ui.js:6789.

**`kizginlik_sil(p_kayit_id)`** → jsonb
→ ui.js:342; replay: ui.js:6789.

**`kizginlik_vaka_ac(p_kizginlik_id, p_tani?, p_tohumlama_id?, p_notlar?)`** → jsonb
→ Kızgınlık kaydından vaka aç (sorun bottom-sheet). Çağrı: ui.js:2635.

**`kizginlik_yok_kaydet(p_hayvan_id, p_dogum_id?, p_notlar?)`** → jsonb
→ "Kızgınlık yok" gözlemi (cozulmemis_kizginlik kapatma). Çağrı: ui.js:320.

**`kizginlik_tedavi_baglanti_kur(p_kayit_id, p_case_id uuid)`** → jsonb
→ forms.js:593.

---

## Görev Sistemi (gorev_log)

**`gorev_tamamla(p_gorev_id, p_padok_hedef?)`** → jsonb
→ Görevi tamamlar; SUTTEN_KESME tipinde `buzagi_sutten_kesme_onayla`'yı çağırır (her kaynaktan kesim garantisi).
→ Çağrı: forms.js:1047; ui.js:468, 4855, 4920; replay: ui.js:6789.

**`gorev_guncelle(p_id, p_aciklama?, p_hedef_tarih?, p_gorev_tipi?)`** → jsonb
→ forms.js:1119; ui.js:4971; replay: ui.js:6789.

**`gorev_geri_al(p_gorev_id)`** → jsonb
→ ui.js:5047.

**`islem_geri_al(p_islem_id)`** → jsonb
→ ui.js:2106 (`islemGeriAl`).

**`geri_al(p_islem_id)`** → jsonb *(tek girdi — D3 düzeltmesi)*
→ islem_log snapshot'ından undo: `olusturulan` siler, `guncellenen`'in `onceki` değerlerini restore eder; log satırı `durum='geri_alindi'`. uuid PK fallback (20260830000032) ile tohumlama gibi uuid PK'lı tablolarda çalışır.
→ Çağrı: forms.js:1355 (dinamik `rpcName`, default 'geri_al', 1336-1355; TOHUMLAMA ref_id'li kayıtlarda `tohumlama_geri_al`'a yön değiştirir).

**`besleme_tamam(p_gorev_id)`** → jsonb
→ ui.js:467, 795.

**`padok_transfer_gorev_uzlastir()`** → jsonb
→ Padok transfer görevleri uzlaştırma. Çağrı: ui.js:311.

**`gorev_orphan_temizle()`** → jsonb `{temizlenen, zaman}`
→ Orphan görev temizliği; cron `gorev-orphan-temizle-daily` 05:15 UTC. js çağırmaz.

**`stale_tohumlama_gorev_temizle()`** → jsonb
→ Bayat tohumlama görevi temizliği. js çağırmaz (bakım).

**`tohumlama_duplicate_bekliyor_temizle()`** → jsonb
→ Çift Bekliyor kaydı temizliği. js çağırmaz (bakım).

**`tohumlama_orphan_gorev_temizle()`** → jsonb
→ js çağırmaz (bakım).

**`protokol_eksik_tara()`** → jsonb
→ Protokol instance açığı taraması. Çağrı: ui.js:301, 1060, 1367.

**`protokol_gorev_bol(p_dry_run?)`** → jsonb
→ js çağırmaz (bakım/operatör).

**`protokol_orphan_audit()`** → jsonb · **`protokol_orphan_temizle(p_dry_run?)`** → jsonb
→ js çağırmaz (bakım/operatör).

**Views:** `v_gorev_log_sync` (açık + son 300 kapalı; `pullTables` okur), `v_orphan_gorev`.

---

## Vaka / Tedavi (cases)

**`create_case(p_animal_id, p_disease_id uuid, p_notes?)`** → jsonb
→ Kontrollü hastalık listesinden vaka. Çağrı: forms.js:555; replay: ui.js:6789.

**`close_case(p_case_id uuid)`** → jsonb *(LEGACY — korundu)*
→ Basit kapatma; akıllı versiyon `close_case_with_remaining`. Çağrı: ui.js:5995.

**`close_case_with_remaining(p_case_id uuid, p_not?)`** → jsonb *(BUG-059)*
→ Erken kapatma: kalan seanslar uygulanmadi=true, stok iade, açık görevler kapanır.
  `{ok, iptal_edilen_seans, iade_edilen_stok, mesaj}`. Çağrı: api.js:671.

**`case_geri_al(p_case_id uuid)`** → jsonb
→ Vaka geri alma. Çağrı: js'te yok — RPC olarak kullanılmıyor (DB'de duruyor).

**`case_plan_notu_guncelle(p_case_id uuid, p_plan_notu)`** → jsonb
→ js çağırmıyor — kullanılmıyor (GT:4632'de tanımlı).

**`add_treatment_day(p_case_id uuid, p_date, p_planned_time time?)`** → jsonb *(LEGACY)*
→ Tek-seans gün ekleme. Çağrı: ui.js:5677. Yeni akış: `add_treatment_day_with_sessions`.

**`add_treatment_day_with_sessions(p_case_id uuid, p_date, p_sessions jsonb?, p_existing_day_id uuid?)`** → jsonb *(BUG-059 Faz 2)*
→ `p_sessions` NULL → eski tek-seans davranış; `p_existing_day_id` doluysa reçete revizyonu.
  `{ok, day_id, gorev_id, admin_ids, seans_sayisi, mesaj}`. Çağrı: api.js:624.

**`add_sessions_to_existing_day(p_day_id uuid, p_sessions jsonb)`** → jsonb
→ Mevcut güne seans ekle. Çağrı: ui.js:8327.

**`delete_treatment_day(p_day_id uuid)`** → jsonb
→ ui.js:5924.

**`treatment_day_tamamla(p_day_id uuid, p_not?, p_uygulanmadi_ids uuid[]?)`** → jsonb *(idempotent)*
→ Zaten tamamsa exception yok, `{ok:true}`. Çağrı: ui.js:4915, 5514.

**`treatment_day_not_guncelle(p_day_id uuid, p_notes)`** → **void**
→ ui.js:5550.

**`update_treatment_time(p_day_id uuid, p_treatment_time time)`** → jsonb
→ ui.js:5502.

**`seans_tamamla(p_seans_admin_id uuid, p_uygulanmadi boolean?, p_not?)`** → jsonb *(BUG-059)*
→ Race-safe seans tamamla/iptal (SELECT FOR UPDATE). `{ok, tamamlandi, gun_tamam, mesaj}`. Çağrı: api.js:641.

**`remove_treatment_session(p_seans_id uuid)`** → jsonb
→ ui.js:8232.

**`update_treatment_session(p_seans_id uuid, p_dose?, p_unit?, p_route?, p_planned_time?)`** → jsonb
→ ui.js:8279.

**`add_drug_administration(p_day_id uuid, p_drug_product_id uuid, p_stok_id, p_dose, p_unit?, p_route?)`** → jsonb *(C3 düzeltmesi: `p_drug_id` YOK)*
→ İlaç uygulaması + stok düşüm. Çağrı: ui.js:5862; replay: ui.js:6789.

**`update_drug_administration(p_admin_id uuid, p_dose?, p_unit?, p_route?)`** → jsonb
→ ui.js:5980; replay: ui.js:6789.

**`remove_drug_administration(p_admin_id uuid)`** → jsonb
→ ui.js:5914.

**`recete_guncelle(p_case_id uuid, p_yeni_plan jsonb)`** → jsonb *(BUG-059)*
→ Tamamlanmamış günlerin reçetesi → `add_treatment_day_with_sessions`'a delege. Çağrı: api.js:657.

**`tedavi_sablon_kaydet(p_id uuid?, p_ad, p_aciklama?, p_disease_ids jsonb?, p_kalemler jsonb?)`** → jsonb
→ ui.js:3998 (şablon builder).

**`tedavi_sablon_sil(p_id uuid)`** → jsonb
→ ui.js:3761.

**`tedavi_sablon_uygula(p_case_id uuid, p_sablon_id uuid)`** → jsonb
→ forms.js:568.

**`tedavi_sablon_tohumlama_gorev_ekle(p_case_id uuid, p_sablon_id uuid)`** → jsonb
→ forms.js:569. **GT'de YOK** (audit).

**`disease_ekle(p_name, p_category)`** / **`disease_guncelle(p_id uuid, p_name, p_category)`** / **`disease_sil(p_id uuid)`** → jsonb
→ Tanım yönetimi (hastalık kataloğu). Çağrı: ui.js:3422 (ternary ekle/güncelle), 3430 (sil).

### Legacy hastalık/tedavi (hastalik_log tablosu)

**`hastalik_kaydet(p_hayvan_id, p_tani, p_kategori?, p_siddet?, p_semptomlar?, p_lokasyon?, p_hekim_id?, p_ilaclar jsonb?, p_tedavi_gun?)`** → jsonb
→ **Legacy** — frontend kullanmıyor; `create_case` yeni yol.

**`hastalik_guncelle(p_id, p_tani, p_kategori, p_siddet, p_symptomlar?, p_lokasyon?, p_hekim_id?, p_tarih?)`** → jsonb
→ forms.js:1220 (hst düzenleme hâlâ legacy log'da çalışıyor).

**`hastalik_kapat(p_id)`** → jsonb — forms.js:1139.
**`hastalik_sil(p_id)`** → jsonb — forms.js:1243.

**`tedavi_ekle(p_vaka_id, p_hayvan_id, p_ilac_stok_id, p_miktar, p_uygulama_yolu?, p_bekleme_gun?, p_hekim_id?, p_notlar?)`** → jsonb
→ forms.js:1542 (legacy hızlı ilaç formu).

**`tedavi_sil(p_tedavi_id)`** → jsonb — forms.js:1564.
**`tedavi_guncelle(p_tedavi_id, p_miktar?, p_uygulama_yolu?, p_bekleme_gun?, p_hekim_id?, p_notlar?)`** → jsonb
→ **Legacy** — js çağırmıyor.

---

## Aşı

**`asi_ekle(p_name, p_marka?, p_etken_madde?, p_dose?, p_unit?, p_route?, p_is_mandatory?, p_disease_ids uuid[]?, p_protokol_tipi?, p_protokol_adimlar jsonb?, p_repeat_interval_days?, p_baslangic_stok?, p_esik?)`** → jsonb
→ Aşı tanımı + protokol adımları. Çağrı: forms.js:1950.

**`asi_guncelle(p_vaccine_id uuid, [asi_ekle ile aynı 13 alan])`** → jsonb
→ forms.js:1948.

**`asi_sil(p_vaccine_id uuid)`** → jsonb
→ js çağırmıyor — ayarlarda sil akışı yok (DB'de duruyor).

**`add_vaccination(p_animal_id, p_vaccine_id uuid, p_date?, p_dose_override?, p_notes?, p_next_offset_days?)`** → jsonb
→ forms.js:1018.

**`bulk_vaccination(p_animal_ids text[], p_vaccine_id, p_date, p_dose_ml?, p_notes?)`** → jsonb
→ Toplu aşılama. Çağrı: forms.js:1662.

**`vaccination_dismiss(p_vaccination_id uuid, p_note?)`** → jsonb
→ Aşı görevini görmezden gel. Çağrı: ui.js:385.

**`vaccine_rapel_guncelle(p_vaccine_id uuid, p_repeat_days)`** → jsonb
→ ui.js:6978 (ayarlar rapel).

**`get_vaccination_schedule(p_animal_id)`** → TABLE(vaccine_id, vaccine_name, disease_target, dose, unit, route, schedule_date, is_due, notes)
→ js çağırmıyor (aşı takvim görünümü kullanılmıyor; DB'de duruyor).

**`list_vaccinations(p_animal_id)`** → TABLE(id, vaccine_name, disease_target, vaccination_date, dose_given, unit, route, next_due_date, notes)
→ js çağırmıyor — hayvan detayındaki aşı geçmişi `vaccination_log` tablosundan okunuyor.

---

## Hekim / Padok / Kategori / Tanımlar

**`hekim_ekle(p_ad, p_telefon?)`** → jsonb *(C4 düzeltmesi: 2 param — p_id YOK)*
→ ui.js:6990.

**`hekim_guncelle(p_hekim_id, p_ad?, p_telefon?, p_aktif?)`** → jsonb
→ ui.js:7106.

**`hekim_sil(p_hekim_id)`** → jsonb
→ ui.js:7119.

**`hekim_listesi()`** → ⚠️ **CANLIDA YOK** — migration 20260308000009:321'de tanımlı, GT'de yalnız GRANT (GT:2609),
  2026-08-31 canlı snapshot'ında fonksiyon yok. app.js:30 çağırıyor; hata catch edilip config.js `HEKIMLER`'e
  fallback yapılıyor. Çelişki — idle raporuna not edildi (canlıdan drop edilmiş olmalı; GT regen'de netleşecek).

**`padok_ekle(p_ad, p_kapasite?, p_sira?)`** → jsonb — ui.js:7873.
**`padok_guncelle(p_padok_id uuid, p_ad?, p_kapasite?, p_sira?, p_aktif?)`** → jsonb — ui.js:7168.
**`padok_sil(p_padok_id uuid)`** → jsonb — ui.js:7186.
**`grup_padok_eslem_toggle(p_grup_adi, p_padok_id uuid)`** → jsonb — ui.js:7861.

**`kategori_ekle(p_ad, p_tip?)`** / **`kategori_guncelle(p_id uuid, p_new_ad?, p_tip?)`** → jsonb
→ ui.js:4042 (ternary). **`kategori_sil(p_id uuid)`** → jsonb — ui.js:4050.

**`seed_defaults(p_tip)`** → jsonb
→ Tanım varsayılanlarını yükle. Çağrı: ui.js:3450.

**`irk_listesi()`** → TABLE(irk, tohumlama_gun, suttten_kesme_gun, kullanim_sayisi)
→ app.js:204.

---

## Stok / İlaç

**`stok_ekle(p_urun_adi, p_kategori, p_birim, p_baslangic_miktar?, p_esik?)`** → jsonb `{ok, id}`
→ forms.js:1446.

**`stok_guncelle(p_stok_id, p_urun_adi?, p_kategori?, p_birim?, p_esik?)`** → jsonb
→ ui.js:4218.

**`stok_ekleme(p_stok_id, p_miktar, p_notlar?)`** → jsonb
→ Stok girişi. Çağrı: forms.js:1377, 1412.

**`stok_duzelt(p_stok_id, p_yeni_miktar, p_not?)`** → jsonb
→ Sayım düzeltmesi. Çağrı: ui.js:4248.

**`stok_arsivle(p_stok_id)`** → jsonb
→ ui.js:4235.

**`stok_hareket_ekle(p_stok_id, p_tur, p_miktar, p_notlar?)`** → jsonb
→ **Yalnız manuel replay yolu**: ui.js:6789 `buildRpcParams` (case 'stok_hareket_ekle'). Doğrudan form çağrısı yok.

**`ilac_ekle(p_urun_adi, p_kategori?, p_birim?, p_baslangic_miktar?, p_esik?, p_drug_class_id uuid?, p_concentration?, p_concentration_unit?, p_default_route?)`** → jsonb
→ forms.js:1429.

**`link_drug_to_stock(p_drug_id uuid, p_stock_item_id)`** → jsonb
→ forms.js:1577; ui.js:3176.

**`bulk_ilac(p_animal_ids text[], p_ilac_stok_id, p_miktar, p_notlar?)`** → jsonb
→ Toplu ilaç. Çağrı: forms.js:1743.

**`hizli_uygulama(p_hayvan_id, p_stok_id, p_doz?, p_birim?, p_rota?, p_notlar?)`** → jsonb
→ Hayvana hızlı ilaç uygulaması + stok düşüm + protokol dinleme. Çağrı: ui.js:1300, 1440, 4851.

**`hizli_uygulama_geri_al(p_uygulama_id uuid)`** → jsonb
→ ui.js:1350.

**`sperma_sil(p_stok_id)`** → jsonb
→ js çağırmıyor — sperma ayar silme akışı yok (DB'de duruyor).

**`drug_ekle(p_name, p_default_unit?, p_default_route?, p_stock_item_id?, p_kategori?)`** / **`drug_guncelle(p_id uuid, [drug_ekle alanları])`** / **`drug_sil(p_id uuid)`** → jsonb
→ js çağırmıyor — ilaç tanım akışı `ilac_ekle` + drug_class sistemine taşındı (legacy drugs kataloğu).

**`drug_product_ekle(p_drug_class_id uuid, p_brand_name, p_concentration?, p_concentration_unit?, p_default_route?, p_default_unit?, p_stok_id uuid?)`** → **uuid**
→ Marka ürün tanımı (drug_classes). Çağrı: js'te yok — `ilac_ekle`/tanım panelleri drug_product satırlarını
  dolaylı üretiyor; doğrudan RPC çağrısı bulunamadı (kullanılmıyor notu).

**`drug_class_ekle(p_group_name, p_class_name, p_active_ingredient?, p_kategori_id uuid?)`** → jsonb `{ok, id, mesaj}`
→ ui.js:3556, 3565, 3577 (grup/sınıf/etken madde ekleme).

**`drug_class_guncelle(p_id uuid, [drug_class_ekle alanları])`** → jsonb
→ ui.js:3592, 3602, 3615.

**`drug_class_sil(p_id uuid)`** → jsonb
→ ui.js:3580, 3633, 3650, 3664 (bağlı product varsa engeller).

**`drug_class_varsayilan_yukle()`** → jsonb `{ok, eklenen}`
→ 44 referans etken madde seed. Çağrı: ui.js:3442.

---

## Sütten Kesme & Protokol Ayarları

**`buzagi_sutten_kesme_onayla(p_hayvan_id, p_tarih?)`** → jsonb
→ Kanonik tekli kesim; yalnız `suttten_kesme_tarihi` yazar (grup/padok BEFORE trigger ile senkron);
  idempotent; 40g sert sınır. Çağrı: forms.js:796 (+ `gorev_tamamla` içinden).

**`buzagi_sutten_kesme_toplu(p_hayvan_idler text[], p_tarih?)`** → jsonb
→ Limit 200; partial success `{ok, basari, hata_sayisi, hatalar, toplam}`. Çağrı: forms.js:766.

**`buzagi_sutten_kesme_geri_al(p_hayvan_id)`** → jsonb
→ forms.js:809.

**`buzagi_sutten_kesme_kontrol()`** → jsonb
→ Alarm tarayıcısı (eşik `_ayar('sutten_kesme_gun',60)`, gecikme 75). Çağrı: ui.js:280 (dashboard).

**`protokol_ayar_guncelle(p_anahtar, p_deger numeric)`** → jsonb
→ Eşik güncelleme + islem_log audit. Çağrı: forms.js:841.

---

## Sessiz Hayvan (2026-08-31 güncel)

**`sessiz_hayvanlar_listele(p_min_gun?, p_padok?)`** → jsonb `{hayvan_id, kupe_no, grup, padok, sessiz_gun, son_aktivite}`
→ `sessiz_gun` NULL → 9999 sentinel; RPC içi sıralama `COALESCE(sessiz_gun,9999) DESC`, UI client-side
  sentinel-son sıralar (bb4ea92). Çağrı: ui.js:286 (dashboard bandı), 958 (modal `_showSessizList`).

**`sessiz_hayvanlar_reconcile()`** → jsonb `{uretilen, kapatilan, zaman}` — **TEK OTORİTE**
→ `v_eligible` + `sessiz_gun >= 55` → `VETERINER_KONTROL` görevi (`kaynak='SESSIZ-<id>'`, 30g cooldown).
  Günlük cron `sessiz-reconcile-daily` (05:00). js çağırmaz.

**`sessiz_hayvanlar_gorev_olustur()`** → **integer** — eski jeneratör, ince wrapper (reconcile çağırır).
→ js doğrudan çağırmaz; `stat_suru_ozet` içinden kullanılır.

**`v_eligible`** (view): Dişi + Aktif + kısır değil + buzağı/küçük değil + ≥13 ay + hiç Gebe yok + son event >55g;
ankraj = MAX(kızgınlık, tohumlama, abort_tarihi, dogum_tarihi, dogum). Aktif vaka filtresi YOK (20260830000020).

---

## İstatistik

**`stat_suru_ozet(p_padok?, p_son_donem?)`** → jsonb
→ Sürü istatistik paneli. Çağrı: ui.js:1511 (`_fetchSuruStat`).

**`stat_gebelik_ozet(p_donem_baslangic, p_donem_bitis, p_kategori?, p_grup?, p_sperma?)`** → jsonb
→ js çağırmıyor — rapor ekranı kullanılmıyor (DB'de duruyor).

---

## AI Asistan

> Asistan RPC'leri Edge Function (`supabase/functions/ai-agent/tools.ts`) ve `js/ai-asistan.js` tarafından kullanılır.
> tools.ts çağrıları: asistan_sql_calistir (16, 53), asistan_hayvan_detay (31), asistan_plan_olustur (83), asistan_plan_uygula (100).

**`asistan_sql_calistir(p_sql)`** → jsonb (satır dizisi — `{ok}` sarmalı DEĞİL)
→ Salt-okuma SELECT guard'lı (tek SELECT, 5s timeout, LIMIT 500, read_only).

**`asistan_hayvan_detay(p_kupe?, p_id?)`** → jsonb — hayvan 360° özeti. **2026-09-01:** küpe eşleşmesinde
`ORDER BY (durum='Aktif') DESC` — aynı string hem çıkışlı hem aktif hayvanda varsa AKTİF döner (K7).

**`asistan_plan_olustur(p_thread_id uuid, p_adimlar jsonb)`** → jsonb — tools.ts:83.
**`asistan_plan_uygula(p_plan_id uuid)`** → jsonb — tools.ts:100.
**`asistan_plan_iptal(p_plan_id uuid)`** → jsonb — ai-asistan.js:280.
**`asistan_plan_geri_al(p_plan_id uuid)`** → jsonb — ai-asistan.js:298.
**`asistan_tumunu_sil()`** → jsonb — ai-asistan.js:385.

**`agent_threads_prune()`** → void — cron `agent-threads-prune` günlük 03:00 (90g/200 thread).
**`agent_plans_prune()`** → void — plan temizliği; js çağırmaz (cron/bakım). **GT'de YOK** (audit).

---

## Demo Projesi (AYRI Supabase projesi — PROD şemasında YOK)

**`demo_klonla`** → demo.js:16 · **`demo_sema_diff`** → demo.js:29
→ Yalnız demo projesinde tanımlı; prod snapshot'ında bulunmazlar (public-by-design, bkz AGENTS.md).

---

## Trigger Fonksiyonları (js çağırmaz — tablo trigger'larına bağlı)

| Fonksiyon | Tetiklendiği yer (snapshot envanteri) |
|---|---|
| `_guard_dogum_ileri_tarih()` | dogum trg_dogum_guard (2026-08-31; rpc değil tablo guard'ı) |
| `_guard_hayvanlar_cinsiyet_grup()` | hayvanlar trg_hayvanlar_guard (2026-08-31; erkek↔grup backend guard'ı BURADA) |
| `_guard_tohumlama_yas_cinsiyet()` | tohumlama trg_tohumlama_guard (2026-08-31) |
| `_islem_log_immutable_guard()` | islem_log B/U/D immutable koruma |
| `_islem_log_yaz()` | islem_log üreticisi (tohumlama/insert kolları) |
| `_kizginlik_case_close()` | cases (kızgınlık vaka kapanışı) |
| `_tohumlama_kizginlik_kapat()` | tohumlama (kızgınlık kapatma) |
| `_trg_case_ureme_sessiz_iptal()` | cases → sessiz görev iptali |
| `_trg_gorev_parent_kapandi()` | gorev_log (parent kapanınca çocuklar) |
| `_trg_hayvan_cikis_gorev_iptal()` | hayvanlar durum (çıkışta görev iptali) |
| `_trg_kizginlik_sessiz_iptal()` | kizginlik_log |
| `_trg_tohumlama_gebe_sessiz_iptal()` | tohumlama (gebe olunca) |
| `_trg_tohumlama_sessiz_iptal()` | tohumlama |
| `tohumlama_cycle_gorevcil_iptal()` | tohumlama cycle iptal zinciri |
| `gorev_log_cycle_guard()` | gorev_log cycle koruması |
| `drug_administration_stok_dusum()` | drug_administrations |
| `vaccination_stok_dusum()` | vaccination_log |
| `fn_dinle_uygulama()` / `fn_dinle_vaccination()` / `fn_dinle_drug_admin()` | protokol dinleyicileri |
| `fn_gebe_gorev_yarat()` | tohumlama gebe geçişi (gebe kontrol görevleri) |
| `fn_hayvan_grup_padok_sync()` | hayvanlar grup↔padok eşlemi |
| `fn_islem_log()` | eski islem_log üreticisi |
| `fn_padok_transfer_gorev_kapat()` | padok transfer görev kapatma |
| `set_deneme_no()` | tohumlama deneme no |
| `set_treatment_day_no()` | treatment_days day_no |
| `trg_sutten_kesme_normalize()` / `trg_sutten_kesme_kapat()` | sütten kesme trigger çifti |

## Internal Helper'lar (SQL içi — RPC olarak çağrılmaz)

`_ayar(p_anahtar, p_varsayilan)` → numeric (protokol_ayar okuma; STABLE) ·
`_protokol_kapat(p_kaynak_ref, p_sebep)` → void · `_sessiz_gorev_iptal(p_hayvan_id)` → void ·
`_gorev_dinle(p_hayvan_id, p_etken_kod, p_ref, p_tarih)` → void (**canlıda 4 param — GT'de 3, audit**) ·
`_tohumlama_gorev_uygunluk(p_hayvan_id, p_tarih)` → text (**GT'de YOK**) ·
`_etken_kod_bul(p_stok_id, p_vaccine_id uuid)` → text ·
`_asistan_ref_coz(p_param, p_ctx)` / `_asistan_step_calistir(p_tip, p_param)` / `_asistan_step_dogrula(p_tip, p_param)` → jsonb (asistan plan motoru)

## Test / Debug / Altyapı

`test_dollar_block()` / `test_migrate_working()` → text (deploy doğrulama) ·
`_debug_protokol_ozet()` → jsonb (debug) ·
`current_farm_id()` → uuid (tek-tenant sabiti; Faz 2 JWT) ·
`rls_auto_enable()` → event_trigger (DDL sonrası RLS açma) ·
`search_code(query_embedding vector, match_count?)` / `search_memory_notes(query_embedding vector, match_count?, filter_category?)` → TABLE (pgvector arama — js çağırmaz; tools-bank geçmiş altyapısı)

---

## Phase 4 audit notes (2026-09-03, from current code)

- Wrapper stack: raw `db.rpc` (about 10 legacy direct sites, no error
  translation) → `rpc()` (api.js, throws `ok:false` with body on `.data`) →
  `rpcOptimistic` (auto-pull via `RPC_TABLES`) → typed wrappers
  (`rpcSeansTamamla`, `rpcReceteGuncelle`,
  `rpcCloseCaseWithRemaining`, `rpcAddTreatmentDayWithSessions`).
- Measured call surface: roughly 145-150 wrapper call sites across `js/`
  invoking 113 unique Postgres functions; over half sit in `js/ui.js` and
  about a third in `js/forms.js` (per-file counts drift with edits). About 11
  legacy direct `db.rpc` sites remain outside the wrapper stack.
- `RPC_TABLES` (api.js) is missing several RPCs called from `js/` (both
  `js/ui.js` and `js/forms.js`): `kategori_*`, `hastalik_*`,
  `tedavi_ekle/sil`, `asi_planli_tamamla`, `asi_gorev_planla`,
  `asi_toplu_planla`, `hizli_uygulama_geri_al`, `islem_geri_al`,
  `gorev_geri_al`, `kizginlik_vaka_ac`, `vaccination_dismiss`, `hekim_sil`,
  `padok_degistir*`, `stok_duzelt`, `treatment_day_*`, session RPCs, and
  `hastalik_kapat`; those callers refresh manually. (Membership verified per
  name on 2026-09-03; an earlier draft wrongly listed `vaka_tohumlama_ekle`,
  which is registered.) New write RPCs must register in
  `RPC_TABLES`.
- Offline-replay `RPC_MAP` (ui.js `dataTrafficTekGonder`) and `RPC_TABLES`
  are separate, partially divergent maps; extend both when they overlap.
- Edge functions: `supabase/functions/ai-agent` is called from
  `js/ai-asistan.js` (streaming HTTP); `supabase/functions/stat-hesapla` has
  no frontend caller (the `stat_suru_ozet` RPC serves that data) — classified
  superseded from the frontend's point of view.
