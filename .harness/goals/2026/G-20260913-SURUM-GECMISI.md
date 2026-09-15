---
id: G-20260913-SURUM-GECMISI
status: done
owner: root
flow: ss_org
created: 2026-09-13
base_sha: 621f12a
branch: agent/surum-gecmisi-diff
report: reports/2026-09-13-surum-gecmisi-teslim.md
write_manifest:
  - supabase/migrations/          # only 20260913* surum-gecmisi files (F1/F2)
  - js/degisiklikler/             # new frontend module (F3)
  - js/api.js                     # ADDITIVE only: RPC wrappers for the 4 frozen RPCs
  - index.html                    # ADDITIVE only: page section, script tags, nav entry
  - js/ui.js                      # ADDITIVE only: nav wiring + animal-detail link
  - tests/unit/                   # new pure-layer tests + fixtures
  - reports/                      # W1/W2/final delivery reports
  - .harness/references/ui-map.md         # docs checkpoint (lead, W2 PROPOSED)
  - .harness/references/rpc-reference.md  # docs checkpoint (lead, W2 PROPOSED)
  - .harness/goals/2026/G-20260913-SURUM-GECMISI.md
pattern_refs: [MODAL-ROUTER-01, TESTING-01]
pattern_exceptions: []
review_lane: codex_luna_max_bounded
implement_lane: glmf_workers
---

# G-20260913-SURUM-GECMISI — Version history + diff UI + ticketed revert

## Status
done — closed 2026-09-15 (D4 documentation closure; criterion evaluation in
the Closure section below). Lead lane was `agent/surum-gecmisi-diff`;
workers W1 (F1+F2 DB), W2 (F3 UI). Code, migrations, prod application, and
the main merge (`6a0edb1`) are all complete.

## Closure (2026-09-15, D4)

Prod application evidence (owner approval, 2026-09-15): the L2 4 migrations
were applied to prod — commits `e3c281e`/`b75d154`, merged to main as
`6a0edb1`. Root live measurement (recorded in commit `b75d154` message):
`surum_gizli` schema present, `trg_degisim_log` installed on 39 tables,
`islem_log` denies authenticated INSERT.

Owner UI walkthrough: **sahip doğruladı (2026-09-15 canlı)**.

Criterion-level result (evidence per `reports/2026-09-13-surum-gecmisi-teslim.md` §3):

| Kabul | Sonuç | Kanıt |
|---|---|---|
| 1 I/U/D log + immutability (demo) | PASS | W1 demo test betiği 156/156 (39 tablo; no-op ve kaynak vakaları dahil) |
| 2 Tek txid + trigger yükü | PASS | üç bağımsız koşum, medyan ek yük raporda |
| 3 Revert testleri (demo) | PASS | 46/46 (43 W1 vakası + luna düzeltme vakaları; iki tur tekrar) |
| 4 Unit + saf katman | PASS | taban 796/795/1; bilinen kırmızı `gecmis-pipeline.test.js:283` constraint gereği hariç |
| 5 UI açılır + sahip testi | PASS | 8 ekran görüntüsü raporda; K5 PARTIAL'ın sahip ayağı: sahip doğruladı (2026-09-15 canlı) |
| 6 Teslim raporu | PASS | `reports/2026-09-13-surum-gecmisi-teslim.md` |

Known open (outside this goal, owner-decided separate wave): prod
`schema_migrations` records (D3 §7b) and ground-truth regen (D3 §7c) are
pending; they do not block this closure.

## Date
2026-09-13

## Owner directive (BINDING, verbatim from owner task `.ss/tasks/L2-surum-gecmisi-diff.md`)

### Hedef
DB'deki her iş verisi değişikliği (ekleme, güncelleme, silme) iz bıraksın; bu
değişiklikler kendi ekranı olan bir **diff arayüzünde** işlem bazlı görülsün ve
güvenli şekilde geri alınabilsin. Git mantığı: işlem (transaction) = commit,
satır sürümü = dosya sürümü, alan farkı = diff, geri al = revert.

### Neden (ölçüldü, 2026-09-13)
- `islem_log` trigger'ı yalnız INSERT logluyor; `hayvanlar` UPDATE/DELETE izsiz.
- 2026-06-02 14:01:16 UTC'de uygulama dışı tek bir toplu yazım 124 hayvan
  satırını değiştirdi (küpe 4019→51, 22 devlet küpe, 10 doğum tarihi) — kim
  yaptığı hiçbir izden çıkmadı. Rapor: dal `agent/buzagi-51-arastirma`,
  `reports/2026-09-13-kupe-degisim-adli.md`.
