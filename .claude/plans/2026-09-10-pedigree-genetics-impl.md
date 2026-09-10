# EgeSüt ERP — Pedigree / Soy Graph / Genetik Katman Implementasyon Planı

**Durum:** Executor-ready implementation plan — **REVİZYON 2**  
**Tarih:** 2026-09-10  
**Mimari otorite:** `EgeSüt ERP — Pedigree, Soy Graph ve Genetik Katman Mimari Spec`  
**İncelenen repo dump:** `egesut-dump.zip`, dump içindeki HEAD `a3d8bc2` (2026-09-09)  
**Hedef:** Mevcut EgeSüt üretim/üreme akışını bozmadan global pedigree DAG + focal tree UI + kontrollü semen identity + akrabalık/inbreeding + founder/breed contribution + dış genetik değerlendirme katmanını fazlı olarak devreye almak.

> **EXECUTION NOTE:** Bu plan tek seferde “big bang” uygulanmamalı. Her phase kendi migration + test + acceptance gate’ini geçmeden sonraki phase’e başlanmamalı. DB tarafı additive/compatible önce deploy edilir, frontend daha sonra yeni kontrata geçirilir.
>
> **REPO FLOW:** Bu repodaki mevcut implementasyon planı geleneğine uy: implementer commit atmaz; coordinator review/commit yapar. Her task sonunda working tree kontrollü bırakılır.
>
> **NON-NEGOTIABLE:** Frontend pedigree/genetik hesabı yapmaz. Cytoscape/ELK yalnız render/layout yapar. Kinship, F, founder contribution, completeness ve mating sonucu PostgreSQL/RPC otoritesindedir.
>
> **REVİZYON 2 (2026-09-10):** Repo + canlı DB doğrulaması ve owner review turu
> sonrası revize edildi. Kapsayıcı değişiklikler: (1) D4 — üreme stok/RPC
> bugfix'leriyle hizalama (BUGS.md BUG-001..003, goal `G-20260910-UREME-STOK-BUGFIX`);
> (2) D5 — v1 = Faz 0-10 + 4 teslim paketi, Faz 11-12 v2; (3) D6 — metrik cache
> tabloları v1'de yok (on-demand RPC); (4) Task 0.2 tip beklentileri canlıdan
> okuma talimatına döndü; (5) Task 5 layout kararı breadthfirst-önce + ELK lazy;
> (6) Task 10/11 stok semantiği + RPC_MAP zorunluluğu + üç kaynaklı sperma yüzeyi;
> (7) offline kabulü "sekme açıkken ağ kesilmesi"ne bağlandı; (8) Task 27 SQL
> koşum ortamı repo araçlarına bağlandı. Orijinal İndirilenler kopyası Revizyon 1
> referansı olarak durur.

---

## 0. Uygulamadan önce kesinleştirilen implementasyon kararları

Mimari spec korunuyor; ancak repo gerçekleri nedeniyle aşağıdaki uygulama sertleştirmeleri (D1-D6) planın otoritesidir. D4-D6 Revizyon 2 ile eklendi.

### D1 — Farm animal node lifecycle: `ON DELETE SET NULL` değil undo-compatible lifecycle

Mimari spec’teki örnek `pedigree_nodes.farm_animal_id ... ON DELETE SET NULL`, aynı spec’teki “farm_animal node ise farm_animal_id zorunlu” invariant’ıyla ve repo’daki generic `geri_al()` DELETE davranışıyla çelişir.

Uygulamada:

```text
hayvanlar DELETE
    ↓
pedigree farm node DELETE
    ↓
ona bağlı parentage edge'leri DELETE
```

kullanılmalı.

Öneri:

- `pedigree_nodes.farm_animal_id REFERENCES hayvanlar(id) ON DELETE CASCADE`
- `pedigree_parentage.parent_node_id/child_node_id ... ON DELETE CASCADE`
- external pedigree node’lar frontend’den raw DELETE edilemez; yalnız kontrollü RPC ile yönetilir.

Bu, yeni kaydı geri alma ve doğum geri alma akışını bozmadan `farm_animal` invariant’ını korur. Sürüden çıkış zaten fiziksel DELETE değil `durum` değişimidir; tarihsel soy node’u yaşamaya devam eder.

### D2 — Farm animal node creation: yalnız RPC’ye değil trigger + ensure helper’a bağlanır

Farm animal çeşitli yollarla oluşabiliyor (`hayvan_ekle`, `dogum_kaydet`, demo/gelecek import yolları). Bu nedenle tek tek bütün RPC’lere node INSERT kopyalamak yerine:

```text
AFTER INSERT ON hayvanlar
    ↓
pedigree_ensure_farm_node(NEW.id)
```

kullanılır.

Aynı helper doğum/repair/backfill kodundan da çağrılabilir ve idempotent olmak zorundadır.

### D3 — Sync sınırı

`semen_catalog` küçük ve operasyonel controlled catalog olduğu için normal IDB sync’e alınabilir.

Aşağıdakiler **TABLES full-sync listesine alınmaz**:

- `pedigree_nodes`
- `pedigree_parentage`
- `pedigree_node_metrics`
- `pedigree_founder_contributions`
- `genetic_evaluations`

Bunlar yalnız projection/profile RPC sonucu olarak `pedigree_cache` içinde on-demand tutulur.

### D4 — Üreme stok/RPC bugfix hizalaması (PENDING bugfix)

`BUGS.md` BUG-001..003 ve goal `G-20260910-UREME-STOK-BUGFIX` (dal
`idle/ureme-stok-bugfix`) bu plana girdi sağlar:

- **Task 10'un stok maddesi** "mevcut düşümü koru" değil, **"bugfix'lerle
  düzeltilmiş kuralı taşı"**dır: boş sperma düşmez + exact-before-substring +
  üç tohumlama yolu tek ortak kural. Bugfix merge edilmeden Faz 5-7'nin write
  kontratı dondurulmaz.
- **BUG-003 ön koşulu:** `gebelik_kaydet_manual` canlıda 42804 ile kırık;
  `gebelik_kaydet_manual_semen` varyantı, temel RPC canlıda çalışır hale
  gelmeden yazılmaz.
- **Migration numaraları:** bugfix migration'ları `20260910*` aralığını
  kullanacak; bu planın migration timestamp'leri implementasyon anında
  next-free kuralıyla yeniden seçilir (aşağıdaki sıra konsept sırasıdır).
- **Canlı ölçüm gerçeği (2026-09-10):** `tohumlama_kaydet` ve
  `tohumlama_tekrar_kaydet` ILIKE desenle düşürüyor, `planli_tohumlama_kaydet`
  hiç düşürmüyor. GT dosyasında bu gövde ayrışmış durumda (SMELL-003) —
  GT rehber, canlı otorite.

### D5 — v1 kapsamı ve teslim paketleri (overridable)

v1 = eski Faz 0-10 (soy ağacı + mating precheck + genetik havuz).
**Faz 11 (EBV/PTA) ve Faz 12 (retirement hazırlığı) v2'ye taşındı.**
Fazlar 4 teslim paketine eşlenir; her paket kendi migration seti + testleri +
demo gösterimiyle kapanır (owner demo-onaylı merge akışı):

