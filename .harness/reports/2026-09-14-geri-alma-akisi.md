# L4 Teslim Raporu — Değişiklikler + geri alma: insan akışı

**Goal:** G-20260914-GERI-ALMA-AKISI · **Dal:** `agent/geri-alma-akisi` ·
**Teslim ucu:** `L4 teslim` commit'i (bu raporla birlikte; `git log -1`) ·
**Tarih:** 2026-09-15 · **Lead:** geri-alma-akisi (glm)

## 0. Yönetici özeti

Sahibin 6 şikayetinin 5'i uçtan uca kapandı (S3 zincir, S4 işlem dili, S5
gezinme, S6 takvim + çok-yüzeyli geri al); 1'i KISMİ (S1a: Geçmiş gün
görünümündeki **tohumlama** kartından önizleme, motorda doğru olduğu hâlde
tarayıcı hattında LOG_YOK diyaloğu veriyor — açık kalem §7). Luna 2 tur
koştu; 1. turun 9 bulgusundan 8'i kapatıldı, L4-09 bu raporla kapanıyor.
DB değişiklikleri **yalnız DEMO**; PROD runbook'u §8'de (K2: main'e çıkış
buna bağlı).

## 1. Zincir (kim neyi kapattı)

| Aşama | Kanıt |
|---|---|
| FAZ A plan (9ff0873) + root koşullu onayı (97ea3b1: K1+K2) | plan raporu §10 |
| W1 motor (45ea50a → a45b10a) | k4 22/22 + k3 46/46 + lead canlı probe (tam çakışma listesi) |
| W2 UI tek motor (46f948d → c61c3c6) | grep 0/0, unit 973, PW 16/16 |
| W3 gezinme+takvim (215301d → 17e9141) | unit 996, PW 19/0 |
| Entegrasyon: stub sökümü + gerçek-RPC dumanı (2918392) | entegrasyon-smoke PASSED |
| Lead: liste kartı işlem dili (d2a26a4); onarım sözleşmesi (5f483f2) | plan §5'in eksik kalan ayağı |
| **Luna 1. tur** (f7938e3 üzerinden) | DUZELTME-ISTEK, L4-01..09 (`reports/2026-09-14-luna-denetim-l4.md`) |
| W4 motor onarımı (05dad26 → 290a7f0) | k4 32/32 (22+adversarial A1..A6) + k3 46/46 + **lead bağımsız güvenlik yoklamaları**: A3 GERI_ALINDI kapısı (42501), A4 köprü ezmesi (istemci 999999 → gerçek txid), A6 authenticated INSERT reddi |
| W5 UI onarımı (1f4134d → f48c768) | unit 1023, PW 16/0; BULGU-X (ölü det-panel butonu) |
| **Luna 2. tur** (**76713f4** üzerinden) | L4-01..06+08 KAPANDI; L4-07 alt (stok_uyari txid) → W6; L4-09 bu rapor (`reports/2026-09-14-luna-denetim-l4-tur2.md`) |
| Lead (76713f4 sonrası, **lead ölçümlü**): gün görünümü geri-al butonu (cf335a8: "defter ayrıcalığı" kalktı — plan §1a), gmUndoClick DEDUP-birleşik kart IDB yedeği (cf335a8) | unit 1025/1025/0 |
| W6 stok_uyari txid çıkışı (ae19a12 → 7bf1f05) | unit 1031/1031/0; txid yalnız teknik katlama, unit kilitli (root teslimde yeniden ölçecek) |

**Luna kapsamı:** 1. tur `f7938e3`, 2. tur `76713f4`. `76713f4` sonrası
commit'ler (cf335a8, 7bf1f05) lead ölçümlüdür: birleşik uçta unit
**1031/1031/0**, damga `?v=20260914-11` TEK değer (26 script + manifest),
`git diff --check` temiz.

## 2. Sahip senaryosu × sonuç tablosu (plan §8; ekran görüntüleri `~/tmp/agents/l4-akis/`)

