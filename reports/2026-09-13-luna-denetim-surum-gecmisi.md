# L2 Luna bağımsız denetim — sürüm geçmişi + diff + biletli geri al

Tarih: 2026-09-13 (Europe/Istanbul)

Denetlenen ref: `agent/surum-gecmisi-diff` (`6fabaf50ef7eaa27d050e4eeed6ab98159b741eb`)

Denetim sınırı: hedef branch `git show`/diff ile salt-okundu. PROD yalnız
`information_schema`/`pg_catalog` SELECT sorguları ile ölçüldü. DEMO yazan
kabul betikleri ve kontrollü probe çalıştırıldı; her probe sonunda test izleri
temizlendi. Şifre, token ve bilet değerleri çıktıya yazılmadı.

Gelen iş kapısı: **KABUL ET VE BAŞLA — bulgu yok.** Zarfın ölçülebilir kabul
ölçütleri vardı; migration veya teslim raporu canlı durumun yerine kanıt kabul
edilmedi. Gate kırıntısı: `ebd4c7c64f54`.

## 1. PROD'a dokunuldu mu?

**DOĞRU — PROD'da bu teslimata ait nesne yok.**

Komut (token değeri gösterilmeden, Management API database/query yüzeyine yalnız
SELECT gönderildi):

```text
SELECT current_database(),
  (to_regclass('public.degisim_log') IS NOT NULL),
  (SELECT count(*) FROM pg_namespace WHERE nspname='surum_gizli'),
  (SELECT count(*) FROM pg_proc ... yeni public ve internal fonksiyon adları ...),
  (SELECT count(*) FROM pg_trigger ... degisim ilişkili triggerlar ...);
```

Çıktı:

```text
PROD_STRICT_REF=zqnexqbdfvbhlxzelzju CURL_EXIT=0
db=postgres surum_gizli_schema_count=0 any_schema_degisim_log_relations=0
new_or_internal_function_count=0 new_or_related_trigger_count=0
```

İlk yokluk probe'u da aynı sonucu verdi: `degisim_log_table=false`,
`new_public_function_count=0`, `new_related_trigger_count=0`, `CURL_EXIT=0`.

## 2. DEMO kabul 1–3

**YANLIŞ — davranış testleri geçti, fakat canlı kapsam kanıtı güncel değil ve
kabul betiği paylaşımlı gizli durumu kapsam dışı silebiliyor.**

### I/U/D, no-op ve değiştirilemezlik

Komutlar, hedef branch'teki ham kabul betikleriyle DEMO ref
`vtzqjmazsvurxdeondmi` üzerinde doğrudan koşuldu:

```text
psql ... -f reports/2026-09-13-surum-gecmisi-W1/k1_iud_log.sql
psql ... -f reports/2026-09-13-surum-gecmisi-W1/k1b_immutability.sql
```

Çıktı:

```text
K1_DIRECT_EXIT=0
tablo_sayisi | pass | fail
39           | 156  | 0
distinct_txid | rows_in_tx
1             | 124

K1B_DIRECT_EXIT=0
RED-BEFORE: UPDATE 1, DELETE 1 (guard triggerları kapalıyken)
guard açık: UPDATE/DELETE/TRUNCATE -> beklenen exception
authenticated INSERT/DELETE -> permission denied
anon SELECT -> permission denied
```

K1 çıktısında kaynak damgası da yeniden görüldü: `rol=authenticated`,
`jwt_sub=k1-test-sub`, `istemci_etiketi=k1-betik`; içerik değişmeyen UPDATE
kaydı yoktu.

### Geri alma betiği

```text
psql ... -f reports/2026-09-13-surum-gecmisi-W1/k3_geri_alma.sql
```

Çıktı: `K3_DIRECT_EXIT=0`; `pass=43`, `fail=0`, `toplam=43`. Aynı koşumda
alan/satır/işlem revert, çakışma, bağımlılık engeli, bileşik PK, çok kullanımlı
bilet ve revert-in-revert vakaları geçti. Temizlik çıktısı:
`log=0`, sentetik satır `0`; sonrasında `disabled_related_triggers=0`,
`test_marker_logs=0`, bilet/kullanım/şifre satırları `0`.

### Kapsam drift'i

Komut:

```text
SELECT c.relname,
       EXISTS (SELECT 1 FROM pg_trigger t
               WHERE t.tgrelid=c.oid AND t.tgname='trg_degisim_log') AS logged
FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
WHERE n.nspname='public' AND c.relkind='r';
```

