# Ovsync Takip Ekranı — Tasarım (spec)

- Tarih: 2026-09-28 · Durum: sahip tasarım onayı verildi (brainstorm turu, aşağıda karar günlüğü) — spec incelemesi bekliyor
- Dal: `ovsync-takip` @ c9122fd (bu belge bu dalda yazıldı)
- Girdiler: `runs/2026-09-28-ovsync-takip/db-ovsync-durum-raporu.md` (PROD envanter) ·
  `runs/2026-09-28-ovsync-takip/w1-kod-raporu.md` (8 yüzey, 14 parça, 9 gap) ·
  `runs/2026-09-28-ovsync-takip/w2-veri-modeli-raporu.md` (17 nesne, A1-A10) ·
  `runs/2026-09-28-ovsync-takip/sentez-tasarim-malzemesi.md` ·
  `.harness/references/domain-rules.md` §18 (bağlayıcı)
- Mockup: `runs/2026-09-28-ovsync-takip/mockup/ovsync-takip-mockup.png` (ekran) ·
  `dashboard-giris-mockup.png` (giriş) · `yasam-dongusu-mockup.png` (hayat döngüsü + geçiş
  haritası + durum-aksiyon matrisi) — ucuz taslak, ürün kodu değil

## 1. Amaç

Tek ekrandan tüm ovsync protokol vakalarının izlenmesi: hangi hayvan hangi adımda, beklenen
tarih geçti mi, protokol sonlandı mı, nasıl sonlandı, sonuç ne bekleniyor. Mevcut dashboard
yüzeyleri (sessiz hayvanlar, ileri gebeler) bireysel liste özetidir; zincir-düzeyi takip
yoktur [W1 gap 1-2].

