# W1 — Dashboard takip tablolarının kod anatomisi (ovsync takip ekranı ön-arştırması)

Ağaç: `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip` @ c9122fd (dal `ovsync-takip`, çalışma alanı temiz).
Metod: tools-bank `atlas_query` (repo=egesut-erp1, sha c9122fd ile eş, taze) önce; JSDoc+gövde birlikte okundu;
atlas'ın string-literal kör alanları (`OVSYNC_BASLAT`) `grep -n` ile kapatıldı. Satır numaraları c9122fd'ye göredir —
sembol adlarıyla birlikte okunmalı (drift dayanıklılığı).
Zorunlu referanslar okundu: `.harness/references/domain-rules.md` (§4, §12, §18), `ui-map.md`, `rpc-reference.md`.

> **Belge-drift düzeltmesi (W1 bulgusu):** rpc-reference §Sessiz ve domain-rules §4 eşik **55** der;
> canlı migration `20260925000002` eşiği **55 → 50** aldı (`sessiz_hayvanlar_listele(p_padok, p_min_gun DEFAULT 50)`,
> `WHERE COALESCE(e.sessiz_gun,9999) >= p_min_gun`) ve UI `_showSessizList` başlığı "50+ gündür sessiz" yazar
> [CONFIRMED supabase/migrations/20260925000002_sessiz_siniflandirma.sql:37,75-87; ui.js:2764]. İki referans doküman bayat.

---

## 1. Yüzey envanteri

| # | Yüzey | Veri kaynağı | api.js sorgu yolu | ui.js render | Ana kanıt |
|---|---|---|---|---|---|
| 1 | Sessiz hayvanlar (RPC bandı + sheet) | RPC `sessiz_hayvanlar_listele(p_padok, p_min_gun DEFAULT 50)` → `v_eligible` | `rpc()` × 2 çağrı noktası; RPC_TABLES'ta DEĞİL (salt-okuma invariant) | `_dashBands` bant kırmızı + `_showSessizList` sheet | ui.js:610, 2735 |
| 2 | İleri gebeler (dashboard bandı) | RPC `gebelik_protokol_kontrol` → `res.hayvanlar` | `rpc()` + `pullTables(['gorev_log'])` | `ileriGebeKontrol` → `_dashBands` amber bant | ui.js:340-351, 491-505 |
| 3 | Görevler ekranı | IDB `gorev_log` (+ 7 pull tablosu; offline-IDB öncelikli) | `pullTables` + `idbGetAll` | `loadTasks` (F3/F4) + `openTaskDet` | ui.js:956-1231, 8702-8951 |
| 4 | Üreme sekmesi | IDB `tohumlama`/`kizginlik_log`/`dogum` (+ ilgili tablolar) | `idbGetAll` (pull ile dolan) | `loadUreme` 5 tab → `_ureme*` loader'lar | ui.js:6056-6079, 5978-6031 |
| 5 | Protokol ekranı (🔔 panel) | RPC `protokol_eksik_tara` + `ovsync_baslat_uyarilari`; `window.__*` cache | `rpc()`, cache-fallback | `_showProtokolEkran` + `_ovUyariSatirHtml` | ui.js:2888-2983, 3096-3115 |
| 6 | Belirsiz üreme | RPC `hayvan_belirsiz_ureme_listele` | `rpc()` + toplu işaret `hayvan_genc_anne_isaretle_toplu` | `_showBelirsizList` + `_belirsizRender` | ui.js:2778-2859 |
| 7 | Ovsync temas noktaları | RPC `start_first_service_protocol`, `protokol_iptal`, `gorev_ertele`, `gorev_tamamla(p_iptal)`, `tohumlama_sonuc_bos` (PG retry) | `rpc()`/`rpcOptimistic`; RPC_TABLES'ta yazma setleri var, RPC_MAP'te YOK (online-only) | `ovsyncBaslat`, `ovsyncIptal`, `_pgKapiAc`, `_ovsyncBaslatKilitHtml`, `_erteleBtnHtml` | ui.js:1799-1974, 1384-1473, 1697-1781 |
| 8 | Vaka detay + timeline | IDB `cases`, `treatment_days`, `treatment_day_uygulamalar`, `drug_administrations`, `tohumlama`, `gorev_log` | `pullTables` + `idbGetAll` Promise.all | `openCaseDet` + `renderCaseTimeline` | ui.js:9440-9499, 9521-9782 |

Ortak veri düzlemi: `rpc()` ok:false'u ASLA döndürmez → Error + `err.data` gövde; gerçek iletim hatası → 'İnternet bağlantısı gerekli'
[CONFIRMED api.js:66-97]. `rpcOptimistic` toast + `RPC_TABLES[name]` pull seti + renderSafe [CONFIRMED api.js:741-762].
`pullTables` sıralı `_pullChain` kilitli, `idbClearAndPut` REPLACE [CONFIRMED api.js:505-519, 555-738].

