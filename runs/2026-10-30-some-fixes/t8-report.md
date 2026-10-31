⟦ss-sub model=opus effort=high rol=ss-worker-high iş=20261031000001 migration'ını prod'a uygula ve ground truth'u güncelle⟧
sonuc: KISMI
job_id: j-20261031T042036Z-c40db1
kabul SHA: a5dc5e5
progress: Brief'in 5 adımı bitti. Tek açık kapı `scripts/ground-truth-audit.sh` rc=1: 83 fark, apply öncesi ölçümle birebir aynı, bu işten gelmiyor.
BOYUT: bütçe brief'te yok · gerçek üretim kodu 0 (GT referans dosyası +148/−49) · bütçe içinde

## Özet

| Adım | Sonuç | Etiket |
|---|---|---|
| Yedek | `~/yedek/prod-yedek-2026-10-31-olu-yavru/`, manifest doğrulandı | MEASURED |
| Dry run | rc=0, 42703/42P01/42710 sıfır, NOTICE yok | MEASURED |
| Apply | HTTP 201, hata yok | MEASURED |
| `schema_migrations` | Kayıt var, `md5(statements[1])` = dosya md5 `97394445…` | MEASURED |
| Gövde md5 | `dogum_kaydet` `756c56af…`, `kupe_musait_mi` `1dd68d03…`, ikisi de migration ile eşit | MEASURED |
| ACL, `SECURITY DEFINER`, `search_path` | Değişmedi | MEASURED |
| GT refresh | Commit `a5dc5e5`, 4 fonksiyonda GT = canlı | MEASURED |
| `ground-truth-audit.sh` | **FAIL, 83 fark**, önce ve sonra aynı | MEASURED |
| `migration-sira-kilidi`, `dogum-kupe-recycle` | 1/1 ve 9/9 geçti | MEASURED |
| `veri-eslesme hepsi` | rc=0, `sizinti` 0, t5 bakiyesi kapandı | MEASURED |
| Gerçek doğum kaydı | Denenmedi (brief gereği); prod'da uçtan uca ölçülmedi | UNKNOWN |

Prod'a yazılan yalnız bu migration ve onun `schema_migrations` satırı. Push ve merge yok.

## Gelen iş denetimi

Üç bulgu, biri kapsamı belirledi:

1. **Yetki:** Brief "sahip onayı" diyordu, ama ajan mesajı onay sayılmaz. Oturum kaydında sahibin kendi cevabını okudum: `20261031000001` sorusuna 04:20 UTC'de "Uygula (Recommended)". CONFIRMED. Migration DROP/RENAME/TRUNCATE taşımıyor.
2. **Regen prosedürü tam regen değil:** `.claude/gt-v5-taslak/regen-proseduru.md` adım 3.1 mevcut GT'yi temel alıp canlı tanımla yama yapıyor. Bu yüzden kapsam brief'in saydığı nesnelerde kaldı.
3. **Araç:** Worktree'de `.env` yok, `q.sh` silinmişti. Yardımcı yeniden yazıldı. Audit, env ana checkout'un `.env` dosyasından verilerek koşuldu.

## Sapmalar

1. **`schema_migrations` kaydı ayrı istek.** t5 ile aynı: dosya kendi transaction'ını taşıyor, sarmalanmadı. İkisi de başarılı, kayıt geri okundu.
2. **Runbook adım 7 eklendi.** `veri-eslesme hepsi` brief'in maddelerinde yoktu, runbook'ta var. Salt okunur, koştum.
3. **Worktree'de başka yazıcı var.** Çalışırken `.harness/references/domain-rules.md`, `runs/2026-10-17-ovsync-mu-fix/KAFA-NOTU.md` ve üç devir dosyası değişti. Benim değil, commit'e girmedi (`a5dc5e5` tek dosya). Stage edilmedi, root'a kalıyor. OBSERVED

## Yedek ve rollback

`~/yedek/prod-yedek-2026-10-31-olu-yavru/` (repo dışı, dizin 700): `fonksiyonlar.json`, `schema_migrations_son.json`, `ROLLBACK.md`, `manifest.sha256`.

Rollback: `fonksiyonlar.json` içindeki `def` alanları çalıştırılır, `20261031000001` kaydı silinir. Migration satır yazmadığı için veri geri alımı yok. Bu sürümden sonra verilen küpeler kayıtlı kalır.

