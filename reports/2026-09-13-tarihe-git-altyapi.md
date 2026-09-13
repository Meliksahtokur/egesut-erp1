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

**"Kuruya ayırma" notu:** Semada kuruya-ayırma verisi **yok** — `%kuru%` adında tablo/kolon yok (§E-11), `hayvanlar.durum` değerleri yalnız `Aktif/Ölü/Satıldı/Kesildi` (§E-5; "Kuru" durumu yok). Kuruya ayırma ürün kodunda türetilmiş bir plan bilgisi değil, muhtemelen son tohumlama tarihinden hesaplanan bir öneri — gün görünümünde "kuruya ayırma olayı" **kaynağı yoktur**; istenirse son-tohumlama+gün hesabıyla türetilen görünür kalem olur (goal taslağı kapsamı dışı).

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

### A.4 Kapsam kararları — gun görünümüne girer mi?

| Tablo | Karar | Gerekçe |
|---|---|---|
| `treatment_day_uygulamalar` | **Girmez (ayrı satır olarak)** | Fiili olay zaten `treatment_days` (gün) + `islem_log` (`TEDAVI_SEANS_TAMAM` 520, `SEANS_EKLENDI` 260, §E-5) üzerinden temsil edilir; ayrıca listeye almak **çift sayım** üretir. Seans detayı, gün görünümünden tek tıkla seans modalına inilir. |
| `cop_kutusu` | **Girmez** | Silinmiş kayıt arşivi; "o gün ne oldu"nun öznesi değil. Geri yükleme akışına aittir (`geri_yuklendi`, 30 gün otomatik silme). |
| `protokol_dismiss` | **Girmez** | Kullanıcının bildirim erteleyip ertelememesi — UI eylemi, hayvan olayı değil (30 benzeri satır). |
| `hayvan_override` | **Girmez** | Metadata (güncelleme damgası taşır, olay taşımaz; `guncelleme_tarihi` def CURRENT_DATE). |
| `bildirim_log` | **Opsiyonel** | Olay değil ama takvimle ilişkili (erteleme_tarihi). Faz 1 dışında tutulması önerilir; kararı lead verir. |
| `protokol_instance` | **Girer** (baslangic/kapandi_at) | Hayvana bağlı gerçek durum değişimi; `_gmEventAt` map'ine 1 satır ekleme ile (Faz 1'de opsiyonel notuyla). |

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

### B.5 Pedigree P1/P2 durumu (zarf soru 2'nin eksik cevabı — düzeltme turunda eklendi)

- **PROD'da pedigree nesnesi YOK**: canlı `pg_proc`/`information_schema` taramasında `%pedigree%` adında **0 fonksiyon, 0 tablo** (§E-12 — boş küme).
- Projection RPC'leri **depoda, deploy edilmemiş**: `supabase/migrations/20260911000002_pedigree_foundation.sql`, `20260911000003_pedigree_farm_backfill.sql`, `20260911000004_pedigree_projection_rpc.sql` (P2 devir belgesindeki "deploy sırası 7 migration" borcunun parçası). Demo ortamına uygulandığı bilgisini doğrulayamadım: demo projesine (`vtzqjmazsvurxdeondmi`) Mgmt API erişimi yok (HTTP 403, yetki kapsamı dışı) — bu madde root beyanıdır, ölçülmüş kanıt **değil**.
- **"Tarihe git" etkisi:** pedigree projection RPC'leri prod'a girse bile gün görünümüne doğrudan girdi değildir (soy ağacı görünümü); yalnız doğum kayıtları (`dogum.anne_id`) ile kesişir. Faz 1 planını etkilemez.

## C. Timezone riski (timestamptz × UTC+3)

