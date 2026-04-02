# 🚀 EgeSüt ERP — Quick Start (Session Stability)

## ⚡ Hızlı Başlangıç

### İlk Kez Kullanım

```bash
# 1. update-cli çalıştır
./update-cli

# 2. Mevcut oturumu kapat
/exit

# 3. PRoot optimized başlat
./fedora-optimized.sh

# 4. Qwen Code başlat
qwen
```

### Günlük Kullanım

```bash
# Her 4 saatte bir
./session-clean.sh

# Yeni oturum başlat
./fedora-optimized.sh
qwen
```

---

## 📁 Komutlar

| Komut | Ne Zaman | Ne Yapar |
|-------|----------|----------|
| `./update-cli` | İlk kurulum VEYA sorun olduğunda | Tüm optimizasyonları otomatik kurar |
| `./session-clean.sh` | Her 4 saatte bir | Zombie process temizler |
| `./fedora-optimized.sh` | Her yeni oturum başında | PRoot optimizasyonlu başlatır |
| `qwen` | Normal kullanım | Qwen Code başlatır |

---

## 🎯 Beklenen Sonuçlar

### Öncesi
```
Session ömrü: ~30 dakika
Memory: ~600MB
Process: 13+
Crash: Sık
```

### Sonrası
```
Session ömrü: ~4+ saat (+8x)
Memory: ~300MB (-50%)
Process: 8+ (-40%)
Crash: Nadir
```

---

## 🔧 Sorun Giderme

### Session çöküyor

```bash
# 1. Temizlik yap
./session-clean.sh

# 2. update-cli çalıştır
./update-cli

# 3. Yeni oturum başlat
./fedora-optimized.sh
qwen
```

### update-cli hata veriyor

```bash
# Logları kontrol et
cat /root/egesut-erp1/.update-logs/update-*.log | tail -30

# Durum dosyasını kontrol et
cat /root/egesut-erp1/.update-status.json
```

### MCP bağlantısı kopuk

```bash
# MCP kontrol
qwen mcp list

# Beklenen: gwen-consolidated + context7
```

---

## 📊 Durum Sorgulama

```bash
# Son update durumu
cat /root/egesut-erp1/.update-status.json

# Son log
ls -t /root/egesut-erp1/.update-logs/update-*.log | head -1 | xargs tail -20

# Memory durumu
free -h

# Process sayısı
ps aux | grep node | wc -l
```

---

## 📚 Detaylı Dokümantasyon

- `SESSION_STABILITY.md` — Tüm optimizasyonlar detaylı
- `.claude/UPDATE_RECOVERY_GUIDE.md` — Agent recovery prosedürleri
- `.qwen/AGENT_HIERARCHY.md` — Ofis sistemi

---

**Tarih:** 2026-03-31  
**Durum:** ✅ Production Ready
