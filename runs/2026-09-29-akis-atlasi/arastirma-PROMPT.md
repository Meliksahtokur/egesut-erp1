# Araştırma prompt'u — Kodlama ajanlarına web uygulamasının UI akışlarını "gösterecek" araç/yöntem

> Kullanım: aşağıdaki "PROMPT" bölümünü olduğu gibi derin araştırma modeline (ChatGPT Deep Research / Gemini / Perplexity vb.) yapıştır.
> Bağlam bölümü kasıtlı olarak ayrıntılı; model repoyu görmüyor.

---

## PROMPT

Bir araştırma yapmanı istiyorum. Cevabı **Türkçe** yaz; araç adları, komutlar ve alıntılar orijinal dilinde kalabilir.
Her iddia için kaynak linki ver ve kaynağın tarihini yaz. Kendi doğrulayamadığın şeyi "doğrulanmadı" diye işaretle; tahmin etme.
Bugünün tarihi 2026-09-29. **Son 12 ayda aktif olan** araçlara ağırlık ver; terk edilmiş projeyi "terk edilmiş (son commit: …)" diye işaretle.

### Bağlam — sorun ne

Bir süt çiftliği ERP'si geliştiriyorum. Kodu büyük ölçüde AI kodlama ajanları yazıyor ve planlıyor (Claude Code, OpenAI Codex CLI, GLM tabanlı Claude Code koltukları; hepsi terminalde, tmux/herdr pane'lerinde koşuyor).

Tekrarlayan sorun: **ajanlar uygulamanın UI akışlarını anlamıyor.** Bir iş akışı (ör. "tohumlama kaydı → 40 gün sonra gebelik muayenesi görevi doğar → görev ekranında sonuç girilir → Boş ise Ovsync/PG protokolü seçilir") şu halkalara dağılmış durumda:
- ekran/modal (HTML) → onclick → JS fonksiyonu (birkaç büyük dosyada: ui.js ~12k satır, forms.js, api.js),
- JS → Supabase RPC (PostgreSQL SECURITY DEFINER fonksiyonları),
- RPC → tablolar → **tetikleyiciler** ve **pg_cron işleri** (arka planda görev üreten, kapatan),
- offline-first katman (IndexedDB önbelleği, sonradan senkron).

Ajan kodu dosya dosya okuyup akışı zihninde kurmaya çalışıyor ve ara halkaları kaçırıyor: confirm() pencereleri, ikinci bir RPC ile yapılan retry, sabah cron'unun doğurduğu görev, aynı görev tipini üreten **ikinci bir üretici**. Somut örnek: iki ayrı plan/review turu kodu okuyup "gebelik kontrol görevini yalnız 40 g cron'u üretir" diye varsaydı. Oysa tohumlama RPC'si de +21/+35 günde görev üretiyordu. Bunu ancak bir ajan demo ortamında tarayıcıyla gerçekten gezinip canlı bir "35. Gün gebelik kontrolü" görevi görünce bulduk.

Şu an elle yaptığımız çözüm: ajan, Playwright ile demo modunda (ayrı demo veritabanı) dokunduğu akışı **elle yazdığı betikle** yürüyor, ekran görüntüsü alıyor, sonra akışı mermaid diyagramı + "ekran → fonksiyon → RPC → tablo" zinciri olarak yazıyor. İşe yarıyor ama her seferinde elle ve iş bitince kayboluyor.

### Teknik yığın ve kısıtlar
- Frontend: framework'süz **Vanilla JS** SPA (tek index.html, modal/bottom-sheet ağırlıklı, hash routing yok ya da sınırlı), GitHub Pages'te statik.
- Backend: Supabase (PostgreSQL + PostgREST RPC), pg_cron, tetikleyiciler. JS tarafı RPC'yi `supabase.rpc('ad', {...})` ile çağırıyor.
- Test: Playwright (Docker imajında, Linux / CachyOS), Node birim testleri.
- Ortam: yerel Linux iş istasyonu, 30 GB RAM, ayrı bir demo DB var. Ajanlar MCP sunucuları kullanabiliyor.
- Mevcut statik araçlar: GitNexus (kod bilgi grafiği: çağrı grafiği, route_map, trace, impact), JSDoc tabanlı bir JS "atlas"ı, SQL LSP.
- **Kısıtlar:** üretim verisi dışarı gönderilmez; yalnız demo ortamı taranır. Ücretli bulut SaaS ancak ücretsiz katmanı ya da self-host seçeneği varsa ve demo verisiyle sınırlıysa kabul. Açık kaynak ve yerelde koşan tercih edilir. Uygulama kendi hesabımızla oturum açıyor (storageState ile).