---

## 2. Yüzey başına anatomi (a-e)

### 2.1 Sessiz hayvanlar

- **(a) Veri kaynağı:** DB-side. `v_eligible` view (Dişi+Aktif+kısır değil+buzağı değil+≥13 ay+Gebe yok+eşik altı; ankraj
  = MAX(kızgınlık, tohumlama, abort_tarihi, dogum_tarihi, dogum); event'siz düvelerde sayaç 12a21g kural gününden) [CONFIRMED
  rpc-reference.md:563-564 + domain-rules §4 + 20260925000002:38]. `sessiz_hayvanlar_listele` satırı jsonb:
  `COALESCE(e.sessiz_gun, 9999)` sentinel, `ORDER BY COALESCE(...) DESC`, `WHERE ... >= p_min_gun` (DEFAULT 50) [CONFIRMED 20260925000002:75-87].
- **(b) Sorgu yolu:** Dashboard: `rpc('sessiz_hayvanlar_listele', {})` try/catch İÇİNDE — offline/RPC hatasında sessiz düşer,
  dashboard bantsız devam eder [CONFIRMED ui.js:608-610]. Sheet: `_showSessizList` aynı RPC'yi taze çağırır [CONFIRMED ui.js:2735].
  RPC_TABLES'ta bilinçli yok: "pg_uyari_kontrol / ovsync_baslat_uyarilari salt-okuma: RPC_TABLES'te DEGIL" yorumu bu invariant'ı
  genel kural yapar [CONFIRMED api.js:417-420]. Offline'da yüzey verisi YOKTUR — IDB'den türetilmez (RPC-only veri).
- **(c) Render:** Bant: `_dashBands(...sessizList...)` → `band('red', '🔇 Sessiz Hayvanlar', ...)` ilk 8 satır + "+N daha" [CONFIRMED ui.js:454-537, 513-521].
  Tam liste: `_showSessizList` → `#sessiz-bs` non-router bottom sheet (ui-map overlay listesinde router-dışı) [CONFIRMED ui.js:2733-2770 + ui-map.md:64-68].
  Aynı sheet üstte `gebelik_muayene_listele` (S2) sonucunu izole bölümde gösterir [CONFIRMED ui.js:2736-2738, 2760].
- **(d) Filtre/sıralama:** Sunucu COALESCE-DESC + client-side **sentinel-son** yeniden sıralama: bantta
  `sessizTop=[...].sort((a,b)=>{const af=a.sessiz_gun>=9999?1:0, bf=...; return af-bf || b.sessiz_gun-a.sessiz_gun})` [CONFIRMED ui.js:515];
  sheet'te SAF `_sessizGrupla` aynı kuralı gruplu bölümlemeyle yapar, 9999'lar "Hiç kayıt yok" bölümünde en altta [CONFIRMED ui.js:2714-2727].
