# Bağımsız DB sağlık taraması — bulgu raporu (research, kod YOK)

- **Zarf:** `.claude/tasks/2026-09-11-db-saglik-worker.md` (owner talebi 2026-09-11:
  "db'de kırılan bozulan başka bir şey var mı bağımsız araştırılsın")
- **Ortam:** DEMO Supabase Postgres (pooler, psql 18.6), tüm sorgular
  `BEGIN; SET LOCAL default_transaction_read_only = on; ... ROLLBACK;` desenli salt-okunur.
  PROD'a bağlanılmadı; PROD yazma sıfır.
- **Demo anlık görüntüsü:** son `demo_klonla` = 2026-09-02 15:59 UTC (10.823 satır, OK) —
  bulgular 9 gün bayat olabilir; demo klonu prod'un birebir kopyasıdır
  (`demo/02_demo_klonla.sql`: truncate+insert, tablo filtresi yok), bu yüzden
  yapısal bulguların prod'da da var olması beklenir (PROD probe'ları ekte).
- **Yöntem:** anomali sınıfları zarftan alındı; her probe canlı
  `information_schema` + ilgili migration gövdeleriyle (`20260512000004_islem_geri_al_genel.sql`,
  `20260520000001_tohumlama_case_geri_al.sql`, `20260605000003_protokol_instance_schema.sql`,
  `20260620000002_sutten_kesme_trigger.sql`) ve stok formülü kod kanıtıyla
  (`js/ui.js:848` — "baslangic_miktar − Σ(iptal olmayan hareket)") temellendi.
- **Kontrol listesi:** BUGS.md bilinenleri (BUG-002/003, SMELL-001..004, 907 rota vakası,
  pedigree P1'in 2 maternal blocker'ı) yeniden keşfedilmedi; bilinen 2 maternal
  blocker (`5979186d…` kupe55, `982fbd16…` kupe31) tarih-uyumsuz probe'larında istisna edildi.

## Sınıf tablosu

| # | Sınıf | Probe SQL (özet) | Demo sonucu | PROD gerekli mi |
|---|---|---|---|---|
| A | Yetim/geçersiz referans | `v_orphan_gorev` sayımı; `islem_log.ref_tablo/ref_id` UNION-varlık kontrolü; FK-vari NOT EXISTS turu | **872 aktif islem_log→silinmiş tohumlama** (hepsi 2026-05); 308 HAYVAN_EKLENDI→yok hayvan; 80 parent_id yetim (açık olan yok — bkz. BF-7); v_orphan_gorev=66 koşum anında (review turunda 69 — demo sürüklenmesi, BF-6) | EVET (P1, P2) |
| B | Takılı kalan görev | `tamamlandi=false AND iptal=false AND hedef_tarih<current_date`, tip×yaş kovası | 272 açık gecikmiş (98'i ≤7g TEDAVI_SEANS); **>90g = 0** | EVET (P7) |
| C | Çift uygulama | `uygulama_log` self-join, aynı hayvan+etken+stok, `created_at` 0–5 dk penceresi | **4 çift (tek hayvanda üçleme dahil)**; 60 sn penceresi: 2 | EVET (P4) |
| D | Stok tutarsızlığı | `baslangic_miktar − Σ(iptal olmayan hareket) < 0` | 12 negatif kalem (−9 … −945); iptal hareket=177 | EVET (P3) |
| E | Geri_alma yarım kalanı | `durum='geri_alindi'` × `geri_alma_tarihi IS NULL` / snapshot es / ref ölü; iade-hareket karşıtı | **28/31 geri_alindi'de timestamp yok**; 26 geri_alindi ref'i ölü; 2 İade hareketi ↔ 0 işaretli hızlı-uygulama geri alması | EVET (P2, P5) |
| F | Protokol hayaleti | `protokol_instance_id` ölü-ref; aktif protokolde açık görev kalmaması; vaccination↔uygulama eşleşme | Ölü-instance ref = 0; **45 zombi aktif protokol**; vaccination↔uygulama eşleşmez = 379/380 (zayıf sinyal, eşleme belirsiz) | EVET (P5, P6) |
| G | Tarih anomalisi | gelecek-tarihli kayıt (7 tablo); `dogum.tarih` ↔ buzağı `dogum_tarihi`; anne-yaş çelişkisi | **Hepsi 0** — temiz | hayır |

## Bulgular

Öncelik sırası: audit bütünlüğü → hasta-güvenliği (çift doz) → tutarlılık → hijyen.
Her bulguda: sayım + örnek kimlik + önerilen düzeltim sınıfı (**data-fix / kod / izle**) —
bu raporda hiçbir düzenleme yapılmadı.

### BF-1 — 872 aktif islem_log satırı silinmiş tohumlama satırlarını gösteriyor (audit kırığı) [HIGH]

- **Kanıt:** `ref_tablo='tohumlama'` 1.200 islem_log satırından 873'ünün hedefi yok;
  872'si `durum='aktif'` (yalnız 1'i `geri_alindi`). Hepsinin `tarih`'i 2026-05
  (ay kırılımı: 2026-05 = 873, diğer aylar 0). `tohumlama` tablosunda 276 satır var
  (min 2022-07-24, max 2026-09-10) — yani Mayıs'ta toplu bir silme olmuş.
