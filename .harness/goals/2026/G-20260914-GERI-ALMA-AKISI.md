---
id: G-20260914-GERI-ALMA-AKISI
status: draft
owner: root
flow: ss_org
created: 2026-09-14
base_sha: d4bd07fa05ef3231da1048b2e1496ffccb8eb5fc
launch_sha: d4bd07fa05ef3231da1048b2e1496ffccb8eb5fc
branch: agent/geri-alma-akisi
worktree: /home/melik/.superset/worktrees/1dddb562-abe3-495c-970e-872567945510/agent/geri-alma-akisi
plan_report: .harness/reports/2026-09-14-geri-alma-akisi-plan.md
report: .harness/reports/2026-09-14-geri-alma-akisi-plan.md
task_envelope: /home/melik/egesut-erp1/.ss/tasks/L4-degisiklikler-geri-alma-insan-akisi.md
write_manifest:
  - .harness/goals/2026/G-20260914-GERI-ALMA-AKISI.md
  - .harness/reports/2026-09-14-geri-alma-akisi-plan.md
  - .harness/reports/2026-09-14-geri-alma-akisi.md
  - js/degisiklikler/degisiklikler.js
  - js/degisiklikler/diff.js
  - js/degisiklikler/etiketler.js
  - js/gecmis.js
  - js/ui.js
  - js/forms.js
  - js/api.js
  - js/tarih/tarih.js
  - js/utils/handlers.js
  - index.html
docs_authority:
  tracked_paths:
    write:
      - .harness/goals/2026/G-20260914-GERI-ALMA-AKISI.md
      - .harness/reports/2026-09-14-geri-alma-akisi-plan.md
      - .harness/reports/2026-09-14-geri-alma-akisi.md
    append: []
  local_paths:
    write: []
    append:
      - .crumbs/geri-alma-akisi.jsonl
      - .ss/geri-alma-akisi-BOARD.md
  db: write
  propose_only:
    - .harness/references/ui-map.md
    - .harness/references/rpc-reference.md
acceptance:
  - "Sahip senaryolari S1-S6 (plan raporu §8) tarayicida yurunur; ekran goruntuleri ~/tmp/agents/l4-akis/ altinda"
  - "Motor genisletmesi frozen contract'a uyum — W1 demo RPC test ciktilari"
  - "Tek motor: islemGeriAl/m-geri-al cagrisi 0 (grep + unit)"
  - "Unit 0 fail; PW tek belgelenmis kosum"
  - "DB degisikligi YALNIZ demo; prod'a hicbir sey uygulanmadi"
  - "Teslim raporu .harness/reports/2026-09-14-geri-alma-akisi.md"
stop_conditions:
  - "Root plan onayi gelmeden kod YAZILMAZ (FAZ A kapisi)"
  - "PROD'a hicbir migration uygulanmaz (ayrı sahip kapisi)"
  - "Acik kalemler O-1..O-4 root karari bekler"
checkpoint:
  sequence: 0
  kind: null
  head: null
  docs_verdict: null
pattern_refs:
  - MODAL-ROUTER-01
  - OFFLINE-SYNC-01
  - RPC-WRITE-01
  - TESTING-01
pattern_exceptions: []
review_lane: codex_luna_max_bounded
implement_lane: glmf_workers
---

# G-20260914-GERI-ALMA-AKISI — Değişiklikler + geri alma: insan akışı

## Status
draft (zarf dili: pending) — FAZ A (tasarım + plan) bu goal ile teslim edildi;
kod YOK. Root plan kapısı: `.harness/reports/2026-09-14-geri-alma-akisi-plan.md`
okunup onaylanmadan FAZ B başlamaz. Onay status'u `active` yapar.
Not: FAZ B'de materialleşecek migration/test dosyaları kesin adları belirlenince
write_manifest'e eklenir (goal kendini manifest'te içerir).

## Date
2026-09-14

## Owner directive (BINDING, özet + sahibin sözleri zarftan)

Zarf: `/home/melik/egesut-erp1/.ss/tasks/L4-degisiklikler-geri-alma-insan-akisi.md`
(tam metin orada; sahibin sözleri aynen korunur).

Sahibin sözleri (2026-09-14, deneme sunucusunda test):
1. "Geri al butonu her yerde yok. Elimizde git revert var ama bağlantıları tam değil."
2. "Her eylem geri alınamıyor."
3. "Geri alma çakışma blokajı veriyor ama hangi günlerden nasıl geri alma yapması
   gerektiği yönlendirilmiyor. 1-2-3-4-5 sıralı olaylardan 3'ü geri almaya
   çalışıyorsam zincir olarak teklif göndermeli: '3-4-5 sıralı olaydır, komple
   geri alınacak, onaylıyor musunuz?'"