Apply öncesi drift yok: canlı `dogum_kaydet` md5'i 20261030000001 ile, `kupe_musait_mi` md5'i 20260901000002 ile eşit. Canlıdan migration'a fark yalnız ikiz guard ve kendi küpe koşulu satırları. MEASURED

## Ground truth diff'i

| Nesne | Değişen satır | Not |
|---|---|---|
| `dogum_kaydet` | 24 | Üç migration'dan fazlası: GT'de `COUNT(*)+1`, `11. Gün PG` kalmıştı, `_ilk_tohumlama_rota_kur` çağrıları yoktu |
| `gebelik_protokol_kontrol` | 147 | Çoğu biçim, canlı metin yazıldı; `etken_kod` değerleri yeni |
| `hizli_uygulama` (10 parametre) | 8 | `p_occurred_at` tarihe yazılıyor |
| `kupe_musait_mi` | 4 | Kendi küpe koşulu |
| `uq_hayvanlar_kupe_no` | satır çıktı | Canlıda yok; adı yalnız başlık notunda geçiyor |
| Başlık | 2 satır | `Tarih: 2026-10-31`, son senkron notu |

Gövdeler canlı `pg_get_functiondef` metniyle betikle yazıldı. Yeniden parse edildi: 4/4 md5 canlıyla eşit, tanım metni birebir var. MEASURED

## Audit: 83 fark

| Tür | Eksik | Fazla |
|---|---|---|
| Tablo | 2 (`gorev_ertele_kural`, `pg_application_event`) | 1 (`surum_gizli`) |
| Fonksiyon | 37 | 1 (`surum_gizli`) |
| Trigger bağlantısı | 42 | 0 |

- Apply öncesi ve sonrası çıktı `diff` ile aynı. MEASURED
- 9ecd6a0 bu tür farkı 79 olarak ayrı bakiye diye yazmıştı. Sayının 83'e çıkma nedenini tek tek ölçmedim. GT 2026-10-02'den beri senkron edilmediği için sonraki migration'lar olabilir. INFERRED
- Bu farkları kapatmadım: brief kapsamı üç migration'ın nesneleri, prosedür tam regen değil.

## veri-eslesme

| Ayak | Sonuç |
|---|---|
| `sizinti` | 0 şüpheli, t5'in ölçemediği ayak kapandı |
| `isaret` | BULGU 58, kombinasyon kümesi ve satır sayıları t7 ile birebir |
| `koken` | Yetim 0 |
| `statik` (varsayılan 10 eski dosya) | sabit=47, t7 ile aynı dosya kümesi; bu migration'ı kapsamıyor |
| `statik --dosya 20261031000001` | TEMİZ, sabit 0 |

Hüküm `BULGU: 58` bu işten değil: küme t7 ile aynı. MEASURED

Son durum sorgusu: aktif küpe tekrarı 0, doğum 83, hayvan 176. MEASURED

## Bakiye

1. **GT tam senkron:** audit 83 fark, ayrı kalem.
2. **GRANT satırları:** GT `dogum_kaydet` ve `gebelik_protokol_kontrol` için `TO anon` yazıyor, canlı ACL'de anon yok. Audit ACL ölçmüyor. Dokunmadım. MEASURED
3. **GT artefaktı:** `dogum_kaydet` kapanışından sonra `; LANGUAGE plpgsql SECURITY DEFINER;` artığı duruyor, eski. Dosya çalıştırılmıyor, dokunmadım. OBSERVED
4. **JS yayını:** t5'teki kısa süreli risk sürüyor; K7 düzeltmeleri `some-fixes` dalında, yayında değil. Merge+push root'ta. INFERRED
5. **Araç borcu:** Worktree'de `.env` olmadığı için `ground-truth-audit.sh` env verilmeden koşmuyor. Brief'teki komut tek başına çalışmaz. MEASURED

SORU: Audit'in 83 eski farkı bu teslimi bloke etsin mi? · seçenekler: ayrı GT senkron kalemi olarak bakiyede kalır ve t8 kabul edilir / şimdi tam senkron açılır · önerim: bakiyede kalsın; bu işin nesneleri canlıyla eşit ve fark sayısı değişmedi.

## Run kanıtı

Env notu: İlk komut, kabuğa `~/egesut-erp1/.env` yüklenmiş halde (`set -a; . .env; set +a`) worktree kökünde koşuldu. Token çıktıya yazılmadı; yardımcı log ve apply dosyalarında `sbp_` taraması 0.

