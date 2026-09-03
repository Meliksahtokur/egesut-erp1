# Review: `CLAUDE-OPUS-REVIEW-PROMPT.md` — prompt kalitesi ve iyileştirme önerileri

- **İnceleyen:** Claude Opus 5 (1M context), Claude Code oturumu
- **Tarih:** 2026-09-02
- **Repo HEAD:** `e8cd620` — `/home/melik/egesut-erp1`
- **İncelenen dosya:** `.harness/design/2026-09-02-unified-agent-harness/CLAUDE-OPUS-REVIEW-PROMPT.md` (194 satır)
- **Bağlam olarak okundu:** `SPEC.md` (17.9 KB), `IMPLEMENTATION-PLAN.md` (12.7 KB)
- **Kapsam:** Bu doküman **prompt'un kendisini** eleştirir (meta-review). SPEC/PLAN'ın mimari
  değerlendirmesi değildir; ancak prompt'un onları doğru hedefleyip hedeflemediğini ölçmek için
  ikisi de okundu ve birkaç somut tutarsızlık kanıt olarak kullanıldı.

---

## 0. Özet verdict

**`ACCEPT_WITH_CHANGES`** — prompt üst çeyrek kalitede: rol, kapsam, read-only sınırlar,
belirsizlik etiketleme ve çıktı şeması net. Ancak **altı yapısal kusuru** var ve bunlar
düzeltilmezse review'ın sonucu, "SPEC'i onaylayan uzun bir doküman" olmaya doğru sistematik
biçimde kayar:

| # | Kusur | Etki |
|---|---|---|
| C1 | `HARD_INVARIANTS` tasarım kararlarını tartışılmaz ilan ediyor | Reviewer SPEC'in en riskli seçimlerini **sorgulayamaz** |
| C2 | `CONTEXT` bloğu SPEC'i olumlayıcı dille tekrar ediyor | Anchoring / confirmation bias |
| C3 | Ölçülmüş repo taban durumu (baseline) verilmiyor | VERIFIED etiketleri zayıf temele oturur, riskler yanlış tartılır |
| C4 | Çıktı yükü tek turda taşınamayacak kadar büyük (12 bölüm × alt-matrisler) | Derinlik kaybı / kesilme; bölümler birbirini tekrar eder |
| C5 | Çıktının **nereye yazılacağı** yok + "hiçbir şey yazma" ile çelişki | Uzun review terminal scroll'unda kaybolur; talimat çelişkisi |
| C6 | "Cross-document consistency" ve "coexistence" soruları hiç sorulmuyor | SPEC↔PLAN arası gerçek boşluklar (aşağıda 3 kanıt) gözden kaçar |

Aşağıda her biri kanıtla ve **doğrudan kopyalanabilir düzeltme metniyle** verilmiştir.
§9'da revize edilmiş tam prompt (v2) var.

---

## 1. Prompt'un doğrulanmış güçlü yanları

Bunlar korunmalı; v2'de aynen taşındı.

1. **`<ROLE>` skeptik çerçeveleme.** "Be skeptical of ceremony, duplicated authority, false
   enforcement, and claims unsupported by the live repository" — bu tek cümle, LLM review'larının
   en yaygın hatasını (nazik onay) doğrudan hedefliyor. Nadiren iyi yazılmış.
2. **Read-only operasyonel sınırlar açık ve sayılmış.** "Do not write or modify files, install
   packages, start workers, create worktrees, commit, merge, push, deploy, mutate databases, call
   live providers" — kapalı liste, "dikkatli ol" gibi bulanık bir ifade değil.
3. **Kirli ağaç koruması explicit.** "The repository is already dirty ... Preserve it exactly" —
   bu repoda 44 untracked + 2 modified dosya var; korumasız bir review ajanı temizlik yapmaya
   kalkabilirdi. Doğru refleks.
4. **`UNCERTAINTY_HANDLING` üçlü etiket** (`VERIFIED` / `HYPOTHESIS` / `DECISION_NEEDED`) ve
   "Never fabricate file paths, line numbers, commands, runtime behavior, or schema facts" —
   halüsinasyon bütçesini sıfırlıyor. Ayrıca "Distinguish proposal defects from
   existing-repository defects" ayrımı çok değerli: bu repoda ikisi kolayca karışır.
5. **Seeded hipotezler (H1–H8)** review'ı "genel tavsiye" olmaktan çıkarıp yanlışlanabilir
   iddialara bağlıyor. H8 ("plan may still contain bloat") özellikle iyi — reviewer'a silme
   yetkisi veriyor.
6. **`Bloat audit` çıktı bölümü.** Çoğu review prompt'u sadece "ne eklemeli" sorar; bu prompt
   "ne silmeli" diye ayrı bölüm açıyor. Doğru asimetri kırma.
7. **`DO NOT` satırları zorunlu** (Output §10). "Tempting but harmful changes" istemek, review'ın
   negatif alanını da kayıt altına alıyor.
8. **Son cümle:** "Do not provide generic multi-agent advice." — LLM review'larının ikinci en
   yaygın hatasını kapatıyor.

---

## 2. C1 — `HARD_INVARIANTS` tasarım kararlarını invariant'a terfi ettiriyor (EN KRİTİK)

### Bulgu

`HARD_INVARIANTS` bloğunda 13 madde var. Bunlar **iki farklı türden**:

**(a) Gerçek invariant — süreç/güvenlik, tartışılamaz:**
- "Existing user-owned dirty/untracked state must be preserved."
- "Push, deploy, DB mutation, destructive cleanup ... remain separately gated."
- "Avoid a from-scratch product rewrite."
- "Do not accept stale schema/ID facts merely because a current skill says so."

**(b) Tasarım kararı — SPEC'in tezi, review'ın konusu olmalı:**
- "No vector DB, Obsidian, or external harness is required for correctness."
- "ZCode Desktop must not default to Herdr."
- "Do not make one orchestration runtime mandatory."
- "Runtime hooks may warn but are not the sole governance truth."
- "Worker PASS must not equal root integration acceptance."
- "A lead must not write outside its goal and declared docs authority."

