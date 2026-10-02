# SENTEZ — Tek-ekran Ovsync protokol takip sistemi: tasarım malzemesi (brainstorm girdisi)

Tarih: 2026-09-28 · Yazar: lead-arastirma (ovsync-takip @ c9122fd)
Girdiler: `w1-kod-raporu.md` (8 yüzey, 14 parça, 9 gap — kanıt: [W1]) ·
`w2-veri-modeli-raporu.md` (17 nesne, A1-A10 açık — kanıt: [W2]) ·
`.harness/references/domain-rules.md` §18 (bağlayıcı kurallar) ·
sahip vizyonu (W3 prompt başlığı): *hangi hayvan hangi adımda · beklenen tarih geçti mi ·
protokol sonlandı mı · nasıl sonlandı*.

> Bu belge TASARIM MALZEMESİDİR — spec değil. Fakt iddialar [W1]/[W2]/[CONFIRMED]/[OBSERVED]
> etiketiyle raporlara bağlanır; tasarım önerileri **öneri** düzeyindedir, sahibin brainstorm'u
> ile kesinleşir. W3 (dış sektör araştırması, sahibin koşacağı `w3-dis-sektor-arastirmasi-PROMPT.md`)
> sonuçlandığında §2 seçenek tablosu yeniden gözden geçirilir.

---

## 1. Ekranın bilgi birimi: "takip satırı" (temel tasarım kararı)

Sahibin dört sorusu tek satır tipine indirgenir: **hayvan × zincir**. Bir hayvanın ovsync
yaşamı zaten tek zincirdir (aktif senkronizasyonda ovlama yok — domain-rules §18.12 kapsam),
dolayısıyla satır anahtarı `hayvan_id` + zincir evresidir. Dört evre, ekranın dört sabit bölümü olur:

| Bölüm | Evre | Veri kaynağı (W2 kanıtıyla) | Bugünkü sayı [W2 §3] |
|---|---|---|---|
| **① Başlatılmayı bekleyenler** | kural günü geldi/gelecek, vaka yok | açık `gorev_log` `OVSYNC_BASLAT` (30) + görevsiz pencere adayları (`ovsync_baslat_uyarilari` gorevsiz CTE) | 30 görev |
| **② Aktif zincirler** | vaka açık, gün/seans ilerliyor | `cases protocol_family='OVSYNC' AND status='active'` (12) + gün/görev birleşimi | 12 vaka |
| **③ Bugün & geciken** | yatay kesit: vakti gelen + geciken | açık `TEDAVI_GUN/TEDAVI_SEANS/TOHUMLAMA_PLANLI` görevleri (`hedef_tarih` karşılaştırması) | 4 geciken gün + 12 TAI |
| **④ Sonlananlar** | vaka kapalı — nasıl kapandı | `cases status='closed'` + `close_reason` ∈ {TOHUMLAMA, PG, ERKEN_KAPANIS, IPTAL, NULL(eski)} | 23 |

Bu bölümleme mevcut hiçbir yüzeyde birleşik yok [W1 gap 1-2]; `ovsync_baslat_uyarilari` yalnız ①'yi
kısmen kapsıyor [W1 §2.5]. ③'ün "bugün" kesiti Görevler ekranının işi — takip ekranında **filtre
çipi** olarak yaşar (varsayılan: ② aktifler + ③ gecikenler birleşik görünüm).

**Satır şeması (öneri):**
```
[kupe] [grup] [padok] [taban_turu: Düve+12a21g / Doğum+51 / Abort+51]
  ② d0● d7● d8◌ d9◌  TAI 07.10⏳ │ sonraki: d8 · 26.09 │ ⚠d7 +2gün gecikti   [▶Aksiyon]
① hedef 12.10 (6 gün) 🔒pencere−2 │ [▶ Başlat kilidi: _ovsyncBaslatKilitHtml dili]
④ [sonuç rozeti] kapandı 23.09 · toh_sonuc: — (A3 yüzünden şemadan okunamaz)
```
- Gün şeridi d0/d7/d8/d9 + TAI: Ovsynch-56 şablonunun 4 kalemi + d10 tohumlama planı [W2 §1.1
  tedavi_sablonu_kalem; §2.3 gün 1..4 = +0/+7/+8/+9 tarih deseni].
