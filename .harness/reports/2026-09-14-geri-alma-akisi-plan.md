# L4 FAZ A — Değişiklikler + geri alma: insan akışı tasarımı ve uygulama planı

**Goal:** `.harness/goals/2026/G-20260914-GERI-ALMA-AKISI.md` (status: pending) ·
**Dal:** `agent/geri-alma-akisi` (taban d4bd07f = `agent/entegrasyon-tarih-surum`) ·
**Tarih:** 2026-09-14 · **Durum:** ROOT KAPISI — onay bekler, onaysız kod YOK.

Ölçüm kanıtları (gitignored `reports/` altında, worktree'de):
`reports/2026-09-14-geri-alma-akisi-plan/olcum_zincir.{sql,out}` — demo probe'u
(padoklar, kendi işaretli satırlarımız, koşum sonrası temiz: işaretli log=0).

---

## 0. Yönetici özeti

Sahibin 6 şikayetinin hepsi tek mimari eksikten türemiyor ama tek çözüm ailesine
bağlanıyor: **geri alma L2 motorunda var, insanın olduğu yerde yok.** Bu plan:

1. **Tek motor:** tüm geri-al yüzeyleri (Geçmiş kartı, hayvan kartı, işlem
   detayı, vaka/görev/tohumlama/protokol/sütten-kesme detayları, Değişiklikler)
   tek akışa (önizleme → bilet → uygula) bağlanır; a+b matematik modalı ve
   `islemGeriAl` yolu sökülür (§4).
2. **Köprü:** `islem_log.degisim_txid` (aynı-tx kesin eşleşme) + zaman-penceresi
   yedeği — Geçmiş'teki olay kartından motor hedefi deterministik kurulur (§3).
3. **Zincir:** çakışma artık "blokaj" değil "öneri" — motor sonraki
   değişikliklerin TAM listesini döner, zincir seviyesi hepsini tek onayla,
   tek tx'te geri alır: "3-4-5 sıralı olaydır, komple geri alınacak" (§3).
4. **İnsan dili:** başlıklar "Görev tamamlandı — 14.09 17:25 · küpe 4019";
   UUID/tx katlanır; boş alan gizli; teknik + uygulama-dışı gürültü varsayılan
   kapalı; geri alınamayan olay NEDEN + NE YAPILABİLİR ile açıklanır (§5).
5. **Gezinme:** takvim, gün görünümü, tx detayı history'ye girer; hiçbir ekran
   hapsolmaz (§1g, §7 W3). **Takvim:** olaylı günler renkli nokta (§6).
6. **Geçmiş doğru kalır:** L2 geri alması `islem_log`'a telafi kaydı yazar
   ("X geri alındı") — akış geri alınmış olayı gerçek gibi göstermez (§3.4).

DB değişikliği **yalnız demo** (migration `2026091400000N_*`); prod ayrı sahip
kapısı, sıralama önerisi §9 O-1'de.

---

## 1. İnsan akışları (zarf md.1)

Ortak önizleme modalı (mevcut `m-dg-onizle` + `m-dg-bilet` yeniden kullanılır,
işlem diliyle yeniden yazılır): başlık = olayın insan cümlesi; gövde = plan
özeti (adım kartları); varsa çakışma/zincir bloğu; gerekçe (opsiyonel);
onay butonu `geri_alinabilir` değilse kapalı AMA kutu yönlendirme dolu.

### (a) Geçmiş'teki bir olayı geri alma
1. Geçmiş sekmesi (gün görünümü ya da defter/klasik) → olay kartı:
   "💉 Tohumlama — 14.09 09:30 · 4019".
2. Kartın altında "↩ Geri Al" (çevrimdışıda buton üretilmez — mevcut kural).
3. Tıkla → önizleme: "Tohumlama geri alınacak" + plan ("tohumlama kaydı
   silinecek; aynı anda stok hareketi …") + hayvan küpesi kim satırı.
4. Onayla → bilet yoksa şifre modalı (🔓 kalan süre rozeti) → uygula.
5. Sonuç: "✅ Geri alındı — N adım (yeni işlem …)"; Geçmiş akışında **"Tohumlama
   geri alındı — 14.09 18:02 · 4019"** kartı belirir; açık ekranlar tazelenir;
   kullanıcı Geçmiş'te kaldığı yerde devam eder (hiçbir "baştan giriş" yok).

### (b) Hayvan kartından o hayvanın bir olayını geri alma
1. Sürü → hayvan kartı → Geçmiş sekmesi (tek-hayvan akışı) → olay kartı →
   "↩ Geri Al" → (a) ile aynı modal; kart açık kalır, liste tazelenir.
2. Alternatif hat: kart özeti → "🧾 Bu hayvanın değişiklikleri" → Değişiklikler
   (hayvan filtresi ön-dolu) → tx kartı → geri al (akış (c)).
3. Sürüden çıkarma (satış/ölüm/kesim) dahil: `hayvanlar` güncellemesidir,
   hayvan kartından ve Değişiklikler'den geri alınabilir.

### (c) Değişiklikler'den denetim + geri alma
1. Log → Değişiklikler. Liste tx kartları **işlem dili başlıklarla** ("Görev
   tamamlandı — 14.09 17:25 · 4019"); filtreler: küpe, tarih aralığı (kanonik
   takvim), tablo, işlem tipi; gürültü çipleri: "Teknik (N)" ve "Uygulama
   dışı (N)" varsayılan KAPALI (açınca girer).
2. Tx kartı → detay: satır kartları; güncellemede YALNIZ değişen alanlar;
   boş değer satırı gizli; teknik satır "teknik" rozetli ve varsayılan gizli.
3. Alan / satır / işlem düzeyinde geri al → aynı önizleme akışı.

### (d) Zincir geri alma (sahibin 3-4-5 senaryosu)
1. Herhangi bir yüzeyden (a/b/c) geri al başlat → önizleme çakışma dönerse
   artık blok DEĞİL öneri: "Bu olaydan sonra aynı kayıtta N değişiklik daha
   var:" + gün-saatli insan dilli liste (14.09 17:25 · 4019 · Görev
   tamamlandı …) + **"🔗 Zincir olarak geri al — N olay birlikte"** düğmesi.
2. Tıkla → zincir önizleme: kart listesi en yeni üstte, her kart işlem dilli;
   toplam etki özeti; onay cümlesi: **"3-4-5 sıralı olaydır, komple geri
   alınacak. Onaylıyor musunuz?"**
3. Tek onay + tek bilet → tüm zincir TEK işlemde döner → "✅ N olay birlikte
   geri alındı". Zincir dışı gerçek çakışma varsa (başka satır) zincir de
   önerilemez, engel açıklaması kalır (bypass YOK — sahibin L2 kararı).

### (e) Geri alınamayan olay: neden + ne yapılabilir
Engel kutusu artık insan dilli ve YÖNLENDİRMELİ (onay kapalı, bağlantılar canlı):
- Sistem öncesi (13.09.2026'dan önce / `LOG_YOK`): "Bu olay değişiklik takibi
  kurulmadan önce yapılmış — geri alınamaz. Kaydı elle düzeltebilirsin:
  Hayvan kartı → Düzenle." + bağlantı.
- `ZAMAN_ESLESME_YOK`: "Bu olay kayıtla eşleşemedi (geç girilmiş olabilir).
  Değişiklikler'den günü seçip işlemi oradan geri al." + ön-dolu bağlantı.
- Çakışma: (d)'deki zincir önerisi ya da "önce şu olayı geri al" sıra bilgisi.
- Bağımlılık engeli: "Bu kayıt silinemiyor çünkü bağlı N alt kayıt var: …
  Önce onları geri al ya da sil." (alt kayıt listesi insan dilli).
- Bilet süresi dolmuş: otomatik şifre modalı (mevcut davranış).

### (f) Geri almanın geri alınması
- Geri almanın KENDİSİ de `degisim_log`'a işler (L2 semantiği, değişmez).
- Sonuç toast'ında/Geçmiş "geri alındı" kartında **"⟲ Geri alınanı geri al**
  kısayolu (hedef = geri alma tx'i). Değişiklikler listesinde geri alma tx'i
  normal karttır ve onun da geri al butonu vardır.

### (g) Gezinme: geri/ileri, hapsolmama
- Sayfa geçişi zaten hash+pushState (`goTo`), modal yığını + popstate var —
  korunur. Eksikler kapanır (W3):
  1. `tekTarihTakvimAc` history'ye girer → tarayıcı/Android geri **takvimi
     kapatır** (bugün sayfayı değiştiririyor).
  2. Geçmiş gün görünümü (`_gecmisGun`) ve Değişiklikler tx detayı history
     girişi → geri, görünümü/detayı kapatır.
  3. `pg-degisiklikler` ve `pg-asistan` başlığında "← Geri" düğmesi (bugün
     nav'da butonları yok, geri çıkışsız).
  4. Modallarda ESC kapatma (bugün yok; backdrop/X var).
  5. Hayvan detayı `det-back` ("Göreve Dön"/"Sürüye Dön") deseni aynen.

---

## 2. Geri alınabilirlik envanteri (zarf md.2)

Tam envanter keşfi (dosya:satır kanıtlı, ~70 yazma eylemi) yapıldı; aşağıdaki
tablo ekrana göre sıkıştırılmış özettir — tam satır listesi keşif çıktısında
(lead elinde; W2 zarfına eklenir). Sütunlar: eylem → RPC → L2 tx-geri-alıması
geri getirir mi → eksik/uyarı → karar.

**Genel kural (ölçülmüş):** her eylem tek RPC = tek transaction → L2
`islem`-seviye geri al **işlemi bütünüyle** geri getirir (çok tablolu
yan etkileriyle: vaka aç + tedavi zinciri + görevler tek tx). Şartlar:
olay 13.09.2026 sonrası, demo, çakışma/bağımlılık yok, hedef çözülebilir.

| Grup | Eylem (temsili; tam liste keşifte) | RPC | L2 geri al | Not/karar |
|---|---|---|---|---|
| Sürü | hayvan ekle/düzenle, genc-anne (tek+toplu), kilo, not, çıkış/satış, padok (tek+toplu) | hayvan_ekle/guncelle/… | ✅ tx | Sonradan tohumlama vb. varsa hayvan-INSERT geri alı **bağımlılık engeli** yiyebilir — doğru koruma; (e) metni açıklar |
| Üreme | kızgınlık kaydet/sil/yok, kızgınlıktan vaka, tohumlama kaydet/tekrar, sonuç (gebe/boş/bekliyor), abort, ertele, onayla, manuel gebelik, doğum, vaka içi tohumlama | … | ✅ tx | Tohumlama ailesi stok düşer → aynı tx'te plana girer; farklı tx'te stok_uyari (bilgi) |
| Vaka/Tedavi | vaka aç (toplu dahil), şablon uygula, gün/seans ekle-sil-güncelle-tamamla, ilaç uygulama ekle/sil/güncelle, reçete, gün saati/not, seans tamamla/iptal, vaka kapat (kalanla), manuel tedavi ekle/sil, hasta kaydı kapat/güncelle/sil, protokol sustur | create_case, add_treatment_day*, … | ✅ tx | HASTALIK_KAYDI eski `hastalik_log` tablosuna gider — tablo kapsamda, L2 çalışır |
| Görevler | aşı planla (tek+toplu), görev tamamla, besleme tamam, planlı/ileri-gebe aşı, görev güncelle/ertele, hızlı uygulama | gorev_tamamla, asi_planli_tamamla, … | ✅ tx | gorev_log kapsamda (sahip talimatı, L2) |
| Stok | stok girişi, ilaç/ürün ekle, güncelle, arşivle, düzelt, kategori e/s/g, ilaç-stok eşle, toplu ilaç, toplu aşı, aşı uygula, dozaj, aşı tanımı, rapel | stok_ekleme, bulk_ilac, … | ✅ tx | Stok hareketleri aynı tx'te → geri al stoku da döndürür |
| Tanımlar | hastalık/etken/hekim/padok/grup-padok/protokol-ayar/tedavi şablonu e-s-g, varsayılan yükle | disease_ekle, padok_sil, … | ✅ tx | `seed_defaults` tek tx ise tek işlemde geri döner (W1 testine vakaa) |
| Doğrudan REST | protokol sustur (ui.js:2036 upsert), UI log (app.js:12) | RPC DEĞİL | protokol_dismiss ✅ (trigger yakalar); ui_logs ❌ kapsam dışı | ui_logs telemetri — geri alınmamalı; istisna notu dokümana |
| Asistan | plan uygula/iptal, sohbet sil | asistan_plan_uygula, … | iş tabloları ✅ (tx); agent_* ❌ kapsam dışı | `asistan_plan_geri_al` AYRI sistem — L4 dokunmaz, butonları kalır |
| Geri al kendisi | bileti al, degisim_geri_al | L2 | ✅ (f) | bilet/kullanım tabloları kapsam dışı (tasarım) |
| Kapsam dışı | cop_kutusu, bildirim_log, islem_log'un kendisi | — | ❌ | cop_kutusu'nun kendi geri-yükleme yaşam döngüsü var; bildirim türetilmiş |

**Hiç UI'dan yazılmayan kapsamdaki tablolar** (yalnız RPC içi): uygulama_log,
vaccination_schedule, sablon_hastalik_eslem, tedavi_sablonu_kalem,
vaccine_protocol_steps, vaccine_diseases, pedigree_*, hayvan_override, irk_esih
— bunlara eylem satırı gerekmez; üst eylemlerinin tx'i kapsar.

**Eksik ne vardı (ölçülmüş):** (1) UI'da geri-al yalnız 6 islem tipi +
tohumlamada (`_GM_UNDO_ISLEM_TIPLERI`, gecmis.js:19) + 4 bağımsız buton;
(2) HAYVAN_GUNCELLENDI detay butonu KIRIK (tek-arg `islemGeriAl`,
ui.js:3000 ↔ forms.js:3471 gölgeleme — her tık "İşlem bulunamadı");
(3) Geçmiş↔motor köprüsü yok; (4) zincir yok; (5) telafi kaydı yok.
Hepsi bu planla kapanır; tablodaki ✅'ler eylem bazında FAZ B sonunda
senaryo yürüyüşüyle kanıtlanır (§8).

---

## 3. Zincir geri alma tasarımı (zarf md.3)

### 3.1 Bugün ne döndürüyor (ölçüldü, demo)
Padok satırında E1 INSERT → E2 UPDATE → E3 UPDATE dizisi kurup E1/E2'yi
hedefledik (`olcum_zincir.out`):
- `cakismalar` **yalnız İLK sonraki değişikliği** verir (E1 hedefte yalnız
  E2'nin txid'si; E3 görünmez). Kayıt alanları: `{tablo, pk, satir_pk, txid,
  neden:'SONRAKI_DEGISIKLIK', alan?}` — txid var, **zaman/özet yok**.
- `engeller`: ham teknik metin — `padoklar kaydı "9cb95fc2-…": SONRAKI_DEGISIKLIK`.
- `geri_alinabilir:false` → UI'da kırmızı blok + kapalı onay; **hiçbir
  yönlendirme yok** (sahibin şikayet 3'ün makine tarafı kanıtı).
- Temiz hedef (en son değişiklik): plan tam satır görüntüleriyle döner,
  `geri_alinabilir:true`.

### 3.2 Backend tasarımı (W1, demo migration — goal'da donmuş)
1. **Çakışma tam liste + zengin kayıt:** her `cakismalar` kaydına `zaman`,
   `degisen_alanlar`, `islem`, `log_id`; liste tüm sonraki değişiklikler.
   → UI "hangi günlerden" listesini ve zincir önerisini bu veriden kurar.
2. **`zincir` seviyesi (ROOT K1 ile genişletildi):** kapsam yineli —
   (a) hedef + aynı (tablo,pk) sonraki TÜM değişiklikler; (b) plan satırlarının
   **bağımlılık grafiğindeki satırlarda** (alt kayıtlar + hayvan köprüsü:
   hedef hayvana FK'lı satırlar) hedef txid'den sonraki ve **engel/çakışma
   üreten** değişiklikler ("bağımlı adım" — sahibin tohumlama→sonuc→doğum
   zinciri buradan girer; ilgisiz olaylar GİRMEZ). Sıralama: aynı satırda en
   yeni önce, bağımlı adımlar topolojik önce. Zincire dahil satırların sonraki
   değişiklikleri çakışma SAYILMAZ; zincir DIŞI gerçek çakışma/ENGEL aynen
   bloklar (bypass YOK korunur); `degisim_geri_al` zinciri TEK transaction'da
   uygular → tek `geri_alma_txid`, tek telafi kaydı. Sınır 100 adım.
   **Sıralı rehber (çıkmaz engel YOK):** otomatik zincir kurulamıyorsa yanıt
   `sirali_rehber[]` döndürür — en yeni önce, tekil hedefler + neden; UI her
   satırda kendi geri-al düğmesini gösterir ("önce 5'i, sonra 4'ü geri al").
3. **Köprü — kesin:** `islem_log.degisim_txid bigint` + BEFORE INSERT trigger
   (`txid_current()`; mevcut immutable trigger yalnız U/D'yi bloklar — INSERT
   serbest, ölçüldü). İş satırı + islem_log aynı RPC tx'inde yazılır → birebir.
4. **Köprü — yedek:** `p_hedef.zaman` (ISO): (tablo,pk) için en yakın
   `kayit_zamani` ≤120 sn; bulunamazsa `HEDEF_BULUNAMADI` +
   `detay.neden='ZAMAN_ESLESME_YOK'` → UI açık yönlendirme (akış (e)).
   Gerekçe: `islem_log.tarih` İŞ tarihi olabilir (geç giriş) — kesin eşleşme
   garantisi yalnız `degisim_txid`'dedir, zaman yedeği elimde kalır.
5. **Telafi kaydı:** `degisim_geri_al` aynı tx'te `islem_log`'a
   `tip='GERI_ALINDI'` INSERT (ref_id/ref_tablo/ana_hayvan_id/payload).
   Geçmiş akışı geri alınan olayı "…geri alındı" kartıyla anlatır; orijinaller
   değişmez (immutable korunur).

### 3.3 Zincirin sınırları (dürüst liste — K1 sonrası)
- Kapsam: aynı satır + **bağımlılık grafiğinden engel üreten** çapraz-satır
  olaylar (aynı hayvan, FK/alt kayıt). Hayvanın ilgisiz sonraki olayları
  (ör. haftalar sonraki kilo güncellemesi) zincire GİRMEZ.
- Otomatik zincir kurulamayan durum kalmaz çıkmazsız: `sirali_rehber` tekil
  adımları sırayla gösterir, her adımın kendi düğmesi vardır.
- INSERT geri al + sonradan değişmiş alt kayıt → bağımlı adım olarak zincire
  girer; aşılamaz ENGEL kalırsa rehbere düşer.
- >100 adım → `ZINCIR_COK_UZUN` (demo ölçeğinde pratik değil; sınır bildirilir).

---

## 4. Tek geri alma motoru (zarf md.4)

### 4.1 Legacy yollar ve kararları

| Mevcut yol | Nerede | Karar |
|---|---|---|
| `m-geri-al` a+b modalı, `openGeriAl`, `islemGeriAl` (forms.js:3471), handlers `geri-al`/`close-geri-al`, ui.js:2956 ölü `islemGeriAl` tanımı | Geçmiş kartı, işlem detay paneli | **SÖKÜLÜR** — yerine tek L2 girişi `dgGeriAlAkisi(hedef, seviye, baglam)`; onay = bilet |
| İşlem detay paneli HAYVAN_GUNCELLENDI tek-arg kırık butonu (ui.js:3000) | Geçmiş detayı | Kırık zaten; L2 butonuna döner → kırık da kapanır |
| Görev detayı `gorev_geri_al` (ui.js:6388) | Görev → tamamlandı detayı | L2'ye bağlanır (hedef: gorev_tamamla tx'i — degisim_txid köprüsü) |
| Protokol paneli `hizli_uygulama_geri_al` (ui.js:2086) | Protokol uyarıları | L2'ye bağlanır |
| Buzağı sütten kesme `buzagi_sutten_kesme_geri_al` (forms.js:2827) | Sütten kesme ekranı | L2'ye bağlanır |
| Tohumlama detayı abort/son kayıt geri al (ui.js:8106) | toh-det | L2'ye bağlanır |
| Vaka detayı `cd-geri-al` → `openGeriAl` (ui.js:6540) | vaka detayı | L2'ye bağlanır |
| `asistan_plan_geri_al` (ai-asistan.js:298) | Asistan | **DOKUNULMAZ** — ayrı sistem, kapsamda değil |
| DB'deki 7+ legacy RPC (`geri_al`, `islem_geri_al`, `tohumlama_geri_al`, `case_geri_al`, `gorev_geri_al`, `buzagi_sutten_kesme_geri_al`, `hizli_uygulama_geri_al`) | migrations | **DB'DE KALIR** — prod'da L2 migration'ları uygulanana dek tek güvenlik ağı; emeklilik ayrı sahibe işi. Demo'da UI çağrısı kalmayınca ölü |
| `cop_kutusu` geri yükleme | çöp kutusu | Ayrı yaşam döngüsü — dokunulmaz |

### 4.2 Bilet/şifre görünümü (her yüzeyde aynı)
Mevcut L2 akışı aynen: `m-dg-bilet` (şifre → 🔓 kalan dk rozeti, sessionStorage,
30 sn tazeleme); bilet 1 saat çok-kullanımlı; `BILET_*` hatalarında bilet
silinir + şifre modalı geri döner. a+b matematik onayı EMEKLİ (L2 goal'unda
sahip "hızlı onay için a+b kalabilir" demişti; tek motor = tek onay türü —
bilet zaten daha güçlü; root isterse a+b ön-adımı geri eklenir, açık kalem O-3).

### 4.3 Prod uyumluluğu (O-1 ROOT KARARI: sıralı runbook, flag YOK)
UI tek motora bağlanınca **L2'siz ortamda geri al kalmaz** — bu nedenle
(K2): **L4 dalı, L2(4)+L4 migration'ları PROD'a uygulanmadıkça main'e
MERGE EDİLMEZ.** Runbook sırası (hepsi root/sahip kapısı): prod migration'ları
(L2 4 + L4 N) → salt-okunur teyit → merge/deploy. Capability flag YOK.

---

## 5. Görsel dil (zarf md.5)

- **Başlık şablonu (tek kaynak):** `${olayEtiketi} — ${gg.aa ss:dd} · ${kim}`;
  `olayEtiketi` gecmis.js tek haritasından (+ `GERI_ALINDI`); `kim` = küpe
  (IDB indeksinden) ya da kayıt adı; **ham UUID/tx/PostgREST asla görünmez**
  (U1 kökü korunur) — bunlar "Teknik ayrıntı" katlama bloğunda.
- **Anlamlı alanlar:** `etiketler.js`'e tablo-başına **öne çıkan alan sırası**
  (her tablonun 3-6 kimlik alanı: küpe, ad, tarih, doz…); satır kartında önce
  onlar; güncellemede yalnız değişen alan (var); boş değer → satır gizli;
  değer biçimleme `degerMetni` (var).
- **Teknik ayrıntı katlama:** txid, log_id, kaynak (kim/rol/app), satır pk —
  "Teknik ayrıntı ▸" katlanır blok.
- **Gürültü filtresi:** `teknikal_mi` satırları + `app_name≠'egesut-web'`
  kayıtları varsayılan GİZLİ; liste başında çipler "Teknik (N)" /
  "Uygulama dışı (N)" (U1 çip deseni); sayaç filtre öncesi.
- **Liste kartı (Değişiklikler):** başlık işlem dilli; ikinci satır özet
  "N tablo · M satır" + kaynak rozeti; I/U/D rozetleri renkli (var).
- **Mobil:** mevcut `dg-*` CSS + çip sarma deseni; önizleme modalı tam
  genişlik alt-sheet (mevcut modal deseni); hedef 390 px taşmasız.

---

## 6. Takvim olay günleri (zarf md.6)

- **Çekirdek:** `tekTarihTakvimAc(opts)`'a `isaretliGunler: Set<'YYYY-MM-DD'>`
  (ui.js sarmalayıcısına opt; ızgara çekirdeği `tarih.js` SAF kalır — DOM
  yok kuralı; işaretleme render katmanında). Görünüm: olaylı günde küçük renkli
  nokta + açık ton; boş gün beyaz (sahibin sözü). Seçili-gün yeşili korunur.
- **Yüzeyler ve veri (ek pull YOK):**
  - Geçmiş "Tarihe git" (ana): görünür ay için olay günleri `_gecmisCollectSources`
    havuzunun gün-kümesinden (IDB, zaten bellekte; ay değişince yeniden hesap).
  - Hayvan kartı Geçmiş "Tarihe git": aynı hesap `scope:{animalId}` ile.
  - Değişiklikler filtresi: **varsayılan YOK** (gün listesi ek RPC ister;
    "ek pull yok" tercihi — root isterse ayrı kaleme, O-2).
- **Sınır:** işaretleme yalnız cihazdaki IDB yansımasına göredir (çevrimdışı
  kuyruk henüz sunucuya gitmemiş olayı da işaretler — kabul; not düşülür).

---

## 7. Uygulama planı + fan-out (zarf md.7)

**Şerit:** worker'lar yalnız glm/glmf; denetim luna (codex) serbest.
Worker dalları `--base agent/geri-alma-akisi --local` (zarf FAZ B talimatı).
Her worker: builtin review notu zorunlu, teslim ölçütlü bekleyici, birleşen
dal+workspace hemen kapanır (kırıntı hasadı + `backup/<tarih>-dal-*` etiketi).

| Parça | İçerik | Dosyalar | Worker | Kabul ölçütü |
|---|---|---|---|---|
| **W1 DB** | frozen contract §1-6: köprü kolonu+trigger, `zaman` hedefi, `zincir` seviyesi, çakışma tam liste+alanlar, neden detayları, telafi kaydı | `supabase/migrations/20260914000001..N_*.sql` | glmf | demo RPC test betiği: zaman-hedefi (eşleşen/eşleşmeyen), zincir (2+1'li dizi → 3 adım tek tx), tam çakışma listesi (E1 hedefte E2+E3), telafi kaydı (tip/ref), 100 sınırı, mevcut 46 k3 vakası REGRESYONSUZ; migration replay-safe; birim baseline raporu |
| **W2 UI çekirdek** | tek giriş `dgGeriAlAkisi`; `_gmGeriAlHedef` çözücü; söküm (a+b modal, islemGeriAl×2, handlers); 7 bağlama noktası (§4.1); işlem dili başlıklar + kim satırı; teknik katlama; gürültü çipleri; zincir UX; (e) metinleri; `GERI_ALINDI` etiketi + geri-alınanı-geri-al | `js/degisiklikler/*`, `js/gecmis.js`, `js/ui.js`, `js/forms.js` (söküm bölgesi), `js/api.js` (ADDITIVE), `js/utils/handlers.js`, `index.html`, `tests/unit/*`, `tests/degisiklikler*.spec.js` | glmf (W1 sözleşmesine karşı stub'la başlar — L2 precedensı; entegrasyonda sökülür) | grep: `islemGeriAl` 0 çağrı, `m-geri-al` 0 referans; ham UUID/tx görünürde 0 (unit+e2e); çözücü unit tablosu (tip×kaynak); zincir e2e (fixture); damga tek değer; unit 0 fail |
| **W3 navigasyon+takvim** | takvim history; gün görünümü + tx detayı history; pg-degisiklikler/pg-asistan "← Geri"; ESC; `isaretliGunler` + iki yüzey | `js/ui.js`, `js/tarih/tarih.js` (saf çekirdek), `js/utils/handlers.js`, `index.html`, `tests/*` | glmf (W2'den SONRA — ui.js tek yazıcı) | e2e: takvim açıkken geri → takvim kapanır sayfa aynı; gün görünümü geri → kapanır; ESC modal kapatır; işaretli gün noktası görünür (fixture günü) |

**Sıra/bağımlılık:** W1 ∥ W2 (donmuş sözleşme + stub) → W3 (W2 sonrası).
**Neden bu bölünme:** W2'nin parçaları aynı 4 dosyada birleşir (degisiklikler/
gecmis/ui/forms) — bölünmek merge çakışması + sözleşme kayması üretir; W3'ün
ui.js kesişimi W2'yi bekletmek yerine ardıla koymak tek-yazıcı garantisi verir.
W1 bağımsız (yalnız SQL + test betiği).

**Entegrasyon (lead):** stub sökümü + gerçek RPC ile açılış (demo) → luna
review (tek tur) → insan akışı yürüyüşü (§8, ekran görüntüleri
`~/tmp/agents/l4-akis/`) → teslim raporu.

---

## 8. Kabul senaryoları (zarf md.8 — sahibin 6 şikayeti × yürüyüş)

Her senaryo Playwright betiğiyle demo üzerinde yürünür; adım ekran görüntüsü
`~/tmp/agents/l4-akis/` altına; tablo teslim raporuna.

| # | Sahibin şikayeti | Senaryo (adımlar) | Beklenen ekran |
|---|---|---|---|
| S1 | "Geri al butonu her yerde yok" | (1) Geçmiş kartı → Geri Al; (2) hayvan kartı Geçmiş → Geri Al; (3) işlem detayı paneli → Geri Al; (4) vaka detayı → Geri Al; (5) görev tamamlandı detayı → Geri Al; (6) Değişiklikler tx kartı → Geri Al | Altı yüzeyde de AYNI önizleme modalı açılır; onay sonrası aynı sonuç toast'u; hiçbirinde "baştan gir" yok |
| S2 | "Her eylem geri alınamıyor" | Sırayla: tohumlama kaydet → geri al; doğum kaydet → geri al; görev tamamla → geri al; stok girişi → geri al; toplu aşı → geri al; satış (çıkış) → geri al | Her eylem sonrası önizleme "eylem cümlesi" ile açılır; geri al sonrası ilgili ekran (sürü/stok/geçmiş) eski değere döner; Geçmiş'te "…geri alındı" kartı |
| S3 | "Çakışma blokajı yönlendirmiyor; zincir teklif etmeli" | Bir padok/hayvan kaydında 3 ardışık değişiklik kur (1-2-3); 1.'yi geri almaya çalış | Önizleme: "sonra N değişiklik var" listesi (gün-saat + insan dili) + "Zincir olarak geri al — N olay"; tıkla → kart listesi + "komple geri alınacak, onaylıyor musunuz?" → tek onay → "N olay birlikte geri alındı"; kayıt 1-öncesi duruma döner |
| S3b | (K1) çapraz-satır zinciri | Bir hayvanda tohumlama → sonuc (Gebe) → doğum zinciri kur; tohumlama KAYDINI geri almaya çalış | Zincir önerisi DOĞUM olayını da kapsar (bağımlı adım, kart listesinde görünür); onay → üçü birlikte döner; hayvan kaydı ve üreme geçmişi 1-öncesi duruma döner. Otomatik zincir kurulamayan varyantta: sıralı rehber ("önce doğumu, sonra sonucu geri al") + her satırda kendi düğmesi — çıkmaz YOK |
| S4 | "UI kontrol paneli, SQL tablosu değil" | Değişiklikler'i aç; görev tamamlama tx'ini bul; detayı aç | Başlık "Görev tamamlandı — 14.09 17:25 · 4019"; ekranda txid/UUID YOK (teknik blok katlı); yalnız değişen alanlar; boş alan yok; teknik/uygulama-dışı satır varsayılan gizli |
| S5 | "Detayda hapsoldum, geri tuşu yok" | Hayvan kartı → işlem detayı → (tarayıcı geri); Geçmiş gün görünümü → (Android geri); Değişiklikler → tx detayı → (geri); takvim açıkken (geri); asistan/Değişiklikler sayfasında "← Geri" | Her geri: bir seviye YUKARI kapanır (detay/görünüm/takvim), sayfa kaybolmaz; hiçbir ekranda çıkışsız derinlik kalmaz |
| S6 | "Takvimde olay günleri renkli, boş günler beyaz" | Geçmiş → Tarihe git (olayı olan ay); hayvan kartı Geçmiş → Tarihe git | Olaylı günlerde renkli nokta/dolgu, boş günler beyaz; seçili gün yeşili korunur; ay çevrilince işaretler güncellenir |

---

## 9. Riskler ve root kararına sunulan açık kalemler

**Riskler:**
- Zaman-yedeği yanlış eşleşme (geç girilen olay): köprü kolonu ileriye dönük
  kesin; eski/uyumsuzlarda `ZAMAN_ESLESME_YOK` → açık yönlendirme (hatalı
  geri alma değil, geri alamama hatası — güvenli yön).
- `degisim_listele` büyüme maliyeti (L2 riski aynen; GIN indeksi prod öncesi).
- Zincir yanlışlıkla çok kapsamlı revert: sınır 100 + önizleme kart listesi
  insan onayına zorunlu + bypass YOK.
- Çift log görüntüsü (islem_log + degisim_log) karışıklığı: UI tek akış;
  Değişiklikler yalnız degisim_log, Geçmiş yalnız islem_log okur (bugünkü
  ayrım aynen, telafi kaydıyla tutarlı).
- Worktree node_modules yok — `NODE_PATH` ana checkout (bilinen ortam kısıtı).

**Açık kalemler (root):** — **ROOT KARARI 2026-09-14, hepsi KAPANDI:**
- **O-1 Prod sıralaması:** sıralı runbook (L2 4 + L4 migration'ları prod'a
  uygulanmadan L4 main'e GİRMEZ); capability flag YOK. (§4.3, goal K2)
- **O-2 Değişiklikler filtre takviminde işaretli gün:** HAYIR (ek pull yok).
- **O-3 a+b hızlı onayı:** HAYIR — bilet tek onay türü; sahibe teslim
  raporunda bildirilecek.
- **O-4 `tasks` tablosu L2 kapsamı:** HAYIR.

## 10. Root kapısı kaydı (2026-09-14)

**Karar: KOŞULLU ONAY** (plan commit'i 9ff0873 üzerinden). Uygulanan koşullar:
- **K1 — zincir kapsamı:** aynı-satır kapsamı genişletildi: bağımlılık
  grafiğinden (alt kayıt + hayvan köprüsü) engel üreten çapraz-satır sonraki
  olaylar zincire bağımlı adım olarak girer; otomatik zincir kurulamıyorsa
  `sirali_rehber` (en yeni önce, her satırın kendi düğmesi) — çıkmaz engel
  YOK. §3.2/§3.3/§8(S3b) ve goal frozen contract §3 güncellendi.
- **K2 — main çıkışı:** L4 dalı, L2(4)+L4 migration'ları prod'a uygulanmadan
  main'e merge edilmez; capability flag YOK. §4.3 + goal Constraints güncellendi.
- Goal `status: active` (FAZ B başladı). O-1..O-4 yukarıdaki kararlarla kapandı.

— FAZ A kapandı; FAZ B (W1 ∥ W2 → W3) bu kararlarla yürüyor.
