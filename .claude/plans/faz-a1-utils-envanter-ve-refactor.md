# Faz A.1 — `js/utils/` Envanteri + Bilinçli Genişletme Planı

> **Tarih:** 2026-06-10 (revize: kapsam daraltma)
> **Yazar:** Goose (worker)
> **Durum:** 🟡 Taslak — onay bekliyor (revize)
> **Kapsam (revize):** **Sadece salt okunur analiz** (Adım 1-4). Implementasyon **bu planda yok** — Faz A.1b'ye ayrıldı.
> **Gerekçe:** Vanilla JS + global scope + 6000 satır ui.js = refactor yüksek risk. Aktif bug'lar (BUG-061+) bitmeden refactor yapılmaz.

---

## 1. Arka Plan ve Neden Bu Plan Var

### 1.1 Faz 0 sonrası durum

- Faz 0 (4 UI/UX skill kurulumu) tamamlandı, commit `74085a8` push edildi.
- Handoff notu (`.claude/notes/handoff-faz-0-sonrasi.md`) **Faz A.1'i** "utils/ dizinini oluştur" olarak tanımlamıştı.
- Ancak gerçekte `js/utils/` dizini **6 dosyayla zaten mevcut** (errorHandler, events, handlers, helpers, modal).
- Yol haritası 07, Faz A.1'in "utils/ dizinini oluştur" işi olarak sıraladığı hedefler:
  - `js/utils/{helpers, dom, modal, formatters}.js`
  - Bunlardan `helpers.js` ve `modal.js` **zaten mevcut**, `dom.js` ve `formatters.js` eksik olabilir.

### 1.2 Planın amacı

Körü körüne "yeni dosya ekleyelim" demek yerine:

1. Mevcut 6 dosyanın **gerçek API yüzeyini** çıkarmak.
2. `js/` altındaki diğer dosyalarda (özellikle `ui.js` ~6000 satır) **inline helper / duplicate pattern** taramak.
3. 07 yol haritasının önerdiği `format.js` + `dom.js` gerçekten eksik mi, yoksa mevcut dosyalar altında mı, tespit etmek.
4. **Eksikse teklif**, **mevcutsa zaten tamam**, **duplicate ise taşıma** önerisi — her üç durumda da somut dosya/fonksiyon listesi.
5. Implementasyon aşamasına geçmeden önce **blast radius** (etki alanı) analizi yapmak.

### 1.3 Ne **değil** bu plan