- Durum sözlüğü mevcut renk dilini kullanır: tamam=yeşil, planlandı=amber/gri, gecikti=kırmızı,
  uygulanmadi=soluk [W1 parça 14 + timeline tohState].
- Kural günü hesaplanamayan satır: sentinel-son sıralama + "kural günü yok" etiketi [W1 parça 4].

## 2. Ekran deseni seçenekleri

| Seçenek | Betim | Güçlü | Zayıf | Verdict |
|---|---|---|---|---|
| **A. Kart-liste + gün-şeridi** (önerilen) | Mevcut `.arow` kart dili; satıra 5 noktalı mini-ilerleme (d0·d7·d8·d9·TAI) gömülü | Mobil-first CSS'e sıfır yeni bileşen [W1 gap 7'nin cevabı]; arama/sıralama/checkbox kalıpları hazır [W1 parça 5-7]; gün-şeridi matris bilgisini kartta taşır | Çok-kolonlu yoğun görünüm değil | **FAZ 1** |
| **B. Hayvan×gün matrisi** | satır=hayvan, kolon=d0..d9/TAI/sonuç hücreleri | Sürü ölçeğinde en hızlı tarama; W3 sektör klasiği | Yeni grid bileşeni (CSS setinde yok [W1 gap 7]); mobil yatay scroll; padok/grup bağlamı dar | FAZ 2 (masaüstü geniş görünüm, A'nın üstünde toggle) |
| **C. Kanban (aşama kolonları)** | kolon=Bekliyor→d0→…→Sonuç | Aşama dağılımı anında görünür | Kolon sayısı az (6) ve ①/④ kolonları kalabalık (30+23) — dengesiz; sürükleme etkileşimi koda yabancı | ÖNERİLMİYOR (bilgi, A'nın bölüm başlıkları + üst KPI şeridinde zaten var) |
| **D. Takvim görünümü** | gün-gün ızgara | "Bugün ne var" sorusuna güçlü | Geciken vurgusu zayıflar; 30 bekleyen 2027'ye uzanan hedefle takvimi şişirir [W2 §2.1]; kanonik tarih bileşeni tek-seçim için tasarlı [ui-map Canonical date] | ÖNERİLMİYOR (③ bölümü + tarih-pencere çipleri aynı ihtiyacı karşılar) |

**Net öneri:** A ile başla (kart-liste + gün-şeridi + 4 bölüm + KPA üst şeridi); B'yi masaüstü
için FAZ 2 opsiyonu olarak not et; C/D için sektörden (W3) baskın bir desen çıkarsa yeniden değerlendir.

## 3. Veri katmanı: TEK yeni salt-okunur RPC (kritik öneri)

**`ovsync_takip_listele(p_padok?, p_pencere_gun?)` → jsonb `{ok, satirlar:[…]}`** — W1 parça 2'nin
CTE modelinin genişletilmesi (gorevli UNION gorevsiz'e aktif-zincir ve kapalı CTE'leri eklenir):

- Satır başına sunucu üretir: `hayvan_id, kupe_no, grup, padok, taban_turu, bolum(①②③④),
  gorev_id (①), case_id, start_date (②), gunlar:[{gun_no, tarih, planned_time, durum
  (planli|tamam|gecikti|uygulanmadi), tamamlandi_tarihi}] (②), tai:{gorev_id, hedef_tarih, hedef_saat,
  durum, kaynak: sablon|pg} (②), sonraki_gun, gecikme_gun, close_reason (④: NULL→'ESKI'),
  toh_sonuc (hayvan-seviyesi `tohumlama.sonuc` — gebelik otoritesi, domain-rules §18.11)`.
- **Neden RPC:** (a) day_id/gun_no `gorev_log.aciklama` JSON string içinde — client-side parse
  4 tablo join'i demek [W2 A1-A2]; (b) `tohumlama.case_id` canlıda 0 dolu — vaka↔tohumlama köprüsü
  ancak sunucuda kaynak-metni/`pg_application_event.tohumlama_gorev_id` üzerinden kurulabilir [W2 A3,
  §2.3-10]; (c) PostgREST'te gruplu count 42803 — KPA sayımları RPC içinde [W2 A8]; (d) eşik/pencere
  sabitleri üçüncü kez JS'e kopyalanmaz — sunucudan taşınır (`ovsync_baslat_uyarilari`'nın
  `tai_tarihi` türetmesi doğru desen) [W1 gap 8].
- **Uygulama disiplini (bağlayıcı kurallardan):** SECURITY DEFINER + authenticated-only grant
  (anon EXECUTE açığı dersi: yeni migration anon GRANT yazmaz); salt-okuma; `RPC_TABLES`'a pull
  setiyle kaydolur (`cases, treatment_days, treatment_day_uygulamalar, gorev_log, hayvanlar`) —
  offline'da bayat-rozetli zayıf görünüm FAZ 2 kararı [W1 gap 5]; online-only yazma akışları
  (E6 üç-ayağı) değişmez [W1 parça 10].

## 4. Mevcut koda entegrasyon noktaları

| Katman | Nokta | Bağlantı biçimi | Kanıt |
|---|---|---|---|
| UI-giriş | `js/ui.js:_dashBands` | Yeni bant: "🔄 Ovsync zincirleri (12 aktif · 4 geciken)" → tüm-liste açar; üç-katman deseni aynen | [W1 §2.1, parça 1] |
| UI-giriş (2) | 🔔 panel `_showProtokolEkran` 🌱 bölümü | "Tüm takibi aç →" linki; mevcut önbellek/cache-invalidate akışına katılır | [W1 §2.5, parça 9] |
| UI-yüzey | yeni `_showOvsyncTakip` full-sheet | Non-router bottom-sheet kalıbı (pushState + `_modalBackGuard`); router modalı DEĞİL | [W1 parça 3] |
| UI-satır butonları | `_ovsyncBaslatKilitHtml` + `ovsyncBaslat`/`ovsyncIptal` + `_erteleBtnHtml` | Tek-kaynak üreticiye bağlan — buton mantığı kopyalanmaz; pencere/kısır kilidi bedava | [W1 parça 8, §2.7] |
| UI-aksiyon zinciri | TAI satırı → `openTaskDet` → "🐄 Tohumlamayı Kaydet"; gün satırı → `openCaseDet` (renderCaseTimeline) | Mevcut detay motorları yeniden kullanılır; takip ekranı yalnız satır-özet üretir | [W1 §2.3, §2.8] |
| UI-PG aksiyonu | `_pgKapiHata` sarmalı | Takip ekranından PG dokunuşu olursa zorunlu (düz Hata toast YASAK) — FAZ 1'de PG aksiyonu yok, gün detayına düşer | [W1 parça 11; §18.8] |
| api.js | `RPC_TABLES` + `rpc()` sarmalı + `window.__ovsyncTakip` cache üçlüsü | bayat-fallback rozeti + yazma sonrası invalidate (ovsyncBaslat/protokol_iptel/erteleme sonrası `null`) | [W1 parça 9; rpc-reference D2] |
| DB | yeni RPC migration'ı | `supabase/migrations/` append-only + `scripts/db-validate.sh` kapısı; demo/prod ayrı uygulanır | [db-validation kuralı] |
| Filtre/sıralama | blok-önceden-derlenmiş arama + katmanlı sıralama anahtarı + tarih-pencere çipleri (bugün/7g/30g/özel) | Mevcut kalıpların aynası; "gün X'te olasılar" sorgusu RPC parametresine iner | [W1 parça 5-6, gap 3] |
| Görevler ekranı kesişimi | `_uremeVakaCaseIds` (`protocol_family='OVSYNC'`) | Takip ekranı aynı seti paylaşır — kategori süzmesi tek kaynak | [W1 §2.3] |

## 5. Üst KPA şeridi (ilk sürüm önerisi; W3 soru-5'in lokal karşılığı)

`Aktif 12 · Bugün vakti gelen N · Geciken 4 · Bekleyen başlatma 30 · Kapanan (30 gün) N —
sonlanma kırılımı: TOHUMLAMA 10 / PG 1 / ERKEN 4 / IPTAL 1 / Eski 7` [sayılar W2 §3'ten, OBSERVED].
Protokol başarı oranı (kapalı içinden TOHUMLAMA %'si) FAZ 2 — payda tanımı (iptal dahil mi?)
sahip kararı.

## 6. Açık kalemler → sahibine sorular (brainstorm gündemi)

1. **Yüzeyin yeri:** full-sheet (öneri) mı, Üreme sekmesine 6. tab mı, yoksa alt-nav bağımsız ekran mı?
2. **④ Sonlananlar derinliği:** satır-özet yeterli mi, yoksa kapanan zincirin gün-gün dökümü
   (W1 gap 6: arşiv görünümü yok — `openCaseDet` kapalı vakada açılıyor ama listeden erişim yok)?
3. **A3 (tohumlama.case_id 0 dolu):** sonlanma→sonuç-tohumlama köprüsü FAZ 1'de RPC içinde
   kaynak-metinden mi çözülür, yoksa yazma yolunda `case_id` doldurmak ayrı bir migration işi mi?
   (İkincisi kalıcı çözüm ama `tohumlama_kaydet` gövdesi değişimi = sahip kapısı.)
4. **Toplu işlem:** FAZ 1 tekil aksiyonlar (öneri); toplu erteleme/toplu gün-tamamla FAZ 2 mi?
   Checkbox barı kalıbı hazır [W1 parça 7].
5. **A10 (day_no ↔ şablon gun_no eşlemesi):** canlıdan kanıtlanamadı; RPC gövdesi
   (`start_first_service_protocol`) satır-satır okunarak etiketleme kuralı ("Gün 8 · PG") doğrulanmalı —
   ekran etiketleri bu doğrulama olmadan "1./2./3./4. uygulama" nötr dilinde kalmalı (öneri).
6. **Offline:** FAZ 1 online-only okuma + bant sessiz-düşer deseni (öneri) mi, IDB'den bayat zayıf
   görünüm mü?
7. **Doküman-drift (ayrı iş, bu ekrandan bağımsız):** sessiz eşik canlıda 50, rpc-reference +
   domain-rules §4 hâlâ 55 diyor [W1 belge-drift notu; migration 20260925000002]. Referans doküman
   güncelleme kalem olarak root'a taşınmalı.
8. **W3 entegrasyonu:** sahibin dış sektör bulguları geldiğinde §2 tablo + KPA seti gözden geçirilir
   (özellikle: sektörde matris (B) baskınsa FAZ 2 öne çekilir).

## 7. Risk listesi (tasarım yanlışlarına karşı)

- **Çift-bayrak tuzağı:** "kapandı" ≠ "iptal edildi" — her liste `(tamamlandi, iptal)` ikilisiyle
  yorumlanır, tek durum kolonu varsayılmaz [W2 A6].
- **NULL close_reason:** 7 eski vaka "eski/bilinmiyor" sınıfı; sessiz varsayılan YASAK [W2 A7].
- **Şablon-TAI vs PG-TAI:** aynı hayvanda eskisi iptal+tamam, yenisi açık olabilir ("son PG kazanır")
  [W2 §2.3-11] — satır yalnız AKTİK TAI'yı gösterir, geçmişi detayda taşır.
- **Sabit kopyalama:** pencere (−2), TAI (+10), eşikler JS'e yazılmaz; RPC satırından okunur [W1 gap 8].
- **Kanun değişkenliği:** `ovsync_pg_kurallari_aktif` bayrağı kapalıysa bu ekranın ①/② bölümleri
  anlamsızlaşabilir — RPC bayrağı okuyup `bayrak_kapali` durumu dönmeli (fail-closed, sessiz boş liste YASAK).

---
*Üretim disiplini: salt-araştırma — kod/DB yazılmadı, worktree temiz. Fakt kanıtlar W1/W2
raporlarının [CONFIRMED/OBSERVED] etiketlerine bağlı; bu dosyadaki tasarım içerikleri öneri düzeyinde.*