```text
P1 Temel   = Faz 0-2   (foundation + backfill + integrity raporu)   — demo: rapor
P2 Ağaç    = Faz 3-4   (projection RPC + cache + Soy tabı UI)       — demo: soy ağacı
P3 Üreme   = Faz 5-7   (semen identity + kontrollü write + doğum)   — demo: buzağı soyu
P4 Analiz  = Faz 8-10  (kinship + precheck + founder/breed havuzu)  — demo: precheck
v2         = Faz 11-12 (EBV + retirement hazırlığı)
```

Paketler bağımsız worktree/dal olarak yürür; "Önerilen final repo değişiklik
haritası" ve tek-owner dosya listesi her zarfın write-manifest'ine aynen geçer.

### D6 — Metrik cache'siz v1 (overridable)

`pedigree_node_metrics` ve `pedigree_founder_contributions` tabloları ile
invalidation mekanizması **v1'de YOKTUR**. Kinship, F, founder katkısı ve
completeness on-demand RPC hesabıdır (yanıtlar `algorithm_version` taşır).
130 hayvan + birkaç bin node ölçeğinde tabular hesap ucuzdur; kalıcı cache ve
dirty-descendant queue ancak ölçümle gerekçelenirse v2'de eklenir. Task 14 ve
Task 19'un cache kısımları v2 bandına alınmıştır.

---

# PHASE 0 — Preflight, canlı veri envanteri ve baseline

## Task 0.1 — Repo baseline’i dondur

**Dosya değişikliği:** yok.

Önce:

```bash
git status --short
git rev-parse HEAD
npm run test:unit
```

kaydedilir.

Ardından pedigree ile çakışabilecek mevcut akışlar ayrıca bulunur:

```bash
rg -n "tohumlama_kaydet|planli_tohumlama_kaydet|tohumlama_tekrar_kaydet|gebelik_kaydet_manual|dogum_kaydet" js supabase/migrations
rg -n "INSERT INTO public.tohumlama|INSERT INTO public.hayvanlar" supabase/migrations
rg -n "sperma|baba_bilgi|anne_id" js supabase/migrations
```

**Gate:** baseline unit test sonucu kayıt altına alınmadan SQL değiştirme.

## Task 0.2 — Canlı schema imzalarını yeniden doğrula

Dump’taki snapshot rehberdir, otorite canlı DB’dir. En az şu imzalar doğrulanmalı:

- `hayvan_ekle`
- `dogum_kaydet`
- `tohumlama_kaydet`
- `planli_tohumlama_kaydet`
- `tohumlama_tekrar_kaydet`
- `gebelik_kaydet_manual`
- `geri_al`

Ayrıca canlı column type’ları **beklenti yazmadan, canlıdan okunarak** kaydedilir
(Revizyon 2: önceki "tohumlama.id = uuid" beklentisi YANLIŞTI — gerçekte
`tohumlama.id` **text**’tir, UUID text olarak üretilir; `dogum.id`/`olay_id`
uuid’dir). Bugünkü bilinen değerler plana ölçüm çıktısı olarak işlenir;
GT↔canlı drift zaten kanıtlı (BUGS.md SMELL-003), bu yüzden GT dump’ı tip
iddiası için kaynak DEĞİLDİR.

**Gate:** tracked ground truth ile canlı arasında pedigree implementasyonunu etkileyen yeni drift varsa önce plana not düş.

## Task 0.3 — Legacy semen / baba identity envanteri

Canlı DB’den:

```sql
SELECT sperma, count(*)
FROM public.tohumlama
WHERE sperma IS NOT NULL AND btrim(sperma) <> ''
GROUP BY sperma
ORDER BY count(*) DESC, sperma;

SELECT baba_bilgi, count(*)
FROM public.hayvanlar
WHERE baba_bilgi IS NOT NULL AND btrim(baba_bilgi) <> ''
GROUP BY baba_bilgi
ORDER BY count(*) DESC, baba_bilgi;

SELECT baba_bilgi, count(*)
FROM public.dogum
WHERE baba_bilgi IS NOT NULL AND btrim(baba_bilgi) <> ''
GROUP BY baba_bilgi
ORDER BY count(*) DESC, baba_bilgi;

SELECT id, urun_adi, kategori, birim
FROM public.stok
WHERE kategori = 'Sperma'
ORDER BY urun_adi;
```

çıktıları alınır.

Bunlardan **human-reviewed** mapping hazırlanır:

```text
legacy string            canonical bull       stock_id       güven
Armada                    Armada               ...            exact
ARMADA RED                Armada               ...            confirmed
Fresco Red                Fresco Red           ...            confirmed
? / belirsiz              NULL                 NULL           unresolved
```

**Kural:** fuzzy string similarity ile otomatik biological identity merge YOK. Aynı boğayı birleştirme yalnız explicit mapping veya registry code ile yapılır.

**Gate:** belirsiz kayıtlar unresolved kalabilir; yanlış merge yapmak blocker’dır, unknown bırakmak blocker değildir.

**Revizyon 2 — gerçek veri spot-check:** envanter çıktısı yanına, vethek’ten
işlenen gerçek sürü verisiyle (207 tohumlamalı set) salt-okunur maternal hat
doğrulaması eklenir: `hayvanlar.anne_id` ↔ `dogum` kayıtları çapraz kontrol;
çelişkiler integrity raporunun ilk girdisidir. Fixture uydurma veriyle geçer,
gerçek sürü geçmeyebilir.

## Task 0.4 — Embriyo transferi gate’i

Canlı tarihçede embriyo transferi kullanıldıysa bu planın `dam = dogum.anne_id` varsayımı durdurulur ve önce `genetic_dam` / `recipient_dam` genişletmesi yapılır.

**Gate:** ET yok/ihmal edilebilir diye domain kararı netleşmeden Phase 4 doğum parentage write açılmaz.

---

# PHASE 1 — Pedigree storage foundation, henüz UI yok

## Task 1 — Foundation migration

**Create:**

```text
supabase/migrations/20260910000001_pedigree_foundation.sql
tests/sql/pedigree_graph_test.sql
```

### 1.1 Önce SQL acceptance fixture’larını yaz

En az şu invariant testleri bulunmalı:

1. farm animal → tek `pedigree_node`
2. aynı `(farm_id, farm_animal_id)` ikinci kez oluşmaz
3. external node farm animal olmadan yaratılabilir
4. aynı registry identity ikinci kez oluşmaz
5. child başına bir dam + bir sire sınırı
6. parent = child reddi
7. cross-farm edge reddi
8. cycle A→B→C→A reddi
9. node silindiğinde edge orphan kalmaz
10. farm animal undo/delete olduğunda farm node orphan kalmaz

### 1.2 Tablolar

İlk migration yalnız çekirdeği kurmalı:

```text
pedigree_nodes
pedigree_parentage
semen_catalog
```

`genetic_evaluations`, metric cache ve founder contribution tabloları daha sonraki migration’a bırakılır; foundation blast radius’u küçültülür.

#### `pedigree_nodes`

Zorunlu implementasyon detayları:

- `id uuid PK`
- `farm_id uuid NOT NULL DEFAULT REAL_FARM_ID`
- `farm_animal_id text NULL REFERENCES hayvanlar(id) ON DELETE CASCADE`
- `node_kind IN ('farm_animal','external_animal')`
- `display_name`, `registry_system`, `registry_code`, `sex`, `breed`, `birth_date`, `country_code`, `metadata`
- timestamps

DB CHECK:

```text
farm_animal     => farm_animal_id IS NOT NULL
external_animal => farm_animal_id IS NULL
```

Unique/index:

- `(farm_id, farm_animal_id)` unique
- partial unique `(farm_id, registry_system, registry_code)` when both registry fields dolu
- `(farm_id, node_kind)`

