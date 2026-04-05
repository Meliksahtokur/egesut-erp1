# 🔬 Multi-Agent Orchestration Framework Araştırma Raporu

**Tarih:** 2026-04-05  
**Amaç:** MiniMax M2.7 ile çalışan hazır multi-agent orchestration framework bulmak  
**Kaynaklar:** Context7, GitHub, MiniMax official repos  

---

## Yönetici Özeti

**Sonuç:** MiniMax'in resmi framework'ü olan **Mini Agent**, multi-agent orchestration **yok**. Diğer tüm hazır multi-agent framework'leri **Claude Code CLI** bağımlılığı taşıyor — bu da bizim yaşadığımız subprocess timeout sorununu tetikleyebilir.

İki yol var:
1. **Mini Agent'ı base alıp üstüne multi-agent katmanı yazmak** — en temiz
2. **Claude Code CLI tabanlı framework'lerde timeout sorununu çözmek** — daha riskli

---

## 1. MiniMax Mini Agent ⭐⭐⭐ (Tek Resmi Çözüm)

**Repo:** `github.com/minimax-ai/mini-agent`  
**Stars:** Resmi MiniMax projesi  
**Dil:** Python 3.10+  
**Model:** MiniMax M2.5/M2.1 (⚠️ M2.7 desteklenmiyor, M2.5 üzerine inşa edilmiş)

### Kurulum
```bash
# Tek satır kurulum
uv tool install git+https://github.com/MiniMax-AI/Mini-Agent.git

# Yapılandırma
curl -fsSL https://raw.githubusercontent.com/MiniMax-AI/Mini-Agent/main/scripts/setup-config.sh | bash

# Config dosyası (~/.mini-agent/config/config.yaml)
api_key: "YOUR_API_KEY"
api_base: "https://api.minimax.io"  # Global
model: "MiniMax-M2.5"              # ⚠️ M2.7 değil!
```

### Mimari
```
Agent (tek instance)
  └── LLMClient (Direct HTTP → api.minimax.io)
        └── MiniMax M2.5 API
  └── Tools: ReadTool, WriteTool, EditTool, BashTool
  └── MCP: load_mcp_tools_async()
  └── Memory: SessionNoteTool (kalıcı hafıza)
```

### Özellikleri
- ✅ **Direct API** — subprocess yok, timeout yok
- ✅ **MCP entegrasyonu** — Supabase, GitHub, PostgreSQL
- ✅ **Claude Skills** — 15 hazır skill
- ✅ **Token yönetimi** — 80K limit, otomatik özetleme
- ✅ **CLI** — `mini-agent` komutu
- ✅ **Minimal kod** — 3000 satır, kolay anlaşılır

### ⚠️ Kritik Sorun: Multi-Agent Yok!
```python
# Mini Agent sadece TEK agent desteği veriyor
# Kaynak koda bakınca: sadece bir Agent class'ı var
# multi-agent, sub-agent, team gibi kavramlar YOK
```

### ⚠️ Model Uyumsuzluğu
```
README: "built on the MiniMax M2.5 model"
Kod:    model="MiniMax-M2.1" default
Biz:    MiniMax-M2.7 kullanıyoruz
```
M2.7, M2.5/M2.1'den farklı olabilir — API uyumu test edilmeli.

### Bağımlılıklar
```
pydantic>=2.0.0
pyyaml>=6.0.0
httpx>=0.27.0
mcp>=1.0.0
anthropic>=0.39.0    # Anthropic SDK — direct API çağrısı
openai>=1.57.4
tiktoken>=0.5.0
prompt-toolkit>=3.0.0
```

---

## 2. Multi-Agent Ralph Loop ⭐⭐⭐⭐ (En Kapsamlı)

**Repo:** `github.com/alfredolopez80/multi-agent-ralph-loop`  
**Stars:** 108 | **Versiyon:** v3.0 (2026-01-02)  
**Dil:** Shell + Claude Code hooks  

### Genel Bakış
En olgun multi-agent orchestration framework. Claude Code'u full development OS'ye çeviriyor.

