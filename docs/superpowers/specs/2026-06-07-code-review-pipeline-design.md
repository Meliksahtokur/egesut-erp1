# EgeSüt ERP — Kapsamlı Kod Review Pipeline

**Tarih:** 2026-06-07  
**Yazar:** Claude Sonnet 4.6  
**Durum:** Onaylandı  

---

## 1. Amaç

EgeSüt ERP'nin güncel kod tabanını (Haziran 2026) dış ve iç araçlarla tam tarama yaparak:
- Güvenlik açıklarını tespit etmek
- Kalite skorunu ölçmek
- Mimari haritasını çıkarmak
- Teknik borcu listelemek
- Aksiyon planı oluşturmak

Mayıs 2026'daki `big-analiz/` çalışmasının yerini alacak, taze ve araç destekli bir analiz üretecek.

---

## 2. Kapsam Dışı

- Otomatik kod düzeltme (sadece tespit)
- CI/CD entegrasyonu
- Gito veya başka LLM review aracı (repomix+Claude bu ihtiyacı karşılıyor)

---

## 3. Araçlar

| Araç | Kategori | Kurulum | Maliyet |
|------|----------|---------|---------|
| Semgrep CE | Güvenlik | `pip install semgrep` | Ücretsiz |
| SonarCloud MCP | Kalite | Hazır (MCP bağlı) | Ücretsiz (public repo) |
| GitNexus MCP | Mimari | Hazır (indeksli) | Ücretsiz |
| Repomix + Claude | Derin Analiz | Hazır | Ücretsiz |

---

## 4. Pipeline Mimarisi

Sıralı / Katmanlı yaklaşım — her aşama bir öncekinin bulgularını bağlama alır.

```
Semgrep → SonarCloud → GitNexus → Repomix+Claude → Sentez
   ↓           ↓           ↓             ↓             ↓
 01.md       02.md       03.md         04.md         05.md
```

---

## 5. Aşama Detayları

### Aşama 1 — Semgrep Güvenlik Taraması
**Çıktı:** `research/code-review-2026-06/01-semgrep-guvenlik.md`

Taranacak dizinler: `js/`, `supabase/migrations/`  
Kural setleri:
- `p/owasp-top-ten` — injection, XSS, CSRF
- `p/javascript` — JS güvenlik best practices
- `p/secrets` — credential leak, hardcoded key

Format:
```
- Araç versiyonu + çalışma komutu
- Bulgular tablosu (dosya:satır | kural | önem | açıklama)
- Sınıflandırma: Kritik / Orta / Düşük
```

### Aşama 2 — SonarCloud Kalite Analizi
**Çıktı:** `research/code-review-2026-06/02-sonarcloud-kalite.md`

MCP araçları:
- `sonar_quality_gate` → genel geçme/kalma durumu
- `sonar_issues` → aktif issue listesi
- `sonar_hotspots` → güvenlik hotspot'ları
- `sonar_duplications` → kopya kod oranı
- `sonar_coverage` → test coverage

Bağlam notu: Semgrep'te çıkan güvenlik bulgularıyla örtüşme kontrolü yapılır.

### Aşama 3 — GitNexus Mimari Analizi
**Çıktı:** `research/code-review-2026-06/03-gitnexus-mimari.md`

Sorgular:
- `gitnexus_query` → execution flows
- `gitnexus_context` → kritik semboller
- `gitnexus_route_map` → bağımlılık grafiği

Çıktılar:
- Mermaid mimari diyagramı
- En riskli semboller (HIGH/CRITICAL blast radius)
- Execution flow haritası

Bağlam notu: Semgrep + SonarCloud'da işaretlenen riskli dosyalar için impact analizi yapılır.

### Aşama 4 — Repomix + Claude Derin Analizi
**Çıktı:** `research/code-review-2026-06/04-repomix-derin-analiz.md`

Repomix ile kod pack edilir → Claude'a 1-4 arası bulguların özeti bağlam olarak verilir → semantik review yapılır.

Odak alanları:
- Önceki araçların yakalayamadığı mantık hataları
- Domain kuralı ihlalleri (tohumlama state machine, stok ledger)
- Teknik borç önceliklendirmesi
- Refactor roadmap önerileri

### Aşama 5 — Final Sentez
**Çıktı:** `research/code-review-2026-06/05-sentez-final.md`

```
1. Proje Sağlık Skoru (0-100) — 4 araçtan gelen metriklerin ağırlıklı ortalaması
   - Güvenlik skoru (Semgrep + SonarCloud hotspots): %30
   - Kalite skoru (SonarCloud issues + coverage): %30
   - Mimari sağlık (GitNexus risk seviyesi): %20
   - Teknik borç (Repomix+Claude): %20

2. Kritik Bulgular Tablosu
   - Öncelik sırası | Kaynak araç | Dosya:satır | Önem | Durum

3. Mimari Harita — Mermaid diyagramı (Aşama 3'ten)

4. Teknik Borç Listesi — big-analiz (Mayıs 2026) ile delta karşılaştırma

5. Aksiyon Planı
   - Quick wins (1-2 saat): hemen yapılabilir
   - Orta vadeli (1-2 hafta): planlama gerektirir
   - Uzun vadeli (1+ ay): mimari karar gerektirir
```

---

## 6. Çalışma Dizini

```
research/code-review-2026-06/
├── 01-semgrep-guvenlik.md
├── 02-sonarcloud-kalite.md
├── 03-gitnexus-mimari.md
├── 04-repomix-derin-analiz.md
└── 05-sentez-final.md
```

---

## 7. Başarı Kriterleri

- Her aşama için ayrı rapor dosyası mevcut
- Her raporda bulgular tablo formatında, öncelik sıralı
- Sentezde 0-100 skor hesaplanmış
- Mermaid diyagramı render edilebilir
- Aksiyon listesi öncelik sıralı ve atanabilir görevler içeriyor