- **DB TZ = UTC, ölçüldü** (§E-3): `current_setting('TimeZone')='UTC'`; sorgu anında `now()=10:38+00` ↔ TR 13:38.
- `date` kolonları (`tohumlama.tarih`, `vaccination_log.vaccination_date`, …) TZ'siz — gün sorgusunda güvenli.
- `timestamptz` kolonları (`islem_log.tarih`, `stok_hareket.tarih`, `tamamlanma_tarihi*`, `gerceklesme_at`, `kapandi_at`, `olusturma`): UTC'de saklanır; **Türkiye günü** için sunucu sorgusunda `((kolon) AT TIME ZONE 'Europe/Istanbul')::date = p_tarih` deseni gerekir. `Date::timestamptz` karşılaştırması UTC-değeriyle yapılırsa TR gece 00:00–03:00 arası kayıtlar yanlış güne düşer.
- **Mevcut sapmalar (ölçülmüş):**
  - 32 public RPC gövdesi `CURRENT_DATE` kullanıyor (§E-3) — `CURRENT_DATE` sunucu TZ'sine (UTC) göre hesaplanır. UTC, TR'den 3 saat **geride** olduğundan sapma penceresi **TR 00:00–03:00**'tür ve yön **ÖNCEKİ TR gününe** yazmadır: TR 00:30'da UTC 21:30'dur (hâlâ dün) → `CURRENT_DATE`-defaultlu kayıt TR takviminde **bir önceki güne** düşer. Gün görünümü bu kayıtları TR 00:00–03:00 aralığında bir gün geride gösterir — kaynak `date` kolonu ise sorun yok (`CURRENT_DATE` yalnız default'tur, kullanıcı tarihi el ile girer); `islem_log.tarih` gibi timestamptz kaynaklarda istemci TR-günü normalizasyonu (`_gmDateKey`, §B.1) bu kaymayı düzeltir.
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

### (c) İstemci tarafı: IndexedDB + `gecmis.js` **olay-günü** filtresi — **ÖNERİLEN (ayrı tarih kuralı şartıyla)**

> **Root denetimi düzeltmesi (ölçülmüş):** İlk sürümde "dateKey her entry'de hazır, tek-satır filtre" deniyordu; bu **öncül tutmuyor**. `_gmDateKey`, `_gmEventAt` çıktısını normalize eder; `_gmEventAt` ise "defter günlüğü" (kayıt anı) tercih eder, **olay gününü değil**: tohumlama/uygulama_log/doğum için `created_at` önceliği (`js/gecmis.js:71,77,79`), cases için `closed_at` (`js/gecmis.js:75`). Canlı ölçüm — TR günü `created_at` ≠ olay `tarih`:

| Tablo | toplam | created_at günü ≠ olay tarihi | oran |
|---|---|---|---|
| `tohumlama` | 282 | **252** | %89 |
| `dogum` | 72 | **53** | %74 |
| `vaccination_log` | 381 | **356** | %93 |
| `uygulama_log` | 120 | **3** | %2,5 |

(Kayıt çoğu kez olaydan sonra girilir — `created_at` kayıt anıdır. Aşı satırlarında sapma %93: root ölçümüne benim eklediğim kanıt; aşı kaynak eklenince aynı tuzağa düşmemek için bu ölçüm gereklidir. Sorgu: §E-13.)

