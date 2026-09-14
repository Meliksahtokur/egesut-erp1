# Teslim Raporu — TG1 "Tarihe git" Faz 1 implementasyonu (W2 worker)

**Dal:** `agent/tarihe-git-faz1-W2` (taban `main` @ `bdee91f`) · **Worker:** W2 (glmf)
**Zarf:** `/home/melik/egesut-erp1/.ss/tasks/TG1-W2-impl.md` (lead) ← `.ss/tasks/L3-tarihe-git-faz1.md` (root)
**Goal:** `.harness/goals/2026/G-20260914-TARIHE-GIT.md` — paralel W1 worker'ı yazıyor; bu rapor
goal'a yol referansıyla bağlıdır, goal dosyasına DOKUNULMADI (zarf md.11).

## 1. Ne yapıldı (özet)

Geçmiş sekmesine "tarihe git: o gün ne oldu?" girişi — istemci tarafı (rapor §D.c seçenek c):
kanonik tarih seçiciyle gün seçimi, seçilen günün olayları **olay-günü kuralıyla** (`olayGunu`)
tek listede; 5 eksik kaynak eklendi; islem_log aynaları DEDUP öncelik tablosuyla baskılanıyor;
`_gmGroupLabel` DÜN time-bomb onarıldı. Defter/klasik hattının `dateKey`/`eventAt` davranışı
DEĞİŞMEDİ (ayrı hat + dokunulmazlık testleri).

## 2. Değişen dosyalar (tam kapsam)

