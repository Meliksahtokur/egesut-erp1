# L4-W4 — Motor onarımı: DB teslim raporu

**Goal:** G-20260914-GERI-ALMA-AKISI — Onarım turu sözleşmesi (root kararı
2026-09-14/2, BAĞLAYICI) · **Dal:** `agent/geri-alma-akisi-W4` (taban 5f483f2) ·
**Tarih:** 2026-09-14
**Durum:** TESLİM — luna L4-01/02/03/04/06 kapatıldı; k4_onarim **32/32 PASS**
(W1 §3'ün 22 vakası yeni sözleşme beklentileriyle + A1..A6 adversarial + V5a2/V5c)
+ k3 regresyon **46/46 PASS** + unit **997/997/0** (JS dokunulmadı).
**Yalnız DEMO (vtzqjmazsvurxdeondmi); PROD'a hiçbir şey uygulanmadı ve hiçbir
komutta PROD ref'i geçmedi.**

---

## 1. Teslim kapsamı (dosyalar + blob SHA)

| Dosya | İçerik | Blob SHA (git hash-object) |
|---|---|---|
| `supabase/migrations/20260914000003_l4_onarim.sql` | L4-01/02/03/04/06 onarımı (tek migration, replay-safe; DEMO'ya 3× uygulandı (son 2'si replay; tümü EXIT=0)) | `dd6623b7c7c413bfd5d7de59ac275a6152194ac5` |
| `reports/2026-09-14-geri-alma-akisi-W4/k4_onarim.sql` | Kabul koşumu (32 vaka; aşağıda) | `035eb7a92a764a3a6655ac80fc4992c27b9a76c8` |
| `reports/2026-09-14-geri-alma-akisi-W4/k4_onarim.out` | k4 çıktısı (32/32) | koşum artefaktı (commit'le dalda) |
| `reports/2026-09-14-geri-alma-akisi-W4/k3_regresyon.out` | k3 46 vaka regresyon çıktısı (kaynak: ana checkout `reports/2026-09-13-surum-gecmisi-W1/k3_geri_alma.sql`, değiştirilmedi) | `b6f7cbfc7d9d69d020188ed42e9c48fe61a746e3` |
| `reports/2026-09-14-geri-alma-akisi-W4/probe_sema_w4.{sql,out}` | Onarım öncesi canlı DEMO salt-okunur şema yoklaması (policy/ACL/FK envanteri) | — |
| `reports/2026-09-14-geri-alma-akisi-W4/m3_dogrulama.{sql,out}` | Migration sonrası canlı doğrulama (trigger/policy/grant) | — |

**Gate bulgusu (kırıntıya da işlendi):** W1'in özgün `k4_l4_motoru.sql` hiçbir
worktree'de kalmadı (W1 worktree'si kapanmış, ana checkout'a kopyalanmamış).
22 vaka, W1 raporu §3 tablosu + k3_geri_alma.sql deseninden yeniden kuruldu;
beklenti güncellemeleri §3'te tek tek gerekçelendirildi.

## 2. Onarım maddeleri — ne yapıldı

### L4-01 — `l4_rehber` sunucu üretir (jeton tablosu mekanizması)
**Seçim:** Zarfın önerdiği iki yoldan **jeton tablosu**
(`surum_gizli.l4_rehber_adimlari`) seçildi; gerekçe: onizle ve geri_al ayrı
transaction'larda koştuğu için GUC köprüsü taşınamaz; deterministik
yeniden-üretim ise orta-dizi durumunda (örn. drift'li birim revert edildikten
sonra kalan zincir artık temiz göründüğünde) rehberi yeniden üretemediği için
üyelik kararı veremiyordu. Jeton tablosu "sunucunun KENDİ ürettiği rehber"
ibaresini birebir modeller.

- `_l4_zincir` sıralı rehber ürettiğinde her adım `(tablo, satir_pk, txid,
  kok_txid)` olarak kayda yazılır (`ON CONFLICT DO NOTHING`; üretim anında
  7 günden eski adımlar tembel süpürülür).
- Gevşetme, `_degisim_plan` içinde yeni `surum_gizli._l4_rehber_uyesi(p_hedef)`
  ile doğrulanır: **yalnız `satir` seviyesinde** (L4-04) ve hedef kayıtta
  (7 gün taze) bulunuyorsa. `p_hedef`'teki herhangi bir `l4_rehber` anahtarı
  **hiçbir yerde okunmaz** (kodda artık hiçbir okuma noktası yok).
- Rehber hedeflerinden `'l4_rehber': true` anahtarı **kaldırıldı** — yetki
  artık sunucu kaydından gelir, bayrak taşınamaz (L4-04).
- Tablo `REVOKE ALL ... FROM PUBLIC, anon, authenticated`; yalnız SECURITY
  DEFINER motor yolları (postgres) yazar/okur.

### L4-02 — sahtecilik kapanması (3 katman)
1. **Köprü trigger:** `_islem_log_degisim_txid` artık `NEW.degisim_txid :=
   txid_current()` yazıyor — koşulsuz; trigger'daki `WHEN (NEW.degisim_txid IS
   NULL)` koşulu DROP+CREATE ile kaldırıldı (istemci değeri her zaman ezilir;
   A4 kanıtı).
2. **GERI_ALINDI kapısı:** yeni BEFORE INSERT trigger
   `trg_islem_log_geri_alindi_kapisi` — `NEW.tip='GERI_ALINDI'` ve
   `app.geri_alma_aktif` GUC'i 'on' değilse `RAISE ... ERRCODE 42501`.
   `degisim_geri_al` telafi INSERT'inden önce
   `set_config('app.geri_alma_aktif','on',true)` (is_local; tx sonunda
   otomatik düşer + açıkça temizlenir). A3 kanıtı.
3. **Authenticated INSERT kapandı (canlı şemadan doğrulanarak):** ölçüm
   (`probe_sema_w4.out`): `service_insert` policy'si `FOR ALL TO public USING
   true WITH CHECK true` + authenticated tablo-grant INSERT açık;
   `postgres` ve `service_role` `rolbypassrls=t`. Uygulama `islem_log`'a
   yalnız SELECT yapar (js/api.js:417; tüm iş yazımları SECURITY DEFINER
   RPC'lerde). Uygulanan: `REVOKE INSERT ON islem_log FROM authenticated` +
   `service_insert` artık `FOR INSERT TO service_role WITH CHECK (true)`;
   `islem_log_select` (SELECT TO public) **korundu** → uygulamanın tüm okuma
   yolları etkilenmez. A6 kanıtı: authenticated INSERT → `42501 permission
   denied for table islem_log`.

### L4-03 — zincir kapsamı (K1 YENİ tanım)
`_l4_zincir`'den **kolon-adı hayvan köprüsü (eski (b2) bloğu) tamamen
kaldırıldı** (+ kullanılmayan `c_hayvan_kolonlar` sabiti). Zincir üyeliği artık:
(a) zincir satırlarında hedef adımından sonraki tüm değişiklikler; (b)
`pg_constraint`'ten doğrulanan **gerçek FK alt kayıtlarında** planı gerçekten
engelleyen değişiklikler (mevcut (b1) bloğu — izlenen çocuk → BAGIMLI_ADIM,
izlenmeyen çocuk (confdeltype≠'n') → aşılamaz ENGEL, bypass yok).
Aynı hayvanın ilgisiz olayları zincire girmez (A1: aynı hayvana sonraki
vaccination_log INSERT → planda yok, bağımlılıkta yok). **Dürüst FK ölçümü
(A5):** `dogum`→`tohumlama` FK'sı yok (yalnız `anne_id`/`buzagi_id`→`hayvanlar`);
tohumlama satırı, dogum mevcutken engellenmeden silinebiliyor (rollback'li
DELETE ölçümü) → doğum otomatik zincire girmez; bağımsız (satir/işlem) hedef
olarak geri alınır. Bu, V4a/V4b'nin W1 beklentilerini (doğum=BAGIMLI_ADIM,
dogum=0) yeni sözleşme gereği değiştirir: **doğum HAYATTA kalır (dogum=1)**.

### L4-04 — rehber adımı satır seviyesiyle
Planner rehber hedefleri `{tablo,pk,txid}` (bayraksız); gevşetme yalnız
`satir` seviyesinde üye hedeflerde çalışır. Kanıt: V5b (bayraksız tekil geri
alma ok), V5c (3-adım rehber sırasıyla 3/3; üçüncü adım iz-çifti gevşetmesiyle
geçer), A2 (bayraklı çağrı gevşetme ÜRETMEZ). W2'nin `seviye:'islem'`
gönderen kodu UI tarafı kalıntısıdır — W5 kapsamı (motor `islem`'i hiçbir
zaman gevşetmez).

### L4-06 — `payload.orijinal_tip` gerçek işlem tipi
Telafi kaydında `orijinal_tip`: (1) önce plan txid'leri `degisim_txid`
köprüsünden `islem_log.tip`'e çözülür (`DISTINCT` birleşik); (2) çözülmezse
fallback = hedef tablo + işlem etiketi (`'padoklar ekleme, guncelleme'`
biçiminde). `'I,U'` harf kümesi üretimi **kaldırıldı**. Kanıt: V6a
(otip=`TOHUMLAMA`, köprüden; telafi satırının `degisim_txid`'i =
`geri_alma_txid`), V6c (fallback etiketi), V6b (orijinal islem_log satırı
tam-alan değişmedi).

## 3. Kabul kanıtları — koşumlar ve EXIT'ler (hepsi DEMO)

| Koşum | Komut | EXIT |
|---|---|---|
| Migration uygulama | `psql … -v ON_ERROR_STOP=1 -f supabase/migrations/20260914000003_l4_onarim.sql` → `m3_uygula1.out` | 0 |
| Replay (replay-safe kanıtı) | aynı komut 2. kez → `m3_uygula2_replay.out` | 0 |
| Review sertleştirmesi sonrası yeniden uygulama | aynı komut 3. kez → `m3_uygula3_sertlestirme.out` | 0 |
| k4 kabul | `psql … -f reports/2026-09-14-geri-alma-akisi-W4/k4_onarim.sql` → `k4_onarim.out` | 0 — **32 PASS / 0 FAIL** |
| k3 regresyon | `psql … -f reports/2026-09-13-surum-gecmisi-W1/k3_geri_alma.sql` → `k3_regresyon.out` | 0 — **46 PASS / 0 FAIL** |
| Unit baseline | `NODE_PATH=/home/melik/egesut-erp1/node_modules node --test tests/unit/*.test.js` | 0 — **997/997/0** (W4 JS değiştirmedi; sayı W3-entegrasyon sonrası dal baseline'ı) |
| Canlı doğrulama | `m3_dogrulama.sql` (BEGIN READ ONLY) | 0 — trigger defs / policy / grant aşağıda |

Migration sonrası canlı gerçek (`m3_dogrulama.out`): köprü trigger tanımında
`WHEN` yok; `trg_islem_log_geri_alindi_kapisi` yerinde; policy'ler
`islem_log_select (SELECT, {public})` + `service_insert (INSERT,
{service_role}, check=true)`; authenticated'in yalnız SELECT grant'ı var;
`surum_gizli.l4_rehber_adimlari` mevcut.

### k4_onarim vaka × sonuç (32/32 PASS — tam satırlar `k4_onarim.out` içinde)

| Vaka | W1 §3 karşılığı | Sonuç |
|---|---|---|
| S0 şifre kur | S0 | PASS |
| V2 köprü: degisim_txid == degisim_log.txid (18378=18378) | V2 | PASS |
| V1a zaman → aynı tx eşleşir | V1a | PASS |
| V1b 120 sn aşan → ZAMAN_ESLESME_YOK + en_yakin | V1b | PASS |
| V1c txid + zaman → txid kazanır | V1c | PASS |
| V1d olmayan pk → SATIR_YOK (hayvanlar/text-pk) | V1d | PASS |
| V1e logsuz satır → LOG_YOK | V1e | PASS |
| V1f zincir boş txid → LOG_YOK | V1f | PASS |
| V4a K1 YENİ: doğum FK'sız → plana girmez (plan=2, dogum_plan=0, dogum_bag=0) | V4a (beklenti güncellendi) | PASS |
| V4b zincir uygula: adim=2 tek tx; tohumlama=0 **dogum=1** hayvan=1 | V4b (beklenti güncellendi) | PASS |
| V6a telafi orijinal_tip=TOHUMLAMA (gerçek tip; telafi degisim_txid=geri_alma_txid) | V6a (beklenti güncellendi) | PASS |
| V6b orijinal islem_log satırı birebir değişmedi | V6b | PASS |
| V8a satır hedef → TAM çakışma listesi (2 kayıt, zengin alanlar) | V8a | PASS |
| V8b alan hedef → alana dokunan tüm sonrakiler (1) | V8b | PASS |
| V3a zincir aynı-satır: 3 adım E3→E2→E1 | V3a | PASS |
| V3b zincir uygula: tek tx, tek geri_alma_txid, satır silinir | V3b | PASS |
| V6c telafi fallback: orijinal_tip='padoklar ekleme, guncelleme' | V6c (beklenti güncellendi) | PASS |
| V5a kaymalı zincir → ga=false, rehber=1 (kaymalı T2 dışarıda; hedef BAYRAKSIZ) | V5a (bayrak kaldırıldı) | PASS |
| V5a2 jeton kaydı: kayit(T1)=1, kayit(T2)=0 | yeni (L4-01) | PASS |
| V5b rehber adımı bayraksız satir hedefle geri alındı | V5b | PASS |
| V5c-0 3-adım rehber [txC,txB,tX] (blok T4'te) | yeni (iz-çifti kanıtı zemini) | PASS |
| V5c rehber sırasıyla 3/3 (3. adım iz-çifti gevşetmesi) | yeni (L4-01 davranış kanıtı) | PASS |
| V7 zincir >100 → ZINCIR_COK_UZUN (102 adım) | V7 | PASS |
| V7b başlangıç >100 → ZINCIR_COK_UZUN (101) | V7b | PASS |
| A1 ilgisiz aynı-hayvan aşı INSERT → planda/bağımlılıkta yok | yeni (K1 yeni) | PASS |
| A2-1 sahte l4_rehber (üye değil, temiz sonraki giriş) → CAKISMA | yeni (L4-01) | PASS |
| A2-2 sahte l4_rehber (kaymalı satır) → CAKISMA | yeni (L4-01) | PASS |
| A3 sahte GERI_ALINDI (postgres, GUC yok) → 42501 | yeni (L4-02b) | PASS |
| A4 sahte degisim_txid=424242424 → ezilir (damga=txid_current) | yeni (L4-02a) | PASS |
| A5 doğum FK'sız: plan/bağımlılık/rehber=0; tohumlama silinimi engellenmez | yeni (K1 yeni ölçüm) | PASS |
| A6 authenticated islem_log INSERT → 42501 permission denied | yeni (L4-02c) | PASS |
| TEMIZLIK: log=0 padok=0 hayvan=0 islem_log=0 jeton=0; şifre metadata birebir | TEMIZLIK | PASS |

## 4. Tasarım notları / kalan riskler

1. **Jeton tablosu yaşam döngüsü:** adımlar zincir önizlemesi/uygulaması
   rehber ürettiğinde yazılır; `_l4_rehber_uyesi` 7 gün tazeliği ister;
   `_l4_zincir` üretim anında eski kayıtları tembel süpürür. Üyelikler
   (tablo, txid, satir_pk) UNIQUE — tekrar üretim çoğaltmaz.
2. **`degisim_onizle` artık yan-etkili** (rehber üretirken jeton yazar):
   `BEGIN READ ONLY` içinde 'zincir' önizlemesi çağrılırsa bloklanan zincirde
   yazı hatası döner. Salt-okunur denetim desenlerinde 'zincir' çağrısından
   kaçınılmalı (bu koşumdaki tüm READ ONLY probe'ları tablo okumasıdır,
   etkilenmez).
3. **GUC kapısının sınırı:** `app.geri_alma_aktif` özel GUC'ını rol bazında
   kilitleyemeyiz; kapının authenticated'ya karşı sert katmanı RLS/grant
   kapatmasıdır (A6). postgres/service_role (DBA) seviyesinde bir kimlik
   GUC'i elle set edip GERI_ALINDI yazabilir — bu rol zaten operatör
   yetkisindedir; kalıntı risk olarak belgelenir.
4. **`tohumlama.sperma LIKE 'k4-%'` temizlik deseni:** k4 sahnesi işaretli
   veri kullanır; prod verisiyle çakışmaz ('k4-' öneki sahte üretim).
5. **W5'e not:** W2 rehber hedefini `seviye:'islem'` ile gönderiyor
   (luna L4-04 UI yarısı) — motor tarafı hazır; UI `satir` gönderecek ve
   hedefi olduğu gibi geçirecek (bayrak yok; taşınanı da motor yok sayar).
6. **Prod runbook notu (root kapısı):** migration 3, PROD'a alınırken L2'nin
   4 migration'ının ARDINDAN sıralı uygulanmalı (`surum_gizli` ve
   `degisim_log`/`l4_rehber_adimlari` bağımlılıkları). `service_insert`
   daraltması PROD'da da authenticated SELECT'i etkilemez (SELECT policy'si
   ayrı), ancak PROD'da uygulama dışı bir islem_log yazarı varsa (canlı
   doğrulama gerekli) etkilenir.

## 5. Builtin subagent review notu (ZORUNLU)

code-reviewer alt-ajanı (builtin) migration 3 + k4 koşumu + eski gövdelerle
mekanik diff + sözleşme üzerinde koşturuldu (34 araç çağrısı; claim a-h tek tek
kod/artefakt üzerinden doğrulandı). Sonuç: **migration seviyesinde tüm
iddialar doğrulandı, istenmeyen drift YOK** (`degisim_onizle` gövdesi
bayt-bayt aynı; diğer üçünde yalnız belgelenmiş onarım düzenlemeleri).
Benim bağımsız satır-diff'im de aynı sonucu verdi.

**Bulgular ve çözüm durumu:**

| Sev. | Bulgu | Çözüm |
|---|---|---|
| CRITICAL (review'in etiketi) | `js/degisiklikler/degisiklikler.js:547` rehber adımlarını hâlâ `seviye:'islem'` ile gönderiyor → gevşetme UI'dan hiç devreye girmez (satir şart) + `islem` tx'in bütün satırlarını planlar (aşırı-geri-alma riski) | **W4 KAPSAMI DIŞI — W5'e raporlandı:** W4 zarfı L4-04'ü "motor tarafı" ile sınırlandırır ve "(UI satir gönderecek — W5)" der; lead kabul maddesi de "4 motor tarafı uyumlu" diye ayrı tutar. W5 aynı dosyada çalıştığından buradan dokunulmadı. Motor tarafı k4 V5b/V5c ile kanıtlı. |
| Important | jeton adımlarında sahip/kök bağlanğı yok — başka akıştan/geçen biletten 7 gün boyunca gevşetme tetiklenebilir | Kabul edilen kalıntı (sınır: gevşetme yalnız iz-çiftlerini ve etkisi geri dönülmüş girişleri atlar; gerçek sonraki değişiklik ve drift A2-1/A2-2 ile bloke). Önerilen düzeltmeler istemci sözleşmesiyle çelişiyor (bilet önizleme anında bilinmiyor; kök txid istemciden istenemez — bayrak yasağı L4-01'in özü). Lead'e not §6.2. |
| Important | `app.geri_alma_aktif` penceresi apply fazını kapsıyordu | **Düzeltildi:** `set_config('on')` telafi INSERT'inin hemen önüne taşındı (kapı penceresi gerçek kullanıma sıkıştı). Yeniden uygulama + k4 32/32 + k3 46/46 ile kanıtlı. |
| Minor | `_degisim_plan` EXECUTE revoke edilmemişti (authenticated doğrudan ulaşırsa sert hata) | **Düzeltildi:** `REVOKE ALL ON FUNCTION surum_gizli._degisim_plan(jsonb,text) FROM PUBLIC, anon, authenticated` eklendi (W1'in `_l4_zincir` revoke deseniyle parite). |
| Minor | jeton INSERT regex'i bigint taşmasını dışlamıyor | Ulaşılamaz (tek yazar `e.txid::text` bigint kaynağı) — nit olarak kabul. |
| Minor | katalog-geneli SECURITY INVOKER islem_log yazarı taraması yoktu | **Koşuldu:** `probe_islem_log_yazarlari.out` — islem_log'a yazan 63/63 fonksiyon SECURITY DEFINER (owner postgres); INVOKER yazar YOK → policy daraltması tam güvenli. |
| Not (root onayı) | K1-YENİ'de engel yokken çapraz-satır sonraki olay (dogum) ne zincirde ne rehberde (frozen §3'ün harfi: rehber yalnız geri_alinabilir=false iken) | A5/V4a dürüst ölçüldü; kök-oturum yorum sorusu §6.3'te. |

Review'in VERDICT'i `DUZELTME-ISTEK`'tir; kritik bulgusu UI yarısıdır ve W4
zarfı gereği W5 kapsamındadır. Migration tarafındaki iki Important/Minor'dan
uygulanabilir olanlar bu dalda düzeltildi ve tüm koşumlar yeniden yeşillendi
(k4 32/32, k3 46/46, replay EXIT=0).

## 6. Açık sorular / lead'e notlar

1. **L4-04 UI yarısı (W5 için kritik):** `js/degisiklikler/degisiklikler.js:547`
   rehber adımlarını `seviye:'islem'` ile gönderiyor. Onarım sonrası motorda
   gevşetme yalnız `satir` seviyesinde çalışır → W5 entegrasyonunda rehber
   akışının çalışması için çağrı `satir`'a çevrilmeli (hedef `{tablo,pk,txid}`
   satir-tam). W5 yapılmadan UI'dan rehber akışı çalışmaz; motor tek başına
   doğru (k4 V5b/V5c). İsteğe bağlı ek sertlik: motor, üye hedefe `islem`
   çağrısını reddedebilir (review önerisi; W5/lead kararı).
2. **Jeton sahiplik bağlanğı:** adımlar kullanıcıya/bilete/kök-tx'e bağlı
   değil; 7 gün içinde başka biletli çağıran gevşetme tetikleyebilir. Sınır
   etkili (gerçek çakışma/drift hâlâ bloke — A2). Bilete bağlamak önizleme
   anında bilet bilinmediği için, kök-tx'e bağlamak istemciden kök istemek
   gerektiği (bayrak yasağı) için uygulanamaz. Kalıntı risk olarak kabul;
   root farklı karar verirse sözleşme gerekir.
3. **K1 yorum sorusu (root):** engel yokken (geri_alinabilir=true) çapraz-
   satır sonraki olaylar (ör. dogum) ne zincirde ne rehberde — frozen §3'ün
   harfi böyle (rehber yalnız bloke zincirde üretilir); K1 notunun "aksi
   hâlde rehberde sıralı adım olur" cümlesi blokeli senaryoyu anlatıyor.
   Sahibin beklentisi farklıysa sözleşme değişikliği gerekir.
4. **Kayıp k4 kaynağı:** W1'in `k4_l4_motoru.sql`'i hiçbir yerde yok; 22 vaka
   rapordan yeniden kuruldu (bu rapor §1'de beyan). Arşivden çıkarsa birebir
   karşılaştırma lead'te yapılabilir — engel değil.
5. **L4-09 (lead):** teslim raporu + hedefe pinli S1-S6+S3b yürüyüşü lead
   adımında yapılacak (zarf W4'ün kapsamı dışında).
6. **L4-07/L4-08 (UI):** bu turun kapsamı dışında; W5 zarfında.