(b) grubu **SPEC'in vardığı sonuçların ta kendisi**. Bunları invariant ilan etmek, reviewer'a
"tezimi kabul et, sadece detayları eleştir" demektir.

### Kanıt: prompt kendi kaynağıyla çelişiyor

`SPEC.md` §19 "Decisions that review must challenge" listesi şunu içeriyor:

> whether leads should ever receive direct canonical memory authority

Ama prompt `HARD_INVARIANTS`'ta bunu kilitliyor:

> A lead must not write outside its goal and declared docs authority.

Ve daha sertçe:

> No vector DB, Obsidian, or external harness is required for correctness.

Bu repoda **canlı, doğrulanmış, kullanımda olan bir "external harness" zaten var**: tools-bank
mailbox + registry + Event Bus + `worker_list.py` + `tb-worker` + `goose-teammate.py` +
`codex-teammate.py`, ve `memory_notes` (lokal Qwen3 embedding) + `code_embeddings` (Cloudflare
bge-m3) vektör katmanı — hepsi kök `CLAUDE.md`'de kurumsal politika olarak belgeli. Reviewer'ın
sorması gereken en pahalı soru şudur:

> `.harness/` bu altyapının **yerine mi geçiyor, yanında mı yaşayacak**, ve iki governance
> kaynağı aynı anda çalışırken hangisi kazanır?

Mevcut invariant bu soruyu **peşinen "gerekli değil" diye kapatıyor**. Bu, review'ın en yüksek
değerli çıktısını iptal eder.

### Düzeltme (kopyalanabilir)

`HARD_INVARIANTS`'ı ikiye böl:

```text
<PROCESS_INVARIANTS>   <!-- tartışılamaz; ihlali review'ı geçersiz kılar -->
- Read-only: do not write, modify, install, spawn, commit, merge, push, deploy,
  mutate DBs, call live providers, or clean up anything.
  (Single exception: the deliverable file named in <DELIVERABLE>.)
- Preserve existing user-owned dirty/untracked state byte-identically.
- Never fabricate paths, line numbers, commands, runtime behavior, or schema facts.
- Live schema remains the authority for DB facts; no current skill or tracked
  document overrides it.
- This review concerns the harness, not a product rewrite.
</PROCESS_INVARIANTS>

<CHALLENGEABLE_ASSUMPTIONS>
The proposal asserts the following. You are REQUIRED to test each one and may
recommend reversing any of them if the evidence supports it. Do not treat them
as constraints on your conclusions.

A1. A tracked repository-local `.harness/` should be the governance source of truth.
A2. No orchestration runtime should be mandatory.
A3. ZCode Desktop should not default to Herdr; Herdr stays explicitly selected.
A4. Worker PASS must not equal root integration acceptance.
A5. Leads must not write outside declared goal docs authority.
A6. Runtime hooks warn; deterministic checks own enforcement.
A7. No vector DB / external harness is required for correctness.
A8. Fast mode must never require a pre-authored goal.

For each: state KEEP / MODIFY / REVERSE with evidence and the cost of being wrong.
If you recommend REVERSE on A2, A4, A5 or A8, you must also show that the
resulting design still bounds worker authority and avoids mandatory ceremony.
</CHALLENGEABLE_ASSUMPTIONS>
```

Kritik nokta: A2/A4/A5/A8'i tersine çevirmek için **ek ispat yükü** koydum. Böylece hem
sorgulanabilir kalıyorlar hem de reviewer tembel bir "her şeye goal koyalım" cevabına kayamıyor
— yani prompt'un korumak istediği şey (bürokrasi patlaması) invariant yerine **kanıt yüküyle**
korunuyor. Bu daha sağlam bir mekanizma.

---

## 3. C2 — `CONTEXT` bloğu tarafsız değil (anchoring)

### Bulgu

`<CONTEXT>` şöyle açılıyor:

> The intended architecture is: — a tracked repository-local `.harness/` as the governance source
> of truth; ... — root as integration authority; ...

15 maddelik bu liste, SPEC'in özeti değil **savunusu**. "intended", "source of truth",
"authority" gibi kelimeler kararları verilmiş gibi sunuyor. Reviewer bu listeyi okuduktan sonra
SPEC'i okuduğunda, zaten iki kez ikna edilmiş oluyor.

Ayrıca **gereksiz**: SPEC dosyası zaten prompt'un birincil girdisi ve reviewer'ın onu okuması
zorunlu. Aynı içeriği ikinci kez, üstelik olumlayıcı dille vermek net bias eklemesi yapıyor.

### Düzeltme

`<CONTEXT>`'i tamamen kaldır, yerine iki kısa şey koy:

```text
<CONTEXT>
Read SPEC.md and IMPLEMENTATION-PLAN.md as the primary input. Do not rely on this
prompt's paraphrase of them; the documents govern.

Non-obvious background you cannot derive from the two documents:
- The repository already runs a working external agent infrastructure documented
  in root CLAUDE.md (tools-bank mailbox/registry/Event Bus, goose/codex/pi
  teammate bridges, a local-embedding memory store and a cloud-embedding code
  index). The proposal does not state how it coexists with or replaces this.
- The owner operates this repo effectively alone; every role in the proposal
  (owner/root/lead/worker/verifier) maps onto one human plus N agents.
- Turkish and English documentation coexist; the harness documents are English.
</CONTEXT>
```

Bu, bias eklemeden reviewer'ın **dokümanlardan çıkaramayacağı** gerçek bağlamı veriyor — bir
prompt'un CONTEXT bloğunun tek meşru işi budur.

---

## 4. C3 — Ölçülmüş repo taban durumu (baseline) eksik

### Bulgu

Prompt "live terminal review" diyor ama reviewer'a **hiçbir ölçülmüş gerçek** vermiyor ve
doğrulaması gereken şeylerin listesini de vermiyor. Sonuç: reviewer ya kendi keşfine saatler
harcar (ve token bütçesini bulgu üretmek yerine keşfe yakar), ya da SPEC'in ima ettiği durumu
gerçek sanar.

Bu review sırasında ölçtüğüm ve **prompt'un yanlış izlenim yarattığı** noktalar:

| İddia / ima | Ölçüm (2026-09-02, HEAD `e8cd620`) | Sonuç |
|---|---|---|
| "tracked repository-local `.harness/`" | `git ls-files .harness` → **boş**; `.gitignore`'da `harness` geçmiyor | `.harness/` şu an **untracked**. Tracked olması bir *hedef*, mevcut durum değil. Prompt bunu "intended" diyerek geçiştiriyor; reviewer "zaten tracked" sanabilir. |
| "short root `AGENTS.md`" | `AGENTS.md` = **577 satır**, `CLAUDE.md` = **422 satır** | Phase 1'in "Reduce root AGENTS.md to a concise shared map" maddesi ~1000 satırlık politika ayrıştırma işi. Prompt bu iş büyüklüğünü hiç görünür kılmıyor; effort tahminleri buradan sapar. |
| "unrelated user-owned `.claude` and local runtime state" (untracked ima) | `.claude` altında **23 tracked dosya** + `M .claude/domain-rules.md`, `M .claude/rpc-reference.md` | `.claude` **kısmen tracked**. "Preserve it exactly" talimatı doğru ama sınıflandırma yanlış; Phase 0/6 migration riski bu yüzden yanlış tartılabilir. |
| `.qwen` / `.agents` / `.zcode` retirement (Phase 6) | üçü de **0 tracked dosya** | Bu üç yüzeyin "retirement"ı büyük ölçüde **Git dışı** bir iş. Reviewer bunu bilmezse Phase 6'ya olduğundan yüksek Git riski atfeder. |
| `tests/harness/` | **yok** (mevcut: `tests/unit`, `tests/sql`, `tests/support`, 8 playwright spec) | Yeni test ağacı sıfırdan; PLAN §12'deki `python3 -m unittest discover -s tests/harness` şu an çalışmaz. |
| Genel kirlilik | **44 untracked**, **2 modified** | "already dirty" doğru, ama büyüklüğü verilmemiş. |

### Düzeltme

Prompt'a şu bloğu ekle — hem bilgi verir hem **tazeliğini reviewer'a doğrulattırır** (bayat fact
enjekte etmemek için kritik):

```text
<REPO_BASELINE>
Measured at HEAD e8cd620 on 2026-09-02. RE-VERIFY before citing; treat any
mismatch as a finding, not as noise.

  git rev-parse --short HEAD
  git ls-files .harness | wc -l          # expected 0  -> .harness is UNTRACKED
  git ls-files .claude  | wc -l          # expected 23 -> .claude is PARTLY TRACKED
  git ls-files .agents .qwen .zcode | wc -l   # expected 0
  wc -l AGENTS.md CLAUDE.md              # expected 577 / 422
  ls tests/                              # no tests/harness/ yet
  git status --porcelain | wc -l         # ~46 entries; preserve all of them

Implications you must fold into effort/risk estimates:
- "tracked .harness/" is a target state, not the current state.
- "short AGENTS.md" means splitting ~1000 lines of live policy, not writing a new file.
- .qwen/.agents/.zcode retirement is mostly a non-Git operation.
- tests/harness/ and .harness/bin/harness.py do not exist; do not attempt to run them.
</REPO_BASELINE>
```

Son satır önemli: mevcut prompt, PLAN §12'deki komut listesini gören bir reviewer'ın
`python3 .harness/bin/harness.py validate` çalıştırmasını engellemiyor — komut yok, hata alır,
kafası karışır veya (kötü senaryo) "çalışmıyor" diye yanlış bir VERIFIED bulgu üretir.

---

## 5. C4 — Çıktı yükü tek turda taşınamaz; sorular çıktıya eşlenmemiş

### Bulgu 1: hacim

Prompt tek yanıtta şunu istiyor:

- 12 zorunlu bölüm,
- bunlardan §5 tam bir **authority matrisi** (5 rol × 9 aksiyon = 45 hücre),
- §10 tam bir **roadmap tablosu** (7 kolon × N satır + DO NOT satırları),
- §6/§7/§8 üç ayrı alt-sistem derinlemesine incelemesi,
- artı 14 review sorusu, artı 8 hipotezin her birine confirm/refute/extend.

Gerçekçi olarak bu 15.000–25.000 kelimelik bir doküman. Tek turda üretilirse ya sonu zayıflar
(son bölümler her zaman en zayıfı olur — ki §11 "owner decisions" ve §12 "final recommendation"
tam da **en değerli iki bölüm**), ya da her bölüm sığlaşır.

### Bulgu 2: eşleme yok

`REVIEW_QUESTIONS` (14 soru) ile `OUTPUT_FORMAT` (12 bölüm) arasında **hiçbir eşleme yok**.
Reviewer soru 4'ü ("Can goal and worktree history be queried reliably?") §8'de mi cevaplayacak,
§3'te mi? Belirsiz. Pratikte 2–4 soru sessizce düşer ve kimse fark etmez.

### Bulgu 3: örtüşen soru enflasyonu

Üç ayrı yerde soru soruluyor ve **ciddi biçimde örtüşüyorlar**:

- `SPEC.md` §19 — 8 "must challenge" maddesi
- prompt `<CONTEXT>` — 8 hipotez (H1–H8)
- prompt `<REVIEW_QUESTIONS>` — 14 soru

Toplam 30 soru; benzersiz sayısı kabaca 12–14. Örnekler:
- SPEC §19 "whether generated BOARD/HANDOFF views preserve enough human narrative"
  = H2 = REVIEW_QUESTIONS 6 → **aynı soru üç kez**.
- SPEC §19 "whether `--no-commit` merge reconciliation is robust"
  = H6 = REVIEW_QUESTIONS 9 (kısmen) → **üç kez**.
- SPEC §19 "the exact threshold between Fast and Full modes"
  = REVIEW_QUESTIONS 3 → **iki kez**.

Bu, review'ın aynı şeyi üç farklı bölümde tekrar etmesine yol açar — ki bu, prompt'un kendi
`Bloat audit` talebiyle ironik biçimde çelişir.

### Düzeltme

**(a) İki pass'e böl.** Bu tek değişiklik hem kaliteyi hem maliyeti düzeltir:

