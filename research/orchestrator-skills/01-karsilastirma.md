# Karşılaştırma: orchestrator-master vs alisherry/claude-skills

> Kaynak: `alisherry/claude-skills/multi-agent-orchestration/SKILL.md` — 84KB'lik kapsamlı bir skill

## Ortak Yanlar

| Özellik | orchestrator-master | alisherry/orchestration |
|---------|-------------------|------------------------|
| Sub-agent spawning | ✅ `agent_open` | ✅ Agent spawn |
| Worker types | Sub-orch / leaf | Simple / Resilient / Sub-Orch |
| Territory control | ✅ Write disjoint, read overlapping | ❌ Yok (serbest) |
| Quota management | ✅ Maks 20, sub-orch kotalı | ❌ Yok (sınırsız spawn) |
| Depth control | ✅ max_depth (0-3) | ❌ Yok (sınırsız) |
| Parallel execution | ✅ Batch all in one turn | ✅ Swarm |
| Sequential mode | ✅ Tightly-coupled files | ❌ Varsayılan hep parallel |
| S.A.F.E.R. workflow | ✅ Scout-Ask-Fork-Evaluate-Review | ❌ Kendi workflow'u var |
| Language rules | ✅ EN internal, TR user | ❌ Hep İngilizce |
| Error handling | ✅ Tablo + fallback | ❌ Sadece "retry" |
| MCP tools reference | ✅ | ✅ |

## alisherry'de Olup Bizde Olmayanlar

| Özellik | Ne işe yarar | Eklemeli miyiz? |
|---------|-------------|-----------------|
| **Worker Mode** (ilk satırda rol tespiti) | "Are you orchestrator or worker?" — agent kendi rolünü prompt'tan algılar | 🟡 Orta — faydalı ama mevcut sistemde sub-orch/laf ayrımı zaten var |
| **Simple vs Resilient Worker** | Resilient'ın failure budget'ı var (5-10 deneme), simple tek deneme | 🟢 Evet — failure budget eklenebilir |
| **Pattern Adherence Workflow** | Önce kod analizi yap, sonra pattern'leri tespit et, sonra implement et (4 adım) | 🟢 Evet — büyük refactor'larda işe yarar |
| **Domain Guides** | Her domain için ayrı guide (frontend, backend, testing, etc.) | 🟡 Orta — projeye özel değil |
| **Anti-Patterns Tablosu** | "Never do X" listesi | 🟢 Evet — eklenebilir |
| **Persona/Flavor** | Flamboyant "Conductor" persona, ASCII art, milestone celebrations | 🔴 Hayır — biz sade/teknik duruyoruz |
| **Signature Bar** | Her yanıt sonunda `─── ◈ Orchestrating ──` | 🟡 Orta — isteğe bağlı |

## AgentPower.io Multi-Agent Patterns

**Kaynak:** agentpower.io/guides/multi-agent-orchestration/

Bu kaynak bir skill DEĞİL, AGENTS.md için pattern rehberi. Öne çıkanlar:

| Pattern | Ne işe yarar | not |
|---------|-------------|-----|
| Single-Agent | Role tanımı, sınırlar, yasaklar | Bizde skill'in kendisi zaten bu |
| Manager + Worker | Merkezi orchestrator, uzman worker'lar | Bizdeki hierarchical mode |
| Pipeline | Sequential adımlar (A→B→C) | Kısmen var (sequential mode) |
| Cross-Tool | Claude + Codex + Cursor koordinasyonu | Bizim için geçerli değil |

**Anti-Patterns (alınabilir):**
1. Swiss Army Knife — her işi yapan agent → başarısız
2. The Rule Lawyer — 147 kural → hiçbiri uygulanmaz
3. The Micromanager — worker'ı 30sn'de bir kontrol et
4. The Telepathic Handoff — "bir yere bırak, bulur" → explicit handoff şart

## Azure Agent Design Patterns

**Kaynak:** learn.microsoft.com/en-us/azure/architecture/ai-ml/guide/ai-agent-design-patterns

| Pattern | Bizde var mı? |
|---------|--------------|
| Sequential | ✅ (parallel/sequential kararı) |
| Concurrent | ✅ (parallel research mode) |
| Group Chat | ❌ — ihtiyaç yok |
| Handoff | ✅ (sub-orch parent'a raporlar) |
| Magentic (many-to-many) | ❌ — ihtiyaç yok |

## Feature Gap: Ne Eksik, Ne Eklenebilir

### Eksik — Eklenmeli

1. **Worker Mode auto-detection** — agent prompt'ta "You are a WORKER" varsa sub-agent açma
2. **Simple vs Resilient worker** — resilient'ın failure budget'ı var (N deneme)
3. **Pattern adherence** — refactor öncesi "önce kod yapısını analiz et, pattern'leri çıkar"
4. **Anti-Patterns listesi** — "Yapma" listesi (skill'e eklenmeli)
5. **Failure budget** — sub-orch'lara max hata sayısı ver

### İhtiyaç Yok

1. Persona/flavor (ASCII art, milestone celebrations) — biz soğukkanlı duruyoruz
2. Domain-specific guides — projeye özel olmalı, genel skill'de olmaz
3. Group chat pattern — bu proje için gereksiz
4. Cross-tool coordination — sadece bir araç kullanıyoruz