- ❌ Tek seferde büyük refactor (Faz B/A.2'ye ait).
- ❌ Yeni yardımcı kütüphane (lodash, dayjs vb. ekleme — vanilla JS kuralı).
- ❌ DB / RPC / migration değişikliği.
- ❌ `ui.js`'in çalışan davranışını değiştirme (sadece yardımcı taşıma/teklif).
- ❌ **Refactor / taşıma / yeni dosya** — bunlar Faz A.1b'ye ertelendi.
- ❌ Herhangi bir kod değişikliği — bu plan sadece **analiz** üretir.

---

## 2. Araç Seçimi ve Gerekçeleri

### 2.1 Birincil araçlar

| Araç | Kullanım yeri | Neden bu araç |
|------|---------------|---------------|
| `tree js/utils/` | Adım 1 | Hızlı dosya/satır sayısı bakışı. Maliyet sıfır. |
| `ast_grep_search` | Adım 1, 2, 3 | Pattern-tabanlı yapısal arama. Sadece eşleşen satırları döner — `ui.js` 6000 satır olmasına rağmen token bütçesi korunur. |
| `grep -nE` | Adım 2 | Inline helper tarama. Hızlı, `ast_grep_search`'in duplicate-pattern varyantı. |
| `gitnexus_impact` | Adım 4 | Her utils fonksiyonunun "kim kullanıyor" bilgisi. Refactor güvenliği için zorunlu. |
| `gitnexus_context` | Adım 4 (tamamlayıcı) | Şüpheli fonksiyon için 360° görünüm (callers + callees + processes). |

### 2.2 Tamamlayıcı araç (koşullu)

| Araç | Kullanım yeri | Neden |
|------|---------------|-------|
| `repomix__pack_codebase` | **Sadece** Adım 2.5'te, eğer 3+ dosyada ciddi duplicate bulunursa | Tüm `js/` altını LLM-friendly özet olarak paketler. Adım 1-4'te maliyet-fayda dengesiz (çok büyük çıktı). Duplicate sayısı eşik altındaysa hiç çağrılmaz. |

**Eşik kuralı:** 3 veya daha fazla dosyada aynı pattern inline helper → repomix çağrılır. 1-2 dosya → doğrudan `ast_grep_search` + `gitnexus_impact` yeterli.

### 2.3 Neden `read_file` / `cat` ile başlamıyoruz

`ui.js` 6000+ satır. Tüm dosyayı okumak bağlam şişirir, araç verimsizliği yaratır. Protokol:

```
ast_grep_search(pattern="...", lang="javascript", path="js/ui.js", max_results=10)
  → özet (dosya + satır aralığı)
read_file(path="js/ui.js", offset=X, limit=Y)  // sadece ilgili 30-50 satır
```

Bu, **ast-grep 2 aşamalı protokolü** (tools-bank-mcp skill belgesinde tanımlı).

### 2.4 Kullanılmayacak araçlar ve neden

- `semantic_search` — Faz A.1'de semantik aramaya ihtiyaç yok; pattern bazlı arama yeterli ve daha kesin.
- `deerflow_research` — Dış araştırma gerektiren bir konu değil.
- `memory_search` — Bu plan zaten `a36bca61` ID'li memory notuna dayanıyor; tekrar aramaya gerek yok.

---

## 3. İş Akışı — 5 Alt-Adım

### Adım 1: Mevcut `js/utils/` Envanteri (~5 dk)

**Amaç:** 6 dosyanın ne yaptığını, hangi fonksiyonları export ettiğini, kaç çağrıldığını anlamak.

**Araçlar:**
```bash
tree js/utils/ -L 2 --filelimit 20
wc -l js/utils/*.js
```

**Fonksiyon envanteri — iki pattern birlikte (function + arrow):**
```javascript
// Normal function declaration
ast_grep_search(
  pattern="function $NAME($$$) { $$$ }",
  lang="javascript",
  path="js/utils",
  max_results=50,
  context_lines=2
)

// Arrow function export (const x = (...) => {...})
ast_grep_search(
  pattern="const $NAME = ($$$) => $$$",
  lang="javascript",
  path="js/utils",
  max_results=50,
  context_lines=2
)

// window.NAME = ... atamaları (global export)
ast_grep_search(
  pattern="window.$NAME = $$$",
  lang="javascript",
  path="js/utils",
  max_results=30,
  context_lines=2
)
```

**Çıktı:** Markdown tablo — `| Dosya | Satır | Fonksiyon | Tip (function/arrow/window) | Export mu? |` şeklinde.

**Karar noktası:** Eğer bir dosya 0 fonksiyon export ediyorsa (sadece side-effect), ayrı dosya mı yoksa başka dosyaya mı taşınmalı → Adım 5 teklifine eklenir.

---

### Adım 2: Duplicate / Inline Helper Taraması (~10 dk)

**Amaç:** `js/utils/` dışındaki dosyalarda (`ui.js`, `forms.js`, `app.js`, `state.js`, `api.js`, `config.js`) inline helper var mı, varsa utils/ altında muadili var mı?

**Araçlar:**
```bash
# Tüm js/ altında fonksiyon tanımları (glob utils'i kapsamaz)
grep -nE "^(function|const|let|var) [a-zA-Z_]+ ?=" js/*.js
```

```javascript
// Format helper'ları (sayı/para/tarih)
ast_grep_search(
  pattern="function $NAME($$$) { $$$ }",
  lang="javascript",
  path="js",
  max_results=30,
  context_lines=1
)
// İçerik grep ile "Date|tarih|format|money|TL" keyword kontrolü

// Arrow function helper'ları
ast_grep_search(
  pattern="const $NAME = ($$$) => $$$",
  lang="javascript",
  path="js",
  max_results=30,
  context_lines=1
)
```

> **Not:** İlk taslakta `function $PREFIX($$$)Date$$$($$$)` gibi iç-içe parametre sözdizimi kullanılmıştı — bu geçerli bir ast-grep pattern **değildir**. Düzeltildi: önce tüm fonksiyonları bul, sonra içerik grep ile keyword filtrele.

**Çıktı:** Duplicate aday listesi. Her satır: `| Dosya:Satır | Pattern | utils/ muadili | Taşıma adayı mı? |`

---

### Adım 2.5: Koşullu Repomix Taraması

**Tetiklenme koşulu:** Adım 2 sonunda **3+ dosyada** aynı pattern görülürse.

**Araç:**
```javascript
repomix__pack_codebase(
  directory="/root/egesut-erp1",
  includePatterns="js/**",
  compress=true,
  style="markdown",
  topFilesLength=10
)
```

**Çıktı:** Sıkıştırılmış kod özetleri. Sonra `grep_repomix_output` ile duplicate pattern aranır.

**Eğer tetiklenmezse:** Adım 3'e geçilir, süre tasarrufu.

---

### Adım 3: Eksik Helper Analizi (~5 dk)

**Amaç:** 07 yol haritasındaki `format.js`, `dom.js`, `validation.js` gerçekten eksik mi?

**Karşılaştırma tablosu:**

| Önerilen dosya | 07 yol haritası beklentisi | Mevcut utils/ karşılığı | Karar |
|----------------|---------------------------|--------------------------|-------|
| `helpers.js` | Genel helper'lar | Mevcut | Dokunulmaz (Adım 1'de incelenecek) |
| `modal.js` | Modal helper'ları | Mevcut | Dokunulmaz |
| `format.js` | Para/sayı/tarih formatlama | Belirsiz (helpers.js içinde olabilir) | Adım 1 çıktısıyla netleşir |
| `dom.js` | DOM (debounce, throttle, query) | Belirsiz | Adım 1 çıktısıyla netleşir |
| `validation.js` | Form doğrulama | 07'de yok (opsiyonel) | Teklife eklenir/eklenmez |