```text
<EXECUTION>
Run this review in two passes, in one session.

PASS 1 — EVIDENCE (cheap, mechanical, no judgment)
Produce a table: Claim | Source (SPEC §/PLAN §) | Status (TRUE/FALSE/UNVERIFIABLE)
| Evidence (command run + first line of output, or path:line).
Cover at minimum: every path the two documents assert exists; every runtime
behavior they assume; every "current state" claim; every cross-document
inconsistency between SPEC §4 layout and PLAN phase write manifests.
Write PASS 1 to the deliverable file, then continue.

PASS 2 — JUDGMENT (expensive)
Using only PASS 1 evidence plus the two documents, produce the numbered output
sections. Any VERIFIED label in PASS 2 must point to a PASS 1 row.
</EXECUTION>
```

Bu, review'ın kendi felsefesini (kanıt önce, iddia sonra — SPEC §14 "no checker may silently
repair", PLAN §2 "each needs an actual probe") **prompt seviyesinde dogfood** eder.

**(b) Soruları konsolide et ve bölümlere eşle.** 14 soruyu 12'ye indir ve her birine hedef
bölüm yaz:

```text
<REVIEW_QUESTIONS>
Answer each question inside the listed output section. A "Question coverage"
table at the end must map every Q to the section and paragraph that answers it;
an unanswered question must be listed as UNANSWERED with a reason.

Q1  Authority model completeness / contradiction resistance            -> §5
Q2  Role boundary precision (owner/root/lead/worker/verifier)           -> §5
Q3  Fast/Full trigger minimality and enforceability                     -> §3, §8
Q4  Queryability of goal + worktree + ad-hoc history from Git alone     -> §8
Q5  Docs-update state machine completeness and fakeability              -> §6
Q6  BOARD/HANDOFF: generated vs partial vs curated                      -> §6
Q7  Memory promotion rules vs a second stale knowledge system           -> §6
Q8  Git lifecycle safety: direct-main, worktree, --no-commit, rollback  -> §7
Q9  Check placement: warning hook vs command vs test vs review vs owner -> §5, §7
Q10 Product-test vs harness-test separation                             -> §3, §4
Q11 Coexistence with the existing tools-bank/bridge infrastructure      -> §3, §9
Q12 Smallest first increment with least irreversible commitment         -> §9, §10
</REVIEW_QUESTIONS>
```

Not: Q11 **yeni** — bkz. C6. Eski Q12 (migration/rollback/secret/cleanup gaps) ve Q13 (bloat)
zaten §3 ve §4 çıktı bölümlerinin konusu, ayrı soru olmalarına gerek yok.

---

## 6. C5 — Deliverable tanımsız ve "hiçbir şey yazma" ile çelişiyor

### Bulgu

- `<TASK>`: "Do not implement or edit anything."
- `<OPERATING_MODE>`: "Do not write or modify files..."
- `<OUTPUT_FORMAT>`: 12 bölümlük dev bir doküman istiyor.

Çıktının **nereye** gideceği hiç söylenmemiş. Varsayılan: terminal stdout. 20.000 kelimelik bir
review terminal scroll buffer'ında yaşar; oturum kapanınca kaybolur; owner'ın alıntılayacağı
kalıcı bir artefakt yok. Ayrıca SPEC/PLAN'ın kendi felsefesi (rapor = kalıcı kanıt) ihlal edilmiş
oluyor.

Ve daha kötüsü: dosyaya yazması gerektiğini düşünen bir reviewer, prompt'un iki ayrı yerindeki
"do not write" ile **doğrudan çelişki** yaşar ve muhtemelen yazmaz.

### Düzeltme

```text
<DELIVERABLE>
Write the full review to exactly one file:

  .harness/design/2026-09-02-unified-agent-harness/REVIEW-<reviewer-id>-<YYYY-MM-DD>.md

This single file is the ONLY write you are permitted. Creating it does not
violate the read-only invariants. Do not `git add` it, do not commit it, and do
not modify SPEC.md or IMPLEMENTATION-PLAN.md.

Header the file with: reviewer id, model, date, repo HEAD short SHA
(`git rev-parse --short HEAD`), `git status --porcelain | wc -l` before and
after, and the exact list of files you read.

Then print to the terminal ONLY: the executive verdict, the top five findings,
and the deliverable's absolute path.
</DELIVERABLE>
```

`base_sha` kaydı özellikle önemli: SPEC §10 her worktree'den "exact base SHA" istiyor. Review'ın
kendisi bu disiplini uygulamıyorsa, review'ın önerdiği disipline güven zayıflar. Ayrıca
"status before/after" beyanı, "kirli ağacı koru" invariant'ını **denetlenebilir** hale getirir —
şu an sadece bir temenni.

---

## 7. C6 — İki kritik review boyutu hiç sorulmuyor

Prompt 14 soru soruyor ama aşağıdaki iki boyut hiç yok. İkisi de bu repoya **özgü** ve ikisi de
yüksek maliyetli.

### 6.1 Cross-document tutarlılık ve faz↔layout kapsama matrisi

Prompt hiçbir yerde "SPEC ile PLAN birbiriyle tutarlı mı" diye sormuyor. Bu review sırasında,
sadece iki dokümanı okuyarak **üç gerçek boşluk** buldum — bunlar reviewer'ın bulması gereken
tipte bulgular ve mevcut soru listesi bunları hedeflemiyor:

1. **`.harness/runtimes/` tanımsız.** `IMPLEMENTATION-PLAN.md` §4 Phase 1 write manifest'inde
   `.harness/runtimes/*` var. Ama `SPEC.md` §4'teki hedef dizin ağacında **`runtimes/` yok**.
   SPEC §5.3 "Its runtime adapter injects or points to..." diyor, §19 ise "whether runtime
   adapters should be tracked files, generated files, or thin symlinks" diye soruyor — yani
   adapter'ların **fiziksel yeri ve biçimi hiç kararlaştırılmamış** ama Phase 1 onları yazmayı
   planlıyor. Phase 1'in exit criteria'sı ("all four supported runtimes demonstrate the same
   contract version") tanımlanmamış bir artefakta bağlı.

2. **`.harness/decisions/` hiçbir fazda yaratılmıyor.** `SPEC.md` §4 layout'unda `decisions/`
   var; §12.4 onu "canonical input" sayıyor; §12.5 "domain/state-machine changes evaluate domain
   rules and **decisions**" diyor. Ama PLAN'ın hiçbir fazının write manifest'inde `decisions/`
   geçmiyor (Phase 2: goals/reports/schemas; Phase 3: memory/generated). Ayrıca `decisions/` için
   `schemas/` altında şema da yok (sadece `goal.schema.json`, `report.schema.json`). Yani
   canonical bir kayıt türü **şemasız ve sahipsiz**.

3. **`docs-update.md` faz sırası ters.** SPEC §12 docs-update'i checkpoint mimarisi olarak
   Phase 2'nin ürettiği goal metadata'sına (`checkpoint.docs_verdict`) bağlıyor, ama
   `.harness/docs-update.md` dosyası Phase 3'te yazılıyor. Phase 2'nin `goal.schema.json`'ı,
   Phase 3'te tanımlanacak bir verdict enum'unu doğrulamak zorunda. Sıralama çalışabilir ama
   PLAN bunu hiç ele almıyor; Phase 2 kabul kriterlerinde `docs_verdict` doğrulaması yok.

Bunlar "mimari itiraz" değil, **mekanik kapsama boşlukları** — ve tam da bir prompt'un
garantilemesi gereken türden bulgular.

**Düzeltme:**

```text
<CROSS_DOCUMENT_CHECK>
Mandatory mechanical check before judgment. Produce two tables:

(1) Layout coverage: every path in SPEC §4's tree x the PLAN phase that creates
    it. Flag: paths in SPEC with no creating phase; paths in a PLAN write
    manifest that are absent from SPEC §4; canonical record types with no schema
    in .harness/schemas/.

(2) Dependency order: for each phase, list the artifacts it validates that a
    LATER phase defines. Any backward dependency is a finding.

Report these in output section §3 (Critical findings) even if you consider them
minor; do not fold them into prose.
</CROSS_DOCUMENT_CHECK>
```

### 6.2 Mevcut çalışan altyapıyla koexistans ve operatör maliyeti

Prompt hiç sormuyor:

- **Koexistans:** tools-bank mailbox/registry/Event Bus, `goose-teammate.py`,
  `codex-teammate.py`, `pi-teammate.py`, `worker_list.py`, `tb-worker`, `omp-lane.sh`,
  `memory_add`/`memory_search` — hepsi canlı, doğrulanmış ve kök `CLAUDE.md`'de politika olarak
  belgeli. `.harness/goals/` + `.harness/generated/BOARD.md` ile mailbox/registry **iki ayrı
  gerçeklik kaydı** yaratır. Hangi worker registry'si doğru? `worker_list.py` mi
  `harness worktrees` mi? SPEC bunu hiç ele almıyor, prompt da sormuyor — üstelik invariant
  (A7) soruyu bastırıyor (bkz. C1).
- **Token/süre maliyeti:** 8 checkpoint türü × goal başına. Her checkpoint'te docs-update
  değerlendirmesi = diff sınıflandırma + N doküman yüzeyi × verdict. Bu repo zaten
  "token-disiplinli Goose loop'u" (kök `CLAUDE.md`) diye açık bir maliyet politikası
  yürütüyor. SPEC §16'nın bloat kontrolleri **doküman hacmini** sınırlıyor, **LLM çağrı
  maliyetini** değil. Prompt bunu hiç ölçtürmüyor.
- **Tek-operatör gerçeği:** 5 rol (owner/root/lead/worker/verifier) tek insana + n ajana
  düşüyor. "Root reviews the lead's work" pratikte "aynı insan, aynı seans, farklı context
  window" demek. Bu ayrımın **gerçek koruma sağladığı** yerler ile **sadece tören** olan
  yerler ayrıştırılmalı. Prompt sadece "role boundaries precise enough?" diye soruyor — bu,
  sınırların *gerekli* olup olmadığını değil, *net* olup olmadığını sorar.

**Düzeltme:** Q11'i ekle (§5'te verildi) ve maliyet ölçümünü çıktıya zorunlu kıl:

```text
In output section §4 (Bloat audit), include a quantified cost line:
- estimated LLM calls and operator prompts per Full goal under the proposal,
  vs. the current tools-bank/bridge workflow for the same unit of work;
- which of the 8 checkpoint kinds you would delete or merge, with the specific
  failure each one actually prevents (if you cannot name the failure, delete it);
- which of the 5 roles collapse into one in a single-operator setup, and which
  separations survive because they catch a real class of error.
</...>
```

Son madde özellikle güçlü: "if you cannot name the failure, delete it" — bu, bloat audit'i
öznel bir estetik yargıdan **yanlışlanabilir bir teste** çevirir.

---

## 8. Küçük ama ucuz düzeltmeler

| # | Sorun | Düzeltme |
|---|---|---|
| m1 | Hard-coded yol: "started from `/home/melik/egesut-erp1`" | `cd "$(git rev-parse --show-toplevel)"` yaz; repo taşınırsa kırılmaz |
| m2 | Çıktı dili belirtilmemiş (repo Türkçe+İngilizce karışık) | "Write the review in English; SPEC and PLAN are English. Quote Turkish source lines verbatim when citing." |
| m3 | `<SELF_CHECK>` "internally verify" — denetlenemez | Çıktıya §13 "Self-check attestation" bölümü ekle: her madde ✓/✗ + tek cümle gerekçe. Görünmeyen self-check, self-check değildir. |
| m4 | Komut allowlist'i yok; "read-only shell" bulanık | Açık liste: `git ls-files/status/log/show/diff/rev-parse`, `rg`, `sed -n`, `wc`, `ls`, `cat`, GitNexus read-only MCP araçları. Yasak: `gitnexus analyze` (`.gitnexus/`'a **yazar** — mevcut prompt bunu yasaklamıyor ama PLAN Phase 0 "refreshed GitNexus index" istiyor; bu review-zamanı bir çelişki, açıkça çözülmeli: "do not refresh the index; report staleness as a finding") |
| m5 | Review'ın kendisi için kabul kriteri yok | Minimum kanıt bütçesi: ≥15 VERIFIED satır PASS 1'de; her Critical finding'de evidence anchor; bloat audit'te ≥3 somut silme; roadmap'te ≥2 DO NOT satırı |
| m6 | Hipotezler asimetrik (H1–H7 hepsi olumlu ifade) | Her hipoteze "Falsifier:" satırı ekle — "bu hipotezi çürütecek somut gözlem nedir". Örn. **H5** için: SPEC §15.2 commit trailer'ları *"Recommended"* diyor, yani opsiyonel; opsiyonel trailer'la Fast mode işi Git'ten goal/flow/karar bazında **indekslenemez** → H5 muhtemelen ÇÜRÜR. Mevcut prompt bu çürütmeyi hedeflemiyor. |
| m7 | "Executive verdict — with the five highest-impact reasons" ama verdict tanımı yok | `ACCEPT` / `ACCEPT_WITH_CHANGES` / `REJECT` için eşik yaz: örn. "REJECT if any PROCESS invariant is violated by the design itself, or if ≥2 of A1/A4/A5/A8 must be REVERSED." |

