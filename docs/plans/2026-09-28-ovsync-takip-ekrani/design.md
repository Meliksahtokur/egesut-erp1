# Ovsync Takip Ekranı — Tasarım (spec v2)

- Tarih: 2026-09-28/29 · Durum: **v4 — sahip onaylı; sol plan-review (17 bulgu) sonrası sahip kararları §10c'de; plan düzeltmesi bu sürüme göre yapılır**
- Dal: `ovsync-takip` @ 40feed3 (v1) → v2 bu dalda, commit'siz çalışma kopyası
- Girdiler: `runs/2026-09-28-ovsync-takip/db-ovsync-durum-raporu.md` (PROD envanter) ·
  `runs/2026-09-28-ovsync-takip/w1-kod-raporu.md` · `runs/2026-09-28-ovsync-takip/w2-veri-modeli-raporu.md` ·
  `runs/2026-09-28-ovsync-takip/sentez-tasarim-malzemesi.md` ·
  `.harness/references/domain-rules.md` §18 (bağlayıcı; §18.13–16 bu turda eklendi)
- Mockup: `runs/2026-09-28-ovsync-takip/mockup/*.png` — v1 taslağı; v2 farkları §3 notunda

### v1 → v2 değişiklik özeti (mimar review 2026-09-28)

| # | v1 | v2 | Kanıt |
|---|---|---|---|
| R1 | RPC `RPC_TABLES`'a kaydolur | Kaydolmaz — harita yalnız pull isteyen yazma RPC'leri içindir; `__ovsyncUyarilar` deseni | `js/api.js:417-420` |
| R2 | "Üç yüzey tek RPC kaynağından" | Daraltıldı: ovsync sayfası + 🔔 🌱 bölümü aynı RPC; Görevler rozeti (yerel IDB) ve çan rozeti (iki RPC toplamı) kapsam dışı | `js/ui.js:2461-2471`, `:630-651` |
| R3 | Kategori filtresi `_curTaskFilter` | Kategori = `_taskKategori` (`setTaskKat`); 🌱 Üreme çipi zaten var | `js/ui.js:26,63-68,146` |
| R4 | "Boş 6. hücre" | 5 hücre, 2 kolonlu grid; **yeni** 6. hücre son satırı tamamlar | `js/ui.js:264-268`, `index.html:85` |
| R5 | Kaydırma konumu "korunur" | `goTo` konum saklamaz — yeni mekanizma yazılır (§6b) | `js/app.js:104-132` |
| R6 | Offline "buton sessiz düşer" | Bayat önbellek + "çevrimdışı · HH:MM verisi" etiketi; veri yoksa açık mesaj | fail-closed, §18.10 |
| R7 | Kontrol penceresi TAI+21g | **İPTAL** — gebelik muayenesi ≥40 g, `sessiz_tohumlama_muafiyet_gun` ayarından | sahip; §18.13 |
| R8 | `deneme_no` tanımsız | Son doğumdan beri sayılır (her yavruda sıfır) | sahip; §18.14 |
| R9 | Boş → "yeni OVSYNC_BASLAT doğar → ①" | Boş anında PG / Ovsync / Takibe bırak seçimi, tek işlem (§6c) | sahip; §18.15 |
| R10 | Vaka↔sonuç köprüsü kaynak-metin çözümü | `hayvan_id` + TAI tarihi vaka penceresinde eşleşme (deterministik) | mimar |
| R11 | Bölüm numaraları ②⑤①④ | Ekran sırasıyla S0–S4 | mimar |
| R12 | Gelecek tarihli "tamamlandı" → `uygulanmadi` | Ayrı durum `tutarsiz` (⚠ veri tutarsız) | fail-closed |
| R13 | Başlık ‹ davranışı tanımsız | ‹ = `history.back()`; `goTo('dash')` DEĞİL | K11 |

## 1. Amaç

Tek ekrandan tüm ovsync protokol vakalarının izlenmesi: hangi hayvan hangi adımda, beklenen
tarih geçti mi, protokol sonlandı mı, nasıl sonlandı, sonuç ne bekleniyor. Zincir-düzeyi takip
bugün yok [W1 gap 1-2].

