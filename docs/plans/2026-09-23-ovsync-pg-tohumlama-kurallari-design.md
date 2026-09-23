# Ovsync/PG/Tohumlama Kuralları — Tasarım

Tarih: 2026-09-23
Durum: Brainstorm onaylı taslak (sahip ile netleştirildi)
Dal: `feature/ovsync-tohumlama-tedavi-kapanisi`
Tetikleyici vaka: Hayvan 121 (kupe) — Ovsync sürerken 17.09.2026 tohumlandı, tedavi
kapanmadı, 20–23.09 seansları devam etti (PG dahil), zigot kaybı şüphesi.

## 0. Zemin (kanıtlı)

- `tohumlama_kaydet` doğrudan tohumlamada açık `TOHUMLAMA_PLANLI` görevini otomatik
  iptal eder (`iptal=true, tamamlandi=true`) ama `cases` kaydına **dokunmaz**;
  vaka kapanışı tamamen manuel (`close_case_with_remaining`).
  [CONFIRMED supabase/migrations/20260830000010_abort_vwp_penceresi.sql:215-222]
- Vaka 121: 13.09 açılış, planlı tohumlama 23.09'ya kuruldu; 17.09'da elle girilen
  tohumlama (deneme 2, Darius, Bekliyor) görevi iptal etti; vaka aktif kaldı;
  Gün 2–5 seansları 20–23.09'da uygulandı. [OBSERVED canlı DB, 2026-09-23]
- Etken maddeler zaten kategorize: "Prostaglandinler" kategorisi (Dinoprost,
  Kloprostenol sodyum) + "Hormonlar ve Üreme İlaçları" ailesi (GnRH Agonistleri,
  Oksitosin, Progesteron vb.). [OBSERVED canlı UI]

## 1. Kural — Tohumlama, aktif Ovsync vakasını "başarı" ile kapatır

**Kapsam:** Yalnız senkronizasyon/Ovsync ailesi şablon vakaları. Diğer hastalık
vakaları (mastit, ayak vb.) tohumlamadan etkilenmez — kapanmaz.

**Mekanizma (RPC):**
- `tohumlama_kaydet` içinde, mevcut "planlı görev iptali" bloğunun yanına:
  hayvanın `status='active'` ve senkronizasyon-ailesi vakası varsa
  `close_case_with_remaining(case_id, not: 'Tohumlama ile başarıyla tamamlandı')`
  çağrılır. Vaka `closed`; kalan `TEDAVI_GUN`/`TEDAVI_SEANS` görevleri iptal.
- "Senkronizasyon ailesi" tespiti: hastalık/şablon kaydında `senkronizasyon=true`
  bayrağı (mevcut Ovsync/Presynch şablonlarına migration ile işlenir).
- **Ayrı log tipi (mimari):** kapanış `islem_log`'a `CASE_CLOSED_EARLY` değil
  **`CASE_CLOSED_BY_TOHUMLAMA`** tipiyle yazılır — 'başarıyla tamamlandı'
  semantiği ayrıştırılabilir kalsın (raporlama/audit için sorgulanabilir olay).
- RPC cevabına `kapatilan_ovsyncler: [{hayvan_kupe, case_id, iptal_seans}]` eklenir.
- **Toplu-ready:** cevap dizi-tabanlı; tek komutla 100 tohumlama girildiğinde her
  hayvan için aynı kural işler, dizi birikir.

**UI:** Cevapta `kapatilan_ovsyncler` doluysa TEK tarayıcı uyarısı
(`window.alert` biçimi, [Tamam] ile kapanır):
`✅ N Ovsync tedavisi tohumlama ile başarıyla tamamlandı:` + hayvan listesi
(kupe + iptal seans sayısı). 100 hayvan → 1 özet uyarı, 100 uyarı değil.

**Sonuç davranışı örneği (121):** 17.09'da tohumlama girilseydi vaka hemen
kapanır, 20–23.09 seansları iptal edilirdi (ya da henüz üretilmemişse hiç açılmaz).

## 2. Kural — Tohumlanmış hayvana PG → iki kademe: GEBE=hard block, BEKLIYOR=onaylı modal

