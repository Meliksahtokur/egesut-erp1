# DEMO TEST HAZIRLIK — Sahibin lokal yürüyüş rehberi (Ovsync Cila Turu)

- **Tarih:** 2026-09-25 · **Dal:** `ovysch-feature-cila-turu` · **Damga:** `?v=20260925-02` (tek değer, 26 etiket — CONFIRMED `index.html:11,2326`)
- **Amaç:** Bu turda teslim edilen Ovsync cila işlerinin (S1 kısır blok, S2 sessiz sınıflandırma + 🔬 gebelik muayenesi, S3 temizlik RPC + koşumu, S4 navigasyon + yardım katmanı, T1/T5 tutarlılık paketi) **demo DB üzerinde sahibin lokal browser yürüyüşü** için adım adım checklist'i.
- **Kural hatırlatma:** Tarayıcı yürüyüşü sahibindir (ajan koşmaz); ajan kapıları (unit + DB kabul + db-validate) bu daldaki commit'lerle kanıtlıdır. Prod push/merge yok.
- **Kanıt etiketleri:** CONFIRMED (dosya:satır) / OBSERVED (2026-09-25 demo pooler psql, salt-SELECT) / INFERRED / UNKNOWN.

---

## 1. Ortamı kur (5 dakika)

1. **Lokal server'ı worktree'de başlat:**
   ```bash
   cd /home/melik/.herdr/worktrees/egesut-erp1/ovysch-feature-cila-turu
   npm run serve:local        # = python3 -m http.server 8080 (CONFIRMED package.json)
   ```
2. **Demo modunda aç:** `http://127.0.0.1:8080/?demo` — `?demo` localStorage kilidi açar, reload'da kalır; çıkış için `?prod` (CONFIRMED `js/api.js:11-14`). Demo girişi otomatiktir (gömülü kullanıcı `demo@egesut.web` — CONFIRMED `js/api.js:19-20`).
3. **Hard-reload yap** (Ctrl+Shift+R) ve eski sekmeleri kapat: `?v=20260925-02` damgası bu dalın JS'ini taşır; eski-cache karışımı **sahte bulgu üretir** (spec-s4 V-4 dersi). Damga `20260924-01` / `20260925-01` eski-damga karalistesindedir (CONFIRMED `313db91` + `5eb32ff`).
4. **Lokal DNS tuzağı (bilinen):** Tailscale MagicDNS demo alt alan adını NXDOMAIN negatif-cache'leyebilir — tarayıcı "bağlanamıyorum" verirse `resolvectl flush-caches` (BUGS.md BUG-TAILSCALE-DNS, geçici çözüm doğrulandı).
5. **Demo DB kanalı (gerekirse salt-SELECT kontrol için):**
   ```bash
   set -a; . /home/melik/egesut-erp1/.env; set +a   # .env ana checkout'tadır (worktree'de yok)
   PGPASSWORD="$SUPABASE_DEMO_DB_PASSWORD" psql \
     "postgresql://postgres.$SUPABASE_DEMO_REF@$SUPABASE_DEMO_POOLER:5432/postgres?sslmode=require"
   ```
   **KANAL UYARISI (bağlayıcı):** tools-bank `supabase_*` MCP araçları **PROD**'a bakar (ref `zqnexqbdfvbhlxzelzju`) — demo ölçümü sanarak onları çağırma (CONFIRMED `~/tools-bank/mcp_server/server.py` + `js/api.js:23-24`; spec-s1 KANAL KURALI). Alternatif demo yolu: `SUPABASE_DEMO_PAT` ile Mgmt query endpoint.
6. **Unit test istersen:** worktree `node_modules`'ı eksiktir (`fast-check` çözülmez — OBSERVED); `NODE_PATH=/home/melik/egesut-erp1/node_modules npm run test:unit` ile koş (bkz. §5).

---

## 2. Bugünkü demo taban çizgisi (OBSERVED 2026-09-25, salt-SELECT psql)

Canlı veri kayar; yürüyüş sırasında sayılar bir-iki değişebilir. Sınırlar ve kim-nerede bilinmeli:

