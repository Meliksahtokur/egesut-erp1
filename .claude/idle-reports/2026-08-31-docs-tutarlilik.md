# Kod–Doküman Tutarlılık Denetimi — 2026-08-31

> **Read-only denetim.** Kod yazılmadı, doküman değiştirilmedi, Supabase'e yazılmadı.
> Yöntem: 4 paralel subagent (RPC, domain kuralları, roadmap, ID tipleri) + orkestratör
> spot-check doğrulaması (gorev_log/islem_log/stok_hareket DDL, roadmap dosyaları, js/utils
> doğrudan grep ile teyit edildi).
> Kanıt gösterimi: `GT` = `supabase/migrations/99999999999999_ground_truth.sql`.

---

## Yönetici Özeti

| Çift | Denetlenen | Tutarlı | Tutarsız | En kritik bulgu |
|---|---|---|---|---|
| rpc-reference.md ↔ js RPC çağrıları | 50 dokümante RPC / ~120 çağrılan | 47 eşleşme | 4 param + 3 not + 3 ölü girdi + **73 doc'ta yok** | `buildRpcParams` offline replay imzaları canlı RPC'lerle çelişiyor (kod bug'ı) |
| domain-rules.md ↔ kod | 60 kural | 41 eşleşti | 8 çelişki + 8 bayat | Erkek↔grup backend guard'ı YOK (doc "backend de kontrol eder" diyor) — kod eksiği |
| ReFactorRoadmap ↔ kod | ~31 öğe | 12 doğrulandı | 3 "bekliyor ama yapılmış" + 4 "tamam ama eksik" | Kök `ReFactorRoadmap.md` silinmiş; AGENTS.md kırık referans veriyor |
| AGENTS.md ID tablosu ↔ migrations | 9 tablo | 6 MATCH | **3 MISMATCH** | `gorev_log` gerçekten **uuid**; AGENTS.md'deki "text, cast gerekmez" kılavuzu canlıda `uuid = text` hatası üretir |

**En kritik 5 sonuç (özet):**
1. **AGENTS.md ID tablosunda 3 tablo ters yazılmış** (gorev_log, stok_hareket, islem_log) — dördüncü agentın
   bağımsız bulgusu orkestratör tarafından GT:48, GT:2006, GT:39'dan doğrulandı. Dokümandaki INSERT/WHERE
   cast kılavuzu yanlış premise üzerine kurulu.
2. **İki kod-taraflı bug adayı** (doc değil): (a) erkek hayvan↔grup kontrolü yalnız frontend'de, backend RPC'lerde
   yok; (b) `dogum_kaydet`'te ileri doğum tarihi backend kontrolü yok; (c) bonus: `js/ui.js:6725-6809`
   `buildRpcParams` (offline replay) parametre setleri canlı RPC imzalarıyla uyuşmuyor.
3. **rpc-reference.md ~120 çağrılan RPC'nin sadece 50'sini dokümante ediyor** (73 eksik); 4 dokümante imza bayat.
4. **domain-rules.md'in doğum/protokol bölümleri Haziran–Temmuz 2026 revizyonlarını yakalamamış**
   (14→16 görev, PG d11→d39, Yeldif→E Vitamini, "Pasif" durum değeri yok). "Sessiz hayvan" ve "abort VWP"
   bölümleri ise tam güncel.
5. **ReFactorRoadmap kök dosyası commit `1a80118` ile silinmiş**; otorite kopya `.claude/ReFactorRoadmap.md`
   (untracked, git'siz). AGENTS.md:196 hâlâ kök dosyaya referans veriyor.

---

## 1. `.claude/rpc-reference.md` ↔ `js/*.js` RPC Çağrıları

### 1.1 Özet

- Doküman: 51 girdi / **50 benzersiz RPC** (`geri_al` iki kez yazılmış). Git takibinde **değil** (`??`) — tarihçesi doğrulanamaz.
- Kod: ~120 benzersiz RPC çağrısı (`rpc()` sarmalayıcı + `rpcOptimistic` + doğrudan `db.rpc` + offline replay).
- Eşleşme: 47. A (doc'ta yok): 73 · B (kodda çağrılmıyor): 3 · C (param uyuşmazlığı): 4 · D (not çelişkisi): 3.

### 1.2 [C] Parametre uyuşmazlıkları — 4 bulgu (doğru taraf: **kod + canlı DB**; doc güncellenmeli)

| # | RPC | Doc diyor | Kod/DB diyor | Kanıt |
|---|-----|-----------|--------------|-------|
| C1 | `hayvan_ekle` | `p_padok` | imzada **hem** `p_padok text` hem `p_padok_id uuid` var; kod `p_padok_id` geçiyor | doc:10; js/forms.js:123; GT:7124-7139; migration 20260511000003 (commit e1b6a87) |
| C2 | `hayvan_guncelle` | `p_padok`, `p_kisir` yok | kod `p_padok_id` + `p_kisir` geçiyor; DB'de ikisi de var | doc:13; js/forms.js:90,99; GT:8218+; migration 20260513000005 (commit b000700) |
| C3 | `add_drug_administration` | `p_drug_id` param adı | DB'de `p_drug_id` **yok** → `p_drug_product_id uuid, p_stok_id text`; kod böyle çağırıyor | doc:110; js/ui.js:5806-5807; GT:892 |
| C4 | `hekim_ekle` | `(p_id, p_ad, p_telefon?)` | DB imzası 2 param: `(p_ad text, p_telefon text DEFAULT NULL)`; kod p_id geçmiyor | doc:185; js/ui.js:6867; GT:1346 |

**Öneri:** Doc dört imza da canlı `pg_get_functiondef` çıktısıyla eşitlenmeli. Migration commit'leri (e1b6a87, b000700)
"yeni niyet" tarafının kod+DB olduğunu kanıtlıyor.

### 1.3 [B] Dokümante ama js'te hiç çağrılmayan — 3 bulgu (silmeden önce doğrula)

| RPC | Doc satırı | Durum | Öneri |
|---|---|---|---|
| `hastalik_kaydet` | 57 | Legacy; DB'de mevcut | "(frontend kullanmıyor — legacy)" notu, silme |
| `tedavi_guncelle` | 79 | Legacy; `tedavi_ekle`/`tedavi_sil` çağrılıyor (forms.js:1509,1531) | aynı not |
| `case_plan_notu_guncelle` | 107 | DB'de var (GT:4682 GRANT), js çağrısı yok | kullanım eklenecek ya da "kullanılmıyor" notu |

Kendini açıklayan (bulgu değil): `_ayar` (internal), `sessiz_hayvanlar_reconcile`/`gorev_orphan_temizle`/`agent_threads_prune` (cron),
`asistan_sql_calistir`/`asistan_hayvan_detay` (Edge Function — `supabase/functions/ai-agent/tools.ts:16,31,53`).

### 1.4 [D] Doc notu kodla çelişiyor — 3 bulgu

**D1. "Asla doğrudan db.from().insert/update kullanılmaz" yanlış** — doc:4.
Kod: `js/api.js:191` (`db.from(table).update`), `js/api.js:199` (`db.from(table).insert`) — `dbUpdate`/`dbInsert`, offline kuyruk
senkronu (`syncNow`, api.js:458-482) tarafından kullanılıyor.
**Doğru olan:** kod (offline-first mimari gereği). Doc cümlesi "online yazma yolu RPC'dir; offline kuyruk replay senkronu
db.from PATCH/POST kullanır" şeklinde düzeltilmeli.

**D2. `{ok:false}` dönüş notu vs `rpc()` sarmalayıcısı** — doc:3,30 "RPC `{ok:false}` döner".
Kod: `js/api.js:76` — sarmalayıcı `ok:false`'u asla döndürmez, `Error` fırlatır. Sonuç: `rpc()` sonrası `if (!res.ok)` desenleri
ölü kod: js/forms.js:1238; js/ui.js:4168, 6867, 6982, 7043, 7060, 7746.
**Doğru olan:** ikisi de, farklı katmanlarda — DB düzeyinde doc doğru; doc'a "rpc() sarmalayıcısı ok:false'ı Error'a çevirir"
notu eklenmeli; ölü `if(!res.ok)` desenleri ayrı temizlik görevi olmalı.

**D3. `geri_al` dokümanda iki kez girdi** (satır 46-48 ve 179-180, aynı imza). Tek girdiye indirilmeli.

### 1.5 [A] Kodda çağrılan ama doc'ta olmayan 73 RPC (doğru taraf: kod; doc'a eklenmeli)

Alan bazında temsilî çağrı noktalarıyla:

- **Üreme (13):** `planli_tohumlama_kaydet` (forms.js:283), `tohumlama_tekrar_kaydet` (365), `tohumlama_geri_al` (1289),
  `gebelik_kaydet_manual` (1432), `gebelik_protokol_kontrol` (ui.js:162), `hayvan_belirsiz_ureme_listele` (ui.js:956),
  `hayvan_tohumlanabilir_onayla` (forms.js:828), `hayvan_tohumlama_ertele` (841), `kizginlik_sil` (ui.js:341),
  `kizginlik_vaka_ac` (2595), `kizginlik_yok_kaydet` (319), `kizginlik_tedavi_baglanti_kur` (forms.js:580), `vaka_tohumlama_ekle` (ui.js:5661)
- **Hayvan (4):** `cikis_yap` (forms.js:678), `hayvan_genc_anne_isaretle` (104), `hayvan_genc_anne_isaretle_toplu` (ui.js:1012), `kupe_musait_mi` (forms.js:41)
- **Görev (9):** `gorev_tamamla` (forms.js:1017; param `{p_gorev_id, p_padok_hedef}`), `gorev_guncelle` (1085), `gorev_geri_al` (ui.js:4990),
  `islem_geri_al` (2066), `besleme_tamam` (461), `hizli_uygulama` (1261), `hizli_uygulama_geri_al` (1310), `protokol_eksik_tara` (300), `padok_transfer_gorev_uzlastir` (310)
- **Vaka/Tedavi (14):** `delete_treatment_day` (5867), `treatment_day_not_guncelle` (5493), `update_drug_administration` (5923),
  `remove_drug_administration` (5857), `remove_treatment_session` (8105), `update_treatment_session` (8152),
  `add_sessions_to_existing_day` (8200), `tedavi_sablon_kaydet` (3949), `tedavi_sablon_sil` (3712), `tedavi_sablon_uygula` (forms.js:555),
  `tedavi_sablon_tohumlama_gorev_ekle` (556), `disease_ekle`/`guncelle` (ui.js:3373), `disease_sil` (3381)
- **Aşı (6):** `add_vaccination` (forms.js:988), `bulk_vaccination` (1629), `asi_ekle`/`asi_guncelle` (1916/1914),
  `ileri_gebe_asi_tamamla` (ui.js:4888), `vaccination_dismiss` (384), `vaccine_rapel_guncelle` (~6857)
- **Hekim/Padok (9):** `hekim_listesi` (app.js:30), `hekim_guncelle` (ui.js:6982), `hekim_sil` (6995), `padok_ekle` (7746),
  `padok_guncelle` (7043), `padok_sil` (7060), `padok_degistir` (7685), `padok_degistir_toplu` (7528), `grup_padok_eslem_toggle` (7735)
- **Stok/İlaç (7):** `stok_ekleme` (forms.js:1343), `stok_arsivle` (ui.js:4184), `stok_duzelt` (4197), `ilac_ekle` (forms.js:1388),
  `link_drug_to_stock` (1544), `bulk_ilac` (1709), `stok_hareket_ekle` (ui.js:6678 — yalnız offline replay yolu)
- **Kategori/Seed (3):** `kategori_ekle`/`kategori_guncelle` (ui.js:3993), `kategori_sil` (4001), `seed_defaults` (3401)
- **AI Asistan (3):** `asistan_plan_iptal` (ai-asistan.js:280), `asistan_plan_geri_al` (298), `asistan_tumunu_sil` (385)
- **Demo (2):** `demo_klonla` (demo.js:16), `demo_sema_diff` (29)
- **İstatistik (1):** `stat_suru_ozet` (ui.js:1471)

### 1.6 İlgili KOD bulgusu (doc tutarlılığı değil — bug adayı)

**`buildRpcParams` (js/ui.js:6725-6809, offline replay) bayat imzalarla çalışıyor:**
`hayvan_ekle` → `p_grup_id`/`p_irk_id` (DB'de yok) · `hayvan_guncelle` → `p_alan`/`p_deger` (yok) ·
`tohumlama_kaydet` → `p_sperma_kodu`/`p_teknisyen` (yok) · `dogum_kaydet` → `p_buzagi_cinsiyet`/`p_buzagi_kupe`
(DB'de `p_kupe`/`p_cins`) · `create_case` → `p_hayvan_id`/`p_tanis`/`p_tarih` (DB'de `p_animal_id`/`p_disease_id`/`p_notes`) ·
`add_drug_administration` → fazladan `p_time`. Bu kuyruk replay yolu tetiklenirse RPC'ler parametre hatasıyla patlar.
**Doğru taraf: canlı DB imzaları; kod düzeltilmeli.**

### 1.7 Doğrulanmış eşleşmeler (47)

Üçlü (doc + kod + GT) birebir doğrulandı. Örnekler: `tohumlama_kaydet` (p_vwp_override + VWP dipnotu dahil, forms.js:283-290),
`tohumlama_abort` (forms.js:613-617), `dogum_kaydet` (forms.js:165-173), `kizginlik_kaydet` (417-422), `create_case` (542-545),
BUG-059 seti (`add_treatment_day_with_sessions` api.js:572, `seans_tamamla` 589, `recete_guncelle` 605, `close_case_with_remaining` 619,
`treatment_day_tamamla` ui.js:4858 idempotent notuyla), sütten kesme 4'lüsü, `sessiz_hayvanlar_listele` (9999 sentinel notu dahil, ui.js:940),
`geri_al` (forms.js:1302), `irk_listesi`, `stok_ekle`, `hayvan_not_ekle`, `hastalik_guncelle/kapat/sil`, `tedavi_ekle/sil`,
`update_treatment_time`, `close_case`, `drug_class_*` 4'lüsü. Doc satır 44 notu ("legacy `abort_kaydet` frontend kullanmaz") doğru.

---

## 2. `.claude/domain-rules.md` ↔ Koddaki Gerçek Davranış

### 2.1 Özet

60 checkable kural: **41 ✅ eşleşti · 8 ❌ çelişti · 8 ⚠️ bayat/belirsiz · 3 ❓ doğrulanamıyor.**
"Sessiz hayvan takibi" ve "abort VWP" bölümleri tam güncel; bayatlık ağırlıklı olarak **Bölüm 5 (doğum postpartum protokolü)**,
**Bölüm 9-10 (sütten kesme / çıkış)** ve **Bölüm 11-12 (islem_log/gorev_tipi listeleri)**'nde.

> Metodoloji notu: GT 2026-06-25'te üretildiği için içindeki bazı fn tanımları eski; kanonik doğrulama son
> migration'lara göre yapıldı (`dogum_kaydet`: 20260730000002, `cikis_yap`: 20260706000003, `tohumlama_*`: 20260830000034).

### 2.2 Çelişkiler (❌) — 8 adet

| # | Doc diyor (satır) | Kod yapıyor | Kanıt | Hangisi doğru |
|---|---|---|---|---|
| 1 | `dogum_kaydet` **14 görev** üretir (128) | **16 görev**; `"gorev_sayisi", 16` | 20260730000002:407-417,443 | **kod** — doc güncellenmeli (Oksitosin/Ademin/Kalsiyum 3 ayrı görev) |
| 2 | Postpartum PG: d11 (138) | **d2·d25·d39** (Presynch-14); d11 Haziran sonunda kaldırıldı | 20260730000002:412-414; 20260628000001:3 | **kod** |
| 3 | "53. Gün: Ademin + Yeldif", "54. Gün: Yeldif" (140-141) | d53 = Ademin + **E Vitamini** (etken_kod E_VIT); **d54 görevi yok** | 20260730000002:415-416, 358-359, 43-44; commit 978e018 | **kod** — doc satır 141 silinmeli ("Yeldif" ürün değil E vit sınıfı) |
| 4 | Buzağı padok: "Buzağı Ahırı" (131) | **"Buzağı Padok (Süt İçenler)"** | 20260730000002:401; 20260326000026:7 | **kod** |
| 5 | Sütten kesme `tohumlama_durumu='tohumlanabilir'` **yazar** (203) | yalnız `suttten_kesme_tarihi` yazar; `tohumlama_durumu` hiçbir sütten kesme RPC'sinde yazılmıyor | 20260620000003:47; commit 6e41b94 | **kod** — flag tabanlı yaklaşım terk edildi |
| 6 | Çıkışta `durum='Pasif'` (210) | `'Pasif'` değeri kod tabanında **hiç yok** (0 grep); olum→'Ölü', satis→'Satıldı', kesim→'Kesildi', kayip→'Kayıp' | 20260706000003:191-201 | **kod** — davranışsal sonuç (listelerde görünmez) doğru, değer adı yanlış |
| 7 | Erkek↔sağmal/gebe grubu kontrolü "**backend ve frontend** her ikisi de" (31, 246, 248) | Frontend ✓ (app.js:280-304); **backend RPC'lerde cinsiyet↔grup kontrolü yok** (hayvan_ekle/guncelle yalnız yaş-grup; padok_degistir yalnız grup↔padok eşlemi) | 20260706000006:48-88,137-161; GT:7400-7470 | **KOD EKSİĞİ (bug adayı)** — REST'ten hayvan_ekle ile bypass edilebilir; ya backend guard eklenmeli ya doc dürüstleştirilmeli |
| 8 | Bölüm 14 DEFAULT farm_id `'400b9107-a85e-4126-fd7fe73fb68e'` (269) | `400b9107-a85e-4126-af2c-fd7fe73fb68e` — doc'ta `af2c-` segmenti eksik, **geçersiz UUID** | 20260701214717:12; farm-id-discipline.md:15,32; doc'un kendi satır 263'ü de doğru | **migration** — tipografi hatası düzeltilmeli |

### 2.3 Bayat / belirsiz (⚠️) — 8 adet

1. **75 gün sınırı kodda yok** (doc 43-44, 55-56): `app.js:287-288,297-298` — 0-180 gün penceresinde iki grup da seçilebilir;
   sütten kesme tetikleyicisi 60. günde ateşleniyor (20260513000002:29). → Tablo 0-180 olarak sadeleştirilmeli ya da "öneri, uygulanmıyor" etiketi.
2. **GRUP_PADOK'ta 'Gebe İnek' eksik** (doc 20-29, 8 grup): config.js:51 + 20260511000001:46 — canlıda 9 grup.
3. **Hastalık kategori tablosu eksik**: config.js:23-32'de ek olarak 'Sindirim', 'Diğer' var; 'Beyaz Çizgi' → 'Beyaz Çizgi Hastalığı'.
4. **"Lokasyon bazı kategoriler için zorunlu" (195)**: config.js:34-38 'Göz'ü de içeriyor; yaptırım yok — forms.js:1192 boş geçilebilir,
   backend'de RAISE yok. "Zorunlu" ifadesi karşılıksız.
5. **islem_log tip listesi eksik** (219-229): kodda ek olarak `TOHUMLAMA_OTOMATIK_BOS`, `VWP_OVERRIDE`, `SUTEN_KESME`,
   `HASTALIK_GUNCELLENDI`, `padok_degisim`, `TEDAVI_GUNCELLENDI`, `GOREV_EKLENDI/GUNCELLENDI`, `VAKA_ACILDI`.
6. **`TOHUMLAMA_GUNCELLENDI` artık üretilmiyor** (doc 222): 20260830000030:29-37 — 2026-08-30'dan beri trigger UPDATE'lerde sessiz.
   Doc satır 223'teki ABORT_KAYDI üreticisi de trigger değil `tohumlama_abort` RPC'si (20260830000034:46).
7. **gorev_tipi listesi bayat** (doc 236: `ILAC, BUZAGI_BAKIM, TOHUMLAMA_HAZIRLIK, DIGER`): gerçekte `GEBELIK_KONTROL`
   (TOHUMLAMA_HAZIRLIK'ın yerini aldı, 20260830000010:185), `ILERI_GEBE`, `BESLEME`, `SUTTEN_KESME`, `PADOK_DEGISIM`,
   `TOHUMLAMA_PLANLI`, `TEDAVI_GUN`/`TEDAVI_SEANS`, `VETERINER_KONTROL`, `KIZGINLIK_TAKIP`. CHECK kısıtı da yok (GT:51).
8. **"Doğum tarihi ileri tarih olamaz" backend'de yok** (doc 153, 251): frontend ✓ (forms.js:155); `dogum_kaydet`'te kontrol yok
   (hayvan_ekle/guncelle ve tohumlamada var: 20260706000006:51-54; 20260830000010:93-95). → **kod eksiği adayı** ya da doc netleştirilmeli.

### 2.4 Eşleşenler (✅) — 41 kural (özet)

Kimlik/kupe (3), grup↔padok eşlemi guard'ları (2), yaş-grup pencereleri frontend+backend birebir (7), tohumlama önkoşulları +
VWP 55g + override + abort-VWP (15), doğum akışı + buzağı 6 alt görevi (7), gebelik/abort durum makinesi (4), kızgınlık (3),
sağlık vaka kuralları (2), sütten kesme bireysel/toplu (2), çıkış 4 neden + sonrası yazma yasağı (2), görev parent/child (2),
farm_id + RLS tek-tenant (2), Bölüm 13 K2/K3/K6/K7 (2). **Özellikle:** sessiz hayvan ankrajı (max of 5 event), 55g penceresi,
düve 13ay+55g, 9999 sentinel sıralama (RPC COALESCE + ui.js:215,940) — doc'un 2026-08-31 tarihli sessiz bölümü kodla birebir.

### 2.5 Doğrulanamayanlar (❓) — 3

"21 günlük kızgınlık döngüsü" (saf domain bilgisi), "ref_id migration 016+ sonrası dolu" (canlı veri iddiası),
Bölüm 13 K8 "REST PATCH bypass" (canlıda test gerekir; 20260516000001 mekanizmayı destekliyor).

---

## 3. ReFactorRoadmap ↔ Kodun Güncel Durumu

### 3.1 Dosya durumu (önce)

| Dosya | Durum |
|---|---|
| `ReFactorRoadmap.md` (kök) | **YOK** — commit `1a80118` ("repo temizliği") ile silindi |
| `.claude/ReFactorRoadmap.md` | **Otorite** — silinen kök dosyanın birebir kopyası (md5 aynı), untracked, ilerleme tablosu 2026-06-13 |
| `.claude/RefactorRoadmap.md` | Farklı içerik: Mart 2026 tarihli ilerleme **günlüğü** (1889 B), yol haritası değil |

### 3.2 "Bekliyor" işaretli ama kodda YAPILMIŞ — 3 bulgu (doğru taraf: kod; roadmap güncellenmeli)

1. **Aşama 3 "⏸️ RİSKLİ → BEKLİYOR (event delegation ~150 handler)"** (satır 200) — delegation **kurulmuş**:
   `js/utils/events.js:1-61` (5 merkezi listener: data-action/input/focus/keydown/change), `js/utils/handlers.js`'te
   **277 kayıtlı handler**, index.html'de 283 `data-*` attribute vs 17 inline onclick (events.js+handlers.js index.html:2009,2019'de yüklü).
   Kalan gerçek boşluklar: 3.1 virtual scroll, 3.3 modal sınıfı, 3.4 toast kuyruğu — satır bölünmeli.
   (Not: js/ui.js dinamik HTML'inde kalan 212 onclick bilinçli — AGENTS.md modal-router kuralı attribute onclick istiyor.)
2. **1.4 "acHdeTani/acDisease dönüşümü BEKLİYOR"** (satır 198) — bu fonksiyonlar artık **yok**: acDisease silinmiş
   (ui.js:6526 dead-code notu), acHdeTani 0 eşleşme. `setupAutocomplete` (helpers.js:41) mevcut ama **çağıran yok** (dead infra).
   Kalan gerçek iş: 5 `ac*` fonksiyonu (acHdiStok/acSperma/acIlac/acDilacSatir/acHayvan, ui.js:5966-6382) ya da dead-code temizliği.
3. **1.1 "13 global hala app.js:81'de"** (satır 195) — `_A/_S/_curPg` artık yok (0 eşleşme); kalan ~12 global app.js:48-60,451,486,655'te.
   "Kısmen" doğru, örnekler ve satır referansı bayat.

### 3.3 "Tamam" işaretli ama kodda EKSİK/DEĞİŞMİŞ — 4 bulgu

1. **Aşama 2 "✅ DONE — insertOffline/updateOffline"** (satır 199) — bu fonksiyonlar kodda **yok** (0 eşleşme). Git: `5cf33c1`
   ekledi → `a71a5e4` (2026-05-23) bilinçli dead-code kaldırma. 2.2 exponential backoff da yok (api.js:458-479 hatada `break`).
   **Doğru taraf: kod** (bilinçli karar); roadmap gerekçesiyle güncellenmeli.
2. **Aşama 8 "JSDoc ✅"** (satır 205) — JSDoc yalnızca 6 yerde (api.js:58,557,580,596,611; helpers.js:36); 8.2'nin adını verdiği
   `openDet`/`loadDash` JSDoc'suz. "✅" → "api.js'te kısmi" olmalı.
3. **Aşama 9 "✅ DONE"** (satır 206) — 9.2 **CONTRIBUTING.md yok** (README.md var, gerekçeyi karşılıyor).
4. **Aşama 5 sayıları bayat** — "8865 satır" → GT bugün **11426 satır**; "41/12/165" → bkz §4.5.

### 3.4 Doğrulanan tutarlı öğeler

1.2 sabitler→config.js (config.js:7-91, duplikat yok) · 1.3 helpers/modal (utils/helpers.js + utils/modal.js:4,53,72; index.html:2006-2008) ·
2.3 IndexedDB index'leri (api.js:102-112, iddia edildiği gibi) · 2.4 rpcOptimistic (api.js:421) · 4 hata yönetimi (errorHandler.js:23;
app.js:577,636; global dinleyiciler) · 6 esc() "test gerekli" notu makul · 7 debounce/throttle (helpers.js:96,101) ·
8.1 ESLint/Prettier (`.eslintrc.json` — roadmap `.eslintrc.js` diyor, kozmetik) · 9.1 README · Faz 2 farm_id foundation (20260701214717) ·
AGENTS.md'in "1.3 done / 1.4 bekliyor" özeti roadmap tablosuyla tutarlı.

### 3.5 Bağlantılı dokümantasyon sorunları

- **AGENTS.md:196 kırık referans:** Key Dosyalar tablosu kök `ReFactorRoadmap.md`'yi gösteriyor; dosya silinmiş. Referans
  `.claude/ReFactorRoadmap.md`'ye güncellenmeli ya da dosya köke geri döndürülmeli ve commit'lenmeli (şu an untracked = kayıp riski).
- **CLAUDE.md:299 ciddi biçimde bayat:** "1.3❌ 1.4❌, Aşama 2-9 bekliyor" — kod ve roadmap ile çelişiyor (1.3 yapılmış, 2/4/5/7/8 DONE).
  CLAUDE.md'ye bu denetim kapsamında dokunulmadı (yasak); kullanıcı bilgilendirilmeli.
- `.claude/RefactorRoadmap.md` (Mart günlüğü) → `.claude/archive/` önerisi. İçindeki tek özgün borç kaydı:
  "`HASTALIK_LISTESI` hardcoded — ileriki aşamalara bırakıldı" (satır 24-25), ana roadmap'te karşılığı yok.
- AGENTS.md Stack satırı yalnız 6 js dosyası sayıyor; `js/utils/` (5 dosya), `auth.js`, `demo.js`, `ai-asistan.js` listede yok.

---

## 4. AGENTS.md ID-Tip Tablosu ↔ Migration Dosyaları

### 4.1 Eşleşme tablosu (orkestratör tarafından GT'den yeniden doğrulandı)

| Tablo | AGENTS.md iddiası | GT gerçek | Sonuç |
|---|---|---|---|
| `hayvanlar` | text | `id text PRIMARY KEY` (GT:8) | ✅ MATCH |
| `stok` | text | `id text PRIMARY KEY` (GT:31) | ✅ MATCH |
| `hekimler` | text | `id text PRIMARY KEY` (GT:7059) | ✅ MATCH |
| `tohumlama` | text | `id text PRIMARY KEY` (GT:116) | ✅ MATCH |
| `gorev_log` | **text** | **`id uuid PRIMARY KEY DEFAULT gen_random_uuid()`** (GT:48-49) | ❌ MISMATCH |
| `stok_hareket` | **uuid** | **`id text PRIMARY KEY`** (GT:39-40) | ❌ MISMATCH |
| `padoklar` | uuid | `id uuid DEFAULT gen_random_uuid()` (GT:6968) | ✅ MATCH |
| `vaccines` | uuid | `id uuid` (GT:5361) | ✅ MATCH |
| `islem_log` | **uuid** | **`id text PRIMARY KEY DEFAULT gen_random_uuid()::text`** (GT:2006-2007) | ❌ MISMATCH |

### 4.2 MISMATCH'ler — "hangisi doğru" (üçünde de: **migration/GT doğru, AGENTS.md güncellenmeli**)

1. **`gorev_log` = uuid.** Orijinal `20260303000001:39`'da text idi; tip canlıda değiştirilmiş (commit'lenmiş ALTER yok —
   GT 2026-06-25 canlı onarımıyla güncel). Dört bağımsız migration yorumu uuid diyor (20260513000006:3, 20260509000003:5,
   20260603000005:6, 20260604000002:16). INSERT'ler plain `gen_random_uuid()` kullanıyor (20260306000008:127-132).
   **Sonuç:** AGENTS.md'de gorev_log uuid listesine taşınmalı; "WHERE text=text cast GEREKMİYOR" notu **silinmeli** —
   tam tersine text parametreyle karşılaştırmada `::uuid` cast **gerekli**. Bu yanlış kılavuzun canlıda gerçek hata ürettiğinin
   kanıtı: `20260830000032_geri_al_uuid_fallback.sql:1` "(operator does not exist: uuid = text)" başlığı ve
   `20260604000002_gorev_dinle_uuid_fix.sql` (tam olarak bu bug'ı düzelten migration).
2. **`stok_hareket` = text.** initial_schema:30 + GT:40 hemfikir; doc'un uuid iddiasının hiçbir kaynağı yok.
   JS tarafındaki tek doğrudan yazma da text kolonla tutarlı (`crypto.randomUUID()` string, ui.js:6172).
3. **`islem_log` = text** (`gen_random_uuid()::text` DEFAULT ile). faz1_core:106 + GT:2007 hemfikir. AGENTS.md'deki
   "uuid kolona `::text` YAPMA" kuralı bağlamında netleştirilmeli: `gen_random_uuid()::text` **tam olarak bu tablonun**
   canonical INSERT pattern'idir (ör. 20260730000002:137-139 — aynı fonksiyonda gorev_log'a plain uuid, islem_log'a ::text).
   Yani AGENTS.md'in "gorev_log.id text ama UUID string saklar" cümlesi büyük olasılıkla **islem_log** için yazılmış ve
   yanlış tabloya iliştirilmiş.

### 4.3 Liste eksikleri (doc 9/40 tablo)

- **Belgelenmemiş text-id (5):** `hastalik_log` (GT:101), `kizginlik_log` (1913), `irk_esik` (1963), `bildirim_log` (1985), `cop_kutusu` (2035) — son üçü `gen_random_uuid()::text` pattern'i.
- **Belgelenmemiş uuid-id (22):** `uygulama_log`, `protokol_dismiss`, `dogum`, `tedavi`, `agent_plans`, `stok_kategorileri`,
  `drug_classes`, `drug_products`, `diseases`, `drugs`, `cases`, `treatment_days`, `drug_administrations`,
  `treatment_day_uygulamalar`, `tedavi_sablonu`, `sablon_hastalik_eslem`, `tedavi_sablonu_kalem`, `vaccination_schedule`,
  `vaccine_protocol_steps`, `vaccination_log`, `grup_padok_eslem`, `protokol_instance` (GT satırları kayıtlı).
- **Özel PK (4):** `ui_logs` (bigint/bigserial), `hayvan_override` (PK `kupe_no`), `vaccine_diseases` (composite PK), `protokol_ayar` (PK `anahtar`).

Öneri: 9 tabloluk kısmi liste yerine GT'den üretilmiş tam tip listesi ya da "INSERT kuralı için GT dosyasına bak" yönergesi.

### 4.4 gorev_log INSERT pattern doğrulaması

JS gorev_log'a doğrudan INSERT yapmıyor (RPC üzerinden: forms.js:1017 gorev_tamamla, ui.js:4798). Doc'taki
"`gen_random_uuid()::text` veya `gen_random_uuid()`" ikili önermesi yanlış premise'den türetilmiş; doğru kural:
uuid kolon → plain `gen_random_uuid()`, text kolon → `gen_random_uuid()::text`.

### 4.5 Sayım doğrulaması (AGENTS.md "41 tablo · 12 view · 165 fn")

| Nesne | İddia | GT gerçek |
|---|---|---|
| Tablo | 41 | 41 CREATE TABLE ifadesi / **40 unique** (`ui_logs` GT:271 + GT:6082 iki kez tanımlı) |
| View | 12 | 15 ifade / **13 unique** |
| Fonksiyon | 165 | 182 ifade / **175 unique isim** |

GT son olarak 2026-08-31'de güncellendi (commit 8a77888, 00e965e) — 2026-06-25 audit rakamları bayatlamış.
Ek GT iç tutarlılık kusuru: ilk `ui_logs` tanımı (GT:271) ancak GT:6082'deki bigserial ile oluşan sequence'e ileri referans veriyor.
GT "canlı ile birebir" iddiası read-only denetimde lokal olarak doğrulanamaz (DB çağrısı yapılmadı).

---

## 5. Öncelik Sıralı Aksiyon Listesi (hiçbiri bu denetimde uygulanmadı)

**Kod taraflı (bug adayı — doc doğru, kod eksik):**
1. `js/ui.js:6725-6809` `buildRpcParams` — offline replay parametre setlerini canlı RPC imzalarıyla eşitle (tetiklenirse patlar).
2. Erkek↔grup backend guard'ı yok (domain-rules ❌7) — `hayvan_ekle`/`hayvan_guncelle`/`padok_degistir`'e cinsiyet-grup kontrolü eklenmeli.
3. `dogum_kaydet`'e ileri doğum tarihi backend kontrolü eklenmeli (domain-rules ⚠️8).

**Doküman güncellemeleri (kod/DB doğru taraf):**
4. **AGENTS.md ID tablosu** — gorev_log→uuid, stok_hareket→text, islem_log→text; WHERE cast kılavuzu düzeltilmeli (aktif yanıltıcı).
5. **rpc-reference.md** — 4 imza (C1-C4) düzeltilmeli, `geri_al` tek girdiye indirilmeli, D1/D2 notları eklenmeli;
   73 eksik RPC tamamı ya da en azından sık kullanılanlar eklenmeli; dosya **git'e işlenmeli** (şu an untracked).
6. **domain-rules.md** — 8 çelişki + 8 bayatlık (başta Bölüm 5 doğum protokolü 16 görev/d2·d25·d39/E Vitamini, Bölüm 9-10, Bölüm 11-12 listeleri, farm_id UUID tipografisi).
7. **AGENTS.md:196** — kırık `ReFactorRoadmap.md` referansı; `.claude/ReFactorRoadmap.md` ya köke geri alınıp commit'lenmeli ya referans düzeltilmeli.
8. **`.claude/ReFactorRoadmap.md`** — Aşama 3 (delegation yapıldı), 1.4 (fonksiyonlar silindi), Aşama 2 (insertOffline bilinçli kaldırıldı) satırları güncellenmeli; `.claude/RefactorRoadmap.md` archive'a taşınmalı.
9. AGENTS.md "41/12/165" sayıları tarihlenmeli ya da güncel audit ile tazelenmeli.
10. **CLAUDE.md:299** bayat (kullanıcı onayıyla düzeltilmeli — OMP dokunamaz).

---

## Metodoloji ve Sınırlar

- 4 paralel general-purpose subagent (salt-okunur talimatıyla) + orkestratör spot-check (DDL, dosya varlığı, event-delegation
  dosyaları doğrudan doğrulandı). Supabase'e hiçbir çağrı yapılmadı; "canlı şema" iddiaları GT + commit'lenmiş migration
  yorumları üzerinden çıkarıldı.
- rpc-reference.md git'siz olduğundan "doc mu yeni niyet mi" sorusu tarihçeyle cevaplanamadı; C bulgularında niyet migration
  commit'lerinden çıkarıldı.
- A-listesindeki 73 RPC'nin param setleri tek tek DB imzasıyla karşılaştırılmadı (yalnızca temsilî çağrılar param düzeyinde doğrulandı).
- ground_truth'ın bazı fn tanımları (dogum_kaydet, cikis_yap) canlıdan eski; domain denetiminde son migration'lar esas alındı.
