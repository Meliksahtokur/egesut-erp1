# Goose Tokio Crash Fix — Design

**Tarih:** 2026-05-21  
**Durum:** Brainstorm tamamlandı, implementasyon bekleniyor  
**Sonraki adım:** Yaklaşım A implementasyonu için writing-plans

---

## Problem

EgeSüt ERP'de goused-api, Goose worker'larını `exec.Cmd` ile subprocess olarak spawn ediyor. Bu model altında Goose zaman zaman şu hatayla crash oluyor:

```
thread 'tokio-rt-worker' panicked at tokio-1.50.0/.../io/driver.rs:196:23:
unexpected error when polling the I/O driver:
Os { code: 38, kind: Unsupported, message: "Function not implemented" }
The futex facility returned an unexpected error code.
```

**Teşhis:**
- OS error code 38 = `ENOSYS` — kernel syscall desteklenmiyor
- PRoot ortamı, Tokio'nun kullandığı epoll/futex variant syscall'larını pass-through etmiyor
- Crash sadece **subprocess spawn modunda** görülüyor
- Goose, terminal'de interaktif çalıştırıldığında hiç Tokio crash yaşanmadı
- Sonuç: Sorun Tokio'nun kendisi değil, goused-api'nin Goose'u subprocess olarak spawn etme şekliyle ortaya çıkıyor (FD inheritance, pipe setup, environment farkı)

---

## Goose'un Kendi Gateway/Server Seçenekleri

```
goose serve --port 3284   → ACP (Agent Communication Protocol) HTTP + WebSocket server
goose gateway start ...   → Telegram vb. harici platform entegrasyonu (bizimle alakasız)
goose acp                 → stdio ACP modu
```

`goose serve` bizim için ilgili olan: Goose'u persistent HTTP daemon olarak başlatır.

---

## Üç Yaklaşım

### Yaklaşım A — `goose serve` ACP Daemon (ÖNERİLEN)

**Mimari:**
```
Claude → goused MCP tool → HTTP POST :3284 → goose serve (kalıcı daemon)
                                                    ↑
                                          Subprocess değil, kendi process'i
                                          Terminal'de çalışmayla aynı model
```

**Nasıl çalışır:**
- `goose serve --port 3284` bir kere başlatılır (watchdog ile)
- goused-api artık Goose spawn etmez; ACP HTTP endpoint'lerine task gönderir
- Session'lar ACP protokolü üzerinden yönetilir
- goused-api'nin commit lock, telsiz, tier slots özellikleri korunur

**Pro:**
- Subprocess spawn yok → Tokio crash yok (terminal modelin aynısı)
- goused-api kodu dramatik şekilde basitleşir
- Goose'un native session yönetimi kullanılır

**Con:**
- ACP protokolü öğrenilmeli (endpoint'ler, session format)
- Mevcut recipe YAML formatı muhtemelen değişir
- Tek process — crash olursa watchdog restart eder, aktif session'lar kesilir

---

### Yaklaşım B — goused-api Subprocess Spawn Düzeltmesi

`exec.Cmd` spawn'ında FD inheritance ve process group sorununu düzelt:

```go
cmd.SysProcAttr = &syscall.SysProcAttr{Setsid: true}
cmd.Stdin = nil
// ExtraFiles temizle
```

**Pro:** Mimari değişmez, recipe YAML'lar çalışmaya devam eder  
**Con:** Root cause tahmine dayalı — düzelmeyebilir  
**Con:** PRoot futex/epoll sınırlaması ortadan kalkmaz

---

### Yaklaşım C — goused-api Tamamen Kaldır

goused-api tamamen silinir, tüm orchestration `goose serve` ACP üzerinden yapılır.

**Pro:** En temiz mimari — tek Goose daemon, custom Go kodu yok  
**Con:** En büyük değişiklik  
**Con:** Commit lock, heartbeat watchdog, tier slots yeniden yazılmalı  
**Con:** ACP'nin bu özellikleri destekleyip desteklemediği bilinmiyor

---

## Karar: Yaklaşım A

**Gerekçe:**
1. Terminal'de Goose hiç Tokio crash yaşamadı → persistent daemon modeli çalışıyor
2. `goose serve` tam olarak bu: kendi process'i olarak çalışan Goose
3. goused-api'yi tamamen atmıyoruz — commit lock, telsiz, tier slots değerli kalıyor
4. Değişiklik scope'u makul: sadece spawn mantığı → HTTP client'a dönüşüyor

---

## Sonraki Adımlar

1. `goose serve`'in ACP protokolünü keşfet — session başlat, task gönder, sonuç al
2. goused-api'yi ACP client'a çevir (goose_start → ACP session, goose_status → ACP session status)
3. goused MCP tool'larını güncelle (interface değişmez, altta ACP çalışır)
4. watchdog'a goose serve'i de ekle
5. recipe YAML migration planı — ACP formatına geçiş

---

## İlgili Dosyalar

- Crash log: `/tmp/goose-gebelik-001.log`
- goused-api kaynak: `/root/tools-bank/internal/api/session.go`
- Mevcut mimari: `.claude/arch-decisions/ADR-007-multi-tier-goose-orchestration.md`
- goused skill: `.claude/skills/goused/SKILL.md`
