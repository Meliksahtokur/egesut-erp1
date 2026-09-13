# W2 — "Tarihe git: o gün ne oldu?" altyapı araştırması

- **Tarih:** 2026-09-13 · **Rol:** worker (`agent/tarihe-git-arastirma`) · **Tip:** research (salt-okuma)
- **Zarf:** `.ss/tasks/W2-tarihe-git.md` · **Canlı DB:** Supabase prod `zqnexqbdfvbhlxzelzju` (= `js/api.js:23` `PROD_URL`), read-only Mgmt API `/database/query`
- **Yöntem:** Tüm envanter satırları canlı şema sorgularından üretildi (sorgu eki §E); kod kanıtları `dosya:satır` referanslıdır.

## Özet

- Olay taşıyan **17 tablo** envanterlendi; hepsi canlı şemadan doğrulandı (§A/§E). **Tenant kolonu hiçbir tabloda yok** — RLS "allow all" tek-şirket modeli (§A.2).
- En kritik bulgu: **"o gün ne oldu" pipeline'ının istemci tarafı büyük ölçüde hazır.** `js/gecmis.js` IndexedDB'den 6+ tabloyu birleştirip her entry'ye **Europe/Istanbul gününe normalize `dateKey`** veriyor (`js/gecmis.js:91-99,171`) ve gün gruplaması yapıyor (`_gmGroup`, `_gmGroupLabel`). Ana "Geçmiş" sekmesi (`#pg-gecmis`, `index.html:715,944`) ve hayvan-kartı Geçmiş sekmesi aynı pipeline'ı tüketiyor.
- Sunucu tarafında benzer iki view **var ama atıl**: `hayvan_timeline_view` JS'te **sıfır referans** ve **bozuk** (aşağıda kanıtla). `treatment_timeline` da kullanılmıyor.
- Aşı, stok hareketi, satış/ölüm/çıkış ve kızgınlık **`gecmis.js` kaynaklarında eksik**; ama hepsi IndexedDB pull kapsamında (`TABLES`, `js/api.js:30-33`) — eklenmeleri pull maliyeti gerektirmez.
- Timezone: DB TZ **UTC** (ölçüldü §C). `date` kolonları TZ-dürüst; `timestamptz` kolonlarında gün sınırı `AT TIME ZONE 'Europe/Istanbul'` ile kesilmeli. İstemci pipeline'ı bunu zaten yapıyor; 32 RPC `CURRENT_DATE` kullanıyor (UTC bazlı gece sapma riski §C).
- Öneri: **Seçenek (c) istemci tarafı** + (a) RPC'yi yalnız derin-geçmiş için izler — gerekçe §D.

## A. Olay tabloları envanteri (canlı şema)

Tüm satırlar §E-1…§E-5 sorgularının canlı çıktılarıdır. "Hayvan FK" = `information_schema` FK kısıtlarından; boş = FK yok.

### A.1 Olay tabloları

