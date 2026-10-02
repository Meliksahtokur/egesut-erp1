VERDICT: DÜZELTME

Salt-okuma plan re-review 3. Checkout: `40feed3c6b1e5da55b44ba998618fdb24a5ee250`.
Ürün kodu, migration, plan, `.ss/` ve canlı veritabanı değiştirilmedi; test veya canlı sorgu
çalıştırılmadı. Değerlendirme plan v5 gövdesi ile mevcut migration/JS kaynaklarının
karşılaştırmasına dayanır.

## (A) C1–C6 kapanışı

| Kalem | Hüküm | Kanıt ve hüküm |
|---|---|---|
| C1 | **KAPANDI** | P2b normatif çözücü `tip/ref_tablo/ref_id`, `snapshot` Boş izi, `durum IS DISTINCT FROM 'geri_alindi'`, `ORDER BY tarih DESC, id DESC LIMIT 1` ve `Europe/Istanbul` yerel günüyle yazılmış (`docs/plans/2026-09-28-ovsync-takip-ekrani/plan.md:310-319`); P9 UI ikizi ve `fmtTarih` yasağı (`:592`), üç kenar testi (`:655`). IDB iddiası kaynakta doğrulanıyor: `islem_log` TABLES içinde ve tam sayfalı `select('*')` ile çekiliyor (`js/api.js:30-35,535-546,658`); `fmtTarih` ham ilk-10 kesimi (`js/utils/helpers.js:58-64`) özel timestamptz tarihleri için dışlanmış. |
| C2 | **KAPANDI** | Üç PG yolu ve vaka yolları için kesin eski→yeni imza tablosu; bulk `p_takip_onaylar text[]`, tekil `p_takip_onay`, altküme guard'ı ve yalnız onaylı kimliklerin `ORDER BY id` ile retry edilmesi yazılmış (`plan.md:400-413`). Stok hesabı `v_success`/uygulanan satırlara bağlanmış ve kabul ölçütü verilmiş (`plan.md:400,436`); mevcut bulk imzası, satır döngüsü ve stok düşümü kaynakta doğrulanıyor (`supabase/migrations/20260923000004_ovsync_pg_uygulama_kapisi.sql:361-441,454-510`). |
| C3 | **KISMİ** | Global değişmez, hayvan-önce MK9 ve T-72b kabul provası gövdede var (`docs/plans/2026-09-28-ovsync-takip-ekrani/plan.md:186,293,436,762`), ancak uyum tablosu mevcut kilit davranışını eksik/koşulsuz özetliyor: `hizli_uygulama` ve `bulk_ilac` “satır kilidi yok” denirken ortak `_pg_kapi` PG yolunda hayvanı `FOR NO KEY UPDATE` kilitliyor (`supabase/migrations/20260923000003_ovsync_pg_yardimcilar.sql:187-205`; çağrılar `supabase/migrations/20260923000004_ovsync_pg_uygulama_kapisi.sql:134,416`); `tohumlama_kaydet` ve `seans_tamamla` hayvan kilidini yalnız bayrak açıkken alıyor (`supabase/migrations/20260923000005_ovsync_vaka_kapanis.sql:323-328`; `supabase/migrations/20260923000004_ovsync_pg_uygulama_kapisi.sql:219-232`). Ayrıca düzeltilen start yolu görev satırını hayvandan hemen sonra kilitleyip daha sonra vaka/seans zincirine giriyor (`docs/plans/2026-09-28-ovsync-takip-ekrani/plan.md:414-418`; mevcut akış `supabase/migrations/20260925000017_start_protocol_fonksiyon_adi.sql:44-62,120-137`), literal “görev son katman” kuralı ve bulk/vaka-toplu çapraz kapsamı açık bir istisna/graph olarak tanımlanmamış. Bayrak kapalı sarmal/start yollarının reddedilmesi planlanmış (`docs/plans/2026-09-28-ovsync-takip-ekrani/plan.md:326`), dolayısıyla doğrudan yeni bir döngü kanıtlanmıyor; fakat kaynak ölçümü ve T-72b kapsamı bu koşullu/yardımcı kilitlerini kapatmıyor. |
| C4 | **KISMİ** | `kizginlik_vaka_ac` imza/gate envanterine, gerçek UI çağrı noktasına ve Playwright kabulüne eklenmiş (`plan.md:411,433,631,636`; UI `js/ui.js:5655-5662,5728-5742`). Ancak trigger yalnız Ovsync hastalık/kaynaklı `cases` INSERT'lerini kapsıyor (`plan.md:381-383`), mevcut RPC ise keyfi `p_tani` ile PG veya serbest tanı hastalığı bulup doğrudan vaka açabiliyor (`supabase/migrations/20260526000002_tohumlama_case_link.sql:15-53`); plan `p_takip_onay=true` dalında kapatmayı söylüyor ama `false` iken sunucu `TAKIP_ACIK` RAISE'ini açıkça şart koşmuyor. Bu nedenle UI testi var, fail-closed authenticated REST yolu kanıtlanmış değil. |
| C5 | **KISMİ** | Yedi imza değişimi için eski imza, yeni imza, DROP/ACL ve negatif test yükümlülüğü tabloya bağlanmış (`plan.md:401-412,432`). Fakat negatif oracleda eski imza çağrısı için `PGRST204` bekleniyor (`plan.md:432,765`); PostgREST stale/missing RPC signature için `PGRST202`/404, `PGRST204` ise bulunamayan `columns` parametresi içindir ([PostgREST hata kodları](https://docs.postgrest.org/en/v16/references/errors.html)). DROP/ACL kapsamı tamam, test kodu düzeltilmeden C5 tam kapanmış sayılamaz. |
| C6 | **KAPANDI (sınırlı)** | P1/P2b dokunan 16 tablo ve tek `farm_id` taşıyan nesne olarak `pg_application_event` envanteri plan gövdesinde ölçüm sonucu olarak verilmiş (`plan.md:152`); `son_pg` okumasında `farm_id = public.current_farm_id()` zorunlu, kolon taşımayan tablolarda predicate/damga yok (`plan.md:241,294`). Kaynak tablo gerçekten `farm_id` ve `(farm_id, hayvan_id, occurred_at)` index'i taşıyor (`supabase/migrations/20260923000002_ovsync_pg_sema.sql:471-499`), §14 retrofit yasağıyla uyumlu (`.harness/references/domain-rules.md:332-353`). Bu tur canlı şema yeniden ölçülmedi; hüküm planın aktardığı demo ölçümüyle sınırlıdır. |

## (B) rereview2 KISMİ/AÇIK satırlarının kapanışı

| Önceki kalem | Hüküm | Güncel kanıt |
|---|---|---|
| D1 | **KAPANDI** | C1 normatif `TOHUMLAMA_SONUC` çözücüsü ve yerel gün dönüşümü P2b/P9/P11'e taşınmış (`plan.md:310-319,592,655`). |
| D4 | **KAPANDI** | Bulk dizi ve tekil scalar onay imzaları, altküme/retry/stok sözleşmesi artık kesin (`plan.md:400-413,436`). |
| D5 | **KISMİ** | Hayvan-önce yön ve start düzeltmesi var (`plan.md:414-431`), fakat C3'teki bayrak koşulları, `_pg_kapi` gizli kilidi ve görev-son-katman/bulk kapsamı açıklığı kapanmadı. |
| Önceki #1 | **KAPANDI** | Dört tablo tetikleyicisi ve üç PG preflight/retry yolu gövdede tanımlı (`plan.md:372-387,400-413`); `kizginlik_vaka_ac` ayrı C4 eksikliği olarak kaldı. |
| Önceki #4 | **KAPANDI** | Birleşik kapı ve bulk satır onayı kesin imza/uygulama sözleşmesine bağlandı (`plan.md:400-413,625-636`). |
| Önceki #9 | **KISMİ** | XOR/yarış kriteri duruyor, fakat lock-order değerlendirmesi C3'teki koşullu ve eksik graph nedeniyle tam kapanmıyor (`plan.md:292-293,414-436`). |
| Önceki #16 | **KISMİ** | `kizginlik_vaka_ac` artık listede, ancak keyfi `p_tani` nedeniyle doğrudan REST fail-closed guard'ı plan gövdesinde kesin değil (`plan.md:411-413,433`; `supabase/migrations/20260526000002_tohumlama_case_link.sql:15-53`). |
| Kalem 11 — D1-UI | **KAPANDI** | İki satır üretimi, aktif/son kayıt seçimi, geri-alınmış dışlama ve İstanbul günü testleri yazılmış (`plan.md:592,655`). |
| #16 kapı listesi | **KISMİ** | UI çağrı noktası ve E2E senaryosu var (`plan.md:631,636`), fakat C4 sunucu kapısı doğrudan REST için tamamlanmamış. |

Özet: önceki satırlar **5 KAPANDI / 4 KISMİ / 0 AÇIK**.

## (C) Yeni bulgular

| # | Şiddet | Plan maddesi | Kanıt | Önerilen düzeltme |
|---:|---|---|---|---|
| 1 | **KRİTİK** | P2a/P2b/P3b — MK9 uyum envanteri ve T-72b | Plan uyum tablosu `hizli_uygulama`/`bulk_ilac` için kilit yok derken `_pg_kapi` hayvan kilitliyor (`docs/plans/2026-09-28-ovsync-takip-ekrani/plan.md:421-430`; `supabase/migrations/20260923000003_ovsync_pg_yardimcilar.sql:202-205`), `tohumlama_kaydet`/`seans_tamamla` kilitleri bayrağa bağlı (`supabase/migrations/20260923000005_ovsync_vaka_kapanis.sql:323-328`; `supabase/migrations/20260923000004_ovsync_pg_uygulama_kapisi.sql:219-232`) ve T-72b yalnız dört yolu sayıyor (`docs/plans/2026-09-28-ovsync-takip-ekrani/plan.md:436,762`). | Her yol için bayrak-açık/kapalı ve ortak-helper dahil gerçek lock graph'ı yazın; `start_first_service_protocol`, `vaka_toplu_ac` onaylı dizi ve bulk/trigger yollarının görev-son-katman istisnasını veya sırasını açıkça belirleyip çapraz iki-oturum provaya ekleyin. |
| 2 | **ÖNEMLİ** | P3b/P10 — `kizginlik_vaka_ac` TAKIP_ACIK kapısı | RPC keyfi tanı ile doğrudan `cases` INSERT ediyor (`supabase/migrations/20260526000002_tohumlama_case_link.sql:15-53`); UI'da `PG Protokolü` ve `Serbest Giriş` var (`js/ui.js:5655-5662,5728-5742`); plan trigger'ı yalnız Ovsync vakaları için tarifliyor (`docs/plans/2026-09-28-ovsync-takip-ekrani/plan.md:381-383`) ve yalnız onaylı kapanışı açıkça yazıyor (`docs/plans/2026-09-28-ovsync-takip-ekrani/plan.md:411-413`). | RPC'nin `p_takip_onay=false` + açık takip dalında sunucu `TAKIP_ACIK` RAISE etmesini, `true` dalında aynı transaction kapanışını ve eski imza/REST negatif DB testini açıkça ekleyin. |
| 3 | **ÖNEMLİ** | P3b/P12 — C5 PostgREST negatif oracle | Plan eski imza çağrısını `PGRST204` bekliyor (`plan.md:432,765`); PostgREST resmi hata tablosunda stale function signature `PGRST202`/404, `PGRST204` column-query hatasıdır. | Negatif testi eski imza için `PGRST202`/HTTP 404 (veya doğrulanmış gerçek response) bekleyecek şekilde düzeltin; yeni imza ve anon EXECUTE negatiflerini ayrı assertion yapın. |

## Ölçüm sınırı

Bu turda yalnızca yerel checkout, plan, migration/JS kaynakları ve zarf girdileri okundu;
migration, canlı DB, test, demo veya deploy çalıştırılmadı. `pg_application_event`/16 tablo
ölçümü plan içinde `[OBSERVED]` olarak aktarılmıştır; canlı şema için bu tur bağımsız PASS
iddiası yoktur. Kalan düzeltmeler yapılmadan plan v5 **KABUL** değildir.
