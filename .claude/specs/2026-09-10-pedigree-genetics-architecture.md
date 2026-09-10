# EgeSüt ERP — Pedigree, Soy Graph ve Genetik Katman Mimari Spec

**Durum:** Tasarım / implementasyon öncesi spec — **REVİZYON 2**  
**İncelenen dump:** `egesut-dump.zip`, HEAD `a3d8bc2` (2026-09-09)  
**Hedef:** Mevcut EgeSüt ERP üreme akışına, çiftlik hayvanları ile dış boğa/sperma soylarını aynı biyolojik graph üzerinde birleştiren; focal tree, ortak ata, akrabalık, inbreeding, founder/breed katkısı ve ileride genetik değerlendirme/çiftleşme skoru üretebilen bir katman eklemek.

> **REVİZYON 2 (2026-09-10) — repo + canlı DB doğrulaması sonrası:**
>
> 1. **v1 kapsamı = Faz 0-10 karşılığı** (foundation → soy ağacı UI → semen/doğum
>    entegrasyonu → kinship/mating → founder/breed havuzu). Dış EBV/PTA profilleri
>    ve legacy retirement **v2'ye** taşındı (bkz. §15).
> 2. **Metrik cache tabloları v1'den çıkarıldı** (§4.6/§4.7): kinship, F,
>    founder katkısı, completeness **on-demand RPC** hesabıdır; kalıcı cache
>    ancak ölçümle gerekçelenirse v2'de eklenir.
> 3. **Stok düşümü okuması canlı ölçümle düzeltildi + BUG-001 refuted (r12-F79):**
>    canlıda `tohumlama_kaydet` ve `tohumlama_tekrar_kaydet` ILIKE desenle
>    düşürüyor; `planli_tohumlama_kaydet` koşulsuz `tohumlama_kaydet`'e delege
>    eder ve düşüm delegasyonla gerçekleşir (davranışsal probe + tracked
>    migration teyidi — BUGS.md BUG-001 REFUTED). Eşleşmede boş-string joker
>    riski real (BUG-002). `gebelik_kaydet_manual` canlıda 42804 ile
>    kırık (BUG-003) — üreme write entegrasyon fazının ön koşulu.
> 4. **Layout kararı**: v1 focal tree Cytoscape yerleşik `breadthfirst`
>    yerleşimiyle açılır (0 ek byte); ELK yalnız mating overlay için lazy-load
>    edilir (§9.2-9.3).
> 5. **Offline kabulü gerçekçileştirildi**: app shell cold-start offline
>    değildir (SW stub); cache senaryosu "sekme açıkken ağ kesilmesi"dir (§10).
> 6. **GT↔canlı drift kayıtlı** (`BUGS.md` SMELL-003): tracked ground truth
>    rehberdir, canlı şema otoritedir; GT regen deploy sonrası ayrı adımdır.
>
> 7. **Canlı ölçüm iddialarının kanıt dosyası:**
>    `.claude/reviews/2026-09-10-live-probe-evidence.md` (root, salt-okunur
>    pg katalog ölçümü; nokta-zamanlıdır, teyit gerektiğinde sorgu yeniden koşulur).
>
> 1, 2 ve 4 numaralı kararlar owner onayıyla üzerine yazılabilir (overridable
> defaults); dayanakları İndirilenler'deki Revizyon 1 metniyle karşılaştırmalı
> review'dur.

---

## 1. Karar özeti

Bu özellik **tree olarak saklanmayacak**. Kanonik veri modeli **directed acyclic pedigree graph (DAG)** olacak; tree yalnızca seçili hayvana göre üretilen bir UI projection olacak.

Temel kararlar:

1. `hayvanlar` yalnız çiftlikteki operasyonel hayvanları temsil etmeye devam eder.
2. Armada gibi çiftlikte fiziksel olarak bulunmayan boğalar ve onların anne/baba/nine/dede soyları `hayvanlar` tablosuna sahte kayıt olarak sokulmaz.
3. Bunun yerine bütün biyolojik bireyleri tek kimlik uzayında birleştiren yeni `pedigree_nodes` tablosu kurulur.
4. `pedigree_parentage` parent → child edge tablosu kanonik soy graph'ını oluşturur.
5. `hayvanlar.anne_id`, `hayvanlar.baba_bilgi`, `dogum.baba_bilgi` ve `tohumlama.sperma` mevcut sistem için compatibility/snapshot alanları olarak korunur; yeni genetik hesaplarda authoritative kaynak değildir.
6. Sperma bir metin değil, kontrollü entity olur: `semen_catalog`. Bir semen kaydı bir `pedigree_node` boğasına bağlanır; isterse mevcut `stok` satırına bağlanır.
7. Tohumlama gerçekleştiğinde pedigree edge oluşmaz. Yalnız seçilen semen entity'si kaydedilir. Yavru doğduğunda `dogum_kaydet` transaction'ı yavru node'unu ve dam/sire edge'lerini oluşturur.
8. Akrabalık, inbreeding, founder contribution ve mating risk **PostgreSQL/RPC katmanında** hesaplanır. Frontend yalnız projection/render yapar; bu mevcut “frontend hesap yapmaz” invariant'ıyla uyumludur.
9. Görselleştirme: **Cytoscape.js**. Focal tree yerleşimi gömülü `breadthfirst`; ELK yalnız mating overlay'de lazy-load (Revizyon 2). Tree-sitter, Graphology, Neo4j veya ayrı graph DB MVP için kullanılmaz.
10. İlk fazda “genetik değer” tek bir uydurma 0–100 puanı olmayacak. Pedigree metrikleri, yayınlanmış EBV/PTA vb. değerlendirmeler ve ileride çiftliğin fenotip verisinden üretilecek internal breeding index birbirinden ayrı tutulur.

---

## 2. Mevcut EgeSüt durumunun mimari okuması

### 2.1 Uygulama stack'i

Mevcut uygulama:

- Vanilla JS, tek `index.html`
- build/bundle step yok
- Supabase JS browser SDK
- Supabase PostgreSQL + stored procedure/RPC ağırlıklı backend
- IndexedDB `egesut_v12`, mevcut `DB_VER=24`
- GitHub Pages deploy
- Playwright E2E + Node unit testleri
- Service Worker bilinçli olarak fetch cache yapmıyor

Bu feature mevcut stack'i değiştirmemeli.

### 2.2 Mevcut soy bilgisinin problemi

Şu an soy bilgisi normalize değil:

```text
hayvanlar
  anne_id      -> text, çiftlik hayvanına referans olabiliyor
  baba_bilgi   -> text snapshot

tohumlama
  sperma       -> text

dogum
  anne_id      -> hayvanlar FK
  baba_bilgi   -> text snapshot

stok
  kategori='Sperma'
  urun_adi     -> UI'da sperma adı olarak kullanılıyor
```

Doğum RPC'si babayı son `Gebe` tohumlamanın `sperma` text'inden alıyor ve hem `dogum.baba_bilgi` hem yeni buzağının `hayvanlar.baba_bilgi` alanına kopyalıyor.

Bu mekanizma operasyonel geçmiş için yeterli, fakat şu soruları güvenilir cevaplayamaz:

- Armada'nın babası kim?
- Armada ile 136'nın ortak atası var mı?
- Aynı boğa iki farklı yazımla sisteme girilmiş mi?
- Yavrunun sire node'u hangisi?
- 6 kuşak soyda tekrarlanan ortak ata kaç kez geçiyor?
- beklenen yavru inbreeding'i nedir?
- founder katkıları / breed composition nedir?

### 2.3 Mevcut kodla uyulması gereken invariant'lar

Bu tasarım aşağıdakileri bozmamalı:

- karmaşık writes yalnız RPC
- frontend domain hesabı yapmaz
- yeni tenant-scoped tablolar `farm_id` alır
- yeni controlled entity free-text ile kalıcı ilişki kurmaz
- mevcut `dogum_kaydet` ikiz/üçüz için `olay_id` modelini korur
- `1 dogum row = 1 calf` modeli korunur
- `RPC_TABLES`, IndexedDB ve `pullTables` entegrasyonu bilinçli yapılır
- legacy kolonlar tek release'te kaldırılmaz