#### `pedigree_parentage`

- `parent_node_id` / `child_node_id` FK `ON DELETE CASCADE`
- `parent_role IN ('dam','sire')`
- `source_type IN ('birth','manual','import','reconcile')`
- `source_ref text`
- `confidence numeric 0..1`
- `(farm_id, child_node_id, parent_role)` unique

Indexes:

```text
(farm_id, child_node_id)
(farm_id, parent_node_id)
(farm_id, parent_role, child_node_id)
```

#### `semen_catalog`

- `farm_id`
- `bull_node_id` → external/farm male pedigree node
- `stock_id text NULL REFERENCES stok(id) ON DELETE SET NULL`
- `code`, `display_name`, `supplier`, `semen_type`, `active`, `metadata`
- `(farm_id, stock_id)` partial/normal unique when stock_id non-null

### 1.3 RLS / grants

Yeni tablolar RLS-enabled olacak; Faz 2 öncesi repo politikasına uygun `USING(true)` kalabilir.

Ancak mutation surface sınırı korunmalı:

- `semen_catalog`: frontend SELECT gerekir
- pedigree graph tables: SELECT doğrudan şart değil; projection RPC otorite olabilir
- graph INSERT/UPDATE/DELETE client’a açık bırakılmamalı

### 1.4 Helper’lar

Foundation ile:

```text
pedigree_ensure_farm_node(p_hayvan_id text) -> uuid
pedigree_is_ancestor(p_ancestor uuid, p_descendant uuid) -> boolean
pedigree_parent_set(...)
pedigree_external_upsert(...)
```

oluştur.

`pedigree_parent_set`:

- `public.current_farm_id()` stamp
- same-farm check
- parent != child
- role uniqueness
- aynı role + aynı parent tekrar gelirse idempotent success
- aynı role + farklı parent gelirse **sessiz overwrite YOK**; `p_replace=true` veya ayrı replace RPC gerekir
- cycle check
- source metadata
- advisory transaction lock ile parentage mutation serialize
- raw graph write yerine tek canonical mutation yolu

Sex kontrolü fail-closed değil, veri uyumluluğunu gözeten şekilde tasarlanmalı:

- bilinen erkek → `dam` olarak reddet
- bilinen dişi → `sire` olarak reddet
- sex NULL/unknown → izin ver ama integrity report’ta uyar

### 1.5 Hayvan insert trigger

```text
trg_pedigree_hayvan_insert
AFTER INSERT ON hayvanlar
→ pedigree_ensure_farm_node(NEW.id)
```

Trigger function `farm_id` değerini client’tan almaz.

### 1.6 Test

Migration local/test DB’ye uygulanıp `tests/sql/pedigree_graph_test.sql` çalıştırılır.

**Phase 1 acceptance:** mevcut frontend hiç değişmeden çalışır; yeni tablolar additive’dir; yeni/geri alınan hayvan node lifecycle testi geçer.

---

# PHASE 2 — Existing herd bootstrap + maternal pedigree + integrity report

## Task 2 — Existing farm nodes backfill

**Create:**

```text
supabase/migrations/20260910000002_pedigree_farm_backfill.sql
```

### 2.1 Node backfill

```text
hayvanlar
  ↓
pedigree_ensure_farm_node(id)
```

Tüm farm hayvanları için idempotent çalışır.

Farm node render alanları kopyalanarak authoritative hale getirilmemeli; farm animal label çözümü projection sırasında `hayvanlar` join’i ile yapılmalı. Böylece küpe/ırk değişiminde graph node snapshot drift etmez.

### 2.2 Maternal edge backfill

Yalnız güvenli satırlar:

```text
child.hayvanlar.anne_id == existing hayvanlar.id
```

ise:

```text
dam node → child node
source_type = reconcile
confidence = 1
```

oluştur.

`anne_id` değeri gerçek `hayvanlar.id` ile resolve olmayan satırları otomatik node’a dönüştürme; integrity report’a bırak.

### 2.3 `pedigree_integrity_report()`

**Create read-only RPC** ve şu grupları JSON döndür:

- farm animal node eksikleri
- unresolved `anne_id`
- unresolved `baba_bilgi`
- child without dam
- child without sire
- role/sex contradiction
- duplicate registry identities
- legacy semen strings without catalog mapping
- cycle count (normalde 0)
- parent born after child gibi tarih anomalileri

### 2.4 Idempotency testi

Backfill iki kez çalıştırıldığında node/edge sayısı artmamalı.

**Phase 2 acceptance:** bütün mevcut sürü tek farm node identity’sine sahip; resolve edilebilen anne hatları graph’ta; paternal unknown veriler yanlış tahmin edilmeden raporda görünür.

---

# PHASE 3 — Projection query API + on-demand local cache

## Task 3 — `pedigree_subgraph` RPC

**Create:**

```text
supabase/migrations/20260910000003_pedigree_projection_rpc.sql
```

RPC:

```text
pedigree_subgraph(
  p_focus_node_id uuid,
  p_ancestor_depth integer default 4,
  p_descendant_depth integer default 1
) -> jsonb
```

Ek convenience read:

```text
pedigree_subgraph_for_animal(
  p_hayvan_id text,
  p_ancestor_depth integer default 4,
  p_descendant_depth integer default 1
) -> jsonb
```

### 3.1 Query guard’ları

- depth negative reddi
- MVP max ancestor depth: 8
- MVP max descendant depth: 3
- same-farm node check
- recursive CTE içinde `path uuid[]` cycle guard (DB invariant bozulsa bile sonsuz traversal yok)

### 3.2 Dönüş kontratı

```json
{
  "focus": "uuid",
  "nodes": [
    {
      "id": "uuid",
      "kind": "farm_animal|external_animal",
      "farm_animal_id": "H...|null",
      "label": "136|Armada",
      "sex": "...",
      "breed": "...",
      "birth_date": "..."
    }
  ],
  "edges": [
    {
      "id": "uuid",
      "source": "parent uuid",
      "target": "child uuid",
      "role": "dam|sire",
      "source_type": "birth|..."
    }
  ],
  "meta": {
    "ancestor_depth": 4,
    "descendant_depth": 1,
    "truncated": false
  }
}
```

Farm animal label/sex/breed/birth_date `hayvanlar`dan resolve edilir; external node kendi alanını kullanır.

### 3.3 Query unit/SQL cases

- focus only
- 4-generation chain
- shared ancestor dedup
- sibling descendants
- unknown parent
- max depth truncate
- malformed historical cycle olsa dahi query termination

**Gate:** UI başlamadan RPC contract fixture stabil olmalı.

## Task 4 — IndexedDB pedigree cache + API wrapper

**Modify:** `js/api.js`  
**Create:** `js/pedigree/pedigree-api.js`  
**Create:** `tests/unit/pedigree-cache.test.js`, `tests/unit/pedigree-api.test.js`

### 4.1 DB version

Dump’ta `DB_VER=24`; implementasyon branch’inde başka feature bump yapmadıysa `25` yap. Başka branch değeri artırdıysa **next free version** kullan; hardcode 25’e kör gitme.

`openDB().onupgradeneeded` içine TABLES dışında özel store:

```text
pedigree_cache
keyPath = key
```

row shape:

```json
{
  "key": "subgraph:animal:H123:up4:down1:v1",
  "payload": {},
  "cached_at": "ISO",
  "schema_version": 1
}
```