4. "Bu bir UI kontrol paneli, SQL tablosu değil. Çiftlikte kimse bu işlem nosu
   kime ait diye düşünemez."
5. "Geri/ileri tuşları yok — detay ekranında hapsoldum, baştan girmem gerekti."
6. "Bir hayvanda olay olan günler takvimde renkli gösterilmeli, boş günler beyaz."

Root'un kabul edilmiş önerileri: işlem dili başlıklar (tx/UUID katlanır),
yalnız anlamlı alanlar, geri almanın olayın yaşadığı yere taşınması (Geçmiş
kartı, hayvan kartı, işlem detayı — tek motor = L2 RPC'leri), teknik gürültü
varsayılan gizli.

L2'nin "eski Geçmiş sekmesi ve 7 legacy RPC'ye dokunulmaz" kısıtı bu goal'le
sahiben KALDIRILDI (yeni sahibe direktifi; UI çağrı noktaları L2'ye bağlanır,
legacy RPC'lerin DB tarafı prod uyumluluğu için yerinde kalır).

## Ölçülmüş taban (2026-09-14, lead; kanıtlar plan raporunda)

- L2 teslimi: `degisim_log` (39 tablo), 4 RPC, biletli geri al, Değişiklikler
  sayfası — yalnız DEMO'da (prod migration YOK). Taban: d4bd07f.
- `degisim_onizle` çakışmada SADECE ilk sonraki değişikliği listeler;
  engel metni ham UUID + koddur (`SONRAKI_DEGISIKLIK`) — zincir önerisi ve
  yönlendirme için motor genişletmesi gerekir (probe:
  `reports/2026-09-14-geri-alma-akisi-plan/olcum_zincir.{sql,out}` — gitignored).
- Eski geri-al UI: Geçmiş kartı `↩ Geri Al` yalnız 6 islem tipi + tohumlamada
  çıkar (`_GM_UNDO_ISLEM_TIPLERI`, js/gecmis.js:19); işlem detay panelindeki
  buton TEK-ARG `islemGeriAl` çağırır = KIRIK (iki tanım, yük sırası gölgelemesi;
  js/ui.js:3000 vs js/forms.js:3471). Onay: a+b matematik modalı. Motor: legacy
  `geri_al`/`tohumlama_geri_al` RPC'leri (islem_log tabanlı, L2'siz).
- `islem_log`'da `ref_id`+`ref_tablo` çoğu tipte dolu (demo ölçümü; istisnalar:
  DOGUM_KAYDI, KIZGINLIK, kısmi TOHUMLAMA/ABORT/HAYVAN_EKLENDI) — Geçmiş
  yüzeyinden hedef satır çıkarımı için hazır anahtar, tip-bazlı fallback gerekir.

## Frozen contract — FAZ B motor genişletmesi (BINDING for W1; W2 stub'la kodlar)

Hepsi ADDITIVE; mevcut 4 RPC imzası ve davranışı korunur. Yalnız DEMO migration:
`supabase/migrations/2026091400000N_*.sql`. PROD'a uygulama YOK.

