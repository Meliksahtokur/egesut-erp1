> ⚠️ **FUZULİ — Bu araştırma uygulanmamıştır.**
> Sadece fantezi/düşünce egzersizi olarak yapılmıştır. Uygulamayın. İleride çok boş vakit olursa denenebilir.

# Dashy Nedir ve EgeSüt ERP'de Nasıl Kullanılır?

**Tarih:** 2026-05-21
**Proje:** EgeSüt ERP (egesut-erp1)
**Araç:** [Lissy93/dashy](https://github.com/Lissy93/dashy) — Self-hosted Dashboard

---

## 1. Dashy Basitçe Nedir?

Dashy, **kendi sunucunda çalışan bir başlangıç sayfasıdır.**

Şu anki durumda, projedeki servislerin durumunu görmek için terminal açıp `ps aux | grep` veya `curl localhost:XXXX/health` yazman gerekiyor. Dashy bunu görsel bir panele dönüştürür:

```
Terminal'de şu an:
  $ curl -s http://localhost:8743/health
  ok
  $ curl -s http://localhost:3284/health
  ok
  $ ps aux | grep goose
  ... (uzun çıktı)

Dashy ile:
  ┌──────────────────────────────────┐
  │  goused-proxy  ● Healthy  :8742  │
  │  goused-api    ● Healthy  :8743  │
  │  goused-telsiz ● Healthy  :8744  │
  │  goose-serve   ● Healthy  :3284  │
  └──────────────────────────────────┘
```

Her servis için bir kutu, yanında yeşil/kırmızı canlı durum göstergesi. Tarayıcıda açık kalır, otomatik yenilenir.

---

## 2. Dashy Ne YAPABİLİR?

### ✅ Yapabildikleri

| Özellik | Nasıl Çalışır | EgeSüt'te Kullanımı |
|---------|--------------|---------------------|
| **Link + Status** | Bir URL verirsin, Dashy periyodik GET atar. 200 dönerse yeşil, dönmezse kırmızı | tools-bank servislerinin sağlık kontrolü |
| **Widget'lar** | Saat, takvim, sistem istatistikleri, RSS, weather | Sunucu CPU/RAM/Disk metrikleri |
| **Arama** | Tüm linklerde ve sayfalarda anlık arama | Hızlı servis bulma |
| **Çoklu Sayfa** | YAML'da birden çok sayfa tanımlama | "Altyapı", "Raporlar", "Linkler" sayfaları |
| **Tema** | Renk, logo, duvar kağıdı değiştirme | EgeSüt marka renkleriyle özelleştirme |
| **Auth** | Kullanıcı adı/şifre ile koruma | Paneli yetkisiz erişime kapatma |
| **Workspaces** | Alt grup ve bölümler oluşturma | "Backend Servisleri", "Frontend", "CI/CD" grupları |

### ❌ YAPAMADIKLARI

| Yapamaz | Neden |
|---------|-------|
| **ERP Dashboard'unun yerini alamaz** | Aktif hayvan sayısı, gebe listesi, aşı alarmları, görev bildirimleri, stok uyarıları — bunların hiçbirini gösteremez. ERP verisine erişimi yok |
| **Supabase'e SQL atamaz** | Dashy sadece HTTP GET istekleri atar, PostgreSQL'e bağlanmaz |
| **Veri yazamaz/güncelleyemez** | ERP'ye müdahale edemez, sadece link gösterir |
| **IndexedDB ile çalışmaz** | Offline-first mimariyi desteklemez |

---

## 3. EgeSüt ERP'de Somut Kullanım

### 3.1 Mevcut Durum

Projede şu an çalışan arka uç servisleri:

```
Servis                Port    Watchdog    Görsel Panel
─────────────────────────────────────────────────────
goused-proxy          8742    ✅ izliyor    ❌ yok
goused-api            8743    ✅ izliyor    ❌ yok
goused-telsiz         8744    ✅ izliyor    ❌ yok
goose-serve           3284    ✅ izliyor    ❌ yok
EgeSüt ERP (live)     443     ❌           ✅ var (kendi dashboard'u)
Supabase Dashboard    -       ❌           ❌
GitHub Repo           -       ❌           ❌
GitHub Actions        -       ❌           ❌
```

Watchdog terminal'de `[api] healthy`, `[goose-serve] unhealthy` diye log yazar ama bir **görsel gösterge** yoktur. Bir servis çöktüğünde anlamak için:
1. Terminal log'larını okumak
2. Veya `ps aux | grep` yapmak
3. Veya `curl` atmak gerekir

### 3.2 Dashy ile Olacak Durum

Dashy şu adrese kurulur: **http://localhost:4000**

**Sayfa 1 — Altyapı Durumu:**
```
┌────────────────────────────────────────────────────────┐
│  EgeSüt ERP — Altyapı Monitörü                         │
│                                                        │
│  ┌─────────────────┐  ┌─────────────────┐             │
│  │ goused-proxy    │  │ goused-api      │             │
│  │ ● Çalışıyor     │  │ ● Çalışıyor     │             │
│  │ :8742           │  │ :8743           │             │
│  └─────────────────┘  └─────────────────┘             │
│  ┌─────────────────┐  ┌─────────────────┐             │
│  │ goused-telsiz   │  │ goose-serve     │             │
│  │ ● Çalışıyor     │  │ ● Çalışıyor     │             │
│  │ :8744           │  │ :3284           │             │
│  └─────────────────┘  └─────────────────┘             │
│                                                        │
│  ┌────── Sistem Widget'ı ──────────────────────────┐  │
│  │  CPU  ████████░░ 78%   RAM  ██████░░░░ 62%      │  │
│  │  Disk ██░░░░░░░░ 23%   Uptime 12g 34d           │  │
│  └──────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────┘
```

**Sayfa 2 — Hızlı Linkler:**
```
┌────────────────────────────────────────────────────────┐
│  EgeSüt ERP — Hızlı Erişim                             │
│                                                        │
│  🔗 EgeSüt ERP Live  → meliksahtokur.github.io        │
│  🔗 Supabase Dashboard → supabase.com/project/xxx     │
│  🔗 GitHub Repo        → github.com/Meliksahtokur/... │
│  🔗 GitHub Actions     → CI/CD pipeline durumu        │
│  🔗 Playwright Reports → test sonuçları               │
│  🔗 DeerFlow Gateway   → deerflow durumu              │
└────────────────────────────────────────────────────────┘
```

### 3.3 Kimin İşine Yarar?

| Rol | Nasıl Kullanır |
|-----|---------------|
| **Geliştirici (sen)** | "Servisler çalışıyor mu?" diye bakmak için tarayıcıyı açar. Watchdog log'larını okumaktan hızlı |
| **Sistem Yöneticisi** | Projeyi devralan veya sunucuda değişiklik yapan kişi, tüm servisleri tek yerden görür |
| **Proje Sahibi** | Teknik bilmeyen kişiye "sistemin durumu" sorulduğunda gösterilecek bir panel |

---

## 4. Çalışma Şekli (Teknik)

```
Tarayıcı (http://localhost:4000)
       │
       ▼
┌─────────────────┐
│    Dashy         │  Node.js uygulama, statik dosya sunar
│  (port 4000)     │
└────────┬────────┘
         │
         ├── conf.yml okur → hangi servisler listelenecek
         │
         ├── Her servise 30sn'de bir GET atar (arka planda)
         │   ├─ http://localhost:8742/health → 200 → 🟢
         │   ├─ http://localhost:8743/health → 200 → 🟢
         │   ├─ http://localhost:3284/health → 200 → 🟢
         │   └─ http://localhost:8744/health → timeout → 🔴
         │
         └── Tarayıcıya durumu JSON olarak iletir
```

**Bağımlılık yok:** Dashy çökerse ERP çalışmaya devam eder. ERP Dashboard ile ilgisi yoktur.

---

## 5. Özet Karar

```
Dashy, EgeSüt ERP'nin arka uç altyapısı için bir "servis durumu panosudur."
───────────────────────────────────────────────────────────────

✅ Artıları:
  • Kurulumu 2 dakika (docker run)
  • İşletme maliyeti $0
  • Bakım gerektirmez (yılda 1-2 image update)
  • Çökerse ERP etkilenmez
  • Görsel olarak terminal'den iyi

❌ Eksileri:
  • ERP için hayati bir araç değil, "güzel-ama-gereksiz" kategorisinde
  • Watchdog zaten aynı işi terminal'de yapıyor (ama görsel değil)
  • Sadece link + status check, başka bir işlevi yok

📋 Ne Zaman Yapılmalı?
  • Klinik frontend tamamlandıktan sonra
  • Boş zaman aktivitesi olarak
  • "Şu an acil değil, yapılırsa iyi olur" seviyesinde
```