| # | Tablo | Olay tarih kolonu | Tip | Tenant kolonu | Hayvan FK | Satır (exact) | Olay anlamı |
|---|---|---|---|---|---|---|---|
| 1 | `tohumlama` | `tarih`, `kontrol_tarihi`, `dogum_tarihi`, `abort_tarihi`, `gerceklesme_at` | date ×4, timestamptz | yok | `hayvan_id → hayvanlar.id` | 282 | Tohumlama + gebelik muayenesi + doğum/abort sonucu |
| 2 | `dogum` | `tarih` | date | yok | `anne_id → hayvanlar.id` | 72 | Doğum |
| 3 | `cases` | `start_date`, `closed_at` | date, timestamptz | yok | `animal_id → hayvanlar.id` | 112 | Vaka açılışı/kapanışı |
| 4 | `treatment_days` | `treatment_date`, `tamamlanma_tarihi` | date, timestamptz | yok | dolaylı: `case_id → cases` | 424 | Tedavi günü planı/tamamlaması |
| 5 | `treatment_day_uygulamalar` | `planned_date`, `uygulama_tamamlandi_at` | date, timestamptz | yok | dolaylı: `treatment_day_id` | 564 | Seans/ilaç uygulaması |
| 6 | `drug_administrations` | (`created_at`; fiili tarih dolaylı: `treatment_day_id → treatment_days.treatment_date`) | timestamptz | yok | dolaylı: `treatment_day_id` | 638 | Uygulama kaydı (seans altı) |
| 7 | `vaccination_log` | `vaccination_date`, `next_due_date` | date | yok | `animal_id → hayvanlar.id` | 381 | Aşı |
| 8 | `kizginlik_log` | `tarih` | date | yok | `hayvan_id` text — **FK yok** (§E-2 kanıtı) | 30 | Kızgınlık gözlemi |
| 9 | `uygulama_log` | `tarih` | date | yok | `hayvan_id → hayvanlar.id` | 120 | Hızlı uygulama |
| 10 | `stok_hareket` | `tarih` | **timestamptz** | yok | **hayvan FK yok** (`stok_id → stok`); `referans_tipi` %97 boş (970/997, §E-5) | 997 | Stok çıkış/giriş (tedavi/aşı/tohumlama stok düşüşü) |
| 11 | `hayvanlar` | `dogum_tarihi`, `cikis_tarihi`, `suttten_kesme_tarihi`, `tohumlama_onay_tarihi` | date | yok | kendisi | 166 | Hayvan yaşam olayları; **satış/ölüm/kesim = `cikis_tarihi` + `cikis_tipi`** (`cikis_yap` RPC `islem_log`'a yazmaz — §E-7 kanıt) |
| 12 | `gorev_log` | `hedef_tarih`, `tamamlanma_tarihi`, `hedef_saat` | date, timestamptz, time | yok | `hayvan_id → hayvanlar.id` | 3055 | Görev (tamamlananlar fiili olay; bekleyenler "plan") |
| 13 | `islem_log` | `tarih` | **timestamptz** | yok | `ana_hayvan_id` text — **FK yok** | 4235 | Birleşik işlem günlüğü, canlıda **49 tip** (§E-5); geri-al altyapısı (`geri_al`, `islem_geri_al`) |
| 14 | `protokol_instance` | `baslangic`, `kapandi_at` | date, timestamptz | yok | `hayvan_id → hayvanlar.id` | 140 | Protokol açılış/kapanış |
| 15 | `hastalik_log` | `tarih`, `kapanis_tarihi`, `kapanma_tarihi` | date | yok | `hayvan_id → hayvanlar.id` | **0** | Eski vaka tablosu — boş; vaka akışı `cases`'e taşınmış |
| 16 | `tedavi` | `tarih`, `sut_yasagi_bitis` | date | yok | `hayvan_id → hayvanlar.id` | **0** | Eski tekil-tedavi tablosu — boş (`tedavi_view` hâlâ okuyor) |
| 17 | `bildirim_log` | `erteleme_tarihi`, `olusturma`, `guncelleme` | date, timestamptz ×2 | yok | `hayvan_id` — FK yok | 70 | Bildirim (olay değil; takvimde görünmesi isteğe bağlı) |

Yıl dağılımı (tohumlama/aşı/doğum, §E-5): veri 2022'den başlar; 2026 en yoğun yıl (489). Hacim küçük: toplam olay satırı ~12–13k → §D performans değerlendirmesinin temeli.

**"Süt" notu:** Ayrı süt-verimi/süt-satışı tablosu **yok** (§E-1: kolon listesi). Zarfın "süt" maddesi kodda **sütten kesme** olarak karşılık buluyor: `hayvanlar.suttten_kesme_tarihi` + `islem_log` tipi `SUTEN_KESME` (32 satır, §E-5) + `buzagi_sutten_kesme_*` RPC'leri. Stok kategorilerinde de süt yok (§E-4).

### A.2 RLS / tenant

- Her tabloda `tenant_id`/`isletme`/`farm_id` kolonu **yok** (§E-1 tam kolon dökümü).
- Politikalar (§E-6): olay tablolarında `allow all` (role `public`) + `anon_all` (`anon`) deseni — yani anon engelleniyor, authenticated her şeye erişiyor; **tenant izolasyonu tanımsız** (tek-şirket ürün). `current_farm_id()` fonksiyonu var ama hiçbir tablo kolonu ona bağlanmıyor.
- `islem_log` istisna: `islem_log_select` (SELECT, public) + `service_insert` — yani yazım service-role'a bağlanmış.
- **Sonuç:** "Tarihe git" yüzeyi için RLS tarafında yeni bir zorunluluk üretmez; seçenek (a) SECURITY INVOKER + mevcut RLS yeterli, seçenek (b)/(c) için de ek tenant mantığı gerekmez.

### A.3 Tarih kolonlarındaki indexler (§E-8)

| Tablo | Index |
|---|---|
| `dogum` | `(anne_id, tarih)` |
| `islem_log` | `(tarih DESC)` |
| `uygulama_log` | `(tarih)` |
| `vaccination_log` | `(vaccination_date)` |
| `treatment_day_uygulamalar` | `(case_id, planned_date)`, `(planned_date, …)` |
| `tohumlama` | `(hayvan_id, sonuc, …)` — `tarih` tek başına indexli **değil** |

Index **yok**: `stok_hareket.tarih`, `cases.start_date`, `gorev_log.hedef_tarih`, `kizginlik_log.tarih`, `treatment_days.treatment_date`. Mevcut hacimde kritik değil; RPC seçeneği seçilirse (a) bölümündeki 3–4 index tek migration maddesidir.

## B. Mevcut altyapı (yeniden kullanılabilir olanlar)

### B.1 `js/gecmis.js` pipeline — CANLI ve uygun (birincil temel)

- Ana yüzey: "Geçmiş" sekmesi `#pg-gecmis` (`index.html:715`, alt-buton `index.html:944`), sürücü `js/ui.js:4041 loadGecmis` — sekme girişinde `pullTables([...11 tablo])` + `_gecmisCollectSources()` (IndexedDB okuma, `js/ui.js:3872`) + `_gmEntriesFromSources(sources, null, {mode:'defter'|'klasik', tumu})`.
- Hayvan kartı aynı pipeline'ı kapsam daraltarak kullanır: `js/ui.js:2798 openDet` → `js/ui.js:2665 _detRenderGecmis` → `_gmEntriesFromSources(sources, {animalId:id})`.
- Entry üretimi (`js/gecmis.js:144-185`): her entry'ye `eventAt` + **`dateKey = _gmDateKey(eventAt)`** (`js/gecmis.js:91-99`) veriliyor — `dateKey`, Z/offset damgalarını **Europe/Istanbul gününe** Intl ile çevirir (`_GM_IST_GUN`); timezone'suz yazımlar aynen korunur. Yani **gün-normalizasyonu ve TZ kaygısı zaten çözülmüş**.
- Gün gruplaması hazır: `_gmGroup` / `_gmGroupLabel(dateKey, todayKey)` (`js/gecmis.js:237-270`) — Bugün/Dün/tarih etiketli gruplar. Arama (`_gmSearch`), CSV dışa aktarım (`_gmCsv`), geri-al entegrasyonu (`_gmUndoRef/_gmUndoButtonHtml`) aynı dosyada.
- **Kapsam eksikleri** (§A ile karşılaştırma): `_gmEntriesFromSources` kaynakları `dogum, tohumlama, cases, gorev_log, uygulama_log, islem_log` (`js/gecmis.js:177-182`). **Eksik: `vaccination_log` (aşı), `stok_hareket`, hayvan çıkışı (`hayvanlar.cikis_*`), `kizginlik_log`, `protokol_instance`.** Bu tabloların hepsi zaten IndexedDB'de (`TABLES`, `js/api.js:30-33`) — `pull` maliyeti yok, yalnız `_gmEventAt`/`_gmPolicyRow` map'lerine kaynak eklenmesi gerekiyor.
- `_gecmisCollectSources` pull listesi de aynı 11 tabloyu çekiyor (`js/ui.js:4047`): `gorev_log, tohumlama, cases, dogum, treatment_days, drug_administrations, drug_products, stok, islem_log, uygulama_log, diseases` — aşı/kızgınlık/çıkış için bu listeye de 3 tablo eklenecek.

### B.2 Sunucu tarafı view'ler — VAR ama ATIL (ve biri bozuk)

- **`hayvan_timeline_view`** (canlı tanım §E-9): 6 dal `UNION ALL` — `dogum`, `tohumlama`, `hastalik_log`, `kizginlik_log`, `islem_log` ×2 (padok-değişimi + ABORT/SATIS/OLUM/SUTTEN_KESME). `tip/event_type/zaman/jsonb detay/kaynak_id` normalizasyonuyla — deseni **güzel**, ama:
  1. **JS'te hiç kullanılmıyor** (`hayvan_timeline_view` ve `treatment_timeline` için `js/`'de sıfır referans — arama kanıtı §E-10).
  2. **Kapsamı dar**: aşı, stok hareketi, görev, vaka (`cases`), protokol, çıkış yok.
  3. **Bozuk en az iki nokta**: (i) `islem_log` tipini `'SUTTEN_KESME'` bekliyor; canlıda gerçek tip `'SUTEN_KESME'` (49 tip dağılımı, §E-5) → sütten-kesme dalı hiç eşleşmez. (ii) `'SATIS_KAYDI'`/`'OLUM_KAYDI'` tiplerini bekliyor; canlıda **hiç yok** (`cikis_yap` RPC'si `islem_log`'a yazmıyor — §E-7) → bu dallar da boş kalır.
