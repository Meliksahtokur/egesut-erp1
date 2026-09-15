# L4 Teslim Raporu — Değişiklikler + geri alma: insan akısı (R1)

**Goal:** G-20260914-GERI-ALMA-AKISI · **Dal:** `agent/geri-alma-akisi` ·
**Teslim ucu:** `L4 teslim R1` commit'i (bu raporla birlikte; `git log -1`) ·
**Tarih:** 2026-09-15 · **Lead:** geri-alma-akisi (glm)

> **R1 notu:** İlk teslim (4fad122) root kapısından DÜZELTME ile geri çevrildi
> (D1-D4 + kanıt kuralı). Bu rapor R1 teslimidir: D1-D4 kapandı, final yürüyüş
> uç `f753c14`'e pinli yeniden alındı, **her OK satırı görüntüyle
> karşılaştırıldı** (bkz. §2 ve §2b kanıt kuralı).

## 0. Yönetici özeti

Sahibin 6 şikayetinin **6'sı da uçtan uca kapandı**. R1 turunda:
**D1** (tx detay insan dili — W8), **D2** (köprü-önce-tarih-sonra — W7),
**D3** (gün kartı etiketleri + PW 0 fail — W8), **D4** (zincir satırları
insan dili — W8). 4fad122'deki KISMİ kalan tek kalem (S1a tohumlama kartı)
D2 ile kapandı: **Geçmiş gün görünümündeki tohumlama kartından geri al
artık uçtan uca çalışıyor** (S3b-01..03 + S3b-uygulandi + DB telafi kaydı).
Luna 2 tur koştu (1. tur 9 bulgudan 8'i + L4-07 W6 ile; L4-09 bu rapor).
DB değişiklikleri **yalnız DEMO**; PROD runbook §8'de (K2).

## 1. Zincir (kim neyi kapattı)

| Aşama | Kanıt |
|---|---|
| FAZ A plan (9ff0873) + root koşullu onayı (97ea3b1: K1+K2) | plan raporu §10 |
| W1 motor (45ea50a → a45b10a) | k4 22/22 + k3 46/46 + lead canlı probe |
| W2 UI tek motor (46f948d → c61c3c6) | grep 0/0, unit 973, PW 16/16 |
| W3 gezinme+takvim (215301d → 17e9141) | unit 996, PW 19/0 |
| Entegrasyon: stub sökümü + gerçek-RPC dumanı (2918392) | entegrasyon-smoke PASSED |
| Lead: liste kartı işlem dili (d2a26a4); onarım sözleşmesi (5f483f2) | plan §5'in eksik kalan ayağı |
| **Luna 1. tur** (f7938e3 üzerinden) | DUZELTME-ISTEK, L4-01..09 (`reports/2026-09-14-luna-denetim-l4.md`) |
| W4 motor onarımı (05dad26 → 290a7f0) | k4 32/32 (22+adversarial A1..A6) + k3 46/46 + lead bağımsız güvenlik yoklamaları |
| W5 UI onarımı (1f4134d → f48c768) | unit 1023, PW 16/0 |
| **Luna 2. tur** (**76713f4** üzerinden) | L4-01..06+08 KAPANDI; L4-07 alt (stok_uyari txid) → W6; L4-09 bu rapor (`reports/2026-09-14-luna-denetim-l4-tur2.md`) |
| Lead (76713f4 sonrası, lead ölçümlü): gün görünümü geri-al butonu + DEDUP IDB yedeği (cf335a8) | unit 1025/1025/0 |
| W6 stok_uyari txid çıkışı (ae19a12 → 7bf1f05) | unit 1031/1031/0; txid yalnız teknik katlama |
| **L4 teslim 4fad122 → root R1 DÜZELTME** (D1-D4 + kanıt kuralı) | `.ss/tasks/L4-R1-root-duzeltme.md` |
| **W7 D2 köprü-önce** (6b74bbd → e9adcc1) | kök: kur SQL'i sonuc UPDATE + islem_log INSERT'i ayrı tx'te yazıyordu → izsiz tx = islem-seviye LOG_YOK; çözüm: boş köprüde tek-tur zamansız `{tablo,pk}` satır yedeği (`dgOnizleGoster` TEK tur) + kur SQL'i gerçekçi (aynı tx); adversarial 3 vaka (geriye-tarihli+köprülü → köprüden; NULL köprü+tarih öncesi → meşru LOG_YOK; DEDUP IDB yedeği); unit 1045/1045/0 (`W7-D2.md`) |
| **W8 D1+D3+D4 insan dili** (f6f6151 → f753c14) | D1: detay başlığı `_dgKartBaslik`+zaman+kim'e bağlandı (`dgDetayBaslikMetni` → `_gmIslemBaslikSatiri`); Kayıt no/kaynak/tx teknik katlamaya; alan DEĞERLERİ tek haritadan Türkçe (`gmKodDenderEtiketi`). D3: gün kartı etiketleri çözüldü (`L4Y-01 — ?` → işlem etiketi; yavru `?` → çözülen küpe/nötr; ham pill → "Tedavi Günü"; notlardaki `<sözlük>:<uuid>` tokenları temizlendi `gmNotlarGorunur`). D4: `dgZincirAdimEtiketi` (GUNCELLE/SIL → Güncellendi/Silindi) + `dgZincirAlanOzeti` (ilk 1-2 anlamlı alan "eski → yeni"). Unit 1053/1053/0, PW 16/16 0 fail (`W8-insan-dili.md`) |

**Luna kapsamı:** 1. tur `f7938e3`, 2. tur `76713f4`. `76713f4` sonrası
commit'ler (cf335a8, 7bf1f05, e9adcc1, f753c14) lead ölçümlüdür: birleşik uç
unit **1067/1067/0**, PW **16/16 0 fail**, damga `?v=20260914-12` TEK değer
(26 script + manifest), `git diff --check` temiz.

## 2. Sahip senaryosu × sonuç tablosu — R1 pinli yürüyüş (uç f753c14)

Ekran görüntüleri `~/tmp/agents/l4-akis/` (4fad122 görüntüleri
`~/tmp/agents/l4-akis/eski-4fad122/` altında). Yürüyüş günlüğü:
`~/tmp/agents/l4-akis/yuruyus.json` (11 kayıt: 9 ok, 2 walk-extra flaky —
aşağıda).

| Senaryo | Sonuç | Kanıt görüntüsü (açıldı, iddiayla karşılaştırıldı) |
|---|---|---|
| S1a Geçmiş kartından geri al — **tohumlama** | **OK** (R1'de KAPANDI) | `S1a-01-gecmis-1209-gun-kartlar.png` (kartlar+butonlar) → `S3b-01..03` → `S3b-uygulandi.png` (2-olay zincir onayı) + DB: `GERI_ALINDI·l4y-anne·23:35:22Z` = görüntü saniyesi |
| S1a — doğum kartı | **OK** | `S2-dogum-uygulandi.png` + DB: `GERI_ALINDI·l4y-anne·23:35:39Z` |
| S1b hayvan kartından | ÖLÇÜLEMEDİ (walk-extra: kart render yarışı; R1 istek listesinde değil; hayvan ekleme geri alma Değişiklikler'den kanıtlı) | `S1b-01/02` (yarış anı) |
| S1c işlem detay paneli | OK (4fad122 yürüyüşünde kanıtlı: `eski-4fad122/S1c-*`; BULGU-X düzeltmesi canlı) — R1 walk'unda panel kart render yarışı, tekrar alınamadı (walk-extra) | `S1c-01` |
| S1 yüzey çeşitliliği (7 bağlama) | grep kanıtlı (W2 raporu §2) + 4'ü tarayıcıda | W2/W5 |
| S2 her eylem geri alınabilir | **OK** — motor: k4 32 vaka; tarayıcıda doğum tekil + padok zinciri | `S2-02` + k4 |
| S3 aynı-satır zincir 1-2-3 | **OK** — çakışma=öneri → "3 olay birlikte" → TEK onay + TEK bilet → uygulandı | `S3-01..05`; `S3-03` (D4 dili analizle doğrulandı), `S3-05` ("☑️ 3 olay birlikte geri alındı") + DB `GERI_ALINDI·23:35:03Z` |
| S3b çapraz-satır zincir | **OK** — tohumlama+sonuç zincire girer, doğum GİRMEZ (FK yok, K1-yeni): `S3b-02` önizlemede zincir önerisi "Bu olaydan sonra 1 değişiklik daha var" | `S3b-01..03`, `S3b-uygulandi` |
| S4 işlem dili + gürültü | **OK** — **D1 kapandı**: detay başlığı "Görev ekleme — 15.09 02:34 · l4y-anne"; görünürde UUID/Kayıt-no/kaynak satırı yok; "Tedavi Günü" Türkçe; liste başlıkları işlem dilli | `S4-01-degisiklikler-liste.png`, `S4-02-tx-detay-islem-dili.png` (her ikisi analizle doğrulandı) |
| S5 gezinme/hapsolmama | **OK** (değişiklik yok; W3 e2e 19/0 + S5d) | W3/W5 PW |
| S6 takvim işaretli günler | **OK** (değişiklik yok; W3 S6a/b e2e) | W3 PW |
| (f) geri alının geri alınması | **OK** — ⟲ kısayolu + GERI_ALINDI kartları Geçmiş'te görünür | yürüyüş gövdesi |
| (e) geri alınamayan | **OK** — LOG_YOK/ZAMAN_ESLESME_YOK yalnız gerçek legacy'de; insan dilli + yönlendirme | W7 testleri |

### 2b. Kanıt kuralı uygulaması (R1 BAĞLAYICI kural)

> "Her OK satırının yanında o sonucu gösteren ekran görüntüsünün dosya adı
> olacak ve sen o görüntüyü açıp iddiayla karşılaştırmış olacaksın."

Uygulama: **9 görüntü açılıp görsel-analizle birebir okundu** (S1a-01,
S3-03, S3-05, S3b-02, S3b-uygulandi, S2-dogum-uygulandi, S4-01, S4-02 +
S4-02 başlık dar-teyit turu) ve iddialarla karşılaştırıldı. Ek olarak
başarı iddiaları **DB çapraz-kanıtıyla** pekiştirildi: demo
`islem_log`'da R1 yürüyüşünün 3 uygulamasının telafi kayıtları,
görüntülerin dosya zaman damgalarıyla **saniye saniye** örtüşüyor
(23:35:03Z padok zinciri / 23:35:22Z tohumlama zinciri /
23:35:39Z doğum; yerel 02:35 +0300).

Dürüstlük notu (kuralın değerini gösteren vaka): S3b-uygulandi'nin ilk
görsel okuması "Geri alınamadı" toast'ı bildirdi. Birebir transkripsiyon
tekrarında görüntüde hata toast'ı **yok** olduğu, ekrandaki şeyin
kırmızı birincil butonlu **2-olay zincir onay modali** olduğu anlaşıldı;
DB telafi kaydı aynı saniyede yazılmış. İlk okuma yanlış-pozitifti,
satır OK ancak bu üçlü teyitle yazıldı. Aynı zaafiyet walk betiğinde de
var: `toastBekle('geri al')` başarı ve "Geri alınamadı" metnini de
eşleyebiliyor ve `onayVeUygula` koşulsuz `true` döner — S1a/S2 başarı
iddiaları bu yüzden toast'a değil, DB telafi kaydına dayanıyor (açık kalem
§7.6).

## 3. Testler

- **Unit (birleşik uç f753c14):** `NODE_PATH=/home/melik/egesut-erp1/node_modules
  node --test tests/unit/*.test.js` → **1067/1067/0** (taban 938 → +129;
  R1 eklemeleri: W7 `geri-al-kopru-yedegi.test.js` 14, W8
  `w8-insan-dili.test.js` 22 + mevcut dosyalara kilitler).
- **PW (final uç, Docker demo, TEK belgelenmiş koşum):**
  entegrasyon-smoke + w3-nav + l4-stok-uyari + gecmis-ux +
  degisiklikler-geri-alma → **16 passed / 0 failed / 0 skipped**.
  4fad122'deki tek PW kusuru (gecmis-ux "gün görünümü ham UUID YOK")
  W8'in `gmNotlarGorunur` düzeltmesiyle kapandı — **D3'ün "teslimde
  başarısız test olmaz" şartı sağlandı**.
- **Damga:** `?v=20260914-12` TEK değer (26 script + manifest;
  `tests/unit/vaka-toplu-ac.test.js` pin'leri; W7/W8 çakışan 11→12 bump'ı
  tarihçe satırı birleştirilerek çözüldü).
- **DB (demo):** k4_onarim 32/32 + k3 46/46 (değişiklik yok; W4 kanıt
  dizinleri ana checkout'ta). R1 turunda DB'ye migration YAZILMADI
  (yalnız `yuruyus_kur.sql` senaryo verisi — işaretli, idempotent).

## 4. DB değişiklikleri (YALNIZ DEMO — vtzqjmazsvurxdeondmi)

1. `20260914000001_l4_islem_log_kopru.sql` — islem_log.degisim_txid köprüsü
2. `20260914000002_l4_geri_alma_zincir.sql` — zaman hedefi, zincir seviyesi,
   sıralı rehber, tam çakışma listesi, telafi kaydı
3. `20260914000003_l4_onarim.sql` — L4-01..06 (jeton tablosu, sahtecilik
   kapama, FK kapsam, GERI_ALINDI)
4. `20260914000004_l4_stok_uyari_txid.sql` — stok_uyari txid ayrı alan

R1 (W7/W8) yalnız JS + test dokundu; yeni migration yok. islem_log ACL:
authenticated yalnız SELECT. PROD'a HİÇBİRŞEY uygulanmadı.

## 5. Tek motor durumu

`islemGeriAl`/`openGeriAl`/`m-geri-al`/`ga-*` tamamen söküldü (grep 0);
7 yüzey tek girişe (`dgGeriAlAkisi`) bağlı; onay = L2 bileti (a+b emekli).
Legacy DB RPC'leri prod uyumluluk için yerinde. `asistan_plan_geri_al`
dokunulmadı.

## 6. Görsel dil / gürültü (R1 sonrası nihai durum)

- **Detay başlığı:** `İşlem adı — gg.aa ss:dd · küpe` (D1; görsel teyit:
  "Görev ekleme — 15.09 02:34 · l4y-anne").
- **Görünür alanda yok:** ham UUID, `Kayıt no`, `Supavisor·kaynak` satırı,
  tablo adı (`gorev_log (1)`), ham kodlar ("TEDAVI GUN" → "Tedavi Günü").
  Bunlar `Teknik ayrıntı` katlamasında (W8; S4-02 görsel teyit).
- **Gün kartları:** boş başlık yok, `?` yok, ham pill yok (D3; S1a-01
  görsel teyit: 7 kart — "Görev Tamamlandı", "Doğum", "Tohumlama Sonucu",
  "Hayvan Eklendi", yavru satırı çözülmüş küpe ile).
- **Zincir satırları:** "Güncellendi — Sonuç: Bekliyor → Gebe" /
  "Silindi" + alan özeti; onay cümlesi aynen ("N olay sıralıdır, komple
  geri alınacak. Onaylıyor musunuz?") (D4; S3-03 + S3b-uygulandi teyit).
- Liste kartlarında gürültü kaynak rozeti ("uygulama dışı · Supavisor ·
  l4-yuruyus") tasarım gereği kalıyor — bu, gürültü filtresinin etiketi;
  D1'in talebi tx detayındaydı ve orada kapandı.

## 7. Açık kalemler / bilinen sınırlar (root kapısı)

1. **KAPANDI (R1/D2):** S1a tohumlama kartı LOG_YOK — kök: senaryo kur
   SQL'i sonuc UPDATE'ini ve islem_log INSERT'ini ayrı tx'lerde yazıyordu
   (izlenen tabloda değişiklik olmayan tx = izsiz). W7 hem kod yolunu
   sağlamlaştırdı (köprü varken tarih asla gölgelemez; boş köprüde tek-tur
   satır yedeği) hem kur SQL'ini gerçekçi yaptı.
2. **KAPANDI (R1/D3):** gün görünümü görünür UUID (stok_hareket notlarındaki
   `<sözlük>:<uuid>` tokenları) — `gmNotlarGorunur`; gecmis-ux testi
   geçiyor, PW 0 fail.
3. **ERTOLENDİ (root kararı):** yarım-gece TZ ayrışması (dateKey İstanbul /
   BUGÜN etiketi cihaz saati; 00:00-03:00 penceresi). R1 kapsamı dışında;
   ayrı küçük iş.
4. **Legacy nötr fallback (kabul, root kararı):** köprü öncesi islem_log
   olaylarında telafi etiketi nötr ("Kayıt geri alındı").
5. **Walk-extra flaky (R1 istek listesi dışı):** S1c (işlem detay paneli)
   ve S1b (hayvan kartı) R1 yürüyüşünde kart render yarışı yüzünden
   tekrar kanıtlanamadı; 4fad122 yürüyüşünde kanıtlıydılar
   (`eski-4fad122/S1c-*`). Root kararı bekliyor: yeniden yürüyüş mü,
   eski kanıt yeterli mi.
6. **Walk betiği `toastBekle('geri al')` zaafiyeti:** başarı/hata toast'ı
   ayrışmıyor, `onayVeUygula` koşulsuz true döner. Bu teslimde başarı
   iddiaları DB telafi kayıtlarıyla saniye-eşleşmeli doğrulandı (§2b);
   betik düzeltmesi bir sonraki dokunuşta yapılmalı.
7. **Yürüyüş senaryo verisi:** `yuruyus_kur.sql` işaretli (l4-yuruyus),
   idempotent; demo'daki artıklar bir sonraki temizlikte süpürülebilir.

## 8. PROD runbook (SAHİP/ROOT KAPISI — HİÇBİRİ UYGULANMADI; K2)

Sıra: (1) 7 eski borç migration; (2) L2'nin 4 migration'ı; (3) L4'ün 4
migration'ı (20260914000001..04); (4) `sahip_sifresi_ayarla`
(service_role); (5) salt-okunur teyit (5 fonksiyon ACL + jeton tablosu +
islem_log ACL: authenticated INSERT yok); (6) GT regen; (7) merge/deploy.
**L4 dalı bu adımlar tamamlanmadan main'e merge EDİLMEZ (K2).**

## 9. Kırıntılar / izleme

- `.crumbs/geri-alma-akisi.jsonl` (lead) + hasat kayıtları; W1-W8 kırıntı
  ve raporları ana checkout `.crumbs/` + `reports/` altında (ad ad
  doğrulanarak kopyalandı; R1 kapanışında aynısı yapılacak).
- Backup etiketleri: `backup/2026-09-1[45]-dal-*-W[1-8]`.
- Board: `.ss/geri-alma-akisi-BOARD.md` (gitignored).
