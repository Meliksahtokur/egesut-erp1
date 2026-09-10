# RPC Quick Reference

Tüm RPC'ler `SECURITY DEFINER`, `jsonb` döndürür: `{ ok: boolean, ... }`
Frontend'de `api.js` üzerinden çağrılır. Asla doğrudan `db.from().insert/update` kullanılmaz.

---

## Hayvan Yönetimi

**`hayvan_ekle(p_kupe_no, p_devlet_kupe, p_irk, p_cinsiyet, p_dogum_tarihi, p_grup, p_padok, p_dogum_kg?, p_anne_id?, p_baba_bilgi?, p_canli_agirlik?, p_boy?, p_renk?, p_ayirici_ozellik?)`**
→ Yeni hayvan kaydı oluşturur, otomatik ID üretir.

**`hayvan_guncelle(p_id, p_kupe_no?, p_devlet_kupe?, p_irk?, p_cinsiyet?, p_dogum_tarihi?, p_grup?, p_padok?, p_dogum_kg?, p_canli_agirlik?, p_boy?, p_renk?, p_ayirici_ozellik?)`**
→ Hayvan bilgilerini günceller.

**`hayvan_not_ekle(p_hayvan_id, p_not)`**
→ Hayvana not ekler.

---

## Üreme

**`tohumlama_kaydet(p_hayvan_id, p_tarih, p_sperma, p_hekim_id?, p_irk_bilgisi?, p_ek_uygulamalar?, p_vwp_override?)`**
→ Tohumlama kaydeder. State machine: boş → gebe.
→ **VWP kapısı (2026-08-30):** son doğumdan VEYA son aborttan (`GREATEST(son_dogum, son_abort)`) 55 gün dolmadan `VWP_VIOLATION:gun:55` / `ABORT_VWP_VIOLATION:gun:55` RAISE eder. Frontend confirm → `p_vwp_override=true` ile geçilir (forms.js submitInsem; ABORT dalı regex alt-dize tuzağı yüzünden ÖNCE test edilir).
→ Yaş ≥365g, erkek engeli, aktif gebelik engeli, ileri tarih engeli de RPC'de.

**`tohumlama_sonuc_gebe(p_tohumlama_id)`**
→ Tohumlama sonucunu "Gebe" yap. Hayvan durumu "Gebe" → islem_log kaydı.
→ Abort kayıtta `{ok:false, mesaj:'Bu tohumlama kaydı abort edildi — tekrar gebe işaretlenemez. Yeni bir tohumlama kaydı girin.'}` döner (20260830000031).

**`tohumlama_sonuc_bos(p_tohumlama_id)`**
→ Tohumlama sonucunu "Boş" yap (muayenede gebe değil). Hayvan durumu "Boş" → islem_log kaydı.

**`tohumlama_sonuc_bekliyor(p_tohumlama_id)`**
→ Hatalı kaydı düzelt: sonuç → "Bekliyor", hayvan durumu → "Tohumlanabilir" → islem_log kaydı.

**`dogum_kaydet(p_anne_id, p_tarih, p_kupe, p_cins?, p_tip?, p_kg?, p_baba?, p_hekim_id?)`**
→ Doğum kaydeder + buzağı oluşturur + 14 doğum sonrası görev üretir.

**`tohumlama_abort(p_tohumlama_id, p_notlar?, p_abort_tarihi?)`** *(2026-08-30, 3-param — eski 2-param imza korundu)*
→ Tohumlama abort'u kaydeder. State: gebe → Abort. `abort_tarihi` kolonuna yazar (default bugün; frontend prompt ile geriye dönük tarih girilebilir) → VWP çapası olur.
→ islem_log'a TEK `ABORT_KAYDI` yazar (`_islem_log_yaz` trigger'ının tohumlama UPDATE kolu sessizleştirildi — 20260830000030; öncesinde çift log düşüyordu).
→ Snapshot `onceki.abort_tarihi` içerir → `geri_al` ile undo çalışır. Legacy `abort_kaydet(p_tohumlama_id, p_notlar?)` hâlâ durur ama frontend kullanmaz.

