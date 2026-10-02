# Plan RE-review 2 — plan v4

VERDICT: DÜZELTME

Salt-okuma review. Kapsam yalnız D1–D8, önceki 7 KISMİ kapanışı ve zarfın yeni
kalemleri 11/12 ile #16/D8/D5 nokta kontrolleridir. Plan, kaynak kod ve mevcut
migration'lar karşılaştırıldı; ürün kodu, plan, `.ss/` veya katalog dosyası
değiştirilmedi.

## (A) D1–D8 ve önceki 7 KISMİ kapanış

| Kalem | Hüküm | Plan v4 gövdesi ve bağımsız kanıt |
|---|---|---|
| D1 | **KISMİ** | Özel Boş→Gebe çekirdeği, beş koşul, yan-etki tablosu, audit ve ACL yazılmış (`docs/plans/2026-09-28-ovsync-takip-ekrani/plan.md:277-305`). Ancak `bos_atama_tarihi` yalnız `TOHUMLAMA_SONUC` `tarih` alanına bağlanmış (`:287,290,532`); `islem_log.tarih` gerçekte `timestamptz`, `durum` ise geri-alınabilir durum alanıdır (`supabase/migrations/20260306000006_faz1_core.sql:105-117`). Aktif kayıt seçimi/status filtresi ve İstanbul yerel tarih normalizasyonu çekirdek/UI sözleşmesinde yok. |
| D2 | **KAPANDI** | S2 için beş predicate ve 30 günlük tamamlanmış görev cooldown'ı plan gövdesinde birebir yazılmış (`plan.md:217,226`); otorite fonksiyonunun aynı koşulları kaynakta mevcut (`supabase/migrations/20260925000002_sessiz_siniflandirma.sql:305-320`). |
| D3 | **KAPANDI** | Görev tipine bağlı seçim kümeleri DB ve UI için açıkça ayrılmış; GEBELIK_KONTROL'de TAKIP var, TAKIP_MUAYENE'de yok (`plan.md:276,497`); senkron testi de DB CASE–JS çıktısını kilitliyor (`plan.md:594`). |
| D4 | **KISMİ** | Üç PG yolu ve bulk satır-onayı planlanmış (`plan.md:371-376,572-576`), fakat bulk için satır-seçimli retry parametresi/imzası tanımlı değil; mevcut `bulk_ilac` p_pg_onaylar dizisiyle çalışıyor (`supabase/migrations/20260923000004_ovsync_pg_uygulama_kapisi.sql:361-441,457-495`), plan ise tüm fonksiyonlara scalar `p_takip_onay` ekliyor (`plan.md:372`). |
| D5 | **AÇIK** | Plan sabit `tohumlama → hayvanlar → gorev_log` sırası emrediyor (`plan.md:247,274`), fakat mevcut `tohumlama_kaydet` önce hayvanı kilitleyip sonra tohumlama satırlarını `FOR UPDATE` kilitliyor (`supabase/migrations/20260923000005_ovsync_vaka_kapanis.sql:323-328,369-374`); `start_first_service_protocol` görev→hayvan (`supabase/migrations/20260925000017_start_protocol_fonksiyon_adi.sql:44-62`), seans yolu hayvan→seans (`supabase/migrations/20260923000004_ovsync_pg_uygulama_kapisi.sql:215-232`). Planın “deadlock önleme” hükmü mevcut çağrı grafiğiyle doğrulanmıyor. |
| D6 | **KAPANDI** | İki mevcut test dosyasının ve yeni test dosyasının manifestteki güncellemesi, kırmızı→yeşil sırası ve K14 testleri plan gövdesine taşınmış (`plan.md:461-472,588-596`). |
| D7 | **KAPANDI** | Katalog güncellemesi P12’nin ilk adımı yapılmış ve katalog hizalanmadan P12/P13 PASS yasağı açık (`plan.md:611-615,751-766`). Dosyanın fiilen yazılması uygulama koltuğunun sonraki işidir; plan yetki/gate açığını kapatıyor. |
| D8 | **KAPANDI** | Ölçülen sekiz mevcut tabloda kolon yoksa damga/predikat eklememe kararı §14 ile uyumlu (`plan.md:134,222,239-246`; `.harness/references/domain-rules.md:332-353`). Ancak bu karar `pg_application_event` gibi farm_id taşıyan nesnelere genellenemez; sınır C-6'da açık. |
| Önceki #1 | **KISMİ** | Dört tablo tetikleyicisi ve idempotensi yazılmış (`plan.md:350-358`), fakat D4'ün üç PG preflight/retry sözleşmesi eksik kaldığı için tüm kapanış yolları henüz kapanmış sayılmaz (`plan.md:371-376`). |
| Önceki #3 | **KAPANDI** | Muayene yolunda Boş kaydı düzeltmeye özel çekirdek, beşli yetki koşulu ve genel `tohumlama_sonuc_gebe` Bekliyor-only sınırı yazılmış (`plan.md:277-290,302-305`); mevcut genel guard'ın Boş'u reddettiği kaynakta da açık (`supabase/migrations/20260830000031_gebe_sonuc_mesaji.sql:21-27`). D1-UI tarih izi ayrı bir kısmi kalemdir. |
| Önceki #4 | **KISMİ** | Birleşik kapı ve tek retry hedefi yazılmış (`plan.md:296,371,565-573`), ancak bulk satır onayının taşınacağı parametre ve eski/yeni RPC imzalarının kesin geçişi yok. |
| Önceki #5 | **KAPANDI** | GEBELIK_KONTROL'ün TAKIP seçimi ve TAKIP_MUAYENE'nin TAKIP'i reddetmesi açık tabloyla yazılmış (`plan.md:276,497`); test matrisi bunu ayrıca kilitliyor (`plan.md:594`). |
| Önceki #9 | **AÇIK** | XOR, `FOR UPDATE` ve yarış kabulü yazılmış olsa da D5 sırası mevcut hayvan→tohumlama ve görev→hayvan yollarıyla çelişiyor (`plan.md:273-274`; kaynak kanıtı yukarıdaki D5 satırında). |
| Önceki #13 | **KAPANDI** | §14 kararı mevcut, farm_id'siz tabloları retrofit etmiyor ve P1/P2a damgasını kaldırıyor (`plan.md:134,222,239-246`). `pg_application_event` istisnası ayrı tutulmalıdır. |
| Önceki #16 | **KISMİ** | Ölçüm sonrası `create_case` ve `vaka_toplu_ac` kapı listesine alınmış (`plan.md:136,372-373,571-576`), fakat `kizginlik_vaka_ac` keyfi tanı ile doğrudan `cases` INSERT ediyor ve plan bunu yalnız notla dışarıda bırakıyor (`supabase/migrations/20260526000002_tohumlama_case_link.sql:15-53`). Gerekçe, Ovsync/PG'yi sunucu tarafında dışladığını kanıtlamıyor. |