**Mekanizma (RPC):** `pg_uyari_kontrol(hayvan_id[], ilac_id)` — toplu parametre.
Her hayvan için: ilacın etken maddesinin kategorisi `Prostaglandinler` mi, sonra:

- **`sonuc='Gebe'`** → **HARD BLOCK.** Giriş yapılamaz; RPC kaydı reddeder,
  UI "çıldırmış" sert uyarı verir (kırmızı tam ekran modal, hayvan+gebelik
  bilgisiyle). "Yine de uygula" YOK — bilinçli abort ayrı, sahibin elle
  yürüteceği istisna akışıdır, PG formundan geçmez. (İlk 30 günden önce
  gebelik onayı pratikte gelmez; onay geldiyse block mutlaka tetiklenir.)
- **`sonuc='Bekliyor'` ve son 25 gün içinde tohumlama** → uyarı payload'ı
  (kupe, tarih, sperma, deneme no, sonuç). 25 gün penceresi GEBELIK_KONTROL
  görevlerinin 21/35. gün ritmiyle uyumlu.

**Tetik yüzeyler:** ilaç uygulama ekranı (elle) + şablon/görev planlama ekranı.
Kaydetmeden önce kontrol çağrılır.

**UI (Bekliyor kademesi):** Uyarı VERLERİ boş değilse TEK toplu modal
(engellemeyen ama zorunlu onay):

```
⚠️ N hayvanda tohumlama sonrası 25 gün penceresi içinde PG uygulaması yapılıyor!
▸ 121 — 17.09 Darius (deneme 2, Bekliyor)
▸ ... (liste kaydırılabilir)
                [ Vazgeç ]   [ Yine de uygula ]
```

- `Vazgeç` → işlem iptal, hiçbir şey yazılmaz.
- `Yine de uygula` → işlem normal akışta devam eder (121'deki gibi bilinçli
  risk); uyarı log'da iz bırakır. **Eski döngünün açık işleri temizlenir:**
  geçersiz kalan tohumlamanın bekleyen 21/35. gün `GEBELIK_KONTROL` görevleri
  otomatik iptal edilir (iptal kaydında sebep: 'PG ile döngü sıfırlandı') —
  ölü döngünün kontrolleri panelde yeni tohumlamanınkilerle karışmaz.
- **Toplu karışım:** 100 hayvanın Gebe olanları kayıt öncesi reddedilir (block
  listesi raporlanır), Bekliyor olanları tek modal + kaydırılabilir listede,
  risksizler sessizce akar. Ekran dolma sorunu liste kaydırmayla çözülür.

## 3. Kural — PG verilen hayvana +48 saatte tohumlama görevi

**Mekanizma (RPC):** PG uygulaması (herhangi bir yol: elle, seans tamamlama,
şablon günü — kategori `Prostaglandinler` her ilaç) başarıyla kaydedildikten
sonra — şu **tetik koşullarıyla**:

- **Yalnız postpartum ≥50 gün** hayvanlarda tetiklenir. Önden hazırlık
  PG'leri (25. gün PG, 39. gün Presynch-14 PG — hepsi <50. gün) otomatik
  dışarıda kalır; o şablonların kendi zamanlanmış tohumlama takvimleri
  geçerlidir.
- **Postpartum gün kaynağı (kritik):** `dogum.tarih` — hayvanın EN SON doğum
  kaydı (`SELECT DISTINCT ON (anne_id) ... ORDER BY tarih DESC`). `hayvanlar.
  dogum_tarihi` HAYVANIN KENDİ doğum tarihidir, son buzağılama değil —
  asla bu alandan okunmaz (sessiz yanlış; protokol motoru zaten doğru
  kaynağı kullanır, Kural 3 aynı kaynağa bağlanır).
- **İstisna (çakışma):** hayvanın `TEDAVI_SABLON_TOHUMLAMA` kaynaklı AÇIK
  planlı tohumlama görevi **veya aktif senkronizasyon-ailesi vakası** varsa
  PG_TOHUMLAMA açılmaz — protokol kendi takvimini kurmuş demektir. (İkinci
  istisna Presynch-14'ün 53. gün ikinci PG dozu için gerekli: 39+14=53 ≥50
  eşiği geçer ama protokol sürmektedir; yalnız görev-istisnası yetmez.)
