# EgeSüt ERP — Pedigree / Soy Graph / Genetik Katman Implementasyon Planı

**Durum:** Executor-ready implementation plan — **REVİZYON 2**  
**Tarih:** 2026-09-10  
**Mimari otorite:** `EgeSüt ERP — Pedigree, Soy Graph ve Genetik Katman Mimari Spec`  
**İncelenen repo dump:** `egesut-dump.zip`, dump içindeki HEAD `a3d8bc2` (2026-09-09)  
**Hedef:** Mevcut EgeSüt üretim/üreme akışını bozmadan global pedigree DAG + focal tree UI + kontrollü semen identity + akrabalık/inbreeding + founder/breed contribution + dış genetik değerlendirme katmanını fazlı olarak devreye almak.

> **EXECUTION NOTE:** Bu plan tek seferde “big bang” uygulanmamalı. Her phase kendi migration + test + acceptance gate’ini geçmeden sonraki phase’e başlanmamalı. DB tarafı additive/compatible önce deploy edilir, frontend daha sonra yeni kontrata geçirilir.
>
> **REPO FLOW (Revizyon 2 — şeride göre):** Bu program **ss-org şeridinde** yürür
> (D5 paketleri): worker kendi dalına commit eder, lead kendi dalına merge eder,
> root main'e merge eder + owner push kapısı. Owner'ın root kapısı kuralı
> gereği her teslim merge'den önce bağımsız Codex (luna max) review'dan PASS
> alır (döngü). Eski "implementer commit atmaz" kuralı yalnız inline/coordinator
> şeridinde geçerlidir; bu planla çelişki durumunda aktif goal zarfının şeridi
> kazanır.
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
  düzeltilmiş kuralı taşı"**dır: boş **veya whitespace** sperma düşmez (`btrim(p_sperma) <> ''` guard — goal
  zarfıyla aynı ifade) + exact-before-substring +
  üç tohumlama yolu tek ortak kural. Bugfix merge edilmeden Faz 5-7'nin write
  kontratı dondurulmaz.
- **BUG-003 ön koşulu:** `gebelik_kaydet_manual` canlıda 42804 ile kırık;
  `gebelik_kaydet_manual_semen` varyantı, temel RPC canlıda çalışır hale
  gelmeden yazılmaz.
- **Migration numaraları:** bugfix migration'ları `20260910*` aralığını
  kullanacak; bu planın migration timestamp'leri implementasyon anında
  next-free kuralıyla yeniden seçilir (aşağıdaki sıra konsept sırasıdır).
- **Canlı ölçüm gerçeği (2026-09-10, r10-F56 düzeltmesiyle):**
  `tohumlama_kaydet` ve `tohumlama_tekrar_kaydet` ILIKE desenle düşürüyor;
  `planli_tohumlama_kaydet` koşulsuz `tohumlama_kaydet`'e DELEGE eder ve düşüm
  delegasyonla gerçekleşir (**BUG-001 refuted** — G-UREME-STOK-BUGFIX teslimi:
  davranışsal probe + tracked `20260730000001:477-496` teyidi; ilk lexical
  probe'un "dokunmuyor" sonucu literal-arama sınırlamasıydı, kanıt dosyası
  S1'e düzeltme notu işlendi; davranışsal probe'un komut/çıktı kanıtı
  `.claude/idle-reports/2026-09-10-ureme-bugfix.md` teslim raporundadır —
  bugfix dalı main'e merge edilince repoda kalıcı olur; BUGS.md otorite
  durumu da refuted/fixed-pending-deploy ile senkronlanmıştır [r11-F65]).
  Sonuç: Task 10 planli yoluna AYRI düşüm
  EKLEMEZ (çift düşüm olur); üç yol tek kuralı yalnız iki gövde rewiring'i +
  delegasyon mirasıyla sağlar. GT dosyası gövdelerden ayrışmış (SMELL-003) —
  GT rehber, canlı otorite; Task 10 öncesi davranışsal yeniden ölçüm
  (planli → 1 düşüm) preflight şartıdır.

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

Ayrıca canlı column type’ları **beklenti yazmadan, canlıdan okunarak** kaydedilir.
Canlıdan ölçülen bugünkü değerler (2026-09-10, kanıt dosyası S4):
`tohumlama.id` **uuid**, `tohumlama.created_at` **timestamptz (mevcut)**,
`hayvanlar.id/anne_id` text, `dogum.id/olay_id` uuid, `stok.id` text. Dikkat —
**drift örneği #2:** tracked GT `tohumlama.id`’yi text gösteriyor (GT:116);
canlı uuid’dir ve `created_at` GT tablo tanımında görünmez. GT dump’ı tip
iddiası için kaynak DEĞİLDİR (BUGS.md SMELL-003); otorite kanıt dosyasındaki
canlı çıktıdır, implementer değişiklik görürse günceller.

**Çıktı artefaktı:** ölçüm çıktıları `.claude/reviews/2026-09-10-live-probe-evidence.md`
dosyasına işlenir (2026-09-10 root ölçümü halihazırda commit’li; implementer
değişen bir şey görürse aynı dosyaya tarihli ek yapar). Task 0.2’nin kabulü =
dosyanın güncel tutulmasıdır; serbest metin "baktım, uyumlu" kabul DEĞİLDİR.

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

**Mapping artefaktı (Revizyon 2):** human-reviewed mapping bir **commit’li
dosyadır**: `.claude/specs/2026-09-10-pedigree-semen-mapping.md` — sütunlar
`legacy_string | canonical_bull | stock_id | güven(exact/confirmed/unresolved) | owner_notu`;
versiyon = commit SHA’sı; sahibi owner (onayı satır satır baştadır). Task 8 bu
dosyayı okur ve migration içine dosya versiyonunu not düşer; dosyasız/versiyonsuz
mapping’ten backfill koşulamaz.

**Revizyon 2 — gerçek veri spot-check (r2-I7 ile somutlaşıldı):** envanter
çıktısı yanına, vethek’ten işlenen gerçek sürüyle salt-okunur maternal hat
doğrulaması eklenir; sorgu ve ham çıktı `live-probe-evidence.md`’ye yazılır:

```sql
-- anne_id’si dolu hayvanların dam hattı dogum ile uyumlu mu?
-- (r4 düzeltmesi: dogum tablosunda tarih kolonunun adı ‘tarih’tir — dogum_tarihi DEĞİL; kanıt S8)
SELECT c.id, c.anne_id,
       (SELECT count(*) FROM dogum d WHERE d.anne_id = c.anne_id
          AND d.tarih <= c.dogum_tarihi) AS dogum_kaydi_var
FROM hayvanlar c WHERE c.anne_id IS NOT NULL;
```

Kök ölçümü (kanıt S8, 2026-09-10): 61 anne-id’li hayvandan **1** tanesi
tarihsel olarak uyumsuz (dam’ın doğum kaydı yavrunun doğumundan sonra
tarihli) — integrity raporunun ilk gerçek bulgusu.

