# L2 Luna yeniden denetim — sürüm geçmişi düzeltme turu

Tarih: 2026-09-13 (Europe/Istanbul)

Denetlenen ref: `agent/surum-gecmisi-diff` @ `7c6e871b0947cebaf468e5b623772ecee90d1f51`

Karşılaştırma tabanı: `6fabaf50ef7eaa27d050e4eeed6ab98159b741eb`

Denetim sınırı: Yalnız dört düzeltme maddesi, düzeltmenin önceki doğru
maddeleri bozup bozmadığı ve PROD'da yeni nesne yokluğu ölçüldü. PROD'a yalnız
SELECT gönderildi; DEMO probe'ları koşum sonunda kendi izlerini temizledi. Tam
bilet/şifre değerleri çıktıya yazılmadı.

## Gelen iş kapısı

**KABUL ET VE BAŞLA — bulgu yok.** Düzeltme zarfı her maddenin ölçülebilir
kabul ölçütünü veriyor; verilen ref, DEMO/PROD ayrımı ve rapor yolu doğrulanabilir.
Gate kırıntısı: `ff830c133c5e`.

## 1. Bilet sızıntısı (güvenlik) — DOĞRU

### Kod ve statik DEMO kanıtı

Hedef migration `supabase/migrations/20260913000004_luna_bilet_maske.sql:10-14`
aynı SECURITY DEFINER trigger fonksiyonunu yeniden tanımlıyor; `:78-81` tam
bilet yerine `left(v_bilet, 8) || '…'` yazıyor. DEMO'daki canlı fonksiyon/ACL
SELECT probe'u:

```text
mask_fn=true|full_ticket_insert=false
auth_direct_log_select=true|auth_secret_schema_usage=false|auth_ticket_select=false|auth_usage_select=false|auth_list_exec=true|anon_list_exec=false
DEMO_SECURITY_STATIC_PROBE_EXIT=0
```

### Gerçek authenticated rol probe'u

Komut, `postgres` bağlantısından geçici şifre ve bilet oluşturdu; gerçek satır
revert etti; sonra aynı oturumda `SET ROLE authenticated` ile hem doğrudan
`public.degisim_log` SELECT hem `public.degisim_listele(txid)` çağrısını yaptı.
Karşılaştırmada bilet değeri yazdırılmadı:

```text
query_role | direct_full_ticket_matches | direct_mask_present | direct_audit_payload_visible
authenticated | f | t | t

query_role | rpc_full_ticket_matches | rpc_mask_present | rpc_audit_payload_visible
authenticated | f | t | t

query_role | claims | direct_full_ticket_matches | direct_mask_present
authenticated | {"role":"authenticated","sub":"luna-security-claims-sub"} | f | t

query_role | rpc_full_ticket_matches | rpc_mask_present
authenticated | f | t

new_marker_logs_removed | new_tickets_removed | new_usage_removed | password_restored | row_restored
t | t | t | t | t
DEMO_AUTHENTICATED_CLAIMS_TICKET_PROBE_DIRECT_EXIT=0
```

Komutun canlı DEMO hedefi `vtzqjmazsvurxdeondmi` idi; `SET ROLE authenticated`
koşumu istenen JWT/claims eşdeğeridir. Audit payload ve ilk 8 karakterli maske
görülüyor, fakat tam UUID eşleşmiyor; `surum_gizli` şeması ve gizli tablolar
authenticated SELECT'e kapalı.

Hedef regression betiği de doğrudan çalıştırıldı:

```bash
psql "$DEMO_DSN" -X -v ON_ERROR_STOP=1 -P pager=off \
  -f <(git show 7c6e871:reports/2026-09-13-surum-gecmisi-W1/k3_geri_alma.sql)
```

```text
S13 LUNA-1: tam bilet log'a yazılmaz ... ok=true tam=0 maske=15 ... PASS
== özet ==
pass | fail | toplam
45   | 0    | 45
TARGET_K3_DIRECT_EXIT=0
```

