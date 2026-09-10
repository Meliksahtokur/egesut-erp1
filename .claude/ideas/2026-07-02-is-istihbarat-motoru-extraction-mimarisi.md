# İş İstihbarat Motoru — Extraction (Ayrıştırma) Mimarisi

**Tarih:** 2026-07-02
**Durum:** Fikir / istişare notu — implemente edilmedi. Ana fikirle birlikte **Arch kurulumu sonrasına ertelendi (acele yok).**
**Ana doküman:** `2026-06-30-is-istihbarat-motoru.md` — vizyon, kaynaklar, CAPTCHA, DB şeması, MVP yolu.
**Bu doküman neyi kapsar:** ilan sayfası → yapılandırılmış veri dönüşümünün **nasıl** yapılacağı. Özellikle "arama motorları LLM'siz nasıl yapıyor" ilhamı ve buradan çıkan **kademeli (cascade) extraction mimarisi**.
**İlişkili:** [[project-budget-build-research-skill]] (extract deseni buradan geliyor — JSON-LD/`__NEXT_DATA__`/pgList okuma zaten var).

---

## 0. Bu dokümanı doğuran soru (istişare özeti)

Tartışma zinciri:

1. **Embedding modeli kullanır mıyız?** → Evet ama sınırlı. Embedding = "cetvel" (benzerlik ölçer), "beyin" değil. Ayrıştırma/anlamlandırma/sınıflandırma embedding'in işi DEĞİL. Embedding sadece 3 işe yarar: cross-post dedup, semantik arama, kümeleme/trend. **MVP'de (tek kaynak R10) gereksiz** — content_hash yeter. 2. kaynak (Bionluk/Armut) gelince, cross-post dedup için devreye girer. İlan küçük atomik birim olduğu için **chunking'e gerek yok** (kod embedding'inde chunking gerekiyordu çünkü dosyalar büyük; ilan = tek parça embed).

2. **O halde ayrıştırma/sınıflandırmayı kim yapar?** İki ayrı "model" var, karıştırma:
   - **LLM** (MiniMax-M3 / DeepSeek) = beyin. Serbest metni okur, structured JSON döner, sınıflandırır, puanlar.
   - **Embedding** (bge-m3) = cetvel. Sadece benzerlik.
   - Serbest metin ayrıştırma = LLM işi, embedding değil.

3. **Kritik itiraz (kullanıcı):** "Bu yapısal bir kod bloğu değil, serbest metin — syntax/matematik yok. Makine bunu nasıl ayrıştıracak?" Doğru: kod `CREATE FUNCTION` gibi kesin sınırlarla regex'lenebilir, forum düz yazısı ("merhaba arkadaşlar 30k civarı...") regex'lenemez.

4. **Asıl çerçeveleme (kullanıcı):** "Büyük arama motorları (Google/DDG/Bing) LLM'den ÖNCE onlarca yıl snippet/yapılandırılmış veri çıkardı — makine ile, doğrudan metinden. İlham alabileceğimiz açık kaynak var mı?" → **Bu dokümanın çekirdeği.**

---

## 1. Arama motorlarının "sırrı": ayrıştırmaktan KAÇINMAK

Kilit içgörü: Google serbest düz yazıyı sanıldığı kadar ayrıştırmaz. Numara, **sitenin zaten yayınladığı yapılandırılmış veriyi okumak** ve gerçek belirsizliği en sona bırakmaktır. Dört ayrı teknik geleneği:

### Teknik 1 — Sitenin kendi yapılandırılmış verisini oku (EN ÖNEMLİ)

Google for Jobs **tamamen** bunun üstüne kurulu. Siteler HTML'e `schema.org/JobPosting` JSON-LD gömer:

```html
<script type="application/ld+json">
{
  "@type": "JobPosting",
  "title": "Login tasarımı",
  "baseSalary": { "value": 30000, "currency": "TRY" },
  "employmentType": "CONTRACTOR",
  "datePosted": "2026-06-30"
}
</script>
```

Google bunu **okur, ayrıştırmaz** — site alanları hazır vermiş. LLM sıfır.

**Bizim için:** Bu, budget-build'de zaten yapılan işin aynısı (Akakçe `__NEXT_DATA__`, Cimri JSON-LD). İş ilanı sitelerinin bir kısmı (özellikle kurumsal / Bionluk gibi yapılandırılmış olanlar) JobPosting JSON-LD emit eder → oralarda LLM'e hiç gerek yok. **P0 önceliği.**

