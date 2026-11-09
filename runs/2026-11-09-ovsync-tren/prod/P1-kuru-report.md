⟦ss-sub model=opus effort=high rol=ss-worker-high iş=N7 P1 prod kuru ölçüm (salt-okuma): 16 gövde md5, açık doğum sonrası PG, takılı ACIK-DISI, aktif OVSYNC, 12/19 Kas tren dağılımı⟧
sonuc: TAMAM

# N7 P1 — prod kuru ölçüm (SALT-OKUMA) · job j-20261109T190140Z-68caa5

- Ölçüm anı (UTC): `2026-11-09T19:07:25Z` (tek seferde, tüm sorgular art arda koşuldu). Bugün TR = `2026-11-09` (Pazartesi). MEASURED
- Yol: Supabase Management API `POST /database/query`, gövdede `"read_only": true`. İlk prob `current_setting('transaction_read_only') = on` döndü. CONFIRMED
- Yazma yok: INSERT, UPDATE, DELETE, DDL ve RPC çağrısı yapılmadı. Yalnız SELECT, `pg_get_functiondef` ve katalog (`pg_proc`, `information_schema`, `cron.job`, `supabase_migrations.schema_migrations`) okundu. CONFIRMED
- Yan bulgu: `read_only:true` oturumunun rolü `public._ovsync_kural_tarihi` için EXECUTE yetkisine sahip değil (`42501: permission denied for function _ovsync_kural_tarihi`). MEASURED Bu yüzden (c), (d) ve (e)'de STABLE yardımcı fonksiyonları çağırmadım. Gövdelerini (prod `pg_get_functiondef`, bu oturumda okundu) saf SQL'e açtım: `_ovsync_kural_tarihi`, `_acik_disi_ovsync_hedef` → `_acik_disi_hedef_ic`, `_ovsync_asama` (20261110100002:119-148) ve `_ovsync_tren_gunu_ic` formülü (PLAN D2). Saf SQL'in fonksiyonla birebir aynı sonucu verdiği fonksiyon çağrılarak doğrulanamadı. INFERRED

## Önkoşul ölçümü (apply engeli var mı)

| kontrol | sonuç | etiket |
|---|---|---|
| 24 yeni fonksiyon adı (`dogum_sonrasi_pg_hatirlatma`, `_ovsync_*`, `ovsync_tren_*` …) prod'da | **0 satır**, hiçbiri yok (çakışma yok) | MEASURED |
| `cases.ovsync_tren` / `cases.ovsync_bagimsiz` kolonu | **yok** | MEASURED |
| `protokol_ayar` 5 yeni anahtar (`dogum_sonrasi_pg_gorev_aktif`, `ovsync_tren_aktif`, `ovsync_tren_capa`, `ovsync_tren_one_cekme_gun`, `ovsync_pg_erteleme_tolerans_gun`) | **yok**. `ovsync_pg_kurallari_aktif` = 1 | MEASURED |
| `schema_migrations` son 3 kayıt | `20261031200007` (vaka_sablon_pg_kapi), `…200006`, `…200005`. `2026111010%` kaydı **0** | MEASURED |
| pg_cron `ilk-tohumlama-ovsync-baslat` | `0 4 * * *` (UTC) = **07:00 TR**, aktif, `select public.ilk_tohumlama_zamanlayici()` | MEASURED |

Sahip için anlamı: prod temiz başlangıç durumunda; 8 dosya üst üste uygulanabilir, yarım kalmış önceki uygulama yok.

## (a) 16 fonksiyon `md5(prosrc)` = D0 tablosu

Ölçüt D0 ile aynı: `md5(p.prosrc)` + `oid::regprocedure`. Kaynak tablo: `~/.herdr/worktrees/egesut-erp1/ovsync-tren/runs/2026-11-09-ovsync-tren/db/govde-taban.md` "prod md5" sütunu.

| ad | imza | prod md5 (şimdi) | D0 prod md5 | durum |
|---|---|---|---|---|
| `_acik_disi_gorev_kur` | `_acik_disi_gorev_kur(text)` | cb7b8182151602505b48615148592b2a | cb7b8182151602505b48615148592b2a | EŞİT |
| `_acik_disi_hedef_ic` | `_acik_disi_hedef_ic(text)` | 5082fc8884d9ad96a8fa4f16d457c9f5 | 5082fc8884d9ad96a8fa4f16d457c9f5 | EŞİT |
| `_ovsync_baslat_gorev_kur` | `_ovsync_baslat_gorev_kur(text,date,text,date)` | 66e46e679f85afada875808607a28dac | 66e46e679f85afada875808607a28dac | EŞİT |
| `_vaka_ac_tek` | `_vaka_ac_tek(text,uuid,text,date)` | f9be42278a02581ade0f55230ea37aee | f9be42278a02581ade0f55230ea37aee | EŞİT |
| `dogum_kaydet` | `dogum_kaydet(text,date,text,text,text,numeric,text,text)` | 756c56afb83401721521e42e613ab7f9 | 756c56afb83401721521e42e613ab7f9 | EŞİT |
| `gorev_ertele` | `gorev_ertele(uuid,date,time without time zone)` | 2af93dfba299268b912175c628d4b05c | 2af93dfba299268b912175c628d4b05c | EŞİT |
| `ovsync_baslat_uyarilari` | `ovsync_baslat_uyarilari()` | 869dcfef020a01c6446359d13aa988ed | 869dcfef020a01c6446359d13aa988ed | EŞİT |
| `ovsync_hastalik_gunu_ekle` | `ovsync_hastalik_gunu_ekle(uuid,uuid,date,integer,jsonb,boolean,text)` | 1765d756f499e3ecc36740e74a65d804 | 1765d756f499e3ecc36740e74a65d804 | EŞİT |
| `protokol_iptal` | `protokol_iptal(uuid,boolean,text)` | e5487897bf66b1f8f361792cb4bcf74a | e5487897bf66b1f8f361792cb4bcf74a | EŞİT |
| `seans_tamamla` | `seans_tamamla(uuid,boolean,text,boolean,text,boolean)` | 4afb2221a7e95235e754b7ff508d0379 | 4afb2221a7e95235e754b7ff508d0379 | EŞİT |
| `start_first_service_protocol` | `start_first_service_protocol(uuid,boolean)` | 9c7344bbb42e53246f63bcd7999b7525 | 9c7344bbb42e53246f63bcd7999b7525 | EŞİT |
| `tedavi_sablon_uygula` | `tedavi_sablon_uygula(uuid,uuid,date,boolean,text)` | 7cc9e46508c3f4fab10516a5676d026e | 7cc9e46508c3f4fab10516a5676d026e | EŞİT |
| `tohumlama_bos_ve_devam` | `tohumlama_bos_ve_devam(text,uuid,text,text,numeric,integer,time without time zone,text,boolean)` | ba1ba4bb7b870171e190013d7fc090c8 | ba1ba4bb7b870171e190013d7fc090c8 | EŞİT |
| `tohumlama_gorev_ertele` | `tohumlama_gorev_ertele(uuid,date,time without time zone)` | d9b19df7d182ddd33bc67ccab7318b1e | d9b19df7d182ddd33bc67ccab7318b1e | EŞİT |
| `vaka_kalan_gunleri_kaydir` | `vaka_kalan_gunleri_kaydir(uuid,integer)` | 0f6e319096b3905e56df52dc20bdddc4 | 0f6e319096b3905e56df52dc20bdddc4 | EŞİT |
| `vaka_kalan_gunleri_kaydir_coklu` | `vaka_kalan_gunleri_kaydir_coklu(uuid[],integer)` | 09875ad70b8d98bdd87061738355a964 | 09875ad70b8d98bdd87061738355a964 | EŞİT |

