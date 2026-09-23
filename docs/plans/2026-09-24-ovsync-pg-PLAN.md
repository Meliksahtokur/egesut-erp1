# Ovsync / PG — UI PLAN (A2 çıktısı)

Tarih: 2026-09-24 · Kaynak: SPEC `docs/plans/2026-09-23-ovsync-pg-tohumlama-SPEC.md` (§0, S-1…S-10, R3.1, **R3.2/SK9**, "Kapsam dışı" md.4) + root promptu bölüm A2 brief (a)–(j) + tasarım turnuvası değerlendirmesi (kazanan T3 iskeleti; T1'den [Boş ata ve uygula] tek zinciri + (f) tarih-saat; T2'den history-invariant ve config tek-kaynak notları).

Bu dosyadaki P numaraları **PLAN DRIFT KAPISI**'dır: A3 implementasyonu her P maddesini kapatmak zorundadır; madde dışına çıkan değişiklik DRIFT'tir ve durup raporlanır.

## Bağımlılıklar ve sıra (zorunlu)

- **A1 bağımlılığı:** `ovsync_baslat_uyarilari` / `pg_uyari_kontrol` / `start_first_service_protocol` / `tohumlama_gorev_ertele` RPC'leri bugün kodda YOK; A1 (SPEC §R3.2 + SK9 veri kaynağı) kulvarının çıktısıdır. Bu PLAN'ın P1 (hata ayrıştırma) ve P3 (api.js) maddeleri A1'siz başlayabilir; P4 sonrası RPC sözleşmeleri A1 ile kilitlenir.
- Uygulama sırası: **P1 → P2 → P3 → P4 → P5 → P6 → P7 → P8 → P9 → P10** (hata ayrıştırma → api.js çekim haritası → görev kartları/panel → modallar (PG kapısı, erteleme, toplu) → hızlı uygulama saati → özet alert → bildirimler).
- `tohumlama_sonuc_bos` pull seti `js/api.js:300`'de **zaten mevcut** — yeniden yazma, dokunma.

## Kulvarlar (TEK-YAZICI-PER-DOSYA)

| Kulvar | Dosya |
|---|---|
| K-UI (tek yazıcı) | `js/ui.js` |
| K-FORMS | `js/forms.js` |
| K-API | `js/api.js` |
| K-CONFIG | `js/config.js` |
| K-ERR | `js/utils/errorHandler.js` |

Aynı dosyayı iki kulvara verme; ayrışmıyorsa sıralı yürüt. `index.html` (yalnız `?v=` damgası) K-UI kulvarınca güncellenir.

**`?v=` sürüm damgası:** teslimde `index.html` içindeki TÜM `?v=` değerleri TEK yeni değere alınır (ör. `20260924-01`); her dosyada farklı damga bırakılmaz.

---

## P1 — Hata ayrıştırma: PG_KAPI ve yeni hata sözleşmesi

- **Dosya/fonksiyon:** `js/utils/errorHandler.js` (`getUserMessage`, `USER_FRIENDLY`), `js/config.js` (yeni `PG_HATA_SÖZLÜĞÜ`).
- **Değişiklik:** Hata mesajı sözlüğü tek doğruluk kaynağı olarak `config.js`'e taşınır; `errorHandler` oradan okur (T2 notu). Yeni tanınan desenler:
  - `PG_KAPI:<KOD>:<json>` → KOD'a göre Türkçe mesaj: `BLOCK_PREGNANT` ("Gebe inekte PG uygulanamaz"), `REQUIRE_ACK_PENDING` ("Son tohumlama Bekliyor — onay ya da Boş ata gerekli"), `BLOCK_CATALOG_UNRESOLVED` ("Ürün PG kataloğunda belirsiz — kayıt düzeltilmeli").
  - `PG_ZAMAN_GECERSIZ` → "Uygulama zamanı geçersiz (5 dk ileri / 7 gün geri sınırı)."
  - `SISTEM_ETKEN_MADDE` → "Sistem etken maddesi değiştirilemez/silinemez."
  - `KATALOG_SINIF_KODU_KILITLI` → ilgili kilit mesajı.
  - `PG_KAPI:` JSON detayı ayrıştırılıp KOD + detay (kupe no, tohumlama tarihi, deneme no) mesaja eklenir; jenerik "Bir hata oluştu" dönmez. JSON bozuksa bile `PG_KAPI:` öneki tanınınca KOD kısmı gösterilir (fail-loud, sessiz jenerik yok).
  - `getUserMessage` imzası bozulmaz; sadece sözlük kaynağı değişir.