---

## 9. Revize edilmiş prompt (v2) — kopyala-yapıştır

Aşağıdaki sürüm yukarıdaki C1–C6 ve m1–m7 düzeltmelerini içerir. Güçlü yanların hepsi korundu.

````text
# Claude Opus Terminal Review Prompt v2 — EgeSüt Unified Agent Harness

Start from the repository root:

    cd "$(git rev-parse --show-toplevel)"

---

<ROLE>
You are a principal engineer reviewing a repository-local multi-agent harness for
a production ERP. You have live terminal and filesystem access. Act as an
independent architecture, governance, developer-experience, and failure-mode
reviewer. Be skeptical of ceremony, duplicated authority, false enforcement, and
claims unsupported by the live repository. A polite review that confirms the
proposal is a failed review.
</ROLE>

<TASK>
Review the proposed unified agent harness and produce a decision-ready critique
plus a prioritized correction plan.

Primary documents:
1. .harness/design/2026-09-02-unified-agent-harness/SPEC.md
2. .harness/design/2026-09-02-unified-agent-harness/IMPLEMENTATION-PLAN.md
</TASK>

<PROCESS_INVARIANTS>
Violating any of these invalidates the review.
- Read-only. Do not modify files, install packages, start workers, create
  worktrees, commit, merge, push, deploy, mutate databases, call live providers,
  or clean anything. Single exception: the file named in <DELIVERABLE>.
- Preserve existing user-owned dirty/untracked state byte-identically. Record
  `git status --porcelain | wc -l` before and after; they must match except for
  the deliverable.
- Never fabricate paths, line numbers, commands, runtime behavior, or schema facts.
- Live schema remains the authority for DB facts. No tracked document or existing
  skill overrides it.
- Distinguish proposal defects from existing-repository defects.
- This review concerns the harness. Do not propose a product rewrite.

Allowed commands: git (ls-files, status, log, show, diff, rev-parse, worktree
list), rg, sed -n, wc, ls, cat, find, and read-only GitNexus MCP tools.
Explicitly forbidden: `gitnexus analyze` and any index refresh — it writes.
If the index is stale, report the staleness as a finding.
</PROCESS_INVARIANTS>

<CHALLENGEABLE_ASSUMPTIONS>
The proposal asserts the following. Test each; you may recommend reversing any of
them. Do NOT treat them as constraints on your conclusions.

A1. A tracked repository-local `.harness/` should be the governance source of truth.
A2. No orchestration runtime should be mandatory.
A3. ZCode Desktop should not default to Herdr; Herdr stays explicitly selected.
A4. Worker PASS must not equal root integration acceptance.
A5. Leads must not write outside declared goal docs authority.
A6. Runtime hooks warn; deterministic checks own enforcement.
A7. No vector DB / external harness is required for correctness.
A8. Fast mode must never require a pre-authored goal.

For each: KEEP / MODIFY / REVERSE, with evidence and the cost of being wrong.
Recommending REVERSE on A2, A4, A5 or A8 additionally requires you to show the
resulting design still bounds worker authority and avoids mandatory ceremony.
</CHALLENGEABLE_ASSUMPTIONS>

<CONTEXT>
SPEC.md and IMPLEMENTATION-PLAN.md govern. This prompt does not paraphrase them.

Background you cannot derive from those two documents:
- The repository already runs a working external agent infrastructure documented
  in root CLAUDE.md: tools-bank mailbox + worker registry + Event Bus,
  goose/codex/pi teammate bridges, worktree-per-lane scripts, a local-embedding
  memory store and a cloud-embedding code index. The proposal never states how it
  coexists with, subsumes, or retires this. Treat that as a first-class question.
- The owner operates this repository effectively alone; owner/root/lead/worker/
  verifier all map onto one human plus N agents.
- Documentation is mixed Turkish/English; the harness documents are English.
</CONTEXT>

<REPO_BASELINE>
Measured at HEAD e8cd620 on 2026-09-02. RE-VERIFY; treat any mismatch as a finding.

  git ls-files .harness | wc -l              # 0   -> .harness is UNTRACKED
  git ls-files .claude  | wc -l              # 23  -> .claude is PARTLY TRACKED
  git ls-files .agents .qwen .zcode | wc -l  # 0
  wc -l AGENTS.md CLAUDE.md                  # 577 / 422
  ls tests/                                  # no tests/harness/ yet
  git status --porcelain | wc -l             # ~46; preserve all

Implications for your effort/risk estimates:
- "tracked .harness/" is a target state, not the current state.
- "short AGENTS.md" means splitting ~1000 lines of live policy.
- .qwen/.agents/.zcode retirement is mostly a non-Git operation.
- tests/harness/ and .harness/bin/harness.py DO NOT EXIST. Do not run them.
</REPO_BASELINE>

<EXECUTION>
Two passes, one session.

PASS 1 — EVIDENCE (mechanical, no judgment)
Table: Claim | Source (SPEC §/PLAN §) | Status (TRUE/FALSE/UNVERIFIABLE) |
Evidence (command + first output line, or path:line).
Minimum 15 rows. Cover every asserted path, every assumed runtime behavior, and
every "current state" claim.

