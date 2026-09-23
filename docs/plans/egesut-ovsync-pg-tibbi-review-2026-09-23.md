# egeSüt ERP1 — Ovsynch / PG / Tohumlama Taslağı Tıbbi Review

**Tarih:** 23 Eylül 2026  
**İncelenen repo:** [`Meliksahtokur/egesut-erp1`](https://github.com/Meliksahtokur/egesut-erp1)  
**İncelenen commit:** [`af7d012f4ec57f6bc61e3708bcd355c5d96e72f1`](https://github.com/Meliksahtokur/egesut-erp1/commit/af7d012f4ec57f6bc61e3708bcd355c5d96e72f1)  
**Tasarım:** [`docs/plans/2026-09-23-ovsync-pg-tohumlama-kurallari-design.md`](https://github.com/Meliksahtokur/egesut-erp1/blob/af7d012f4ec57f6bc61e3708bcd355c5d96e72f1/docs/plans/2026-09-23-ovsync-pg-tohumlama-kurallari-design.md)  
**İnceleme türü:** Veteriner hekimlik açısından tasarım/güvenlik değerlendirmesi; canlı sistemde uygulama veya hasta bazlı tedavi emri değildir.  
**Durum:** Taslak revizyon gerektirir; özellikle bağımsız PG sonrası sabit +48 saat tohumlama otomasyonu klinik kural olarak uygulanmamalıdır.

## 1. Yönetici özeti

Tasarlağın temel yazılım hedefi — tohumlama sonrası yanlışlıkla devam eden senkronizasyon hormonlarını durdurmak, gebelik güvenliği için kontrol koymak ve görevleri tek bir akışta izlemek — yerindedir. Ancak **protokol yönetimi ile biyolojik endikasyon aynı şey değildir**. Şu maddeler revize edilmeden hormon otomasyonu etkinleştirilmemelidir:

| Taslak maddesi | Klinik inceleme | Gerekli karar |
|---|---|---|
| Kural 1: Tohumlama aktif Ovsynch vakasını “başarıyla” kapatır | Sonraki PG seanslarını durdurması güvenlik açısından anlamlı; “başarı” gebelik başarısı veya eksiksiz protokol anlamına gelmez. | Olayı `tohumlama_ile_sonlandirildi` olarak tanımla; kalan hormon görevlerini iptal et, uygulananları ve protokolden sapmayı koru. |
| Kural 2: Gebede PG hard block; Bekliyor ise yalnız ilk 25 gün uyarı | **25 günlük üst sınır güvenlik açığıdır:** 26. günde veya daha geç gebeliği henüz dışlanmamış hayvan sessizce geçebilir. | Bekleyen/gebeliği bilinmeyen tohumlama sonuçlarında gün sınırı olmaksızın güvenlik kapısı. Gebe için normal PG akışında hard block; endike gebelik sonlandırma ayrı yetkili klinik akış. |
| Kural 3: Her bağımsız PG sonrası +48 saatte tohumlama | **Tıbben uygunsuz genelleme.** PG sonrası östrus zamanı değişkendir ve fonksiyonel CL varlığına bağlıdır. | +48 saat `KIZGINLIK_KONTROL`; tohumlama yalnız kızgınlık bulgusu veya seçilmiş/eksiksiz TAI protokolü üzerinden planlansın. |
| Kural 4: PP50 otomatik Ovsynch, PP60 TAI | Klasik 7-gün Ovsynch saatleriyle uyumlu kurulabilir; fakat tüm ineklere koşulsuz otomatik hormon uygulanmamalı. | PP50 `PROTOKOL_UYGUNLUK/BAŞLATMA` adayı; gebelik, uterus, siklus/ovaryum ve klinik durum kontrolü; GnRH–PG–GnRH–TAI saatleri birbirine bağlı. |
| PP2, PP25, PP39 PG görevleri | PP25/PP39 iki dozlu presenkronizasyon olarak anlamlı olabilir; PP2'nin rutin tüm sağlıklı ineklere uygulaması ayrı kanıt/endikasyon sorusudur. | PP2'yi otomatik evrensel hormon görevi olarak yeniden değerlendir; gerekirse koşullu/klinik kararlı görev yap. |
| Hormonlar sistem kaydı (`sistem=true`) | Katalog bütünlüğü için uygun; aynı sınıftaki farklı ürünler doz eşdeğeri değildir. | Etken madde, stereokimya/tuz, konsantrasyon, ürün ve doz ayrı veri alanları; gerçek PG ürününe göre guard. |

**Öncelik:** P0 = Kural 2 ve Kural 3 güvenlik kapıları; P1 = Kural 1 kapanış semantiği ve Kural 4 uygunluk/saat tasarımı; P2 = PP2 kanıt değerlendirmesi ve katalog ayrıntıları.

## 2. Kural bazlı teknik ve klinik öneriler

### Kural 1 — Tohumlama, aktif senkronizasyon vakasını kapatsın; fakat gebelik başarısı bildirmesin

Mevcut vaka 121 örneğinde erken tohumlama kaydı, planlı tohumlama görevini iptal etmiş fakat vakayı açık bırakmış; kalan seansların devamı PG uygulaması dahil yanlış işlem riskini artırmış. Bu yazılım açığı kapatılmalı.

Önerilen olay: `CASE_CLOSED_BY_TOHUMLAMA` muhafaza edilebilir; olayın görüntü metni **“Tohumlama ile senkronizasyon sonlandırıldı”** olmalı. “Başarıyla tamamlandı” ile aynı anlama getirilmemeli. Önceki gerçek enjeksiyon kayıtları korunur, yalnız gelecekteki hormon/seans görevleri iptal edilir. Vaka `closed` olurken `closure_reason=insemination_early`, `protocol_completed=false/unknown` gibi bir durum ayrımı raporlanabilir. Sonraki gebelik sonucu bağımsız kayıttır.

Dikkat: Plan dışı/erken tohumlama, Ovsynch'in standart GnRH–PG–GnRH dizisinin tamamlandığını kanıtlamaz. “Tohumlama yapıldı” olayı sonraki hormonal uygulamaların yeniden planlanması için veteriner değerlendirmesini gerektirebilir; sistem bunları sessizce sürdürmemelidir.

### Kural 2 — PG öncesi gebelik güvenliği

**Revizyon:** `sonuc='Bekliyor' && gun <= 25` koşulu kullanılmamalı. Gün sayısından bağımsız, **gebelik durumu kesin dışlanmamış son tohumlama** varsa kontrol çalışmalı. Sonuç `Gebe`, `Bekliyor`, belirsiz, eksik veya çelişkili olabilir. Geçmişte “Boş” kaydı bulunması daha yeni bir “Bekliyor” tohumlamanın güvenliğini ortadan kaldırmaz; karar son güncel üreme olayı ve klinik kanıta göre verilir.

Önerilen kapılar:

1. **Doğrulanmış gebe:** Normal senkronizasyon/ilaç uygulama akışında PG hard block. Endike gebelik sonlandırma ayrı, yetkili, gerekçeli ve denetlenebilir klinik işlem olmalı.
2. **Tohumlama sonrası gebelik bilinmiyor:** Uyarı + veteriner onayı/klinik değerlendirme zorunlu; sadece bir modalın “Yine de uygula” tıklanması klinik doğrulama sayılmamalı. Uygulama gerekçesi, kullanıcı, zaman ve değerlendirme kaydedilmeli.
3. **Gebe olmadığı değerlendirildi:** Muayene tarihi, yöntem ve varsa yeni bulgular kayıtlı olmalı. Erken negatif ultrasonun gebeliği kesin dışlamayabileceği hesaba katılmalı.
4. **İlaç tanımlama:** Sadece kategori adına güvenilmemeli; ürünün etken maddesi, stereokimya/tuz ve konsantrasyonu da doğrulanmalı.

“Yine de uygula” sonucunda eski `GEBELIK_KONTROL` görevlerini tamamen yok etmek yerine, olay bağını ve iptal gerekçesini koru; **uygun durumda yeniden gebelik/üreme değerlendirmesi** oluştur. PG uygulaması ile düşük veya gebe kalmama sonucu otomatik olarak eşitlenmez.

**Örnek kabul testi:** 30 gün önce tohumlanmış, `Bekliyor` hayvana PG girişinde güvenlik kapısı görünür; 25. gün sınırı aşılmış diye sessiz geçiş yoktur.

### Kural 3 — Bağımsız PG: +48 saat tohumlama değil, kızgınlık kontrolü

Merck Veterinary Manual'e göre PGF2α veya analoğunun luteolitik etkisi fonksiyonel korpus luteuma bağlıdır. PG uygulamasından sonra östrus çoğu zaman 2–7 gün içinde ortaya çıkar; dolayısıyla her hayvana **tam +48 saatte sabit tohumlama** tıbbi olarak çıkarılamaz. Klasik Ovsynch'in sabit TAI saati, sonraki ikinci GnRH ile birlikte tanımlanan ayrı bir protokoldür.

| Klinik bağlam | Üretilecek görev |
|---|---|
| Bağımsız PG uygulaması, açık senkronizasyon protokolü yok | +48 saatte `KIZGINLIK_KONTROL`, takip penceresi ve sonuç kaydı. |
| Kızgınlık görüldü | Kızgınlık başlangıcına ve işletmenin onaylı tohumlama politikasına göre `TOHUMLAMA_PLANLI`. |
| Östrus saptanmadı veya CL/ovaryum durumu belirsiz | `UREME_DEGERLENDIRME`, otomatik TAI yok. |
| Aktif Ovsynch/Presynch ve protokolün PG seansı | Bağımsız PG kuralı devre dışı; yalnız protokolün kendi GnRH/TAI saatleri. |
| PG, gebelik belirsizliği varken yetkili klinik işlem olarak uygulandı | Sonuç/yeniden değerlendirme görevleri; **“PG verildi, artık tohumla”** varsayımı yok. |

09:00–12:00 ve 18:00–21:00 pencereleri **iş organizasyonu** için kullanılabilir. Bu pencerelere ileri yuvarlanan +48 saat, yalnız izlem başlangıcıdır. Biyolojik östrus veya ovulasyon saati değildir. `gorev_tipi='TOHUMLAMA_PLANLI'` yerine ayrı bir `KIZGINLIK_KONTROL`/`UREME_KONTROL` tipi kullanılması raporlama ve yanlışlıkla doğrudan tohumlama formu açılmasını önler.

İdempotens: Aynı uygulama olayının tekrar işlenmesi ikinci görev üretmesin; fakat birbirinden ayrı gerçek PG uygulamaları **birbirine yutulmasın**. Her uygulama kendi audit kaydını korumalı. Yeniden kontrolün tarihi ve gerekçesi protokole göre açıkça güncellenmeli.

### Kural 4 — PP50 Ovsynch / PP60 TAI, klinik uygunluk kapısıyla

Klasik 7-gün Ovsynch örnek saat dizisi:

| Olay | İlk GnRH'ye göre zaman | Örnek postpartum hedefi |
|---|---:|---|
| GnRH 1 | 0 saat | PP50 |
| PGF2α | +7 gün | PP57 |
| GnRH 2 | PG'den +56 saat | PP59 civarı |
| TAI | GnRH 2'den +16 saat | PP60 civarı |

Bu tablo **seçilmiş klasik varyantın örneğidir**; GnRH/PG ürün prospektüsü ve sürü protokolü ayrı doğrulanmalıdır. Protokol varyantları (ör. Cosynch) aynı saatleri kullanmayabilir. Zaman hesaplamasında günü değil gerçek uygulama `timestamp`ini esas al. Çalışma saati penceresi ikinci GnRH veya TAI'yi kaydıracaksa protokolün tüm ilişkili saatleri yeniden klinik onayla planlanmalı; herhangi bir saati tek başına ileri yuvarlayıp biyolojik aralığı bozma.

**PP50 = herkesin otomatik hormon enjeksiyonu değil, uygunluk kontrolü/adayı.** Kontrol alanları: en son doğum, gebelik/son tohumlama, klinik iyileşme ve uterus bulguları, ovaryum/siklus durumu, genel durum ve veteriner kararı. Protokol ancak uygunluk onayı sonrasında aktif seanslar üretmeli. Kaçırılmış günlerde otomasyon, geçmişe dönük “uygulanmış” enjeksiyon kaydı üretmemeli; yeniden tarihleme ve hekim onayı isteyebilmeli.

Not: Taslaktaki “gebe atadığı an PP50 otomasyonu tetiklenir” ifadesi olası bağlam hatası içeriyor. Gebelik onayı, postpartum sonraki ilk tohumlama protokolünün tetiklenmesi değildir. **Doğum kaydında gelecek PP50 uygunluk görevini kur; PP50'de klinik kontrol sonrası protokolü başlat.** Gebelik doğrulanan hayvanda yeni Ovsynch otomasyonu kapalı olmalı.

### Mevcut postpartum PG günleri — PP2 / PP25 / PP39

PP25–PP39 aralığı 14 gündür ve iki PG'li Presynch mantığına oturabilir; PP39'dan PP50'ye 11 gün geçiş de literatürde kullanılan varyantlarla kıyaslanabilir. Bununla birlikte **PP2'de bütün normal doğumlu ineklere rutin PG** ayrı bir karar olmalıdır. Normal doğum yapmış 118 süt ineğinde randomize çalışmada erken postpartum oksitosin veya PGF2α uygulamasının uterus involüsyonu, postpartum endometritis ya da üreme performansını iyileştirdiği gösterilmemiştir [3]. Bu tek çalışma tüm klinik endikasyonları dışlamaz; fakat evrensel otomasyonu haklı çıkarmaya yetmez. PP2 için klinik endikasyon, veteriner gerekçesi ve ayrı protokol tanımı önerilir.

### Hormon katalog ve doz güvenliği

`Gonadorelin`, `Buserelin asetat`, `Oksitosin`, `Progesteron`, `Dinoprost`, `Kloprostenol sodyum` kayıtlarını `sistem=true` ile korumak uygun. Ancak kategori üyeliği **doz, farmasötik eşdeğerlik veya aynı zamanlama** anlamına gelmez. Ürün bazında `etken_madde`, `tuz/stereoizomer`, `konsantrasyon`, `konsantrasyon_birimi`, `uygulama_yolu`, `ürün_doğrulama`, `prospektüs_sürümü` alanlarını ayır.

Örnek: Enzaprost 5 mg/ml dinoprost içerir [4]; Dalmazin 75 mikrogram/ml (+)-kloprostenol içerir [5]. Bunlar eşdeğer mililitre dozlar değildir. İsim benzerliğinden doz kopyalanmamalıdır. Lokal ürünün güncel prospektüsü ve veteriner reçetesi esastır.

## 3. 121 numaralı hayvan — olay modeli

Tasarlağın anlattığı olay: 13 Eylül 2026'da açılan senkronizasyon vakasında 17 Eylül'de elle tohumlama kaydedilmiş; 20–23 Eylül'deki seanslar, PG dahil, açık kalmış. **Bu olayın kesin gebelik kaybına yol açtığı çıkarılamaz.** Gebeliğin mevcut olup olmadığı, ovulasyon/CL evresi ve gerçekten uygulanan ilaç-zaman kayıtlarına göre ayrıca değerlendirilmelidir. Hayvanda tohumlama sonrası hormon uygulaması `PREGNANCY_RISK_EXPOSURE` gibi açıklayıcı, sonucu peşinen varsaymayan bir olay olarak kaydedilebilir.

Önerilen kayıtlama:

- `tohumlama_id`, `case_id`, ilgili `drug_administration_id`, gerçek zaman damgaları ve varsa doz/ürün;
- protokol dışı uygulama uyarısı ve bu uyarıya verilen klinik karar;
- iptal edilen gelecekteki seansların listesi;
- takip/gebelik değerlendirmesi (sonuç kesinleşmeden `abort`/`gebe değil` otomatik sonucu yok).

## 4. Worker'a verilecek uygulanabilir revizyon talebi

1. Tasarım belgesinde **Kural 3'ün `PG_TOHUMLAMA +48 saat` kurgusunu `PG_KIZGINLIK_KONTROL +48 saat` olarak değiştir**. Doğrudan `TOHUMLAMA_PLANLI` yalnız gözlenmiş kızgınlık veya geçerli sabit-zaman protokolü ile oluşsun.
2. **Kural 2'de 25 günlük pencereyi güvenlik kapısından kaldır**; `Bekliyor` ve belirsiz gebelik statüsü, aradan geçen günden bağımsız değerlendirme gerektirsin. PG kararını yalnız UI modalına bırakma: gerçek yazma RPC'sinde atomik doğrula.
3. PG sonrası eski gebelik kontrol görevleri silinmesin; ilişkili audit trail korunsun ve gereken yeni değerlendirme görevi oluşturulsun.
4. **Kural 1'de “başarıyla tamamlandı” ifadesini düzelt**. Vakayı tohumlama nedeniyle kapat, sonraki senkronizasyon hormon görevlerini iptal et, gebelik sonucundan ayrı tut. Hastalık vakalarını etkileme.
5. **Kural 4'ü otomatik enjeksiyondan otomatik uygunluk görevine çevir**. Gebelik onayı/doğum kaydı olaylarının görev tetikleme anlamlarını düzelt. Tamamlanan protokol için saat-zinciri korunmalı.
6. PP2 PG'yi rutin zorunlu uygulama olarak ayrı klinik karar kapısına al; PP25/PP39 Presynch şemasını ürün ve sürü protokolüne göre doğrula.
7. `sistem=true` kayıtlarını koru, fakat PG sınıfı ve ürün eşleştirme/dozları için ayrı testler ekle.

**Sınır:** Bu belge review teslimidir; GitHub deposuna commit/push, canlı DB değişikliği veya hormon uygulaması yapılmamıştır. Kodlamadan önce klinik protokol varyantı ve ürün bazlı dozlar sürü veterineri tarafından kesinleştirilmelidir.

## 5. Kabul testleri

- [ ] Son tohumlaması 30/45 gün önce olan ve sonucu hâlâ `Bekliyor` hayvanda PG güvenlik kontrolü atlanmaz.
- [ ] Doğrulanmış gebe hayvanda normal PG RPC yazması reddedilir; UI kontrolünün atlatılması güvenlik kuralını aşmaz.
- [ ] Bağımsız PG, +48 saatte **kızgınlık kontrolü** üretir; kendiliğinden tohumlama görevi üretmez.
- [ ] Aktif Ovsynch içindeki PG ikinci bağımsız tohumlama/kontrol döngüsü açmaz.
- [ ] Erken tohumlama, yalnız ilgili senkronizasyon vakasının ileri hormon seanslarını durdurur; gerçek yapılmış işlemleri veya ilişkisiz mastitis vb. vakaları silmez.
- [ ] Erken tohumlama `gebelik başarıyla sağlandı` ya da `protokol eksiksiz tamamlandı` olarak raporlanmaz.
- [ ] PP50 günü gebelik doğrulanmış veya uygunluğu onaylanmamış hayvana otomatik enjeksiyon kaydı oluşturulmaz.
- [ ] GnRH1–PG–GnRH2–TAI örnek dizisinde +7 gün, +56 saat, +16 saat ilişkisi saat dilimi ve gece-gündüz pencere sınırlarında korunur.
- [ ] Aynı uygulama olayının retry edilmesi ikinci görev üretmez; iki ayrı gerçek PG uygulaması audit'te iki ayrı olay olarak kalır.
- [ ] Enzaprost ve Dalmazin gibi farklı etken/konsantrasyon kayıtları birbirinin dozunu devralmaz.

## 6. Referanslar

1. Merck Veterinary Manual — *Breeding Programs in Cattle Reproduction*: https://www.merckvetmanual.com/management-and-nutrition/management-of-reproduction-cattle/breeding-programs-in-cattle-reproduction
2. Merck Veterinary Manual — *Hormonal Control of Estrus in Cattle*: https://www.merckvetmanual.com/management-and-nutrition/hormonal-control-of-estrus/hormonal-control-of-estrus-in-cattle
3. Randomize çalışma — *The impact of ecbolic therapy in the early postpartum period on uterine involution and reproductive health in dairy cows*: https://pubmed.ncbi.nlm.nih.gov/30726784/ ; tam metin: https://pmc.ncbi.nlm.nih.gov/articles/PMC6451915/
4. Enzaprost 5 mg/ml, ürün özellikleri (VMD): https://www.vmd.defra.gov.uk/productinformationdatabase/files/SPC_Documents/SPC_2759622.PDF
5. Dalmazin 75 mikrogram/ml, AB veteriner ilaç kaydı: https://medicines.health.europa.eu/veterinary/en/600000078343 ; ürün prospektüsü: https://vmd.defra.gov.uk/ProductInformationDatabase/files/QRD_Documents/QRD-Auth_962109.PDF

---

**Review kararı:** Taslağın otomasyon fikri korunabilir; bağımsız PG → sabit +48 saat tohumlama kuralı kaldırılmalı, gebelik güvenliği 25 güne sınırlandırılmamalı ve PP50 başlangıcı klinik uygunluk onayına bağlanmalıdır.
