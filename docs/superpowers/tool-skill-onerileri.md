# Tool/Skill Önerileri — 2026-05-15

## Mevcut Durum

- **Semantic search**: Çalışıyor, Türkçe sorguları anlıyor. Ama `code_embeddings` tablosu (Supabase pgvector) boş olduğu için sadece `.md` dokümanlarına dönüyor. Kod sembolleri için gitnexus_query daha verimli.
- **GitNexus**: `gitnexus_impact` ve `gitnexus_query` çalışıyor. `npx gitnexus analyze` her oturumda manuel başlatılıyor (~30sn).

## Öneri 1: GitNexus Analizini Otomatikleştir

**Sorun:** Her oturumda `npx gitnexus analyze` manuel çalıştırılıyor. Bu zaman kaybı.

**Çözüm:** Gecelik cron job'ı veya GitHub Action ile index'i tazele:
- `crontab -e` ile her gece 03:00'te `cd /root/egesut-erp1 && npx gitnexus analyze`
- Veya push sonrası GitHub Action'da `npx gitnexus analyze` tetikle

**Öncelik:** Yüksek — her oturumu ~30sn hızlandırır.

## Öneri 2: Yeni Skill — ui-pattern-detection

**Amaç:** Frontend'de hangi pattern kullanıldığını hızlı tespit et.
- DOM-based mi state-based mi?
- Event delegation mi inline `onclick` mi?
- Stok, sürü, görev modüllerinde farklı pattern'ler var.

**Kullanım:** "Bana stok pattern'ini referans al" demek yerine tek skill'den pattern analizi + bağımlılık raporu.

**Öncelik:** Orta — sık kullanılan bir pattern ama acil değil.

## Öneri 3: Yeni Skill — codebase-tour

**Amaç:** `semantic_search` + `grep_files` + `list_dir`'ı kombine eden keşif skill'i.
- "Şu modülü anlamak istiyorum" → otomatik dosya taraması + execution flow çıkarma
- Yeni geliştiriciler için onboarding dokümanı üretme

**Öncelik:** Düşük — mevcut araçlar elle kombine edilebiliyor.

## Öneri 4: Semantic Search İyileştirmesi

**Sorun:** `memory_search` Supabase'deki `notes_fts` tablosu olmadığı için çökmüyor ama hata dönüyor.

**Çözüm:** `memory_notes` tablosu + FTS5 index'i oluştur:
```sql
CREATE TABLE IF NOT EXISTS memory_notes (
  id SERIAL PRIMARY KEY,
  content TEXT,
  category TEXT,
  priority TEXT,
  tags TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
-- FTS index için Supabase Management API
```

**Öncelik:** Düşük — şu an .md dosyaları yeterli bilgiyi sağlıyor.

## Özet

| # | Öneri | Öncelik | Etki |
|---|-------|---------|------|
| 1 | GitNexus otomatik index | Yüksek | ~30sn/tasarruf |
| 2 | ui-pattern-detection skill | Orta | Kodlama hızı |
| 3 | codebase-tour skill | Düşük | Keşif hızı |
| 4 | Semantic search FTS fix | Düşük | Hata giderme |