- **(e) Tıklama akışı:** Bant başlığındaki "Tümünü Gör →" → `_showSessizList()`; bant satırı → `openDet(hayvan_id)` [CONFIRMED ui.js:514-518];
  sheet satırı → `_sessizSheetGizle(); openDet(...)` (sheet'i kapatıp hayvan kartına iner) [CONFIRMED ui.js:2753]. Kapatma:
  `history.pushState({sessiz_bs:1})` @2767 + `_modalBackGuard` geri-tuşu zinciri — tüm bottom-sheet'lerin ortak kalıbı.

**W1 notu:** Bu üç-katman (rpc→bant-slice→"Tümünü Gör"→sheet) dashboard takip verisinin standart dağıtım deseni; ovsync takip
ekranının girişteki "sessiz benzeri liste" ihtiyacının birebir kalıbı.

### 2.2 İleri gebeler

- **(a)** RPC `gebelik_protokol_kontrol` sonucu `res.hayvanlar` (gebelik_gun, padok, gebelik rozet alanları) [CONFIRMED ui.js:340-351].
- **(b)** `ileriGebeKontrol`: `rpc(...)` → `window.__ileriGebeListesi` cache → `pullTables(['gorev_log']).then(loadDash)` zinciri;
  RPC_TABLES: `gebelik_protokol_kontrol: ['gorev_log']` [CONFIRMED ui.js:340-351 + api.js:442].
- **(c)** `_dashBands` @491-505: `band('amber', '🐄 İleri Gebeler', ...)`; D-/numara öneki, `gebelik_gun` günü, `>=260` Anyonik rozeti,
  padok ≠ Kuru/Gebe ise 🔴 Transfer rozeti [CONFIRMED ui.js:491-505].
- **(d)** Listede sıralama RPC tarafında; bant slice(0,8) özet [CONFIRMED ui.js:491-505].
- **(e)** Satır → `openDet(hayvan_id)`; görevin kendisi Görevler ekranında ILERI_GEBE/ILERI_GEBE_ASI kartı olarak yaşar
  (rpc-reference: `ileri_gebe_asi_tamamla` çağrısı ui.js:4945) [CONFIRMED rpc-reference.md:139-141].

### 2.3 Görevler ekranı (loadTasks / openTaskDet)

- **(a)** IDB-first: online'da `pullTables(['gorev_log','treatment_days','cases','diseases','treatment_day_uygulamalar',
  'drug_administrations','drug_products','stok'])` (skipPull opts ile atlanır), veri HER ZAMAN `idbGetAll('gorev_log')`'dan okunur
  [CONFIRMED ui.js:983, 988]. Offline'da pull atlanır, IDB'den çalışır (ekran offline-okur).
- **(b)** `ertelemeKurallariYenile()` (cache boşsa `rpc('gorev_ertele_kural_listele')`; 60 sn hata sükuneti; offline skip)
  [CONFIRMED ui.js:10039-10054].
- **(c)** `loadTasks` F3/F4: saat ayracı "⏰ saat (N görev)", grup ayracı "🐄/📋 grup (N)", görev kartı `renderTask` — ovsync
  kartında `_kalanGunEtiket` + `_ovsyncBaslatKilitHtml` + `_erteleBtnHtml` [CONFIRMED ui.js:1191-1221, 1697-1773].
  Seans gruplaması: grup anahtarı `hayvan|TARİH`, ayraç ilerlemesi items'tan (C3 fix) [CONFIRMED ui.js:1106-1135].
  Detay: `openTaskDet` → `openM('m-task-det')` router modalı; tamamlanmışsa `openDoneTaskDet`'e düşer [CONFIRMED ui.js:8702-8709 + ui-map.md:44-46].
- **(d)** Filtreler: today/late/all (+_pendWin 1/7/30 chips)/done; today'da `_taskKategori==='ureme'` için 7-gün pencere
  istisnası (K7, `_planliUremeTipler=['OVSYNC_BASLAT','TOHUMLAMA_PLANLI']`) [CONFIRMED ui.js:1041-1054, 68, 73].
  Kategori süzgeci: `_uremeVakaCaseIds` = `cases.filter(c=>c.protocol_family==='OVSYNC')` id-seti; `_uremeGorevMi` OVSYNC
  vakasının TEDAVI_GUN/SEANS görevlerini Üreme kategorisine bağlar [CONFIRMED ui.js:84-86, 97-111].
  Sıralama F3 blok-bazlı: `tarih.localeCompare || _saatK(saat) ('￿' saatsız en-son) || _grupSira(GOREV_GRUP_SIRA, GENEL=100) ||
  kuceDogalKarsilastir(kupe)` [CONFIRMED ui.js:1175-1179]. Arama F4: blok.arama önceden derlenmiş alan-birleşimi
  (kupe+grup+tip+açıklama+teşhis+ilaç adları, lower), `_terms.every(...)`; arama aktifken 200'lük limit kalkar [CONFIRMED ui.js:1181-1189].
- **(e)** Kart → `openTaskDet(gorev_id)`; TOHUMLAMA_PLANLI detayda "🐄 Tohumlamayı Kaydet" form-yönlendirme butonu; ASI_PLANLI
  parent'ta alt-görev listesi + "Hepsini Uygula" [CONFIRMED ui.js:8754, 8767-8801].

### 2.4 Üreme sekmesi (loadUreme)

- **(a)** IDB tabloları (`tohumlama`, `kizginlik_log`, `dogum`, `gebelik` kaynakları) — pull ile dolan; RPC yok.
- **(b)** `idbGetAll` tabanlı loader'lar; `_keepScroll` scroll koruması [CONFIRMED ui.js:6056-6079].
- **(c)** 5 tab: kizginlik/tohumlama/gebelik/dogum/abort; toolbar görünürlük tab-başına; tab değişiminde `_tohSearch` temizliği (I1) [CONFIRMED ui.js:6056-6079].
- **(d)** `_uremeTohumlama`: tarih DESC; çok-alanlı arama (kupe+isim+sperma+sonuç+tarih, terim-AND); durum-dot renk dili
  (Gebe yeşil / Boş+Abort kırmızı / Bekliyor amber); "N. Deneme" chip; Bekliyor 0-15 gün → "🔁 Tekrar Aşım" (openTekrarAsim),
  >15 gün → "💉 Tohumla" (tekrarTohumla) [CONFIRMED ui.js:5978-6031].
- **(e)** Satır → `openTohDet(id)` (router modalı m-toh-det) [CONFIRMED ui.js:6031 + ui-map.md:48].

### 2.5 Protokol ekranı (🔔 panel, _showProtokolEkran)

- **(a)** İki RPC birleşimi: `protokol_eksik_tara` (eksik/yaklasan/tamamlandi üç bölüm) + `ovsync_baslat_uyarilari`
  (görevli + görevsiz öneri satırları) [CONFIRMED ui.js:2888-2983, 634-640].
  `ovsync_baslat_uyarilari` gövdesi (migration 20260926000003): `gorevli` CTE (açık OVSYNC_BASLAT, hedef≤bugun+2, kaynak
  önekinden taban_turu, hedef+10=tai_tarihi) UNION `gorevsiz` CTE (aktif dişi, kısır değil, `_acik_disi_ovsync_hedef` dolu,
  kural günü bugun..bugun+2, açık görevi OLMAYAN; `_ovsync_kural_tarihi` tek hesap noktası) → `{ok, uyarilar}` ORDER BY
  hedef_tarih; authenticated-only [CONFIRMED supabase/migrations/20260926000003_ovsync_baslat_gorevsiz_pencere.sql].
- **(b)** Dashboard açılışta iki RPC'yi `window.__ovsyncUyarilar` / `window.__protokolUyarilar` cache'ine yazar [CONFIRMED ui.js:634-640];
  panel taze çağrı başarısızsa önbellek-fallback (bayat-fallback rozeti + konsol uyarısı) [CONFIRMED ui.js:2946-2963].
  `gorev_ertele_kural_listele` aynı cache deseni: `ertelemeKurallariYenile` + `setState('ertelemeKurallari')` [CONFIRMED ui.js:10039-10054].
- **(c)** `#protokol-bs` non-router sheet; OVSYNC bölümü EN ÜSTTE "🌱 İlk Tohumlama (N)"; boş veri + boş ovHtml → toast [CONFIRMED ui.js:2888-2983].
  Satır üretici `_ovUyariSatirHtml`: `oneriMi=!u.gorev_id` → görevsiz satır "📅 Görev hedef gününde otomatik açılır" (Başlat
  daveti YOK); görevli satır → `_ovsyncBaslatKilitHtml`; hedef/TAI/taban_turu gösterimi (Düve — 12a21g / Doğum sonrası / Abort
  sonrası / Açık dişi) [CONFIRMED ui.js:3096-3115]. Yardım sheet `_showOvsyncYardim` (C4'te seans uyarı bölümü sahibin talebiyle
  geri alındı — kanıt yorumu ui.js:3117-3119) [CONFIRMED].