Çelişkiler (anne_id’si hiçbir dogum ile doğrulanamayan hayvanlar) integrity
raporunun ilk girdisidir. Fixture uydurma veriyle geçer, gerçek sürü geçmeyebilir.

## Task 0.4 — Embriyo transferi gate’i

Canlı tarihçede embriyo transferi kullanıldıysa bu planın `dam = dogum.anne_id` varsayımı durdurulur ve önce `genetic_dam` / `recipient_dam` genişletmesi yapılır.

**Gate:** ET yok/ihmal edilebilir diye **owner** domain kararı netleşmeden doğum parentage write açılmaz — bu planın ölçeğinde **Faz 7**'dir (doğum entegrasyonu; spec'in ölçeğinde Phase 2). Karar, planın D-bölümüne tarihli owner kararı satırı olarak işlenir; işlenmemiş Faz 7 zarfı yazılamaz.

**Preflight açık girdileri (r4-A4/I7 çerçevesi):** ET owner kararı, semen
mapping dosyasının üretilmesi, PROD 42804 reproduce ve legacy return-shape
yakalama, **implementasyon öncesi** üretilen girdilerdir — bu plandaki
eksiklikleri doküman kusuru değil, **beklenen açık girdi** durumudur. Her biri
kanıt dosyasına veya D-bölümüne tarihli işlenmeden ilgili fazın zarfı
yazılamaz; produce edilen her girdi kanıt zincirine girer.

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