---

## 3. Domain modeli

### 3.1 Üç farklı kavram birbirine karıştırılmamalı

```text
FARM ANIMAL            PEDIGREE SUBJECT          SEMEN PRODUCT
hayvanlar              pedigree_nodes           semen_catalog
operasyon              biyolojik kimlik          üreme materyali

136 -----------------> node:H136
Armada (farmda yok) --> node:ARMADA <------------- semen:Armada-Red
```

`hayvanlar` ile `pedigree_nodes` aynı şey değildir.

- `hayvanlar`: çiftlik operasyonlarında yaşayan/çıkmış gerçek sürü kayıtları
- `pedigree_nodes`: graph içinde yer alabilecek herhangi bir biyolojik sığır
- `semen_catalog`: belirli bir sire'dan gelen, tohumlamada seçilebilir semen entity'si

Bu ayrım dış soyları sisteme sokarken `hayvanlar` tablosunu kirletmeyi engeller.

### 3.2 Graph yönü

Kanonik yön:

```text
PARENT ---> CHILD
```

Örnek:

```text
Armada ----SIRE----> Calf-204
136 -------DAM-----> Calf-204
```

Bu yön descendants sorgularını doğal kılar; ancestors sorgusu edge'i ters yönde traverse eder.

### 3.3 Graph DAG olmak zorunda

Pedigree graph döngü kabul etmez.

Geçersiz örnek:

```text
A -> B -> C -> A
```

Parentage write RPC'si yeni edge eklemeden önce “parent adayı child'ın descendant'ı mı?” kontrolü yapmak zorundadır. UI kontrolü yalnız UX; authoritative guard DB'dedir.

---

## 4. Önerilen veri modeli

### 4.1 `pedigree_nodes`

Bütün soy graph node'larının kimlik tablosu.

```sql
CREATE TABLE public.pedigree_nodes (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  farm_id           uuid NOT NULL DEFAULT '400b9107-a85e-4126-af2c-fd7fe73fb68e',

  farm_animal_id    text NULL REFERENCES public.hayvanlar(id) ON DELETE CASCADE,  -- D1: geri_al DELETE orphan node bırakmasın (plan D1 ile tek otorite)
  node_kind         text NOT NULL CHECK (node_kind IN ('farm_animal','external_animal')),

  display_name      text NULL,
  registry_system   text NULL,
  registry_code     text NULL,
  sex               text NULL,
  breed             text NULL,
  birth_date        date NULL,
  country_code      text NULL,

  metadata          jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at        timestamptz NOT NULL DEFAULT now(),
  updated_at        timestamptz NOT NULL DEFAULT now(),

  -- node_kind ↔ farm_animal_id invariant'i DDL'de (r3-F8):
  CHECK ((node_kind = 'farm_animal'     AND farm_animal_id IS NOT NULL)
      OR (node_kind = 'external_animal' AND farm_animal_id IS NULL)),

  UNIQUE (farm_id, id),              -- composite FK hedefi (cross-farm enforcement, §4.2)
  UNIQUE (farm_id, farm_animal_id)
);
```

Kurallar:

- `node_kind='farm_animal'` ise `farm_animal_id` zorunlu.
- Farm animal'ın ad/ırk/cinsiyetinin authoritative kaynağı `hayvanlar`; node'daki external alanlar kullanılmaz.
- `external_animal` Armada veya onun ataları için kullanılır.
- Registry code biliniyorsa aynı dış hayvanın ikinci kez yaratılması engellenir. Bunun için `(farm_id, registry_system, registry_code)` üzerinde partial unique index önerilir.
- `farm_id` zorunlu: bu graph çiftliğin operasyonel/genetik knowledge alanıdır ve `.harness/contract.md`'deki farm_id kuralının kapsamına girer (owner-local `.claude/farm-id-discipline.md` kopyası tracked değildir; otorite contract'tır).

### 4.2 `pedigree_parentage`

Kanonik biyolojik parentage edge tablosu.

```sql
CREATE TABLE public.pedigree_parentage (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  farm_id           uuid NOT NULL DEFAULT '400b9107-a85e-4126-af2c-fd7fe73fb68e',

  -- composite FK çiftleri: cross-farm edge DDL seviyesinde imkânsız (Revizyon 2)
  parent_farm_id    uuid NOT NULL,
  parent_node_id    uuid NOT NULL,
  child_farm_id     uuid NOT NULL,
  child_node_id     uuid NOT NULL,
  parent_role       text NOT NULL CHECK (parent_role IN ('dam','sire')),

  source_type       text NOT NULL CHECK (source_type IN ('birth','manual','import','reconcile')),
  source_ref        text NULL,
  evidence          jsonb NOT NULL DEFAULT '{}'::jsonb,   -- r3-F2: doğum edge'i {"tohumlama_id","semen_id"} taşır; rebuild/audit iddiasının sorgulanabilir kontratı
  confidence        numeric NOT NULL DEFAULT 1.0 CHECK (confidence >= 0 AND confidence <= 1),
  created_at        timestamptz NOT NULL DEFAULT now(),

  FOREIGN KEY (parent_farm_id, parent_node_id)
    REFERENCES public.pedigree_nodes(farm_id, id) ON DELETE CASCADE,
  FOREIGN KEY (child_farm_id, child_node_id)
    REFERENCES public.pedigree_nodes(farm_id, id) ON DELETE CASCADE,
  CHECK (parent_node_id <> child_node_id),
  CHECK (farm_id = parent_farm_id AND farm_id = child_farm_id),
  UNIQUE (farm_id, child_node_id, parent_role)
);
```

**Cross-farm enforcement (Revizyon 2, yapısal):** farm-scope yalnız RPC
proseunde değil DDL'de taşınır — `pedigree_nodes` üzerinde `UNIQUE (farm_id, id)`
bulunur; `pedigree_parentage` kolonları `(parent_farm_id, parent_node_id)` /
`(child_farm_id, child_node_id)` çiftleri olarak tanımlanır ve
`FOREIGN KEY (parent_farm_id, parent_node_id) REFERENCES pedigree_nodes(farm_id, id)`
(aynısı child için) ile bağlanır. Böylece cross-farm edge DB seviyesinde
imkânsızdır; RPC'deki same-farm check ikinci savunma katmanıdır. Ayrıca graph
tablolarına (`pedigree_nodes`, `pedigree_parentage`) doğrudan client GRANT'i
verilmez — erişim yalnız RPC'dir (bkz. implementasyon planı Task 1.3).

MVP'de bir child için en fazla bir confirmed dam ve bir confirmed sire vardır.

`source_type/source_ref` graph'ın **rebuild edilebilir** ve audit edilebilir olmasını sağlar:

```text
birth     + dogum.id (evidence metadata: tohumlama_id + semen_id olabilir)
manual    + user operation ref
import    + external pedigree import id
reconcile + migration/backfill
```

### 4.3 `semen_catalog`

Mevcut `stok` ile biyolojik sire kimliği arasındaki kontrollü köprü.

```sql
CREATE TABLE public.semen_catalog (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  farm_id           uuid NOT NULL DEFAULT '400b9107-a85e-4126-af2c-fd7fe73fb68e',
  bull_farm_id      uuid NOT NULL,                    -- r3-N3: farm-scope ilişkisel kilit
  bull_node_id      uuid NOT NULL,
  stock_id          text NULL REFERENCES public.stok(id) ON DELETE SET NULL,

  FOREIGN KEY (bull_farm_id, bull_node_id)
    REFERENCES public.pedigree_nodes(farm_id, id),
  CHECK (farm_id = bull_farm_id),                     -- r4-F14: satır kendi farm'ına kilitli

  code              text NULL,
  display_name      text NOT NULL,
  supplier          text NULL,
  semen_type        text NULL,
  active            boolean NOT NULL DEFAULT true,
  metadata          jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at        timestamptz NOT NULL DEFAULT now(),

  UNIQUE (farm_id, stock_id)
);
```

