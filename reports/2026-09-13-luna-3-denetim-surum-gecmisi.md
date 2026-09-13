# A5 — Luna 3. denetim: sürüm geçmişi L2 düzeltmeleri

Tarih: 2026-09-13 (Europe/Istanbul)
Denetlenen ref: `agent/surum-gecmisi-diff` @ `3d134d0c10c87ea73a41a45b1e5755899ed76ea2`
Karşılaştırma: `7c6e871..3d134d0`
Sınır: Yalnız etiket kapsamı/regression, k3 cleanup ve hızlı regresyon. Ürün kodu
değiştirilmedi; PROD'a hiçbir sorgu/yazma gönderilmedi. DEMO probe'u kontrollü
sentinel ve test şifresini koşum sonunda başlangıçtaki boş duruma döndürdü.

## Gelen iş kapısı

**KABUL ET VE BAŞLA — bulgu yok.** Hedef ref, düzeltme dosyaları ve kabul
kriterleri erişilebilirdi; canlı/fixture ayrımı ve k3 tam-satır geri yükleme
özellikle yeniden ölçüldü. Gate kırıntısı: `61f565c24182`.

## 1. Etiket kapsamı — YANLIŞ (regression canlı şemaya bağlı değil)

### Harita ölçümü — DOĞRU

DEMO `information_schema.columns` + `trg_degisim_log` attach sorgusu:

```text
column_count=393 | table_count=39 | sorted_scope_md5=690aadcc5bb087a36966ae2429cc96ca
```

`tests/unit/support/degisiklikler-kapsam-kolonlari.json` aynı 39/393 kümesini
verdi; bağımsız hedef-ref sayımı `explicit_label_pairs=393` ve
`fallback_pairs=0` döndürdü. Bu nedenle mevcut ölçülen DEMO snapshot'ı için
Türkçe açık map tamdır.

Hedef ref temiz kopyasında:

```text
NODE_PATH=/home/melik/egesut-erp1/node_modules node --test tests/unit/degisiklikler-etiketler.test.js
tests 10 | pass 10 | fail 0 | TARGET_LABEL_UNIT_DIRECT_EXIT=0
```

### Regression dürüstlüğü — YANLIŞ

Test `tests/unit/degisiklikler-etiketler.test.js:7-9` ile yalnız yerel JSON
fixture'ı yükleyip `:27-36` arasında onu dolaşıyor; canlı istemci,
`information_schema` veya DEMO sorgusu yok. Canlı schema'ya yeni kolon eklenir
ve fixture güncellenmezse test bunu göremez; dolayısıyla “canlı kolon değişince
kırılır” kabulü sağlanmamış.

Kırmızı mutant kanıtı (repo dışı geçici kopya): `brand_name` map satırı çıkarıldı,
aynı test koşuldu:

```text
tests 10 | pass 8 | fail 2
AssertionError: açık etiketi olmayan kolonlar: drug_products.brand_name
MUTANT_BRAND_NAME_DIRECT_EXIT=1
```

Bu, fixture'a eklenmiş etiketsiz kolonu yakalıyor; canlıya eklenmiş, fixture'a
yansıtılmamış kolonu yakalamıyor.

## 2. k3 cleanup — DOĞRU

Hedef SQL `3d134d0:reports/2026-09-13-surum-gecmisi-W1/k3_geri_alma.sql:56-57,526-549`
şunları yapıyor: koşum öncesi `SELECT *` bilet/şifre snapshot'ı, yalnız yeni
bilet/kullanım silme, şifre `hash + guncelleme` geri yazma ve bilet
`olusturma + son_gecerlilik + kaynak` geri yazma.

DEMO `execute_sql` canlı odaklı probe'u aktif sabit sentinel ve önceden varolan
test şifresiyle bu cleanup bloğunu çalıştırdı. Hash/secret değerleri rapora
yazılmadı; yalnız satır fingerprint'i ve tam satır karşılaştırması tutuldu:

```text
baseline_ticket_rows=0 | baseline_password_rows=0
sentinel_active_before=true | sentinel_active_after=true
ticket_before_md5=78fc1fcd7cb86968ae2716a2578105cd
ticket_after_md5 =78fc1fcd7cb86968ae2716a2578105cd
ticket_full_row_equal=true
password_before_md5=3010abc561883ddd04ac5e3d5aa9e3fd
password_after_md5 =3010abc561883ddd04ac5e3d5aa9e3fd
password_full_row_equal=true
generated_ticket_rows_after=0 | generated_usage_rows_after=0
restored_ticket_rows=1 | restored_password_rows=1
final_ticket_rows=0 | final_password_rows=0
```

Bu kanıt gerçek bilet satırının dört alanını ve şifre satırının `id, hash,
guncelleme` alanlarını önce/sonra karşılaştırıyor. Tam 46-vaka psql harness'ı
bu MCP yüzeyinde yeniden koşturulmadı; `\gset` gibi psql istemci metaları raw
SQL değildir. Cleanup kabulü ise hedef blokla aynı SQL ve canlı DEMO üzerinde
ölçüldü. Hedef ham çıktıdaki S14 de `PASS` ve `46 | 0 | 46` gösteriyor.

## 3. Regresyon ve önceki doğru maddeler — ÖLÇÜLEMEDİ

### Unit tabanı — DOĞRU

Hedef ref geçici kopyasında doğrudan:

```text
tests 817 | pass 816 | fail 1 | TARGET_FULL_UNIT_DIRECT_EXIT=1
known fail: tests/unit/gecmis-pipeline.test.js:283 (_gmGroupHtml, DÜN)
```

Önceki `816/815/1` tabanı korunmuş; yeni kapsam testiyle beklenen toplam
`817/816/1` olmuş ve bilinen tek kırmızı değişmemiştir.

### Bilet maskesi — DOĞRU

DEMO `pg_proc` SELECT probe'u:

```text
mask_function_count=1 | mask_expression_present=true
direct_full_ticket_expression_absent=true
```

### anon EXECUTE kapısı — DOĞRU

DEMO `has_function_privilege` SELECT probe'u:

```text
anon_ticket_exec=false | anon_list_exec=false | anon_preview_exec=false
anon_revert_exec=false | anon_setup_exec=false
authenticated_ticket_exec=true | authenticated_list_exec=true
service_setup_exec=true
```

### PROD yeni nesne yokluğu — ÖLÇÜLEMEDİ

Bu koltukta PROD connector/DSN yoktu; güvenli keşif çıktısı:

```text
dpsql=absent
credential_env_names: (boş)
```

Bu nedenle önceki turdaki PROD yokluk iddiası bu tur için güncel kanıt sayılmadı
ve PROD'a sorgu da gönderilmedi. Root/owner bu alt maddeyi ayrı, yalnız-SELECT
PROD probe'u ile tamamlamalıdır.

## Ek rapor drift'i

Hedef teslim raporu `3d134d0:reports/2026-09-13-surum-gecmisi-teslim.md:117`
K3'ü `817/816/1` ile ve `:106-115` aralığında `46/46` ile anlatırken
`:180` satırında `k3_geri_alma.out — 45/45` bırakmış. Bu, kabul çıktısıyla
çelişen küçük bir rapor hijyeni bulgusudur.

## Son karar

DÜZELTME İSTE (etiket regression'ı canlı DEMO/schema ile otomatik karşılaştırılmalı ve canlı-only etiketsiz kolon için kırmızı kapı eklenmeli; teslim raporundaki k3 `45/45` drift'i `46/46` ile düzeltilmeli; PROD yokluk probe'u root/owner tarafından yalnız SELECT ile tamamlanmalı).
