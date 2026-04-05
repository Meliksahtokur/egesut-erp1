---
name: memory
description: Mini-Agent bellek sistemi - notları otomatik embedding alır, semantic search yapar, benzer notlar bulur ve entity extraction gerçekleştirir. "kaydet", "ara", "benzer", "ilişkili", "hatırla" isteklerinde kullanılmalıdır.
---

# Memory Skill

## Overview

Mini-Agent'ın bellek yeteneklerini genişletir:
- **Embedding:** Her not 1024-boyut vector alır
- **Semantic Search:** Anlam bazlı arama (keyword değil)
- **Similarity:** Benzer not bulma
- **Knowledge Graph:** 321 entity, 4,819 ilişki

**Durum:** 16 not | 100% embedding | Aktif ✅

## Quick Reference

### Not Kaydetme

```python
record_note(content="...", category="...")
```

**Otomatik:** SQLite + Embedding + Entity Extraction

### Arama Komutları

```bash
python3 .claude/memory/search_tool.py --query "anahtar"
python3 .claude/memory/embedding_service.py --search "anlam"
python3 .claude/memory/find_similar_notes.py --query "icerik"
python3 .claude/memory/knowledge_graph.py --query "entity"
```

### Kategoriler

- `project`, `tech`, `migration`, `bug`, `feature`, `decision`

## Detaylı Kullanım

Tüm komutlar, örnekler ve teknik detaylar için:
- [API Reference](references/api_reference.md) - Komut syntax'ı
- [Examples](references/examples.md) - Kullanım senaryoları

## Scripts

Tüm scriptler `.claude/memory/` klasöründe:
- `sqlite_backend.py` - Veritabanı + FTS5
- `search_tool.py` - Full-text arama
- `embedding_service.py` - Semantic search
- `find_similar_notes.py` - Benzerlik + clustering
- `knowledge_graph.py` - Entity extraction