```sql
-- 1) islem_log ↔ degisim_log KÖPRÜSÜ (kesin eşleşme)
ALTER TABLE public.islem_log ADD COLUMN IF NOT EXISTS degisim_txid bigint;
-- küçük AFTER INSERT trigger: degisim_txid := txid_current().
-- İş mantığı: iş satırını yazan RPC ile islem_log INSERT'i AYNI transaction'da
-- koşar → degisim_log.txid ile birebir eşleşir. Geçmiş kartından geri al,
-- hedefi {txid: degisim_txid} ile kesin kurar. Geçmiş (L4 öncesi) satırlarda
-- NULL → zaman-penceresi yedeği (aşağıda).

-- 2) p_hedef'e opsiyonel 'zaman' (ISO8601 text; tablo+pk ile birlikte)
--    (tablo,pk) için kayit_zamani'na en yakın log satırı hedeflenir;
--    en yakın satır 120 sn'den uzaksa HEDEF_BULUNAMADI,
--    detay.neden='ZAMAN_ESLESME_YOK'. txid verilirse txid kazanır.
--    (islem_log.tarih İŞ tarihi olabileceğinden geç girilen olaylarda
--    eşleşmeyebilir → UI "Değişiklikler'den seç" yönlendirmesi verir.)

-- 3) p_seviye 'zincir' (ADDITIVE; 'alan'|'satir'|'islem' aynen)
--    p_hedef: {tablo,pk,txid} | {txid}
--    plan: hedef adımı + aynı (tablo,pk) [islem hedefse tx'in tüm satırları]
--    için hedef txid'den SONRAKİ TÜM değişiklikler; sira = uygulanacak sıra
--    (en yeni önce). Her adım mevcut plan satırı alanları + txid + zaman.
--    geri_alinabilir: bağımlılık ENGEL'i zinciri bloklar (bypass yine YOK);
--    zincire dahil satırların sonraki değişiklikleri ÇAKIŞMA SAYILMAZ.
--    cakismalar: yalnız zincire DAHİL OLMAYAN satırlardaki sonraki değişiklikler.
--    degisim_geri_al 'zincir': TEK transaction, adımlar sira sırasıyla,
--    tek geri_alma_txid; yanıt +{"zincir_adim":M}.
--    Sınır: zincir >100 adım → GECERSIZ_HEDEF, detay.neden='ZINCIR_COK_UZUN'.

-- 4) cakismalar kaydı zenginleştirme (ADDITIVE alanlar; TAM liste)
--    Her kayda + zaman, degisen_alanlar, islem, log_id; liste İLK değil
--    TÜM sonraki değişiklikleri verir (UI "hangi günlerden" yönlendirmesi ve
--    zincir önerisi bu veriden kurulur).

-- 5) HEDEF_BULUNAMADI detayına neden: 'SATIR_YOK'|'LOG_YOK'|'ZAMAN_ESLESME_YOK'
--    (hata kodu değişmez; UI Türkçe metni neden'e göre seçer.)

-- 6) islem_log TELAFİ KAYDI (Geçmiş akışı doğru kalsın diye)
--    degisim_geri_al (her seviye, zincir dahil) aynı tx'te islem_log'a
--    INSERT: tip='GERI_ALINDI', ref_id/ref_tablo=hedef satır pk,
--    ana_hayvan_id (çözülebiliyorsa), payload={orijinal_tip, seviye, adim}.
--    Orijinal islem_log satırları DEĞİŞTİRİLMEZ (mevcut immutable trigger
--    BEFORE UPDATE/DELETE — INSERT serbest; kanıt: pg_trigger probe'u,
--    plan raporu §3). Geçmiş akışı geri almayı "X geri alındı — 14.09
--    17:25 · küpe" kartıyla anlatır; sahibin örnek başlığı birebir bu.
```

Geri alınabilirlik kuralları değişmez: çakışmada bypass YOK (zincir dışı
çakışma), bağımlılık ENGEL bloklar, `degisim_log`/bilet tabloları kapsam dışı,
sistem öncesi değişiklik geri alınamaz.

## Frozen contract — FAZ B UI yüzeyleri (BINDING for W2/W3)

- **Tek geri-al girişi:** `degisiklikler.js`'teki akış (önizleme → bilet →
  uygula) genel giriş olarak açılır; Geçmiş kartı, hayvan kartı Geçmişi,
  işlem detay paneli, vaka paneli, Değişiklikler detayı AYNI girişi çağırır.
  a+b matematik modalı (`m-geri-al`, `openGeriAl`, `islemGeriAl`,
  handlers `geri-al`/`close-geri-al`) SÖKÜLÜR; onay = L2 bilet akışı.
