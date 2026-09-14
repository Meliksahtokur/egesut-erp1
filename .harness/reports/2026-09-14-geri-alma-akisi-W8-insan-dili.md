# L4-W8 — D1+D3+D4 İnsan Dili Paketi (root R1 düzeltmesi) — Teslim Raporu

- **Worker:** glmf, dal `agent/geri-alma-akisi-W8` (taban: lead ucu `4fad122`)
- **Zarf:** `.ss/tasks/L4-W8-D1-D3-D4-insan-dili.md` · kaynak: `.ss/tasks/L4-R1-root-duzeltme.md`
- **Kapsam:** D1 (tx detay insan dili) + D3 (gün görünümü kart etiketleri) + D4 (zincir
  satır dili). D2 (degisim_txid köprüsü/tarih) bu zarfta YOK — W7'nin işi.
- **DB:** hiç dokunulmadı (yalnız JS + test). Merge/push yok. Commit: `W8 teslim`.

## Bulgu × Düzeltme

| # | Bulgu (kanıt) | Düzeltme |
|---|---|---|
| 1 | Tx detay başlığı ham tablo adı `gorev_log (1)` + alt satırda `Supavisor · l4-yuruyus` + zaman (S4-02) | `_dgDetayCiz` başlığı `dgDetayBaslikMetni`'e bağlandı: liste kartıyla AYNI üretici `_dgKartBaslik` + zaman + kim — örn. **"Görev ekleme — 12.09 12:05 · L4Y-01"**. Kaynak dizesi başlıktan kalktı (teknik katlamada `Kaynak:` JSON'u duruyor) |
| 2 | Detay görünür alanında `Kayıt no 193a0625-…` ham UUID (S4-02) | `dgAlanSatiriGorunurMu`: `id` satırı ve ham-UUID değerli hücreler görünür listeden çıkıyor; pk teknik katlamaya taşındı (`Kayıt: <tablo> · <pkKisa>` satırları) + satır-kartı `Teknik ▸` mevcut |
| 3 | `Görev tipi TEDAVI GUN` ham kod değeri (S4-02) | `gmKodDegerEtiketi` (gecmis.js TEK harita, SAF): `TEDAVI GUN`/`TEDAVI_GUN` → "Tedavi Günü" + gorev_tipi/durum/status sözlüğü; haritada olmayan değer aynen kalır (uydurma yok). `_dgDegerMetni` bu haritadan okur |
| 4 | `L4Y-01 — ` boş başlık + `TEDAVI GUN` ham pili (S1a-01, gorev kaynağı kart) | Boş etiket → tip etiketi: tamamlanan **"Görev Tamamlandı"**, bekleyende gorev_tipi TR; pill `gmKodDegerEtiketi`'nden ("Tedavi Günü"); pill class davranışı korundu |
| 5 | `L4Y-01 — ?` (DEDUP-birleşik tohumlama kartı; sperma boş) (S1a-01) | Tohumlama başlık fallback'ı `?` → **"Tohumlama"** (islem etiketi); sonuç kalemindaki `?` → `—` |
| 6 | `L4Y-01 → L4Y-01-B1 (?)` (dogum kartı, yavru_cins boş) (S1a-01) | Cins boşsa parantez hiç basılmıyor; anne çözülemeyirse "Anne", yavru "Yavru" (nötr kısa etiket; ham UUID asla) |
| 7 | **YENİ BULGU (final koşumda ölçüldü):** 06.09 gün görünümünde ~130 ham UUID — trigger-üretili stok_hareket notlarına gömülü `Tedavi · drug_admin:<uuid>` (gecmis-ux "ham UUID YOK" testi fail) | `gmNotlarGorunur` (SAF): notlardaki `<sözlük>:<uuid>` tokenları atılır, okunur metin kalır ("Tedavi"). Stok + uygulama kart alt satırlarında ve CSV aynasında uygula |
| 8 | Zincir önizlemede `GUNCELLE / SIL` ham fiilleri (S3-03) | `dgZincirAdimEtiketi`: **"Güncellendi / Silindi"** (+EKLE→Eklendi; bilinmeyen `islemEtiketi` yedeği); `dgZincirAlanOzeti`: U adımlarında ilk anlamlı 1-2 alan "Padok adı: A → B" (`alanEtiketi` + `degerMetni`; `id` hariç). Onay cümlesi aynen korundu |
| 9 | Çözülemeyen hayvan referansları ham id/'?' düşebiliyordu (tohumlama/hastalık/uygulama/çıkış/sütten/protokol başlıkları, `_gmKatSatirEtiket`) | `gmHayvanEtiketVeya` (SAF, gecmis.js) + `_gmHayvanEtiketVeya` sarmalayıcı: state → IDB indeksi (`_gmHayvanKupeById`) → nötr etiket ("Hayvan"/rol adı); islem kartı alt satırındaki UUID-benzeri `irk/grup` da temizlendi |

## Güvenlik / sözleşme
- esc/escAttr korundu; yeni şablonlarda DB'den gelen her metin yine esc/escAttr'lı
  (dogum başlığı yeniden kurulumunda dahil). Inline onclick yok; `type="date"` yok.