## (B) Yeni eklenenler

| Yeni kalem | Hüküm | Kanıt ve gerekçe |
|---|---|---|
| Kalem 11 — D1-UI | **KISMİ** | İki satır, tahmini doğumun Gebe satırından hesaplanması ve IDB `islem_log` kaynağı yazılmış (`plan.md:290,532,595`). Offline kaynak gerçekten mevcut: `islem_log` IDB store'u tanımlı ve tam sayfalı çekiliyor (`js/api.js:30-35,535-546,658`). Buna rağmen `timestamptz → Europe/Istanbul` tarih dönüşümü, `durum='geri_alindi'` dışlaması ve birden çok `TOHUMLAMA_SONUC` içinden aktif/son kaydın seçimi yazılmamış; mevcut `fmtTarih` ham ilk 10 karakteri kesiyor (`js/utils/helpers.js:58-64`). |
| Kalem 12 — UI-R1 | **KAPANDI** | Saf helper, yerel takvim günü, ileri tarih ve gece yarısı/UTC sınır testleri ile aynı render noktasına bağlama açık (`plan.md:539-554`; test sınırları `:549`). |
| #16 kapı listesi | **KISMİ** | `create_case` ve `vaka_toplu_ac` listede (`plan.md:372,571`), fakat `kizginlik_vaka_ac` doğrudan keyfi `p_tani` ile vaka açıyor; UI'da hem “PG Protokolü” hem serbest giriş var (`js/ui.js:5655-5662,5734-5742`). Bu yolun Ovsync/PG açamayacağı ölçülmeden kapsam dışı bırakılması makul değil. |
| D8 / §14 kararı | **KAPANDI (sınırlı)** | Farm_id'siz mevcut sekiz tabloya damga/predikat eklememe kararı §14'e uygun (`plan.md:134,222`; domain-rules `:332-353`). Farm_id taşıyan `pg_application_event` ayrı nesnedir (`supabase/migrations/20260923000002_ovsync_pg_sema.sql:471-499`); planın “hiçbir CTE'de predikat yok” ifadesi bu nesneye taşınmamalı. |

## (C) Yeni bulgular

