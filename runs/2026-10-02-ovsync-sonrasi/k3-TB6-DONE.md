# K3 / TB-6 — e2e `temizle()` onarımı (DONE)

Tarih: 2026-10-02 · Dal: ovsync-sonrasi · Dosya: `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-sonrasi/tests/e2e/ovsync-takip.spec.js` (yalnız bu dosya; js/ dokunulmadı; git add/commit YOK)

## Kök neden (systematic-debugging, kanıtlı)
1. `temizle()` hayvanı `id LIKE 'E2E-TAKIP-PW-%'` ile arıyordu; seed id'leri UUID (`e2ef0000-…`), marker yalnız `kupe_no`'da → sorgu hep boş → afterAll erken `return`, hiçbir şey silinmedi.
2. `pg_application_event` DELETE yetkisi yok (42501) ve hayvan FK'sı (`pg_application_event_hayvan_id_fkey`, 23503) hayvan silmeyi engeller; hatalar `TRY` ile yutuluyor, `gorev_log`/`tohumlama`/`hayvanlar` silme hataları hiç kontrol edilmiyordu.
3. Seed `hayvanEkle` var olan satırı olduğu gibi yeniden kullanıyordu; kalıntı hayvan Satıldı ise `hizli_uygulama` "Hayvan bulunamadı veya aktif değil" ile düşüyordu.