**Veriyle doğrulanmış gereklilikler (P-bulguları, PROD 35 vaka):**
- P1: çiftlik DALGA ile çalışır (09-13 kohortu 11 vaka aynı gün; 09-24 hedefli 9 vaka toplu
  kaydırıldı 09-27'ye; gün1 toplu uygulandı) → dalga gruplaması zorunlu.
- P2: hedef≠fiili sapma NORMAL'dir (kayırmalar, erken TAI, görevsiz girişler) → görünür ve
  etiketli olmalı; veri bükmeleri (iptal+işaretli-tamam) görünür kalır.
- P3: "TAI yapıldı, sonuç bekleniyor" en kalabalık gerçeklik (11 kayıt, kontroller
  10-08…10-14) → birinci sınıf bölüm; boş→yeniden deneme döngüsü görünür (902, 197, 173).
- P4: TAI saat türetme şüphesi — küpe 002 TAI hedefi 19:00'a düştü (PG_YERINE zincirinden);
  pratikte tohumlama sabah yapılır, akşam saati günlük hayata uymayabilir → B5 backlog.
- P5: koruma boşlukları yaşanmış (küpe 51: kural gününden ~3 ay erken, 4 ilaç, TAI'sız
  kapanış; küpe 19: gelecek tarihli günler "tamamlandı" kapatılmış) → doğruluk kuralları §7.

## 2. Sahip karar günlüğü (brainstorm 2026-09-28)

| # | Karar | Seçim |
|---|---|---|
| K1 | Birincil bakış | **Birleşik**: üstte bugün/geciken şeridi + aktif zincirler dalga gruplu, tek ekranda |
| K2 | Sonuç bekleniyor | **5. bölüm** (TAI tarihi + kontrol penceresi sayacı); mevcut gebelik-kontrol listesiyle tamamlayıcı çapraz bağ |
| K3 | Sapma gösterimi | **Display-only**: hedef→fiili ok + kayma rozeti + erken/görevsiz etiketi; şemaya dokunma; model düzeltmesi ayrı backlog kalemi |
| K4 | Yüzey | **Ovsync'in kendi dashboard sayfası** — `pg-*` ailesine yeni sayfa (`#pg-ovsync`, `goTo('ovsync')`); modal/bottom-sheet DEĞİL (sahip: "modal zayıf kalabilir, ovsync dashboardı gerekli") |
| K5 | Toplu işlem | FAZ 1'de **yeni toplu mekanizma YOK** — mevcutlara bağlanır (F1 çoklu kaydırma Görevler'de, vaka-toplu-ac, `topluHepsiniUygula`); "çoklu-vaka görünümü" eksiği bu ekranla kapanır |
| K6 | Vaka↔sonuç köprüsü | RPC içinde kaynak-metinden çözüm; kalıcı çözüm (`tohumlama_kaydet`'e case_id) **backlog** (sahip kapısı) |
| K7 | Giriş | **Dashboard üst stat butonlarının (`.dash-row`, `_dashStatRow` ui.js:259-270) boş 6. hücresine buton** — `.sc` ailesi: sayı + "🔄 Ovsync ›"; renk sınıfı kritikte `alert`/uyarıda `warn`; rozet basit; dashboard'a bant/satır YOK; ikincil: 🔔 protokol paneli "Tüm takibi aç →" |
| K8 | Aksiyon mimarisi | **Hibrit** — tek-dokunuş işler satırda inline (`ovsyncBaslat`, ertele/kaydır; mevcut RPC'ler); form/kayıt gerekenler mevcut modalları açar (`openTaskDet`→"Tohumlamayı Kaydet", `openCaseDet`→gün uygulama+timeline). Buton bileşenleri mevcut tek-kaynak üreticilerden. |
| K9 | Görevler ilişkisi | Ovsync görevleri Görevler'de **kalır** (rutin + rozet sayıları bozulmaz) + **kategori çipi/filtre** + **"Tüm ovsync takibi →"** köprüsü `goTo('ovsync')`; çift yönlü geçiş. |
| K10 | 🔔 protokol paneli | Mevcut 🌱 izole ovsync bölümü kalır (satır aksiyonlarıyla) + "Tüm takibi aç →" linki. |
| K11 | Gezinme sözleşmesi | **Hub'a mecburiyet yok; geri = kaldığın yere birebir dönüş.** `goTo('ovsync')` mevcut pushState/popstate'ye katılır (app.js:104-152); modal = sayfa geçişi değil (modal-router invariant — geri modalı kapatır, sayfa yerinde); dönüşte filtre/bölüm durumu (`_curOvsync*` deseni) + kaydırma konumu (scroll kaydet/geri yükle) korunur; alt-nav'a yeni giriş YOK. |

## 3. Ekran omurgası (yukarıdan aşağı)

```
KPA şeridi   : Aktif N · Bugün N · Geciken N · Sonuç beklenen N (kontrol penceresi) · Bekleyen başlatma N
BUGÜN&GECİKEN: canlı kartlar (ör. "Küpe 002 — TAI bugün 19:00 [▶]") — boşsa bölüm gizli
② Aktif zincirler — dalga gruplu kartlar
⑤ Sonuç beklenenler — satır: küpe + TAI tarihi + kontrol sayacı + deneme rozeti
① Başlatılmayı bekleyenler — hedef tarih sıralı; ilk 5 + "tümü (M)"
④ Sonlananlar (katlanır) — sonlanma rozeti + toh_sonuc
```

Dalga anahtarı (RPC türetir): vakayı açan `OVSYNC_BASLAT` görevinin `hedef_tarihi` birincil
anahtar; görevi olmayan (elle açılmış) vakalar `start_date` üzerinden grup kurar; yalnız başına
kalanlar "tekil başlangıçlar" grubunda toplanır. Grup başlığı: hedef→fiilen + hayvan sayısı +
ortak sıradaki adım. KPA sayıları RPC'den.

## 4. Satır şeması (②)

```
[kupe] [grup] [padok] [taban_turu] [sapma rozeti]
d0● d7◌ d8◌ d9◌ TAI⏳(tarih)      → nokta dili: tamam yeşil · plan amber · gecikti kırmızı · uygulanmadı soluk
alt: "1/4 uygulandı · sıradaki: 2. uygulama (PGs)"   [Gün detayı / ▶ TAI]
```
- Gün etiketleri **nötr**: "1./2./3./4. uygulama" — "Gün 8 · PG" etiketi `start_first_service_protocol`
  gövdesi satır-satır doğrulanana kadar YASAK (A10; doğrulama backlog).
- Sapma rozetleri: `hedef 09-24 → fiilen 09-27 (+3g)` · `erken 6g` · `görevsiz` · `2. vakası`.
- Satır aksiyonları mevcut motorlara bağlanır (kopyalanmaz): TAI satırı → `openTaskDet` →
  "Tohumlamayı Kaydet"; gün satırı → `openCaseDet` (`renderCaseTimeline`); ▶ Başlat →
  `_ovsyncBaslatKilitHtml`; ertele → `_erteleBtnHtml` (kural cache'i `ertelemeKurallariGetir`).
- PG dokunuşu FAZ 1'de YOK — gün detayına düşer (§18.8 PG onay kapısı korunur).

### 4b. Satır durum–aksiyon matrisi (hayat döngüsü kesitleri)

| Satır durumu | Görünüm | Aksiyon → nereye |
|---|---|---|
| ① pencere dışı | 🔒 kilitli + hedef tarih | buton yok (bilgi) |
| ① pencere içinde (hedef−2) | ▶ Başlat aktif | **inline** `ovsyncBaslat` → satır ②'ye taşınır |
| ② gün vakti geldi | amber nokta + tarih | **modal** `openCaseDet` (gün uygula) → dönünce yeşil |
| ② gün gecikti | kırmızı nokta + "+Ngün" | satır öne alınır + **inline** Ertele / `openCaseDet` |
| ②/③ TAI günü | "BUGÜN" rozeti | **modal** `openTaskDet` → "🐄 Tohumlamayı Kaydet" → vaka ⑤/④'e taşınır |
| ⑤ kontrol vakti geldi | sayaç 0'a indi | köprü → mevcut gebelik-muayene/sonuç akışı; sonuç: Gebe+ → ④ biter, Boş → yeni `OVSYNC_BASLAT` doğar → ① (loop) |
| ④ sonlanmış | sonlanma rozeti + toh_sonuc | `openCaseDet` salt-okuma timeline |

Hayat döngüsü loop'u böyle görünür olur: ① aday → ▶ başlat → ② d0·d7·d8·d9 → TAI → ⑤ bekle →
Gebe+ bitti / Boş yeni deneme → ①. Aynı hayvanda ikinci vaka `deneme_no` rozetiyle ("2. vakası —
önceki boş") görünür (PROD örneği: küpe 902).

## 5. Veri katmanı — TEK salt-okunur RPC

`ovsync_takip_listele(p_padok?, p_pencere_gun?)` → `jsonb {ok, bayrak_kapali, kpa{}, satirlar[]}`

Satır alanları: `bolum(①-⑤)`, `dalga_anahtari`, `hayvan_id, kupe_no, grup, padok, taban_turu`,
`gunler[{gun_no, tarih, planned_time, durum(planli|tamam|gecikti|uygulanmadi), tamamlandi_tarihi}]`,
`tai{gorev_id, hedef_tarih, hedef_saat, durum, kaynak(sablon|pg)}`, `sonraki_gun`, `gecikme_gun`,
`sapma{hedef_baslangic, fiili_baslangic, kayma_gun, erken_tai, gorevsiz_tai}`,
`close_reason(NULL→'ESKI')`, `toh_sonuc` (hayvan-seviyesi `tohumlama.sonuc` — gebelik otoritesi
§18.11; vaka köprüsü görev `kaynak` metninden), `deneme_no` (aynı hayvanda kaçıncı vaka),
`kontrol_pencere{baslangic, bitis, kalan_gun}` (⑤: GERÇEK TAI tarihinden +21g — erken TAI'de
kontrol tarihi de erkenleşir; PROD örneği: küpe 121 TAI 09-17 erken 6g → kontrol ~10-08).

Uygulama disiplini:
- `ovsync_baslat_uyarilari` CTE modelinin genişletilmesi (gorevli UNION gorevsiz + aktif-zincir
  + sonuç-bekleyen + kapalı CTE'leri).
- SECURITY DEFINER + yalnız authenticated grant (anon EXECUTE YASAK — eski ders).
- Sabitler (pencere −2, TAI +10, eşikler) RPC'den taşınır; JS'e kopyalanmaz.
- `protokol_ayar.ovsync_pg_kurallari_aktif=0` → `{ok:true, bayrak_kapali:true}` — sessiz boş
  liste YASAK (fail-closed).
- `RPC_TABLES` pull setine kaydolur (`cases, treatment_days, treatment_day_uygulamalar,
  gorev_log, hayvanlar, tohumlama`); okuma online-only, offline'da buton sessiz düşer
  (zayıf offline görünüm FAZ 2 kararı).
- Client cache `window.__ovsyncTakip`; yazma akışları invalidate eder (`ovsyncBaslat`,
  `protokol_iptal`, erteleme/kaydırma sonrası `null`).

## 6. Entegrasyon noktaları

| Katman | Nokta |
|---|---|
| Giriş butonu | `_dashStatRow` (ui.js:259-270) `.dash-row` satırına **6. `.sc` hücresi**: `🔄 Ovsync ›` + sayı (aktif zincir); sınıf: bugün aksiyon∨geciken∨kontrol-vakti-dolan>0 → `alert`, yalnız bekleyen-başlatma>0 → `warn`, sakin → `ok`; `onclick` → **`goTo('ovsync')`** (diğer stat butonlarıyla aynı desen) |
| İkincil giriş | 🔔 protokol paneli 🌱 bölümüne "Tüm takibi aç →" |
| Yüzey | index.html'de yeni sayfa `#pg-ovsync` (`pg-*` deseni) + yükleyici `loadOvsyncDash()`; `goTo()` sayfa dağıtıcısına (app.js:122-130 switch) `ovsync` dalı eklenir; geri dönüş standart sayfa navigasyonu; sayfa başlığı + KPA şeridi sayfanın kendi chrome'u |
| api.js | `RPC_TABLES` + `rpc()` sarmalı + `__ovsyncTakip` cache üçlüsü |
| DB | yeni migration `supabase/migrations/` append-only; `scripts/db-validate.sh` kapısı ZORUNLU; demo/prod ayrı uygulanır |
| Kesişim | `_uremeVakaCaseIds` (`protocol_family='OVSYNC'`) tek kaynak paylaşılır |
| Görevler köprüsü | Görevler listesinde ovsync kategori çipi/filtre + başlıkta "Tüm ovsync takibi →" → `goTo('ovsync')` |
| Hayat döngüsü köprüsü | ⑤ satırı kontrol vakti geldiğinde mevcut gebelik-muayene/sonuç akışına bağlanır; sonuçta satır ⑤'ten düşer → Gebe+ ④ biter / Boş yeni `OVSYNC_BASLAT` doğar → ① (loop); üç yüzeyin (ovsync·Görevler·🔔) sayıları TEK RPC kaynağından — çelişkili rozet yok |

### 6b. Gezinme sözleşmesi (sürtünmesiz geçiş — sahip 2026-09-28)

- **Hub'a mecburiyet yok** — yatay geçişler doğrudan: Ana ⇄ Ovsync ⇄ Görevler; ovsync'ten
  açılan modal kapanınca kullanıcı AYNI satıra, aynı kaydırma konumuna döner.
- `goTo('ovsync')` mevcut pushState/popstate mekanizmasına katılır (app.js:104-152) —
  telefon/tarayıcı geri tuşu önceki yüzeye döndürür; mevcut sayfalarla birebir aynı davranış.
- **Modal = sayfa geçişi değildir** — modal-router pushState invariant'ı (ui.js:1373 deseni):
  geri tuşu modalı kapatır, ovsync sayfası yerinde kalır ve tazelenir.
- **Dönüşte durum korunur:** filtre/bölüm durumu `window._curOvsync*` deseni (`_curTaskFilter`
  örneği) ile; **kaydırma konumu** sayfadan çıkarken kaydedilip dönüş yüklemesi sonrası geri
  yüklenir. Sayfaya her dönüşte veri TAZE yüklenir (bayat gösterme), konum eskisi gibi.
- **Alt-nav'a yeni giriş YOK** — nav kirletilmez; dönüş yolları: geri tuşu + sayfa başlığındaki ‹.

## 7. Doğruluk kuralları (P-bulgularından, bağlayıcı)

1. Görev durumu `(tamamlandi, iptal)` İKİLİSİYLE yorumlanır; tek kolon varsayılmaz (A5/A6).
2. Satırda yalnız AKTİF TAI; iptal/ geçmiş TAI'lar detayda ("son PG kazanır", §18.6).
3. Gelecek tarihli "tamamlandı" günleri `uygulanmadi` sayılır ve öyle gösterilir (A7 sınıfı).
4. `close_reason=NULL` → "Eski/bilinmiyor" etiketi; sessiz varsayılan YASAK (A7'ye ek 7 eski vaka).
5. Kırılgan köprü (kaynak-metin çözümü) çözülemezse satır `toh_sonuc=bilinmiyor` taşır — tahin YOK.
6. `tohumlama_durumu` alanı asla kullanılmaz (otorite değil, §18.11).
7. Test adlı hayvan satırı "test" notu taşır (kalıcı etiket mekanizması backlog).
8. Tanınmayan yapı/alan → "bilinmiyor" raporlanır; sessiz varsayılan YASAK.
9. **Yazma yolu politikası (bağlayıcı, sahip 2026-09-28):** ekran yeni yazma RPC'si/yolu İÇERMEZ;
   her aksiyon MEVCUT tekil protokol işlemi olarak girer (`start_first_service_protocol`,
   `protokol_iptal`, `vaka_kalan_gunleri_kaydir`/`_coklu`, görev-tamamlama, `tohumlama_kaydet`).
   Takip sayfası bu işlemleri çağırır/görünür kılar; paralel kayıt yüzeyi üretmez.

## 8. Fazlar

- **FAZ 1 (bu iş):** stat butonu + `#pg-ovsync` sayfası + RPC + Görevler çip/köprü + 🔔 "Tüm
  takibi aç" linki + gezinme sözleşmesi uygulamaları (§6b). Tekil aksiyonlar mevcut motorlara.
- **FAZ 2:** hayvan×gün matrisi (masaüstü toggle) · "bugün aynı adım → toplu tamamla" gömmesi
  (checkbox-bar kalıbı hazır) · offline zayıf görünüm · başarı-oranı KPA'ları (payda tanımı
  sahip kararı).
- **Backlog (ayrı kalemler, bu işin kapsamı DIŞI):**
  B1 `tohumlama_kaydet`'e case_id doldurma + backfill (kalıcı köprü; sahip kapısı)
  B2 görev durum modeline "erken/görevsiz girildi" meşru geçişi (P2 kalıcı çözüm)
  B3 test hayvanı etiket mekanizması
  B4 sessiz eşik doküman-drift (canlı 50, referanslar 55 — mig. 20260925000002)
  B5 TAI saat türetme gözden geçirmesi (P4: küpe 002 TAI 19:00 — pratikte uygulanabilirlik
     sahibine sorulmalı; ovsynch-56'da GnRH-sonrası TAI aralığı referansla doğrulanmalı)
  B6 `start_first_service_protocol` gövde okumasıyla gün etiketi doğrulaması (A10)
  B7 sonuç girilmiş-açık-kalmış vaka uyarısı (183 vakası: Gebe+ 08-01, vaka 09-10 kapandı)

## 9. Kabul ölçütleri

1. Migration `scripts/db-validate.sh` PASS.
2. RPC: `bayrak_kapali` yolu dahil; anon EXECUTE yok; KPA sayıları PROD verisiyle nokta-doğrulanmış.
3. Ekran: 5 bölüm + dalga gruplama + sapma rozetleri mockup ile tutarlı; boş bölümler gizli.
4. Girişler çalışır: stat butonu (rozet koşulu doğru) · 🔔 "Tüm takibi aç" · Görevler çip/köprü.
5. Playwright demo koşumu PASS; sahibe demo öncesi glmf-max koltukta UI test listesi PASS
   (proje kuralı "UI testi kapısı").
6. Yazma akışları sonrası cache invalidate doğrulanır.
7. AGENTS.md/CLAUDE.md, mevcut yazma akışları, deploy zinciri değişmez.
8. Gezinme sözleşmesi: Görevler↔ovsync↔dashboard yatay geçiş çalışır; geri tuşu doğru yüzeye
   döner; dönüşte kaydırma konumu ve filtre korunur; modal açıkken geri tuşu yalnız modalı kapatır.
9. Üç yüzey tutarlılığı: ovsync sayfası · Görevler çip sayısı · 🔔 bölüm sayısı aynı anda aynı
   değerleri gösterir (tek RPC kaynağı).
10. Yazma yolu denetimi (kod incelemesi): ekran yeni yazma RPC'si içermez; inline butonlar
    yalnız §7.9'daki mevcut işlemleri çağırır (§4b matrisi birebir uygulanır).

## 10. Açık notlar

- W3 (dış sektör araştırması) sahibin elinde; sonuç gelirse §3 deseni ve §8 FAZ-2 sırası
  gözden geçirilir (özellikle matris öne çekilir mi).
- Mockup PNG'ler atılabilir taslaktır; ekran gerçekleşmesi `.arow`/renk diliyle uyumlu kurılır.
