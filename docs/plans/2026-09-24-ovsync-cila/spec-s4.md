# SPEC S4 — Bildirim/Buton: Navigasyon fix'i, Ovsynch-56+TAI yardım balonu, yaş denetimi

> Spec sürümü: 1.0 · Tarih: 2026-09-24 · Kaynak plan: `reports/plans/ovsync-cila-plan-3.md` (skeptik revizyonlu) + sentez §3/§5A/§9
> Tur-2 uygulama adımı: **Adım 4** (sentez §3) — sıra: Adım 1 (kısır blok) ve Adım 2/3'ten SONRA, Adım 5'ten ÖNCE.
> **BANT:** Prod'a push/merge YOK. Bu spec'in kapsamında **migration YOK** (gerekçe §6). Commit'ler yalnız `ovysch-feature-cila-turu` dalına.

## 0. Sahip kararları (bağlayıcı, 2026-09-24 karar turu)

| Karar | Değer | Bu spec'e etkisi |
|---|---|---|
| "Ovsynch-56" adı | **KALSIN** (sentez §9 S6) | M1 satır metni ve yardım balonu adı korur; "Ovsynch senkronu" çevirisi yapılmaz |
| TAI yardım balonu | **İSTENİYOR** (görev tanımı + plan-3 M2) | M2 yardım katmanı bu spec'in zorunlu maddesi (opsiyonel damgası düştü) |
| TAI'nin hayvan kartında gösterimi | **AÇIK** (sentez §9 S6 — "Tur 2 başında netleşecekler" #5) | Bu spec DIŞI; kart-gösterimi işlenmez (§10 kesişim haritası) |
| Bekliyor ≥40g → gebelik muayenesi + 🔬 izole vurgu | Sahip kararı (sentez §5A) | Bu spec DIŞI — Plan 4/spec-S2 kapsamı (§10) |
| Yaş gözlemi ("12 aylık düve") | **Ölçümle netleşsin** (sentez §9 S2) | Y2 ölçüm SQL'i bu spec'te; koşumu Adım 0'da |

## 1. Amaç

Sahibin 3. maddesi (plan-3 §1): **"İlk Tohumlama" bildirimindeki satır hayvan kartına gitmiyor**; satırdaki "Ovsynch-56 · TAI" terminolojisi işletmeciye yabancı; ayrıca bildirimde yaş-uyumsuz hayvan görünebilme şüphesi var.

Bu spec şu üç sonucu üretir:
1. **Navigasyon:** Protokol panelindeki 🌱 İlk Tohumlama satırına dokunmak hayvan kartını açar; Başlat/İptal butonları satır-tıklamasını tetiklemez; `ovsyncBaslat` başarı bildirimi (Notification API + yeni app-içi yol) hayvan kartına gider.
2. **Metin + yardım:** Satır alt-metni insan diline çevrilir ("Ovsynch-56" adı korunarak); panel başlığına `?` rozetiyle tek-seferlik yardım katmanı (Ovsynch-56 nedir, TAI nedir, taban kuralları) eklenir.
3. **Yaş denetimi:** Panelde yaş-uyumsuz hayvan göründüğü iddiası Adım 0 salt-okunur ölçümle (Y2 SQL) yanıtlanır; istemciye filtre YAZILMAZ (tek otorite sunucu).

## 2. Mevcut durum — kanıtlı bulgular (bu spec yazımında yeniden doğrulandı)

