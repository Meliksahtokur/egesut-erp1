# 🛠️ Fullstack Agent Geliştirme İhtiyaçları

## 📋 Mevcut Durum Analizi

### Çalıştığım Branch
- ✅ `gwen/dev` (ana development)
- ✅ `gwen/task-*` (task branch'leri)

### Mevcut Yetenekler
- EgeSüt ERP domain kuralları (tohumlama, doğum, hayvan yönetimi)
- Vanilla JS, Supabase, IndexedDB pattern'leri
- RPC tabanlı database işlemleri
- Türkçe toast/error mesajları

---

## 🎯 İyileştirme Önerileri

### 1. **Özel MCP Server'lar (En Kritik)**

#### a) `gwen-ege-erp` MCP Server
```
Amaç: EgeSüt ERP domain işlemlerini soyutlamak

Fonksiyonlar:
- `hayvan_getir(kupe_no)` → Hayvan bilgisi + grup + padok
- `tohumlama_yap(hayvan_id, tarih, sperma_bilgisi)` → RPC çağırır, validasyon yapar
- `dogum_kaydet(anne_id, buzağı_bilgisi)` → Tüm RPC zincirini yönetir
- `grup_hesapla(yas, cinsiyet)` → Otomatik grup önerisi
- `padok_degistir(hayvan_id, yeni_padok)` → Trigger'ları otomatik tetikler

Avantaj:
- Her task'ta RPC imzası ezberlemeye gerek kalmaz
- Domain kuralları MCP seviyesinde enforce edilir
- Hata mesajları Türkçe ve domain-specific olur
```

#### b) `gwen-db-inspector` MCP Server
```
Amaç: Database şemasını ve RPC'leri keşfetmek

Fonksiyonlar:
- `tablo_semasi(tablo_adi)` → Kolonlar, tipler, constraint'ler
- `rpc_listesi()` → Tüm RPC fonksiyonları + parametreleri
- `trigger_zinciri(tablo)` → Hangi trigger'lar hangi işlemleri tetikler
- `ormezleme_kontrol(hayvan_id)` → Hayvanın tüm ilişkili kayıtları

Avantaj:
- .claude/rpc-reference.md okumaya gerek kalmaz
- Her task öncesi manuel şema kontrolü gerekmez
- Trigger zincirleri otomatik gösterilir
```

#### c) `gwen-ui-tester` MCP Server
```
Amaç: UI değişikliklerini otomatik test etmek

Fonksiyonlar:
- `sayfa_yukle(url)` → Headless browser başlat
- `form_doldur(selector, veri)` → Form alanlarını doldur
- `button_tikla(selector)` → Buton tıkla + toast mesajını bekle
- `console_hatalari()` → F12 console loglarını çek
- `snapshot_karsilastir(before, after)` → UI regression testi

Avantaj:
- "UI değişikliklerini test et" kuralı otomatik enforce edilir
- Manuel tarayıcı açmaya gerek kalmaz
- Regression testleri otomatik çalışır
```

---

### 2. **Özel Agent Tipleri**

#### a) `gwen-erp-domain` Agent
```
Uzmanlık: Sadece EgeSüt ERP domain kuralları

Yetenekler:
- Hayvan gruplarını otomatik hesaplar (yaş + cinsiyet → grup)
- Tohumlama ön koşullarını kontrol eder (yaş ≥ 12 ay, dişi, aktif)
- Doğum sonrası görev zincirini bilir (7 ilaç + 6 bakım görevi)
- Padok atama kurallarını uygular

Kullanım:
- Complex domain logic gerektiren task'larda otomatik spawn edilir
- Fullstack agent domain kurallarını bu agent'tan öğrenir
```

#### b) `gwen-rpc-expert` Agent
```
Uzmanlık: Sadece Supabase RPC işlemleri

Yetenekler:
- Tüm RPC imzalarını ezbere bilir
- RPC wrapper kodunu otomatik üretir
- Transaction integrity kontrolü yapar
- Rollback senaryolarını yönetir

Kullanım:
- Her RPC çağrısı öncesi otomatik doğrulama
- "Direkt REST bypass" hatasını önler
```

#### c) `gwen-code-reviewer` Agent
```
Uzmanlık: Fullstack kod incelemesi

Yetenekler:
- Duplikat fonksiyon tespiti (grep + AST analizi)
- Türkçe mesaj kontrolü (toast, error, alert)
- RPC bypass tespiti (supabase.from → yasak!)
- State machine ihlali kontrolü

Kullanım:
- Her commit öncesi otomatik çalışır
- PR açıklamasını otomatik doldurur
```

---

### 3. **CLI Araçları**

#### a) `gwen-task` Komutu
```bash
# Yeni task branch'i oluştur + context hazırla
gwen task "Tohumlama formuna tarih validasyonu ekle"

Otomatik:
1. gwen/task-tohumlama-tarih branch'i oluştur
2. İlgili dosyaları tespit et (js/forms.js, js/ui.js)
3. .claude/domain-rules.md → Tohumlama bölümünü yükle
4. .claude/rpc-reference.md → tohumlama_kaydet RPC'sini yükle
5. Fullstack agent'ı spawn et + context'i aktar
```

#### b) `gwen-test` Komutu
```bash
# UI testlerini çalıştır
gwen test tohumlama-form

Otomatik:
1. Headless browser başlat
2. Tohumlama formunu aç
3. Geçersiz tarih gir → toast mesajını kontrol et
4. Console'da hata var mı kontrol et
5. HTML snapshot al → regression testi yap
```

#### c) `gwen-rpc` Komutu
```bash
# RPC çağrılarını test et
gwen rpc tohumlama_kaydet --hayvan_id=123 --tarih=2024-04-01

Otomatik:
1. RPC imzasını doğrula
2. Parametreleri validate et
3. Supabase'e gönder
4. Sonucu göster (başarılı/hata)
5. Trigger zincirini açıkla (hangi tablolar değişti)
```

---

### 4. **Context Yönetimi İyileştirmeleri**

#### a) Otomatik Context Loading
```
Problem: Her task öncesi .claude/*.md dosyalarını manuel okuyorum

Çözüm:
- Task açıklamasından domain'i tespit et (tohumlama → domain-rules.md)
- İlgili bölümü otomatik yükle
- Gereksiz context'i yükleme (sadece ilgili kurallar)
```

#### b) Context Caching
```
Problem: Aynı RPC imzalarını tekrar tekrar okuyorum

Çözüm:
- RPC imzalarını IndexedDB'ye cache'le
- Şema değişikliklerini otomatik tespit et (cache invalidation)
- "Bu RPC 3 gün önce değişti" uyarısı ver
```

#### c) Cross-Reference Linking
```
Problem: Domain kuralları ile RPC'ler arasında bağ yok

Çözüm:
- domain-rules.md'de "Tohumlama → rpc:tohumlama_kaydet" linki
- rpc-reference.md'de "Kullanıldığı yerler: js/forms.js:234" linki
- Tıklayınca ilgili dosyaya git
```

---

### 5. **Debugging Araçları**

#### a) `gwen-trace` Komutu
```bash
# İşlem zincirini izle
gwen trace dogum_kaydet --anne_id=123

Otomatik:
1. RPC çağrısını yakala
2. Buzağı eklendi mi? ✅
3. Anne tohumlama kapatıldı mı? ✅
4. İlaç görevleri oluştu mu? ✅ (7 görev)
5. Bakım görevleri oluştu mu? ✅ (6 görev)
6. Trigger zincirini göster
```

#### b) `gwen-logs` Komutu
```bash
# Son işlemleri listele
gwen logs --table=tohumlama --limit=10

Otomatik:
1. islem_log tablosunu sorgula
2. Son 10 tohumlama işlemini göster
3. Hangi RPC çağrıldı?
4. Hangi trigger'lar çalıştı?
5. Hata var mı?
```

---

### 6. **Code Generation İyileştirmeleri**

#### a) RPC Wrapper Generator
```bash
gwen generate rpc-wrapper tohumlama_kaydet

Output (js/api.js):
/**
 * Tohumlama kaydı oluştur
 * Domain kuralları:
 * - Hayvan dişi olmalı
 * - Yaş ≥ 12 ay (365 gün)
 * - Gebelik yok
 */
async function tohumlamaKaydet(hayvanId, tarih) {
  // Validasyon
  if (new Date(tarih) > new Date()) {
    showToast('Tohumlama tarihi ileri olamaz!', 'error');
    return;
  }
  
  const { data, error } = await supabase.rpc('tohumlama_kaydet', {
    p_hayvan_id: hayvanId,
    p_tarih: tarih
  });
  
  if (error) {
    showToast('Tohumlama kaydı başarısız: ' + error.message, 'error');
    return null;
  }
  
  showToast('Tohumlama kaydı başarılı!', 'success');
  return data;
}
```

#### b) Form Validator Generator
```bash
gwen generate validator tohumlama-form

Output (js/validators.js):
const tohumlamaValidator = {
  tarih: (value) => {
    if (new Date(value) > new Date()) {
      return 'Tohumlama tarihi ileri olamaz';
    }
    return null;
  },
  hayvan: (hayvan) => {
    if (hayvan.cinsiyet !== 'Dişi') {
      return 'Sadece dişi hayvanlar tohumlanır';
    }
    if (hayvan.yas < 365) {
      return 'Hayvan çok genç (< 12 ay)';
    }
    return null;
  }
};
```

---

## 📊 Öncelik Sıralaması

### P0 (Kritik - Hemen Gerekli)
1. `gwen-ege-erp` MCP Server → Domain işlemlerini soyutlar
2. `gwen-db-inspector` MCP Server → Şema/RPC keşfi otomatikleştirir
3. `gwen-task` CLI → Context loading otomatikleştirir

### P1 (Yüksek Öncelikli)
4. `gwen-rpc-expert` Agent → RPC bypass hatalarını önler
5. `gwen-code-reviewer` Agent → Commit öncesi otomatik review
6. `gwen-trace` CLI → Debugging'i kolaylaştırır

### P2 (Orta Öncelikli)
7. `gwen-ui-tester` MCP Server → UI testlerini otomatikleştirir
8. `gwen-erp-domain` Agent → Domain kurallarını enforce eder
9. Context caching → Tekrarları önler

### P3 (Düşük Öncelikli)
10. `gwen-rpc` CLI → RPC testlerini kolaylaştırır
11. `gwen-logs` CLI → Log incelemesini kolaylaştırır
12. Code generation → Boilerplate kodu azaltır

---

## 🎯 Beklenen Verimlilik Artışı

| Alan | Mevcut | Hedef | Artış |
|------|--------|-------|-------|
| Task başlangıç süresi | 5-10 dk context okuma | 30 sn | **10x** |
| RPC hatası | Task başına 1-2 | 0 | **%100 azalma** |
| UI test süresi | 5 dk manuel | 30 sn otomatik | **10x** |
| Debugging süresi | 15-20 dk | 2-3 dk | **5x** |
| Code review | 10 dk manuel | 1 dk otomatik | **10x** |

**Toplam Verimlilik Artışı: ~5-8x**

---

## 💡 Sonuç

**En kritik ihtiyaç:** MCP Server'lar

Neden?
- Fullstack agent her task'ta aynı RPC imzalarını okuyor
- Domain kuralları her seferinde manuel kontrol ediliyor
- Trigger zincirleri bilinmediği için hata yapılıyor

**İlk adım:** `gwen-ege-erp` MCP Server + `gwen-db-inspector` MCP Server

Bu iki MCP server fullstack agent'ın:
- RPC bypass hatasını %100 azaltır
- Domain kural ihlalini %90 azaltır
- Task başlangıç süresini 10x hızlandırır

---

**AR-GE'den İstek:**
1. MCP Server geliştirme önceliklerini onayla
2. Agent tiplerini oluştur
3. CLI araçlarını implement et
4. Context yönetimini iyileştir

📅 **Hedef:** 2 hafta içinde P0 ve P1 öğelerini tamamlamak
