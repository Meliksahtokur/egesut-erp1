# K12 — `OVSYNC_SABLON_BELIRSIZ` kök neden raporu (demo ölçümlü)

> ROL: R-ARAŞTIRMA (salt-okunur kulvar) · 2026-09-25 · Kalem: **K12 / talimat 3d**
> Kanıt kanalı: demo psql (ref `vtzqjmazsvurxdeondmi` doğrulandı) — yalnız SELECT.
> Fix uygulanmaz bu kulvarda; dar fix I-DB kulvarına devredildi (`k12_fix_narrow = true`).

**Özet (tek cümle):** Sahibin düve-32'de aldığı `OVSYNC_SABLON_BELIRSIZ` hatası, tek Ovsync
şablonunun (`a152f7fe…`) **`protokol_ailesi` alanının NULL** olmasından doğuyor; guard tam 1 aktif
`protokol_ailesi='OVSYNC'` şablonu beklerken **0** buluyor. Değeri 2026-09-23 22:30'da S-3 backfill
DOLDURMUŞTU; 2026-09-24 13:25 demo klonu (TRUNCATE+COPY, satır tetikleyicisi tetiklenmez) prod'daki
NULL değeriyle sessizce ezip geri aldı.

---

## 1. Hatanın üretildiği guard (kod izi)