- Ham UUID/kod yalnız teknik katlamada (`Teknik ayrıntı ▸`, `Teknik ▸`) kalıyor.
- Damga `?v=` TEK değer **20260914-12** (26 script/manifest satırı; W7 ile aynı
  hedef değer — merge'te tek değer, aynı satır değişimi). Pin testi güncel;
  tarihçe satırı eklendi, eski -11 notları tarihsel olarak korundu.

## Testler

- **Unit:** baseline 1031/1031/0 → final **1053/1053/0** (`tests/unit/w8-insan-dili.test.js`
  22 yeni SAF test: D1 görünür-alan kilidi + başlık/kim, D3 etiket çözümleri +
  notlar temizliği, D4 dönüşümler). Node 26, `NODE_PATH` ana checkout.
- **Playwright final (demo, chromium, Docker `v1.58.2-noble`):**
  `gecmis-ux.spec.js` + `geri-alma-w3-nav.spec.js` + `entegrasyon-smoke.spec.js`
  → **16 passed / 0 failed / 0 flaky** (workers=1, retries=1; log:
  `~/tmp/agents/w8-pw-FINAL3.log`, review fixlerinden SONRA son kod; önceki 16/16 koşumlar: FINAL2.log, FINAL.log).
- **PW tarihçe:**
  1. Baseline (`4fad122`, değişiklik öncesi): gecmis-ux 4/4 passed — o an demo
     verisinde 06.09 stok notları drug_admin referanslı değildi.
  2. 3-spec paralel koşum: 14 passed / 2 flaky / 0 fail — boot yarışı (retry'de geçti).
  3. Paralel koşum (retries=0): 4 passed / 14 failed — paralel worker'ların demo
     projesi/boot yükünde kitle 30 sn timeout'u (ortam; tek testte de aynı koda
     fail yoktu).
  4. Sıralı koşum: 15 passed / **1 failed — GERÇEK bulgu (yukarıda #7)**: 06.09'da
     127 stok hareketi notunda `drug_admin:<uuid>`; senaryo verisi demo'ya
     araya giren yüklemelerle büyümüş. Fix sonrası aynı test 2/2 geçti.
  5. FINAL: **16/16 passed** (madde 2-4'ün koşullarında workers=1 ile).
  Not: paralel koşumda demo-boot yarışı düzensiz flaky üretiyor — 3-spec koşumu
  `--workers=1` ile alınmalı (lead'e ortam notu).

## Kalanlar / lead'e notlar
- **D2** (degisim_txid köprüsü + geriye tarih kuralı) — W7 zarfı; bu teslimde yok.
- **Yarım-gece TZ ayrışması** (açık kalem 3) — R1 gereği ertelendi, ayrı küçük iş.
- `_dgKartBaslik` çıktısı "Görev ekleme" biçiminde (liste kartıyla birebir AYNI
  üretici — R1 şartı bu); R1'deki "Görev tamamlandı" örneği islem_log GOREV_TAMAMLA
  kartlarında zaten böyle çıkar.
- CSV aynası `lblOf` çözülemeyen id'yi ham döndürebilir (kart tarafı nötr; önceden
  var olan dar nokta, kapsam dışı raporlandı).
- Final pinli yürüyüş ekran görüntüleri (S1a/S3/S3b/S4) R1 akışına göre lead
  turunda alınacak; bu teslim yalnız kod+test kanıtı taşıyor.

## Builtin review NOTU (ZORUNLU)
- code-reviewer builtin ajanı, teslim diff'i üzerinde salt-okunur tam tur yaptı
  (2026-09-15; süre ~10 dk, 36 araç çağrısı; hard-rule tablosu + satır satır bulgu).
- **Karar: 0 Critical / 3 Important / 4 Minor.** Hard rules (esc/escAttr, görünür
  alanda ham UUID, bilinmeyen-geçir, DB-dokunma) — biri dışında PASS.
- **Important bulguların ÜÇÜ de düzeltildi ve testlerle pinlendi:**
  1. `dgZincirAlanOzeti` ham UUID değerli alanı görünür zincir kartına basıyordu →
     değerler `_dgDegerMetni`'den geçiyor, ham UUID/'?' alanlar özete girmiyor
     (unit: "review I1" testi).
  2. Hayvansız görev kartı "GENEL" yerine "Hayvan" basıyordu (çözücü fallback'ım
     GENEL'i öldürmüştü; CSV aynasıyla çeliyordu) → `_gmHayvanEtiketVeya(..., 'GENEL')`
     bağlam fallback'ı; CSV `gl` ile birleşti.
  3. CSV ayna boşlukları: uygulama `ek` notları + çıkış/sütten `kupe` kolonu ham
      id/notlar basıyordu → kartla aynı temizleyici/nötr etikete bağlandı.
- **Minor'lardan yapılanlar:** damga kara listesine `20260914-11` eklendi;
  `gmNotlarGorunur` çıplak UUID kalıntısını da temizliyor; temizlenince boşalan
  notun sarkan `·` ayracı kart şablonundan kalktı; `dgDetayBaslikMetni` boş
  `tablo_adi` nötr 'Değişiklik' düşüyor. (Yapılan: `_dgDegerMetni`'deki
  '?' yedeğine açıklama yorumu eklendi — görünür listede artık ulaşılabilir değil; dgZincirAlanOzeti'nin skip kararında nötr işaret.)
- Review sonrası: unit 1053/1053/0 + PW 3-spec 16/16 (FINAL3.log) yeniden ölçüldü.
