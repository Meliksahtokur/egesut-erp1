# ADR-007 — Multi-Tier Goose Orchestration Mimarisi

**Tarih:** 2026-05-18  
**Durum:** TASARIM ONAYLANDI — summon MCP testi geçti, goused-api geliştirmeleri bekliyor  
**Sonraki adım:** goused-api commit lock → tier slots → cascade kill → goose-ops recipe

---

## Bağlam

EgeSüt ERP'de Claude tek başına orkestrasyon yapıyor, Goose ise tek seferlik görevler için çağrılıyor. Goose'un araç kullanım hızı ve güvenilirliği (kernel seviyesinde Rust işlemleri, neredeyse sıfır latency) bu rolü çok daha verimli kılıyor. Hedef: Claude sadece üst kararlar alsın, orta kademe yönetimi Goose'a devredilsin.

**Gözlem:** conductor recipe testi sırasında (spec-001-task-logic-audit, 2026-05-18) Goose'un tool call hızı ve doğruluğu dikkat çekiciydi. deepseek-tui'den daha hızlı, daha az hata.

---

## Karar: Hiyerarşik Çok Katmanlı Mimari

```
Tier 0 — Claude (CEO)
  • Kullanıcının tek muhatabı
  • Üst kararlar, onay/ret
  • telsiz üzerinden orchestrator'a direktif gönderir
  • Max 3 orchestrator slot yönetir
  
  agent_send(to="goose-ops-A", message="görevi şu...", type="task")
  agent_receive(agent_id="claude", timeout=600)  ← sonucu bekler

Tier 1 — Goose Orchestrator / goose-ops (max 3 eşzamanlı)
  • Görevi analiz eder, planlar, parçalar
  • Worker'ları spawn eder ve yönetir
  • Blackboard'a plan + checkpoint yazar
  • Riskli karar → approval_req Claude'a
  • Bitince exit (per-task fresh context)

  Her orchestrator max 3 worker yönetir

Tier 2 — Goose Workers (max 3 per orchestrator = 6 toplam)
  • egesut-telsiz, researcher, worker recipe'lerinden biri
  • Tek bir task, bitince exit
  • task_claim → çalış → git commit (lock ile) → task_complete

TOPLAM MAX: 1 Claude + 3 Orchestrator + 9 Worker = 13 agent
```

---

## Per-Task Spawn Kararı (Daemon DEĞİL)

**Neden daemon çalışmıyor:**
- Context window dolar (~128K, 5-6 karmaşık görevde)
- Çoklu görev context'i karışır
- Bir crash tüm kuyruğu öldürür

**Per-task spawn avantajları:**
- Her görev fresh context ile başlar
- Crash izole — sadece o görev etkilenir
- Exit sonrası MCP process'leri serbest kalır
- Debug edilebilir ("hangi görevde hata?" açık)

**Kural:** Orchestrator bir görevi alır → çalışır → exit. Yeni görev = yeni spawn.

---

## İletişim Katmanları (3 Katman)

### Katman 1: Telsiz (real-time, ephemeral)
```
Claude → Orchestrator : task direktifi
Worker → Orchestrator : TAMAMLANDI / HATA
Orchestrator → Claude : approval_req (riskli durumlar)
Orchestrator → Claude : SPEC TAMAMLANDI (final)
```
- Kısa TTL, anlık haberleşme
- goused-telsiz (:8744), SQLite long-poll

### Katman 2: Blackboard (persistent, crash-safe)
```
blackboard/plans/{ops-id}.md     ← orchestrator planı + stage checkpoints
blackboard/working/{worker-id}.md ← worker progress ([ ] → [x])
```
- Crash → dosyadan kaldığı yerden devam
- Stage-based: Stage 1 [done], Stage 2 [in_progress]...
- Human-readable, git'e commit edilebilir

### Katman 3: Task DB — Pull Model
```
Orchestrator: task_create("migration yaz", priority="high")
Worker:       task_claim(task_id)  ← boşa düşünce kendisi çeker
Worker:       task_complete(task_id, result="commit: abc123")
Orchestrator: task_review(task_id) → approve/reject
```
- Pull model: worker hazır olunca çeker, orchestrator push etmez
- Worker crash → task claimed kalır → timeout → pending'e döner (self-healing)
- task_create/claim/complete/review MCP tools zaten mevcut (tools-bank)