Then the CROSS_DOCUMENT_CHECK below. Write PASS 1 to the deliverable, then continue.

PASS 2 — JUDGMENT
Using only PASS 1 evidence plus the two documents, produce the output sections.
Every VERIFIED label in PASS 2 must point to a PASS 1 row.
</EXECUTION>

<CROSS_DOCUMENT_CHECK>
(1) Layout coverage: every path in SPEC §4's tree x the PLAN phase that creates it.
    Flag: SPEC paths with no creating phase; PLAN manifest paths absent from
    SPEC §4; canonical record types with no schema under .harness/schemas/.
(2) Dependency order: per phase, artifacts it validates that a LATER phase defines.
    Any backward dependency is a finding.
Report both in output §3 even if minor. Do not fold into prose.
</CROSS_DOCUMENT_CHECK>

<HYPOTHESES>
For each: CONFIRM / REFUTE / EXTEND, and state the Falsifier you actually checked.

H1 tracked .harness/ reduces worktree and runtime-discovery drift more reliably
   than the existing external infrastructure.
   Falsifier: a drift class the tracked layout cannot detect but the current
   registry/bridge setup does.
H2 Generated BOARD/HANDOFF/index views reduce concurrency conflicts.
   Falsifier: narrative loss, or a generator-as-authority failure, or a
   regenerate-on-every-merge conflict path with 2 leads + root on main.
H3 Docs-update at checkpoints with NO_CHANGE_REQUIRED prevents omission without churn.
   Falsifier: a checkpoint whose evaluation can be satisfied without reading the diff.
H4 Goal-level docs_authority suffices to constrain leads if checked against
   diff and staged paths.
   Falsifier: a lead write that the staged-path check cannot see.
H5 Indexing ad-hoc root/lead work from Git makes Fast mode queryable without a goal.
   Falsifier: SPEC §15.2 marks commit trailers "Recommended" (optional). Determine
   whether goal/flow/decision is recoverable from an untrailered commit. If not,
   H5 is REFUTED and you must say so plainly.
H6 Root `merge --no-commit` + main docs reconciliation is useful but may be fragile.
   Falsifier: a dirty-tree or conflict scenario that strands the repo mid-merge.
H7 Warning-only hooks + explicit lifecycle checks beat blocking hooks here.
   Falsifier: an enforcement gap that only a blocking hook closes.
H8 The phased plan still contains removable bloat.
   Falsifier: none needed — name the removals or state there are none.
</HYPOTHESES>

<REVIEW_QUESTIONS>
Answer each inside the listed section. End with a "Question coverage" table
mapping every Q to the section and paragraph that answers it. Anything
unanswered must be listed as UNANSWERED with a reason.

Q1  Authority model completeness / contradiction resistance             -> §5
Q2  Role boundary precision, and which roles collapse for one operator  -> §5
Q3  Fast/Full trigger minimality and enforceability                     -> §3, §8
Q4  Queryability of goal + worktree + ad-hoc history from Git alone     -> §8
Q5  Docs-update state machine completeness and fakeability              -> §6
Q6  BOARD/HANDOFF: generated vs partial vs curated (least error-prone)  -> §6
Q7  Memory promotion rules vs creating a second stale knowledge system  -> §6
Q8  Git lifecycle: direct-main, worktree, --no-commit, rollback, dirty  -> §7
Q9  Check placement: warning hook vs command vs test vs review vs owner -> §5, §7
Q10 Product-test vs harness-test separation                             -> §3, §4
Q11 Coexistence with the existing tools-bank/bridge/registry infra      -> §3, §9
Q12 Smallest first increment with least irreversible commitment         -> §9, §10
</REVIEW_QUESTIONS>

<UNCERTAINTY_HANDLING>
Label material findings VERIFIED (with a PASS 1 evidence row), HYPOTHESIS, or
DECISION_NEEDED (owner policy, not technical inference).
</UNCERTAINTY_HANDLING>

<OUTPUT_FORMAT>
Write in English. Quote Turkish source lines verbatim when citing them.

1.  Executive verdict — ACCEPT / ACCEPT_WITH_CHANGES / REJECT + five reasons.
    Thresholds: REJECT if the design itself violates a process invariant, or if
    two or more of A1/A4/A5/A8 must be REVERSED. ACCEPT only if no Critical
    finding remains open.
2.  Verified strengths — only properties that genuinely reduce drift, ambiguity,
    or operator load.
3.  Critical findings — severity-ordered; evidence anchor + concrete correction
    each. Must include the CROSS_DOCUMENT_CHECK results.
4.  Bloat audit — files, phases, metadata, checkpoints, ceremony to delete or
    merge. Must include: (a) estimated LLM calls and operator prompts per Full
    goal vs. the current workflow for the same unit of work; (b) for each of the
    8 checkpoint kinds, the specific failure it prevents — if you cannot name
    the failure, mark it DELETE; (c) minimum 3 concrete deletions.
5.  Authority matrix — owner/root/lead/worker/verifier x code, docs, goal,
    worktree, commit, merge, push, deploy, DB.
6.  Docs-update review — checkpoint matrix, canonical/generated boundary,
    authority enforcement, memory/handoff/board behavior, omission risks.
7.  Git lifecycle review — Fast direct-main and Full worktree flows: commit,
    merge, push, rollback, dirty-tree failure modes.
8.  Goal/worktree/index review — queryability, state transitions, lineage,
    stale-goal handling, reconstruction from Git.
9.  Revised minimum viable architecture — smallest corrected tree and contract
    to pilot first.
10. Prioritized roadmap — Rank | Change | Why | Impact | Effort | Risk |
    Acceptance evidence. Minimum two explicit DO NOT rows.
11. Owner decisions required — at most seven.
12. Final recommendation — implement / revise first / abandon.
13. Self-check attestation — each SELF_CHECK item, ✓ or ✗, one-sentence reason.

No generic multi-agent advice. Ground everything in these files and this repo.
</OUTPUT_FORMAT>

<DELIVERABLE>
Write the full review to exactly one file:

  .harness/design/2026-09-02-unified-agent-harness/REVIEW-<reviewer-id>-<YYYY-MM-DD>.md

