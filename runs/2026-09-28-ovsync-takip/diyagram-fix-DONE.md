# DONE — 3 diyagram düzeltmesi (T-97, T-98, T-100) — katalog düzeltmeleriyle hizalı

Tarih: 2026-09-30 · Zarf: diyagram-review-DONE.md §4'ün 3 bulgusu (ÖNEMLİ×2, MİNÖR×1) → katalog v2 (`test-senaryolari.md` satır ~811-841) ile hizalama. Commit yok.

## 1. Düzeltme özetleri (önce → sonra)

### T-97 — ÖNEMLİ #1: kimlik fixture'ı ve guard sınırı
- **Önce:** `t97_ui` yalnız `p_secim` modlarını listeliyordu; tam `p_tohumlama_id` fixture'ı yok, üç yazma çağrısının aynı kimliği kullandığı görünmüyordu, red'in hangi kapıdan geldiği belirsizdi.
- **Sonra:** Yeni `Ön koşul / fixture` subgraph'ı eklendi — `t97_fix` (H'de geçerli Boş-yolu tohumlaması `sonuc='Bekliyor'` → TAM `p_tohumlama_id`) + `t97_ayar` (bayrak=0, T-46 aynı seed). `t97_fix → t97_ui` kenarı "aynı tam `p_tohumlama_id` — dört çağrıya da" ve `t97_ui` etiketi "dry-run VE üç yazma modu HEPSİ AYNI tam `p_tohumlama_id` ile" diye gösteriyor. RPC katmanına `t97_xor` safe düğümü kondu ("Kimlik XOR'u (#9) GEÇİLİR"); kenar etiketi "XOR geçildi → GIRIS_CIFT_ANLAMLI red'i BURADAN gelmez", `t97_ayar → t97_kar` kenarı "red kapısı BURASI". Kaplama notu: red `GIRIS_CIFT_ANLAMLI` beklenMEZ, bayrak kapısından gelir.
- **Katalog dayanağı:** `test-senaryolari.md:814-816` (Ön koşul + BEKLENEN son cümle).

### T-98 — ÖNEMLİ #2: izinli red kümesi + deterministik fixture (b)
- **Önce:** Fixture (a) kenarı tek `t98_red` (`BOS_DUZELTME_KOSUL`) düğümüne gidiyordu — kataloğun izinli kümesi `{TOH_SONUCLU, BOS_DUZELTME_KOSUL}` ile çelişiyordu; fixture (b) kenarı yalnız "son değil" diyordu (kurulum belirsiz).
- **Sonra:** Yeni `Fixture` subgraph'ı (t98_fa / t98_fb / t98_fc — üç kırık koşul düğüm olarak) eklendi, her biri `p_secim='GEBE'` ayrı çağrı kenarıyla `t98_r1`'e akar. Fixture (a) kenarı artık `t98_izinli`'ye bağlanıyor: "İZİNLİ RED KÜMESİ (fixture a) — koşul-4 dönmesi: { 'TOH_SONUCLU' | 'BOS_DUZELTME_KOSUL' } … İKİSİ DE KABUL" (eski `t98_don` düğümü bu küme düğümüne birleştirildi; SVG'de `BOS_DUZELTME_KOSUL` tam 2 geçiş: red düğümü + küme düğümü). Fixture (b) düğümü deterministik kurulumu taşır: "üstüne `treatment_date` ile KESİN daha yeni kayıt girilir (eşitlikte `created_at` belirler)"; karar düğümünün koşul-3 satırı da "(tarih DESC, created_at DESC)" ile netleşti. `t98_izinli → t98_now` ("iki red de: hiçbir yazma yok").
- **Katalog dayanağı:** `test-senaryolari.md:822-824` + `plan.md:304` koşul-4 dönmesi.