Canlı DEMO çıktısı: **51** public base tablo; `trg_degisim_log` bağlı tablo
sayısı **39**. `tasks` tablosu (`id,title,status,priority,assigned_to,...`)
unlogged kaldı. Teslim raporu `reports/2026-09-13-surum-gecmisi-teslim.md:43-62`
canlı envanteri **50** tablo ve **11** hariç olarak yazıyor; mevcut 51'in
12'nci hariç nesnesi `tasks` için raporda gerekçe yok. `tasks` teknik tabloya
benziyor, ancak bu ayrım canlı envanterde açıkça belgelenmemiş.

### Kabul betiği kapsam kusuru

`k3_geri_alma.sql:46-48` ve `:495-497` doğrudan şu kapsam dışı silmeleri yapıyor:

```sql
DELETE FROM surum_gizli.geri_alma_kullanim;
DELETE FROM surum_gizli.geri_alma_bileti;
DELETE FROM surum_gizli.sahip_sifresi;
```

Bu betik paylaşımlı DEMO'da başka kullanıcıların biletlerini, kullanım
kayıtlarını ve sahip şifresini de silebilir. Bu koşum öncesinde üç gizli tablo
da `0` idi; bu nedenle bu turda yabancı gizli kayıt kaybı gözlenmedi. Betik
mekanizması yine de güvenli/tekrar üretilebilir kabul edilemez.

## 3. Güvenlik

**YANLIŞ — authenticated kullanıcı aktif geri alma biletini audit çıktısından
okuyabiliyor.**

### Geçen alt kontroller

- Migration hash literal taraması: `git grep -E '\$2[aby]\$' --
  supabase/migrations/20260913*` -> `MATCHES=0` (grep'in beklenen yokluk
  çıkışı `1`). Hash yalnız kurulum RPC'sinde `extensions.crypt(...gen_salt())`
  ile üretiliyor.
- DEMO `pg_proc` probe'u: beş public fonksiyon `prosecdef=t`; her birinin
  `config=search_path=pg_catalog, public`.
- `son_gecerlilik=now()+interval '1 hour'` ve kullanım sırasında
  `son_gecerlilik <= clock_timestamp()` canlı kodda mevcut.
- DEMO privilege probe'u: `degisim_log` için `authenticated SELECT=t`,
  `anon SELECT=f`; yeni public RPC'ler için `anon_exec=f`, `auth_exec=t`.
  `sahip_sifresi_ayarla` için `anon_exec=f`, `auth_exec=f`, `service_exec=t`.
- PostgREST anon anahtarıyla dört doğrudan deneme: tablo GET ve
  `degisim_listele`, `geri_alma_bileti_al`, `degisim_geri_al` RPC'leri her biri
  `CURL_EXIT=0 HTTP=401`, gövde `permission denied` verdi.

### Yeniden üretilebilir bilet sızıntısı

Kod kanıtı:

- `supabase/migrations/20260913000001_surum_gecmisi_f1_degisim_log.sql:140-144`
  revert sırasında `kaynak.geri_alma.bilet` değerini `degisim_log` satırına
  yazıyor.
- `supabase/migrations/20260913000002_surum_gecmisi_f2_geri_alma.sql:764-769`
  `degisim_listele` detay cevabında satırın tüm `kaynak` JSON'unu döndürüyor.
- Aynı dosya `:941-944` ile kullanım kaydını, `:954-957` ile authenticated
  EXECUTE'yi açık tutuyor.

Kontrollü DEMO probe'u: service-role/`postgres` ile throwaway şifre ve bilet
kuruldu; test satırı authenticated rolüyle değiştirildi ve geçerli biletle
revert edildi; sonra `SET ROLE authenticated` altında
`degisim_listele({"txid": <revert_txid>})` çağrıldı. Bilet değeri basılmadan
eşitlik kontrolü yapıldı:

```text
TICKET_LEAK_PROBE_DIRECT_EXIT=0
query_role | ticket_visible | ticket_matches | target_txid | revert_txid
authenticated | t | t | 14036 | 14037

marker_logs_left | tickets_left | usage_left | password_rows_left | restored_tel
0                | 0             | 0            | 0                   | 5550000
```

Sonuç: anon'un doğrudan çağrı yapamaması doğru olsa da, herhangi bir
authenticated kullanıcı revert transaction detayından 1 saatlik çok kullanımlı
bileti alıp şifre modalını atlayabilir. Bu, sahip şifresi kapısının gerçek
güvenlik garantisini bozuyor.

## 4. Geri alma doğruluğu

**DOĞRU — DEMO'daki 43/43 koşumda istenen davranışlar geçti.**

Doğrudan `k3_geri_alma.sql` çıktısından örnekler:

```text
S1b alan revert                  -> PASS
S2b satır revert                 -> PASS
S3b işlem revert                -> PASS
S1a/S6c sonraki değişiklik       -> CAKISMA PASS
S5 sonraki çocuk değişikliği     -> BAGIMLILIK_ENGELI PASS
S6a/S6b composite PK             -> PASS
S3c/S1c revert-in-revert         -> PASS
S0g süresi dolmuş bilet          -> BILET_SURESI_DOLMUS PASS
S0i/S0j bilinmeyen/NULL bilet     -> BILET_GECERSIZ PASS
43 | 0 | 43
```

K3 sonrası ilgili triggerların tamamı `tgenabled='O'`, marker logları ve
throwaway gizli kayıtlar `0` idi; H3 satırı `telefon=5550000` durumuna döndü.

## 5. Kapsam taşması, eski yüzeyler ve unit tabanı

**YANLIŞ — eski ürün yüzeyi korunmuş olsa da teslim raporu/diff hijyeni güncel
ve temiz değil.**

### Eski yüzey ve değişen dosyalar

```text
git diff --name-status main...agent/surum-gecmisi-diff -- js/gecmis.js
(çıktı yok)

git diff --name-status main...agent/surum-gecmisi-diff -- supabase/migrations/202603* ... 202606*
(çıktı yok)

js/api.js diff: yalnız 17 additive satır, dört yeni wrapper
git diff --stat: 34 files changed, 4697 insertions(+), 28 deletions(-)
```

Bu alt kontrol **DOĞRU**: `js/gecmis.js`, eski migration yüzeyleri ve yedi
legacy geri-al RPC'si değişmemiş; F3 dosyaları manifestteki kapsamda.

### Teslim raporu ref drift'i

```text
git rev-parse agent/surum-gecmisi-diff
6fabaf50ef7eaa27d050e4eeed6ab98159b741eb

reports/2026-09-13-surum-gecmisi-teslim.md:7  head: d6acf03
reports/2026-09-13-surum-gecmisi-teslim.md:16 uç d6acf03
```

Raporun kendi frontmatter/özet başı gerçek branch HEAD'i göstermiyor; aynı
raporda final test ref'i `f0814c4` olarak geçiyor (`:79-82`). Bu, kabul
kanıtının hangi uçta üretildiğini belirsizleştiren `doc-drift` kusurudur.

### Diff hijyeni

```text
git diff --check main...agent/surum-gecmisi-diff
DIFF_CHECK_EXIT=2 FINDING_LINES=253
```

253 eklenmiş satır, özellikle psql `.out` kanıt dosyalarında trailing
whitespace olarak raporlandı. Bu uygulamayı bozmaz; teslim diff'inin temiz
olduğu iddiasını bozar.

### Unit ölçümü

Teslim raporundaki komut yeniden koşuldu:

```text
NODE_PATH=/home/melik/egesut-erp1/node_modules node --test tests/unit/*.test.js
UNIT_NODE_PATH_DIRECT_EXIT=1
tests 814 | pass 813 | fail 1
tek hata: tests/unit/gecmis-pipeline.test.js:283 (bilinen kırmızı)

node --test tests/unit/degisiklikler-diff.test.js tests/unit/degisiklikler-etiketler.test.js
NEW_UNIT_DIRECT_EXIT=0
tests 18 | pass 18 | fail 0
```

Bu sayılar teslim raporuyla eşleşiyor; bilinen kırmızı nedeniyle süreç çıkışı
`1`, yeşil `0` değil. Ayrıca package script'i worktree'nin bağımlılık yolu
olmaksızın denendi:

```text
npm run test:unit
UNIT_DIRECT_EXIT=1
tests 643 | pass 633 | fail 10
9 test dosyası: Cannot find module 'fast-check'
```

Bu ikinci sonuç ortam/dependency sınırıdır; `NODE_PATH` ile rapor komutu
ölçülebilir hale geliyor ve kod hatası olarak yükseltilmedi. Normal package
komutunun worktree'de tek başına yeniden üretilebilir olması ise
**ÖLÇÜLEMEDİ**.

## 6. Performans

**DOĞRU — trigger yükü yeniden ölçüldü; değerler teslim raporundaki tek önceki
koşumdan farklı.**

```text
psql ... -f reports/2026-09-13-surum-gecmisi-W1/k2_txid_yuk.sql
K2_DIRECT_EXIT=0
I: 100 satır / txid_sayisi=1 / hepsi_bu_tx=t
U: 100 satır / txid_sayisi=1 / hepsi_bu_tx=t

fresh median ek yük:
INSERT 159.1 us/satır
UPDATE 245.0 us/satır
DELETE 137.4 us/satır
trigger state restored: trg_degisim_log = O
```