### 4.2 Generic IDB helpers

`api.js` içine yalnız ihtiyaç kadar:

```text
idbGetByKey(store, key)
idbClearStore(store)
```

ekle. `pedigree_cache` global `TABLES` listesine eklenmez.

### 4.3 Cache policy

`pedigree-api.js`:

```text
pedigreeApi.subgraphForAnimal(...)
pedigreeApi.subgraphForNode(...)
pedigreeApi.integrityReport()
```

Davranış:

1. network RPC denenir
2. başarılıysa cache overwrite edilir
3. network yok/iletim hatası varsa matching cached payload döner
4. cache de yoksa açık “çevrimdışı ve önbellek yok” durumu döner

Domain hesabı client’a taşınmaz.

### 4.4 Cache invalidation

`api.js` içinde pedigree graph’ını değiştiren RPC’ler için küçük bir invalidator seti kullan:

```text
pedigree_parent_set
pedigree_external_upsert
semen_catalog_upsert
[sonraki phase'de dogum/semen-aware write RPC'leri]
```

Başarılı mutation sonrası `pedigree_cache` clear edilir.

`RPC_TABLES` içine pseudo cache table ekleme.

**Phase 3 acceptance:** subgraph online çağrılır, IDB’ye düşer, offline reopen’da aynı payload render edilebilir.

---

# PHASE 4 — Graph render katmanı ve hayvan kartında focal pedigree tree

## Task 5 — Vendor compatibility spike (Revizyon 2: ikiye bölündü)

**P2 kapsamı (focal tree):**

```text
vendor/cytoscape.min.js     (~0,4 MB, pinned)
```

- CDN `latest` kullanma; sürüm pinlenir ve vendor edilir.
- Plain `<script>`/browser global ile repo buildless yapısında smoke-test
  edilir; mobile/touch zoom/pan denenir.
- Focal tree yerleşimi Cytoscape yerleşik `breadthfirst`’tır — bu aşamada
  başka layout kütüphanesi YOKTUR.

**P4 kapsamı (mating overlay):**

```text
vendor/elk.bundled.js        (~1,5 MB, pinned — sayfaya yalnız mating görünümünde lazy-load)
vendor/cytoscape-elk.js      (adapter, ELK semver aralığı doğrulanmış pin)
```

- ELK yalnız mating görünümü açıldığında yüklenir; ilk yük bütçesi (pedigree
  JS < 1 MB) korunur.
- Gerekçe: focal tree için breadthfirst muhtemelen yeterli; 4-6 kuşak ölçümü
  yetersiz gösterirse ELK focal’e de alınır (karar ölçümle).

**Gate (P2):** `window.cytoscape` + `breadthfirst` yerleşimi local static
server’da hatasız. **Gate (P4):** ELK adapter registration + `layered`
yerleşimi lazy-load akışında hatasız.

## Task 6 — Pedigree frontend feature boundary

**Create:**

```text
js/pedigree/pedigree-adapter.js
js/pedigree/pedigree-style.js
js/pedigree/pedigree-view.js
js/pedigree/pedigree-controller.js

tests/unit/pedigree-adapter.test.js
```

### Sorumluluklar

`pedigree-adapter.js`

- RPC `nodes/edges` → Cytoscape element array
- node classes: focus/farm/external/dam/sire/shared/unknown
- edge data: role/source_type
- **hesap yok**

`pedigree-style.js`

- Cytoscape style config
- theme token’larına uyum
- farm/external ayırt edilebilir ama erişilebilir görünüm

`pedigree-view.js`

- Cytoscape init/destroy
- ELK layered config
- resize/re-layout
- zoom-to-fit
- node click event’i

`pedigree-controller.js`

- current focus
- lazy load
- +2 generation
- stale-response guard (`_detOpenId` idiomuna benzer)
- farm node click → `openDet(farm_animal_id)`
- external node click → external pedigree detail sheet
- cached/offline badge

### Test

Adapter unit testleri:

- source/target yönü parent→child korunur
- shared node duplicate edilmez
- HTML/user strings element data’ya güvenli gider
- missing optional fields crash etmez

## Task 7 — Animal detail “Soy” tabı

**Modify:** `index.html`, `js/ui.js`, `js/utils/handlers.js` gerekirse  
**Create/Modify:** pedigree controller dosyaları

Mevcut detail tabs:

```text
Özet | Sağlık | Üreme | Görevler | Geçmiş
```

şuna genişler:

```text
Özet | Sağlık | Üreme | Soy | Görevler | Geçmiş
```

Yeni pane:

```text
#tab-pedigree
```

İç UI:

```text
[Soy Ağacı] [Genetik]

4 kuşak                        [+2 kuşak]
┌──────────────────────────────────────┐
│ Cytoscape focal projection          │
└──────────────────────────────────────┘
```

### Lazy-load zorunlu

`openDet()` her hayvan açılışında pedigree RPC çağırmamalı. `Soy` tabı ilk kez aktive edildiğinde controller çağrılır.

`openDet()` değişiklikleri yalnız:

- skeleton/clear listesine `tab-pedigree`
- current animal id controller’a hazır hale gelir
- aktif tab `soy` ise lazy loader tetiklenir

olmalı.

### External node sheet

MVP’de ayrı dev modal gerekmez. Küçük bottom sheet/detail panel yeterli:

- canonical name
- registry code
- sex/breed
- parents
- semen catalog refs
- “Bu node’u merkez yap”

**Phase 4 acceptance:** herhangi bir hayvan kartından 4 kuşak focal tree açılır; sekme açıkken ağ kesildiğinde son projection cache’ten açılır (cold-start offline app zaten yoktur — Revizyon 2); shared ancestor aynı projection’da tek node’dur.

---

# PHASE 5 — Semen identity normalization ve paternal graph

## Task 8 — Semen catalog + external bull backfill migration

**Create:**

```text
supabase/migrations/20260910000004_semen_identity_backfill.sql
```

Phase 0’daki human-reviewed mapping bu migration’ın veri girdisidir.

### 8.1 External bull nodes

Her confirmed canonical bull için bir node:

```text
node_kind = external_animal
sex       = male / canonical representation
registry_* varsa doldur
```

Armada’nın anne/baba/nine/dede kayıtları da güvenilir pedigree kaynağı mevcutsa external nodes + import edges olarak eklenebilir.

**Kural:** yalnız isimden pedigree uydurma yok.

### 8.2 Semen catalog rows

Her sperma stok satırı:

```text
stok.id
   ↓
semen_catalog.stock_id
   ↓
bull_node_id
```

ile bağlanır.

Stock olmayan ama sık kullanılan confirmed semen de `stock_id=NULL` catalog row olabilir.

### 8.3 `tohumlama.semen_id`

Additive column:

```sql
ALTER TABLE public.tohumlama
ADD COLUMN semen_id uuid NULL REFERENCES public.semen_catalog(id) ON DELETE SET NULL;
```

Index:

```text
(semen_id)
(hayvan_id, tarih DESC)
```

### 8.4 Legacy tohumlama backfill

Sadece explicit mapping ile `tohumlama.semen_id` doldur.

Unresolved strings NULL kalır.

### 8.5 Paternal existing calf reconciliation

Historical child için güven sırası:

1. doğumla ilişkilendirilebilir pregnant tohumlama + confirmed `semen_id`
2. aynı `dogum.olay_id` içindeki önceki sibling sire edge
3. explicit reviewed `dogum.baba_bilgi` mapping
4. explicit reviewed `hayvanlar.baba_bilgi` mapping
5. aksi halde unknown