- **`treatment_timeline`**: vaka-bazlı seans görünümü; JS'te kullanılmıyor.
- **Değerlendirme:** view'ler yeniden canlandırılmaya değer değil; ama `hayvan_timeline_view`'in `UNION ALL` normalizasyon **deseni**, seçenek (a)'nın RPC taslağına doğrudan taşınabilir.

### B.3 Takvim/tarih-seçici bileşenleri — VAR

- **Kanonik tek-tarih seçici:** `js/ui.js:tekTarihTakvimAc` (ui-map.md §"Single date: canonical component"). W20'nin toplu-tedavi ikizi `js/forms.js:bcTarihTakvimRender`/`bcTarihTakvimAc` (`js/forms.js:1812`), tohumlama döngü-takvimi `bcTakvimAc` (`js/forms.js:1690`), vaka-yüzeyleri `cdSablonTarihTakvimAc`/`cdtTakvimAc` (`js/ui.js:6821,6924`). Hepsi ay-grid render'lı, `toLocaleString('tr-TR')` başlıklı.
- **Genel amaçlı ay-görünümü (month-view sayfası) yok** — ui-map bunu doğruluyor. "Tarihe git" için takvim **seçici** olarak bu bileşenlerden, görsel ay-ızgarası istenirse `bcTakvimAc`'in render deseni örnek alınır.

