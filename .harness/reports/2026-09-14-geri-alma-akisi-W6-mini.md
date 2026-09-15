# L4-W6 mini onarım — stok_uyari txid/UUID görünürden çıkışı (W6 teslim)

Tarih: 2026-09-14 · Rol: glmf worker · Dal: `agent/geri-alma-akisi-W6` (taban
`76713f4`, merge/push YAPILMADI) · Zarf:
`.ss/tasks/L4-W6-stok-uyari-txid.md` · Bulgu: luna 2. tur **L4-07 alt
(MEDIUM)** — `reports/2026-09-14-luna-denetim-l4-tur2.md`

## Kapsam kararları (gate denetimi — `.crumbs/2026-09-14-w6-gate.md`)

1. **txid iki üretim noktasından çıkar:** luna 0003:530-533'ü buldu; aynı
   format metni `_l4_zincir`'in stok döngüsünde de var (0003:1017-1023) ve
   zincir önizlemesi de AYNI görünür bloğu basıyor. Zarf "stok_uyari
   üretiminden `(txid %s)` kalkar" dediği için ikisi de kapsandı.
2. **Aynı-tx döngüsünün ham id'si de çıktı:** `_degisim_plan` 0003:523-529
   `metin`e `e.satir_pk->>'id'` gömer; `stok_hareket.id` text PK ve app
   `crypto.randomUUID()` üretir (`js/api.js:222`) → görünür metinde UUID.
   Zarf adım-3 test şartı "görünür alanda txid/**UUID** yok" bunu zaten
   emrettiği için id `hareket_id` ayrı alanına taşındı.

## Değişiklikler

| Dosya | Değişiklik |
|---|---|
| `supabase/migrations/20260914000004_l4_stok_uyari_txid.sql` (YENİ, 1040 satır) | `_degisim_plan` + `_l4_zincir` gövdeleri 0003'ten BİREBİR kopya; tek fark 3 uyarı satırı: (i) aynı-tx metni tanımlayıcısız + `'hareket_id'` alanı; (ii) bağlı-stok metninden `(txid %s)` kalktı + `'txid', e.txid::text` alanı; (iii) zincir aynı (ii). `metin` alanı KORUNUR. BEGIN/COMMIT + REVOKE; CREATE OR REPLACE → replay-safe. Şema değişikliği YOK (jsonb uyarı nesnesine alan). |
| `js/degisiklikler/degisiklikler.js` | `_dgTeknikDetayHtml`'e stok uyarı satırları (`Stok uyarı txid` / `Stok hareket` — pkKisa). Görünür Stok uyarısı bloğu DOKUNULMADI: artık yalnız temiz `metin` basar; txid/hareket_id YALNIZ teknik katlamada. |
| `index.html` | `?v=` damgası 20260914-09 → **20260914-11** (26 yer, TEK değer; eski damga kalıntısı 0). |
| `tests/unit/l4-stok-uyari-txid.test.js` (YENİ) | 6 test: (1) luna render-probu — görünür önizlemede txid/UUID YOK, katlamada txid KALIR; (2) katlama satırları details İÇİNDE; (3) boş stok_uyari → satır yok; (4-5) SQL pin — 0004 gövdeleri ters-normalizasyonla 0003'e BYTE-EŞİT (birebir kopya kanıtı), tek fark uyarı satırları; (6) kodda `(txid %s)` yok, replay-safe şekil. |
| `tests/unit/vaka-toplu-ac.test.js` | Damga pinleri 20260914-11 + eski-damga listesine `-10`,`-09` eklendi (tek-değer kilidi) + damga zinciri yorumu. |

## Test kanıtları (komut + sonuç)