| Ölçü | Değer | Not |
|---|---|---|
| `sessiz_hayvanlar_listele()` | **9**: 186:57, 168:61, 002:63, 122:66, 149:71, 144:92, Test inek 3:111, 906:9999, 2044:9999 | 173/180/902 listeden DÜŞTÜ (Bekliyor-hariç kuralı); `stat_suru_ozet` sessiz sayısı = 9 (birebir eş — D5 hizalaması) |
| `gebelik_muayene_listele()` | **3**: 902 (55 gün), 173 (57), 180 (92) | 🔬 bandının verisi; `bekliyor_gun DESC` sıralı |
| `ovsync_baslat_uyarilari()` | **`[]` (pencere BOŞ)** | En yakın açık OVSYNC_BASLAT hedefi 2026-10-06 (188); pencere kuralı `hedef ≤ bugün+2` → İlk Tohumlama satırları ~**2026-10-04**'e kadar panelde doğal olarak GÖRÜNMEZ (beklenen davranış, kusur değil) |
| Açık OVSYNC_BASLAT görevi | 29 | Kısır sahipli: 0 |
| Kısır 184/199/208 açık görev | **0 / 0 / 0** | S3 temizlik koşumu 29 kayıt kapattı (2 instance + 27 görev, `kapatan_ref='KISIR_TEMIZLIK'` — OBSERVED + `reports/ureme-temizlik-kosum-2026-09-25.md:32-36`) |
| 188'in açık görevleri | İLAÇ 2026-09-24 · OVSYNC_BASLAT **2026-10-06** · İLAÇ 2026-10-08 · DİĞER 2026-10-13 | Çift zincir **KASITLI** — 188'e dokunma (sahip kararı) |
| Açık SESSIZ-* görev | 168, 186 (2 adet) | Hâlâ gerçek-sessiz → görevleri AÇIK kalması ZORUNLU (S2 kabul A4) |
| Açık GEBELIK_KONTROL görev | 45 — TAMAMI "21./35. Gün gebelik kontrolü" | Eski VWP ailesi; **hiçbiri bu turun `GEBELIK-KONTROL-<id>` kaynağından değil** (demo'da pg_cron yok — `cron.job` şeması yok OBSERVED; muayene görevi üretimi demo'da elle `SELECT public.gebelik_muayene_gorev_uret(false)` ile olur, default `p_dry_run=true` güvenlidir) |
| RPC imzaları (canlı) | `gorev_tamamla(text, text, p_iptal boolean DEFAULT false)` · `sessiz_hayvanlar_listele(p_padok, p_min_gun DEFAULT 50)` · `gebelik_muayene_listele()` · `gebelik_muayene_gorev_uret(p_dry_run DEFAULT true)` · `ureme_temizlik_reconcile(p_dry_run, p_gruplar)` · `tohumlama_sonuc_bos(text,text)` tek imza | S2/T5/S3/T6 hepsi demo'da canlı (OBSERVED pg_proc) |

---

## 3. Yürüyüş checklist'i

> Sıra yukarıdan aşağı; her madde tek gözlem. "Kanıt" sütunundaki çapalar incelemek istersen için.

### A — 🔬 Gebelik Muayenesi Bekleyenler bandı (S2)
- [ ] **A1.** Ana ekranda (Dashboard) kırmızı bant **`🔬 Gebelik Muayenesi Bekleyenler (3)`** — `❗ Sessiz Hayvanlar` bandının TAM ÜSTÜNDE. (CONFIRMED `js/ui.js:312-316`)
- [ ] **A2.** Bant satırları: `902 — 55. gün Bekliyor`, `173 — 57. gün Bekliyor`, `180 — 92. gün Bekliyor`; her satırda "Son tohumlama" tarihi; metin deseni "N. gün Bekliyor". (CONFIRMED `js/ui.js:316`)
- [ ] **A3.** Bir satıra dokun → **hayvan kartı açılır** (satır `openDet` taşır — `js/ui.js:316`); kartı kapat, ana ekrana dön.
- [ ] **A4.** Bant başlığındaki **`Tümünü Gör →`** → sessiz sheet açılır (bkz. B).

### B — Sessiz sheet: muayene bölümü en üstte + 50+ metinleri (S2)
- [ ] **B1.** Sheet'in EN ÜSTÜNDE ayrı `🔬` bölümü (sayaçlı); altında mevcut sessiz grupları (`30+`, `60+`, `90+`, `Hiç kayıt yok`). (CONFIRMED `js/ui.js:1738-1759`)
- [ ] **B2.** Sessiz bölüm alt-metni **"50+ gündür kızgınlık/tohumlama kaydı yok"** — "55+" KALMAMIŞ olmalı. (CONFIRMED `js/ui.js:1759`, eski metin `20260925-01` öncesi)
- [ ] **B3.** Sessiz listede 173/180/902 **YOK** (Bekliyor-hariç kuralı — spec-s2 D1); beklenen 9 kayıt (§2 tablosu). `✕`/backdrop ile kapat.
- [ ] **B4.** `sessiz=0 + muayene>0` uç durumunu denemek istersen: sheet başlığı muayene odaklı düşer, "Sessiz Hayvanlar (0)" DEĞİL (fix `313db91`). (Bugünkü veriyle doğal tetiklenmez — bilgi maddesi.)

