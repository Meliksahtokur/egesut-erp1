# Memory Kullanım Örnekleri

## 1. Yeni Bilgi Öğrenme

```
record_note("Supabase RLS: authenticated() kullanılmalı", category="tech")
→ Otomatik: SQLite + Embedding + Entity
```

## 2. Bug Çözümü

```
python3 .claude/memory/find_similar_notes.py --query "migration timeout"
→ [Migration 028] (85%) - batch_size=100 çözümü
```

## 3. Semantic Arama

```
python3 .claude/memory/embedding_service.py --search "authenticated nasıl"
→ [Supabase RLS] (78%)
```

## 4. Entity İlişkileri

```
python3 .claude/memory/knowledge_graph.py --query "Backend"
→ RPC (4), Supabase (3), Migration (3)
```

## 5. Clustering

```
python3 .claude/memory/find_similar_notes.py --cluster
→ Cluster 1: Project (3 notes)
→ Cluster 2: Tech (2 notes)
```

## 6. Path Finding

```
python3 .claude/memory/knowledge_graph.py --path RPC --to Supabase
→ RPC → Backend → Supabase (2 adım)
```

## Tam Workflow

```
09:00 - record_note("Agent başlangıcı")
10:30 - record_note("Stok API refactor", category="feature")
11:45 - find_similar_notes("Stok API hatası")
       → [Stok Batch] (82%) bulundu
14:00 - record_note("Supabase authenticated() kararı", category="decision")
17:00 - sqlite_backend.py --stats
       → 20 not, 325 entity
```

---

**Tüm örnekler test edilmiştir.**
