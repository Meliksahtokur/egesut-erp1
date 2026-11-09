⟦ss-sub model=opus effort=high rol=ss-worker-high iş=N7 P2-P9: ovsync-tren 8 migration'ını prod'a uygula (yedek, dry run, kapı, apply, kayıt, GT, doğrulama, P9 kuru), bayrak kapalı kalır⟧
sonuc: TAMAM
kabul SHA: bu raporu taşıyan commit (ovsync-tren dalında; GT + prod/ dosyaları). Push ve merge yok.
apply durumu: **UYGULANDI.** Prod commit anı 2026-11-09 19:22:29.93 UTC (sunucu `now()`). 8 migration ve 8 `schema_migrations` kaydı tek işlemde girdi. **3. tur (P10):** sahip onayıyla bayrak 19:48:56Z'de açıldı (`ovsync_tren_aktif`=1). Dönen liste P9 ile birebir. Demo köprüsü yenilendi. Ayrıntı `## P10`.
Tur geçmişi: 1. tur KISMI bitti. `db-dry-run.sh` araç arızası yüzünden SORU açıldı. Root kararı (a): P3 kanıtı = prod provası + db-validate 8/8 + md5 16/16. 2. tur P4–P9 bu kararla yapıldı. 3. tur: P10, root üzerinden gelen sahip onayıyla (bkz. `## P10`).
BOYUT: bütçe 0 üretim kodu (GT eki mekanik) · gerçek 0 · bütçe içinde. GT +3734/−2, tamamı canlı katalogdan üretildi.
Gelen iş denetimi: bulgu yok. 8 dosyada BEGIN/COMMIT, CONCURRENTLY, DROP TABLE/COLUMN, TRUNCATE ya da DELETE yok. DROP yalnız 3 fonksiyon imzasında var (MEASURED, grep).

## Hüküm
Ovsync treni migration'ları prod'da. 24 yeni fonksiyon, 16 fonksiyonun yeni gövdesi, `cases` tablosunda 2 kolon ve 5 ayar satırı canlı. Bayrak kapalı olduğu için davranış eski yolda. `ovsync_tren_onizle()` → `aktif:false` döndü. Yeni gövdelerin hepsi repo dosyalarıyla md5 düzeyinde eş (40/40). anon ya da PUBLIC hiçbir yeni fonksiyonu çalıştıramıyor. Kayıt, GT ve doğrulama aynı teslimde. Veri satırına UPDATE/DELETE yapılmadı. Prod'a yazılan veri yalnız migration'ın 5 ayar satırı ve 8 kayıt satırı.

## Mekanik kapı (P4 öncesi)

| madde | sonuç | etiket |
|---|---|---|
| P3: 42703/42P01/42710 = 0 | `db-dry-run.sh` 9/9 rc=66 (araç arızası, aşağıda). **Root kararı (a)** ile yerine geçen kanıt: prod provası 8 dosya tek işlemde, hata 0, `govde_fark` {}, ACL/anon 0, RAISE ile geri alındı (19:17:52Z) | MEASURED |
| db-validate (`--priors` ile seri) | **8/8 PASS** | MEASURED |
| md5 16/16 | 19:20:14Z'de ve apply'dan hemen önce 19:22:25Z'de yeniden ölçüldü: **16/16 eşit** (P1 ve P2 ile aynı) | MEASURED |
| apply öncesi durum | sm 189, `2026111010%` 0, `idle in transaction` 0, aktif istemci 1 (sorgunun kendisi) | MEASURED |

### dry-run arızası (açık kalemi root yazar)
1. `refresh_lsp_schema.sh` fonksiyonları view'lardan önce yüklüyor. `fn_part_5.sql:3959` adımı `relation "public.v_stat_saglik_vaka" does not exist` ile düşüyor (yerel F=290, canlı F=304) ve script fail-closed çıkıyor.
2. `db-dry-run.sh` tazelemeyi `LOCAL_LSP_URL` üzerinde yapıyor (refresh_lsp_schema.sh:242), denemeyi `NEON_LSP_URL` üzerinde koşuyor (db-dry-run.sh:117). Tazelenen DB ile denenen DB farklı. MEASURED

