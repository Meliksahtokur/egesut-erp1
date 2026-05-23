# TASK — Goose Sistem Standardizasyonu

**Durum:** Bekliyor  
**Öncelik:** Orta  
**Tarih:** 2026-05-21

---

## Yapılacaklar

### 1. goose-watch script (terminal izleme)
ACP log'ları okunabilir şekilde stream eden script:
```bash
# /root/tools-bank/scripts/goose-watch.sh <session_id>
tail -f /root/tools-bank/logs/goose-acp-$1.log | python3 -c "
import sys,re,json
for line in sys.stdin:
    # Tool calls
    m=re.search(r'\"title\":\"([^\"]+)\"', line)
    if m and 'agent_message_chunk' not in line:
        print(f'\n🔧 {m.group(1)}', flush=True)
    # Text output
    m2=re.search(r'\"sessionUpdate\":\"agent_message_chunk\".*?\"text\":\"(.*?)\"}}', line)
    if m2: print(m2.group(1), end='', flush=True)
"
```

### 2. goused servis watchdog CLAUDE.md'ye ekle
Oturum başında servis kontrolü — gerekirse otomatik başlat.
Startup rutinine eklenecek:
```
agent_register("claude") → 111 hata → telsiz down → binary başlat
```

### 3. Protokol skill yazılacak
`erp-goose-workflow` adında skill:
- Claude spec yaz → conductor başlat → approval_req bekle → onay ver → final review
- Her seferinde tarif edilmesine gerek kalmayacak

### 4. goused servisleri için startup script
`/root/tools-bank/scripts/start-all-services.sh` — tek komutla hepsini başlat, health check yap.

---

## 5. Hayvan 195 — Üreme Geçmişi Görünüm Sorunu

**Sorun:** Küpe 195, doğum yapıp yeniden tohumlanan hayvan, kart üreme geçmişinde 5. tohumlama olarak görünüyor.
**Durum:** TASK-026 ile deneme_no DB'de düzeltildi. UI'da `deneme_no` alanını gösteriyor mu doğrulanacak.

**Kontrol edilecek:** `_detUremeHtml` fonksiyonu (js/ui.js:733) `deneme_no` kolonunu gösteriyor mu?
Eğer IDB'deki eski cache'lenmiş veri kullanılıyorsa, migration sonrası sayfa yenileme gerekebilir.
Veya `deneme_no` UI'da hiç gösterilmiyor olabilir — görünüm sorunu farklı olabilir.

**Aksiyon:** Hayvan 195'in güncel tohumlama verisini `supabase_query` ile çek, deneme_no değerlerini kontrol et.