MVP varsayımı: mevcut bir `stok` sperma satırı tek semen catalog kaydına bağlanır. İleride batch/lot takibi gerekirse `semen_batches` ayrı tablo olarak eklenebilir; ilk fazda gereksizdir.

**Guard'lar (r2-review):** `bull_node_id` bağlantısı composite FK ile farm-scope taşır
(`(bull_farm_id, bull_node_id) → pedigree_nodes(farm_id, id)`) ve `semen_catalog_upsert`
RPC'sinde bull node `sex='male'` zorunluluğu ile `stock_id` varsa `stok.kategori='Sperma'`
kontrolü yapılır — geçerli FK bile anlamsız bağ kuramaz.

### 4.4 `tohumlama` genişletmesi

```sql
ALTER TABLE public.tohumlama
  ADD COLUMN semen_id uuid NULL REFERENCES public.semen_catalog(id),
  ADD COLUMN semen_id_onceki uuid NULL REFERENCES public.semen_catalog(id);
  -- semen_id_onceki (r3-N17): tekrar aşım p_force_semen ile kimlik değişince
  -- eski kanonik değer buraya taşınır (tek adım zincir; tam deneme tarihi v2).
```

`tohumlama.sperma` hemen kaldırılmaz.

Yeni write davranışı:

```text
semen_id  = authoritative relationship
sperma    = immutable/display snapshot
```

Geçiş döneminde legacy kayıtların `semen_id` değeri NULL olabilir.

Yeni tohumlamada UI artık serbest `sperma` text'i değil `semen_id` gönderir. Stokta olmayan yeni semen gerekiyorsa önce `semen_catalog` entity'si oluşturulur; böylece yeni legacy free-text üretilmez.

### 4.5 `genetic_evaluations` (v2'ye ertelendi — Revizyon 2)

> Dış EBV/PTA katmanı v2 kapsamındadır (D5). Şema, implementasyon planı
> Task 22 ile tek biçime indirildi: JSON blob yerine **long-form trait
> satırları** — yeni trait eklemek migration gerektirmez.

Armada gibi dış boğaların yayımlanmış genetik değerlerini pedigree metriklerinden ayırmak için.

```sql
CREATE TABLE public.genetic_evaluations (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  farm_id           uuid NOT NULL DEFAULT '400b9107-a85e-4126-af2c-fd7fe73fb68e',
  node_farm_id      uuid NOT NULL,                    -- r4-F15: tenant kilidi composite FK ile
  node_id           uuid NOT NULL,

  source             text NOT NULL,
  source_registry    text NULL,
  evaluation_date    date NOT NULL,   -- NULL unique-key'te tekilleştirmez (r2-N15); tarih bilinmiyorsa kaynak periyodu girilir
  trait_code         text NOT NULL,
  trait_name         text NULL,
  value              numeric NOT NULL,
  unit               text NULL,
  reliability        numeric NULL,
  metadata           jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at         timestamptz NOT NULL DEFAULT now(),

  FOREIGN KEY (node_farm_id, node_id)
    REFERENCES public.pedigree_nodes(farm_id, id) ON DELETE CASCADE,
  CHECK (farm_id = node_farm_id),

  UNIQUE (farm_id, node_id, source, evaluation_date, trait_code)
);
```

Örnek satırlar:

```text
Armada | CDC | 2026-08 | milk_pta  | Milk PTA |  +780 | kg | 0.82
Armada | CDC | 2026-08 | fat_pta   | Fat PTA  |   +42 | kg | 0.79
Armada | CDC | 2026-08 | calf_ease | Calving Ease | 106 | idx | 0.71
```

Kaynak + değerlendirme tarihi + trait bazlı satır korunur; UI yalnız bildiği
trait kodlarını anlamlandırır, bilinmeyenleri etiketiyle listeler.

### 4.6 `pedigree_node_metrics` — derived cache (v2'ye ertelendi)

> **REVİZYON 2:** Bu tablo v1'de YOKTUR — inbreeding F, known_generation_depth,
> pedigree_completeness on-demand RPC yanıtlarında döner. Kalıcı cache ve
> invalidation mekaniği ancak ölçümle gerekçelenirse v2'de eklenir. Şema aşağıda
> referans amaçlı duruyor.

Source-of-truth değildir. Küçük özet metrikler burada tutulur; founder dağılımı ayrı satırlara ayrılır.

```sql
CREATE TABLE public.pedigree_node_metrics (
  farm_id                uuid NOT NULL,
  node_id                 uuid NOT NULL REFERENCES public.pedigree_nodes(id) ON DELETE CASCADE,
  algorithm_version       integer NOT NULL,
  calculated_at           timestamptz NOT NULL DEFAULT now(),

  inbreeding_f            numeric NULL,
  known_generation_depth  integer NOT NULL DEFAULT 0,
  pedigree_completeness   numeric NULL,
  founder_count           integer NULL,
  breed_composition       jsonb NOT NULL DEFAULT '{}'::jsonb,

  PRIMARY KEY (farm_id, node_id, algorithm_version)
);
```

### 4.7 `pedigree_founder_contributions` — queryable derived pool (v2'ye ertelendi)

> **REVİZYON 2:** v1'de founder katkıları `pedigree_profile`/`mating_analyze`
> RPC yanıtlarında on-demand döner; satır bazlı kalıcı havuz (aşağıdaki şema,
> sürü geneli SQL sorgulaması için) v2 kararıdır. "Genetik havuz" değeri v1'de
> tek hayvan görünümü + mating analiziyle sağlanır.

“Genetik havuz” bu feature'ın merkezinde olduğu için founder contribution'ı tek bir JSON blob'a gömmek yerine satır bazında saklamak daha doğru olur. Böylece aynı founder'ın sürüdeki etkisi, iki hayvanın founder-overlap'i ve zaman içindeki havuz yoğunlaşması SQL ile doğrudan sorgulanabilir.

```sql
CREATE TABLE public.pedigree_founder_contributions (
  farm_id             uuid NOT NULL,
  subject_node_id     uuid NOT NULL REFERENCES public.pedigree_nodes(id) ON DELETE CASCADE,
  founder_node_id     uuid NOT NULL REFERENCES public.pedigree_nodes(id) ON DELETE CASCADE,
  algorithm_version   integer NOT NULL,
  contribution        numeric NOT NULL CHECK (contribution >= 0 AND contribution <= 1),
  calculated_at       timestamptz NOT NULL DEFAULT now(),

  PRIMARY KEY (farm_id, subject_node_id, founder_node_id, algorithm_version)
);
```

> **Revizyon 2 (D6):** v1'de kalıcı satır/staleness YOKTUR — hesap her istekte
> tazedir, parentage değişimi bir sonraki sorguya otomatik yansır. Aşağıdaki
> cümleler yalnız v2 cache tasarımı içindir.

Parentage değişince ilgili descendant metrikleri ve founder contribution satırları stale kabul edilir ve yeniden hesaplanır. MVP sürü boyutunda eager rebuild bile ucuz olacaktır; daha sonra dirty-descendant queue eklenebilir.

### 4.8 Tenant/RLS ve write sınırı

Yeni operational/genetic tablolar `.harness/contract.md`'deki farm_id disiplinini izler (owner-local `.claude` kopyası tracked değildir):

- `farm_id UUID NOT NULL DEFAULT current/real farm id`
- mevcut geçiş politikasına uygun RLS açılır; bugün proje `USING (true)` yaklaşımını kullanıyorsa yeni tablolar farklı bir güvenlik modeli icat etmez
- frontend doğrudan parentage mutation yapmaz; write'lar RPC üzerinden gider
- RPC'ler `current_farm_id()` ile farm stamp eder ve cross-farm node bağlamayı reddeder
- grants/migration idempotency mevcut migration standartlarına uyar

Bu spec multi-tenant ürünleştirme yapmıyor; fakat bugün yaratılan graph tablolarının yarın tenant migration'ını engellememesini garanti ediyor.

---