- **Neden bu bir bulgu:** `tohumlama_geri_al` (migration `20260520000001:44-48`)
  silerken islem_log'u `geri_alindi` + timestamp ile işaretliyor. 872 satırın
  `aktif` kalması, silmenin bu RPC dışından (manuel/script/kütle temizlik) ve
  audit kapatılmadan yapıldığını gösteriyor. Örnek: `ref_id=f381376b-1fd6-4672-92ac-fd80a960ceb8`,
  tip=TOHUMLAMA, durum=aktif, tarih=2026-05-09 (hedefi yok).
- **Etki:** undo geçmişi bu satırlar için yanıltıcı; ref-id'ye göre geri arama/rapor kırılır.
- **Önerilen sınıf:** data-fix (872 satırı `geri_alindi` olarak kapatma ya da
  "silinmiş hedef" işaretlemesi — owner kararı) + izle. **Düzenleme yapılmadı.**

### BF-2 — Aynı hayvana aynı etkenle dakikalar içinde tekrar uygulama (907 deseni, genel sınıf) [HIGH]

- **Kanıt (0–5 dk penceresi, aynı hayvan+etken+stok):** 4 çift;
  60 sn penceresinde 3 çift. Örnekler:
  - hayvan `120ff1e6-74ee-4da4-8c67-3f3597d2bdb7`, OKSITOSIN 6 ml ×3:
    2026-07-10 11:35:42 → 11:36:01 (19 sn) → 11:37:22 (81 sn), id'ler
    `51d9e40d…`, `80ca523d…`, `96b04b13…`
  - hayvan `59eca038-8ad2-418e-b1f5-541d47425cc5`, PG ×2: 2026-06-27, 35 sn arayla
  - Not: aynı hayvan 07-09'da da OKSITOSIN almış (13:25 ve 16:16 — 3 sa arayla,
    muhtemel meşru doz); sorun 07-10'daki 100 saniyelik üçleme.
- **İlk probe düzeltmesi:** ilk denemede `b.created_at - a.created_at <= interval '5 minutes'`
  negatif aralıkları (id sırası ≠ zaman sırası) de içine alıyordu — `b.created_at >= a.created_at`
  eklenerek düzeltildi; 27 sahte çift → 4 gerçek çift. (Aynı hayvan+etken farklı
  günlerdeki kayıtları sayan probe'u ilk koşumda eleme gerekçesi bu.)
- **N seçimi:** 5 dk "hızlı-uygulama çift-tık" penceresi olarak savunulur — 907 vakası
  15 sn idi; 5 dk hem insan hatası penceresini kapsar hem meşru aralıklı dozları
  (saatler/src arası) dışarıda bırakır. Hassasiyet: 60 sn'de 2 çift kalır (19 sn'lik
  OKSITOSIN çifti + 35 sn'lik PG çifti; 81 ve 99 sn'lik çiftler pencere dışı).
