# P7 — Prod Adım B: yedek + L2 + L4 migration'ları (8 dosya) (FİNAL)

Tarih: 2026-09-15 · Dal: `agent/prod-adim-b` · Sahip onaylı PROD YAZIMI
(sahip kararı 2026-09-15: "uygula onayı verildi")
Zarf: `.ss/tasks/P7-prod-adim-b-l2l4.md`
Kaynaklar: L4 teslim raporu `.harness/reports/2026-09-14-geri-alma-akisi.md`
(doğrulama bölümleri; §8 runbook kullanılmadı — ESKİ), goal'ler
`G-20260913-SURUM-GECMISI.md` / `G-20260914-GERI-ALMA-AKISI.md`,
P1 ölçümü `reports/2026-09-15-prod-migration-olcum.md` §3 (#11–#18),
P2/P4 betik kalıbı `reports/2026-09-15-prod-adim-a/` ve
`reports/2026-09-15-prod-5-tohumlama/`.

**Kural uyumu:** Prod'a YALNIZ 8 dosya yazıldı, zarf sırasıyla: L2
`20260913000001..04`, L4 `20260914000001..04`. `20260902000001` koşulMADI,
Adım A dosyaları ve #5 tekrar uygulanmadı. `sahip_sifresi_ayarla`
ÇAĞRILMADI — mekanizma kuruldu, şifre değeri kurulmadı (root kendisi
kuracak). Tüm ön kontrol/doğrulama `BEGIN READ ONLY; … ROLLBACK;` sarmında;
prod'a test çağrısı (geri al/sürüm RPC'leri) YAPILMADI. Token değeri hiçbir
dosyaya yazılmadı. Yedek repo DIŞINDA.

## 0. Sonuç (tek paragraf)