```
scripts/ground-truth-audit.sh
```
rc: 1
```
   + trg_degisim_log -> irk_esik -> _degisim_log_yaz
   + trg_degisim_log -> kizginlik_log -> _degisim_log_yaz
   + trg_degisim_log -> padoklar -> _degisim_log_yaz
   + trg_degisim_log -> pedigree_meta -> _degisim_log_yaz
   + trg_degisim_log -> pedigree_nodes -> _degisim_log_yaz
   + trg_degisim_log -> pedigree_parentage -> _degisim_log_yaz
   + trg_degisim_log -> protokol_ayar -> _degisim_log_yaz
   + trg_degisim_log -> protokol_dismiss -> _degisim_log_yaz
   + trg_degisim_log -> protokol_instance -> _degisim_log_yaz
   + trg_degisim_log -> sablon_hastalik_eslem -> _degisim_log_yaz
   + trg_degisim_log -> semen_catalog -> _degisim_log_yaz
   + trg_degisim_log -> stok -> _degisim_log_yaz
   + trg_degisim_log -> stok_hareket -> _degisim_log_yaz
   + trg_degisim_log -> stok_kategorileri -> _degisim_log_yaz
   + trg_degisim_log -> tedavi -> _degisim_log_yaz
   + trg_degisim_log -> tedavi_sablonu -> _degisim_log_yaz
   + trg_degisim_log -> tedavi_sablonu_kalem -> _degisim_log_yaz
   + trg_degisim_log -> tohumlama -> _degisim_log_yaz
   + trg_degisim_log -> treatment_days -> _degisim_log_yaz
   + trg_degisim_log -> treatment_day_uygulamalar -> _degisim_log_yaz
   + trg_degisim_log -> uygulama_log -> _degisim_log_yaz
   + trg_degisim_log -> vaccination_log -> _degisim_log_yaz
   + trg_degisim_log -> vaccination_schedule -> _degisim_log_yaz
   + trg_degisim_log -> vaccine_diseases -> _degisim_log_yaz
   + trg_degisim_log -> vaccine_protocol_steps -> _degisim_log_yaz
   + trg_drug_classes_sistem_koru -> drug_classes -> _trg_drug_classes_sistem_koru
   + trg_hayvan_kisir_zincir_bitir -> hayvanlar -> _kisir_zincir_bitir
   + trg_uygulama_log_pg_geri_al -> uygulama_log -> _trg_uygulama_log_pg_geri_al

✗ AUDIT FAIL — 83 fark
```

```
ram-ultracode exec --class test --sh 'NODE_PATH=~/egesut-erp1/node_modules node --test tests/unit/migration-sira-kilidi.test.js'
```
rc: 0
```
✔ migration-sira-kilidi (106.149163ms)
ℹ tests 1
ℹ suites 0
ℹ pass 1
ℹ fail 0
ℹ cancelled 0
ℹ skipped 0
ℹ todo 0
ℹ duration_ms 229.457344
```

Apply, kayıt ve geri okuma:
```
--- apply 20261031000001
curl_rc=0
[]
__HTTP__201
--- record
curl_rc=0
[]
__HTTP__201
--- readback
[{"version":"20261031000001","name":"olu_yavru_kupe_serbest","created_by":"t8-prod-apply/some-fixes","n_stmt":1,"stmt_md5":"97394445d977e7be3ff16885d4c9f793"}]
__HTTP__201
file_md5 97394445d977e7be3ff16885d4c9f793
```

## Kırıntılar

- measurement: migration prod'da, kayıt ve gövde md5 eşit, GT refresh `a5dc5e5` (kayıtlı, workspace `some-fixes`).
- gate (doc-drift): `supabase/migrations/99999999999999_ground_truth.sql`, audit 83 fark, önce ve sonra aynı (kayıtlı).
- open_item: GT tam senkron, kapanış koşulu audit PASS (kayıtlı).
- assumption: regen prosedürü tam regen değil, kapsam üç migration'ın nesneleri (kayıtlı).
- assumption: brief'te workspace adı yok, t6 ile aynı `some-fixes` kullanıldı.
- Kod keşfi: SQL için canlı katalog, salt okuma; dize aramalarında grep. Atlas ve gitnexus sorgusu kullanılmadı. `analyze --index-only` koştu, indeks `a5dc5e5` ile güncel. MEASURED