This is the ONLY permitted write. Do not `git add` or commit it. Do not modify
SPEC.md or IMPLEMENTATION-PLAN.md.

File header must record: reviewer id, model, date, `git rev-parse --short HEAD`,
`git status --porcelain | wc -l` before and after, and every file you read.

Print to the terminal ONLY: the executive verdict, the top five findings, and the
deliverable's absolute path.
</DELIVERABLE>

<SELF_CHECK>
Attest to each in output §13:
- every process invariant preserved;
- Fast work was not silently turned into mandatory goals;
- no orchestrator was made mandatory;
- warning hooks were not confused with deterministic acceptance;
- docs-update omission AND bloat were both addressed;
- every criticism carries an implementable correction;
- VERIFIED / HYPOTHESIS / DECISION_NEEDED are cleanly separated;
- every A1–A8 assumption received an explicit KEEP/MODIFY/REVERSE;
- every H1–H8 hypothesis received a Falsifier that was actually checked;
- the Question coverage table is complete.
</SELF_CHECK>
````

---

## 10. Öncelikli değişiklik listesi

Sadece bir kısmını uygulayacaksan, sıra bu:

| Sıra | Değişiklik | Neden | Efor |
|---|---|---|---|
| 1 | `HARD_INVARIANTS` → `PROCESS_INVARIANTS` + `CHALLENGEABLE_ASSUMPTIONS` ayrımı (C1) | Tek başına en yüksek etkili. Review'ın SPEC'in tezini sorgulayabilmesini sağlar. | 10 dk |
| 2 | `<DELIVERABLE>` bloğu (C5) | Çıktı kalıcı olur, talimat çelişkisi kalkar, `base_sha` kayda geçer. | 5 dk |
| 3 | `<REPO_BASELINE>` bloğu (C3) | Reviewer'ın keşfe harcayacağı bütçeyi bulguya kaydırır; 5 yanlış varsayımı önler. | 10 dk |
| 4 | İki-pass execution (C4a) | Kanıt önce, yargı sonra — halüsinasyon ve kesilme riskini birlikte düşürür. | 5 dk |
| 5 | Q11 (koexistans) + Q2'ye tek-operatör eklemesi (C6.2) | Bu repoya özgü, en pahalı iki gerçek soru. | 5 dk |
| 6 | `<CROSS_DOCUMENT_CHECK>` (C6.1) | Zaten üç somut boşluk var; mekanik ve ucuz. | 10 dk |
| 7 | Soru konsolidasyonu + bölüm eşlemesi (C4b) | 30 örtüşen soru → 12; tekrar eden bölümleri engeller. | 15 dk |
| 8 | Falsifier'lar (m6) + verdict eşikleri (m7) + §13 attestation (m3) | Review'ı denetlenebilir kılar. | 15 dk |

**DO NOT:**
- Prompt'a daha fazla çıktı bölümü ekleme. Sorun az bölüm değil, **çok bölüm**.
- `<ROLE>` ve `UNCERTAINTY_HANDLING` bloklarına dokunma; ikisi de doğru yazılmış.
- Review'ı bir subagent'a fanout ederek paralelleştirme — bu review'ın değeri
  bütünsel tutarlılıkta, ve parçalara bölünürse authority matrisi ile git lifecycle
  bölümleri birbirinden habersiz çelişir.

---

## 11. Prompt'un yakalayamayacağı, mevcut haliyle kaçacak bulgular (örnekleme)

Aşağıdakiler bu meta-review sırasında **iki dokümanı okuyarak** bulundu ve mevcut prompt'un
soru/hipotez listesi bunları hedeflemiyor. Prompt v2 (§9) her birini hedefler.

1. **`.harness/runtimes/` SPEC layout'unda yok ama Phase 1 onu yazıyor.** — hedefleyen:
   `CROSS_DOCUMENT_CHECK (1)`
2. **`.harness/decisions/` hiçbir fazda yaratılmıyor ve şeması yok.** — hedefleyen:
   `CROSS_DOCUMENT_CHECK (1)`
3. **Phase 2'nin goal şeması, Phase 3'te tanımlanan `docs_verdict` enum'una bağımlı.** —
   hedefleyen: `CROSS_DOCUMENT_CHECK (2)`
4. **SPEC §15.2 commit trailer'ları "Recommended" (opsiyonel) diyor; H5'in ("Fast mode Git'ten
   queryable") dayandığı tek mekanizma bu.** Opsiyonel trailer = güvenilmez indeks. — hedefleyen:
   `H5 Falsifier`
5. **`schema-summary.md` tracked referans olarak öneriliyor** (SPEC §4) ama bu repoda canlı şema
   tek doğruluk kaynağı; tracked bir özet **yeni bir bayatlık kaynağı** yaratır — tam da SPEC'in
   çözmeye çalıştığı problem. — hedefleyen: Q7 + A1 testi
6. **Mevcut worker registry (`worker_list.py`, `tb-worker`) ile `harness worktrees` iki ayrı
   gerçeklik kaydı.** — hedefleyen: Q11
7. **`AGENTS.md` 577 + `CLAUDE.md` 422 satır**; "short map"e indirme işi Phase 1'in en büyük
   kalemi ve PLAN'da hiç boyutlandırılmamış. — hedefleyen: `REPO_BASELINE`

---

## 12. Sonuç

Prompt **iyi yazılmış ama fazla ikna edici**. En büyük riski, teknik bir eksiklik değil,
epistemik bir eksiklik: reviewer'a SPEC'in sonuçlarını invariant olarak verip sonra "skeptik ol"
demek. Bu iki talimat birbirini iptal eder ve pratikte ikincisi kaybeder.

C1 (invariant/varsayım ayrımı) ve C5 (deliverable) tek başına uygulanırsa bile review'ın değeri
belirgin biçimde artar. §9'daki v2 doğrudan kullanılabilir.

Son not: prompt, SPEC'in kendi disiplinlerini (base_sha kaydı, kanıt-önce, kabul kriteri,
denetlenebilir verdict) kendi üzerinde uygulamıyor. Bir governance önerisini değerlendiren
review'ın, o governance'ın kurallarına kendisinin uyması hem tutarlılık hem de ilk gerçek
pilot testtir — v2 bunu yapar.
