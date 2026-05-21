# EgeSüt ERP — Dash Entegrasyon Araştırması

**Tarih:** 2026-05-21
**Araştırma Konusu:** [agno-agi/dash](https://github.com/agno-agi/dash) self-learning data agent'ının EgeSüt ERP'ye entegrasyonu
**Durum:** 🔬 Araştırma tamamlandı

---

## 1. Dash Nedir?

Dash, **self-learning bir data agent**'tır. Bir dashboard framework'ü (Plotly Dash) değildir. Agno (agno-agi) tarafından geliştirilmiş, doğal dil → SQL → bağlamsal yanıt akışını çalıştıran bir yapay zeka sistemidir.

**Temel Yetenek:**
> Kullanıcı "En çok süt veren 5 ineğim hangisi?" diye sorar → Dash PostgreSQL'e SQL sorgusu atar → sonucu yorumlayarak anlaşılır bir yanıt döndürür. Kullanıcı "Şu sütun yanlış, laktasyon sayısını da ekle" derse — Dash düzeltmeyi **öğrenir** ve bir daha aynı soruda laktasyon sayısını da getirir.

---

## 2. Altı Katmanlı Bağlam (Six Layers of Context)

Dash'in doğruluk oranını yüksek tutan temel mimari özelliği:

| Katman | Açıklama | EgeSüt'te Ne İşe Yarar |
|--------|----------|------------------------|
| **1. Instructions** | Sistem talimatları, rol tanımı | "Sen EgeSüt çiftlik asistanısın, süt verisi analisti ol" |
| **2. Schema** | DB şeması (tablo, kolon, tip, FK) | `hayvanlar`, `tohumlama`, `stok`, `cases` şemalarını otomatik tanır |
| **3. Business Rules (Knowledge)** | Domain kuralları, SQL snippet'ları | "Gebelik 280 gündür", "Kuru dönem 60 gün", "Aşı takvimi: 240-260. günler" |
| **4. Past Queries (Learnings)** | Geçmiş başarılı sorgular | "Bu ay en çok doğum yapan inek hangisi?" → benzerlerini öğrenir |
| **5. User Corrections** | Kullanıcı düzeltmeleri | "Hayır, süt verimi litre değil kg" → hafızaya alır |
| **6. Results** | Önceki sonuçların bağlamı | Aynı soruyu iki kere sorarsan farklı cevap vermez |

---

## 3. Teknik Mimari

```
Kullanıcı (Slack/Terminal/Web)
       │
       ▼
┌─────────────┐    ┌──────────────────┐    ┌─────────────┐
│  AgentOS UI  │    │  FastAPI Server  │    │  PostgreSQL │
│ (os.agno.com)│◄──►│  (port 8000)     │◄──►│  (read-only)│
└─────────────┘    │                  │    └─────────────┘
                   │  ┌────────────┐  │
Kullanıcı          │  │  Analyst   │  │  ┌─────────────────┐
  (terminal) ─────►│  │  Agent     │  │  │  Learning Store  │
                   │  │ (SQL->Text)│  │  │  (PostgreSQL)    │
                   │  └────────────┘  │  │  + pgvector      │
                   │  ┌────────────┐  │  └─────────────────┘
                   │  │  Engineer  │  │
                   │  │  Agent     │  │
                   │  │ (SQL->Exec)│  │
                   │  └────────────┘  │
                   └──────────────────┘
```

**İki Agent Rolü:**
- **Analyst**: Doğal dil → SQL sorgusu → sonucu yorumlar. Read-only bağlanır (`default_transaction_read_only=on`)
- **Engineer**: Write işlemleri için, sadece `dash` schema'sına yazabilir. `public` schema'sına yazamaz

---

## 4. Entegrasyon Seçenekleri

### Seçenek A: Sidecar Service (Önerilen)

```
┌─────────────────────────────────────────┐
│  EgeSüt ERP (GitHub Pages)               │
│  ┌──────────┐  ┌──────────┐  ┌────────┐ │
│  │ Vanilla  │  │ Sürü Kartı│  │ Stok   │ │
│  │ Dashboard│  │          │  │ Paneli │ │
│  └──────────┘  └──────────┘  └────────┘ │
│         ▲                                │
│         │ fetch(/ask?q=...)              │
│         ▼                                │
│  ┌──────────────────┐                   │
│  │  Dash API Proxy  │ (opsiyonel)       │
│  └──────┬───────────┘                   │
└─────────┼───────────────────────────────┘
          │
          ▼
  ┌──────────────┐       ┌──────────────────┐
  │  Dash Server  │◄─────►│ Supabase (Read)  │
  │  (FastAPI)    │       └──────────────────┘
  │  port 8000    │       ┌──────────────────┐
  │               │◄─────►│ Learning Store   │
  │               │       │ (pgvector)       │
  └──────────────┘       └──────────────────┘
```

### Seçenek B: Terminal/Slack Entegrasyonu

Dash'in doğal arayüzü (Slack, terminal) ile kullanım. Çiftlik sahibi Slack'ten sorar, Dash Supabase'den veriyi çeker, yanıtlar.

### Seçenek C: Minimal — Sadece RAG Sorgu

Dash'in sadece "ask" endpoint'ini kullanma. Var olan UI'a bir "Yapay Zekaya Sor" input'u ekleme.

---

## 5. Bize Ne Katar? (Avantajlar)

| Özellik | Değer | Açıklama |
|---------|-------|----------|
| **Doğal Dil Sorgulama** | 🟢 Yüksek | "Bu ay kaç buzağı öldü?", "En pahalı 5 ilaç hangisi?" gibi sorulara anında yanıt |
| **Self-Learning** | 🟢 Yüksek | Kullanıcı düzeltmelerini öğrenir, her sorguda iyileşir |
| **6 Katmanlı Doğruluk** | 🟢 Yüksek | Sadece SQL sonucu değil, yorumlu, bağlamsal yanıtlar |
| **Tahminsel Analitik** | 🟡 Orta | "Hangi inekler risk altında?" gibi öngörüler |
| **Veri Keşfi** | 🟢 Yüksek | Dashboard'da görünmeyen korelasyonları bulur |
| **Stok Uyarıları** | 🟡 Orta | "Kritik eşiğe yaklaşan stoklar" gibi proaktif uyarılar |
| **Eğitim/İnsight** | 🟡 Orta | Yeni çalışanların veriyle konuşarak öğrenmesi |
| **Offline Destek** | 🔴 Yok | LLM API'si gerektirir, internet bağımlı |

---

## 6. Bizden Ne Götürür? (Maliyetler)

| Kalem | Seviye | Detay |
|-------|--------|-------|
| **LLM API Maliyeti** | 🔴 Yıllık ~$500-2000 | Her sorgu OpenAI API çağrısı yapar. Sık kullanımda maliyet artar |
| **Ek Servis** | 🟡 Altyapı | PostgreSQL, pgvector, Docker, FastAPI — yeni bir servis ayağa kaldırmak gerekir |
| **Bakım Yükü** | 🟡 Orta | Dash güncellemeleri, veritabanı şeması değişince knowledge'ı güncellemek |
| **Gecikme** | 🟡 3-10sn | LLM çağrısı + SQL çalıştırma = sorgu başına birkaç saniye |
| **Supabase Yedeklilik** | 🟡 Dikkat | Supabase'den veri çekmek için yeni bağlantı/izin gerekir |
| **Güvenlik** | 🟡 Dikkat | Read-only bağlantıyla sınırlanmalı, asla write yetkisi verilmemeli |
| **Bağımlılık** | 🟠 Düşük | Dash durursa ana ERP çalışmaya devam eder (sadece yapay zeka sorguları gider) |
| **Öğrenme Eğrisi** | 🟠 Düşük | Çalışanların "veriye soru sorma" alışkanlığı kazanması zaman alır |

---

## 7. EgeSüt ERP'ye Özel Risk Analizi

### Veri Güvenliği
- Supabase'e read-only bağlantı → yanlışlıkla veri silme/değiştirme riski yok
- LLM (OpenAI) API'si → üretim verisi OpenAI'e gider. Hassas veri (hayvan sağlık kaydı, stok bilgisi) üçüncü taraf sunucuya iletilir
- **Türkiye'de KVKK açısından** — hayvan verileri kişisel veri değildir, ancak çiftlik sahibinin ticari bilgisi OpenAI'e gitmiş olur

### Veritabanı Şeması Uyumu
EgeSüt 20 tablo + 10+ view + 50+ RPC içeriyor. Dash'in schema layer'ı bunları otomatik tarayabilir. Ancak:
- **EgeSüt'te hesaplamalar frontend'de yapılıyor** (gün farkı, laktasyon durumu, kritik eşik). Dash DB'den ham veri çeker, iş mantığını bilemez
- **Trigger/RPC'ler** — Dash sadece tabloları görür, RPC'leri çağırmaz
- **Özel Domain Knowledge** eklenmesi gerekir: gebelik süresi 280 gün, kuru dönem 60 gün, aşı takvimi timeline'ı

### Mevcut Stack ile Uyum
| Stack Bileşeni | Dash ile Uyum | Not |
|----------------|---------------|-----|
| Supabase (PostgreSQL) | ✅ Mükemmel | Dash'in native DB'si PostgreSQL |
| GitHub Pages (Frontend) | ⚠️ Proxy gerek | Dash ayrı portta (8000), frontend'den CORS/proxy ile çağrılmalı |
| Vanilla JS | 🟡 Mümkün | `fetch("/dash/ask?q=...")` ile basit entegrasyon |
| IndexedDB (offline) | 🔴 Yok | Dash online LLM API'sine bağımlı |
| DeerFlow | ✅ | Dash DeerFlow'a agent olarak eklenebilir |

---

## 8. Implementasyon Önerisi (Eğer Karar Verilirse)

### Aşama 1 — Temel Kurulum (2-3 gün)
1. Dash repo'sunu forkla/clone
2. Supabase connection string'ini `.env`'e ekle
3. EgeSüt DB şemasını `scripts/` ile yükle
4. Domain knowledge'ı (gebelik, aşı, laktasyon kuralları) business rules olarak tanımla
5. Docker Compose ile ayağa kaldır

### Aşama 2 — UI Entegrasyonu (1-2 gün)
1. `index.html`'ye "Yapay Zekaya Sor" input'u + modal
2. Dash API proxy (CORS için `/dash/*` → `localhost:8000`)
3. Yanıt formatını ERP'nin mevcut toast/modal sistemine uygun hale getir

### Aşama 3 — İyileştirme (sürekli)
1. Kullanıcı feedback loop'u (beğen/beğenme butonları)
2. Sık sorulan soruları cache'le
3. Raporlama template'leri (haftalık sağlık raporu, stok özeti)

---

## 9. Alternatifler

| Çözüm | Tip | LLM Gerekir mi? | Self-Learning | Kurulum |
|-------|-----|-----------------|---------------|---------|
| **Dash (agno-agi)** | Self-learning data agent | ✅ OpenAI | ✅ | Orta (Docker) |
| Plotly Dash | Dashboard framework | ❌ | ❌ | Kolay (pip) |
| LangChain SQL Agent | Text-to-SQL | ✅ Herhangi | ❌ (manual) | Orta |
| Supabase Edge Functions | Serverless SQL | ❌ | ❌ | Kolay |
| Mevcut Vanilla JS Dashboard | Manuel | ❌ | ❌ | Hazır |

---

## 10. Karar: EVET, entegre edilebilir. Ne zaman?

### Hemen entegre edilebilir mi?
**Evet.** Dash'in Docker Compose kurulumu + Supabase connection string ile 1 saatte ayağa kalkar. Domain knowledge tanımlaması 1-2 gün sürer.

### Değer mi?
- **Kısa vadede** ($500/yıl LLM + Docker sunucu): Yüksek değer. Çiftlik sahibi "şu inek neden hasta?" sorusuna anında yanıt alır.
- **Uzun vadede** (self-learning birikir): Değer katlanarak artar. Her düzeltme sistemi iyileştirir.
- **Riskler yönetilebilir**: Read-only bağlantı + KVKK uyumu (hayvan verisi kişisel veri değildir) + ana ERP bağımsız çalışır.

### Ne zaman entegre edilmeli?
- **Klinik frontend tamamlandıktan sonra** (mevcut roadmap'deki en büyük boşluk)
- **Supabase'den read-only token alınabildiğinde** (mevcut anon key yeterli olmayabilir)
- **OpenAI API bütçesi ayrıldığında** ($500-2000/yıl)

---

## Kaynaklar

- Dash GitHub: https://github.com/agno-agi/dash
- Dash Documentation: https://docs.agno.com/tutorials/dash/overview
- Six Layers of Context: https://docs.agno.com/tutorials/dash/six-layers-of-context
- Self-Learning Loop: https://docs.agno.com/tutorials/dash/self-learning-loop
- Agno (Framework) GitHub: https://github.com/agno-agi/agno
- AgentOS: https://os.agno.com