**16/16 EŞİT. Uyuşmayan yok, imza da aynı, overload yok (16 ad → 16 satır).** MEASURED
Bu 16 değer, migration'lardaki md5 korumalarıyla (001:19, 003:23-28, 004:26-28, 005:21-25, 006:22) tek tek eşleşiyor. Korumaların toplamı 16 ve hepsi bu ölçümle tutuyor. MEASURED (grep)

Sahip için anlamı: canlı kod, planın üzerine kurulduğu kodla aynı. Uygulama md5 korumasına takılıp geri dönmez.

## (b) 2026-11-09'dan sonra açılmış açık d2/d25/d39 doğum sonrası PG görevleri

Süzgeç prod-uygula ile aynı (`uygula/p5_liste.sql`): `ILAC`, açık, `kaynak LIKE 'DOGUM-%'`, `etken_kod='PG'`, 3 açıklama. Tarih kısıtı koymadım; tüm açık görevleri listeledim.

| küpe | görev id | açıklama | hedef |
|---|---|---|---|
| — | — | — | — |

**0 satır.** Geniş süzgeçle de 0 çıktı: açık `DOGUM-%` görevlerinde `etken_kod='PG'` ya da açıklamada `PG` geçen satır yok. 2026-11-09 TR'den bu yana kaydedilmiş doğum da 0. MEASURED
Yani 07:03Z iptal turundan sonra yeni PG görevi doğmadı. P8 (Faz 0 veri iptali) için iptal edilecek görev yok.

Sahip için anlamı: doğum sonrası PG görevlerinden temizlenecek bir şey kalmadı. P8 boş geçer.

## (c) Eski `ACIK-DISI` anahtar çakışmasıyla takılı, apply sonrası görev doğacak hayvanlar (TR-ANAH-GOC)

Koşul `pg_temp.kb_takili` ile birebir (`supabase/tests/ovsync_tren_kabul.sql:207-212`). Hayvanın eski biçimli `ACIK-DISI-<h>-<kural>` instance'ı var ve hayvan uygun: `_acik_disi_ovsync_hedef` NOT NULL, yani aktif dişi, kısır değil, son tohumlaması Gebe ya da Bekliyor değil, aktif protokol vakası yok, açık `OVSYNC_BASLAT`, senkron ya da `TAKIP_MUAYENE` görevi yok.

| küpe | kural | bugün takılı mı | bayrak 0 hedef | bayrak 1 tren |
|---|---|---|---|---|
| — | — | — | — | — |

