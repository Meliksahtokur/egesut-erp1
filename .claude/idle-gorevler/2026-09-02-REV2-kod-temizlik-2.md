# REV-2 — idle/kod-temizlik-2: B9 ikinci dilim + B8 fix + telafi boşluğu + agent-telemetry tag

**Tarih:** 2026-09-02 · **Taban:** main `a71b7a0` · **Branch:** `idle/kod-temizlik-2` (worktree: `/home/melik/egesut-wt/kod-temizlik-2`)
**Kaynaklar:** kod-temizlik raporu §5/§8 (`.claude/idle-reports/2026-09-02-kod-temizlik.md`),
ui-altyapi raporu bulgu 2 (2026-09-01-ui-altyapi.md), e2e-gercek raporu O4 (2026-09-02-e2e-gercek.md)

## ZORUNLU GUARDRAIL

- Push YOK · tek commit · Supabase çağrısı YOK (tamamen local) · rapor: `.claude/idle-reports/2026-09-02-kod-temizlik-2.md`
- **GitNexus impact-before-edit ZORUNLU** — ilk dilimin 8 sembolü HIGH/CRITICAL (neden: openDet fan-out'u).
  Her sembol için `impact({target, direction:"upstream"})` çalıştır, sonucu rapora yaz.
- Her dönüşümde AGENTS.md modal-router kuralı: **attribute onclick + dataset** (DOM property onclick YASAK).
  onclick string içine `esc()` YASAK (helpers.js:37-41); desen: `dataset.x` + attribute onclick'te `this.dataset.x`.
- Toplu sed YASAK — her nokta tek tek; sonrası `const X = X()` self-shadow + bare-identifier taraması
  (TDZ dersi: 2026-08-31 tedavi modalı crash'i).
- Doğrulama zinciri: `npm run test:unit` (362+ yeşil zorunlu) · `node --check` her dokunulan js ·
  `gitnexus detect_changes` (repo: egesut-erp1).

## İş 1 — B9 ikinci dilim (~15 nokta, kod-temizlik raporu §5 tablosu)

Kod-temizlik 1. tur bu 8 sembole HIGH/CRITICAL impact nedeniyle DOKUNMADI. Şimdi mekanik dönüşüm yap
(esc/dataset), davranış değiştirme:

| Sembol | Noktalar |
|---|---|
| renderTask (CRITICAL) | ui.js:712 togglePendingDone `{padok:'${t.padok_hedef}'}` |
| _detOzetHtml (HIGH) | infoFields `${i.v}` (14 kullanıcı-metni alanı), `${anneKupe}` |
| _detUremeHtml (HIGH) | ui.js:1808-1819 dogumYaptiAc/openInsemSafe/openTekrarAsim (hid/sperma ham) |
| _detSaglikRender (HIGH) | `${dis?.name}`; **1976/1977 escAttr-inline küpe — 1. turda ampirik KIRIK bulundu, öncelik burası** |
| _detGorevHtml (HIGH) | ui.js:2053 openMWithHayvan('${kupe}') |
| _uremeKizgınlik (CRITICAL) | ui.js:2611/2613 openInsemSafe/kizginlikTedaviAc (küpe ham) |
| renderPadokDolulukBar (CRITICAL) | ui.js:7304/7311 setPadokFiltreBt(p.ad) + title/padokAdi ham |
| animalGrupDegisti (CRITICAL) | app.js:337 option `${p.ad}` ham |

Not: 1. turdaki 16 dataset dönüşümü `data-x ↔ this.dataset.x` birebir eşleşti — aynı deseni izle.
§6'daki "bilinçli bırakıldı" listesi (statik config, üretilmiş/uuid, textContent) bu tura da DOKUNULMAZ.

## İş 2 — B8 tam fix (davranış değişikliği, bilinçli)

`_dc*`/`_kategori*` ailesi (ui.js — 1. tur §2'de sayıldı: _dcAddGroup/_dcAddClass/_dcAddIngredient/
_dcEditIngredient/_dcDeleteIngredient + _kategoriSave/_kategoriDelete) rpcOptimistic'i try/catch'siz
bekliyor → rpcOptimistic toast basıp re-throw ediyor → **unhandled rejection**. Her çağrıyı try/catch'e al
(catch: sessiz return — toast zaten rpcOptimistic'te geliyor; çift-toast yapma).

## İş 3 — helpers.js:90-91 yorum düzeltmesi

Yorum escAttr-inline kullanımı "JS string literal context için" diye tarif ediyor; §0 bulgusuyla çelişiyor
(ampirik olarak kırık). Yorum dataset desenini işaret etmeli. SADECE yorum — kod yok.

## İş 4 — index.html agent-telemetry tag (e2e-gercek O4)

`index.html:2153` civarı `<script src="agent-telemetry/tracker.js">` — dosya repoda YOK, her ortamda 404.
1. Kök neden: `git log -S "agent-telemetry" -- index.html` — hangi commit, ne amaçla?
2. Varsayılan karar: **tag'i kaldır** (404 üretiyor, dosyası yok). Kök neden "dosyayı sonra ekleyeceğiz" ise
   rapora yaz, KALDIRMA — karar kullanıcıda.
3. Kaldırırsan testlerdeki `IGNORED_LOCATIONS`'tan 'agent-telemetry' girdisinin zorunlu olmadığını not et
   (test dosyalarına dokunma — bir sonraki E2E turunda temizlenir).

## İş 5 — api.js RPC_TABLES telafi boşluğu (ui-altyapi bulgusu 2)

`kategori_ekle/guncelle/sil` + `seed_defaults` RPC_TABLES'ta yok. `loadTanimlarPanel()` →
`pullTables(['stok_kategorileri'])` telafisi VAR (forms.js:1391 civarı) ama **seed_defaults**
drug_classes/diseases yazıyorsa bu tabloların telafisi YOK (ui-altyapi raporu).
Çözüm: ilgili çağrı sonrası `pullTables(['drug_classes','diseases'])` telafisi EKLE
(veya RPC_TABLES'a ekleme + tests/unit/api.test.js muafiyet listesini güncelle). Hangi yolu seçersen
gerekçelendir; `seed_defaults`'ın gerçekte hangi tablolara yazdığını canlıdan doğrulamak YASAK DEĞİL ama
**read-only** (pg_get_functiondef — prod token, SELECT düzeyi).

## Teslim

Tek commit (`idle: kod-temizlik-2 — B9 2. dilim + B8 + RPC_TABLES telafisi + agent-telemetry`),
362+ unit test yeşil kanıtı, detect_changes çıktısı özeti, rapor.
