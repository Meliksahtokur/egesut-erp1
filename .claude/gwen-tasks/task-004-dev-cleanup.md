# Task-004: Development Branch Temizliği — Merge Öncesi Zorunlu

**Durum:** bekliyor
**Branch:** development (mevcut branch'te çalış, yeni branch açma)
**Öncelik:** YÜKSEk — bu task tamamlanmadan development → main merge YAPILMAZ

---

## Görev Özeti

Development branch'i incelendi. Gerçek kod değişiklikleri (bug fixler, UI düzeltmeleri) onaylı.
**Ama** repoya girmemesi gereken bir sürü çöp dosya commit edilmiş. Bunlar temizlenmeden merge yok.

---

## Yapılacaklar

### 1. Şu dosya ve klasörleri development branch'inden sil

Aşağıdakilerin tamamını `git rm` ile sil:

```
dbsnapshot_full.sql
.aider.input.history
.aider.tags.cache.v4/
.update-logs/
agent-telemetry/
gwen-mcp.log
```

Komutlar:
```bash
git rm dbsnapshot_full.sql
git rm -r .aider.input.history
git rm -r ".aider.tags.cache.v4/"
git rm -r .update-logs/
git rm -r agent-telemetry/
git rm gwen-mcp.log
```

Eğer bu dosyaların bir kısmı zaten `.gitignore`'da varsa ve tracked değilse hata alırsın — o zaman sadece tracked olanları sil, geri kalanları atla.

---

### 2. .gitignore'u güncelle

`.gitignore` dosyasına şu pattern'leri EKLE (varsa duplicate yapma, önce grep ile kontrol et):

```gitignore
# SQL dump dosyaları
dbsnapshot*.sql
*snapshot*.sql

# Aider editor dosyaları
.aider*
.aider.tags.cache.v4/

# Log dosyaları
*.log
.update-logs/

# Agent telemetri
agent-telemetry/

# Qwen agent dosyaları
.qwen/
gwen-mcp.log
```

---

### 3. supabase/migrations dosyasını kontrol et

Development branch'inde şu dosya var:
```
supabase/migrations/20260331000032_vaccination_module.sql
```

Bu dosyayı aç ve içeriğini oku. Eğer içinde gerçek migration SQL'i varsa (CREATE TABLE, ALTER TABLE, vb.) **dokunma** — bu dosya main'e geçmeli.
Eğer içi boş ya da test verisi varsa bize haber ver.

---

### 4. DEFERRED_FEATURES.md dosyasını teyit et

Development'ta `DEFERRED_FEATURES.md` adında bir dokümantasyon dosyası var (103 satır).
Bu dosyayı aç, içinde hassas bilgi (şifre, token, connection string, gerçek kullanıcı verisi) var mı kontrol et.
Yoksa dosyaya dokunma — main'e geçebilir.

---

### 5. Commit ve push

Tüm temizlik işlemi **tek commit** olsun:

```bash
git add .gitignore
git commit -m "chore: kirli dosyalar temizlendi, .gitignore güncellendi — merge öncesi zorunlu temizlik

- dbsnapshot_full.sql silindi (3863 satır SQL dump repoya girmemeli)
- .aider.* geçici editor dosyaları silindi
- .update-logs/ log klasörü silindi
- agent-telemetry/ telemetri dosyaları silindi
- gwen-mcp.log silindi
- .gitignore: bu dosya tipleri için pattern eklendi"
```

Sonra push:
```bash
git push origin development
```

---

## Kabul Kriterleri

- [ ] `git diff --name-status main..development` çıktısında `dbsnapshot_full.sql` YOK
- [ ] `git diff --name-status main..development` çıktısında `.aider*` YOK
- [ ] `git diff --name-status main..development` çıktısında `.update-logs/` YOK
- [ ] `git diff --name-status main..development` çıktısında `agent-telemetry/` YOK
- [ ] `git diff --name-status main..development` çıktısında `gwen-mcp.log` YOK
- [ ] `.gitignore` güncellendi ve push edildi
- [ ] `supabase/migrations/20260331000032_vaccination_module.sql` hakkında rapor verildi

---

## Önemli Notlar

- **main branch'e dokunma.** Sadece development'ta çalış.
- `dbsnapshot_full.sql` dosyasını silmeden önce okuma — gereksiz yere zaman harcama, zaten repoya girmemeli.
- Eğer `git rm` sırasında "pathspec did not match" hatası alırsan o dosya zaten tracked değil demektir, `.gitignore`'a eklersen yeterli.
- Birden fazla commit açma — temizlik tek committe bitsin.
- Bu task tamamlandıktan sonra `task-004-done.md` yaz ve bize bildir.

---

## Tamamlandığında

`.claude/gwen-tasks/task-004-done.md` dosyası oluştur, şu bilgileri yaz:
- Hangi dosyalar silindi
- `supabase/migrations` dosyası hakkında ne buldun
- `DEFERRED_FEATURES.md` hakkında ne buldun
- Commit hash
