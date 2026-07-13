# Hermes Orkestrasyon Mimarisi — Plan & Tartışma

> **Tarih:** 2026-07-12
> **Bağlam:** Hermes Agent (deepseek-v4-flash) ile multi-agent orkestrasyon keşfi
> **Durum:** 🟡 Taslak — tartışma aşamasında
> **2026-07-14 karar notu:** Bu dokumandaki "hiyerarsik Hermes / alt Hermes takımlari"
> worker-engine yonu su an icin RED edildi. Hermes control-plane olarak yeniden
> degerli; worker-engine replacement olarak degil.
> **İlgili konuşmalar:** Bu dosyanın yanındaki `2026-07-12-hermes-orkestrasyon-konusmasi.md`
> **İlgili araştırma:** `research/orkestratör katman/2026-07-12-orkestrasyon-harness-arastirmasi.md`
> **tools-bank referans altyapı:**
>   - `tools-bank/docs/plans/2026-07-07-global-agent-control-roadmap.md` — Global Agent Control Roadmap (Phase 1-6)
>   - `tools-bank/docs/plans/2026-07-10-hermes-control-plane-v0.md` — Hermes Control Plane V0
>   - `tools-bank/scripts/mailbox_lib.py` — JSON lease-safe mesajlaşma
>   - `tools-bank/scripts/worker_registry.py` — workers.json + heartbeat
>   - `tools-bank/scripts/spawn_broker.py` — Phase 5 worker lifecycle
>   - `tools-bank/scripts/goose-teammate.py` / `codex-teammate.py` / `omp-teammate.py` / `pi-teammate.py` — teammate bridge'ler

---

## 1. Mevcut Durum (Envanter)

Sistemde halihazırda çalışan bileşenler:

| Bileşen | PID | Durum |
|---------|-----|-------|
| **Claude Code** | 183354, 243829 | `--dangerously-skip-permissions` ile çalışıyor |
| **Codex CLI** | 1623361, 183677 | egesut-erp1'de çalışıyor (2 instance) |
| **Goose Server (ACP)** | 1637578 | Port 4000, TLS, `--dangerously-unauthenticated` |
| **fcc-claude** | 243827 | free-claude-code bridge |
| **tools-bank MCP** | — | 109 tool, 4 MCP server (tools-bank, gitnexus, supabase-demo, lsp-bridge) |
| **Mailbox Sistemi** | — | ~70 team, her birinde JSON inbox'lar |
| **Phase 5 Spawn Broker** | — | `worker_spawn`, `worker_list`, `worker_kill`, `worker_reap` |
| **Phase 6** | — | Lazy-load heuristics tasarlandı, Goose hardening devam ediyor |

### 1.1 Mevcut Orkestrasyon Akışı

```
Kullanıcı → Claude Code / Codex / OMP
    ↓
Plan + Task parçalama (elle veya agent'ın kendi muhakemesiyle)
    ↓
Mailbox JSON dosyasına yaz → Goose worker spawn et
    ↓
Worker mailbox'ı poll eder → işi yapar → cevabı mailbox'a yazar
    ↓
Ana agent mailbox'ı poll eder → sonucu alır → birleştirir
```

### 1.2 Mevcut Sorunlar

1. **Orkestrasyon maliyeti yüksek** — Basit bir iş için Goose atamak yerine agent'ın kendi yapması daha makul. Goose sadece token-heavy işlerde yardımcı oluyor.
2. **Agent'ın çok fazla şeye hakim olması gerekiyor** — Plan + dispatch + takip + review hepsi aynı agent'ın context'inde.
3. **Mailbox polling** — Event-driven değil, dosya tabanlı, gecikmeli.
4. **Context şişmesi** — Ana agent tüm sub-agent sonuçlarını kendi context'inde taşıyor.
5. **Hata yönetimi** — Worker ölünce manuel müdahale gerekiyor.

---

## 2. Önerilen Mimari: Hermes Orchestrator

### 2.1 Genel Sekreter Modeli