| # | Bulgu | Kanıt |
|---|---|---|
| B1 | `_ovSatir` satırı tıklanabilir DEĞİL: `.arow` div'inde `onclick` yok; yalnız [▶ Başlat] ve [✕] butonları var ve buton hücresi `event.stopPropagation()` sarmalısız | CONFIRMED `js/ui.js:1834-1844` |
| B2 | Satır-tıklama→hayvan-kartı kalıbı repoda MEVCUT: sessiz sheet satırı `onclick="_sessizSheetGizle();openDet('${s.hayvan_id}')"`, protokol-detay linki `_protoDetayHayvanGit(...)` | CONFIRMED `js/ui.js:1699` ve `js/ui.js:1920, 1934-1940` |
| B3 | `ovsyncBaslat` başarıda toast + `_ovsyncBildirim(...)` üretir; bildirimin hayvan kartına giden tıklama hedefi yok | CONFIRMED `js/ui.js:1180-1182` |
| B4 | `_ovsyncBildirim` yalnız Notification API yoludur (izin yoksa hiçbir şey göstermez); app-içi bildirim yüzeyi MEVCUT DEĞİL; `tag:'ovsync-pg'`, onclick ataması yok | CONFIRMED `js/ui.js:1201-1207` |
| B5 | Satır metni: `Ovsynch-56 başlat · hedef ${fmtTarih(u.hedef_tarih)} ${(u.hedef_saat||'').slice(0,5)} · TAI ${fmtTarih(u.tai_tarihi)}` — terim açıklamasız; `hedef_saat` boşsa çift-boşluk kozmetik hatası (S3) | CONFIRMED `js/ui.js:1837` |
| B6 | RPC `ovsync_baslat_uyarilari()` dönüşünde `hayvan_id`, `kategori`, `hedef_tarih`, `hedef_saat`, `tai_tarihi` (=hedef+10), `kaynak`, `taban_turu` alanları ZATEN VAR — veri ihtiyacı tam karşılanıyor | CONFIRMED `supabase/migrations/20260924000001_ovsync_pg_r32_acik_disi.sql:1098-1110` |
| B7 | Pencere kuralı: RPC yalnız `hedef_tarih <= (Europe/Istanbul bugünü + 2)` görevleri döner | CONFIRMED aynı dosya `:1117` |
| B8 | TAI türetmesi sunucuda `g.hedef_tarih + 10` | CONFIRMED aynı dosya `:1105` |
| B9 | Yaş kuralı: `_ovsync_kural_tarihi` → inek `GREATEST(son doğum, son abort) + 51`; düve (doğum/abort kaydı yok) `dogum_tarihi + 12 ay 21 gün`; taban yoksa NULL (görev açılmaz) | CONFIRMED aynı dosya `:74-104` |
| B10 | `openDet(id, keepTab)` modül-seviyesi global async fonksiyon; ui.js içinde ~12 çağrı noktası var; imza değişikliği bu spec'te YOK | CONFIRMED `js/ui.js:3220` + grep envanteri (§8) |
| B11 | Popstate 'det' vakası, gizlenmiş `protokol-bs`'i geri getirir (`style.display='flex'`) — "sheet'ten karta git, geri tuşuyla panele dön" akışı ZATEN uygulama seviyesinde çözülmüş | CONFIRMED `js/app.js:162-173` |
| B12 | `_protoDetayHayvanGit(hayvanId)` = detay sheet + protokol sheet'i `display:none` yapar + `openDet` çağırır; iki koşullu guard sayesinde detay-sheet yokken de güvenle çağrılabilir | CONFIRMED `js/ui.js:1934-1940` |
| B13 | Buton-hücresi stopPropagation kalıbı aynı panelde `_satirHtml`'de kullanılıyor: `<div style="display:flex;gap:6px;align-items:center" onclick="event.stopPropagation()">` | CONFIRMED `js/ui.js:1820` |
| B14 | `_modalBackGuard` deseni: sheet kapanışı `globalThis._modalBackGuard = true; history.back()`; popstate tüketir (`app.js:107-113`); `pushState` etiketleri: `{sessiz_bs:1}`, `{protokol:true}`, `{proto_detay:true}` | CONFIRMED `js/ui.js:1667, 1782, 1788, 1862, 1930` + `js/app.js:103-113` |
| B15 | Yardım katmanı için en yakın öncül `_showProtokolDetay`: z-index 350 (panel 300 üstü), `existedBefore` guard'lı pushState (öksüz girdi birikmesi yok — B21), ✕ + backdrop kapanış | CONFIRMED `js/ui.js:1866-1932` |
| B16 | `ovsyncBaslat` çağrı noktaları: 2 buton — görev kartı `_ovsyncBaslatBtnHtml` (stopPropagation'lı, `js/ui.js:1164`) ve panel satırı (stopPropagation'sız, `js/ui.js:1841`). RPC `start_first_service_protocol` dönüşünde `hayvan_id` YOK (`{ok, case_id, tohumlama_gorev_id, baslangic, ...}`) — istemci hayvan_id'yi satır/görev bağlamından taşır | CONFIRMED `js/ui.js:1164, 1841` + migration `:841-843` |
| B17 | `getData('hayvanlar')` ui.js içinde yaygın kullanımda (kupe çözümü için hazır) | CONFIRMED `js/ui.js:1193` (benzer kalıp) |
| B18 | Toast yardımcısı `textContent`-tabanlı, aksiyon/HTML desteklemez, kuyruk sözleşmesi belgeli → aksiyonlu bildirim için toast GENİŞLETİLMEZ | CONFIRMED `js/utils/helpers.js:60-81` |
| B19 | sw.js no-op (fetch handler yok, cache temizler) → push kalıcılığı yok; Notification tıklaması best-effort | CONFIRMED `sw.js:1-10` |
| B20 | Sürüm damgası: index.html'de TÜM js/css tek `?v=20260924-01` değeriyle dolaşır; değişiklikte güncellenir | CONFIRMED `index.html:2325-2331` |
| B21 | Unit test altyapısı: `tests/unit/ovsync-pg-ui.test.js` `loadBrowserModule('js/ui.js', {expose:[...]})` ile modül-seviyesi fonksiyonları sandbox'tan alıp HTML çıktı test ediyor (öncül: `_ovsyncBaslatBtnHtml`) | CONFIRMED `tests/unit/ovsync-pg-ui.test.js:12-16, 40-56` |
| B22 | E2E modal-router dalışı: `tests/modal-router.spec.js` protokol sheet'lerini sentetik uyarıyla deterministik açıyor; B21 maddesi `_closeProtokolListe/Detay` tek-nokta kapanışı doğruluyor | CONFIRMED `tests/modal-router.spec.js:8-25` |
| B23 | `_ovSatir` şu an `_showProtokolEkran` closure'unda tanımlı → unit test'e DOĞRUDAN kapalı; `_ovsyncBaslatBtnHtml` öncülündeki gibi modül-seviyesine çıkarılması gerekiyor | CONFIRMED `js/ui.js:1834` (closure içi arrow) |
| B24 | Canlı demo'da OVSYNC şablonu: tek aktif şablon "Sağmal inek: Ovsynch-56 + çift PGs" (`id=a152f7fe-…`), kalemleri **4 seans** — Gün 1, 8, 9, 10 (10:00/18:00) | OBSERVED canlı demo sorgusu 2026-09-24: `tedavi_sablonu` + `tedavi_sablonu_kalem` |
| B25 | `hedef_saat` `_acik_disi_gorev_kur` tarafından '10:00' yazılır; eski/yol-dışı görevlerde NULL kalabilir (B5 kozmetiğinin koşulu) | CONFIRMED migration `:186` |

