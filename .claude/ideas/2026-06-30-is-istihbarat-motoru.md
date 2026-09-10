# İş İstihbarat Motoru — Türkiye Yazılım İşleri Konsolidasyonu

**Tarih:** 2026-06-30
**Durum:** Fikir — Brainstorm aşaması, implemente edilmedi. **Ar-Ge fazı Arch kurulumu SONRASINA ertelendi (acele yok).**
**Öncelik:** Düşük (zamanlama) / Yüksek (potansiyel değer) — kişisel araç, ileride ürünleşebilir
**Tahmini efor:** Belirsiz — önce fizibilite spike, sonra fazlı. MVP ~1 hafta sonu, production çok daha fazla.
**Hedef ortam:** **PC (tam tarayıcı destekli)** — PRoot/Termux kısıtlı motor DEĞİL. Chromium/Playwright serbest.
**İlişkili:** [[project-budget-build-research-skill]] (motorun %70-80'i buradan geliyor)
**Ek doküman:** `2026-07-02-is-istihbarat-motoru-extraction-mimarisi.md` — ilan → yapılandırılmış veri dönüşümü "nasıl": arama motoru ilhamı (schema.org/extruct, trafilatura, Duckling) + kademeli (cascade) extraction mimarisi (LLM'i en sona koy).

---

## Vizyon (tek cümle)

Türkiye'deki yazılım işlerini (freelance siteleri + köklü forumlar) **gerçek zamanlı tespit eden, sınıflandıran, detaylarını yapılandırılmış olarak çıkaran ve bir DB'ye yazıp UI'da sunan** bir veri-konsolidasyon motoru. Motor, kullanıcı adına sitelere girer, veriyi toplar, normalize eder, tekilleştirir ve dashboard'a post eder.

### Somut çıktı örneği (kullanıcının tarif ettiği kart)

```
Kaynak: armut.com
Başlık: Login tasarımı
Bütçe: 30.000 TL   |   Süre: 1 hafta
Dil: Python        |   Framework: yok
Ödeme modeli: milestone (15k iş başı / 15k teslim)
Detay: Standart login ekranı, basic seviye protection
Seviye: Basic
Link: <ilan-url>
Çekilme zamanı: 2026-06-30 16:25   |   Confidence: VERIFIED
```

---

## 1. Neden sıfırdan yazmıyoruz — motorun %70-80'i zaten elimizde

`budget-build-research` skill'i tam da bu zinciri yapıyor; sadece "ürün" yerine "iş ilanı" koy:

| budget-build bileşeni | iş-motoru karşılığı |
|---|---|
| Fetch ladder (curl_cffi→primp→Jina) + Cloudflare bypass | Armut/Bionluk/R10 erişimi (PC'de tarayıcı ile daha da güçlü) |
| `budget_extract` (JSON-LD/pgList → yapılandırılmış veri) | ilan sayfası → {başlık, bütçe, süre, dil, framework, link} |
| 3-tier confidence (VERIFIED/PARTIAL/UNVERIFIED) | "ilan gerçek mi / scam mı / lowball mı" sinyali |
| distinct_sellers dedup | aynı iş 3 siteye atılmış → tek kayıt |
| outlier + thin-market guard | dampingci / sahte bütçe tespiti |
| `category_schemas.json` agent-settable taksonomi | iş tipi / stack / seviye taksonomisi |
| research/ klasörüne dokümantasyon | aynı desen, iş ilanları için |

**Sonuç:** "Başka iş için tasarlanmış aracın motorunu kendi emellerimiz için kullanabilir miyiz?" → Evet, hem de **kendi aracımız**. En güçlü kart bu.

---

## 2. Hâlihazırda var olan araçlar (tekerleği yeniden icat etme)

**İş-scraping kütüphaneleri:**
- **JobSpy** (Python) — Indeed/LinkedIn/Glassdoor çeker, yapılandırılmış döner. **Türkiye kaynakları YOK** → mimari referans, doğrudan kullanışsız.
- **Crawl4AI / Firecrawl** — LLM'e hazır markdown çıkaran scraper. "Detayları çek" motoru. Crawl4AI self-host bedava.

**Gerçek-zamanlı tetik:**
- **changedetection.io** — sayfa değişimini izler+haber verir. "Yeni iş açıldı" tetiğini hazır verir. Self-host.
- **n8n / Huginn** — RSS + scrape + filtre + bildirim workflow. **R10.net forumlarının RSS'i var** → login'siz yeni başlık yakalama.

**Tarayıcı otomasyon (PC production çekirdeği):**
- **Playwright** — multi-browser, `storage_state` oturum kalıcılığı, en olgun.
- **Camoufox / undetected-chromedriver / patchright** — anti-bot / stealth / fingerprint sertleştirme.
- **Crawlee (Apify)** — session pool + proxy rotasyon + fingerprint + retry hazır framework.
- **browser-use / Stagehand / Skyvern** — LLM-sürücülü tarayıcı ajanları. "Bu sayfadaki ilanın bütçe/süre/stack'ini çıkar" → LLM tarayıcıyı sürer + JSON döner. **Extraction katmanını neredeyse hazır verir.**

---

## 3. DB gerekli mi? Kesinlikle evet — 4 sebep

Bu tek seferlik scrape değil, **canlı bir veri ürünü**:

1. **Dedup** — aynı iş Bionluk + R10 + Armut'a atılır. content-hash + semantik benzerlik (pgvector) → tek kayıt.
2. **Değişiklik takibi** — "30k → 25k düştü", "ilan kapandı", "teklif arttı". Sadece DB ile diff.
3. **Piyasa trendi** — "Python login işi ortalama kaç TL/gün?" → motorun GERÇEK değeri burada (tek ilan değil, **fiyat istihbaratı**).
4. **Full-text + filtreli arama / dashboard** — "son 7 gün, Python, >20k, framework-free".

**Öneri: Supabase (Postgres)** — zaten kullanılıyor, pgvector kurulu, RLS biliniyor, Auth (Katman A) hazır geliyor. MVP'de SQLite olur ama trend/dashboard isteyince Postgres; baştan Supabase mantıklı.

### Taslak şema

```sql
jobs(
  id, source, source_job_id, url, title, raw_text,
  budget_min, budget_max, currency, payment_model,   -- fixed/milestone/hourly
  duration_days, language, framework, stack[],         -- python, django, none...
  job_type,                                            -- web/mobil/data/devops/ai/bot/scraping
  complexity, seniority,                               -- basic/orta/ileri
  posted_at, scraped_at, status,                       -- open/closed/expired
  content_hash, embedding vector(1024),                -- dedup
  confidence                                           -- VERIFIED/PARTIAL (scam/lowball guard)
)
job_price_history(job_id, observed_at, budget, status) -- diff takibi
sources(name, base_url, fetch_strategy, robots_ok, last_run, session_state_path)
```

---

## 4. Türkiye kaynakları + her birinin erişim zorluğu

| Kaynak | Tip | Zorluk |
|---|---|---|
| **R10.net** | Forum (iş ilanları) | ⭐ En kolay — **RSS var**, login'siz başlık. İletişim için login gerekebilir. Köklü, kaliteli iş çok. |
| **Bionluk** | Fiverr-tarzı | Orta — yapılandırılmış sayfalar, bazı JSON endpoint. Hizmet-satışı ağırlıklı. |
| **Armut.com** | Hizmet pazarı | Zor — Cloudflare + login wall (detay login arkasında). |
| **Freelancer.com.tr / Upwork** | Global, TR filtre | API/iyi yapı ama "Türkiye işi" filtresi gürültülü. |
| **Wmaraci + webmaster forumları** | Forum | R10 gibi, RSS muhtemel. |
| **Kariyer.net / secretCV** | İş ilanı | **Maaşlı eleman**, freelance değil — kapsam kararı sonra. |

---

## 5. İKİ AYRI kimlik katmanı (mimaride karıştırma)

| Katman | Ne | Zorluk |
|---|---|---|
| **A — Kullanıcı → Motor** | Kullanıcı motora üye olur, dashboard'a girer | ⭐ Kolay. Supabase Auth. |
| **B — Motor → Kaynak siteler** | Motor kullanıcı adına Bionluk/R10/Armut'a login | 🔴 Asıl mühendislik. Credential vault + kalıcı oturum + anti-bot + CAPTCHA. |

UI/üyelik = Katman A (trivial). Tüm zorluk Katman B'de.

---

## 6. CAPTCHA — birinci sınıf tasarım kısıtı (öngörülemez!)

> **KULLANICI GÖZLEMİ (kritik):** CAPTCHA / "am I robot" testi **gerçek insan elle giriş yaparken bile** çıkabiliyor. Ne zaman çıkacağı **bilinemez**. Bu yüzden "edge case" değil, **her an mümkün, birinci sınıf bir kesinti** olarak tasarlanmalı. Önlem baştan alınmalı.

Tasarım ilkesi: CAPTCHA'yı **tetiklememeye** çalış, ama **her an çıkabileceğini varsayarak** her oturum akışına bir "challenge interrupt" yolu koy.

### Strateji sırası (en iyiden en kötüye)

1. **Önle (en iyi)** — kalıcı oturum + gerçekçi fingerprint + insan-hızı gecikme (Camoufox/undetected-chromedriver). Görülme sıklığı dramatik düşer ama **sıfırlanmaz**.
2. **Human-in-the-loop (production'da doğru olan)** — motor challenge'a takılınca: ekran görüntüsü al → kullanıcıya UI/push bildirimi "şu CAPTCHA'yı çöz" → kullanıcı canlı görüntüde çözer → token döner → motor devam eder. Öngörülemez tetiklendiği için bu yol **her zaman hazır** beklemeli (pause/resume mekanizması zorunlu).
3. **Ücretli çözücü servis** — 2Captcha / Anti-Captcha (insan çiftlikleri, ~birkaç $/1000). Tam otonom istenirse. Dış bağımlılık + maliyet.
4. **LLM çözer (en zayıf — beklenti düşük)** — Vision LLM sadece eski "resimdeki X'i seç" gridlerini bazen çözer. Modern koruma davranışsal: **reCAPTCHA v3 skorlama (çözülecek şey yok), Cloudflare Turnstile çoğunlukla görünmez.** LLM'e bel bağlama.

**Karar:** 1 (önle) + 2 (her an hazır human-in-the-loop pause/resume). 3 opsiyonel otonom-mod. 4'e güvenme.

### Önlem-tasarımı gereksinimleri (CAPTCHA öngörülemezliğinden doğan)
- Her browser worker **duraklatılabilir + sürdürülebilir** olmalı (challenge anında donmadan beklesin).
- Challenge tespiti → ekran görüntüsü + canlı oturum relay (kullanıcı uzaktan çözebilsin).
- İş kaybı olmasın: challenge sırasında o ilanın state'i kaydedilsin, çözülünce kaldığı yerden devam.
- Oturum bayatlama bildirimi: "X sitesi yeniden giriş istiyor" → tek tık.

---

## 7. Kalıcı oturum pattern (CAPTCHA sıklığını azaltan asıl numara)

Production'da **her seferinde sıfırdan login OLMA**:
1. İlk sefer kullanıcı **elle giriş** yapar (CAPTCHA dahil — bir kez).
2. Oturumu kaydet (Playwright `storage_state` = cookies + localStorage).
3. Motor sonraki çalışmalarda kaydedilmiş oturumu yükler → login ekranı bile görmez → CAPTCHA olasılığı minimuma iner.
4. Oturum bayatlayınca (haftada/ayda bir) → tek bildirim, kullanıcı yeniden girer.

> Not: Bu sıklığı **azaltır**, sıfırlamaz (bkz §6 gözlem). Human-in-the-loop yine hazır beklemeli.

---

## 8. Yasal / operasyonel — dürüst değerlendirme

- Halka açık (login sonrası dahil) ilanları kişisel **konsolidasyon** için toplamak genelde savunulabilir; yasadışı bir durum yok (kullanıcı notu).
- **Asıl risk yasal değil, operasyonel:** çoğu sitenin ToS'u otomatik erişimi yasaklar → yakalanırsan hapis değil, **hesap/IP banı**. İnsan-hızı rate-limit + kalıcı oturum + makul sıklık hem etik hem hesabı korur.
- **RSS'i olan kaynakları öncele** (zaten yayınlanmış veri → en temiz).
- Ticari ürüne (başkalarına üyelik açıp satmak) dönüşürse → gerçek hukuki danışmanlık gerekir, ayrı kapı.

---

## 9. Güncellenmiş mimari (PC production)

```
[Scheduler / RSS]  →  yeni ilan tespit
       ↓
[Browser Worker havuzu]  ← credential vault (storage_state per kaynak)
   Playwright + stealth (Camoufox/undetected), kalıcı oturum
   ⚠️ CAPTCHA her an? → pause + screenshot + push → KULLANICI çözer → resume
       ↓ ham sayfa
[LLM Extraction]  (browser-use / structured output)
   → {başlık, bütçe, süre, dil, framework, ödeme modeli, link, confidence}
       ↓
[Dedup]  content-hash + pgvector benzerlik  (aynı iş 3 sitede → tek kayıt)
       ↓
[Supabase: jobs + job_price_history + sources]
       ↓
[UI / Dashboard]  ← Kullanıcı (Katman A auth)
   "bugünkü Python işleri" kartları + diff/trend ("ort. Python login işi 18k/hafta")
```

**Yeni ve gerçekten zor olan tek nokta:** Katman B'nin sağlamlığı (kalıcı oturum + her an mümkün CAPTCHA relay). Gerisi olgun parçaların montajı.

---

## 10. Önerilen MVP yolu (Ar-Ge başlayınca, 1 hafta sonu)

1. **Tek kaynak: R10.net RSS** — login yok, yasal en temiz, kaliteli iş. RSS → yeni başlık tespiti.
2. **Detay çek:** link → browser (Playwright) veya `budget_extract` → ham metin.
3. **LLM extraction:** ham metin → yapılandırılmış JSON (§3 şema alanları). MiniMax-M3 / DeepSeek elimizde.
4. **Supabase'e yaz** + content_hash dedup.
5. **Basit dashboard / günlük rapor:** §0 kart formatı.
6. Çalışınca → Bionluk + Armut ekle (Cloudflare + login wall + CAPTCHA katmanı devreye girer).

---

## 11. Açık sorular / Ar-Ge'de cevaplanacak

- R10 RSS gerçekten yeni ilanları zamanında veriyor mu? (en riskli varsayım → ilk spike bunu test etmeli)
- browser-use ile bir örnek ilanın yapılandırılmış çıkarımı ne kadar doğru? (extraction kalitesi)
- Kalıcı oturum kaç gün dayanıyor (kaynak başına)? CAPTCHA gerçek frekansı?
- Sınıflandırma taksonomisi: iş tipi / stack / seviye / ödeme modeli enum'ları nasıl kesinleşir? (budget-build `category_schemas.json` deseni)
- Dedup eşiği: cross-post'ları yakalayan pgvector benzerlik skoru kaç?
- Scam/lowball guard'ı: hangi sinyaller (aşırı düşük bütçe, yeni hesap, tekrar eden metin)?

---

## Zamanlama Notu

**Kullanıcı kararı (2026-06-30):** Şu an sadece beyin fırtınası. Önce **Arch kurulumu** tamamlanacak, sonra bu işin **iyice Ar-Ge'si** yapılıp öyle başlanacak. **Acele yok.** Bu dosya fikrin havada kalmaması için kayıt; implementasyon tetiği kullanıcıdan gelecek.
