# Ruflo Projesi Detaylı İnceleme

**Tarih:** 2026-05-24
**Kaynak:** https://github.com/ruvnet/ruflo (aka claude-flow)
**Versiyon:** v3.7.0-alpha.81

---

## 1. Proje Kimliği

| Özellik | Değer |
|---------|-------|
| Yıldız | 54.6k |
| Fork | 6.2k |
| Dil | TypeScript (%87), JavaScript (%6.4), Shell (%3.5), Svelte (%1.7), Rust (%0.7), PLpgSQL (%0.5) |
| Lisans | MIT |
| Yayıncı | `ruflo` (npm) |
| CLI | `claude-flow` bin |
| Repo büyüklüğü | ~20 MiB (TypeScript kodu) |
| Paketler | Monorepo — `v3/@claude-flow/` altında ~25 npm paketi |

---

## 2. Mimari Katmanlar

Ruflo'nun mimarisi 5 katmandan oluşur:

```
Kullanıcı → Claude Code / CLI
              │
              ▼
        Orchestration Layer
        (MCP Server, Router, 27 Hooks)
              │
              ▼
        Swarm Coordination
        (Queen, Topology, Consensus)
              │
              ▼
        100+ Specialized Agents
        (coder, tester, reviewer, architect...)
              │
              ▼
        Memory & Learning
        (AgentDB, HNSW, SONA, ReasoningBank)
              │
              ▼
        LLM Providers
        (Claude, GPT, Gemini, Cohere, Ollama)
```

### 2.1 Orchestration Layer
- **MCP Server**: Model Context Protocol sunucusu — 300+ MCP aracı
- **Router**: Thompson sampling ile model routing (3-kademeli, cost-adjusted multi-armed bandit)
- **27 Hook**: Pre/post-task, model-route, model-outcome, edit-train vb.
- **12 Background Worker**: audit, optimize, consolidate (periyodik, priority'li)

### 2.2 Swarm Coordination
- **Queen-led hierarchy**: Strategic (planlama), Tactical (yürütme), Adaptive (optimizasyon) queen'ler
- **8 Worker Type**: Researcher, Coder, Analyst, Tester, Architect, Reviewer, Optimizer, Documenter
- **3 Consensus Algorithm**: Majority, Weighted (Queen 3x), Byzantine (f < n/3)
- **Anti-drift**: Hiyerarşik topoloji + checkpoint'lerle task sapmasını önleme
- **Hive Mind**: Kolektif bellek, LRU cache, SQLite WAL persistence

### 2.3 Agent System
- **43 agent definition** (`.agents/` altında)
- Typed agent IDs, rolleri, durumları
- ToolRegistry: O(1) lookup + şema validasyonu
- Plugin manager: npm tabanlı, 32 plugin

### 2.4 Memory & Learning
- **HNSW**: Hiyerarşik navigasyon, 150x-12500x hızlanma
- **AgentDB**: SQLite + WAL, per-agent isolation + cross-agent transfer
- **SONA**: Self-Optimizing Neural Architecture, sub-ms pattern matching
- **ReasoningBank**: Çıkarım önbelleği
- **PatternLearner**: Outcome-based öğrenme, Mulberry32 PRNG
- **MicroLoRA + EWC++**: Hafif adaptasyon, tam retrain gerekmez

### 2.5 Providers & Federation
- 5 LLM provider: Anthropic, OpenAI, Google, Cohere, Ollama
- Failover — provider düşerse otomatik geçiş
- **Federation**: Swarm'lar arası iletişim (WebSocket, PII stripping, trust scoring)

---

## 3. Öne Çıkan Teknik Özellikler

### 3.1 Config-Driven Orchestration (`.agents/config.toml`)
TOML dosyası üzerinden:
- Model seçimi
- Approval politikası (4 seviye)
- Sandbox modu (3 seviye)
- MCP server tanımı
- Skill yükleme (path bazlı)
- Profiller (dev/safe/ci)
- Neural/Swarm parametreleri
- Hook ve worker yapılandırması

### 3.2 Thompson Sampling Model Router
Statik threshold yerine Bayesian multi-armed bandit:
- `hooks_model-outcome`: Beta(α, β) prior güncellemesi
- `hooks_model-route`: θ ~ Beta(α, β) sample + argmax
- ~50 outcome sonra routing kendi kendini düzeltir
- Maliyet: 45 µs per route call

### 3.3 CLI-Core Performance
- CLI-Core: sadece memory komutları (SQLite/HNSW/ONNX yok)
- Cold-cache `npx`: ~35s → ~1.5s (22.9× speedup)
- Plugin script'ler CLI_CORE=1 flag'i ile seçim yapabilir

### 3.4 Federation Protocol
Swarm'lar arası:
- WebSocket ile bağlantı
- Trust ledger (güven puanı)
- PII stripping (otomatik)
- Byzantine fault tolerance
- Session health monitoring

---

## 4. Skill & Agent Yönetimi

Ruflo'nun `.agents/` yapısı:

```
.agents/
├── README.md           # Agent sistemi dokümantasyonu
├── config.toml          # Merkezi yapılandırma
└── skills/
    ├── swarm-orchestration/
    ├── memory-management/
    ├── sparc-methodology/
    └── security-audit/
```

Skill'ler path bazlı yüklenir, TOML'dan enable/disable edilir.
Her skill kendi SKILL.md + companion file'larını içerir.