### C — Stat kartı (S2)
- [ ] **C1.** Dashboard sağdaki stat kartında **`❗ Sessiz Hayvanlar (9)`** + alt satır **"50+ gündür tohumlama/kızgınlık kaydı yok"** + `Listeyi gör →` linki (sheet'i açar). (CONFIRMED `js/ui.js:2820`) — stat sayısı ile bant sayısı (9) EŞ olmalı.

### D — Protokol paneli: İlk Tohumlama + ? yardım katmanı (S4)
- [ ] **D1.** Üst bardaki **🔔** butonuna dokun → protokol paneli açılır (CONFIRMED `index.html:575`). Rozet sayısı İlk Tohumlama uyarılarını da sayar (CONFIRMED `js/ui.js:428-436`).
- [ ] **D2.** Panelde **`🌱 İlk Tohumlama (0 · önbellek)`** bölümü — pencere BOŞ olduğundan satır YOK (beklenen, §2). (CONFIRMED `js/ui.js:1895,1902`)
- [ ] **D3.** Bölüm başlığındaki **`?`** rozetine dokun → yardım katmanı açılır; 3 madde içermeli: **Ovsynch-56** (4 seanslı program: 1./8./9./10. gün), **TAI** (=başlatma hedefi + 10 gün), **Neden bu hayvan?** (Düve: doğum+12 ay 21 gün; İnek: son doğum/abort+51; görev hedeften 2 gün önce listede). (CONFIRMED `js/ui.js:2023+`, spec-s4 §3.4)
- [ ] **D4.** Yardım katmanını ÜÇ yolla kapat: ✕ butonu, backdrop tap, **geri tuşu**. Geri tuşu seni dash'e ATMAMALI — panel durumunda kal. (CONFIRMED `js/utils/handlers.js` `ovsync-yardim` vakası + `js/app.js` case'i)
- [ ] **D5. (Navigasyon — bugün doğal veriyle GÖRÜLEMEZ.)** "İlk Tohumlama satırına dokun → hayvan kartı açılır; geri tuşu → panel geri gelir" maddesi satır gerektirir; pencere ~2026-10-04'te dolana kadar (188'in 2026-10-06 hedefi) bu satır panelde çıkmaz. Kanıt şu an: sentetik-stub'lı e2e (`tests/modal-router.spec.js` — bu turda RPC-stub şartıyla yazıldı, koşulmadı) + unit testler. **Maddelik değil, bilgi.**
- [ ] **D6. (Bildirim banner — aynı pencere kısıtı.)** Başlat sonrası "🌱 … Hayvan kartına git →" banner'ı da Başlat aksiyonu gerektirir; pencere boşken tetiklenemez. Bilgi.

### E — Görevler: OVSYNC_BASLAT kartı ve Başlat kilidi (S1)
- [ ] **E1.** Alt menü **Görevler** → görev listesinde `188` küpelİ **OVSYNC_BASLAT (hedef 2026-10-06)** kartı: `kisir=false` olduğundan **▶ Başlat butonu normal görünür**. **DOKUNMA — Başlat'a basma:** 188'in çift zinciri KASITLI (sahip kararı; zincir `436fa96` T1 muafiyetiyle korunuyor). Bu madde yalnız "buton kısır olmayanda yerinde" gözlemidir. (CONFIRMED `js/ui.js:1162-1166` bölgesi + §2)
- [ ] **E2. (Kısır rozetini canlıda göremezsin — bilgi.)** `💲 Kısır işaretli — başlatılamaz` / `💲 Kısır işaretli — üreme planı yok` görünümleri yalnız **açık OVSYNC görevli kısır hayvan**da çıkar; S3 temizliği demo'daki üç kısırın açık görevlerini kapattı (§2) → bugün demo'da bu görünüm doğal olarak yok. Kanıt: unit testler + S1-T1..T6 kabul blokları (`1579d0b`, izole koşum PASS). Karttaki kısır rozeti (var olan) hayvan kartında 184/199/208'i açarak görülebilir.
- [ ] **E3.** 184/199/208'in hayvan kartlarındaki görev izlerinde açık senkron zinciri görevi OLMAMALI (Gün1-4/SEANS/TOHUMLAMA_PLANLI kapalı) — temizlik sonrası beklenen.

