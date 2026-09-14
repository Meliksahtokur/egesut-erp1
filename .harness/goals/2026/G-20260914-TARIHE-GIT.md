---
id: G-20260914-TARIHE-GIT
status: done
owner: root
flow: ss_org
created: 2026-09-14
base_sha: bdee91f
branch: agent/tarihe-git-faz1
worktree: /home/melik/.superset/worktrees/1dddb562-abe3-495c-970e-872567945510/agent/tarihe-git-faz1
report: .harness/reports/2026-09-14-tarihe-git-f1.md
write_manifest:
  - js/gecmis.js
  - js/ui.js
  - index.html
  - .harness/references/ui-map.md
  - tests/unit/gecmis-pipeline.test.js
  - tests/unit/gecmis-olaygunu.test.js
  - tests/tarihe-git.spec.js
  - .harness/goals/2026/G-20260914-TARIHE-GIT.md
  - .harness/reports/2026-09-14-tarihe-git-f1.md
  - js/utils/handlers.js
  - js/api.js
  - tests/unit/gecmis-gun.test.js
  - tests/unit/gecmis-xss.test.js
  - tests/unit/vaka-toplu-ac.test.js
pattern_refs:
  - MODAL-ROUTER-01
  - OFFLINE-SYNC-01
  - TESTING-01
pattern_exceptions: []
docs_authority:
  tracked_paths:
    write:
      - .harness/goals/2026/G-20260914-TARIHE-GIT.md
      - .harness/reports/2026-09-14-tarihe-git-f1.md
      - .harness/references/ui-map.md
review_lane: codex_luna_optional
implement_lane: glmf_workers
---

# G-20260914-TARIHE-GIT — "Tarihe git: o gün ne oldu?" (Faz 1, istemci tarafı)

- **Status:** DONE (2026-09-14; kabul zinciri tamam: W1 goal → W2 implementasyon → luna
  denetim/REVİZYON → W3 revizyon → lead kabul; frontmatter `status: done` ile tutarlı;
  teslim raporu: `.harness/reports/2026-09-14-tarihe-git-f1.md`)
- **Task envelope:** `/home/melik/egesut-erp1/.ss/tasks/L3-tarihe-git-faz1.md` (scopes
  this goal) · hazırlık zarfı: `.ss/tasks/TG1-W1-goal.md` (W1, bu dosyanın yazarı)
- **Temel araştırma:** `reports/2026-09-13-tarihe-git-altyapi.md` (W2; §D.c seçenek (c),
  §E riskler, §F UI, §G taslak). Aşağıdaki bölümler §G'yi başlangıç alır; sapmalar
  gerekçesiyle beyan edilir (bkz. "§G'den sapmalar").
- **Kapsam:** Geçmiş yüzeyinde tekil gün görünümü: kullanıcı tarih seçer, seçilen günün
  tüm olayları (doğum, tohumlama+sonuç, gebelik muayenesi, vaka/tedavi seansı, aşı,
  kızgınlık, hızlı uygulama, stok hareketi, satış/ölüm/kesim çıkışı, sütten kesme,
  görev tamamlama) tek listede. Yalnız istemci; migration/RPC yok.

## Kısıtlar (lead zarfından)

- Dal `agent/tarihe-git-faz1` (base `main` @ `bdee91f`); lead worker dallarını kendi
  dalına merge eder. Main'e merge/push root'tadır — implementer merge/push YAPMAZ.
- Yeni tarih bileşeni YAZILMAZ; kanonik `tekTarihTakvimAc` (`js/ui.js:6856`) /
  `tarihAlaniBagla` (`js/ui.js:7151`) kullanılır.
- L2'nin `js/degisiklikler/*` dosyaları main'de değil — dokunulmaz, referans verilmez.
- `supabase/` dizini dokunulmaz; DB/migration/RPC yazımı yok.
- Commit mesajlarında `TG1` işareti; teslim `.harness/reports/2026-09-14-tarihe-git-f1.md`
  (kabul kriteri başına kanıt, review notu, ertelenenler). Sonra dur; entegrasyon root'ta.
