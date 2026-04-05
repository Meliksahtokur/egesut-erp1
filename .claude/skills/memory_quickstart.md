# Memory Skill - Hızlı Başlangıç Kılavuzu

## 🎯 Memory Skill'i Aktivatör

### Agent Başlangıçında Çalıştır:

```python
# Bu fonksiyonu agent'ın başlangıçında çağır
get_skill('memory')
```

---

## 📚 Memory Skill İçindekiler

### 1. Not Kaydetme
```python
record_note(content="...", category="...")
```

### 2. Arama Komutları

| Komut | Kullanım |
|-------|----------|
| **FTS5 Arama** | `python3 .claude/memory/search_tool.py --query "anahtar_kelime"` |
| **Semantic Arama** | `python3 .claude/memory/embedding_service.py --search "anlam_bazli_sorgu"` |
| **Benzer Notlar** | `python3 .claude/memory/find_similar_notes.py --query "icerik"` |
| **Knowledge Graph** | `python3 .claude/memory/knowledge_graph.py --query "entity"` |

---

## 🚀 Hızlı Kullanım Senaryoları

### Senaryo 1: "Benzer bir şey yazmıştık"
```bash
python3 .claude/memory/find_similar_notes.py --query "migration Supabase"
```

### Senaryo 2: "Önceki notları ara"
```bash
python3 .claude/memory/search_tool.py --query "RLS policy"
```

### Senaryo 3: "Anlam bazlı ara"
```bash
python3 .claude/memory/embedding_service.py --search "veritabanı authenticated nasıl"
```

### Senaryo 4: "Entity ilişkilerini bul"
```bash
python3 .claude/memory/knowledge_graph.py --query "Backend"
```

---

## 📊 Örnek Agent Konuşmaları

### "Kaydet" Komutu
```
User: Supabase'de authenticated() kullan
Agent: record_note("Supabase authenticated() rolü kullanılmalı", category="tech")
```

### "Bul" Komutu
```
User: Benzer migration var mı?
Agent: python3 .claude/memory/find_similar_notes.py --query "migration"
```

### "İlişkili" Komutu
```
User: Backend ile ne ilgili vardı?
Agent: python3 .claude/memory/knowledge_graph.py --query "Backend"
```

---

## 🎓 Öğrenme Kuralları

Agent şu durumlarda otomatik kayıt yapmalı:

| Durum | Ne Kaydet | Kategori |
|-------|-----------|----------|
| Bug çözüldü | Hata + Çözüm | `bug` |
| Yeni teknoloji | Kullanım şekli | `tech` |
| Kod değişikliği | Ne değişti | `feature` |
| Önemli bilgi | Detaylar | `project` |

---

## ⚡ Hızlı Not

**Tüm araçlar hazır ve çalışıyor!**  
Sadece `get_skill('memory')` çağır ve kullan.