## P2 — yedek
- git: `backup/2026-11-09-ovsync-tren-oncesi` → `b9542b1` (main). Yalnız yerelde, push edilmedi. MEASURED
- Dizin: `~/tmp/ovsync-tren-prod-yedek-20261109T191249Z/` (izin 700). Manifest: `~/tmp/ovsync-tren-prod-yedek-20261109T191249Z/manifest.sha256` (1. tur sonu 41 dosya, 41/41 OK). 2. turda eklenen `kanit/p4-…`, `p5-…`, `p6-…`, `p7-…`, `p9-…` ve `betikler/gt-uret.py` için manifest yenilendi (aşağıda Run kanıtı). MEASURED
- Satır yedeği (read_only, 19:12:54Z): `protokol_ayar` 11 · açık `gorev_log` 240 · aktif `protokol_instance` 165 · aktif `cases` 32 · `treatment_days` 167 · `treatment_day_uygulamalar` 294. 16 fonksiyonun `pg_get_functiondef`, md5, ACL ve yorumu `fonksiyon16.json` ile `fn/*.sql` içinde. MEASURED

## Dosya listesi
`git diff --name-only main...ovsync-tren -- supabase/migrations/` kesişim prod'da kaydı olmayanlar = **8 dosya**, 20261110100001…100008. D9 bu 8 dosyanın içinde. D0–D9 dışında dosya yok. MEASURED

## P4 — apply
`python3 -I seri.py uygula --evet`. İstek 19:22:28.747Z, yanıt 19:22:30.890Z, **HTTP 201**. Tek işlem: `BEGIN` → 8 dosya, her birinden sonra kendi `schema_migrations` INSERT'i (`created_by ovsync-tren-n7-prod`) → işlem içi kapı (biri tutmazsa `APPLY_KAPI_RED` ve tümü geri) → `COMMIT`. Dosyaların kendi md5 korumaları da geçti. Ham yanıt: `kanit/p4-apply.txt`. MEASURED

## P5 — kayıt geri okuma (ayrı read_only oturum)
8 satır, 20261110100001…100008, `created_by ovsync-tren-n7-prod`. Her satırın `md5(statements[1])` değeri repo dosyasının md5'iyle **8/8 eş** (örnek 100001 `4e95de9b…f199`, 100008 `1274b85e…d7c084`). Toplam kayıt 197. MEASURED

## P6 — ground truth
- `supabase/migrations/99999999999999_ground_truth.sql` dosyasının sonuna "SENKRON 2026-11-09 (N7)" bölümü eklendi. İçerik: 2 kolon ve yorumları, 5 ayar satırı (`WHERE NOT EXISTS`), 3 eski imza için `DROP FUNCTION IF EXISTS`, 40 fonksiyon (canlı `pg_get_functiondef`), ACL aynası, 4 fonksiyon yorumu. Başlık `Tarih: 2026-11-09` ve "Son senkron" satırı güncellendi. Kaynak tek okuma-salt katalog çekimi (`betikler/gt-uret.py` → `kanit/gt-canli.json`). Üretici, canlı md5 = dosya md5 eşitliğini 40/40 assert etti. MEASURED
- GT'den yeniden okunan 40 gövdenin md5'i = migration dosyaları. `git diff --check` temiz. MEASURED