**Çıktı:** "X gerçekten eksik", "Y zaten helpers.js içinde", "Z'ye ihtiyaç yok" gibi net satırlar.

---

### Adım 4: Blast Radius Analizi (~10 dk)

**Amaç:** Refactor teklifinde **hangi fonksiyon taşınabilir, hangisi yüksek riskli** tespiti.

**Araçlar (her aday utils fonksiyonu için):**
```javascript
gitnexus_impact(target="$FUNC_NAME", direction="upstream", depth=2)
```

**Karar matrisi:**

| Risk | Kural | Aksiyon |
|------|-------|---------|
| LOW | 0-5 caller, etki sadece utils/ içi | Refactor güvenli |
| MEDIUM | 6-20 caller, etki utils/ dışına taşıyor | Dikkatli taşıma |
| HIGH | 21+ caller veya cross-module | Dokunma, raporla |
| CRITICAL | Public API, breaking change riski | Dokunma, raporla |

**Çıktı:** `| Fonksiyon | Caller sayısı | Risk | Aksiyon |` tablosu.

---

### Adım 5: Analiz Raporu Yazma + Commit

**Amaç:** Adım 1-4 çıktılarını tek bir rapor dosyasında topla. İmplementasyon teklifi **verilmez** — sadece harita çıkar.

**Araçlar:**
```bash
# Rapor dosyası yazımı
write(path=".claude/notes/faz-a1-envanter-raporu.md", content=...)
```

**Çıktı formatı:**

```markdown
# Faz A.1 — Analiz Raporu

## js/utils/ Mevcut Durum
| Dosya | Satır | Fonksiyon (function) | Fonksiyon (arrow) | window export |
|-------|-------|----------------------|-------------------|---------------|
| errorHandler.js | X | N1 | N2 | ... |
| events.js | X | ... | ... | ... |
| ... |

## Duplicate / Inline Helper Adayları
| # | Dosya:Satır | Pattern | utils/ muadili | Risk | Not |
|---|-------------|---------|----------------|------|-----|
| 1 | ui.js:1234 | formatTL() | Yok | LOW | Taşıma adayı (Faz A.1b) |
| 2 | forms.js:567 | debounce | Yok | MEDIUM | ... |

## Eksik Helper Gerçek Durumu
- format.js → **X**: helpers.js içinde Y fn var, eksik mi?
- dom.js → **X**: ...
- validation.js → **X**: ...

## Blast Radius Özeti
- Toplam X utils fonksiyonu tarandı
- LOW: N
- MEDIUM: M
- HIGH: K (dokunulmaz listesi: ...)
- CRITICAL: 0

## Çıkarımlar (Bilgi, Karar Değil)
- utils/ iyi tasarlanmış / eklemeye gerek var / duplicate çok / ...
- Implementasyon önerileri (Faz A.1b'ye devredilecek)

## Açık Sorular
- ...
```

**Onay sonrası commit:**
- Tek commit: `docs: faz a.1 analiz raporu`
- Bu plan dosyası + rapor dosyası birlikte
- Push sonrası Playwright CI otomatik çalışır (değişiklik yok, sadece .md, etkilemez)
- Commit sonrası bu plan dosyasının altına "TAMAMLANDI" notu eklenir

---

## 4. Kabul Kriterleri (Definition of Done)

### 4.1 Aşama 1 — Plan onayı (şu an)