**`geri_al(p_islem_id)`**
→ islem_log snapshot'ından undo: `olusturulan` siler, `guncellenen`'in `onceki` değerlerini restore eder; log satırı `durum='geri_alindi'` olur.
→ 2026-08-30: `guncellenen` döngüsüne uuid PK fallback eklendi (20260830000032) — önceden tohumlama gibi uuid PK'lı tablolarda `operator does not exist: uuid = text` veriyordu.

**`kizginlik_kaydet(p_hayvan_id, p_tarih, p_belirti?, p_notlar?)`**
→ Kızgınlık gözlemi kaydeder.

---

## Hastalık (Legacy Sistem)

**`hastalik_kaydet(p_hayvan_id, p_tani, p_kategori?, p_siddet?, p_semptomlar?, p_lokasyon?, p_hekim_id?, p_ilaclar?, p_tedavi_gun?)`**
→ Hastalık vakası + tedaviler + follow-up görevler oluşturur.

**`hastalik_guncelle(p_id, p_tani, p_kategori, p_siddet, p_semptomlar, p_lokasyon, p_hekim_id, p_tarih?)`**
→ Vaka bilgilerini günceller.

**`hastalik_kapat(p_id)`**
→ Aktif vakayı kapatır.

**`hastalik_sil(p_id)`**
→ Vakayı + follow-up görevleri siler.

---

## Tedavi (Legacy Sistem)

**`tedavi_ekle(p_vaka_id, p_hayvan_id, p_ilac_stok_id, p_miktar, p_uygulama_yolu?, p_bekleme_gun?, p_hekim_id?, p_notlar?)`**
→ İlaç tedavisi ekler + stok ledger'dan düşer.

**`tedavi_sil(p_tedavi_id)`**
→ Tedaviyi siler + stoğu geri yükler.

**`tedavi_guncelle(p_tedavi_id, p_miktar?, p_uygulama_yolu?, p_bekleme_gun?, p_hekim_id?, p_notlar?)`**
→ Tedavi günceller + stok delta hesaplar.

**`update_treatment_time(p_day_id uuid, p_treatment_time time)`**
→ Tedavi saatini günceller.

---

## Vaka Sistemi (Yeni — Migration 022+)

**`create_case(p_animal_id, p_disease_id uuid, p_notes?)`**
→ Kontrollü hastalık listesinden yeni vaka oluşturur.

**`add_treatment_day(p_case_id, p_date, p_planned_time time?)`** *(LEGACY — korundu)*
→ Vakaya tedavi günü ekler (day_no otomatik, planned_time opsiyonel). planned_time varsa gorev_log JSON'a eklenir. **Yeni akış için `add_treatment_day_with_sessions` tercih edilir.**

**`add_treatment_day_with_sessions(p_case_id, p_date, p_sessions jsonb, p_existing_day_id uuid?)`** *(BUG-059 — Faz 2, 2026-06-11)*
→ Sarmalayıcı RPC. `p_sessions` JSONB array: `[{planned_time, stok_id, drug_product_id?, dose, unit, route}]`. `p_sessions=NULL` ise eski tek-seans davranış (geriye uyumlu). `p_existing_day_id` doluysa günceller (recete revizyonu). `{ ok, day_id, gorev_id, admin_ids, seans_sayisi, mesaj }`

**`seans_tamamla(p_seans_admin_id uuid, p_uygulanmadi boolean?, p_not text?)`** *(BUG-059 — Faz 2)*
→ Seans bazlı race-safe tamamla/iptal. SELECT FOR UPDATE ile eşzamanlılık koruması. `p_uygulanmandi=true` ise stok_hareket güncellenir, drug_admins senkronize edilir, tedavi günü otomatik tamamlanır. `{ ok, tamamlandi, gun_tamam, mesaj }`