### Teknik 2 — Boilerplate temizle, ana metni çıkar

Menü/footer/reklamı at, "asıl içeriği" bul. DOM yoğunluğu + link/metin oranı heuristikleri. LLM'den ~20 yıl önce çözüldü (Readability, boilerpipe).

### Teknik 3 — Kural-tabanlı varlık çıkarma (para / tarih / süre)

"30k civarı, 1 haftada bitsin" → sayı/tarih/süre çıkarımı, **gramer/kural ile, LLM'siz**. Altın standart: **Duckling** (wit.ai/Siri motoru).

```
"30k civarı"    → { value: 30000, unit: "TRY" }
"1 haftada"     → { value: 7, unit: "day" }
"yarısı başta"  → milestone sinyali (kural + anahtar kelime)
```

### Teknik 4 — Snippet = anlama değil, SEÇME

Google snippet'i üretmiyor, sorguya en uygun cümleyi **seçiyor** (BM25/TF-IDF passage retrieval). "Kart özeti" için: en bilgi-yoğun cümleyi kuralla seç, üretme.

---

## 2. Dürüst sınır — teknikler nerede parlar, nerede tıkanır

Bu teknikler iki koşulda **mükemmel** çalışır:

- Site **yapılandırılmış veri emit ediyorsa** (schema.org) → `extruct` ile oku, bitti.
- Site **şablonluysa** (her ilan aynı DOM — Bionluk gibi) → "wrapper induction": XPath'i bir kez öğren, hep kullan.

Ama **R10 forum düz yazısında** ne schema.org var ne tutarlı şablon. Orada Duckling `30k`/`1 hafta`'yı yakalar, ama "bu bir *iş* mi, iş-tipi ne, ödeme modeli ne" bağlamsal kararını kuralla güvenilir veremezsin → **serbest prozanın kuyruğu LLM'e kalır.**

**Arama motorlarının asıl dersi:** *"LLM'i her şeye koşma — en sona koş."*

---

## 3. Kademeli (cascade) extraction mimarisi — asıl karar

```
   HAM İLAN SAYFASI
        │
        ▼
   ┌──────────────────────────────────────────────────────────┐
   │ KADEME 1 — extruct: schema.org/JobPosting JSON-LD var mı? │
   │   VAR → alanları OKU, güvenle çık.  (siteler ~%40-60)     │  ← LLM YOK
   ├──────────────────────────────────────────────────────────┤
   │ KADEME 2 — şablonlu site mi? → wrapper (XPath/CSS) çek    │  ← LLM YOK
   ├──────────────────────────────────────────────────────────┤
   │ KADEME 3 — trafilatura: ana metni temizle                 │  ← LLM YOK
   │            Duckling / spaCy Matcher: para·süre·tarih·tel   │
   ├──────────────────────────────────────────────────────────┤
   │ KADEME 4 — HÂLÂ eksik/belirsiz alan                       │
   │   (ödeme modeli, seviye, iş-tipi, "bu gerçekten iş mi")   │
   │   → SADECE bu boşluğu LLM'e sor (structured output)       │  ← LLM sadece kuyruk
   ├──────────────────────────────────────────────────────────┤
   │ SON — MAKİNE doğrula + normalize + enum'a otur            │
   │   LLM çıktısı geçerli taksonomi enum'u mu? uydurma reddet │  ← LLM'e körü körüne güvenme
   └──────────────────────────────────────────────────────────┘
```

Bu, "makine işin çoğunu yapar, model yetersiz kaldığı yeri yapar" ilkesinin tam mimari karşılığı. Sonuç: **daha az LLM çağrısı (maliyet), daha yüksek güvenilirlik (kaynak-doğru veri), hallucination'a karşı enum doğrulama kalkanı.**

### Sınıflandırma/taksonomi nerede "yaşar"

- **Enum listesi = makinede** (sabit, kurallı). `job_type ∈ {web, mobil, data, devops, ai, bot, scraping}`, `payment_model ∈ {fixed, milestone, hourly}`, `seniority ∈ {basic, orta, ileri}`. budget-build'deki `category_schemas.json` deseninin aynısı.
- **Metni → enum'a eşleme = LLM** (Kademe 4). "Yarısı başta yarısı teslimde" → `milestone` demek anlam işi.
- **Enum doğrulama = makine** (Son kademe). Uydurma değeri ("aşamalı-ödeme") reddet, PARTIAL'a düşür.

Yani: makine sınırı çizer (geçerli değerler kümesi) → LLM içine oturtur → makine tekrar denetler.