| Dosya | Değişiklik |
|---|---|
| `js/gecmis.js` | `olayGunu(sourceKey,row)` saf kuralı + `_gmGunZaman` kolon haritası; `_gmGunEntriesFromSources` tek-gün hattı (5 yeni kaynak, gün politikaları, DEDUP); `_gmGroupLabel` DÜN onarımı (todayKey'ten türetme); defter entry'lerine `sourceKey`; yeni kategori TR/emoji haritaları |
| `js/ui.js` | `_gecmisCollectSources` +5 kaynak (aşı adı/stok adı-birimi zenginleştirme); `loadGecmis` gün modu + pull listesine `vaccination_log`,`kizginlik_log`,`stok_hareket`; `_gecmisRender` tek-gün grubu (todayKey=gerçek bugün); `_gecmisEntryHtml`/`_gecmisSearchText`/`_gecmisCsvMeta` yeni kategoriler; `gecmisTariheGitAc`/`gecmisGunSec`/`_gecmisGunBannerGuncelle` |
| `js/utils/handlers.js` | 4 action: `gecmis-tarihe-git`, `gecmis-gun-bugun`, `gecmis-gun-dun`, `gecmis-gun-kapat` |
| `index.html` | `#pg-gecmis` üstüne tarih şeridi (Bugün/Dün/📅 Tarihe git) + `#gecmis-gun-banner`; `?v=` damgası `20260913-18`→`20260914-01` (23 nokta) |
| `.harness/references/ui-map.md` | Geçmiş bölümüne 3 satır: olay-günü kuralı + gün hattı + gün görünümü girişi (anchor'lar `tests/harness/test_patterns.py` çözümlemesine uygun) |
| `tests/unit/gecmis-gun.test.js` | YENİ — 19 test (olayGunu saf kuralı, gün hattı, DEDUP tablosu, defter dokunulmazlığı, DÜN sözleşmesi) |
| `tests/unit/vaka-toplu-ac.test.js` | `?v=` damga-pinleri `20260914-01`'e (2 test; damga ile AYNI değişiklik) |
| `tests/tarihe-git.spec.js` | YENİ — 4 e2e (kanonik seçici, dedup-sayı eşleşmesi, DÜN etiketi, Kapat dönüşü) |
| `.harness/reports/2026-09-14-tarihe-git-f1.md` | bu rapor |

(`.ss/`-BOARD çalışma aracı; commit dışı. `supabase/`, `js/degisiklikler/*` DOKUNULMADI.)

## 3. Kabul kriterleri — kanıt başına

| Zarf md. | Kriter | Kanıt | Durum |
|---|---|---|---|
| 1 | `olayGunu` saf kuralı; dateKey DEĞİŞMEZ; 5 eksik kaynak; TR-günü + `_GM_TZ_ESNEK` | `js/gecmis.js` (`olayGunu`/`_gmGunZaman`); test §A: date kolon değeri aynen, `2026-09-08T21:30:00Z`→`2026-09-09` (TR), `+03:00` yerel kalır, timezone'suz korunur; **olayGunu≠dateKey** testi (geri tarihli tohumlama olay gününde, defter dateKey kayıt anında) | **PASS** |
| 1 (red-before) | Yeni saf fonksiyon testleri RED-BEFORE kanıtlı | Koşum sırası: test dosyası impl'den ÖNCE → **19 test 0 pass 19 fail** (`TypeError: olayGunu is not a function` — log: `~/tmp/agents/w2-red-before-gun.log`), impl sonrası **19/19/0** (`w2-green-gun2.log`) | **PASS** |
| 2 | Entry'lere `sourceKey`; tip-geri-çözüm YASAK | `js/gecmis.js` push açık taşır; test: `type:'hastalik'` ↔ `sourceKey:'cases'`, `type:'islem'` ↔ `sourceKey:'islem_log'` | **PASS** |
| 3 | "Tarihe git" girişi + gün görünümü + **DEDUP zorunlu** | Şerit butonları (index.html) → `tekTarihTakvimAc` (kanonik — yeni bileşen YOK); DEDUP öncelik tablosu `js/gecmis.js` (aşağıda §4) + 6 birim testi; e2e'de banner sayısı = dedup SONRASI pipeline sayısı (canlı demo verisinde eşleşti) | **PASS** |
| 4 | todayKey sözleşmesi (gerçek bugün; DÜN türetilir; seçili gün ASLA todayKey'e geçmez) | `_gmGroupLabel` DÜN artık todayKey'ten (koddaki yorum sözleşmeyi işler); `_gecmisRender` gün modu `todayKey:_gmTodayKey()` sabit; banner ayrı yüzey; test: enjekte `todayKey=2026-09-09` → DÜN=09-08 gerçek tarihten bağımsız + ay/yıl devri (09-30/10-01, 12-31/01-01) | **PASS** |
| 5 | `_gmGroupHtml` DÜN time-bomb onarımı; **test mi kod mu — gerekçe**; 0 fail | **KOD düzeltildi, test DOKUNULMADI.** Gerekçe: zarf md.4 sözleşmesi "DÜN bugün'den türetilir" der; mevcut kod DÜN'ü sistem saatinden (`new Date()`−1) türetiyordu — enjekte edilen todayKey'yi yok sayıyordu. Test fixture'ı (`todayKey:'2026-09-09'`) sözleşmenin DOĞRU pinidir; hata koddadır. Taban 863/862/1 → final **882/882/0** | **PASS** |
| 6 | Geçmiş giriş pull'ına `stok_hareket` | `js/ui.js` pull listesi +`stok_hareket` (+`vaccination_log`,`kizginlik_log` — rapor §G gereği; `hayvanlar` eklenmedi: boot pull kapsamında, gün hattı IDB'den okur — çekim maliyeti eklenmedi) | **PASS** |
| 7 | `?v=` TEK değer, `20260914-01`+ | `grep -o "?v=[0-9-]*" index.html | sort | uniq -c` → **23× `20260914-01`** (22 script + manifest), `-18` kalıntısı 0; damga-pin testleri aynı değişiklikte güncellendi | **PASS** |
| 8 | ui-map Geçmiş bölümü güncelle | `.harness/references/ui-map.md` +3 satır (olay-günü kuralı, gün hattı + DEDUP özeti, giriş + todayKey notu); anchor'lar `function` bildirimi olarak çözümleniyor | **PASS** |
| 9 | Unit 0 fail | `NODE_PATH=/home/melik/egesut-erp1/node_modules node --test tests/unit/*.test.js` → **ℹ tests 882 · ℹ pass 882 · ℹ fail 0** (EXIT=0; taban 863/862/1, +19 test) | **PASS** |
| 10 | Playwright tek koşum, komut + sonuç | Aşağıda §5 — **18 passed / 2 skipped / 0 failed (1.7m)** | **PASS** |
| 11 | Teslim raporu + dalına commit (TG1 işaretli) | bu dosya + commit | **PASS** |

## 4. DEDUP öncelik tablosu (bildirim — zarf md.3 "§D.c esas, sapma gerekçelendir")

Zarfın 3 zorunlu çifti **birebir uygulandı**; aynı ayna mekanizması gereği 3 çift daha eklendi
(sapma beyanı: `islem_log` birleşik günlüktür — rapor §E.2 "çoğu olay iki kaynaktan gelir";
baskılama yalnız **aynı olay-günü + aynı hayvan/ref** eşleşmesinde çalışır, ayna yoksa islem
kalemi kalır):

| Baskılanan (islem_log aynası) | Kazanan kaynak | Eşleşme |
|---|---|---|
| `ASI_KAYDI` *(zarf)* | `vaccination_log` | ana_hayvan_id=animal_id + gün |
| `KIZGINLIK_KAYDI` *(zarf)* | `kizginlik_log` | ana_hayvan_id=hayvan_id + gün |
| — *(stok çifti, zarf)* | tohumlama/tedavi kalemi | `stok_hareket.referans_id`→kaynak `id` + aynı gün |
| `SUTEN_KESME` *(ek)* | `hayvanlar.suttten_kesme_tarihi` | hayvan + gün |
| `TOHUMLAMA` *(ek)* | `tohumlama` | `ref_id`→id (yoksa hayvan+gün) |
| `VAKA_ACILDI` *(ek)* | `cases` (start_date) | `ref_id`→id (yoksa hayvan+gün) |

**Ölçüm:** birim testleri (6 test, eşleşen baskılanır / eşleşmeyen kalır her yönü) + e2e'de
banner sayısı ile dedup-sonrası pipeline sayısının canlı demo verisinde eşitliği.
**Beyan:** `stok_hareket.referans_tipi` canlıda %97 boş (rapor §E-5) — referans eşleşmesi yalnız
bağlanabilen azınlıkta baskılar; bağlantısız satırlar §E.3 gereği "genel stok hareketi"
(hayvansız) kategorisi olarak GÖRÜNÜR (doğru beklenti; kayıp değil).

Gün görünümü islem politikası §D.c.3 gereği genişletilmiştir: TÜM islem tipleri (geri_alindi
hariç) görünür, defterin `_GM_ISLEM_TIPLERI` kürasyonu defterde aynen kalır. Tedavi seansı
aynası (`TEDAVI_SEANS_TAMAM`/`SEANS_EKLENDI`) baskılanMAZ — §A.4 kararı: seansın gün
görünümündeki temsili budur (treatment_days ayrı satır olarak girmez).

## 5. Playwright tek koşum (docker, demo-mode)

```bash
docker run --rm \
  -e PLAYWRIGHT_DEMO_MODE=1 -e PLAYWRIGHT_BASE_URL=http://127.0.0.1:8080/ \
  -v "$PWD":/work -v /home/melik/egesut-erp1/node_modules:/home/melik/egesut-erp1/node_modules \
  -w /work mcr.microsoft.com/playwright:v1.58.2-noble \
  npx playwright test tests/tarihe-git.spec.js tests/tarih-secici.spec.js \
    tests/gece-tarih.spec.js tests/sutten-kes.spec.js tests/offline-kuyruk.spec.js tests/sablon.spec.js \
    --workers=1 --retries=0 --reporter=list --output=/tmp/pw-out
```

**Sonuç satırı: `18 passed / 2 skipped (1.7m)` — 0 failed.** Toplam 20 test (4+9+3+1+2+1);
2 skip önceden-var olan **veri-bağımlı** koşullar (regresyon spec'lerinde `test.skip(...)`,
R1/F2 koşumlarındakiyle aynı desen; TG1 spec'inin 4 testi de GEÇTİ — "en zengin gün" testi
banner sayısı = dedup-sonrası pipeline sayısı + kart sayısı eşitliğini canlı demo verisinde
doğruladı). Çıktıdaki son koşan test satırı:
`✓ 20 [chromium] › tests/tarihe-git.spec.js:115:7 › ✕ Kapat: defter görünümü döner, banner gizli (3.2s)`.
Not: çıktı yakalama `tail -45` ile yapıldı — özet satırı + v=20260914-01 ile 200/304 dönen tüm
kaynak istekleri yaklandı; spec-başı satırların bir kısmı kuyruk dışında kaldı (koşum sahib
kuralı gereği TEKRAR EDİLMEDİ; skip atıfları spec kaynaklarından statik doğrulandı).
`--output=/tmp/pw-out` konteyner-içi → worktree'de root-artığı YOK (doğrulandı).

## 6. Review notu (öntem)

- **Blast-radius:** PreToolUse hook'u GitNexus indeksi bayat olduğu için geçemedi (R1 teslim
  raporundakiyle aynı durum); gerçek analiz LSP findReferences ile yapıldı
  (`_gecmisCollectSources`: 3 ref — iki çağıran da dönüş-nesnesi eklemesiyle uyumlu;
  `loadGecmis`: 11 ref — imza değişmez, pull listesi ekleme; `_gecmisEntryHtml`: 7 ref —
  yalnız ek `else if` dalları). Risk DÜŞÜK; işaret sonrası edit geçti.
- **Defter dokunulmazlığı:** yeni kaynaklar `_gmEntriesFromSources`'a sızMAZ (birim test
  kilitli); klasik görünüm 'Aktif/Kapalı' vaka etiketi değişmedi (gün modu `olayGunu` alanı
  varlığıyla ayrıştırılır).