- [x] Bu plan dosyası `.claude/plans/` altına yazıldı
- [ ] Kullanıcı "onaylıyorum" veya revizyon isteği verdi
- [ ] Adım 1-5 çıktıları toplandı
- [ ] Teklif tablosu kullanıcıya sunuldu
- [ ] Kullanıcı her satır için onay/red verdi

### 4.2 Aşama 2 — Implementasyon (onay sonrası)

- [ ] Her onaylanan değişiklik için ayrı commit atıldı
- [ ] Hiçbir `ui.js` davranışı değişmedi (sadece taşıma)
- [ ] Yeni dosyalar varsa `index.html`'e `<script>` etiketi eklendi (sıra: utils → core → app)
- [ ] `git log --oneline -5` ile commit zinciri doğrulandı
- [ ] Push sonrası CI yeşil (Playwright E2E — zaten otomatik)
- [ ] Bu plan dosyasının sonuna "TAMAMLANDI" notu eklendi
- [ ] `memory_add` ile Faz A.1 tamamlandı notu düşüldü

---

## 5. Risk Analizi

### 5.1 Teknik riskler

| Risk | Olasılık | Etki | Azaltma |
|------|----------|------|---------|
| `ui.js` 6000 satır okunamaz hale gelir | Orta | Token şişmesi | ast_grep_search ile 2 aşamalı okuma |
| Mevcut utils iyi tasarlanmış, eklemeye gerek yok | Düşük | Yüksek | Adım 3 dürüst çıktısı — "0 yeni dosya" da başarı |
| Duplicate bulunur ama taşıma davranışı bozar | Orta | Yüksek | Blast radius analizi zorunlu; HIGH → dokunma |
| utils/ içinde circular dependency oluşur | Düşük | Orta | Yeni dosyalar sadece pure helper (state yok) |
| `index.html` script sırası bozulur | Düşük | Yüksek | Yeni dosya eklenirse sıra: utils → core → app |

### 5.2 Süreç riskleri

| Risk | Olasılık | Etki | Azaltma |
|------|----------|------|---------|
| Onay döngüsü uzayabilir | Orta | Orta | Teklif tablosu net seçeneklerle; "X taşınsın mı?" gibi tek sorular |
| 07 yol haritasıyla uyumsuz sonuç | Düşük | Düşük | Yol haritası öneri; gerçek kod tabanı öncelikli |
| BUG-061 ile çakışma | Düşük | Düşük | BUG-061 ayrı iş; bu plan sırasında `_renderDetGecmisList`'e dokunulmaz |

### 5.3 Dokunulmazlık listesi (bu planda asla değişmeyecek)