### F — Erteleme (T-borç sınırıyla birlikte)
- [ ] **F1.** Görevler'de `002` küpelİ **TOHUMLAMA_PLANLI (hedef 2026-09-28)** kartında **🗓️ Ertele** butonuna dokun (CONFIRMED `js/ui.js:1206,1039`) → "🗓️ Tohumlamayı Ertele" modalı; yeni tarih seç (ör. +3 gün) → **Ertele** → yeşil toast; kart yeni tarihe düşer.
- [ ] **F2. (Bilinen sınır — sinyal DEĞİL.)** Erteleme yalnız `TOHUMLAMA_PLANLI`'yı kabul eder; başka tip görev kartında Ertele yoktur / kuralsız görevde `Görev ertelenemez` toast'u çıkar. "Erteleme geneli" bu turda BORÇ (BUGS.md BUG-ERTELEME-KURAL-GENEL — hedef tasarım `gorev_ertele_kural` hibrit, fix yok).
- [ ] **F3.** Geçmiş tarih seçimi → `GECMIS_TARIH` Türkçe hata cümlesi; pencere dışı → `GOREV_ERTELENEMEZ` cümlesi (ham JSON değil). (CONFIRMED `js/ui.js:1058-1059` + kabul U-satırı)

### G — İptal (✕) ve T5 p_iptal
- [ ] **G1.** Herhangi bir açık görev kartında (tercihen önemsiz bir DİĞER/İLAÇ görevi) **✕** → görev iptal olur ve listeden düşer; davranış eskisiyle aynı (UI değişmedi — CONFIRMED `js/ui.js:1190-1199` bölgesi).
- [ ] **G2. (Bilgi.)** T5 ile `gorev_tamamla` üçüncü parametre `p_iptal` aldı (canlı imza §2); online ✕ yolu PATCH kalır, **offline replay** artık `p_iptal=true` ile RPC'ye gider — canlı demo'da offline yolun provasını yapmak istersen: uçağı kapat → bir görevi ✕ → uçağı aç → senkron. `tamamlandi` bayrağı bayat iptal-replay'le flip edilmez (guard `9bcd262`, D1c probe PASS).

### H — Kısır temizlik izleri (S3) — beklenen görüntüler
- [ ] **H1.** Vaka listesinde 184/199/208'e ait üç senkron vakası `Aktif` **görünmeye devam edebilir**: temizlik görev+instance kapatır, `cases` satırına dokunmaz (spec-s3 tasarımı; OBSERVED 3/3 `active`). Zincir görevleri kapalı — bu bilinen/beklenen durum.
- [ ] **H2.** İşlem günlüğünde (islem_log) `UREME_TEMIZLIK` kaydı 1 satır: `snapshot.guncellenen` 29 kayıt. (OBSERVED + `reports/ureme-temizlik-kosum-2026-09-25.md:34`)
- [ ] **H3.** `Sessiz hayvan` görevlerinden 168/186 hâlâ AÇIK görünür (gerçek sessizler); "Sessiz hayvan görevli ama hayvan artık Bekliyor" çelişkisi GÖRÜNMEMELİ (R2 onarımı `e0d2c90` son-tohumlama otoritesine bağladı).

### I — Türkçe hata/özet yüzeyleri (T5/T3/T4/D19 paketi)
- [ ] **I1.** Bir tohumlama kaydını "Boş" sonuçla kapat: hata durumları Türkçe cümle ("Tohumlama bulunamadı" vb. — demo probe kanıtı `D6`); "Boş ata ve uygula" 2-adım akışında yarım-durumda tekrar denenebilir buton.
- [ ] **I2.** Vaka kapanış özeti iptal-görev sayısını da söyler (iki parçalı cümle); hepsi 0 ise standart toast.

---

## 4. Bilinen sinyal gürültüsü ("O15 kırmızıları") — bunlar SİNYAL DEĞİL

> Etiket notu: "O15" orkestrasyon başvurusudur; repoda bu kısa-adın birebir karşılığı yok (UNKNOWN). İçerik olarak bilinen gürültü kümesi aşağıdaki beş kalemdir — yürüyüşte görürsen çalışma-bozukluğu sanma.