- `parent_farm_id` + `parent_node_id` ve `child_farm_id` + `child_node_id` **composite FK çiftleri** → `pedigree_nodes(farm_id, id)` `ON DELETE CASCADE` (cross-farm edge DDL'de imkânsız — r2-G3; `pedigree_nodes` tarafında `UNIQUE (farm_id, id)` zorunlu)
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

**Cross-farm enforcement (Revizyon 2):** `pedigree_nodes`'a `UNIQUE (farm_id, id)`
eklenir; `pedigree_parentage` kolonları `(parent_farm_id, parent_node_id)` /
`(child_farm_id, child_node_id)` çiftleri olarak yazılır ve composite FK ile
`pedigree_nodes(farm_id, id)`'ye bağlanır — cross-farm edge DDL seviyesinde
imkânsız (Task 1.1 test 7'nin dayanağı budur; RPC same-farm check ikinci
savunmadır).

#### `semen_catalog`

- `farm_id`
- `bull_farm_id` + `bull_node_id` **composite FK** → `pedigree_nodes(farm_id, id)` (r3-N3; ilişkisel farm kilidi, guard değil)
- `stock_id text NULL REFERENCES stok(id) ON DELETE SET NULL`
- `code`, `display_name`, `supplier`, `semen_type`, `active`, `metadata`
- `(farm_id, stock_id)` partial/normal unique when stock_id non-null

### 1.3 RLS / grants (r2 sonrası yürütülebilir hale getirildi)

Yeni tablolar RLS-enabled olur; repo politikası gereği `USING(true)` kalır.
Yetki sınırı **çalışan DDL cümleleriyle** netleşir (tracked auth-lockdown
PUBLIC’i geri aldığı için yeni nesnelere grant yazılmazsa istemci erişemez).
**Kural: her grant, ilgili nesneyi yaratan MIGRATION’ın kendi içinde durur** —
foundation migration’ı henüz var olmayan fonksiyona grant yazamaz (r2-N1).

Foundation migration’ına girenler:

```sql
-- RLS (her yeni tablo için, tablo CREATE’inden hemen sonra):
ALTER TABLE public.pedigree_nodes       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pedigree_parentage   ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.semen_catalog        ENABLE ROW LEVEL SECURITY;
CREATE POLICY allow_all ON public.pedigree_nodes     FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY allow_all ON public.pedigree_parentage FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY allow_all ON public.semen_catalog      FOR ALL USING (true) WITH CHECK (true);

-- IDB sync gerekir (D3); r10-F51: tracked auth-lockdown anon'a HİÇBİR şey
-- vermiyor + app login gate'i var → tüm grant'lar yalnız authenticated:
GRANT SELECT ON public.semen_catalog TO authenticated;

-- Foundation’da yaratılan RPC’ler (Task 1.4) — tam argüman tipleriyle (r3-N1, r4-F13 sıraları):
GRANT EXECUTE ON FUNCTION public.pedigree_parent_set(uuid,text,uuid,text,text,boolean,jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.pedigree_external_upsert(text,uuid,text,text,date,text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.semen_catalog_upsert(text,uuid,uuid,text,text,text,text,text,text,boolean) TO authenticated;
```

Sonraki fazların migration’larına girenler (fonksiyon orada yaratılır — eksiksiz envanter, r4-F12/F20/F21):

```sql
-- Task 2 (integrity): o migration’da:
GRANT EXECUTE ON FUNCTION public.pedigree_integrity_report() TO authenticated;
-- pedigree_finding_hash IMMUTABLE helper: client grant gerektirmez (yalnız SQL içi kullanım + owner şablonu)
-- Task 3 (projection): o migration’da:
GRANT EXECUTE ON FUNCTION public.pedigree_subgraph(uuid,integer,integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.pedigree_subgraph_for_animal(text,integer,integer) TO authenticated;
-- Task 10 (controlled writes): o migration’da (r4-F12):
GRANT EXECUTE ON FUNCTION public.tohumlama_kaydet_semen(text,date,uuid,text,text,jsonb,boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.planli_tohumlama_kaydet_semen(uuid,text,date,uuid,text,text,jsonb,boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.tohumlama_tekrar_kaydet_semen(text,date,uuid,text,text,boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.gebelik_kaydet_manual_semen(text,date,uuid) TO authenticated;
-- Task 17/P4 (profile+mating+kinship): o migration’da (r4-F20):
GRANT EXECUTE ON FUNCTION public.pedigree_profile(text,integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mating_analyze(text,uuid,integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.pedigree_kinship(uuid,uuid,integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.pedigree_inbreeding(uuid,integer) TO authenticated;
-- v2 (Task 22): genetic_evaluations tablosu + okuma RPC’si birlikte:
GRANT EXECUTE ON FUNCTION public.genetic_evaluations_for_node(uuid) TO authenticated;
```

**SECURITY DEFINER kontratı:** yeni RPC’lerin tamamı `SECURITY DEFINER` +
`SET search_path = public, pg_temp` ile yazılır (graph tablolarına doğrudan
client grant’i olmadığından RPC’ler kendi yetkisiyle okur/yazar); farm stamp
`public.current_farm_id()`’den gelir, client parametresinden değil. Graph DML
istemciye hiçbir tabloda açılmaz; Task 26 denetimi bunu doğrular, ikame etmez.

**Operatör guard’ı (r10-F58, r11-F62/F63 ile uygulanabilir):**
`pedigree_meta` tablosu + `public.assert_is_operator()` fonksiyonu **Task 1
foundation’da yaratılır** (Task 2’de değil): guard, `pedigree_meta`’da
`op_owner_uid` anahtarı varsa `auth.uid()::text` ile eşitlik ister; **anahtar
YOKSA fail-closed — kimse geçemez**; owner deploy sonrası bootstrap INSERT’i
ile kendini açar (deploy talimat satırı). Guard yalnız PUBLIC mutasyon
RPC’lerinde: `pedigree_parent_set` (manuel düzeltme), `pedigree_external_upsert`,
`semen_catalog_upsert`. **Doğum yolu muafiyeti (r11-F62):** bu RPC’lerin
paylaştığı iş mantığı `_pedigree_parent_set_core` gibi INTERNAL (grantsız,
yalnız SQL-içi çağrılabilir) fonksiyonlardadır; `dogum_kaydet` core’u doğrudan
çağırır — normal doğum her authenticated kullanıcıda çalışır, guard yalnızca
manuel soy düzeltmesini owner’a kilitler. SQL fixture: set_config claim
mock’u ile non-owner manuel reddi + owner geçişi + doğum yolunun guardsız
akışı üçü ayrı test edilir. UI etiketi yetki değildir; yetki bu kontrattır.

### 1.4 Helper’lar

Foundation ile:

```text
pedigree_ensure_farm_node(p_hayvan_id text) -> uuid
pedigree_is_ancestor(p_ancestor uuid, p_descendant uuid) -> boolean
pedigree_parent_set(
  p_child_node_id uuid, p_role text,        -- 'dam' | 'sire'
  p_parent_node_id uuid,
  p_source_type text default 'manual',      -- birth|manual|import|reconcile
  p_source_ref text default null,
  p_replace boolean default false,          -- farklı parent'a değişim için açık onay
  p_evidence jsonb default null             -- r4-F10: doğum edge'i {"tohumlama_id","semen_id"} yazar
) -> uuid
-- r5-F29 kontratı: gövde COALESCE(p_evidence, '{}'::jsonb) yazar — NOT NULL
-- kolon hiçbir çağrı yolunda ihlal edilmez; manual/import/reconcile çağrıları
-- evidence='{}' ile sonuçlanır ve bu davranış SQL fixture'da test edilir.
pedigree_external_upsert(                   -- r4-F13: zorunlu parametreler ÖNCE (PG default kuralı)
  p_display_name text,
  p_node_id uuid default null, p_sex text default null, p_breed text default null,
  p_birth_date date default null,
  p_registry_system text default null, p_registry_code text default null
) -> uuid
semen_catalog_upsert(                        -- Task 11 "Elle Gir"/tanımla akışının tek yolu; r4-F13 sıralı
  p_display_name text,
  p_id uuid default null,
  p_bull_node_id uuid default null,          -- verilmezse external bull node yaratılır
  p_registry_system text default null, p_registry_code text default null,
  p_stock_id text default null,
  p_code text default null, p_supplier text default null,
  p_semen_type text default null, p_active boolean default true
) -> uuid
```

**Guard'lar (r2-N3):** upsert (a) `p_stock_id` verildiyse `stok.kategori='Sperma'`
değilse reddeder; (b) bull node yarattırıyorsa `sex='male'` yazar, mevcut node
`female` ise reddeder; (c) tüm node/stock bağlantıları farm-scope composite FK
ile aynı farm'a kilitlidir. Geçerli FK + anlamsız bağ kombinasyonu kapalıdır.

**Tarihsel kimlik değişmezliği (r10-F57, r11-F57 tam kapsam):** `p_id` ile
güncellemede, satır `tohumlama.semen_id` **VEYA** `tohumlama.semen_id_onceki`
tarafından referans ediliyorsa `bull_node_id` DEĞİŞTİRİLEMEZ — RPC hata döner.
Farklı boğa gerekiyorsa yeni catalog satırı yaratılır, eski satır `active=false`
olur (replacement modeli; edge'ler eski node'a bağlı kalır). Silme v1'de yok:
`tohumlama.semen_id`/`semen_id_onceki` FK'ları **default (NO ACTION)** ile
tanımlanır — spec §4.4 ile tek otorite (`SET NULL` DEĞİL; catalog satırı
tarihsel referanslar dururken silinemez). `semen_catalog.stock_id` ayrı
kolondur ve `ON DELETE SET NULL` kalır.

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

Migration demo DB’ye uygulanır; `tests/sql/pedigree_graph_test.sql` **`BEGIN` …
`ROLLBACK`** bloğu içinde koşar (tracked desen:
`tests/sql/hayvan_grup_padok_sync_test.sql:1-5`) — fixture kalıcı satır bırakamaz
(r2-N11). Koşum öncesi hedef doğrulaması zorunludur: `$DATABASE_URL`’nin demo
proje olduğunu gösteren çıktı rapora eklenir; PROD hedefine koşum YASAK.

**Phase 1 acceptance:** mevcut frontend hiç değişmeden çalışır; yeni tablolar additive’dir; yeni/geri alınan hayvan node lifecycle testi geçer.

### 1.7 Tooling (r2-A1): tracked dry-run kapısı

Owner-local `scripts/db-dry-run.sh` **commit edilir** (TMPDIR uyumlu uyarlamayla:
sabit `/tmp/dry-run-refresh.log` → `${TMPDIR:-/tmp}` altına `mktemp`; bağımlı
`refresh_lsp_schema.sh` de tracked edilir ya da betik içine katlanır). Kabul:
`scripts/` altında commit’li + README’de tek satır çağrım talimatı; bu maddeden
sonra "migration dry-run kapısı" tekrar üretilebilirdir. Bu maddeye kadar
migration kabulü Task 1.6’daki psql fixture + demo uygulamasıyla verilir.

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

**Dışlama kuralı (r5-F23, r6-F31 ile kesin predicate):** "güvenli" koşul tam
SQL ile budur — edge yalnız şu koşulda yaratılır:

```sql
c.anne_id IS NOT NULL
AND EXISTS (SELECT 1 FROM hayvanlar p WHERE p.id = c.anne_id)          -- dam mevcut
AND c.dogum_tarihi IS NOT NULL                                          -- tarih kanıtı zorunlu
AND EXISTS (SELECT 1 FROM dogum d
             WHERE d.anne_id = c.anne_id
               AND d.tarih <= c.dogum_tarihi)                           -- S8’in ölçtüğü predicate
```

Bu S8’in `NOT EXISTS` ölçümüyle birebir aynı sınıflandırmadır (dam’in geç bir
kayıtı, daha erken geçerli bir kaydı geçersiz KILMAZ). İki dışlama sınıfı:
`maternal_tarihsel_uyumsuz` (dam var, tarihli, ama erken kayıt yok → blocker)
ve `maternal_tarih_bilinmiyor` (child.dogum_tarihi NULL → warning; edge
yaratılmaz, otomatik güvenilmez). "En geç kayıt" yorumu YOKTUR.

### 2.3 `pedigree_integrity_report()`

> `pedigree_meta` tablosu **Task 1 foundation'da yaratılır** (r11-F63; guard +
> op_owner_uid orada); bu migration yalnızca cutoff anahtarını YAZAR/OKUR
> (Task 10 INSERT eder).