- **Hedef çözücü (saf, testli):** `_gmGeriAlHedef(entry)` →
  {tablo,pk,txid?} | {tablo,pk,zaman?} | null. Öncelik: islem_log
  `degisim_txid` → `ref_tablo`+`ref_id`+tarih → tip-bazlı fallback
  (DOGUM_KAYDI/KIZGINLIK payload kuralları) → null (buton yok,
  Değişiklikler'e yönlendirme).
- **Buton kapsamı:** `_GM_UNDO_ISLEM_TIPLERI` 6-tip kısıtı kalkar; çözücü
  hedef üreten her olay kartında geri-al olur. Çevrimdışıda buton yok (mevcut
  kural). L2 motoru olmayan ortamda (prod) buton bilgi notuna düşer.
- **İşlem dili:** başlık şablonu `${olayEtiketi} — ${gg.aa.ss:dd} · ${kim}`;
  kim = küpe ya da kayıt adı (ham UUID ASLA; U1 kökü). Tek etiket kaynağı
  `js/gecmis.js` haritası; Değişiklikler aynı haritayı kullanır. tx/UUID/
  PostgREST ayrıntısı katlanır (teknik detay bloğu). Haritaya `GERI_ALINDI`
  tipi eklenir ("…geri alındı"); geri alınmış olayın kartında tekrar geri-al
  hedefi = geri alma tx'i (geri almanın geri alınması, akış (f)).
- **Anlamlı alanlar:** tablo-başına önemli-alan sırası `etiketler.js`'e;
  güncellemede yalnız değişen alan (var), boş '—' satır gizli, teknik
  satırlar + uygulama-dışı kaynak (`app_name` ≠ 'egesut-web') varsayılan
  GİZLİ, her biri için katlama çipi ("Teknik (N)", "Uygulama dışı (N)").
- **Zincir UX:** önizlemede çakışma görünce "Zincir olarak geri al — N olay
  birlikte" önerisi; zincir önizlemesi kart listesi (işlem diliyle); TEK
  onay + TEK bilet; sonuçta zincir özeti + geri-alınanı-geri-al bağlantısı.
- **Geri alınamayan:** neden + yapılabilir (açık Türkçe): sistem öncesi →
  kaydı düzenle yönlendirmesi; zincir dışı çakışma → zincir önerisi ya da
  "sonrakini önce geri al" sıra bilgisi; bağımlılık engeli → hangi alt
  kayıtlar önce; bilet süresi → yeniden şifre.
- **Gezinme (W3):** takvim + gün görünümü + Değişiklikler tx detayı history'
  girer (Android/tarayıcı geri KAPATIR, sayfa değiştirmez); pg-degisiklikler
  ve pg-asistan başlığında "← Geri"; modallarda ESC; det-back deseni korunur.
- **Takvim işaretli günler (W3):** `tekTarihTakvimAc` opts'a
  `isaretliGunler: Set<'YYYY-MM-DD'>` — olaylı gün renkli nokta, boş gün
  beyaz; veri IDB'den (ek pull YOK): ana Geçmiş = görünür aralık gün kümesi,
  hayvan kartı = scope'lu küme; Değişiklikler filtresi FAZ B'de karar
  (varsayılan: ek pull gerektiriyorsa YOK).
- Kurallar: `type="date"` YOK; inline `onclick` YOK (`data-action`+escAttr);
  `?v=` damga tek değer; unit 0 fail; PW tek belgelenmiş koşum.

## Work plan
1. [lead] Bu goal + plan raporu (FAZ A) → commit `L4 plan` → ROOT KAPISI.
2. [root] Plan onayı (onay/düzeltme). Onaysız kod YOK.
3. [W1 glmf] Motor genişletmesi (frozen contract §1-5) + demo testleri
   (zaman-hedefi, zincir, tam çakışma listesi, köprü kolonu) + unit baseline.
4. [W2 glmf] UI: tek geri-al girişi + çözücü + söküm + işlem dili + gürültü
   filtreleri + zincir UX + geri-alınamayan metinleri (W1 sözleşmesine karşı
   stub ile başlar, entegrasyonda gerçek RPC).
5. [W3 glmf] Navigasyon + takvim işaretli günler (W2'den sonra; ui.js kesişimi).
6. [lead] Kabul → merge (--no-ff) → dal/workspace kapat (kırıntı hasadı +
   backup etiketi) → entegrasyon (stub sökümü) → luna review → teslim raporu
   + insan akışı yürüyüşü (`~/tmp/agents/l4-akis/`) → root.

## Acceptance mapping
| Kabul | Sahip | Kanıt |
|---|---|---|
| Sahip senaryo 1-6 (plan raporu §8) tarayıcıda yürünür | lead | ekran görüntüleri `~/tmp/agents/l4-akis/` + PW tek koşum |
| Motor genişletmesi sözleşmeye uyum | W1 | demo RPC test çıktıları |
| Tek motor (islemGeriAl yolu ölü) | W2 | grep kanıtı + unit |
| Unit 0 fail | W1/W2/W3 | node --test çıktısı, baseline sayısı raporda |
| DB yalnız demo | W1 | migration listesi + prod yokluk beyanı |
| Teslim raporu | lead | .harness/reports/2026-09-14-geri-alma-akisi.md |

## Constraints
- Demo ref: vtzqjmazsvurxdeondmi (ölçümler bu projede). PROD (zqnexqbdfvbhlxzelzju) DOKUNULMAZ.
- Unit: `NODE_PATH=/home/melik/egesut-erp1/node_modules node --test tests/unit/*.test.js`; taban 938/938/0 (d4bd07f).
- PW şablonu: `.harness/reports/2026-09-14-tarihe-git-f1.md` "FINAL KANIT"; denetçiler tekrar koşmaz.
- Dil: sahip ile Türkçe; owner-directive bölümü Türkçe kalır.
- `.crumbs/geri-alma-akisi.jsonl` bu worktree'de; hasat lead'in işi.