1. **3 bilinen birim-test kırmızısı (pre-existing):** `vaka-toplu-ac.test.js` bc-tarih takvim ×2 (ay-bağlı kırılgan) + `degisiklikler-etiketler.test.js` LUNA-3 (demo'da haritasız 7 kolon). Bu dalın regreyonu DEĞİL — baseline'da da aynı üçü düşer (BUGS.md NOT-TEST-TRIAJ-S2; kanıt §5).
2. **İlk Tohumlama bölümünün boşluğu:** pencere kuralı `hedef ≤ bugün+2` → ~2026-10-04'e kadar panelde doğal satır yok (§3-D2/D5). Kusur değil; sunucu penceresinin doğru davranışı (spec-s4 V-5).
3. **45 adet 21./35. Gün GEBELIK_KONTROL görevi:** eski VWP zincirinin üretimi; bu turun 🔬 muayene RPC'siyle ilgisi yok (kaynak kolonu farklı). Kalabalık görünür — beklenen.
4. **Lokal DNS:** Tailscale MagicDNS NXDOMAIN tuzağı → `resolvectl flush-caches` (BUGS.md BUG-TAILSCALE-DNS). Üretim (GitHub Pages) etkilenmez.
5. **Eski-damga cache:** `?v=20260925-01`/`20260924-01` eski sekmeler karışık UI gösterebilir; hard-reload + tek sekme (§1-3).

Ek izleme notu: demo'da pg_cron YOK — `sessiz_hayvanlar_reconcile`/muayene üretimi otomatik koşmaz; bugünkü liste görüntüsü yürüyüş boyunca kendi kendine kaymaz (OBSERVED `cron.job` şeması yok).

---

## 5. Birim test koşum sonucu (bu worktree, 2026-09-25)

- **Komut:** `NODE_PATH=/home/melik/egesut-erp1/node_modules npm run test:unit`
  (worktree `node_modules` eksik → `Cannot find module 'fast-check'` ile 9 dosya düşer — OBSERVED; NODE_PATH ile ana-checkout bağımlılığı çözülür. Ortam notu: sahibin makinesinde ana checkout node_modules'ı referanstır.)
- **Sonuç:** **1112 test / 1109 PASS / 3 FAIL** — üç fail bilinen üçlüdür (§4-1): bc-tarih "gelecek güne tık", bc-tarih "ay ‹/›" (ikisi `tests/unit/vaka-toplu-ac.test.js:2574,2594`), LUNA-3 (`tests/unit/degisiklikler-etiketler.test.js`). **Yeni kırmızı SIFIR.**
- Bu daldan gelen yeni/üza manifestolu testler YEŞİL: `cila-tutarlilik.test.js` (140 satır — T5/U1 replay-dalı dâhil), `ovsync-pg-ui.test.js` +91 (S4 satır-html/yardım/banner), `ui-pure.test.js` (muayene/menü), `nav-geri-karar.test.js` +14 (ovsync-yardim vakası).
- Playwright e2e BANT gereği koşulmadı (sahip yürüyüşü + stub'lı `modal-router.spec.js` ayrıdır). Koşmak istersen: `npm run test:docker:demo`.
- Ham log (geçici): `/home/melik/tmp/cila-unit-run2.log` (tmpfs — kopyalanmadı; sayılar yukarıda kalıcıdır).

---

## 6. Değişen her şey — özet tablo (dal `ovysch-feature-cila-turu`, main'e push/merge YOK)

### DB (7 migration, hepsi demo'ya uygulanmış ve canlı-doğrulanmış; hepsi db-validate kapısından geçti)

| Dosya | İçerik | İlk commit |
|---|---|---|
| `supabase/migrations/20260925000001_ovsync_kisir_blok.sql` | S1: `_acik_disi_hedef_ic` kısır guard + `start_first_service_protocol` KISIR muafiyeti + zamanlayıcı dry-run filtresi + `ovsync_baslat_uyarilari` `kisir` alanı | `414dbf8` |
| `supabase/migrations/20260925000002_sessiz_siniflandirma.sql` | S2: eşik 55→50 (4 yüzey), Bekliyor tam-hariç view, `gebelik_muayene_listele/_uret` + cron bloğu, stat hizalaması | `86665de` |
| `supabase/migrations/20260925000003_sessiz_bekliyor_son_kayit.sql` | v_eligible Bekliyor-hariç filtresinin son-tohumlama otoritesine bağlanması | `e0d2c90` |
| `supabase/migrations/20260925000004_protokol_ayar_guncelle_search_path.sql` | `protokol_ayar_guncelle` SECURITY DEFINER search_path kilidi | `385fcd3` |
| `supabase/migrations/20260925000005_ureme_temizlik_reconcile.sql` | S3: R1/R2/KISIR temizlik RPC (dry-run'lı, silme yok); demo koşumu 29 kayıt kapattı | `8dbbe27` (+`7687fef` KISIR-B 27'ye) |
| `supabase/migrations/20260925000006_cila_t5_gorev_tamamla_p_iptal.sql` | T5: `gorev_tamamla` `p_iptal` + tamamlandi-guard | `cfce742` (+`a4807db`,`9bcd262`) |
| `supabase/migrations/20260925000007_cila_t1_acik_disi_senkron_muafiyet.sql` | T1: `_acik_disi_hedef_ic` açık senkron zinciri muafiyeti (188 korunur) | `436fa96` |

### JS / test / arayüz

| Dosya | İçerik | İlk commit |
|---|---|---|
| `js/ui.js` (+`index.html` damga) | S2 muayene bandı + sheet bölümü + 50+ metinleri (`1daa7a0`); S1 kısır Başlat kilidi (`edb6c08`); S4 satır-navigasyon + M1 metin + ? yardım + banner (`c14cdb6`); escAttr hizalama (`fca5486`) | bkz. sol |
| `js/app.js`, `js/utils/handlers.js` | S4 geri-tuş vakası (`ovsync-yardim`) | `c14cdb6` |
| `js/forms.js`, `js/api.js`, `js/utils/errorHandler.js` | T5 p_iptal replay + Türkçe hata yüzeyleri | `c6e88b2` |
| `supabase/tests/ovsync_pg_kabul.sql` | S1-T1..T6 kabul blokları (izole koşum PASS, OZET 456→475) | `1579d0b` |
| `tests/unit/cila-tutarlilik.test.js` | YENİ — T5/U1 replay + T1/T3-T4/T7-T10 paketi | `c6e88b2` |
| `tests/unit/ovsync-pg-ui.test.js`, `ui-pure`, `nav-geri-karar`, `vaka-toplu-ac`, `modal-router.spec.js` | S4/S2 test zarfları (e2e stub'lı yardım-sheet testi dâhil) | `c14cdb6`/`1daa7a0`/`313db91`/`2a57486` |

### Doküman / borç kaydı

| Dosya | İçerik | Commit |
|---|---|---|
| `BUGS.md` | 6 yeni kayıt: erteleme-geneli, kuyruk-şema (T9), kısır-gebe otorite notu, db-validate borçları, S2 review temizlik devri, test-triaj; + v_eligible Gebe-son-kayıt, view-listele asimetrisi, escAttr kalan noktalar, son-tohumlama inline kopya | `2d4b466`,`f330a6d`,`3e34a7f`,`5c33211` |
| `docs/plans/2026-09-24-ovsync-cila/` | 5 spec + 5 plan + ölçüm raporu + 3 onarım kaydı + taslak-S2 migration | `c2348b1`→`5c33211` arası |
| `.harness/references/rpc-reference.md` | `ureme_temizlik_reconcile` + çapa tazelemeleri | `f62eeec` |
| `reports/ureme-temizlik-kosum-2026-09-25.md` (ana checkout reports/) | S3 onaylı koşum kanıtı (29 kayıt) | koşum zarfı |
| **Bu dosya** | Sahibin yürüyüş rehberi + test koşum kanıtı + teslim tablosu | (bu commit) |

Dal geneli: main'den 42 commit ileride; 38 dosya, +6826/−84 satır (`git diff main...HEAD --stat`, 2026-09-25).

---

## 7. Son review kapısı (sahip isteği — iş bittikten sonra)

Yürüyüş tamamlandıktan sonra dal, ayrı bir review koşumundan geçecek (sahibin isteği). Review'ın karşılaştıracağı zarf: her spec'in "Dokunulacak dosyalar — TAM liste" bölümleri (spec-s1 §5, spec-s2 §4, spec-s3, spec-s4 §4, spec-s5); zarf-dışı dosya = RED kuralı (spec-s2 §7-C4). Bu rehberdeki §6 tablosu zarf özetidir. Bir sorun görürsen yürüyüşte: bulgu satırını (bölüm-harf + madde) not et — review zarfına girdi olur.

*Rehber sonu. Yalnız `docs/plans/2026-09-24-ovsync-cila/demo-test-hazirlik.md` yazıldı; `tests/` altına yeni betik eklenmedi (mevcut süit + stub'lı modal-router e2e yeterli; sahibin yürüyüşü elle yapılır) — mevcut süite dokunulmadı.*