- **Tasarım (düzeltme sonrası):**
  1. `gecmis.js`'e 5 eksik kaynak eklenir (`vaccination_log`, `stok_hareket`, `kizginlik_log`, `hayvanlar`-çıkış, opsiyonel `protokol_instance`).
  2. **Ayrı tarih kuralı — gun görünümü kendi `olayGunu(sourceKey, row)` fonksiyonunu kullanır, `dateKey`'i **değiştirmez**:**
     - **`date` kolonları** (`tohumlama.tarih`, `dogum.tarih`, `vaccination_log.vaccination_date`, `uygulama_log.tarih`, `kizginlik_log.tarih`, `cases.start_date`, `stok_hareket` yerine `planned_date` benzeri date'ler, `hayvanlar.cikis_tarihi/suttten_kesme_tarihi`): olay günü = kolonun kendisi — TZ'siz, güvenli.
     - **`timestamptz` kolonları** (`islem_log.tarih`, `gorev_log.tamamlanma_tarihi`, `cases.closed_at`, `treatment_day_uygulamalar.uygulama_tamamlandi_at`): olay günü = TR günü (`_GM_IST_GUN.format(new Date(v))` — mevcut `_GM_IST_GUN` Intl biçimlendiricisi, `js/gecmis.js:88-97`, aynen yeniden kullanılır).
     - `dateKey` (defter görünümü) mevcut davranışını **korur** — hayvan-kartı ve ana defter akışına dokunulmaz.
  3. **`_gmPolicyRow` filtreleri gun görünümü için ayrıca ele alınır** (mevcut filtreler "tamamlanmış iş defteri" amacına göre yazıldı, `js/gecmis.js:34-52`):
     - `cases`: `status === 'closed' && closed_at` şartı gun görünümünde **gevşetilir** — açık vakaların açılış günü (`start_date`) de o günün olayıdır; kapanış, `closed_at` TR günüyle ayrı kalem olarak görünür.
     - `tohumlama`: `_GM_TOH_TERMINAL` allow-list'i gun görünümünde **gevşetilir** — tohumlama *işlemi* `tarih`'inde görünmeli (sonuç bekleyenler dâhil); terminal sonuçlar (Gebe/Bekliyor/Abort/Doğum) kendi sonuç günlerinde ayrı kalemlerdir.
     - `gorev_log`: `tamamlanma_tarihi` şartı **kalır** (tamamlanma olayı) + ek kalem: `hedef_tarih`'inde bekleyen görevler "planlandı" görünümü (Faz 1'de opsiyonel).
     - `islem_log`: `_GM_ISLEM_TIPLERI` allow-list'i gun görünümünde **genişletilir** — gün görünümü tüm işlem tiplerini gösterebilir (defter görünümündeki kürasyon orada kalır); tip başına görünüm etiketi goal'da tanımlanır.
     - `dogum`/`uygulama_log`: filtre yok (default true) — değişmez.
  4. `loadGecmis` yüzeyine "tarihe git" girişi: `tekTarihTakvimAc` (kanonik bileşen, §B.3) ile tarih seçilir → `entries.filter(e => e.olayGunu === secilen)`; (5) opsiyonel URL/deep-link (`?gun=2025-11-17`).