Edge:

```text
bull node --sire--> child node
source_type = reconcile
source_ref = dogum.id veya reconciliation ref
```

**Kural:** bir child’da mevcut confirmed sire farklıysa migration overwrite etmez; integrity conflict üretir.

**Phase 5 acceptance:** Armada ve mapped boğalar global graph’ta tek identity; güvenli historical yavrular paternal edge alır; unresolved kayıt sayısı raporlanır.

---

# PHASE 6 — Controlled semen UI ve yeni tohumlama write kontratı

## Task 9 — `semen_catalog` local sync

**Modify:** `js/api.js`, `js/app.js`, tests

`semen_catalog` küçük operational catalog olarak:

- `TABLES` listesine eklenir
- matching fetcher eklenir
- IDB store DB version bump ile yaratılır (Phase 3 aynı branchte bump yaptıysa tekrar bump etme; tek schema upgrade planla)
- state’e bütün pedigree graph değil yalnız semen listesi gerek kadar taşınır

`tests/unit/api.test.js` TABLES/FETCHERS consistency güncellenir.

## Task 10 — Semen-aware write RPC compatibility layer

**Create:**

```text
supabase/migrations/20260910000005_semen_controlled_writes.sql
```

> **D4 ön koşulları (Revizyon 2):** (a) `G-20260910-UREME-STOK-BUGFIX`
> merge edilmeden bu task başlamaz — stok kuralı bugfix’ten miras alınır;
> (b) `gebelik_kaydet_manual` canlıda çalışır (BUG-003 fix deploy edilmiş)
> olmadan `gebelik_kaydet_manual_semen` yazılmaz.

Mevcut kritik RPC imzalarını riskli şekilde bir anda kırma. Yeni semen-aware entry point’ler ekle:

```text
tohumlama_kaydet_semen(..., p_semen_id uuid, ...)
planli_tohumlama_kaydet_semen(..., p_semen_id uuid, ...)
tohumlama_tekrar_kaydet_semen(..., p_semen_id uuid, ...)
gebelik_kaydet_manual_semen(..., p_semen_id uuid NULL, ...)
```

Yeni RPC’ler:

1. semen row same farm + active validate
2. `display_name` snapshot resolve
3. mevcut authoritative business rules’i **tek yerde** kullan
4. `tohumlama.semen_id` set et
5. stock düşümü: bugfix’lenmiş kuralı (boş sperma düşmez + exact-before-substring + üç yol ortak — D4) `semen_catalog.stock_id` üzerinden uygula; davranış icat etme, düzeltilmiş kuralı taşı
6. `tohumlama.sperma` snapshot alanını doldurmaya devam et

### Kritik refactor kuralı

Mevcut `tohumlama_kaydet` 200+ satırlık business body’sini dört kez kopyalama.

İki kabul edilebilir yol:

**Tercih A:** private/internal core function’a çıkar, legacy public RPC + semen-aware public RPC aynı core’u çağırır.

**Tercih B:** semen-aware wrapper mevcut RPC’yi çağırır, fakat stock movement ve `semen_id` atomikliğinin doğru kaldığı SQL testleriyle ispatlanır.

Tercih B text-based yanlış stock seçimi riski yaratıyorsa A’ya geç.

### Legacy compatibility

Eski RPC’ler bir release boyunca çalışmaya devam eder. Legacy string yolunda:

- mümkünse exact unique catalog resolve
- resolve edilemiyorsa eski snapshot davranışı
- yeni frontend ise yalnız semen-aware RPC kullanır

### RPC impact map

`js/api.js:RPC_TABLES` yeni RPC’lerle güncellenir.

**Revizyon 2 (ölçüldü — DOC-004):** `tohumlama`/`dogum` offline kuyrukta ZATEN
queueable (`js/ui.js` `RPC_MAP`). `*_semen` RPC’lerinin `RPC_MAP`’e eklenmesi
**zorunludur** — eklenmezse offline tohumlama girişleri sessizce legacy text
yoluna düşer ve "%100 semen_id" acceptance’ı offline’da kırılır. Aynı
migration’da `tests/unit/api.test.js`’ye RPC_TABLES ↔ RPC_MAP tutarlılık testi
eklenir (BUGS.md SMELL-002 kalıcı kapanır).

## Task 11 — Tohumlama ve tekrar aşım UI controlled selector

**Modify:** `index.html`, `js/app.js`, `js/forms.js`, `js/utils/handlers.js`, tests

**Revizyon 2 — yüzey envanteri (DOC-003, ölçüldü):** sperma girişi bugün ÜÇ
kaynaklıdır ve controlled selector hepsini kapatmak zorundadır:

1. `js/config.js` `SPERMA_LISTESI` sabiti;
2. `js/app.js` `buildSpermaList` — tohumlama geçmişinden datalist (stok DEĞİL);
3. `js/ui.js` stok seçicileri (`getSpermaStok` ~7436, `trSpermaModStok` 7452 —
   `i-sperma-select`/`tr-sperma-select` bunları doldurur) + serbest `geb-sperma`.

"Elle Gir" kapanışı yalnız select'leri düzeltmeye yetmez; datalist + config +
`geb-sperma` yolları da semen identity'ye bağlanmadan free-text üretimi kapanmış
sayılmaz (kabul kriterine üç kaynağın da durumu yazılır).

Mevcut alanlar:

```text
i-sperma-select
i-sperma
tr-sperma-select
tr-sperma
geb-sperma
```

Yeni authoritative hidden value:

```text
i-semen-id
tr-semen-id
geb-semen-id
```

Display snapshot input gerektiği yerde `i-sperma` kalabilir ama submit identity olarak kullanılmaz.

### Stoktan seç

Dropdown `option.value = semen_catalog.id` olur.

Label:

```text
Armada Red — 17 doz
```

Stock amount mevcut `stok` cache’i ile join edilir.

### “Elle Gir” davranışı

Yeni free-text tohumlama yaratma kapatılır.

Elle gir seçeneği:

```text
Yeni boğa/sperma tanımla
  ↓
semen_catalog_upsert RPC
  ↓
created semen_id seç
```

olur.

Kullanıcı geçmişteki unresolved string’i seçmek isterse bunu önce catalog identity’ye dönüştürmelidir.

### Submit

`submitInsem`, `submitTekrarAsim`, manual pregnancy flow yeni RPC’leri çağırır.

### Unit tests

- selector ID gönderir, label değil
- stock row mapping doğru
- manual create sonrası created id seçili
- no selected semen id → submit block
- legacy existing record render hâlâ `t.sperma` ile çalışır

**Phase 6 acceptance:** yeni tohumlama kayıtlarının `%100`’ü `semen_id` taşır; kullanıcı typo ile yeni paternal identity üretemez; eski kayıtlar görüntülenmeye devam eder.

---

# PHASE 7 — Birth → canonical dam/sire edge dual-write

## Task 12 — `dogum_kaydet` pedigree integration

**Create:**

```text
supabase/migrations/20260910000006_dogum_pedigree_integration.sql
```

Mevcut live `dogum_kaydet` gövdesi esas alınır; eski GT body kopyalanmaz.

### Yeni transaction sırası

Mevcut logic korunarak ilgili noktaya:

```text
1 anne resolve
2 olay_id resolve
3 pregnant tohumlama resolve
4 sire node resolve
5 dogum INSERT
6 calf hayvanlar INSERT
   └─ AFTER INSERT trigger farm pedigree node'u garanti eder
7 calf node resolve
8 dam node resolve
9 pedigree_parent_set(dam -> calf, source_type=birth, source_ref=dogum.id)
10 sire biliniyorsa pedigree_parent_set(sire -> calf, source_type=birth, source_ref=dogum.id)
11 legacy baba_bilgi snapshot
12 mevcut görev/protokol/tohumlama yan etkileri
```

Hepsi tek transaction’da.

### Sire resolution

İlk yavru:

```text
son Gebe tohumlama.semen_id
→ semen_catalog.bull_node_id
```

İkinci/üçüncü yavru:

Pregnant tohumlama artık kapanmış olabileceği için aynı `olay_id` içindeki önceki doğumun `source_ref=dogum.id` sire edge’inden bull node resolve edilir.

Fallback:

- legacy `p_baba` / `baba_bilgi` yalnız exact confirmed catalog mapping varsa graph sire olur
- aksi halde snapshot saklanır, sire edge unknown kalır

### İkiz testleri

- first calf: dam+sire
- second calf same olay_id: aynı dam+sire
- second calf after tohumlama `Doğum Yaptı`: sire yine resolve
- unknown sire: sadece dam edge
- graph write fail → doğum transaction tamamen rollback

### Undo test

`dogum` / generated calf geri alındığında:

- calf farm node cascade silinir
- child parentage edges orphan kalmaz
- parent nodes korunur

**Phase 7 acceptance:** yeni doğan her calf dam graph edge alır; semen entity biliniyorsa sire edge atomik oluşur; twin flow doğru.

---

# PHASE 8 — Parentage maintenance / reconciliation UI

## Task 13 — Controlled parent edit surface

**Backend:** `pedigree_parent_set` foundation’da var. Gerekirse `pedigree_parent_clear` / replace action ekle.

**Frontend:** external node sheet veya Soy tabında admin-level küçük aksiyon:

```text
Anne düzelt
Baba düzelt
```

Kurallar:

- raw drag/drop graph editing YOK
- replace confirmation zorunlu
- old/new parent + reason audit edilir
- successful mutation → pedigree cache invalidate
- descendants metrics Phase 9’dan sonra stale yapılır

### Reconciliation queue

Integrity report’taki unresolved paternal rows için basit liste:

```text
"ARMADA RED" → [Armada] [başka seç] [bilinmiyor bırak]
```

Bu UI MVP dışına bırakılabilir; SQL/manual reconciliation yeterliyse task yalnız backend/report olarak tamamlanabilir.

**Acceptance:** yanlış legacy mapping graph’ı raw SQL/client write gerektirmeden düzeltilebilir.

---

# PHASE 9 — Kinship / inbreeding / mating engine

## Task 14 — Metrics schema (Revizyon 2: v2'ye ertelendi — D6)

> v1'de bu task UYGULANMAZ: tablo yok, invalidation yok; Task 15/16/17 on-demand
> RPC hesabı döner (yanıtlar `algorithm_version` taşır). Aşağıdaki şema v2
> referansıdır; "global farm metric cache invalidate" kararı da v2'de gündeme
> gelir. SQL fixture'lar (known-coefficient) v1'de de GEÇERLİDİR — sadece
> kalıcı satır yazımı yoktur.

**Create:**

```text
supabase/migrations/20260910000007_pedigree_metrics_foundation.sql
```

Tables:

```text
pedigree_node_metrics
pedigree_founder_contributions
```

Metric rows versioned olmalı:

- `algorithm_version`
- `pedigree_revision` veya invalidation timestamp/version
- `computed_at`
- depth/completeness metadata

Parentage mutation sonrası affected subject/descendant metrics stale olur. İlk implementasyonda selective invalidation karmaşıksa **global farm metric cache invalidate** kabul edilir; sürü ölçeğinde ucuz ve daha güvenlidir.

## Task 15 — Relationship / F algorithm

**Backend only.**

Önerilen MVP yaklaşım: relevant ancestor closure üzerinde versioned **tabular numerator relationship / kinship-compatible** algorithm.

API ayrımı:

```text
pedigree_kinship(node_a, node_b, depth)
pedigree_inbreeding(node, depth)
```

UI’ye tek belirsiz “akrabalık %” dönme. JSON açık isimlerle:

```json
{
  "relationship": 0.5,
  "kinship": 0.25,
  "expected_offspring_inbreeding_f": 0.25,
  "algorithm_version": "pedigree-v1",
  "completeness": 1.0
}
```

### Known-coefficient fixture gate

SQL fixture minimum:

| Eşleşme | relationship r | expected offspring F |
|---|---:|---:|
| unrelated founders | 0 | 0 |
| parent × offspring | 0.5 | 0.25 |
| full siblings | 0.5 | 0.25 |
| half siblings | 0.25 | 0.125 |
| first cousins | 0.125 | 0.0625 |

Ayrıca inbred ancestor case eklenir; `(1 + F_ancestor)` etkisi doğrulanır.

**Gate:** yukarıdaki fixture değerleri tolerans içinde geçmeden mating UI açılmaz.

## Task 16 — Pedigree completeness

Target generation slots üzerinden completeness hesaplanır.

Dönüşte:

- target depth
- known slots
- total slots
- completeness ratio

Unknown parent branch sessizce unrelated sayılmaz.

## Task 17 — `mating_analyze`

**Create/update:** metrics migration veya ayrı `20260910000008_mating_analyze.sql`

```text
mating_analyze(
  p_cow_hayvan_id text,
  p_semen_id uuid,
  p_depth integer default 6
) -> jsonb
```

Dönüş:

- cow node
- bull node
- merged ancestor graph
- common ancestors
- path/distances
- relationship
- kinship/coancestry
- expected calf F
- completeness cow/bull/combined
- warnings
- algorithm_version

Max depth guard örn. 8.

## Task 18 — Tohumlama modalı mating precheck

Semen seçildikten sonra debounce/lazy online query:

```text
Armada Red
Ortak ata: 1
Beklenen yavru F: 3.1%
Soy kapsama: %82
[Detay]
```

İlk release’te advisory.

**Hard block YOK**; threshold policy ayrı domain kararı olmadan oluşturulmaz.

Network/cache yoksa:

```text
Akrabalık analizi yapılamadı — tohumlama kaydı yine yapılabilir
```

**Phase 9 acceptance:** known fixtures doğru; cow × Armada analizi ortak ancestor graph ile render; low-completeness sonucu açık uyarı taşır.

---

# PHASE 10 — Genetic pool: founder ve breed contribution

## Task 19 — Founder contribution compute (Revizyon 2: on-demand — D6)

> v1'de founder katkısı `pedigree_profile` RPC yanıtının parçası olarak
> on-demand hesaplanır; kalıcı derived-row havuzu (aşağıdaki şema, sürü geneli
> SQL sorgulaması için) v2 kararıdır. Algoritma, normalization kuralı ve
> fixture'lar aynen geçerli.

Server-side propagation:

- ancestry geriye traverse
- gerçek parent bulunmayan node founder boundary
- her parent branch contribution ×0.5
- aynı founder’a farklı path’lerden gelen değerler toplanır
- unknown ancestry ayrı tutulur
- total known + unknown ≈ 1

Derived rows:

```text
subject_node_id
founder_node_id
contribution
algorithm_version
computed_at
```

### Fixture

Basit 2-founder child:

```text
A 50%
B 50%
```

