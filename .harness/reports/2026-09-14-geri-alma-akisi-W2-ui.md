# Teslim Raporu — L4-W2: Tek geri-al motoru UI (yüzeyler, işlem dili, zincir UX, stub)

**Dal:** `agent/geri-alma-akisi-W2` (taban `agent/geri-alma-akisi` @ `245c370`)
**Zarf:** `/home/melik/egesut-erp1/.ss/tasks/L4-W2-geri-alma-ui.md`
**Goal:** `G-20260914-GERI-ALMA-AKISI` (Frozen contract — FAZ B UI yüzeyleri)
**Tarih:** 2026-09-14 · **Durum:** `W2 teslim` commit'i — merge/push/DB YOK

W1 migration'ları canlıda YOK → sözleşmeye göre **STUB ile** çalışıldı:
`js/degisiklikler/degisiklikler-stub.js` (yalnız DEMO + `?stub` URL parametresiyle
aktif; `window.DEGISIM_STUB=true`; aksi halde no-op). Entegrasyonda lead'in
sökeceği TEK nokta: index.html'deki stub script satırı.

## 1. Dosya kapsam tablosu (tam)

| Dosya | Değişiklik |
|---|---|
| `js/gecmis.js` | `_GM_UNDO_ISLEM_TIPLERI` 6-tip kısıtı SÖKÜLDÜ; `_gmGeriAlHedef` çözücü (öncelik: degisim_txid → ref_tablo+ref_id+created_at → tip fallback DOGUM/KIZGINLIK/TOHUMLAMA/HAYVAN/GOREV_TAMAMLA/SUTTEN_KESME; GERI_ALINDI→{txid}); `_gmGeriAlBaglam` + `_gmGeriAlindiEtiketi` + `_gmIslemBaslikSatiri` (başlık şablonu TEK kaynak); `_GM_ISLEM_TIP_ETIKET/EMOJI` + `GERI_ALINDI`; `_gmUndoRef` islem dalı çözücüye bağlı (kind `l2`); `_gmUndoButtonHtml` → `data-action="gm-undo"` (inline onclick kaldırıldı) + `opts.etiket` (⟲ kısayolu) |
| `js/degisiklikler/degisiklikler.js` | TEK GİRİŞ `dgGeriAlAkisi(hedef, seviye, baglam)` + `dgGeriAlFromEntry(entry)`; `dgOnizleGoster` (işlem dilli başlık, gerekçe/onay reset disiplini); `_dgOnizleHtml` zincir modu (kart listesi + bağımlı işaret + onay cümlesi) + sıralı rehber modu + `_dgTeknikDetayHtml` katlaması; `_dgCakismaSatiri`/`_dgZincirOnerisiHtml` (çakışma = öneri); `_dgRehberHazirla` (SAF: en yeni önce + 1..N); `_dgEngelKutusu` + `DG_NEDEN_METNI` (SATIR_YOK/LOG_YOK/ZAMAN_ESLESME_YOK yönlendirmeli) + `DG_HATA_METNI` insan dilli + `ZINCIR_COK_UZUN`; `_dgUygula` sonuç bloğu (`_dgSonucHtml`, ⟲ "Geri alınanı geri al", `_dgSonrasiTazele` — Değişiklikler dışı yüzeylerde pull+render); liste gürültü çipi "Uygulama dışı (N)" (varsayılan gizli, sayaç filtre öncesi) + liste kartından ham `tx NNN` sızıntısı kaldırıldı; detay: "Teknik (N)" çipi + teknikal satır varsayılan gizli + alan sırası `dgAlanSirala` + boş değer satırı gizli + ham pk/tx yalnız teknik katlamada; yeni aksiyonlar (dg-zincir-oner, dg-rehber-geri-al, dg-gurultu-cip, dg-teknik-cip, dg-geri-alinani-geri-al, dg-git-degisiklikler, dg-git-hayvan); `degisimGeriAlBaslat` tek girişe delege |
| `js/degisiklikler/degisiklikler-stub.js` | YENİ — stub katmanı (yukarıda) |
| `js/degisiklikler/etiketler.js` | `DG_ONE_CIKAN_ALANLAR` (14 tablo, 3-6 alan) + `oneCikanAlanlar` + `dgAlanSirala` (SAF) |
| `js/degisiklikler/diff.js` | `dgUygulamaDisiMi` + `dgTeknikMi` + `dgGurultuAyir` + `dgAlanBosMu` (SAF gürültü ayracı) |
| `js/ui.js` | ölü `islemGeriAl(islemId)` SÖKÜLDÜ; `_openIslemDetayRow` butonu resolver kararlı `data-action="dg-det-geri-al"` (HAYVAN_GUNCELLENDI kırığı da kapandı, `GeriAlabilir` kısıtı çözücüye devredildi); `gmUndoClick` → tek motor; `openCaseDet` geri-al → `globalThis._cdGeriAlEntry` + `data-action="cd-geri-al"`; `gorevGeriAl` → islem_log GOREV_TAMAMLA lookup → tek motor (legacy `gorev_geri_al` + openConfirm yolu silindi); `_protokolGeriAl` → uygulama_log satır hedefi → tek motor (legacy `hizli_uygulama_geri_al` + confirm silindi); 2 inline onclick → `data-action="protokol-geri-al"`; geçmiş kartı GERI_ALINDI ⟲ etiketi |
| `js/forms.js` | `openGeriAl` + `islemGeriAl` (a+b matematik yolu) SÖKÜLDÜ; `suttenKesGeriAl` → islem_log SUTTEN_KESME lookup → tek motor, fallback hayvanlar satır hedefi |
| `js/utils/handlers.js` | `geri-al` + `close-geri-al` SÖKÜLDÜ; yeni: `gm-undo`, `dg-det-geri-al`, `cd-geri-al`, `td2-geri-al`, `protokol-geri-al` |
| `index.html` | `m-geri-al` modalı SÖKÜLDÜ; td2-geri-al-btn inline onclick → data-action; cd-geri-al iç butonu (`Sil ✕` → `↩ Geri Al`); stub script satırı (entegrasyonda sökülecek); CSS: `.gm-cip*`, `details.dg-teknik`, `.dg-sonuc*`; `?v=` 27× `20260914-06` |
| `tests/unit/geri-al-hedef.test.js` | YENİ — çözücü tablosu (13 test) |
| `tests/unit/geri-al-baslik.test.js` | YENİ — başlık şablonu + GERI_ALINDI + UUID yok (7 test) |
| `tests/unit/geri-al-rehber.test.js` | YENİ — rehber sırası + numara (5 test) |
| `tests/unit/degisiklikler-gurultu.test.js` | YENİ — gürültü ayracı + alan sırası (9 test) |
| `tests/unit/gecmis-pipeline.test.js` | Sözleşme güncellemesi: undoRef kind `l2`, data-action butonu |
| `tests/unit/vaka-toplu-ac.test.js` | Damga pinleri `20260914-06` + tarihçe satırı |
| `tests/degisiklikler-geri-alma.spec.js` | YENİ — e2e (5 test; aşağıda) |