```
┌──────────────────────────────────────────────────────────┐
│                    HERMES (Orchestrator)                   │
│  • Planlama & Dispatch                                    │
│  • Kanban Board (iş kuyruğu)                              │
│  • Worker lifecycle (Phase 5 Broker)                      │
│  • Sonuç toplama + Review                                 │
│  • Gateway (Telegram/Slack/WhatsApp)                      │
│  • Cron + Webhook                                         │
│  • Persistent Memory                                      │
├──────────────────────────────────────────────────────────┤
│                                                          │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌─────────┐  │
│  │ Claude   │  │  Codex   │  │  Goose   │  │  fcc-   │  │
│  │  Code    │  │   CLI    │  │  ACP     │  │ claude  │  │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘  └─────────┘  │
│       │             │             │                       │
│       │    ┌────────┴────────┐    │                       │
│       │    │ Codex SubAgent  │    │                       │
│       │    └─────────────────┘    │                       │
│       │                  ┌───────┴──────────┐            │
│       │                  │ Goose Worker'lar  │            │
│       │                  └──────────────────┘            │
└──────────────────────────────────────────────────────────┘
```

**Hermes'in rolü:**
- Kendisi kod yazmaz (sadece küçük patch'ler)
- Plan çıkarır, görevleri parçalar, doğru agent'a dağıtır
- İlerlemeyi takip eder, sonuçları toplar, review eder
- Sana tek bir özet sunar
- Alttaki worker/subprocess runtime'inin yerini almaz

### 2.2 Hermes'in Getireceği Avantajlar

| Mevcut Sistem | Hermes ile |
|---------------|------------|
| Mailbox polling (JSON dosya) | Native `delegate_task` — event-driven |
| Manuel worker yönetimi | Phase 5 Broker — spawn/kill/reap otomatik |
| Her agent ayrı terminal | Kanban Board — merkezi iş kuyruğu |
| Elle planlama | Otomatik plan + dispatch |
| Elle sonuç toplama | Otomatik collect + review |
| Sadece terminal | Gateway — Telegram/Slack/WhatsApp'tan da yönet |
| Tek model | Multi-model — her profile ayrı model |
| Hafızasız | Persistent memory — oturumlar arası hatırlama |
| Manuel cron | Native cron — zamanlanmış görevler |

---

## 3. Hiyerarşik Hermes Modeli (Tartışmalı / 2026-07-14 itibariyla reddedildi)

### 3.1 Önerilen Yapı

```
                    ┌─────────────────────────┐
                    │   MAIN HERMES            │
                    │   (deepseek-v4-flash)     │
                    │   Sadece orkestrasyon     │
                    └──────┬──────────┬───────┘
                           │          │
              ┌────────────┼─────┬────┼──────────┐
              │            │     │    │          │
              ▼            ▼     ▼    ▼          ▼
        ┌──────────┐ ┌──────────┐ ┌──────┐ ┌──────────┐
        │ Hermes   │ │ Hermes   │ │Hermes│ │ Hermes   │
        │ Team A   │ │ Team B   │ │Team C│ │ Team D   │
        │ (backend)│ │(frontend)│ │(test)│ │(research)│
        └────┬─────┘ └────┬─────┘ └──┬───┘ └──────────┘
             │            │          │
        ┌────┴────┐ ┌────┴────┐ ┌───┴────┐
        │ Claude  │ │ Codex  │ │ Goose  │
        │ Code    │ │  CLI   │ │ Worker │
        └─────────┘ └─────────┘ └────────┘
```

Bu model dusunuldu ama simdilik ana hat icin uygun bulunmadi.

**Red gerekceleri:**
1. Hermes delegation/session modeli deterministic subprocess ownership vermez.
2. Bizim runtime'in explicit PID/PGID cleanup, worktree/cwd, lease/retry/cancel
   semantigi daha guvenilir ve operator tarafinda daha okunur.
3. Hermes'i bash/headless wrapper seviyesinde kullanmak worker-engine replacement
   icin yeterli kazanci uretmez.
4. Bu hiyerarsi orchestration yukunu azaltirken runtime davranisini bulanıklaştırır;
   "kim kimi spawn etti, kim cleanup'tan sorumlu" netligini dusurur.

**Sonuc:** Main Hermes + alt Hermes team yapisi ancak ayri bir spike olarak
ele alinabilir; mevcut planin bir parcasi degildir.

### 3.2 Riskler ve Endişeler

| Risk | Açıklama | Hafifletici |
|------|----------|-------------|
| **Overengineering** | 3 katmanlı hiyerarşi, basit işler için fazla | Sadece kompleks işlerde kullan, basit işlerde direkt yap |
| **Orkestrasyon gideri > implementasyon gideri** | Her seviyede token + latency maliyeti | Küçük model (v4-flash) kullan → maliyet düşük |
| **Hata zinciri** | Alt katmandaki hata üst katmana yayılır | Timeout + fallback + retry mekanizması |
| **Debug zorluğu** | Hata nerede? Hangi katmanda? | Log chain + trace ID + structured logging |
| **Latency** | Her seviye ekstra round-trip | Paralel dispatch, bekleme yok |

### 3.3 Maliyet Analizi

```
Main Hermes (v4-flash):    ~$0.15/1M input  →  planlama için ~500 token  → ~$0.000075
Alt Hermes (Claude):       ~$3.00/1M input  →  implementasyon için ~2000 token → ~$0.006
Goose Worker:              ~$3.00/1M input  →  test için ~1500 token → ~$0.0045

Toplam: ~$0.01/iş
vs.
Tek Claude Code: ~$0.02/iş (context şişmesi + gereksiz token'lar)

Kazanç: ~2x daha ucuz + daha modüler
```

### 3.4 Ne Zaman Kullanılır / Kullanılmaz

Bu alt-Hermes hiyerarşisi mevcut karar setinde uygulanmayacak.

Onun yerine kullanilacak model:

- Hermes = ust control-plane / sekreter / operator facade
- Alttaki executor'lar = `fcc-claude`, `codex`, `goose`, vb.
- Runtime kaslari = tools-bank teammate bridge + registry + broker + mailbox

---

## 4. Model-İş Eşleştirme Stratejisi

| Model | Güçlü Olduğu Alan | Kullanım |
|-------|-------------------|----------|
| **deepseek-v4-flash** | Hızlı, ucuz, güvenilir | **Orkestrasyon** — plan, dispatch, takip |
| **Claude Sonnet 4** | Kod kalitesi, uzun context | Backend, kompleks implementasyon |
| **GLM-52 / Kimi 2.7** | Analiz, araştırma | Veri analizi, dokümantasyon |
| **GPT-5.4** | Genel amaç, yaratıcılık | Frontend, UI, yaratıcı işler |
| **Goose (çeşitli)** | Token-heavy, batch işler | Test, refactor, lint, batch processing |

---

## 5. Implementasyon Yol Haritası

### Faz 0 — Control-plane POC
- [ ] Hermes mevcut runtime ustunde submit/collect/summarize akisini sadeleştiriyor mu?
- [ ] Worker secimi, result toplama ve bounded review operator acisindan net mi?
- [ ] Yeni bir scheduler/supervisor katmani kurmadan deger uretiyor mu?

### Faz 1 — Control-plane sertlestirme
- [ ] Task routing
- [ ] Progress/result aggregation
- [ ] Escalation / retry / cancel operator yuzeyi
- [ ] Borrow pattern shortlist'i ile incremental iyilestirme

### Faz 2 — Borrow backlog
- [ ] intent classification gate
- [ ] cost-aware routing
- [ ] lifecycle hooks
- [ ] background task manager
- [ ] policy-driven validation
- [ ] durable facts / derived status

---

## 6. Açık Sorular

1. **Hiyerarşi gerçekten gerekli mi?** Yoksa main Hermes doğrudan Claude/Codex/Goose'a mı dağıtsın?
2. **Overengineering riski ne kadar gerçek?** Basit işlerde bypass mekanizması yeterli mi?
3. **v4-flash orkestrasyon için yeterli mi?** Planlama kalitesi, hata yönetimi kararları?
4. **Mevcut mailbox sistemi korunmalı mı?** Yoksa tamamen Hermes `delegate_task`'e mi geçilmeli?
5. **Credential pooling** — 3+ paralel sub-agent için kaç API key gerekli?

---

## 7. İlgili Kaynaklar

- Hermes Agent Skill: `skill_view(name="hermes-agent")`
- Native MCP Client: `skill_view(name="hermes-agent", file_path="references/native-mcp.md")`
- Mevcut planlar: `.claude/plans/faz-a1-utils-envanter-ve-refactor.md`
- Mevcut planlar: `.claude/plans/2026-06-10-bug064-impl.md`
- tools-bank MCP: `mcp__tools_bank_*` (109 tool)
- GitNexus: `mcp__gitnexus_*` (12 tool)
