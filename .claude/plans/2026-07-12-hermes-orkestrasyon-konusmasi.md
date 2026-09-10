# Hermes Orkestrasyon — Keşif Konuşması (2026-07-12)

> **Tarih:** 2026-07-12
> **Model:** deepseek-v4-flash (Hermes Agent)
> **Bağlam:** EgeSüt ERP projesi, multi-agent orkestrasyon keşfi
> **İlgili plan:** `.claude/plans/2026-07-12-hermes-orkestrasyon-mimarisi.md`
> **İlgili araştırma:** `research/orkestratör katman/2026-07-12-orkestrasyon-harness-arastirmasi.md`
> **tools-bank referans altyapı:**
>   - `tools-bank/docs/plans/2026-07-07-global-agent-control-roadmap.md` — Global Agent Control Roadmap (Phase 1-6)
>   - `tools-bank/docs/plans/2026-07-10-hermes-control-plane-v0.md` — Hermes Control Plane V0
>   - `tools-bank/scripts/mailbox_lib.py` — JSON lease-safe mesajlaşma
>   - `tools-bank/scripts/worker_registry.py` — workers.json + heartbeat
>   - `tools-bank/scripts/spawn_broker.py` — Phase 5 worker lifecycle
>   - `tools-bank/scripts/goose-teammate.py` / `codex-teammate.py` / `omp-teammate.py` / `pi-teammate.py` — teammate bridge'ler

---

## Bölüm 1: Yetenek Envanteri

**Soru:** Şuan nelere erişimin var, neler yapabilirsin, standart bir CLI agent'tan farkın nedir?

**Cevap özeti:**
- 4 MCP sunucusu, 109 tool (tools-bank, gitnexus, supabase-demo, lsp-bridge)
- 68 skill (kategorize edilmiş prosedürel bilgi)
- Native tool'lar: computer_use, delegate_task, cronjob, web_search, browser_*, memory, session_search, skill_manage, patch/write_file/read_file/search_files, terminal, execute_code, text_to_speech, clarify, todo, project_*

**Standart CLI Agent'tan farklar:**
- Masaüstü kontrolü (computer_use) — background'da tıklama, yazma, scroll
- Paralel sub-agent (delegate_task) — 3'e kadar paralel işçi
- Zamanlanmış görev (cronjob)
- Kalıcı hafıza (memory) — oturumlar arası
- Geçmiş arama (session_search) — FTS5
- MCP ekosistemi — 109 tool
- Skill sistemi — 68 prosedür
- Tarayıcı otomasyonu (browser_*)
- Ses çıktısı (text_to_speech)
- Kod zekası (GitNexus) — sembol grafiği, blast radius
- Derin araştırma (DeerFlow)

---

## Bölüm 2: Web UI vs Terminal

**Soru:** Hermes Agent'i web UI üzerinden kullanmak ile terminal üzerinden kullanmak arasında nasıl bir fark var?

**Cevap özeti:**

| Yüzey | Komut | Özellikler |
|-------|-------|-------------|
| Terminal (CLI/TUI) | `hermes` | En hızlı, 40+ slash komut, streaming, tool görünürlüğü, PTY modu |
| Web Dashboard | `hermes dashboard` | Admin paneli + embedded TUI chat, config yönetimi tarayıcıdan |
| Desktop App | `hermes desktop` | Electron native, streaming chat, session list, drag-drop, Cmd+K, subagent watch-window |

Hepsi aynı agent core'u kullanır — yetenek farkı yok, sadece arayüz farkı.

---

## Bölüm 3: Multi-Platform Gateway ve Entegrasyonlar

**Soru:** Multi-platform gateway nedir? Hermes gateway hangi amaçlarla kullanılabilir? Hermes'e neler entegre edilebilir?

**Cevap özeti:**

Gateway: 20+ mesajlaşma platformuna aynı anda bağlanan background servis.

**Desteklenen platformlar (20+):** Telegram, Discord, Slack, WhatsApp (Baileys + Business API), iMessage (Photon), Signal, Email, SMS, Matrix, Mattermost, Microsoft Teams, LINE, SimpleX, ntfy, Google Chat, Home Assistant, DingTalk, Feishu, WeCom, Weixin (WeChat), Raft, API Server, Webhooks, Open WebUI.

**Kullanım amaçları:**
- 7/24 erişilebilir asistan
- Takım içi ortak agent
- Bildirim/alert alıcısı
- Multi-platform tek kimlik
- Sesli komut (voice message → STT → agent)
- Otomasyon tetikleyicisi
- IDE entegrasyonu