## 3. Tasarım

### 3.1 N1 — Panel satırı hayvan kartına gider

- `_ovUyariSatirHtml(u)` (bugünkü closure-içi `_ovSatir`, B23) modül-seviyesine çıkarılır; satır div'ine `style`ya ek `cursor:pointer` ve `onclick="_protoDetayHayvanGit('${escAttr(u.hayvan_id)}')"` eklenir.
- **Kalıp kaynağı:** B12 (`_protoDetayHayvanGit` — proto-detay sheet yokken de güvenli: `if (detayBs)` guard'lı) + B11 (popstate 'det' vakası paneli geri getirir; geri-tuş akışı ÜCRETSİZ gelir). Sessiz-sheet kalıbı (`_sessizSheetGizle`) KULLANILMAZ — o kalıbın popstate dönüşü sessiz sheet'e özel, `protokol-bs` için B11'deki mevcut akış zaten doğru.
- **Buton hücresi** `<div style="display:flex;gap:6px;align-items:center">` sarmalına `onclick="event.stopPropagation()"` eklenir (B13 kalıbı, `_satirHtml` ile birebir). Başlat/İptal davranışı değişmez.
- `openDet` imzası ve diğer çağrı noktaları DOKUNULMAZ (B10).
- Fonksiyon adı: `_protoDetayHayvanGit` ismi artık iki bağlamda kullanılacağından **opsiyonel** olarak `_protokolHayvanGit`'e yeniden adlandırılabilir (2 çağrı noktası: `js/ui.js:1920` linki + yeni satır); yeniden adlandırma yapılmazsa mevcut adıyla kullanılır. İkisi de kabul testi 1'i değiştirmez.

### 3.2 N2 — `ovsyncBaslat` başarı bildirimi karta gider

- **İmza uzatmaları (ui.js içi, geriye-dönük uyumlu):**
  - `ovsyncBaslat(gorevId, hayvanId)` — ikinci parametre opsiyonel. İki çağrı noktası aynı zarfta güncellenir: panel butonu `data-h="${escAttr(u.hayvan_id)}"` ile taşır (B16); görev kartı `this.dataset.h` ← `_ovsyncBaslatBtnHtml`'e `data-h="${escAttr(t.hayvan_id)}"` eklenir. `hayvanId` boş gelirse N2 davranışı bugünkü haline düşer (yalnız toast+Notification) — akış KIRILMAZ.
  - `_ovsyncBildirim(baslik, govde, hayvanId, kupeNo)` — üçü/dördüncü parametre opsiyonel.
- **Notification API yolu (mevcut + best-effort, B19):** izin `granted` ise `new Notification(...)` üzerine `notif.onclick = () => { try { window.focus(); openDet(hayvanId); } catch(e){} }` atanır. PWA'da tıklama teslimi tarayıcıya bağlıdır; belgelenir (kabul 7).
- **App-içi yol (YENİ, birincil):** izin yok/default iken (`!('Notification' in window) || Notification.permission !== 'granted'`) ve `hayvanId` biliniyorsa küçük alt-sheet banner:
  - id: `ovsync-bildirim-bs`; z-index **310** (panel 300'ün üstü, proto-detay 350'nin altı); alt-sheet görsel dili B15 öncülüyle (`border-radius:18px 18px 0 0`, safe-area padding).
  - İçerik: "✅ İlk tohumlama protokolü başlatıldı" başlığı + tıklanabilir satır: `🌱 {kupe_no} · TAI {tarih} — Hayvan kartına git →`. Kupe çözümü: `getData('hayvanlar')` içinden `id===hayvanId` (B17); bulunamazsa kupe yerine `—` (satır yine tıklanır).
  - Satır onclick: banner `remove()` + `openDet(hayvanId)`. Backdrop tap: `remove()`.
  - **pushState YOK** (transient banner — toast sınıfı yüzey; history-churn ve modal-router coupling istenmez, B14/C18 gerekçesiyle). Otomatik kapanış: `setTimeout` ~10 sn (timer banner node'u üzerinde tutulur; `remove()` timer'ı da etkisiz kılar).
- **Toast genişletilmez** (B18) — aksiyonlu yüzey yalnız yukarıdaki iki yol.
- RPC dönüşüne alan EKLENMEZ (istemci bağlamı yeterli, B16) → DB değişikliği YOK.

### 3.3 M1 — Satır metni insan dilinde (ad korunur)

Bugünkü B5 metninin yerine:

```
Başlat: Ovsynch-56 senkronu (56 günlük program) · Hedef: {dd.mm}[ {ss:dd}] · Zamanlanmış tohumlama (TAI): {dd.mm}
```

- "Ovsynch-56" adı KORUNUR (sahip kararı §0).
- `hedef_saat` bölümü koşullu basılır: `(u.hedef_saat ? ' ' + String(u.hedef_saat).slice(0,5) : '')` — B5'teki S3 kozmetik hatası (boş saat → çift ayraç) bu kuralla çözülür.
- Satır üçüncü satırındaki taban etiketi (Düve — 12a21g / Doğum sonrası / Abort sonrası / Açık dişi) KORUNUR (mevcut `js/ui.js:1838` mantığı, çıktı `_ovUyariSatirHtml`'de aynı kalır).

### 3.4 M2/M3 — `?` yardım katmanı (yardım balonu)

- **Giriş noktası:** `🌱 İlk Tohumlama (N)` bölüm başlığının (mevcut `js/ui.js:1845`) yanına `?` rozeti: `<button ... onclick="_showOvsyncYardim()" style="…border:1px solid var(--ink3);border-radius:50%;…">?</button>`.
- **Katman:** `_showOvsyncYardim()` — B15 öncülüyle tam kopya kalıp: alt-sheet, id `ovsync-yardim-bs`, z-index **350**, `existedBefore` guard'lı `history.pushState({ovsync_yardim:true}, '', '')` (öksüz girdi yok), backdrop tap + ✕ butonu `_closeOvsyncYardim()`'a bağlar.
- **Kapanış:** `_closeOvsyncYardim()` → `box.remove()` + `if (history.state?.ovsync_yardim) { globalThis._modalBackGuard = true; history.back(); }` (B14 deseni, `_closeProtokolDetay` ile aynı — `js/ui.js:1784-1789`).
- **Geri tuşu:** popstate'e yeni VAKA EKLENMEZ — `{ovsync_yardim:true}` girdisi geri gelişinde navGeriKarar mevcut 'yut'/modal zincirine düşer... **Düzeltme ( Tasarım kararı):** `_modalBackGuard` kod-kaynaklı back'i tükettiği için (B14) geri-tuşu akışı yalnız KULLANICI back'iyle tetiklenir; kullanıcı back'ine cevap olarak katmanın kapanması için navGeriKarar saf makinesine tek vaka eklenir: `ovsyncYardimAcik` girdisi (id kontrolü: `#ovsync-yardim-bs` açık) → `tur:'ovsync-yardim'` → `document.getElementById('ovsync-yardim-bs').remove()`. `js/utils/handlers.js navGeriKarar` + `js/app.js` switch'ine tek case. (Öncül: 'proto-detay' vakası `app.js:151-158`.)
- **İçerik (statik metin — RPC yok):**
  1. **"Ovsynch-56"**: "İneklerde doğum sonrası ilk tohumlama zamanlaması için kullanılan senkron programı. Başlat'a dokununca 4 seanslı hormon zinciri (1./8./9./10. gün) ve tohumlama görevi açılır." — seans sayısı B24 ile OBSERVED; uygulayıcı apply öncesi canlı şablondan bir kez daha teyit eder (§11 V-1).
  2. **"TAI (Zamanlanmış Tohumlama)"**: "Zincirin sonunda planlanan tohumlama. Ekrandaki tarih, başlatma hedefinin 10 gün sonrasıdır." — B8.
  3. **"Neden bu hayvan?"** (taban kuralları): "Düve: doğumdan 12 ay 21 gün sonra. İnek: son doğum/aborttan 51 gün sonra. Görev, hedeften 2 gün önce listede belirir." — B9 + B7.
- M3'ün "uzun bastırma tooltip'i yok" notu geçerli: vanilla JS kısıtı → dokunmalı açılır katman (yukarıdaki çözüm).

### 3.5 Y1/Y2 — Yaş denetimi (bildirimde yanlış hayvan olmasın)

- **Y1 — İstemci filtresi YAZILMAZ** (tek otorite sunucu; plan-3 §3.3). RPC dönüş alanları B6'da zaten tam: `kategori` + `taban_turu` + `hedef_tarih` görüntülenir (bugünkü davranış), ek doğrulama alanı/dönüşümü gerekmez.
- **Y2 — Adım 0 salt-okunur ölçüm** (bu spec'in SQL'i §6.2): Açık tüm `OVSYNC_BASLAT` görevleri için `hedef − _ovsync_kural_tarihi` sapması taban-türüne göre raporlanır. Yorumlama matrisi:
  - `sapma = 0` → görev kurala birebir (normal).
  - `sapma > 0` → kural tarihi geçmiş kaldığında `GREATEST(kural, bugün)` kırpması (migration `:923`) — meşru; raporda ayrı işaretlenmez.
  - `sapma < 0` (hedef kuraldan ERKEN) → **kural/veri ihlali adayı**; kök-neden kolonları (dogum_tarihi, son doğum, son abort) satırda gösterilir. Sahibin "12 aylık düve" gözlemi bu grupta aranır; grupta satır yoksa gözlem kapanır ("kural-dışı düve yok" raporu).
  - Beklenen-sonuç notu (plan-3 B6 OBSERVED): kupe 51 / doğum 2025-11-17 / hedef 2026-12-08 düvesi pencere dışında olduğundan bugünkü panelde GÖRÜNMEZ; 12a21g kuralı hedefte birebir tutar (sapma 0 beklenir).
- **Kapsam sınırları:** Bu spec, görev üretim kurallarını (Plan 1 M1/M2) ve kısır kilidini (Plan 1 U1/U2) DEĞİŞTİRMEZ; yalnız görüntülediği satırın navigasyonu/metnini düzeltir.

## 4. Dokunulacak dosyalar — TAM liste (tek-yazıcı zarfı: Adım 4)

| Dosya | Değişiklik | Kapsam |
|---|---|---|
| `js/ui.js` | (1) `_ovSatir` → modül-seviyesi `_ovUyariSatirHtml(u)` (B23); (2) N1 satır onclick + stopPropagation sarmalı; (3) M1 metni + koşullu saat; (4) `_showOvsyncYardim`/`_closeOvsyncYardim` + `?` rozeti; (5) `_ovsyncBildirim` imza + Notification onclick + app-içi banner `_ovsyncBildirimBanner`; (6) `ovsyncBaslat(gorevId, hayvanId)` + 2 butonda `data-h` | tek yazıcı |
| `js/utils/handlers.js` | `navGeriKarar`'a `ovsync-yardim` vakası (§3.4) | tek satır-sınırlı |
| `js/app.js` | popstate switch'ine `'ovsync-yardim'` case'i (§3.4) | tek case |
| `tests/unit/ovsync-pg-ui.test.js` | Yeni testler (§7 E bloğu): satır html (onclick/stopPropagation/M1 metni/koşullu saat/escAttr disiplini), banner html, yardım metni içerik | test |
| `tests/modal-router.spec.js` | 1 yeni e2e: `?` → yardım sheet açılır → geri tuşu sheet'i kapatır, dash'e atmaz (B22 sentetik-uyarı altyapısıyla) | test |
| `index.html` | `?v=` damgası tek değerde güncellenir (ör. `20260925-01`) (B20) | 1 satır × n etiket |

**Dokunulmayanlar (açık yasak listesi):** `js/api.js`, `js/forms.js`, `js/state.js`, `js/config.js`; tüm `supabase/migrations/*` (migration YOK — §6); RPC imzaları (`ovsync_baslat_uyarilari`, `start_first_service_protocol`); `openDet` imzası; toast sözleşmesi (`js/utils/helpers.js`); sw.js; `js/utils/modal.js` (pushState deseni panel-local'dır).

## 5. Uygulama sırası (tek PR-öncesi commit ölçeğinde 3 adım)

1. **ui.js navigasyon + metin** (N1 + M1 + S3 kozmetik) + `_ovUyariSatirHtml` extract → unit testler E.1-E.3.
2. **ui.js yardım katmanı** (M2/M3) + handlers/app.js geri-tuş vakası → E.4 + modal-router e2e.
3. **ui.js bildirim** (N2: imzalar + banner + Notification onclick) + `?v=` damgası → E.5-E.6.

Her adımdan sonra: `npm run test:unit` + `gitnexus detect_changes` (§8 kapıları).

## 6. Migration / RPC taslağı

### 6.1 Migration: YOK (gerekçeli karar)

- N1/N2/M1/M2 tamamen istemci-taraflıdır; gereken tüm veri alanları RPC dönüşünde zaten mevcuttur (B6).
- RPC'lerin imzası, dönüş şeması ve GRANT'ları değişmez → `scripts/db-validate.sh` kapısı bu spec için **N/A** dır (uygulayıcı hiç migration dosyası üretmez; üretirse bu spec'ten sapmıştır ve kapı zorunludur).
- Y1 gereği istemciye yaş filtresi eklenmez; sunucu penceresi (B7) ve kural fonksiyonu (B9) dokunulmaz.

### 6.2 Y2 ölçüm SQL'i (Adım 0, DEMO, salt-okunur — migration DEĞİL)

```sql
-- Y2: açık OVSYNC_BASLAT görevlerinde hedef−kural sapması (demo, SELECT-only)
SELECT g.id                       AS gorev_id,
       h.kupe_no,
       COALESCE(h.kategori, h.grup) AS kategori,
       (CASE WHEN g.kaynak LIKE 'ILK-TOH-DUVE-%'  THEN 'duve'
             WHEN g.kaynak LIKE 'ILK-TOH-DOGUM-%' THEN 'dogum'
             WHEN g.kaynak LIKE 'ILK-TOH-ABORT-%' THEN 'abort'
             ELSE 'acik_disi' END)              AS taban_turu,
       g.hedef_tarih,
       public._ovsync_kural_tarihi(h.id)       AS kural_tarihi,
       g.hedef_tarih - public._ovsync_kural_tarihi(h.id) AS sapma_gun,
       h.dogum_tarihi,
       (SELECT max(d.tarih) FROM public.dogum d
         WHERE d.anne_id = h.id)               AS son_dogum,
       (SELECT max(t.abort_tarihi) FROM public.tohumlama t
         WHERE t.hayvan_id = h.id AND t.sonuc = 'Abort'
           AND t.abort_tarihi IS NOT NULL)     AS son_abort,
       g.kaynak
FROM public.gorev_log g
JOIN public.hayvanlar h ON h.id = g.hayvan_id
WHERE g.gorev_tipi = 'OVSYNC_BASLAT'
  AND COALESCE(g.tamamlandi, false) = false
  AND COALESCE(g.iptal, false)     = false
ORDER BY 7 ASC NULLS LAST, h.kupe_no;   -- en negatif sapma en üstte
-- Özet: SELECT taban_turu, count(*), min(sapma), max(sapma) → (yukarıdaki sorguyu CTE olarak kullanıp grupla)
```

Rapor sahibe sunulur (sentez §3 Adım 0; plan-1 S1 ile AYNI koşum — iki spec tek çıktı paylaşır).

## 7. Kabul testleri (ölçülebilir maddeler)

**A — Navigasyon**
1. Protokol panelinde İlk Tohumlama satırına dokununca hayvan kartı açılır (`#det.on`), satır küpesi kartta görünür.
2. Kartta geri tuşuna basınca panel YENİDEN görünür (`protokol-bs` display:'flex' — B11 akışı); dash'e atlanmaz.
3. [▶ Başlat] ve [✕] butonlarına dokunuş satır-tıklamasını tetiklemez; Başlat akışı (RPC + toast + pullTables) bugünkü gibi çalışır.
4. `openDet` imzası değişmez; mevcut ~12 çağrı noktasında davranış regresyonu yok (E.7 + `gitnexus detect_changes` boş beklenen-etki).

**B — Metin + yardım katmanı**
5. Satır metni M1 biçiminde; "Ovsynch-56" adı geçer; saat bölümü `hedef_saat` boşken hiç basılmaz (çift ayraç yok).
6. `?` rozetine dokununca yardım katmanı açılır; ✕, backdrop tap ve GERİ TUŞU'nun üçü de kapatır; geri tuşu uygulama sayfasını değiştirmez (modal-router invariantı).
7. Yardım katmanı metni 3 maddeyi içerir: Ovsynch-56 (4 seans), TAI (=hedef+10), taban kuralları (Düve 12a21g / İnek +51 / hedef−2 pencere).
8. Yardım katmanı açıkken panel ve satırlar erişilebilir kalır (katman kapandığında panel state'i bozulmamış).

**C — Bildirim**
9. `Notification.permission==='granted'` + `hayvanId` biliniyorken: sistem bildirimi tıklanınca uygulama odaklanır ve hayvan kartı açılır (best-effort; test ortamında onclick atamasının VARLIĞI doğrulanır — teslim bildiriminde PWA kısıtı belirtilir).
10. İzin yokken `ovsyncBaslat` başarıdan sonra `ovsync-bildirim-bs` banner'ı gösterir; satır tıklaması hayvan kartını açar; backdrop tap kapatır; ~10 sn'de kendiliğinden kapanır; banner pushState üretmez (geri tuşu banner'ı kapatmaz/etkilemez).
11. `hayvanId` bilinmiyorken (beklenmedik çağrı): bugünkü davranış korunur (yalnız toast + Notification), hata fırlatılmaz.

**D — Yaş denetimi**
12. Adım 0'da Y2 SQL koşulmuş ve rapor sahibe sunulmuş; `sapma < 0` satırı YA sıfırdır YA da her satır kök-neden kolonlarıyla tek tek açıklanmıştır.
13. Panel görünüm penceresi değişmemiştir (yalnız `hedef ≤ bugün+2` görevleri — B7); istemcide yaş filtresi yoktur (kod incelemesi: `_ovUyariSatirHtml` u-parametrelerini yalnız görüntüler).

**E — Regresyon/dalış**
14. `npm run test:unit` yeşil; `tests/unit/ovsync-pg-ui.test.js`'e en az 5 yeni test: (E.1) satır html `onclick="_protoDetayHayvanGit"` + `cursor:pointer` içerir; (E.2) buton hücresi `event.stopPropagation()` sarmallı; (E.3) M1 metni + boş-saat kuralı (iki vaka); (E.4) yardım katmanı html'i 3 içerik maddesini barındırır; (E.5) banner html'i hayvan-kartı aksiyonu taşır + `escAttr` disiplini (B21'in XSS test kalıbıyla: ham id basılmaz).
15. `tests/modal-router.spec.js` mevcut testleri (özellikle B21 maddeleri) yeşil kalır; 1 yeni yardım-sheet e2e eklenir.
16. `index.html` `?v=` tek değer güncel; tarayıcıda eski-cache ile eski ui.js karışımı yok (sahip yürüyüşü öncesi hard-reload notu teslime yazılır).
17. `gitnexus detect_changes` çalıştırılır; etki yalnız beklenen sembollerde (`_ovUyariSatirHtml`, `_ovsyncBildirim`, `ovsyncBaslat`, `_showOvsyncYardim`, `navGeriKarar`, popstate case).

## 8. Blast-radius ön-kontrolleri (uygulayıcı kapıları — zorunlu)

- **gitnexus indeks yenileme:** Bu spec yazılırken indeks `d6a41c0` (HEAD'den 4 commit geride — `list_repos` OBSERVED 2026-09-24). Uygulayıcı dokunmadan ÖNCE `gitnexus analyze` ile indeksi dal ucuna (beklenen: bu dalın HEAD'i) eşitler; kapıların tümünü taze indeksle koşar.
- **`gitnexus context openDet`** — imza/çağrı envanteri teyidi (plan-3 skeptik notunun istediği adım; bu spec'te grep envanteri B10 ile ön-dolduruldu).
- **`gitnexus impact _ovsyncBildirim` / `_ovsyncBaslatBtnHtml`** (upstream) — imza uzatmalarının dokunmadığı tüketici kalmadığını gösterir (beklenen: çağrı envanteri §2 B4/B16 ile birebir).
- **`code-change-precheck` skill'i** (ui.js/handlers/app.js düzeni öncesi) — repo sözleşmesi gereği.

## 9. Geri-dönüş planı

- Değişiklik yüzeyi yalnız istemci dosyalarıdır (§4) → geri dönüş = `git revert <adım-commit'leri>`; DB tarafında geri alınacak HİÇBİR şey yok (§6.1) — demo verisi bütünlüğü bu spec'ten bağımsız kalır.
- Kısmi geri-dönüş:
  - Yardım katmanı sorunluysa: `?` rozetini çizen satır + `_showOvsyncYardim/_closeOvsyncYardim` + handlers/app.js case'i tek commit'te geri alınır; N1/M1 ayakta kalır.
  - Banner sorunluysa: `_ovsyncBildirim`'in izin-yok kolu tek satırla banner'sız eski davranışa döner (kabul 11'in yolu); N1/M1 ayakta kalır.
- Geri-tuş vakası (handlers/app.js) geri alınırsa: yardım katmanı pushState'i öksüz girdi bırakabilir → ikisi AYNI commit'te revert edilir (ayrık revert YASAK — spec maddesi).

## 10. Kesişim haritası (tek-yazıcı koordinasyon)

| Kesişen iş | Sahip | Bu spec'in yükümlülüğü |
|---|---|---|
| Plan 1 U2 — kısır kilidi (`_ovUyariSatirHtml` içinde aynı satır çizimi) | Adım 1 (önce koşar) | Bu spec'in baseline'ı kısır-kilitli satırı İÇERİR; E.1-E.3 testleri `u.kisir` alanının varlığında kilidi kırmaz (test verisi kisir'siz hayvanla yazılır; kisir'li vaka Plan 1 testlerine aittir) |
| Plan 4 M3 UI — `_dashBands` izole bandı + `_showSessizList` bölümü + `_sessizGrupla` | spec-S2 | Bu spec o yüzeylere DOKUNMAZ; yalnız `_protoDetayHayvanGit` ortak fonksiyonunu tüketir (değiştirmez) |
| Sentez §5A "Plan 3'e muayene bildirim metni" ataması | **BELİRSİZ** | GEBELIK_KONTROL bildirim metni bu spec'in konu satırında YOK; plan-4 M3 UI maddesi band+sheet'i üstlenmiş durumda (plan-4'te Plan-3 atfı yazılı değil — grep boş). Ticket decomposition'da tek sahibe bağlanmalı; bu spec bilinçli olarak dokunmaz. **ATAMA BELİRSİZLİĞİ — UNKNOWN** (bkz. §11 U-3) |
| TAI'nin hayvan kartında gösterimi (sentez S6 yarısı) | Tur-2 başında netleşecekler #5 | Bu spec işlemez; yardım katmanındaki TAI tanımı kart-gösteriminden bağımsız doğrudur |

## 11. Varsayımlar ve bilinmeyenler

- **V-1 (OBSERVED→teyit):** Yardım metnindeki "4 seans" B24 ile canlı demo şablonundan doğrulandı; uygulayıcı apply-öncesi aynı 2 satırlık sorguyu bir kez daha koşar (şablon kullanıcı-düzenlenebilir — aradaki değişiklik metni değiştirir).
- **V-2 (CONFIRMED):** `_protoDetayHayvanGit`'in detay-sheet'siz kullanımı güvenli (B12 guard'ları) — satır-düzeyi doğrudan çağrı için tasarım varsayımı değil, kod-düzeyi doğrulama.
- **V-3 (INFERRED):** Notification `onclick` + `window.focus()` PWA'da her tarayıcıda çalışmayabilir (B19 sw.js no-op) — kabul 9 bilinçli best-effort'tur; birincil yol app-içi banner.
- **U-1 (UNKNOWN):** Eski `OVSYNC_BASLAT` görevlerinde `hedef_saat`'in NULL oran Adım 0'da ölçülmedi; B5 kozmetiği koşullu-basım kuralıyla her oranda doğru davranır ama raporda sayı verilirse sahibe bilgi olarak eklenir.
- **U-2 (UNKNOWN):** "12 aylık düve" gözleminin kök nedeni (veri hatası mı, eski-kural görevi mi) Y2 raporu olmadan SÖYLENEMEZ — spec bilinçli olarak tahmin üretmez; kabul 12 kapıya bağlar.
- **U-3 (UNKNOWN):** GEBELIK_KONTROL bildirim metninin spec sahipliği — §10 satırı; decomposition'da kapatılmalı.
- **V-4 (CONFIRMED):** `?v=` damgası tek-değer kuralı (B20) — ui.js + handlers + app.js üç dosya birden değiştiği için damga mutlaka güncellenir; güncellenmezse sahibin yürüyüşünde eski-cache karışımı sahte-bulgu üretir (teslim riski).

## 12. Skeptik öz-denetim (bu spec yazımında)

- *İtiraz: "Satır tıklaması `_closeProtokolListe` ile mi, `_protoDetayHayvanGit` ile mi?"* → `_protoDetayHayvanGit` seçildi: popstate 'det' vakası (B11) gizlenen paneli KENDİLİĞİNDEN geri getirir; `_closeProtokolListe` yolunda panel geri gelmez (remove edilir) ve kullanıcı bağlamını kaybeder. Kod kanıtlı, yeni mekanizma icat edilmedi.
- *İtiraz: "Banner'a pushState koymalı mıydın; back-banner'ı kapatmalı?"* → Hayır: toast sınıfı transient yüzey + 10 sn otomatik kapanış; pushState koymak modal-router yüzeyini her ovsync başlatmada şişirirdi. Kabul 10'da davranış kilitli.
- *İtiraz: "`hedef_saat` hep '10:00' zaten; koşullu basım gereksiz."* → Görevler `_acik_disi_gorev_kur` dışı yollardan da gelebilir (R3.2 öncesi görevler B25'te NULL bırakabilir); koşullu basım maliyetsiz ve S3'ü kalıcı kapatır.
- *İtiraz: "Yardım katmanı için navGeriKarar'a vaka eklemek fazla mühendislik."* → Eklenmezse kullanıcı back'e basınca sayfa değişir, öksüz `{ovsync_yardim}` girdisi history'de kalır (B15'teki B21 dersi) — vaka eklemek mevcut desenin şartı, yeni desen değil.
- *İtiraz: "Migration yok diye spec DB'sizmiş gibi davranıyor; Y2 SQL'i nereye giriyor?"* → Y2 Adım 0 salt-okunur ölçümdür, şema değişikliği değil; §6.2'de açıkça "migration DEĞİL" damgalı; db-validate kapısının N/A gerekçesi §6.1'de bağlandı.