Rapor cutoff okumasını NULL-güvenli yapar: `semen_controlled_cutoff` anahtarı
yoksa (Task 10 henüz deploy edilmemişse) rapor **makine değeri `"tanimsiz"`**
döner (İngilizce harflerle — JSON enum'da tek gösterim; yanındaki insan-açıklaması
ayrı bir `detail` alanındadır, değerle karışmaz) ve NULL-sayaç bölümü atlanır;
hata vermez.

**Create read-only RPC** — döndürdüğü grup evreni **tek gösterim**: aşağıdaki
severity matrisindeki kod listesinin ta kendisidir (r10-F52; ayrı liste
YOKTUR). Matris: `farm_animal_node_eksik, unresolved_anne_id,
unresolved_baba_bilgi, child_without_dam, child_without_sire,
role_sex_contradiction, duplicate_registry, legacy_semen_no_mapping,
cycle_count, parent_born_after_child, maternal_tarihsel_uyumsuz,
maternal_tarih_bilinmiyor, legacy_anne_graph_dam_celiskisi,
dogum_anne_graph_dam_celiskisi, suspiciously_young_parent,
post_cutoff_null_semen, cutoff_invalid` — 17 kod.

**Emisyon kuralları (r10-F53):** (a) bulgusu olmayan grup HİÇ emit edilmez
(yokluk = sıfır); (b) sayım anlamlı gruplarda (`post_cutoff_null_semen`) her
ihlal SATIRI bir item'tır (`key = tohumlama.id`, `detail = "created_at > cutoff,
sperma=<t>"`) — `{count:0}` item'i YOKTUR; (c) `cutoff_invalid` tek item:
`key="cutoff"`, `detail=<ham value>`.
- post-cutoff tohumlama satırlarında `semen_id IS NULL` sayısı (cutoff = `pedigree_meta` tablosundaki `semen_controlled_cutoff` değeri — r3-F6; tablo bu migration'da yaratılır, r4-F11)

**Yanıt kontratı (r5-F28):** rapor tek JSON döner:

```json
{
  "generated_at": "ISO",
  "cutoff": "ISO | 'tanimsiz' | 'gecersiz'",
  "groups": [
    {"code": "maternal_tarihsel_uyumsuz", "severity": "blocker|warning|info",
     "items": [{"key": "hayvan-id", "detail": "tek satır açıklama",
                "disposition": "open|accepted", "stale_disposition": false}]}
  ]
}
```

Grup `code` listesi bu bölümdeki kontrollerle birebir; her bulgu satırı
`key` ile kimliklenir. **Yazma kuralı (r5-I6/F6 + r6-F34 exception-güvenli):**
`pedigree_meta` cutoff değeri ISO-8601 timestamp metnidir; okuma aynı
migration'da tanımlanan `pedigree_try_timestamptz(p_value text)` helper'ıyla
yapılır (PL/pgSQL `BEGIN ... EXCEPTION WHEN others THEN RETURN NULL` bloğu —
bilinear cast istisnası raporu ÇALIŞTIRAMAZ). Anahtar yok → `cutoff:"tanimsiz"`,
helper NULL döner → `cutoff:"gecersiz"`; her ikisinde NULL-sayaç bölümü atlanır.
SQL fixture: bozuk değerle (`'1900-13-45'`) raporun istisna değil
`gecersiz` döndüğü doğrulanır.

**Group→severity matrisi (r6-F33):**

```text
blocker: maternal_tarihsel_uyumsuz, duplicate_registry, cycle_count,
         post_cutoff_null_semen, cutoff_invalid
warning: farm_animal_node_eksik, unresolved_anne_id, child_without_dam,
         role_sex_contradiction, legacy_semen_no_mapping, parent_born_after_child,
         maternal_tarih_bilinmiyor,
         legacy_anne_graph_dam_celiskisi,   -- r8-F44: hayvanlar.anne_id dam'i ile graph dam edge'i farklı
         dogum_anne_graph_dam_celiskisi,    -- r8-F44: dogum.anne_id ile graph dam farklı
         suspiciously_young_parent          -- r8-F44: child doğumunda parent yaşı < 18 ay (548 gün)
info:    unresolved_baba_bilgi, child_without_sire
```

**Yeni üç kontrolün predikat kontratı (r9-F48):**

```text
legacy_anne_graph_dam_celiskisi:
  hayvanlar.anne_id NULL değil VE graph'ta tam bir dam edge'i var VE
  anne_id → dam node resolve edilebiliyorsa; iki node farklıysa bulgu.
  key = hayvan_id; detail = "anne_id=<id> graph=<node-uuid kısa>".
  anne_id NULL / edge yok / resolve edilemiyor → bulgu YOK (bu durumlar
  unresolved_anne_id / child_without_dam gruplarına aittir).

dogum_anne_graph_dam_celiskisi:
  dogum satırının buzağı node'u graph'ta dam edge'i taşıyorsa VE
  dogum.anne_id → dam node resolve edilebiliyorsa; farklıysa bulgu.
  key = dogum.id; detail = "dogum.anne_id=<id> graph=<node>"; resolve
  edilemiyorsa bulgu YOK (başka grup sahiplenir).

suspiciously_young_parent:
  child doğum tarihi VE parent node doğum tarihi biliniyorsa VE
  0 <= (child_tarih - parent_tarih) < 548 gün (18 ay) ise bulgu —
  r10-F61: negatif fark (child'tan SONRA doğan parent) bu kontrole girMEZ;
  o durum yalnızca parent_born_after_child grubunun konusudur.
  key = "<child_hayvan_id>:<parent_role>"; detail = "parent <node> yaşı <gün> gün".
  Tarihlerden herhangi biri NULL → bulgu YOK.

dogum_anne_graph_dam_celiskisi (join ifadesi — r10-F48, r11-F48 deterministik):
  dogum satırının buzağı node'u — kupe recycle (domain kuralı: benzersizlik
  yalnız aktif+dolu küpede) nedeniyle SKALER alt sorgu DETERMİNİSTİK
  sıralanmalıdır:
    pedigree_nodes.farm_animal_id = (
      SELECT h.id FROM hayvanlar h
      WHERE h.kupe_no = dogum.yavru_kupe
      ORDER BY (h.dogum_tarihi = dogum.tarih) DESC,   -- bu doğumun buzağısı önce
               (h.durum = 'Aktif') DESC,              -- sonra aktif kayıt
               h.dogum_tarihi DESC, h.id              -- son kırbaç: deterministik
      LIMIT 1)
  kupe eşleşmesi hiç yoksa bulgu YOK. (v2 notu: dogum.buzagi_id kolonu bu
  heuristiği tamamen kaldırır — bilinçli borç.)
  Karşılaştırma: dogum.anne_id → dam node vs buzağı node'unun graph dam edge'i.
  Parent tarih kaynağı (tek ifade): farm node → hayvanlar.dogum_tarihi,
  external node → pedigree_nodes.birth_date; COALESCE(h.dogum_tarihi, pn.birth_date).
```

**Makine-okunur durum kuralları (r8-F40):** rapor item şeması
`{"key","detail","disposition":"open|accepted","stale_disposition":true|false}`
taşır (stale → kabul geçersiz, item open işlem görür). Cutoff durumları:
`cutoff:"tanimsiz"` → `post_cutoff_null_semen` grubu HİÇ emit edilmez
(yokluğu = not_applicable); `cutoff:"gecersiz"` → `cutoff_invalid` grubu
(blocker, tek item) emit edilir. **G2 (tek yorum):** rapor emit ettiği tüm
gruplarda blocker item sayısı = 0 VE tüm warning/info item'larında
`disposition=accepted AND stale_disposition=false`.

**Kabul kaydı (r6-F33, r7-F37; r8-F43 ile owner-SQL):** kabul CLIENT RPC'si
değildir — demo/PROD signup açıktır, `authenticated` grant'ı her kayıt olana
kabul yazdırırdı. Kabul **owner'ın SQL ile yazdığı** karardır: Task 2
migration'ı `IMMUTABLE` helper `pedigree_finding_hash(p_code text, p_key text,
p_detail text) returns text` (md5(code||':'||key||':'||detail)) tanımlar; rapor
her item için aynı helper'ı çağırır. Owner, rapor JSON'undaki item için
dokümante şablonu koşar:

```sql
INSERT INTO public.pedigree_meta (farm_id, key, value) VALUES (
  public.current_farm_id(),
  'integrity_accepted:<code>:<key>',
  jsonb_build_object(
    'accepted_at', now(),
    'note', '<not>',
    'finding_hash', public.pedigree_finding_hash('<code>','<key>','<detail>')
  )::text
)
ON CONFLICT (farm_id, key) DO UPDATE SET value = excluded.value;
```

`disposition=accepted` YALNIZ meta `finding_hash`'i birebir eşitse; eşit
değilse item `open` + `stale_disposition:true` (kanıt değişince kabul bayatlar
— tazelik mekanik). `pedigree_accept_finding` RPC'si ve grant'ı YOKTUR (v2'de
owner-auth tasarımıyla değerlendirilir). SQL fixture: (a) şablonla kabul →
accepted; (b) detail değişimi → tekrar open + stale.

**Cutoff durumunun G2 bağlamı (r7-F36, r8-F40 makine-okunur):** yukarıdaki
emit kuralları — `tanimsiz` → grup yok (not_applicable), `gecersiz` →
`cutoff_invalid` blocker, geçerli → ölçülür.

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
  "key": "farm:<farm_id>:subgraph:animal:H123:up4:down1:v1",
  "payload": {},
  "cached_at": "ISO",
  "schema_version": 1,
  "epoch": "<localStorage pedigree_cache_epoch değeri — r8-F42 karantina alanı>"
}
```

