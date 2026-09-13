---
id: W1-surum-gecmisi-f1-f2-db
goal: G-20260913-SURUM-GECMISI
branch: agent/surum-gecmisi-diff-W1
task: .ss/tasks/W1-surum-gecmisi-f1-f2-db.md
date: 2026-09-13
db: demo only (ref vtzqjmazsvurxdeondmi) — PROD'a hiç bağlanılmadı, PROD'a hiç yazılmadı
---

# W1 — Sürüm geçmişi F1 (kayıt) + F2 (geri alma motoru) — DB Teslim Raporu

## Özet

Demo DB'ye 3 migration uygulandı ve tüm kabul kriterleri canlı demo üzerinde
koşularla PASS edildi:

| Migration | İçerik | Blob SHA |
|---|---|---|
| `supabase/migrations/20260913000001_surum_gecmisi_f1_degisim_log.sql` | `degisim_log` tablosu + immutability (UPDATE/DELETE/TRUNCATE reddi) + generic AFTER trigger + 39 tabloya attach + drift-temizlik + identity-PK guard + 3 indeks | `ea3a8bd193bf777ccafb68a80d8f89e90bfde97d` |
| `supabase/migrations/20260913000002_surum_gecmisi_f2_geri_alma.sql` | pgcrypto, `surum_gizli` şeması (şifre/bilet/kullanım, default-privs kilitli), `geri_alma_bileti_al`, `degisim_listele`, `degisim_onizle`, `degisim_geri_al` + plan (topolojik EKLE sırası) /uygula/kilit-sarmalı iç yardımcıları | `e4344d8ba4e4b5631f629fbe7e57b4bc39f98eb3` |
| `supabase/migrations/20260913000003_surum_gecmisi_f2_sahip_sifresi.sql` | `sahip_sifresi_ayarla` (yalnız service_role; hash migration'a yazılmaz) | `3c5a468ed0060cdca9093c166613c11ab070f728` |

Test kanıtları `reports/2026-09-13-surum-gecmisi-W1/` altında betik + ham çıktı:

| Dosya | Kapsam | Sonuç |
|---|---|---|
| `k1_iud_log.sql` / `.out` | Kabul 1: 39 tabloda I/U/D + içerik-değişmez UPDATE + kaynak damgası + tek txid | **156/156 PASS** |
| `k1b_immutability.sql` / `.out` | Kabul 1: degisim_log UPDATE/DELETE/TRUNCATE reddi, **red-before** + rol ACL'leri | tüm redler kanıtlandı |
| `k2_txid_yuk.sql` / `.out` | Kabul 2: 100 satır tek tx → tek txid; trigger yükü ölçümü | PASS + sayılar aşağıda |
| `k3_geri_alma.sql` / `.out` | Kabul 3: bilet akışı, 3 seviye revert, revert-in-revert, çakışma, bağımlılık, composite PK, cascade revert | **43/43 PASS** |

Komutlar: `psql "host=$SUPABASE_DEMO_POOLER ... user=postgres.$SUPABASE_DEMO_REF"
-f <betik>` — hepsi `EXIT=0` (`ON_ERROR_STOP=1`).

## A. Kapsam envanteri (canlı DEMO şemadan, 2026-09-13)

Canlı envanter: 50 public base tablo (`pg_class` + `pg_constraint` sorgusu).
**39 tablo kapsama alındı** (her birinde `trg_degisim_log` attach kanıtı:
`pg_trigger` sayımı = 39), **11 tablo hariç** (lead'in eğilimine uygun olarak
türetilmiş akış `bildirim_log` da hariç — gerekçe tabloda):

| Hariç tablo | Gerekçe |
|---|---|
| `degisim_log` | Sözleşme: log'un kendisi loglanmaz; ayrıca immutability trigger'ı var |
| `islem_log` | Eski nesil log tablosu — immutable-by-design; loglanması her iş değişikliğini çift kayda düşürür |
| `bildirim_log` | **Türetilmiş akış**: satırlar altta yatan olaydan (gorev/dogum/uyarı) üretilir ve teslim durumu taşır (durum/erteleme_tarihi). Asıl iş değişikliği kaynak tabloda zaten loglanıyor; dahil etsek diff UI'da her olay çift satır görünür ve bildirim satırını geri almak altta yatan olayı geri almaz. Teknik/turetilmiş → HARIC. (İstenirse attach listesine tek satır eklenerek dahil edilebilir.) |
| `cop_kutusu` | Zaten ayrı bir yumuşak-silme/geri-yükleme mekanizması (`geri_yuklendi`, otomatik silme); kalıcı silme adımı yaşam-döngüsü işlemidir, iş verisi mutasyonu değil |
| `ui_logs` | İstemci telemetrisi — iş verisi değil |
| `chat`, `agent_threads`, `agent_plans`, `agent_messages` | Ajan altyapısı (`demo_klonla` da kapsam dışı tutuyor) |
| `goose_embeddings` | AI embedding önbelleği (goal'daki "teknik tablolar" tanımı) |
| `demo_klon_log` | Klon işinin kendi altyapı kaydı |

`gorev_log` dahil (sahip talimatı); `hayvan_override` dahil (iş verisi:
küpe-no override); composite PK'lı `vaccine_diseases` (2 kolon) ve
`pedigree_meta` (farm_id+key) dahil ve `satir_pk` nesne şemasıyla test edildi.

## B. Kabul eşlemesi

### Kabul 1 — I/U/D kaydı + immutability → **PASS**

- `k1_iud_log.sql`: 39 tablonun **her birinde** sentetik satır üretip
  I→1 kayıt, gerçek UPDATE→`degisen_alanlar` doğru 1 kayıt, D→`eski` tam
  satırla 1 kayıt; içerik değişmeyen UPDATE→kayıt yok. Özet satırı:
  `tablo_sayisi=39, pass=156, fail=0`. Tek transaction, ROLLBACK ile bitti
  (`distinct_txid=1` — aynı zamanda txid gruplamasının da kanıtı).
  Sentetik-satır üretilemeyen tabloda mevcut satır kullanılıp re-INSERT ile
  I kanıtlandı.
- Kaynak damgası: `SET LOCAL ROLE authenticated` +
  `request.jwt.claims` altında UPDATE → log `kaynak` =
  `{"rol":"authenticated","jwt_sub":"k1-test-sub","jwt_role":"authenticated",
  "app_name":"Supavisor","oturum_rolu":"postgres","istemci_etiketi":"k1-betik"}`
  (SECURITY DEFINER altında `current_user` maskelendiği için `role` GUC + jwt
  claims ikilisi kullanıldı).
- `k1b_immutability.sql` **red-before**: guard trigger'ları DISABLE iken
  UPDATE/DELETE başarılı (toksuz kanıt), ENABLE sonrası:
  - UPDATE → `ERROR: degisim_log degistirilemez (UPDATE reddedildi)`
  - DELETE → `ERROR: degisim_log degistirilemez (DELETE reddedildi)`
  - TRUNCATE → `ERROR: degisim_log degistirilemez (TRUNCATE reddedildi)`
  - `authenticated`: INSERT/UPDATE/DELETE → `42501 permission denied`,
    SELECT ✓ (RLS `USING(true)`)
  - `anon`: SELECT → `42501 permission denied`
- Tüm betik ROLLBACK ile kapandı; `degisim_log` 0 deneme satırı bıraktı.

### Kabul 2 — tek txid + trigger yükü → **PASS (ölçüldü)**

- `k2_txid_yuk.sql` (a): 100 satır INSERT + 100 satır UPDATE tek tx'te →
  `I:100 satır / txid_sayisi=1 / hepsi_bu_tx=t`, `U:100 / 1 / t`.
- (b) Trigger yükü — `stok_hareket` (iş trigger'sız tablo), 2000 satır,
  3 tekrar, trigger açık/kapalı aynı oturumda dönüşümlü, medyanlar:

| İşlem | Trigger açık | Kapalı | Oran | Ek maliyet |
|---|---|---|---|---|
| INSERT | 197.5 ms | 33.9 ms | 5.82× | **+81.8 µs/satır** |
| UPDATE | 329.7 ms | 35.7 ms | 9.24× | **+147.0 µs/satır** |
| DELETE | 144.2 ms | 3.4 ms | 41.99× | **+70.4 µs/satır** |

  Not: bu tablo demo boyutundadır; DELETE oranındaki mutlak değer küçüktür
  (3.4 ms taban). Ölçüm sonrası trigger durumu `tgenabled='O'` olarak
  geri doğrulandı. Betik ROLLBACK ile bitti.

### Kabul 3 — geri alma testleri → **PASS**

`k3_geri_alma.sql` **43/43 PASS** (ham çıktı `.out`). Vaka grubu:

- **Bilet/şifre:** SIFRE_AYARLI_DEGIL (kurulum öncesi), setup RPC'nin
  `authenticated`/`anon` tarafından çağrılamaması (42501; yalnız
  service_role), yanlış şifre → SIFRE_HATALI, doğru şifre →
  `kalan_sn≈3600`, süresi dolmuş bilet → BILET_SURESI_DOLMUS (+kullanım
  kaydı yazılır), bilinmeyen uuid ve NULL → BILET_GECERSIZ, **çok
  kullanımlılık**: aynı bilet ile 12 deneme (8 başarılı revert), hepsi
  `geri_alma_kullanim`'a kaydedildi.
- **Alan seviyesi:** son değişikliğin revert'i ✓; eski tx hedefi sonraki
  değişiklik varken → **CAKISMA** ✓; **revert-in-revert** ✓ (revert'in
  ürettiği yeni log kaydı hedeflenerek değer geri döndü).
- **Satır seviyesi:** revert ✓; **stok_uyari** (aynı satıra referans veren
  başka tx'teki stok hareketi — bilgilendirici, engellemiyor) ✓; revert'in
  `degisim_log`'a yazdığı yeni kaydın `kaynak.geri_alma.{bilet,gerekce}`
  damgası ✓.
- **İşlem seviyesi:** tek tx'te 2 farklı tabloya dokunan değişikliğin
  (padok INSERT + hekim UPDATE) planı 2 adım ✓; revert ✓; **islem-seviyesi
  revert-in-revert** ✓ (revert txid'si hedeflenerek).
- **Bağımlılık:** aynı tx'te doğan çocuk (padok+grup eşlem) → **KADEMELI**
  (çocuk plana girer, 2 adımlı revert) ✓; sonradan değişmiş çocuk →
  **ENGEL + BAGIMLILIK_ENGELI** ✓.
- **Composite PK (satir_pk nesne)** — lead isteği: `vaccine_diseases`
  `{vaccine_id,disease_id}` nesne hedefli revert ✓; `pedigree_meta`
  `{farm_id,key}` nesne hedef + txid'li revert ✓; composite hedefte
  sonraki değişiklik → CAKISMA ✓.
- **Hata yolları:** olmayan pk / boş txid / logsuz satır (sistem kurulumu
  öncesi simülasyonu: trigger disable ile yazılan değişiklik) →
  HEDEF_BULUNAMADİ; geçersiz seviye → GECERSIZ_SEVIYE; kapsam dışı tablo
  (`islem_log`), dizi-şekli pk → GECERSIZ_HEDEF; INSERT kaydında alan
  hedefi → GECERSIZ_HEDEF.
- **degisim_listele:** txid→detay (kayıt başına id/txid/zaman/tablo/pk/
  islem/eski/yeni/degisen_alanlar/**teknikal_mi**/kaynak — lead isteğiyle
  alan varlığı da assert edildi), tablo/işlem-tipi/tarih-aralığı (TR gün
  sınırı, Europe/Istanbul)/hayvan_id filtreleri ✓; `authenticated` rolüyle
  çağrı ✓.
- **Cascade revert (S12, review regression):** sablon+kalem
  (ON DELETE CASCADE) tek tx'te silindikten sonra islem-seviyesi revert →
  önizlemede plan 2 adım ve **EKLE sırası anne-önce topolojik** ✓; revert
  anne+çocuğu birlikte geri getirdi ✓; satır-seviyesi kısmi revert (yalnız
  anne) → çocuk geri gelmez, `bagimliliklar` içinde **UYARI** (engel değil)
  ✓.
- **Temizlik (S11):** tüm sentetik satırlar + k3'ün kendi log kayıtları
  (operator eylemiyle trigger-disable + etiket bazlı purge — k1b red-before
  ile aynı desen) + test şifresi/biletleri silindi; demo başlangıç
  durumuna döndü (`log=0 padok=0 hekim=1`).

### Kabul 4 — unit baseline → **PASS (taban ölçüldü; yeni saf katman testleri W2 scope'u)**

- Değişiklik ÖNCESİ taban (worktree, `NODE_PATH=/home/melik/egesut-erp1/node_modules`
  ile — worktree'de node_modules yok, ana checkout paylaşılıyor):
  `node --test tests/unit/*.test.js` → **tests 796 / pass 795 / fail 1**
  (EXIT=1). Tek kırmızı = bilinen `tests/unit/gecmis-pipeline.test.js:283`
  (`_gmGroupHtml ...`) — goal Constraints'te kayıtlı, iddiadan hariç.
  Not: `NODE_PATH`sız koşum `fast-check` modülü bulunamadığından 10 dosyada
  patlıyor (625/615/10) — bu bir ortam kısıtıdır, kod durumu değildir.
- Yeni saf JS katman testleri (diff üretimi, Türkçe etiketler): W2 zarfı.

### Kabul 5 / 6 — UI ve final rapor: **kapsam dışım** (W2 + lead)

## C. Sözleşme yorumları (raporlanacak kararlar)

1. **S1 — pk tipi (lead ONAYLI, ss-ask c9f7fd34):** sözleşmedeki `pk:"<uuid"`
   örneği canlı şemayla uyumsuzdu (19 text, 2 sayısal, 2 composite PK).
   Çözüm: `satir_pk` jsonb **nesne** `{pkkolon: değer}`; `p_hedef.pk`
   tek-kolon PK'da **skaler string**, composite'ta **nesne**. Çıktılarda
   hem `pk` (görünüm) hem `satir_pk` (kanonik nesne) dönülüyor → W2
   `satir_pk`'dan okur. Goal 3674e62 ile güncellendi (lead).
2. **S2 — satır/alan hedefinde txid (lead ONAYLI):** `p_hedef.txid`
   opsiyonel — verilirse o tx'in o satır/alan değişikliği, verilmezse
   **EN SON** değişiklik. İmza/dönüş şekli değişmedi.
3. **Çakışma kuralı (lead ek talimatı):** hedef sonrası plana dahil olmayan
   **her** değişiklik (teknik alan dahil) CAKISMA — bypass yok. Kod buna
   göre yazıldı (S1a/S6c vakaları kanıtlıyor).
4. **S3 — grant daraltması (kendi kararım, islem_log aynası + iyileştirme):**
   canlı `islem_log` RLS açık + `SELECT USING(true)` + `authenticated`
   INSERT,SELECT grant'lı. `degisim_log` RLS ve SELECT politikasını
   birebir izliyor; ama INSERT grant'ı **verilmedi** (islem_log'un INSERT
   grant'ı sahte-geçmiş yazımına izin veriyor; `k1b` ile kanıtlandı) —
   yazım yalnız SECURITY DEFINER trigger'dan. `farm_id` yok (islem_log
   aynası; tek-şirket katalog kuralı).
5. **S4 — gizli tablolar ayrı şemada (kendi kararım):** şifre hash'i,
   biletler ve kullanım kayıtları `surum_gizli` şemasında — PostgREST
   expose etmez ve `demo_klonla` yalnız **public** tabloları prod'dan
   TRUNCATE+kopyaladığından prod sahip hash'i demo'ya sızmaz. Şemaya
   PUBLIC/anon/authenticated USAGE yok; tablo grant'ı yalnız postgres.
   RPC imzaları sözleşmeyle birebir (public'te kalır).
6. **teknikal_mi kümesi:** canlı envanterden teknik zaman-damga kolonları:
   `created_at, updated_at, olusturma, guncelleme, guncelleme_tarihi,
   guncellendi`. Yalnız bu küme değiştiyse kayıt `teknikal_mi=true` ile
   yazılır; içerik değişimi yoksa kayıt hiç yazılmaz (k1 adım 2).
7. **"Aynı txid'deyse plana girer" (stok) yorumu:** sözleşme cümlesi
   satır/işlem seviyesinde uygulanır — satır hedefinin aynı tx'indeki
   `stok_hareket` kayıtları plana girer. **Alan** seviyesinde girmez
   (yalnız o alanın eski değeriyle sınırlı revert); orada ve plan-dışı
   durumlarda bilgilendirici `stok_uyari`/`bagimliliklar.UYARI` üretilir.
   Kod yorumu + rapor kaydı olarak belgelendi.
8. **cascade çocuk UYARI:** bir DELETE'in revert'i plana yalnız anne
   alındığında (satır-seviyesi), aynı tx'te cascade silinen çocuklar için
   `bagimliliklar` içinde `etki:UYARI` (bilgilendirici, engellemez) döner
   — S12c ile kanıtlandı.

## D. Tenant/RLS durumu — islem_log aynası (kanıtlı)

Canlı `islem_log`: `relrowsecurity=t`; policy `islem_log_select`
(`FOR SELECT USING(true)`, tüm rollere) + `service_insert` (ALL, WITH
CHECK true); grant `authenticated: INSERT,SELECT`; `farm_id` yok.

`degisim_log`: `relrowsecurity=t` ✓, `degisim_log_select FOR SELECT
USING(true)` ✓ (aynı desen), `farm_id` yok ✓ (aynı desen), grant
`authenticated: SELECT` (bilinçli daraltma — bkz. C.4; kanıt k1b).
RLS tabloda açık olduğundan PostgreSQL düzeyinde de satır erişimi
 USING(true) ile açık ama grant katmanı anon'u kesiyor.

## E. Kalan riskler / ölçülmemiş sınırlar

1. **UYGULAMA_HATASI yolu test edilmedi** — revert adımının iş
   trigger/constraint'ine takılması sentetik senaryoda üretilemedi; kod
   yolu var (EXCEPTION → `ok:false, hata:UYGULAMA_HATASI, sqlstate/mesaj`).
2. **Süperuser/owner degisim_log'u değiştirebilir** (trigger disable ile) —
   immutability uygulama rollerine karşı; testler (k1b red-before, k3
   temizliği) bu yetkiyi operator eylemi olarak kullandı. Postgres
   düzeyinde tam koruma DB sahibini kapsamaz.
3. **Trigger yükü:** UPDATE'te satır başına ~147 µs. Yüksek hacimli toplu
   güncellemelerde (binlerce satır/tx) işlem süresi uzar; prod'a alınmadan
   önce gerçek iş yükü profiliyle tekrar ölçülmesi önerilir.
4. **k3 committed-mode koştu** (gerçek ayrık txid'ler gerektiği için) ve
   kendi izini temizledi; çalıştırma sırasında gerçek revert'ler demo
   verisini birkaç yüz ms boyunca değiştirdi (test penceresi).
5. Şifre test sonrası **ayarlı değil** (`SIFRE_AYARLI_DEGIL` durumuna
   döndü) — kurulum, deploy sonrası owner'ın `sahip_sifresi_ayarla`
   adımıdır; hash hiçbir migration dosyasına yazılmadı.
6. SQL LSP aynası yeni nesneleri bilmiyordu (diagnostics'ta "does not
   exist" gürültüsü); `scripts/refresh_lsp_schema.sh` ile tazelendi.
   LSP süreci bu oturumda elle başlatılmadı (lazy).
7. hayvanlar `notlar` test izi: k3 S9 bir hayvana `~k3` eki yazıp S11'de
   ekleri temizledi; `regexp_replace` ile son ek kaldırıldı (S11 PASS).
8. **PROD notu — brute-force:** `geri_alma_bileti_al` authenticated-only ve
   bf(10) ile yavaşlatılmış ama kilitleme/gecikme yok; sahiplik tek-şifre
   modeli için kabul edilebilir, prod'da gözlemlenebilir.
9. **PROD notu — demo_klonla:** `degisim_log` bugün prod_fdw karşılığı
   olmadığından klon kapsamı dışında (geçmiş klonlardan sağ çıkıyor).
   Prod deploy sonrası FDW yeniden çekilirse klonla `degisim_log`'u da
   TRUNCATE+kopyalayacak (trigger'ları DISABLE ederek) — o pencerede
   çalışan revert'ler log üretmez; runbook'a "klon sonrası degisim_log
   muafiyeti" satırı eklenmeli.
10. **PROD notu — performans:** `degisim_onizle`/`degisim_listele` sorguları
    log büyüdükçe yavaşlar; `degisen_alanlar` GIN ve `referans_id` ifade
    indeksi prod öncesi değerlendirilmeli.
11. **identity-PK guard:** F1 attach bloğu, PK'sında identity/generated
    kolon olan tabloyu attach etmeyi reddeder (revert executor'ın sessiz
    yeniden-numaralandırma riskine karşı; bugün 39 tabloda yok).

## G. Builtin subagent review (şerit kuralı 1)

`code-reviewer` subagent incelemesi tamamlandı — **REQUEST_CHANGES**
(1 Critical + 2 Important + 1 latent). Bulgular ve çözümleri:

| # | Sınıf | Bulgu | Çözüm | Kanıt |
|---|---|---|---|---|
| 1 | Critical | Cascade-delete revert'te EKLE adımları id-DESC ile çocuk-önce → anne FK 23503, deterministik başarısızlık | `_degisim_plan` adım kurulum: EKLE adımları plan-içi FK grafiğinde **Kahn topolojik sırası** (anne-önce, döngüde id-sırası fallback), U/SIL id-DESC kalır | k3 S12a (plan ilk=tedavi_sablonu), S12b (anne+çocuk geri geldi), 43/43 |
| 2 | Important | `degisim_geri_al` kilitleme+yeniden-plan bloğu exception dışında → deadlock'ta kullanım kaydı yazılmaz, PostgREST 500 | kilit+yeniden-plan kendi subtransaction'ına alındı; hata → `ok:false, hata:UYGULAMA_HATASI, asama:KILIT_PLAN` + kullanım kaydı yine yazılır | kod; tüm revert vakaları regresyonsuz |
| 3 | Important | Rapor `bildirim_log` HARIC derken migration attach ediyordu (kod-rapor çelişkisi) | `bildirim_log` attach listesinden çıkarıldı + drift-temizlik döngüsü (liste-dışı tablodan trigger düşürülür); k1 39 tabloyla yeniden koşuldu | k1 156/156; `pg_trigger` sayısı 39 |
| 4 | Latent | EKLE adımı identity-PK'lı tabloda sessiz yeniden-numaralandırma riski (bugün yok) | F1 attach DO bloğu identity/generated PK tespitinde RAISE ile reddeder | migration 000001 |
| 5 | Minor | `surum_gizli` gelecek tabloları için default privilege yok; `_cagiran` kaynağı dar | `ALTER DEFAULT PRIVILEGES ... REVOKE` eklendi; `_cagiran` app_name/istemci_etiketi ile zenginleştirildi | migration 000002 |
| 6 | Minor | alan-seviyesinde same-tx stok join'inin yorumu belgesiz; brute-force, klonla penceresi, performans indeksleri | §C.7, §C.8 yorum olarak; §E.8-10 prod notları olarak işlendi | bu rapor |

Review sonrası tüm betikler (k1 156/156, k3 43/43) final motorla
yeniden koşuldu — regresyon yok.

## F. Board / kırıntı / teslim

- Board: `/home/melik/egesut-erp1/.ss/surum-gecmisi-diff-W1-BOARD.md`
- Gate kırıntısı (gelen iş denetimi, 4 bulgu → 2'si lead onayıyla çözüldü,
  2'si C.4/C.5'te karar olarak işlendi): `.crumbs/surum-gecmisi-diff-W1.jsonl`
- Teslim mesajı lead'e: dal + son SHA + rapor yolu (ss-ask kaydı)
