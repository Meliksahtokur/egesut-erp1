# Unit Test Kapsam Genişletme Raporu — 2026-08-31

**Görev:** js/ modüllerindeki saf fonksiyonlar için unit test kapsamı (mevcut `node --test`
altyapısıyla, yeni framework yok). **Commit:** `6f3aa13` (push EDİLMEDİ — sabah incelemesi için).
**Sonuç:** 22 test → **251 test** (229 yeni, 0 kırmızı, 1 belgelenmiş skip).

## Yeni altyapı: tests/unit/support/loadModule.js

js/ tarayıcı-global yazılmış (module.exports yok) ve kural gereği değiştirilemez.
Çözüm: `node:vm` tabanlı loader — kaynak dosyayı lenient DOM/localStorage/window stub'lı
sandbox'ta çalıştırır. Üst-seviye `function` bildirimleri sandbox'a düşer; `let/const/class`
için `expose: [...]` ikinci script ile dışarı çıkar. Ek yardımcılar: `makeDomStub`,
`makeElement`, `makeStorage`, `makeDbStub` (rpc stub), `extractFunctionSource` /
`loadExtractedFunction` (tüm modül yüklenemeyen durumlarda cerrahi fonksiyon çıkarma).
Doğrulandı: 8.4k satırlık ui.js ve 1.9k satırlık forms.js dahil tüm modüller yükleniyor.

**Bilinen vm/altyapı tuzakları** (test dosyalarında yorumlandı):
- vm realm'inin prototipleri host'tan farklı → `deepStrictEqual`/`instanceof` vm nesnelerinde
  düşer; yapısal karşılaştırma veya JSON round-trip normalizasyonu gerekir.
- `loadBrowserModule` o anki global `setTimeout`'ı sandbox'a kopyalar → mock timer'lar
  `t.mock.timers.enable()` sonrası yapılacak yüklemede etkili olur.
- Node mock `Date` vm realm'ine geçmez → throttle testinde ilerletilen saat stub'ı `extra.Date` ile verildi.

## Eklenen testler (dosya bazlı)

| Dosya | Test | Kapsam |
|---|---|---|
| state.test.js | 28 | AppState: get/set/getAll/setBatch/on/off/emit semantiği, no-emit aynı değer, unsubscribe |
| config.test.js | 13 | HASTALIK_KAT↔LISTESI bütünlüğü, GRUP_PADOK/SPERMA/HEKIMLER tutarlılığı |
| helpers-extra.test.js | 23 | escAttr (5 char + property), esc (fake document ile), debounce/throttle (mock timer), g/v/cl |
| errorHandler.test.js | 20 | getUserMessage eşleme/öncelik/fallback, withErrorHandling sözleşmesi |
| events.test.js | 12 | data-action/input/focus/change/keydown delegation, preventDefault kuralları |
| ui-pure.test.js | 36 | yasHesapla (11 + 3 property), band, _dashVacAlerts (latest-wins), _yeniDogumGun, _durumClr/Txt, renderSeansGrupAyrac |
| forms-validation.test.js | 42 | _kupeKontrolEt (RPC param routing dahil 10), _sutIcenBuzagilar, renderBuzagiPicker, vaccinePickerSearch/selectedVaccineRows, _vaccineNaive, ekUygulama akışı |
| ai-asistan.test.js | 32 | _asistanStripThink/_asistanEsc/_asistanCevapHtml/_asistanBalon vs. |
| auth.test.js | 14 | authGate/şifre değişimi hata eşleme/oturum gate'leri (db.auth stub ile) |
| modal.test.js | 9 | openM/closeM router semantiği (history stub ile) |

1 skip: `yasHesapla` gün-ödünç dalı 31 Ağustos'ta takvimle ulaşılamaz — test kendini
gerekeniyle birlikte atlıyor; fast-check mirror property dalı rastgele tarihlerle yine de kapsıyor.

## Şüpheli davranışlar (kaynak DÜZELTİLMEDİ — testlerde `ŞÜPHELİ DAVRANIŞ` olarak kilitlendi)

**Yüksek ilgi gerektirenler:**
1. **`forms.js:_kupeKontrolEt` fail-open** — DB hatası veya rpc throw'da uyarı temizleniyor:
   başarısız çakışma kontrolü sessizce "küpe müsait" sayılıyor (forms.js:41-47 civarı).
2. **`ui.js:band()` escape yapmıyor** (ui.js:67) — `_dashBands` births60 bandı `anne_id`/`tarih`
   ham giriyor (ui.js:196 civarı). En az bir çağrı doğru `esc()` kullanıyor; hepsi değil.