---

## Orchestrator Tam Akışı (goose-ops.yaml)

```
1. agent_receive(agent_id=ops_id, timeout=60)
   → Claude'dan direktif geldi

2. Analiz:
   memory_search("görevle ilgili geçmiş")
   semantic_search("ilgili kod")
   gitnexus_query("etkilenecek semboller")
   file_read(".claude/rpc-reference.md")

3. Plan yaz (crash recovery için):
   file_write("blackboard/plans/ops-{id}.md")
   içerik: Stage 1: ..., Stage 2: ..., kabul kriterleri

4. Task'lara böl:
   task_create("migration: anyonik_besleme_gorev_yarat", priority="high")
   task_create("js: gorev listesine anyonik tip ekle", priority="medium")
   task_create("test: migration deploy + grep doğrulama", priority="low")

5. Worker spawn:
   goose_start("egesut-telsiz", "worker-{ops-id}-1", {agent_id, task_id})
   goose_start("egesut-telsiz", "worker-{ops-id}-2", {agent_id, task_id})
   [veya summon native — test sonucuna göre, bkz. Açık Sorular]

6. Worker directive (telsiz):
   agent_send(to="worker-{id}", message=task_detayı, type="task")

7. Monitor loop:
   task_list(status="pending|in_progress")
   goose_status(session_id=worker_id)
   Hata → 2 retry → approval_req Claude'a

8. Review (ayrı reviewer subagent — orchestrator kendi işini review ETMEZ):
   goose_start("reviewer", "reviewer-{ops-id}")
   agent_send(to=reviewer, kriterleri gönder)
   agent_receive → approve/reject

9. Final:
   file_write("blackboard/plans/ops-{id}.md")  ← Stage N [done]
   agent_send(to="claude", "TAMAMLANDI: commit_hash — özet", type="result")
   exit
```

---

## Review Sistemi — Neden Orchestrator Kendi İşini Review Edemez

**Problem:** Orchestrator planı yapan taraftır. Kendi worker'larının çıktısını review ederse:
- Confirmation bias: "Ben söyledim, o yaptı, doğrudur"
- Context contamination: planı bilen biri objektif review yapamaz

**Seçenekler:**
- A) Claude review eder (approval_req via telsiz) → en güvenilir, yavaş
- B) Orchestrator B, Orchestrator A'nın çıktısını review eder
- C) **Dedicated reviewer subagent** (tercih edilen) — sadece kabul kriterleri bilir, ne yapıldığını bilmez

reviewer.yaml zaten mevcut (`/root/tools-bank/recipes/reviewer.yaml`).

---

## goused-api Planlanan Geliştirmeler

**Henüz yapılmadı. Öncelik sırasıyla:**

### 1. Commit Lock (KRİTİK — git race condition)
```go
// POST /commit-lock/acquire  → 200 OK | 423 Locked
// POST /commit-lock/release

// Worker akışı:
// acquire → git add → git commit → git push → release
// Go mutex + TTL (crash'e karşı otomatik release)
```
3 worker aynı anda commit yaparsa: corrupt commit, kayıp değişiklik.

### 2. Tier-Based Slot Enforcement
```go
// goose_sessions tablosuna tier INT kolonu ekle
// Tier1 (orchestrator): max 3 running
// Tier2 (worker): max 3 per parent_session_id
// HTTP 429 döner slot doluysa
```

### 3. parent_session_id
```sql
ALTER TABLE goose_sessions ADD parent_session_id TEXT;
-- Orchestrator worker spawn ederken kendi session_id'sini geçer
```

### 4. Cascade Kill
```
POST /goose/stop-tree/:id
→ session + tüm children (parent_session_id = id) SIGTERM
```

### 5. Heartbeat Watchdog
```
Orchestrator her 30s: agent_send(type="heartbeat")
goused-api 90s heartbeat gelmezse: cascade kill + slot serbest bırak
```

---

## Açık Sorular — Test Edilmesi Gereken

### ✅ TAMAMLANDI: Goose Native Subagent MCP Paylaşımı

**Test tarihi:** 2026-05-18  
**Test recipe:** `/root/tools-bank/recipes/summon-test.yaml`  
**Sonuç:** `MCP_ACCESSIBLE=true` — **PAYLAŞILIYOR**