### Mimari
```
Orchestrator (ana agent)
  └── Claude Code CLI subprocess
        └── Model (GLM-5 varsayılan, model-agnostic)
  └── 6 Uzman Agent (Agent Teams):
        - coder, reviewer, tester, researcher
        - frontend, security
  └── Vault System (Obsidian-backed knowledge base)
  └── Quality Gates (4-stage validation)
```

### Özellikleri
- ✅ **Agent Teams** — 6 hazır uzman agent
- ✅ **Swarm Mode** — paralel agent spawn (`--launch-swarm --teammate-count 3`)
- ✅ **Aristotle First Principles** — 5-fazlı analiz
- ✅ **Vault System** — kalıcı bilgi birikimi
- ✅ **Quality Gates** — correctness, quality, security, consistency
- ✅ **MCP desteği** — 15 MCP server
- ✅ **Anti-Rationalization Tables** — 37-entry hata önleme
- ✅ **Cross-platform sync** — Claude, MiniMax, Zai arasında

### ⚠️ Kritik Sorun: Claude Code CLI Bağımlılığı
```
Requires: Claude Code v2.1.42+
Problem:  Claude Code CLI subprocess → MiniMax M2.7
          → subprocess timeout (~30sn+) → deadlock
```

### ⚠️ Model Durumu
```
v2.84.1: "GLM-5 integration, model-agnostic architecture"
Varsayılan: GLM-5 (Z.AI)
MiniMax M2.7: Muhtemelen destekleniyor ama TEST EDİLMEMİŞ
```

### Kurulum
```bash
git clone https://github.com/alfredolopez80/multi-agent-ralph-loop.git
cd multi-agent-ralph-loop
./.claude/scripts/centralize-all.sh
ralph health --compact

# Orchestrator çalıştır
/orchestrator "Create a REST API endpoint"
```

---

## 3. Claude Code Agent Farm ⭐⭐⭐ (En Popüler)

**Repo:** `github.com/go-skynet/claude_code_agent_farm`  
**Stars:** 772 (en yüksek!)  
**Amaç:** 20+ Claude Code agent'ı paralel çalıştırma

### Özellikleri
- ✅ **20+ paralel agent** — aynı anda birden fazla görev
- ✅ **Batch task execution** — görev kuyruğu
- ✅ **Farm mode** — agent havuzu yönetimi

### ⚠️ Kritik Sorun: Sadece Claude Code CLI
```
Tamamen Claude Code CLI wrapper'ı
Subprocess timeout sorunu BİZE DE YAŞATICAK
```

---

## 4. Diğer Framework'ler

| Proje | Stars | Durum | Sorun |
|-------|-------|-------|-------|
| `claude-flows` | 110 | ❌ | Claude Code wrapper |
| `multi-agent-squad` | 81 | 🔲 | Bilinmiyor |
| `metaswarm` | 183 | 🔲 | Claude Code + Gemini CLI |
| `Multi-AI-Workflow` | 252 | 🔲 | Erişilemedi |
| `kelos` | 102 | 🔲 | Kubernetes-native, Claude Code |

---

## 5. Şu An Kullandığımız: agent_framework_claude