Repeated ancestor fixture contribution’un duplicate node değil path katkısı üzerinden doğru toplandığını doğrular.

## Task 20 — Breed composition

Founder/ancestor contribution, canonical `breed` üzerinden aggregate edilir.

UI:

```text
Holstein        62.5%
Brown Swiss     25.0%
Red Holstein    12.5%
Unknown          0.0%
```

Unknown asla sessiz normalize edilmez.

## Task 21 — “Genetik” subtab

Animal Soy tabındaki ikinci surface:

```text
Pedigree completeness
Inbreeding F
Founder dağılımı
Breed composition
```

Client yalnız server value formatlar.

**Phase 10 acceptance:** selected animal için “genetik havuz” pedigree-derived olarak hesaplanır ve unknown veri açık gösterilir.

---

# PHASE 11 — External EBV/PTA / bull genetics

## Task 22 — Genetic evaluations schema

**Create:**

```text
supabase/migrations/20260910000009_genetic_evaluations.sql
```

Table minimum:

```text
id
farm_id
node_id
source
source_registry
published_at / evaluation_date
trait_code
trait_name
value
unit
reliability
metadata
created_at
```

Bir trait’i kolona sabitlemek yerine long-form trait rows tercih edilir; yeni PTA/EBV trait eklemek migration gerektirmez.

Unique key source + evaluation date + node + trait bazlı tasarlanır.

### Kural

Pedigree-derived değerlerle external evaluation aynı tablo/alan adı altında karıştırılmaz.

## Task 23 — External bull detail/genetic UI

Armada node detail:

```text
Soy
├─ sire/dam
└─ ancestors

Published genetics
├─ milk PTA/EBV
├─ fat
├─ protein
├─ fertility
├─ calving ease
└─ reliability/source/date
```

Source/date/reliability her zaman görünür.

**Phase 11 acceptance:** external bull pedigree + yayınlanmış genetik değer aynı node etrafında gösterilir ama provenance ayrıdır.

---

# PHASE 12 — Final hardening, rollout ve legacy retirement hazırlığı

## Task 24 — Full regression suite

Minimum:

```bash
npm run test:unit
npm run test:local
```

Demo write paths uygunsa:

```bash
npm run test:demo
```

Playwright scenarios:

1. animal → Soy tab open
2. +2 generation
3. farm ancestor node click → openDet
4. external bull click → external detail
5. semen selector returns ID
6. mating precheck renders
7. birth demo flow → calf tree contains dam/sire
8. twin demo flow → both calves same parents
9. sekme açıkken ağ kesilmesi → cached pedigree açılımı (cold-start offline yok — Revizyon 2)
10. cache invalidated after controlled parent mutation

Prod E2E write YOK.

## Task 25 — Performance / safety checks

Target farm ölçeği için:

- 4-gen focal query
- 6-gen mating query
- 8-gen worst allowed query
- Cytoscape render with representative external pedigree size

ölçülür.

Acceptance guideline:

- normal focal query kullanıcıya anlık hissedilmeli
- no unbounded recursive query
- max-depth enforced server-side
- no full pedigree table pull at app startup
- no graph object global `state.animals` benzeri dev array’e kopyalanmamalı

## Task 26 — Security / mutation audit

Kontrol:

- graph DML browser’a açılmış mı?
- yeni SECURITY DEFINER functions `search_path` / same-farm guards açısından repo standardına uyuyor mu?
- cross-farm node/semen link kurulabiliyor mu?
- client `farm_id` gönderebiliyor mu? → göndermemeli
- cycle guard yalnız UI’da mı? → DB’de olmalı
- external input HTML escape ediliyor mu?

## Task 27 — Ground truth ve docs sync

**Modify after migrations proven:**

```text
supabase/migrations/99999999999999_ground_truth.sql
.harness/references/rpc-reference.md
ARCHITECTURE.md
README / README.tr.md yalnız kullanıcı-facing feature anlatımı gerekiyorsa
```

**Revizyon 2 ekleri:**

- **SQL koşum ortamı (DOC-006):** "local/test DB" yoktur. Fixture'lar
  `psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f` ile koşulur (mevcut desen:
  `tests/sql/hayvan_grup_padok_sync_test.sql`); migration ön kontrolü
  `scripts/db-dry-run.sh` (Neon şema aynası, `.env` → `NEON_LSP_URL`) ile
  yapılır. CI otomasyonu kapsam dışıdır (repo test stratejisi: lokal yeter).
