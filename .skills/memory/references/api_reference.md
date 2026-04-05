# Memory API Reference

## Komutlar

### 1. search_tool.py - FTS5 Arama
```bash
python3 .claude/memory/search_tool.py --query "anahtar_kelime"
python3 .claude/memory/search_tool.py --query "migration" --category "tech"
python3 .claude/memory/search_tool.py --query "Supabase" --limit 5
```

### 2. embedding_service.py - Semantic Arama
```bash
python3 .claude/memory/embedding_service.py --search "veritabanı sorgusu"
python3 .claude/memory/embedding_service.py --embed-note <note_id>
python3 .claude/memory/embedding_service.py --stats
```

### 3. find_similar_notes.py - Benzerlik
```bash
python3 .claude/memory/find_similar_notes.py --query "python"
python3 .claude/memory/find_similar_notes.py --note-id 5
python3 .claude/memory/find_similar_notes.py --cluster
python3 .claude/memory/find_similar_notes.py --auto-tag <note_id>
```

### 4. knowledge_graph.py - Entity Graph
```bash
python3 .claude/memory/knowledge_graph.py --query "Backend"
python3 .claude/memory/knowledge_graph.py --relate "Supabase"
python3 .claude/memory/knowledge_graph.py --path RPC --to Supabase
python3 .claude/memory/knowledge_graph.py --extract
```

### 5. sqlite_backend.py - İstatistik
```bash
python3 .claude/memory/sqlite_backend.py --stats
python3 .claude/memory/sqlite_backend.py --list
```

## Örnek Senaryolar

### Hızlı Arama
```bash
python3 .claude/memory/search_tool.py --query "migration" --category "bug"
```

### Anlam Araması
```bash
python3 .claude/memory/embedding_service.py --search "authenticated nasıl"
```

### Benzer Not
```bash
python3 .claude/memory/find_similar_notes.py --query "Supabase RLS"
```

### Entity İlişki
```bash
python3 .claude/memory/knowledge_graph.py --relate "RPC"
```

## Veritabanları

| DB | İçerik |
|----|--------|
| `memory.db` | Notlar + Embeddings |
| `knowledge_graph.db` | Entities + Relations |