- Mevcut geri al: 7 ayrı SECURITY DEFINER RPC, yetki kontrolü yok, tek koruma
  UI'daki a+b; `cop_kutusu` tek yönlü. `supa_audit` canlıda YOK; `pgaudit`
  kurulu ama satır sürümü tutmaz.

### Sahip kararları (bağlayıcı)
- **Rol sistemi EKLENMEYECEK.** Koruma: sahip şifresi → sunucu 1 saatlik geri
  alma bileti verir; geri alma RPC'si geçerli bilet ister. Hızlı onay için a+b
  kalabilir.
- **Gerekçe opsiyonel.**
- Mevcut geri al düğmelerine bağlamak yerine **ayrı bir diff arayüzü**;
  sürüden çıkarma (satış/ölüm/kesim) dahil. Mevcut **Geçmiş sekmesi ve 7 eski
  RPC'ye dokunulmaz** — iki sistem şimdilik bağımsız.

### Fazlar (owner)
**F1 — Sürüm kaydı (DB)**: `degisim_log` (id, txid, zaman, tablo, satır pk,
işlem I/U/D, `eski` jsonb, `yeni` jsonb, `degisen_alanlar` text[], kaynak);
silme/güncellemede eski satır TAM; generic AFTER trigger; değişen alan yoksa
kayıt yok; teknik-alan-değişimi ayrı işaretlenir; kapsam = tüm iş tabloları
(canlı şemadan envanter, teknik tablolar hariç, liste goal'da gerekçesiyle);
`degisim_log` değiştirilemez; indeksler (tablo, pk), txid, zaman; trigger
yükü demo'da ölçülür.

**F2 — Geri alma motoru (DB)**: `geri_alma_bileti_al(p_sifre)` (pgcrypto,
1 saatlik bilet, kullanım kaydı; şifre hash'i migration'a GÖMÜLMEZ — kurulum
adımı ayrı, demo'da test şifresi); `degisim_onizle(hedef, seviye)` (plan,
çakışma, bağımlı alt kayıt, stok etkisi); `degisim_geri_al(hedef, seviye,
bilet, gerekce?)` (geri almanın kendisi yeni sürüm kaydı; hard delete yok;
bilet yok/süresi dolmuşsa red). Geri alınamayanlar açıkça: çakışan hedef
(zorla seçeneği YOK), bağımlı alt kayıt engeli, `degisim_log`'un kendisi,
sistem kurulmadan önceki değişiklikler.

**F3 — Diff arayüzü (frontend)**: ayrı "Değişiklikler" sayfası; txid bazlı
liste (zaman, özet, kaynak); filtreler (hayvan, tarih aralığı — kanonik
`tekTarihTakvimAc`, gg.aa.yyyy; tablo; işlem tipi; sürüden çıkarma dahil);
satır satır renkli diff (eklenen yeşil, silinen kırmızı, eski→yeni; Türkçe
alan etiketleri); geri al akışı (alan/satır/işlem düğmesi → önizleme →
şifre modalı + kalan süre → opsiyonel gerekçe → uygula); çevrimdışıyken
kapalı; hayvan detayından filtre ön-dolu bağlantı.

### Kurallar (owner)
- Migration'lar **yalnız DEMO DB'de** uygulanır ve test edilir. **PROD'a
  hiçbir şey uygulanmaz** — prod deploy sahip kapısıdır.
- DB işi `code-change-precheck` + canlı şema doğrulaması ile.
- Rol/kullanıcı yetki tasarımı YOK.
- Worker bölünmesi: F1+F2 DB / F3 frontend; F3, RPC sözleşmesi sabitlendikten
  sonra (sözleşme bu goal'de aşağıda sabitlendi).
- main'e dokunma, push yok — entegrasyon root'ta. UI final testlerini sahip
  yapar; root teste hazırlar.

### Kabul (root yeniden ölçecek)
1. Demo DB: kapsamdaki her tabloda I/U/D sonrası `degisim_log` kaydı (test
   betiği + çıktı); değişen alan yoksa kayıt yok; `degisim_log` UPDATE/DELETE
   reddi.
2. Toplu işlem (100 satır tek tx) tek txid altında; trigger yükü ölçümü raporda.
3. Geri alma testleri (demo): alan/satır/işlem seviyesi; çakışma tespiti;
   bağımlı alt kayıt engeli; bilet yok/süresi dolmuş red; geri almanın geri
   alınması.
4. Unit testler yeşil (taban ölçülür, sayı raporda); yeni saf JS katman
   testleri (diff üretimi, Türkçe alan etiketleri).
5. UI: lokal sunucuda demo DB ile açılır (sahip test eder); ekran görüntüsü
   raporda.
6. Teslim raporu: `reports/2026-09-13-surum-gecmisi-teslim.md` — faz başı SHA,
   kapsam tablosu + gerekçe, test çıktıları, kalan riskler (prod deploy adımları
   ayrı bölüm).

## Authority
1. Owner directive above (verbatim, binding). 2. Frozen contracts below.
3. `.harness/contract.md`. 4. Live DEMO schema (only DB structure authority).

## Frozen contract — F2 RPC surface (BINDING for W1; W2 codes against it)
All four RPCs `SECURITY DEFINER`, fixed `search_path`, callable by
`authenticated`; anon denied. Migration files: `supabase/migrations/20260913*`.

```sql
geri_alma_bileti_al(p_sifre text) RETURNS jsonb
-- ok:   {"ok":true,"bilet":"<uuid>","olusturma":"<ISO8601>","son_gecerlilik":"<ISO8601>","kalan_sn":3600}
-- fail: {"ok":false,"hata":"SIFRE_HATALI"|"SIFRE_AYARLI_DEGIL"}
-- Semantik: pgcrypto crypt/gen_salt('bf'); bilet 1 saat geçerli, ÇOK
-- KULLANIMLI; her kullanım geri_alma_kullanim satırına yazılır.
-- Şifre hash'i migration'a GİRMEZ: sahip_sifresi_ayarla(p_sifre text)
-- RETURNS jsonb kurulum RPC'si ayrı migration'da gelir (demo'da test şifresi
-- bu RPC ile kurulur).

degisim_listele(p_filtre jsonb) RETURNS jsonb
-- p_filtre: {"baslangic":"YYYY-MM-DD"?,"bitis":"YYYY-MM-DD"?,"tablo"?,"islem"?,
--            "hayvan_id"?,"txid"?,"sayfa"?,"adet"?}   (hepsi opsiyonel)
-- ok: {"ok":true,"kayitlar":[{"txid","ilk_zaman","ozet":{"tablo_sayisi",
--      "satir_sayisi","islemler":{"I":n,"U":n,"D":n},"baslik"} ,"kaynak":{...}}],
--      "toplam":N,"sayfa":1,"adet":50}
-- txid filtresi verildiğinde AYNI RPC satır-bazlı entries döner:
-- {"ok":true,"detay":true,"kayitlar":[{id,txid,zaman,tablo_adi,satir_pk,islem,
--   eski,yeni,degisen_alanlar,teknikal_mi,kaynak}]}
--   (teknikal_mi W2 istemi Q3, lead onayı 2026-09-13: UI "teknik" rozeti
--    bu alandan; detay satırlarında bulunmalı)
-- (gerekçe: hayvan/tarih filtresi + tx gruplama PostgREST jsonb ile
-- yapılamaz; lead sözleşme kararı, root'a raporda bildirilir)

degisim_onizle(p_hedef jsonb, p_seviye text) RETURNS jsonb
-- p_seviye: 'alan'|'satir'|'islem'
-- p_hedef: {"txid":"<bigint>"} | {"tablo":"<tablo>","pk":"<deger>"[,"txid":"<bigint>"]} |
--          {"tablo":"<tablo>","pk":"<deger>","alan":"<kolon>"[,"txid":"<bigint>"]}
-- pk (W1 sorusu c9f7fd34, lead onaylı 2026-09-13): tek-kolon PK'da DEĞER
-- string olarak (uuid/text/sayı — canlı demo: 19 text PK tablo, 2 sayısal),
-- composite PK'da NESNE {pkkolon:deger} (vaccine_diseases, pedigree_meta);
-- degisim_log.satir_pk her zaman jsonb nesnesidir, W2 görüntüde pk'yi
-- satir_pk'nın tek değerinden okur.
-- Opsiyonel p_hedef.txid (satır/alan hedefinde): verilirse o tx'in o
-- satır/alan değişikliği hedeflenir; verilmezse satırın/alanın EN SON
-- değişikliği. Çakışma kuralı DEĞİŞMEZ: hedef txid'den sonraki,
-- plana dahil olmayan değişiklik yine CAKISMA (bypass yok).
-- ok: {"ok":true,"seviye":"...","hedef":{...},"plan":[{"sira","tablo","pk",
--      "islem","alanlar","eski","yeni","yapilacak"}],
--      "cakismalar":[{"tablo","pk","alan"?,"neden"}],
--      "bagimliliklar":[{"tablo","pk","iliski","etki":"ENGEL"|"KADEMELI"|"UYARI"}],
--      "stok_uyari":[{"stok_id","metin"}],
--      "geri_alinabilir":bool,"engeller":["..."]}
-- fail: {"ok":false,"hata":"HEDEF_BULUNAMADI"|"GECERSIZ_SEVIYE"|"GECERSIZ_HEDEF"}

degisim_geri_al(p_hedef jsonb, p_seviye text, p_bilet uuid,
                p_gerekce text DEFAULT NULL) RETURNS jsonb
-- ok:   {"ok":true,"geri_alma_txid":"<bigint>","uygulanan_adim":N}
-- fail: {"ok":false,"hata":"BILET_GECERSIZ"|"BILET_SURESI_DOLMUS"|"CAKISMA"|
--        "BAGIMLILIK_ENGELI"|"HEDEF_BULUNAMADI","detay":{...}}
```

Semantics (frozen):
- `degisim_geri_al` planı UYGULAMA ANINDA yeniden hesaplar (önizleme önerilir
  ama zorunlu değil; taze çakışma varsa red — race-safe).
- Geri alma gerçek DML'dir → normal trigger akışıyla `degisim_log`'a yeni
  kayıtlar düşer (geri almanın geri alınması mümkün). `degisim_geri_al`
  transaction-local GUC yazar: `app.geri_alma_bileti`, `app.geri_alma_gerekce`
  → trigger bunları `kaynak.geri_alma` içine damgalar.
- `alan` seviyesi yalnız `islem='U'` kayıtlarında geçerli; değilse
  `GECERSIZ_HEDEF`.
- Çakışma: hedef (tablo,pk[,alan]) için hedef txid'den SONRAKI, revert
  planına dahil olmayan değişiklik → `CAKISMA`, bypass YOK (sahip kararı).
- Bağımlılık: INSERT'in geri alınması satırı siler; silinen satırın, hedef
  txid'den sonra değişmiş alt kaydı varsa `ENGEL`; yoksa kademeli revert
  planı (`KADEMELI`).
- Stok: `stok_hareket` aynı txid'deyse plana girer; değilse `stok_uyari`
  (bilgilendirici, engellemez).
- Kapsam dışı: `degisim_log`, bilet/kullanım tabloları trigger kapsamına
  girmez; sistem kurulmadan önceki değişiklikler `HEDEF_BULUNAMADI`.

## Frozen contract — degisim_log schema (BINDING)
```sql
CREATE TABLE degisim_log (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY, -- tx içinde sıra = id
  txid bigint NOT NULL,                               -- txid_current()
  kayit_zamani timestamptz NOT NULL DEFAULT now(),
  tablo_adi text NOT NULL,
  satir_pk jsonb NOT NULL,                            -- composite-safe
  islem text NOT NULL CHECK (islem IN ('I','U','D')),
  eski jsonb,                                         -- I'de NULL
  yeni jsonb,                                         -- D'de NULL
  degisen_alanlar text[],                             -- yalnız U'da dolu
  teknikal_mi boolean NOT NULL DEFAULT false, -- degisen_alanlar ⊆ teknik küme
  kaynak jsonb NOT NULL
    -- {"rol":current_user,"jwt_sub","jwt_role","app_name","istemci_etiketi",
    --  "geri_alma":{"bilet","gerekce"}?}
);
-- İndeksler: (tablo_adi, satir_pk), (txid), (kayit_zamani).
-- Değiştirilemezlik: BEFORE UPDATE/DELETE (ve TRUNCATE) → RAISE EXCEPTION.
-- RLS/tenant durumu: islem_log'un canlıdaki dururumunu AYNEN izler (W1 canlı
-- şemadan doğrular, raporda kanıtlar).
-- Trigger: tek generic fn (AFTER INSERT/UPDATE/DELETE FOR EACH ROW), enum
-- edilmiş tablolara bağlanır; U'da içerik değişimi yoksa kayıt YOK; yalnız
-- teknik küme (updated_at vb — W1 canlıdan listeler) değiştiyse
-- teknikal_mi=true ile yazılır.
```

## Frozen contract — F3 module surface (BINDING for W2)
- `js/degisiklikler/degisiklikler.js` — sayfa kontrolcüsü (liste, filtreler,
  detay, geri-al akışı, bilet modalı + kalan süre, çevrimdışı kilidi).
- `js/degisiklikler/diff.js` — SAF katman (DOM yok, node --test ile test
  edilir): `diffSatirlari(eski, yeni) -> [{alan, eski, yeni, durum}]`,
  `islemOzeti(rows) -> {tablo_sayisi, satir_sayisi, islemler}`.
- `js/degisiklikler/etiketler.js` — SAF katman: `alanEtiketi(tablo, alan)`,
  `tabloEtiketi(tablo)` → Türkçe etiketler (test kapsamı kabul 4).
- `js/api.js`: yalnız 4 RPC wrapper'ı EKLENİR (mevcut rpc çağrı kalıbı izlenir;
  pattern_refs'e örnek isim verilir).
- Sayfa/nav: index.html + js/ui.js ADDITIVE (mevcut Geçmiş sekmesi ve modal
  akışlarına dokunulmaz); `?v=` damgası TÜM yeni script tag'lerinde TEK değer
  (kısmi bump = bilinen tuzak).
- Tarih: kanonik `tekTarihTakvimAc`, gösterim gg.aa.yyyy.
- Stub: W1 merge edilene kadar api wrapper'lar kontrat-şekilli demo stub ile
  çalışır (precedent: idle/pedigree-p2-W3); stub kodu gerçek wrapper ile
  AYNI imzayı sunar ve W1 merge'ünde tek noktadan sökülür.
- Test sunucu portu 8097/8098; 8080 sahibin SearXNG'si — dokunma.

## Lane rules (owner standing, 2026-09-11 — plan Rev 3.1, BINDING)
1. Worker: lead'e teslimden ÖNCE builtin subagent review ZORUNLU (not
   teslimin parçası; notsuz teslim reddedilir).
2. Lead: root'a devretmeden ÖNCE bağımsız luna (codex max) review ZORUNLU
   (tek tur; bulgu aynı worker'a döner).
3. İş yükü workerlarda; lead orkestrasyon + küçük dokunuşlar.
4. DB: demo serbest / PROD worker+lead'e KAPALI. Push ve deploy owner emriyle.

## Constraints (measured / known)
- Bilinen kırmızı main'de: `tests/unit/gecmis-pipeline.test.js:283` — yeşil
  iddiasından hariç tutulur; baseline sayısı raporda.
- Tenant kuralı (yeni tablo): `farm_id`/RLS durumu canlı şemadan doğrulanır;
  `degisim_log` için islem_log durumu referanstır.
- Dil: owner ile Türkçe; internal artifacts İngilizce (owner directive
  bölümü yürür metin olarak Türkçe kalır — authority sırası gereği).
- `.crumbs/` kirıntıları ana checkout'ta: `/home/melik/egesut-erp1/.crumbs/`.

## Work plan
1. [lead] goal commit (bu dosya) → W1/W2 görev dosyaları → workspaces +
   binding + bekleyiciler.
2. [W1] F1 migration + trigger + envanter kanıtı + F2 RPC'ler + demo test
   betiği (kabul 1-3) + yük ölçümü + unit baseline raporu.
3. [W2] F3 UI (frozen contract'a karşı stub) + saf katman unit testleri
   (kabul 4) + ekran görüntüsü (kabul 5).
4. [lead] W1 kabul → merge; W2 kabul → merge; entegrasyon (stub sökümü +
   gerçek RPC ile sayfa açılışı, demo); luna review; teslim raporu; root.

## Acceptance mapping
| Kabul | Sahip | Kanıt |
|---|---|---|
| 1 (I/U/D log + immutability) | W1 | demo test betiği + çıktı raporda |
| 2 (tek txid + yük) | W1 | ölçüm çıktısı raporda |
| 3 (revert testleri) | W1 | demo RPC test çıktısı |
| 4 (unit + saf katman) | W1 baseline + W2 | node --test çıktısı, baseline sayısı |
| 5 (UI açılır) | W2 + lead entegrasyon | ekran görüntüsü + lokal sunucu komutu |
| 6 (teslim raporu) | lead | reports/2026-09-13-surum-gecmisi-teslim.md |
