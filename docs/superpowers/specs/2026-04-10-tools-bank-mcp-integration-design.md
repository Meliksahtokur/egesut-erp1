# Design: Tools-Bank → Claude Code CLI Entegrasyonu

**Tarih:** 2026-04-10  
**Branch:** feat/tools-bank-mcp-integration  
**Durum:** Tasarım onaylandı, implementasyon bekliyor

---

## Bağlam

Tools-bank, EgeSüt ERP projesinin geliştirme altyapısıdır: SQLite FTS5 tabanlı bellek sistemi, MiniMax embo-01 ile 1024-boyutlu vektör embedding'leri, knowledge graph ve otomasyon araçlarını kapsar. Şu an bu araçlar yalnızca manuel CLI komutlarıyla erişilebilir; Claude Code'a entegre değil.

### Mevcut Araçlar

| Araç | Konum | Durum |
|---|---|---|
| `memory_search.py` | tools-bank/tools/ | Çalışıyor (FTS5) |
| `embedding_service.py` | tools-bank/memory/ | embo-01 ile çalışıyor |
| `search_tool.py` | tools-bank/memory/ | Çalışıyor |
| `knowledge_graph.py` | tools-bank/memory/ | Çalışıyor |
| `intelligence_wrapper.py` | tools-bank/tools/ | Çalışıyor |
| `daemon-manager.sh` | tools-bank/automation/ | Çalışıyor |
| `code_change_watcher.py` | tools-bank/automation/ | Çalışıyor |

### Sorunlar

- tools-bank, egesut-erp1 repo'su içinde → diğer agentların push/pull'ları dosyaları ezebilir
- Claude Code'un araçlara native erişimi yok — proaktif kullanamıyor
- Semantic search MINIMAX_API_KEY olmadan rastgele embedding üretiyordu (artık key var)

---

## Kararlar

### Repo Ayrımı

tools-bank, egesut-erp1'den **ayrı bir git reposuna** taşınır:

```
/root/tools-bank/     ← Yeni konum (ayrı repo)
/root/egesut-erp1/    ← ERP projesi, tools-bank bağımlılığı yok
```

**Gerekçe:** Çok agent ortamında (Claude, OpenCode, Gwen) pull/push çakışmalarını önlemek. tools-bank altyapı katmanı, proje kodu değil.

### MCP Daemon (stdio değil, persistent daemon)

**Seçilen:** Daemon tabanlı MCP — Unix socket üzerinden haberleşme.

**Gerekçe:** PRoot/ARM ortamında stdio yaklaşımı her tool çağrısında Python process başlatır (~300-500ms). Daemon, FTS5 index ve embedding cache'i RAM'de sıcak tutar, tool çağrısı <10ms'e iner. `daemon-manager.sh` zaten crash recovery ve PID yönetimi yapıyor.

### Embedding Modeli

**Model:** MiniMax `embo-01` — 1024 boyut  
**Key:** `MINIMAX_API_KEY` settings.json env'ine eklenir  
**Fallback:** API erişilemezse deterministic hash embedding (arama kalitesi düşer ama hata vermez)

---

## Mimari

```
Claude Code CLI
    │
    ├── [Katman 1] MCP Daemon (tools-bank/mcp/server.py)
    │       Unix socket → kalıcı process, daemon-manager.sh yönetir
    │       Tools: memory_search, semantic_search, knowledge_graph_query,
    │              memory_add, memory_stats
    │
    ├── [Katman 2] UserPromptSubmit Hook (tools-bank/hooks/prompt_context_injector.py)
    │       Her kullanıcı mesajında → keyword çıkar → memory_search
    │       → bulunan critical_rules / rpc_reference notları context'e inject
    │
    └── [Katman 3] Skills (tools-bank/skills/mem-tools/SKILL.md)
            /mem-search <query>   → FTS5 + semantic, formatlanmış çıktı
            /mem-add <text>       → Not ekle + embed
            /mem-graph <entity>   → Knowledge graph sorgusu
            /mem-stats            → DB istatistikleri
```

---

## Hedef Dosya Yapısı

```
/root/tools-bank/                    ← YENİ REPO
├── .git/
├── mcp/
│   ├── server.py                    ← MCP daemon (YENİ)
│   └── README.md
├── hooks/
│   └── prompt_context_injector.py   ← (YENİ)
├── skills/
│   └── mem-tools/
│       └── SKILL.md                 ← (YENİ)
├── memory/
│   ├── memory.db                    ← Taşınıyor
│   ├── knowledge_graph.db           ← Taşınıyor
│   ├── embedding_service.py         ← Taşınıyor
│   ├── search_tool.py               ← Taşınıyor
│   ├── knowledge_graph.py           ← Taşınıyor
│   └── ...diğer memory araçları
├── tools/
│   ├── intelligence_wrapper.py      ← Taşınıyor, path'ler güncellenir
│   ├── intelligence_shortcuts.sh    ← Taşınıyor
│   └── memory_search.py             ← Taşınıyor
└── automation/
    ├── daemon-manager.sh            ← Taşınıyor, tools-bank-mcp entry eklenir
    ├── code_change_watcher.py       ← Taşınıyor
    └── file_watcher.sh              ← Taşınıyor
```

---

## settings.json Değişiklikleri

`/root/.claude/settings.json`'a eklenecekler:

```json
{
  "mcpServers": {
    "tools-bank": {
      "command": "python3",
      "args": ["/root/tools-bank/mcp/server.py", "--socket", "/tmp/tools-bank-mcp.sock"],
      "env": {
        "MINIMAX_API_KEY": "sk-cp-..."
      }
    }
  },
  "hooks": {
    "UserPromptSubmit": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "python3 /root/tools-bank/hooks/prompt_context_injector.py"
          }
        ]
      }
    ]
  }
}
```

---

## MCP Server Exposed Tools

### `memory_search`
```
input:  query (str), category (str, optional), limit (int, default=5)
output: [{id, content, category, priority, tags, rank}]
```

### `semantic_search`
```
input:  query (str), limit (int, default=5)
output: [{id, content, category, similarity_score}]
```

### `knowledge_graph_query`
```
input:  entity (str), relation_target (str, optional)
output: {nodes, edges, paths}
```

### `memory_add`
```
input:  content (str), category (str), priority (str), tags ([str])
output: {id, embedded: bool}
```

### `memory_stats`
```
input:  -
output: {total_notes, embeddings, categories, db_size_mb}
```

---

## Daemon Yaşam Döngüsü

```
Alpine başlar
  └─ daemon-manager.sh start tools-bank-mcp
       └─ nohup python3 /root/tools-bank/mcp/server.py &
            └─ Unix socket açar: /tmp/tools-bank-mcp.sock
                 └─ Claude Code bağlanır → tool çağrıları <10ms

Alpine kapanır
  └─ socket kapanır, PID dosyası temiz kalır

Sonraki başlangıçta
  └─ daemon-manager.sh → PID kontrolü → restart
```

---

## Kapsam Dışı (Bu Tasarımda Yok)

- Başka projelerde tools-bank kullanımı (ileride, global config)
- Web UI veya dashboard
- tools-bank'in egesut-erp1'e submodule olarak bağlanması
- Çoklu memory DB (şimdilik tek global DB)
- Otomatik Alpine başlangıç scripti (init.d/rc.local — PRoot'ta kısıtlı)
