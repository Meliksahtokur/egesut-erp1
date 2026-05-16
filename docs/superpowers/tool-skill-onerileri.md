# Tool/Skill Önerileri — 2026-05-16

## Mevcut Durum

- **Semantic search**: Çalışıyor, Türkçe sorguları anlıyor. Ama `code_embeddings` tablosu (Supabase pgvector) boş olduğu için sadece `.md` dokümanlarına dönüyor. Kod sembolleri için gitnexus_query daha verimli.
- **GitNexus**: ✅ Otomatik index aktif (her 12 saatte bir `mcp-health-daemon.sh` ile). Manuel `npx gitnexus analyze` gerekmiyor.
- **MCP Health**: ✅ Daemon çalışıyor (zombie temizlik + gitnexus index). `tmux attach -t mcp-health` ile durum görülebilir.

---

## Öneri 1: GitNexus Analizini Otomatikleştir ✅

**Durum:** Tamamlandı (2026-05-16)

**Çözüm:** `mcp-health-daemon.sh` ile arka planda çalışıyor:
- Her 5 dakikada bir zombie MCP server kontrolü
- Her saat başı (en az 12 saat geçmişse) `npx gitnexus analyze` tetikler
- `tmux` session'ı üzerinden kalıcı olarak ayakta

**Kullanım:**
```bash
# Durum kontrol
tmux has-session -t mcp-health && echo "çalışıyor" || echo "ölü"

# Log görüntüle
tail -20 /var/log/mcp-health-daemon.log
tail -10 /var/log/mcp-health.log

# Manuel çalıştırma
/root/tools-bank/scripts/mcp-health.sh --quick    # zombie only
/root/tools-bank/scripts/mcp-health.sh --index    # gitnexus only
```

---

## Öneri 5: MCP Server Health Monitor ✅

**Durum:** Tamamlandı (2026-05-16)

**Amaç:** MCP server (python3 server.py --stdio) zombie olduğunda otomatik temizlik + log.

**İçerik:**
- `mcp-health.sh` — zombie tespit + SIGCHLD parent'a + kill -9
- `mcp-health-daemon.sh` — cron'suz ortam için foreground loop (flock ile single-instance)
- `/etc/systemd/system/mcp-health.{service,timer}` — systemd ortamı için (referans, bu container'da çalışmaz)

**Sınırlama:** deepseek-tui Rust runtime SIGCHLD handler'ı `wait()` çağırmadığı için zombie parent exit edene kadar kalabilir. Script tespit eder, log'a yazar, parent'a sinyal gönderir.

---

## Öneri 2: Yeni Skill — ui-pattern-detection ❌

**Amaç:** Frontend'de hangi pattern kullanıldığını hızlı tespit et.
- DOM-based mi state-based mi?
- Event delegation mi inline `onclick` mi?
- Stok, sürü, görev modüllerinde farklı pattern'ler var.

**Kullanım:** "Bana stok pattern'ini referans al" demek yerine tek skill'den pattern analizi + bağımlılık raporu.

**Öncelik:** Orta — sık kullanılan bir pattern ama acil değil.

---

## Öneri 3: Yeni Skill — codebase-tour ❌

**Amaç:** `semantic_search` + `grep_files` + `list_dir`'ı kombine eden keşif skill'i.
- "Şu modülü anlamak istiyorum" → otomatik dosya taraması + execution flow çıkarma
- Yeni geliştiriciler için onboarding dokümanı üretme

**Öncelik:** Düşük — mevcut araçlar elle kombine edilebiliyor.

---

## Öneri 4: Semantic Search İyileştirmesi 🟡

**Sorun:** `memory_search` Supabase'deki `notes_fts` tablosu olmadığı için çökmüyor ama hata dönüyor.

**Güncel Durum:** tools-bank local SQLite FTS5 + vec0 çalışıyor. Supabase tarafı ihmal edilebilir.

**Öncelik:** Düşük — local sistem yeterli.

---

## Özet

| # | Öneri | Öncelik | Durum |
|---|-------|---------|-------|
| 1 | GitNexus otomatik index | Yüksek | ✅ Tamam |
| 5 | MCP server health monitor | Yüksek | ✅ Tamam |
| 2 | ui-pattern-detection skill | Orta | ❌ Bekliyor |
| 3 | codebase-tour skill | Düşük | ❌ Bekliyor |
| 4 | Semantic search FTS fix | Düşük | 🟡 Kısmen |