**Entegre edilebilenler:**
- 20+ LLM Provider
- 20+ Messaging Platform
- Sınırsız MCP Server
- STT/TTS (5+ provider)
- IDE (VS Code, Zed, JetBrains)
- Cron/Webhook
- Plugin Sistemi
- External CLI Agent (Claude Code, Codex, OpenCode, Goose)

---

## Bölüm 4: Lokal Agent'lar Sub-Agent Olarak Kullanılabilir mi?

**Soru:** Lokaldeki diğer agent'lar (Claude, Codex, fcc-claude, Goose) Hermes ile entegre olabilir mi? Sub-agent olarak kullanılabilirler mi? Hermes bir orkestratör üst kabuğu olarak hizmet verebilir mi?

**Cevap özeti:**

**Evet, her biri için mekanizma var:**

| Agent | Entegrasyon Yöntemi |
|-------|---------------------|
| Claude Code | `claude-code` skill → `terminal(pty=true)` ile spawn |
| Codex CLI | `codex` skill → aynı pattern |
| OpenCode | `opencode` skill → aynı pattern |
| Goose | Mailbox protokolü veya Phase 5 `worker_spawn` |
| Başka Hermes | `terminal(pty=true)` ile tmux içinde spawn, `--worktree` ile git conflict önleme |

**Hermes orkestratör olarak:**
- `delegate_task` — paralel sub-agent spawn
- Kanban Board — multi-agent iş kuyruğu
- Phase 5 Spawn Broker — worker lifecycle
- Profile Sistemi — farklı uzmanlıklar
- Cron + Webhook — zamanlanmış/event-driven
- Gateway — farklı platformlardan gelen istekler
- Worktree Mode (`-w`) — git conflict'siz paralel çalışma
- `delegate_task(role='orchestrator')` — nested sub-agent

---

## Bölüm 5: Karmaşık Hiyerarşi ve Otonomi Seviyeleri

**Soru:** Bu basit yapı daha karmaşık hale getirilebilir mi? Ne düzeyde otonomluk sağlanır? Agent'lerin birbiri ile konuşması sağlanabilir mi? Aynı anda 3'ten fazla sub-agent kullanılamaz mı? Orta hiyerarşideki agent'ler kendi sub'larını summon edemez mi?

**Cevap özeti:**

### Otonomi Seviyeleri

| Seviye | Yetenek | Örnek |
|--------|---------|-------|
| L1 — Task | Tek iş, sonuç döndür | "Auth API yaz" → Claude Code |
| L2 — Plan+Execute | Plan → parçala → dağıt → topla | "ERP'ye rapor modülü ekle" |
| L3 — Adaptive | Hata alınca alternatif dene | Codex hata → Claude Code dene |
| L4 — Self-healing | Worker ölünce restart | Goose 5dk cevap vermedi → kill + restart |
| L5 — Proactive | İhtiyaçları sez, önlem al | "Test coverage düşüyor" → otomatik test |

### Agent'ler Arası İletişim