- `?v=` önbellek damgası: tüm yerel js/css için TEK yeni değer `20260914-01`
  (ya da sonrası), tek commit'te.

## Lead kapıları — zorunlu maddeler (biri eksikse teslim RED)

Bu beş madde lead denetiminin kapı bulgularıdır; goal'dan çıkarılamaz.

### 1. Dedup — tablo bazlı öncelik tablosu (ölçülebilir kabul kriteri 5'e bağlı)

Gün görünümü 5 yeni kaynakla neredeyse her olayı iki kez listeler: aşı
`vaccination_log` ↔ `islem_log`(`ASI_KAYDI`), kızgınlık `kizginlik_log` ↔
`islem_log`(`KIZGINLIK_KAYDI`), tohumlama/tedavi stok düşüşü ↔ `stok_hareket`.
Beyan edilen öncelik (zengin olay kaydı birincil, birleşik günlük/stok yansıması
ikincil):

| Olay ailesi | Birincil (görünür) | Bastırılan ikincil | Eşleştirme |
|---|---|---|---|
| Aşı | `vaccination_log` | `islem_log` `ASI_KAYDI` | hayvan + olay günü; mümkünse referans id |
| Kızgınlık | `kizginlik_log` | `islem_log` `KIZGINLIK_KAYDI` | hayvan + olay günü |
| Tedavi seansı / uygulama | `treatment_days` + seans `islem_log` tipleri | `stok_hareket` (referans dolu ilaç çıkışı) | referans id; yoksa hayvan + olay günü |
| Tohumlama + stok düşüşü | `tohumlama` (+ tohumlama `islem_log` tipi) | `stok_hareket` (referans dolu tohum/ilaç çıkışı) | referans id; yoksa hayvan + olay günü |
| Diğer stok hareketi | `stok_hareket` (`referans_tipi` boş — canlıda %97, rapor §E.3) | — | eşleşme yok; "Stok hareketi (genel)" olarak hayvansız görünür |

Kural: bastırılan ikincil kayıt, birinciliyle aynı olaya çözülüyorsa entry üretmez.
`referans_tipi` dolu ama birincili bulunamayan `stok_hareket` bastırılmaz, genel kalem
olarak kalır. Öncelik tablosu değişirse goal revize edilir (stop koşulu 1).

### 2. todayKey sözleşmesi

`todayKey` = **gerçek bugünün** anahtarı (`_gmTodayKey()`, `js/gecmis.js:255-258`);
DÜN bugün'den türetilir. "Tarihe git" tek-gün görünümü **SEÇİLEN günü todayKey'e ASLA
geçirmez**; seçili günün vurgusu ayrı mekanizmadır (gün başlığı "X günü (n olay)" +
seçim şeridi durumu, rapor §F). Böylece gün görünümü açıkken BUGÜN/DÜN etiketleri
gerçek takvime göre kalır. Bilinen kusur bu sözleşmeyle bağlantılı: `_gmGroupLabel`
(`js/gecmis.js:259-265`) DÜNü parametre yerine `new Date()`'ten türetir;
`tests/unit/gecmis-pipeline.test.js:283` (DÜN bölümü :299-300) bu yüzden gün sınırında
kırmızıdır (14.09.2026 itibarıyla kırmızı — ölçüldü). Onarım kök nedeni bulup
test mi kod mu kararını gerekçelendirir; todayKey sözleşmesi bozulmadan.

### 3. Pull eki `stok_hareket` DAHİL

`loadGecmis` pull listesi (`js/ui.js:4047`) ve `_gecmisCollectSources`
(`js/ui.js:3872`) genişletilirken `stok_hareket` de listeye girer — §G'nin dosya
listesi bunu atlamıştı. Gerekçe: gün görünümü realtime'ı kaçırdıysa bayat/eksik stok
olayı gösterir; `stok_hareket` gün görünümünün birinci sınıf kaynağıdır (yukarıdaki
öncelik tablosu). `vaccination_log`, `kizginlik_log` da pull listesine girer
(`hayvanlar`, `protokol_instance` TABLES pull kapsamındadır, `js/api.js:30-33`).