| Senaryo | Sonuç | Kanıt |
|---|---|---|
| S1a Geçmiş kartından geri al | **KISMİ** | Gün görünümü kartlarında buton ÜRETİLİYOR (S1a-01; 61 buton ölçüldü), **doğum** kartı uçtan uca çalıştı (S2-02/uygulandi). **Tohumlama** kartında önizleme LOG_YOK diyaloğu veriyor (S3b-ENGEL-kilitli; açık kalem §7) |
| S1b hayvan kartından | ÖLÇÜLEMEDİ (S1a'nın açık kalemi yüzünden akış tamamlanmadı; hayvan ekleme geri alma Değişiklikler'den kanıtlı) | — |
| S1c işlem detay paneli | **OK** (panel açıldı, önizleme görüntülendi: S1c-01/02; BULGU-X düzeltmesi canlı) | ekran görüntüleri |
| S1 yüzey çeşitliliği (7 bağlama) | grep kanıtlı (W2 raporu §2 tablo) + 4'ü tarayıcıda | W2/W5 |
| S2 her eylem geri alınabilir | **OK motor düzeyinde** (envanter §2; k4 32 vaka) + tarayıcıda: doğum tekil (OK), padok zinciri (OK) | k4 + yürüyüş |
| S3 aynı-satır zincir 1-2-3 | **OK** — çakışma=öneri → "3 olay birlikte" kart listesi → TEK onay + TEK bilet → uygulandı | S3-01..05 |
| S3b çapraz-satır zincir | **KISMİ** — K1-yeni kapsam doğrulandı (doğum zincire GİRMEZ, kendi düğmesiyle döner: S2-dogum OK); tohumlama kartındaki önizleme açık kalem | S3b-01..02, S2-02 |
| S4 işlem dili + gürültü | **OK** — ham UUID/tx yok görünürde, çipler varsayılan filtrede; liste kartı başlıkları işlem dilli ("Padok ekleme") | S4-01/02; PW UUID-taraması (bkz. §7 açık kalem 2) |
| S5 gezinme/hapsolmama | **OK** — takvim/gün/tx-detay history, ESC, ← Geri, det-back (W3 e2e 19/0 + S5d gerçek RPC) | W3/W5 PW |
| S6 takvim işaretli günler | **OK** — olaylı gün noktası, boş gün beyaz, ek istek yok (W3 S6a/b e2e) | W3 PW |
| (f) geri alının geri alınması | **OK** — ⟲ kısayolu + GERI_ALINDI kartları Geçmiş'te görünür (L4-06; yürüyüş gövdesinde kanıtlı) | yürüyüş dökümü |
| (e) geri alınamayan | **OK** — LOG_YOK/ZAMAN_ESLESME_YOK insan dilli + yönlendirme butonları (S3b-ENGEL ekranı buna örnek) | S3b-ENGEL-kilitli |

**Yürüyüş günlüğü:** `~/tmp/agents/l4-akis/yuruyus.json` + 17 ekran görüntüsü.
Koşum ucu: 7bf1f05 ağacı (damga 20260914-11 servis edildi — serve log).

## 3. Testler

- **Unit (birleşik uç):** `NODE_PATH=/home/melik/egesut-erp1/node_modules node
  --test tests/unit/*.test.js` → **1031/1031/0** (taban 938 → +93: çözücü,
  başlık, rehber, gürültü, nav-karar, gün-kümesi, modal, GERI_ALINDI,
  islem-detay-güvenli, gün-pipeline undoRef, stok-uyarı txid).
- **PW (final uç, Docker demo):** entegrasyon-smoke + w3-nav +
  l4-stok-uyari + gecmis-ux + degisiklikler-geri-alma → **15 passed /
  5 skipped (stub spec kendini atlıyor) / 1 failed** — kusur: gecmis-ux
  "gün görünümü ham UUID YOK" (§7 açık kalem 2). Dürüst tarihçe: regresyon
  koşumu iki kez alındı (ilkinde aynı 1 kusur; ölçüm tekrarı, worker finali
  değil — "PW bir kez yeter" kuralı worker teslimleri için uygulandı).
- **DB (demo):** k4_onarim **32/32** (22 yeniden üretilmiş + A1..A6
  adversarial: ilgisiz aynı-hayvan INSERT girmez, sahte l4_rehber reddi,
  sahte GERI_ALINDI reddi, köprü ezmesi, authenticated INSERT reddi) +
  k3 regresyon **46/46** + lead bağımsız güvenlik yoklamaları (§1 W4 satırı).
  Kanıt dizinleri: `reports/2026-09-14-geri-alma-akisi-W4/` (ana checkout
  kopyalı), W1 kanıtları kapanışta kayboldu (root bilgisi; 22 vaka W4'te
  yeniden üretildi).

## 4. DB değişiklikleri (YALNIZ DEMO — vtzqjmazsvurxdeondmi)

1. `20260914000001_l4_islem_log_kopru.sql` — islem_log.degisim_txid köprüsü
2. `20260914000002_l4_geri_alma_zincir.sql` — zaman hedefi, zincir seviyesi,
   sıralı rehber, tam çakışma listesi, telafi kaydı
3. `20260914000003_l4_onarim.sql` — L4-01 jeton tablosu (sunucu-üretimi
   l4_rehber), L4-02 sahtecilik kapama (köprü ezmesi + GERI_ALINDI GUC
   kapısı + authenticated INSERT revoke), L4-03 pg_constraint FK kapsamı,
   L4-06 gerçek orijinal_tip