### T-100 — MİNÖR #3: H3 kaynak kanıtı adımı
- **Önce:** Kapanış akışı yalnız gözlem kanıtı çiziyordu (`t100_ok` "Kapanış 40P01 / 55P03 OLMADAN tamamlanır"); `pg_get_functiondef` kaynak-gövde okuma adımı yoktu.
- **Sonra:** `t100_h3` düğümü eklendi (adım 2): "H3 KAYNAK KANITI: `pg_get_functiondef` ile kapanış tetikleyici fonksiyon gövdesi okunur → 'FOR UPDATE' / 'LOCK' kalıbı İÇERMEZ"; `t100_t2 → t100_h3` kenarı ("adım 2: kaynak kanıtı"). `t100_ok` yeniden etiketlendi: "DESTEKLEYİCİ KANIT … tek başına kanıt DEĞİL; H3 kaynak kanıtıyla birlikte değerlendirilir" + `t100_h3 -.-> t100_ok` kesikli bağlantı. Kaplama notu birincil/destekleyici kanıt ayrımını yazıyor.
- **Katalog dayanağı:** `test-senaryolari.md:839` (adım 2, review MİNÖR #3).

Dokunulmayan bloklar: T-95, T-96 (diyagram-T95-97.md), T-99 (diyagram-T98-100.md) — parça↔birleşik birebir diff ile doğrulandı.

## 2. Doğrulama kanıtları (verification-before-completion-obra)

1. **RENDER (3 değişen blok, mmdc 12.0.0 + puppeteer-config chromium):**
   - Puppeteer config: `{"executablePath": "/home/melik/.cache/ms-playwright/chromium-1228/chrome-linux64/chrome"}` — not: `node -e require('playwright').chromium.executablePath()`'in bildirdiği `chromium-1208` yolu diskte YOKTU (`Browser was not found`, exit=1 ×3); gerçek binary `chromium-1228` altında bulundu.
   - Parça dosyalardan: `t97 exit=0 svg=220354B · t98 exit=0 svg=233933B · t100 exit=0 svg=224284B`
   - **Birleşik dosyadan tekrar:** `T-97 exit=0 svg=220354B · T-98 exit=0 svg=233933B · T-100 exit=0 svg=224284B` (bayt bayt aynı — içerik birebir).
   - SVG içerik taraması (case-sensitive, Türkçe stringler): T-97 `TAM p_tohumlama_id / GEÇİLİR / red kapısı BURASI / GIRIS_CIFT_ANLAMLI / OZELLIK_KAPALI` = her biri mevcut; T-98 `İZİNLİ RED KÜMESİ / DETERMİNİSTİK / treatment_date / created_at belirler / İKİSİ DE KABUL / BOS_DUZELTME_KOSUL(×2 geçiş)` mevcut; T-100 `pg_get_functiondef / FOR UPDATE / DESTEKLEYİCİ KANIT / tek başına kanıt DEĞİL / H3 KAYNAK KANITI` mevcut.
2. **NODE-ID BENZERSİZLİĞİ (değişen bloklar, tanım sayımı `uniq -c`):** T-97: 14 id (10 düğüm + 4 subgraph: `t97_l_fix/l_ui/l_rpc/l_db`, `t97_fix`, `t97_ayar`, `t97_ui`, `t97_secici`, `t97_xor`, `t97_rpc`, `t97_kar`, `t97_dry`, `t97_red`, `t97_yok`) — her id tam 1 tanım, tanımsız referans YOK. T-98: 19 id (t98_fa/fb/fc/t98_izinli yeni; `t98_don` silindi, `grep t98_don` mmd+svg = 0) — hepsi tam 1, tanımsız referans YOK. T-100: 17 id (`t100_h3` yeni) — hepsi tam 1, tanımsız referans YOK.
3. **ÇİTLER:** Birleşik dosyada `^```mermaid` = **6** açılış, `^flowchart LR` = **6** başlık [OBSERVED grep -c].
4. **BİRLEŞİK DOSYA:** `runs/2026-09-28-ovsync-takip/diyagramlar.md` — **311 satır**; başlık formatı korundu + "v2 — katalog düzeltmeleriyle hizalı" notu; 6 blok parça dosyalarla birebir (diff -q temiz: T-95/34, T-96/34, T-97/37, T-98/55, T-99/39, T-100/40 satır).
5. **Yazma manifesti:** yalnız 3 hedef dosya + bu rapor yazıldı (`git status --short` yalnız bu yolları gösterir; katalog/plan/önceki DONE'lar okuma-only). Commit yok. Geçiciler `~/tmp/diyagram-fix/`; `/tmp`'ye yazım yok (yanlışlıkla denen `/tmp_c_*.mmd` izin sistemi tarafından engellendi, dosya oluşmadı — teyit: `ls /tmp_c_*.mmd` → no matches).

## 3. Değişen dosyalar

- `runs/2026-09-28-ovsync-takip/diyagram-T95-97.md` (yalnız T-97 bloğu + kaplama notu; T-95/T-96 dokunulmadı)
- `runs/2026-09-28-ovsync-takip/diyagram-T98-100.md` (yalnız T-98/T-100 blokları + notları; T-99 dokunulmadı)
- `runs/2026-09-28-ovsync-takip/diyagramlar.md` (yeniden birleştirildi)
- `runs/2026-09-28-ovsync-takip/diyagram-fix-DONE.md` (bu rapor)

## HÜKÜM: BİTTİ — 3 bulgu düzeltildi, render + statik kontroller kanıtlı.
