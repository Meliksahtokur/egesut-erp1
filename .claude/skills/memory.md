# Memory Skill - Mini-Agent Bellek Sistemi

## 📋 Genel Bakış

Bu skill, Mini-Agent'ın bellek yeteneklerini genişletir. Notlar otomatik olarak vektör embededding alır, entity extraction yapılır ve benzer notlar bulunur.

**Oluşturulma:** 2025-04-05  
**Versiyon:** 1.0  
**Durum:** ✅ Aktif

---

## 🎯 Bu Skill Ne Yapar?

1. **Otomatik Embedding:** Her kaydedilen not vektör embedding alır
2. **Semantic Search:** Anahtar kelime değil, anlam bazlı arama
3. **Benzer Not Bulma:** İçerik benzerliğine göre not önerileri
4. **Entity Extraction:** Kod ve metinlerden varlık (dosya, fonksiyon, değişken) çıkarımı
5. **Knowledge Graph:** Notlar arası ilişki haritası

---

## 🛠️ Kullanılabilir Araçlar

### 1. `record_note` - Not Kaydetme (Ana Araç)

```python
record_note(content="Bugün migration 028 tamamlandı", category="migration")
```

**Otomatik Tetiklenir:**
- ✅ SQLite'e kaydet
- ✅ FTS5 full-text index güncelle
- ✅ MiniMax API ile embedding üret
- ✅ Knowledge graph entity extraction

**Parametreler:**
- `content`: Not içeriği (zorunlu)
- `category`: Kategori (opsiyonel) - "project", "migration", "bug", "feature", "tech"
- Özel kategoriler: `[note]`, `[memory_enhancement]`, `[egesut]`, `[rpc]`, `[commands]`

### 2. Bellek Arama Araçları

Tüm araçlar `.claude/memory/` klasöründe:

```bash
# Hızlı arama (FTS5 + BM25)
python3 .claude/memory/search_tool.py --query "migration"

# Semantic arama (anlam bazlı)
python3 .claude/memory/embedding_service.py --search "nasıl yapılır"

# Benzer notlar
python3 .claude/memory/find_similar_notes.py --query "python"

# Bilgi grafiği sorgula
python3 .claude/memory/knowledge_graph.py --query "sqlite"
```

---

## 🚀 Nasıl Kullanılır?

### Senaryo 1: Yeni Bilgi Öğrenildiğinde

```python
# Agent bir şey öğrendiğinde
record_note(
    content="Supabase'te RLS policy oluştururken,
             authenticated() rolü kullanılmalı",
    category="tech"
)
```

**Sonuç:**
- SQLite'e kaydedildi
- Embedding üretildi (ileride semantic search için)
- Entity çıkarıldı: "Supabase", "RLS", "authenticated"

### Senaryo 2: Benzer Not Aramak

```bash
# Benzer kod örnekleri bul
python3 .claude/memory/find_similar_notes.py --query "python liste işlemleri"
```

**Örnek Çıktı:**
```
📝 Benzer Notlar:
1. [python-veri-yapilari] (78% benzerlik)
   - Python listeler, dict, set kullanımı
2. [javascript-diziler] (45% benzerlik)
   - JavaScript array metodları
```

### Senaryo 3: Knowledge Graph Sorgulama

```bash
# Entity ilişkilerini bul
python3 .claude/memory/knowledge_graph.py --query "Backend"
```

**Örnek Çıktı:**
```
🏗️ Entity: Backend
📊 İlişkili Varlıklar:
   - RPC (4 bağlantı)
   - Supabase (3 bağlantı)
   - Migration (3 bağlantı)
```

---

## 📊 Mevcut Veritabanları

| DB | Boyut | İçerik |
|----|-------|--------|
| `memory.db` | 156 KB | Notlar + FTS5 + Embeddings |
| `knowledge_graph.db` | 568 KB | Entities + Relationships |

**Toplam:**
- 16 kayıtlı not
- 321 entity
- 4,819 ilişki

---

## 🎓 En İyi Pratikler

### ✅ Yapılacaklar

1. **Önemli bulguları kaydet:**
   ```python
   record_note("Migration 028'de batch_size=100 kullan")
   ```

2. **Hata çözümlerini kaydet:**
   ```python
   record_note("Supabase RLS Error: authenticated() kullan", category="bug")
   ```

3. **Semantic search kullan anlam aramak için:**
   ```bash
   python3 .claude/memory/embedding_service.py --search "veritabanı sorgusu nasıl"
   ```

### ❌ Yapılmaması Gerekenler

1. **Çok kısa notlar:** En az 2-3 cümle
2. **Tekrar:** Aynı bilgiyi tekrar kaydetme (önce `find_similar` kontrol et)
3. **Günlük notları:** Sadece teknik bilgi kaydet

---

## 🔧 Geliştirici Bilgisi

### Dosya Yapısı

```
.claude/
├── memory/
│   ├── sqlite_backend.py       # Veritabanı işlemleri
│   ├── search_tool.py          # FTS5 arama
│   ├── embedding_service.py    # Vector embeddings
│   ├── find_similar_notes.py   # Benzerlik algoritması
│   ├── knowledge_graph.py       # Entity extraction
│   ├── memory.db              # Notlar + embeddings
│   └── knowledge_graph.db      # Entity graph
└── skills/
    └── memory.md              # ⬅️ Bu dosya
```

### Teknik Detaylar

**Embedding Model:** MiniMax `embo-01`  
**Vector Boyutu:** 1024  
**Benzerlik:** Cosine Similarity  
**FTS5:** BM25 ranking

### Sınırlar

- Embedding rate limit: 60 RPM (MiniMax)
- Rate limit aşılırsa: Deterministik fallback (hash-based)
- Max not uzunluğu: 10,000 karakter

---

## 🚦 Otomatik Kullanım Kuralları

Agent şu durumlarda otomatik kayıt yapmalı:

| Durum | Örnek | Kategori |
|-------|-------|----------|
| Yeni teknoloji öğrenildi | "Supabase RLS kullanımı" | `tech` |
| Bug çözüldü | "Migration timeout sorunu" | `bug` |
| Kod değişikliği | "Stok API refactor" | `feature` |
| Önemli karar | "Authenticated() seçimi" | `decision` |

---

## 📞 Örnek Workflow

```
1. Agent: "Migration scripti yazıyorum"
   ↓
2. record_note("Migration 028 başladı", category="migration")
   ↓
3. Sistem otomatik:
   - SQLite'e kaydeder
   - Embedding üretir
   - Entity çıkarır (Migration, 028)
   ↓
4. Agent: "Benzer migration var mı?"
   ↓
5. python3 .claude/memory/find_similar_notes.py --query "migration"
   ↓
6. Sonuç: Önceki migration'lar listelenir
```

---

## 🔗 İlgili Dosyalar

- `.agent_memory.json` - Agent konfigürasyonu
- `.mini_agent_tasks.json` - Görev takibi
- `README.md` - Proje dokümantasyonu

---

**Son Güncelleme:** 2025-04-05  
**Yazan:** Mini-Agent Memory Enhancement System
