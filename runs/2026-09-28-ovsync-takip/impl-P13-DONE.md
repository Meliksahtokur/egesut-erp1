# impl-P13-DONE — TAMAM

- **Goal:** `G-20260930-OVSYNC-TAKIP-IMPL` · **Plan madde:** P13 (plan.md:705-721, birebir; MADDE DRIFT KAPISI — yalnız P13)
- **GOREV:** `runs/2026-09-28-ovsync-takip/impl-P13-GOREV.md` · **Tarih:** 2026-10-01
- **Sonuç:** 4/4 kabul kanıtlı — **TAMAM** (self-repair 0/2; commit ATILMADI)
- **Protokol:** using-superpowers-obra okundu-uygulandı (SUBAGENT-STOP sahibin kuralıyla geçersiz) → kaynak gerçeği DONE'lar + canlı demo şema (psql) → verification-before-completion-obra (aşağıdaki kanıtlar bu oturumda taze koşuldu).

## Yazılan dosyalar (manifest 3/3 — TEK YAZICI)

1. `.harness/references/rpc-reference.md` (MODIFY) — yeni "Ovsync Takip Ekranı" bölümü (2 yeni RPC + gebelik_muayene sistemi + C2 imza tablosu + H5 satır-sonucu tablosu + P3a tetikleyicileri + yeni yardımcılar); mevcut girdilere nokta güncellemeler (`gorev_tamamla` H6 guard, `tohumlama_sonuc_gebe` D1 yeniden-tanım, `tohumlama_sonuc_bos` UI yönlendirme + fallback, `gebelik_protokol_kontrol` bayat notu, tetikleyici tablosuna 3 yeni + 2 güncelleme satır, Live-schema audit'e 2026-10-01 probe paragrafı).
2. `.harness/references/ui-map.md` (MODIFY) — yeni "Ovsync takip ekranı" bölümü (`#pg-ovsync` sayfa/gezinti/scroll, api.js veri katmanı, `_ovsyncDashDurum` matrisi, P6 render ailesi, 3 bottom-sheet, K15 özel tamamlama akışı + jenerik buton exclusion, P7 köprüleri); "Non-router overlays" paragrafına yönlendirme cümlesi.
3. `runs/2026-09-28-ovsync-takip/impl-P13-DONE.md` (bu dosya).

Manifest dışı repo yazımı YOK [OBSERVED `git status --porcelain` çalışma sonu: `M` yalnız 2 referans dosyası + önceden-devralınan mimar checkpoint'leri (`.harness/goals/...IMPL.md`, `domain-rules.md`, `.ss/BOARD`, `design.md` — görev başı git snapshot'ında mevcuttu, dokunulmadı)]. Kod/test/migration/ground-truth/domain-rules/plan yazımı YOK. Canlı gövde dökümleri repo DIŞINDA: `~/tmp/p13-live-{bos_ve_devam,gorev_tamamla,tohumlama_kaydet}.sql`.

## Kabul ölçütleri (plan.md:719 birebir)

### 1) docs-update checkpoint — PASS

Dokunulanlar: rpc-reference.md + ui-map.md (manifestin kendisi). Dokunulmayanlar gerekçeli: **domain-rules.md** — §18.15-17 spec'le uyumlu görüldü, zarf kuralı "uyumluysa DOKUNMA" (aşağıda teyit satırı); **design.md / plan.md / ground-truth / kod-test-migration** — zarf YASAK listesi. `.harness/references/` dışına dokunulmadı.

### 2) Ground-truth raporu — DONE'da (aşağıdaki ayrı bölüm; dosya yazımı YOK)

### 3) rpc-reference tabloları canlı gövdeyle eşleşiyor — 17 imza + 2 gövde psql'den kanıtlı

[OBSERVED demo pooler psql, 2026-10-01, `pg_get_function_identity_arguments` + `has_function_privilege`; değer basılmadı]:

- `ovsync_takip_listele | p_padok text, p_sonlanan_gun integer -> jsonb` · ACL `anon=false auth=true`
- `tohumlama_bos_ve_devam | p_tohumlama_id text, p_muayene_gorev_id uuid, p_secim text, p_pg_urun text, p_pg_doz numeric, p_gun integer, p_saat time without time zone, p_notlar text, p_onay boolean -> jsonb` · ACL `anon=false auth=true`
- `gorev_tamamla | p_gorev_id text, p_padok_hedef text, p_iptal boolean -> jsonb` + canlı gövdede H6 guard [OBSERVED: `IF p_iptal IS NOT TRUE THEN ... IF v_guard_tip IN ('GEBELIK_KONTROL','TAKIP_MUAYENE') THEN RAISE 'MUAYENE_SONUC_GEREKLI:%'`, kilitsiz okuma FU'dan ÖNCE, T5/SUTTEN dal yorumları]
- C2 7 üretici tek-imza canlı: `hizli_uygulama(..., p_takip_onay)`, `seans_tamamla(..., p_takip_onay)`, `bulk_ilac(..., p_takip_onaylar text[])`, `start_first_service_protocol(p_gorev_id uuid, p_takip_onay)`, `create_case(..., p_takip_onay)`, `vaka_toplu_ac(...11 param..., p_takip_onaylar text[])`, `kizginlik_vaka_ac(..., p_takip_onay)` — isim başına tek satır (eski overload 0)
- `tohumlama_bos_ve_devam` canlı gövdesi TAM döküldü: 24 RAISE kodu (GIRIS_CIFT_ANLAMLI → PG_UYGULAMA_RED), dry-run dönüş alan seti, 5 yazma modu dönüşü, ERTALE `Europe/Istanbul` + `COALESCE(p_gun,7)` + `TAKIP_UZADI ≥21` zincir eşiği, XOR guard, kilit sırası (hayvan NKU → tohumlama FU → gorev_log FU) — dokümandaki tablolar bu gövdeden yazıldı
- `gebelik_muayene_gorev_uret` canlı: eşik `_ayar('sessiz_tohumlama_muafiyet_gun',40)`, NOT EXISTS çift-görev koşulu, `CURRENT_DATE` hedef, `GEBELIK-KONTROL-<toh_id>` kaynak
- `tohumlama_kaydet` canlı: **GEBELIK_KONTROL 0 eşleşme** (P2c kaldırma canlı), `protokol_instance` korunuyor (3 eşleşme)
- P12b TZ 4'lüsü canlı `Europe/Istanbul` pozitif: `_takip_gorev_kur` t, `tohumlama_bos_ve_devam` t (5 kalıp), `vaka_toplu_ac` t, `kizginlik_vaka_ac` t
- P3a tetikleyicileri canlı: `trg_takip_yeni_tohumlama_kapat` (AFTER INSERT tohumlama), `trg_takip_pg_olay_kapisi` (BEFORE INSERT pg_application_event), `trg_takip_ovsync_case_kapisi` (BEFORE INSERT cases); `_tohumlama_gebe_uygula` ACL `anon=false auth=false` (EXECUTE yok)

### 4) `git diff --check` — TEMİZ

[OBSERVED exit 0, boş çıktı]. Ek mekanik kontrol: ui-map.md + rpc-reference.md'deki TÜM `file:symbol` anchor'ları harness çözücüsüyle (`tests/harness/test_patterns.py:symbol_defined` regex'leri) doğrulandı — **benim eklediğim anchor'ların tamamı çözülüyor**; HEAD'te zaten çözülmeyen 3 bayat anchor korundu (aşağıda açık kalem 1).

## Ground-truth kapısı (#12) — SAHİBE RAPOR (RAPOR KALEMİ; dosya yazma YOK; `99999999999999_ground_truth.sql`'e DOKUNULMADI)

**1. Değişen fonksiyon listesi (plan.md:717 + DONE'lardan; hepsi demo'da canlı):**

| Kaynak migration | Fonksiyon | Değişim |
|---|---|---|
| 20260929000001 (P1) | `ovsync_takip_listele` | YENİ (salt-okunur) |
| 20260929000002 (P2a/P2b) | `_takip_gorev_kur`, `_takip_kapat`, `tohumlama_bos_ve_devam`, `_tohumlama_gebe_uygula` | YENİ |
| 20260929000002 (P2b) | `tohumlama_sonuc_gebe` | YENİDEN TANIM (D1 çekirdeğine yönlendirme; imza aynı) |
| 20260929000003 (P3a) | `_trg_takip_yeni_tohumlama_kapat`, `_trg_takip_pg_olay_kapisi`, `_trg_takip_ovsync_case_kapisi` | YENİ (+3 trigger) |
| 20260929000003 (P3a) | `_trg_hayvan_cikis_gorev_iptal`, `gorev_log_cycle_guard` | CREATE OR REPLACE (canlı gövde + CIKIS UPDATE / TAKIP_MUAYENE muafiyeti) |
| 20260929000003 (P3b) | `gorev_tamamla` (H6 guard), `hizli_uygulama`, `seans_tamamla`, `bulk_ilac`, `start_first_service_protocol` (MK9 gövde düzeltmesi), `create_case`, `vaka_toplu_ac`, `kizginlik_vaka_ac` (C4 kapısı) | CREATE OR REPLACE + eski overload DROP (C2/C5) |
| 20260929000004 (P2c) | `tohumlama_kaydet` | CREATE OR REPLACE (+21/+35 GEBELIK_KONTROL üretimi kaldırıldı; `pg_catalog.jsonb_array_elements` tek-satırlık davranış-aynı niteleme — P2c-DONE sapma notu) |
| 20260929000005 (P2d) | `gorev_log` (DML) | tek-seferlik veri temizliği (fonksiyon değil; idempotent, resmi apply'da koşar) |
| 20261001000001 (P12b) | `_takip_gorev_kur`, `tohumlama_bos_ve_devam` (ERTALE), `vaka_toplu_ac` (geçmiş guard), `kizginlik_vaka_ac` (cases.start_date) | CREATE OR REPLACE — **demo'da yeni, PROD'da ESKİ (CURRENT_DATE'li) gövdeler** |

**2. Tam migration replay sonrası doğrulama gereksinimi (kabul ölçütü):** db-validate replay modunda tam zincir koşturulduğunda `pg_proc`'ta her fonksiyon için **son-kazanan gövde** yukarıdaki tablonun en-alt migration'ı olmalı — özellikle: `tohumlama_kaydet` gövdesi **20260929000004** olmalı (GT eski +21/+35 üretimini taşır → GT kaynaklı replay'de bayat gövde kazanırsa KIRMIZI işaret), `gorev_tamamla` gövdesinde H6 guard (MUAYENE_SONUC_GEREKLI) bulunmalı, P12b'nin 4 fonksiyonunda `Europe/Istanbul` kalıbı bulunmalı, C2 7 RPC'de `to_regprocedure` eski imzalar 7/7 NULL kalmalı. **Kazanmazsa:** ground-truth YENİLEME talebi manifest kapısında (sahip) — bu planda GT DOSYASI DEĞİŞMEZ (plan.md:717 hükmü; talep sahibe aşağıda bırakıldı).

**3. GT eski-kopya uyarısı:** `99999999999999_ground_truth.sql` en az şu noktalarda demo/prod gerçekliğinden ESKİDİR: (a) `tohumlama_kaydet` eski +21/+35 üretimini taşır [CONFIRMED P2c-DONE GT:382-390 notu], (b) P12b'nin 4 fonksiyonunda CURRENT_DATE'li eski gövdeler — **GT karşılaştırma raporunda bu 4 fonksiyondaki demo-farkı BEKLENEN işarettir** (impl-P12b-DONE GT-notu; prod apply edilene kadar), (c) yeni takip nesnelerinin (2 RPC + 4 helper + 3 tetikleyici fonksiyonu) GT'de hiç kaydı yoktur. Replay doğrulaması GT üzerinden DEĞİL, migration zinciri sırasından yapılmalı.

**4. Sahibe GT-yenileme talebi (manifest kapısına bırakıldı):** P12b PROD apply sonrası (ya da sahibin seçeceği kapıda) `99999999999999_ground_truth.sql` yenilenmeli; yenileme öncesi db-validate replay son-kazanan kontrolü koşulmalı (madde 2 ölçütleri).

## domain-rules.md teyidi (yalnız OKU — §18.15-17)

Teyit: domain-rules.md §18.15 (Boş sonrası devam: üç seçenek tek işlemde, TAKIP varsayılan +7, TAKIP_ACIK onay kapanışları, ≥21g onayı, muayene-GEBE düzeltmesi), §18.16 (üreme kategorisi + K14 tip eşlemesi), §18.17 (birleşik sonuç ekranı, sonuçsuz kapanmaz, erteleme yalnız sonuç ekranından + saatsiz varsayılan) — yazdığım doküman girdileriyle **çelişki YOK**; DOKUNMADIM.

## Bilinçli sapmalar / notlar

1. `gebelik_protokol_kontrol` girdisini güncelledim (bayat "21/35. gün üreticisi" notu) — canlı gövde GEBELIK_KONTROL 0 eşleşme [OBSERVED]; §18.13 "tek üretici" hükmüyle tutarlı hale getirildi. Manifest "gebelik_muayene sistemi değişiklikleri" kaleminin kapsamında.
2. Anchor denetiminde HEAD'ten devralınan 3 bayat anchor görüldü, DOKUNULMADI (kapsam dışı): `index.html:m-geri-al`, `js/forms.js:openGeriAl`, `js/forms.js:islemGeriAl` — L4 W2'de SÖKÜLEN yüzeyler; ui-map'in kendi L4 bölümü emekliliği zaten belgeliyor, üstteki router tablosu/forms listesi satırları bayat kalmış (mimar turunda 3 satırlık temizlik).
3. rpc-reference başlığındaki "195 giriş / 189 fiziksel / 185 benzersiz" sayaçları güncellenMEDİ — eski sayımlar 2026-09-03 ölçümüdür; 2 yeni RPC bu bölümde ayrıca belgelendi. Sayaç yenileme ayrı bakım kalemi (tam envanter yeniden sayımı ister).

## Açık kalemler (BLOKE değil)

1. **3 bayat ui-map anchor'ı** (yukarıda sapma 2) — mimar/sahip turunda temizlik.
2. **PROD apply** sahibin kapısında: P12b'nin 4 TZ gövdesi + (sahip kararına göre) P1-P3b zinciri PROD'a uygulanınca GT yenileme (yukarıdaki talep) devreye girer.
3. **rpc-reference sayaç tazeleme** (yukarıda sapma 3) — ayrı bakım kalemi.
4. Demo'da P2d temizliği hâlâ bekliyor (40 eski GEBELIK_KONTROL görevi) — resmi toplu apply'da 20260929000005 koşunca kapanır (P2d-DONE açık kalem 3 aynen).

## Ölçüm komutları (özet)

- psql (demo pooler, .env SUPABASE_DEMO_*, değer basılmadı): `pg_get_function_identity_arguments` ×17 fonksiyon; `has_function_privilege` ×5; `pg_get_functiondef` döküm → `~/tmp/p13-live-*.sql` (bos_ve_devam 487 satır, gorev_tamamla 155 satır, tohumlama_kaydet); trigger listesi `pg_trigger`
- `git diff --check` → temiz (exit 0)
- Anchor denetimi: `tests/harness/test_patterns.py` regex'leriyle 2 dosyanın tüm anchor'ları (yeni eklenenler 100% çözülür; 3 bayat HEAD'ten)
- Taze doğrulamalar: GEBELIK_KONTROL×tohumlama_kaydet=0; TZ×4 fonksiyon=t; `_takip_gorev_kur` TZ=t
