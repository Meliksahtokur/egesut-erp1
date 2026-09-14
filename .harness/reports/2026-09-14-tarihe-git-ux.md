# Teslim Raporu — U1 "Geçmiş / Tarihe git" UX düzeltmesi

**Dal:** `agent/tarihe-git-faz1-U1` (taban `agent/tarihe-git-faz1` @ `89eade1` — merge ÇALIŞTIRILMADI) · **Worker:** U1 (glmf)
**Zarf:** `/home/melik/egesut-erp1/.ss/tasks/U1-tg1-gecmis-ux.md` + root düzeltmeleri (2026-09-14, canlı talimat — aşağıda §5)
**Hedef (sahip cümlesi):** "Bir güne gidince o gün ne olduğunu bir bakışta anlarım, bir olaya tıklayınca o olayın kendisine giderim."

## 1. Değişen dosyalar (tam kapsam)

| Dosya | Değişiklik |
|---|---|
| `js/gecmis.js` | `_GM_ISLEM_TIP_ETIKET`/`_GM_ISLEM_TIP_EMOJI` TEK harita (52 tip) + `_gmIslemTipEtiket`/`_gmIslemTipEmoji` okunur yedek; `_gmGunKatla` (saf katlama) + `_gmGunKategoriSayac` (çip sayaçları); `_gmGroupHtml`'e `opts.katHtmlFn` |
| `js/ui.js` | `_ISLEM_ETK`/`_ISLEM_ICO` SİLİNDİ (4 kullanım tek haritada); `_gecmisEntryHtml` tüm kartlar `data-action` + `escAttr` (gm-islem/gm-case/gm-toh/gm-stok/gm-det/gm-kupe — inline onclick YOK); `_gecmisKupeLabel`/`_gmIslemBaslikEtiketi`/`_gmKatSatirEtiket`/`_gmKatKartHtml`; `openIslemDetay` → `_openIslemDetayRow(l, anchor)` (panel kartın ALTINA açılır — eski `.hist-row` hedefi D9 sonrası hiç bulamıyordu = sessiz no-op); `globalThis._gmHayvanKupeById` (id→küpe, collect'te kurulur — UUID YOK kuralı) + `_gmIslemLogById` (panel id-erişimi); `_gecmisGunCiplerGuncelle` + `_gecmisGunCip` filtresi + gün modunda eski filtre satırını gizleme; klasik/defter/gün render'larında katlama |
| `js/utils/handlers.js` | 7 aksiyon: `gm-islem`, `gm-case`, `gm-toh`, `gm-stok`, `gm-kupe`, `gm-kat-ac`, `gm-gun-cip` |
| `index.html` | `#gecmis-gun-cipler` konteyneri; üst filtre satırına `id="gecmis-filtre-satir"` (gün modunda gizlenir); CSS `.gm-cip*`/`.gm-kat-acik` + `@media (max-width:400px)`; `?v=` 23 satır → `20260914-04` |
| `tests/unit/gecmis-etiket.test.js` | YENİ — 6 test (harita TAM, ham kod YOK, yedek, emoji eş-küme) |
| `tests/unit/gecmis-katla.test.js` | YENİ — 9 test (≥3 grup / <3 tek / eşik / farklı tip-dakika-kaynak-gün / saat'siz katılmaz / sıra / boş / çip sayaç) |
| `tests/unit/gecmis-xss.test.js` | +9 test: EVIL id dataset+escAttr (islem/hastalik/tohumlama/stok/dogum); katlı kartta hostile metin ham tag ÜRETMEZ; **root düzeltme testleri** — ham UUID ASLA YOK (IDB indeksi çözer), hayvansız başlık 'Genel', katlı küpe listesinde UUID YOK |
| `tests/unit/vaka-toplu-ac.test.js` | Damga pinleri `20260914-04`; eski-damga listesine `-02` eklendi |
| `tests/tarihe-git.spec.js` | Fixture testi: banner **266 statik oracle KORUNDU**; kart sayısı katlama-farkındalı yapısal eşitlik (olay + grup sayısı); veri-konverjans beklemesi (`expect.poll _gecmisGunSayi>0`) |
| `tests/gecmis-ux.spec.js` | YENİ — 4 e2e: ham kod YOK + **ham UUID YOK** + ölü kart yok + **tek filtre satırı**; islem kartı → panel kart-altı; katlı kart aç/kapa/satır-tıklama; çip sayaç+toggle+mobil sarma |
| `.harness/reports/2026-09-14-tarihe-git-ux.md` | bu rapor |

(`supabase/`, `js/degisiklikler/` DOKUNULMADI. `type="date"` YOK — kanonik `tekTarihTakvimAc` şeridi aynen.)

## 2. Hedef başına kanıt

### H1 — Türkçe etiket, tek kaynak (zarf md.1)
- Tek harita `js/gecmis.js` (52 tip): eski iki kopyanın birleşimi (`_ISLEM_ETK`/`_ISLEM_ICO` + `openIslemDetay` yerel LABEL/ICO — ikisi de silindi, `grep` yalnız yorum notu verir) + `_GM_UNDO_ISLEM_TIPLERI` + islem_log INSERT taraması (migration'lar). Canlı demo verisinden çıkan iki tip haritalandı: `GOREV_TAMAMLA` ("Görev Tamamlandı"), `VAKA_TOHUMLAMA_EKLE` ("Vaka Tohumlama Günü Eklendi" — zarfın örneği; önce ekranda yedekle doğrulandı, sonra haritaya alındı).
- Yedek: bilinmeyen tip → `'İşlem: ' + toLowerCase().replace(/_/g,' ')` (düz toLowerCase — TR I→ı 'tedavı' ürettiği için, zarf örneği 'tedavi' esas; koddaki yorumda gerekçe). Ham `BUYUK_HARF_KOD` hiçbir kartta görünmez: unit §A/§B + e2e raw-kod taraması (09-06 günü body metni).

### H2 — Ölü kart yok (zarf md.2)
- İşlem aynası kartı KOŞULSUZ tıklanabilir: `data-action="gm-islem" data-det=escAttr(data.id)` → `_openIslemDetayRow(l, el)` — panel TIKLANAN KARTIN ALTINDA açılır.
- **Bulgu-onarım:** eski `openIslemDetay(idx)` `#tab-gecmis .hist-row[idx]` arıyordu; D9 sonrası det kartları `.stok-item` olduğundan hedef hiç bulunamıyor = ana listede panel **sessiz no-op**tu. `anchor` genelleştirmesi her iki yüzeyde çalışır; idx-arayüzü geriye-dönük korunur. idx/global yarışı `_gmIslemLogById` id-haritasıyla (ana+det MERGE) kalktı.
- Diğer kartlar: hastalik→`gm-case`, tohumlama→`gm-toh`, gorev→`gm-det` (TEDAVI_GUN+_caseId→`gm-case`), uygulama/asi/kizginlik/protokol→`gm-det`, cikis/sutten→`gm-det(id)`, dogum span'ları→`gm-det`/`gm-kupe`, stok→`gm-stok(stok_id)` (openStokDet ui.js:5311). Hepsinde dataset+escAttr, inline onclick YOK.
- e2e: `.stok-item[onclick]` sayısı 0; hedefsiz kart listesi boş; islem kartı tıklaması paneli açıp Kapat'la kaldırıyor.

### H3 — Toplu işlemleri katla (zarf md.3)
- `_gmGunKatla` (saf): anahtar `dateKey|sourceKey|tip|dakika` (islem'de tip=`data.tip`; dakika `_gmCsvSaat` TR kuralı). **≥3 → tek düğüm; <3 → tek tek.** Saat damgası olmayan satır (yalnız date kolonu) ASLA katılmaz — "aynı dakika" kanıtı yoksa birleştirme bilgi yutar (unit testli).
- Kart: "🌱 Vaka Tohumlama Günü Eklendi — 10 hayvan" + küpe listesi (ilk 8, "+N") + "▸ Tıkla — N kaydı göster"; `gm-kat-ac` aç/kapa; açılınca satırlar tam kart, her biri kendi hedefine tıklanabilir. Ekran kanıtı: 13.09'da iki grup — "Vaka Tohumlama Günü Eklendi — 10 hayvan" (04·121·23·4019·178·135·136·200+2) ve "Tedavi Günü Eklendi — 44 hayvan".
- Kapsam: gün + defter + klasik (zarf md.15); det (hayvan kartı) hattında katlama yok — tek-hayvan hattında yığın oluşmaz.

### H4 — Gün özeti + kategori çipleri (zarf md.4)
- Banner altında çip satırı: "Tümü (108) · 🐮 İşlem (62) · 📦 Stok Hareketi (34) · 🏥 Hastalık (11) · ✅ Görev (1)" — sayaçlar filtre ÖNCESİ tüm günden (`_gmGunKategoriSayac`, saf/unit'li), azalan sıra, yalnız gün modunda.
- Tık → `category` filtresi (istemci tarafı, ek pull YOK); tekrar tık/Tümü → kaldır (e2e: state + yapısal sayı eşliği + toggle).
- Mobil ≤400px: çipler sarılır (e2e: 390px'te ≥2 satır), `.stok-item` taşma kilidi (ekran görüntüsü mobil 390×844).

## 3. Root düzeltmeleri (2026-09-14 canlı talimat — 4/4 uygulandı)

1. **Kartlarda ham UUID YOK.** Teşhis: `_gecmisKupeLabel` zinciri eski kodun birebir aynısıydı (regresyon DEĞİL); UUID'ler çekim betiğinin hayvanlar store commit'ini (~5,5 sn) beklemeden çekmesinden + state-gecikmesi riskinden geliyordu. Düzeltme İKİ katman: (a) `_gecmisCollectSources` artık `globalThis._gmHayvanKupeById` indeksi kuruyor (hayvanlar zaten collect'te IDB'den okunuyor — state gecikse bile çözülür); (b) fallback zincirinin ham-id ayağı kaldırıldı → çözülemeyen '?' (islem başlığında root-2 kuralı). REST ölçümü: 13.09'da 73 islem satırı canlı (veri duruyordu, sorun yarıştı). Test: unit root-1/root-3 + e2e UUID-taraması (09-06 body metni).
2. **Hayvansız kartta '?' YOK:** `_gmIslemBaslikEtiketi` — küpe çözülmüyorsa snapshot'taki görev adı/açıklaması (JSON label ayrıştırılır), o da yoksa 'Genel'. Ekran: "Genel — Görev Tamamlandı". Unit root-2.
3. **Gün modunda TEK filtre satırı:** eski HEPSİ/DOĞUM/… satırı (`#gecmis-filtre-satir`) gün modunda gizlenir; tek satır çiplerdir ve sayılar aynı pipeline'dan (`_gmGunKategoriSayac`) — tutarsız sayı yapısal olarak imkânsız. e2e: `#gecmis-filtre-satir` gizli + çipler görünür. (Eski satır `TOHUMLAMA (0)` gösteriyordu çünkü VAKA_TOHUMLAMA_EKLE kartları kategori 'islem' — çip satırında da tohumlama 0'dır ama artık İKİNCİ bir çelişkili sayaç YOK.)
4. **Ekran görüntüleri yeniden çekildi** (§4) — ayrıca çekim betiği sağlamlaştırıldı: boot-pull hayvanlar bekleme + sakinlik koşulu (loader YOK + boş-uyarı YOK + sayaç 2,5 sn sabit) + 5 denemeli yeniden-gün-seçme; üç yarışmacı loadGecmis (boot-pull + tab-girişi pull'u + gün seçimi skipPull) ara-render'larını (spinner/"0 olay") ekran görüntüsüne sokmuyor.

## 4. FINAL KANIT — Playwright tek koşum (final kod, damga `20260914-04`)

- **Komut** (W3 final şablonu + U1 spec'i):
  `docker run --rm -e PLAYWRIGHT_DEMO_MODE=1 -e PLAYWRIGHT_BASE_URL=http://127.0.0.1:8080/ -v "$PWD":/work -v /home/melik/egesut-erp1/node_modules:/home/melik/egesut-erp1/node_modules -w /work mcr.microsoft.com/playwright:v1.58.2-noble bash -c "ln -sfn /home/melik/egesut-erp1/node_modules /work/node_modules && npx playwright test tests/tarihe-git.spec.js tests/gecmis-ux.spec.js tests/tarih-secici.spec.js tests/gece-tarih.spec.js tests/sutten-kes.spec.js tests/offline-kuyruk.spec.js tests/sablon.spec.js --workers=1 --retries=0 --reporter=list --output=/tmp/pw-out"`
- **Sonuç (logdan okundu):** **24 passed / 1 skipped / 0 failed (2.4m), EXIT=0** — 25 test; U1'nin 4 yeni e2e'si + güncellenen fixture testi dâhil.
  **Log:** `/home/melik/tmp/agents/tg1-ux/u1-playwright-final.log`
- **Damga kanıtı:** logdaki 1150 kaynak isteği `?v=20260914-04`; eski damga yanıtı YOK.
- **Kalan tek skip:** `tests/gece-tarih.spec.js:63` — önceden-var olan veri-bağımlı skip (küpeli-hayvan; W3 finalindekiyle AYNI, U1 dışı, dokunulmadı).
- **Tarihçe (GEÇERSİZ koşumlar, dürüst döküm):** (a) geliştirme koşumu 12:57 — 9p/0f (yalnız 2 spec); (b) final-girişim-1 13:10 — 23p/1f/1s: fixture testi tab-girişi pull yarışına takıldı (banner "0 olay") → testte konverjans beklemesi eklendi (statik oracle korundu); (c) final-girişim-2 13:16 — 24p/1s/0f. Root'un 4 düzeltmesi SONRASI, final kodun kendi belgeli koşumu yukarıdaki (13:4x) koşumdur; öncekiler tarihçedir, tekrar edilmedi.

### Ekran görüntüleri (sahip kanıtı; repoda DEĞİL)
Demo, 13.09.2026 (toplu tedavi + toplu vaka tohumlaması olan gün), FİNAL kodla:
- `/home/melik/tmp/agents/tg1-ux/gun-gorunumu-masaustu-1366x900.png` — banner "DÜN · 13.09.2026 · 108 olay" + TEK filtre satırı (çipler) + küpeli kartlar ("01 — Tedavi Günü Eklendi", "Genel — Görev Tamamlandı")
- `/home/melik/tmp/agents/tg1-ux/katli-kart-acik-masaustu.png` — katlı kart AÇIK: "🌱 Vaka Tohumlama Günü Eklendi — 10 hayvan" (04·121·23·4019·178·135·136·200+2), 10 satır açık ve tıklanabilir; altta "Tedavi Günü Eklendi — 44 hayvan"
- `/home/melik/tmp/agents/tg1-ux/gun-gorunumu-mobil-390x844.png` — mobil 390×844: çipler sarılı, kartlar taşmasız
- Çekim script'i: `/home/melik/tmp/agents/tg1-ux/cekim.mjs` (test koşumu DEĞİL)

## 5. Ölçümler

- **Unit:** `NODE_PATH=/home/melik/egesut-erp1/node_modules node --test tests/unit/*.test.js` → **tests 916 · pass 916 · fail 0** (taban 892 + 24 yeni: 6 etiket + 9 katla + 9 XSS). Sözdizimi `node --check` ui/gecmis/handlers TEMİZ.
- **Damga:** `grep -o "?v=[0-9-]*" index.html | sort | uniq -c` → **23× `20260914-04`** (+1 dinamik nokta); final logda 1150 istek aynı damga.
- **REST ölçümü (root-1 teşhisi):** demo islem_log 13.09 = 73 satır (son: `2026-09-13T19:37Z TEDAVI_GUN_EKLENDI`) — veri canlıydı, UUID sorunu veri değil yarış kökenliydi.
- `git diff --check` TEMİZ; staged alan `git diff --cached --stat` ile doğrulandı (§6).

## 6. Commit

Stage doğrulaması: `git diff --cached --stat` (commit öncesi — 13 dosya: 10 M + 3 ??). Commit mesajı `U1 teslim` içerir. `git merge`/push YAPILMADI (zarf md.8).

## 7. Açık kalemler (root kararı)

1. **`islemGeriAl` tek-arg kırığı (ROOT KURALIYLA DOKUNULMADI — yazma yolu U1 dışı):** det panelindeki HAYVAN_GUNCELLENDI "Geri Al" butonu `onclick="islemGeriAl('${l.id}')"` (js/ui.js `_openIslemDetayRow`, ~2986) tek argümanla çağırır; global `islemGeriAl` forms.js:3471 `(btn, islemLogId)` bekler (ui.js'ten SONRA yüklenir → gölgeleme) → `btn=id, islemLogId=undefined` = sessiz kırık. ui.js:2953'teki eski `(islemId)` tanımı gölgede durur. Buton HTML'i U1'de AYNEN korundu (root talimatı 2026-09-14).
2. **Panel payload değerleri ham `${v}`** (`_openIslemDetayRow` satirlar döngüsü) — DB payload değeri esc'siz basılır (eski davranış aynen; U1 kart kapsamı dışı). Aday güvenlik işi.
3. **Det (hayvan kartı) panelinde katlama/çip yok** — tek-hayvan hattında yığın oluşmuyor; gerekirse ayrı iş.
4. **e2e gün-modu akışlarındaki tab-girişi pull yarışı** (bu rapor §4 tarihçe-b) — U1 yalnız kendi spec'lerinde konverjans beklemesi koydu; diğer spec'ler için `expect.poll` deseni önerilir (öneri, uygulanmadı).
5. **`gorev` pill metni 'TEDAVI GUN' biçimli** (gorev_tipi `_`→boşluk, uppercase kalır) — islem_log tipi DEĞİL; md.1 kapsamı dışında bırakıldı (gözlem).

## 8. Kırıntılar

`.crumbs/tarihe-git-faz1-U1.jsonl` — gate (kabul-et-başla, 3 beyan) + root-düzeltme + teslim kırıntıları. Board: `.ss/-BOARD.md` (çalışma aracı, commit dışı).