- **(d)** Bölüm filtreleri eksik/yaklasan/tamamlandi; ovsync satırları hedef-tarih sırasını RPC'den alır [CONFIRMED].
- **(e)** Görevli satır: ▶ Başlat (`ovsyncBaslat`) + ✕ (`ovsyncIptal`); görevsiz satır tıklanamaz bilgi satırı; "❓ Nasıl
  çalışır" → `_showOvsyncYardim` [CONFIRMED ui.js:3096-3115, 1736-1755].

### 2.6 Belirsiz üreme (_showBelirsizList)

- **(a)** RPC `hayvan_belirsiz_ureme_listele` → TABLE(hayvan_id, kupe_no, grup, padok, dogum_sayisi, tohumlama_sayisi,
  son_tohumlama); `dogum_sayisi=COUNT(DISTINCT olay_id)` (ikiz modeli) [CONFIRMED rpc-reference.md:69-70 + domain-rules §5].
- **(b)** `rpc()` taze çağrı; toplu işaret yazması `rpcOptimistic('hayvan_genc_anne_isaretle_toplu')` [CONFIRMED ui.js:2778-2793, 2848-2859].
- **(c)** `#belirsiz-bs` bottom sheet + `_belirsizRender`: checkbox seçim Set'i, predikat çipleri (Tümü/1 doğum/0 doğum/Temizle),
  scroll koruma; alt bar "🐮 Genç Anne / 🐄 Olgun İnek" toplu etiketleme [CONFIRMED ui.js:2798-2859].
- **(d)** İstemci-tarafı predikat filtreleri; sıralama RPC'den [CONFIRMED ui.js:2798-2828].
- **(e)** Satır checkbox → seçim Set'i; etiketleme → RPC → yeniden listeleme [CONFIRMED ui.js:2848-2859].

**W1 notu:** checkbox-lı toplu işlem + predikat çipleri + alt toplu-eylem barı deseni, ovsync takip ekranında "çoklu hayvan
seç → toplu başlat/ertele" ihtiyacına hazır kalıp (F1 çoklu kaydırma da aynı dili kullandı).