- **İstisna (idempotensi):** aynı hayvana son 48 saatte PG verilmişse yeni
  görev açılmaz, mevcut görev korunur (çift doz → çift görev değil).
- Amaç: 121 tarzı **planlı tohumlamasız, gayri-resmi PG** sonrası hayvanı
  saatinden sorumlu tutmak.

Tetik uygunsa:

- `hedef = pg_gerçekleşme_zamanı + 48 saat`
- **Saat penceresi yuvarlama (her zaman ileri, asla erken değil):**
  - Pencereler: `09:00–12:00` ve `18:00–21:00`.
  - Hedef penceredeyse olduğu gibi kullan.
  - `12:00–18:00` arasına düştüyse → `18:00`.
  - `21:00–09:00` arasına düştüyse → ertesi gün `09:00`.
  - Gerekçe: PG'nin luteolitik etkisi tamamlanmadan erken tohumlama riski.
- `gorev_log` INSERT: `gorev_tipi='TOHUMLAMA_PLANLI'`,
  `hedef_tarih`+`hedef_saat`=yuvarlanmış hedef, `kaynak='PG_TOHUMLAMA:<uygulama_id>'`,
  aciklama `PG sonrası zamanlanmış tohumlama`.
- Mevcut görev tipi kullanılır (yeni tip yok) → tıklayınca var olan
  planlı-tohumlama akışı açılır; kayıt girilince Kural 1 tetiklenir.
- Toplu-ready: 100 hayvana tek ekrandan PG → her biri için görev üretilir.
- 2. kuralın "Yine de uygula" ile bilinçli PG verilenler de dahil — "PG yediyse
  artık tohumla" döngüsü otomatik kurulur.

**Görünürlük (ıskalanamaz):**
- Görev **bekleyenler listesinde asla durmaz** — normal görev akışına karışmaz.
- 📋 Protokol Uyarıları panelinde **kendi bölümü: `Tohumlamalar (N)`** —
  her zaman panelin EN ÜSTÜnde, Gecikmiş'in de üstünde (saat-hassas görevler;
  aşı 2 gün sonra da olur, tohumlama saatinde olmak zorunda).
- Bölüm kurulduğu ANDAN itibaren görünür (son 3 saate kalma yok; PG anından
  hazırlık vakti var); hedef geçtikten sonra satır gecikme bilgisiyle aynı
  bölümde kalır.
- **Saat gösterimi:** PG_TOHUMLAMA satırları her zaman planlanan tarih+saat
  basar (`25.09 10:00`), yalnız-gün ifadesi ("2 gün kaldı") kullanmaz; kalan/
  gecikme bilgisi yanına eklenir (`· 1 gün kaldı` / `· 4 saat gecikmiş`).
- "Gecikmiş (N)" sayacı değişmez — zamanlanmış tohumlamalar kendi sayacında
  yaşar (gerçek gecikmeler maskelenmez).

## 4. Kural — İlk tohumlama protokolü: her postpartum hayvan 60. günde tohumlanır

**Hedef:** her postpartum hayvan **50. günde otomatik Ovsync'e alınır**, hedef
**60. günde ilk tohumlama**. Eski hazırlık PG'leri (2/25/39. gün) aynen korunur;
yeni protokol onların üzerine inşa edilir.

**Zemin:** `DOGUM_PROTOKOL` motoru zaten gün-ofsetli görev üretir (son doğum
tarihi + VALUES listesi: d0 OKSITOSIN/ADEMIN/KALSIYUM, d2/25/39 PG, d53 ADEMIN,
d54 E_VIT) [CONFIRMED supabase/migrations/20260718000001_protokol_scanner_task_
authority.sql:34-44]. Yeni satırlar eklemek kadardır:

```
(50, 'OVSYNC_BASLAT', '50. Gün: Ovsync başlat'),
(60, 'TOHUMLAMA',     '60. Gün: İlk tohumlama hedefi')
```