3. **`state.js:setBatch` asimetrisi** — `set` `'*'` event'i `(key,value,old)` yayınlar;
   `setBatch` tek argümanlı dizi `[{key,value}]` yayınlar + anahtar event'leri `old` değerini
   taşımaz. `'*'` dinleyicileri iki biçimi ayrı işlemek zorunda.
4. **`errorHandler.js:showDebug` → `esc` bare global** (errorHandler.js:40) — modül kendi
   `esc`'ini tanımlamıyor; `debugMode` + `#debugPanel` varken catch bloğu içinde
   ReferenceError üretebilir (production'da global `esc` var, modül self-contained değil).

**Orta/bilgi notu:**
5. `helpers.js:escAttr` idempotent DEĞİL (`escAttr(escAttr('&')) === '&amp;amp;'`) — çift
   escape tehlikesi; `esc(0)→''` ama `escAttr(0)→'0'` (falsy coercion tutarsızlığı).
6. `errorHandler.js` eşleme `Object.entries` sırasına bağımlı + case-sensitive
   ('failed to fetch' eşleşmez).
7. `events.js` keydown delegation sözleşmesi farklı: `{key,event}` wrapper, element yok.
8. `config.js`: 'Ruminal Asidoz', 'Timpani', 'Şirden Deplasmanı' hem 'Metabolik' hem 'Sindirim'
   kategorisinde (çift sayım riski); `LOKASYON_KAT`'ta 'Göz' var, `HASTALIK_KAT`'ta yok.
9. `ui.js:_dashVacAlerts` latest-wins seçimden SONRA `next_due_date` filtresi — en yeni
   kayıtta tarih yoksa çift tamamen kaybolur (ui.js:118).
10. `forms.js:_sutIcenBuzagilar` kolon `suttten_kesme_tarihi` (üç t — muhtemelen DB ile aynı);
    ≤180 gün OR kuralı gruptan bağımsız her aktif hayvanı, grup üyelerinde yaş sınırını kaldırıyor.
11. `ui.js:_yeniDogumGun` `gun>0` katı — bugünkü doğum hiç gösterilmez ("0 gün" yok).
12. `ai-asistan.js`: `_asistanEsc(5)` truthy non-string throw; kapanmamış `<think>` geçmiş
    görünümünde kuyruğu yutar; `_asistanPlanKarti` global `escAttr` bağımlı;
    `asistanGecmisAc` (344-345) `data-tid` ham interpolasyon (uuid-only, düşük risk).
13. `modal.js:closeM` element olmasa da `history.back()` çağırıyor.
14. `auth.js:58` bilinen güvenlik bulgusu notu — dokunulmadı (agent o satırı `setMode`
    çağrısı olarak gördü; eski bulgu satır numarası kaymış olabilir, sabah kontrolü iyi olur).

## Kapsanamayan alanlar (nedeniyle)

- **ui.js DOM render fonksiyonları** — görev tanımı gereği E2E kapsamı. Ek olarak:
  `kizginlikYoktu` (async db+confirm), `_belirsizSelPredik` (DOM state mutasyonu),
  `_gecmisSearchText` (getState bağımlı, düşük öncelik).
- **api.js** — yüklenebilir (`extra.supabase.createClient` stub ile); test edilebilir
  adaylar ileride: `_trErr`, `rpc()` arg doğrulaması, `RPC_TABLES`; IDB katmanı indexedDB
  stub ister (orta efor). Bu oturumda kapsam dışı bırakıldı.
- **handlers.js** — tümü app/ui global'lerine delege eden ince lambda'lar; saf mantık yok,
  izole yükleme `registerActions` global'i yüzünden ReferenceError.
- **demo.js / app.js** — IIFE/DOM/init ağırlıklı, unit dışı.
- **forms.js `renderVaccinePicker`** — ürettiği DOM'un elle kurulmuş aynasıyla dolaylı test edildi.

## Sabah incelemesi için

- Suite: `npm run test:unit` → 251 test, 250 pass + 1 skip, ~0.14 sn.
- Commit `6f3aa13` yalnızca tests/ altını içerir (11 dosya, +3195); js/ ve diğer takip
  edilen dosyalara dokunulmadı (git status doğrulandı, detect_changes: risk yok).
- Push yapılmadı. Supabase'e hiçbir yazma yapılmadı.
- Önerilen sıradaki adımlar: (1) yukarıdaki 1-4 numaralı bulgular için karar (fix task
  açılırsa testler zaten mevcut davranışı kilitliyor, düzeltince testler bilinçli
  güncellenmelidir); (2) api.js `_trErr`/arg doğrulama testleri; (3) fast-check seed
  sabitleme değerlendirilebilir (şu an 3-5 ardışık koşuda stabil).