- **Kabul ölçütü:** `npm run test:unit` içinde yeni ayrıştırıcı testleri: beş desen için doğru Türkçe mesaj; tanınmayan mesaj önceki jenerik davranışta kalır; sözlük `config.js`'ten okunuyor (errorHandler'da kod kopyası yok).

## P2 — api.js çekim haritası (pull map)

- **Dosya/fonksiyon:** `js/api.js` `RPC_TABLES` (api.js:293 itibarıyla).
- **Değişiklik:**
  - `bulk_ilac`: `['islem_log','stok','stok_hareket']` → `+ 'gorev_log'` (S-4 toplu yolu görev açabilir).
  - `tohumlama_abort`: `['hayvanlar','tohumlama','islem_log']` → `+ 'gorev_log'` (S-8 `ILK-TOH-ABORT` görevi).
  - `tohumlama_kaydet`: `+ 'cases'` + seans tabloları (`treatment_days`, `treatment_day_uygulamalar`) — S-7 vaka kapanışı. `planli_tohumlama_kaydet` içte aynı `tohumlama_kaydet`'i çağırdığından aynı ekleme.
  - Yeni RPC satırları: `start_first_service_protocol: ['cases','treatment_days','treatment_day_uygulamalar','drug_administrations','gorev_log','protokol_instance','islem_log','tedavi_sablonu','diseases','drugs','stok','stok_hareket']` (şablon uygulama zinciri + görevler), `tohumlama_gorev_ertele: ['gorev_log','islem_log']`, `hizli_uygulama`: mevcut set `+ 'gorev_log'` (S-4/S-5 PG görevi), `seans_tamamla`: `+ 'gorev_log'`, `hizli_uygulama_geri_al`: `+ 'gorev_log','pg_application_event'` tablosu pull setinde tanımlıysa ekle (A1 şema onayıyla; yoksa yalnız `gorev_log`).
  - **`protokol_instance` pull setine GİRMEZ** (RPC_TABLES pull'lanan fiziksel tablolar içindir; instance tablosu UI'da okunmaz — devrilmiş fikir).
  - `tohumlama_sonuc_bos` satırı **mevcut, dokunulmaz** (api.js:300).
- **Kabul ölçütü:** Birim testi: yeni/çevrilen her RPC için `RPC_TABLES[rpc]` beklenen kümeyi içeriyor; `protokol_instance` hiçbir pull setinde yok; mevcut satırlarda yalnız hedeflenen eklemeler var (diff kapısı).

## P3 — Görev kartları ve Tohumlamalar paneli

