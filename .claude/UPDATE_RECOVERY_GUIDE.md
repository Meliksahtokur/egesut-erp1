# 🔄 Session Stability Update — Agent Recovery Guide

**Son Güncelleme:** 2026-03-31  
**Durum:** ✅ Tamamlandı (update-cli ile)

---

## 📋 Hızlı Başvuru

### Kullanıcı Ne Zaman `update-cli` Çalıştırır?

```bash
# Her yeni oturum başında VEYA
# Session crash sorunu yaşandığında
./update-cli
```

### update-cli Ne Yapar?

| Adım | Açıklama | Süre |
|------|----------|------|
| 1/6 | .bashrc → NODE_OPTIONS=256MB | 1sn |
| 2/6 | session-clean.sh kontrol | 1sn |
| 3/6 | fedora-optimized.sh kontrol | 1sn |
| 4/6 | MCP Consolidation kontrol | 2sn |
| 5/6 | Git durumu kontrol | 1sn |
| 6/6 | Özet ve talimatlar | - |

**Toplam:** ~6 saniye

---

## 🤖 Agent İçin Bilgiler

### Durum Sorgulama

```bash
# 1. update-cli durumunu kontrol et
cat /root/egesut-erp1/.update-status.json

# 2. Son logları oku
ls -lt /root/egesut-erp1/.update-logs/ | head -3

# 3. En son log detayı
cat $(ls -t /root/egesut-erp1/.update-logs/update-*.log | head -1)
```

### Başarı Kriterleri

✅ **update-cli başarılı oldu ise:**
- `.update-status.json` → `"status": "success"`
- `.bashrc` → `NODE_OPTIONS="--max-old-space-size=256"` satırı var
- `session-clean.sh` → Var ve executable
- `fedora-optimized.sh` → Var ve executable
- `gwen-mcp-servers/consolidated/` → Var ve node_modules yüklü

❌ **update-cli başarısız oldu ise:**
- `.update-status.json` → `"status": "failed"`
- Log dosyasında `❌ HATA:` mesajı var
- Kullanıcıya log dosyasını göster

---

## 📁 Dosya Konumları

| Dosya | Yol | Amaç |
|-------|-----|------|
| **update-cli** | `/root/egesut-erp1/update-cli` | Ana update script |
| **Durum** | `/root/egesut-erp1/.update-status.json` | Son update durumu |
| **Loglar** | `/root/egesut-erp1/.update-logs/` | Tüm update logları |
| **Cleanup** | `/root/egesut-erp1/session-clean.sh` | Zombie temizliği |
| **PRoot** | `/root/egesut-erp1/fedora-optimized.sh` | PRoot optimizasyonu |
| **MCP** | `/root/egesut-erp1/gwen-mcp-servers/consolidated/` | Tek MCP server |

---

## 🔍 Troubleshooting

### Sorun: update-cli çalışmıyor

```bash
# 1. Executable kontrolü
ls -la /root/egesut-erp1/update-cli

# 2. Bash syntax kontrolü
bash -n /root/egesut-erp1/update-cli

# 3. Manuel çalıştır
bash /root/egesut-erp1/update-cli
```

### Sorun: .bashrc değişiklikleri kayıp

```bash
# NODE_OPTIONS kontrolü
grep NODE_OPTIONS /root/.bashrc

# Yoksa ekle
echo 'export NODE_OPTIONS="--max-old-space-size=256"' >> /root/.bashrc
```

### Sorun: session-clean.sh yok

```bash
# Git'ten geri yükle
cd /root/egesut-erp1
git checkout session-clean.sh
chmod +x session-clean.sh
```

### Sorun: MCP Consolidation çalışmıyor

```bash
# Dependencies yükle
cd /root/egesut-erp1/gwen-mcp-servers/consolidated
npm install

# Test et
timeout 3 node index.js
```

---

## 📊 Beklenen Sonuçlar

### update-cli Öncesi

```bash
$ ps aux | grep node | wc -l
13+

$ free -h | grep Mem
7.4Gi used: ~3.6Gi

$ qwen mcp list
gwen-supabase, gwen-github, context7 (3 ayrı process)
```

### update-cli Sonrası

```bash
$ ps aux | grep node | wc -l
8+

$ free -h | grep Mem
7.4Gi used: ~2.8Gi

$ qwen mcp list
gwen-consolidated, context7 (2 process)
```

---

## 🎯 Agent Aksiyon Listesi

### Kullanıcı "update-cli çalıştırdım" derse:

1. **Durum kontrolü:**
   ```bash
   cat /root/egesut-erp1/.update-status.json
   ```

2. **Başarılı ise:**
   - Kullanıcıyı tebrik et
   - Yeni oturum başlatmasını söyle
   - `./fedora-optimized.sh` kullanmasını hatırlat

3. **Başarısız ise:**
   - Log dosyasını oku
   - Hatayı tespit et
   - Manuel düzeltme yap veya kullanıcıyı yönlendir

### Kullanıcı "session çöküyor" derse:

1. **Hemen yap:**
   ```bash
   ./session-clean.sh
   ```

2. **Sonra kontrol et:**
   ```bash
   cat /root/egesut-erp1/.update-status.json
   ```

3. **Eğer update-cli çalışmamışsa:**
   ```bash
   ./update-cli
   ```

4. **Yeni oturum başlat:**
   ```bash
   ./fedora-optimized.sh
   qwen
   ```

---

## 📝 Commit Mesajı Şablonu

Eğer update-cli yeni dosyalar oluşturduysa:

```bash
cd /root/egesut-erp1
git add -A
git commit -m "[gwen] feat: update-cli — Session stability automation

- update-cli: Tek komutla tüm optimizasyonlar
- .update-status.json: Durum takibi
- .update-logs/: Log arşivi
- Agent recovery guide: Agent'lar için başvuru

Kullanıcı ./update-cli ile tüm optimizasyonları otomatik uygular."
```

---

## 🔗 İlgili Dokümantasyon

- `SESSION_STABILITY.md` — Tüm optimizasyonlar detaylı
- `.qwen/AGENT_HIERARCHY.md` — Ofis sistemi
- `session-clean.sh` — Cleanup script
- `fedora-optimized.sh` — PRoot başlatma

---

**Güncelleme Tarihleri:**
- 2026-03-31: İlk oluşturma
- 2026-03-31: update-cli automation

**Son Kontrol:** ✅ Agent bu dosyayı kullanarak recovery yapabilir