**8 dosya prod'da CANLI.** Ön kontrol: 8/8 EKSİK/KISMİ (CANLI yok), ön
koşullar sağlam (39 hedef tablo + PK, identity-PK yok, pgcrypto var), canlı
site uyumu temiz (main `js/` `islem_log`'a yalnız SELECT — api.js:417; L2/L4
RPC'lerini hiç çağırmıyor; 8 dosya hiçbir mevcut imzayı kaldırmıyor).
Uygulama öncesi tam yedek alındı (52 tablo + şema, KAPI A+B yeşil) ve 8 dosya
dosya metni olduğu gibi, her biri tek istek/tek transaction olarak sırayla
uygulandı — **7,3 s, 8/8 OK, hatasız**. Doğrulama: 21 fonksiyonun canlı gövde
md5'i zincirin son tanımlayan dosyasıyla birebir; 4 public RPC ACL'si
(authenticated VAR, anon/PUBLIC yok) ve `sahip_sifresi_ayarla` (yalnız
service_role) demo referansıyla birebir; `trg_degisim_log` tam 39 tabloda;
`islem_log`'da authenticated INSERT kapalı, SELECT korunuyor; 52 tablonun
satır sayıları yedekle birebir; yeni 5 tablo 0 satır. Veri eşleşme kontrolü:
`statik` ×8 TEMİZ; `hepsi` **BULGU: 59** — uygulama öncesi (18:22) koşuyla
birebir aynı (59 kombinasyon / 2550 satır); 8 dosya 0 satır yazdığından
bulgular bu işle ilgisiz, önceden var olan veri durumu (§5). Sapmalar
bölümünde iki açıklamalı kalem var (yedek 1. deneme KAPI A + prod↔demo
2 fonksiyonda zincir ilerisi) — ikisi de beklenen davranış, veri kaybı/risk
yok (§7).

## 1. Ön kontrol (salt okunur) — `p7_precheck.py` / `precheck_summary.json`

### 1.1 Dosya durumları (P1 md5_normall yöntemi)

| # | Dosya | P1 (öğleden önce) | P7 ölçümü | Sonuç |
|---|---|---|---|---|
| 11 | `20260913000001_…f1_degisim_log.sql` | KISMİ | KISMİ (degisim_log yok, trg 0/39, 2 trigger-fn yok) | OK |
| 12 | `20260913000002_…f2_geri_alma.sql` | KISMİ | KISMİ (surum_gizli yok, 13 fn yok) | OK |
| 13 | `20260913000003_…f2_sahip_sifresi.sql` | KISMİ | KISMİ (fn + service_role grant yok) | OK |
| 14 | `20260913000004_luna_bilet_maske.sql` | EKSİK | EKSİK (maskeli `_degisim_log_yaz` yok) | OK |
| 15 | `20260914000001_l4_islem_log_kopru.sql` | EKSİK | KISMİ (kolon+trigger yok) | OK |
| 16 | `20260914000002_l4_geri_alma_zincir.sql` | EKSİK | EKSİK (5 fn yok) | OK |
| 17 | `20260914000003_l4_onarim.sql` | KISMİ | KISMİ (l4_rehber_adimlari yok, 7 fn yok) | OK |
| 18 | `20260914000004_l4_stok_uyari_txid.sql` | EKSİK | EKSİK (2 fn yok) | OK |

Zarf kapısı: **CANLI çıkan yok** → devam edilebilir. (KISMİ/EKSİK ayrımı
P1'in nesne-kapsamıyla aynı düzeyde; iki ölçüm tutarlı.)

### 1.2 Ön koşullar

| Koşul | Ölçüm | Sonuç |
|---|---|---|
| 39 hedef tablo VAR | 39/39 `to_regclass` pozitif | OK |
| PK VAR (attach koşulu) | 39/39 tam 1 PK | OK |
| identity/generated PK YOK (revert yazamazz kapısı) | 39/39 temiz | OK |
| `islem_log` VAR | policy/trigger envanteri alındı (`precheck_prod_objects.json`) | OK |
| pgcrypto | `extensions.crypt` + `extensions.gen_salt` VAR | OK |

Uygulama öncesi kayıt: `islem_log` authenticated INSERT grant **VARDI**
(L4-02c REVOKE bunu kapatacak; canlı uygulama yalnız SELECT kullandığından
kırılmaz — §1.3), `trg_degisim_log` 0/39 tabloda.

### 1.3 Canlı site uyumu (main `js/`)

| Soru (zarf §0) | Bulgu | Sonuç |
|---|---|---|
| main `js/` `islem_log`'a doğrudan INSERT? | Hayır. Tek dokunuş `js/api.js:417` **SELECT** (`from('islem_log').select(*)…`). `dbInsert` (api.js:224) genel yardımcısına `islem_log` geçen çağrı yok; `RPC_TABLES` (api.js:291+) yalnız çekme-yenileme haritası | OK |
| main `js/` L2/L4'ün kaldırdığı/değiştirdiği RPC imzasını çağırıyor mu? | Hayır. 8 dosyada fonksiyon **DROP yok** (yalnız `DROP TRIGGER/POLICY IF EXISTS`); 4 RPC imzası değişmeden CREATE OR REPLACE. main `js/`'te `degisim_*`/`geri_alma_*`/`sahip_sifresi_*` çağrısı **0** (UI merge'i K2 kapısında hâlâ main'e girmedi). main'in çağırdığı RPC'ler (`asistan_*`, `irk_listesi`, `demo_*`, `kupe_musait_mi`, `stat_suru_ozet`, `padok_degistir_toplu`, `tohumlama_*` ailesi) 8 dosyaya dokunulmuyor | OK |

**Hüküm:** migration ile main push arasındaki pencerede canlıda kırılacak
çağrı yok → uygulamaya geçildi. Not: `demo_klonla` (demo projesi) artık
public `degisim_log`'u da kopyalar — prod canlı sitesini etkilemez.

## 2. Yedek (uygulamadan ÖNCE) — `p7_backup_prod.py`

- **Yer:** `/home/melik/tmp/agents/prod-yedek-2026-09-15-adim-b/` (repo DIŞI).
  Diğer tüm `prod-yedek-*` ve `github-yedek-*` klasörleri salt okunur —
  dokunulmadı.
- **Yöntem:** P4 betiği (OUT değiştirildi, purpose P7); salt-okunur SELECT,
  tablo başına parçalı json_agg.
- **Kapsam:** 52 public tablo (17.479 satır) + şema tanımları: functions 212,
  triggers 33, policies 77, grants_routine 706, grants_table 1477, indexes
  132, columns 721, constraints 142, views 13, extensions 64,
  roles_grants_schema 1 → **63 dosya, 77.841.936 bayt, 159,3 s**.
- **Manifest:** `manifest.json` (repo dışında) — dosya başına satır/bayt/
  sha256 + kapı sonuçları. Manifest'in kendi sha256'si `be9b79f6f61433d5…`.
- **Kapı A:** her tablo `backup_rows == yedek-başı count(*)` — 52/52 OK.
- **Kapı B:** yedek-sonu ikinci count turu == `backup_rows` — 52/52 OK.
- Bilgi: aynı günün P4 yedeğine göre (`prod-yedek-2026-09-15-p4`) satır
  artışları yalnız canlı kullanım tablolarında: `gorev_log` 3084→3100,
  `islem_log` 4253→4262, `stok_hareket` 1007→1018, `drug_administrations`
  646→651, `treatment_days` 428→433, `treatment_day_uygulamalar` 572→577 —
  gün içi normal üretim trafiği (P5 §Y-sayımı ile uyumlu).

## 3. Uygulama — `p7_apply.py` / `apply_log.json` / `apply_NN_*.txt`

- Betik başlamadan: yedek manifest kapıları (gate_A/gate_B OK) + sentinel
  kontrol (`degisim_log`/`surum_gizli` hâlâ yok) — geçti.
- Sıra: `20260913000001` → `…02` → `…03` → `…04` (luna) →
  `20260914000001` → `…02` → `…03` → `…04`. Her dosya **tek istek**, dosya
  metni olduğu gibi. 7 dosyada atomiklik dosyanın kendi `BEGIN;…COMMIT;`'inden
  (çift sarmalama YOK); `20260913000004` tek `CREATE OR REPLACE FUNCTION`
  statement (kendiliğinden atomik).
- Sonuçlar (`apply_log.json`):

| # | Dosya | Süre | Yanıt |
|---|---|---|---|
| 1 | 20260913000001_f1_degisim_log | 0,8 s | `[]` OK |
| 2 | 20260913000002_f2_geri_alma | 1,5 s | `[]` OK |
| 3 | 20260913000003_f2_sahip_sifresi | 0,6 s | `[]` OK |
| 4 | 20260913000004_luna_bilet_maske | 0,7 s | `[]` OK |
| 5 | 20260914000001_l4_islem_log_kopru | 0,8 s | `[]` OK |
| 6 | 20260914000002_l4_geri_alma_zincir | 0,7 s | `[]` OK |
| 7 | 20260914000003_l4_onarim | 1,2 s | `[]` OK |
| 8 | 20260914000004_l4_stok_uyari_txid | 0,9 s | `[]` OK |

**8/8 OK — toplam 7,3 s. Hata yok; "ilk hatada DUR" tetiklenmedi.**
`sahip_sifresi_ayarla` çağrısı YAPILMADI (zarf §2; root kendisi kuracak).

## 4. Doğrulama (salt okunur) — `p7_verify.py` / `verify_summary.json`

| Kapı | Ölçüm | Sonuç |
|---|---|---|
| 8 dosya CANLI | Her fonksiyonun canlı gövde md5'i (md5_normall, P1/P3/P4 yöntemi) zincirin **son tanımlayan dosyasıyla** birebir; 21/21 fonksiyon. Zincir: `_degisim_log_yaz` 01→04(luna), `_islem_log_degisim_txid` 05→07, `_degisim_plan`/`_l4_zincir` 06→07→08, `degisim_onizle`/`degisim_geri_al` 02→06→07 | OK |
| 4 public RPC ACL | `geri_alma_bileti_al(text)`, `degisim_listele(jsonb)`, `degisim_onizle(jsonb,text)`, `degisim_geri_al(jsonb,text,uuid,text)` → `{postgres=X,authenticated=X,service_role=X}/postgres` — authenticated VAR; anon/PUBLIC **yok** (dosya `REVOKE … FROM PUBLIC, anon`; service_role default-privilege EXECUTE'te kalır — dosya ona dokunmaz) | OK |
| `sahip_sifresi_ayarla` ACL | `{postgres=X,service_role=X}/postgres` — anon/authenticated/PUBLIC **yok**, yalnız service_role EXECUTE (zarf: şifre kurulmadı, `surum_gizli.sahip_sifresi` 0 satır) | OK |
| Demo paritesi (L4 raporu beklentisi) | 5 public fonksiyonun `proacl`'ı demo (`vtzqjmazsvurxdeondmi`, L4 tesliminde doğrulanmış referans) ile **birebir**; 21 fonksiyonun gövde md5'i 19 birebir + 2 açıklamalı (§7.2) | OK |
| `surum_gizli.l4_rehber_adimlari` | VAR (0 satır); surum_gizli tablolarında anon/authenticated/PUBLIC erişim yok | OK |
| `islem_log` ACL | authenticated INSERT **YOK** (L4-02c); authenticated SELECT **korunuyor** (api.js:417 çalışır); policy `service_insert` artık `FOR INSERT TO service_role`; `islem_log_select` korunuyor | OK |
| Trigger'lar | `trg_degisim_log` **tam 39 tabloda** (küme eşitliği — dosya listesiyle); `trg_islem_log_degisim_txid` koşulsuz (WHEN kaldırıldı, L4-02a); `trg_islem_log_geri_alindi_kapisi` VAR; `trg_islem_log_immutable` duruyor | OK |
| Kolon | `islem_log.degisim_txid bigint` VAR + index | OK |
| Satır sayıları | 52/52 tablo canlı count == yedek `backup_rows` (migration veri taşımıyor — statik §6); yeni 5 tablo (`degisim_log`, `surum_gizli.sahip_sifresi/geri_alma_bileti/geri_alma_kullanim/l4_rehber_adimlari`) 0 satır | OK |
| Test çağrısı | YAPILMADI — yalnız katalog + count okuması | OK |

## 5. Veri eşleşme kontrolü — `veri-eslesme-kontrol.py` (main'den, repoya eklenmeden)

- Betik `git show main:scripts/veri-eslesme-kontrol.py` ile
  `~/tmp/p7-vevk/` altına alındı (bu dalda yok; repoya EKLENMEDİ);
  `supabase/` sembolik bağla bu dalın 8 dosyası tarandı. READ ONLY guard
  self-test OK (iki DB'de de yazma reddedildi).
- **`statik --dosya` ×8: HÜKÜM: TEMİZ** — 8 dosyada migration-zamanı
  INSERT/UPDATE/DELETE yok (türetilmiş=0, sabit=0; 17 ifadenin tamamı RPC
  gövdeleri içinde — çağrı anında koşar). `statik_ozet.json` committed.
- **`hepsi` (sizinti+isaret+koken+statik): HÜKÜM: BULGU: 59.** Bileşenler:
  - `sizinti`: SIZINTI(süpheli)=**0** (kesisim 3328 — tamamı `demo_klonla`
    kopya-imzalı; pk farkı 0) → prod'a demo-doğumlu şüpheli satır sızmadı.
  - `koken`: YETIM=0, ad_eslesme=1, std_dose_dolu=26 (bilgi).
  - `isaret`: 59 kombinasyon / 2550 satır — işaret-listesindeki kelimeler
    (`test`, `deneme`, `demo`, …) prod text kolonlarında geçiyor. Dağılım
    ağırlıkla araç tabloları (`agent_messages`, `code_embeddings`,
    `goose_embeddings`, `entity_graph`, `agent_threads`) + iş notu/başlık
    alanları — ERP iş verisinde kalıcı, bilinen bir kelime-eşleşmesi durumu.
  - `statik` (hepsi içinde P6 varsayılan 10 dosya — Adım A seti):
    türetilmiş=0, sabit=47 (dozaj seed'in sabit UPDATE'leri — bilinen).
- **İlişki analizi (hüküm bu iş bağlamında):** 18:22'deki uygulama-ÖNCESİ
  koşu (`~/tmp/agents/veri-eslesme-20260915/ozet.json`) **aynı hüküm, aynı
  sayılar** (BULGU: 59 / 59 kombinasyon / 2550 satır). 8 dosya 0 satır
  yazdığı için (statik ×8 + yeni tablolar 0 + satır sayıları yedekle aynı)
  bulguların hiçbiri bu uygulamayla oluşmadı — önceden var olan durumu
  aynen yansıtıyor. Ayrıntı çıktıları repo dışında `~/tmp/agents/p7-vevk-*/`.

## 6. Prod'un L4 ötesi durumu (root için notlar)

- Sıradaki sahip adımları (L4 raporu §8 sırasından): `sahip_sifresi_ayarla`
  (service_role bağlantıyla, root kendisi), GT regen, sonra merge/deploy (K2:
  L4 dalı main'e merge edilebilir hale geldi — L2/L4 prod'da CANLI).
- Canlı site (GitHub Pages = main) yeni RPC'leri hiç çağırmıyor; merge'e
  kadar davranış değişikliği görünmez. Yalnız görünen fark: business
  tablolardaki her yazım artık `degisim_log`'a da satır yazıyor (tasarım
  gereği; uygulama bunu okumuyor).

## 7. Sapmalar / olaylar

### 7.1 Yedek 1. deneme KAPI A'ya takıldı (beklenen kapı davranışı)

İlk yedek denemesinde `islem_log backup_rows=4256 != count=4253` — yedek
penceresinde canlı trafik 3 satır yazdı; OFFSET sayfalaması kaydığı için betik
KAPI A ile kendiliğinden DUR etti (zarf: "eşleşmezse DUR"). Yedek
salt-okunur olduğu için **aynı betik** sessiz bir pencerede bir kez daha
koşuldu; 2. deneme KAPI A+B 52/52 yeşil. Eksik 1. deneme klasörün üzerine
yazıldı (zarf OUT'u tek klasör). Prod'a yazma işlemi yalnız doğrulanmış
yedeğin ardından başladı.

### 7.2 prod↔demo gövde paritesinde 2 fonksiyonda zincir ilerisi (açıklamalı)

`surum_gizli._degisim_plan` ve `_l4_zincir`: prod = `20260914000004`
(W6 stok-uyarı txid düzeltmesi) md5'leri (`1c270f5f20`/`9b4143a797`), demo =
`20260914000003` md5'leri (`55d971481f`/`2a0bb1a631`). Neden: L4 raporu §4'e
göre demo'ya yalnız 01–03 uygulandı; `20260914000004` demo'ya hiç
uygulanmadı. Kanıt: demo md5'leri dosya 07'in md5'leriyle birebir; 07→08
gövde farkı yalnız dosya 04 header'ının belgelediği stok-uyarı satırları
(metinden txid/UUID çıkarılıyor; `txid`/`hareket_id` ayrı alanlara taşınıyor;
`tests/unit/l4-stok-uyari-txid.test.js` pinleri). Yani prod, demo'nun bir
adım önünde — istenen uç durum; ACL paritesi 5/5 birebir.

### 7.3 Doğrulama betiğinin ilk koşusunda iki yanlış-alarm (araç hatası, prod değil)

1. Zincir-semantiği eksikti: ara dosya md5'i arayan kapı, son dosyanın
   sürümünü "sapma" saydı → zincir-nihai kuralı eklendi (§4, 1. kapı).
2. RPC ACL beklentisi fazla kâtıydı: `service_role`'un default-privilege
   EXECUTE'unu hata saydı → dosya metnine göre düzeltildi (authenticated VAR,
   anon/PUBLIC YOK; service_role bilgi) + demo paritesi kanıtı eklendi.

Prod'da düzeltilmesi gereken bir şey çıkmadı; her iki düzeltme de ölçümün
doğru yorumuna aitti.

## 8. Teslimat

- Rapor: `reports/2026-09-15-prod-adim-b.md` (`git add -f`).
- Ham çıktılar: `reports/2026-09-15-prod-adim-b/` — betikler (4),
  `apply_log.json`, `apply_01..08_*.txt` (tamamı `[]`), precheck/verify
  özet + envanter JSON'ları, `statik_ozet.json`, `hepsi_ozet.json`.
  **Tablo satırı/değeri içeren JSON commit EDİLMEDİ** — yedek verisi repo
  dışında; fonksiyon tanımları zaten repo'daki migration dosyalarının kendisi
  (`git diff --cached --stat` ile kontrol edildi).
- Yedek (repo dışı): `/home/melik/tmp/agents/prod-yedek-2026-09-15-adim-b/`
  (63 dosya + manifest, sha256'lı).