### 2.7 Ovsync temas noktaları

- **Başlatma:** `ovsyncBaslat(gorevId)` → `rpc('start_first_service_protocol',{p_gorev_id})` → atlandi/zaten dalları, TAI
  hedefi (başlangıç+10g) toast'u; `pullTables(['cases','treatment_days','treatment_day_uygulamalar','drug_administrations',
  'gorev_log','stok','stok_hareket'])`; `closeM('m-task-det')` + `loadTasks(...,{skipPull:true})` + `loadDash()` +
  `window.__protokolUyarilar=null` cache-invalidate [CONFIRMED ui.js:1799-1814].
  Sunucu: vaka açar ve `SET protocol_family = 'OVSYNC' ... AND protocol_family IS NULL` [CONFIRMED
  migrations/20260925000017_start_protocol_fonksiyon_adi.sql:133-135]. Pull seti RPC_TABLES'ta tam [CONFIRMED api.js:403].
- **Pencere kilidi (UI aynası):** `_ovsyncBaslatPencereGunu` = hedef−bugun; pencere hedef−2: `pencereGun>2` → "📅 N gün sonra
  başlatılabilir" (▶ çizilmez); DB aynası `OVSYNC_ERKEN` reddi [CONFIRMED ui.js:1715-1719, 1736-1743 + domain-rules §18.3].
- **Kısır kilidi:** `_ovsyncBaslatKilitHtml` kısır → kilit etiketi, ▶ yok [CONFIRMED ui.js:1736-1743] (domain-rules §18.5 hard-block ile uyumlu).
- **İptal:** `ovsyncIptal` → `_ertelemeOfflineGuard('protokol-iptal')` → aktif `protocol_family` vakası varsa A dalı
  `_protokolIptalAkisi` (IDB'den açık gün/seans sayımı → 2 confirm → `rpc('protokol_iptal',{p_vaka_id,p_yeniden_baslat,p_not})`
  → RPC_TABLES pull → kapanan görev/seans/iade/yeni-görev toast'u → true), yoksa B dalı `confirm` + `gorev_tamamla(p_iptal:true)`
  (önü-başlangıç görevi iptali; eski REST PATCH kalktı) [CONFIRMED ui.js:1830-1876]. Vaka detay yüzeyi `cdProtokolIptal` @1891-1897.
- **PG onay kapısı:** `_pgKapiHata`: `const m=/^(PG_KAPI:[A-Z_]+):([\s\S]*)$/.exec(msg); if(!m) return false;` → `_pgKapiAc`
  `#pg-kapi-bs` sheet: `BLOCK_PREGNANT` (yalnız Tamam), `REQUIRE_ACK_PENDING` (gerekçe input zorunlu + "Boş ata ve uygula" →
  `tohumlama_sonuc_bos` → `window.__pgKapiTekrar(true,gerekce)` retry; retry hatasında modal AÇIK kalır), `BLOCK_CATALOG_UNRESOLVED`
  [CONFIRMED ui.js:1384-1473]. Çağıranlar: `api.js:rpcSeansTamamla@954`, `_hayvanHizliUygulaKaydet@3919`, `_protokolUygulaKaydet@3696`
  [OBSERVED atlas_query context + CONFIRMED api.js:954-979]. Düz "Hata" toast'ı YASAK (domain-rules §18.8).
- **Bildirim üçlüsü:** `ovsyncBaslat` sonrası `_ovsyncBildirim` (Notification.permission==='granted' + app-içi banner fallback)
  [CONFIRMED ui.js:1901-1914]; açılışta `ovsyncAcilisOzeti` (hedefi gelenler tek bildirim) [CONFIRMED ui.js:1921-1928]; rozet:
  `_rozetTopla` protokol + ovsync uyarılarını `#bellbadge`'te birleştirir [CONFIRMED ui.js:646-651, 1781].
