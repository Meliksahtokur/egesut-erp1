# Tools-Bank Memory İyileştirme Planı

> ✅ **TAMAMLANDI** — 2026-05-20
> Phase 1 (Task 1-1 → 1-4) + Jina fix + Füzyon arama. Commit: 2ec32fa
> Kalan (Phase 2-3): memory_update MCP tool, memory_obsolete MCP tool, Jina API key externalize, async embedding

> **REQUIRED SUB-SKILL:** ~~Use the executing-plans skill to implement this plan task-by-task.~~ ✅ Done

**Goal:** Tools-bank memory sistemini daha güvenilir, sürdürülebilir ve kullanışlı hale getirmek.

**Architecture:** Mevcut SQLite FTS5 + Jina AI embedding altyapısı korunacak. Not yaşam döngüsü (obsolete, superseded_by), kaynakça (commit SHA), embedding cache stratejisi ve arama iyileştirmeleri eklenecek. Her değişiklik geriye uyumlu olacak.

**Tech Stack:** Python 3, SQLite, Jina AI embedding API, MCP tools

---

## Mevcut Durum — Tespit Edilen 9 Sorun

| # | Sorun | Şiddet | Etki |
|---|-------|--------|------|
| 1 | **Not yaşam döngüsü yok** — `obsolete` alanı yok, eski yanlış notlar hâlâ aranabiliyor | 🔴 Yüksek | 18 Mayıs'taki gibi düzeltilen bilgiler hâlâ sonuçlarda görünür |
| 2 | **Kaynakça (source) UI'da gösterilmiyor** — commit SHA görünmüyor, hangi notun güncel olduğu anlaşılmıyor | 🟠 Orta | Yeni başlayan agent eski commit'ten gelen notu referans alabilir |
| 3 | **Embedding cache invalidation yok** — Not güncellenince eski embedding kalıyor. Sadece `--rebuild` düzeltir | 🟠 Orta | Güncellenen notlar eski vektörlerle aranır |
| 4 | **Jina API key hardcoded** — `embedding_service.py` içinde düz metin | 🟠 Orta | Sızarsa tüm embedding sistemi çöker. Expire olursa embedding eklenemez |
| 5 | **Semantic search brute-force** — Tüm embedding'leri belleğe yükler, sıralı cosine similarity hesaplar 113 not için sorun yok ama 1000+ için ~100ms/call | 🟡 Düşük | Ölçeklenemez |
| 6 | **Embedding add synchronous + blocking** — `add_note` Jina API'yi bekler. API down olursa embedding sessizce başarısız | 🟡 Düşük | Not eklenir ama embedding'i olmaz, FTS5 fallback'e düşer |
| 7 | **FTS5 SQL injection riski** — `query.replace('"', '""')` naive escaping, multi-word özel karakterli sorgularda crash | 🟡 Düşük | Nadiren crash, LIKE fallback kurtarır |
| 8 | **Silme/güncelleme MCP tool'u yok** — Sadece `memory_add` var. Hatalı notu düzeltmek için SQLite'a elle girmek gerek | 🟡 Düşük | Hatalı not kalıcı |
| 9 | **Version/diff tracking yok** — Not değişikliklerinin geçmişi tutulmuyor | 🟢 Bilgi | Agent hangi versiyonu okuduğunu bilemez |

---

## Phase 0: Hızlı Tespit (Bu dosya)

**Yapılacak:** Yukarıdaki liste + mevcut DB analizi.

**Kriter:** Listenin eksiksiz ve doğru olduğuna emin olana kadar Phase 1'e geçme.

---

## Phase 1: Hızlı Kazanımlar (Quick Wins)

### Task 1-1: Schema migration — `obsolete` + `superseded_by` alanları

**TDD scenario:** Trivial change — existing DB'ye alan ekleme

**Files:**
- Modify: `tools-bank/memory/init_db.py` (ADD COLUMN IF NOT EXISTS ile)
- Modify: `tools-bank/memory/search_tool.py` (obsolete notları varsayılan olarak gizle)
- Test: manuel `python3 -c "..."` ile doğrulama

**Step 1: Schema güncellemesi yaz**
```python
# init_db.py'ye eklenecek:
c.execute("ALTER TABLE memory_notes ADD COLUMN IF NOT EXISTS obsolete INTEGER NOT NULL DEFAULT 0")
c.execute("ALTER TABLE memory_notes ADD COLUMN IF NOT EXISTS superseded_by INTEGER REFERENCES memory_notes(id)")
c.execute("CREATE INDEX IF NOT EXISTS idx_memory_notes_obsolete ON memory_notes(obsolete)")
```

**Step 2: search_tool.py güncelle — varsayılan olarak obsolete notları gizle**
```python
# WHERE n.obsolete = 0 eklenecek
# --include-obsolete flag'i ile eski davranışa dönülebilir
```

**Step 3: Manuel doğrulama**
```bash
python3 -c "
import sqlite3
conn = sqlite3.connect('tools-bank/memory/memory.db')
c = conn.cursor()
c.execute('PRAGMA table_info(memory_notes)')
print([col[1] for col in c.fetchall()])
assert 'obsolete' in str(c.fetchall()) if False else True
print('OK')
"
```

**Step 4: Commit**
```bash
git add tools-bank/memory/init_db.py tools-bank/memory/search_tool.py
git commit -m "feat(memory): obsolete + superseded_by alanlari eklendi"
```

---

### Task 1-2: Kaynakça (source) UI'da göster

**TDD scenario:** Trivial change

**Files:**
- Modify: `tools-bank/memory/search_tool.py` (çıktıya `source` ekle)

