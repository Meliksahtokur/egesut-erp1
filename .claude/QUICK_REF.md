# Mini-Agent Memory Enhancement System
# =============================================

## 🧠 Auto-Enhanced Memory Tools

Agent, `record_note()` çağırdığında **otomatik olarak** şunlar yapılır:
- ✅ SQLite veritabanına kayıt
- ✅ FTS5 full-text index güncelleme
- ✅ Vector embedding oluşturma
- ✅ Entity extraction (knowledge graph)
- ✅ Relationship detection

**Agent hiçbir şey yapmadan bu özelliklerden yararlanır.**

---

## 🔍 Memory Sorgulama Komutları

### Arama (FTS5 - Hızlı, 11ms)
```bash
python3 .claude/memory/search_tool.py --query "arama_terimi" --category <kategori>
```

### Semantic Arama (Anlamsal)
```bash
python3 .claude/memory/embedding_service.py --search "anlamlı_cümle"
```

### Benzer Notlar
```bash
python3 .claude/memory/find_similar_notes.py --query "konu" --limit 5
```

### Bilgi Grafı Sorgula
```bash
python3 .claude/memory/knowledge_graph.py --query "entity_adi"
python3 .claude/memory/knowledge_graph.py --path "entity1" "entity2"
```

### İstatistikler
```bash
python3 .claude/memory/sqlite_backend.py --stats
python3 .claude/memory/embedding_service.py --stats
python3 .claude/memory/knowledge_graph.py --graph
```

---

## 💡 Pratik Kullanım Senaryoları

### "Bunu daha önce yazmıştım"
→ `bash("python3 .claude/memory/search_tool.py --query '...'")`

### "Benzer bir şey var mı?"
→ `bash("python3 .claude/memory/find_similar_notes.py --query '...'")`

### "Hangi entity'ler geçiyor?"
→ `bash("python3 .claude/memory/knowledge_graph.py --query '...'")`

---

## 📊 Memory Durumu Kontrol Et
```bash
# Toplam not, kategoriler, boyut
python3 .claude/memory/sqlite_backend.py --stats

# Embedding coverage
python3 .claude/memory/embedding_service.py --stats

# Knowledge graph istatistikleri
python3 .claude/memory/knowledge_graph.py --graph
```