---

## 4. İlham alınacak açık kaynak — somut liste

| Alt-problem | Proje | Dil | Not |
|---|---|---|---|
| schema.org / JSON-LD / microdata oku | **extruct** (Zyte) ⭐ | Python | JSON-LD + microdata + RDFa + OpenGraph + microformats. Motorun P0'ı. |
| " (alternatif) | crwlr/schema-org | PHP | Aynı iş |
| ana metin + metadata çıkar | **trafilatura** ⭐ | Python | Bugün en iyisi, aktif (2.1.0, 2025). Metin + tarih/yazar/başlık + JSON-LD tek çağrıda. Fetch ladder'ın bir üstü. |
| " (alternatif) | Mozilla Readability.js, jusText, boilerpipe/dragnet | JS/Py | Klasik boilerplate temizleyiciler |
| para/tarih/süre kural-çıkarımı | **Duckling** (Meta) ⭐ | Haskell | wit.ai/Siri motoru. amount-of-money/duration/date/number. TR kısmi ama sayı/para/süre çalışır. |
| " (Python-native) | spaCy Matcher / EntityRuler | Python | Regex + sözlük tabanlı, opsiyonel istatistiksel NER |
| şablonlu site alan çıkarımı | Scrapy + wrapper, MDR (data record mining) | Python | XPath-öğren-tekrar-kullan |
| snippet seçimi (üretme değil) | rank_bm25, Whoosh | Python | En bilgi-yoğun cümleyi SEÇ |
| tam scraper mimari referansı (TR kaynak YOK) | JobSpy, Crawl4AI | Python | Sadece mimari ilham |

**Okunacak tek doküman:** Google Search Central — *"Job posting (JobPosting) structured data"* geliştirici kılavuzu. Motorun hedef şeması aynen orada; `extruct` çıktısıyla birebir eşleşir. Şema referansı olarak alınırsa `jobs` tablosu baştan standarda hizalı olur.

---

## 5. MVP'ye etkisi (ana dokümandaki §10 ile birlikte oku)

Ana doküman MVP = tek kaynak R10 RSS. Bu extraction mimarisinin MVP'ye somut yansıması:

- **R10 düz yazı ağırlıklı** → schema.org muhtemelen YOK, şablon zayıf → Kademe 1-2 çoğu zaman boş döner. MVP'de asıl yük **Kademe 3 (trafilatura + Duckling) + Kademe 4 (LLM kuyruk)** üzerinde olur. Yani MVP'de LLM daha aktif — ama yine de "önce Duckling para/süre yakala, kalanı LLM" hibridi ham-LLM'den ucuz/güvenilir.
- **extruct'ın asıl değeri 2. kaynakta** (Bionluk / kurumsal ilan siteleri) ortaya çıkar — orada JobPosting JSON-LD olma olasılığı yüksek, LLM neredeyse sıfıra iner.
- **Embedding hâlâ MVP dışı** — cross-post olmadığı için (§0.1). Şemaya `embedding vector(1024)` kolonu bile MVP'de eklenmeyebilir; `ALTER TABLE ADD COLUMN` 2. kaynakta bir dakikalık iş.

---

## 6. Açık sorular (Ar-Ge'de cevaplanacak — ana doküman §11'e ek)

- R10 ilanlarında schema.org oranı gerçekte ne? (spike ölçsün — Kademe 1'in MVP değeri buna bağlı)
- Duckling TR para/süre kapsama oranı yeterli mi, yoksa spaCy TR + custom kural sözlüğü mü gerekli?
- Kademe 4 LLM'e "sadece eksik alanı sor" mu, yoksa "tüm metni ver tam JSON iste" mi daha güvenilir/ucuz? (kısmi-prompt vs tam-prompt spike)
- Wrapper induction (Kademe 2) hangi kaynaklarda değer üretir — sadece Bionluk mu, R10 ilan-formu şablonu var mı?
- Enum doğrulama katmanı hangi normalize kurallarını içermeli? ("website"→"web", "flutter"→mobil framework eşlemesi vb.)

---

## Zamanlama Notu

Ana dokümanla aynı: **şu an sadece istişare/beyin fırtınası.** Önce Arch kurulumu, sonra iyice Ar-Ge, öyle başlanacak. Acele yok. Bu doküman, extraction tarafının "nasıl" kararını (kademeli, LLM-en-sona) ve ilham kaynaklarını havada bırakmamak için kayıt. İmplementasyon tetiği kullanıcıdan gelecek.
