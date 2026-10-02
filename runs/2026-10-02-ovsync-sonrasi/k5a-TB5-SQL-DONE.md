# K5A — TB-5 SQL ayağı DONE (2026-10-02)

Goal: `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-sonrasi/.harness/goals/2026/G-20261002-OVSYNC-SONRASI-BORC.md` kalem 5 (SQL ayağı; UI ayağı ayrı zarf).
Domain-rules §18.6–18.8, §18.15, §18.17 okundu: çelişki YOK (yeni davranış icat edilmedi; `karar` zaten `_pg_kapi`'nın ürettiği değer).

## 1. Kaynak bulgusu [OBSERVED]
- `_pg_kapi_detay(jsonb,text,text)` canlı demo gövdesi == migration `20260923000004:60-77`; prod (Mgmt API SELECT) gövde md5 = demo md5 = `ac157e9cf078ffd6d22bad3e1fc90565` (özdeş). Çıktıda `karar` anahtarı YOKTU (9 anahtar).
- `_pg_kapi` (canlı demo gövdesi okundu) `karar` üretir: KAPALI | ALLOW | ACK_PENDING | REQUIRE_ACK_PENDING | BLOCK_PREGNANT | BLOCK_CATALOG_UNRESOLVED (+ iç hata `PG_KAPI_IC_HATA`). Tüm birleşik RAISE noktaları yalnız şu 3 blok değerinde tetiklenir, bu yüzden birleşik yükte `pg_kapi.karar` her zaman bu 3 değerden biridir.
- Birleşik `PG_KAPI:TAKIP_ACIK:` RAISE noktaları: `hizli_uygulama` (canlı gövde), `seans_tamamla` (20260929000003:773), `tohumlama_bos_ve_devam` (20261001000001:551), `_pg_kapi_detay` çağıran diğer: `bulk_ilac` blocked/requires_ack satırları (20260929000003:~995-1000).

## 2. `karar` anlam sözleşmesi (yalnız ekleme; yeni iş kuralı YOK)
| değer | üretildiği koşul (`_pg_kapi`) | birleşik yükte görünür mü | önerilen UI metni (mevcut `_takipPgKararEtiket` ile aynı) |
|---|---|---|---|
| `REQUIRE_ACK_PENDING` | ürün PG, son tohumlama `Bekliyor`, onay (`p_pg_onay`) yok | EVET | "Son tohumlama sonucu Bekliyor — PG onayı gerekli" |
| `BLOCK_PREGNANT` | ürün PG, son tohumlama `Gebe` (onay kapıyı AÇMAZ) | EVET | "Gebe inekte PG uygulanamaz" |
| `BLOCK_CATALOG_UNRESOLVED` | ürün PG kataloğuna çözülemiyor (BELIRSIZ: stok yok / ürün yok / PG adlı ama bağsız) | EVET | "Ürünün PG katalog bağı belirsiz" |
| `ACK_PENDING` | PG, Bekliyor, onay VAR | HAYIR (bloklamaz → yalın `TAKIP_ACIK:` döner, `pg_kapi` anahtarı yok) | boş |
| `ALLOW` | PG değil ya da son tohumlama Boş/Doğum Yaptı/Abort/yok | HAYIR | boş |
| `KAPALI` | `ovsync_pg_kurallari_aktif` kapalı | HAYIR | boş |
| `null` | kapıda `karar` yok (NULL/{} girdi) | HAYIR (savunma; anahtar var, değer JSON null) | UI fail-closed "bilinmiyor" (mevcut) |

Not: dispatch metnindeki "Boş ata ve uygula / takibi kapat" sunucu kararı DEĞİL, UI eylemidir (`_pgKapiAc` yalnız `REQUIRE_ACK_PENDING`'de "Boş ata ve uygula" düğmesi çizer; `BLOCK_*` yalnız "Tamam"; birleşik sheet tek onayla takibi kapatır). Sunucu bu eylemleri `karar` ile ADLANDIRMAZ — gerek yoksa değer kümesine eylem eklenmedi (iş kuralı icadı olurdu).

Yan etkiler (hepsi additive): tekil `PG_KAPI:<karar>:<detay>` RAISE'inde detayda da `karar` tekrar eder (önekle aynı, K5A-7); `bulk_ilac` `blocked[]`/`requires_ack[]` satırlarında `karar` = mevcut `kod` (K5A-8); `takip_onay_listesi[].pg_kapi_karar` zaten vardı, değişmedi.

## 3. JS tüketim noktaları (UI ayağı zarfı için; ui.js başka ajanda düzenleniyor, satırlar 2026-10-02 07:3x anlık)
- `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-sonrasi/js/ui.js:3152` `_takipAcikAc` — gövdede `3163-3170`: `_pgk.karar || (pg_kapi_kod önek regex)`; yoksa "Son tohumlama sonucu <sonuc>". **Sunucu `karar`'ı gönderince `_pgk.karar` yolu doğrudan çalışır — UI mantığı zaten hazır.** UI ayağı: (a) 3163-3164 yorumunu "H5: karar YOK" → "karar sunucudan gelir; eski sunucu (N-1) için önek/tohumlama_sonuc yedeği" olarak düzelt, (b) `_takipAcikHata` (`ui.js:3125`, `pg_kapi: pg` 3136) `pg_kapi_kod`'u HİÇ doldurmuyor — `pg_kapi_kod` yedeği ölü; ya kaldır ya hata önekinden doldur (N-1 kararı sahip/mimar), (c) birim test `tests/unit/ovsync-uifix1.test.js:78-95` (K3) `karar`'lı yük senaryosuna genişlet, e2e `tests/e2e/ovsync-takip.spec.js` gerçek sunucu yükünde "💉 PG kapısı: <etiket>" assert'i.
- `ui.js:3066` `_takipPgKararEtiket(karar)` — etiket haritası (3 blok değer); değişiklik gerekmez.
- `ui.js:2160` `_pgKapiAc` (tekil `PG_KAPI:<karar>`, kodu önekten alır) + `ui.js:2228` `_pgKapiHata` (regex `^(PG_KAPI:[A-Z_]+):`) — tekil yol, `karar` gerektirmez. `_pgKapiAc` içinde `kod === 'TAKIP_ACIK'` dalı (~2170): `pgD = detay.pg_kapi` → `_takipAcikAc`'a geçer; `pgD.karar` artık dolu geleceğinden `seans` birleşik yolunda da doğru metin çıkar.
- `ui.js:3273-3274` toplu takip sheet satırı `r.pgKarar` → `_takipPgKararEtiket`; kaynak `js/forms.js:5034` `pgKarar: r.pg_kapi_karar` (bulk_ilac `takip_onay_listesi`, zaten sunucuda var) — değişiklik yok. `js/forms.js:3295` `pgKarar: null` (başka çağrı noktası; sunucu `karar`'ı varsa `pg_kapi.karar`'dan beslenebilir — UI zarfı karar versin).
- `js/api.js:1058` `_pgKapiHata` çağrısı (rpcSeansTamamla sarmalı) — dokunulmaz.

## 4. Migration diff özeti
`/home/melik/.herdr/worktrees/egesut-erp1/ovsync-sonrasi/supabase/migrations/20261002000002_pg_kapi_detay_karar.sql` (yeni, git YOK): `CREATE OR REPLACE FUNCTION public._pg_kapi_detay(jsonb,text,text)` — tek fark `'karar', p_kapi->'karar'` anahtarı eklendi (10 anahtar). İmza/dönüş tipi/`IMMUTABLE SECURITY DEFINER`/`search_path = public, pg_temp`/ACL (postgres + service_role; PUBLIC/anon/authenticated REVOKE) birebir canlı. anon GRANT yok. Rollback: önceki gövde `20260923000004_ovsync_pg_uygulama_kapisi.sql:60-77` (header yorumunda yazılı); anahtarı okuyan UI `_pgk.karar || yedek` olduğundan geri alma N-1 güvenli.

## 5. db-validate
`bash /home/melik/egesut-erp1/scripts/db-validate.sh <migration>` → **PASS** (exit 0). Rapor: `/home/melik/egesut-erp1/reports/db-validation-e98ae410.md` (SHA-256 `e98ae41038acb574a8582c4cb15adb82f52263836e1567bd8c6dd1ce94205322`, taslak = final, dosya sonradan değişmedi). Fazlar: sqlfluff-parse PASS, squawk PASS (2 WARNING: lock_timeout/statement_timeout — CREATE OR REPLACE FUNCTION için gürültü, ERROR yok), şema-uyum PASS, C1 restore+apply+postcheck+RLS+parite PASS. "VERİ UYUŞUMLULUĞU DOĞRULANMADI" (migration veri dokmuyor, C2 koşulmadı). Notlar: (a) worktree'de `.env` yok → script ana checkout'tan koşuldu (aynı betik, diff boş); (b) `egesut-val-pg17` konteyneri durmuştu → `docker start` ile açıldı, iş bitince `docker stop` ile geri durduruldu; (c) rapor ayna uyarısı: yerel ayna F=256, prod F=264 (ayna bayat olabilir — `refresh_lsp_schema.sh` önerilir, bu migration'ı etkilemedi).

## 6. Test + demo prova (`BEGIN … ROLLBACK`, KALICI apply YOK)
`/home/melik/.herdr/worktrees/egesut-erp1/ovsync-sonrasi/tests/sql/ovsync_takip_test.sql` sonuna S9 (K5A) eklendi (yalnız ekleme; mevcut satırlara dokunulmadı). Yapı: saf birim (K5A-0a/0b ön-koşul ACL+definer, K5A-1 6 karar değeri, K5A-2 NULL→json null ters kanıt, K5A-3 eski 9 anahtar+toplam 10, K5A-4 parametre yedeği) + entegrasyon (fixture `E2E-TAKIP-K5A*`, kapı kararı `_pg_kapi`'dan bağımsız ön-koşul okunur): K5A-5 REQUIRE_ACK_PENDING + ters (onaylı → yalın TAKIP_ACIK, `pg_kapi` anahtarı yok), K5A-6 BLOCK_PREGNANT (onaylı bile), K5A-7 takipsiz tekil önek=detay.karar, K5A-8 bulk_ilac `blocked[].karar=kod=pg_kapi_karar`, K5A-9 BLOCK_CATALOG_UNRESOLVED.
- KIRMIZI (migration uygulanmadan, demo, ROLLBACK): `K5A TOPLAM: PASS=3 FAIL=14` (ön-koşullar PASS, karar assert'leri FAIL — testler ayırt edici). Çıktı: `/home/melik/tmp/k5a/red.out`.
- YEŞİL (migration + S9, tek transaksiyon, ROLLBACK): `K5A TOPLAM: PASS=17 FAIL=0`. Çıktı: `/home/melik/tmp/k5a/green.out`.
- Rollback sonrası doğrulama: demo'da `E2E-TAKIP-K5A%` hayvan=0, `E2E-TAKIP-K5A-STOK`=0, `_pg_kapi_detay` gövde md5 yine `ac157e9c…` (canlı değişmedi).
- Koşum: `psql "$DEMO_URL" -X -v ON_ERROR_STOP=0 -v ovs_fixture_ok=true -f <BEGIN;\i migration;S9;ROLLBACK;>` (S9 betiği tek başına da koşar: kendi temp tablosu `_ovs_k5a`).

## 7. Kanıt etiketleri
[OBSERVED] demo/prod gövde md5, ACL, `_pg_kapi` gövdesi, red/yeşil çıktıları, JS grep satırları. [INFERRED] "tüm birleşik RAISE noktaları aynı 3 değerde bloklar" — hizli_uygulama canlı gövdesi + migration kaynağı (seans_tamamla/sarmal canlı gövdesi ayrıca çekilmedi; K5A senaryoları yalnız hizli_uygulama + bulk_ilac'ı çalıştırdı). [UNMEASURED] seans_tamamla ve tohumlama_bos_ve_devam yollarında canlı `pg_kapi.karar` (aynı `_pg_kapi_detay` çağrısı → kod yolu özdeş, ancak SQL testi yok; UI e2e kapsayabilir). Prod: yalnız SELECT yapıldı.

## 8. Açık sahip/mimar soruları
1. `karar` değer kümesi mevcut kapı kararlarıyla sınırlı bırakıldı ("Boş ata ve uygula" gibi eylem adı sunucuda YOK, UI eylemi). Eylem-adlı ayrı alan (`onerilen_eylem`) isteniyorsa yeni iş kuralı/sözleşme kararı — şimdilik gerek görülmedi.
2. UI ayağı N-1 yedeği (`pg_kapi_kod` ölü yol + tohumlama_sonuc metni) kalsın mı, kaldırılsın mı? (PROD apply öncesi eski sunucuya karşı yeni UI senaryosu var mı — Pages UI önce yayınlanabilir; yedek kalması güvenli.)
3. PROD apply sahip kapısı (root talep belgesi). Sıra önerisi: DB (bu migration, yalnız additive) → UI.

SONUC: TAMAM