- **Performans:** _gecmisCollectSources zaten IndexedDB'den ~12k satırı her açılışta tarıyor; `olayGunu` ek geçiş O(n), bellek-içi — telefonda bile <50ms mertebesi (ölçülmedi; hacim kanıtı §A.1).
- **RLS/tenant:** sunucuya ek sorgu yok; mevcut pull RLS'i aynen.
- **Offline:** **doğal tam kapsamlı** — veri cihazda; gün görünümü çevrimdışı çalışır (mevcut Geçmiş sekmesiyle aynı sözleşme: `navigator.onLine && !skipPull` tazeleme, `js/ui.js:4046-4047`).
- **Bakım:** düşük — yeni tablo/olay = `olayGunu` map'ine bir satır; RPC/migration şartı yok. Defter↔Klasik mod, arama, CSV, geri-al hepsi ücretsiz gelir.
- **TZ:** iki ayrı kural, iki ayrı doğru: date kolonlarında kolon değeri (TZ'siz); timestamptz'ta TR-günü Intl (`_GM_IST_GUN`). `created_at` tabanlı dateKey'in olay-günü sanılması bu denetimde düzeltildi (§E-13).
- **Risk/maliyet:** kaynak büyümesi IndexedDB bellek ayak izini artırmaz (tablolar zaten TABLES pull listesinde). Aynı olayın iki kaynaktan gelmesi (`islem_log` + kaynak tablo) gerçek bir konu: **dedup önceliği goal'da tablo bazında tanımlanmalı ve kabul kriteriyle ölçülmeli** (§G kriter 4) — mevcut pipeline'ın dedup davranışı bu rapor kapsamında ölçülmedi, iddia edilmez.

### Öneri

**Seçenek (c) birincil**, (a) izleyici:

1. **Faz 1 — (c):** "Tarihe git" girişi + **ayrı olay-günü kuralı** (`olayGunu()`) + 5 eksik kaynak + gun görünümü politika ayarı (§D.c.2-3). JS paketi: `gecmis.js` (olayGunu + kaynaklar + politika), `ui.js` (yüzey + `_gecmisCollectSources:3872` ve `loadGecmis` pull listesi `:4047` genişletme). Migration **yok**.
2. **Faz 2 — (a) yalnız gerekirse:** derin-geçmiş arşiv taraması (IndexedDB'ye inmemiş, çok eski yıllar) istenirse `gun_olaylari(p_tarih)` RPC'si; `hayvan_timeline_view`'in bozuk dalları o sırada düzeltilir ya da view DROP edilir (ayrı karışıklık azaltma maddesi olarak önerilir).

## E. Riskler

1. **TZ sapması timestamptz kaynaklarda** (§C): RPC yazılırsa `AT TIME ZONE 'Europe/Istanbul'` zorunlu; istemcide TR-günü kuralı iki katmanlı — defter için `_gmDateKey` (mevcut), olay günü için `olayGunu()` (Faz 1'de tanımlanacak, §D.c). `CURRENT_DATE` kullanan 32 RPC'nin gece sapması (pencere TR 00:00–03:00, yön ÖNCEKİ gün) ayrı bir teknik-borç maddesi (kapsam dışı; rapor edilir).
2. **Dedup:** `islem_log` birleşik günlük olduğundan çoğu olay iki kaynaktan gelir (ör. `ASI_KAYDI` 38 ↔ `vaccination_log` 381). Seçenek (c) genişletmesinde olay başına tek görünüm için kaynak önceliği goal'da tablo bazında beyan edilmeli ve kabul kriteriyle ölçülmelidir (§G kriter 5) — mevcut pipeline'ın dedup davranışı bu raporda ölçülmedi.
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
  hayvanlar-çıkış, protokol_instance[ops]); AYRI olay-günü kuralı: olayGunu()
  (date kolonlarda kolon değeri, timestamptz'ta _GM_IST_GUN TR-günü);
  gun görünümü için politika ayrımı (_gmPolicyRow aynen kalır, gün görünümü
  cases açık-vaka açılışı + bekleyen tohumlama + genişletilmiş islem_log
  tipleriyle ayrı kural — rapor §D.c.3); dedup önceliği tablo bazında
  tanımlanır (goal'da beyan edilir, ölçü kriter 4)
- js/ui.js — loadGecmis'e "Tarihe git" girişi (tekTarihTakvimAc), seçili-gün
  filtre state'i (_gecmisGun), gün başlığı; _detRenderGecmis'e aynı giriş;
  _gecmisCollectSources (js/ui.js:3872) ve loadGecmis pullTables listesine
  (js/ui.js:4047) vaccination_log + kizginlik_log eki
- index.html — #pg-gecmis üst şeridi (Bugün/Dün/📅 butonları)
- .harness/references/ui-map.md — tarih filtresi maddesi

(Not: hayvanlar/stok_hareket TABLES sabitinde zaten var — js/api.js:30-33
dokunulmaz.)

## Kabul kriterleri (ölçülebilir)
1. 2025-11-17 gibi bir gün seçildiğinde o güne ait: tohumlama, aşı, doğum,
   vaka seansı ve stok hareketi kayıtları tek listede görünür (demo verisiyle).
2. Olay günü doğruluğu: olayı geri tarihli girilmiş bir tohumlama kaydı
   (created_at != tarih, canlıda 252/282 — rapor §D.c) OLAY gününün
   grubunda görünür, kayıt anının gününde değil.
3. Çevrimdışında (skipPull) gün görünümü IndexedDB'den dolu çalışır.
4. TZ: TR saatiyle 00:00-03:00 arası yazılmış islem_log kaydı, TR gününe göre
   doğru grupta görünür (olayGunu TR-günü kuralı; CURRENT_DATE sapma yönü:
   ÖNCEKİ gün, rapor §C).
5. Dedup: aynı olay (örn. aşı) hem vaccination_log hem islem_log'dan gelen
   tek entry görünür; goal'da beyan edilen öncelik tablosuyla ölçülür —
   toplam entry sayısı = beyan edilen önceliğe göre olay sayısı.
6. Defter/Klasik mod, arama, CSV dışa aktarım filtreyle birlikte çalışır;
   defter görünümü dateKey/eventAt davranışı DEĞİŞMEZ (mevcut testler yeşil).
7. Yeni Playwright testi: takvimden gün seç → beklenen olay listesi.

## Kapsam dışı
- gun_olaylari RPC / migration (yalnız derin-geçmiş ihtiyacında ayrı goal)
- hayvan_timeline_view DROP/fix (ayrı temizlik maddesi)
- CURRENT_DATE kullanan 32 RPC'nin TZ düzeltmesi (teknik borç kaydı)
```

## K. Kırıntı özeti

Bu raporun üretimi boyunca `.crumbs/tarihe-git-arastirma.jsonl`'a yazılan kırıntılar: gate (zarf denetimi: bulgu yok), gate·dead-path (`hayvan_timeline_view` atıl ve bozuk), measurement (envanter + TZ + index), open_item (kapsam dışı borçlar), assumption (gitignore `reports/`).

**Düzeltme turu (root denetimi @402c53a, 5 madde — hepsi işlendi):** (1) (c) önerisinin dateKey öncülü düzeltildi — `_gmEventAt` defter günlüğü (created_at/closed_at) tercih ediyor, canlı sapma ölçümüyle ayrı `olayGunu()` kuralı tanımlandı (§D.c, §E-13); (2) CURRENT_DATE sapma yönü düzeltildi — pencere TR 00:00–03:00, yön ÖNCEKİ gün (§C); (3) pedigree P1/P2 durumu eklendi — prod'da yok, migration 20260911000002..04 depoda, demo ölçümü yetki yok (§B.5); (4) goal taslağı yol düzeltmesi (js/ui.js:3872/4047) + kanıtsız dedup iddiası ve 17→22 sayısı çıkarıldı (§G); (5) kuruya-ayırma notu + §A.4 kapsam kararları (§A.1, §A.4).

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
- **E-11. Kuruya-ayırma taraması** (§A.1 "Kuruya ayırma" notu — boş küme kanıtı):
  ```sql
  SELECT table_name FROM information_schema.tables WHERE table_schema='public'
  AND (table_name LIKE '%kuru%' OR table_name LIKE '%sut%');  -- 0 satır
  ```
- **E-12. Pedigree taraması** (§B.5 — prod'da yok, boş küme kanıtı):
  ```sql
  SELECT proname FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
  WHERE n.nspname='public' AND proname LIKE '%pedigree%'
  UNION ALL SELECT table_name FROM information_schema.tables
  WHERE table_schema='public' AND table_name LIKE '%pedigree%';  -- 0 satır
  -- Migration kanıtı: supabase/migrations/20260911000002..04_pedigree_*.sql (depoda)
  -- Demo ölçümü: Mgmt API demo projesine 403 (yetki yok) — root beyanıyla sınırlı
  ```
- **E-13. created_at ≠ olay-tarihi sapması** (§D.c düzeltme kanıtı — root denetimi ölçümü bağımsız tekrarlandı):
  ```sql
  SELECT 'tohumlama' t, count(*) n, count(*) FILTER (WHERE
           ((created_at AT TIME ZONE 'Europe/Istanbul')::date IS DISTINCT FROM tarih)) sapma
         FROM tohumlama WHERE tarih IS NOT NULL GROUP BY 1
  UNION ALL SELECT 'dogum', count(*), count(*) FILTER (WHERE
           ((created_at AT TIME ZONE 'Europe/Istanbul')::date IS DISTINCT FROM tarih))
         FROM dogum WHERE tarih IS NOT NULL GROUP BY 1
  UNION ALL SELECT 'uygulama_log', count(*), count(*) FILTER (WHERE
           ((created_at AT TIME ZONE 'Europe/Istanbul')::date IS DISTINCT FROM tarih))
         FROM uygulama_log WHERE tarih IS NOT NULL GROUP BY 1
  UNION ALL SELECT 'vaccination_log', count(*), count(*) FILTER (WHERE
           ((created_at AT TIME ZONE 'Europe/Istanbul')::date IS DISTINCT FROM vaccination_date))
         FROM vaccination_log WHERE vaccination_date IS NOT NULL GROUP BY 1;
  -- Sonuç: tohumlama 252/282, dogum 53/72, uygulama_log 3/120, vaccination_log 356/381
  ```
- **E-14. Kod kanıtı** (§D.c — `_gmEventAt` defter günlüğü tercihi): `js/gecmis.js:65-85` (`created_at` önceliği satır 71/77/79; `cases.closed_at` satır 75); `_gmPolicyRow` filtreleri `js/gecmis.js:34-52`.
