# Kod Temizlik Turu 2 — idle/kod-temizlik-2 (B9 2. dilim + B8 + RPC_TABLES telafisi + agent-telemetry)

**Tarih:** 2026-09-02 · **Worktree:** `/home/melik/egesut-wt/kod-temizlik-2` · **Branch:** `idle/kod-temizlik-2` (taban: main `a71b7a0`)
**Kapsam:** 6 dosya, +73/−53 satır · Supabase'e YAZMA yok (yalnız İş 5 için read-only `pg_get_functiondef`) · push yok · tek commit
**Sonuç:** `npm run test:unit` **362/362 yeşil** (2 koşu) · `node --check` 5 js OK · self-shadow taraması TEMİZ

---

## 0 · GitNexus impact-before-edit (8 sembol, upstream, repo: egesut-erp1)

| Sembol | Risk | Doğrudan çağıran (d=1) | Etkilenen process |
|---|---|---|---|
| renderTask | **CRITICAL** (69 impacted) | `_rt`, `loadTasks`, `_detGorevHtml` (3) | 17 |
| _detOzetHtml | **HIGH** (19) | `openDet` | 4 |
| _detUremeHtml | **HIGH** (19) | `openDet` | 4 |
| _detSaglikRender | **HIGH** (19) | `openDet` | 4 |
| _detGorevHtml | **HIGH** (19) | `openDet` | 4 |
| _uremeKizginlik | **CRITICAL** (37) | 1 doğrudan (üreme sekme render'ı) | 7 |
| renderPadokDolulukBar | **CRITICAL** (11) | 2 doğrudan | 8 |
| animalGrupDegisti | **CRITICAL** (42) | 3 doğrudan | 9 |

İlave: İş 5'te dokunulan `_tanimVarsayilan` → **LOW** (0 impacted).
Risk sınıfı 1. tur §5 ile birebir aynı; HIGH/CRITICAL'e rağmen görev zarfında mekanik dönüşüm
talimatlıydı — tüm değişiklikler esc/dataset düzeyinde kaldı, davranış/akış değişmedi.

## 1 · B9 ikinci dilim — 17 template satırında ~22 dönüşüm

Desen: 1. tur kanıtı (`data-x="${escAttr(v)}"` + `this.dataset.x`, onclick string'ine esc/escAttr YOK).

| Sembol | Noktalar (yeni satır) | Dönüşüm |
|---|---|---|
| renderTask | ui.js:746 butonu | `data-padok` + `{padok:this.dataset.padok}` (ui.js:5034 örneğiyle aynı desen; `'' → null` eşlemesi togglePendingDone'daki `data.padok \|\| null` ile korunur) |
| _detOzetHtml | 1879, 1905 | `esc(anneKupe)`; `esc(i.v)` (14 alanlı infoFields) |
| _detUremeHtml | 1936/1939/1941/1944/1946 (5 buton) | `data-hid` + `this.dataset.hid`; dogumYaptiAc'a ek `data-sperma` + `this.dataset.sperma` |
| _detSaglikRender | 2098, 2103/2104 | `esc(dis?.name\|\|'?')`; **1. turda ampirik KIRIK olan escAttr-inline küpe butonları** → `data-kupe` + `this.dataset.kupe` (öncelikli madde, §0 bulgusuyla kapanır) |
| _detGorevHtml | 2180 | `data-kupe` + `openMWithHayvan('m-task-add','ta-hid',this.dataset.kupe)` |
| _uremeKizginlik | 2738/2740 | `data-kupe` + `openInsemSafe(this.dataset.kupe)` / `kizginlikTedaviAc('${k.id}',this.dataset.kupe)` |
| renderPadokDolulukBar | 7454/7461 (2 chip dalı) | onclick'teki `esc(p.ad)` (YASAK desen) → `data-ad` + `this.dataset.ad`; `title` → `escAttr(p.ad)`; `esc(padokAdi)` |
| animalGrupDegisti | app.js:331 | option metinleri `esc(p.ad)` / `esc(ad)` (value'daki uuid §6 gereği dokunulmadı) |

Dokunulmayanlar (1. tur §6 listesi aynen geçerli): statik config, üretilmiş/uuid onclick değerleri
(openDet('${id}'), abortKaydet('${a.id}',...), kizginlikSil('${k.id}') vb.), textContent bağlamları.
Ampirik kırık olmayan kalan escAttr-inline kalıntıları (ui.js:220/253/5651/5652) yalnız uuid taşır —
tehdit modeli dışı, bu turun zarfı dışında bilinçli bırakıldı.

## 2 · B8 tam fix — 7 fonksiyona try/catch (bilinçli davranış değişikliği)

`_dcAddGroup`, `_dcAddClass`, `_dcAddIngredient`, `_dcEditIngredient`, `_dcDeleteIngredient`,
`_kategoriSave`, `_kategoriDelete`: `await rpcOptimistic(...)` artık try içinde; catch **sessiz return**
(rpcOptimistic hata yolunda kendi toast'unu bastığı için çift-toast yapılmadı). Başarı kolu
(toast + loadTanimlarPanel) try içinde → hata durumunda "eklendi" toast'u ve bayat panel render'i çalışmaz.

Zarf notu: aynı ailenin `_dcEditInline` / `_dcDeleteGroup` / `_dcDeleteClass` üçlüsünde de
try/catch'siz `await rpcOptimistic` döngüsü var; görev listesi 7 fonksiyonu saydığı için bu turda
dokunulmadı (döngü-ortası catch'i kalan hedefleri atlar — ayrıca karar gerektirir). Sonraki tura.

## 3 · helpers.js yorum düzeltmesi (yalnız yorum — kod yok)

`js/utils/helpers.js:90-94`: escAttr'in "JS string literal context" tarifleri silindi; yorum artık
§0 ampirik bulgusunu (entity-decode → ' string'i kırar) ve `data-x="${escAttr(v)}" + this.dataset.x`
desenini işaret ediyor (AGENTS.md modal-router kuralına referansla).

## 4 · index.html agent-telemetry tag — kök neden + kaldırma

- **Ekleme:** `57bb740` "[gwen] feat: Agent telemetry pipeline" (2026-03-31) — `agent-telemetry/`
  dizisi (tracker.js + WS server + analyzer) ve index.html tag'i birlikte eklendi; Gwen/Qwen
  ArGe deneyi (browser event → local WebSocket → agent izleme).
- **Silinme:** `a7f42e4` "chore: repoya girmeyen dosyalar temizlendi (gwen-mcp-servers, agent-telemetry,
  araçlar)" — diziyi sildi, **index.html tag'ini unuttu** → o günden beri her ortamda 404.
- **Karar:** kök neden "sonra eklenecek dosya" DEĞİL, temizlik kalıntısı → tag + yorum satırı kaldırıldı.
- Test dosyalarındaki `IGNORED_LOCATIONS` 'agent-telemetry' girdisi artık gereksiz; E2E dosyalarına
  bu turda dokunulmadı (görev talimatı) — bir sonraki E2E turunda temizlenir.

## 5 · api.js RPC_TABLES telafisi (ui-altyapi bulgusu 2)

**Canlı doğrulama (read-only, prod token SELECT düzeyi):** `pg_get_functiondef(oid 109988)` →
`seed_defaults(p_tip text)` **üç** tabloya yazıyor: `diseases` / `drugs` / `stok_kategorileri`.
**`drug_classes` YAZMAZ** — ui-altyapi raporundaki "drug_classes/diseases" varsayımı kısmen yanlış;
drug_classes'ı `drug_class_varsayilan_yukle` yazar ve o zaten RPC_TABLES'ta mapli.
(İmza doğrulama: önce `'seed_defaults(text)'::regproc` 42883 verdi → `pg_proc` ile gerçek imza
`p_tip text` bulundu, oid ile gövde çekildi.)

**Karar: RPC_TABLES kaydı yolu** (çağrı-yeri telafisi yerine):
- `seed_defaults: ['diseases','drugs','stok_kategorileri']` eklendi. Gerekçe: (a) p_tip'e göre koşullu
  pull gerektirir; statik üçlü map over-pull üretir ama üç tablo da küçük — maliyet ihmal edilebilir;
  (b) mevcut dolaylı telafi (loadTanimlarPanel → aktif sekme render'ının kendi pullTables'ı) **kazara**
  çalışıyordu ve tip='drugs' için hiç telafi yoktu (UI'da bugün 'drugs' butonu yok, olsa boşluktaydı);
  (c) map kaydı, api.test.js:294'teki "rpcOptimistic ile çağrılan HER RPC mapte" disiplin kilitine girer.
- `tests/unit/api.test.js`: `seed_defaults` EXEMPT setinden çıkarıldı; kategori üçlüsünün muafiyet
  yorumu düzeltildi (telafi `js/ui.js` `_renderKategoriler`'de, bayat `forms.js:1391` referansı değil).

## 6 · Doğrulama zinciri

1. `npm run test:unit` → **362/362 yeşil** (2. koşu da yeşil).
2. `node --check` → js/ui.js, js/app.js, js/utils/helpers.js, js/api.js, tests/unit/api.test.js — hepsi OK.
3. Self-shadow taraması (`const X = X(` backreference) → TEMİZ; `data-x ↔ this.dataset.x`
   birebir eşleşme taraması → uyumsuzluk YOK (TDZ dersi tekrar yaşanmadı).
4. `gitnexus detect_changes({scope:"all", worktree})` → 6 dosya; genel risk etiketi "critical" —
   bu etiket openDet fan-out'u sembollerine (animalGrupDegisti vb.) dayanıyor (beklenen; yukarıdaki
   impact tablosuyla tutarlı). Sembol listesindeki pullTables/toggleSub/openIslemDetay/_sablonDrugName/
   sablon*/btEtiket*/setupAutocomplete isimleri **indeks satır-kayma gürültüsü** (1. tur §7'de
   kanıtlanan durum): `git diff -U0` hunk başlıkları gerçek dokunulan fonksiyonlarla birebir —
   RPC_TABLES, animalGrupDegisti, renderTask, _detOzetHtml×2, _detUremeHtml×5, _detSaglikRender×2,
   _detGorevHtml, _uremeKizginlik×2, _dc*×5, _kategori*×2, renderPadokDolulukBar×2, esc yorumu,
   index.html, api.test.js. Zarf dışı zero-touch.

## 7 · Sonraki tura notları

1. `_dcEditInline` / `_dcDeleteGroup` / `_dcDeleteClass` — rpcOptimistic döngülerine try/catch
   (döngü-ortası hata politikası ayrıca kararlı).
2. tests/smoke.spec.js + tests/e2e.spec.js `IGNORED_LOCATIONS` → 'agent-telemetry' çıkarımı.
3. ui.js:220/253/5651/5652 escAttr-inline kalıntıları uuid-only (§6 sınıfı) — istenirse dataset'e alınır.