### Aradığım şey
Ajanın (ya da bir betiğin) uygulamayı **keşfederek** akışları çıkarmasını ve bunu kalıcı, makine tarafından okunabilir bir "akış atlası"na dönüştürmesini sağlayacak araç/yöntem. Tercihen:
1. **Keşifsel tarayıcı gezinimi:** uygulamayı otomatik gezip ekranları/durumları ve geçişleri çıkaran bir araç (crawler, durum makinesi çıkarımı).
2. **UI olayı ↔ ağ çağrısı eşlemesi:** hangi tıklamanın hangi RPC/HTTP çağrısını tetiklediğini kaydeden bir araç (tarayıcı izleme / trace / HAR).
3. **Ajan entegrasyonu:** bir LLM kodlama ajanının bu bilgiyi sorgulayabilmesi (MCP sunucusu, CLI, JSON/markdown çıktı).
4. **Arka uç halkası:** RPC → tablo → tetikleyici/cron zincirini çıkaran bir yöntem (Postgres katalog analizi, pg_stat, log tabanlı).
5. **Bakım:** kod değiştikçe atlasın bayatladığını fark etme / yeniden üretme.

### Araştırma soruları
1. **Keşifsel UI tarama / model tabanlı test:** bir web uygulamasını gezip durum-geçiş modeli çıkaran araçlar ve akademik yaklaşımlar hangileri? (Aday alan adları: GUI ripping, Crawljax tarzı durum-akış grafiği, model-based testing (GraphWalker vb.), LLM destekli otonom web ajanlarıyla keşif. Bunları doğrula, yenilerini bul.) Framework'süz, modal ağırlıklı bir SPA'da ne kadar işe yarıyorlar?
2. **LLM tarayıcı ajanları ve MCP:** Playwright MCP, Chrome DevTools MCP, browser-use, Stagehand ve benzerleri ile Playwright'ın kendi AI/test ajanı özellikleri (planner/generator/healer gibi). Hangisi (a) keşif, (b) akışı belgeleme, (c) tekrar üretilebilir test çıkarma işini yapıyor? Yerelde ve Claude Code / Codex CLI ile kullanılabiliyor mu?
3. **Ağ izleme ile akış çıkarma:** Playwright trace / HAR / CDP ile "tıklama → istek" eşlemesini otomatik çıkaran hazır araç ya da desen var mı? Çıktıdan otomatik sıralama diyagramı (mermaid/PlantUML) üreten bir şey var mı?
4. **Statik + dinamik birleşimi:** kod bilgi grafiği (çağrı grafiği) ile çalışma zamanı izini birleştirip "ekran → fonksiyon → API → DB" zincirini çıkaran araçlar ya da yayınlanmış yöntemler var mı?
5. **Postgres tarafı:** bir RPC fonksiyonunun dokunduğu tabloları, tetikleyici zincirini ve pg_cron bağımlılıklarını otomatik çıkaran araçlar (plpgsql bağımlılık analizi, pg_depend, plpgsql_check, lineage araçları).
6. **Ajanlar için "uygulama haritası" pratikleri:** AI kodlama ajanlarına uygulama akışını anlatmak için topluluk ne yapıyor? (Ör. repo içinde akış belgeleri, llms.txt benzeri yapılar, "user journey map" dosyaları, test kayıtlarından belge üretimi.) Kanıtlanmış iyi pratik var mı?
7. **Bayatlık tespiti:** akış belgesinin koddan geri kaldığını otomatik yakalamanın yolları (akış başına bir e2e testi "canlı belge" olarak kullanmak, ekran görüntüsü farkı vb.).

### Değerlendirme ölçütleri (her aday için tablo)
| Ölçüt | Açıklama |
|---|---|
| Ne yapar | tek cümle |
| Kategori | keşif / izleme / belge üretimi / test üretimi / DB analizi |
| Vanilla JS modal SPA'ya uygunluk | yüksek/orta/düşük + gerekçe |
| Yerel/self-host | evet/hayır; veri dışarı çıkıyor mu |
| Ajan entegrasyonu | MCP / CLI / API / yok |
| Çıktı biçimi | JSON, mermaid, test kodu, grafik… |
| Olgunluk | son sürüm/commit tarihi, yıldız/kullanım, lisans |
| Maliyet | ücretsiz / ücretli (fiyat) |
| Kurulum eforu | saat cinsinden kaba tahmin + gerekçe |

### İstenen çıktı
1. **Yönetici özeti** (≤10 satır): benim durumum için en iyi 2–3 yol ve nedeni.
2. Yukarıdaki ölçütlerle **aday tablosu** (en az 8 aday, kategorilere göre).
3. **Önerilen mimari:** keşif + izleme + statik grafik + DB analizi nasıl birleşir; "akış atlası" dosyası neye benzemeli (örnek bir akış sayfası iskeleti ver: mermaid + zincir tablosu + kanıt + son doğrulama bilgisi).
4. **Pilot planı:** tek bir akış üzerinde 1 günde denenebilecek en küçük deney. Adımlar, başarı ölçütü, ve "işe yaramadı" sayılma koşulu.
5. **Riskler ve bilinmeyenler:** özellikle modal/bottom-sheet ağırlıklı ve offline-first (IndexedDB) SPA'da keşif araçlarının takıldığı noktalar.
6. **Kaynakça:** link + tarih.

Kapsam dışı: genel "E2E test nasıl yazılır" anlatımı, UI tasarım araçları, üretim izleme (APM) satış sayfaları.