**`recete_guncelle(p_case_id, p_yeni_plan jsonb)`** *(BUG-059 — Faz 2)*
→ Henüz tamamlanmamış tedavi günlerinin reçetesini günceller (DRY → `add_treatment_day_with_sessions`'a delege eder). `{ ok, guncellenen_gun_sayisi, mesaj }`

**`treatment_day_tamamla(p_day_id, p_not?, p_uygulanmadi_ids uuid[]?)`** *(BUG-059 — Faz 2, idempotent)*
→ Tedavi gününü tamamlar. **Idempotent** — zaten tamamlandıysa exception fırlatmaz, `{ ok: true }` döner. p_uygulanmadi_ids'deki ilaçlar uygulanmadi=true + stok_hareket iptal. Tüm seanslar tamamsa gun kapatılır, gorev_log güncellenir. `{ ok, day_id }`

**`case_plan_notu_guncelle(p_case_id, p_plan_notu)`**
→ cases.plan_notu güncelle.

**`add_drug_administration(p_day_id uuid, p_drug_id uuid, p_dose, p_unit, p_route?)`**
→ İlaç uygulaması kaydeder + stok düşer.

**`close_case(p_case_id uuid)`** *(LEGACY — korundu)*
→ Vakayı kapatır (status='closed'). **Eksik reçete uyarısı veren akıllı versiyon için `close_case_with_remaining` tercih edilir.**

**`close_case_with_remaining(p_case_id uuid, p_not text?)`** *(BUG-059 — Faz 2)*
→ Vakayı erken kapatır. Tamamlanmamış tedavi günlerindeki tüm seanslar `uygulanmadi=true` yapılır, stok iade edilir, drug_admins senkronize edilir, açık gorev_log'lar kapatılır. `{ ok, iptal_edilen_seans, iade_edilen_stok, mesaj }`

---

## Sütten Kesme & Protokol Ayarları (2026-06-20)

**`buzagi_sutten_kesme_onayla(p_hayvan_id text, p_tarih date DEFAULT CURRENT_DATE)`** → jsonb
→ Kanonik tekli kesim. Sadece `suttten_kesme_tarihi` yazar; BEFORE trigger grup/padok'u senkronlar (Sütten Kesilmiş Buzağı + padok), AFTER trigger görev/instance'ı kapatır. İdempotent (zaten kesilmişse no-op). 40g sert sınır (`_ayar('sutten_kesme_erken_uyari')`). Snapshot'a grup/padok/padok_id yazar (undo için).

**`buzagi_sutten_kesme_toplu(p_hayvan_idler text[], p_tarih date DEFAULT CURRENT_DATE)`** → jsonb
→ Çoklu kesim (limit 200). Partial success: `{ok, basari, hata_sayisi, hatalar:[{hayvan_id,hata,kod}], toplam}`.

**`buzagi_sutten_kesme_geri_al(p_hayvan_id text)`** → jsonb
→ Son aktif SUTEN_KESME log'undan grup/padok geri yükler, tarihi NULL'a çeker → AFTER trigger instance'ı tekrar açar.

**`buzagi_sutten_kesme_kontrol()`** → jsonb
→ Alarm tarayıcısı (dashboard'da otomatik çağrılır). Eşik `_ayar('sutten_kesme_gun',60)`, gecikme `_ayar('sutten_kesme_gecikme_gun',75)`. SUTTEN_KESME tipi görev + BAKIM/SUTTEN_KESME `protokol_instance` (kaynak_ref='SUTTENKES-<id>'). İdempotent.

**`protokol_ayar_guncelle(p_anahtar text, p_deger numeric)`** → jsonb
→ UI'dan eşik günceller (min/max doğrulama + islem_log audit). Anahtarlar: sutten_kesme_gun, sutten_kesme_gecikme_gun, sutten_kesme_erken_uyari, besleme_baslangic_gun, kuru_donem_gun, ileri_gebe_asi1_gun, ileri_gebe_asi2_gun, ileri_gebe_ademin_gun, ileri_gebe_evit_gun.

**`_ayar(p_anahtar text, p_varsayilan numeric)`** → numeric
→ protokol_ayar'dan değer okur, yoksa varsayılan (mantık geriye uyumlu). SQL STABLE.

> **gorev_tamamla**: SUTTEN_KESME tipi görev tamamlanınca `buzagi_sutten_kesme_onayla` çağrılır (her kaynaktan kesim garantisi).
> **gebelik_protokol_kontrol**: tüm gün eşikleri artık `_ayar()` config'inden (davranış birebir).

---

## Sessiz Hayvan Reconciliation (2026-06-25, güncel 2026-08-31)

**`v_eligible` view filtreleri:** Dişi + Aktif + kısır değil + buzağı/küçük değil + ≥13 ay + hiç `sonuc='Gebe'` yok + **son event >55g**. **Aktif vaka filtresi KALDIRILDI (20260830000020)** — açık vaka hayvanı sessiz takipten sürgün etmez (147 vakası 6 ay görev üretememişti; kalkınca 147/178/174/144/200 geri döndü). Vaka açmak üreme takibini durdurmaz.

**`sessiz_gun` ankrajı (20260831000001 + 20260831000002, canlı v4):** en yeni event = MAX(kızgınlık, tohumlama, `tohumlama.abort_tarihi`, `tohumlama.dogum_tarihi`, `dogum` tablosu). `son_aktivite_tarihi` kolon adı korundu ama artık bu geniş event'i taşır. Sayaç sırası: son event → son doğum → (event'siz düve) 13 aylık uygunluk noktası (`GREATEST(0, bugün - (doğum + 13 ay))`) → NULL. WHERE: `son_event IS NULL OR son_event < bugün-55`. Doğum/abort sonrası ilk 55 gün hayvan listede görünmez; düve 13ay+55g'de listeye girer. Görünüm SADECE sessiz akışlarını besler; tohumlama form autocomplete'i client-side `_eligibleHayvanlar()`.

**`sessiz_hayvanlar_listele(p_min_gun int DEFAULT 55, p_padok text)`**
→ `RETURNS jsonb` — `{hayvan_id, kupe_no, grup, padok, sessiz_gun, son_aktivite}`; `sessiz_gun` NULL → 9999 ('Hiç kayıt yok').
→ Dashboard bandı (`js/ui.js _dashBands`) ve modal (`_showSessizList`) kullanır; iki yüzeyde de 9999'lular client-side sentinel-son sıralanır (bb4ea92).
→ RPC içi sıralama hâlâ `COALESCE(sessiz_gun,9999) DESC` (9999 başta) — UI'a dokunmadan RPC sırasına güvenme.

**`sessiz_hayvanlar_reconcile()`** — **TEK OTORİTE**
→ `RETURNS jsonb {uretilen:int, kapatilan:int, zaman:timestamptz}`
→ `v_eligible` ile `sessiz_gun >= 55` hayvanları tarar.
→ `gorev_log`'a `kaynak='SESSIZ-<id>'` ile `VETERINER_KONTROL` görevi üretir.
→ 30 gün cooldown: yalnız kullanıcı-tamamlaması (`tamamlandi=true && tamamlanma_tarihi >= CURRENT_DATE - 30`).
→ Açık SESSIZ-* görevi olan ama artık eligible olmayan hayvanları `kapatan_ref='sessiz-noteligible'` ile kapatır.
→ Günlük cron `sessiz-reconcile-daily` (05:00) otomatik çağırır.
→ SECURITY DEFINER — anon/authenticated GRANT EXECUTE.

**`sessiz_hayvanlar_gorev_olustur()`** — eski jeneratör → ince wrapper
→ `RETURNS integer` (geriye uyumlu imza).
→ İçeride `sessiz_hayvanlar_reconcile()` çağırır, `uretilen` count'unu döner.
→ Eski çağıranlar (stat_suru_ozet vb.) güvenle çalışır.

**SESSIZ- kaynak kimliği:** kararlı kalıcı anahtar (`gorev_log.kaynak='SESSIZ-' || hayvan_id`).
→ 30g cooldown = aynı hayvana spammy görev üretmez.
→ Görev tamamlanınca cooldown başlar (otomatik kapatma cooldown SAYMAZ).

---

## Diğer

**`geri_al(p_islem_id)`**
→ islem_log'dan işlemi geri alır (önceki state'e döner).

