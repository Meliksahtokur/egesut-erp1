# PART-07 — Ajanlar için uygulama haritası ve bayatlık tespiti

## Repo içi bilgi mimarisi

`AGENTS.md` kodlama ajanlarına proje talimatı vermek için yaygın açık format; uygulamanın kendisinin domain graph'ını taşımak için kanonik veri formatı değildir. [S40]

Öneri:

```text
AGENTS.md
  -> "UI/DB davranışı hakkında varsayım yapma; atlas/index.json'a bak"

atlas/
  index.json
  flows/
    repro.insemination_to_pregcheck/
      flow.yaml
      FLOW.md
      flow.mmd
      evidence/
  entities/
    rpc.json
    tables.json
    triggers.json
    cron.json
```

`llms.txt` web'de LLM tüketimi için site summary/document discovery formatı olarak düşünülür; repo içi executable flow graph yerine kullanmak semantik olarak zayıf. [S41]

## Flow sayfası iskeleti

```markdown
# Flow: Tohumlama → Gebelik Kontrol
Status: VERIFIED / STALE / PARTIAL
Last verified: commit, date, demo fixture

## User journey
Mermaid stateDiagram

## Runtime sequence
Mermaid sequenceDiagram

## Chain
| Step | UI | JS | RPC | DB | Evidence |

## Producers / side effects
| Output | Producer | Condition | Timing | Evidence |

## Offline behavior
IndexedDB stores + sync rule

## Known alternatives
retry / confirm dismiss / empty result / offline

## Evidence
trace, HAR, screenshot, SQL output

## Staleness inputs
source globs + schema objects + test names
```

## Bayatlık kapısı

### 1. Source hash / glob invalidation

Flow metadata `source_globs` tutar. Git diff bu globs'a dokunuyorsa:

```text
VERIFIED -> DIRTY
```

Bu yalnız “yeniden doğrula” sinyalidir; flow'un gerçekten bozulduğunu iddia etmez.

### 2. E2E live document

Her kritik flow için bir Playwright test. Test geçerse ve evidence schema tam ise `last_verified_commit` güncellenir.

### 3. Visual/ARIA snapshot

Playwright screenshot comparison ve ARIA snapshot assertion, UI state'in beklenmeyen değişimini yakalamak için kullanılabilir. Screenshot baseline aynı ortamda üretilmeli; rendering ortam farkları false positive üretebilir. [S42][S43]

### 4. Runtime edge fingerprint

Örnek fingerprint:

```text
hash(sorted([
  "ui.save->rpc.save_insemination",
  "rpc.save_insemination->table.inseminations",
  "rpc.save_insemination->task.pregcheck_35d"
]))
```

Yeni run edge set'ini değiştirirse doc stale.

### 5. DB object fingerprint

- `pg_get_functiondef(function_oid)` hash
- `pg_get_triggerdef(trigger_oid)` hash
- normalized `cron.job.command + schedule`

Hash değiştiyse ilişkili flow DIRTY.

## Agent query deneyimi

Ajanın büyük Markdown dosyası okuması yerine küçük query CLI/MCP:

```bash
flow-atlas find --output task:pregnancy_check
flow-atlas trace ui:insemination.save
flow-atlas producers task:pregnancy_check
flow-atlas stale --since HEAD~1
```

JSON çıktısı:

```json
{
  "producers": [
    {"id":"rpc:...", "offset_days":21, "confidence":"confirmed-both"},
    {"id":"rpc:...", "offset_days":35, "confidence":"confirmed-both"},
    {"id":"cron:...", "offset_days":40, "confidence":"confirmed-static"}
  ]
}
```

Bu “ajan kodu dosya dosya okuyup zihninde birleştirsin” problemine doğrudan karşı çözüm.