Binary analizi (2026-05-18) şunları gösterdi:
- `sub_agent` session tipi mevcut
- `subagent_created` notification tipi var
- `summon` extension: "Load knowledge and delegate tasks to subagents"
- `sub_recipes` field recipe YAML struct'ında mevcut
- `delegatesubagent` + `resuming builtin` → subagent resumable
- Native tools fire-and-forget DEĞİL: interrupt + stop mevcut

**Karar:** Tier-2 workers için native summon kullanılacak.
- 8 goose için sadece **2 MCP process** (orchestrator'ın mcp'leri, workers inherit eder)
- Tier-1 orchestrator hâlâ goused-api ile spawn edilir (Claude tarafından görülebilir)
- Tablet "ciğer sokma" riski ortadan kalktı

---

## Resource Hesabı

```
goused-api spawn modeli (şu an):
  8 goose × 2 MCP (tools-bank + duckduckgo) = 16 ekstra process
  Azaltma: duckduckgo sadece researcher recipe → gerçek max ~10 process

Native summon MCP paylaşım modeli (✅ TEST GEÇTİ — 2026-05-18):
  2 orchestrator × 2 MCP = 4 ekstra process (workers inherit)
  Çok daha verimli — KULLANILACAK MODEL BU

Kullanıcı notu: "şu an sorun yok ama tablet bir aşamada ciğer sokabilir"
→ Summon paylaşım testi geçti — 4 process yeterli, tablet riski yok
```

---

## Uygulama Sırası

```
[x] 1. summon MCP paylaşım testi — TAMAMLANDI, MCP paylaşılıyor (2026-05-18)
[x] 2. goused-api: commit lock endpoint — TAMAMLANDI (2026-05-18)
[x] 3. goused-api: parent_session_id + tier slots + cascade kill — TAMAMLANDI (2026-05-18)
[x] 4. goused-api: heartbeat watchdog — TAMAMLANDI (2026-05-18)
[ ] 5. goose-ops.yaml recipe yaz (orchestrator)
[ ] 6. egesut-telsiz.yaml: commit lock acquire/release ekle
[ ] 7. kaz-cobani skill güncelle (Claude + deepseek-tui)
[ ] 8. Gerçek bug fix → bu sistemle Goose'a ver (ilk gerçek orkestrasyon testi)
```

---

## Conductor → goose-ops Geçiş

Mevcut `conductor.yaml` + `orchestrator.yaml` → `goose-ops.yaml` ile değiştirilecek.

conductor.yaml: spec-based executor (kendi içinde değerli, karmaşık çok adımlı görevler için kullanılabilir)
orchestrator.yaml: spec designer (goose-ops içinde eriyecek)
goose-ops.yaml: YENİ — analiz + plan + exec + review + report, tek recipe

---

## Claude'un Operasyonel Kullanımı

```python
# Oturum başında (CLAUDE.md oturum başlangıcına eklenecek):
agent_register("claude", ["orchestrate","approve","review"])
agent_receive("claude", timeout=1)  # bekleyen mesaj var mı?

# Görev vermek:
agent_send(
  to="goose-ops-A",       # hangi orchestrator
  from_="claude",
  message="""
    Görev: anyonik besleme pre-birth görevi ekle
    Detay: 250. gün, tüm gebeler, ILERI_GEBE tipi
    Pattern: SC Ademin (260. gün) ile aynı
    Kabul: migration deploy edilmiş, ileri_gebe_gorev_kontrol test geçiyor
    Riskli değişiklik varsa approval iste
  """,
  message_type="task",
  priority="high"
)

# Sonuç bekle:
result = agent_receive("claude", timeout=900)
# → "TAMAMLANDI: abc123 — anyonik_besleme_gorev_yarat eklendi, deploy edildi"

# Approval gelirlerse:
# agent_send(to="goose-ops-A", message="Onaylıyorum", type="answer")
```

---

## Bu Dokümana Referans

- `.claude/arch-decisions/ADR-007-multi-tier-goose-orchestration.md` (bu dosya)
- İlgili: `ADR-006-agent-telsiz-mimarisi.md`
- Recipe'ler: `/root/tools-bank/recipes/` (conductor, orchestrator, egesut-telsiz, reviewer)
- goused-api kaynak: `/root/tools-bank/internal/api/session.go`
- Test edilecek: summon extension, sub_recipes YAML field