`start_first_service_protocol(p_gorev_id uuid)` gövdesinde (canlı demo gövdesi =
`supabase/migrations/20260925000001_ovsync_kisir_blok.sql:85` sürümü — KISIR + BEKLIYOR muafiyet
guard'ları gövdede mevcut [OBSERVED pg_proc: uzunluk 7950, üç imza işareti de t]):

```sql
-- 20260925000001_ovsync_kisir_blok.sql:172-180 (r32:745-754 ve 000006:507-516 aynı guard'ın kopyaları)
SELECT count(*), (array_agg(id))[1] INTO v_n, v_sablon_id
  FROM public.tedavi_sablonu
 WHERE protokol_ailesi = 'OVSYNC' AND aktif IS TRUE;
IF v_n <> 1 THEN
  RAISE EXCEPTION 'OVSYNC_SABLON_BELIRSIZ:%', jsonb_build_object(
    'gorev_id', p_gorev_id, 'aktif_ovsync_sablon_sayisi', v_n);
END IF;
```

Ardından ikinci guard `OVSYNC_HASTALIK_BELIRSIZ` (`sablon_hastalik_eslem` üzerinden tam 1 hastalık).
Sahibin ekran görüntüsündeki payload alan adı `aktif_ovsync_sablon_sayisi` bu RAISE'e birebir uyuyor.

**Sahibin patladığı görev** [OBSERVED demo]: `gorev_log` `4cd3d45a-bca8-4bc2-9544-49842bab6fcb` —
`OVSYNC_BASLAT`, küpe **32** (düve), hedef 2026-09-26 10:00, bugün `tamamlandi=t, iptal=t`
(hatadan sonra iptal edilmiş). Panel "Başlat" → `ovsyncBaslat()` → RPC `start_first_service_protocol`
→ yukarıdaki guard.

## 2. Demo ölçümleri (K12 kabul ölçütünün kendisi)

| Ölçüm | Sonuç | Sorgu özeti |
|---|---|---|
| Aktif ovsync şablon sayısı | **0** | `SELECT count(*) FROM tedavi_sablonu WHERE protokol_ailesi='OVSYNC' AND aktif IS TRUE` |
| `ad ILIKE '%ovsync%'` eşleşen şablon | **1** — `a152f7fe-e1d5-4de4-8157-344f1bffbaf7` "Sağmal inek: Ovsynch-56 + çift PGs", `aktif=t`, **`protokol_ailesi=NULL`**, `updated_at=2026-07-22` | tablo listesi |
| Şablonun eşlediği hastalık sayısı (2. guard) | **tam 1** — `c346e115-35ff-4430-92b8-874c505d857e` | `sablon_hastalik_eslem` count(DISTINCT disease_id) |
| Şablon kalemleri | 4 kalem (`tedavi_sablonu_kalem`) — zincir uygulanabilir | count |
| Özellik bayrağı | `ovsync_pg_kurallari_aktif = 1` (2026-09-23 22:39 set) | `protokol_ayar` |
| Diğer şablonlarda aile | 11 şablonun tamamında NULL (beklenen — protokol olmayanlar) | tablo listesi |

## 3. Kök neden zinciri (kanıt etiketli)

1. **[OBSERVED degisim_log]** `degisim_log`'da `tablo_adi='tedavi_sablonu'` için TEK kayıt:
   `2026-09-23 22:30:46 — islem=U — degisen_alanlar={protokol_ailesi}`. Bu, ovsync-pg serisinin
   (20260923000002) S-3 backfill'inin aileyi **başarıyla doldurduğunu** kanıtlar
   (`UPDATE … WHERE ad ILIKE '%ovsync%' AND protokol_ailesi IS NULL`).
2. **[OBSERVED demo_klon_log]** Demo 2026-09-24'te üç kez yeniden klonlandı: 13:18, 13:22, **13:25**
   (son, `satir_sayisi=13359`, durum OK). Klon `TRUNCATE + COPY` tabanlıdır (2BP01 fix'inin konusu
   buydu) — **satır-düzeyi AFTER trigger TRUNCATE'te tetiklenmez**, dolayısıyla `trg_degisim_log`
   ezilmeye dair iz yazmaz.
3. **[OBSERVED mevcut durum]** Bugün aile NULL ve 22:30'dan SONRA `tedavi_sablonu`'ya dair hiçbir
   U/D/I kaydı yok → değeri satır-tetikleyicisinden kaçan bir yol sildirmiş: klon. Klon kaynağı
   prod kopyası aile NULL getirmiş olmalı (prod'un kendi satırı 2026-09-24 13:25 anında henüz
   backfill'li değildi ya da hiç olmadı — **prod durumu BİLİNEMEZ, ölçüm yasak**).
4. **[CONFIRMED grep]** Cila serisi (20260925000001..8) `tedavi_sablonu`'ya yalnız guard SELECT'iyle
   dokunur (000001:174); S-3 backfill'i yeniden koşan hiçbir cila migration'ı yok. 20260923/24
   serisinin demo'da `schema_migrations` kaydı da yok (mimar A3) — yani "yeniden uygula" mekanizması
   bu tabloya işlemez.
5. **[OBSERVED]** Sonuç: guard `v_n=0` → `OVSYNC_SABLON_BELIRSIZ`. Hata adı yanıltıcı: gerçek durum
   "BELİRSİZ/çoklu" değil **"HİÇ/yok"** (0). Davranış yine de doğru (red gerekiyordu); yalnız etiket
   hatalı sınıflandırıyor.

**İkincil etki (not):** aynı NULL, `20260923000005_ovsync_vaka_kapanis.sql:622-657`'deki
`cases.protocol_family = t.protokol_ailesi` doldurma yolunu da besleyemiyor →
BUG-CILA-PROTOCOL-FAMILY-BOS'un (demo 0/12 aktif vaka) ikinci besleyicisi. K4'ün start-yolu
backfill'i tek başına yetmez; şablon ailesi de dolmadan kapanış-yolu aile yazamaz.

## 4. Dar fix önerisi — I-DB kulvarına (k12_fix_narrow = TRUE)

**Gerekçe (darlık/güvenlik):** tek satır, tek kolon, NULL→'OVSYNC'; S-3 backfill'in birebir yenisi;
2. guard ölçülmüş geçiyor (tam 1 hastalık); tüm tüketiciler bu değeri İSTİYOR (3 guard kopyası +
kapanış family doldurması). AKTIF_SENKRONIZASYON muafiyeti `cases.protocol_family` okur (hâlâ NULL) →
fix anında muafiyet davranışı değişmez.

```sql
-- I-DB: demo psql (ref doğrula: vtzqjmazsvurxdeondmi)
UPDATE public.tedavi_sablonu
   SET protokol_ailesi = 'OVSYNC'
 WHERE id = 'a152f7fe-e1d5-4de4-8157-344f1bffbaf7'
   AND ad ILIKE '%ovsync%'
   AND aktif IS TRUE
   AND protokol_ailesi IS NULL;
-- beklenen: UPDATE 1 (0 ise dur — koşullar değişmiş, yeniden ölç)
-- trg_degisim_log audit kaydını otomatik yazar (satır UPDATE'i tetikler)
```

**Apply-sonrası kabul (probe):**

```sql
SELECT count(*) FROM public.tedavi_sablonu WHERE protokol_ailesi='OVSYNC' AND aktif IS TRUE;
-- beklenen: 1  (K12 kabul: guard'ın okuduğu değer)
```

İsteğe bağlı uçtan-uca probe (riskli değil, atomic): sahibin 4cd3d45a görevi kapalı; açık
OVSYNC_BASLAT'lardan KISIR olmayan bir hayvanın göreviyle `start_first_service_protocol` çağrımı
artık guard'ı geçip zincir açmalı — ancak bu zincir AÇAR (vaka + 4 gün + TAI üretir). Demo'da
kabul edilebilir; istenmiyorsa yalnız sayı probe'u yeterli (K12 kabul ölçütü sayıyı soruyor).

## 5. Dayanıklılık önerileri (bu kulvarın raporu; uygulama I-DB/sahip kapısı)

1. **Idempotent S-3 backfill DO bloğu 000009'a (K1 dosyası) eklenmeli** — `v_eslesen=0 → WARNING`
   kalıbıyla aynısı. Böylece (a) prod uygulaması prod'un kendi satırını onarır/korumaya alır,
   (b) demo gelecekte yeniden klonlansa migration yeniden koşmasa bile elle aynı tek satır
   çalıştırılabilir stderr-uyarılı reçeteye dönüşür.
2. **Prod uygulama checklist maddesi (sahip kapısı):** prod apply sırasının sonunda
   `SELECT count(*) FROM tedavi_sablonu WHERE protokol_ailesi='OVSYNC' AND aktif` = 1 doğrulanmalı.
   Prod'da da 0 ise aynı hata prod'da da patlar (feature bayrağı prod'da açık — talimat 3d'nin
   prod yüzü).
3. **Gelecek klon sonrası kontrol:** her demo klonu sonrası (demo-test-hazirlik listesine madde)
   yukarıdaki sayı probe'u koşulmalı; 0 dönürürse tek satır backfill yeniden.
4. **Opsiyonel cila (bu turda YOK):** hata adının 0-durumunu ayırt etmesi
   (`OVSYNC_SABLON_YOK` vs `OVSYNC_SABLON_COKLU`) üç gövde kopyasında birden değişiklik ister —
   dar fix kapsamı dışı, borç kaydı olarak kalsın.

## 6. Kaynaklar

- Sahip talimatı 3d: `~/Masaüstü/EGESUT-ERP1 NOTLARI/yurutme-haritasi-ss-research-2026-09-23.md`
- Mimar raporu: `reports/2026-09-25-cila-dal-inceleme-mimar.md` §D (3d YOK), §E yan bulgu
- Guard gövdeleri: `supabase/migrations/20260925000001_ovsync_kisir_blok.sql:172`,
  `20260924000001_ovsync_pg_r32_acik_disi.sql:745`, `20260923000006_ilk_tohumlama_zinciri.sql:507`
- S-3 backfill: `supabase/migrations/20260923000002_ovsync_pg_sema.sql:369-390`
- Kapanış family doldurma: `supabase/migrations/20260923000005_ovsync_vaka_kapanis.sql:622-657`