**Durum:** Test edilmiş, çalışıyor (Cerebras'ta), MiniMax'te timeout var

### Mimari
```
Python Script (orchestrator.py)
  └── agent_framework_claude.ClaudeAgent
        └── Claude Code CLI subprocess
              └── MiniMax M2.7 API
        └── Subagent spawn (agents={})
```

### Test Sonuçları
| Senaryo | Model | Sonuç |
|---------|-------|-------|
| Basit query | Cerebras | ✅ Çalışıyor |
| Multi-agent handoffs | Cerebras | ✅ Çalışıyor |
| Orchestrator interaktif | Cerebras | ✅ Çalışıyor |
| Basit query | MiniMax M2.7 | ✅ Çalışıyor (8sn) |
| Subagent spawn | MiniMax M2.7 | ❌ Timeout (30sn+) |
| Interaktif loop | MiniMax M2.7 | ❌ Deadlock |

### Timeout Kök Neden
```
MiniMax M2.7 yanıt süresi: ~8 saniye
Claude Code CLI subprocess timeout: varsayılan ~30 saniye
Sorun: Stream modunda subprocess stdin/stdout deadlock oluyor
```

---

## 6. Karşılaştırma Matrisi

| Kriter | Mini Agent | Ralph Loop | Agent Farm | agent_framework |
|--------|------------|------------|------------|-----------------|
| **MiniMax native** | ✅ | ⚠️ | ⚠️ | ❌ |
| **Direct API** | ✅ | ❌ | ❌ | ❌ |
| **Multi-agent** | ❌ | ✅ | ✅ | ✅ |
| **Subprocess yok** | ✅ | ❌ | ❌ | ❌ |
| **Timeout riski** | Yok | Var | Var | Var |
| **Kurulum** | 1 komut | Kompleks | — | Hazır |
| **Bakım** | Aktif | Çok aktif | Aktif | Microsoft |

---

## 7. Önerilen Yol Haritası

### Yol A: Mini Agent Base + Custom Multi-Agent (Önerilen) ⭐

```
MiniMax M2.7 (Direct HTTP, subprocess yok)
       │
       ▼
┌─────────────────┐
│ Mini Agent      │ ← Direct API, timeout yok, MCP var
│ (LLMClient)     │
└────────┬────────┘
         │ Tek instance — üstüne biz yazacağız:
         ▼
┌─────────────────┐
│ Custom Layer     │ ← Biz yazacağız:
│ - Orchestrator  │   - Agent pool (birden fazla Mini Agent instance)
│ - Task router   │   - Task dağıtıcı
│ - Result merge  │   - Sonuç birleştirici
│ - Memory share  │   - Paylaşımlı hafıza
└─────────────────┘
```

**Avantajları:**
- ✅ Subprocess yok — timeout yok
- ✅ MiniMax native — M2.7 direkt kullanılır
- ✅ MCP desteği — Supabase, GitHub
- ✅ Claude Skills — 15 hazır skill
- ✅ Bakımı kolay — minimal kod

**Yapılacaklar:**
1. Mini Agent'ı kur (`uv tool install`)
2. MiniMax-M2.7 model test et (M2.5/M2.1 üzerine inşa — uyumluluk kontrolü)
3. Custom orchestrator layer yaz
4. Agent pool sistemi kur (birden fazla MiniAgent instance)
5. Task routing + result merge yaz

### Yol B: Ralph Loop'i MiniMax'e Uyarla

```
Ralph Loop orchestrator
  └── Claude Code CLI (subprocess)
        └── MiniMax M2.7 (model-agnostic)
              └── Timeout sorunu OLABİLİR
```

**Avantajları:**
- ✅ En olgun framework
- ✅ Agent teams hazır
- ✅ Vault, quality gates var

**Dezavantajları:**
- ❌ Claude Code CLI subprocess — timeout riski
- ❌ Kompleks kurulum
- ❌ GLM-5 odaklı dokümantasyon

### Yol C: mevcut agent_framework_claude ile devam

Timeout sorununu çözmeye odaklan:
1. `stream=False` zorla
2. MiniMax M2.7 API timeout ayarlarını artır
3. Subprocess yerine direct SDK çağrısı dene

---

## 8. Sonraki Adımlar

```
1. [ ] Mini Agent kurulumu test et
2. [ ] M2.7 uyumluluğunu kontrol et (M2.5 tabanlı olduğu için)
3. [ ] Mini Agent + direct M2.7 API test et
4. [ ] Custom multi-agent layer tasarımı yap
5. [ ] Ralph Loop swarm mode'u incele (ilham için)
```

---

## Kaynaklar

- Mini Agent: https://github.com/MiniMax-AI/Mini-Agent
- Multi-Agent Ralph: https://github.com/alfredolopez80/multi-agent-ralph-loop
- Claude Agent Farm: https://github.com/go-skynet/claude_code_agent_farm
- MiniMax Platform: https://platform.minimax.io
- MiniMax API Base: `https://api.minimax.io`