**0 satır.** MEASURED Sağlık sayaçları (aynı CTE'ler):

| sayaç | değer |
|---|---|
| `ACIK-DISI-%` instance toplam | 44 |
| bunlardan anahtarı hayvanın şimdiki kural günüyle eşleşen (eski biçim) | 44 |
| uygun (görevsiz, açılabilir) hayvan | 13 |
| uygun ve kural günü geçmiş | 0 |
| aktif dişi | 111 |

44 eski biçimli instance'ın hiçbiri uygun hayvanda değil. Bu hayvanların ya açık `OVSYNC_BASLAT` görevi, ya aktif vakası ya da Gebe/Bekliyor tohumlaması var. Uygun 13 hayvanın eski anahtarı yok (bkz. (e) ek tablo, `eski_anahtar_dolu = false`). MEASURED
Not: bu 44 hayvandan biri ileride Boş sonucu alıp açık-dişi yoluna düşerse, eski kodda anahtar çakışır ve görev açılmaz. R10 anahtarı (`-<son tohumlama id>`) bunu önler. Bu durum geleceğe dönük; bugün takılı hayvan yok. INFERRED

Sahip için anlamı: apply'ın ertesi sabahı 07:00 cron'unda sürpriz görev doğmayacak. Göç etkisi listesi boş.

## (d) Aktif OVSYNC vakaları + D0 + aşama

D0 = hastalık dışı gün#1 (GnRH1 planı, R3/R14 tanımı). Aşama R6 deseni: Y = yapıldı, N = yapılmadı, X = belirsiz.

| küpe | case id | start_date | D0 (GnRH1) | günler | desen | aşama | hastalık günü | PG1 kayma | D0 ritimde (çapa 11-12) | açık TAI |
|---|---|---|---|---|---|---|---|---|---|---|
| 169 | <prod-id> | 2026-11-07 | **2026-11-12** | 11-12 11-19 11-20 11-21 | NNNN | **0** | yok | — | **evet** | 11-22 10:00 |

**1 aktif OVSYNC vakası.** MEASURED

- `belirsiz_asama` listesi: **boş**. Aşaması türetilemeyen aktif OVSYNC vakası yok. MEASURED
- R14 üyelik adayı (P10'da `ovsync_tren` yazılacak): 169 → `2026-11-12`. Etiketi yok, hastalık günü yok, D0 ritimde. INFERRED (formül 008:71-77)
- `start_date` (11-07) ile D0 (11-12) farklı. Bunun nedeni 2026-11-09 prod-uygula turundaki `vaka_kalan_gunleri_kaydir`. Üyelik D0'dan türediği için sonuç değişmez.

Sahip için anlamı: şu an tek Ovsync hayvanı 169. GnRH1 11-12'de henüz yapılmadı. Bayrak açılınca 12 Kasım trenine otomatik bağlanır.

## (e) 2026-11-09..2026-11-26 açık OVSYNC_BASLAT görevleri gün gün + 4 hayvanın durumu

Tren her Perşembe: **11-12 · 11-19 · 11-26** (`to_char` 11-12 = Thu). MEASURED
Formül: R9 `yeni = _ovsync_tren_gunu_ic(GREATEST(kural, eski), 2026-11-12, 2, bugün)`. Bugün 11-09, 11-10 ve 11-11 için ayrı ayrı hesapladım; 25 görevin hepsinde üçü aynı sonucu verdi. MEASURED

### e1. Pencere içi açık `OVSYNC_BASLAT` (gün gün)

| gün | küpe | görev id | hedef | kural günü | R9 yeni (tren) |
|---|---|---|---|---|---|
| 11-09 Pzt … 11-11 Çar | — | — | — | — | — |
| **11-12 Per** | 36 | <prod-id> | 2026-11-12 10:00 | 2026-10-27 | 2026-11-12 (AYNI) |
| **11-12 Per** | 38 | <prod-id> | 2026-11-12 10:00 | 2026-11-04 | 2026-11-12 (AYNI) |
| **11-12 Per** | 5708 | <prod-id> | 2026-11-12 10:00 | **2026-11-14** | 2026-11-12 (AYNI; 2 gün öne çekme) |
| 11-13 … 11-26 | — | — | — | — | — |

Pencerede **3 açık görev** var, üçü de 11-12'de. 11-13..11-26 arasında açık `OVSYNC_BASLAT` yok. Gecikmiş görev (hedef < bugün) de yok. MEASURED

### e2. Pencereye girecek ama bugün görevi henüz doğmamış hayvanlar (uygun, görevsiz)

Kaynak (c)'deki CTE'ler. Bayrak 0'da görev kural günü doğar ve hedefi de kural günüdür (eski yol). Bayrak 1'de görev tren−2 günü doğar ve hedefi tren günüdür (R8).

| küpe | grup | kural günü | bayrak 0: görev/hedef | bayrak 1: tren | bayrak 1: görev doğumu |
|---|---|---|---|---|---|
| 181 | Sağmal | 2026-11-18 Çar | 11-18 (bağımsız başlar) | **11-19** | 11-17 |
| 156 | Sağmal | 2026-11-19 Per | 11-19 | **11-19** | 11-17 |
| 153 | Sağmal | 2026-11-23 Pzt | 11-23 (bağımsız başlar) | **11-26** | 11-24 |

Pencere dışı 10 hayvan: 905 (12-01 → 12-03), 163 (12-04 → 12-03), 903+ (12-07 → 12-10), 142 (12-12 → 12-10), 206 (12-16 → 12-17), 182 (12-19 → 12-17), 155 (12-25 → 12-24), 906 (12-29 → 12-31), 5 (2027-10-24), 9 (2027-11-25). MEASURED

### e3. 12 Kasım'da eski yolla başlayacak 4 hayvanın bugünkü durumu

| küpe | açık Ovsync işi | aktif OVSYNC vaka | diğer açık görev | not |
|---|---|---|---|---|
| 36 (Düve Büyük) | `OVSYNC_BASLAT` 11-12 10:00 · <prod-id> | yok | — | aktif instance `PROTOKOL-IPTAL` (ILK_TOHUMLAMA); tohumlaması yok |
| 38 (Düve Büyük) | `OVSYNC_BASLAT` 11-12 10:00 · <prod-id> | yok | — | aktif instance `PROTOKOL-IPTAL`; tohumlaması yok |
| 5708 (Sağmal) | `OVSYNC_BASLAT` 11-12 10:00 · <prod-id> | yok | E Vitamini 11-16 (<prod-id>), "⚡ 58-63. gün kızgınlık takibi" 11-21 (<prod-id>) | kural 11-14; kızgınlık takibi başlatma anında iptal edilir (prod-uygula raporu, CONFIRMED orada) |
| 169 (Sağmal) | OVSYNC vakası <prod-id>: GnRH1 11-12 10:00 (TEDAVI_GUN <prod-id> / SEANS <prod-id>), PG 11-19, PG2 11-20, GnRH2 11-21 18:00, TAI 11-22 10:00 (<prod-id>) | **var** (aşama 0) | E Vitamini 11-09 (<prod-id>); ayrıca ailesiz aktif vaka <prod-id> (start 09-24) | — |

MEASURED (sorgu e4, 30 satır)

Başlatma mekaniği: pg_cron 07:00 TR `ilk_tohumlama_zamanlayici()` hedefi ≤ bugün olan açık `OVSYNC_BASLAT` görevleri için `start_first_service_protocol(r.id)` çağırır (`ilk_tohumlama_zamanlayici` prod gövdesi satır 100-112). MEASURED
36, 38 ve 5708 bu yüzden 11-12 07:00'de otomatik başlar. `start_first_service_protocol` içindeki erken başlatma kapısı (`v_bugun < hedef_tarih - 2`) kural günüyle değil hedefle çalışır; 5708'in 11-14 kuralı başlatmayı engellemez. MEASURED (prod gövde satır 50-58)

### Hangi hayvan hangi trene

| tren | GnRH1 (D0 treni) | PG1 (D7 treni, aynı gün) |
|---|---|---|
| **2026-11-12 Per** | **36, 38, 169, 5708** (4'lü; P10 kabulündeki grup) | — |
| **2026-11-19 Per** | **181** (kural 11-18 Çar; bayrak açıksa 1 gün bekleyip trene biner), **156** (kural 11-19) | 36, 38, 169, 5708 (PG 11-19) |
| **2026-11-26 Per** | **153** (kural 11-23 Pzt; öne çekme ≤ 2 gün olduğu için 11-19'a binemez, 11-26'yı bekler) | 181, 156 |

Sahibin örneği ("12 kasımdan 2 sonra tren varsa ikisi birleşmeli") prod'da tam olarak **5708**: kural günü 11-14 (12 Kas'tan 2 gün sonra), görevi 11-12'de. R9 onu 11-12'de tutar (AYNI). MEASURED
**Zamanlama bulgusu:** 181'in 11-19 trenine binmesi için bayrak (P10) en geç **2026-11-18 07:00 TR** cron'undan önce açık olmalı. Bayrak kapalıyken 181'in görevi 11-18'de doğar ve aynı gün bağımsız başlar (D0 11-18 ritim dışı, üye olmaz). INFERRED (eski çekirdek `p_kural_tarihi > bugün → NULL` + cron hedef ≤ bugün başlatır; prod gövdeleri)
36, 38, 5708 ve 169 için P10 saati önemsiz: vaka 11-12 07:00'de eski yolla açılsa da D0 = 11-12 ritimde kalır ve R14 onu bayrak açılırken trene bağlar. INFERRED (008:71-77)

Sahip için anlamı: 12 Kasım treninde 36, 38, 169 ve 5708 var. 19 Kasım treninde yeni başlayan 181 ve 156 var, aynı gün ilk dördün PG'si de yapılır. 153, 26 Kasım'a kalır.

## ENGEL

ENGEL: yok. 12 Kasım öncesi N7'ye mani teknik engel görmedim: md5 16/16 tuttu, yeni nesne çakışması yok, migration kaydı temiz, takılı hayvan ve açık PG görevi yok, belirsiz aşama yok. MEASURED

Engel olmayan süreç notları:
- **P9 kuru çağrısı:** `ovsync_tren_yeniden_hedefle(true, …)` Management API'de `read_only:true` ile koşulursa büyük olasılıkla `42501` alır. Ölçüm: aynı rol `_ovsync_kural_tarihi`'yi çalıştıramadı. Yeni fonksiyon yalnız `authenticated`/`service_role`'e GRANT'li. Kuru koşum yetkili rolle `BEGIN … ROLLBACK` içinde yapılmalı. INFERRED
- **P9 sayısı:** PLAN "22 ileri görev" diyor; bugün prod'da **25** açık `OVSYNC_BASLAT` var (6 AYNI + 19 TAŞINIR, hepsinin hedefi ≥ bugün). P9 listesi 25 satır beklemeli. MEASURED (sorgu e)
- **P10 son saat:** 181'in 11-19 trenine binmesi için 2026-11-18 07:00 TR (yukarıda). INFERRED

## Kırıntılar

- measurement: (a) 16/16 md5 = D0. (b) 0. (c) 0 (44 eski instance, 13 uygun hayvan, kesişim 0). (d) 1 vaka (169, aşama 0, D0 11-12). (e) pencerede 3 görev (11-12), 4'lü grup doğrulandı. Kanıt: bu rapor, Run kanıtı.
- assumption: read_only rolünde EXECUTE yok; STABLE yardımcıların gövdeleri saf SQL'e açıldı (gövdeler bu oturumda prod'dan okundu). Fonksiyon çağrısıyla çapraz doğrulama yapılamadı.
- open_item: P9 kuru çağrısı read_only:true ile 42501 riski taşıyor; runbook'ta rol ya da koşum biçimi kararlaştırılmalı.
- open_item: PLAN P9 "22 ileri görev" → bugün 25.

SORU: yok.
progress: P1 tamam; sıradaki adım P2 (root).

BOYUT: bütçe 0 · gerçek 0 · bütçe içinde (salt-okuma ölçüm, kod yok)

## Run kanıtı

Komut biçimi: `q.sh <sql>`. Betik scratchpad'de; kimlik `.env`'den okunur, proje ref'i ve token rapora yazılmadı. `curl POST …/database/query` gövdesi `{"query": <dosya>, "read_only": true}`. Toplu koşum çıktısı (rc ve satır sayısı):

```
r0 rc=0 n=1
a rc=0 n=16
on rc=0 n=5
b rc=0 n=0
b2 rc=0 n=0
c rc=0 n=0
c_sag rc=0 n=1
d rc=0 n=1
e rc=0 n=25
e4 rc=0 n=30
e_gorevsiz rc=0 n=13
cron rc=0 n=9
```
Toplu koşum sonucu, ilk tekil koşumlarla bayt bayt aynı (a, c, d, e, e4, e_gorevsiz için `cmp`). MEASURED
İlk (c) denemesi fonksiyon çağrılı sürümdü. Yanıtı: `{"message":"Failed to run sql query: ERROR:  42501: permission denied for function _ovsync_kural_tarihi\n"}`. Bu sürüm aşağıdaki saf SQL sürümüyle değiştirildi.
Ek katalog okumaları (yalnız `pg_get_functiondef` / `information_schema`): `_acik_disi_gorev_kur`, `_acik_disi_hedef_ic`, `_acik_disi_ovsync_hedef`, `_ovsync_kural_tarihi` (4 satır), `_ovsync_baslat_gorev_kur`, `_ovsync_pg_aktif` (2), `start_first_service_protocol` (1), `ilk_tohumlama_zamanlayici` (1), 8 tablonun kolon listesi (8).

## Sorgu metinleri (birebir) ve satır sayıları

### r0.sql — read_only probu · satır: 1

```sql
-- read_only probu: transaction_read_only = on beklenir
SELECT current_setting('transaction_read_only') AS ro, now() AS simdi_utc, (now() AT TIME ZONE 'Europe/Istanbul')::date AS bugun_tr, version();
```

### a.sql — (a) 16 fonksiyon md5 · satır: 16

```sql
SELECT p.proname, p.oid::regprocedure::text AS imza, md5(p.prosrc) AS md5, p.provolatile
FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
WHERE n.nspname='public' AND p.proname = ANY(ARRAY['dogum_kaydet','_ovsync_baslat_gorev_kur','_acik_disi_gorev_kur','_acik_disi_hedef_ic','ovsync_baslat_uyarilari','protokol_iptal','tohumlama_bos_ve_devam','start_first_service_protocol','tedavi_sablon_uygula','_vaka_ac_tek','gorev_ertele','tohumlama_gorev_ertele','vaka_kalan_gunleri_kaydir','vaka_kalan_gunleri_kaydir_coklu','ovsync_hastalik_gunu_ekle','seans_tamamla'])
ORDER BY p.proname;
```

### on.sql — önkoşul kataloğu · satır: 5

```sql
-- ön kontrol: yeni nesneler prod'da var mı, ayar anahtarları, son migration kaydı
SELECT 'fn' AS tur, p.proname AS ad, p.oid::regprocedure::text AS deger
  FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
 WHERE n.nspname='public' AND p.proname = ANY(ARRAY['dogum_sonrasi_pg_hatirlatma','_ovsync_asama','ovsync_bastan_baslat','_ovsync_gorev_mu','ovsync_hayvan_ertele','_ovsync_ic_ac','_ovsync_ic_mi','_ovsync_kilit_gorev','_ovsync_kilit_vaka','_ovsync_pg1_kayma','ovsync_pg48_tohumla','_ovsync_tren_aktif','_ovsync_tren_ayar','ovsync_tren_ayar_guncelle','ovsync_tren_ertele','ovsync_tren_ertele_onizle','_ovsync_tren_ertele_plan','_ovsync_tren_gunu','_ovsync_tren_gunu_ic','_ovsync_tren_gunu_mu','ovsync_tren_listele','ovsync_tren_onizle','_ovsync_tren_uye_vaka','ovsync_tren_yeniden_hedefle'])
UNION ALL
SELECT 'kolon', column_name, data_type FROM information_schema.columns
 WHERE table_schema='public' AND table_name='cases' AND column_name IN ('ovsync_tren','ovsync_bagimsiz')
UNION ALL
SELECT 'ayar', anahtar, deger::text FROM public.protokol_ayar
 WHERE anahtar IN ('dogum_sonrasi_pg_gorev_aktif','ovsync_tren_aktif','ovsync_tren_capa','ovsync_tren_one_cekme_gun','ovsync_pg_erteleme_tolerans_gun','ovsync_pg_kurallari_aktif')
UNION ALL
SELECT 'mig_son', version, name FROM (SELECT version, name FROM supabase_migrations.schema_migrations ORDER BY version DESC LIMIT 3) s
UNION ALL
SELECT 'mig_2026111010', count(*)::text, '' FROM supabase_migrations.schema_migrations WHERE version LIKE '2026111010%';
```

### b.sql — (b) açık doğum sonrası PG · satır: 0

```sql
-- (b) açık doğum sonrası PG görevleri (p5_liste.sql süzgeci, tarih kısıtı yok; created_at ile ayrılır)
SELECT h.kupe_no, g.id AS gorev_id, g.aciklama, g.hedef_tarih, g.created_at,
       (SELECT max(d.tarih) FROM public.dogum d WHERE d.anne_id = g.hayvan_id) AS son_dogum,
       g.created_at >= '2026-11-09 07:03:14+00' AS iptal_turundan_sonra
  FROM public.gorev_log g JOIN public.hayvanlar h ON h.id = g.hayvan_id
 WHERE g.gorev_tipi = 'ILAC' AND COALESCE(g.tamamlandi,false) = false AND COALESCE(g.iptal,false) = false
   AND g.kaynak LIKE 'DOGUM-%' AND g.etken_kod = 'PG'
   AND g.aciklama IN ('2. Gün PG','25. Gün PG','39. Gün PG (Presynch-14 senkron)')
 ORDER BY g.hedef_tarih, h.kupe_no;
```

### b2.sql — (b) geniş süzgeç + yeni doğumlar · satır: 0

```sql
-- (b) yardımcı: 2026-11-09 TR ve sonrası kaydedilen doğumlar + 'PG' içeren tüm açık DOGUM- görevleri (geniş süzgeç)
SELECT 'dogum' AS tur, h.kupe_no, d.tarih::text AS tarih, d.created_at::text AS created_at, NULL AS aciklama
  FROM public.dogum d JOIN public.hayvanlar h ON h.id = d.anne_id
 WHERE d.created_at >= '2026-11-08 21:00+00' OR d.tarih >= '2026-11-09'
UNION ALL
SELECT 'acik_pg_genis', h.kupe_no, g.hedef_tarih::text, g.created_at::text, g.aciklama
  FROM public.gorev_log g JOIN public.hayvanlar h ON h.id = g.hayvan_id
 WHERE COALESCE(g.tamamlandi,false) = false AND COALESCE(g.iptal,false) = false
   AND g.kaynak LIKE 'DOGUM-%' AND (g.etken_kod = 'PG' OR g.aciklama ILIKE '%PG%')
ORDER BY 1, 3;
```

### c.sql — (c) TR-ANAH-GOC takılı hayvan (saf SQL) · satır: 0

```sql
-- (c) TR-ANAH-GOC / pg_temp.kb_takili koşulu, read_only rolünde fonksiyon EXECUTE yetkisi olmadığından
--     _ovsync_kural_tarihi + _acik_disi_hedef_ic gövdeleri (prod pg_get_functiondef, bu oturum) saf SQL'e açıldı.
WITH p AS (SELECT (now() AT TIME ZONE 'Europe/Istanbul')::date AS bugun, DATE '2026-11-12' AS capa, 2 AS one,
                  COALESCE((SELECT deger FROM public.protokol_ayar WHERE anahtar='ovsync_pg_kurallari_aktif') = 1, false) AS pg_aktif),
k AS (  -- _ovsync_kural_tarihi
  SELECT h.id AS hayvan_id, h.kupe_no, h.grup, h.durum, h.cinsiyet, COALESCE(h.kisir,false) AS kisir,
         CASE WHEN d.md IS NOT NULL OR a.ma IS NOT NULL
              THEN GREATEST(COALESCE(d.md,'-infinity'::date), COALESCE(a.ma,'-infinity'::date)) + 51
              WHEN h.dogum_tarihi IS NULL THEN NULL
              ELSE (h.dogum_tarihi + interval '12 months 21 days')::date END AS kural
    FROM public.hayvanlar h
    LEFT JOIN LATERAL (SELECT max(tarih) md FROM public.dogum WHERE anne_id = h.id) d ON true
    LEFT JOIN LATERAL (SELECT max(abort_tarihi) ma FROM public.tohumlama WHERE hayvan_id = h.id AND sonuc='Abort' AND abort_tarihi IS NOT NULL) a ON true
),
e AS (  -- _acik_disi_ovsync_hedef → _acik_disi_hedef_ic uygunluk
  SELECT k.*, (SELECT t.id FROM public.tohumlama t WHERE t.hayvan_id = k.hayvan_id
                ORDER BY t.tarih DESC NULLS LAST, t.created_at DESC NULLS LAST LIMIT 1) AS son_toh_id,
         (SELECT t.sonuc FROM public.tohumlama t WHERE t.hayvan_id = k.hayvan_id
                ORDER BY t.tarih DESC NULLS LAST, t.created_at DESC NULLS LAST LIMIT 1) AS son_sonuc
    FROM k
),
u AS (
  SELECT e.* FROM e CROSS JOIN p
   WHERE p.pg_aktif AND e.durum = 'Aktif' AND e.cinsiyet = 'Dişi' AND NOT e.kisir
     AND e.son_sonuc IS DISTINCT FROM 'Gebe' AND e.son_sonuc IS DISTINCT FROM 'Bekliyor'
     AND NOT EXISTS (SELECT 1 FROM public.cases c WHERE c.animal_id = e.hayvan_id AND c.status='active' AND c.protocol_family IS NOT NULL)
     AND NOT EXISTS (SELECT 1 FROM public.gorev_log g WHERE g.hayvan_id = e.hayvan_id AND g.gorev_tipi='OVSYNC_BASLAT'
                       AND COALESCE(g.tamamlandi,false)=false AND COALESCE(g.iptal,false)=false)
     AND NOT EXISTS (SELECT 1 FROM public.gorev_log g WHERE g.hayvan_id = e.hayvan_id AND g.gorev_tipi IN ('ILAC','TOHUMLAMA_HAZIRLIK')
                       AND COALESCE(g.tamamlandi,false)=false AND COALESCE(g.iptal,false)=false
                       AND (g.kaynak ILIKE '%senkron%' OR g.aciklama ILIKE '%senkron%'))
     AND NOT EXISTS (SELECT 1 FROM public.gorev_log g WHERE g.hayvan_id = e.hayvan_id AND g.gorev_tipi='TAKIP_MUAYENE'
                       AND COALESCE(g.tamamlandi,false)=false AND COALESCE(g.iptal,false)=false)
     AND e.kural IS NOT NULL
)
SELECT u.kupe_no, u.hayvan_id, u.grup, pi.durum AS instance_durum, pi.created_at::date AS instance_tarih, u.kural,
       u.kural <= p.bugun AS bugun_takili, u.son_sonuc,
       EXISTS (SELECT 1 FROM public.protokol_instance x WHERE x.kaynak_ref =
               'ACIK-DISI-' || u.hayvan_id || '-' || u.kural::text || '-' || COALESCE(u.son_toh_id::text,'0')) AS yeni_anahtar_dolu,
       GREATEST(u.kural, p.bugun) AS bayrak0_hedef,
       (GREATEST(u.kural - p.one, p.bugun) + (((p.capa - GREATEST(u.kural - p.one, p.bugun)) % 7) + 7) % 7) AS bayrak1_tren
  FROM u JOIN public.protokol_instance pi ON pi.kaynak_ref = 'ACIK-DISI-' || u.hayvan_id || '-' || u.kural::text
  CROSS JOIN p
 ORDER BY u.kural, u.kupe_no;
```

### c_sag.sql — (c) sağlık sayaçları · satır: 1

```sql
-- (c) sağlık sayaçları: aynı CTE'ler
-- (c) TR-ANAH-GOC / pg_temp.kb_takili koşulu, read_only rolünde fonksiyon EXECUTE yetkisi olmadığından
--     _ovsync_kural_tarihi + _acik_disi_hedef_ic gövdeleri (prod pg_get_functiondef, bu oturum) saf SQL'e açıldı.
WITH p AS (SELECT (now() AT TIME ZONE 'Europe/Istanbul')::date AS bugun, DATE '2026-11-12' AS capa, 2 AS one,
                  COALESCE((SELECT deger FROM public.protokol_ayar WHERE anahtar='ovsync_pg_kurallari_aktif') = 1, false) AS pg_aktif),
k AS (  -- _ovsync_kural_tarihi
  SELECT h.id AS hayvan_id, h.kupe_no, h.grup, h.durum, h.cinsiyet, COALESCE(h.kisir,false) AS kisir,
         CASE WHEN d.md IS NOT NULL OR a.ma IS NOT NULL
              THEN GREATEST(COALESCE(d.md,'-infinity'::date), COALESCE(a.ma,'-infinity'::date)) + 51
              WHEN h.dogum_tarihi IS NULL THEN NULL
              ELSE (h.dogum_tarihi + interval '12 months 21 days')::date END AS kural
    FROM public.hayvanlar h
    LEFT JOIN LATERAL (SELECT max(tarih) md FROM public.dogum WHERE anne_id = h.id) d ON true
    LEFT JOIN LATERAL (SELECT max(abort_tarihi) ma FROM public.tohumlama WHERE hayvan_id = h.id AND sonuc='Abort' AND abort_tarihi IS NOT NULL) a ON true
),
e AS (  -- _acik_disi_ovsync_hedef → _acik_disi_hedef_ic uygunluk
  SELECT k.*, (SELECT t.id FROM public.tohumlama t WHERE t.hayvan_id = k.hayvan_id
                ORDER BY t.tarih DESC NULLS LAST, t.created_at DESC NULLS LAST LIMIT 1) AS son_toh_id,
         (SELECT t.sonuc FROM public.tohumlama t WHERE t.hayvan_id = k.hayvan_id
                ORDER BY t.tarih DESC NULLS LAST, t.created_at DESC NULLS LAST LIMIT 1) AS son_sonuc
    FROM k
),
u AS (
  SELECT e.* FROM e CROSS JOIN p
   WHERE p.pg_aktif AND e.durum = 'Aktif' AND e.cinsiyet = 'Dişi' AND NOT e.kisir
     AND e.son_sonuc IS DISTINCT FROM 'Gebe' AND e.son_sonuc IS DISTINCT FROM 'Bekliyor'
     AND NOT EXISTS (SELECT 1 FROM public.cases c WHERE c.animal_id = e.hayvan_id AND c.status='active' AND c.protocol_family IS NOT NULL)
     AND NOT EXISTS (SELECT 1 FROM public.gorev_log g WHERE g.hayvan_id = e.hayvan_id AND g.gorev_tipi='OVSYNC_BASLAT'
                       AND COALESCE(g.tamamlandi,false)=false AND COALESCE(g.iptal,false)=false)
     AND NOT EXISTS (SELECT 1 FROM public.gorev_log g WHERE g.hayvan_id = e.hayvan_id AND g.gorev_tipi IN ('ILAC','TOHUMLAMA_HAZIRLIK')
                       AND COALESCE(g.tamamlandi,false)=false AND COALESCE(g.iptal,false)=false
                       AND (g.kaynak ILIKE '%senkron%' OR g.aciklama ILIKE '%senkron%'))
     AND NOT EXISTS (SELECT 1 FROM public.gorev_log g WHERE g.hayvan_id = e.hayvan_id AND g.gorev_tipi='TAKIP_MUAYENE'
                       AND COALESCE(g.tamamlandi,false)=false AND COALESCE(g.iptal,false)=false)
     AND e.kural IS NOT NULL
)
SELECT
 (SELECT count(*) FROM public.protokol_instance WHERE kaynak_ref LIKE 'ACIK-DISI-%') AS acik_disi_instance_toplam,
 (SELECT count(*) FROM public.protokol_instance pi JOIN k ON k.hayvan_id=pi.hayvan_id WHERE pi.kaynak_ref = 'ACIK-DISI-'||k.hayvan_id||'-'||k.kural::text) AS eski_anahtar_guncel_kural,
 (SELECT count(*) FROM u) AS uygun_hayvan,
 (SELECT count(*) FROM u CROSS JOIN p WHERE u.kural <= p.bugun) AS uygun_kural_gecmis,
 (SELECT count(*) FROM e WHERE e.durum='Aktif' AND e.cinsiyet='Dişi') AS aktif_disi;
```

### d.sql — (d) aktif OVSYNC vakaları + aşama · satır: 1

```sql
-- (d) aktif OVSYNC vakaları: D0 (hastalık-dışı gün#1 = GnRH1 planı), start_date, gün deseni, aşama (R6/_ovsync_asama
--     gövdesi 20261110100002:119-148 saf SQL'e açık), hastalık günü, PG1 kayma (R18), ritim (çapa 2026-11-12) ve R14 üyelik adaylığı
WITH p AS (SELECT (now() AT TIME ZONE 'Europe/Istanbul')::date AS bugun, DATE '2026-11-12' AS capa),
s AS (
  SELECT u.treatment_day_id, count(*) AS n,
         count(*) FILTER (WHERE u.uygulama_tamamlandi_at IS NOT NULL) AS uygulandi,
         count(*) FILTER (WHERE u.uygulama_tamamlandi_at IS NULL AND COALESCE(u.uygulanmadi,false)) AS uygulanmadi,
         max(u.uygulama_tamamlandi_at) AS son_uyg
    FROM public.treatment_day_uygulamalar u GROUP BY u.treatment_day_id
),
g AS (
  SELECT c.id AS case_id, d.id AS day_id, d.treatment_date, d.day_no, s.son_uyg,
         CASE WHEN COALESCE(d.tamamlandi,false) AND s.n > 0 AND (s.uygulandi = s.n OR (s.uygulandi = 0 AND s.uygulanmadi = 0)) THEN 'Y'
              WHEN s.n > 0 AND s.uygulandi = 0 AND (NOT COALESCE(d.tamamlandi,false) OR s.uygulanmadi > 0) THEN 'N'
              ELSE 'X' END AS durum,
         row_number() OVER (PARTITION BY c.id ORDER BY d.treatment_date, d.day_no) AS sira
    FROM public.cases c
    JOIN public.treatment_days d ON d.case_id = c.id AND d.disease_id IS NULL
    LEFT JOIN s ON s.treatment_day_id = d.id
   WHERE c.status = 'active' AND c.protocol_family = 'OVSYNC'
),
k AS (
  SELECT case_id, count(*) AS gun_sayisi, string_agg(durum, '' ORDER BY treatment_date, day_no) AS desen,
         string_agg(to_char(treatment_date,'MM-DD'), ' ' ORDER BY treatment_date, day_no) AS gunler,
         min(treatment_date) FILTER (WHERE sira = 1) AS gun1,
         min(treatment_date) FILTER (WHERE sira = 2) AS gun2,
         max(son_uyg) FILTER (WHERE sira = 1) AS gun1_son_uyg
    FROM g GROUP BY case_id
)
SELECT h.kupe_no, c.id AS case_id, c.start_date, k.gun1 AS d0, k.gunler, k.desen,
       CASE WHEN k.gun_sayisi <> 4 THEN NULL WHEN k.desen='NNNN' THEN 0 WHEN k.desen='YNNN' THEN 1 WHEN k.desen LIKE 'YY__' THEN 2 END AS asama,
       EXISTS (SELECT 1 FROM public.treatment_days d WHERE d.case_id = c.id AND d.disease_id IS NOT NULL) AS hastalik_gunu,
       CASE WHEN k.desen IN ('YNNN') OR k.desen LIKE 'YY__' THEN
         k.gun2 - (COALESCE((k.gun1_son_uyg AT TIME ZONE 'Europe/Istanbul')::date, k.gun1) + 7) END AS pg1_kayma,
       ((k.gun1 - p.capa) % 7 + 7) % 7 = 0 AS d0_ritimde,
       (SELECT string_agg(to_char(t.hedef_tarih,'MM-DD') || COALESCE(' '||to_char(t.hedef_saat,'HH24:MI'),''), ', ' ORDER BY t.hedef_tarih)
          FROM public.gorev_log t WHERE t.hayvan_id = c.animal_id AND t.gorev_tipi = 'TOHUMLAMA_PLANLI'
           AND NOT COALESCE(t.tamamlandi,false) AND NOT COALESCE(t.iptal,false)) AS acik_tai
  FROM public.cases c JOIN public.hayvanlar h ON h.id = c.animal_id
  LEFT JOIN k ON k.case_id = c.id CROSS JOIN p
 WHERE c.status = 'active' AND c.protocol_family = 'OVSYNC'
 ORDER BY k.gun1 NULLS FIRST, h.kupe_no;
```

### e.sql — (e) tüm açık OVSYNC_BASLAT + R9 yeni · satır: 25

```sql
-- (e) tüm açık OVSYNC_BASLAT görevleri: hedef, kural (_ovsync_kural_tarihi saf SQL), R9 yeni hedef
--     yeni = _ovsync_tren_gunu_ic(GREATEST(kural, eski), capa 2026-11-12, one_cekme 2, bugün) — P9/P10 günü bugün=11-09/10/11 için
WITH k AS (
  SELECT h.id AS hayvan_id,
         CASE WHEN d.md IS NOT NULL OR a.ma IS NOT NULL
              THEN GREATEST(COALESCE(d.md,'-infinity'::date), COALESCE(a.ma,'-infinity'::date)) + 51
              WHEN h.dogum_tarihi IS NULL THEN NULL
              ELSE (h.dogum_tarihi + interval '12 months 21 days')::date END AS kural
    FROM public.hayvanlar h
    LEFT JOIN LATERAL (SELECT max(tarih) md FROM public.dogum WHERE anne_id = h.id) d ON true
    LEFT JOIN LATERAL (SELECT max(abort_tarihi) ma FROM public.tohumlama WHERE hayvan_id = h.id AND sonuc='Abort' AND abort_tarihi IS NOT NULL) a ON true
),
x AS (
  SELECT h.kupe_no, h.grup, g.id AS gorev_id, g.hedef_tarih AS eski, g.hedef_saat, g.kaynak, g.created_at, k.kural,
         GREATEST(k.kural, g.hedef_tarih) AS taban
    FROM public.gorev_log g JOIN public.hayvanlar h ON h.id = g.hayvan_id LEFT JOIN k ON k.hayvan_id = g.hayvan_id
   WHERE g.gorev_tipi = 'OVSYNC_BASLAT' AND NOT COALESCE(g.tamamlandi,false) AND NOT COALESCE(g.iptal,false)
)
SELECT x.kupe_no, x.grup, x.gorev_id, x.eski, x.hedef_saat, split_part(x.kaynak,'-',1)||'-'||split_part(x.kaynak,'-',2) AS kaynak_tur, x.kural,
       to_char(x.eski,'Dy') AS gun_adi,
       ((x.eski - DATE '2026-11-12') % 7 + 7) % 7 = 0 AS eski_ritimde,
       (SELECT GREATEST(x.taban - 2, b) + (((DATE '2026-11-12' - GREATEST(x.taban - 2, b)) % 7) + 7) % 7
          FROM (SELECT DATE '2026-11-09' AS b) q) AS yeni_b1109,
       (SELECT GREATEST(x.taban - 2, b) + (((DATE '2026-11-12' - GREATEST(x.taban - 2, b)) % 7) + 7) % 7
          FROM (SELECT DATE '2026-11-10' AS b) q) AS yeni_b1110,
       (SELECT GREATEST(x.taban - 2, b) + (((DATE '2026-11-12' - GREATEST(x.taban - 2, b)) % 7) + 7) % 7
          FROM (SELECT DATE '2026-11-11' AS b) q) AS yeni_b1111
  FROM x ORDER BY x.eski, x.kupe_no;
```

### e4.sql — (e) 4 hayvan durumu · satır: 30

```sql
-- (e) 4 hayvan (36/38/169/5708) bugünkü durum: hayvan, açık görevler, aktif vakalar, aktif protokol_instance, son tohumlama
SELECT 'hayvan' AS tur, h.kupe_no, h.grup || ' · ' || h.durum || ' · kisir=' || COALESCE(h.kisir,false)::text || ' · tohumlama_durumu=' || COALESCE(h.tohumlama_durumu,'-') AS bilgi, NULL::date AS tarih, NULL::text AS id
  FROM public.hayvanlar h WHERE h.kupe_no IN ('36','38','169','5708')
UNION ALL
SELECT 'acik_gorev', h.kupe_no, g.gorev_tipi || ' · ' || left(g.aciklama, 60) || COALESCE(' · '||to_char(g.hedef_saat,'HH24:MI'),''), g.hedef_tarih, g.id::text
  FROM public.gorev_log g JOIN public.hayvanlar h ON h.id = g.hayvan_id
 WHERE h.kupe_no IN ('36','38','169','5708') AND NOT COALESCE(g.tamamlandi,false) AND NOT COALESCE(g.iptal,false)
UNION ALL
SELECT 'aktif_vaka', h.kupe_no, COALESCE(c.protocol_family,'-') || ' · start ' || c.start_date::text, c.start_date, c.id::text
  FROM public.cases c JOIN public.hayvanlar h ON h.id = c.animal_id
 WHERE h.kupe_no IN ('36','38','169','5708') AND c.status = 'active'
UNION ALL
SELECT 'aktif_instance', h.kupe_no, pi.alttip || ' · ' || split_part(pi.kaynak_ref,'-',1)||'-'||split_part(pi.kaynak_ref,'-',2), pi.baslangic, pi.id::text
  FROM public.protokol_instance pi JOIN public.hayvanlar h ON h.id = pi.hayvan_id
 WHERE h.kupe_no IN ('36','38','169','5708') AND pi.durum = 'aktif'
UNION ALL
SELECT 'son_tohumlama', h.kupe_no, COALESCE(t.sonuc,'-'), t.tarih, t.id::text
  FROM public.hayvanlar h JOIN LATERAL (SELECT * FROM public.tohumlama t WHERE t.hayvan_id = h.id ORDER BY t.tarih DESC NULLS LAST, t.created_at DESC NULLS LAST LIMIT 1) t ON true
 WHERE h.kupe_no IN ('36','38','169','5708')
ORDER BY 2, 1, 4;
```

### e_gorevsiz.sql — (e) görevsiz uygun hayvanlar · satır: 13

```sql
-- (e) ek: uygun, açık OVSYNC_BASLAT'ı olmayan (görevsiz) hayvanlar — görev ne zaman doğar, hangi trene düşer
--     (c) ile aynı CTE'ler (_ovsync_kural_tarihi + _acik_disi_hedef_ic saf SQL)
WITH p AS (SELECT (now() AT TIME ZONE 'Europe/Istanbul')::date AS bugun, DATE '2026-11-12' AS capa, 2 AS one,
                  COALESCE((SELECT deger FROM public.protokol_ayar WHERE anahtar='ovsync_pg_kurallari_aktif') = 1, false) AS pg_aktif),
k AS (  -- _ovsync_kural_tarihi
  SELECT h.id AS hayvan_id, h.kupe_no, h.grup, h.durum, h.cinsiyet, COALESCE(h.kisir,false) AS kisir,
         CASE WHEN d.md IS NOT NULL OR a.ma IS NOT NULL
              THEN GREATEST(COALESCE(d.md,'-infinity'::date), COALESCE(a.ma,'-infinity'::date)) + 51
              WHEN h.dogum_tarihi IS NULL THEN NULL
              ELSE (h.dogum_tarihi + interval '12 months 21 days')::date END AS kural
    FROM public.hayvanlar h
    LEFT JOIN LATERAL (SELECT max(tarih) md FROM public.dogum WHERE anne_id = h.id) d ON true
    LEFT JOIN LATERAL (SELECT max(abort_tarihi) ma FROM public.tohumlama WHERE hayvan_id = h.id AND sonuc='Abort' AND abort_tarihi IS NOT NULL) a ON true
),
e AS (  -- _acik_disi_ovsync_hedef → _acik_disi_hedef_ic uygunluk
  SELECT k.*, (SELECT t.id FROM public.tohumlama t WHERE t.hayvan_id = k.hayvan_id
                ORDER BY t.tarih DESC NULLS LAST, t.created_at DESC NULLS LAST LIMIT 1) AS son_toh_id,
         (SELECT t.sonuc FROM public.tohumlama t WHERE t.hayvan_id = k.hayvan_id
                ORDER BY t.tarih DESC NULLS LAST, t.created_at DESC NULLS LAST LIMIT 1) AS son_sonuc
    FROM k
),
u AS (
  SELECT e.* FROM e CROSS JOIN p
   WHERE p.pg_aktif AND e.durum = 'Aktif' AND e.cinsiyet = 'Dişi' AND NOT e.kisir
     AND e.son_sonuc IS DISTINCT FROM 'Gebe' AND e.son_sonuc IS DISTINCT FROM 'Bekliyor'
     AND NOT EXISTS (SELECT 1 FROM public.cases c WHERE c.animal_id = e.hayvan_id AND c.status='active' AND c.protocol_family IS NOT NULL)
     AND NOT EXISTS (SELECT 1 FROM public.gorev_log g WHERE g.hayvan_id = e.hayvan_id AND g.gorev_tipi='OVSYNC_BASLAT'
                       AND COALESCE(g.tamamlandi,false)=false AND COALESCE(g.iptal,false)=false)
     AND NOT EXISTS (SELECT 1 FROM public.gorev_log g WHERE g.hayvan_id = e.hayvan_id AND g.gorev_tipi IN ('ILAC','TOHUMLAMA_HAZIRLIK')
                       AND COALESCE(g.tamamlandi,false)=false AND COALESCE(g.iptal,false)=false
                       AND (g.kaynak ILIKE '%senkron%' OR g.aciklama ILIKE '%senkron%'))
     AND NOT EXISTS (SELECT 1 FROM public.gorev_log g WHERE g.hayvan_id = e.hayvan_id AND g.gorev_tipi='TAKIP_MUAYENE'
                       AND COALESCE(g.tamamlandi,false)=false AND COALESCE(g.iptal,false)=false)
     AND e.kural IS NOT NULL
)
SELECT u.kupe_no, u.grup, u.kural, to_char(u.kural,'Dy') AS gun_adi, u.son_sonuc,
       EXISTS (SELECT 1 FROM public.protokol_instance pi WHERE pi.kaynak_ref = 'ACIK-DISI-'||u.hayvan_id||'-'||u.kural::text) AS eski_anahtar_dolu,
       u.kural AS bayrak0_gorev_dogar_ve_hedef,
       (GREATEST(u.kural - p.one, p.bugun) + (((p.capa - GREATEST(u.kural - p.one, p.bugun)) % 7) + 7) % 7) AS bayrak1_tren,
       (GREATEST(u.kural - p.one, p.bugun) + (((p.capa - GREATEST(u.kural - p.one, p.bugun)) % 7) + 7) % 7) - 2 AS bayrak1_dogum
  FROM u CROSS JOIN p
 ORDER BY u.kural, u.kupe_no;
```

### cron.sql — pg_cron işleri · satır: 9

```sql
SELECT jobid, jobname, schedule, active, left(command, 200) AS command FROM cron.job ORDER BY jobid;
```

