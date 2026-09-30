# DONE — Plan v7 sonrası çalıştırılabilir senaryo testleri (P12 1. adım D7)

**SONUÇ: TAMAM** — beş teslimat üretildi ve koşuldu; kırmızılar beklenen-öncesi olarak AÇIK raporlandı (zarf kuralı: RED PASS SAYILMAZ). İki açık sözleşme (H5 satır-sonucu JSON alanı, Ç3 seans fixture) fail-closed bırakılıp aşağıda kesin bildirildi.

Tarih: 2026-09-29 · Koltuk: glmf-max test lead · Dağıtan: ovsync-takip-codex-devir · Zarf: `runs/2026-09-28-ovsync-takip/test-uygulanabilir-GOREV.md`

## 1. Değişen dosyalar (yalnız zarf yazma listesi)

| Dosya | Durum |
|---|---|
| `docs/plans/2026-09-28-ovsync-takip-ekrani/test-senaryolari.md` (o günkü adı `test-senyolari.md` idi; 2026-09-30'da düzeltildi) | Katalog sürüm 2 — KATALOG GÜNCELLEME 1–17 (git-ignored local path, manifest kapsamında) |
| `tests/sql/ovsync_takip_test.sql` | YENİ — demo DB-SQL + REST probe (S0–S8) |
| `tests/concurrency/ovsync-takip-t72b.mjs` | YENİ — T-72b sonuç-oracle betiği (dış npm dep yok; iki psql bağlantısı) |
| `tests/e2e/ovsync-takip.spec.js` | YENİ — 8 gerçek assertion'lı Playwright temsilcisi |
| `runs/2026-09-28-ovsync-takip/ui-test-listesi.md` | YENİ — glmf-max kapı listesi (25 madde; bu tur PASS YOK, link YOK) |
| `.crumbs/ovsync-takip.jsonl` | 3 satır eklendi (role: lead) |

Commit/dal/merge/push/PROD apply yapılmadı; `.ss/`, ürün kodu, migration, plan, domain-rules, goal dosyaları YAZILMADI. Oturum başında dirty olan dosyalar (`.harness/references/domain-rules.md`, `design.md`, `.ss/ovsync-takip-BOARD.md`, `runs/2026-09-29-akis-atlasi/`) başka oturumlara aittir — dokunulmadı, geri alınmadı.

## 2. Katalog güncelleme 1–17 tablosu

| # | KATALOG GÜNCELLEME kalemi | Uygulanan |
|---|---|---|
| 1 | T-04 K15 tam set | Gebe / Boş→seçici / Ertele varyantları; "TAKIP_MUAYENE ekranıyla AYNI ekran" özdeşliği; S-10 etiketi |
| 2 | T-05 Gebe ekleme | GEBE/Ovsync/PG/Ertele seti (TAKIP hariç — P2b tablosu); S-3/GEBE_BULUNDU; saatsiz ertele |
| 3 | T-39 birleşik ekran | "mevcut gebelik sonuç akışı" → birleşik muayene sonuç ekranı + ertele yolu + S-9/§10d #2 |
| 4 | S-10 kapandı | "Muayene tamam + …" (§10c copy); SPEC SORULARI bölümü kapanış tablosuna çevrildi (açık soru YOK) |
| 5 | T-61 farm_id | §10c #13/D8/C6: predikat+damga YOKLUĞU kanıtı; iki-farm Faz 2 |
| 6 | K15 yeni senaryolar | T-74 (H6 üç-dal guard), T-75 (GK erteleme), T-76 (ekran özdeşliği), T-77 (takipte Gebe), T-78 (GK'da Gebe çekirdek), T-79 (cron entegrasyon), iki-üretici → §10d #1 ile kapanış (T-80/T-81) |
| 7 | Kapsam dışı notu | T-45 "eşik-ortaklığı" → küme-tam eşitlik + ekran entegrasyonu; + B9 ve Faz 2 satırları |
| 8 | İNSAN-UI 12 | K14-uyumlu — değişiklik yok (belirtildi); + 13–15 yeni İNSAN maddeleri |
| 9 | +21/+35 taraması | Beklenti taşıyan T yok; T-44 güçlendirildi; T-80 ("yeni tohumlama → görev doğmaz") + T-81 ("temizlik sonrası çift görev yok") eklendi |
| 10 | T-25/T-26 saat | "saat korunur" → "seçilebilir, VARSAYILAN SAATSİZ" (§10d #3); T-26 ≥21 g tek onay (S-7) |
| 11 | Dashboard 40 g satırı | T-82: açık görev→birleşik ekran; yoksa hayvan detayı (§10d #4) |
| 12 | T-45 (D2) | cooldown'a giren+girmeyen hayvanla iki-yönlü EXCEPT fark=0 |
| 13 | T-61 (D8) | madde 5 ile aynı kalem — predikat/damga yokluğu kanıtı |
| 14 | v4 senaryoları | T-83 (D1 geri-alınma), T-84 (iki satır), T-85 (göreli gün), T-86 (D4 preflight), T-72 güncellendi (MK9 kilit sırası + TOH_SONUCLU) |
| 15 | v5 senaryoları | T-87 (T-72b), T-88 (C1 çözücü üç vaka), T-89 (kizginlik onay), T-90 (C5 PostgREST), T-91 (C6 envanter) |
| 16 | v6→v7 senaryoları | 16a→17a; T-92 (C4 sunucu kapısı, tanıdan bağımsız); 16c→T-90'a işlendi; 16d (MK9-T) kaldırıldı — çift T-87'de |
| 17 | v7 senaryoları | T-87 (T-72b oracle — final 5 çift), T-74 (H6 üç-dal), T-93 (H5 satır-sonucu), T-94 (H8 istemci mesajı) |

Senaryo sayıları: eski T-01..T-73 korundu; **T-74..T-94 = 21 yeni senaryo**; katalog v2 toplam 94 senaryo (ölçüm: `grep -c '^### T-'` = 94, T-95/T-96 yoktu — aritmetik kayma düzeltildi 2026-09-30). Kapsam-açık denetimi (2026-09-30): planın sınamayan kaldığı 6 P2b/P3a sözleşme guard'ı için **T-95..T-100 eklendi → katalog toplam 100 senaryo** (rapor: `runs/2026-09-28-ovsync-takip/katalog-kapsam-DONE.md`). SPEC SORULARI: **açık soru 0** (S-1..S-10 + iki-üretici → kapanış tablosu).

## 3. Test sayıları ve koşum sonuçları (komut + çıkış)

### 3a. `tests/sql/ovsync_takip_test.sql` — demo DB-SQL (psql)
Komut:
```
export PGPASSWORD=… ; psql "postgresql://postgres.vtzqjmazsvurxdeondmi@aws-0-eu-west-1.pooler.supabase.com:5432/postgres" -X -v ON_ERROR_STOP=0 -v ovs_fixture_ok=true -f tests/sql/ovsync_takip_test.sql
```
Sonuç (demo, 2026-09-29 17:3x, fixture'lı): **6 RED(beklenen) + 4 PASS + REST pinleri**
- S1/T-80: **RED(beklenen)** — `tohumlama_kaydet` RPC yolu **2 adet GEBELIK_KONTROL doğurdu** (+21/+35 üretimi demo'da canlı — P2c bekleniyor). İlk koşumdaki doğrudan-INSERT yanlış-PASS'i RPC yoluna çevrilerek düzeltildi.
- S2/T-08, S2/XOR: **RED(beklenen)** — `tohumlama_bos_ve_devam` yok (42883); atomiklik/XOR P2b sonrası sınanır.
- S3/T-19/23: **RED(beklenen)** — tetikleyici yok: `iptal=false, neden=(kolon yok — P2a)`.
- S4 dal1: **RED(beklenen)** — jenerik `gorev_tamamla` muayene görevini sonuçsuz kapattı (guard yok — P3b). dal2 `p_iptal=true` → **PASS**; dal3 SUTTEN_KESME → **PASS** (H6'nın koruyacağı mevcut davranış bugünden yeşil).
- S5/T-93: **RED(beklenen)** — fail-closed (P2a kolonu yok; TAKIP_ACIK satır sözleşmesi açık).
- S6/T-90 ACL: **PASS** — `kizginlik_vaka_ac: anon=false auth=true` [demo ölçüm].
- S7 REST pinler [demo gerçek yanıtları, `~/tmp/ovsync-takip-olcum/`]: 7a olmayan-RPC → **PASS** (HTTP 404 + `PGRST202`); 7c anon → **PASS** (HTTP 401 + `42501 permission denied`); 7b eski-imza+yeni-param → HTTP 404+PGRST202 kaydedildi (**RED beklenen** — C5 DROP'larından sonra eski-imza assertion'ı bu kayda sabitlenir); 7d T-92 iki tanı varyantı → imza red (**RED beklenen** — P3b sonrası `TAKIP_ACIK:*`).
- Fixture temizlik: E2E-TAKIP- kalıntısı **0** (hayvan/tohumlama/görev) — tekrar koşulabilir.
- Salt-okuma modu (`ovs_fixture_ok` olmadan) da koşuldu: senaryolar UNMEASURED düşüyor — kapı çalışıyor.

### 3b. `tests/concurrency/ovsync-takip-t72b.mjs` — T-87/T-72b (demo)
Komut:
```
export T72B_DB_URL='postgresql://postgres.vtzqjmazsvurxdeondmi:…@aws-0-eu-west-1.pooler.supabase.com:5432/postgres'
node tests/concurrency/ovsync-takip-t72b.mjs --rounds=2   # ve --pairs=1 probu
```
Sonuç: envanter doğru ölçüldü (`sarmal=0 takip_kolon=0 tetik=0 disease=1`); **Ç1/Ç2/Ç4/Ç5 RED(beklenen)** — yeni yol yok, N=30 tur koşulmadı (fail-closed); **Ç3 BLOKE** (aşağıda); `SONUÇ: BLOKE`, exit=2. Bağlantı katmanı ölçüldü: iki psql bağlantısı, `SET lock_timeout='5s'` + `statement_timeout='30s'` her oturumda; sonuç protokolü tek-stdout (yarışsız). Fixture temizlik: E2E-T72B- kalıntısı **0**.

### 3c. `tests/e2e/ovsync-takip.spec.js` — Playwright demo
Keşif:
```
NODE_PATH=/home/melik/egesut-erp1/node_modules PLAYWRIGHT_DEMO_MODE=1 \
  /home/melik/egesut-erp1/node_modules/.bin/playwright test tests/e2e/ovsync-takip.spec.js --list
→ 8 tests in 1 file
```
Hedefli kırmızı koşum (host libicu74 eksik → Docker deseni, memory'deki kanıtlanmış yol):
```
docker run --rm --network host -v "$PWD":/work -w /work -v /home/melik/egesut-erp1:/main:ro \
  -e NODE_PATH=/main/node_modules -e PLAYWRIGHT_DEMO_MODE=1 -e HOME=/tmp/pwhome \
  mcr.microsoft.com/playwright:v1.58.2-noble \
  /main/node_modules/.bin/playwright test tests/e2e/ovsync-takip.spec.js --reporter=list --retries=0
→ 8 failed (10.1–10.4s her biri)
```
Kırmızı nedenleri (hepsi ANLAMLI assertion'da — import/launch hatası değil): T-56 → `.dash-row .sc` içinde "Ovsync" **0 hücre** (6. stat hücresi P7 uygulanmadı); diğer 7 → `#pg-ovsync` `.on` olmuyor / seçici-sheet-rozet selector'ları yok (P5–P10 uygulanmadı). **8/8 RED(beklenen); PASS sayılmaz.** PW seed (E2E-TAKIP-PW-) temizliği doğrulandı: kalıntı 0.

### 3d. Ortak
`node --check` → iki JS de OK. `git diff --check` → temiz (çıktı boş). `sonuclar.json` ve başka kullanıcı artefaktına dokunulmadı (koşumlar `--reporter=list`, HTML rapor yazmadı).

## 4. Katman durum özeti (zarf sözlüğüyle)

| Katman | PASS | RED(beklenen) | KISMI | UNMEASURED | FAIL |
|---|---|---|---|---|---|
| SQL (demo DB-SQL) | 4 | 6 | 0 | 0 (fixture'lı koşumda) | 0 |
| REST pin (SQL dosyası içinde) | 2 | 3 | 0 | 0 | 0 |
| T-72b (çift bazında) | 0 | 4 | 0 | 0 (envanter ölçüldü) | 0 (+1 BLOKE) |
| Playwright (demo) | 0 | 8 | 0 | 0 | 0 |

## 5. Açık sözleşmeler (fail-closed — implementasyona girdi)

1. **H5 / rereview5 ÖNEMLİ #2 — TAKIP_ACIK satır sözleşmesi:** `bulk_ilac` ile `vaka_toplu_ac`'ın mevcut dönüş anahtarları farklıdır (ölçüm: `vaka_toplu_ac` → `{ok, toplam, basari, atlanan, hatalar, acilan, sablon, manuel, tohumlama[, toplanti_uygulandi]}` [20260906120000:735-738]). `TAKIP_ACIK` satırının KESİN JSON alanı, onaylı/atlanan/hata kümeleri ve retry'da `p_animal_ids` eşlemesi P3b'de makine-okunur sabitlenmelidir. Betik bugün alan adı VARSAYMAZ — T-93'te "satır işlenmedi" koşulu `acilan`/başarı listelerinde yoklukla sınanır; alan adı pinlenince daraltılır.
2. **H7 / rereview5 ÖNEMLİ #3 — T-72b oracle'ı:** Çift başına İZİNLİ sonlu kümeler betiğe gömüldü (kaynaklı): sarmal (P2b hata sözleşmesi), `tohumlama_kaydet` (VWP/ABORT_VWP), `start_first_service_protocol` (tam red listesi [20260926000002:49-166] + TAKIP_ACIK), `seans_tamamla` (PG_KAPI ailesi), `vaka_toplu_ac` (RAISE yalnız `TAKIP_ONAY_KUME_UYUMSUZ`), tetikleyici yolu (iş hatası beklenmez). Tur raporu biçimi: çift başına histogram `family:OK` / `family: SQLSTATE mesaj(ilk 50)` + lock/timeout/bilinmeyen sayaçları; `40P01`/`55P03`/`57014`/bilinmeyen asla PASS değil. **Ç3 (sarmal × seans_tamamla) fixture sözleşmesi AÇIK:** seans uygulama satırı kurulumu kaynakla kapanamadı (treatment_day_uygulamalar zinciri şablon/sablon bağımlı) → betik koşum için `--seans-uygulama-id <uuid>` ister; verilmezse BLOKE (bugünkü durum).
3. **Ölçüm bulgusu (ürün kararı değil, gözlem):** demo hastalık kataloğunda Ovsync vakasının adı **'Ovsync Protokol'** ('Ovsync' değil). Plan P3a cases tetikleyicisinin ad-çözümü `diseases.name='Ovsync'` yazıyor — demo'da eşleşmez; P3a uygulaması ad-çözümünü demo/prod uyumlu tanımlamalı (gözlem planda `ovsync_disease` envanter satırıyla da görünür).

## 6. Yeni SPEC sorusu

**YOK.** Katalog v2'de açık soru kalmadı (S-1..S-10 + iki üretici kararı kapanış tablosuna işlendi; design §10b/§10c/§10d ile çelişki bulunmadı).

## 7. Sınırlar

- PROD DB'ye erişim yok (tüm koşumlar demo pooler; bağlantı hedefi betiklerde mekanik denetimli: SQL fixture kapısı URL-ref'e bağlı, T-72b `T72B_ALLOW_ANY_HOST` guard'ı).
- Demo sahibi şifresine dokunulmadı, çıktıya basılmadı; demo yazmaları yalnız E2E- marker'lı fixture'lardır ve temizlikleri ölçüldü (kalıntı 0). `islem_log` izleri bilinçli silinmez (log tablosu; demo reset'i toplar — belgeli).
- Commit/merge/push/deploy yok; `.ss/` yazılmadı; LSP/statik typecheck diagnostics temp-tablo gürültüsü dışında temiz.
- B9 (eski-yol kilit denetimi) kapsam dışı — T-72b eski-yol çiftleri prova listesinde yok (§10h H2).
- Playwright koşumu host'ta libicu74 eksikliğinden Docker imajında koşuldu (v1.58.2 — package.json ile aynı); `--list` her iki ortamda da geçti.
- Saat penceresi: koşumlar 13:00 sonrası yapıldı (17:3x–17:5x) — 09:00–13:00 GLM durdurma kuralına takılmadı.
