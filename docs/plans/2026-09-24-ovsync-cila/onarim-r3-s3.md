# ONARIM R3 — S3 spec/plan kanıt yeniden-doğrulama kaydı (2026-09-24)

- **Tetik:** reviewer 3. tur FAIL. Workflow'tan bulgu listesi gelmedi (`BULGULAR: undefined`) → tüm kanıt iddiaları
  onarım ajanınca repodan + canlı demo şemasından tek tek yeniden doğrulandı (S5 lane'inin `onarim-r3.md`
  sözleşmesiyle aynı yöntem).
- **Yetki zarfı:** yalnız bu dizindeki dosyalara yazıldı (spec-s3.md, plan-s3.md, bu kayıt); koda dokunulmadı.
- **Yöntem:** satır iddiaları `grep -n/sed -n` ile repo-düzeyi; canlı iddialar ana checkout `.env`'indeki
  `SUPABASE_DEMO_REF`/`SUPABASE_DEMO_POOLER`/`SUPABASE_DEMO_DB_PASSWORD` ile psql salt-okunur sorgular
  (2026-09-24 23:10-23:30). Prod'a hiçbir bağlantı açılmadı. `supabase_migrate` MCP'sine dokunulmadı
  (S5-R3/B3: prod hedefli).

## 1. Kesinleşen bulgular (onarımda işlendi)