**Mekanizma (görevler GERÇEK kayıt olarak doğar, pasif satır değil):**
- `dogum_kaydet` bugün 7 protokol görevini doğum anında `gorev_log`'a önceden
  yazıyor (d2/25/39 PG dahil) — yeni `50. Gün: Ovsync başlat` ve `60. Gün`
  satırları da **aynı desende doğum kaydı anında yaratılır** (gerçek görev
  satırları; scanner yalnız görünürlüktamamlandı takibi yapar, satır üretmez).
- **Tetik katmanları (birincil sahip, yedekler örtüşür ama çakışmaz):**
  1. **Birincil — sahip:** hayvanı **gebe atadığı an** (gebelik onayı) 50. gün
     otomasyonunu kendisi tetikler/kurar; zincir sahibin elinde başlar.
  2. **Yedek 1 — uygulama açılışı VE her refresh:** günü gelmiş ama
     tetiklenmemiş 50. gün görevleri taranır, uygulanır.
  3. **Yedek 2 — `pg_cron` günlük job:** aynı taramayı sunucu tarafında
     çalıştırır; uygulama hiç açılmasa bile garanti.
  - **Çift ateşleme koruması (topuk-sırmama):** tüm katmanlar aynı
     idempotency kilidini kullanır — tetik kaynağı benzersiz anahtarla
     (`ILK-TOH-<anne_id>-<dogum_id>`) işaretlenir; ikinci katman anahtarı
     görünce sessizce geçer, hata/duplikasyon üretmez. Yani biri ıskalarsa
     diğeri vurur, ikisi birden vurursa tek sonuç doğar.
- **50. gün tetiklendiğinde:** senkronizasyon şablonu otomatik uygulanır
  (`sablon_uygula`; vaka + seans günleri + şablonun kendi planlı tohumlama
  görevi). Şablon tohumlama ofseti 10 güne kurulur → planlı tohumlama tam
  60. güne düşer; saat penceresi (Kural 3'teki 09–12/18–21, ileri yuvarlama)
  burada da geçerli.
- **Browser bildirimi:** tetiklenme anında detaylı bildirim verilir (hayvan,
  açılan vaka, seans takvimi, 60. gün tohumlama hedefi) — tarayıcı
  notification API + panel; ıskalanmaz.
- **Muafiyet:** hayvan 50. günden önce tohumlandıysa 50/60. gün görevleri
  üretilmez, açıksa düşürülür; scanner satırı da çıkmaz (DOGUM_PROTOKOL
  döngüsüne erken-tohumlama kontrolü eklenir — bugün yok). Sahip notu:
  "50. günden önce zaten tohumlamam."
- **Çakışma yok:** Kural 3'ün istisnası (aktif senkronizasyon vakası →
  PG_TOHUMLAMA açılmaz) bu protokolden açılan vakaları kapsar; Presynch PG'leri
  (<50. gün) zaten dışarıda.

**Görünürlük:** 50/60. gün satırları PG_TOHUMLAMA ile aynı bölümde yaşar:
panelin en üstünde `Tohumlamalar (N)` kategorisi (saat-hassas görevler),
tarih+saat gösterimi, Gecikmiş sayacından bağımsız sayaç.

## 5. Hormon etken maddeleri — sistem kaydı (hardcoded)

- Seed migration ile 6 etken madde + kategorileri `sistem=true` bayrağıyla
  işaretlenir (Gonadorelin, Buserelin asetat, Oksitosin, Progesteron, Dinoprost,
  Kloprostenol sodyum — "Hormonlar ve Üreme İlaçları" ailesi).
- **DB:** silme/düzenleme RPC'leri `sistem=true` kayıtları reddeder (fail-closed;
  kusur defteri `silent-success` karşıtı — ret açık hata döner).
- **UI:** sistem kayıtlarının sil/kalem butonları gizli/deaktif.
- Kırılım riski düşük: bunlar katalog satırları; reçete/tedavi geçmişi id
  üzerinden bağlıdır, satırın kendisi değişmez.
