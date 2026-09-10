---
name: memory-update
description: "EgeSüt ERP tools-bank memory sistemini güncelle. Kullanıcı 'memory güncelle' veya 'tools bank memory güncelle' dediğinde bu skill'i çağır."
---

# Memory Update — tools-bank

Bu skill, EgeSüt ERP'nin tools-bank memory sistemine (`memory_notes` — SQLite + sqlite-vec + FTS5/BM25, **lokal Qwen3-Embedding-0.6B GPU embedding**, Jina/bge-m3 DEĞİL) yeni bilgiler eklemek ve mevcut notları güncellemek için kullanılır.

> **2026-07-05 düzeltme:** Bu dosya önceden "Jina AI embedding" diyordu — bayattı. `memory_notes` artık tamamen lokal (Qwen3, GPU, offline). Sadece ayrı bir sistem olan `code_embeddings` (kod/doküman `semantic_search`) bulut Cloudflare `@cf/baai/bge-m3` kullanıyor — ikisi karıştırılmamalı, aynı 1024-dim uzayda ama farklı modeller. Detay: `project_toolsbank_embedding_architecture` memory (Claude Code native memory, egesut-erp1 projesi).

## Ne Zaman Çağrılır

- Kullanıcı "memory güncelle", "tools bank memory güncelle", "not ekle", "şunu kaydet" dediğinde
- Oturum sonunda kritik kararlar, hatalar, RPC referansları kaydedileceği zaman
- Bir hata çözüldüğünde veya yeni bir kural keşfedildiğinde

## Workflow

### 1. Oturum Bilgilerini Topla

Son oturumda neler yapıldığını özetle:
- Hangi dosyalar değiştirildi
- Hangi kararlar alındı
- Hangi hatalar çözüldü
- Hangi RPC'ler/migration'lar eklendi

### 2. Kategori Seç

| Kategori | Ne Zaman Kullanılır |
|----------|---------------------|
| `code_change` | Kod değişikliği, yapısal karar, refactor |
| `critical_rules` | Güvenlik kuralı, yapılması/yapılmaması gerekenler |
| `rpc_reference` | Yeni RPC fonksiyonu, parametre değişikliği |
| `domain_rules` | İş domain'i kuralı, çiftlik akışı |
| `tech_stack` | Teknoloji seçimi, bağımlılık, tool |
| `general` | Yukarıdakilerin hiçbiri |

### 3. `memory_add` ile Kaydet

Her bir bilgi için ayrı `memory_add` çağrısı yap:

```
memory_add({content: "...", category: "...", priority: "high|medium|low", tags: "etiket1,etiket2"})
```

**Örnekler:**

```
memory_add({content: "tohumlama_sonuc_bos RPC'si eklendi — tohumlama_id parametresi alır, durumu 'bos' yapar", category: "rpc_reference", priority: "high", tags: "rpc,tohumlama"})

memory_add({content: "AGENTS.md'ye tools-bank MCP bölümü eklendi — 13 tool: 4 memory + 9 gitnexus", category: "code_change", priority: "medium", tags: "agants,mcp,docs"})

memory_add({content: "Stok hareketleri asla silinmez, immutable ledger. Düzeltme yeni kayıt olarak girilir.", category: "critical_rules", priority: "high", tags: "stok,ledger,immutable"})
```

### 4. Önceliklendirme

- `high`: Kalıcı kurallar, güvenlik, kritik RPC'ler
- `medium`: Normal değişiklikler, yeni özellikler
- `low`: Küçük notlar, hatırlatmalar

### 5. Etiketleme İpuçları

- Birden çok kategoriyi etiketlerle birleştir (örn: `"rpc,hayvan,kritik"`)
- Dosya adlarını etiket olarak ekle (örn: `"ui.js,forms.js"`)
- Migration numarasını ekle (örn: `"mig-027"`)
- Hata kodlarını ekle (örn: `"42883,bug"`)

## Önemli

- `memory_add` lokal Qwen3 GPU ile otomatik embedding oluşturur (offline, ağ yok). Elle `--rebuild` gerekmez.
- Aynı bilgiyi tekrar ekleme — önce `memory_search` ile kontrol et (yüksek `sim` skorlu bir eşleşme varsa yeni içerik gerçekten farklı/güncel mi diye bak, salt tekrar ise ekleme).
- Oturum sonunda MUTLAKA kaydet. Bir sonraki oturum `memory_search` ile başlar.
- **Claude Code'un kendi native memory'si (`~/.claude/projects/*/memory/*.md`, `MEMORY.md` index) ile bu vektör DB (`memory_notes`) OTOMATİK senkron DEĞİL** — biri diğerini otomatik beslemez. Native memory dosyası yazınca/güncelleyince aynı bilginin aranabilir bir özetini AYRICA `memory_add` ile buraya da gönder (bkz. global `session-update` skill'inin 3.5 adımı — bu skill'in genişletilmiş hâli).
