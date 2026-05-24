# Ruflo Agent Framework — Araştırma Raporu
**Tarih:** 2026-05-24  
**Kaynak:** https://github.com/ruvnet/ruflo  
**Amaç:** deepseek-tui master orchestrator skill upgrade için pattern çıkarımı

---

## 1. Proje Özeti

Ruflo (eski adı: Claude Flow), Claude Code için çok-agent orkestrasyonu yapan açık kaynak bir platform.

- **Lisans:** MIT
- **Stack:** TypeScript / Node.js ≥20
- **GitHub:** 54.6k star, aktif geliştirme
- **Paketler:** `@claude-flow/cli-core`, `@claude-flow/mcp`, `@claude-flow/neural`
- **DB:** AgentDB v3.0+ (HNSW vektör indeksleme — "150x-12500x daha hızlı arama")
- **Ticari:** ruv.io üzerinden enterprise destek

---

## 2. Agent Kataloğu (43+ tanım, 8 kategori)

### Temel Agent'lar
| Agent | Rol |
|-------|-----|
| Coordinator | Diğer agent'ları orkestre eder, görev akışını yönetir |
| Coder | Kod yazma ve implementasyon |
| Tester | Test yazma ve çalıştırma |
| Reviewer | Kod kalitesi, bağımsız inceleme |
| Architect | Sistem tasarımı, çözüm mimarisi |
| Researcher | Gereksinim analizi, bilgi toplama |
| Security-Architect | Güvenlik odaklı tasarım |
| Security-Auditor | Güvenlik taraması ve analiz |

### Swarm Koordinasyon Agent'ları
| Agent | Rol |
|-------|-----|
| Hierarchical-Coordinator | Hiyerarşik takım yapılarını yönetir |
| Mesh-Coordinator | Peer-to-peer agent iletişimi |
| Adaptive-Coordinator | Koordinasyon stratejisini dinamik ayarlar |
| Byzantine-Coordinator | Hata-tolerant konsensüs (N agent'tan M onay) |
| Raft-Manager | Raft konsensüs protokolü |
| Gossip-Coordinator | Gossip tabanlı bilgi yayınlama |

### Uzman Agent'lar
| Agent | Rol |
|-------|-----|
| Memory-Specialist | Pattern depolama ve geri çağırma |
| Performance-Engineer | Sistem optimizasyonu ve profilleme |

### Domain Plugin'leri (32 plugin)
- Software Engineering: Coding, Testing, Documentation
- Security: CVE scanning, Prompt injection detection
- Architecture: ADR, Domain-Driven Design, SPARC methodology
- Domain-specific: Trading systems, IoT management, GOAP planning

---

## 3. Desteklenen LLM'ler

| Provider | Destekleniyor mu? |
|----------|------------------|
| Claude (Haiku/Sonnet/Opus) | ✅ |
| GPT (OpenAI) | ✅ |
| Gemini (Google) | ✅ |
| Qwen (Alibaba) | ✅ |
| Cohere | ✅ |
| Ollama (local) | ✅ |
| **DeepSeek v4 official API** | ❌ Resmi destek yok |

**NOT:** DeepSeek API OpenAI-uyumlu endpoint sunuyor → GPT provider üzerinden adapter ile eklenebilir.

---

## 4. Mimari Desenler (Bizim İçin Kritik)

### 4.1 Agent Topolojileri

```
Hierarchical (Varsayılan)      Mesh (Eşit ağırlıklı)
─────────────────────          ──────────────────────
     Coordinator                A ←→ B ←→ C
    /     |      \              ↑         ↓
 Coder Tester Reviewer          D ←────── E

Ring (Sıralı pipeline)         Star (Merkezi hub)
──────────────────────         ──────────────────
A → B → C → D → A             A, B, C, D → Hub → A, B, C, D
```

**Hangi topoloji ne zaman:**
- Hierarchical: Bağımlı, sıralı task'lar (bizim ERP plan'larımız)
- Mesh: Bağımsız, eşit öncelikli paralel task'lar
- Ring: Pipeline — çıktı bir sonraki input'u besler (ETL, analiz zinciri)
- Star: Merkezi orkestratör, çok sayıda worker (bizim Claude ↔ telsiz modeli)

### 4.2 Thompson Sampling Routing

Model seçimini maliyet + başarı oranına göre yapar:
```
Basit validation → Ollama (local, free)
Rutin kod yazma  → deepseek-chat (ucuz)
Kompleks analiz  → Claude Sonnet/Opus (pahalı, gerektiğinde)
```

Bizim eşdeğerimiz:
- Basit → `mcp__deepseek__deepseek_chat` (flash)
- Reasoning → `mcp__deepseek__deepseek_chat` (reasoner)
- Orkestrasyon/onay → Claude direkt