## 5. Source of truth ve invariant'lar

En kritik konu duplicate data'nın split-brain olmamasıdır.

### 5.1 Authoritative alanlar

| Bilgi | Authoritative kaynak |
|---|---|
| çiftlik hayvanının operasyonel kartı | `hayvanlar` |
| doğum olayı / calf occurrence | `dogum` |
| semen kullanımı | `tohumlama.semen_id` |
| semen → sire | `semen_catalog.bull_node_id` |
| soy graph parentage | `pedigree_parentage` |
| dış hayvan kimliği | `pedigree_nodes` |
| yayımlanmış genetik değerlendirme | `genetic_evaluations` |
| F/completeness | hesap motoru; `pedigree_node_metrics` yalnız cache |
| founder katkıları / genetik havuz | hesap motoru; `pedigree_founder_contributions` yalnız cache/read model |

### 5.2 Legacy snapshot alanları

Aşağıdakiler compatibility için kalır:

```text
hayvanlar.anne_id
hayvanlar.baba_bilgi
dogum.baba_bilgi
tohumlama.sperma
```

Yeni genetik sorgular bunları graph yerine okumaz.

`hayvanlar.anne_id` mevcut UI ve ikiz/helper kodunda yoğun kullanıldığı için erken kaldırılmamalıdır. Yeni `dogum_kaydet` transaction'ı hem legacy alanı hem graph edge'ini aynı transaction içinde yazar.

### 5.3 Graph rebuild ilkesi

Farm doğumlarından gelen edge'ler provenance taşıdığı için gerektiğinde graph tekrar üretilebilir:

```text
dogum + hayvanlar + tohumlama.semen_id
             ↓
      pedigree_reconcile
             ↓
    pedigree_parentage
```

Manual/import external lineage edge'leri ise doğrudan graph source-of-truth'tur ve reconcile sırasında silinmez.

---

## 6. Write akışları

### 6.1 Hayvan ekleme

Mevcut `hayvan_ekle` başarılı olduğunda:

```text
hayvanlar INSERT
    ↓
pedigree_ensure_farm_node(hayvan_id)
```

Manual parent seçimi ilk fazda zorunlu değildir. UI daha sonra anne/sire selector kazanabilir.

### 6.2 Semen oluşturma

Yeni RPC:

```text
semen_catalog_upsert(...)
   ├─ dış bull node resolve/create
   ├─ stock_id bağla (opsiyonel)
   └─ semen_catalog write
```

Armada için:

```text
pedigree_node: ARMADA (external male)
        ↑
semen_catalog: Armada Red
        ↑
stock: Armada Red / 17 doz
```

Armada'nın dam/sire/ancestor node'ları sonradan aynı graph'a eklenebilir.

### 6.3 Tohumlama

Yeni hedef akış:

```text
UI semen entity seçer
   ↓
tohumlama_kaydet(
  p_hayvan_id,
  p_semen_id,
  ...
)
   ↓
DB semen_catalog kaydını resolve eder
   ↓
tohumlama INSERT
  semen_id = UUID
  sperma   = display snapshot
   ↓
mevcut stok düşümü semen_catalog.stock_id üzerinden
```

**Stok düşümü (Revizyon 2 + r12-F79 düzeltmesi):** canlıda `tohumlama_kaydet` ve
`tohumlama_tekrar_kaydet` ILIKE string eşleşmesiyle düşürüyor;
`planli_tohumlama_kaydet` `tohumlama_kaydet`'e DELEGE eder — düşüm delegasyonla
zaten gerçekleşir (BUG-001 refuted; planli'ye ayrı düşüm eklemek ÇİFT düşüm
üretirdiğinden YASAK). Boş `p_sperma` joker gibi davranıp
rastgele satırdan düşebiliyor (`BUGS.md` BUG-001/BUG-002 — fix işi
`G-20260910-UREME-STOK-BUGFIX` goal'unda ayrı yürüyor). Pedigree burada
davranış icat ETMEZ: semen-aware yollar, bugfix'lerle düzeltilmiş kuralı
(boş/whitespace sperma düşmez — `btrim(p_sperma) <> ''` guard; exact-first; üç yol ortak kural) `semen_catalog.stock_id`
üzerinden taşır. Bugfix merge edilmeden bu fazın write kontratı dondurulmaz.

**Tekrar aşım kimlik kuralı (r2-N17):** mevcut `tohumlama_tekrar_kaydet` aynı
tohumlama satırını günceller — önceki denemenin metni snapshot'ta kalır ama
kanonik kimlik yalnız tek kolonda yaşayacağı için ezilir. Kural: tekrar
varyantı, satırda farklı ve NULL-olmayan bir `semen_id` varsa sessiz ezmez;
açık `p_force_semen boolean default false` ister. Ezilen denemenin kimliği
`islem_log` snapshot'ında ve `sperma` metninde korunur. Deneme-başı tam kimlik
tarihi (per-attempt table) bilinçli olarak v2'dir.

**Tohumlama parentage edge üretmez.** Henüz doğmuş child yoktur.

### 6.4 Doğum

`dogum_kaydet` mevcut ikiz modeli korunarak genişletilir:

```text
1. anne resolve
2. son Gebe tohumlama resolve
3. semen_id -> semen_catalog -> bull_node
4. dogum row oluştur
5. calf hayvanlar row oluştur
6. calf pedigree node oluştur
7. dam node resolve
8. parentage: dam -> calf
9. sire biliniyorsa parentage: bull -> calf
10. legacy baba_bilgi snapshot doldur
11. mevcut görev/protokol yan etkileri
```

Bütün 1–11 aynı DB transaction'ı içindedir.

İkiz/üçüzde her calf ayrı node'dur, hepsi aynı `dogum.olay_id` olayına bağlıdır ve aynı dam/sire edge setine sahip olur.

**MVP biyolojik anne varsayımı:** mevcut EgeSüt doğum modeli `dogum.anne_id` değerini hem doğuran hem genetik dam kabul ediyor. Embriyo transferi kullanılıyorsa bu varsayım geçersizdir; o durumda Phase 2'den önce `genetic_dam` ile `recipient/gestational_dam` ayrımı eklenmelidir. ET yoksa mevcut `dam` edge modeli doğrudur.

### 6.5 Parentage düzeltme

Graph node/edge'i frontend'den raw `db.from().update()` ile değiştirilmez.

Önerilen RPC:

```text
pedigree_parent_set(child_node_id, role, parent_node_id, source_note)
```

RPC:

- same-node reddi
- cycle reddi
- duplicate confirmed role reddi / bilinçli replace akışı
- sex consistency uyarısı/guard'ı
- audit (`islem_log` veya domain-specific audit)
- descendant metric invalidation

uygular.

---

## 7. Query ve calculation API

### 7.1 Projection RPC

```text
pedigree_subgraph(
  p_focus_node_id,
  p_ancestor_depth = 4,
  p_descendant_depth = 1
)
```

Dönüş:

```json
{
  "focus": "uuid",
  "nodes": [...],
  "edges": [...],
  "meta": {
    "ancestor_depth": 4,
    "truncated": false
  }
}
```

Frontend bu JSON'u Cytoscape elementlerine dönüştürür. Domain hesabı yapmaz.

### 7.2 Mating graph RPC

```text
mating_analyze(
  p_cow_hayvan_id,
  p_semen_id,
  p_depth = 6
)
```

Dönüşte:

- cow root node
- bull root node
- birleşik ancestor subgraph
- ortak atalar
- ilişki/coancestry metriği
- beklenen offspring inbreeding F
- pedigree completeness
- uyarılar
- varsa bull genetic evaluation özeti — **(v2: dış değerlendirme katmanı; v1 mating yanıtında yoktur)**

bulunur.

Örnek:

```json
{
  "common_ancestors": [
    {"node_id":"...", "cow_distance":4, "bull_distance":3}
  ],
  "relationship": 0.0625,
  "offspring_inbreeding_f": 0.03125,
  "completeness": {"cow": 0.91, "bull": 0.84, "combined": 0.87},
  "effective_depth": 6,
  "warnings": []
}
```

### 7.2b `pedigree_profile` — v1 "Genetik" sekmesinin tek veri kaynağı (Revizyon 2 ile eklendi)

```text
pedigree_profile(
  p_hayvan_id text,
  p_depth     integer default 6
) -> jsonb
```

Dönüş kontratı:

```json
{
  "focus": "H0136",
  "node_id": "uuid",
  "inbreeding_f": 0.031,
  "completeness": {"target_depth": 6, "known_slots": 83, "total_slots": 126, "ratio": 0.659},
  "founder_contributions": [
    {"founder_node_id": "uuid", "label": "Armada", "contribution": 0.25}
  ],
  "unknown_share": 0.125,
  "breed_composition": [
    {"breed": "Holstein", "share": 0.625},
    {"breed": "Brown Swiss", "share": 0.25}
  ],
  "algorithm_version": "pedigree-v1",
  "effective_depth": 6
}
```

**Invariant (r4-F22):** `Σ(founder_contributions.contribution) + unknown_share = 1`.
Bilinmeyen atalar uydurulmuş founder olarak listelenmez; kütleleri yalnız
`unknown_share`'de yaşar. Bilinmeyen parent slotu completeness'te BİLİNMEMİŞ
sayılır (r4-F19) — hesapta founder sınırı gibi davranır ama known-slot şişirmez.

Hesap **istek anında** yapılır (D6: kalıcı cache yok). Founder katkıları ve
breed composition bu yanıtın parçasıdır; ayrı tablo/RPC yoktur. Implementasyon
planı Task 21 bu kontratı okur.

### 7.3 Founder contribution

“Genetik havuz” için MVP'deki doğru kavram **expected founder contribution** olmalıdır.

Algoritma — üç durumlu sınıflandırma kontratı ile (r5-F26):

- Bilinen ancestry üzerinde geriye git.
- **Kayıtlı founder:** graph'ta VAR olan (kimliği işlenmiş, parent-edge'siz) node
  — katkısı o node'a yazılır (known founder).