**`irk_listesi()`**
→ `TABLE(irk, tohumlama_gun, suttten_kesme_gun, kullanim_sayisi)` — ırk referans listesi.

**`hekim_ekle(p_id, p_ad, p_telefon?)`**
→ Veteriner kaydı ekler.

---

## İlaç Sınıflandırma (drug_classes)

**`drug_class_ekle(p_group_name, p_class_name, p_active_ingredient, p_kategori_id?)`**
→ Yeni etken madde sınıfı ekler. `{ ok, id, mesaj }`

**`drug_class_guncelle(p_id, p_group_name?, p_class_name?, p_active_ingredient?, p_kategori_id?)`**
→ Sınıf bilgilerini günceller. `{ ok, mesaj }`

**`drug_class_sil(p_id)`**
→ Sınıfı siler. drug_products bağlıysa engeller. `{ ok, mesaj }`

**`drug_class_varsayilan_yukle()`**
→ 44 referans etken maddeyi seed eder (ON CONFLICT DO NOTHING). `{ ok, eklenen }`

---

## Stok Yönetimi

**`stok_ekle(p_urun_adi, p_kategori, p_birim, p_baslangic_miktar, p_esik?)`**
→ Yeni stok kaydı. Kategori stok_kategorileri'nde olmalı. `{ ok, id }`

