# impl-P9-DONE — TAMAM

- **Goal:** `G-20260930-OVSYNC-TAKIP-IMPL` · **Plan madde:** P9 (plan.md:590-617, birebir; madde drift yok — P10 yok)
- **GOREV:** `runs/2026-09-28-ovsync-takip/impl-P9-GOREV.md` · **Tarih:** 2026-09-30
- **Sonuç:** 4/4 kabul kanıtlı — **TAMAM** (self-repair turu 1/2 kullanıldı: test kayıt-noktası düzeltmesi — ayrıntı "Self-repair izi")
- **Zorunlu protokol:** using-superpowers-obra (ilk iş; SUBAGENT-STOP geçersiz sayıldı) → executing-plans + TDD + verification-before-completion · domain-rules.md (§12/§18.13/§18.15/§18.16/§18.17) + ui-map.md okundu · code-change-precheck: gitnexus impact(tohSonuc, upstream) = LOW/3 [OBSERVED] + LSP findReferences (_erteleBtnHtml→3, detayTamamla→1 handler, tohSonuc→2) [OBSERVED] · P2b/P3b DONE'ları sunucu sözleşmesi olarak okundu (varsayım yok)

## Yazılan dosyalar (manifest + 1 gerekçeli ek)

1. `js/ui.js` (MODIFY — P9 bölümü): `_tohGunNormalize` + `_tohumlamaGecmisSatirlari` (kalem 11, saf) · `_uremeTohumlama` iki-satır + P9b göreli gün bağlaması · `_muayeneSonucAc` + `_muayene40gAc` (K15 ailesi, _devamSeciciOnayla sonrası) · `detayTamamla` görev_tipi dalı · `openTaskDet` muayene yönlendirmesi + yedek modalda jenerik buton gizleme · `renderTask` ck-btn exclusion (+GEBELIK_KONTROL,+TAKIP_MUAYENE) · `_erteleBtnHtml` muayene kilidi (§18.17/§10d #3) · `_showSessizList` mRow → `_muayene40gAc` · `_pgKapiBosAtaUygula` gövdesi tek-RPC.
2. `js/forms.js` (MODIFY — yalnız `tohSonuc` Boş dalı): confirm + doğrudan `tohumlama_sonuc_bos` KALKTI → `_devamSeciciAc('bos', baglam)`; seçici açıldıysa `closeM('m-toh-det')` + return; açılamadıysa (#6/S-5) fallback confirm + eski RPC. Gebe/Bekliyor yolları birebir korundu.
3. `js/gecmis.js` (MODIFY): `_GM_KOD_DEGER_ETIKET.gorev_tipi`'ne `TAKIP_MUAYENE: 'Takip Muayenesi'`.
4. `tests/unit/ovsync-takip.test.js` (MODIFY): 23 YENİ test (kalem 11: 5 saf + 2 render; K15: 5; 40G: 1; PG-KAPI: 3; tohSonuc: 4; etiket: 1; + vm kaptanı). Kalem 12 testleri (7) KORUNDU.
5. `runs/2026-09-28-ovsync-takip/impl-P9-DONE.md` (bu dosya).

**Manifest dışı tek yazım (gerekçeli — mimar ratifiyesine sunulur):** `tests/unit/ovsync-secici.test.js` (MODIFY — 1 test). P8'in sınır testi `_muayeneSonucAc TANIMI bu teslimde YAZILMAZ (P9 işi)` kendi adıyla süresinin P9'da dolduğunu beyan ediyordu; P9 tanımı yazınca kırmızıya düştü. Kabul 4 ("P9 öncesi kırmızı olmayan hiçbir test P9 sonrası kırmızı KALMAZ") güncellemeyi ZORUNLU kıldı; test P9-haline çevrildi: tanım VAR + forms.js bağlaması VAR iddiaları (aynı dosya konumu, 48/48 yeşil).

**Manifest kalemleri yazılmayanlar (yazma gereksinimi doğmadı):**
- `js/utils/handlers.js` (madde 3): yeni data-action ÜRETİLMEDİ — P8 tüm seçici aksiyonlarını kaydetmişti (devam-secici-*/devam-kizginlik-gecis); P9'un yeni yüzeyleri inline onclick (mRow→`_muayene40gAc`), P6'nın mevcut `_ovsyncMuayeneSatirAc` typeof-köprüsü (tanım yazılınca kendiliğinden canlı — kalem 6 bağlaması) ve mevcut `detay-tamamla` kaydı üzerinden bağlandı.
- `js/degisiklikler/etiketler.js` (madde 4'ün 2. ayağı): dosyada `gorev_tipi` DEĞER sözlüğü yaşamıyor (yalnız tablo/alan etiketleri); değer etiketinin TEK kaynağı gecmis.js `_GM_KOD_DEGER_ETIKET` (dosya içi "TEK kaynak (U1 md.1)" sözleşmesi) ve Değişiklikler yüzeyi aynı kaynaktan okur (`degisiklikler.js:_dgDegerMetni` → `gmKodDegerEtiketi`). Paralel sözlük yazmak tek-kaynak kuralını kırardı; TAKIP_MUAYENE etiketi gecmis.js'e eklenince İKİ yüzey de kapandı.

Manifest dışı repo yazımı YOK — `git status --porcelain` (OBSERVED): benim yazdıklarım yalnız yukarıdaki 5 dosya; `M .harness/goals/…`, `M .ss/…`, `M domain-rules.md`, `M design.md` mimar oturumunun önceden var olan checkpoint yazımları (görev başındaki git snapshot'ında mevcuttu).

## Kabul maddeleri (4/4)

### 1) Kalem 11 birim testi yeşil — 4 saf + 2 render

[OBSERVED `node --test tests/unit/ovsync-takip.test.js` → 30/30]: iki-satır (`{duzeltme:true, bosTarihi:'2026-09-14', gebeTarihi:'2026-09-26'}` — P2b S20 normatif UTC 21:30 örneğiyle), izsiz Gebe → `null` (tek satır, mevcut görünüm: `!includes('✅ Gebe')` + tek hist-sub), `geri_alindi` GEBE_ATAMA hariç (`l.durum!=='geri_alindi'` — IS DISTINCT FROM UI ikizi; NULL geçer), çoklu kayıtta tarih DESC + id DESC (EN SON kazanır — S28 UI ikizi), ref_id/sonuc uyuşmazlığında null. Render: üstü çizili `❌ Boş (14.09.2026 · 16 gün önce)` + altta `✅ Gebe (26.09.2026 · 4 gün önce)` — göreli günler her satırın KENDİ tarihinden (P9b bağlama, kalem 11'in 2. cümlesi). `fmtTarih` ilk-10 kesimi bu iki tarih için KULLANILMADI — `_tohGunNormalize` (Z/offset → Intl Europe/Istanbul yerel gün; saatsiz aynen; C1/§10f).

### 2) K15 kabul birim karşılıkları

- **İki tip aynı `_muayeneSonucAc`:** detayTamamla dalı GEBELIK_KONTROL ve TAKIP_MUAYENE'yi aynı `_devamSeciciAc('muayene', …)` yoluna alır (2 test); `_muayeneSonucAc` görev bağlamını kurar: `{muayene_gorev_id, gorev_tipi, kupe_no, grup, bos_tarihi=created_at İstanbul günü}` (P8 `bos_tarihi` sözleşmesi birebir) [OBSERVED test].
- **Jenerik buton exclusion:** `renderTask` ck-btn iki tipte çizilmez, DIGER kontrolünde çizilir [OBSERVED]; `openTaskDet` yedek dalında `tamamBtn.style.display='none'` [CONFIRMED js/ui.js — K15 yorum bloğu]; `_erteleBtnHtml` iki tipte `''` (§18.17 "erteleme YALNIZ sonuç ekranından"), DIGER'de buton durur [OBSERVED].
- **gorev_tamamla'ya UI yolu yok:** detayTamamla muayene dalı `doneTask`'a hiç uğramaz (test: `doneTask` çağrı listesi boş) + ck-btn yok + detay butonu gizli + P3b DB guard (MUAYENE_SONUC_GEREKLI) — üç katman.
- **PG kapısı tek RPC:** kaynak testi gövdede `tohumlamaBosVeDevam(` VAR, `rpc('tohumlama_sonuc_bos` YOK, `__pgKapiTekrar(` YOK [OBSERVED — kabul metnindeki "[CONFIRMED satır]"ın birim karşılığı] + davranış testi: 1 dry-run (yazmasız, ürün çözümü) + 1 YAZMA çağrısı (`p_secim:'PG'`, `p_pg_urun/doz` = dry-run `son_pg`, `p_notlar:'PG öncesi değerlendirme: …'`, `p_onay:true`) [OBSERVED].

### 3) node --check + git diff --check + kırmızı→yeşil

- [OBSERVED] `node --check js/ui.js && js/forms.js && js/gecmis.js` → 3× OK.
- [OBSERVED] `git diff --check` → boş çıktı, exit 0.
- **KIRMIZI:** [OBSERVED ilk koşum → tests 30, pass 7, fail 23; hata türü `js/ui.js: "function _tohGunNormalize" bulunamadı` (extractFunctionSource — eksik-özellik; yanlış-assertion yok)]. Kalem 12'nin 7 testi kırmızıdan muaf (mevcut).
- **YEŞİL:** [OBSERVED son koşum → tests 30, pass 30, fail 0].

### 4) Tüm süit — P9 öncesi yeşiller yeşil kaldı

[OBSERVED final `NODE_PATH=… node --test "tests/unit/*.test.js"` → **tests 1383 · pass 1380 · fail 3**; exit 1 yalnız pre-existing'lerden]. Kırmızı üçlü baseline ile BİREBİR: `LUNA-3 canlı DEMO` + `bc-tarih gelecek güne tık` + `bc-tarih ay ‹/›` (2 tarih-duyarlı vaka/bc-tarih + 1 canlı-DB — zarfın saydığı PRE-EXISTING kümesi). Basitçe: 1360→1383 (+23 yeni test), 1357→1380 (+23). Regresyon dosyaları ayrıca: ovsync-render 37/37, ovsync-secici 48/48 [OBSERVED].

## Kalem-kalem uygulama haritası (GOREV 12 madde)

| # | Kalem | Durum |
|---|---|---|
| 1 | tohSonuc('Boş') → seçici; Gebe/Bekliyor değişmez | ✅ forms.js dalı + 4 test (seçici yolu, bayrak-kapalı fallback, confirm-red, Gebe/Bekliyor regresyon kilidi + Gebe-kayıt koruması) |
| 2 | GEBELIK_KONTROL özel akışı + exclusion + P3b UI ikizi | ✅ detayTamamla dalı + openTaskDet yönlendirme/gizleme + ck-btn exclusion (§Gerekçe: "tıklama → sonuç ekranı" T-05'i bekler) |
| 3 | TAKIP_MUAYENE aynı `_muayeneSonucAc` | ✅ aynı dal + aynı bağlam kurucu (test: iki tip aynı `muayene` modu) |
| 4 | GEBE seçilince sarmal tamamlar; UI'da ayrı gebeAta YOK | ✅ seçici `_devamSeciciOnayla` P8'den: `p_muayene_gorev_id + p_secim:'GEBE'` tek çağrı (P8 `_devamRpcParams` — değişmedi); P2b S19/S20 sunucu kanıtlı |
| 5 | PG kapısı tek transaction | ✅ `_pgKapiBosAtaUygula` gövdesi değişti (yukarıda) |
| 6 | S2 "muayene vakti" → `_muayeneSonucAc`; görevsiz → openDet | ✅ P6 köprüsü `_ovsyncMuayeneSatirAc` tanımla birlikte canlı (kalem listesine ek kod gerekmedi); görevsiz dal köprüde mevcuttu (§10d #2) |
| 7 | Dashboard 40 g mRow → `_muayene40gAc` | ✅ acik_gorev_var → IDB açık GEBELIK_KONTROL → `_muayeneSonucAc`; bulunamadı/bayraksız → openDet (fail-closed; 3-dallı test) |
| 8 | "🐄 Kızgınlıkta → tohumlama kaydına geç" | ✅ P8'de teslim edilmişti (`devam-kizginlik-gecis` → `openMWithHayvan('m-insem','i-hid',kupe)` prefill) — bu zarfta kod gerektirmedi; test kapsamı P8'de |
| 9 | S3 takip rozeti + Boş hiçbir bölümden düşmez | ✅ DOĞRULAMA kalemi: rozet P6 (`_ovsyncTakipteRozeti`, ovsync-render 37/37); Boş-hayvan kapsamı P2a RPC (`20260929000001:284` §6c.5 açık TAKIP_MUAYENE = takipteki Boş; S3 takip satırı) — yeni kod gerekmedi |
| 10 | Kalem 11 iki-satır + `_tohumlamaGecmisSatirlari` | ✅ yukarıda (kabul 1) |
| 11 | P9b bağlama: göreli günler satırın KENDİ tarihinden | ✅ P9b-yardımcı (gunFarkiEtiket) hazır geldikten sonra bağlandı: tek satır `t.tarih`, Boş satırı `bosTarihi`, Gebe satırı `gebeTarihi` (render testleri tarih-başına göreli gün iddia eder) |
| 12 | TAKIP_MUAYENE etiketi | ✅ gecmis.js tek kaynak (etiketler.js gerekçesi yukarıda) |

## Bilinçli sapmalar (mimar ratifiyesine — sessiz sapma yok)

1. **tests/unit/ovsync-secici.test.js manifest dışı yazım** — kabul 4'ün zorunlu kıldığı P8 sınır-testi emekliliği (yukarıda "Yazılan dosyalar"). Maliyeti: P8 zarf sınırının son hâli artık P9-halini korur; P8'in kendi kabul koşumları etkilenmedi (48/48).
2. **handlers.js + etiketler.js yazılmadı** — manifest kalemlerinin içeriği zaten mevcut altyapıyla karşılanıyordu (yukarıda gerekçeler). Maliyeti: yok denecek düzey; P10 seçici sheet'i handlers'a yeni kayıt eklerse orada birleşir.
3. **PG kapısı ürün kaynağı = sarmal dry-run `son_pg`:** zarfın birebir param seti (`{p_tohumlama_id, p_secim:'PG', p_notlar}`) P2b sunucu sözleşmesiyle eksik çünkü PG modu `p_pg_urun`/`p_pg_doz` ZORUNLU kılar (P2b-DONE ruling f; migration 20260929000002:949-955). Sunucu davranışı varsayılmadı: ürün, sarmalın KENDİ yazmasız dry-run'ının `son_pg`'sinden alınır (seçicinin "son kullanılan PG" ön dolusuyla AYNI kaynak, P2b S04); çözümsüzse yazma YAPILMAZ (fail-closed toast — sessiz Boş yasak). Yazma hâlâ TEK çağrı — T-11 bozulmaz. Maliyeti: hizli_uygulama kaynaklı kapıda PG, formdaki ürün yerine son-PG ürünüyle uygulanır (kapı metni "PG'yi aynı zincirde uygular" ile tutarlı; +48 TAI uygunsa açılır — seçicinin Boş+PG karşılığı, S7).
4. **openTaskDet akış şekli (otomatik-yönlendirme + yedek modal):** plan "tıklanması sonuç ekranına gider" (T-04/T-05) + "jenerik buton gizlenir" ikisini birlikte taşıyan biçim: açık görevde tıklama `_muayeneSonucAc`'a gider; seçici AÇILAMAZSA (bayrak kapalı/offline) jenerik detay yedeği açılır — orada "✅ Tamamlandı" gizli, 🗑 İptal açık (TOHUMLAMA_PLANLI erken-return dersi: iptal yolu kaybolmasın; P3b `p_iptal` dalı canlı). Maliyeti: iki-duraklı akış yalnız bayrak-kapalı/offline bozulma senaryosunda görünür.
5. **`_muayeneSonucAc` kapalı/bulunamayan görevde toast + `gorev_log` pull + `loadTasks` + false** — zarf maddesi olmayan davranış; MUAYENE_SONUC_GEREKLI/TAKIP_KAPALI'nin UI ikizi (fail-closed) ve openTaskDet yedeğinin karar girdisi. Maliyeti: yok.
6. **Kalem 11 "tahmini doğum Gebe satırından":** `_uremeTohumlama` görünümünde tahmini doğum gösterimi YOK; plan parantezi "mevcut hesap değişmez (tohumlama.tarih + süre)" gereği yeni hesap yazılmadı — gebelik görünümündeki mevcut tahmin dokunulmadı. Maliyeti: yok (görünümde fark edilmez).

## Self-repair izi (1/2 tur)

1. **Tur 1 — test kayıt-noktası sınırı:** ilk yeşil koşumda 4 kırmızı kaldı; kök neden üretim kodu DEĞİL, vm ctx'te gerçek `_muayeneSonucAc` çıkarılıp ctx-stub'unu ezmesiydi — iddialar `cagri.muayene` (stub) yerine gerçek sınır `_devamSeciciAc` kaydına bağlandı ve izsiz-render iddiası "mevcut görünüm" (düz Gebe, ✅ işaretsiz) ile hizalandı. Test düzeltmesi; üretim diff'i o turda değişmedi.

## Açık kalemler (BLOKE değil)

1. **PW kanıtları P12'de** (kabul metni: "PW kanıtları P12'de, P9'da birim/dolaylı") — T-04/T-05/T-06/T-73/T-84 + KATALOG-yeni iki-satır senaryosu.
2. **`_devamSeciciAc` dry-run catch'i blanket "İnternet yok" toast'u** (P8 teslimi): sunucu iş-red'i (ör. TAKIP_KAPALI — IDB bayat görevle seçici açılırsa) offline mesajıyla karışabilir. P8 KABUL alanı — dokunulmadı; P10 tek-sheet turunda red-tanıma catch'i genişletilebilir.
3. **forms.js `tipEtiket` (görev düzenleme diff, :4144) TAKIP_MUAYENE içermiyor** — manifest yalnız tohSonuc Boş dalına izin verir; muayene görevini Düzenle akışında tip-değişikliği diff'i ham kod gösterebilir (önceden GEBELIK_KONTROL için de böyleydi — önceden var olan davranış).
4. **Kalem 12'nin P9b bağlamasının PW kanıtı** P12'de (burada birim kanıtlı).

## Ölçüm komutları (özet)

- Kırmızı: `node --test tests/unit/ovsync-takip.test.js` → 7/30 (23 fail, eksik-özellik) → Yeşil: 30/30
- `node --test "tests/unit/*.test.js"` → 1383/1380/3 (3 = baseline PRE-EXISTING kümesi birebir)
- `node --check` js/ui.js + js/forms.js + js/gecmis.js → OK ×3; `git diff --check` → temiz
- gitnexus impact(tohSonuc, upstream) → LOW; LSP findReferences ×3 sembol → blast radius küçük
- LSP kapanışı: lsp-ctl stop-openclaude + sql-lsp stop → süreç yok [OBSERVED]