- **Erteleme/kaydırma:** `_erteleBtnHtml` kuralı `ertelemeKurallariGetir(t.gorev_tipi)` cache'inden okur; kural yoksa /
  ertelenebilir değilse BUTONSUZ (fail-closed — DB tablosu `gorev_ertele_kural`, JS'e tip listesi yazılmaz); `!_ertelemeOnline()`
  → buton yok [CONFIRMED ui.js:1767-1773]. `cdKaydirAc` `_ertelemeOfflineGuard('kaydir')`; "Kalan Günleri Kaydır" yalnız açık
  günleri taşır [CONFIRMED ui.js:10057-10090 civarı]. F1 çoklu kaydırma `apiCokluKaydir` → `vaka_kalan_gunleri_kaydir_coklu`
  (RPC_TABLES'ta, RPC_MAP'te bilinçli yok — online-only) [CONFIRMED api.js:409-412, 1052-1068].
- **Offline replay ayrımı:** `RPC_MAP` (ui.js:12534, `dataTrafficTekGonder` replay'i) ovsync RPC'lerini (start_first_service_protocol,
  protokol_iptal, gorev_ertele, vaka_kalan_gunleri_kaydir_coklu) BİLİNÇLİ İÇERMEZ → ovsync yazma akışları online-only (E6) [CONFIRMED
  ui.js:12534 + api.js:405-416 yorumları + rpc-reference.md:282-306].

### 2.8 Vaka detay + timeline (openCaseDet / renderCaseTimeline)

- **(a)** IDB: `cases`+`diseases` (detay), timeline 6 tablo Promise.all (`treatment_days`, `treatment_day_uygulamalar`,
  `drug_administrations`, `tohumlama`, `gorev_log`, ilaç adları) [CONFIRMED ui.js:9440-9499, 9521-9535].
- **(b)** `openCaseDet` → `pullTables(['treatment_days','drug_administrations','treatment_day_uygulamalar'])` taze pull →
  `renderCaseTimeline(caseId)` → `openM('m-case-det')` router modalı [CONFIRMED ui.js:9495-9499].
- **(c)** Chip'ler (Aktif/Kapalı renkli, kategori, start_date, closed_at); `ertelemeBtnGuncelle()` (protokol-iptal + erteleme/
  kaydırma butonlarının online-duruma göre çizilmesi, E6); `cd-geri-al-btn` yalnız `islem_log`'da `tip==='VAKA_ACILDI' &&
  ref_id===caseId` kaydı varsa çizilir [CONFIRMED ui.js:9440-9499]. Timeline: gün akordeonları, seans satırları, ilerleme
  çubuğu `doneDays/totalDays` [CONFIRMED ui.js:9630-9638].
- **(d)/(e) Timeline kuralları (tek örnek):**
  - **Sanal tohumlama günü enjeksiyonu:** `TOHUMLAMA_PLANLI` görevi tedavi-günü olmayan vakaya sanal gün olarak eklenir:
    `day_no = önceki_max + 0.5`, kaynak prefix `TEDAVI_SABLON_TOHUMLAMA:+caseId`, `_cdDayData`'ya YAZILMAZ (geçici görünüm)
    [CONFIRMED ui.js:9539-9600, 9663-9665].
  - **Sıralı gün kilidi:** `day._locked = lockAktif && idx>0 && !sortedDays[idx-1].tamamlandi` — yalnız AKTİF vakada; kilitli
    günün eylemleri kapanır ("⏳ Önceki gün tamamlanmadan ...") [CONFIRMED ui.js:9622-9628, 9720-9740].
  - **Tohumlama kalemi durumları:** `tohState` map done/overdue/now/scheduled → "✓ Kaydedildi / ⚠ Gecikti / ⏱ Vakti geldi /
    ⏳ Planlandı" [CONFIRMED ui.js:9704-9706].
  - Seanslı günde "✅ Tamamla" yoktur — son seans otomatik kapatır [CONFIRMED ui.js:9728-9740].
  - Akordeon açık-durum + scroll korunumu; ilk açılışta aktif vakada ilk tamamlanmamış gün auto-open; `startNowCursorLoop`
    "şimdi" imleci canlı tutar [CONFIRMED ui.js:9652-9654, 9778].
  - OVSYNC bağlantısı: `start_first_service_protocol` vaka açıp şablon günlerini kurduğundan OVSYNC vakası da case_id üzerinden
    bu genel timeline motorunda görünür; protocol_family etiketi `cases.protocol_family='OVSYNC'` [CONFIRMED 20260925000017:133-135]
    + [INFERRED: timeline motoru case-türünden bağımsız; RPC_TABLES start_first_service_protocol pull seti cases+treatment_days
    içerir — ovsync vakasının timeline'ı aynı ekrana düşer; özel ovsync-rota görünümü yok].

---

## 3. W1b — Yeniden kullanılabilir parçalar

1. **Dashboard üç-katman dağıtım deseni** — RPC taze veri → `band()` ilk-8 özet → "Tümünü Gör →" tam sheet. Kaynak: `_dashBands`
   + `_showSessizList`. Ovsync takip listesi bu desene oturur; ekstra iş: yok.
2. **`ovsync_baslat_uyarilari` CTE modeli** — gorevli (açık görev, hedef≤bugun+N) UNION gorevsiz (görevi henüz olmayan, kural-günü
   penceresinde) tek RPC'de; `taban_turu` kaynak-önek etiketi; `hedef+10=tai_tarihi` türetme. Takip ekranı RPC'si bu gövdeyi
   genişletebilir (zincir-ortası durumu ek CTE'lerle) [CONFIRMED 20260926000003].
3. **Non-router bottom-sheet kalıbı** — `document.createElement('div')` + fixed inset + `align-items:flex-end` +
   `history.pushState({<anahtar>:1})` + `_modalBackGuard` geri-tuşu kapatması. 5 örnek canlı (sessiz/protokol/belirsiz/pg-kapi/
   ovsync-yardim). Router modalı (`openM/closeM`) yalnız index.html'deki statik modal'lar için — yeni takip sheet'i bu kalıptan
   kurmalı [CONFIRMED ui.js:2733-2770, 2888-2983 + ui-map.md:16-68].
4. **Sentinel-son sıralama disiplini** — veri-eksikliği 9999 sentinel'i + client-side "en altta" sıralaması; SAF `_sessizGrupla`
   + unit test kilidi deseni. Ovsync takipte "kural günü hesaplanamayan hayvan" için aynı semantiğin aynası gerekir [CONFIRMED
   ui.js:515, 2714-2727].
5. **Blok-önceden-derlenmiş arama** — `blok.arama = [alanlar].join(' ').toLowerCase()` + `_terms.every(includes)` + arama-aktifken
   limit kaldırma. Çok-alanlı takip araması için hazır [CONFIRMED ui.js:1181-1189, 5978-6031].
6. **Katmanlı sıralama anahtarı** — tarih→saat('￿' saatsız en-son)→grup(GOREV_GRUP_SIRA)→küpe(kuceDogalKarsilastir doğal sıra).
   Takip listesi satır sırası için tek kaynak [CONFIRMED ui.js:1175-1179].
7. **Checkbox toplu-eylem barı** — `_belirsizRender` seçim Set'i + predikat çipleri + alt toplu butonlar; F1 çoklu kaydırma aynı
   dili kullandı. Toplu başlat/ertele/iptal için doğrudan kalıp [CONFIRMED ui.js:2798-2859].
8. **Tek-kaynak kart buton üreticisi** — `_ovsyncBaslatKilitHtml` hem görev kartında hem panel satırında aynı kilit/pencere/
   Başlat dilini çizer. Yeni yüzeyde buton mantığını kopyalama, aynı üreticiye bağlan [CONFIRMED ui.js:1736-1755, 3096-3115].
9. **Cache + bayat-fallback + cache-invalidate üçlüsü** — `window.__ovsyncUyarilar` dashboard dolgusu; panel taze çağrı hatasında
   bayat-fallback rozeti; yazma sonrası `window.__protokolUyarilar=null` ile invalidate [CONFIRMED ui.js:634-640, 2946-2963, 1814].
10. **Online-only kapı deseni (E6)** — RPC_TABLES'e gir + RPC_MAP'e GİRME + `_ertelemeOfflineGuard` + offline'da buton üretme.
    Yeni ovsync yazma RPC'si bu üç ayağı birden almalı [CONFIRMED api.js:405-416, ui.js:1767-1773, 12534].
11. **PG_KAPI hata-sarmalı** — regex `PG_KAPI:KOD:detay` → özel onay sheet'i; HER giriş noktası aynı `_pgKapiHata` zincirine
    bağlanır (api katmanındaki `rpcSeansTamamla` dahil). Yeni PG dokunuşlu aksiyon aynı sarmala mecbur (domain-rules §18.8)
    [CONFIRMED ui.js:1432-1438, api.js:954-979].
12. **Timeline sanal-gün + sıralı-kilit motoru** — sanal gün `+0.5` day_no enjeksiyonu (IDB'ye yazmaz), önceki-gün kilidi,
    ilerleme çubuğu, tohState durum-dili. Ovsync zincir görünümünün tek mevcut gün-modeli motoru [CONFIRMED ui.js:9539-9782].
13. **Bildirim üçlüsü** — Notification (izin şartlı) + app-içi banner + panel/rozet kalıcı kaynak; rozet tek `#bellbadge`
    birleştirme noktası [CONFIRMED ui.js:1901-1928, 646-651].
14. **Üreme durum-dot renk dili** — Gebe yeşil / Boş+Abort kırmızı / Bekliyor amber (+timeline tohState amber/kırmızı/yeşil).
    Takip ekranı aynı sözlüğü kullanmalı; yeni renk tanıtma gerekçesiz olmaz [CONFIRMED ui.js:5978-6031, 9704-9706].

---

## 4. W1b — Gap listesi (mevcut desenler ovsync takip ekranı için neden yetersiz)

1. **Zincir-düzeyi takip satırı YOK.** Mevcut tüm listeler anlık-durum satırları döner: sessiz_gun, gebelik_gun, belirsiz
   sayaçlar. Bir OVSYNC zincirinin bütünü (başlatıldı mı → 1. gün → 8./9./10. gün seansları → TAI → PG → sonuç) tek satırda
   birleşik durum olarak hiçbir RPC'de yok; `ovsync_baslat_uyarilari` yalnız ZİNCİR BAŞINI (başlatma penceresi) kapsar [CONFIRMED
   20260926000003 + tüm yüzey okumaları]. Takip ekranının temel veri-ihtiyacı: hayvan başına `{zincir aşaması, son uygulanan
   gün, sonraki beklenen gün, TAI hedefi, PG durumu}` — yeni RPC veya IDB-birleşim katmanı GEREKLİ.