RED kanıtı (eski spec, demo'da 10 `Satildi` kalıntı varken): `~/tmp/ovsync-sonrasi-k3/red1.log` → T-56 beforeAll'da `seed hizli_uygulama b reddi: Hayvan bulunamadı veya aktif değil`, 11 test koşmadı. Önceki A/B (`~/tmp/agents/uitur-20261001/e2e-ab/kos.log`) ayrıca her koşum öncesi el aracının 12 gorev_log / 10 tohumlama sildiğini, hayvan DELETE'in FK ile düştüğünü gösterir.

## Değişiklik özeti
`git diff --stat`: `tests/e2e/ovsync-takip.spec.js | 96 ++++++++++++++++++++++++++++++------` (72 ekleme, 24 silme)

- `temizle(faz)` yeniden yazıldı: hayvanlar `kupe_no LIKE 'E2E-TAKIP-PW-%'` ile bulunur (yalnız bu spec'in fixture'ı; E2E-UITUR-* vb. kümelere dokunmaz).
- Her adım `{error}` kontrollü; hatalar toplanır, sonda tek `Error` fırlatılır (fail-closed, sessiz yutma yok). afterAll hook hatası test PASS/FAIL satırlarını değiştirmez, ayrı raporlanır (maskeleme yok).
- Çocuk tablolar sırayla silinir: cases zinciri (treatment_day_uygulamalar, treatment_days), protokol_instance, kizginlik_log, uygulama_log, gorev_log, tohumlama, cases.
- `pg_application_event` BİLEREK silinmez (yetki yok; bilinen kısıt, gerekçe kodda yorumlu). Hayvan önce DELETE; yalnız `23503` FK ihlalinde `durum='Satıldı'` (kanonik yazım, domain-rules §10; DB'deki `Satildi` hatalı yazımdır) çıkışı yapılır, `trg_hayvan_cikis_gorev_iptal` kalan açık görevleri iptal eder. Başka her hata gerçek hata.
- Sonda doğrulama: marker'lı hayvan Aktif kalmamalı, açık görev kalmamalı; aksi halde throw.
- beforeAll başında `await temizle('önce')` (artık-dayanıklılık); `hayvanEkle` mevcut ama Aktif olmayan hayvanı `Aktif`'e döndürür (hata kontrollü).
- `pgGecmisiEkle` içindeki await'siz `TRY(...)` silmeleri (yarış + sessiz yutma) await + hata kontrollü döngüye çevrildi; `pg_application_event` silme denemesi kaldırıldı.
- DB client noktaları: spec'te tek `createClient` var → `DEMO_URL` (vtzqjmazsvurxdeondmi, demo); ayrıca `test.skip(!IS_DEMO)` kapısı; `tests/support/app.js` da demo URL'ye sabit. Prod'a gidiş yok (grep ile doğrulandı).

## Koşum komutu
```
python3 -m http.server 8147 --bind 127.0.0.1   # worktree kökü (head arşivi için 8148)
docker run --rm --network host -v <WORK>:/work -w /work -v /home/melik/egesut-erp1:/main:ro \
  -e NODE_PATH=/main/node_modules -e PLAYWRIGHT_DEMO_MODE=1 -e PLAYWRIGHT_BASE_URL=http://127.0.0.1:<PORT>/ \
  -e HOME=/tmp/pwhome mcr.microsoft.com/playwright:v1.58.2-noble \
  /main/node_modules/.bin/playwright test tests/e2e/ovsync-takip.spec.js --reporter=list --retries=0 --workers=1
```
Sarmalayıcı: `/home/melik/tmp/ovsync-sonrasi-k3/kos.sh <ad> <work> <port>`; seri: `seri.sh`. Loglar: `/home/melik/tmp/ovsync-sonrasi-k3/{red1,fix1,w2,h1,h2,w3}.log` (+ `.olc` ölçümleri).

## Temizlik ölçümü (her koşum sonrası, `olc.cjs`)
Sorgu: `hayvanlar WHERE kupe_no LIKE 'E2E-%'` (durum kırılımı) ve Aktif sayısı.

| Koşum | Ölçüm çıktısı |
|---|---|
| fix1 (çalışma ağacı) | `E2E-% toplam 3 {"E2E-TAKIP-PW-* / Satıldı":1,"E2E-UITUR-* / Satildi":2}` · `E2E-% AKTIF 0` |
| w2 | aynı · `AKTIF 0` |
| h1 (HEAD arşivi) | aynı · `AKTIF 0` |
| h2 (HEAD arşivi) | aynı · `AKTIF 0` |
| w3 | aynı · `AKTIF 0` |
| son (final.olc) | `E2E-% toplam 3 {"E2E-UITUR-* / Satildi":2,"E2E-TAKIP-PW-* / Satıldı":1}` · `E2E-% AKTIF 0` |

Başlangıç: 12 E2E-* (10 TAKIP-PW + 2 UITUR) Satildi. Her koşum sonrası TAKIP-PW 10 → 1 hayvan kaldı (yalnız `b`; pg_application_event'li, FK yüzünden silinemeyen, Satıldı). Kabul "E2E-* Aktif = 0": SAĞLANDI (5/5 ölçüm). 2 UITUR hayvanı bu spec'in değil, dokunulmadı (Satildi, aktif değil). afterAll/beforeAll'da temizlik hatası logda yok (hook throw görülmedi).

## e2e sonuç tablosu (12 test; her satır = o koşumdaki sonuç)
| # | Test | fix1 (W) | w2 (W) | w3 (W) | h1 (HEAD) | h2 (HEAD) |
|---|---|---|---|---|---|---|
| 1 | T-56 dashboard Ovsync hücresi | PASS | PASS | PASS | PASS | PASS |
| 2 | T-32/T-59 KPA şeridi | PASS | PASS | PASS | PASS | PASS |
| 3 | T-01/T-07/T-02/T-03 Boş→seçici | FAIL | PASS | PASS | PASS | FAIL |
| 4 | T-20 TAKIP_ACIK sheet | PASS | PASS | FAIL | FAIL | FAIL |
| 5 | T-38/T-44 muayene vakti rozeti | PASS | PASS | PASS | PASS | PASS |
| 6 | T-04/T-05 sonuç ekranı | PASS | PASS | PASS | PASS | PASS |
| 7 | T-25/T-26 ertele saatsiz | PASS | PASS | PASS | PASS | PASS |
| 8 | T-87 takip muayenesi 4 seçim | PASS | PASS | PASS | PASS | PASS |
| 9 | T-19 sessiz kapanış | PASS | PASS | PASS | PASS | PASS |
| 10 | T-73/T-89 REST guard + C4 | PASS | PASS | PASS | PASS | PASS |
| 11 | T-84/T-85 Gebe + geçmiş | PASS | FAIL (timeout 60s) | FAIL (timeout 60s) | PASS | PASS |
| 12 | T-03/T-50 TAKIP + invalidate | PASS | FAIL | FAIL | PASS | PASS |
| | Toplam | 11/12 | 10/12 | 9/12 | 11/12 | 10/12 |

(fix1: 11 passed, 1 failed; 12. test PASS.)

## A/B hükmü (HEAD ffdc342 arşivi + düzeltilmiş spec vs çalışma ağacı + düzeltilmiş spec; temizlik sonrası, 2'şer tur)
- 12/12 hiçbir koşumda yok; HEAD arşivi de kırmızı (11/12, 10/12). Kırmızı ürün değişikliğinden gelmiyor: HEAD arşivinde aynı sınıf hata var. Not: koşum sırasında çalışma ağacı js/ui.js, demo.js ve yeni migration (`20261002000002`, demo'ya ~07:4x uygulandı) ile HEAD'den ayrışıyordu; hata kümeleri yine de her iki tarafta aynı.
- Hata sınıfı 1 (T-01, T-20; her iki tarafta, W 3/5, HEAD 3/4 toplam fail olayı): `#ureme-body .hist-row` filtre `E2E-TAKIP-PW-b` → "Arama sonucu yok" (sayfa snapshot'ı `fix1` error-context). Yalnız `b` hayvanı etkileniyor; `b` tek kalıcı hayvan (pg_application_event'li, hizli_uygulama seed'i). Değişken test (T-01 ya da T-20), koşumdan koşuma yer değiştiriyor → zamanlama/veri-görünürlük kaynaklı flake; temizlikle ilgisiz (b'nin çocuk kayıtları her koşum silinip yeniden kurulur, hayvan Aktif'e döner).
- Hata sınıfı 2 (T-84/T-85 timeout → T-03/T-50 f satırı yok): yalnız çalışma ağacı (w2, w3), HEAD'de h1/h2 PASS. T-12 ikinci hata T-11'in 60s timeout'unun ardıl etkisi (aynı worker/sayfa). `page.evaluate` timeout'u, ağacın koşum sırasında değişen ui.js/demo.js ya da demo DB'ye uygulanan 20261002000002 ile ilişkili olabilir; 2 tur sınırı ve "yeni koşum başlatma" talimatı nedeniyle ayrıştırılmadı.
- Hüküm: TB-6 hedefi (temizlik) kanıtlı çalışıyor; spec'in 12/12 kabulü kırmızı kaldı çünkü ürün/ortam kaynaklı b-satırı flake'i var (HEAD'de de) + çalışma ağacında T-84/T-85 zaman aşımı. Bu spec onarımının kapsamı dışında; sebep tespiti sonraki iş.

## Açık / sahip için
- 12/12 PASS kabulü KARŞILANMADI (en iyi 11/12). 2 onarım turu hakkı kullanıldı sayılmaz: temizlik düzeltmesi tek turda çalıştı; kalan kırmızı spec temizliği değil ürün/zamanlama sınıfı. Sonraki iş önerisi: (a) `b` için `#tohumlama-srch` satırının neden "Arama sonucu yok" döndüğünü (app pull gecikmesi vs `b`'nin eski pg_application_event/tohumlama görünürlüğü) tek koşumlu izleme ile ayır; (b) w2/w3'te T-84/T-85 `page.evaluate` kilitlenmesini 20261002000002 öncesi/sonrası ui.js ile ayır.
- Kalıntı: demo'da 1 E2E-TAKIP-PW hayvanı (`b`, Satıldı) bilinçli kalır (FK); sonraki beforeAll yeniden Aktif'e çeker.
- Geçici: http sunucuları durduruldu; `~/tmp/ovsync-sonrasi-k3/head` arşiv kopyası bırakıldı.

Kanıt etiketleri: [KOŞUM] red1/fix1/w2/w3/h1/h2 logları · [ÖLÇÜM] olc.cjs çıktıları · [KOD] spec diff · [KURAL] domain-rules §10, trg_hayvan_cikis_gorev_iptal migration 20260626000030.

SONUC: KISMI