**Veriyle doğrulanmış gereklilikler (PROD 35 vaka):**
- P1: çiftlik DALGA ile çalışır (09-13 kohortu 11 vaka; 09-24 hedefli 9 vaka 09-27'ye kaydırıldı) → dalga gruplaması.
- P2: hedef≠fiili sapma NORMAL → görünür ve etiketli; veri bükmeleri görünür kalır.
- P3: "TAI yapıldı, sonuç bekleniyor" en kalabalık gerçeklik (11 kayıt) → birinci sınıf bölüm.
- P4: TAI saat türetme şüphesi (küpe 002 TAI 19:00) → B5 backlog.
- P5: koruma boşlukları (küpe 51, küpe 19) → doğruluk kuralları §7.

## 2. Sahip karar günlüğü

| # | Karar | Seçim |
|---|---|---|
| K1 | Birincil bakış | Birleşik: üstte bugün/geciken şeridi + aktif zincirler dalga gruplu |
| K2 | Sonuç bekleniyor | Ayrı bölüm (S2). Muayene zamanı **≥40 g** (§18.13) — sayaç "muayeneye N gün", eşik `_ayar('sessiz_tohumlama_muafiyet_gun',40)`'tan; dashboard "gebelik muayenesi gerekenler" listesiyle aynı kaynak. 21 g kontrolü YOK. |
| K3 | Sapma gösterimi | Display-only: hedef→fiili ok + kayma rozeti + erken/görevsiz etiketi; şemaya dokunma |
| K4 | Yüzey | Kendi sayfası `#pg-ovsync`, `goTo('ovsync')`; modal değil |
| K5 | Toplu işlem | FAZ 1'de yeni toplu mekanizma yok; mevcutlara bağlanır |
| K6 | Vaka↔sonuç köprüsü | RPC içinde `hayvan_id` + tohumlama tarihi ∈ [vaka start_date, kapanış+2g] eşleşmesi; eşleşme yoksa `bilinmiyor`. Kalıcı çözüm (`tohumlama_kaydet`'e case_id) backlog B1 |
| K7 | Giriş | Dashboard `.dash-row`'a **yeni 6. `.sc` hücresi** "🔄 Ovsync ›" + sayı; 2 kolonlu grid'de son satırı tamamlar; ikincil: 🔔 🌱 bölümünde "Tüm takibi aç →" |
| K8 | Aksiyon mimarisi | Hibrit: tek-dokunuş inline (mevcut RPC'ler), form gerekenler mevcut modallar |
| K9 | Görevler ilişkisi | Ovsync görevleri Görevler'de kalır. Kategori: mevcut **🌱 Üreme** çipi (`_katTipMap.ureme`); ovsync'e özel emoji/alt-çip opsiyonel (§18.16, §10-S1). Başlıkta "Tüm ovsync takibi →" köprüsü |
| K10 | 🔔 protokol paneli | 🌱 bölümü kalır + "Tüm takibi aç →" |
| K11 | Gezinme | Hub'a mecburiyet yok; geri = kaldığın yere birebir dönüş (§6b) |
| K12 | Boş sonrası devam | Boş atanınca aynı modalda **PG uygula · Ovsync uygula · Takibe bırak**; seçim zorunlu, Ovsync ön seçili; tek işlem; varsayılan hemen; takip = +7 g muayene görevi, saat = atama anı; DB beklenen olayla takibi kapatır (§6c, §18.15) |
| K14 | Üreme kategorisi | "İşin ucunda gebelik varsa üreme": `GEBELIK_KONTROL`, `TAKIP_MUAYENE`, `TOHUMLAMA_PLANLI`, `OVSYNC_BASLAT` → 🌱 Üreme. Üreme vakaları: Ovsync, Kistik Over, Anoestrus. Enfeksiyon/doğum sonrası (Metrit, Endometrit, Pyometra, RFM, Retensiyo Sekundinarum, Postpartum Hemoraji) → normal muayene/tedavi. Yalnız filtre/kategori eşlemesi güncellenir; hastalık kataloğu değişmez (§18.16) |
| K15 | Birleşik muayene sonucu | Mevcut gebelik muayenesi sistemi (40 g listesi `gebelik_muayene_listele` + cron `gebelik_muayene_gorev_uret` → `GEBELIK_KONTROL`) bu işle entegre ve güncellenir: `GEBELIK_KONTROL` ve `TAKIP_MUAYENE` görevleri AYNI muayene sonuç ekranını açar — Gebe · Boş (→ devam seçici) · Muayeneyi ertele. Takip ekranı S2 "muayene vakti" = aynı liste/kaynak |
| K13 | Deneme sayacı | Her doğumda sıfırlanır (§18.14); `tohumlama.deneme_no` (ömür boyu) gösterimde kullanılmaz |

## 3. Ekran omurgası (yukarıdan aşağı)

```
KPA şeridi : Aktif N · Bugün N · Geciken N · Muayene bekleyen N · Bekleyen başlatma N
S0 BUGÜN & GECİKEN : canlı kartlar ("Küpe 002 — TAI bugün 19:00 [▶]") — boşsa gizli
S1 Aktif zincirler — dalga gruplu kartlar
S2 Sonuç bekleyenler — küpe + TAI tarihi + "muayeneye N gün"/"muayene vakti" + deneme rozeti
S3 Başlatılmayı bekleyenler — hedef tarih sıralı; ilk 5 + "tümü (M)"; takipteki Boş hayvanlar "🔍 takipte · muayene GG.AA SS:DD" rozetiyle
S4 Sonlananlar (katlanır, son p_sonlanan_gun=60 gün) — sonlanma rozeti + toh_sonuc
```

Dalga anahtarı: vakayı açan `OVSYNC_BASLAT` görevinin `hedef_tarih`'i; görevsiz vakalar
`start_date`; tekil kalanlar "tekil başlangıçlar" grubunda. Grup başlığı: hedef→fiilen + hayvan
sayısı + ortak sıradaki adım.

Mockup farkı (v1 PNG'leri güncellenmedi): "kontrol 08.10" yerine "muayeneye N gün";
197 "yeni deneme bekliyor" satırı S2'de değil — Boş atanınca S2'den düşer (§6c akışına göre S1/S3'e).

## 4. Satır şeması (S1)

```
[kupe] [grup] [padok] [taban_turu] [sapma rozeti] [deneme rozeti]
d0● d7◌ d8◌ d9◌ TAI⏳(tarih)   → tamam yeşil · plan amber · gecikti kırmızı · uygulanmadi soluk · tutarsiz ⚠
alt: "1/4 uygulandı · sıradaki: 2. uygulama"   [Gün detayı / ▶ TAI]
```
- Gün etiketleri nötr: "1./2./3./4. uygulama" — ilaç adlı etiket B6 doğrulanana kadar YASAK (A10).
- Sapma rozetleri: `hedef 09-24 → fiilen 09-27 (+3g)` · `erken 6g` · `görevsiz`.
- Deneme rozeti: "2. deneme — önceki boş" (son doğumdan beri, K13).
- Satır aksiyonları mevcut motorlara bağlanır: TAI → `openTaskDet` (`js/ui.js:8702`) →
  "Tohumlamayı Kaydet"; gün → `openCaseDet` (`:9440`, `renderCaseTimeline` `:9521`); ▶ Başlat →
  `_ovsyncBaslatKilitHtml` (`:1736`) / `ovsyncBaslat` (`:1799`); ertele → `_erteleBtnHtml` (`:1767`).
- PG dokunuşu yok — gün detayına düşer (§18.8 PG onay kapısı).

### 4b. Satır durum–aksiyon matrisi

| Satır durumu | Görünüm | Aksiyon |
|---|---|---|
| S3 pencere dışı | 🔒 + hedef tarih | yok (bilgi) |
| S3 pencere içinde (hedef−2) | ▶ Başlat | inline `ovsyncBaslat` → S1 |
| S1 gün vakti | amber + tarih | modal `openCaseDet` |
| S1 gün gecikti | kırmızı + "+Ng" | öne alınır + inline Ertele / `openCaseDet` |
| S1 TAI günü | "BUGÜN" | modal `openTaskDet` → "Tohumlamayı Kaydet" → S2 |
| S2 muayeneye N gün | sayaç | yok (bilgi) |
| S2 muayene vakti (≥40 g) | "muayene vakti" | mevcut gebelik sonuç akışı (`gebeAta` / `tohumlama_sonuc_bos` modalı); **Gebe** → S4; **Boş** → §6c seçimi → PG/Ovsync: S1 · Takibe bırak: S3 |
| S4 sonlanmış | rozet + toh_sonuc | `openCaseDet` salt-okuma |

## 5. Veri katmanı — TEK salt-okunur RPC

`ovsync_takip_listele(p_padok text DEFAULT NULL, p_sonlanan_gun int DEFAULT 60)` →
`jsonb {ok, bayrak_kapali, kpa{}, esikler{muayene_gun, pencere_gun}, satirlar[]}`

Satır alanları: `bolum(S0-S4)`, `dalga_anahtari`, `hayvan_id, kupe_no, grup, padok, taban_turu`,
`gunler[{gun_no, tarih, planned_time, durum(planli|tamam|gecikti|uygulanmadi|tutarsiz), tamamlandi_tarihi}]`,
`tai{gorev_id, hedef_tarih, hedef_saat, durum, kaynak(sablon|pg)}`, `sonraki_gun`, `gecikme_gun`,
`sapma{hedef_baslangic, fiili_baslangic, kayma_gun, erken_tai, gorevsiz_tai}`,
`close_reason(NULL→'ESKI')`, `toh_sonuc` (K6 köprüsüyle; eşleşmezse `bilinmiyor`),
`deneme_sayisi` (son `dogum.tarih`'ten beri tohumlama sayısı, K13),
`muayene{tai_tarihi, muayene_tarihi = tai + esikler.muayene_gun, kalan_gun}` (S2).

Uygulama disiplini:
- `ovsync_baslat_uyarilari` (`20260926000003`) CTE modelinin genişletilmesi (gorevli ∪ gorevsiz + aktif-zincir + sonuç-bekleyen + kapalı).
- `STABLE SECURITY DEFINER`, `search_path` sabit, yalnız authenticated grant; anon EXECUTE YOK; REVOKE'a PUBLIC dahil (default-privilege dersi).
- Eşikler RPC'den taşınır (`esikler`); muayene eşiği `_ayar('sessiz_tohumlama_muafiyet_gun',40)` — yeni sabit YAZILMAZ; JS'e kopyalanmaz.
- Bayrak kapalı → `{ok:true, bayrak_kapali:true}` ve ekranda açık mesaj; sessiz boş liste YASAK.
- **`RPC_TABLES`'a kaydolmaz** (salt-okuma invariant'ı). Çağrı doğrudan `rpc('ovsync_takip_listele',…)`;
  sonuç `window.__ovsyncTakip = {veri, zaman}`; hata/offline → bayat önbellek + "çevrimdışı · HH:MM verisi";
  önbellek de yoksa "İnternet yok — takip verisi alınamadı" (sessiz boş YASAK).
- Yazma akışları sonrası invalidate: `ovsyncBaslat`, `protokol_iptal`, erteleme/kaydırma, tohumlama kaydı,
  gebe/boş atama, §6c RPC → `__ovsyncTakip = null`; sayfa açıksa yeniden yükle.

## 6. Entegrasyon noktaları

| Katman | Nokta |
|---|---|
| Giriş butonu | `_dashStatRow` (`js/ui.js:259-270`) `.dash-row`'a **yeni** 6. `.sc`: `🔄 Ovsync ›` + aktif zincir sayısı; sınıf: S0>0 ∨ muayene vakti dolan>0 → `alert`; yalnız bekleyen-başlatma>0 → `warn`; sakin → `ok`; `onclick="goTo('ovsync')"` |
| İkincil giriş | 🔔 🌱 bölümü (`js/ui.js:2950-2963`) "Tüm takibi aç →" |
| Yüzey | `index.html` `#pg-ovsync` (`.pg` deseni) + `loadOvsyncDash()`; `goTo()` if/else zincirine (`js/app.js:122-130`) `ovsync` dalı |
| api.js | takip RPC'si yalnız `rpc()` + `__ovsyncTakip` önbelleği (`RPC_TABLES`'a girmez); §6c yazma RPC'si `RPC_TABLES`'a pull tablolarıyla girer |
| DB | yeni migration append-only; `scripts/db-validate.sh` ZORUNLU; demo/prod ayrı |
| Kesişim | `_uremeVakaCaseIds` (`js/ui.js:84`) tek kaynak |
| Görevler köprüsü | 🌱 Üreme çipi (mevcut) + başlıkta "Tüm ovsync takibi →" |
| Sayı tutarlılığı | Ovsync sayfası ve 🔔 🌱 bölümü aynı RPC ailesinden; **Görevler rozeti (IDB) ve çan rozeti (iki RPC toplamı) bu işte değişmez, eşitlik iddia edilmez** |

### 6b. Gezinme sözleşmesi

- Yatay geçiş: Ana ⇄ Ovsync ⇄ Görevler; hub'a mecburiyet yok.
- `goTo('ovsync')` mevcut pushState/popstate'e katılır (`js/app.js:114,134`, `navGeriKarar`).
- Modal = sayfa geçişi değil: geri tuşu yalnız modalı kapatır; kapanınca sayfa yerinde tazelenir.
- Durum: bölüm açık/kapalı + padok filtresi `window._curOvsync*`.
- **Kaydırma konumu yeni mekanizma:** `goTo` ovsync'ten ayrılırken `window._ovsyncScrollY` kaydeder; `loadOvsyncDash` render sonrası geri yükler. Veri her dönüşte taze.
- Başlıktaki ‹ → `history.back()` (geçmiş yığını şişmez). Alt-nav'a giriş YOK.

### 6c. Boş sonrası devam + takip muayenesi (K12, §18.15) — FAZ 1'in tek yeni yazma yolu

Mockup'lar (sahip onaylı 2026-09-28): `runs/2026-09-28-ovsync-takip/mockup/bos-devam/01..07-*.png`
(07 = uçtan uca akış).

**Bugün (kanıt):** Boş atama `js/forms.js:4347` → `tohumlama_sonuc_bos(p_tohumlama_id)`
(`20260924000001:505-572`): sonuç=Boş, açık `GEBELIK_KONTROL`/`TOHUMLAMA_HAZIRLIK` iptal,
`_acik_disi_gorev_kur` → kural tarihli `OVSYNC_BASLAT`. İkinci giriş: PG kapısı `_pgKapiBosAtaUygula`
(`js/ui.js:1461`).

**6c.1 Devam seçici (tek UI bileşeni).** Boş atanan HER giriş noktası kullanır: tohumlama sonuç
modalı, gebelik muayenesi sonucu (`GEBELIK_KONTROL`), takip muayenesi sonucu (6c.4). PG kapısındaki
"Boş ata ve uygula" = "Boş + PG" seçiminin karşılığıdır; orada seçici ayrıca açılmaz.
Seçim ZORUNLU — seçilmeden Kaydet pasif; "yalnız Boş ata" yolu YOK.

| Seçenek | Ön ayar | Tek işlemde |
|---|---|---|
| 🔄 **Ovsync uygula** — ÖN SEÇİLİ | hemen | Boş + Ovsync vakası açılır |
| 💉 **PG uygula** | hemen; son kullanılan PG ürünü+dozu dolu, değiştirilebilir | Boş + PG (mevcut PG çekirdeği, stok düşümü aynı) → uygunsa +48 s TAI (§18.6) |
| 🔍 **Takibe bırak** | +7 gün; saat = atama anındaki saat | Boş + takip muayenesi görevi (`hedef_tarih`, `hedef_saat`) |

- Kaydet etiketi seçime göre: "Boş ata + Ovsync başlat" / "Boş ata + PG uygula" / "Boş ata + takibe bırak".
- **Ovsync hard block:** kısır (§18.5) ya da kural günü (§18.1) gelmemiş hayvanda Ovsync kartı kilitli +
  gerekçe ("🔒 Kural günü 12.10 — 14 gün var" / "🔒 Kısır"); ön seçim Takibe bırak'a düşer. Kapı
  esnetilmez (§18.3 aynen); istisna gerekirse DB seed ile (sahip).

**6c.2 Sunucu — tek sarmal RPC.** `tohumlama_bos_ve_devam(p_tohumlama_id, p_secim OVSYNC|PG|TAKIP,
p_pg_urun?, p_pg_doz?, p_gun?, p_saat?, p_onay bool DEFAULT false)`: içinde `tohumlama_sonuc_bos`
çekirdeği + seçime göre `start_first_service_protocol` / PG çekirdeği / takip görevi kurulumu. Tek
transaction — biri düşerse Boş da atanmaz. Sıra: TAKIP seçiminde takip görevi `_acik_disi_gorev_kur`'dan ÖNCE kurulur ya da çekirdek bu yolda o çağrıyı atlar — aksi halde muafiyetten önce `OVSYNC_BASLAT` doğar. Sunucu redleri (`OVSYNC_ERKEN`, kısır, `PG_KAPI:*`,
`TAKIP_ACIK:*`) açık hata; PG kapısında `_pgKapiHata` zinciri (§18.8). SECURITY DEFINER, yalnız
authenticated; anon/PUBLIC EXECUTE yok. Yazma RPC'si olduğu için `RPC_TABLES`'a pull tablolarıyla kaydolur
(`tohumlama, hayvanlar, gorev_log, cases, treatment_days, …` — plan aşamasında kesinleşir).

**6c.3 Takip görevi + DB otomatik kapanış.**
- Takip muayenesi, kapanışın hedeflenebilmesi için ayırt edilebilir işaret taşır (yeni tip mi, `MUAYENE` +
  kaynak işareti mi — plan aşamasında koda göre seçilir; kategori Görevler'de muayene/🌱 ile uyumlu).
- Takip açıkken otomatik `OVSYNC_BASLAT` AÇILMAZ (`_acik_disi_ovsync_hedef` muafiyetine "açık takip
  görevi" eklenir — bugünkü "açık OVSYNC_BASLAT görevi olan muaf" kuralının eşi).
- DB, beklediği olaylardan biri gerçekleşince takibi kendisi kapatır (tablo tetikleyicisi — tüm giriş
  yolları kapsansın; kısır guard deseni):
  - yeni tohumlama kaydı (kızgınlıkta tohumlandı) → **sessiz** kapanış;
  - Ovsync vakası açılması / PG uygulaması → sunucu önce `TAKIP_ACIK:{…}` döner; UI uygulamanın kendi
    onay penceresini açar ("Küpe 197, 05.10 14:35'te muayene takibinde. Takip kapatılıp PG uygulansın mı?"
    — tarayıcı `confirm()` DEĞİL); evet → `p_onay=true` ikinci çağrı → takip kapanır, akış başlar;
  - hayvan çıkışı → kapanış.
- Kapanış nedeni görevde kaydedilir (hangi olay kapattı) — sessiz iptal değil.

**6c.4 Takip muayenesi sonuç ekranı.** Görev açılınca aynı devam seçici; seçenekler:
Ovsync uygula / PG uygula / 📅 **Muayeneyi ertele** (+7 gün ön ayar, saat; yeni muayene tarihi yeniden
hesaplanır, aynı takip zinciri sürer) + bağlantı "🐄 Kızgınlıkta → tohumlama kaydına geç" (tohumlama kaydı
takibi 6c.3 gereği kapatır).

**6c.5 Takip ekranına yansıma.** Takipteki hayvan S3'te "🔍 takipte · muayene 05.10 14:35" rozetiyle
görünür; Boş hayvan hiçbir bölümden düşmez.

**Plan aşamasında kodla doğrulanacak (açık teknik):** PG uygulamasının yazdığı tablo (tetikleyici hedefi);
"son kullanılan PG" kaynağı; takip görev tipi seçimi; gebelik muayenesi sonucu Boş giriş noktası.

## 7. Doğruluk kuralları (bağlayıcı)

1. Görev durumu `(tamamlandi, iptal)` ikilisiyle yorumlanır.
2. Satırda yalnız aktif TAI; iptal/geçmiş TAI detayda ("son PG kazanır", §18.6).
3. Gelecek tarihli "tamamlandı" gün → `tutarsiz` (⚠ veri tutarsız); `uygulanmadi` diye gösterilmez.
4. `close_reason=NULL` → "Eski/bilinmiyor".
5. K6 köprüsü eşleşmezse `toh_sonuc=bilinmiyor` — tahmin YOK.
6. `tohumlama_durumu` kullanılmaz (§18.11).
7. Test adlı hayvan "test" notu taşır (kalıcı etiket B3).
8. Tanınmayan yapı/alan → "bilinmiyor"; sessiz varsayılan YASAK.
9. **Yazma yolu politikası:** takip **ekranı** yeni yazma yolu içermez; aksiyonlar mevcut tekil işlemleri
   çağırır (`start_first_service_protocol`, `protokol_iptal`, `vaka_kalan_gunleri_kaydir`/`_coklu`,
   görev tamamlama, `tohumlama_kaydet`, gebe/boş atama). Tek istisna §6c sarmal RPC'si — sonuç
   modalında yaşar, mevcut çekirdekleri birleştirir; yeni iş kuralı icat etmez.
10. Muayene eşiği tek kaynaktan (§18.13); ekranda 21 g ya da başka sabit yok.

## 8. Fazlar

- **FAZ 1:** RPC + `#pg-ovsync` + stat hücresi + 🔔 linki + Görevler köprüsü + gezinme (§6b) + **Boş sonrası devam (§6c)**.
- **FAZ 2:** hayvan×gün matrisi · "bugün aynı adım → toplu tamamla" · başarı-oranı KPA'ları.
- **Backlog (kapsam dışı):**
  B1 `tohumlama_kaydet`'e case_id + backfill · B2 "erken/görevsiz" meşru geçişi · B3 test hayvanı etiketi ·
  B4 sessiz eşik doküman-drift (50/55) · B5 TAI saat türetme (küpe 002 19:00) ·
  B6 gün etiketi doğrulaması (A10) · B7 sonuç girilmiş-açık-kalmış vaka uyarısı (183) ·
  B8 `tohumlama.deneme_no` ömür boyu sayıyor — §18.14 ile hizalama kararı (sahip).

## 9. Kabul ölçütleri

1. Migration(lar) `scripts/db-validate.sh` PASS.
2. RPC: `bayrak_kapali` yolu dahil; anon/PUBLIC EXECUTE yok; KPA sayıları PROD verisiyle nokta-doğrulanmış.
3. Ekran: S0–S4 + dalga gruplama + sapma/deneme rozetleri; boş bölümler gizli; muayene sayacı 40 g ayarından.
4. Girişler: 6. stat hücresi (sınıf koşulu doğru) · 🔔 "Tüm takibi aç" · Görevler köprüsü.
5. Playwright demo PASS + glmf-max UI test listesi PASS (UI testi kapısı).
6. Yazma akışları sonrası `__ovsyncTakip` invalidate; offline'da bayat etiket ya da açık mesaj (sessiz boş yok).
7. `RPC_TABLES`'a yalnız §6c yazma RPC'si eklenir (takip RPC'si eklenmez); AGENTS.md/CLAUDE.md, deploy zinciri değişmez.
8. Gezinme: yatay geçiş; geri tuşu doğru yüzey; kaydırma + filtre korunur; ‹ = `history.back()`; modal açıkken geri yalnız modalı kapatır.
9. Ovsync sayfası ile 🔔 🌱 bölümü aynı anda aynı bekleyen-başlatma sayısını gösterir.
10. Yazma yolu denetimi: ekran §7.9 dışı yazma yapmaz.
11. §6c: Boş + her seçenek tek işlemde; hata olunca Boş ataması da geri alınır; kısırda Ovsync kilitli;
    Takibe bırak varsayılanı 7 g + atama saati, görev seçilen gün+saatte Görevler'de görünür; takip açıkken otomatik `OVSYNC_BASLAT` açılmaz; yeni tohumlama takibi sessiz kapatır; PG/Ovsync `TAKIP_ACIK` onay penceresinden geçer; muayene sonucu "ertele" yeni tarih kurar; tüm Boş giriş noktaları seçiciden geçer (PG kapısı hariç = Boş+PG).

## 10. Brainstorm kararları (sahip, 2026-09-28 — kapandı)

| # | Soru | Karar |
|---|---|---|
| S1 | Görevler kategori | 🌱 Üreme kalır; özel ovsync emojisi opsiyonel (§18.16) |
| S2 | Takibe bırak ne görevi | Rektal muayene görevi; UI zinciri yok; DB beklenen olayla kapatır (6c.3) |
| S2b | Takip açıkken PG/Ovsync | Onay penceresi → evet: takip kapanır, akış başlar |
| S2c | Takip açıkken otomatik OVSYNC_BASLAT | Açılmaz (mimar önerisi, sahip onayı Bölüm 1) |
| S3 | Seçim zorunlu mu | Zorunlu |
| S3b | Ön seçim | Ovsync uygula |
| S4 | PG ürünü | Son kullanılan ürün+doz dolu, değiştirilebilir |
| S5 | Takip saati | Atama anındaki saat |
| S6 | Kural günü gelmemiş Boş hayvanda Ovsync | Hard block + bilgilendirme; istisna DB seed |
| S7 | PG kapısı yolu | "Boş + PG" sayılır; seçici açılmaz (mimar) |
| S8 | Muayeneden gelen Boş | Aynı devam seçici (mimar) |
| — | Muayene sonucu | "Muayeneyi ertele" (+7) de seçenek |

### 10b. Test kataloğu SPEC SORULARI — mimar cevapları (2026-09-28)

Kaynak: `docs/plans/2026-09-28-ovsync-takip-ekrani/test-senaryolari.md` SPEC SORULARI.

| # | Soru | Cevap |
|---|---|---|
| S-1 | Kısır + kural günü birlikte | Kısır gerekçesi önce gösterilir (kalıcı engel); kural günü ikinci satır |
| S-2 | Ertelemede saat | Düzenlenebilir; ön ayar önceki takip saati |
| S-3 | Takip muayenesinde Gebe bulunursa | **SAHİP (a):** önceki Boş hatalıydı → son tohumlama Gebe'ye çevrilir (mevcut gebe atama çekirdeği), takip kapanır (neden: GEBE_BULUNDU) |
| S-4 | PG_KAPI + TAKIP_ACIK birlikte | Tek birleşik onay penceresi (iki gerekçe alt alta, tek "Evet"); sunucu tek `p_onay` ile ikisini de geçer |
| S-5 | Bayrak kapalıyken §6c | Devam seçici açılmaz; bugünkü Boş davranışı (bayrak = özellik kapalı); ekranda "Ovsync/PG kuralları kapalı" notu |
| S-6 | "Bekleyen başlatma" KPA'sı takip içerir mi | İçerir; alt metin "(N takipte)" |
| S-7 | Takip erteleme tavanı | **SAHİP:** sınırsız; takip toplam süresi ≥21 gün olunca erteleme onay ister: "Bu hayvan N gündür takipte, emin misiniz?" (evet → ertelenir) |
| S-8 | Zaten sonuçlanmış tohumlamaya ikinci çağrı | Açık hata `TOH_SONUCLU:{…}`; hiçbir yazma yok |
| S-9 | "muayene vakti" sınırı | `kalan_gun <= 0` → "muayene vakti" |
| S-10 | Takip muayenesinde Kaydet etiketi | "Boş ata" öneki YOK (Boş zaten atanmış): "Ovsync başlat" / "PG uygula" / "Muayeneyi ertele" |

### 10c. Sol plan-review sonrası sahip kararları (2026-09-29)

Kaynak: `runs/2026-09-28-ovsync-takip/plan-review.md` (VERDICT DÜZELTME, 5 kritik / 11 önemli / 1 küçük).
Plan düzeltmesi 17 bulgunun HEPSİNİ uygular; aşağıdakiler bulguların sahip/mimar kararıyla netleşen halidir.

| Bulgu | Karar |
|---|---|
| #1 otomatik kapanış | Dört olayın dördü (tohumlama, `pg_application_event`, `cases` Ovsync, hayvan çıkışı) idempotent TABLO TETİKLEYİCİSİYLE; RPC içine gömülmez; kapanış nedeni kaydedilir |
| #2 PG kapısı "Boş ata ve uygula" | Eski iki-RPC zinciri kalkar; `tohumlama_bos_ve_devam` tek transaction'ına yönlenir |
| #3 S-3 | Takip muayenesi VE gebelik kontrolünde Gebe → `tohumlama_sonuc_gebe` çekirdeği, takip `GEBE_BULUNDU` ile kapanır (K15) |
| #4 S-4 | Birleşik kapı payload'ı + tek bottom-sheet + tek `p_onay` |
| #5 GEBELIK_KONTROL Boş girişi | **SAHİP: EKLENİR (K15).** Gebelik kontrol görevi tamamlanırken sonuç sorulur: Gebe / Boş (→ devam seçici: Ovsync/PG/Takibe bırak) / Muayeneyi ertele. Eski 40 g sistemi bununla güncellenir; jenerik `gorev_tamamla` bu tip için sonuçsuz kapanmaz |
| #6 S-5 bayrak kapalı | Devam seçici açılmaz, bugünkü Boş davranışı; dry-run RPC `bayrak_kapali` döner |
| #7 S-2/S-7 | Ertelemede saat düzenlenebilir — **varsayılan SAATSİZ** (§10d #3 ile güncellendi; "ön ayar önceki saat" geçersiz); takip toplamı ≥21 g → tek onay |
| #8 S-6 KPA | Bekleyen başlatma = toplam + ayrı `takipte` sayısı; 🔔 eşitliği yalnız `ovsync_baslat_uyarilari` alt kümesi için |
| #9 RPC modları | XOR guard, `FOR UPDATE`, `TOH_SONUCLU` / `TAKIP_KAPALI` hata sözleşmesi, yarış testleri |
| #10 son PG | TOPLU_ILAC dalı `islem_log.snapshot.miktar`'dan; "doz belirsiz" iddiası kalkar |
| #11 | `gebelik_muayene_listele` VAR (`20260925000002:287`); P1/T-45 ona bağlanır |
| #12 ground_truth | Tam migration replay sonrası son-kazanan gövde + ACL doğrulaması kabul kriteri; ground_truth yenilemesi manifest/doküman kapısı |
| #13 farm_id | **SAHİP: sistem tek-tenant** (§14 domain-rules, RLS `USING(true)`, `current_farm_id()` sabit). Yalnız §14 uygulanır: YENİ tablo/kolon `farm_id` alır, yeni yazma `current_farm_id()` damgalar; farm_id kolonu OLMAYAN mevcut tablolara predikat/retrofit YOK; iki-farm negatif testi YOK (Faz 2) |
| #14 kategori | **SAHİP: K14** — takip ve gebelik kontrolü 🌱 Üreme; test kataloğu buna göre |
| #15 test kapsaması | T-01..T-73 kapsama matrisi, her T bir katman sahibine |
| #16 boyut | P2 → şema/çekirdek + sarmal modlar; P3 → tablo tetikleyicileri + giriş kapıları; kesin imzalar |
| #17 sıra | Kırmızı test iskeletleri ilgili P'nin önüne; P13 sıralı en sonda |
| copy | Muayene ekranında "Boş ata" öneki yok: "Muayene tamam + …" (S-10) |

### 10d. plan-fix SPEC SORULARI — sahip kararları (2026-09-29)

Kaynak: `runs/2026-09-28-ovsync-takip/plan-fix-DONE.md` §Yeni SPEC SORULARI. Domain-rules §18.13 / §18.17'ye işlendi.

| # | Soru | Karar |
|---|---|---|
| 1 | GEBELIK_KONTROL'ün iki üreticisi (`tohumlama_kaydet` +21/+35 g ↔ cron ≥40 g) | **SAHİP: +21/+35 üretimi KALDIRILIR; tek üretici cron ≥40 g** (§18.13). `tohumlama_kaydet` artık GEBELIK_KONTROL doğurmaz. Açık kalan eski +21/+35 görevleri AYRI veri-temizliği kalemidir (kod fix'ten ayrı madde) |
| 2 | S2 "muayene vakti" satırında görev yoksa | Hayvan detayına gider (bilgi satırı); görev ertesi sabah cron'la gelir, satırdan görev doğmaz |
| 3 | GEBELIK_KONTROL genel "ertele" butonu | Kalkar; erteleme YALNIZ birleşik sonuç ekranından. Saat atanabilir; **varsayılan SAATSİZ** — iki görev tipinde de (TAKIP_MUAYENE dahil; S-2 "önceki saat" ön ayarı geçersiz) |
| 4 | Dashboard 40 g listesi satır tıklaması | **Birleşik muayene ekranı** açılır (açık görev varsa); açık görev yoksa hayvan detayı |

### 10e. luna re-review sonrası sahip kararları (2026-09-29)

Kaynak: `runs/2026-09-28-ovsync-takip/plan-rereview.md` (VERDICT DÜZELTME).

| # | Konu | Karar |
|---|---|---|
| D1 | Takip muayenesinde Gebe → önceki Boş | **SAHİP ONAY:** "önceki muayenede gebelik görülememiş, sonradan çıkmış" mantıken doğru. Genel `tohumlama_sonuc_gebe` Bekliyor-only KALIR; Boş→Gebe düzeltmesini yalnız sarmal RPC'nin takip-GEBE modu yapar (dahili çekirdek, son tohumlama + bağlı açık takip + kilit + kayıt izi). Ayrı "hatalı Boş" formu YOK. Geçmişte hayvanın "Boş → takip muayenesi → Gebe" görünmesi kabul (bilgi taşır). |
| D1-UI | Düzeltilen tohumlamanın görünümü | **SAHİP: iki satır** — üreme geçmişinde aynı tohumlama altında üstü çizili `❌ Boş (Boş giriş tarihi)` ve altında `✅ Gebe (takip muayenesi tarihi)`; tahmini doğum Gebe'den. Kayıt izi eski sonucu ve Boş giriş tarihini saklamak ZORUNDA (UI bunu okur). |
| D2 | S2 = 40 g listesi | **SAHİP ONAY:** `gebelik_muayene_listele`'nin tüm predicate'leri (30 g cooldown dahil) birebir. |
| UI-R1 | Hayvan kartı üreme geçmişi göreli tarih | **SAHİP İSTEĞİ (2026-09-29):** her satırın tarihinin yanına göreli gün: `2025-12-30 · Gebe · 273 gün önce` ("bugün", "dün"; hep gün cinsinden). Gün farkı yerel tarih (Europe/Istanbul) üzerinden, UTC kayması yok. Kapsam: yalnız hayvan kartı üreme/tohumlama geçmişi satırları (D1-UI ile aynı render noktası). |

### 10f. luna re-review 2 sonrası MİMAR kararları (2026-09-29)

Kaynak: `runs/2026-09-28-ovsync-takip/plan-rereview2.md` (VERDICT DÜZELTME; C1–C6). Sahip kararı değil, teknik yön; domain kuralına dokunmaz.

| # | Konu | Karar |
|---|---|---|
| C3 (KRİTİK) | Kilit sırası | Plan v4'ün `tohumlama → hayvanlar → gorev_log` sırası İPTAL. Yerleşik **MK9** (20260923000004:43,215; 20260923000005:30,323) GENEL sözleşme olur: **hayvan satırı İLK** (`FOR NO KEY UPDATE`, ilk tablo erişiminden önce) → tohumlama → vaka/seans → görev. Toplu yollar hayvanları `ORDER BY id` ile kilitler. MK9'u ihlal eden `start_first_service_protocol` (görev→hayvan, 20260925000017:44,62) düzeltilir: görev kilitsiz okunur → hayvan kilitlenir → görev kilitlenip yeniden doğrulanır. Advisory lock EKLENMEZ. Çapraz iki-oturum deadlock provası (tohumlama_kaydet × sarmal × start protocol × seans). |
| C1 | D1-UI tarih kaynağı | Normatif çözücü: `islem_log` `tip='TOHUMLAMA_SONUC' AND ref_tablo='tohumlama' AND ref_id=<toh> AND durum IS DISTINCT FROM 'geri_alindi'` + snapshot'ta Boş sonucu, `ORDER BY tarih DESC, id DESC LIMIT 1`; `timestamptz → Europe/Istanbul` yerel tarih. Çekirdek `bos_duzeltme.bos_atama_tarihi`'ni yerel TARİH olarak yazar; iki satır + göreli gün aynı normalize tarihten. `fmtTarih`'in ilk-10-karakter kesimi timestamptz için KULLANILMAZ. |
| C2 | Bulk retry | Mevcut `p_pg_onaylar` dizi desenine paralel `p_takip_onaylar text[]` (onaylanan hayvan id'leri); retry yalnız bu id'leri aynı transaction'da uygular; stok düşümü uygulanan satırlardan. Tekil yollarda scalar `p_takip_onay`. |
| C4 | `kizginlik_vaka_ac` | Kapı envanterine GİRER (fail-closed): açık takip varken TAKIP_ACIK onay kapısı aynı desen; test edilir. |
| C5 | İmza geçişi | Her imzası değişen RPC için eski overload `DROP FUNCTION` + ACL yeniden; PostgREST overload bypass'ı negatif test. |
| C6 | farm_id sınırı | §14: farm_id TAŞIYAN nesneler (`pg_application_event` ve bu işin yeni nesneleri) okunurken `farm_id = public.current_farm_id()` filtrelenir; kolonsuz mevcut tablolara predikat/damga YOK. P1/P2b dokunulan tablo envanteri + her birinin farm_id durumu yazılır. |


### 10g. luna re-review 3 sonrası MİMAR kararları (2026-09-29)

Kaynak: `runs/2026-09-28-ovsync-takip/plan-rereview3.md` (VERDICT DÜZELTME; C1/C2/C6 KAPANDI, C3/C4/C5 KISMİ; yeni 1 KRİTİK + 2 ÖNEMLİ). Teknik yön; domain kuralına dokunmaz.

| # | Konu | Karar |
|---|---|---|
| MK9-N (C3, yeni #1) | MK9'un normatif biçimi | Hayvan satırı kilidi **hayvan başına muteks**tir. Kural: aynı hayvanın satırlarına (tohumlama, cases, treatment_days/_uygulamalar, gorev_log, takip) kilit alan ya da YAZAN her kapsam-içi yol, bunların herhangi birine dokunmadan ÖNCE `hayvanlar` satırını `FOR NO KEY UPDATE` kilitler (asla `FOR UPDATE` — FK KEY SHARE'i bloklar; `_pg_kapi` yorumu 20260923000003:200-202). Muteks alındıktan sonra aynı hayvanın alt satırları arasındaki sıra SERBESTTİR; §10f'deki "tohumlama → vaka/seans → görev" alt sırası BİLGİ amaçlıdır, "görev son katman" harfi kural DEĞİL. Çok-hayvanlı yollar tüm hayvanları başta `ORDER BY id` ile kilitler (döngü içinde hayvan başına kilit ancak artan id sırasıyla ve önceki hayvanın alt satırlarından bağımsızsa kabul). |
| MK9-G | Kilit grafiği envanteri | Plan, uyum tablosunu **gerçek kilit grafiği** olarak yeniden yazar; sütunlar: yol · bayrak AÇIK kilit dizisi · bayrak KAPALI kilit dizisi · yardımcıdan miras kilit (`_pg_kapi` vb., dosya:satır) · hayvan muteksi alt satırdan önce mi · tetikleyiciye giriş (hangi tabloya yazıp hangi tetikleyiciyi çalıştırır) · hüküm. Kaynaktan ölçülür; "kilit yok" yalnız yardımcılar da tarandıktan sonra yazılır. Muteks sadece TÜM yazıcılar onu alırsa korur: muteks ALMAYAN bir yol (eski yollar, jenerik `gorev_tamamla`, PostgREST doğrudan tablo UPDATE'leri dahil) aynı hayvanın EN FAZLA TEK alt satırını kilitliyor/yazıyorsa döngü kuramaz → "tek-satır, güvenli" hükmü; birden fazla alt satır kilitliyorsa ya muteks eklenir (madde) ya da sırası muteks sahiplerinin sırasıyla uyumlu olduğu kanıtlanır. |
| MK9-T | Tablo tetikleyicileri | Otomatik kapanış tetikleyicileri takip satırına dokunmadan önce hayvan muteksini alır (aynı tx'te çağıran zaten tutuyorsa yeniden-giriş maliyetsiz). Tetikleyiciyi çalıştıran her çağıran yol ya muteksi alt satırdan önce tutar ya da grafikte "muteks yok + alt satır kilidi yok" olarak kanıtlanır; ikisi de değilse çağırana muteks eklenir (madde). |
| MK9-K | Bayrak kapalı | Yeni yazma yolları bayrak kapalıyken `OZELLIK_KAPALI` RAISE eder (plan P2b); bayrak kapalıyken eski yolların grafiği MK5 gereği değişmez ve kapsam dışıdır — ama tetikleyiciler bayrak kapalıyken de çalışıyorsa MK9-T onlar için de geçerlidir (plan açıkça yazar). |
| MK9-P | Deadlock provası | T-72b çapraz iki-oturum provası grafikteki HER çift için değil, muteks almayan ya da tetikleyiciye giren yolların sarmal/start/seans/bulk ile çiftleri için zorunlu; en az: tohumlama_kaydet × sarmal, start × seans, bulk_ilac (2 hayvan, ters sırada gönderim) × bulk_ilac, vaka_toplu_ac(onaylı) × sarmal, kapanış tetikleyicisi × sarmal. |
| C4 (yeni #2) | `kizginlik_vaka_ac` sunucu kapısı | Açık takip varken `p_takip_onay=false` → sunucu `RAISE 'TAKIP_ACIK:…'` (UI'dan bağımsız, doğrudan REST ile de); `true` → aynı tx'te `_takip_kapat` sonra INSERT. Tanı keyfi olduğu için kapı tanıdan bağımsız uygulanır (Ovsync/PG olsun olmasın açık takip varsa sorulur) — tetikleyici kapsamı buna göre değil, RPC kapısı buna göre yazılır. DB negatif testi (authenticated REST, onaysız → TAKIP_ACIK). |
| C5 (yeni #3) | PostgREST negatif beklentisi | Eski imza çağrısı `PGRST202` / HTTP 404 bekler (`PGRST204` sütun hatasıdır). Test önce demo'da gerçek yanıtı kaydeder, assertion o yanıta sabitlenir; yeni imza çalışır ve anon EXECUTE yok ayrı assertion'lardır. |

### 10h. luna re-review 4 sonrası MİMAR kararı — MK9 KAPSAM DARALTMASI (2026-09-29)

Kaynak: `runs/2026-09-28-ovsync-takip/plan-rereview4-DONE.md` (VERDICT DÜZELTME; 7 yeni bulgu, 3 KRİTİK). Teknik yön; domain kuralına dokunmaz.
Teşhis: review bulguları 17→8→6→3→7 — yakınsamıyor; plan bu işin kapsamını aşıp **tüm eski yazıcıların** (legacy RPC, yardımcı, tetikleyici, ham REST) global deadlock-serbestliğini kanıtlamaya çalışıyor. Bu ayrı bir denetim işidir. PostgreSQL deadlock'u algılar (`40P01`) ve tek tx'i geri alır — veri bütünlüğü bozulmaz; risk nadir, tekrar-denenebilir bir hatadır (tek çiftlik, az eşzamanlı kullanıcı — INFERRED).

| # | Konu | Karar (§10g'yi DARALTIR; çelişkide §10h kazanır) |
|---|---|---|
| H1 | MK9 kapsamı | MK9-N hayvan-önce muteksi YALNIZ (a) bu işin YENİ nesnelerine (sarmal RPC, yeni yardımcılar, yeni tetikleyiciler) ve (b) bu işin İŞLEVSEL nedenle zaten değiştirdiği mevcut RPC'lerin YENİ eklenen kısmına uygulanır. Başka nedenle değişmeyen eski yolların (`tohumlama_sonuc_bos`, `gorev_tamamla` SUTTEN_KESME/padok, `hizli_uygulama_geri_al`, ham REST, eski tetikleyiciler) kilit davranışına bu işte DOKUNULMAZ — eski yola kilit eklemek de regresyon riskidir. v6'nın eski yollara eklediği kilit maddeleri (`tohumlama_sonuc_bos` giriş NKU, `gorev_tamamla` sıra düzeltmesi, `create_case` genel giriş NKU) GERİ ALINIR. İstisna: `start_first_service_protocol` düzeltmesi (§10f) KALIR — kurucu ihlal, bu işin sarmalıyla doğrudan çakışır. |
| H2 | Eski yol denetimi | rereview3/4'ün eski-yol bulguları (grafik hücreleri, SUTTEN_KESME, geri-al çok-satır, ham REST yazıcıları) **backlog B9 "MK9 eski yol kilit denetimi"** olarak AYRI işe devredilir; plan yalnız "kapsam dışı — B9" satırıyla anar. Kilit grafiği tablosu planda BİLGİ amaçlı kalır, kabul ölçütü değildir. |
| H3 (bulgu #1) | Kapanış tetikleyicileri | §10g MK9-T GERİ ALINIR: tetikleyiciler hayvan kilidi ALMAZ (AFTER INSERT ON tohumlama içinde hayvan kilidi = çağıranın tohumlama kilidinden sonra ters sıra). Tetikleyici yalnız o hayvanın açık TAKIP_MUAYENE `gorev_log` satır(lar)ını günceller (tek satır tipi), idempotent, bayraktan bağımsız. BEFORE INSERT ret tetikleyicileri (pg_application_event, cases) yalnız OKUR + RAISE eder, kilit almaz. Yön tutarlılığı: tetikleyici tohumlama → takip-görev yönünde kilitler; bu yüzden YENİ yollar hayvan muteksinden sonra tohumlama satırını takip `gorev_log` satırından ÖNCE kilitler (MK9-N'nin "alt sıra serbest" hükmü bu çift için bu sırayla sabitlenir). |
| H4 (bulgu #4) | Giriş deseni | Girdisi alt-satır kimliği olan YENİ/DEĞİŞEN giriş noktaları için standart: kilitsiz keşif (alt satırdan `hayvan_id`) → hayvan `FOR NO KEY UPDATE` → alt satır `FOR UPDATE` + yeniden doğrulama (değiştiyse mevcut hata sözleşmesiyle RAISE). Mevcut dönüş/hata/idempotentlik sözleşmesi korunur. `kizginlik_vaka_ac` kapı eklemesi bu desenle yazılır. |
| H5 (bulgu #3, #6) | Toplu yollar | `vaka_toplu_ac` ve `bulk_ilac`'ın mevcut döngü/kilit davranışı DEĞİŞMEZ. Takip kapısı yalnız ek adımdır: fonksiyon başında açık takibi olan hayvanlar okunur; `p_takip_onaylar` içinde OLMAYAN açık-takipli hayvan satırı işlenmez, satır sonucu `TAKIP_ACIK` döner (PG bulk `p_pg_onaylar` satır-sonucu deseniyle aynı); içindekiler için `_takip_kapat` o satırın işlenmesinden hemen önce çağrılır. Retry = istemcinin onaylı alt kümeyle yeni çağrısı (`p_animal_ids` = onaylılar); kilit kümesi = mevcut davranış. Yeni boyut sınırı YOK. |
| H6 (bulgu #7) | `gorev_tamamla` guard | Guard yalnız TAMAMLAMA dalında (`p_iptal` false/NULL) ve yalnız `GEBELIK_KONTROL`/`TAKIP_MUAYENE` tiplerinde RAISE eder; `p_iptal=true` dalı (T5, js/ui.js:1841-1844 — ilk tohumlama iptali) ve SUTTEN_KESME/padok dalları AYNEN korunur; guard ilk tablo erişiminden önce yalnız görev tipini okur, kilit sırasını değiştirmez. Üç dal için davranış testi. |
| H7 (bulgu #5) | T-72b provası | Kabul ölçütü = sonuç oracle'ı, "önce kırmızı" ŞARTI YOK (deadlock deterministik üretilemez): bu işin YENİ yolları × çakışan yollar (sarmal × tohumlama_kaydet, sarmal × start, sarmal × seans_tamamla, sarmal × vaka_toplu_ac, tetikleyici × sarmal) için iki bağlantılı Node/psql betiği, her çift N=30 eşzamanlı tur, `lock_timeout='5s'`; PASS = hiçbir turda SQLSTATE `40P01`/`55P03` yok ve her sonuç izinli kümede (başarı ya da belgelenmiş iş hatası). Demo DB'de koşulur. |
| H8 | 40P01 istemci davranışı | İstemci `40P01` (ve `55P03`) için ham hata yerine "İşlem başka bir kayıtla çakıştı, tekrar deneyin" gösterir; otomatik yeniden deneme YOK. (Eski yollarda kalan nadir deadlock'un güvenli yüzü.) |
| H9 | Review yakınsama kuralı | Sonraki review turu YALNIZ §10h uygulamasını denetler; eski-yol (H1/H2 kapsam dışı) bulguları B9'a yazılır, DÜZELTME gerekçesi olmaz; yalnız bu işin kapsamındaki KRİTİK bulgu DÜZELTME doğurur. |
