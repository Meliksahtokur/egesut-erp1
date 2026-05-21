> ⚠️ **FUZULİ — Bu araştırma uygulanmamıştır.**
> Sadece fantezi/düşünce egzersizi olarak yapılmıştır. Uygulamayın. İleride çok boş vakit olursa denenebilir.

# EgeSüt ERP — Dashy Entegrasyon Araştırması

**Tarih:** 2026-05-21
**Araştırma Konusu:** [Lissy93/dashy](https://github.com/Lissy93/dashy) self-hosted dashboard'un EgeSüt ERP'ye entegrasyonu
**Durum:** 🔬 Araştırma tamamlandı

---

## 1. Dashy Nedir?

Dashy, **self-hosted bir dashboard / başlangıç sayfası** uygulamasıdır. Tüm servislerinizi, linklerinizi, widget'larınızı tek bir yerden görüntülemek için kullanılır.

```
╔══════════════════════════════════════════════╗
║  Dashy — Altyapı Monitörü                   ║
║                                              ║
║  ┌─────────┐ ┌─────────┐ ┌─────────┐       ║
║  │goused   │ │goused   │ │goused   │       ║
║  │Proxy    │ │API      │ │Telsiz   │       ║
║  │● Healthy│ │● Healthy│ │● Healthy│       ║
║  └─────────┘ └─────────┘ └─────────┘       ║
║  ┌─────────┐ ┌─────────┐ ┌─────────┐       ║
║  │Goose    │ │DeerFlow │ │Supabase │       ║
║  │Serve    │ │Gateway  │ │Status   │       ║
║  │● Healthy│ │● Healthy│ │● OK     │       ║
║  └─────────┘ └─────────┘ └─────────┘       ║
║                                              ║
║  ┌──── Widget: Sistem Bilgisi ────────────┐ ║
║  │ CPU: ████████░░ 78%                    │ ║
║  │ RAM: ██████░░░░ 62%                    │ ║
║  │ Uptime: 12g 34d                        │ ║
║  └─────────────────────────────────────────┘ ║
╚══════════════════════════════════════════════╝
```

---

## 2. Dashy Özellikleri

| Özellik | Açıklama | EgeSüt'te Kullanımı |
|---------|----------|---------------------|
| **Status Indicators** | Servislere HTTP health check atar, yeşil/kırmızı gösterir | Watchdog target'larının canlı durumu |
| **Widget'lar** | Saat, hava durumu, RSS, sistem metrikleri | Sunucu kaynak kullanımı, Supabase durumu |
| **Özel Sayfalar** | Birden çok sayfa oluşturma | "Altyapı", "Hızlı Linkler", "Raporlar" |
| **Authentication** | Kullanıcı girişi, read-only erişim | Yönetici paneli şifre koruması |
| **Tema Desteği** | Özel renk/log ile markalaşma | EgeSüt renkleriyle uyumlu tema |
| **YAML Konfig** | Tek dosya ile tüm yapılandırma | `conf.yml` ile kolay yönetim |
| **Arama/Kısayol** | Servisler arası hızlı arama | ERP sayfalarına hızlı erişim |

---

## 3. EgeSüt ERP'de Yeri

### Mevcut Durumdaki Boşluklar

EgeSüt ERP'nin **tools-bank** altyapısında çalışan servisler:

| Servis | Port | Watchdog ile İzleniyor | Görsel Panel |
|--------|------|------------------------|--------------|
| goused-proxy | 8742 | ✅ | ❌ |
| goused-api | 8743 | ✅ | ❌ |
| goused-telsiz | 8744 | ✅ | ❌ |
| goose-serve | 3284 | ✅ | ❌ |
| DeerFlow Gateway | ? | ❌ | ❌ |

Watchdog bu servisleri terminal'de izliyor ama **görsel bir panel yok**. Servis durumunu görmek için `ps aux | grep` veya `curl localhost:XXXX/health` gerekli.

### Dashy'nin Doldurabileceği Boşluk

```
KULLANICI İHTİYACI:
  "Servisler çalışıyor mu?" → terminal + grep → yavaş, pratik değil

DASHY İLE:
  Tarayıcı aç → dashy.local → tüm servisler yeşil/kırmızı görünür
```

---

## 4. Entegrasyon Seçenekleri

### Seçenek A: Altyapı Monitörü (Önerilen)

Dashy, tools-bank altyapısının **görsel durum paneli** olarak çalışır.

```
┌──────────────────────────────────────────────────────┐
│                    Dashy (port 4000)                   │
│                                                        │
│  ┌─── Sayfa 1: Altyapı Durumu ────────────────────┐   │
│  │                                                  │   │
│  │  🔵 goused-proxy  ──── http://localhost:8742    │   │
│  │  🔵 goused-api     ──── http://localhost:8743   │   │
│  │  🔵 goused-telsiz  ──── http://localhost:8744   │   │
│  │  🔵 goose-serve    ──── http://localhost:3284   │   │
│  │  🔵 DeerFlow       ──── (varsa)                 │   │
│  │                                                  │   │
│  │  ┌─── Widget: Sistem ───────────────────────┐   │   │
│  │  │  CPU ████░░ 42%  RAM ██████░ 58%          │   │   │
│  │  │  Disk ██░░░░ 23%  Uptime 12g              │   │   │
│  │  └───────────────────────────────────────────┘   │   │
│  └──────────────────────────────────────────────────┘   │
│                                                        │
│  ┌─── Sayfa 2: Hızlı Linkler ─────────────────────┐   │
│  │                                                  │   │
│  │  🔗 EgeSüt ERP Live     → meliksahtokur.github  │   │
│  │  🔗 Supabase Dashboard  → supabase.com/project  │   │
│  │  🔗 GitHub Repo         → github.com/...         │   │
│  │  🔗 GitHub Actions      → CI/CD durumu           │   │
│  └──────────────────────────────────────────────────┘   │
└──────────────────────────────────────────────────────┘
```

**conf.yml taslağı:**
```yaml
pageInfo:
  title: "EgeSüt ERP — Altyapı"
  description: "Tools-Bank Servis Durumu"
sections:
  - name: "Arka Uç Servisleri"
    items:
      - title: "goused-proxy"
        icon: "far fa-server"
        url: "http://localhost:8742/health"
        statusCheck: true
      - title: "goused-api"
        icon: "far fa-database"
        url: "http://localhost:8743/health"
        statusCheck: true
      - title: "goused-telsiz"
        icon: "far fa-comments"
        url: "http://localhost:8744/health"
        statusCheck: true
      - title: "goose-serve"
        icon: "far fa-robot"
        url: "http://localhost:3284/health"
        statusCheck: true
  - name: "Sistem"
    widgets:
      - type: "system-stats"
```

### Seçenek B: Yönetici Paneli (Kapsamlı)

Dashy'nin authentication özelliği ile sadece yetkili kullanıcıların görebileceği bir **yönetici paneli**:
- Servis durumları
- Sunucu metrikleri
- Supabase kullanım istatistikleri
- GitHub Actions son durum
- Watchdog log'larına hızlı erişim

### Seçenek C: Kullanılmamalı — ERP Dashboard Yerine Değil

Dashy **EgeSüt ERP'nin kendi dashboard'unun yerini alamaz**. Şu nedenlerle:

| ERP Dashboard (js/ui.js) | Dashy |
|--------------------------|-------|
| Aktif hayvan sayısı gösterir | ❌ Yapamaz |
| Gebe inek listesi gösterir | ❌ Yapamaz |
| Aşı alarmları gösterir | ❌ Yapamaz |
| Görev bildirimleri gösterir | ❌ Yapamaz |
| Stok kritik eşik uyarısı | ❌ Yapamaz |
| Supabase + IndexedDB offline-first | ❌ Yapamaz |
| Hayvan kartı açma | ❌ Yapamaz |

Dashy **ERP değildir**, sadece **servis durumu panelidir**.

---

## 5. Bize Ne Katar?

| Özellik | Değer | Açıklama |
|---------|-------|----------|
| **Görsel Servis İzleme** | 🟢 Yüksek | Watchdog terminal çıktısı yerine canlı yeşil/kırmızı panel |
| **Hızlı Erişim** | 🟢 Yüksek | Supabase, GitHub, Actions, ERP live — tek yerden link |
| **Sistem Metrikleri** | 🟡 Orta | CPU/RAM/Disk widget'ı |
| **Çoklu Sayfa** | 🟡 Orta | "Altyapı", "Raporlar", "Geliştirici" sayfaları |
| **Markalaşma** | 🟠 Düşük | EgeSüt logosu + renk teması |
| **Offline Değer** | 🔴 Yok | ERP çalışırken Dashy'nin çalışması gerekmez |

---

## 6. Bizden Ne Götürür?

| Kalem | Seviye | Detay |
|-------|--------|-------|
| **Kurulum** | 🟢 Kolay | Docker: `docker run -d -p 4000:80 lissy93/dashy` |
| **Bakım** | 🟢 Çok Az | YAML dosyası güncellemesi, yılda 1-2 Docker image update |
| **Kaynak** | 🟢 Hafif | Tek container, Node.js static site |
| **Güvenlik Riski** | 🟢 Yok | Sadece internal network, port 4000'e kimse erişmez |
| **Bağımlılık** | 🟢 Yok | Dashy düşerse ERP çalışmaya devam eder |

**Götürüsü neredeyse yok.** Hafif bir static uygulama, Docker ile 2 dakikada ayağa kalkar.

---

## 7. Karşılaştırma: agno-agi/dash vs Lissy93/dashy

| Özellik | agno-agi/dash (önceki araştırma) | Lissy93/dashy (bu araştırma) |
|---------|----------------------------------|------------------------------|
| **Tip** | Self-learning data agent (AI) | Self-hosted dashboard |
| **Kurulum** | Docker + PostgreSQL + pgvector | Docker veya Node.js |
| **LLM Gerekir** | ✅ OpenAI API | ❌ Gerekmez |
| **Maliyet** | ~$500-2000/yıl | $0 |
| **ERP Dashboard Yerine** | ❌ Geçemez | ❌ Geçemez |
| **Altyapı Monitörü** | ❌ | ✅ Mükemmel |
| **Doğal Dil Sorgulama** | ✅ | ❌ |
| **Projeye Uygunluk** | 🟡 İleriye dönük faydalı | 🟢 Hemen faydalı |

---

## 8. Karar

### Hemen yapılabilir mi?
**Evet.** Docker ile 2 dakikada kurulur. `conf.yml`'de tools-bank servislerinin health endpoint'leri tanımlanır. Watchdog ile aynı işi yapar ama görsel olarak.

### Yapılmalı mı?
**Düşük öncelikli.** Faydası var (servis durumunu görsel görmek) ama watchdog zaten terminal'de bu işi yapıyor. Öncelik sırası:

1. 🔴 Klinik frontend tamamlama (mevcut roadmap)
2. 🟡 Supabase RPC hata düzeltmeleri
3. 🟢 **Dashy kurulumu** — düşük efor, düşük risk
4. 🟢 agno-agi/dash (ilerde)

### Nasıl yapılmalı?
```
docker run -d \
  --name egesut-dashy \
  -p 4000:80 \
  -v /root/egesut-erp1/dashy-conf.yml:/app/user-data/conf.yml \
  lissy93/dashy
```

---

## Kaynaklar

- Dashy GitHub: https://github.com/Lissy93/dashy
- Dashy Demo: https://demo.dashy.to
- Dashy Dokümantasyon: https://dashy.to/docs
- Quick Start: https://github.com/Lissy93/dashy/blob/master/docs/quick-start.md
- Status Indicators: https://github.com/Lissy93/dashy#status-indicators-
- Widget'lar: https://github.com/Lissy93/dashy#widgets-