## P7 — doğrulama
| kontrol | sonuç | etiket |
|---|---|---|
| `ground-truth-audit.sh` | GT ekinden önce 140 fark, sonra **107**. Yeni fark **0** (önce/sonra satır farkı yalnız silme). 40 fonksiyondan kalan fark 0. 140 = önceki 116 + 24 yeni fonksiyon. 107 < 116, çünkü değişen 9 fonksiyonun eski "bilinen fark" kaydı da kapandı | MEASURED |
| `veri-eslesme-kontrol.py hepsi` | Brief'teki komut, script'in kendi kusuru yüzünden çöktü: `OSError: [Errno 7] Argument list too long: 'curl'` (sizinti, `-d body` argv'de >128 KiB). Yalnız taşıma kısmı değiştirilmiş kopya (`-d body` → `--data-binary @-` stdin; diff 1 satır, `kanit/p7-veri-eslesme-tasima.diff`) koşuldu, rc 0: **SIZINTI(şüpheli)=0**, **YETIM=0**, statik sabit 47 (11-05 ile aynı), isaret 61 kombinasyon | MEASURED |
| isaret 60→61 | Yeni kombinasyon `v_gorev_log_sync.aciklama:test`. Bugün 10:06Z'deki (apply öncesi) koşumda da 61 vardı. Apply'dan gelmiyor | MEASURED |
| yeni gövdelerin md5'i = repo | `govde_fark` {} (40/40), overload 0, eski 3 imza yok | MEASURED |
| `ovsync_tren_onizle()` | authenticated + sahip jwt ile çağrıldı: `{"ok":true,"aktif":false}`. `ovsync_tren_listele()` `aktif:false`, `trenler []`. `_ayar('ovsync_tren_aktif')`=0 | MEASURED |
| anon EXECUTE | 40 fonksiyonda `has_function_privilege('anon',…)` true sayısı **0**. anon/PUBLIC ACL 0, `proacl` NULL 0. İç (`_`) fonksiyonlarda authenticated 0, RPC'lerde authenticated eksiği 0. Açık kalemler ff39271e3d98 ve 36d89c3fdba9 bu ölçümle kapanır | MEASURED |
| `cases` | `ovsync_tren date NULL`, `ovsync_bagimsiz boolean NOT NULL DEFAULT false`. `tren_dolu` 0, `bagimsiz_true` 0 (veriye dokunulmadı) | MEASURED |

## P8 — doğum sonrası açık PG
19:18:20Z'de ve apply'dan sonra 19:29:43Z'de yeniden ölçüldü: P1(b) süzgeci **0**, geniş süzgeç 0. Yazma yapılmadı, adım atlandı. MEASURED

## P9 — göç kuru (canlı, apply sonrası)
`BEGIN; set_config(jwt sahip) + set_config(role authenticated); ovsync_tren_yeniden_hedefle(true, '2026-11-12')` tek istekte koşuldu ve RAISE ile geri alındı (an 19:29:21Z). Kimlik: `current_user`=authenticated, `auth.uid()`=sahip. Çıktı: `~/.herdr/worktrees/egesut-erp1/ovsync-tren/runs/2026-11-09-ovsync-tren/prod/p9-goc-kuru.json` (`kip: canli-kuru`). MEASURED
- **25 görev = 6 AYNI + 19 TAŞINIR**, KURAL_YOK 0. Üyelik: 169'un vakası (<prod-id>) → 2026-11-12. Belirsiz aşama 0. Sonuç 1. turdaki prova ön izlemesiyle birebir eş (`prova_onizleme_ile_ayni: true`). MEASURED
- Geri alma doğrulaması: ayrı read_only sorguda açık `OVSYNC_BASLAT` listesi (25 satır) çağrı öncesi listeyle birebir eş. `cases.ovsync_tren` dolu 0, `idle in transaction` 0. Görev hedefleri değişmedi. MEASURED

Sahip tablosu (küpe · bugünkü hedef → tren günü; hepsi Perşembe):

| # | küpe | şimdiki hedef | yeni tren | durum |
|---|---|---|---|---|
| 1 | 36 | 2026-11-12 Per | 2026-11-12 Per | AYNI |
| 2 | 38 | 2026-11-12 Per | 2026-11-12 Per | AYNI |
| 3 | 5708 | 2026-11-12 Per | 2026-11-12 Per | AYNI |
| 4 | 45 | 2026-11-30 Pzt | 2026-12-03 Per | TAŞINIR |
| 5 | 46 | 2026-12-04 Cum | 2026-12-03 Per | TAŞINIR |
| 6 | 51 | 2026-12-08 Sal | 2026-12-10 Per | TAŞINIR |
| 7 | 55 | 2026-12-25 Cum | 2026-12-24 Per | TAŞINIR |
| 8 | 56 | 2026-12-29 Sal | 2026-12-31 Per | TAŞINIR |
| 9 | 61 | 2027-01-08 Cum | 2027-01-07 Per | TAŞINIR |
| 10 | 62 | 2027-01-13 Çar | 2027-01-14 Per | TAŞINIR |
| 11 | 68 | 2027-02-27 Cmt | 2027-02-25 Per | TAŞINIR |
| 12 | 74 | 2027-03-12 Cum | 2027-03-11 Per | TAŞINIR |
| 13 | 75 | 2027-04-09 Cum | 2027-04-08 Per | TAŞINIR |
| 14 | 77 | 2027-04-29 Per | 2027-04-29 Per | AYNI |
| 15 | 78 | 2027-04-29 Per | 2027-04-29 Per | AYNI |
| 16 | 79 | 2027-05-05 Çar | 2027-05-06 Per | TAŞINIR |
| 17 | Test buzağı cabbiş | 2027-06-16 Çar | 2027-06-17 Per | TAŞINIR |
| 18 | 82 | 2027-06-27 Paz | 2027-07-01 Per | TAŞINIR |
| 19 | 85 | 2027-07-18 Paz | 2027-07-22 Per | TAŞINIR |
| 20 | 87 | 2027-07-22 Per | 2027-07-22 Per | AYNI |
| 21 | 88 | 2027-07-25 Paz | 2027-07-29 Per | TAŞINIR |
| 22 | 92 | 2027-08-11 Çar | 2027-08-12 Per | TAŞINIR |
| 23 | 94 | 2027-08-14 Cmt | 2027-08-12 Per | TAŞINIR |
| 24 | 97 | 2027-09-06 Pzt | 2027-09-09 Per | TAŞINIR |
| 25 | 3 | 2027-09-22 Çar | 2027-09-23 Per | TAŞINIR |

Sahip için anlamı: bayrak açılırsa 12 Kasım treninde 36, 38 ve 5708 değişmez, 169'un vakası bu trene bağlanır. Kalan 19 görev en yakın Perşembe'ye kayar: en çok 2 gün öne ya da en çok 4 gün geri (82, 85, 88). 17. satırdaki küpe adı "Test buzağı cabbiş", prod'da test kaydı gibi duruyor; dokunulmadı (sahibin bilgisine). INFERRED
Bayrak açma (P10) son saati: 2026-11-18 07:00 TR (P1; 181'in 19 Kasım trenine binmesi için).

## P10 — bayrak açma (3. tur, sahip onayıyla)
Onay root üzerinden geldi (birebir 2026-11-09: "1 2 EVET"; soru "Tren bayrağını şimdi açayım mı?"). Kanıt dosyaları `~/tmp/ovsync-tren-prod-yedek-20261109T191249Z/kanit/p10-*`.

| adım | sonuç | etiket |
|---|---|---|
| 1. P9 canlı kuru tekrarı (19:48:24Z, RAISE ile geri) | 25 = 6 AYNI + 19 TAŞINIR. `(gorev_id, eski, yeni, durum)` kümesi ve üyelik `p9-goc-kuru.json` ile **birebir eş** | MEASURED |
| 2. `ovsync_tren_ayar_guncelle(true, '2026-11-12')`, authenticated + sahip jwt | Tek işlem. İstek 19:48:56.484Z, commit 19:48:56.86Z, **HTTP 201**. Dönüş `ok:true, aktif:true, capa:2026-11-12` | MEASURED |
| 3. dönen liste = P9 | Hızlı geriden daha sıkı bir koruma kullandım. Dönen `gorevler` (id\|yeni\|durum) ve `uyelik` kümesi aynı işlem içinde P9 kümesiyle karşılaştırıldı; fark olsaydı `P10_FARK` RAISE ile tümü geri dönerdi (görev taşımaları dahil; hızlı geri taşımaları geri almaz). Koruma geçti ve commit oldu: **25/25 + üyelik 1/1 birebir**. Hızlı geri gerekmedi | MEASURED |
| 4a. geri okuma (read_only) | `protokol_ayar`: `ovsync_tren_aktif`=**1**, çapa 20261112, öne çekme 2, tolerans 1, `dogum_sonrasi_pg_gorev_aktif` 0. 25 görevin `hedef_tarih`'i = P9 `yeni` (fark 0), hepsi açık (iptal/tamam değil), saat 10:00 korunmuş. Açık `OVSYNC_BASLAT` (`NOT COALESCE(iptal,false)` süzgeciyle) 25. `islem_log`: 19 erteleme + 1 ayar kaydı. `idle in transaction` 0 | MEASURED |
| 4b. `cases.ovsync_tren` dolu | **1** (169, <prod-id> → 2026-11-12). `ovsync_bagimsiz` true 0 | MEASURED |
| 4c. `ovsync_tren_listele()` (authenticated, geri) | `aktif:true`, çapa 2026-11-12. **2026-11-12 grubu: 169, 36, 38, 5708** (ritim içi). İkinci grup 2026-12-03: 45, 46. Bağımsız 0. `ovsync_tren_onizle()`: `aktif:true`, `tren_gunu 2026-11-12`, `uye_sayisi 4`, `uye_kupeler [36, 38, 169, 5708]` | MEASURED |
| 5. demo köprüsü | Önce prova (geri alındı): `DROP SCHEMA prod_fdw CASCADE` + `IMPORT FOREIGN SCHEMA` (01_fdw_bridge.sql EXCEPT listesi) + `demo_klonla()` → `ok:true`, `ekstra_bosalan []`. Klon `cases.ovsync_tren`'i taşıyor (1 dolu). Şifre ve migration sayısı aynı, kapalı tetikleyici 0. **Commit yalnız köprü** (19:50:12Z, klon yok): `prod_fdw` 68 nesne, hariç tablo 0, `prod_fdw.cases`'ta 2 yeni kolon, **`demo_sema_diff()` = `{"eksik_kolon": [], "eksik_tablo": []}`**. İşlem içi koruma: demo `islem_log`, `hayvanlar`, `cases`, `gorev_log`, `degisim_log`, `stat_kayitli_grafik` sayıları ve tüm `protokol_ayar` değişmedi. Demo bayrağı (`ovsync_tren_aktif`=1, vitrin) dokunulmadan aynı. `demo_klon_log` max 22 (yeni klon yok) | MEASURED |
| 6. veri eşleşme (taşıma düzeltmeli kopya, P7 ile aynı tek satır fark) | rc 0 · **SIZINTI(şüpheli)=0** · **YETIM=0** · statik sabit 47 · isaret 61 (P7 ve bugün 10:06Z ile aynı küme) · prod_only 630→650 (bayrak işlemleri kaynaklı yeni prod satırları; bilgi, hükme girmez). Bir kez geçici `curl rc=35` alındı, script kendi yeniden denedi | MEASURED |

Sahip için anlamı: Ovsync treni prod'da açık. 12 Kasım Perşembe treninde 36, 38, 169 ve 5708 var. 19 hayvanın ileri tarihli başlangıç görevi en yakın Perşembe'ye taşındı, 6'sı zaten Perşembe'deydi. 181 ve 156 görevleri 11-17'de doğup 11-19 trenine binecek; 11-18 07:00 son saati geçmeden açıldı. INFERRED (P1 §e formülü)

## P11 — geri alma dosyası (hazır, KOŞULMADI)
`~/.herdr/worktrees/egesut-erp1/ovsync-tren/runs/2026-11-09-ovsync-tren/prod/geri-al.sql` = D8 dosyası + başlık notu. 16 gövdenin md5'i P2 prod yedeğiyle 16/16 eşit, ACL deseni P2 `proacl` ile uyumlu. Kolon DROP sahibin son onayını ister. MEASURED

## Bulgular
1. `db-dry-run.sh` / `refresh_lsp_schema.sh`: yükleme sırası kusuru ve tazelenen/denenen DB farkı. Runbook adım 3 şu an hiçbir migration'da çalışmıyor. MEASURED
2. `veri-eslesme-kontrol.py` sizinti: sorgu gövdesi curl'e argv olarak gidiyor ve demo büyüyünce `E2BIG` ile çöküyor. Düzeltme 1 satır (`--data-binary @-` + `input=body`). Script yazılabilir listemde değildi, repo kopyası değişmedi. MEASURED
3. `db-validate.sh` her koşumda ana checkout `reports/` altına rapor yazıyor (gitignore'da). OBSERVED
4. `_vaka_ac_tek` için authenticated EXECUTE kaldırıldı (D4 tasarımı, TR-ACL-2). `js/` içinde doğrudan çağıran yok (grep 0). MEASURED

## Kırıntılar
Root talimatıyla bu turun kırıntıları yalnız bu raporda. Kayıt: 1. turda 3 kırıntı `ss-crumbs` ile `fable-rol-ve-davranislar` workspace dosyasına düştü (gate `env-mismatch` db-dry-run.sh; measurement prova; decision kapı → SORU). Silmedim; root taşır ya da tüketir.
- gate (env-mismatch) · `~/egesut-erp1/scripts/db-dry-run.sh` + `refresh_lsp_schema.sh`: ayna tazeleme fail-closed (v_stat_saglik_vaka sırası) ve LOCAL/NEON hedef farkı. Kanıt: yukarıdaki dry-run bölümü.
- gate (env-mismatch) · `scripts/veri-eslesme-kontrol.py`: argv `E2BIG`. Taşıma düzeltmeli kopya ile ölçüldü. Kanıt: `kanit/p7-veri-eslesme.txt` + `kanit/p7-veri-eslesme-tasima.diff`.
- decision: root kararı (a) uygulandı. P3 kanıtı = prod provası + db-validate 8/8 + md5 16/16.
- measurement: apply 19:22:29.93Z, sm 197, 40/40 md5, anon 0, GT audit 140→107 (yeni fark 0), SIZINTI 0, YETIM 0, P9 25 = 6 + 19.
- measurement (P10): bayrak açık 19:48:56Z, 25/25 + üyelik birebir P9, 11-12 grubu {36, 38, 169, 5708}, demo köprüsü 68 nesne, `demo_sema_diff` {}.
- decision (P10): "fark varsa hızlı geri" yerine işlem içi küme koruması (fark → RAISE → tümü geri). Hızlı geri görev taşımalarını geri almadığı için daha güvenli. Koruma geçti.
- open_item (INFERRED): bayrak açıkken JS (merge + `?v=`) prod'da eski sürüm. UI'ın tren ekranı merge'e kadar görünmez; DB davranışı (cron görev doğumu, R9 hedefleme) şu an etkin. Root merge-gate.
- open_item: ff39271e3d98 ve 36d89c3fdba9 (anon EXECUTE) bu ölçümle kapanabilir: root `KAPANIS:` yazar.

## Run kanıtı
Ortam: worktree'de `.env` yok. Her komuttan önce aynı kabukta `set -a && . ~/egesut-erp1/.env && set +a` koşuldu. cwd `~/.herdr/worktrees/egesut-erp1/ovsync-tren`.

```
bash scripts/ground-truth-audit.sh
rc: 1
▶ Canlı canonical envanter alınıyor…
▶ Ground truth efektif envanteri hesaplanıyor…
  Tablolar : canlı=52 dosya=47 eksik=6 fazla=1
  Views    : canlı=16 dosya=13 eksik=3 fazla=0
  Fns      : canlı=321 dosya=269 eksik=53 fazla=1
  Triggers : canlı=85 dosya=42 eksik=43 fazla=0
   + trg_degisim_log -> vaccines -> _degisim_log_yaz
   + trg_drug_classes_sistem_koru -> drug_classes -> _trg_drug_classes_sistem_koru
   + trg_hayvan_kisir_zincir_bitir -> hayvanlar -> _kisir_zincir_bitir
   + trg_uygulama_log_pg_geri_al -> uygulama_log -> _trg_uygulama_log_pg_geri_al
✗ AUDIT FAIL — 107 fark
-- (GT ekinden önce aynı komut: ✗ AUDIT FAIL — 140 fark; önce/sonra fark satırları yalnız silme, 33 satır; yeni fark 0)
```
rc 1 beklenen: bilinen eski farklar bloke etmez, yalnız yeni fark sayılır.

```
python3 scripts/veri-eslesme-kontrol.py hepsi
rc: 1
[selftest] READ ONLY guard sınanıyor...
[selftest] OK — iki DB'de de yazma reddedildi (salt-okunur kanıtlandı)
Traceback (most recent call last):
  File ".../scripts/veri-eslesme-kontrol.py", line 530, in main
    bulgu += cmd_sizinta(prod, demo, args, out)
  File ".../scripts/veri-eslesme-kontrol.py", line 263, in cmd_sizinta
    prows = prod.sql(
  File ".../scripts/veri-eslesme-kontrol.py", line 105, in post_salt_okuma
    r = subprocess.run(
OSError: [Errno 7] Argument list too long: 'curl'
```
Taşıma düzeltmeli eşdeğer (aynı script, tek satır: `"-d", body` → `"--data-binary", "@-"` + `input=body`):
```
python3 <scratchpad>/ve/scripts/veri-eslesme-kontrol.py hepsi --cikti <scratchpad>/ve/cikti
rc: 0
[selftest] READ ONLY guard sınanıyor...
[selftest] OK — iki DB'de de yazma reddedildi (salt-okunur kanıtlandı)
[sizinti] ortak=57 kopya_tarihi=2026-07-02T00:00:00+03:00 SIZINTI(supheli)=0 bilgi: kesisim=7772 (klon_imzali=7772) pk_farki=0 demo_dogumlu=4724 prod_only=630 olculmeyen=18
[isaret] eslesen_kombinasyon=61 eslesen_toplam_satir=2860
[koken] fk=5 doldurulan=1 ad_eslesme=1 YETIM=0 std_dose_dolu=26
[statik] dosya=10 turetilmis=0 sabit=47 rpc_govdesi=38
HÜKÜM: BULGU: 61
```

```
python3 -I seri.py uygula --evet
rc: 0
HTTP 201 curl_rc 0
[{"bitis":"2026-11-09 19:22:29.932065+00","d":{"sm8":["20261110100001",…,"20261110100008"],"ayar":{"ovsync_tren_capa":20261112,"ovsync_tren_aktif":0,"ovsync_pg_kurallari_aktif":1,"ovsync_tren_one_cekme_gun":2,"dogum_sonrasi_pg_gorev_aktif":0,"ovsync_pg_erteleme_tolerans_gun":1},"kolon":{"ovsync_tren":"date:YES:","ovsync_bagimsiz":"boolean:NO:false"},"nesne":{"F":328,"T":60},"acl_null":0,"overload":{},"anon_exec":0,"eski_imza":{"adgk":false,"obgk":false,"sfsp":false},"sm_toplam":197,"tren_dolu":0,"govde_fark":{},"auth_exec_ic":[],"bagimsiz_true":0,"acl_anon_public":0,"auth_exec_rpc_yok":[]}}]
```

```
bash ~/egesut-erp1/scripts/db-validate.sh <dosya N> --priors <dosya 1..N-1>   (N=1..8)
rc: 0 (8/8, her biri "SONUÇ: PASS")
```

```
bash ~/egesut-erp1/scripts/db-dry-run.sh <8 dosya + seri>
rc: 66 (9/9) — ✗ Ayna tazeleme BAŞARISIZ — dry-run durduruldu (fail-closed).
```
