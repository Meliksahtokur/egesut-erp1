---
name: block-direct-db-writes
enabled: true
event: file
action: block
pattern: db\.from\(['"`](tohumlama|dogum|hayvanlar|kizginlik_log|islem_log|gorev_log)['"`]\)\s*\.\s*(update|insert|delete|upsert)\s*\(
---

🛑 **Korunan tabloya doğrudan DB yazma tespit edildi!**

Bu tablolar SADECE Supabase RPC fonksiyonları üzerinden yazılmalıdır:

- `tohumlama` → `tohumlama_kaydet` RPC
- `dogum` → `dogum_kaydet` RPC
- `hayvanlar` → `hayvan_ekle` / `hayvan_guncelle` RPC
- `kizginlik_log`, `islem_log`, `gorev_log` → RPC/trigger'lar tarafından doldurulur

Doğrudan yazma; validasyon, state machine guard'larını ve otomatik task oluşturmayı bypass eder.
Bkz: `.claude/domain-rules.md` bölüm 13 ve `.claude/session-learnings.md`