- **Dosya/fonksiyon:** `js/ui.js` — `_katTipMap` (ui.js:52), görev listesi `data`/filtre blokları (ui.js:641–690'lar), `renderTask` benzeri kart üretimi; Tohumlamalar panel kaynak etiketi üretimi.
- **Değişiklik:**
  - `OVSYNC_BASLAT` ve `TOHUMLAMA_PLANLI` görev tipleri `_katTipMap`'e uygun kategoriye eklenir (Tanı/Tedavi-benzeri mevcut "üreme" kategorisi varsa oraya; yoksa `diger` kapanmasın diye açıkça listelenir) — yoksa kartlar "Diğer"e düşer ya da hiç görünmez.
  - `TOHUMLAMA_PLANLI` kartında **kaynak etiketi**: `kaynak` alanından türetilir — `PG_TOHUMLAMA:` → "PG sonrası (+48s)", şablon TAI (`kaynak` şablon ref) → "Şablon TAI", ilk tohumlama zinciri → "İlk tohumlama (D50→D60)". T1'den: kartta **"X gün kaldı / X gün gecikmiş"** dinamik etiketi.
  - `OVSYNC_BASLAT` kartı: hedef tarih (D50) ve beklenen TAI tarihi (hedef+10, 10:00) görünür; düve/inek ayrımı ("Düve — 12a21g" / "İnek — doğum+51"); [Başlat] ve [İptal] butonları. **Gebe inek kartında/hayvanında buton DOM'unda hiç olmamalı** (sunucu yine kapatır — nihai otorite sunucu; UI yalnız bilinen muafiyetleri önceden gizler).
  - Tüm dinamik değerler `data-x="${escAttr(...)}" + this.dataset.x` kalıbıyla basılır; `onclick="fn('${escAttr(v)}')"` YASAK (helpers.js:91–95 sözleşmesi).
- **Kabul ölçütü:** Görev ekranında `OVSYNC_BASLAT` kartı doğru kategoride, hedef+TAI+etiketle görünüyor; [İptal] görev iptal yoluna düşüyor (islem_log); `TOHUMLAMA_PLANLI` kartı üç kaynak etiketini doğru gösteriyor; DOM'da escAttr dışında string interpolasyonu yok (kod incelemesi + birim test).

## P4 — Protokol uyarıları ekranı: OVSYNC_BASLAT (SK9)

- **Dosya/fonksiyon:** `js/ui.js` `_showProtokolEkran` (ui.js:1496) + `_satirHtml` (ui.js:1518); veri kaynağı A1'in genişlettiği `protokol_eksik_tara` ya da yeni `ovsync_baslat_uyarilari` salt-okuma RPC (**A1 bağımlılığı — sözleşme A1 ile kilitlenir**).
- **Değişiklik:** `hedef_tarih − 2 gün ≤ bugün` olan açık `OVSYNC_BASLAT` görevleri uyarı ekranında listelenir (Gecikmiş/Yaklaşan bölümlerine mevcut `_renk` mantığıyla); satırda küpe, inek/düve, hedef (D50), TAI tarihi; satır dokunuşu → [Başlat] (`start_first_service_protocol`, kart tepkisi: vaka + seans + TAI kartı yerinde tazelenir) ve [İptal]. `s := GREATEST(hedef, bugün)` nedeniyle hedefi geçmiş kart "gecikmiş" renkte ama aynı akışla başlar.
- **Kabul ölçütü:** hedef−2g öncesi kart görünmez; hedef−2g'de görünür; [Başlat] sonrası `OVSYNC_BASLAT` kartı kapanır, yeni TAI kartı (`TOHUMLAMA_PLANLI`, "Şablon TAI" etiketi) görev listesinde belirir; sunucu `atlandi:<neden>` dönerse toast + kart kapanır.

## P5 — PG kapısı modalı (tekil yol)

- **Dosya/fonksiyon:** `js/ui.js` (yeni `_pgKapiModal`, mevcut modal-router kalıbıyla — `tests/modal-router.spec.js`); çağrı yerleri `js/forms.js` `submitInsem` DEĞİL, hızlı uygulama/seans tamamlama submit akışları.
- **Değişiklik:** Sunucu `RAISE` (MK6) ile dönen `PG_KAPI:` hataları reaktif yakalanır (her uygulamada ön-`pg_uyari_kontrol` önizlemesi YOK — devrilmiş fikir; tekil yol +1 RPC ve TOCTOU yüzeyi):
  - `BLOCK_PREGNANT` → bilgi modalı, "Yine de uygula" BUTONU YOK.
  - `REQUIRE_ACK_PENDING` → tek modal: son tohumlama bilgileri (tarih, deneme no, gün), gerekçe alanı, ve **[Boş ata ve uygula]** tek-zincir butonu (T1): sırayla `tohumlama_sonuc_bos` → başarılıysa aynı zincirde uygulama RPC'si `p_pg_onay=true, p_pg_gerekce` ile tekrar; buton "İşleniyor…" kilitli, ikinci dokunuş yarış yaratamaz; `source_id` idempotent (UNIQUE). İki-adımlı ayrı [Boş ata]→[Uygula] akışı KULLANILMAZ (devrilmiş). Gerekçe boşsa buton pasif.
  - `BLOCK_CATALOG_UNRESOLVED` → yönlendirici bilgi mesajı.
  - Offline replay'de `p_pg_onay` taşınamadığından onay kaybı **fail-closed** kabulüdür: uygulama kaydı kuyruğa alınırsa yeniden denendiğinde kapı yine sorar (T3 belgelenmiş kabulü).
  - Modal `history.pushState({protokol:true})` kalıbını izler (L4-08): Android geri tuşu modalı kapatır, dash'e atlasız (mevcut modal-router invariant'ı; kabul testine eklenir).