Sonuç: authenticated kullanıcı aktif tam bileti audit/list SELECT yolundan
alamıyor. Prefix korelasyon için kalıyor; UUID v4'ün yalnız ilk 8 karakteri
tam bileti yeniden kurmaya yeterli değil.

## 2. Türkçe etiketler — YANLIŞ

Hedef unit test yeni 39 tablo üyeliğini ve yalnız önceki bulgudaki beş alanı
kontrol ediyor (`tests/unit/degisiklikler-etiketler.test.js:17-46`). Hedef
`7c6e871` üzerinden test sonucu yeşil olsa da canlı kolon kapsamını kontrol
etmiyor:

```text
LIVE_DEMO_TRIGGERED_TABLES=39
TARGET_TABLE_MAP_ENTRIES=42
LIVE_DEMO_COLUMNS_IN_SCOPE=393
TARGET_EXPLICIT_FIELD_MAPS=120+common:44
MISSING_TABLE_LABELS=none
MISSING_FIELD_LABEL_COUNT=81
LIVE_DEMO_LABEL_SCHEMA_PROBE_EXIT=0
```

Canlı DEMO `trg_degisim_log` kapsamındaki 39 tablonun tablo etiketi haritada
var; fakat aşağıdaki 81 alan açık map'e sahip değil ve
`js/degisiklikler/etiketler.js:191-195` içindeki mekanik snake_case fallback'e
düşüyor:

```text
diseases: category
dogum: buzagi_id
drug_classes: group_name, class_name, active_ingredient, kategori_id
drug_products: drug_class_id, brand_name, concentration, concentration_unit, default_route, default_unit, std_dose, std_dose_unit, std_dose_min, std_dose_max
drugs: description, stock_item_id, default_unit, default_route
grup_padok_eslem: grup
hayvan_override: kupe_no, pasif_mi, guncelleme_tarihi
hekimler: telefon
irk_esik: irk, tohumlama_gun, suttten_kesme_gun, kullanim_sayisi
pedigree_meta: farm_id, key, value
pedigree_nodes: farm_id, farm_animal_id, node_kind, registry_system, registry_code, sex, breed, birth_date, country_code, founder_status, metadata
pedigree_parentage: farm_id, parent_node_id, child_node_id, parent_role, source_type, evidence, confidence
protokol_ayar: anahtar, deger, min_deger, max_deger, guncellendi
protokol_dismiss: protokol, neden
sablon_hastalik_eslem: sablon_id
semen_catalog: farm_id, bull_node_id, stock_id, supplier, semen_type, active, metadata
stok_kategorileri: sira
tedavi_sablonu: tohumlama_plani
tedavi_sablonu_kalem: sablon_id, gun_no
vaccination_schedule: timing_type, timing_days, sequence_order
vaccine_protocol_steps: adim_no, offset_gun
vaccines: disease_target, repeat_interval_days, is_mandatory, stock_item_id, marka, etken_madde, protokol_tipi
```

Örnek olarak `pedigree_nodes.farm_animal_id` ve
`vaccines.repeat_interval_days` kullanıcıya İngilizce/fallback biçiminde
gösterilir. Dolayısıyla “tüm tabloların alanları Türkçe map'te” kabulü
sağlanmıyor; test yalnız üyelik ve beş seçilmiş alan için fake-arm niteliğinde.

## 3. Teslim raporu hijyeni — DOĞRU

Hedef teslim raporu `7c6e871:reports/2026-09-13-surum-gecmisi-teslim.md` içinde:

- `:8` DEMO ref'i `vtzqjmazsvurxdeondmi`, `:9` PROD ref'i
  `zqnexqbdfvbhlxzelzju` olarak açıkça yazıyor;
- `:54-85` canlı 51 tablo, 39 dahil / 12 hariç kapsamını ve `tasks` gerekçesini
  listeliyor;
- `:95-105` K2 ölçümünü ref'lerle eşliyor;
- `:166-173` ham kanıt dosyalarını gösteriyor.

Komutla canlı DEMO kümesi ve rapor metni çaprazlandı:

```text
REPORT_SCOPE_INCLUDED_COUNT=39
LIVE_DEMO_BASE_TABLE_COUNT=51
LIVE_DEMO_TRIGGERED_SCOPE_COUNT=39
REPORT_EXCLUDED_CODE_TOKEN_COUNT=12
REPORT_SCOPE_LIVE_SET_MATCH=true
REPORT_SCOPE_MISSING=none
REPORT_SCOPE_EXTRA=none
REPORT_DEMO_REF=vtzqjmazsvurxdeondmi
REPORT_K2_VALUES=+120.4,+206.0,+108.4
REPORT_SCOPE_CROSSCHECK_DIRECT_EXIT=0
```

K2 ham çıktı `k2_txid_yuk.out` içinde aynı değerleri veriyor:

```text
DELETE | 220.3 | 3.6  | 60.75 | 108.4
INSERT | 294.0 | 53.2 | 5.52  | 120.4
UPDATE | 459.3 | 47.3 | 9.70  | 206.0
```

Düzeltme ref aralığının dosya listesi dokuz ilgili dosyadan oluşuyor: etiket
map'i, etiket unit testi, maske migration'ı, cleanup/regression SQL'i, dört
ham kabul çıktısı ve teslim raporu. Her biri LUNA-1..4 kanıtı veya bu kanıtın
rapor yüzeyi; ilgisiz ürün dosyası yok.

```text
git diff --name-status 6fabaf5 7c6e871
M js/degisiklikler/etiketler.js
M reports/2026-09-13-surum-gecmisi-W1/k1_iud_log.out
M reports/2026-09-13-surum-gecmisi-W1/k1b_immutability.out
M reports/2026-09-13-surum-gecmisi-W1/k2_txid_yuk.out
M reports/2026-09-13-surum-gecmisi-W1/k3_geri_alma.out
M reports/2026-09-13-surum-gecmisi-W1/k3_geri_alma.sql
M reports/2026-09-13-surum-gecmisi-teslim.md
A supabase/migrations/20260913000004_luna_bilet_maske.sql
M tests/unit/degisiklikler-etiketler.test.js
CORRECTION_DIFF_CHECK_EXIT=0
LEGACY_SURFACE_UNCHANGED=1
```

Bu alt ölçütler (ref, kapsam, K2 kanıtı ve diff hijyeni) doğru.

## 4. Test temizliği / paylaşımlı DEMO kayıtları — YANLIŞ

Hedef SQL başlangıçta yalnız bilet anahtarlarını ve şifre hash'ini
snapshot'lıyor (`7c6e871:reports/2026-09-13-surum-gecmisi-W1/k3_geri_alma.sql:46-51`).
Son cleanup `:519-523` ile snapshot'ta olmayan biletlerin kullanımını ve
biletini siliyor; `:526-530` mevcut şifre varsa yalnız hash'i geri yazıyor.

