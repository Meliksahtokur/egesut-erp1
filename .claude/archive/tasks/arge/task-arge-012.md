# Task-arge-012: Operator Pattern Implementasyonu — Faz 1

**Durum:** bekliyor
**Branch:** gwen/arge
**Tarih:** 2026-04-02
**Öncelik:** yüksek
**Kaynak:** task-arge-011 tasarım belgesi

---

## Bağlam

task-arge-011 analizi tamamlandı. gwen.md operator pattern'e geçiyor.

**Hedef:** gwen.md artık kodu kendisi yazmayacak — ekip kuracak, dağıtacak, derleyecek.

---

## Yapılacaklar

### 1. 4 Yeni Agent Dosyası Oluştur

**a) `.agents/qwen/agents/gwen-researcher.md`**
- Rol: Context yükleme uzmanı
- Tools: `read_file`, `grep_search`
- Görev: domain-rules.md + rpc-reference.md + ui-map.md paralel oku, 50 satır özet çıkar
- Girdi: task tipi (tohumlama, doğum, hayvan, RPC)
- Çıktı: kritik kurallar + RPC imzası özeti

**b) `.agents/qwen/agents/gwen-analyst.md`**
- Rol: Mevcut kod analisti
- Tools: `read_file`, `grep_search`
- Görev: İlgili js dosyalarını oku, değişiklik gerektiren satırları tespit et, pattern öner
- Girdi: task özeti + RESEARCHER özeti
- Çıktı: dosya:satır listesi + pattern önerisi

**c) `.agents/qwen/agents/gwen-coder.md`**
- Rol: Kod yazma uzmanı
- Tools: `read_file`, `edit_file`, `run_shell_command`
- Görev: ANALYST pattern'ini + RESEARCHER kurallarını uygulayarak kod yaz, node --check çalıştır
- Girdi: ANALYST önerisi + RESEARCHER kuralları
- Çıktı: değiştirilen dosyalar + node --check sonucu
- **Kritik:** Direkt REST yasak, sadece rpcOptimistic() kullan

**d) `.agents/qwen/agents/gwen-tester.md`**
- Rol: Test ve güvenlik mühendisi
- Tools: `run_shell_command`, `grep_search`
- Görev: syntax + duplikat + security kontrolü
- Girdi: CODER'ın değiştirdiği dosyalar
- Kontroller: node --check, grep duplikat, API key scan, SQL injection, RPC bypass
- Çıktı: PASS/FAIL raporu + hatalar

---

### 2. gwen.md Operator Workflow'u Ekle

`gwen.md`'nin "🛠️ Çalışma Akışı" bölümünü güncelle:

**Eski flow:** tek agent tüm adımları yapar
**Yeni flow:**

```
1. TASK AL (Operator)
2. PLAN HAZıRLA (Operator) — 3-5 adım
3. EKİP KUR:
   a. RESEARCHER spawn → paralel context yükle
   b. ANALYST spawn → mevcut kodu analiz et (RESEARCHER sonucu ile)
   c. CODER spawn → kod yaz (ANALYST + RESEARCHER sonuçları ile)
   d. TESTER spawn → test et (CODER çıktısı ile)
4. SONUÇLARI DERLE (Operator)
5. /review → gwen-reviewer
6. COMMIT + PUSH (Operator)
7. RAPOR YAZ (Operator) — done.md + BLACKBOARD
```

**Koordinasyon kuralları (gwen.md'ye ekle):**
- RESEARCHER + ANALYST paralel spawn edilebilir (farklı dosyalar okuyorlar)
- CODER her zaman sıralı — ANALYST bitmeden başlamaz
- TESTER her zaman sıralı — CODER bitmeden başlamaz
- BLACKBOARD.md dosya kilidi: "js/forms.md → CODER (meşgul)"
- Max 3 paralel agent
- Her agent max 3 retry, sonra task bloke

**Basit task istisnası:** Tek dosya, tek fonksiyon değişikliği → operator olmadan eski flow kullan (overhead'e değmez)

---

### 3. Setup.sh Güncelle

4 yeni agent'ı `~/.qwen/agents/`'e kopyalayan satırları ekle (mevcut sync mekanizmasına ekle).

---

## Kabul Kriterleri

- [ ] `gwen-researcher.md` oluşturuldu, `~/.qwen/agents/`'e kopyalandı
- [ ] `gwen-analyst.md` oluşturuldu, `~/.qwen/agents/`'e kopyalandı
- [ ] `gwen-coder.md` oluşturuldu, `~/.qwen/agents/`'e kopyalandı
- [ ] `gwen-tester.md` oluşturuldu, `~/.qwen/agents/`'e kopyalandı
- [ ] `gwen.md` operator workflow'u güncellendi
- [ ] `setup.sh` 4 yeni agent'ı sync ediyor
- [ ] Push edildi, `task-arge-012-done.md` yazıldı

---

## Notlar

- Yeni MCP ekleme YASAK
- Her agent dosyası ~100-150 satır max — kısa tut
- Türkçe dil kuralı her agent'ta geçerli
- gwen-reviewer değişmez — Faz 1'e dahil değil
- Büyük task / küçük task ayrımını gwen.md'ye açıkça yaz