2. **Çoklu-vaka protokol görünümü YOK.** Zincir görünümünün tek motoru `renderCaseTimeline` ama vaka-başına + modal-içi; çoklu
   hayvanın zincir ilerlemesini yan-yana/ liste gösteren yüzey yok. loadTasks görev-kesiti (bugün/7g) verir, zincir-kesiti vermez
   [CONFIRMED ui.js:9521-9782 tek-case imzası].
3. **Tarih-pencere filtreleri sabit.** loadTasks today/late/all + 1/7/30 chips; "gün X'te olasılar" / "bu hafta PG'ye girecekler"
   gibi parametreli pencere sorgusu yüzeyde yok [CONFIRMED ui.js:1041-1054].
4. **Durum semantiği çok kaynağa dağınık.** Ovsync durumunu anlamak için client en az 4 kaynağı kendisi birleştirmeli:
   `cases.protocol_family` + `gorev_log` (OVSYNC_BASLAT/TOHUMLAMA_PLANLI/TEDAVI_*) + `treatment_days`(+uygulamalar) + uyarı
   RPC'leri. `_uremeVakaCaseIds` yalnız kategori süzme için protocol_family seti çıkarır; birleşik model-eşleme fonksiyonu yok
   [CONFIRMED ui.js:84-111].
5. **Offline yüzey eksiği.** Sessiz/ovsync uyarı RPC'leri RPC-only veri: offline'da bant düşer, sheet boş toast verir; ovsync
   yazma akışları bilinçli online-only (RPC_MAP yok). Takip ekranı offline'da en azından IDB'den türetilmiş zayıf görünüm
   (bayat-rozetli) isteyecekse bu yeni bir hesaplama katmanıdır [CONFIRMED ui.js:608-610, 12534 + api.js:417-420].
