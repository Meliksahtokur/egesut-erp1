# Goose Serve / ACP — Araştırma Soruları

**Amaç:** goused-api'nin exec.Cmd spawn modelini `goose serve` ACP daemon'una geçirmek için
gerekli bilgileri topla. Çıktıları bu dosyaya ekle.

**Araştırma kaynakları:**
- https://block.github.io/goose/docs/
- https://github.com/block/goose
- ACP spec: https://agentcommunicationprotocol.dev/

---

## Bölüm 1 — goose serve vs goose acp Farkı

**Bilinen:**
- `goose serve` → HTTP + WebSocket server, port 3284, network daemon
- `goose acp` → stdio transport (başka bir ACP orchestrator'ın Goose'u subprocess embed ettiği durum)
- Her ikisi de ACP protokolünü implement ediyor, transport farklı

**Araştırılacak:**

1. `goose serve` ile `goose acp` hangi ACP özelliklerini farklı implement ediyor?
   Session lifecycle, tool call, streaming davranışı farklı mı?

2. `goose serve` birden fazla bağımsız session'ı eşzamanlı destekliyor mu?
   Yoksa tek session mı var, sıralı mı çalışıyor?

3. `goose serve`'in HTTP endpoint listesi nedir?
   - Session aç: `POST /sessions` mı? Body formatı?
   - Mesaj gönder: `POST /sessions/{id}/messages` mı?
   - Durum sorgula: `GET /sessions/{id}` mı?
   - Session kapat: `DELETE /sessions/{id}` mı?

4. Yanıtlar streaming mi (SSE/WebSocket) yoksa polling mi?
   goused-api'de long-poll yaptık, burada ne yapacağız?

---

## Bölüm 2 — Process ve Session Yönetimi

5. `goose serve` max kaç eşzamanlı session destekliyor?
   Limit var mı, config'den ayarlanabiliyor mu?

6. Bir session içinde Goose tool call yapıyor (file_write, bash vb.) —
   bu tool call'lar hangi working directory / user context'inde çalışıyor?
   Subprocess spawn'da her goose process kendi env'inde çalışıyordu.

7. Session crash olursa (Goose içinde panic/error) serve process ayakta kalıyor mu?
   Sadece o session mı ölüyor, tüm server mı duruyor?

8. `goose serve` restart olursa aktif session'lar ne oluyor?
   Resume edilebilir mi, yoksa sıfırdan mı başlamak gerekiyor?

---

## Bölüm 3 — MCP ve Extension Konfigürasyonu

9. `goose serve` başlarken hangi MCP server'ları yüklüyor?
   `~/.config/goose/config.yaml`'daki MCP config'i otomatik okuyup yüklüyor mu?
   Yoksa `--with-builtin` ile manuel ekleme mi şart?

   **Kritik:** tools-bank MCP ve duckduckgo MCP serve modunda da çalışmalı.
   Şu an `goose run` ile spawn edildiğinde bu MCP'ler Goose'a DEERFLOW_ADMIN_EMAIL vb.
   env var'larıyla birlikte geçiriliyor. Serve modunda nasıl geçirilecek?

10. `goose serve` ile başlatılan session'a "bu recipe'yi çalıştır" şeklinde talimat
    verilebiliyor mu? Recipe YAML dosyaları ACP üzerinden nasıl geçirilir?
    Yoksa recipe konsepti serve modunda yok mu, sadece prompt mu var?

11. `--with-builtin` flag ne zaman kullanılıyor? Hangi builtin'ler var?

---

## Bölüm 4 — Authentication ve Güvenlik

12. `goose serve` herhangi bir auth gerektiriyor mu?
    Localhost'ta token olmadan POST atabilir miyiz?
    Yoksa API key / Bearer token şart mı?

13. CORS politikası var mı? (Browser'dan değil Go'dan HTTP atıyoruz, muhtemelen önemsiz)

---

## Bölüm 5 — Pratik Entegrasyon

14. goused-api'deki `goose_start(recipe, session_id, params)` flow'u
    ACP'de nasıl karşılık buluyor?
    - Recipe → ACP'de system prompt / initial message mi?
    - session_id → ACP session ID'si mi, yoksa goused kendi mı yönetiyor?
    - params JSON → nasıl geçirilir?

15. `goose_status(session_id)` için ACP'de polling endpoint var mı?
    Yoksa WebSocket subscription mı gerekiyor?

16. Session'ı zorla durdurmak (cascade kill, SIGTERM) ACP'de nasıl yapılıyor?
    `DELETE /sessions/{id}` yeterli mi?

17. Başka projeler goused-api benzeri bir şey yazıp goose serve'e entegre etmiş mi?
    GitHub'da örnek var mı?

---

## Bölüm 6 — Alternatif: Doğrudan Goose HTTP Client

goused-api'yi Go'da yeniden yazmak yerine:
- Python'da basit bir ACP client yazıp MCP tool olarak eklemek
- tools-bank MCP server'ına `goose_session_start`, `goose_session_send`, `goose_session_status`
  tool'larını doğrudan HTTP ile implement etmek

18. Bu yaklaşım mümkün mü? ACP endpoint'leri stable / documented mı?

---

## Notlar

- Crash log (referans): `/tmp/goose-gebelik-001.log`
  `thread 'tokio-rt-worker' panicked: ENOSYS (code 38) — Function not implemented`
  Sadece subprocess spawn'da oluyor, terminal'de hiç olmadı.

- Mevcut goused-api: `/root/tools-bank/internal/api/session.go`
- Spec: `docs/superpowers/specs/2026-05-21-goose-tokio-crash-fix-design.md`
- Goose version: `goose --version` ile kontrol et araştırma sırasında