- **Bilinmeyen slot:** parent edge'i OLMAYAN boş slot — katkısı `unknown_share`
  kovasına gider; o dalın depth-limit'e kadar TÜM alt slotları unknown sayılır.
- **Derinlik sınırı:** limit ötesi kalan kütleye ulaşılamaz — `unknown_share`'e
  eklenir (beyond-depth bilinmiyor).
- Her bilinen parent branch'e 0.5 aktar; aynı founder'a farklı yollardan gelen
  katkıları topla.
- Invariant: `Σ(founder_contributions) + unknown_share = 1`.

Bu, “nine %25” gibi basit kuşak gösteriminden daha doğrudur; tekrarlanan ortak ataları tek founder üzerinde birleştirir.

### 7.4 Breed composition

Aynı propagation mekanizması founder node'ların `breed` değerleri üzerinden uygulanabilir:

```text
Holstein      62.5%
Brown Swiss   25.0%
Red Holstein  12.5%
```

Bilinmeyen ancestry ayrıca gösterilir:

```text
known 87.5%
unknown 12.5%
```

UI unknown'u sessizce bir ırka dağıtmamalıdır.

### 7.5 Inbreeding / kinship

MVP için server-side tabular relationship/Wright-compatible hesap uygulanmalıdır. Algoritma version'lanır.

Kavramlar ayrı isimlendirilir:

- `relationship` / additive relationship coefficient
- `kinship` / coancestry
- `inbreeding_f`
- `expected_offspring_inbreeding_f`

UI bunları tek “akrabalık %” alanında birbirine karıştırmamalıdır.

### 7.6 Pedigree completeness

Metrik değerlendirmesinin güvenilirliğini göstermek için her sonuçla completeness verilmelidir.

Örnek:

```text
6 kuşak hedef
bilinen ancestor slots: 83 / 126
completeness: 65.9%
```

Düşük completeness varsa düşük inbreeding sonucu “akraba değil” olarak yorumlanmaz; “veri yetersiz” uyarısı verilir.

---

## 8. “Genetik değer” sınırı

Pedigree'den tek başına güvenilir bir EBV/ıslah değeri üretildiği iddia edilmemelidir.

Sistem üç ayrı katman taşır:

### Katman A — pedigree-derived

- inbreeding
- kinship
- founder contributions
- breed composition
- lineage diversity
- pedigree completeness

### Katman B — external published evaluations

`genetic_evaluations`:

- milk/fat/protein PTA/EBV
- fertility
- calving ease
- longevity
- health traits
- reliability
- source/evaluation date

### Katman C — EgeSüt internal breeding index (gelecek)

İleride süt verimi, laktasyon, fertilite, hastalık, ayak/meme, longevity gibi phenotype verileri oluştuğunda ayrıca tasarlanır.

```text
pedigree + phenotype + relatives + external EBV
                     ↓
             internal breeding model
```

Bu faz ayrı bir model/spec olmalıdır. İlk pedigree release'i “genetic score 82/100” gibi bilimsel anlamı belirsiz puan üretmez.

---

## 9. Frontend mimarisi

### 9.1 Yeni dosya sınırları

Mevcut büyük `ui.js/forms.js` dosyalarına bütün feature'ı yığmak yerine:

```text
js/
├── pedigree/
│   ├── pedigree-api.js
│   ├── pedigree-adapter.js
│   ├── pedigree-view.js
│   ├── pedigree-style.js
│   └── pedigree-controller.js
```

Önerilen sorumluluklar:

- `pedigree-api.js`: yalnız RPC/read wrapper
- `pedigree-adapter.js`: RPC JSON → Cytoscape elements dönüşümü; genetik hesap YOK
- `pedigree-view.js`: Cytoscape init/render/layout
- `pedigree-style.js`: node/edge style config
- `pedigree-controller.js`: modal/tab lifecycle, focus değişimi, click handlers

Build step eklenmeyeceği için klasik script düzeni veya mevcut repo desenine uygun globals kullanılır. Feature sınırı klasörle korunur.

### 9.2 Görselleştirme stack'i

**Cytoscape.js** graph render/interaction için kullanılmalı.

Neden:

- pure JS
- browser global/UMD kullanımı mümkün
- JSON serializable node/edge modeli
- touch + desktop interaction
- graph selector/event altyapısı
- biyolojik/relational graph kullanımına doğal uyum

Layout (Revizyon 2 kararı):

- **Focal tree (v1):** Cytoscape yerleşik `breadthfirst` yerleşimi — ek
  byte/yok, hiyerarşi için yeterli başlangıç. 4-6 kuşakta ölçüm yapılır;
  yetersiz kalırsa ELK focal'e de alınır.
- **Mating overlay (v1):** cow × bull ortak ancestor graph'ında ELK
  `layered` — `elk.bundled.js` (~1,5 MB) yalnız bu görünüm açıldığında
  lazy-load edilir.
- `mrtree` v1'de kullanılmaz; gerekirse v2'de değerlendirilir.

MVP'de ayrı Graphology katmanı kullanılmamalı; graph state backend'de zaten PostgreSQL'dedir ve Cytoscape kendi element modeline sahiptir.

Neo4j/AGE gibi graph DB de gereksizdir. Birkaç yüz/olası birkaç bin pedigree node için PostgreSQL recursive CTE + indexed edge tables yeterlidir.

### 9.3 Dependency yerleştirme

Proje buildless olduğu için iki güvenli yol var:

1. pinned CDN `<script>`
2. minified release dosyalarını `vendor/` altında repo'ya almak

EgeSüt production için öneri: **vendor/pinned**. Runtime'da üçüncü taraf CDN availability'sine feature bağımlılığı bırakılmaz. İlk yük bütçesi: pedigree JS < 1 MB (cytoscape.min ~0,4 MB + adapter); `elk.bundled.js` bütçenin dışında ve yalnız mating görünümünde yüklenir.

Örnek:

```text
vendor/cytoscape.min.js
vendor/elk.bundled.js
vendor/cytoscape-elk.js
```