| # | Şiddet | Plan maddesi | Kanıt | Önerilen düzeltme |
|---:|---|---|---|---|
| 1 | **ÖNEMLİ** | P2b/P9/P9b — D1-UI kayıt izi | `plan.md:287,290,532,546,551`; `js/utils/helpers.js:58-64`; `supabase/migrations/20260306000006_faz1_core.sql:105-117`; Boş audit üretimi `supabase/migrations/20260924000001_ovsync_pg_r32_acik_disi.sql:549-560` | D1 resolver'ı `ref_tablo/ref_id/tip` ile eşleyip `durum IS DISTINCT FROM 'geri_alindi'`, `ORDER BY tarih DESC, id DESC` ve Europe/Istanbul yerel tarih dönüşümünü normatif kılmalı; hem iki satırın görünen tarihi hem göreli gün testi bu normalize edilmiş tarihten beslenmeli. |
| 2 | **ÖNEMLİ** | P3b/P10 — D4 bulk retry | `plan.md:371-376,572-576`; mevcut bulk imzası ve scalar/array ayrımı `supabase/migrations/20260923000004_ovsync_pg_uygulama_kapisi.sql:361-441,457-495` | Bulk için seçilen hayvan kimliklerini ve PG/TAKIP onaylarını taşıyan kesin `p_takip_onaylar`/JSON sözleşmesi tanımlanmalı; retry yalnız bu kimlikleri aynı transaction'da uygulamalı ve stok hesabı aynı listedeki başarılı satırlardan türetilmeli. |
| 3 | **KRİTİK** | P2a/P2b/P3b — D5 global kilit sırası | Plan `plan.md:247,274`; mevcut ters/başka sıralar `supabase/migrations/20260923000005_ovsync_vaka_kapanis.sql:323-328,369-374`, `supabase/migrations/20260925000017_start_protocol_fonksiyon_adi.sql:44-62`, `supabase/migrations/20260923000004_ovsync_pg_uygulama_kapisi.sql:215-232` | Tüm aynı-hayvan çağrılarını tek lock-order sözleşmesine göre yeniden düzenlemeli veya ortak per-animal advisory lock kullanmalı; `tohumlama_kaydet`, planlı wrapper, start protocol ve seansla çapraz iki-oturum deadlock provası eklenmeli. |
| 4 | **ÖNEMLİ** | P3b/P10 — #16 `kizginlik_vaka_ac` | Plan dışlama gerekçesi `plan.md:372-373`; keyfi tanı ile doğrudan INSERT `supabase/migrations/20260526000002_tohumlama_case_link.sql:15-53`; PG/serbest UI seçenekleri `js/ui.js:5655-5662` | Bu RPC kapı envanterine eklenmeli veya sunucuda Ovsync/PG hastalıklarını kesin reddeden allowlist uygulanmalı ve her iki durumda TAKIP_ACIK/tek onay davranışı test edilmelidir. |
| 5 | **ÖNEMLİ** | P3b/P10 — `p_takip_onay` imza geçişi | Plan `plan.md:372`; önceki imza değişimlerinde eski overload'ların DROP edilmesi `supabase/migrations/20260923000004_ovsync_pg_uygulama_kapisi.sql:84-89,193-195,359-361`; `create_case`/toplu vaka drop ve grant'ları `supabase/migrations/20260906120000_vaka_toplu_ac.sql:250-286,749` | Her değişen RPC için eski PostgreSQL imzası DROP edilmeli veya eski wrapper yeni kapıya yönlendirilmeli, eski ACL'ler kapatılmalı ve PostgREST'in overload belirsizliği/kapı bypass'ı negatif test edilmelidir. |
| 6 | **ÖNEMLİ** | P1/P2b — D8 farm_id kapsamı | Planın geniş iddiası `plan.md:134,163,222`, PG kaynağına açıkça referans `:114-116,275`; `pg_application_event.farm_id` ve farm index'i `supabase/migrations/20260923000002_ovsync_pg_sema.sql:471-499` | P1/P2b'nin dokunduğu tabloların tam envanteri çıkarılmalı; farm_id taşıyan `pg_application_event` okumaları `public.current_farm_id()` ile filtrelenirken kolon taşımayan mevcut tablolara predicate/damga eklenmemelidir. |

## Ölçüm sınırı

Bu tur salt-okumadır; migration, canlı DB, test veya demo yürütülmedi. D8'in
önceki demo ölçümü plan içinde aktarılan kanıttır; canlı şema bu turda bağımsız
yeniden ölçülmedi ve bu nedenle canlı deployment/schema PASS iddiası yoktur.