4. `20260914000004_l4_stok_uyari_txid.sql` — stok_uyari txid ayrı alan
   (görünür metin temiz)

Ayrıca islem_log ACL: authenticated yalnız SELECT (REVOKE INSERT; policy
`service_insert` → service_role INSERT). PROD'a HİÇBİRŞEY uygulanmadı.

## 5. Tek motor durumu

`islemGeriAl`/`openGeriAl`/`m-geri-al`/`ga-*` tamamen söküldü (grep 0);
7 yüzey tek girişe (`dgGeriAlAkisi`) bağlı; onay = L2 bileti (a+b emekli —
sahibe bildirim: root O-3 kararı). Legacy DB RPC'leri prod uyumluluğu için
yerinde (kullanılmıyor). `asistan_plan_geri_al` dokunulmadı.

## 6. Görsel dil / gürültü

Başlıklar işlem dilli (`${olayEtiketi} — gg.aa ss:dd · kim`; liste kartı
"Padok ekleme / — geri alındı"); ham UUID/tx yalnız `Teknik ayrıntı`
katlamasında; teknikal_mi + uygulama-dışı varsayılan gizli (çipler);
yalnız değişen alanlar; boş alan gizli; stok uyarısında txid yok (W6).

## 7. Açık kalemler / bilinen sınırlar (root kapısı)

1. **S1a tohumlama kartı LOG_YOK (KISMİ):** Geçmiş gün görünümünde tohumlama
   kartının önizlemesi "değişiklik takibi kurulmadan önce" diyaloğu veriyor.
   Motor aynı hedefle her rol/şekilde DOĞRU (psql kanıtlı: ok:true, plan
   SIL + çakışma listesi); tarayıcı hattında hedef bir biçimde bozularak
   gidiyor — tam kök bu teslimde kapanamadı. Doğum kartı AYNI yüzeyden
   çalışıyor. Yönlendirme metni çıkımaz bırakmıyor (Değişiklikler'den
   çalışıyor). Düzeltme sonrası tek tur yürüyüş yeter.
2. **Gün görünümünde görünür UUID (SQL-tohumlu veriyle):** U1'in
   "ham UUID YOK" testi, benim psql-tohumlu senaryo verimle 6 UUID
   görünürü yakaladı (gerçek uygulama akışının yazdığı payload'larda
   görünmüyor; W5'in 16/0 koşumu temiz veriyle geçti). Trigger-üretili
   satırların etiket çözümü ayrı bir düzeltme adayı.
3. **Yarım-gece TZ ayrışması:** dateKey (İstanbul) ile BUGÜN etiketi
   (cihaz saati) 00:00-03:00 İstanbul penceresinde ayrışabiliyor (ölçüldü:
   konteyner UTC'de '15 Eylül' grubu + 'BUGÜN' ayrı göründü). Kenar durum;
   ayrı küçük iş.
4. **Legacy nötr fallback (root kararı 2):** köprü öncesi islem_log
   olaylarında telafi etiketi nötrdür ("Kayıt geri alındı") — immutable
   satırlar yeniden yazılmaz; bilinen sınır olarak kabul.
5. **Yürüyüş senaryo verisi:** `reports/2026-09-14-geri-alma-akisi-plan/
   yuruyus_kur.sql` işaretli (l4-yuruyus); demo'da kalan artıklar bir sonraki
   temizlikte süpürülebilir (temizlik betiği aynı dizinde tasarlandı, kur
   idempotent).

## 8. PROD runbook (SAHİP/ROOT KAPISI — HİÇBİRİ UYGULANMADI; K2)

Sıra: (1) 7 eski borç migration; (2) L2'nin 4 migration'ı; (3) L4'ün 4
migration'ı (20260914000001..04); (4) `sahip_sifresi_ayarla`
(service_role); (5) salt-okunur teyit (5 fonksiyon ACL + jeton tablosu +
islem_log ACL: authenticated INSERT yok); (6) GT regen; (7) merge/deploy.
**L4 dalı bu adımlar tamamlanmadan main'e merge EDİLMEZ (K2).**

## 9. Kırıntılar / izleme

- `.crumbs/geri-alma-akisi.jsonl` (lead) + hasat: `hasat-geri-alma-akisi-W1.jsonl`,
  W2-W6 kırıntıları ana checkout `.crumbs/` + `reports/` altında.
- Backup etiketleri: `backup/2026-09-1[45]-dal-*-W[1-6]` (W2/W4/W5/W6 root
  adıyla; W1/W3 lead).
- Board: `.ss/geri-alma-akisi-BOARD.md` (gitignored).