### 9.4 UI yüzeyleri

#### Hayvan kartı → “Soy & Genetik”

```text
[ Soy Ağacı ] [ Genetik ] [ Akrabalık ]
```

Soy Ağacı:

- selected animal focal/root
- default 4 generations
- “+2 kuşak” lazy expand
- dam/sire edge farklı label
- external animal ile farm animal görsel olarak ayrılır
- node click: farm animal ise mevcut `openDet`; external ise pedigree detail sheet

Genetik:

- pedigree completeness
- inbreeding F
- founder/breed contribution
- available published evaluations — **(v2: dış değerlendirme katmanı)**

#### Sperma kartı

Armada semen entity'si açıldığında:

- sire identity
- supplier/code
- stok miktarı
- sire ancestry tree
- published evaluations — **(v2)**
- “Bu hayvanla eşleştir” aksiyonu

#### Tohumlama modalı

Sperma seçildiğinde opsiyonel precheck:

```text
Armada Red
Akrabalık: düşük
Tahmini yavru F: 1.8%
Soy kapsama: 82%
Ortak ata: 1
[Detay]
```

Bu hesap submit guard olmak zorunda değildir. İlk fazda advisory olabilir. Daha sonra çiftlik kuralına göre hard threshold eklenebilir.

### 9.5 Tree vs graph davranışı

Tek hayvan görünümü tree gibi davranır:

```text
ancestors
   ↓
 focus
   ↓
descendants (opsiyonel)
```

Mating görünümü graph davranır:

```text
cow ancestors ---- shared ancestor ---- bull ancestors
       \                               /
        -------- proposed calf --------
```

**Proposed calf DB node'u yaratılmaz.** UI-only virtual node olabilir; source data'ya yazılmaz.

---

## 10. IndexedDB / state / sync entegrasyonu

> **Revizyon 2 (offline gerçekçiliği):** app shell cold-start offline DEĞİLDİR
> (service worker stub, README). Bu yüzden "internet yokken app açılır"
> senaryosu yoktur; cache'in kabul senaryosu **sekme açıkken ağ kesilmesi**dir.
> Çevrimiçi ikinci açılışta shell yüklendikten sonra son projection RPC'siz
> sunulabilir (cache hit); **tam çevrimdışı ikinci açılış kabul senaryosu
> değildir** (r2-N14). Asıl değer RPC trafiği ve veri hacmi korumasıdır.

Mevcut `pullFromSupabase()` `TABLES` listesindeki her şeyi full-pull yaptığı için external pedigree graph büyüdüğünde bütün graph'ı her sync'te çekmek yanlış olur.

Bu feature **on-demand read model** kullanmalı.

### 10.1 IDB

Yeni dedicated stores:

```text
pedigree_query_cache
pedigree_entity_cache
```

veya daha basit tek:

```text
pedigree_cache
```

key örneği (farm-scope önekli — r2-N4; çıkış/farm değişiminde store temizlenir):

```text
farm:<farm_id>:subgraph:<focusNode>:up4:down1:v3
farm:<farm_id>:mating:<cow>:<semen>:depth6:v3
```