### 4. `sourceKey` yazılır; tip-geri-çözümü yok

Her gün-görünümü entry'sine `sourceKey` yazılır. `type` ↔ `sourceKey` birebir DEĞİLDİR
(`cases`→`hastalik`, `islem_log`→`islem` takma adları, `js/gecmis.js:32-44`) — kaynak
eşlemesi tip alanından geri çözülmez; `olayGunu(sourceKey, row)` ve dedup, tablo
anahtarlarıyla çalışır. Yeni kaynakların entry'lerinde `sourceKey` tablo adıdır
(`vaccination_log`, `stok_hareket`, `kizginlik_log`, `hayvanlar`, `protokol_instance`).

### 5. TR-günü kuralı

`olayGunu` iki ayrı doğruyu izler: `date` kolonlarında kolon değeri aynen (TZ'siz,
güvenli); `timestamptz` mutlak-anlarında `Europe/Istanbul` günü (`_GM_IST_GUN` Intl
biçimlendirici, `js/gecmis.js:23`). `_GM_TZ_ESNEK` esnekliği (`js/gecmis.js:90` —
Z/offset damgalı yazım → Intl, damgasız yazım aynen) `olayGunu` kuralına da taşınır:
yalnız TZ damgası taşıyan değerler TR gününe çevrilir. Arka plan: CURRENT_DATE
sapması TR 00:00–03:00 penceresi, yön ÖNCEKİ gün (rapor §C).

## Değişecek dosyalar

- `js/gecmis.js` — 5 eksik kaynak (`vaccination_log`, `kizginlik_log`, `stok_hareket`,
  `hayvanlar`-çıkış, `protokol_instance`[ops]); AYRI olay-günü kuralı `olayGunu(sourceKey, row)`
  (mevcut `dateKey`/`_gmDateKey` davranışı DEĞİŞMEZ); gün görünümü politika ayrımı
  (`_gmPolicyRow` defterde aynen kalır; gün görünümünde cases açık-vaka açılışı +
  bekleyen tohumlama + genişletilmiş `islem_log` tipleri — rapor §D.c.3); dedup öncelik
  tablosunun uygulaması; `_gmGroupHtml` DÜN time-bomb onarımı (kod/test kararı
  gerekçeli, todayKey sözleşmesi bozulmadan).
- `js/ui.js` — `loadGecmis`'e "Tarihe git" girişi (`tekTarihTakvimAc`), seçili-gün
  filtre state'i, gün başlığı; `_detRenderGecmis`'e aynı giriş; `_gecmisCollectSources`
  (`js/ui.js:3872`) ve `loadGecmis` pullTables listesine (`js/ui.js:4047`)
  `vaccination_log` + `kizginlik_log` + `stok_hareket` eki.
- `index.html` — `#pg-gecmis` üst şeridi `[Bugün] [Dün] [📅 Tarihe git]` + gün başlığı;
  `?v=` damgası tüm yerel js/css için TEK değer `20260914-01` (ya da sonrası).
- `.harness/references/ui-map.md` — Geçmiş sekmesi bölümüne "tarih filtresi / gün
  görünümü" maddesi (kanıtlanan desen; rapor §F).
- `tests/unit/gecmis-pipeline.test.js` — time-bomb onarımının test tarafı (gerekçeli).
- `tests/unit/gecmis-olaygunu.test.js` — YENİ: `olayGunu` saf testleri (red-before),
  dedup önceliği, sourceKey, todayKey sözleşmesi.
