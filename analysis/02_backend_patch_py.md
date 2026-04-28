# Backend Code Analysis: patch.py

**Dosya:** `/root/egesut-erp1/patch.py`  
**Analiz Tarihi:** 2026-04-17  
**Analiz Eden:** WORKER_BACKEND_2

---

## 1. Security (Güvenlik)

### 1.1 Path Traversal Riski
- **Öncelik:** [YUKSEK]
- **Dosya ve Satır:** patch.py:55
- **Sorun:** `Path(args[0])` ile alınan dosya yolu doğrudan kullanılıyor. Kullanıcı `../../etc/passwd` gibi path traversal saldırısı yapabilir.
- **Çözüm önerisi:**
```python
target = Path(args[0]).resolve()
# Proje dizini kontrolü ekle
allowed_base = Path("/root/egesut-erp1").resolve()
if not str(target).startswith(str(allowed_base)):
    die("Güvenlik: Proje dizini dışında dosya izin verilmiyor.")
```

### 1.2 subprocess Command Injection Riski
- **Öncelik:** [ORTA]
- **Dosya ve Satır:** patch.py:33, 36, 39
- **Sorun:** `subprocess.run` ile shell=False kullanılsa da, dosya adları kullanıcı girdisi içerebilir. `cwd` parametresi güvenlik açısından kritik.
- **Çözüm önerisi:** Dosya yollarını normalize edin, absolute path kullanın ve izin verilen dizin kontrolü yapın.

### 1.3 Backup Dosyası Üzerine Yazma
- **Öncelik:** [DUSUK]
- **Dosya ve Satır:** patch.py:7
- **Sorun:** `shutil.copy2` mevcut .bak dosyasını sormadan üzerine yazar. Veri kaybı riski.
- **Çözüm önerisi:** Mevcut .bak varsa numaralandırılmış yedek oluştur (örn: `.bak.1`, `.bak.2`).

---

## 2. Code Quality (Kod Kalitesi)

### 2.1 Eksik Docstring ve Type Hints
- **Öncelik:** [ORTA]
- **Dosya ve Satır:** Tüm dosya
- **Sorun:** Hiçbir fonksiyonda docstring yok. Type hints kullanılmamış. Kod okunabilirliği düşük.
- **Çözüm önerisi:**
```python
def apply_patch(target: Path, raw: str) -> bool:
    """Patch dosyasındaki SEARCH/REPLACE bloklarını hedef dosyaya uygular."""
```

### 2.2 Naming Tutarsızlıkları
- **Öncelik:** [DUSUK]
- **Dosya ve Satır:** patch.py:3-4, 5
- **Sorun:** Yardımcı fonksiyonlar `ok`, `warn`, `die` şeklinde kısa yazılmış. Standart Python convention'a uymuyor (snake_case).
- **Çözüm önerisi:** `print_ok`, `print_warning`, `exit_with_error` veya İngilizce isimler kullanın.

### 2.3 Yetersiz Error Handling
- **Öncelik:** [ORTA]
- **Dosya ve Satır:** patch.py:16, 55, 56
- **Sorun:** `target.read_text()` ve dosya okuma işlemleri try-except ile sarılmamış. FileNotFoundError, PermissionError yakalanmıyor.
- **Çözüm önerisi:**
```python
try:
    content = target.read_text(encoding="utf-8")
except PermissionError:
    die(f"Izin hatası: {target}")
except UnicodeDecodeError:
    die(f"Encoding hatası: {target}")
```

---

## 3. Best Practices (En İyi Uygulamalar)

### 3.1 DRY İhlali - subprocess.run Tekrarı
- **Öncelik:** [ORTA]
- **Dosya ve Satır:** patch.py:33, 36, 39
- **Sorun:** `subprocess.run` 3 kez tekrar ediliyor. Kod duplication var.
- **Çözüm önerisi:**
```python
def _git(cmd: list, cwd: Path) -> subprocess.CompletedProcess:
    return subprocess.run(cmd, cwd=cwd, capture_output=True, text=True)
```

### 3.2 Global State ve Side Effects
- **Öncelik:** [DUSUK]
- **Dosya ve Satır:** patch.py:7, 24
- **Sorun:** `backup()` ve dosya yazma işlemleri side effect oluşturuyor. Test edilebilirlik düşük.
- **Çözüm önerisi:** Fonksiyonları pure function olarak yeniden tasarlayın veya dependency injection kullanın.