- **Kabul ölçütü:** Bekliyor inekte PG → modal → [Boş ata ve uygula] → tohumlama `Boş`, uygulama kaydı var, +48s `TOHUMLAMA_PLANLI` görevi açılır (A1 sonrası entegrasyon testi); onaysız ağ çağrısı yapılmaz (network assert: `hizli_uygulama` yalnız `p_pg_onay=true` ile çağrılır); gebe inekte "Yine de uygula" DOM'da yok; geri tuşu modalı kapatır (modal-router testi).

## P6 — Erteleme modalı

- **Dosya/fonksiyon:** `js/ui.js` (yeni `_erteleModal`, mevcut tarih seçici `tests/tarih-secici.spec.js` kalıbıyla) + `js/forms.js` submit sarmalayıcı; RPC `tohumlama_gorev_ertele` (A1 bağımlılığı).
- **Değişiklik:** `TOHUMLAMA_PLANLI` kartından [Ertele]: tarih seçici (geçmiş gün seçilemez — RPC `GECMIS_TARIH`'i de yakalar) + saat girişi (NULL → mevcut hedef_saat). **Canlı önizleme:** pencere yuvarlaması JS aynası `pencereYuvarla` (config'den tek kaynaktan MK1 pencereleri `[09:00,12:00],[18:00,21:00]`) ile hesaplanır ve "Kaydedilecek: gg.aa HH:MM" olarak gösterilir (T2). Dönüşte `uyari='ERTELEME_7_GUN_ASILDI'` → sarı uyarı toast/bant; `toplam_erteleme_gun` gösterilir.
- **Kabul ölçütü:** 12:30 seçili → önizleme 18:00; 22:00 → ertesi gün 09:00; başarılı erteleme kartta yeni hedef+saatle görünür ve `TOHUMLAMA_ERTELE` etiketi geçmiş ekranında; 8 günlük erteleme → uyarı gösterilir ama kayıt gerçekleşir (MK2).

## P7 — Toplu PG sonucu modalı