Standart hedef koşumu başlangıçta paylaşımlı gizli kayıt olmadığından
`S11b ... bilet=0 sifre=0` verdi ve tek başına korumayı kanıtlamadı. Bu açığı
ölçmek için DEMO'da yalnız test sentinel'i (aktif bilet, ona bağlı kullanım ve
şifre hash'i) oluşturuldu:

```text
sentinel_inserted password=1|ticket=1|usage=1
SHARED_SENTINEL_SETUP_DIRECT_EXIT=0
```

Aynı hedef k3 betiği sentinel ile çalıştırıldı:

```text
S0a ... SIFRE_HATALI sifrevardi=t ... PASS
S13 ... tam=0 maske=15 ... PASS
S11b ... bilet=1 sifre=1 ... PASS
== özet ==
45 | 0 | 45
TARGET_K3_SHARED_SENTINEL_DIRECT_EXIT=0
```

Post-check satırların silinmediğini ve hash'in kaldığını, fakat aktif biletin
artık aktif olmadığını gösterdi:

```text
sentinel_ticket_count=1|sentinel_usage_count=1|sentinel_ticket_active=false|sentinel_password_matches=true|k3_owned_ticket_rows=0|k3_owned_usage_rows=0|k3_marker_logs=0
SHARED_SENTINEL_POST_K3_SELECT_EXIT=0
```

Mekanizma: hedef `sahip_sifresi_ayarla` migration'ı
`20260913000003_surum_gecmisi_f2_sahip_sifresi.sql:31-33` ile tüm geçerli
biletleri `son_gecerlilik=now()` yapıyor; k3 cleanup ise snapshot'taki bilet
satırının `son_gecerlilik` alanını geri yüklemiyor. Yani kendi ürettiği
kayıtları temizleme kısmı geçiyor, ancak paylaşımlı aktif bilet kaydı
değiştiriliyor; “paylaşımlı kayıt korunur” kabulü sağlanmıyor. Aynı nedenle
şifre `guncelleme` metadata'sının tam snapshot/restore'u da kodda yok
(`:50` yalnız hash snapshot'lıyor, `:527` yalnız hash yazıyor).

Sentinel, yalnız bu denetimin oluşturduğu kayıt olarak kaldırıldı ve son durum
SELECT ile doğrulandı:

```text
sentinel_ticket=0|sentinel_usage=0|sentinel_password=0|k3_marker_logs=0
SHARED_SENTINEL_CLEANUP_DIRECT_EXIT=0
```

## Ek — regresyon ve önceki doğru maddeler

Hedef ref geçişinde focused ve full unit doğrudan çalıştırıldı; hedef ref
geçici `TMPDIR` kopyasında koştu, ürün checkout'u değiştirilmedi:

```text
TARGET_FOCUSED_UNIT: tests 20, pass 20, fail 0
TARGET_FOCUSED_UNIT_DIRECT_EXIT=0

BASELINE_6FABAF5: tests 814, pass 813, fail 1
BASELINE_6FABAF5_FULL_UNIT_DIRECT_EXIT=1
  bilinen hata: tests/unit/gecmis-pipeline.test.js:283

TARGET_7C6E871: tests 816, pass 815, fail 1
TARGET_FULL_UNIT_DIRECT_EXIT=1
  aynı bilinen hata: tests/unit/gecmis-pipeline.test.js:283
```

Sonuç: düzeltme turu yeni unit kırmızısı eklememiş; iki yeni etiket testi
geçiyor. Hedef k3'te önceki denetimde DOĞRU olan alan/satır/işlem revert,
çakışma, bağımlılık, composite-PK, revert-in-revert ve immutability komşu
yolları `45/45` içinde kaldı. Legacy `js/gecmis.js` ve eski migration yüzeyi
değişmedi.

PROD yokluk kontrolü yalnız Supabase Management API database/query yüzeyine
SELECT gönderilerek yapıldı:

```text
PROD_REF=zqnexqbdfvbhlxzelzju
[{"json_build_object":{"db":"postgres","degisim_log_exists":false,"surum_gizli_schema_count":0,"new_public_function_count":0,"new_related_trigger_count":0,"new_hidden_relation_count":0}}]
HTTP_STATUS=201
PROD_SELECT_CURL_DIRECT_EXIT=0
```

Gerçek DEMO tarayıcı/RPC final akışı bu yeniden denetimin dört maddesi içinde
yeniden ölçülmedi; teslim raporundaki sahip kapısı olarak **ÖLÇÜLEMEDİ** kaldı.

## Sonuç

Güvenlik maskesi ve teslim raporu hijyeni geçti; fakat tüm canlı kapsam
alanlarının Türkçeleştirilmesi ve paylaşımlı aktif ticket'ın cleanup sonrası
korunması kanıtlanmadı.

**DÜZELTME İSTE (1) 39 kapsam tablosundaki 81 fallback alanını Türkçeleştirip canlı kolonlarla regression ekle; (2) k3 cleanup'ında koşum öncesi bilet satırının tüm alanlarını ve şifre metadata'sını tam geri yükle, aktif paylaşımlı sentinel ile yeniden kanıtla.**