### 3.3 Magic String/Number Sabitleri
- **Öncelik:** [DUSUK]
- **Dosya ve Satır:** patch.py:11, 14, 28, 48
- **Sorun:** `"---\n"`, `"SEARCH:"`, `"REPLACE:"`, `5` (git parent arama limiti) kod içinde hardcoded.
- **Çözüm önerisi:** Module-level constant olarak tanımlayın:
```python
PATCH_DELIMITER = "---\n"
SEARCH_TOKEN = "SEARCH:"
REPLACE_TOKEN = "REPLACE:"
MAX_GIT_SEARCH_DEPTH = 5
```

### 3.4 eri Bilgisi Açığı
- **Öncelik:** [DUSUK]
- **Dosya ve Satır:** patch.py:39
- **Sorun:** `f"patch: {target.name}"` commit mesajı çok kısa ve bilgi vermiyor.
- **Çözüm önerisi:** Daha açıklayıcı commit message formatı kullanın.

---

## 4. Potential Bugs (Olası Hatalar)

### 4.1 Replace Sayısı Problemi
- **Öncelik:** [YUKSEK]
- **Dosya ve Satır:** patch.py:27
- **Sorun:** `working.replace(search_text, replace_text, 1)` sadece ilk eşleşmeyi değiştiriyor. Dosyada aynı text birden fazla kez geçerse beklenmedik sonuç.
- **Çözüm önerisi:** Kullanım senaryosuna göre ya tümünü değiştirin (`replace()`) ya da kullanıcıyı uyarın.

### 4.2 .bak Dosyası Kontrolü Yok
- **Öncelik:** [ORTA]
- **Dosya ve Satır:** patch.py:24
- **Sorun:** `backup()` çağrılmadan önce hedef dosyanın yedeklenip yedeklenmediği kontrol edilmiyor. Aynı patch iki kez çalıştırılırsa orijinal dosya kaybolur.
- **Çözüm önerisi:** `.bak` varsa yedeklemeden önce mevcut orijinali koru veya uyar.

### 4.3 Blok Parsing Edge Case
- **Öncelik:** [ORTA]
- **Dosya ve Satır:** patch.py:16
- **Sorun:** `raw.split("---\n")` sadece literal newline karakteri ile ayırıyor. Windows formatlı (`\r\n`) dosyalarda sorun çıkarabilir.
- **Çözüm önerisi:** `re.split` veya `.replace("\r\n", "\n")` ile normalize edin.

### 4.4 Git Add/Commit Sırası Race Condition
- **Öncelik:** [ORTA]
- **Dosya ve Satır:** patch.py:33-39
- **Sorun:** `git add` ve `git commit` ayrı çağrılıyor. Commit sırasında başka bir process değişiklik yaparsa sorun çıkar.
- **Çözüm önerisi:** Tek atomic transaction kullanın veya commit öncesi dirty check yapın.

### 4.5 Boş Blok Filtreleme Eksikliği
- **Öncelik:** [DUSUK]
- **Dosya ve Satır:** patch.py:14-15
- **Sorun:** SEARCH/REPLACE içeren ancak boş bloklar (sadece token'lar) filtrelenmiyor.
- **Çözüm önerisi:** Boş blokları kontrol edin ve uyarı verin.

---

## 5. Performance Issues (Performans)

### 5.1 Büyük Dosyalarda read_text()
- **Öncelik:** [DUSUK]
- **Dosya ve Satır:** patch.py:18
- **Sorun:** Tüm dosya tek seferde belleğe yükleniyor. Çok büyük dosyalarda performans sorunu.
- **Çözüm önerisi:** Mevcut kullanım senaryosunda (ERP JS dosyaları) sorun yok, ancak streaming alternativa düşünülebilir.

### 5.2 subprocess Overhead
- **Öncelik:** [DUSUK]
- **Dosya ve Satır:** patch.py:33, 36, 39
- **Sorun:** Her git komutu ayrı subprocess fork ediyor. 4 ayrı subprocess çağrısı var.
- **Çözüm önerisi:** Git'in multi-command desteğini kullanın veya birleşik pipeline düşünün (ancak bu durumda gerekli değil).

---

## Özet

| Öncelik | Bulgu Sayısı |
|---------|--------------|
| KRITIK   | 0 |
| YUKSEK   | 2 |
| ORTA     | 8 |
| DUSUK    | 7 |

**En Kritik İyileştirmeler:**
1. Path traversal koruması eklenmeli
2. Replace sayısı davranışı netleştirilmeli (tek mi, tümü mü)
3. Error handling iyileştirilmeli

**Genel Değerlendirme:** Kod basit ve anlaşılır. Küçük automation scripti için yeterli. Ancak production kullanım için yukarıdaki güvenlik ve error handling iyileştirmeleri şart.