**`stok_guncelle(p_stok_id, p_urun_adi?, p_kategori?, p_birim?, p_esik?)`**
→ Stok günceller. Kategori değiştiriliyorsa validate edilir. `{ ok }`

---

## AI Asistan (salt-okuma)

> Bu RPC'ler asistan Edge Function'ı (`ai-agent`) tarafından kullanılır. `{ok,...}` DEĞİL, ham `jsonb` döner.

**`asistan_sql_calistir(p_sql text)`** → `jsonb` (satır dizisi)
→ Salt-okuma SELECT/WITH çalıştırır. Guard'lar: yalnız tek SELECT, yazma/DDL anahtar kelime reddi, `SET LOCAL transaction_read_only=on` (motor seviyesi yazma engeli), `statement_timeout=5s`, dış LIMIT 500. SECURITY DEFINER. `authenticated, anon` EXECUTE.

**`asistan_hayvan_detay(p_kupe text?, p_id text?)`** → `jsonb`
→ Tek hayvanın 360° özeti: `{bulundu, hayvan, tohumlama[], gorevler[], uygulamalar[], islem_log[]}`. Küpe no veya ID ile. SECURITY DEFINER.

**`agent_threads_prune()`** → `void`
→ Sohbet temizliği: 90 günden eski VEYA kullanıcı başına 200 üstü thread'leri siler. pg_cron job `agent-threads-prune` ile günlük 03:00 çalışır.

---

## Görev Log (gorev_log yaşam döngüsü — 2026-06-26)

**`gorev_orphan_temizle()`** → `jsonb {temizlenen:int, zaman:timestamptz}`
→ `v_orphan_gorev`'deki orphan'ları (parent silinmiş/kapanmış-farklı-tip VEYA hayvan aktif değil) iptal; **zincir tipleri** (BESLEME, BUZAGI_BAKIM, TEDAVI_GUN, ILERI_GEBE_ASI) MUAF. Kaçak bulursa `bildirim_log ORPHAN_GOREV` kaydı yazar. SECURITY DEFINER. Cron: `gorev-orphan-temizle-daily` 05:15 UTC.

**Views (salt-okuma, fetcher yardımcı):**
- `v_gorev_log_sync` → açık görevler (`!tamamlandi && !iptal`) HEPSİ + son 300 kapalı. `pullTables` bu view'i okur → 1000-satır tavanı korunur.
- `v_orphan_gorev` → canlı orphan tespit (zincir tipleri hariç).

**Trigger'lar (gorev_log / hayvanlar):**
- `trg_gorev_parent_kapandi` (AFTER DELETE/UPDATE OF tamamlandi,iptal ON gorev_log) → parent kapanınca çocukları iptal; aynı-tip zincir muaf.
- `trg_hayvan_cikis_gorev_iptal` (AFTER UPDATE OF durum ON hayvanlar) → durum 'Aktif'ten çıkarsa hayvana bağlı tüm açık görevleri iptal.
