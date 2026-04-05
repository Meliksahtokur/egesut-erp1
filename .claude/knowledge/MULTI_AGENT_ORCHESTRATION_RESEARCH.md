# Multi-Agent Orchestration Araştırma Raporu

**Tarih:** 2026-04-04
**Amaç:** Claude CLI + MiniMax M2.7 endpoint uyumlu, interaktif, subagent spawn edebilen ücretsiz framework/CLI bulmak

---

## Gereksinimler

| # | Gereksinim | Öncelik |
|---|---|---|
| 1 | İnteraktif / stateful (tek mesajlık değil) | Kritik |
| 2 | CLI veya TUI (tablet/tty uyumlu) | Kritik |
| 3 | Claude endpoint uyumlu (api.minimax.io/anthropic) | Kritik |
| 4 | Multi-agent spawn / orkestrasyon | Kritik |
| 5 | Ücretsiz / açık kaynak | Kritik |
| 6 | Hızlı — 2 satır kod görmek için bekletmesin | Önemli |

**Dışlanan:** OpenAI endpoint tabanlı projeler (MiniMax Anthropic formatında olduğundan).

---

## Araştırılan Projeler

### ❌ Teknoloji Odaklı Projeler (Eksen Yanlış)

| Proje | Neden Elendi |
|---|---|
| **OpenAI Swarm** (21,276⭐) | OpenAI endpoint, Swarm → Agents SDK'ya yönlendiriyor, CLI yok |
| **OpenAI Agents SDK** (32,942⭐) | CLI yok, Python-only, OpenAI-native |
| **Swarms** (6,188⭐) | CLI var ama OpenAI endpoint ağırlıklı, MiniMax dolaylı (LiteLLM ile) |
| **Agency Swarm** (4,140⭐) | OpenAI-only, CLI var ama MiniMax uyumsuz |
| **LangGraph Swarm** | OpenAI/LangChain bağımlı, hafif değil |
| **Mini-Agent** | Single agent demo — multi-agent yok |

### ⚠️ Potansiyel Ama Uzak

| Proje | Bulgu |
|---|---|
| **OmoiOS** | DAG tabanlı agent swarm, paralel execution, Daytona sandbox — ağır ve backend gerektirir |
| **MCP Task Orchestrator** | MCP server olarak specialist roller (Architect, Implementer, Tester) — ama agent spawn değil, rol değiştirme |

---

## 🥇 Bulunan: Open-Agents (`OpenAEC-Foundation/Open-Agents`)

| Özellik | Değer |
|---|---|
| **Lisans** | MIT |
| **CLI** | ✅ `oa` komutu |
| **TUI** | ✅ Textual dashboard |
| **Agent spawn** | ✅ Yüzlerce agent paralel (tmux tabanlı) |
| **Nested spawning** | ✅ 6 seviye derinliğe kadar child agent |
| **API key** | ❌ **GEREKTİRMEZ** — Claude Code subscription ile çalışır |
| **Model seçimi** | Claude Opus/Sonnet/Haiku + Ollama (local) |
| **Template** | ✅ 1,612+ agent template, 112 kategori |
| **Pipeline** | ✅ Planner → Workers → Combiner |
| **Web arayüzü** | ✅ React dashboard (opsiyonel) |
| **MCP** | ✅ MCP entegrasyonu |

### Temel CLI Komutları

```bash
oa start                    # Interaktif oturum başlat
oa run "görev" --name x    # Agent spawn et
oa status                   # Tüm agentları listele (TUI tablo)
oa agents list             # Template kütüphanesi
```

### Mimari

```
Kullanıcı (oa start)
  └── Orchestrator (tmux session)
        ├── Agent-1 (paralel) ──→ tmux pane
        ├── Agent-2 (paralel) ──→ tmux pane
        └── Supervisor merge yapar
```

### MiniMax Uyumluluk Analizi

Claude Code formatında çalıştığından — MiniMax'in Anthropic-format endpoint'i ile **uyumlu olması bekleniyor**.

**Risk:** Doğrudan test edilmesi gerekir.

---

## Alternatif: Claude Code Plugin Sistemi (En Hafif)

Mevcut Claude Code zaten multi-agent spawn yapabiliyor:

```bash
# Claude Code içinde — /agents komutu
/agents                    # Mevcut agentları listele
/agent <name>              # Agent oluştur veya seç
```

**Avantajları:**
- Kuruluma gerek yok — zaten kurulu
- Native tool entegrasyonu
- MCP zaten çalışıyor

---

## Sonuç ve Öneri

| Öneri | Gerekçe |
|---|---|
| **1. Open-Agents dene** | API key gerektirmez, CLI+TUI var, subagent spawn var, 1,612 template |
| **2. Claude Code native agent sistemini güçlendir** | Mevcut `.claude/agents/` dosyaları zaten çalışıyor |
| **3. Basmuhendis için custom wrapper** | Open-Agents template'lerini Basmuhendis rolleriyle eşleştir |

### Yapılacaklar

- [ ] `git clone OpenAEC-Foundation/Open-Agents && ./install.sh` — test et
- [ ] `oa start` — interaktif oturumu başlat
- [ ] MiniMax endpoint ile test et
- [ ] Basmuhendis rolleri → Open-Agents template mappingı yap

---

## Kaynaklar

- Open-Agents: https://github.com/OpenAEC-Foundation/Open-Agents
- MCP Task Orchestrator: https://github.com/EchoingVesper/mcp-task-orchestrator
- OmoiOS: https://github.com/kivo360/OmoiOS
- Claude Agent SDK (Go): https://github.com/severity1/claude-agent-sdk-go