- **farm_id ilk uygulama (DOC-005):** pedigree tabloları bu repoda `farm_id`
  taşıyan İLK tablolardır (canlıda bugün hiçbir tabloda farm_id kolonu yok;
  yalnızca `current_farm_id()` helper'ı var). Contract kuralının ilk
  uygulayıcısı olarak: her yeni tabloda `farm_id uuid NOT NULL DEFAULT
  '400b9107-…'` + farm_id ile BAŞLAYAN index — checklist maddesidir.
- **GT regen zamanlaması (SMELL-003):** GT↔canlı drift bugün bile mevcut
  (tohumlama_kaydet gövdesi). GT regen hem bugfix deploy'ından hem pedigree
  migration'larından sonra, ayrı root adımı olarak koşar; bu taskın parçası
  değil, tetikleyicisidir.

Mimari spec ve bu plan repo içine alınacaksa önerilen konum:

```text
.claude/specs/2026-09-10-pedigree-genetics-architecture.md
.claude/plans/2026-09-10-pedigree-genetics-impl.md
```

Canlı schema doğrulandıktan sonra schema snapshot güncellenir; tracked doc canlı schema yerine otorite sayılmaz.

## Task 28 — Legacy read/write retirement (hemen DROP yok)

İlk stabil release sonrası telemetry/inventory:

```text
Yeni tohumlama satırlarında semen_id NULL sayısı = 0 olmalı
Yeni doğan calf'larda dam edge eksik = 0
Semen bilinen doğumlarda sire edge eksik = 0
```

Bundan sonra:

- `tohumlama.sperma` display snapshot olarak kalabilir
- `hayvanlar.baba_bilgi` display/history snapshot olarak kalabilir
- `dogum.baba_bilgi` snapshot olarak kalabilir
- fiziksel column DROP ayrı migration/spec olmadan yapılmaz

---

# Önerilen migration sırası

```text
20260910000001_pedigree_foundation.sql
20260910000002_pedigree_farm_backfill.sql
20260910000003_pedigree_projection_rpc.sql
20260910000004_semen_identity_backfill.sql
20260910000005_semen_controlled_writes.sql
20260910000006_dogum_pedigree_integration.sql
20260910000007_pedigree_metrics_foundation.sql
20260910000008_mating_analyze.sql
20260910000009_genetic_evaluations.sql
```

Gerçek implementasyon sırasında timestamp’ler **next-free kuralıyla** yeniden seçilir; isim sırası konsept sırasını gösterir. Revizyon 2 notu: `G-20260910-UREME-STOK-BUGFIX` bugfix migration’ları `20260910*` aralığını kullanacak — pedigree migration’ları implementasyon anında bugfix setinin ÜSTÜNDEN numaralanır (D4).

---

# Önerilen final repo değişiklik haritası

```text
index.html
  + Soy tab/pane
  + controlled semen hidden IDs
  + vendor + pedigree script tags

js/api.js
  ~ next DB_VER
  + semen_catalog sync
  + pedigree_cache store/helpers
  + pedigree mutation cache invalidation
  + RPC_TABLES entries

js/app.js
  ~ sperma dropdown: stock text -> semen_catalog identity
  ~ legacy buildSpermaList retirement path

js/forms.js
  ~ submitInsem -> *_semen RPC
  ~ submitTekrarAsim -> *_semen RPC
  ~ manual pregnancy controlled identity
  ~ birth UI legacy display compatibility

js/ui.js
  + Soy tab integration only
  - graph implementation burada yığılmaz

js/utils/handlers.js
  + pedigree/semen UI action routing as needed

js/pedigree/
  + pedigree-api.js
  + pedigree-adapter.js
  + pedigree-style.js
  + pedigree-view.js
  + pedigree-controller.js

vendor/
  + cytoscape.min.js
  + elk.bundled.js
  + cytoscape-elk.js

supabase/migrations/
  + 9 phased migrations
  ~ ground_truth only after validation

tests/unit/
  + pedigree-api.test.js
  + pedigree-adapter.test.js
  + pedigree-cache.test.js
  ~ api.test.js
  + semen-selector/param contract tests as appropriate

tests/sql/
  + pedigree_graph_test.sql
  + pedigree_metrics_test.sql (ayrı dosya tercih edilir)

tests/
  + pedigree.spec.js
```

---

# Rollout gate matrisi

| Gate | Açılması için şart | Sonraki kabiliyet |
|---|---|---|
| G0 | baseline + live inventory | migration başlat |
| G1 | graph schema invariant tests green | farm backfill |
| G2 | integrity report + maternal backfill clean | read projection |
| G3 | subgraph RPC + offline cache green | Soy UI |
| G4 | external bull/semen mapping reviewed | paternal backfill |
| G5 | controlled selector + semen-aware writes green | new writes canonical |
| G6 | birth/twin SQL tests green | automatic calf parentage |
| G7 | known kinship coefficient fixtures green | mating precheck |
| G8 | founder totals/completeness tests green | genetic pool UI |
| G9 | full local/demo regression green | production rollout |

---

# Definition of Done — ilk “Pedigree & Genetics v1”

V1 tamam sayılmak için:

1. Her farm hayvanı bir ve yalnız bir pedigree node ile resolve edilir.
2. External boğa/ata farm animal oluşturmadan graph’a girebilir.
3. Farm animal insert path’lerinin tamamı trigger ile node üretir.
4. Parentage graph cycle kabul etmez.
5. Mevcut güvenli maternal history backfill edilmiştir.
6. Human-reviewed semen aliases canonical bull identity’lerine bağlanmıştır.
7. Yeni tohumlama `semen_id` ile kaydolur; free-text identity oluşturmaz.
8. Yeni doğum calf için dam edge, semen biliniyorsa sire edge üretir.
9. İkiz/üçüz aynı biological parents’i doğru paylaşır.
10. Animal detail’den focal pedigree tree açılır.
11. Global graph full-sync edilmez; projection on-demand/cache’tir.
12. Cow × semen common ancestors bulunur.
13. Relationship/kinship/F known fixtures doğru sonuç verir.
14. Her F sonucu pedigree completeness ile birlikte gelir.
15. Founder/breed contribution toplamları ve unknown payı gösterilir.
16. Frontend hiçbir pedigree/genetics coefficient hesaplamaz.
17. External EBV/PTA provenance/source/date/reliability ile ayrı katmanda tutulur.
18. Existing legacy animal/reproduction/history UI kırılmaz.
19. Generic `geri_al` calf/new animal node lifecycle’ını orphan bırakmadan çalışır.
20. Unit + SQL fixture + local Playwright gates green’dir.

---

# Self-review — implementasyon planı denetimi

Plan mimari spec ve repo gerçekleriyle tekrar çapraz kontrol edildi. Sonuç:

### 1. `farm_animal_id ON DELETE SET NULL` düzeltildi

Repo’daki `geri_al()` generic DELETE yaptığı için SET NULL orphan/invalid `farm_animal` node bırakabilirdi. Cascade lifecycle planlandı.

### 2. Node creation blast radius küçültüldü

Yalnız `hayvan_ekle` değiştirilse `dogum_kaydet` ve gelecekteki import yolları node üretmeme riski taşıyordu. AFTER INSERT trigger + idempotent helper seçildi.

### 3. Full graph IDB sync tekrar reddedildi

Mevcut `TABLES/FETCHERS` modeli bütün tablo snapshot’ı çekiyor. Pedigree graph büyüdükçe startup maliyetini lineer artırmamak için graph projection-cache olarak kaldı. Yalnız küçük `semen_catalog` full-sync edildi.

### 4. Existing reproduction RPC’lerini tek release’te kırma reddedildi

Mevcut browser deployment ile DB deploy atomik değil. Yeni semen-aware RPC entry point’leri + legacy compatibility window, signature-overload karmaşasından daha güvenli kabul edildi.

### 5. Semen identity fuzzy auto-merge reddedildi

Yanlış biological identity, eksik identity’den daha tehlikeli. Belirsiz legacy string unknown kalabilir; human-reviewed mapping olmadan merge edilmez.

### 6. Twin sire resolution netleştirildi

İkinci yavruda `Gebe` tohumlama artık kapanmış olabilir. Sire, aynı `olay_id` içindeki ilk doğumun parentage provenance edge’inden tekrar kullanılacak; string heuristic’e dönülmeyecek.

### 7. Parentage cycle check concurrency sertleştirildi

Sadece “önce ancestor query sonra insert” eşzamanlı mutation’da teorik yarış yaratabilir. Parentage mutation farm-scope advisory transaction lock ile serialize edilir.

### 8. Genetic value scope tekrar sınırlandı

Pedigree-derived F/founder/breed değerleri external EBV/PTA ile aynı skor olarak birleştirilmiyor. Internal breeding value hâlâ ayrı gelecekteki spec’tir.

### 9. Mating threshold hard-block reddedildi

İlk release advisory olacak. Bilimsel/domain threshold ayrıca tanımlanmadan “F > X ise tohumlamayı engelle” kuralı eklenmeyecek.

### 10. Planı bloke eden ek doküman bulunmadı

Mimari ve kod dump’ı implementation plan için yeterli. Uygulama sırasında gerekli ek girdi **doküman değil canlı veri envanteri**: semen/baba string mapping ve ET kullanım kararı.

---

# Executor için önerilen çalışma biçimi

Bu iş tek agent’a “hepsini yap” diye verilmemeli. En doğal bölümleme:

```text
Lead / root
│
├─ Worker A — SQL foundation + integrity/backfill
├─ Worker B — projection RPC + cache/API
├─ Worker C — Cytoscape/ELK + Soy UI
├─ Worker D — semen normalization + reproduction integration
└─ Worker E — kinship/founder algorithms + fixtures
```

Ama aynı migration/function alanına paralel iki worker yazmamalı. Özellikle:

```text
tohumlama_kaydet
dogum_kaydet
ground_truth.sql
js/api.js
index.html
```

tek owner üzerinden sırayla değiştirilmelidir.

En güvenli execution order:

```text
A foundation
→ A/B projection
→ C read-only UI
→ D semen controlled writes
→ D birth integration
→ E metrics
→ C mating/genetic UI
→ full review
```

Bu sıra sayesinde read-only pedigree feature, reproduction write refactor’ından bağımsız olarak erken doğrulanabilir; en riskli mutation değişiklikleri ancak graph ve test zemini hazır olduktan sonra açılır.