- **Kod incelemesi builtin subagent ile ayrıca koşulmadı** — denetim luna (codex) koltuğunda
  lead sürecinde yapılacak (L3 zarfı; sahibin "denetim luna" kuralı).

## 7. Ertelenenler / açık kalemler (lead+root kararı)

1. **Hayvan kartına gün görünümü girişi** (rapor §F önerisi) — zarf kapsamında DEĞİL (zarf
   yalnız "Geçmiş sekmesi" der); `_gmEntriesFromSources`'a `{animalId, olayGunu}` scope'u
   doğal genişlemedir, ayrı iş olarak önerilir.
2. **Bekleyen görevin "planlandı" kalemi** (`hedef_tarih` gününde) — §D.c.3 "Faz 1'de
   opsiyonel"; eklenmedi.
3. **`?gun=YYYY-MM-DD` deep-link** — §D.c.4 opsiyonel adımı; eklenmedi.
4. **Kategori çipleri** gün görünümünde yalnız 'Hepsi' altında yeni kategorileri gösterir
   (asi/kizginlik/stok/cikis/sutten/protokol çipi yok) — Faz 1 bilinçli sınır.
5. **Önceden-var olan harness testi kırmızıları (2)** — `tests/harness/test_patterns.py`:
   (a) `ui-map.md`'de F3'ten kalma stale anchor `js/forms.js:bcTarihTakvimAc` (Toplu vaka
   bölümü; benim diff'imin dışında — taban `bdee91f`'te de kırmızı, kanıt: forms.js'te 0 tanım);
   (b) eski goal dosyalarının biçim hataları (INVALID_ACCEPTANCE vb.). **Düzeltilmedi**
   (görevde olmayan kusur — rapor kuralı).
6. **`hayvanlar` pull listesinde değil** — boot pull kapsamında; gün hattı IDB'den okur
   (offline kriteri korunur). Bayat-hayvan uyarısı: uygulama ömründe uzun oturumlarda gün
   görünümü hayvan çıkışlarını boot pull'undan okur; sekme girişindeki pull hayvanları
   tazelemez (zarf yalnız stok_hareket istedi; rapor §G de eklemedi).

## 8. Kırıntılar

`.crumbs/tarihe-git-faz1-W2.jsonl` — gate (kabul-et-basla, 6 bulgu) + bu teslim kırıntısı.

---

# REVİZYON TURU — W3 (luna denetimi 4K+6O → REVIZYON; zarf TG1-W3-revizyon, 2026-09-14)

**Dal:** `agent/tarihe-git-faz1-W3` (taban main @ `2890817` = merge `agent/tarihe-git-faz1`;
merge'i root yaptı — koltuğun izin katmanı 3 kez `git merge`'ü reddetti, kanıtlı eskalasyon).
**Worker:** W3 (glmf) · **Zarf:** `.ss/tasks/TG1-W3-revizyon.md` · Denetim raporu VERİ olarak
okundu; her iddia kodla karşılaştırıldı, sonra düzeltildi.

## Bulgu → düzeltme → kanıt

| # | Luna bulgusu | Düzeltme | Kanıt |
|---|---|---|---|
| F1 [K] | TOHUMLAMA/VAKA_ACILDI dedup ref'siz fallback'le ayrı olayı yutuyordu | `js/gecmis.js` — `ref_id` DOLU ise baskılama YALNIZ `id\|olay-günü` eşleşmesiyle (`tohRefGun`/`vakaRefGun` kümeleri gün taşır); HAYVAN+GÜN fallback'ı yalnız `ref_id` BOŞ aynada | `tests/unit/gecmis-gun.test.js` "W3 adversarial (F1)": aynı id farklı gün → görünür; eşleşmeyen ref + aynı hayvan/gün (TOHUMLAMA ve VAKA_ACILDI) → görünür; ref BOŞ → fallback hâlâ baskılar. Canlı: 2026-09-06'da 34 VAKA_ACILDI aynasından tam 21'i (ref+gün eşleşenler) baskılanır — kalan 13 gerçek ayrı olay olarak görünür (fixture toplamına gömülü) |
| F2 [K] | stok dedup aile/tipi doğrulamadan her non-stok entry id'sini bastırıyordu | `js/gecmis.js` — baskılama yalnız `referans_tipi='tohumlama'` + `referans_id`→tohumlama.id + aynı gün. Yazıcı envanteri (migration'lar) ölçüldü: canlıda referanslı tek aile 'tohumlama'; tedavi seans stoku referanssız (`notlar='drug_admin:<id>'` deseni), 'vaccination' ailesi goal öncelik tablosunda baskılanmaz → kaynakIdGun kümesi tamamen kaldırıldı | "W3 adversarial (F2)": non-primary islem id'li stok → görünür; tipisiz/vaccination-tipili → görünür; aile+tipi+gün → baskılanır. Eski W2 stok testi yeni sözleşmeye çekildi (S1/S3'e `referans_tipi:'tohumlama'`) |
| F3 [K] | gün görünümü 7 metin yolu ham DB metni taşıyordu | `js/ui.js` `_gecmisEntryHtml`: hekim adı (hkName), dogum_tipi, tohumlama sonucu, tedavi etiketi (`_lbl`), gorev_tipi (class=escAttr + metin=esc), uygulama doz/birim/rota, bilinmeyen islem tipi — hepsi `esc`/`escAttr` | `tests/unit/gecmis-xss.test.js` YENİ (7 test): `<img src=x onerror=…>` girdili tüm alanlar çıktıda ham tag ÜRETMEZ; class attribute birebir escAttr çıkışı (ham tırnak yok) |
| F4 [K] | yeni kartlar DB kimliğini inline onclick'e gömüyordu | 5 yeni kart (aşı/kızgınlık/çıkış/sütten/protokol) `data-action="gm-det" data-det="${escAttr(id)}"` + merkezi delegasyon (`js/utils/events.js` data-action deseni; handler `js/utils/handlers.js` 'gm-det' → `openDet(el.dataset.det)`) | gecmis-xss.test.js: 5 kartta da `onclick=` YOK; `data-det` değeri birebir escAttr çıkışı (attribute kırılımı imkânsız; `'A' onmouseover=…` vektörü ölü alt-dizgiye iner) |
| F5 [O] | DÜN handler `dAgo(bugun(),1)` NaN üretiyordu | `js/utils/handlers.js:~119` → `dAgo(1)` (kaynak doğrulaması: `helpers.js:16` `dAgo(n)` yalnız sayı); spec oracle'ı da aynı doğru ifade | e2e "Dün hızlı girişi… (luna F5)": `_gecmisGun === dAgo(1)` — ürünün DOĞRU ifadesiyle, self-confirming değil |
| F6 [O] | "en zengin gün" e2e self-oracle'dı | statik fixture: **2026-09-06, 266 olay** (kaynak: islem 107 · stok 127 · gorev 11 · vaka 21). Ölçüm yöntemi: demo projesinden (vtzqjmazsvurxdeondmi) uygulamanın çektiği YÜZEYLERDEN (hayvan_durum_view, v_gorev_log_sync, stok_tuketim_view + düz tablolar) REST dökümü + düzeltilmiş pipeline koşumu (2026-09-14; artefaktlar `~/tmp/agents/w3-measure/`) | e2e fixture testi: banner "266 olay" + DOM kart sayısı 266 + temsil metinleri (Klinik Mastit, Klavil (vilsan), Enrolen, Gun 1 tedavisi). Bu toplam aynı zamanda F10'un canlı kanıtıdır: eski 100-satır cap ile o günün islem satırlarının tamamı gelemezdi; dedup da (21 ayna) toplamın içinde ölçülür |
| F7 [O] | TG1 spec veri-bağımlı skip taşıyordu | skip kaldırıldı; fixture günü ölçümle garantili. TG1'nin 5 testi de KOŞTU (koşum çıktısında ✓ 17-21) | Final koşum: 0 TG1 skip. Kalan tek skip `gece-tarih.spec.js:63` (önceden-var olan, küpeli-hayvan koşulu — TG1 dışı, W3 kapsamı değil) |
| F8 [O] | manifest handlers.js/vaka-toplu-ac.test.js kapsıyordu | goal write_manifest'e +5: `js/utils/handlers.js`, `js/api.js` (bkz. beyan A), `tests/unit/gecmis-gun.test.js` (W2'nin olaygunu-kapsamını taşıyan GERÇEK dosya adı), `tests/unit/gecmis-xss.test.js`, `tests/unit/vaka-toplu-ac.test.js`; "Değişecek dosyalar"a tek satır not — zarfla verilmiş lead yetkisiyle | goal dosyası diff'i (tek commit'te) |
| F9 [O] | goal `_detRenderGecmis` gün girişi istiyor, rapor kapsam dışı sayıyordu | hayvan kartına aynı şerit: `gecmisDetTariheGitAc` (kanonik `tekTarihTakvimAc`), `gecmisDetGunSec`, `_detGecmisGunBannerGuncelle` (ana banner deseni), 4 action (`gecmis-det-*`); gün hattına `{animalId}` scope'u (`_gmGunHayvanId` — defter scope kurallarıyla paralel; stok hayvansız → kapsam dışı). Yapısal büyümedi (goal stop-3 tetiklenmedi) | unit "W3 (F9)": kapsam + kapsamda-dedup + stok-dışı; e2e "hayvan kartı geçmişi…": 002 küpesi @2026-09-06 = **33 olay** (29 islem+4 vaka; ölçümlü sabit beklenti), şerit + banner + Kapat dönüşü canlıda |
| F10 [O] | islem_log pull cap=100 gün vaadini kırıyordu | `_fetchIslemLogTumu` (js/api.js): sayfalı tam çekim (1000'lük `range` sayfaları; üst sınır 50 sayfa). Ölçüm (demo, 2026-09-14): **4087 satır · 1641 ms · 2.57 MB**. REST tek istek 1000'de cap'lenir (ölçüldü: `limit=5000` → 1000 döndü) — naif limit artışı yetmezdi. Tarih-aralıklı çekim MİMARİYE AYKIRI: pull `idbClearAndPut` ile DEĞİŞTİRİR, aralıklı çekim diğer satırları silerdi (seçim gerekçesi). Yan etki (beyan): boot/geçmiş pull'ları ~+1.6 sn — pull arka planda, defter/klasik/çevrimdışı (skipPull) akışları değişmedi; e2e'ler yeşil | demo REST ölçüm çıktısı; e2e fixture 266 (tam pull olmadısı imkânsız); unit 892/892 |

## Ölçümler (dışsal, tekrarlanabilir)

- **demo islem_log:** 4087 satır; REST `limit=5000` → 1000 (server cap kanıtı); tam sayfalı
  çekim 1641 ms / 2.57 MB (script: `~/tmp/agents/w3-measure/demo-rest.mjs`).
- **F6 fixture gün seçimi:** en zengin gün 2026-05-09 (1484 olay — render cap 300'ü aşar,
  kart sayısı=toplam iddiasını kırar) → 2026-09-06 seçildi (266 ≤ 300, 4 kaynak ailesi).
- **Boot pull süresi (yan etki gözlemi, dbg timeline):** taze context'te `hayvanlar`
  store'u ~5.5 sn'de commit edilir (pull toplu `Promise.all` — F10 sayfalama zinciriyle).
  Uygulama ilk boyama bu sürede loader gösterir; davranış bozulmadı (tüm e2e yeşil).

## Beyanlar

- **A (gate bulgusu):** zarf md.10 `js/api.js`'i değiştiriyor ama md.8'ün manifest listesinde
  yoktu — md.8'in lead yetkisiyle api.js de manifest'e girdi (W2'nin işlediği sınıfın tekrarı
  önlandı). Gate kırıntısı: workspace `1dddb562…`, `type: gate`, KABUL + 2 beyan.
- **B (md.9 okuma):** "Yapısal olarak büyükse DURMA" → "DUR + ss-ask (goal stop-3)" okundu;
  uygulanmadı (büyükmedi).
- **Playwright koşumları (dürüst döküm):** geliştirme koşumu-1 19p/1f/1s (F9 testinde sekme
  tıkı eksi); koşum-2 19p/1f/1s (F9'da `waitForFunction` async-predicate yanlış-pozitif
  geçişi — vaat nesnesine truthy diyor; `expect.poll`'a geçildi); **FİNAL BELGELİ KOŞUM:**
  `20 passed / 1 skipped / 0 failed (2.0m)` — TG1'nin 5 testi dahil. Skip: gece-tarih:63
  (küpeli-hayvan veri koşulu; TG1 dışı). Komut (belgeli tek koşum):
  `docker run --rm -e PLAYWRIGHT_DEMO_MODE=1 -e PLAYWRIGHT_BASE_URL=http://127.0.0.1:8080/ -v "$PWD":/work -v /home/melik/egesut-erp1/node_modules:/home/melik/egesut-erp1/node_modules -w /work mcr.microsoft.com/playwright:v1.58.2-noble bash -c "ln -sfn /home/melik/egesut-erp1/node_modules /work/node_modules && npx playwright test tests/tarihe-git.spec.js tests/tarih-secici.spec.js tests/gece-tarih.spec.js tests/sutten-kes.spec.js tests/offline-kuyruk.spec.js tests/sablon.spec.js --workers=1 --retries=0 --reporter=list --output=/tmp/pw-out"`
  (worktree'de node_modules yok → konteyner içinde ana-checkout symlink'i; log:
  `~/tmp/agents/w3-measure/w3-playwright-final.log`).
- **Unit:** `NODE_PATH=/home/melik/egesut-erp1/node_modules node --test tests/unit/*.test.js`
  → **892/892/0** (W2 tabanı 882 + 10 yeni: 3 gecmis-gun adversarial + 7 gecmis-xss).
- **Damga:** `?v=20260914-02` × 23 (22 script + manifest); damga-pin testleri aynı değişiklikte.

## Dondurma notu

Sahip kararıyla ~12:5x'te donduruldu; WIP commit `WIP(TG1-W3): dondurma noktasi` atıldı
(teslim işareti yok). 13:01 devam — bu bölüm dondurma sonrası tamamlandı.

## Ertelenenler (W3)

- Boot pull'unun uzaması (~+1.6 sn) kabul edildi; paralel sayfalama optimizasyonu istenirse
  ayrı iş (ölçüm yukarıda).
- `gece-tarih.spec.js:63` veri-bağımlı skip TG1 dışı bırakıldı (F7 kapsamı tarihe-git spec).
- Luna bulguları DIŞINDA yeniden düzenleme yapılmadı (dar-tutum kuralı); W2'nin §7 maddeleri
  aynen durur (F9 hariç — o bu turda kapatıldı).

---

# LEAD TESLİM (kapanış) — 2026-09-14

**Dal:** `agent/tarihe-git-faz1` (base main @ `bdee91f`) · **Goal:** `G-20260914-TARIHE-GIT` → status **done**.

## Kabul zinciri
1. **W1** (glmf) goal dosyası `7773716` — lead KABUL (5 kapı maddesi + 13 kriter + 5 stop + gerekçeli sapmalar); merge `b1756b4`.
2. **W2** (glm) implementasyon `cee3297` — geçici kabul (unit 882/0, red-before 19→19, PW 18/2s/0f, damga `-01`); merge `5fff822`.
3. **Luna denetim** `1ea174c` — VERDICT: REVİZYON (4 KRİTİK + 6 ÖNEMLİ, VM adversarial ölçümlü); rapor dalda `101472b`.
4. **W3** (glm) revizyon `9503331` — F1-F10 giderildi; lead KABUL; merge `7c83663`.

## Lead'in kendi ölçümleri (W3 sonrası, bu dalda)
- Unit: `node --test tests/unit/*.test.js` → **tests 892 · pass 892 · fail 0** (lead koşumu).
- Damga: `grep -o "?v=[0-9-]*" index.html | sort | uniq -c` → **23× `20260914-02`** tek değer (+1 dinamik birleştirme noktası).
- TG1 diff'inde eklenen inline `onclick="openDet`: **0** (yeni kartlar `data-action="gm-det"` + `escAttr` delegasyonu; kalan 21 occurrence TG1 öncesi legacy koddur — bu goal'in diff'i değildir).
- DÜN handler: `js/utils/handlers.js:112` `dAgo(1)` (F5 düzeltmesi yerinde, gerekçe yorumuyla).
- Playwright: TEKRAR KOŞULMADI (sahip kuralı) — W3'ün belgeli final koşumu esas: **20 passed / 1 skipped / 0 failed (2.0m)**, TG1'nin 5 testi koştu.

## Açık kalemler (root)
- **Tabandan gelen 2 test_patterns.py kızılı** (stale `bcTarihTakvimAc` anchor'u ui-map Toplu vaka bölümünde + eski goal biçim hataları) — bdee91f'te de kızıl, TG1 dışı.
- **Legacy 21 inline `onclick="openDet`** js/ui.js'te — TG1 öncesi XSS yüzeyi (escAttr'siz kimlik geçen varsa ayrı güvenlik işi; bu goal kapsamı dışında bilinçli bırakıldı).
- **Boot/geçmiş pull ~+1.6 sn** (F10 tam sayfalı islem çekimi, arka planda; paralel sayfalama ayrı optimizasyon işi).
- **`gece-tarih.spec.js:63`** veri-bağımlı skip (küpeli-hayvan koşulu; TG1 dışı).
- **`.gitignore` +`.ss/`** (W3 hijyen commit'i `a019a56`, zarf yazma listesi dışında — ss rol ağı çalışma yüzeyini lokal tutar; root onayı için beyan).
- **K1 interakasyonu:** bu dal W3 tabanı üzerinden K1 commit'lerini (ui-map tarih seçici bölümü, R1 goal gövde düzeltmesi, reports/k1 raporu) taşır — main'de zaten var, hasatta no-op.
- **`bildirim_log` gün görünümü, ay-ızgara, `?gun=` deep-link, hayvan-kartı kategori çipleri** — goal kapsam dışı/ertelenmiş (Faz 2 adayları).

## Süreç kaydı
- ss-dispatch taban kapısı tools-bank misfire (cross-repo `_repo`) → dağıtım `superset workspaces create` primitive'iyle (rol sözleşmesinin tanımı; kırıntıda assumption).
- Worker rolünde merge izin katmanınca yasak (W3'te 2× RED) → merge root tarafından `2890817`; ders: bundan sonra worker dalları lead dalından açılır.
- Sahip dondurması ~12:5x–13:01 (WIP `2fc0653` teslim sayılmadan atlandı).
- Kırıntılar: `/home/melik/egesut-erp1/.crumbs/tarihe-git-faz1.jsonl` (lead), `tarihe-git-faz1-W1/W2/W3.jsonl`, `tarihe-git-faz1-R1` (luna denetim kırıntıları kendi worktree'sinde).
- Teslim ölçüm çıktıları workspace dışı: `~/tmp/agents/w2-red-before-gun.log`, `w2-green-gun2.log`, `~/tmp/agents/w3-measure/*` (demo-rest.mjs, fixture artefaktları, `w3-playwright-final.log`).