### B.4 İlgili RPC/view desenleri

- `stat_gebelik_ozet(p_donem_baslangic date, …)` / `stat_suru_ozet(...)` — dönem-parametreli jsonb özet deseni (gün-RPC'sinin dönüş sözleşmesi için model).
- `asistan_hayvan_detay(p_kupe, p_id)` — hayvan detay toplama (tekil hayvan, çoklu kaynak).
- IndexedDB pull altyapısı: `pullTables` + `REALTIME_TABLES` (`js/api.js:30-33,396,578`) — olay tablolarının tamamı cihazda.

## C. Timezone riski (timestamptz × UTC+3)

- **DB TZ = UTC, ölçüldü** (§E-3): `current_setting('TimeZone')='UTC'`; sorgu anında `now()=10:38+00` ↔ TR 13:38.
- `date` kolonları (`tohumlama.tarih`, `vaccination_log.vaccination_date`, …) TZ'siz — gün sorgusunda güvenli.
- `timestamptz` kolonları (`islem_log.tarih`, `stok_hareket.tarih`, `tamamlanma_tarihi*`, `gerceklesme_at`, `kapandi_at`, `olusturma`): UTC'de saklanır; **Türkiye günü** için sunucu sorgusunda `((kolon) AT TIME ZONE 'Europe/Istanbul')::date = p_tarih` deseni gerekir. `Date::timestamptz` karşılaştırması UTC-değeriyle yapılırsa TR gece 00:00–03:00 arası kayıtlar yanlış güne düşer.
- **Mevcut sapmalar (ölçülmüş):**
  - 32 public RPC gövdesi `CURRENT_DATE` kullanıyor (§E-3) — UTC "bugün"; TR saatle 21:00–24:00 arasında girilen `CURRENT_DATE`-defaultlu kayıtlar bir **sonraki** TR gününe yazılır. Bu, "tarihe git" ile birlikte değerlendirilmeli: geçmiş görünümü hangi kaynağı okursa okusun, kayıt günü kolon zaten date ise sorunsuz; `islem_log.tarih` gibi timestamptz kaynaklarda istemci normalizasyonu (`_gmDateKey`, §B.1) bu kaymayı düzeltiyor.
  - Ters örnekte dikkatlice işlenmiş: `cikis_yap` default tarihi `((now() AT TIME ZONE 'Europe/Istanbul'))::date` alıyor (canlı gövde, §E-7) — codebase'te bilinçli TR-TZ kullanımı **var**; "tarihe git" yüzeyi bu standardı izlemeli.
- **İstemci pipeline'ı bu riski zaten çözmüş durumda** (`_gmDateKey` → `_GM_IST_GUN` Intl formatı, `js/gecmis.js:88-99`) — seçenek (c)'nin TZ açısından en sağlam yönü bu.

## D. Seçenekler ve öneri

### (a) Tek RPC: `gun_olaylari(p_tarih date) → jsonb` (UNION ALL)

- **Tasarım:** 17 tabloyu `hayvan_timeline_view` deseniyle birleştirir; günü `date` kolonlarda `= p_tarih`, `timestamptz` kolonlarda `AT TIME ZONE 'Europe/Istanbul')::date = p_tarih` ile keser; `hayvanlar`'dan çıkış/dogum/sütten-kesme satırları; dönüş `stat_gebelik_ozet` gibi `jsonb` (dizi + meta).
- **Performans:** gün filtresi sunucuda; ~12–13k toplam satırda tablo taraması bile <10ms mertebesi, +3–4 index ile endişe kalmaz (§A.3). Tek çağrı, tek sonuç.
- **RLS/tenant:** SECURITY INVOKER + mevcut "allow all" yeterli; tenant kolonu yok (§A.2) — ek güvenlik katmanı konusu değil.
- **Offline:** **zayıf nokta.** Ürün PWA + IndexedDB modeli; RPC-only görünüm çevrimdışında boş kalır. (İstisna: `rpc_invalidate` deseniyle IndexedDB'ye yazılmaz — RPC sonucu önbelleklenmez.)
- **Bakım:** yüksek — 17 tablodan biri kolon değiştirince RPC bozulur; `.harness` RPC referans belgesi + migration yükü her olay-tablosu değişiminde bu RPC'yi de kapsar.
- **TZ:** desende doğru yapılabilir (yukarıda); `CURRENT_DATE` yerine `p_tarih` zorunlu.

### (b) View: `gun_olaylari_view` + istemci `WHERE` 

- **Tasarım:** `hayvan_timeline_view`'in genişletilmiş hâli; istemci `.from('gun_olaylari_view').select().gte/lte(...)` ile gün keser.
- **Performans:** view her sorguda tüm birleşim tablolarını gezer; PostgREST'te parametreli değil — günden bağımsız olarak ~12–13k satırlık UNION üretip süzer. Bugünkü hacimde sorun değil, büyümeyle (yıl başına ~500 olay → 10 yıl ~5k) hâlâ makul.
- **RLS/tenant:** view'lar `security_invoker` yapılmadıkça RLS atlanır — bu şemada etkisi yok (herkese açık) ama deseni kirletir.
- **Offline:** yok (PostgREST view = çevrimdışı erişilemez; IndexedDB'ye pull edilebilir ama "pull full view" deseni repoda yok).
- **Bakım:** (a) ile aynı — her tablo değişiminde view güncellemesi.
- **Kanıt karşılaştırması:** mevcut iki timeline view'in **kullanıcısı sıfır** ve biri bozuk (§B.2) — view yaklaşımının bu repoda **zaten başarısız olduğunu ölçülmüş şekilde biliyoruz**.

### (c) İstemci tarafı: IndexedDB + `gecmis.js` dateKey filtresi — **ÖNERİLEN**

- **Tasarım:** (1) `gecmis.js`'e 5 eksik kaynak eklenir (`vaccination_log`, `stok_hareket`, `kizginlik_log`, `hayvanlar`-çıkış, opsiyonel `protokol_instance`); (2) `loadGecmis` yüzeyine "tarihe git" girişi: `tekTarihTakvimAc` (kanonik bileşen, §B.3) ile tarih seçilir → `entries.filter(e => e.dateKey === secilen)` (dateKey her entry'de hazır, `js/gecmis.js:171`); (3) opsiyonel URL/deep-link (`?gun=2025-11-17`).
- **Performans:** _gecmisCollectSources zaten IndexedDB'den ~12k satırı her açılışta tarıyor; ek filtre O(n) tek geçiş, bellek-içi — telefonda bile <50ms mertebesi (ölçülmedi; hacim kanıtı §A.1).
- **RLS/tenant:** sunucuya ek sorgu yok; mevcut pull RLS'i aynen.
- **Offline:** **doğal tam kapsamlı** — veri cihazda; gün görünümü çevrimdışı çalışır (mevcut Geçmiş sekmesiyle aynı sözleşme: `navigator.onLine && !skipPull` tazeleme, `js/ui.js:4046-4047`).
- **Bakım:** düşük — yeni tablo/olay = `_gmEventAt` map'ine bir satır; RPC/migration şartı yok. Defter↔Klasik mod, arama, CSV, geri-al hepsi ücretsiz gelir.
- **TZ:** zaten çözülmüş (`_GM_IST_GUN` TR-günü normalize, §B.1/C).
- **Risk/maliyet:** `gecmis.js` kaynak büyümesi (17→22 tablo) IndexedDB bellek ayak izini artırmaz (tablolar zaten TABLES pull listesinde); yalnız `islem_log`'a ikinci kez sayılan olayların **dedup** edilmesi gerekir (ör. tohumlama hem `tohumlama` hem `islem_log`'da) — mevcut pipeline bunu `kaynak önceliği` ile zaten yönetiyor; genişletmede aynı ilke korunmalı.

### Öneri

**Seçenek (c) birincil**, (a) izleyici:

1. **Faz 1 — (c):** "Tarihe git" girişi + dateKey filtresi + 5 eksik kaynak. Tek JS dosyaları paketi (`gecmis.js`, `ui.js` küçük yamalar, `api.js` pull listesine `vaccination_log/kizginlik_log` eki — TABLES'ta zaten varlar, yalnız `_gecmisCollectSources` listesi genişler). Migration **yok**.
2. **Faz 2 — (a) yalnız gerekirse:** derin-geçmiş arşiv taraması (IndexedDB'ye inmemiş, çok eski yıllar) istenirse `gun_olaylari(p_tarih)` RPC'si; `hayvan_timeline_view`'in bozuk dalları o sırada düzeltilir ya da view DROP edilir (ayrı karışıklık azaltma maddesi olarak önerilir).

## E. Riskler

1. **TZ sapması timestamptz kaynaklarda** (§C): RPC yazılırsa `AT TIME ZONE 'Europe/Istanbul'` zorunlu; istemcide `_gmDateKey` zaten doğru. `CURRENT_DATE` kullanan 32 RPC'nin gece sapması ayrı bir teknik-borç maddesi (kapsam dışı; rapor edilir).
2. **Dedup:** `islem_log` birleşik günlük olduğundan çoğu olay iki kaynaktan gelir (ör. `ASI_KAYDI` 38 ↔ `vaccination_log` 381). Seçenek (c) genişletmesinde olay başına tek görünüm için kaynak önceliği belirlenmeli (mevcut pipeline deseni korunarak).
3. **`stok_hareket` hayvansız:** %97 `referans_tipi` boş (§E-5) — stok hareketini gün görünümünde hayvana bağlamak mümkün değil; "Stok hareketi (genel)" olarak hayvansız kategori görünmesi doğru beklentidir.
4. **Atıl/bozuk view borcu:** `hayvan_timeline_view` bozuk dallar taşır (§B.2) — "tarihe git" bu view üzerinden yapılırsa yanlış-eksik görünüm riski gerçek; öneri (c) bu riskten bağımsız, ama view'in DROP/fix kararı geciktirilmemeli.
5. **Veri büyümesi:** (c) IndexedDB'de tüm tablo zaten cihazda; (a)/(b)'de index eklenmezse (§A.3) gün-sorgusu index'siz tablolarda (gorev_log 3055, stok_hareket 997) tarama yapar — bugün önemsiz, yıllar sonra değil.
6. **`hastalik_log`/`tedavi` boş ama canlı:** görünümü bu tabloları okursan hiç olay göstermez; vaka akışı `cases`'ten okunmalı (§A.1 notları).

## F. UI yerleşimi önerisi (ui-map.md'ye göre)

- **Ana yüzey:** mevcut `#pg-gecmis` "Geçmiş" sekmesinin üstüne **tarih şeridi**: `[Bugün] [Dün] [📅 Tarihe git]` + seçili gün için "X günü (n olay)" başlığı; filtre seçiliyken `_gmGroup` yerine tek-gün grubu. Bileşen: `js/ui.js:tekTarihTakvimAc` (kanonik; W20 ikizini kopyalamak yerine).
- **Hayvan kartı:** `openDet` Geçmiş sekmesine aynı "tarihe git" girişi eklenir — `_gmEntriesFromSources`'a `{animalId, dateKey}` scope'u doğal genişleme.
- **Ay-ızgarası görünümü (opsiyonel, Faz 2+):** `bcTakvimAc` render deseniyle ay hücresinde olay sayısı rozetleri; ui-map'te ay-görünümü olmadığı için yeni yüzey olarak "Geçmiş" sekmesi altına sekme-içi mod (yeni `pg` sayfası değil).
- **ui-map güncellemesi:** kanıtlanan bu desen ui-map.md'ye "tarih filtresi" maddesiyle eklenmeli (goal'da doküman adımı olarak).

## G. Önerilen goal taslağı

```markdown
# G-20260913-TARIHE-GIT (öneri — W2 araştırma çıktısı)

## Kapsam
"Geçmiş" yüzeyinde tekil gün görünümü: kullanıcı tarih seçer, o günün tüm
olayları (doğum, tohumlama+sonuç, gebelik muayenesi, vaka/tedavi seansı,
aşı, kızgınlık, hızlı uygulama, stok hareketi, satış/ölüm/kesim çıkışı,
sütten kesme, görev tamamlama) tek listede.

## Değişecek dosyalar
- js/gecmis.js — 5 kaynak ekle (vaccination_log, kizginlik_log, stok_hareket,
  hayvanlar-çıkış, protokol_instance[ops]); _gmEventAt/_gmPolicyRow map'leri;
  dedup önceliği (islem_log üstü kaynak önceliği korunur)
- js/ui.js — loadGecmis'e "Tarihe git" girişi (tekTarihTakvimAc), seçili-gün
  filtre state'i (_gecmisGun), gün başlığı; _detRenderGecmis'e aynı giriş
- js/api.js — _gecmisCollectSources pull listesine vaccination_log,
  kizginlik_log (hayvanlar/stok_hareket TABLES'ta zaten var)
- index.html — #pg-gecmis üst şeridi (Bugün/Dün/📅 butonları)
- .harness/references/ui-map.md — tarih filtresi maddesi

## Kabul kriterleri (ölçülebilir)
1. 2025-11-17 gibi bir gün seçildiğinde o güne ait: tohumlama, aşı, doğum,
   vaka seansı ve stok hareketi kayıtları tek listede görünür (demo verisiyle).
2. Çevrimdışında (skipPull) gün görünümü IndexedDB'den dolu çalışır.
3. TR saatiyle gece 00:00-03:00 arası kaydedilmiş islem_log kaydı, TR gününe
   göre doğru grupta görünür (_gmDateKey davranışı korunur).
4. Dedup: aynı olay (örn. aşı) hem vaccination_log hem islem_log'dan gelen
   tek entry görünür; toplam entry sayısı olay sayısıyla eşit.
5. Defter/Klasik mod, arama, CSV dışa aktarım filtreyle birlikte çalışır.
6. Yeni Playwright testi: takvimden gün seç → beklenen olay listesi.

## Kapsam dışı
- gun_olaylari RPC / migration (yalnız derin-geçmiş ihtiyacında ayrı goal)
- hayvan_timeline_view DROP/fix (ayrı temizlik maddesi)
- CURRENT_DATE kullanan 32 RPC'nin TZ düzeltmesi (teknik borç kaydı)
```

## K. Kırıntı özeti

Bu raporun üretimi boyunca şu kırıntılar `.crumbs/tarihe-git-arastirma.jsonl`'a yazılmalı (yazıldı): gate (zarf denetimi: bulgu yok), measurement (canlı şema envanteri + TZ + index ölçümleri), finding (atıl/bozuk `hayvan_timeline_view`; `cikis_yap` `islem_log` yazmıyor; `referans_tipi` %97 boş).

---

### Ek: Canlı şema sorguları (kabul kriteri — envanter kaynağı)

Tüm sorgular Supabase Mgmt API `POST /v1/projects/zqnexqbdfvbhlxzelzju/database/query` (read-only SELECT) ile koşuldu; çıktı dosyaları `$SS_TMP_ROOT/w2/*.json`.

- **E-1. Tablo+kolon dökümü** (§A.1 kolonlar/tipler; §A.2 tenant-yok kanıtı; §E "süt yok" kanıtı):
  ```sql
  SELECT c.table_name, t.table_type, c.column_name, c.data_type, c.udt_name, c.is_nullable, c.column_default
  FROM information_schema.columns c
  JOIN information_schema.tables t ON t.table_schema=c.table_schema AND t.table_name=c.table_name
  WHERE c.table_schema='public' ORDER BY c.table_name, c.ordinal_position;  -- 677 satır
  ```
- **E-2. FK kısıtları** (§A.1 hayvan FK kolonu; `kizginlik_log.hayvan_id` FK-yok kanıtı):
  ```sql
  SELECT tc.table_name AS tablo, kcu.column_name AS kolon, ccu.table_name AS ref_tablo, ccu.column_name AS ref_kolon
  FROM information_schema.table_constraints tc
  JOIN information_schema.key_column_usage kcu ON tc.constraint_name=kcu.constraint_name AND tc.table_schema=kcu.table_schema
  JOIN information_schema.constraint_column_usage ccu ON tc.constraint_name=ccu.constraint_name AND ccu.table_schema='public'
  WHERE tc.constraint_type='FOREIGN KEY' AND tc.table_schema='public';  -- 45 satır
  ```
- **E-3. Exact satır sayısı, TZ, CURRENT_DATE sayısı** (§A.1; §C):
  ```sql
  SELECT 'tohumlama' t, count(*) n FROM tohumlama UNION ALL SELECT 'dogum', count(*) FROM dogum UNION ALL
  SELECT 'tedavi', count(*) FROM tedavi UNION ALL SELECT 'hastalik_log', count(*) FROM hastalik_log UNION ALL
  SELECT 'kizginlik_log', count(*) FROM kizginlik_log UNION ALL SELECT 'uygulama_log', count(*) FROM uygulama_log UNION ALL
  SELECT 'vaccination_log', count(*) FROM vaccination_log UNION ALL SELECT 'stok_hareket', count(*) FROM stok_hareket UNION ALL
  SELECT 'treatment_days', count(*) FROM treatment_days UNION ALL SELECT 'treatment_day_uygulamalar', count(*) FROM treatment_day_uygulamalar UNION ALL
  SELECT 'drug_administrations', count(*) FROM drug_administrations UNION ALL SELECT 'cases', count(*) FROM cases UNION ALL
  SELECT 'hayvanlar', count(*) FROM hayvanlar UNION ALL SELECT 'bildirim_log', count(*) FROM bildirim_log UNION ALL
  SELECT 'gorev_log', count(*) FROM gorev_log UNION ALL SELECT 'islem_log', count(*) FROM islem_log UNION ALL
  SELECT 'protokol_instance', count(*) FROM protokol_instance UNION ALL SELECT 'stok', count(*) FROM stok ORDER BY n DESC;
  SELECT current_setting('TimeZone') AS tz, count(*) FILTER (WHERE pg_get_functiondef(p.oid) LIKE '%CURRENT_DATE%') AS current_date_rpc
  FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.prokind='f' GROUP BY 1;  -- tz=UTC, rpc=32
  SELECT current_date AS sunucu_gunu, now() AS sunucu_zamani, (now() AT TIME ZONE 'Europe/Istanbul') AS tr_zamani;
  ```
- **E-4. RPC listesi + stok kategorileri** (§B.4; "süt yok"):
  ```sql
  SELECT p.proname, pg_get_function_arguments(p.oid) AS arg, pg_get_function_result(p.oid) AS res
  FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.prokind='f';  -- 195 satır
  SELECT ad AS kategori, count(*) AS urun FROM stok_kategorileri GROUP BY ad;
  ```
- **E-5. Dağılımlar + yıl dağılımı** (§A.1 stok/exit/islem notları; hacim):
  ```sql
  SELECT 'stok_hareket.tur' alan, tur deger, count(*) n FROM stok_hareket GROUP BY 2
  UNION ALL SELECT 'hayvanlar.cikis_tipi', cikis_tipi, count(*) FROM hayvanlar WHERE cikis_tipi IS NOT NULL GROUP BY 2
  UNION ALL SELECT 'hayvanlar.durum', durum, count(*) FROM hayvanlar GROUP BY 2;
  SELECT 'stok_hareket.referans_tipi' alan, COALESCE(referans_tipi,'(bos)') deger, count(*) n FROM stok_hareket GROUP BY 2
  UNION ALL SELECT 'islem_log.tip', tip, count(*) FROM islem_log GROUP BY 2 ORDER BY alan, n DESC;
  SELECT to_char(tarih,'YYYY') yil, count(*) n FROM tohumlama WHERE tarih IS NOT NULL GROUP BY 1
  UNION ALL SELECT to_char(vaccination_date,'YYYY'), count(*) FROM vaccination_log WHERE vaccination_date IS NOT NULL GROUP BY 1
  UNION ALL SELECT to_char(tarih,'YYYY'), count(*) FROM dogum WHERE tarih IS NOT NULL GROUP BY 1;
  ```
- **E-6. RLS politikaları** (§A.2):
  ```sql
  SELECT tablename, policyname, roles, cmd, qual FROM pg_policies WHERE schemaname='public'
  AND tablename IN ('tohumlama','dogum','hastalik_log','cases','vaccination_log','stok_hareket','hayvanlar','gorev_log','islem_log');
  ```
- **E-7. RPC gövdesi** (§B.2 `cikis_yap` `islem_log`-yazmıyor + TR-TZ default kanıtı):
  ```sql
  SELECT pg_get_functiondef(p.oid) AS def FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
  WHERE n.nspname='public' AND p.proname='cikis_yap';
  ```
- **E-8. Tarih indexleri** (§A.3):
  ```sql
  SELECT tablename, indexname, indexdef FROM pg_indexes WHERE schemaname='public'
  AND (indexdef LIKE '%tarih%' OR indexdef LIKE '%date%') ORDER BY tablename;  -- 10 satır
  ```
- **E-9. View tanımları** (§B.2, canlı `hayvan_timeline_view` gövdesi):
  ```sql
  SELECT viewname, definition FROM pg_views WHERE schemaname='public';
  ```
- **E-10. JS referans taraması** (§B.2 "atıl" kanıtı; `ss-runner` salt-okuma):
  ```text
  grep: "hayvan_timeline_view" ve "treatment_timeline" → js/ altında 0 eşleşme
  ```