- `tests/tarihe-git.spec.js` — YENİ Playwright: takvimden gün seç → beklenen olay listesi.
- (W3 revizyon, lead yetkisiyle — zarf TG1-W3 md.8) manifest'e `js/utils/handlers.js`
  (W2'nin 4 action'ı), `js/api.js` (F10 islem_log pull cap), `tests/unit/gecmis-gun.test.js`
  (W2'nin olaygunu kapsamını taşıyan gerçek dosya adı), `tests/unit/gecmis-xss.test.js`
  (W3 adversarial) ve `tests/unit/vaka-toplu-ac.test.js` (damga-pin) eklendi.

(Not: `hayvanlar`/`stok_hareket` TABLES sabitinde zaten var — `js/api.js:30-33`
dokunulmaz. Yeni test dosya adları öneridir; eşdeğer kapsamda farklı ad, raporda
beyan edilmek koşuluyla kabul edilir.)

## Kabul kriterleri (ölçülebilir)

1. **Gün seçimi:** Demo verisinde 2025-11-17 gibi bir gün seçildiğinde o güne ait
   tohumlama, aşı, doğum, vaka seansı ve stok hareketi kayıtları tek listede görünür.
2. **Olay günü doğruluğu:** Olayı geri tarihli girilmiş bir tohumlama kaydı
   (`created_at != tarih`, canlıda 252/282 — rapor §D.c) OLAY gününün grubunda görünür,
   kayıt anının gününde değil.
3. **Çevrimdışı:** `skipPull` ile gün görünümü IndexedDB'den dolu çalışır.
4. **TZ:** TR saatiyle 00:00–03:00 arası yazılmış `islem_log` kaydı, TR gününe göre
   doğru grupta görünür (`olayGunu` TR-günü kuralı; sapma penceresi/yönü rapor §C).
5. **Dedup:** Aynı olay tek entry: öncelik tablosuna göre — bir aşı gününde o hayvan
   için tek aşı kartı (`vaccination_log`), `islem_log ASI_KAYDI` kopyası görünmez;
   kızgınlık ve stok düşüşü için aynı. Unit: çift-kaynak fixture → tek entry + doğru
   birincil kaynak seçimi. Toplam entry sayısı = beyan edilen önceliğe göre olay sayısı.
6. **Mevcut davranış korunur:** Defter/Klasik mod, arama, CSV dışa aktarım filtreyle
   birlikte çalışır; defter görünümü `dateKey`/`eventAt` davranışı DEĞİŞMEZ (mevcut
   testler yeşil).
7. **Playwright:** Takvimden gün seç → beklenen olay listesi (yeni spec).
8. **Unit suite:** `NODE_PATH=/home/melik/egesut-erp1/node_modules node --test
   tests/unit/*.test.js` → **0 fail** (time-bomb onarımı dahil). Yeni saf fonksiyonlar
   için red-before kanıtı.
9. **todayKey sözleşmesi:** Gün görünümü açıkken BUGÜN/DÜN etiketleri gerçek bugüne
   göre kalır; seçilen gün todayKey'e geçirilmez (unit test ile kanıtlanır).
10. **sourceKey:** Yeni kaynak entry'lerinde `sourceKey` tablo adıdır; dedup/`olayGunu`
    tip-geri-çözümü yapmaz (unit test ile kanıtlanır).
11. **`?v=` damgası:** index.html'deki tüm yerel js/css referansları TEK yeni değer
    (`20260914-01` ya da sonrası); karışık değer kalmaz.
12. **Test koşumu belgelenir:** Playwright (docker `mcr.microsoft.com/playwright:v1.58.2-noble`,
    demo-mode) **bir kez** koşulur; komut + sonuç satırı rapora yazılır. Denetçiler
    aynı tarayıcı testini TEKRAR KOŞMAZ; belgelenmiş çıktıyı ve kapsamı kontrol eder
    (sahip kuralı).
13. **ui-map:** `.harness/references/ui-map.md` Geçmiş sekmesi bölümü günceldir.

## Test disiplini

- Unit: `NODE_PATH=/home/melik/egesut-erp1/node_modules node --test tests/unit/*.test.js` → 0 fail.
- Playwright: docker `mcr.microsoft.com/playwright:v1.58.2-noble`, demo-mode, **bir kez**; çıktı raporda.
- Red-before: yeni saf fonksiyon testleri (`olayGunu`, dedup, sourceKey) önce kırmızı kanıtla.

## Kapsam dışı

- `gun_olaylari` RPC / migration (yalnız derin-geçmiş ihtiyacında ayrı goal — Faz 2).
- `hayvan_timeline_view` DROP/fix (ayrı temizlik maddesi).
- CURRENT_DATE kullanan 32 RPC'nin TZ düzeltmesi (teknik borç kaydı).
- `bildirim_log` gün görünümü (opsiyonel kalem; lead kararı bekler).
- Ay-ızgarası görünümü (Faz 2+).
- DB/migration/RPC yazımı; `supabase/`; `js/degisiklikler/*`; main'e merge/push.

## Stop koşulları

1. **Dedup eşleştirme anahtarı kurulamıyorsa** (islem_log/stok_hareket referans
   bağlantısı canlı/demo veride doğrulanamıyor ve yalnız hayvan+gün kalıyorsa; bu da
   yanlış birleştirme üretiyorsa) → dur + lead'e soru; öncelik tablosu goal revizyonuyla değişir.
2. **`protokol_instance` veri şekli** beklenmedikse → kaynak opsiyonel düşürülür,
   raporda beyan edilir; diğer 4 kaynak zorunludur (lead bilgilendirilir).
3. **todayKey onarımı** `loadGecmis`/`gecmis.js` dışındaki bugün-anahtarı üretim
   yerlerini değiştirmeyi gerektiriyorsa → dur + lead kararı.
4. **Kanonik seçici yetersizse** (`tekTarihTakvimAc` gün-görünümü ihtiyacını
   karşılamıyorsa) → yeni bileşen YAZILMAZ; dur + lead'e soru.
5. **`stok_hareket` pull'u** kabul kriteri 3'ü (çevrimdışı doluluk) veya pull
   süresini kabul edilemez biçimde bozarsa → dur + lead'e kanıtla.

## §G'den sapmalar (gerekçeli beyan)

1. **Kimlik/tarih:** Taslak başlığı `G-20260913-TARIHE-GIT` → bu goal `G-20260914-TARIHE-GIT`
   (lead zarfı dosya adını buyurur; oluşturulma günü 14.09).
2. **Pull ekine `stok_hareket`:** §G'nin dosya listesinde yoktu — lead kapısı 3 ile eklendi.
3. **Dedup beyanı somutlaştı:** §G "goal'da beyan edilir" diyordu; yukarıda tablo bazlı
   öncelik tablosu + eşleştirme kuralları olarak yazıldı (lead kapısı 1).
4. **todayKey sözleşmesi ve sourceKey şartı eklendi:** §G'de yoktu — lead kapıları 2 ve 4.
5. **TR-gün kuralına `_GM_TZ_ESNEK` taşıyıcısı eklendi:** §G iki kuralı tanımlıyordu;
   lead kapısı 5 esneklik kuralını `olayGunu`'na da bağlar.
6. **Dosya listesi genişletildi:** §G + L3 birleşimi — `tests/unit/gecmis-pipeline.test.js`
   (time-bomb, L3 madde 4), `?v=` damga (L3 madde 5, index.html zaten vardı ama değer
   şartı yoktu), yeni unit/Playwright test dosyaları (L3 test disiplini), ui-map
   güncelleme maddesi ölçülebilir kabul kriteri 13'e bağlandı.
7. **Dil:** Bu goal Türkçe — emsal `G-20260913-TARIH-SECICI-R1` Türkçedir ve W2 taslağı
   Türkçe yazılmıştır; contract'ın "internal artifacts in English" varsayılanından
   emsal-uyumu sapmasıdır.