### 4.3 SONA (Self-Optimizing Pattern Learning)

Başarılı görev kalıplarını sinir ağı benzeri yapıda saklar → benzer görevlerde en iyi yaklaşımı tekrarlar.

**Bizim eşdeğerimiz:** `memory_add(content, category="code_change")` — başarılı pattern'ları kaydet, bir sonraki benzer görevde `memory_search` ile çek.

### 4.4 Byzantine Consensus (Onay Mekanizması)

Kritik işlemler için birden fazla agent'tan onay istenir:
```
Senaryo: bulk UPDATE (geri alınamaz)
→ Worker proposes SQL
→ Coordinator pauses
→ Reviewer okur
→ N/M onay → execute
```

Bizim eşdeğerimiz: mevcut `ONAY GEREKLİ` bloğu — ama sadece tek onay noktası.

### 4.5 Commit Lock

Paralel worker'ların aynı anda commit yapmasını engeller:
```bash
curl -X POST .../commit-lock/acquire {"session_id":"W1"}
# 423 → 5s bekle, retry (max 10)
git commit
curl -X POST .../commit-lock/release {"session_id":"W1"}
```

Bizim eşdeğerimiz: goused-api'deki commit-lock — paralel DeepSeek agent'ları için de gerekebilir.

### 4.6 Loop Workers

Özyinelemeli görev zincirleri:
```
purchase_request → approval → PO → receipt → invoice_matching
```
Her adım tamamlanınca bir sonraki başlar. Checkpoint ile kurtarılabilir.

Bizim eşdeğerimiz: plan'daki sıralı Task'lar + `memory_add` checkpoint.

### 4.7 MCP Entegrasyonu

- 313+ MCP araç, 31+ modül
- Local MCP execution (privacy)
- Parallel MCP tool calling
- stdio tabanlı custom MCP server desteği (bizim `deepseek_mcp.py` uyumlu)

---

## 5. DeepSeek TUI Entegrasyon Potansiyeli

### Mevcut Durum
- `deepseek-tui serve --mcp` → Tokio crash (PRoot ENOSYS)
- Çözüm: `/root/tools-bank/mcp_server/deepseek_mcp.py` — python3 stdio wrapper, çalışıyor

### Ruflo'dan Alınabilecekler

| Ruflo Özelliği | DeepSeek TUI'ye Adaptasyon |
|----------------|---------------------------|
| Agent topoloji seçimi | Plan yazılmadan topoloji belirleme adımı |
| SONA learning | Her plan sonrası `memory_add` ile pattern kayıt |
| Byzantine consensus | Riskli task'larda çift-onay mekanizması |
| Loop worker pattern | Checkpoint'li sıralı task zinciri |
| Memory-Specialist | Ayrı bellek okuma/yazma task adımları |
| Adaptive coordinator | Görev karmaşıklığına göre model seçimi |

### Entegre EDİLEMEYECEKLER (PRoot kısıtı)
- Ruflo'nun doğrudan kurulumu → Node.js runtime çöküyor (Tokio benzeri sorun)
- Agent federation (mTLS) → production altyapı gerektiriyor
- AgentDB → ayrı servis, PRoot'ta çalışmaz

---

## 6. ERP Kullanım Senaryoları (Referans)

| Senaryo | Topoloji | Agent'lar |
|---------|----------|-----------|
| Rutin migration deploy | Hierarchical | Coordinator → Coder → Reviewer |
| Paralel JS+SQL değişikliği | Mesh | Coder(JS) + Coder(SQL) → Merger |
| Kritik bulk UPDATE | Byzantine | Coordinator → 2x Reviewer → onay → Coder |
| ETL / veri analizi zinciri | Ring | Parser → Transformer → Validator → Loader |
| Uzun plan (10+ task) | Star | Coordinator (Claude) → N x DeepSeek Worker |

---

## 7. Skill Upgrade Önerileri (deepseek-tui-plan)

Araştırmadan çıkan, mevcut skill'e eklenecek pattern'lar:

1. **Topoloji Seçimi Adımı** — plan yazmadan önce task bağımlılık grafiği çıkar, topoloji belirle
2. **SONA Memory Hook** — her plan sonuna otomatik `memory_add(pattern, category="code_change")` ekle
3. **Checkpoint Pattern** — uzun planlarda (5+ task) ara checkpoint'ler → recovery
4. **Model Routing Kararı** — plan başına hangi task'ın hangi modelle yapılacağını belirle
5. **Byzantine Onay** — mevcut tek onay → riskli task'lar için "Reviewer agent" adımı ekle
6. **Dosya Sahipliği** — paralel task'larda her task hangi dosyaya yazacağını netleştir (race condition önleme)

---

*Araştırma: 2026-05-24 | Claude Sonnet 4.6 + Explore subagent*