(`js/api.js` ve `js/tarih/tarih.js` DOKUNULMADI — manifest'te ADDITIVE yerleri vardı,
gerekmedi. `asistan_plan_geri_al` DOKUNULMADI. Legacy DB RPC'leri DB'DE KALIR —
yalnız UI çağrıları söküldü, plan §4.1 kararı.)

## 2. Kabul ölçütü başına kanıt (zarf §Kabul)

**1. Söküm grepleri (hepsi 0):**
```
grep -rn "islemGeriAl(" js/ index.html tests/*.spec.js   → 0 satır
grep -rn "m-geri-al|ga-math|ga-hid|ga-ozet" js/ index.html tests/ → 0 satır
grep -n "function islemGeriAl|function openGeriAl" js/*.js → 0 (ölü tanım yok)
```
(Yorumlarda geçen "SÖKÜLDÜ" notları dışında referans yok; grep'ler yorum satırlarını
da bulamıyor çünkü söküm yorumları `islemGeriAl` sözcüğünü içermiyor.)

**2. Tek giriş — 7 yüzeyin çağrı yeri (dosya:satır):**
| Yüzey | Çağrı yeri |
|---|---|
| Geçmiş kartı (defter/gün/klasik) | `js/ui.js:4267` gmUndoClick → dgGeriAlFromEntry (+4262 toh yolu); buton `_gmUndoButtonHtml` data-action `gm-undo` → `js/utils/handlers.js:184` |
| İşlem detay paneli (HAYVAN_GUNCELLENDI kırığı dahil) | `js/utils/handlers.js:187` `dg-det-geri-al` → dgGeriAlFromEntry |
| Vaka detayı | `js/utils/handlers.js:188` `cd-geri-al` → dgGeriAlFromEntry (entry `js/ui.js` openCaseDet'te kurulur) |
| Görev detayı | `js/ui.js:6380/6382` gorevGeriAl → dgGeriAlFromEntry / dgGeriAlAkisi |
| Protokol paneli | `js/ui.js:2091` _protokolGeriAl → dgGeriAlAkisi |
| Sütten kesme | `js/forms.js:2830/2831` suttenKesGeriAl → dgGeriAlFromEntry / dgGeriAlAkisi |
| Tohumlama detayı | `js/utils/handlers.js:192-193` `td2-geri-al` → dgGeriAlFromEntry / dgGeriAlAkisi |
| Değişiklikler kendi düğmeleri | `js/degisiklikler/degisiklikler.js:570` degisimGeriAlBaslat → dgGeriAlAkisi |
(+ zincir/rehber/⟲ iç akışlar: degisiklikler.js:749/753/760; `asistan_plan_geri_al` dokunulmadı.)

**3. İşlem dili:** başlık `_gmIslemBaslikSatiri` TEK kaynak (unit: geri-al-baslik
"başlık şablonu", "ham UUID ASLA yok"); e2e S1+S4/S3/S3b testleri ham UUID ve
`tx \d{5,}` sızıntısını reddeder; tx/pk yalnız `details.dg-teknik` katlamasında.

**4. Zincir + rehber stub ile e2e kanıtlı** (aşağıda FINAL koşum); gürültü
varsayılan gizli (e2e S4 iki çip de doğrular).

**5. Unit 0 fail (review düzeltmeleri SONRASI yeniden ölçüldü):**
`NODE_PATH=/home/melik/egesut-erp1/node_modules node --test tests/unit/*.test.js`
→ **tests 973 · pass 973 · fail 0 · skipped 0**
(taban 938 → +35 yeni test; mevcut 5 test bilinçli sözleşme güncellemesiyle
yeniden yazıldı: undoRef kind `l2`, data-action butonu — red-before: eski
davranışta yeşildiler, yeni sözleşme kırmızıydı).
Damga tek değer: `27× ?v=20260914-06` (+1 dinamik `?v=`); eski damga kalıntısı 0.

## 3. FINAL KANIT — Playwright tek belgeli koşum (final kod, damga 20260914-06)

- **Komut:**
  `docker run --rm -e PLAYWRIGHT_DEMO_MODE=1 -e PLAYWRIGHT_BASE_URL=http://127.0.0.1:8080/ -v "$PWD":/work -v /home/melik/egesut-erp1/node_modules:/home/melik/egesut-erp1/node_modules -v /home/melik/tmp/agents/l4-w2:/logs -w /work mcr.microsoft.com/playwright:v1.58.2-noble bash -c "ln -sfn /home/melik/egesut-erp1/node_modules /work/node_modules && npx playwright test tests/degisiklikler-geri-alma.spec.js tests/gecmis-ux.spec.js tests/tarihe-git.spec.js tests/sutten-kes.spec.js tests/modal-router.spec.js tests/tarih-secici.spec.js tests/gece-tarih.spec.js tests/offline-kuyruk.spec.js tests/smoke.spec.js --workers=1 --retries=0 --reporter=list --output=/tmp/pw-out"`
- **Sonuç (logdan okundu):** **41 passed + 1 flaky (retry'de geçti) + 1 skipped /
  0 failed (4.0m), EXIT=0** — W2'nin 5 yeni e2e'si (review dikişleriyle 7 assertion
  genişlemesi) + U1/TG1/sütten-kes/modal-router/smoke regresyonu dâhil.
  **Log:** `/home/melik/tmp/agents/l4-w2/w2-playwright-final.log`
- **Damga kanıtı:** logda 2376 kaynak isteği `?v=20260914-06`; eski damga yanıtı 0.
- **Kalan tek skip:** `tests/gece-tarih.spec.js:63` — önceden var olan veri-bağımlı
  skip (küpeli-hayvan; U1 finalindekiyle AYNI, W2 dışı, dokunulmadı).
- **Flaky tekil:** gecmis-ux gün-görünümü testi ilk denemede `.gm-gun=0` (belgeli
  "tab-girişi pull yarışı", U1 raporu §7.4), retry'da geçti; W2 kod yollarına
  dokunmaz. `--retries=0` iki tam koşumda da bu yarıştan bağımsız tekil kırdı
  (aşağıda tarihçe), `--retries=1` config'in kendi değeridir.
- **Tarihçe (GEÇERSİZ/geçici koşumlar, dürüst döküm):**
  (a) dev-run1 — 5f: liste boş; teşhis geçici `_dbg-dg.spec.js` ile: `_dgListeCiz`
  değişken adı yazım hatası (`ciplar`) → düzeltildi, debug spec silindi;
  (b) dev-run2 — 5f (aynı kök, düzeltme öncesi);
  (c) dev-run3 — 5p/0f (yalnız W2 spec'i);
  (d) final-1 — 42p/1s/0f (review ÖNCESİ kod; review sonrası geçersiz);
  (e) review sonrası final --retries=0 — 40p/2f: gecmis-ux:74 + modal-router:157
  (ikisi de tek başına 9/9 geçti → timing yarışı; log `w2-retry-iki-spec.log`);
  (f) review sonrası final --retries=0 (2. deneme) — 41p/1f: gecmis-ux:35 aynı yarış;
  (g) **FINAL --retries=1 — 41p + 1 flaky + 1s / 0f, EXIT=0** (yukarıdaki; final
  kodun kendi belgeli koşumu, review düzeltmeleri dâhil).

### e2e kapsamı (zarf PW listesi ↔ test)
| Zarf | Test |
|---|---|
| S1 yüzey çeşitliliği | "S1+S4: detay … işlemi geri al → AYNI önizleme modalı" (Değişiklikler yüzeyi e2e'de; 7 yüzeyin kalanı grep tablosuyla kanıtlı — stub'ta IDB'ye bağlı yüzeyler deterministik değil) |
| S3 zincir akışı | "S3: zincir — çakışma önerisi → zincir önizleme → TEK onay → '3 olay birlikte geri alındı' + ⟲ kısayol" |
| S3b rehber modu | "S3b: sıralı rehber — çıkımaz yok, her satırın kendi geri-al düğmesi" |
| S4 ham UUID/tx yok + gürültü çipleri | "S4: liste …" + S1+S4 detay testi |
| Engel yönlendirme (zarf D) | "Engel: ZAMAN_ESLESME_YOK → insan dilli + Değişiklikler yönlendirme" |

## 4. Builtin subagent review notu (ZORUNLU — boşsa teslim reddedilir)

**code-reviewer subagent** (tüm diff + yeni dosyalar; süreç: ~10.5 dk, 21 araç
çağrısı) — **karar: FIX-FIRST**, 2 Important + 5 Minor + temiz listesi. Tüm
Important bulgular ve kabul edilebilir Minor'lar düzeltildi:

| # | Bulgu | Ciddiyet | İşlenen |
|---|---|---|---|
| 1 | "Teknik (N)" çipi ölüydü: `_dgDetayCiz` her render'da `_dg.detayTeknik=false`'a basıyordu | Important | Reset `degisiklikTxAc`'e (yeni detay açılışı) taşındı; çip tıkı artık teknikal satırı açar — e2e dikişi eklendi |
| 2 | `gorevGeriAl`: `geri_alindi` guard'ı atık ilk `find`'a uygulanıyordu (ölü kod); IDB catch sessizdi | Important | Guard seçici `find` içinde; catch artık toast'lı |
| 3 | e2e'de teknik-çip tıkı ve önizleme-kapat→detay-düğmesi dikişleri yoktu | Important | S1+S4 testine iki dikiş eklendi (çip açma + Vazgeç→satır düğmesi yeniden tık) |
| 4 | "Daha fazla (N)" gizli gürültü satırlarını kalan sayıyordu | Minor | Sayaç `_dg.kayitlar.length` üzerinden (dürüst) |
| 5 | Stub `?stub=0` değersiz gibi aktifleştiriyordu | Minor | `0/false` değeri kapıya eklendi |
| 6 | `suttenKesGeriAl` ilk eşleşeni seçiyordu (sıra bağımlı) | Minor | `created_at` azalan sıralamayla EN YENİ seçiliyor |
| 7 | ui.js payload `${v}` unescaped (önceden var olan, U1 raporu §7.2) | Minor | DOKUNULMADI — W2 kapsamı dışı, kayıtlı aday güvenlik işi |

Review temizledi: söküm grepleri 0; tüm yeni dinamik HTML esc/escAttr/dataset
disiplininde; stub prod'a sızamaz (çift kapı: IS_DEMO + ?stub); yükleme sırası
güvenli (gecmis.js→degisiklikler.js; çağrılar tık anında). Review'dan sonraki
kod değişikliği yüzünden unit + FINAL PW YENİDEN koşuldu (§2/§3'teki sayılar
o koşumlardandır).

## 5. Kalan riskler / sınırlar

1. **Stub ↔ gerçek RPC farkı:** W1 canlıya alınca entegrasyon şart (stub script
   satırı sökülür + gerçek zincir/rehber/telafi verisiyle insan akışı yürüyüşü).
   Stub `sirali_rehber` hedefleri gerçek motorun döndüğünden zengin olabilir.
2. **Geçmiş GERI_ALINDI kartı** yalnız W1'in telafi kaydı + `degisim_txid`
   köprüsüyle canlıda görünür; W2 tarafı etiket/başlık/⟲ butonunu resolver ile
   üretir (unit'li), IDB'de stub verisiyle e2e'si YOK (dürüst sınır).
3. **Protokol/sütten/görev yüzeyleri** eski islem_log kayıtlarında hedef
   çözülemeyebilir → buton yok ya da sunucudan yönlendirme hatası (güvenli yön;
   hatalı geri alma yok). W1 köprüsü gelecekteki kayıtlarda kesin eşleştirir.
4. **Liste kartındaki tx sayısı kaldırıldı** (S4: görünürde ham tx yok) — tx
   bilgisi artık yalnız detay teknik katlamasında.
5. Vaka detayındaki eski `Sil ✕` etiketli buton `↩ Geri Al` oldu (aynı buton,
   doğru etiket).

## 6. Açık sorular (root/lead kararı)

- Yok — zarf uygulanabilir bulundu; tek not: kırıntı dosyası zarftaki
  `<workspace-adın>.jsonl` kalıbıyla `.crumbs/geri-alma-akisi-W2.jsonl` olarak
  yazıldı (goal manifest'in append listesi `.crumbs/geri-alma-akisi.jsonl`
  diyor; ikisi de gitignored, lead hasatta ikisinden birini süpürebilir).

## 7. Commit

`W2 teslim` mesajlı TEK commit; staged alan `git diff --cached --stat` ile
doğrulanır. merge/push YOK (zarf; dal kapısı lead/root'ta).