- **Önerilen sınıf:** kod (hızlı-uygulama formuna kısa-süre aynı-hedef idempotency
  uyarısı — 907 fix'iyle aynı sınıf) + data-fix review (bu 4 çift klinik mi hata mı — owner).

### BF-3 — 28/31 geri_alindi satırında geri_alma_tarihi NULL [MEDIUM]

- **Kanıt:** `durum='geri_alindi' AND geri_alma_tarihi IS NULL` = 28 (toplam geri_alindi=31).
  Tip kırılımı: 23 VAKA_ACILDI + 5 ABORT_KAYDI (ör. id `21438ddd-7331-4c58-97c3-be71fc7d3b8b`,
  ref=cases:019fc09d…).
- **Neden:** tracked `case_geri_al` (`20260520000001:123-125`) her iki alanı da yazıyor
  (`SET durum='geri_alindi', geri_alma_tarihi=now()`). Canlı gövde farklıysa (SMELL-003
  ailesi) ya da satırlar eski-sürüm yoldan geldiysa timestamp eksik kalıyor.
- **Önerilen sınıf:** izle + PROD doğrulama (P2: sayım + canlı fonksiyon gövdesi
  salt-okunur `pg_get_functiondef`). Kod düzeltimi yalnız canlı gövde gerçekten
  timestamp yazmıyorsa.

### BF-4 — 45 zombi "aktif" protokol: tüm çocuk görevleri kapalı [MEDIUM]

- **Kanıt:** `protokol_instance.durum='aktif'` (98) içinde 45'inin
  `protokol_instance_id` ile bağlı hiç açık görevi yok (0'ının da çocuğu yok).
  Kapanma normalde trigger'la: `kapandi_sebep ∈ {DOGUM, OLUM, SATIS, MANUEL, TAMAMLANDI}`
  (`20260605000003:13`, `20260620000002:63`). Örnek: `1ad458fd-0a42-4c1e-98b7-90c2b61d90fd`
  UREME/GEBELIK, bas=2025-10-03 — 11 aydır aktif duran gebelik protokolü, 3 çocuğu da kapalı.
- **Etki:** kapama olayını (doğum/satış) kaçırmış protokoller görev üretmeye/panelde
  aktif görünmeye devam edebilir.
- **Önerilen sınıf:** izle (45'in tip×yaş kırılımı PROD'da çıkarılmalı) + owner data-fix
  kararı (elle kapatma listesi).

### BF-5 — 12 stok kaleminde negatif hesaplanan kalan [MEDIUM-izle]

- **Kanıt:** `baslangic_miktar − Σ(iptal olmayan hareket) < 0` (formül: `js/ui.js:848`).
  En büyükler: Klavil (bas=300, kalan=−945), Enrolen (251→−918), Makrovil (215→−247),
  Halocur (120→−495); ayrıca başlangıcı hiç girilmemiş 7 kalem (bas=0, −2 … −711).
- **Bağlam:** eksiye düşme politika olarak serbest (BUGS.md BUG-002 notu, emsal
  migration `20260902000002`). Bulgu sınıfı "negatif var" değil, **büyüklük**
  (başlangıcın 3 katı aşım) — BUG-002'deki serbest-metin/rastgele eşleşme ailesinin
  bir belirtisi olabilir ya da çift düşüm.
- **Önerilen sınıf:** izle + PROD probe (P3); aşım kalemlerinde hareket dökümü review.

### BF-6 — E2E kalıntı görevleri (demo test-artifact kirliliği) [LOW]

- **Kanıt:** koşum anında `v_orphan_gorev` 66 satırının tamamı: tip=MANUEL,
  `hayvan_id IS NULL`, `aciklama LIKE 'E2E-OFLINE-%'` (ör. `4bec7a82…`
  "E2E-OFLINE-IYI-1788427746552", hedef=2026-09-03); MANUEL hayvan-NULL açık
  görevlerin 66/68'i bu desen. **Review turunda yeniden ölçüldü: E2E deseni 46,
  v_orphan 69** — demo canlı E2E koşularıyla sürükleniyor (eski kalıntılar
  kapanıp yenileri ekleniyor); bu sınıfın sayıları oynaktır, sınıfın kendisi sabit.
- **Neden:** offline E2E senaryoları demo'ya görev yazıyor, teardown temizlemiyor.
  (Testler demo-only kurala uyuyor; sorun kalıntı.)
- **Önerilen sınıf:** data-fix (demo'da temizlik) + kod (test teardown'ına silme adımı).

### BF-7 — 80 parent_id yetimi + küçük hijyen kalemleri [LOW]

- **Kanıt:** `parent_id` dolu ama ebeveyn yok = 80 → 79 TEDAVI_SEANS (40
  `tamamlandi=true` + 39 `tamamlandi=false, iptal=true` — **açık olan yok**; Haziran
  örneklemi, kaynak NULL; ör. `b7a7419d…` hedef=2026-06-15) + 1 BESLEME. review
  bağımsız ölçümü: 80'in tamamı `v_orphan_gorev` dışında (view yalnız açık görevleri
  tarıyor) — operasyonel etkisi düşük, audit hijyeni.
- **Diğer:** 10 satır `kaynak='SUTTENKES-H000xxx'` eski-kimlik formatlı kaynak
  referansı taşıyor — **yetim DEĞİL**: hayvanların 10/10'u hayvanlar'da mevcut ve
  Aktif (ilk probe'daki substring off-by-one hatası review'da yakalandı, iddia
  düşürüldü); `bildirim_log` 1 yetim; boş-string `gorev_tipi` = 1;
  `islem_log` 26 satır ref_tablo NULL/ref_id dolu + 6 tersi.
- **Önerilen sınıf:** izle. (Bu raporda V7 ilk koşumunda nitelenmemiş `parent_id`
  alt-sorgu iç skuba çözünüp 1.662 saymıştı; `g.`/`p.` niteliyle düzeltildi — 80 doğru değer.)

### BF-8 — Açık gecikmiş görev birikimi 272 (ancak >90g sıfır) [LOW-izle]

- **Kanıt:** açık+geçmiş hedef 272 / açık toplam 546. Kırılım: TEDAVI_SEANS 104
  (98'i ≤7g), MANUEL 60 (27'si 8–30g — E2E kalıntılarının hedef tarihleri bu kovada;
  BF-6), TEDAVI_GUN 60, BESLEME 23 … **>90g = 0** — eski-yarıda takılı kalma yok.
  En eskisi 2026-08-20 (PADOK_DEGISIM, `093d5bca…`).
- **Yorum:** birikim yeni (≤1 ay) — operasyonel gecikme + demo anlık görüntüsü etkisi
  karışık; PROD'da gerçek dağılım P7 ile ölçülmeli.
- **Önerilen sınıf:** izle.

### BF-9 (zayıf sinyal, iddia DEĞİL) — vaccination_log ↔ uygulama_log eşleşmezliği

- **Kanıt:** vaccination_log=380 satırın 379'u için aynı hayvan+aynı gün
  uygulama_log kaydı yok (uygulama_log toplamı 107). İki tablonun kimlik eşlemesi
  net değil (`vaccine_id`/`stock_item_id` ↔ serbest `etken_kod`); çift-yazının hangi
  alt kümede zorunlu olduğu kod tarafında belirlenmeli (907 vakası bir aşı çift-yazısıydı).
- **Önerilen sınıf:** PROD probe (P6) + kod-eşleme kararı. **Defekt iddiası yok.**

### Negatif bulgular (temiz çıkan sınıflar — arandı, bulunamadı)

- Gelecek tarihli kayıt: uygulama/vaccination/tohumlama/dogum/hayvan-dogum_tarihi/
  islem_log/stok_hareket → **hepsi 0**.
- `dogum.tarih` ↔ buzağı `dogum_tarihi` uyumsuz (>1 gün): **0** (bilinen 2 maternal
  blocker dahil değil — zaten bu probe tanımında çıkmıyor; pedigree ölçütü farklı).
- `dogum.tarih` < anne `dogum_tarihi`: **0**.
- vaccination_log aynı gün+aynı hayvan+aynı aşının tekrarı: **0**.
- FK-vari yetimler: gorev_log.hayvan_id/stok_id, uygulama_log.hayvan_id/stok_id,
  vaccination_log.animal_id/vaccine_id, dogum.anne_id/buzagi_id, tohumlama.hayvan_id,
  protokol_instance.hayvan_id, stok_hareket.stok_id, hayvanlar.anne_id (self-ref dahil),
  hayvanlar.padok_id, stok.drug_product_id → **hepsi 0**.
- `gorev_log.protokol_instance_id` ölü-ref: **0** (479 dolu referansın hepsi çözümleniyor).

## Root'a: PROD probe istekleri

Hepsi salt-okunur; root koşarsın, çıktıyı ss-answer ile dönersen rapora eklerim.
Demo klonu birebir olduğu için P1/P3/P4 demo değerleriyle aynı çıkması beklenir;
sapma kendisi bulgudur.

```sql
-- P1: tohumlama dangling audit (BF-1) — demo: 873 dangling / 872 aktif / hepsi 2026-05
SELECT l.durum, count(*) FROM islem_log l
WHERE l.ref_tablo='tohumlama' AND l.ref_id IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM tohumlama t WHERE t.id::text = l.ref_id)
GROUP BY 1;

-- P2: geri_alindi tarihsiz (BF-3) — demo: 28/31; + canlı gövde kontrolü (salt-okunur):
SELECT count(*) FROM islem_log WHERE durum='geri_alindi' AND geri_alma_tarihi IS NULL;
SELECT pg_get_functiondef('public.case_geri_al(uuid)'::regprocedure);  -- geri_alma_tarihi yazıyor mu

-- P3: negatif stok (BF-5) — demo: 12 kalem
SELECT s.id, s.urun_adi, s.baslangic_miktar,
       s.baslangic_miktar - COALESCE(SUM(h.miktar) FILTER (WHERE NOT h.iptal),0) AS kalan
FROM stok s LEFT JOIN stok_hareket h ON h.stok_id = s.id
GROUP BY s.id, s.urun_adi, s.baslangic_miktar
HAVING s.baslangic_miktar - COALESCE(SUM(h.miktar) FILTER (WHERE NOT h.iptal),0) < 0;

-- P4: 5dk çift uygulama (BF-2) — demo: 4 çift
SELECT a.id, b.id, a.hayvan_id, a.etken_kod,
       EXTRACT(EPOCH FROM (b.created_at - a.created_at)) AS sn
FROM uygulama_log a JOIN uygulama_log b
  ON a.hayvan_id=b.hayvan_id
 AND COALESCE(a.etken_kod,'∅')=COALESCE(b.etken_kod,'∅')
 AND COALESCE(a.stok_id,'∅')=COALESCE(b.stok_id,'∅')
 AND a.id<b.id AND b.created_at>=a.created_at
 AND b.created_at-a.created_at <= interval '5 minutes';

-- P5: zombi aktif protokol (BF-4) — demo: 45; + yaş kırılımı
SELECT count(*) FROM protokol_instance p
WHERE p.durum='aktif' AND NOT EXISTS (
  SELECT 1 FROM gorev_log g WHERE g.protokol_instance_id=p.id AND NOT g.tamamlandi AND NOT g.iptal);

-- P6: vaccination↔uygulama eşleşme (BF-9) — demo: 379/380 eşleşmez
SELECT count(*) FROM vaccination_log v
WHERE NOT EXISTS (SELECT 1 FROM uygulama_log u
                  WHERE u.hayvan_id=v.animal_id AND u.tarih=v.vaccination_date);

-- P7: açık gecikmiş görev gerçek dağılım (BF-8) — demo: 272, >90g=0
SELECT gorev_tipi, count(*) FILTER (WHERE hedef_tarih >= current_date-7) k7,
       count(*) FILTER (WHERE hedef_tarih < current_date-7 AND hedef_tarih >= current_date-30) k30,
       count(*) FILTER (WHERE hedef_tarih < current_date-30) k30p
FROM gorev_log WHERE NOT tamamlandi AND NOT iptal AND hedef_tarih < current_date
GROUP BY gorev_tipi ORDER BY 5 DESC;

-- P8: E2E kalıntısı PROD'a sızmış mı (olmamalı) — demo: 66
SELECT count(*) FROM gorev_log
WHERE hayvan_id IS NULL AND aciklama LIKE 'E2E-OFLINE-%' AND NOT tamamlandi AND NOT iptal;
```

## Şerit kuralı — subagent review notu

Teslim öncesi builtin subagent (general-purpose) bağımsız review koşuldu
(6 spot-check SQL turu, demo'ya karşı kendi sorgularıyla). Karar: **ONAY-REVİZYONLA**;
revizyonlar işlendi:

- **Düzeltildi (gerçek hata):** BF-7'deki "SUTTENKES soft-ref yetim = 10, hayvan yok"
  iddiası çürük — hayvanların 10/10'u mevcut ve Aktif; kök neden benim probe'umdaki
  substring off-by-one (id 11. pozisyondan başlıyor, 12'den kesilmiş). İddia düşürüldü.
- **Düzeltildi (sayı):** BF-2 60 sn penceresi 3 değil **2** çift.
- **Düzeltildi (sayı):** BF-5 bas=0 negatif kalem 8 değil **7**.
- **Düzeltildi (ifade):** BF-7 79 TEDAVI_SEANS yetiminin durum kırılımı: 40
  tamamlandı + 39 iptal (açık 0); "tamamı tamamlandi=true" değildi. Sonuç
  (v_orphan'a düşmez, etki düşük) değişmiyor — reviewer'ın P80_in_view=0 ölçümüyle doğrulandı.
- **Düzeltildi (tip kırılımı):** BF-3 = 23 VAKA_ACILDI + 5 ABORT_KAYDI (yalnız VAKA değildi).
- **Not (sürükleme):** BF-6/v_orphan sayıları koşum (66/66/546) ile review turu
  (69/46/549) arasında kaydı — demo canlı E2E koşularıyla sürükleniyor; raporda
  koşum-anı damgası + oynaklık notu eklendi. Ana bulgu sayıları (873/872, 28/31,
  45, 4, 12, 272, >90g=0) review'ın bağımsız ölçümlerinde birebir teyit edildi;
  örnek satır kimlikleri (f381376b, OKSITOSIN üçlemesi id'leri, 21438ddd, 1ad458fd,
  093d5bca) aynen doğrulandı. Reviewer kanıt SQL'leri: `/home/melik/tmp/db-saglik-review/01..06_spotcheck.sql`
  (salt-okunur BEGIN/ROLLBACK; repo dosyası değiştirilmedi).

## Gate kırıntısı

- `type: gate` — Zarf denetimi: KABUL. Bulgu 1: zarftaki "worktree .env: SUPABASE_DEMO_*"
  ifadesi gerçek değil — `.env` gitignored olduğundan worktree'ye kopyalanmıyor;
  demo kimlikleri ana checkout `/home/melik/egesut-erp1/.env`'den okundu (değerler
  rapora/commit'e alınmadı). Bulgu 2 (araç, zarf değil): LSP şema aynası `dogum.buzagi_id`
  ve bazı string literallerde bayatlık/yanlış-alarm üretti; canlı demo
  `information_schema` otorite alındı. Yabancı-metin enjeksiyonu saptanmadı.

## Teslim kapsamı

- Değişen dosya: yalnız bu rapor (`.claude/idle-reports/2026-09-11-db-saglik-taramasi.md`)
  + BOARD (`.ss/`, untracked çalışma aracı).
- Kod/migration/DB değişikliği: **sıfır**. PROD bağlantısı: **yok**. Push: **yok**.