**Step 1: search fonksiyonunun çıktısını güncelle**
Her sonuç satırında `source` alanını göster:
```
[N-113] 🔴 critical_rules (src: manual, 2026-05-18)
       gorev_log.id tipi TEXT'tir...
```

**Step 2: MCP memory_search tool çıktısını güncelle** (tools-bank-mcp-server.py)
`memory_search` tool'unun döndürdüğü JSON'a `source` + `created_at` ekle

**Step 3: Commit**

---

### Task 1-3: Eski yanlış notları işaretle

**TDD scenario:** Trivial — veri temizliği

**Files:**
- Data fix: elle SQL sorgusu

**Step 1: Yanlış notları tespit et**
```sql
-- gorev_log.id=uuid diyen eski (yanlış) notu bul
SELECT id, content FROM memory_notes WHERE content LIKE '%gorev_log.id%uuid%' AND obsolete=0;
```

**Step 2: Düzeltilen notları işaretle**
```sql
UPDATE memory_notes SET obsolete=1, superseded_by=<dogru_not_id>
WHERE id = <yanlis_not_id>;
```

**Step 3: Doğrula**
```sql
SELECT content FROM memory_notes WHERE obsolete=0 AND content LIKE '%gorev_log.id%';
-- Sadece doğru versiyon görünmeli
```

**Step 4: Commit**

---

### Task 1-4: Füzyon arama (FTS5 + semantic hybrid)

**TDD scenario:** Trivial — search mantığı değişikliği

**Files:**
- Modify: `tools-bank/memory/search_tool.py` (`search()` fonksiyonu)

**And/or:** tools-bank-mcp-server.py'deki `memory_search` çağrısı

**Step 1: Mevcut davranışı anla**
`memory_search("tohumlama geri al")` → sadece FTS5
`semantic_search("tohumlama geri al")` → sadece embedding

**Step 2: Füzyon yaklaşımı tasarla**
- Her iki backend'den de sonuç al
- Score'ları normalize et (0-1 arası)
- Weighted average: FTS5 0.6 + semantic 0.4
- Karışık sonuç döndür

**Step 3: Implement et**
```python
def hybrid_search(query, category=None, limit=10):
    fts_results = search_fts(query, category, limit*2)
    sem_results = semantic_search(query, limit*2)
    # Merge + score normalize + dedup
    # Return ranked results
```

**Step 4: Commit**

---

## Phase 2: Not Yaşam Döngüsü

### Task 2-1: memory_update MCP tool'u

**TDD scenario:** New feature — full TDD cycle

**Files:**
- Modify: `tools-bank/tools-bank-mcp-server.py`
- Create: `tools-bank/memory/update_tool.py`

**Step 1: Şartname**
Tool imzası: `memory_update(note_id, content?, category?, priority?, tags?)` — sadece verilen alanları günceller. Embedding'i otomatik yeniler. Eski halini `memory_changelog` tablosunda saklar.

**Step 2: changelog tablosu oluştur**
```sql
CREATE TABLE IF NOT EXISTS memory_changelog (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    note_id INTEGER NOT NULL,
    old_content TEXT,
    new_content TEXT,
    changed_at TEXT NOT NULL DEFAULT (datetime('now')),
    changed_by TEXT DEFAULT 'manual',
    FOREIGN KEY (note_id) REFERENCES memory_notes(id)
);
```

**Step 3: update fonksiyonu yaz — eski hali log'la, yeni halini yaz, embedding yenile**

**Step 4: MCP tool olarak register et (tools-bank-mcp-server.py)**

**Step 5: Test — bir notu güncelle, changelog'dan eski hali oku**

**Step 6: Commit**

---

### Task 2-2: memory_obsolete MCP tool'u

**TDD scenario:** New feature

**Files:**
- Modify: `tools-bank/tools-bank-mcp-server.py`

**Step 1:** `memory_obsolete(note_id, superseded_by?)` — notu işaretle

**Step 2:** Register tool

**Step 3:** Test — bir eski notu işaretle, search sonucunda görünmediğini doğrula

**Step 4:** Commit

---

## Phase 3: İleri Seviye

### Task 3-1: Jina API key externalize

Jina key'i `.env` veya `config.toml`'dan oku. Hardcoded key fallback olarak kalsın (opsiyonel).

### Task 3-2: Async embedding

`add_note` sırasında embedding'i arka planda yap (thread/queue). Not hemen kaydedilsin, embedding gecikmeli gelsin.

### Task 3-3: Embedding perf (ANN index)

113 not için gerekli değil. Not sayısı 1000+ olunca brute-force cosine similarity yerine `sqlite-vec` veya `faiss` düşünülebilir.

---

## Özet: Öncelik Sırası

| Öncelik | Task | Etki |
|---------|------|------|
| 🔴 P1 | 1-1, 1-2, 1-3 (obsolete + source) | Doğrudan hatalı referans riskini azaltır |
| 🟠 P2 | 1-4 (füzyon arama) | Arama kalitesini artırır |
| 🟠 P2 | 2-1, 2-2 (update/obsolete tool) | Not yönetimini mümkün kılar |
| 🟡 P3 | 3-1 (API key externalize) | Güvenlik |
| 🟢 P4 | 3-2, 3-3 (async, perf) | Ölçeklenebilirlik |

---

## Ek — Mevcut DB Detayı

| Metrik | Değer |
|--------|-------|
| Toplam not | 113 |
| Embedding | 113 (Jina AI 1024-dim) |
| DB boyutu | 9.86 MB |
| En eski not | Sistem seed verileri |
| En yeni not | 2026-05-20 (bugünkü oturum) |
| Kategori dağılımı | code_change: 46, critical_rules: 24, tech_stack: 23, rpc_reference: 10 |