- PG tespiti her zaman kategori bazlı: kategoriye ileride eklenen yeni PG
  etken maddesi otomatik kapsama girer.

## 6. Bileşen/yüzey özeti

| Kural | Katman | Dosyalar (tahmini) |
|---|---|---|
| 1 | RPC + UI alert | `tohumlama_kaydet` migration, `js/forms.js` (alert toplama) |
| 2 | RPC kontrol + UI modal | yeni `pg_uyari_kontrol` fn, `js/forms.js`/`js/ui.js` (uygulama + planlama ekranları) |
| 3 | RPC görev üretimi + panel | uygulama RPC'leri, `js/ui.js` (Protokol Uyarıları paneli, sıralama) |
| 4 | protokol motoru + şablon tetiği | protokol scanner migration'ı, `sablon_uygula` entegrasyonu, `js/ui.js` (panel) |
| 5 | seed + koruma | migration (bayrak + RPC guard), `js/ui.js` (buton gizleme) |

## 7. Test stratejisi (kabul ölçütleri)

1. Aktif Ovsync vakalı hayvan tohumlanınca vaka `closed`, kalan seans iptal,
   RPC cevabında `kapatilan_ovsyncler`, UI'da tek uyarı. Non-Ovsync aktif vaka
   tohumlamada KAPANMAZ.
2. Toplu (çok hayvanlı) tohumlamada uyarı tek, içerik tam.
3. **Gebe** hayvana PG: kayıt REDDEDİLİR (hard block), sert uyarı, "Yine de
   uygula" yok. Son 25 günde `Bekliyor` tohumlaması olan hayvana PG: modal
   açılır; Vazgeç → hiçbir kayıt; Yine de uygula → kayıt (+ Kural 3 koşulları
   uygunsa 48 saatlik görev). Toplu PG'de Gebe'ler block listesinde, Bekliyor'lar
   tek modalda, risksizler sessiz.
4. PG +48h hedefi daima pencere içinde ve hiçbir zaman 48 saatten önce değil
   (sınır örnekleri: 12:00–18:00 → 18:00; 21:30 → ertesi gün 09:00).
5. PG_TOHUMLAMA tetik koşulları: postpartum <50 günde PG → görev YOK
   (postpartum günü `dogum.tarih`'ten — son doğum, `hayvanlar.dogum_tarihi`
   değil); açık `TEDAVI_SABLON_TOHUMLAMA` görevli VEYA aktif senkronizasyon
   vakalı hayvana PG → görev YOK; son 48 saatte PG yiyene ikinci PG →
   görev YOK (idempotent); 50+ gün, plansız PG → görev VAR.
6. PG_TOHUMLAMA görevi bekleyenlerde görünmez; panelde ayrı `Tohumlamalar (N)`
   bölümünde, panelin en üstünde, tarih+saatli; "Gecikmiş" sayacını etkilemez.
7. İlk tohumlama protokolü: 50/60. gün görevleri `gorev_log`'a yazılır;
   tetik katmanları — (1) sahibin gebe ataması anındaki kurulumu (birincil),
   (2) uygulama açılışı/refresh taraması, (3) `pg_cron` günlük job — aynı
   idempotency anahtarıyla çalışır: çift tetik → tek sonuç, tek katman
   yeter. 50. günde Ovsync otomatik uygulanır (vaka + seanslar + 60. güne
   planlı tohumlama, saat penceresi içinde) VE detaylı browser bildirimi
   çıkar. 50. günden önce tohumlanmış hayvanda görevler yok/düşmüş + scanner
   satırı çıkmaz. Eski d2/25/39 PG görevleri aynen çalışmaya devam eder.
8. Bilinçli PG ("Yine de uygula") sonrası eski tohumlamanın bekleyen
   `GEBELIK_KONTROL` görevleri iptal edilmiştir.
9. Kural 1 kapanışı `islem_log`'da `CASE_CLOSED_BY_TOHUMLAMA` tipiyle görünür
   (`CASE_CLOSED_EARLY` değil).
10. Sistem etken maddesi DB'den silinemez (açık hata), UI'da buton yok.