### 4.2 Generic IDB helpers

`api.js` içine yalnız ihtiyaç kadar:

```text
idbGetByKey(store, key)
idbClearStore(store)
```

ekle. `pedigree_cache` global `TABLES` listesine eklenmez. Key'ler farm-scope öneki
taşır (r2-N4) ve **çıkış/farm bağlamı değişiminde `pedigree_cache` store
tamamen temizlenir** — başka farm/bağlamın grafiği yanlış bağlamda render
edilemez. **Farm bağlamının istemci kaynağı (r3-F3):** `js/config.js`'e
`PEDIGREE_FARM_ID` sabiti eklenir (DB farm_id varsayanıyla hizalı; bugün tek
farm — değer network'süz okunur, offline arama çalışır; multi-farm fazında RPC
değerine taşınır). **Temizliğin yüzeyi (r4-F17/F18 + r6-F32 — buildless gerçeklere bağlı):**
`js/api.js`'e top-level global fonksiyon `clearPedigreeCacheStore()`
eklenir (mevcut global desen; `api.` namespace'i YOKTUR). `js/auth.js`'te
**her iki çıkış yolu da** kapanır: (a) açık logout: `await
clearPedigreeCacheStore()` ÖNCE, sonra `await db.auth.signOut()`;
(b) `SIGNED_OUT` listener'ı (session expiry / başka sekme logout'ı):
reload'dan ÖNCE `await clearPedigreeCacheStore()` — listener bloğu
`location.reload()` çağrısından önce clear'ı bekler. Kabul testi iki yolu
da içerir: açık logout + listener üzerinden external sign-out (test,
listener'ın clear çağırdığını mock/spy ile kanıtlar).

### 4.3 Cache policy

`pedigree-api.js`:

```text
pedigreeApi.subgraphForAnimal(...)
pedigreeApi.subgraphForNode(...)
pedigreeApi.integrityReport()
```

Davranış:

1. network RPC denenir
2. başarılıysa cache overwrite edilir — **generation guard’lı (r7-F38; sayaç
   = `globalThis.__pedigreeSessionGen`, r8-F41 tek gösterim):** istek
   başlarken sayaç okunur; yazma öncesi sayaç değiştiyse (arada clear olduysa)
   sonuç DISKARDE edilir — logout sonrası gelen eski yanıt yeni oturumun
   cache’ine yazamaz
3. network yok/iletim hatası varsa matching cached payload döner
4. cache de yoksa açık “çevrimdışı ve önbellek yok” durumu döner

Domain hesabı client’a taşınmaz.

**`clearPedigreeCacheStore()` hata politikası (r7-F39 + r8-F41/F42):**
fonksiyon kendi içinde try/catch’tir (fail-open; IDB hatası loglanır,
fırlatılmaz) ve çıkış asla bloklanmaz — auth kesimleri
`try { await clear... } finally { signOut()/reload() }` yazar.

**Paylaşılan sayaç (r8-F41 — buildless gerçek):** repo dersi: classic
script’lerde top-level `let/const` globalThis’a ÇIKMAZ, script’ler arasında
paylaşılmaz (`tests/unit/support/loadModule.js:10-12`; 2026-09-09 💡-buton
vakası). Bu yüzden sayaç **`globalThis.__pedigreeSessionGen`** üzerinde yaşar:
`pedigree-api.js` yazma öncesi okur, `clearPedigreeCacheStore()` (api.js)
HER durumda `globalThis.__pedigreeSessionGen =
(globalThis.__pedigreeSessionGen ?? 0) + 1` çalıştırır. Modül-seviye `let`
sayaç YASAKTIR (bağlantısız ikinci sayaç riski).

**Sıra kontratı (r10-F54) + yazma askısı (r11-F64):** `clearPedigreeCacheStore()`
gövdesi İLK ÜÇ adımı SENKRON ve IDB temizliği BAŞLAMADAN yapar: (1) globalThis
sayaç++, (2) localStorage epoch üret, (3) `globalThis.__pedigreeWritesSuspended
= true` — ancak sonra `await idbClearStore(...)` başlar (try/catch fail-open).
**Askı bayrağı reload'a kadar kalır:** fence→reload arası başlayan HER yeni
istek network sonucunu döner ama cache'e YAZMAZ (yeni-epoch satırı üretilemez).
Böylece IDB silme başarısız olsa bile: eski satırlar epoch karantinasında,
yeni satırlar askı ile — izolasyon iki mekanizmayla birlikte tamdır. Kabul
testi: (a) fence öncesi pending yanıt yazılmaz; (b) fence SONRASI başlayan
istek de yazmaz (askı); (c) IDB reddi simülasyonunda okuma eski payload
döndüremez.

**Okuma karantinası (r8-F42 — fail-open kalıntısı):** epoch
`localStorage[‘pedigree_cache_epoch’]` içinde yaşar (app init’te yoksa
üretilir; clear HER durumda yeni epoch üretir — IDB temizliği başarısız olsa
bile). Cache yazımı satıra `epoch` yazar; okuma (network fallback dahil)
YALNIZ satır epoch’u === güncel epoch olan satırları sunar. Böylece clear
sonrası fiziksel olarak kalmış eski satır görünmezdir — fail-open, garantiyi
bozmaz. Test: IDB clear reddi simülasyonu → logout tamamlanır VE sonraki
okuma eski payload’u DÖNÜREMEZ (epoch karantinası); pending yanıt store’a
yazılamaz (generation guard) — final durum: store okumada boş.

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

**Phase 3 acceptance:** subgraph online çağrılır, IDB’ye düşer; **sekme açıkken ağ kesildiğinde** aynı payload cache’ten render edilebilir (cold-start offline app zaten yoktur — spec §10 Revizyon 2).

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
- layout config — P2'de `breadthfirst` (ELK YOK); P4'te mating overlay için ELK `layered` (lazy-load, Task 5 P4 kapsamı)
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

Phase 0’daki human-reviewed mapping bu migration’ın veri girdisidir — girdi **commit’li dosyadır**: `.claude/specs/2026-09-10-pedigree-semen-mapping.md` (format Task 0.3’te; versiyon = commit SHA’sı; migration bu versiyonu not düşer).

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
  ADD COLUMN semen_id uuid NULL REFERENCES public.semen_catalog(id);  -- default NO ACTION (r11-F57: SET NULL değil — tarihsel referans satırı korur; silme v1'de yok)
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
tohumlama_kaydet_semen(
  p_hayvan_id text, p_tarih date, p_semen_id uuid,
  p_hekim_id text, p_irk_bilgisi text,
  p_ek_uygulamalar jsonb default null, p_vwp_override boolean default false
) -> legacy tohumlama_kaydet ile AYNI dönüş kontratı
planli_tohumlama_kaydet_semen(
  p_gorev_id uuid, p_hayvan_id text, p_tarih date, p_semen_id uuid,
  p_hekim_id text, p_irk_bilgisi text,
  p_ek_uygulamalar jsonb default null, p_vwp_override boolean default false
) -> legacy ile AYNI
tohumlama_tekrar_kaydet_semen(
  p_hayvan_id text, p_tarih date, p_semen_id uuid,
  p_hekim_id text, p_irk_bilgisi text,
  p_force_semen boolean DEFAULT FALSE   -- satırda FARKLI non-null semen_id varsa sessiz ezme yok (r2-N17; spec §6.3 kuralı)
) -> legacy ile AYNI
gebelik_kaydet_manual_semen(
  p_hayvan_id text, p_tarih date, p_semen_id uuid DEFAULT NULL
) -> legacy ile AYNI   -- NULL geçerli: mevcut modal sperma bilinmiyor'a izin veriyor (index.html:2241-2244); yeni RPC de bilinmeyen-sperma gebeliğini kabul eder (r2-N9)
```

**Tekrar-aşım kimlik taşıma kuralı (r3-N17):** `p_force_semen=true` ile
değişimde eski `semen_id` → `tohumlama.semen_id_onceki` kolonuna taşınır ve
`islem_log` snapshot JSON'u `eski_semen_id` anahtarını zorunlu taşır; kolon
aynı migration'da eklenir (spec §4.4). Böylece force ile bile kanonik kimlik
kaybolmaz (tek adım zincir; tam deneme tarihi v2).

**Kontrat kuralı:** her `_semen` varyantı, legacy eşiyle aynı parametre sırası
(p_sperma → p_semen_id dönüşümü dışında), aynı dönüş değeri ve aynı hata
davranışına sahiptir; etkilenen tablo seti legacy eşinininki + `tohumlama.semen_id`
yazımıdır. Return shape değişikliği YASAK — frontend iki yolu da aynı şekilde
çağırabilmelidir. **Legacy dönüş/hata kontratı ezberden yazılmaz:** Task 0.2
ölçümünde her legacy RPC'nin dönüş tipi + temel hata durumları kanıt dosyasına
(`live-probe-evidence.md`) kaydedilir; eşdeğerlik fixture'ı o çıktıya karşı
doğrulanır (r2-I3). SQL testleri eşdeğerliği (aynı girdi → aynı sonuç + semen_id
dolu) ölçer.

Yeni RPC’ler:

1. semen row same farm + active validate
2. `display_name` snapshot resolve
3. mevcut authoritative business rules’i **tek yerde** kullan
4. `tohumlama.semen_id` set et
5. stock düşümü: bugfix’lenmiş kuralı (boş **veya whitespace** sperma düşmez — `btrim` guard; exact-before-substring; üç yol ortak — D4) `semen_catalog.stock_id` üzerinden uygula; davranış icat etme, düzeltilmiş kuralı taşı
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

**Revizyon 3 (r2-N5 — önceki iddia ölçümle düzeltildi):** önceki metin
"tohumlama offline kuyrukta ZATEN queueable" diyordu; **yanlıştı**.
`submitInsem`/`submitTekrarAsim` offline’da kuyruk öğesi yaratmadan reddediyor
(`js/forms.js:317-322`, `407-423`); `RPC_MAP`’teki `tohumlama → tohumlama_kaydet`
girdisi bu formlardan gelmiyor. Sonuç: **v1’de `*_semen` çağrıları
online-only’dir** ve `RPC_MAP`’e yeni ad EKLENMEZ (payload ayrımı olmayan tek
POST hedefi rota belirleyemez). Offline tohumlama kuyruğunu açmak ayrı bir
iştidir ve bu planın kapsamı dışındadır. Kalan madde: `tests/unit/api.test.js`’ye
RPC_TABLES ↔ RPC_MAP tutarlılık testi (SMELL-002’nin izleme aracı) — queueability
iddiası içermez.

## Task 11 — Tohumlama ve tekrar aşım UI controlled selector

**Modify:** `index.html`, `js/app.js`, `js/forms.js`, `js/utils/handlers.js`, tests

**Gebelik formu kuralı (r3-F1):** `geb-sperma` serbest metni KALKAR; form ya
**controlled semen seçimi** ya **"bilinmiyor" (NULL)** kabul eder. Boş olmayan
serbest metin submit edilmez — UI bloklar, RPC (`p_semen_id uuid NULL`) metin
temsil edemez. Mevcut free-text modal P3'te bu iki durumlu select'e dönüşür;
eski legacy string'li kayıtlar görüntüde oldugu gibi kalır.

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
- no selected semen id → submit block — **yalnız i-sperma/tr-sperma formlarında**; `geb-sperma` formunda seçim OPSİYONELDİR (mevcut modal davranışı, r2-N9) ve NULL `p_semen_id` geçerli kabul edilir
- legacy existing record render hâlâ `t.sperma` ile çalışır

**Phase 6 acceptance (ölçülebilir — r3-F6 revizyonu):** "yeni" kayıt =
`created_at > cutoff`. **Cutoff'un saklı otoritesi DB'dedir:** semen-controlled
migration'ı `public.pedigree_meta(farm_id, key, value)` tablosunu yaratır ve
`key='semen_controlled_cutoff'` satırına kendi timestamp'ini yazar — dosya
adı değişse bile sorgu otoritesi bozulmaz; `tohumlama.created_at` canlıda
mevcuttur (kanıt S4). Integrity sorgusu pedigree_meta'dan okur. Kabul:

1. UI E2E: controlled selector’dan giden her **tohumlama/tekrar** kaydı
   `semen_id` taşır (bu iki formda NULL üreten yol kalmadığının testi);
   **gebelik formu ayrıdır** (r4-F16): ya `semen_id` ya bilinçli NULL
   (unknown-sire) — iki yol da ayrı test senaryosuyla doğrulanır, NULL
   "kalan yol" sayılmaz.
2. `pedigree_integrity_report()` sorgusu: `created_at > cutoff AND semen_id IS NULL`
   satır sayısını raporlar — 0 hedefi DB sorgusuyla izlenir.
3. Veritabanı-geneli sert garanti (NOT NULL + legacy RPC kapatma) **v2**
   maddesidir; v1’de legacy RPC’ler açık kaldığı için bu kabul iddia edilmez.

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
9 pedigree_parent_set(dam -> calf, source_type=birth, source_ref=dogum.id, evidence={"tohumlama_id":...})
10 sire biliniyorsa pedigree_parent_set(sire -> calf, source_type=birth, source_ref=dogum.id, evidence={"tohumlama_id":...,"semen_id":...})  -- r3-F2: edge hangi denemeden geldiğini sorgulanabilir taşır
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
- descendants metrics — v1’de kalıcı cache yok, istek-başı hesap kendini tazeler (stale kavramı v2’de anlamlı)

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
supabase/migrations/20260910000007_pedigree_metrics_foundation.sql   ← v2: v1'de OLUŞTURULMAZ
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

Önerilen MVP yaklaşım: relevant ancestor closure üzerinde versioned **tabular numerator relationship / kinship-compatible** algorithm. Kontrat (r3-F7 — deterministik implementasyon):

- Numaratör ilişki matrisi `A`: `a_ij = 0.5*(a_i,sire(j) + a_i,dam(j))`
  (i<j topolojik sırada); köşegen `a_ii = 1 + 0.5*a_sire(i),dam(i)`;
  inbreeding `F_i = a_sire(i),dam(i)`; kinship `f_ij = 0.5*a_ij`.
- Founder: bilinen parent'ı olmayan node; `F=0`, satırı birim köşegenli.
- **Bilinmeyen parent (r4-F19):** hesapta founder sınırı gibi davranır (F=0,
  a=0) ANCAK (a) completeness slotu BİLİNMEMİŞ sayılır — known-slot şişirmez;
  (b) katkısı uydurulmuş founder'a değil `unknown_share` kovasına yazılır;
  (c) unknown dalın depth-limit'e kadar tüm alt slotları unknown sayılır
  (r5-F26/F27 — kayıtlı-founder vs unknown-slot ayrımı spec §7.3'te).
  Fixture (r5-F27 — çağrı `p_depth=1` ile): focus'un bir parent'ı bilinmiyorsa
  `completeness = {known_slots: 1, total_slots: 2, ratio: 0.5}` ve
  `unknown_share = 0.5` beklenir (sayısal beklenen değer).
- **Derinlik kesme:** depth limit ötesi yollar yok sayılır; kesilen her dal
  completeness payını düşürür. Inbred ancestor `(1+F)` etkisi korunur.
- Node'lar topolojik sırayla işlenir (ancestor closure içinde); aynı founder
  birden çok yoldan katkı taşır (toplama).
- `algorithm_version` yanıta gömülür; fixture'lar (unrelated/parent-offspring/
  full sib/half sib/first cousins + inbred ancestor) bu kontratın deterministik
  çıktısını ölçer.

**Depth sınırı (r10-F59 — tüm analiz RPC'lerinde tek kural):** `p_depth`
NULL → default (6); `< 0` → exception; `> 8` → **8'e clamp** + yanıtta
`effective_depth` döner. `pedigree_profile`, `pedigree_kinship`,
`pedigree_inbreeding`, `mating_analyze` için eşit geçerli; projection
RPC'lerindeki mevcut negatif-red/max-8 kuralı zaten uyumludur.

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

Ayrıca inbred ancestor case eklenir — **sayısal beklenen değer (r5-F7):** A
boğası F_A=0.25 (inbred), B unrelated founder, X=A×B → F_X=0 (kinship(A,B)=0);
`pedigree_kinship(X, A) = 0.3125` (F_A=0 olsaydı 0.25 olurdu — `(1+F_A)`
etkisi bu farkla kanıtlanır).

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

**Create:** `20260910000008_mating_analyze.sql` — **tek v1 migration'dır** (r10-F55: metrics foundation v2'dir, v1 RPC oraya ASLA konmaz) ve `pedigree_profile(p_hayvan_id text, p_depth integer default 6)` (spec §7.2b; Task 21'in veri kaynağı — r2-N7) **+ `pedigree_kinship(uuid,uuid,integer)` + `pedigree_inbreeding(uuid,integer)`** fonksiyonlarını yaratır (r4-F20); `GRANT EXECUTE` cümleleri bu migration'dadır (Task 1.3 envanteri)

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
- completeness cow/bull/combined — **alan adlarıyla: `"completeness": {"cow": r, "bull": r, "combined": r}` + `"effective_depth": n` (r10-F60; spec §7.2 örneğiyle tek şekil)**
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

Server-side propagation (r5-F26 sınıflandırması — spec §7.3 ile tek):

- ancestry geriye traverse
- **kayıtlı founder** (var olan parent-edge’siz node) → katkı node’a;
  **bilinmeyen slot** (edge yok) + **derinlik sınırı ötesi** → `unknown_share`
- her parent branch contribution ×0.5
- aynı founder’a farklı path’lerden gelen değerler toplanır
- unknown ancestry ayrı tutulur; unknown dalın alt slotları unknown sayılır
- invariant: Σ(founder) + unknown_share = 1

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

Animal Soy tabındaki ikinci surface — veri kaynağı **tek RPC**:
`pedigree_profile(p_hayvan_id text, p_depth integer default 6) -> jsonb`
(kontrat: spec §7.2b; inbreeding_f + completeness + founder_contributions +
breed_composition + algorithm_version tek yanıtta, istek anında hesap).

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
node_farm_id       -- uuid NOT NULL kolonu (r4-F15; spec §4.5 ile aynı)
node_id
  -- CONSTRAINT: FOREIGN KEY (node_farm_id, node_id) → pedigree_nodes(farm_id, id)
  --             + CHECK (farm_id = node_farm_id)
source
source_registry
evaluation_date    -- date NOT NULL (spec §4.5; NULL unique-key deler — kaynak periyodu girilir)
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

**Okuma yolu (r2-N8 + r3-F9):** tablo D3 gereği full-sync'e girmez ve SELECT
grant'i yoktur; aynı v2 migration `genetic_evaluations_for_node(p_node_id uuid) -> jsonb`
read RPC'sini yaratır + `GRANT EXECUTE ... TO authenticated` (Task 1.3
v2 bloğu). **Yanıt kontratı:**
`{"node_id": "...", "evaluations": [{"source","source_registry","evaluation_date","trait_code","trait_name","value","unit","reliability","metadata"}...]}`,
`evaluation_date DESC, trait_code` sıralı. **Same-farm guard:** node
`(farm_id = public.current_farm_id())` ile resolve edilir; uymayan node için
boş liste döner (veri sızdırmaz). Task 23 UI'sı yalnız bu RPC'den okur.

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

**Stub disiplini (r2-N12 — sahte-yeşil riski):** mevcut
`tests/support/stub-backend.js` bilinmeyen RPC'lere `{ok:true}`, bilinmeyen
tablolara boş dizi döndürüyor. Pedigree E2E senaryoları koşulmadan önce her
pedigree RPC'si için **gerçekçi stub handler** eklenir ve senaryo, handler'ın
fiilen çağrıldığını doğrular (çağrı sayacı) — stub'un sessiz ok:true'si ile
yeşil senaryo KABUL SAYILMAZ.

## Task 25 — Performance / safety checks

Target farm ölçeği için:

- 4-gen focal query
- 6-gen mating query
- 8-gen worst allowed query
- Cytoscape render with representative external pedigree size

ölçülür.

Acceptance guideline (r2-N13 — sayısal kapılar; veri seti: gerçek sürü +
sentetik 6-kuşak dış soy fixture’ı; ölçüm = sorgu + süre tablosu raporda):

- 4-kuşak focal `pedigree_subgraph`: p50 < 300 ms, p95 < 1 sn (RPC süresi)
- 6-kuşak `mating_analyze`: p95 < 2 sn
- 8-kuşak izin verilen en derin sorgu: p95 < 4 sn
- Cytoscape render (temsili dış soy boyutuyla): < 1 sn ilk layout
- max-depth sunucu tarafında zorunlu; app startup’ta tam pedigree pull yok;
  graph nesnesi `state.animals` benzeri global diziye kopyalanmaz (bunlar
  yapısal şartlardır, ölçümle birlikte raporlanır)

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

- **SQL koşum ortamı (DOC-006, Revizyon 2 düzeltmesi):** "local/test DB" yoktur.
  Fixture'lar `psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f` ile koşulur (mevcut
  tracked desen: `tests/sql/hayvan_grup_padok_sync_test.sql`). Dikkat:
  `scripts/db-dry-run.sh` **tracked değildir** (owner-local, commit'siz;
  sabit `/tmp` log yazar — TMPDIR kuralına aykırı). **P1 tooling maddesi:**
  dry-run kapısı TMPDIR-uyumlu ve tracked olarak bu programa dahil edilir;
  o ana kadar migration kabulü psql fixture'ları + demo uygulamasıyla verilir,
  db-dry-run "varsa bonus"tur. CI otomasyonu kapsam dışıdır.
- **farm_id ilk uygulama (DOC-005):** pedigree tabloları **canlı üretim
  şemasında** `farm_id` taşıyan ilk tablolardır (ürün şemasında bugün
  `farm_id` kolonu yok, yalnızca `current_farm_id()` helper'ı var;
  `demo/02_demo_klonla.sql`'deki `demo_klon_log` demo-yardımcıdır, ürün
  şemasına dahil değildir). Contract kuralının ilk
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

Gerçek implementasyon sırasında timestamp’ler **next-free kuralıyla** yeniden seçilir; isim sırası konsept sırasını gösterir. Revizyon 2 notu: `G-20260910-UREME-STOK-BUGFIX` bugfix migration’ları `20260910*` aralığını kullanacak — pedigree migration’ları implementasyon anında bugfix setinin ÜSTÜNDEN numaralanır (D4). **v1 dizisi = foundation, backfill, projection, semen×2, dogum, mating (yukarıda 000001-000006 + 000008); 000007 (metrics) ve 000009 (genetic_evaluations) v2 migration’larıdır ve v1 paketlerinde oluşturulmaz.**

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
  + v1: 000001-000006 + 000008 (P1-P4);  v2: 000007, 000009
  ~ ground_truth only after validation

.harness/references/rpc-reference.md    ← Task 27; root/lead şeridi (worker zarflarına girmez)
ARCHITECTURE.md                         ← Task 27; root/lead şeridi
README.md / README.tr.md                ← Task 27; yalnız kullanıcı-facing anlatım gerekirse

.claude/specs/2026-09-10-pedigree-semen-mapping.md   ← Task 0.3 preflight artefaktı (owner onaylı; Task 8 girdisi — r2-N6)
.claude/reviews/2026-09-10-live-probe-evidence.md    ← Task 0.2/0.3 ölçüm kanıtı (yaşayan dosya)
scripts/db-dry-run.sh + refresh_lsp_schema.sh        ← Task 1.7 tooling (tracked + TMPDIR-uyumlu)
js/auth.js                                           ← r3-F4/r5-F25: çıkışta clearPedigreeCacheStore() çağrısı (ad Task 4.4 ile tek)
js/config.js                                         ← r3-F3: PEDIGREE_FARM_ID sabiti (cache key kaynağı)
tests/support/stub-backend.js                        ← r3-F5: Task 24 pedigree RPC stub handler'ları + çağrı sayaçları

tests/unit/
  + pedigree-api.test.js
  + pedigree-adapter.test.js
  + pedigree-cache.test.js
  ~ api.test.js
  + semen-selector/param contract tests as appropriate

tests/sql/
  + pedigree_graph_test.sql
  + pedigree_metrics_test.sql (v2 — v1'de kinship fixture'ları pedigree_graph_test.sql içinde)

tests/
  + pedigree.spec.js
```

---

# Rollout gate matrisi

| Gate | Açılması için şart | Sonraki kabiliyet |
|---|---|---|
| G0 | baseline + live inventory | migration başlat |
| G1 | graph schema invariant tests green | farm backfill |
| G2 | Task 2.3 makine kuralının birebir kendisi: emit edilen tüm gruplarda blocker item=0 VE her warning/info item `disposition=accepted AND stale_disposition=false` (stale kabul=open işlem görür) — r9-F49: tek gösterim, rollout satırı ayrı yorum taşıMAZ | read projection |
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
17. External EBV/PTA provenance/source/date/reliability ile ayrı katmanda tutulur — **(v2 maddesi, D5: Faz 11 v2'ye taşındı; v1 DoD'una dahil değildir)**.
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