| # | Bulgu | Kanıt | İşlem |
|---|---|---|---|
| F1 | **R1 veri çapası sürüklenmiş:** demo `cases.protocol_family` **NULL ×132** (`IS NOT NULL` = 0 satır); 168/186'nın aktif case'leri durur (`f90731be`/`b284807a`, status='active') ama pf boş → R1 canlıda **0** döner. 168/186 MK3 son tohumlama `'Doğum Yaptı'` (2025-09-12/2025-10-29) → **R2 de yakalamaz**; beklenen koşum 30 kayıt, 168 (`5fe2ef8b`)/186 (`65012b75`) açık kalır | OBSERVED psql-demo 23:15-23:20 | spec §2+K20/K21, V-1 veri-uyarısı, §6 çift-senaryo taban (30/32), U-6, E-6; plan §0, 0c-d maddesi, 0f sentetik R1 kanıtı (geri-alımlı demo UPDATE), Adım 4 iki senaryo, Adım 5 T-A3/T-A5, 6d, 7c(6) |
| F2 | **Demo'da pg_cron YOK:** `pg_extension` boş, `cron` şeması yok; `cron.job` "relation does not exist". Spec K18'in "OBSERVED cron.job" etikiti demo'da yeniden üretilemez; cron semantiği PROD'a ait; demo'da yeniden üretim vektörü ELLE `sessiz_hayvanlar_reconcile()` çağrısı | OBSERVED psql-demo 23:15 | spec K18/K21 rewrite, §4.1/§4.7, V-4, E-1; plan 0b, 6a, 7c(7: cron maddesi kaldırıldı), §10 E-1 |
| F3 | **Demo `schema_migrations` bayat:** üst `20260706052550` (repo 20260924'te); ham `psql -f` apply kayıt YAZMAZ → plan 0b'nin "S1/S2 version görünüyor mu?" kapısı demo'da **asla** geçmez | OBSERVED psql-demo 23:10 | spec §4.1 davranışsal kanıt birincil (K22, E-7); plan 0b rewrite (S1: `_acik_disi_hedef_ic` → NULL; S2: `sessiz_hayvanlar_listele` default **55**→50 + `v_eligible` Bekliyor-hariç) |
| F4 | **`_trg_gorev_parent_kapandi` cascade (OBSERVED):** kapanan görevin çapraz-tip açık çocuklarını `kapatan_ref='parent-kapandi'` ile kapatır; KISIR kümesinde her SEANS aynı tarihli GUN'ün çocuğu (12 çift) → eski `ORDER BY` ile çocuk önce tetikle kapanıp RPC'nin `onceki` snapshot'ı yalan söyleyebilirdi; ayrıca `gorev_log_cycle_guard` INSERT-only, `trg_gorev_asip_iade` hedef tiplerde no-op, `trg_degisim_log` yalnız `degisim_log` tablosuna yazar (islem_log değil); `cases.trg_kizginlik_case_close` yalnız active→closed'ta yan yazar | OBSERVED pg_get_functiondef + parent_id sorgusu 23:20 | spec §5.1 taslak KISIR-B `ORDER BY g.hayvan_id, g.gorev_tipi DESC, g.id` + **D-2** tasarım notu, V-3 INFERRED→OBSERVED (K23/K24), T-A3 tetik-gürültü notu; plan 0e KOŞULDU, Adım 1 D-2 kaydı, §10 E-8 |
| F5 | **`SUPABASE_DEMO_DB_URL` diye ortam değişkeni YOK** (ana checkout `.env` grep=0); plan 0b/4a bu değişkeni kullanıyordu. Gerçek: `SUPABASE_DEMO_REF`+`SUPABASE_DEMO_POOLER`+`SUPABASE_DEMO_DB_PASSWORD`; çalışan psql kalıbı onarımda bizzat kullanıldı | CONFIRMED grep + OBSERVED (bağlantı kuruldu) | plan Adım 2 env kalıbı, Adım 3 (4a), §10 E-3 |
| F6 | **Spec/plan taban tutarsızlığı:** spec §6 "KISIR_GOREV = 24 (184/199/208 × 8)" diyordu; canlı 27 (24 TEDAVI + 3 TOHUMLAMA_PLANLI `113c327f`/`9c3c7180`/`af9dd507`) — plan D-1 doğruydu | OBSERVED 23:15 | spec §6 Rev-2 taban (27; K15 zenginleştirildi: kısır 6 hayvan +115/204/185) |
| F7 | **rpc-reference Sessiz imza drift (kesişim notu):** canlı `sessiz_hayvanlar_listele(p_padok text DEFAULT NULL, p_min_gun integer DEFAULT 55)`; rpc-reference.md:523 "(p_min_gun?, p_padok?)" yazıyor. S-3 planı 4b'de yalnız YENİ bölüm ekler; mevcut satırlara dokunma kuralı korunur — drift S-2/S-lane kapsamına aittir | OBSERVED pg_get_functiondef 23:25; CONFIRMED rpc-reference:523 | bilgi notu olarak bu kayıtta; plan 4b'ye dokunulmadı (mevcut-metin dokunulmazlığı zaten var) |
| F8 | **`20260925*` migration dosyası bugün hiç YOK** (S1/S2/S5 henüz dosya yazmamış; S2 spec'i revert için `…000002` de istiyor) → 0d "kullanılmayan en düşük numara" kuralı doğru ve gerekli; beklenen örnek `…00004` geçerli | CONFIRMED `ls supabase/migrations/` + spec-s2:164 + plan-s5 | plan 0d tazelendi (S2-revert kanıtı eklendi) |

## 2. Doğrulanıp DEĞİŞMEYEN iddialar (birebir teyit)

- Repo satır çapaları: `20260923000003` :34 (`_tohumlama_pencere`), :540 (`tohumlama_gorev_ertele`), :562-563 (tip kilidi), :585-618 (ilk-hedef + audit) — K1/K2 ✓. `js/ui.js` :1009/:1058/:1168/:1259 — K3 ✓. `js/api.js` :44-52 (`_ERR_MAP`, `GOREV_ERTELENEMEZ`/`GECMIS_TARIH` yok) — K4 ✓. `js/config.js` :195/:203 (`TOHUMLAMA_PENCERELERI`/`pencereYuvarla`) — K5 ✓. `js/forms.js` :2901 (`hayvan_tohumlama_ertele`) — K6 ✓. `20260625000020` :15-56/:80 (üretici + cron.schedule) — K7 ✓. `20260831000002` :34-35 (yalnız Gebe hariç; eşik 55) — K8 ✓. `20260924000001` :262-279 muafiyet, :299-300/:334 (ACIK-DISI anahtar) — K9/K10 ✓. `20260603000001` :13 (`kapatan_ref`) — K19 ✓. `.gitignore` :98-99 (`.env`), :122 (`reports/`) ✓. `BUGS.md` :183 (`BUG-ERTELEME-KURAL-GENEL [open/borç]`) ✓. rpc-reference "Sessiz Hayvan (2026-08-31 güncel)" :521 ✓.
- Canlı veri çapaları (psql-demo 23:15): K13 birebir (3 açık SESSIZ görev, kapatan_ref=NULL, hedef 2026-09-24) ✓; K11 fonksiyon seti birebir (`ureme_temizlik_reconcile`/`gorev_ertele` YOK; diğer 6 VAR) ✓; K12 `protokol_ayar` = 10 satır ✓; K17 `TOHUMLAMA_ERTELE`=0, `PROTOKOL_AYAR`=2 ✓; `protokol_instance_kaynak_unique` constraint adı canlı ✓; KISIR_INSTANCE=2 (`5570df8f`/`9bc82033`) ve kısır 6 hayvan kümesi ✓; 188 `0818cd2e` İLAÇ görevi açık-dokunulmaz ✓; kısır hayvanlarda açık OVSYNC_BASLAT YOK ✓; SESSIZ vet görevlerinin ve TOHUMLAMA_PLANLI'ların açık çocuğu YOK (cascade hedef-küme dışına çıkmaz) ✓.
- S2 henüz uygulanmamış (default 55 + yalnız-Gebe-hariç) → E-1 bekleme durumu halen geçerli; S-3 koşumu S1+S2 apply'ından sonra.

## 3. ENGEL durumu

- **ENGEL (kalıcı değil, kayıt):** F1 — R1 pf veri-borcu: koşumu ENGELLEMEZ (birinci senaryo 30 kayıtla koşulur,
  0f kanıtı kuralı doğrular); kalıcı çözüm sahibin U-6 kararına (pf backfill mi, klon-borcu kaydı mı) bağlıdır.
- E-1 bekleme kapısı halen AÇIK (S1+S2 demo apply'sız onaylı koşum yapılmaz) — planın öngördüğü gibi.
- Zarf B borç: dokunulmadı (`BUGS.md:183` açık; spec §8 tasarım kaydı hazır).
- Diğer lane'lerin WIP'i (BUGS.md, spec-s2/s4/s5, plan-s4, taslak-s2-migration.sql çalışma-ağacı değişiklikleri)
  bu onarıma DAHİL EDİLMEDİ; commit yalnız S-3 dosyalarını kapsar.

## 4. Sıradaki adım

Implementasyon kulvarı planın Rev-2 haliyle koşmaya hazır: Adım 0 (0a indeks; 0b davranışsal E-1; 0c taze ölçüm +
pf sayacı; 0d numara; 0e TAMAM-kaydı; 0f sentetik R1) → Adım 1 (D-1+D-2'li migration) → Adım 2 (db-validate, env
kalıbıyla) → Adım 3 (demo apply + rpc-reference girdisi + commit) → Adım 4 (dry-run; 30/32 senaryo ayrımı raporda)
→ Adım 5 (onaylı koşum) → Adım 6 (T-A4/T-A6/T-A7 + parity) → Adım 7 (zarf + son review kapısı + analyze).
