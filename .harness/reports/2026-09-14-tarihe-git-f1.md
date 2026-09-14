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