Teslim raporunda önceki medyanlar INSERT `81.8`, UPDATE `147.0`, DELETE
`70.4 us/satır` idi. Pooler ve paylaşımlı DEMO dalgalanması olasıdır; final
rapor taze koşumun ref/zaman/ham çıktısını açıkça eşlemelidir.

## 7. F3 UI

**YANLIŞ — tarih ve çevrimdışı kapısı doğru, fakat tüm gerçek kapsam için Türkçe
etiket garantisi yok; gerçek RPC ile tarayıcı kabulü de ölçülmedi.**

### Doğru alt kontroller

- F3 dosyaları branch'te mevcut: `js/degisiklikler/degisiklikler.js`,
  `diff.js`, `etiketler.js`; `index.html`, `js/api.js`, `js/ui.js` additive
  entegrasyonu var.
- Tarih gösterimi `js/utils/helpers.js:18-19` (`fmtTarih`/`fmtTarihSaat`)
  ve kullanım `js/degisiklikler/degisiklikler.js:149-150` ile `gg.aa.yyyy`.
  Kanonik seçim `tekTarihTakvimAc` ile yapılıyor.
- Çevrimdışı liste kapısı `degisiklikler.js:168-174`, geri-al düğmesi kapısı
  `:256-258`, bağlantı geçişi ve açık modal temizliği `:479-493` altında.
  `navigator.onLine=false` iken liste alınmıyor ve geri-al düğmeleri
  çizilmiyor.

### Türkçe etiket kusuru

`js/degisiklikler/etiketler.js:7-46` ve `:91-164` map'lerinde bazı canlı
kapsam tabloları/alanları yok; `:176-186` bilinmeyenleri mekanik İngilizce
snake_case fallback'e bırakıyor. Canlı kolonlarla hedefli node probe çıktısı:

```text
pedigree_nodes.display_name    => table=Pedigree nodes    field=Display name
pedigree_parentage.source_ref  => table=Pedigree parentage field=Source ref
semen_catalog.code             => table=Semen catalog     field=Code
vaccination_schedule.target_type => field=Target type
vaccine_protocol_steps.label   => field=Label
LABEL_FALLBACK_TARGETED_EXIT=0
```

Bu değerler kullanıcıya gösterilen diff alanı/başlığı için Türkçe değildir.

### Ölçülmemiş tarayıcı sınırı

Teslim raporu `:96-103` ve W2 raporu `:62-83` ekran görüntülerinin stub
verisiyle üretildiğini, gerçek DEMO RPC tarayıcı akışının sahip final testine
kaldığını söylüyor. Bu denetimde code-path okundu; gerçek RPC + gerçek DEMO
tarayıcı akışı yeniden koşulmadı. Ayrıca test sonrası DEMO'da
`password_row_count=0`; bu nedenle UI bilet akışının canlı şifreyle kanıtı
**ÖLÇÜLEMEDİ**.

## Düzeltme istekleri

1. `kaynak.geri_alma.bilet` değerini authenticated audit/listeleme yolundan
   kaldır veya tekrar kullanılamaz biçimde maskele; bilet sızıntısı için
   authenticated regression ekle.
2. Canlı 39 kapsam tablosunun tüm gösterilen tablo/alan isimlerini Türkçe map'e
   ekle; en az `pedigree_nodes`, `pedigree_parentage`, `semen_catalog`,
   `vaccination_schedule` ve `vaccine_protocol_steps` alanlarını fallbackten
   çıkar.
3. Teslim raporunu gerçek `6fabaf5` ucu, güncel 51 tablo envanteri/`tasks`
   gerekçesi ve taze K2 ölçümüyle yeniden üret; 253 trailing-whitespace
   kanıt satırını temizle.
4. `k3_geri_alma.sql` cleanup'ını test marker/biletine daralt; paylaşımlı
   DEMO'daki diğer bilet, kullanım ve sahip şifresini topluca silme.
5. Sahip final tarayıcı testini gerçek RPC + DEMO şifresiyle koşup K5'i
   `PASS`/`PARTIAL` olarak yeniden kanıtla; şu an bu sınır ölçülmemiştir.

**KARAR: DÜZELTME İSTE (1) aktif bilet sızıntısını kapat ve regression ekle; 2) kapsamın tüm UI etiketlerini Türkçeleştir; 3) ref/kapsam/K2/diff hijyeni teslim raporunu yenile; 4) DEMO cleanup'ını test sahipliğiyle sınırla; 5) gerçek RPC tarayıcı kabulünü tamamla).**