6. **Kapanmış zincir arşivi YOK.** Geçmiş sekmesi (D15 saf-bitmiş kuralı) satır-bazlı defter; protokol-başına kapanmış zincir
   dökümü ("bu hayvanın iptal edilmiş 2. denemesi hangi günlerde neydi") yüzeyi yok; kapalı vakada timeline açılır ama listeden
   erişim yok [CONFIRMED domain-rules §16 + ui.js okumaları].
7. **Tablo/grid bileşeni YOK.** Tüm liste yüzeyleri `.arow` kart dili (mobile-first); çok-kolonlu izleme tablosu (küpe | aşama |
   son gün | sonraki gün | TAI | durum) mevcut CSS/bileşen setinde yok — masaüstü geniş görünüm için yeni bileşen kararı gerektirir
   [CONFIRMED tüm render okumaları; ui-map'te tablo bileşeni tanımsız].
8. **Eşik/parametre sabitleri iki katmana dağınık.** Pencere (hedef−2), TAI (+10g), sessiz eşiği (50) bazıları RPC gövdesinde,
   bazıları JS aynasında (`_ovsyncBaslatPencereGunu`), kural-günü yalnız `_ovsync_kural_tarihi` DB helper'ında. Takip ekranı bu
   sabitleri üçüncü kez JS'e kopyalamamalı — sunucu satırında taşınmalı (ovsync_baslat_uyarilari'nın tai_tarihi türetmesi doğru
   desen) [CONFIRMED ui.js:1715-1719 + 20260926000003].
9. **Doküman-drift riski canlı kanıtlandı** — sessiz eşiği 55→50 geçişi iki referans dokümanda (rpc-reference, domain-rules §4)
   hâlâ 55. Takip ekranı tasarımında eşik/pencere değerleri canlı migration'dan doğrulanmadan JS'e yazılmamalı [CONFIRMED
   20260925000002 vs rpc-reference.md:552-564 vs domain-rules §4].

---

*Kanıt disiplini: `[CONFIRMED dosya:satır]` = bu çalışmada c9122fd ağacından doğrudan okundu; `[OBSERVED komut]` = atlas/grep
çıktısı; `[INFERRED]` = gerekçeli çıkarım (gövdede açıkça yazılı değil ama veri akışı zorunlu kılıyor). Rapor yalnız okuma
üretimidir — hiçbir dosya değiştirilmedi, commit/push yok, DB/Playwright dokunuşu yok.*