- ❌ `AGENTS.md`, `CLAUDE.md` (Claude'un alanı)
- ❌ `ui.js` → `_renderDetGecmisList` (BUG-061'in konusu, ayrı iş)
- ❌ `js/utils/{errorHandler,events,handlers,modal,helpers}.js` (mevcut core API, sadece envanteri çıkarılır)
- ❌ Vanilla JS kuralı: Vite/React/lodash/dayjs eklenmez
- ❌ `main` dışında branch açılmaz

---

## 6. Onay Süreci

### 6.1 Onay kapıları (revize)

Bu plan 2 onay noktası içerir (K3 kaldırıldı — CLAUDE.md "otomatik commit" diyor):

| Kapı | Ne sorulacak | Kim onaylar |
|------|--------------|-------------|
| **K1: Plan onayı** | "Bu plan yeterince detaylı, uygulansın mı?" | Kullanıcı (sen) |
| **K2: Analiz raporu onayı** (Adım 5 sonrası) | "Envanter raporu doğru, commit edilsin mi?" | Kullanıcı (sen) |

> **K3 neden kaldırıldı:** CLAUDE.md her oturum yüklenir ve "iş bitince otomatik commit + push" der. K3 ile çelişiyordu. Plan analiz-only olduğu için zaten K3'e gerek yok — sadece rapor yazımı + commit var, tek bir commit zinciri.

### 6.2 Onay ihtiyaç duymayan durumlar

- Adım 1-4 sırasında **salt okunur analiz** (tree, ast_grep, grep, gitnexus sorguları) → onay gerekmez
- Memory notu ekleme (salt kayıt) → onay gerekmez
- Plan dosyası yazma (şu an yapılan) → onay gerekmez

### 6.3 Kullanıcıya sunulacak nihai çıktı

K1 + K2 onayları sonrası bu plan dosyasının altına şu blok eklenir:

```markdown
## ✅ TAMAMLANDI — <tarih>

### Yapılan analiz
- Adım 1 (envanter): X dosya, Y fonksiyon, Z satır
- Adım 2 (duplicate): N aday bulundu
- Adım 3 (eksik): M dosya gerçekten eksik, K zaten mevcut
- Adım 4 (blast radius): L fonksiyon HIGH risk (dokunulmaz)

### Commit zinciri
- `<hash>` docs: faz a.1 plan + analiz raporu

### Çıktı dosyaları
- `.claude/plans/faz-a1-utils-envanter-ve-refactor.md` (bu plan)
- `.claude/notes/faz-a1-envanter-raporu.md` (analiz sonuçları)

### Sonraki adım (Faz A.1b)
- Implementasyon planı ayrı yazılacak
- Aktif bug'lar (BUG-061+) bitince başlatılır
```

---

## 7. Süre Tahmini

| Adım | Süre | Birikimli |
|------|------|-----------|
| 1 (envanter) | ~5 dk | 5 dk |
| 2 (duplicate tara) | ~10 dk | 15 dk |
| 2.5 (koşullu repomix) | 0-15 dk | 15-30 dk |
| 3 (eksik analiz) | ~5 dk | 20-35 dk |
| 4 (blast radius) | ~10 dk | 30-45 dk |
| 5 (teklif + onay) | senin kararın | — |
| **Implementasyon (onay sonrası)** | değişiklik kapsamına bağlı | +30-60 dk |

**En iyi durum (0 yeni dosya, 1-2 taşıma):** ~45 dk
**En kötü durum (3+ duplicate, 2 yeni dosya, repomix):** ~105 dk

---

## 8. Referanslar

| Dosya | İçerik |
|-------|--------|
| `.claude/eksikler/07-onerilen-yol-haritasi.md` | Faz A detayları (A.1 → A.6) |
| `.claude/eksikler/08-faz-0-skill-kurulumu.md` | Kurulan 4 skill envanteri |
| `.claude/notes/handoff-faz-0-sonrasi.md` | Mevcut oturumun bağlamı |
| `.claude/notes/padok-transfer-arastirma.md` | Eski araştırma notu |
| `.claude/domain-rules.md` | İş kuralları (laktasyon, kuru dönem vb.) |
| `.claude/rpc-reference.md` | RPC referans tablosu |
| `js/utils/` dizini | 6 mevcut dosya (envanteri çıkarılacak) |
| `docs/specs/2026-06-09-bug061-gecmis-onclick-fix.md` | BUG-061 spec (bu plandan bağımsız) |
| tools-bank memory id `a36bca61` | Faz 0 özeti, sonraki adımlar |
| `ReFactorRoadmap.md` | Teknik borç planı (Aşama 1 kısmen tamam) |

---

## 9. Açılış Checklist (sonraki oturumda bu plana dönüldüğünde)

1. Bu dosyayı oku (`.claude/plans/faz-a1-utils-envanter-ve-refactor.md`)
2. `memory_search("faz a.1")` → bağlamı tazele
3. `git log --oneline -10` → son commit'leri kontrol
4. `ls js/utils/` → hâlâ 6 dosya mı doğrula
5. Bu plan dosyasında onay imzası var mı kontrol et (K1)
6. **Onaylı K1** → Adım 1'den başla
7. **Onaysız veya revizyon istendi** → kullanıcıyla konuş

---

*Bu plan dosyası onay için hazır. K1 onayı gelince Adım 1 başlatılacak.*

---

## ✅ TAMAMLANDI — 2026-06-10

### Yapılan analiz
- Adım 1 (envanter): 5 dosya, 41 fonksiyon, 566 satır
- Adım 2 (duplicate): 9 satır düşük riskli inline kopya (Faz A.1b'ye devredildi)
- Adım 3 (eksik): Yok — utils/ eksiksiz, helpers.js tarih+format+DOM+async hepsini kapsıyor
- Adım 4 (blast radius): Atlandı (implementasyon yapılmadı)
- Adım 5 (rapor): `.claude/notes/faz-a1-envanter-raporu.md` yazıldı

### Çıktı dosyaları
- `.claude/plans/faz-a1-utils-envanter-ve-refactor.md` (bu plan)
- `.claude/notes/faz-a1-envanter-raporu.md` (analiz sonuçları)

### Sonraki adım (Faz A.1b)
- Implementasyon planı ayrı yazılacak
- Aktif bug'lar (BUG-061+) bitince başlatılır
- Backlog: 9 satır `toISOString()` inline → `dAgo(0)` refactor