- **Dosya/fonksiyon:** `js/ui.js` (yeni `_topluSonucModal`); `js/forms.js` `submitBulkIlac` (forms.js:3822).
- **Değişiklik:** `bulk_ilac` dönüşündeki `applied[] / blocked[] / requires_ack[]` ile kaydırılabilir TEK modal: applied (yeşil), blocked (kırmızı, sebep etiketi `BLOCK_PREGNANT` vb.), requires_ack (sarı). Requires_ack satırında gerekçe + onay onay kutusu; **[Seçilenleri tekrar gönder]** yalnız `requires_ack` içindeki işaretli alt kümeyi `p_pg_onaylar` ile yeniden gönderir — `applied` seti asla yeniden gönderilmez (stok çift düşüm koruması, T1 Risk #6). Önizleme: toplu gönderim ÖNCESİ `pg_uyari_kontrol` önizlemesi bu yolda KULLANILIR (tekil değil — değerlendirme kararı) ve modal "N hayvan engellenecek, M onay ister" ön bilgi verir.
- **Kabul ölçütü:** Karışık toplu gönderimde stok yalnız `applied` + onaylı tekrar kadar düşer ( ağ/DB assert); tekrar gönderim istek gövdesinde `applied` id'leri yok; tek modal, modal-içi gezinti yok; escAttr disiplini.

## P8 — Hızlı uygulama: uygulama anı (tarih + saat)

- **Dosya/fonksiyon:** `js/forms.js` hızlı uygulama submit; `js/ui.js` hızlı uygulama form satırı.
- **Değişiklik:** Opsiyonel "Uygulama zamanı" alanı: **tarih seçici + saat girişi birlikte** (T1; yalnız saat DEĞİL — MK7 7 günlük geç kayıt penceresi gün seçimi gerektirir). Default "Şimdi" (boş → `p_occurred_at` gönderilmez). Seçili değer İstanbul saat dilimiyle `timestamptz`'e çevrilip `p_occurred_at` olarak gönderilir; sunucu `PG_ZAMAN_GECERSIZ` dönerse P1 mesajıyla kullanıcıya döner (5 dk ileri / 7 gün geri).
- **Kabul ölçütü:** Alan boş → istek gövdesinde `p_occurred_at` yok, davranış bugünküyle aynı; "dün 19:30" seçili → istekte doğru timestamp; +8 gün eski seçim → sunucu hatası P1 mesajıyla görünür, kayıt yok.

## P9 — Tohumlama kaydı sonrası senkronizasyon özeti

- **Dosya/fonksiyon:** `js/forms.js` tohumlama submit akışı (`submitInsem`/planlı yol, forms.js:317/334 civarı).
- **Değişiklik:** `tohumlama_kaydet`/`planli_tohumlama_kaydet` dönüşünde `kapatilan_senkronizasyon_vakalari` varsa (boş değilse) başarı alert'ine additive özet eklenir: "Kapatılan senkronizasyon vakası: N (iptal seans X, iptal görev Y)". Mevcut anahtarlar/akış değişmez; alan yoksa davranış bugünküyle birebir.
- **Kabul ölçütü:** Açık Ovsync vakalı hayvanda tohumlama → özet alert görünür, vaka listesinde vaka kapalı (`TOHUMLAMA`); vakasız hayvanda ek çıktı yok; dönüş anahtarlarından hiçbiri eskiyen yerde kırılmaz (birim test: eski dönüş şekli).

## P10 — Bildirimler (sahip kararı: D50 tetik anı detaylı bildirim; SPEC §S-8 görünürlük)

- **Dosya/fonksiyon:** `js/ui.js` (yeni `_bildirimGonder` yardımcısı + uygulama açılış kontrolü), `js/config.js` (bildirim tercih anahtarı).
- **Değişiklik:**
  - **B1 — D50 başlatma bildirimi:** P4'teki [Başlat] başarı dönüşünde (`start_first_service_protocol` → case_id/seans/TAI) detaylı browser bildirimi (Notification API): küpe, inek/düve, seans sayısı, TAI tarihi+saati; bildirim dokunuşu → hayvan kartı. Panel satırı da aynı anda güncellenir (kalıcı kaynak panel; bildirim yardımcı kanal — tarayıcı kapalıysa bildirim düşer, bilgi kaybolmaz).
  - **B2 — açılış özeti:** uygulama açılış/refresh'te `ovsync_baslat_uyarilari` içinde `hedef_tarih ≤ bugün` (gecikmiş/bugün) kayıt varsa TEK özet bildirim: "N hayvanda ilk tohumlama protokolü başlatılacak" (cron yedek taramasının UI aynası; birden fazla hayvan → tek bildirim, liste panelde).
  - **B3 — izin yönetimi:** Notification izni yoksa sessiz düşme YOK — panel başlığında rozet "bildirim kapalı" + ilk fırsatta tek izin istemi (`Notification.requestPermission` yalnız kullanıcı etkileşiminden; sayfa yüklenirinde otomatik istem YASAK). Reddedilmişse rozet kalır, bildirim denenmez (gürültü yok), panel çalışır.
  - Bildirim gövdesi `escAttr`'ten geçer; bildirmler yalnız bu iki olaydır (spam yok).
- **Kabul ölçütü:** [Başlat] sonrası izin verildiyse bildirim doğar (içerik: küpe+TAI), reddedildiyse rozet görünür ve hata yok; açılışta gecikmiş D50 varsa tek özet bildirimi; izin istemi yalnız etkileşimden tetiklenir (test: yükleme sırasında requestPermission çağrılmaz).

---

## Açık bilinen bağımlılıklar (A3 girişinde sahibe hatırlatılır)

1. `ovsync_baslat_uyarilari`, `pg_uyari_kontrol`, `start_first_service_protocol`, `tohumlama_gorev_ertele` RPC'leri A1 çıktısı — P4/P5/P6/P7 entegrasyon testleri A1 bitmeden koşulamaz (birim testler mock sözleşmeyle yazılır).
2. SK9 veri kaynağının adı (genişletilmiş `protokol_eksik_tara` mı yeni RPC mi) A1'de netleşir; P4 buna göre bağlanır.
3. Bayrak kapalıyken: yeni UI yalnız yeni dönüş anahtarı ya da `PG_KAPI:` hatası geldiğinde devreye girer; mevcut akışlar bit-bit aynı kalır (MK5 frontend aynası).