Zaten çalışan mailbox sistemi var (~70 team, her birinde JSON inbox'lar):
- Claude Code → Goose Worker
- Codex CLI → Goose Worker
- Goose Worker → Goose Worker

Hermes ile native event bus'a dönüşür.

### 3+ Sub-Agent

`delegation.max_concurrent_children` config'de ayarlanabilir (default 3, istenilen değere çıkarılabilir). Uyarı: 3+ paralel LLM çağrısı rate limit'e takılabilir → credential pooling ile çözülür.

### Nested Sub-Agent

`delegate_task(role='orchestrator')` ile mümkün. `max_spawn_depth` config'de ayarlanır (default 1, artırılabilir).

---

## Bölüm 6: Hiyerarşik Hermes Modeli — Derinlemesine Analiz

**Soru:** Main Hermes 3 farklı işi 3 farklı takıma bölüyor, her takımın altında bir sub-agent Hermes var. Main Hermes işi kendi altına atıyor, alttaki Hermes işi yönetiyor. Böylece main Hermes'in dikkati dağılmıyor. Ama overengineering riski var. Orkestrasyon işini v4-flash gibi küçük modele yaptırmayı planlıyorum. Ne dersin?

### Önerilen Yapı

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

### Riskler

| Risk | Açıklama | Hafifletici |
|------|----------|-------------|
| Overengineering | 3 katman, basit işler için fazla | Sadece kompleks işlerde kullan, basit işlerde bypass |
| Orkestrasyon gideri > implementasyon | Her seviyede token + latency | Küçük model (v4-flash) → maliyet düşük |
| Hata zinciri | Alt katmandaki hata üst katmana yayılır | Timeout + fallback + retry |
| Debug zorluğu | Hata nerede? | Log chain + trace ID |
| Latency | Her seviye ekstra round-trip | Paralel dispatch |

### Maliyet Tahmini

```
Main Hermes (v4-flash):    ~$0.15/1M input  →  ~500 token  → ~$0.000075
Alt Hermes (Claude):       ~$3.00/1M input  →  ~2000 token → ~$0.006
Goose Worker:              ~$3.00/1M input  →  ~1500 token → ~$0.0045
Toplam: ~$0.01/iş
vs. Tek Claude Code: ~$0.02/iş (context şişmesi + gereksiz token'lar)
Kazanç: ~2x daha ucuz + daha modüler
```

### Ne Zaman Kullanılır

**KULLAN:** 3+ paralel iş, farklı uzmanlık gerektiren işler, uzun sürecek görevler (>5 dk), farklı modellerin güçlü olduğu alanlar.

**KULLANMA:** Tek dosya düzenleme, basit hata düzeltme, hızlı cevap gereken işler, blast radius küçük değişiklikler.

### Model-İş Eşleştirme

| Model | Güçlü Olduğu Alan | Kullanım |
|-------|-------------------|----------|
| deepseek-v4-flash | Hızlı, ucuz, güvenilir | **Orkestrasyon** |
| Claude Sonnet 4 | Kod kalitesi, uzun context | Backend, kompleks implementasyon |
| GLM-52 / Kimi 2.7 | Analiz, araştırma | Veri analizi, dokümantasyon |
| GPT-5.4 | Genel amaç, yaratıcılık | Frontend, UI |
| Goose (çeşitli) | Token-heavy, batch | Test, refactor, lint |

---

## Bölüm 7: Mevcut Sistemin Durumu (ps çıktısı)

```
PID 183354 — claude --dangerously-skip-permissions --resume
PID 183670 — node /home/melik/.npm-global/bin/codex resume
PID 183677 — codex-linux-x64 (binary)
PID 185043 — goose-lsp-bridge.py (tools-bank venv)
PID 243827 — fcc-claude (free-claude-code)
PID 243829 — claude --dangerously-skip-permissions
PID 497838 — fcc-server
PID 1623354 — codex (node)
PID 1623361 — codex-linux-x64 (binary, egesut-erp1'de çalışıyor)
PID 1624518 — goose-lsp-bridge.py
PID 1637578 — goose.bin serve --port 4000 --tls --dangerously-unauthenticated
PID 1662173 — mcp_stdio_watchdog.py (Hermes MCP watchdog)
PID 1662176 — goose-lsp-bridge.py (Hermes altında)
```

**Codex şu an egesut-erp1'de çalışıyor** (cwd = /home/melik/egesut-erp1). İki instance var:
- PID 1623361 (yeni, 14:38'de başlamış, 43s CPU)
- PID 183677 (eski, Tem10'dan beri, 9dk CPU)

`phase6-goose-hardening` team'inde codex.json 90KB — üzerinde çalıştığı bir şey var ama son aktivite 2 gün önce.

---

## Bölüm 8: Implementasyon Yol Haritası

### Faz 0 — POC (1 gün)
- [ ] Hermes'ten Claude Code'a `delegate_task` ile görev gönder
- [ ] Sonucu al, review et, kullanıcıya sun
- [ ] Basit bir "backend API yaz" göreviyle test et

### Faz 1 — Temel Orkestrasyon (2-3 gün)
- [ ] Main Hermes (v4-flash) kurulumu
- [ ] Kanban Board entegrasyonu
- [ ] Phase 5 Broker ile worker lifecycle
- [ ] 3 paralel işi 3 farklı agent'a dağıtma

### Faz 2 — Hiyerarşik Model (opsiyonel, 3-5 gün)
- [ ] Alt Hermes instance'larının spawn edilmesi
- [ ] Her alt Hermes'in kendi worker'larını yönetmesi
- [ ] Main Hermes'in sadece koordinasyon yapması
- [ ] Hata yönetimi + retry + timeout

### Faz 3 — İyileştirme (sürekli)
- [ ] Maliyet optimizasyonu
- [ ] Context yönetimi
- [ ] Model routing
- [ ] Self-healing
- [ ] Gateway entegrasyonu

---

## Açık Sorular

1. Hiyerarşi gerçekten gerekli mi? Yoksa main Hermes doğrudan Claude/Codex/Goose'a mı dağıtsın?
2. Overengineering riski ne kadar gerçek? Basit işlerde bypass mekanizması yeterli mi?
3. v4-flash orkestrasyon için yeterli mi? Planlama kalitesi, hata yönetimi kararları?
4. Mevcut mailbox sistemi korunmalı mı? Yoksa tamamen Hermes `delegate_task`'e mi geçilmeli?
5. Credential pooling — 3+ paralel sub-agent için kaç API key gerekli?