| Koşum | Komut | EXIT | Sonuç |
|---|---|---|---|
| Baseline (değişiklik öncesi) | `NODE_PATH=/home/melik/egesut-erp1/node_modules node --test tests/unit/*.test.js` | 0 | 1023 pass / 0 fail / 0 skipped (luna'nın ölçümüyle aynı) |
| Yeni test dosyası | `node --test tests/unit/l4-stok-uyari-txid.test.js` | 0 | 6 pass / 0 fail |
| Tam suite (sonrası) | aynı tam komut | 0 | **1029 pass / 0 fail / 0 skipped** (1023 + 6 yeni) |
| Sözdizimi | `node --check js/degisiklikler/degisiklikler.js` | 0 | OK |
| Probe parse | SQL LSP typecheck `probe_stok_uyari.sql` | — | sözdizimi hatası YOK (yalnız "aynada obje yok" — ayna 0003-öncesi; canlı DEMO'da apply sonrası mevcut) |

## Engel: DEMO apply bu koltukta YAPILAMADI (kanıtla)

Zarf adımı 1 "DEMO'ya uygula" — koltukta DEMO DB erişimi yok:

1. Koltuk env'inde `SUPABASE_DEMO_*` / `DATABASE_URL` yok (75 env adının
   tamamı listelendi; W4 koltuğunun aksine DSN enjekte edilmemiş).
2. `~/.pgpass`, `~/.pg_service.conf` mevcut değil; fish/profile'da demo DSN yok.
3. tools-bank Management token'ı DEMO org'una erişmiyor:
   `POST /v1/projects/vtzqjmazsvurxdeondmi/database/query` → **403** "Your
   account does not have the necessary privileges"; token'ın proje listesi
   (4 proje) DEMO ref'ini içermiyor.
4. DSN şablonu `.claude/tasks/2026-09-11-pedigree-p1-W1.md` içinde
   `${SUPABASE_DEMO_DB_PASSWORD}` **yer tutucusu** — parola değerini taşımıyor.
5. `/root/tools-bank/.env`, `/root/egesut-erp1` → EACCES (koltuk melik kullanıcısı).
6. Bu koltukta ulaşılabilir tek DB yüzeyi tools-bank MCP `supabase_*` —
   `SB_PROJECT` hardcoded **PROD** (`mcp_server/server.py:334`,
   `zqnexqbdfvbhlxzelzju`) → zarf kuralı "DB yalnız DEMO" gereği DOKUNULMADI.

**Sonuç:** Migration + replay + canlı probe lead/root'a hazır komutlarla
bırakıldı: `reports/2026-09-14-geri-alma-akisi-W6/UYGULAMA.md` (uygula →
replay → probe; beklenen çıktılar yazılı) +
`reports/2026-09-14-geri-alma-akisi-W6/probe_stok_uyari.sql` (ROLLBACK-tabanlı
sentetik vaka; W6-A/B/C; iz bırakmaz). Apply yapılmadan bu bulgunun DEMO
üzerindeki kapanışı ölçülmüş sayılmaz — luna 3. turda `uygula*.out` +
`probe_stok_uyari.out` üzerinden doğrulayabilir.

## Bilinen sınır (root kararı 2 — dokunulmadı)

Köprü öncesi legacy olayların nötr etiketi YETERLİ sayıldı (zarf notu 5);
bu turda dokunulmadı, lead tesliminde bilinen sınır olarak yazılacak.

## Açık sorular

1. DEMO apply lead koltuğunda mı yapılacak, yoksa W6 koltuğu
   `SUPABASE_DEMO_*` env ile mi yeniden açılacak? (Rapor + UYGULAMA.md hazır.)
2. `_degisim_plan` aynı-tx uyarısının `hareket_id` alanı ve bağlı-stok
   uyarısının `txid` alanı ileride UI'da "hangi stok hareketi" detayı olarak
   katlamadan da mı gösterilsin — şimdilik yalnız teknik katlama (bu zarfın
   şartı).
3. rpc-reference.md stok_uyari payload şeklini dokümante etmiyor; ek alanlar
   (txid/hareket_id) dokümana eklenmeli mi? (lead manifest adımında karar.)

## Builtin review notu

code-reviewer subagent, tek-bulgu taraması (tam crumb:
`.crumbs/2026-09-14-w6-review.md`): **Kritik 0 / Önemli 0 / Küçük 3 —
birleştirmeye hazır.** Reviewer bağımsız sed+diff ile 0004/0003 byte-kıyası
yaptı (kopya iddiası doğrulandı), format/null-güvenliği/fixture/damga temiz.
Küçük bulgulardan ikisi uygulandı: görünür stok bloğu null-guard'ı
(`esc((st && st.metin) || '')`) + changelog yorumu kronolojik sıra; üçüncüsü
(pkKisa ilk-8-hex) bilinçli davranış — not olarak kaldı. Fix sonrası tam
suite yeniden koşuldu: **1029 pass / 0 fail** (EXIT 0).