`DB_VER` implementasyon anında bir sonraki boş değere artırılır (dump'ta 24).

Bu cache `TABLES` global full-pull listesine eklenmez.

### 10.2 State

`state.js` içine tüm graph'ı global array olarak koymak yerine küçük UI state:

```text
pedigreeCurrentView
pedigreeFocusNode
pedigreeLoading
```

yeterlidir.

Graph instance/controller kendi feature scope'unda yaşar.

### 10.3 RPC_TABLES

Write RPC'leri graph tablolarını etkiliyorsa mapping güncellenir; ancak full table pull yerine pedigree cache invalidation hook'u tercih edilir.

Örnek:

```text
dogum_kaydet success
  -> mevcut operational pulls
  -> invalidatePedigree(calf, dam, sire)
```

`dogum_kaydet` her doğumdan sonra binlerce graph row'unu çekmemelidir.

---

## 11. Backend indexleri ve performans

Minimum indexler:

```sql
CREATE INDEX ... ON pedigree_parentage (farm_id, child_node_id, parent_role);
CREATE INDEX ... ON pedigree_parentage (farm_id, parent_node_id);
CREATE INDEX ... ON pedigree_nodes (farm_id, farm_animal_id);
CREATE INDEX ... ON semen_catalog (farm_id, bull_node_id);
CREATE INDEX ... ON genetic_evaluations (farm_id, node_id, evaluation_date DESC);
CREATE INDEX ... ON pedigree_founder_contributions (farm_id, founder_node_id, contribution DESC);  -- v2 (D6): tablo v1'de yok
```

Recursive ancestor sorgularında `child_node_id`; descendant sorgularında `parent_node_id` kritik index'tir.

130 hayvanlık mevcut çiftlik için graph DB veya materialized transitive closure gerekmiyor. Dış pedigree 6–10 kuşakla birkaç bin node'a çıksa bile on-demand recursive CTE + cache yeterli olacaktır.

Transitive closure ancak ölçümle gerekirse sonradan eklenir.

---

## 12. Backfill / legacy migration stratejisi

Tek seferde string kolonları kaldırmak yasak. Geçiş dört aşamalı olmalı.

### Aşama A — schema additive

- `pedigree_nodes`
- `pedigree_parentage`
- `semen_catalog`
- `genetic_evaluations` — **(v2)**
- `pedigree_node_metrics` — **(v2, D6)**
- `pedigree_founder_contributions` — **(v2, D6)**
- `tohumlama.semen_id`
- gerekli RPC'ler

Mevcut davranış değişmez.

### Aşama B — identity backfill

Bütün `hayvanlar` için farm pedigree node yarat.

Anne ilişkileri:

- `hayvanlar.anne_id` geçerli bir farm hayvanına işaret ediyorsa dam edge üret.
- `dogum` kayıtlarıyla cross-check et.
- çelişki varsa otomatik override etme; reconciliation raporuna düşür.

Sire/semen:

- `DISTINCT tohumlama.sperma`
- `DISTINCT dogum.baba_bilgi`
- `DISTINCT hayvanlar.baba_bilgi`
- `stok WHERE kategori='Sperma'`

normalize edilir.

### Aşama C — controlled new writes

- yeni tohumlama `p_semen_id` kullanır
- yeni doğum graph edge'i transaction içinde üretir
- yeni semen entity olmadan arbitrary string kabul edilmez

Legacy `sperma` snapshot yazılmaya devam eder.

### Aşama D — legacy read retirement

Bütün consumer'lar graph/semen FK'ye geçtikten sonra:

- UI'da `baba_bilgi` yalnız historical fallback
- `sperma` display snapshot

olarak kalabilir. Fiziksel DROP ancak ayrı ve çok daha sonraki migration'da düşünülür.

### 12.1 Backfill için implementasyon öncesi gereken canlı envanter

Spec için gerekmedi; migration mapping için gerekir:

```sql
SELECT sperma, count(*) FROM tohumlama GROUP BY sperma ORDER BY count(*) DESC;
SELECT baba_bilgi, count(*) FROM hayvanlar WHERE baba_bilgi IS NOT NULL GROUP BY baba_bilgi;
SELECT baba_bilgi, count(*) FROM dogum WHERE baba_bilgi IS NOT NULL GROUP BY baba_bilgi;
SELECT id, urun_adi, kategori FROM stok WHERE kategori='Sperma';
```

Amaç typo/alias'ları (`Armada`, `Armada Red`, vendor code vb.) otomatik aynı bull'a yanlış bağlamamaktır.

---

## 13. Data quality ve reconciliation

Graph hesaplarının değeri veri kalitesine bağlıdır. Bu nedenle ilk-class reconciliation gerekir.

Önerilen read-only RPC/report:

```text
pedigree_integrity_report()
```

**Kontrol evreni tek otoritede (r7-F35):** grup kodları, severity matrisi,
JSON yanıt şekli ve kabul-kayıtı mekanizması implementasyon planı **Task
2.3'te** tanımlıdır; spec ayrı bir kontrol listesi YÜRÜTMEZ — oradaki liste
bağlayıcıdır ve iki doküman aynı kontrol evrenini üretir (bilinmeyen semen
eşlemesi, node eksikleri, dam/sire boşlukları, role-sex çelişkileri, döngü,
tarih anomalileri, post-cutoff semen sayacı vb. — kod seviyesinde plan
matrisi). Spec'in önceki serbest liste denemesi bu atıfla yürürlükten
kalkmıştır.

**Yanıt kontratı:** raporun JSON şekli (grup `code` + `severity` + `items`
listesi; cutoff `tanimsiz`/`gecersiz` durumları dahil) implementasyon planı
Task 2.3'te tek otorite olarak tanımlıdır; spec bu kontrata atıf yapar (r5-F28).

---

## 14. Test stratejisi

### 14.1 SQL tests

Yeni `tests/sql/pedigree_graph_test.sql`:

- farm node idempotent create
- dam/sire unique invariant
- self-parent reject
- cycle reject
- birth → calf + 2 parent edge
- sire unknown → yalnız dam edge
- twin birth → iki child, aynı dam/sire, aynı `olay_id`
- semen stock link resolve
- parentage düzeltmesi sonraki profil/kinship sorgularına yansır (v1: istek-başı hesap; kalıcı cache invalidation v2'de anlamlıdır)

### 14.2 Unit tests

`tests/unit/pedigree-adapter.test.js`:

- RPC JSON → Cytoscape node/edge conversion
- repeated common ancestor duplicate render edilmez
- external/farm node class mapping
- virtual proposed calf DB entity sanılmaz

`tests/unit/pedigree-cache.test.js`:

- cache key/version
- invalidation
- stale result kullanılmaması

### 14.3 E2E

Playwright:

1. animal card aç
2. Soy & Genetik tabı
3. focal tree render
4. external bull node click
5. tohumlama modalında semen seç
6. mating precheck aç
7. ortak ata detail
8. doğum sonrası yeni calf tree'sinde anne+sire görünür

### 14.4 Property tests

Projede `fast-check` zaten var. Graph için değerlidir:

- rastgele DAG üret
- parent edge ekleme cycle yaratmıyor
- founder contribution toplamı ≈ 1 (v1: istek-bazlı hesap; satır-bazlı cache eşdeğerlik özelliği v2'de eklenir)
- offspring F simetrik parent order'dan etkilenmiyor
- ancestor projection depth limit'i aşmıyor

---

## 15. Rollout fazları

> **Revizyon 2:** Spec'in bu fazları implementasyon planındaki 12 faza açılır.
> Teslim birimi **paket**tir: P1 Temel (plan Faz 0-2), P2 Ağaç (Faz 3-4),
> P3 Üreme (Faz 5-7), P4 Analiz (Faz 8-10). Plan Faz 11 (EBV) ve 12
> (retirement hazırlığı) v2 kapsamındadır. Aşağıdaki Phase 4 bölünür:
> founder/breed katkı UI'ı **v1**'dedir; dış EBV/PTA import + evaluation UI **v2**'dir.

### Phase 0 — Foundation / no UI

- tables + indexes
- farm node backfill
- integrity report
- semen normalization raporu

**Acceptance:** mevcut feature'larda davranış değişikliği yok.

### Phase 1 — Pedigree graph + tree UI

- external animal CRUD/import
- parentage CRUD RPC
- Cytoscape (gömülü `breadthfirst`; ELK DEĞİL — ELK yalnız P4 mating overlay'de lazy)
- animal card Soy Ağacı
- Armada gibi semen sire tree

**Acceptance:** focal animal + 4–6 generation ancestry doğru; shared ancestor aynı node olarak tek render edilir.

### Phase 2 — Reproduction integration

- `tohumlama.semen_id`
- semen catalog UI
- stock linkage
- `dogum_kaydet` graph write
- legacy snapshot dual-write

**Acceptance:** yeni doğan calf otomatik dam/sire graph'ında görünür; ikizler doğru bağlanır.

### Phase 3 — Kinship / mating engine

- common ancestors
- relationship/coancestry
- offspring F
- completeness
- mating precheck
- metric cache (v2 — D6: v1'de istek başına hesap)

**Acceptance:** test pedigree fixtures üzerinde known coefficients ile doğrulama.

### Phase 4 — Genetic profiles

- breed/founder contribution — **v1**
- external bull EBV/PTA import/manual entry — **v2** (Revizyon 2)
- genetic evaluation UI — **v2**

### Phase 5 — Internal breeding value (ayrı spec)

- süt/fenotip kayıt altyapısı varsa BLUP/index yaklaşımı değerlendirilir
- bu spec'e zorla dahil edilmez

---

## 16. Tech stack kararı

| Katman | Seçim | Karar |
|---|---|---|
| Operational DB | mevcut Supabase PostgreSQL | korunur |
| Pedigree graph storage | PostgreSQL node + edge tables | yeni |
| Graph traversal | recursive CTE / PLpgSQL RPC | yeni |
| Kinship/inbreeding | versioned server-side algorithm | yeni |
| Frontend | mevcut Vanilla JS | korunur |
| Graph render | Cytoscape.js | ekle |
| Hierarchical layout | focal: Cytoscape `breadthfirst`; mating overlay: ELK layered (lazy-load, P4) | ekle |
| Local cache | mevcut IndexedDB, on-demand pedigree cache | genişlet |
| Test | mevcut Node + Playwright + fast-check + SQL fixtures | genişlet |
| Graphology | yok | gerekmez |
| Neo4j / AGE | yok | gerekmez |
| Tree-sitter | yok | problem parser problemi değil |
| Build system/framework | yok | eklenmez |

Cytoscape core saf JS/UMD kullanımına uygundur; ELK'nin layered layout'u hiyerarşik DAG/tree için uygundur. `cytoscape-elk` buildless/plain HTML entegrasyonu sağlayabilir. Production'da **'latest' kovalanmaz**: birlikte test edilmiş Cytoscape + adapter + ELK sürüm üçlüsü pinlenip vendor edilir; adapter'ın ELK semver aralığı ayrıca doğrulanır.

---

## 17. Önerilen repo değişiklik haritası

İlk implementasyon sonunda yaklaşık:

```text
index.html
  + Soy & Genetik tab/modal container
  + pinned vendor scripts

js/api.js
  + pedigree cache stores / next DB_VER
  + pedigree query wrappers veya dedicated API script integration
  + relevant invalidation hooks

js/state.js
  + minimal pedigree UI state (gerekirse)

js/forms.js
  ~ tohumlama submit: semen_id
  ~ dogum submit: legacy p_baba path geriye uyumlu

js/app.js
  ~ semen selector controlled catalog'a geçiş

js/ui.js
  + animal card entry point / küçük summary
  - ağır graph implementation burada tutulmaz

js/pedigree/
  + pedigree-api.js
  + pedigree-adapter.js
  + pedigree-view.js
  + pedigree-style.js
  + pedigree-controller.js

vendor/
  + cytoscape.min.js
  + elk.bundled.js (adapter sürümüyle uyumlu pin)
  + cytoscape-elk.js

supabase/migrations/
  + pedigree foundation
  + semen normalization
  + reproduction integration
  + kinship metrics

supabase/migrations/99999999999999_ground_truth.sql
  ~ deploy sonrası kanonik sync

tests/unit/
  + pedigree-adapter.test.js
  + pedigree-cache.test.js

tests/sql/
  + pedigree_graph_test.sql

tests/
  + pedigree.spec.js
```

---

## 18. Explicit non-goals

İlk sürümde YOK:

- genomic SNP storage/analysis
- haplotype/recessive carrier inference
- embryo transfer / recipient dam modeli
- Mendelian sampling tahmini
- BLUP/ssGBLUP
- Neo4j
- arbitrary editable visual graph canvas
- graph üstünden doğrudan drag-drop parent değiştirme
- bütün pedigree graph'ı her app sync'te download etme
- tek “genetik kalite 0–100” puanı
- deneme-başı tam semen kimlik tarihi (v1: tek adım `semen_id_onceki` zinciri; tam geçmiş bilinçli olarak v2 — r5-N17)

Bunlar core modelin önünü kapatmadan sonradan eklenebilir.

---

## 19. Kabul kriterleri

Feature “pedigree foundation tamam” sayılabilmesi için:

1. Her aktif/çıkmış farm animal gerektiğinde tek bir `pedigree_node` ile resolve edilebilir.
2. External sire/dam/ancestor farm hayvanı oluşturmadan graph'a girebilir.
3. Aynı biological ancestor bütün projection'larda aynı node identity'siyle kullanılır.
4. Parentage graph DB seviyesinde cycle kabul etmez.
5. Yeni doğumda calf, dam ve bilinen semen sire edge'i atomik oluşur.
6. İkiz doğumda iki calf aynı parents ile bağımsız child node olarak oluşur.
7. Yeni tohumlama semen free-text yerine controlled `semen_id` kullanabilir.
8. Legacy kayıtlar kırılmadan görüntülenir.
9. Animal card 4+ kuşak focal pedigree'yi render eder.
10. Cow × semen query shared ancestor graph üretir.
11. Inbreeding sonucu completeness metriği olmadan gösterilmez.
12. Frontend hiçbir kinship/inbreeding/founder hesabı yapmaz.
13. Parentage değişimi sonraki tüm metrik sorgularına yansır (v1'de istek-başı hesap bunu kendiliğinden sağlar; kalıcı cache invalidation v2 maddesidir).
14. Pedigree tabloları `farm_id` ileri-disiplinine uyar.
15. Full app sync graph büyüklüğüyle lineer şişmez; pedigree read'leri on-demand kalır.

---

## 20. Self-review sonucu

Spec teslim edilmeden önce mevcut repo invariant'ları ve önerilen model bir kez daha çapraz kontrol edildi. Bu kontrolde şu düzeltmeler/kararlar kesinleştirildi:

1. **Client-side genetics reddedildi.** `ARCHITECTURE.md` içindeki “frontend hesap yapmaz” kuralı nedeniyle Cytoscape/ELK yalnız projection/render yapar; F, kinship, founder contribution ve completeness DB/RPC tarafında kalır.
2. **Tek tree storage reddedildi.** Shared ancestor identity ve Armada gibi dış soyların tekrar kullanılabilmesi için kanonik storage DAG'dır; tree yalnız focal projection'dır.
3. **`hayvanlar` içine sahte boğa basma reddedildi.** External animal identity ayrı `pedigree_nodes` katmanında tutulur; operasyonel hayvan kartı kirletilmez.
4. **Free-text sperm source-of-truth reddedildi.** Mevcut `tohumlama.sperma`/`baba_bilgi` transition snapshot olur; yeni write'lar controlled `semen_id` üzerinden akar.
5. **Full-sync reddedildi.** Dump'taki `pullFromSupabase()` TABLES davranışı nedeniyle pedigree graph global sync listesine eklenmez; projection bazlı on-demand cache kullanılır.
6. **Founder contribution JSON blob'u küçültüldü.** Genetik havuzun gerçekten sorgulanabilmesi için founder dağılımı `pedigree_founder_contributions` tablosuna ayrıldı — **(v2 — D6, r5-F30: v1'de founder kütlesi `pedigree_profile` yanıtında on-demand döner; tablo v1'de yoktur.)**
7. **Parentage provenance netleştirildi.** Semen bir parentage olayı değildir; doğan calf edge'inin provenance'ı `dogum.id`, evidence'i `tohumlama/semen` olur.
8. **Embriyo transferi riski açıklandı.** Mevcut model doğuran annenin genetik dam olduğu varsayımıyla çalışır. Gerçek veride ET varsa Phase 2 öncesi model genişletilmelidir.
9. **Library version drift kapatıldı.** Buildless projede unpinned CDN yerine test edilmiş Cytoscape/ELK adapter sürüm seti vendor edilir.
10. **Mevcut ikiz modeli korundu.** `dogum.olay_id` sibling-event kimliği olarak kalır; pedigree identity için tarih/anne heuristic'i kullanılmaz.

Self-review sonunda mimariyi bloke eden bir çelişki bulunmadı. En büyük migration riski teknik değil, legacy semen/baba isimlerinin identity resolution kalitesidir.

---

## 21. Son mimari şekil

```text
                         ┌──────────────────────────┐
                         │       hayvanlar          │
                         │ operational animal card  │
                         └────────────┬─────────────┘
                                      │ 1:1 mapping
                                      ▼
┌──────────────┐             ┌──────────────────────┐
│    stok      │             │   pedigree_nodes     │
│ Sperma stock │             │ farm + external cow  │
└──────┬───────┘             │ / bull identities    │
       │                     └──────────┬───────────┘
       ▼                                │
┌──────────────┐                        │ parent -> child
│semen_catalog │──────── bull ──────────┤
└──────┬───────┘                        ▼
       │                       ┌──────────────────────┐
       │                       │ pedigree_parentage   │
       │                       │      DAG edges       │
       │                       └──────────┬───────────┘
       ▼                                  │
┌──────────────┐                          ├──────────────┐
│  tohumlama   │                          │              │
│  semen_id    │                          ▼              ▼
└──────┬───────┘                 ┌──────────────┐ ┌──────────────┐
       │                         │ metrics/RPC  │ │ evaluations  │
       │ birth resolution        │ F / kinship  │ │ EBV/PTA etc  │
       ▼                         │ founders     │ └──────┬───────┘
┌──────────────┐                 └──────┬───────┘        │
│    dogum     │                        └────────┬─────────┘
│ olay_id      │                                 ▼
└──────┬───────┘                         ┌─────────────────┐
       │ creates calf                   │ projection RPC  │
       └────────────────────────────────>│ tree / mating   │
                                         └────────┬────────┘
                                                  ▼
                                      ┌──────────────────────┐
                                      │ Vanilla JS frontend  │
                                      │ Cytoscape (bf)       │
                                      └──────────────────────┘
```

Ana fikir: **DB'de tek global pedigree DAG, ekranda seçilen hayvana göre tree; çiftleşme analizinde iki tree'nin ortak node'larda birleştiği graph.**
(*ELK yalnız mating overlay'de lazy-load; focal tree `breadthfirst` — Revizyon 2.)


---

## 22. Implementasyon öncesi ek bilgi ihtiyacı

**Bu mimari spec'i için ek doküman gerekmiyor.** Mevcut dump yeterliydi.
*(İstisna, r2-N6: iki commit'li uygulama artefaktı bu planın parçasıdır —
`.claude/specs/2026-09-10-pedigree-semen-mapping.md` (owner onaylı kimlik
eşlemesi) ve `.claude/reviews/2026-09-10-live-probe-evidence.md` (canlı ölçüm
kanıtları). "Ek doküman yok" ifadesi tasarım dokümanı içindir.)*

Kodlamaya/backfill'e geçerken ise dokümandan ziyade canlı DB envanteri gerekir:

```sql
SELECT sperma, count(*)
FROM tohumlama
GROUP BY sperma
ORDER BY count(*) DESC;

SELECT baba_bilgi, count(*)
FROM hayvanlar
WHERE baba_bilgi IS NOT NULL
GROUP BY baba_bilgi
ORDER BY count(*) DESC;

SELECT baba_bilgi, count(*)
FROM dogum
WHERE baba_bilgi IS NOT NULL
GROUP BY baba_bilgi
ORDER BY count(*) DESC;

SELECT id, urun_adi, kategori
FROM stok
WHERE kategori = 'Sperma';
```

Bunlar Armada/diğer boğa adlarının alias/dedup/backfill haritasını çıkarmak içindir. Mimariyi değiştirmez; sadece migration eşlemesini güvenli hale getirir.

Eğer çiftlikte **embriyo transferi geçmişi** varsa ayrıca bunun belirtilmesi gerekir; bu bilgi `dam` edge semantiğini değiştirir.
