⟦ss-sub model=sonnet effort=medium rol=ss-worker iş=ovsync-tren N4 UI-B öncesi veri sözleşmesi + test tabanı + toast ölçümü (salt-okuma)⟧
sonuc: TAMAM
BOŞLUK: 5 (+2 kısmi türetim) · fail eden test: 4 (hepsi main'de de kırmızı) · etiket-tazelik rc=1 (main'de de rc=1, aynı liste)
BOYUT: bütçe yok (salt-okuma ölçüm) · gerçek 0 üretim satırı · bütçe içinde
Brief denetimi: bulgu yok (tek düzeltme: brief'in "tests/unit/ileri-gebe-duve-siralama.test.js:209 `?v=` sayısını sabitliyor" varsayımı yarım — bkz. §4).

Notlar
- Yol kısaltması: `M1`..`M8` = `~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100001..008_*.sql` (M1 dogum_pg_hatirlatma, M2 cekirdek, M3 gorev_dogumu, M4 baslatma, M5 kilit, M6 asama, M7 toptan, M8 ayar_goc). `UA1` = `~/.herdr/worktrees/egesut-erp1/ovsync-tren/js/ovsync-tren.js`. `PLAN` = docs/plans/2026-11-09-ovsync-tren/PLAN.md.
- Okuma anı: aynı worktree'de D9 yürütücüsü M2/M4/M5/M8 dosyalarını düzenliyor (git diff: M2 +4, M4 +9/-2, M5 +3/-1, M8 +5/-2). Satır numaraları okuma anına göredir, D9 sonrası ±10 kayabilir; D9 brief'i RPC imza/dönüşünü değiştirmediğini söylüyor (D9-brief RD9-6) — bu raporun dönüş şemaları ona dayanıyor (INFERRED).
- Etiketler: CONFIRMED = kaynakta satır okundu; OBSERVED = komut koştum; INFERRED = çıkarım; UNKNOWN = ölçülmedi.

## Sözleşme tablosu

### A) RPC imza + dönüş + hata kodları (gövdeden)

Ortak: tüm tarihler TR günü (`(now() AT TIME ZONE 'Europe/Istanbul')::date`, M4:52, M7:72). Bayrak (`ovsync_tren_aktif`+`ovsync_pg_kurallari_aktif`) kapalıyken: listele/onizle `{aktif:false}`; yazan RPC'ler `OVSYNC_TREN_KAPALI:{rpc,…}` (M6:271/350/419, M7:153/257, M8:41). Hata metni biçimi `KOD:{json}`; `RAISE EXCEPTION 'KOD:%', jsonb::text` (UA1 `ovsyncTrenHataMetni` bu biçimi çözer). Anahtar tiplerde `date` alanları ISO `YYYY-MM-DD` string, `timestamptz` ISO string.

1. **`ovsync_tren_onizle(p_hayvan_id text DEFAULT NULL)`** — M4:540-607, STABLE SECURITY DEFINER. CONFIRMED.
   - Kapalı: `{ok:true, aktif:false}` (M4:559).
   - Açık: `{ok:true, aktif:true, bugun:date, tren_gunu:date, tren_bugun_mu:bool, uye_sayisi:int, gorev:{id:uuid,hedef_tarih:date}|null, gorev_hedef_eski:bool, kupe_no:text|null, kural_tarihi:date|null, uye_kupeler:[text]}` (M4:600-605).
   - `kupe_no`/`kural_tarihi` yalnız `p_hayvan_id` verilince dolu (M4:563-572); `p_hayvan_id` NULL → ikisi null. `gorev` hayvanın en geç açık OVSYNC_BASLAT'ı, yoksa null.
   - `tren_gunu`: görev hedefi geçmiş ya da ritim dışıysa R9 formülü `_ovsync_tren_gunu_ic(GREATEST(kural, hedef), capa, öne_çekme, bugün)` ve `gorev_hedef_eski:true` (M4:574-576); aksi `COALESCE(görev hedefi, _ic(bugün, capa, 0, bugün))` (M4:578) → görevsiz hayvanda kural YOK SAYILIR (ilk ritim günü ≥ bugün).
   - `uye_sayisi`/`uye_kupeler`: (aktif OVSYNC vakası etiket=tren) ∪ (hedefi tren olan açık OVSYNC_BASLAT), **sorulan hayvan hariç**, küpe uzunluk+metin sırası (M4:581-598).
   - Hata: `OVSYNC_TREN_AYAR` (ayar bozuk, M2:41-73).

2. **`ovsync_tren_listele()`** — M7:65-124. CONFIRMED.
   - Kapalı: `{ok,aktif:false,capa:null,bugun,trenler:[],bagimsizlar:[],ileri_sayisi:0}` (M7:81).
   - Açık: `{ok, aktif:true, capa:date, bugun:date, trenler:[{tren_gunu:date, ritim_disi:bool, uyeler:[UYE]}], bagimsizlar:[UYE], ileri_sayisi:int}` (M7:121-122). Trenler `tren_gunu` artan.
   - `UYE` (vaka, M7:56-58): `{hayvan_id, kupe_no, case_id:uuid, gorev_id:null, asama:0|1|2|null, ovsync_tren:date|null, sonraki_is:{tarih,saat,tur:'GNRH1'|'PG1'|'PG2'|'GNRH2'|'TAI'}|null, pg_pay:int|null (yalnız aşama 1: tolerans − kayma, ham/negatif olabilir), pg1_zaman:timestamptz|null (gün#2 TÜM seansları uygulandıysa en geç an), ritim_disi_neden:text|null}`.
   - `UYE` (görev, M7:90-94): `{hayvan_id, kupe_no, case_id:null, gorev_id:uuid, asama:0, ovsync_tren:=hedef_tarih, pg_pay:null, pg1_zaman:null, sonraki_is:{tarih,saat,tur:'GNRH1'}, ritim_disi_neden}`.
   - Görev üyesi `hedef_tarih <= bugün+28` (alt sınır YOK — gecikmiş görevler listelenir, M7:97); ötesi `ileri_sayisi` (M7:117-119). `bagimsizlar` = `ovsync_tren IS NULL` aktif OVSYNC vakalar (M7:113-115).
   - Hata: `OVSYNC_TREN_AYAR`.

3. **`ovsync_tren_ertele_onizle(p_tarih date, p_n int)`** — M7:249-261 → `{ok:true} || plan` (plan = `_ovsync_tren_ertele_plan`, M7:136-245). CONFIRMED.
   - plan: `{tren:date, yeni_tren:date(=tren+n), uyeler:[{hayvan_id,kupe_no,case_id|null,gorev_id|null,asama,ovsync_tren,pg_pay,pg1_zaman, sonuc:'KAYAR'|'BASTAN'|'SECIM'|null, yeni_tarih:date|null}], ileri_gorevler:[{gorev_id,hayvan_id,eski,yeni, kural_yok?:true}], ileri_vakalar:[{case_id,hayvan_id,kupe_no,eski,yeni}], tren_sayisi:int, dokunulmaz:{bagimsiz:int, ritim_disi:int}}` (M7:242-244). `sonraki_is`/`ritim_disi_neden` plan üyesinde YOK (M7:190 `- 'sonraki_is' - '_kayma'`).
   - `sonuc` kuralı (M7:199-202): aşama 0 → `BASTAN` (ovsync_tren < X, yani X−7 treninin gecikmiş GnRH1'i — RL-17) yoksa `KAYAR`; aşama 1 → `n ≤ pg_pay` ise `KAYAR` yoksa `BASTAN`; aşama 2 → `SECIM`; **aşama NULL → `sonuc:null`** (sunucu bu üyeyi ertelemede düşürür, M7:312-313).
   - `yeni_tarih`: KAYAR görev = X+n, vaka aşama 0 = gün#1+n, aşama 1 = gün#2+n; BASTAN = yeni tren (RL-15); SECIM/null → null (M7:205-212).
   - Hatalar: `OVSYNC_TREN_KAPALI:{rpc:'ovsync_tren_ertele_onizle',tarih}` (M7:257), `OVSYNC_TREN_N_GECERSIZ:{gun,min:1,max:7}` (M7:160), `GECMIS_TARIH:{tarih,bugun}` (M7:163; `OVSYNC_` öneki YOK), `OVSYNC_TREN_GUNU_DEGIL:{tarih,capa}` (M7:166) ve `OVSYNC_TREN_GUNU_DEGIL:{tarih,sebep:'ONCEKI_TREN_VAR',ilk_tren}` (M7:178, RL-16), `OVSYNC_TREN_BOS:{tarih}` (M7:214), `OVSYNC_TREN_AYAR`.

4. **`ovsync_tren_ertele(p_tarih date, p_n int, p_secimler jsonb DEFAULT '{}')`** — M7:267-376, SECURITY DEFINER. CONFIRMED.
   - Dönüş: `{ok, tren, yeni_tren, islenen:[{hayvan_id,kupe_no,case_id,gorev_id,asama,sonuc,islem:'KAYAR'|'BASTAN'|'PG48',yeni_tarih,detay:<alt RPC dönüşü>}], ileri_gorevler:[…], ileri_vakalar:[…]}` (M7:373-374). `detay` BASTAN'da `ovsync_bastan_baslat` dönüşü (iptal_tai[] dahil), PG48'de `ovsync_pg48_tohumla` dönüşü.
   - `p_secimler` = `{ "<case_id>": "PG48"|"BASTAN" }` (M7:292, 304).
   - Hatalar: önizlemedekiler + `OVSYNC_TREN_SECIM_EKSIK:{eksik:[case_id]}` (M7:294) + `OVSYNC_TREN_ERTELE_DUSTU:{tren,n,dusenler:[{hayvan_id,kupe_no,case_id?,gorev_id?,sebep:<SQLERRM ham>,oneri?:'BASTAN_BASLAT_YA_DA_SEANS_ISARETLE'}]}` (M7:332-361). Not: `sebep` içinde ham `KOD:{json}` metni var (M7:333).
   - Kısmi başarı YOK (DUSTU hepsini geri sarar; çapa dahil).

5. **`ovsync_hayvan_ertele(p_hayvan_id text, p_gun int)`** — M6:251-329. CONFIRMED.
   - Dönüş: `{ok:true, asama:0|1|2, sonuc:'SONRAKI_TREN'|'KAYDI', yeni_tarih:date}` (M6:294, 325-327). Aşama 0 trende → `SONRAKI_TREN` = `_ic(D0+p_gun, capa, 0, bugün)` (M6:316); aşama 0 bağımsız / aşama 1 → `KAYDI` (p_gun serbest 1-7 / aşama 1'de tolerans içi).
   - Hatalar: `OVSYNC_TREN_KAPALI` (M6:271), `OVSYNC_TREN_N_GECERSIZ` (M6:275), `OVSYNC_VAKA_YOK:{hayvan_id}` (M6:290), `OVSYNC_ASAMA_BELIRSIZ:{case_id,oneri:'BASTAN_BASLAT'}` (M6:302), `OVSYNC_ASAMA2_ERTELEME_YOK:{case_id,secenekler:['PG48','BASTAN']}` (M6:304), `OVSYNC_ASAMA1_TOLERANS:{tolerans,mevcut_kayma,istenen,oneri:'BASTAN_BASLAT',case_id}` (M6:308).

6. **`ovsync_pg48_tohumla(p_case_id uuid)`** — M6:333-392. Dönüş `{ok, tai_gorev_id, tai_hedef:date, kapanan_seans:int}` (M6:390). Hatalar: `OVSYNC_TREN_KAPALI` (:350), `OVSYNC_VAKA_YOK:{case_id}` (:357), `OVSYNC_ASAMA2_DEGIL:{case_id,asama}` (:362), `OVSYNC_PG48_TAI_YOK:{case_id,hayvan_id}` (:369), `OVSYNC_PG48_GECMIS:{case_id,tai_gorev_id,tai_hedef,tai_saat}` (:373), `OVSYNC_PG48_SEANS_KAPANMADI` (:385). CONFIRMED.

7. **`ovsync_bastan_baslat(p_case_id uuid, p_bagimsiz boolean DEFAULT false, p_not text DEFAULT NULL, p_hedef date DEFAULT NULL)`** — M6:399-475 (PLAN R11 imzası 3 parametre; gerçek 4, `p_hedef` D7 tur 2/RL-15, toptan içindir). Dönüş `{ok, kapanan_case_id, yeni_gorev_id, hedef_tarih:date, basladi:bool, yeni_case_id:uuid|null, iptal_tai:[uuid]}` (M6:472-473). Hedef = tren günü; bağımsız ya da hedef=bugün → aynı işlemde başlar. Hatalar: `OVSYNC_TREN_KAPALI` (:419), `OVSYNC_VAKA_YOK` (:426), `OVSYNC_BASTAN_BASLATILAMADI:{case_id,yeniden_not|yeni_gorev_id,…}` (:432, :451), `OVSYNC_BASTAN_HEDEF_GECERSIZ:{case_id,hedef,en_erken,bagimsiz}` (:437). CONFIRMED. Yeni görevin hedefi `_ovsync_tren_gunu(kural)` (M3:50) — kural-tabanlı; bkz. BOŞLUK-4.

8. **`ovsync_tren_yeniden_hedefle(p_kuru boolean DEFAULT true, p_capa date DEFAULT NULL)`** — M8:19-105. Dönüş `{ok, kuru, capa, gorevler:[{gorev_id,hayvan_id,kupe_no,eski,yeni:date|null,durum:'KURAL_YOK'|'AYNI'|'TASINIR'}], uyelik:[{case_id,hayvan_id,tren}], belirsiz_asama:[{case_id,hayvan_id,kupe_no}], belirsiz_sayisi:int}` (M8:102-103). Kuru bayraktan bağımsız; `p_capa` kuru önizlemede ayardan farklı olabilir, kuru değilken farklıysa `OVSYNC_TREN_AYAR:{…,sebep:'AYARDAN_FARKLI'}` (M8:46-49). Hedef<bugün görevler listede yok (M8:64). Hatalar: `OVSYNC_TREN_KAPALI` (kuru değil, M8:41), `OVSYNC_TREN_AYAR`. CONFIRMED.

9. **`ovsync_tren_ayar_guncelle(p_aktif boolean, p_capa date)`** — M8:112-164. Dönüş `{ok, aktif:bool, capa:date|null, yeniden_hedef:<#8 dönüşü>|null}` (M8:162). Hatalar: `OVSYNC_TREN_AYAR:{anahtar,deger,sebep:'EKSIK'|'ARALIK_DISI'|'TAMSAYI_DEGIL'|'TARIH_GECERSIZ'|'AYARDAN_FARKLI'}` (M8:128, 137, 141; M2:65). CONFIRMED.

10. **`dogum_sonrasi_pg_hatirlatma()`** — M1:193-216, SQL STABLE. Dönüş `{ok:true, aktif:bool (= dogum_sonrasi_pg_gorev_aktif≠1), satirlar:[{hayvan_id,kupe_no,dogum_tarihi:date,gun:int(2|25)}]}`; satırlar `gun,kupe_no` sıralı, hayvan başına tek satır (ikiz tek). ACL yalnız `authenticated` (M1:222). CONFIRMED.

11. **`start_first_service_protocol(p_gorev_id uuid, p_takip_onay boolean DEFAULT false, p_bagimsiz boolean DEFAULT false)`** — M4:38-321. Dönüş: normal `{ok, case_id, tohumlama_gorev_id, baslangic:date, d58_iptal:[uuid], pg_gorev_iptal:[uuid], ovsync_tren:date|null}` (M4:316-319); **yeni kol** `{ok, basladi:false, gorev_id, yeniden_hedef:date, ovsync_tren:null}` (M4:185 — TREN yolunda hedefi geçmiş/ritim dışı görev ilk trene taşınır, başlamaz); zaten kapalı `{ok,zaten:true,…}` (M4:90); muaf `{ok,atlandi:<neden>,gorev_id}` (M4:169). Hatalar: `OVSYNC_ERKEN:{gorev_id,hedef_tarih,kalan_gun,acilisa_kalan_gun}` (:106), `TAKIP_ACIK:{muayene_tarihi,muayene_saat}` (:203), `OVSYNC_SABLON_BELIRSIZ` (:219), `OVSYNC_HASTALIK_BELIRSIZ` (:227), `OVSYNC_VAKA_ACILAMADI` (:234), `OVSYNC_SABLON_UYGULANAMADI` (:249), `OVSYNC_TREN_UYELIK_YOK:{gorev_id,case_id,d0}` (:257), `OVSYNC_TAI_OLUSMADI` (:265), `GOREV_BULUNAMADI`, `GOREV_TIPI_UYUMSUZ`, `OZELLIK_KAPALI`. Bayrak kapalı → `ovsync_tren:null`, `p_bagimsiz` yok sayılır (M4:95). CONFIRMED.

12. **`seans_tamamla(p_seans_admin_id uuid, p_uygulanmadi bool DEFAULT false, p_not text DEFAULT NULL, p_pg_onay bool DEFAULT false, p_pg_gerekce text DEFAULT NULL, p_takip_onay bool DEFAULT false)`** — M6:28-247. Dönüş `{ok:true, seans_done:true, gun_tamam:bool}` + (yalnız PG1 geç tamamlanıp `gecikme > tolerans` ise) `ovsync_uyari:{kod:'PG1_TOLERANS_ASILDI', gecikme_gun:int, oneri:'BASTAN_BASLAT', case_id:uuid, kupe_no:text, planlanan_tarih:date, tamamlanan_tarih:date, bastan_tren_gunu:date}` (M6:221-224, 244-245). Yalnız tren açık + aktif OVSYNC vaka (M6:172-173). Hata/ret biçimleri mevcut (`{ok:false,mesaj,race}` M6:76-79). Not: `bastan_tren_gunu = _ovsync_tren_gunu(bugün)` kural YOK SAYAR (BOŞLUK-4). CONFIRMED.

13. **Yan etkili/UI'ı ilgilendiren diğer dönüşler** (kilit + göç): `gorev_ertele`/`tohumlama_gorev_ertele` → `OVSYNC_TREN_EKRANI:{gorev_id,hayvan_id,tren_gunu|null}` (M2:226, çağrı M5:83/212); `vaka_kalan_gunleri_kaydir` → `OVSYNC_TREN_EKRANI:{case_id,hayvan_id,tren_gunu|null}` (M2:243, çağrı M5:311) ve başarıda `ovsync_tren += p_gun` (M5:396-397); `vaka_kalan_gunleri_kaydir_coklu` → `…,ovsync_atlanan:[{gorev_id,case_id,hayvan_id,kupe_no|null}]` (M5:547-548, 626-633); `ovsync_hastalik_gunu_ekle` → `{ok,gun_id,mevcut,ertelenen,ilac,tren_ayrildi:bool}` (M5:737-739); `tohumlama_bos_ve_devam(p_secim:'OVSYNC')` → `{ok,secim:'OVSYNC',tohumlama_id,islem_id,ovsync_gorev_id:uuid,takip_kapatildi}` (M3:913-917) + hatalar `OVSYNC_SECIM_KISIR`, `OVSYNC_SECIM_TABAN_YOK`, `OVSYNC_SECIM_ERKEN:{kural_gun,kalan_gun}`, `OVSYNC_GOREV_ACILAMADI:{hayvan_id,sebep:'HEDEF_YOK'|'KURAMADI'}` (M3:874-906); `protokol_iptal(...)` → `{ok,case_id,kapanan_*,yeni_gorev_id,yeniden_not}` (M3:484-492). CONFIRMED.

### B) Mockup ekranı → bilgi/düğme → kaynak → tanım satırı

Sütun: bilgi/düğme | kaynak (RPC.alan ya da UA1 fn) | gövdede tanım.

**1a K8 "Trene bin" (01a)**
| bilgi | kaynak | tanım |
|---|---|---|
| "▶ Ovsync başlat — 212" | `ovsync_tren_onizle.kupe_no` → UA1 `ovsyncTrenSoruHtml` | M4:605 |
| "Kural günü Sal 17 Kas" | `onizle.kural_tarihi` | M4:571, 605 |
| "tren her Perşembe" | `onizle.tren_gunu` hafta günü (UA1 `_ovtHaftaGunu`) | M4:601 |
| "Trene bin — Per 19 Kas (4 hayvan)" | `onizle.tren_gunu`, `onizle.uye_sayisi` (sorulan hariç) | M4:601-602, 598 |
| "Bu trende: 36 · 38 · 169 · 5708" | `onizle.uye_kupeler` | M4:595, 605 |
| "(3 gün sonra)" | `tren_gunu − bugun` (UA1 `_ovtFark`) | M4:601 |
| "Bağımsız başlat — bugün" / "Bugün Pzt 16 Kas" | `onizle.bugun` | M4:601 |
| "Vazgeç/Başlat" | UA1 `ovsyncTrenSor` → sonra `start_first_service_protocol(p_gorev_id, p_bagimsiz)` / `tedavi_sablon_uygula(p_baslangic_tarihi)` | UA1:184-185; M4:38, 324 |
**1b R4 tren=bugün**: "🚆 Bugün tren günü — başlat" → `onizle.tren_bugun_mu` / UA1 `ovsyncTrenSoruGerekli` (false → modalsız) (M4:602; UA1:147-151). Toast "212 trene bindi · Per 19 Kas · 5 hayvan": tren günü `start_first_service_protocol.ovsync_tren` (M4:319), "5" = `onizle.uye_sayisi+1` (türetim; start dönüşünde sayı yok → **KISMİ-1**).

**2a Ovsync takip ekranı (02a)**
| bilgi | kaynak | tanım |
|---|---|---|
| "🚆 Ovsync treni: açık · her Perşembe" | `ovsync_tren_listele.aktif`, `.capa` hafta günü | M7:121-122 |
| "Tren ayarı ›" | UA1'de fonksiyon YOK (UB3 ui.js) → panel 06 | — |
| "S1 · 9 vaka · 3 tren · 2 bağımsız" | S1 satır sayısı (mevcut `renderOvsyncSayfa`), `trenler.length`, `bagimsizlar.length` | M7:121; ui.js:1984 |
| "Tren · Per 19 Kas · 4 hayvan" | `trenler[].tren_gunu`, `uyeler.length` → UA1 `ovsyncTrenBaslikHtml` | UA1:268-282 |
| "· bugün: PG günü" | `tren_gunu` vs `bugun` gün farkı 0/7/8/9/10 (UA1 `_OVT_TREN_IS`) | UA1:23, 239; M7:121 |
| "Tren gününü ertele…" | `trenler[].ritim_disi` + UA1 `ovsyncToptanTarih` → `ovsyncToptanAc(X)` (UB3) | M7:109; UA1:251 |
| kart satırları (36, Sağmal, Doğum+51, 1-4. uygulama, TAI, 2/4 uygulandı, Gün detayı) | MEVCUT `ovsync_takip_listele` S1 satırı (`kupe_no,grup,taban_turu,gunler,tai,sonraki_gun`) | 20260929000001:371-380, 351-370; ui.js:1088-1131 |
| "PG yapıldı · erteleme yok:" + "PG1 + 48 s'te tohumla" / "Baştan başlat" | `UYE.asama==2` → UA1 `ovsyncAsamaAksiyonHtml` PG48/BASTAN → `ovsync_pg48_tohumla(case)` / `ovsync_bastan_baslat(case)` | M7:56-58; M6:333, 399 |
| "PG bugün:" + "PG'yi ertele · en çok +1 gün" | `asama==1`, `sonraki_is.tarih`, `pg_pay` → `ovsync_hayvan_ertele(hayvan, p_gun≤pg_pay)` | M7:43-44, 58; M6:251 |
| "Başlamadı:" + "Sonraki trene aktar → Per 3 Ara" | `asama==0` → `ovsync_hayvan_ertele(hayvan,1)` (sonuç `SONRAKI_TREN`) | M6:292-294, 312-317 |
| "1. uygulama 1 gün geç (20.11)" | MEVCUT S1 `sapma.fiili_baslangic/kayma_gun` (`_ovsyncSapmaRozeti`) | 20260929000001:381-390; ui.js:794-808 |

**2b ritim dışı + bağımsız (02b)**
| bilgi | kaynak | tanım |
|---|---|---|
| "Tren · Cum 20 Kas · 1 hayvan · ritim dışı" | `trenler[].ritim_disi=true` | M7:109 |
| "(PG +1 gün)" parantezi | `UYE.ritim_disi_neden` = "PG +1 gün" (UA1 KULLANMIYOR, sabit metin) | M7:100-103 |
| "PG payı doldu (1 gün kullanıldı):" + "Baştan başlat → trene bin" | `pg_pay ≤ 0` → BASTAN; "1 gün kullanıldı" = `tolerans(IDB protokol_ayar) − pg_pay` (türetim) | M7:58; M2:70-71 |
| "Bağımsız · 2 hayvan" + açıklama | `bagimsizlar.length` | M7:113-115 |
| 1203 "bağımsız başlatıldı (24.11)", 88 "hastalık günü 25.11 (İnaktif Ovaryum) → bağımsız" | **BOŞLUK-3** | — |
| "PG 01.12:" bağımsız aşama 1 | `sonraki_is.tarih` | M7:43 |

**3a/3b toptan erteleme (03a, 03b)**
| bilgi | kaynak | tanım |
|---|---|---|
| "Tren gününü ertele — Per 26 Kas" | `ovsyncToptanTarih(tren)` = X | UA1:251 |
| "Bugünün Ovsync işleri: 6 hayvan, 2 tren" | `plan.uyeler.length`, `plan.tren_sayisi` (UA1 trenSet'ten türetir) | M7:243 |
| +1…+7 çipleri | `p_n` 1-7 (`OVSYNC_TREN_N_GECERSIZ`) | M7:159-161 |
| grup başlığı "Tren · Per 19 Kas — bugün PG günü" | `uyeler[].ovsync_tren` + `_ovtTrenBugunIs` | M7:56-57; UA1:386-391 |
| "aşama 1 · PG bugündü" / "aşama 2 · PG yapıldı 09:40" | `asama`, `pg1_zaman` (UTC→TR saat; UA1 saat KULLANMIYOR) | M7:52-58 |
| "kayar → Cum 27 Kas" | `sonuc=KAYAR`, `yeni_tarih` | M7:199-212 |
| "PG 1 gün ertelenir (pay 1 gün)" | `pg_pay` | M7:58 |
| "baştan başlar → Cmt 28 Kas" + "PG en çok 1 gün ertelenir; +2 aşıyor" | `sonuc=BASTAN`, `yeni_tarih`, `pg_pay` | M7:199-212 |
| "1. uygulama 1 gün geç yapıldı (20.11); PG için 2 gün pay var" | `pg_pay` ✔; "1 gün geç (20.11)" **BOŞLUK-6** (planda GnRH1 gerçek günü yok; S1 `sapma` ile hayvan_id eşlemesi mümkün) | — |
| "seçim gerekli" + (a)/(b) radyo | `sonuc=SECIM`; seçim `p_secimler[case_id]` | M7:202, 292 |
| "(a) PG1 + 48 s'te tohumla — Cmt 28 Kas 09:40" | **BOŞLUK-1** | — |
| "(b) Baştan başlat → Cum 27 Kas treni" | `plan.yeni_tren` (BASTAN yeni tren = X+n) | M7:208-210 |
| "🔁 Ritim kalıcı kayar: her Cuma (sonraki: Cum 4 Ara)" | `plan.yeni_tren` (UA1 türetir) | M7:180; UA1:400-403 |
| "Dokunulmaz: 2 bağımsız (1203, 88) · 1 ritim dışı (77)" | `plan.dokunulmaz` yalnız SAYI; küpeler **BOŞLUK-2** | M7:234-240 |
| "N hayvan için (a) ya da (b) seçin" / Onayla pasif | UA1 `ovsyncToptanOnayAcikMi` (fail-closed) | UA1:322-331 |
| "Onayla (6 hayvan)" → `ovsync_tren_ertele(X,n,secimler)` | M7:267 | — |
| "Tek işlem: biri işlenemezse hiçbiri değişmez, düşen hayvan ve nedeni yazılır" | `OVSYNC_TREN_ERTELE_DUSTU.dusenler[]` | M7:360-361 |

**04a/04b vaka kartı**
| bilgi | kaynak | tanım |
|---|---|---|
| "🚆 Tren Per 19 Kas · aşama 2" chip | `cases.ovsync_tren` (IDB; `select *`, INFERRED) + aşama: yalnız `ovsync_tren_listele` (hayvan_id/case_id ile bul) → **KISMİ-2** (çevrimdışı aşama yok) | M2:29; M7:56 |
| "PG yapıldı (26.11 09:40)" | `UYE.pg1_zaman` | M7:52-55 |
| "PG1 + 48 s'te tohumla — Cmt 28 Kas 09:40" | **BOŞLUK-1** | — |
| "Baştan başlat → trene bin (Per 3 Ara)" / "→ bugünkü tren" | **BOŞLUK-4** | — |
| "Kalan Günleri Kaydır" gizli (aşama 2) | `UYE.asama==2` (lookup) | M6:304 (sunucu da reddeder) |
| 04b "PG'yi Ertele — 169", "+1 → Cum 27 Kas" | gün#2 `treatment_date` (IDB) + 1; çağrı `ovsync_hayvan_ertele(hayvan,1)` (`vaka_kalan_gunleri_kaydir` doğrudan çağrısı K10 ile `OVSYNC_TREN_EKRANI`) | M6:319-320; M5:311 |
| "Bu hayvan Per 19 Kas treninden ayrılır" | statik; etiket `+= p_gun` ⇒ ritim dışı | M5:396-397 |

**05a/05b görevler (K10)**
| bilgi | kaynak | tanım |
|---|---|---|
| "Ovsync ekranında düzenle →" (36 TAI, 5708 gün) vs "🗓️ Ertele" (ILAC, Ovsync-dışı TAI) | UA1 `ovsyncTrenGorevMu(t,{hayvanIdSet,gunIdSet})` ↔ SQL `_ovsync_gorev_mu` | UA1:427-448; M2:180-205 (UA1 fark F8) |
| 5b "⏭ 2 Ovsync görevi atlandı (36, 5708)" | `vaka_kalan_gunleri_kaydir_coklu.ovsync_atlanan[].kupe_no` → UA1 `ovsyncCokluAtlananNot` | M5:547-548, 633; UA1:476-484 |
| "Ovsync ekranı →" | UA1 `ovsyncEkranindaDuzenle(null)` | UA1:455-458 |

**06 tren ayarı**
| bilgi | kaynak | tanım |
|---|---|---|
| Kapalı/Açık düğmesi | `listele.aktif` / IDB `protokol_ayar.ovsync_tren_aktif`; kaydet `ovsync_tren_ayar_guncelle(p_aktif,p_capa)` | M8:112 |
| "Tren günü 04.12.2026 (önceki: 03.12.2026)" | yeni = seçici; önceki = `listele.capa` | M7:121 |
| "→ her Cuma" | yeni çapa hafta günü | — |
| "Öne çekme en çok 2 gün · PG toleransı 1 gün" | IDB `protokol_ayar` (`ovsync_tren_one_cekme_gun`, `ovsync_pg_erteleme_tolerans_gun`); RPC'de yok (TABLES içinde protokol_ayar: api.js:34) | M2:21-24 |
| önizleme satırları "905 başlatma görevi Per 3 Ara → Cum 4 Ara" | `ovsync_tren_yeniden_hedefle(true,yeni_capa).gorevler[]` (`kupe_no`,`eski`,`yeni`,`durum=TASINIR`) | M8:53-56 |
| "kural günü bulunamadı — dokunulmaz" | `durum='KURAL_YOK'` | M8:55 |
| "Başlamış Ovsync'ler (9 vaka) ve bağımsızlar değişmez" | `listele` toplam üye+bağımsız (türetim) | M7:121 |
| "Kaydet (3 görev)" | `durum='TASINIR'` sayısı | M8:55 |
| (mockup'ta YOK, veri var) | `belirsiz_asama[]`/`belirsiz_sayisi` (R6-EK), `uyelik[]` | M8:78-83, 103 |

**07a 🔔 hatırlatma**: "💉 Doğum sonrası PG hatırlatma (3)", "1840 · doğumun 2. günü", "doğum Sal 24 Kas" → `dogum_sonrasi_pg_hatirlatma().satirlar[].{kupe_no,gun,dogum_tarihi}` (M1:213-215) → UA1 `dogumPgHatirlatmaHtml(satirlar)` (UA1:559-571; çağıran `.satirlar` geçmeli). Rozet 5 = 2 + 3: `_rozetTopla` + `satirlar.length` (PLAN UB5). `aktif:false` iken satırlar boş (M1:200,207).

**07b geç tamamlama**: "PG1 2 gün geç" → `ovsync_uyari.gecikme_gun`; "169 ·" → `kupe_no`; "PG planı Per 26 Kas idi, Cmt 28 Kas'ta yapıldı" → `planlanan_tarih`, `tamamlanan_tarih`; "(Per 3 Ara)" → `bastan_tren_gunu`; "PG en çok 1 gün geç kalabilir" → IDB tolerans; "🔁 Baştan başlat → trene bin" → UA1 `BASTAN` `data-case=case_id` → `ovsync_bastan_baslat`; "Devam et" → kapat. Hepsi M6:221-224. UA1 yalnız `kod,gecikme_gun,kupe_no,case_id` kullanıyor (UA1 fark F6).

### C) BOŞLUK listesi (kaynağı OLMAYAN bilgi)
- **BOŞLUK-1** — "PG1 + 48 s'te tohumla — Cmt 28 Kas 09:40" (3a/3b (a) satırı, 04a): önizlemede PG+48 TAI hedef günü/saati döndüren alan yok. `pg1_zaman + 48 saat` istemci türetimi gerçek PG_TOHUMLAMA görevinin hedefiyle (R12, `ovsync_pg48_tohumla` kullanır M6:364-367) örtüşmeyebilir; gerçek `tai_hedef` ancak uygulandıktan sonra döner (M6:390). Seçenek: türetilmiş tahmini "≈" ile göster ya da mockup'tan saat/tarih kaldır.
- **BOŞLUK-2** — "Dokunulmaz: 2 bağımsız (1203, 88) · 1 ritim dışı (77)" (3a/3b): `plan.dokunulmaz` yalnız `{bagimsiz:int, ritim_disi:int}` (M7:234-236); küpe listesi yok. Seçenek: sayı ("2 bağımsız · 1 ritim dışı") ya da D7'ye küpe dizisi (RPC değişimi).
- **BOŞLUK-3** — 02b bağımsız kartı alt satırları: "bağımsız başlatıldı (24.11)" ve "hastalık günü 25.11 (İnaktif Ovaryum) → bağımsız": `bagimsizlar[]` üyesinde neden/tarih/hastalık adı yok (M7:56-58); NULL etiket hem "eski (bayrak öncesi)" hem K8/K9 bağımsızı (D9 `ovsync_bagimsiz` ayrımı UI'a dönmüyor, D9-brief RD9-4/RD9-6). İstemci türetimi (IDB `treatment_days.disease_id`/`diseases.name`, `cases.start_date`) mümkün ama RPC kaynağı değil.
- **BOŞLUK-4** — "Baştan başlat → trene bin (Per 3 Ara)" (04a), "→ bugünkü tren" (04b) ve 07b "(Per 3 Ara)": önizleme RPC yok. `ovsync_uyari.bastan_tren_gunu = _ovsync_tren_gunu(bugün)` (M6:224) ve `ovsync_tren_onizle(p_hayvan_id)` (görevsiz hayvanda `_ic(bugün,capa,0,bugün)`, M4:578) KURAL'ı yok sayar; gerçek yeni görev hedefi `_ovsync_tren_gunu(kural)` (M3:50, protokol_iptal M3:446-448) → kural bugünden ilerideyse gösterilen tarih yanlış olabilir (INFERRED; ölçülmedi).
- **BOŞLUK-5** — S1 satırında tren başlığına "bugün: PG günü" gösterilirken S0/S1 ayrımı: mockup 02a PG-bugün üyelerini (169, 5708) S1 kartında gösteriyor; sunucu bunları `bugun_isi=true` ⇒ **S0** yapar (20260929000001:118, 355-358) — S1 satırında yalnız bugün işi olmayanlar kalır. Tren başlığı `uyeler.length` ile S1 grubu satır sayısı uyuşmaz (UA1 fark F1). Kaynak veri var, mockup/UA1 gruplaması sözleşmeye uymuyor (INFERRED, kod okuması).
- **KISMİ-1** — K8 toast "…5 hayvan": `onizle.uye_sayisi+1` türetimi (start dönüşünde sayı yok).
- **KISMİ-2** — Vaka kartı "aşama 2" chip'i: aşama yalnız `ovsync_tren_listele` ile gelir (çevrimiçi); `cases.ovsync_tren` IDB'den (INFERRED).

Mockup'ta gösterimi OLMAYAN ama sunucunun döndüğü (UB brief'inde karar gerektirir): `ileri_sayisi`, `ileri_gorevler`, `ileri_vakalar` (RL-14), `iptal_tai[]` (RL-12; `ovsync_bastan_baslat`, `islenen[].detay`), `start_first_service_protocol.basladi:false + yeniden_hedef`, `belirsiz_asama[]`, `gorev_hedef_eski`, `OVSYNC_TREN_GUNU_DEGIL.sebep=ONCEKI_TREN_VAR/ilk_tren`, `OVSYNC_TREN_UYELIK_YOK`, `ritim_disi_neden` (4 değer), `ovsync_hastalik_gunu_ekle.tren_ayrildi`.

## Tanımlar

1. **Aşama** (`_ovsync_asama`, M2:115-144; hastalık günleri `disease_id IS NULL` filtresiyle dışarıda, :133). Gün durumu: **Y** = gün `tamamlandi` ve (tüm seanslar uygulandı ya da hiçbiri uygulanmamış+hiçbiri "uygulanmadı" işaretli = geriye tarihli kayıt); **N** = hiç seans uygulanmamış ve (gün tamamlanmadı ya da "uygulanmadı" işaretli seans var); **X** = diğer (kısmi seans vb.). Desen (tarih, day_no sırası): `NNNN`→**0**, `YNNN`→**1**, `YY..`→**2**, gün sayısı ≠4 ya da başka desen → **NULL (belirsiz)**; aktif OVSYNC vaka değilse NULL (M2:139-142). Görev (OVSYNC_BASLAT, vaka yok) listede aşama 0 sayılır (M7:91). UI: 0 → "Başlamadı: Sonraki trene aktar → …"; 1 → "PG (tarih|bugün): PG'yi ertele · en çok +pg_pay gün" (pay ≤0 → "PG payı doldu: Baştan başlat → trene bin"); 2 → "PG yapıldı · erteleme yok: PG1+48 s'te tohumla | Baştan başlat"; NULL → "Aşama belirsiz: Baştan başlat" (UA1:522-550). Sunucu belirsizde `OVSYNC_ASAMA_BELIRSIZ` (M6:302), toptanda üyeyi düşürür (M7:312-313).
2. **PG payı / kayma** (`_ovsync_pg1_kayma`, M2:149-162): PG1 günü − (GnRH1 gerçek tamamlanma günü TR + 7) — GnRH1 seanslarının en geç uygulama anının TR günü, işaretsiz tamamlanmışsa `treatment_date`; aşama 0/NULL → NULL. `pg_pay = tolerans − kayma` ham (negatif olabilir) yalnız aşama 1 (M7:58). Tolerans varsayılan 1 (0-2), öne çekme 2 (0-2) (M2:21-24).
3. **Gecikmiş**: (a) başlangıç görevi hedef < bugün: listele'de bulunur (alt sınır yok, M7:97); ritim dışıysa `ritim_disi_neden='gecikmiş başlangıç'` (M7:94); onizle `gorev_hedef_eski:true` + ilk tren (M4:574-579); `start_first_service_protocol` tren yolunda eskiyi ilk trene taşır, tren bugünse başlar, ileriyse `basladi:false,yeniden_hedef` (M4:176-187); `yeniden_hedefle` hedef<bugün görevleri LİSTELEMEZ (M8:64). (b) seans gecikmesi mevcut S1/S0 `gecikme_gun` (20260929000001:362-366). (c) K11 geç tamamlama: `gecikme = bugün − PG1 günü + kayma > tolerans` ⇒ `ovsync_uyari` (M6:219-225); işlem başarılı, protokol sürer; metin "PG1 N gün geç — baştan başlat önerilir" + "Baştan başlat → trene bin" + "Devam et".
4. **Ritim dışı**: tren etiketi ≢ çapa (mod 7) (`trenler[].ritim_disi`, M7:109). `ritim_disi_neden` (üye, ritim dışı trende; ritim içi → NULL): görev üyesi `'gecikmiş başlangıç'` (hedef<bugün) | `'başlangıç ritim dışı'` (M7:93-94); vaka üyesi `'PG +k gün'`/`'PG -k gün'` (k=`_ovsync_pg1_kayma`≠0) | `'tren ritmi değişti'` (kayma 0/NULL) (M7:100-103). UI: "ritim dışı" etiketi + ertele düğmesi YOK (UA1:272, 275); açıklama notu neden'e göre değişmeli (UA1 sabit metin — F2). Toptan erteleme kümesine girmez; plan `dokunulmaz.ritim_disi` sayar (M7:235).
5. **Bağımsız**: aktif OVSYNC vakası `ovsync_tren IS NULL` → `bagimsizlar[]` (M7:113-115). Girişler: K8 "bağımsız başlat" (`start_first_service_protocol(p_bagimsiz)`, M4:95, 211), K9 hastalık günü (`ovsync_tren=NULL`, `tren_ayrildi:true`, M5:711, 737-739), bayrak öncesi eski vakalar (NULL, D9 öncesi ayırt edilemez), tren günü olmayan D0. Tren bugünse `p_bagimsiz` bile trene biner (R4). Toptan ertelemeye girmez (`dokunulmaz.bagimsiz`, M7:234); tek hayvan ertelemesi aşama kurallarıyla (M6:306-310). Toptan kümede (iii) `ovsync_tren=X−7` ve (ii) `=X`; bağımsızlar küme dışı.
6. **İleri**: `ileri_sayisi` = hedefi > bugün+28 açık OVSYNC_BASLAT sayısı; `trenler[]`'de yok (M7:97, 117-119). Toptan plan: `ileri_gorevler` = hedefi > X açık başlatma görevleri, yeni = R9 formülü (yeni çapa), `kural_yok:true` kural çözülemezse, değişmeyen listelenmez (M7:217-226); `ileri_vakalar` = `ovsync_tren > X` aşama 0 aktif vakalar `+n` (RL-14, M7:228-232). UA1 yalnız `ileri_gorevler.length` metnini yazar (UA1:404-405), `ileri_vakalar` yok.
7. **Üye sayısı**: onizle `uye_sayisi` = tren kümesi **sorulan hayvan HARİÇ** (M4:598) — K8 başlığı "(n hayvan)" bu sayıdır (UB-ekler #5'in `uye_kupeler.length` eşdeğeri: ikisi aynı kümeden). Listele `trenler[].uyeler.length` = vakalar + o güne hedefli görevler, sorulan hayvan kavramı yok (M7:99-108). Plan `uyeler.length` = X kümesi (X−7 treni vakaları dahil; "6 hayvan, 2 tren" `tren_sayisi` = distinct `ovsync_tren`, M7:243).
8. **"Yapıldı" (kısmi tren günü)**: bir günün seansları ayrı ayrı uygulanır; gün Y olması TÜM seansların uygulanmasını (ya da hiç uygulanmamış+tamamlandı geriye tarihli kaydı) ister; yalnız bir kısmı uygulanmış gün X ⇒ aşama NULL (belirsiz). Aynı trende karışık aşama normaldir (36/38 aşama 2, 169/5708 aşama 1, 02a). `pg1_zaman` yalnız PG1 günü tüm seanslar uygulandıysa dolu (M7:52-55); kısmi ise null ve aşama 1/NULL.

## UA1 ile fark

(UA1 = js/ovsync-tren.js; UB-ekler #4 alanları artık HEPSİ RPC'de var: `kupe_no/kural_tarihi/uye_kupeler` M4:605, `pg_pay/pg1_zaman/ritim_disi_neden/ovsync_tren` M7:56-58/90-100, `tren_sayisi/dokunulmaz` M7:243-244, `ovsync_uyari.{kupe_no,planlanan_tarih,tamamlanan_tarih,bastan_tren_gunu}` M6:221-224 — UA1 bunların bir kısmını kullanmıyor, aşağıda.)

- **F1 — S0 üyeleri tren grubunda yok (CONFIRMED veri, INFERRED etki):** `ovsyncTrenGrupla(satirlar, trenVeri)` yalnız verilen satırları gruplar (UA1:291-311); çağıran `grp.S1` verirse bugün işi olan üyeler (`bolum='S0'`, 20260929000001:355-358) başlıktaki `uyeler.length`'e girmez. UB3 `grp.S0∪grp.S1` vermeli ya da başlık sayısını satır sayısından ayırmalı; S0 kartlarına da `ovsyncAsamaAksiyonHtml` gerekir.
- **F2 — ritim dışı notu sabit metin:** UA1 her ritim dışı trende "Tek hayvan ertelemesiyle ritimden çıktı…" (UA1:279) yazar; `ritim_disi_neden` kullanılmıyor. Gecikmiş başlangıç (göç kalıntısı, en yaygın durum — D8 `ileri/gecikmiş` görevler) için metin YANLIŞ. Mockup "(PG +1 gün)" için `ritim_disi_neden` hazır (M7:100-103).
- **F3 — aşama 0 "Sonraki trene aktar → tren+7" etiketi:** UA1 `_ovtGunEkle(tren,7)` (UA1:544); sunucu `_ic(D0+p_gun,capa,0,bugün)` (M6:292, 316). Etiket (`ovsync_tren`) ritim dışı ya da gecikmişse (görev üyesinde `ovsync_tren=hedef<bugün`) tren+7 yanlış hedef gösterir. `ovsync_hayvan_ertele` yanıtındaki `yeni_tarih` (M6:294/327) gösterilmeli; etiket yalnız `ritim_disi=false` iken güvenilir. `ERTELE`/`SONRAKI_TREN` düğmesi `p_gun` taşımıyor (UB3 N seçici gerekir; aşama 1'de ≤ `pg_pay`, bağımsız aşama 0'da serbest 1-7).
- **F4 — toptan önizleme `sonuc:null`:** aşama NULL üyede `sonuc=null` (M7:199-202 CASE'in tüm kolları yok); UA1 `'bilinmeyen sonuç: yok'` yazar ve onayı kalıcı kapatır (UA1:322-331, 356). Sunucu ise üyeyi `OVSYNC_ASAMA_BELIRSIZ`/DUSTU ile düşürür (M7:312-313, 331-334) → kullanıcının çıkış yolu yok; "belirsiz → baştan başlat öner" satırı gerekir (R6-EK `oneri`).
- **F5 — plan alanları kullanılmıyor:** `ileri_vakalar` (RL-14), `dokunulmaz`, `tren_sayisi`, `pg1_zaman` saat (UA1:371-414). `ileri_gorevler` yalnız sayı; `kural_yok` gösterilmiyor. L-DB-DONE açık kalem 3'ün (`ileri_vakalar`, `iptal_tai`, `basladi:false`+`yeniden_hedef`, `ONCEKI_TREN_VAR`) UA1 karşılığı yok.
- **F6 — K11 uyarısı yeni alanları kullanmıyor:** `planlanan_tarih`, `tamamlanan_tarih`, `bastan_tren_gunu`, `oneri` var (M6:221-224); UA1 genel "PG planlanan günden N gün sonra yapıldı" (UA1:505) ve "hayvan sonraki trene biner" yazar; mockup 7b tarihli metin. (UA1-report #5 açık kalemi artık kapatılabilir.) `bastan_tren_gunu` kural-yok-sayar (BOŞLUK-4).
- **F7 — hata metinleri:** `OVSYNC_TREN_GUNU_DEGIL` her sebepte "Seçilen tarih bir tren günü değil." (UA1:596); `sebep:'ONCEKI_TREN_VAR'+ilk_tren` için "Önce {ilk_tren} treni ertelenmeli" metni yok (UB-ekler #6, M7:178). `OVSYNC_TREN_ERTELE_DUSTU.dusenler[].sebep` ham `KOD:{json}` içerir (M7:333) ama UA1 olduğu gibi basar (UA1:586) — `ovsyncTrenHataMetni(sebep)` özyinelemeli çağrılmalı; `oneri` kullanılmıyor. `GECMIS_TARIH` (M7:163) `OVSYNC_` önekli değil → UA1 regex yakalamaz → ham mesaj. Metni olmayan kodlar (ham mesaj döner, sessiz değil): `OVSYNC_TREN_UYELIK_YOK`, `OVSYNC_BASTAN_HEDEF_GECERSIZ`, `OVSYNC_PG48_SEANS_KAPANMADI`, `OVSYNC_VAKA_ACILAMADI`, `OVSYNC_SABLON_*`, `OVSYNC_HASTALIK_BELIRSIZ`, `OVSYNC_TAI_OLUSMADI`, `OVSYNC_SECIM_KISIR/TABAN_YOK/ERKEN`, `OVSYNC_ERKEN`, `OVSYNC_BASLAT_PARAMETRE`.
- **F8 — `ovsyncTrenGorevMu` bozuk-JSON kolu SQL'den geniş (CONFIRMED kod okuması):** SQL yalnız `aciklama ~ '^\s*\{'` iken JSON çözer, aksi sessiz `false` (M2:194-203); UA1 boş olmayan HER string `aciklama`'yı `JSON.parse`'a sokar (UA1:437-441) → düz metinli TEDAVI_GUN/TEDAVI_SEANS görevlerde (ör. "Gün 10 — Ovsync 4. uygulama" biçimi; M5:540 `left(aciklama,1)='{'` koruması mevcut kodda mixed içerik olduğunu gösterir) her çağrıda hata bildirimi/`console.error` + gürültü. Kapı tur 2 ekinin (JSON.parse try/catch) hedefi "bozuk veri" idi; düz metin bozuk değildir. UA1'e `^\s*\{` ön koşulu ekle.
- **F9 — "Tren gününü ertele…" her ritim başlığında:** UA1 `ovsyncToptanTarih` ritim içi her tren için X döndürür (UA1:251-258); sunucu X'in bugünden itibaren üyesi olan İLK ritim günü olmasını ister (RL-16, M7:168-179 `ONCEKI_TREN_VAR`). UB-ekler #6: düğme yalnız ilk başlıkta. UB3 `min(X)` seçip yalnız ona düğme koymalı (X'ler tren etiketi ve etiket+7'den oluşur, M7:171-176).
- **F10 — K8 önizleme ek bilgisi:** `gorev_hedef_eski` ve `gorev.hedef_tarih` UA1'de kullanılmıyor (UB-ekler #5): gecikmiş görevde modal "görev eski tarihi yerine X trenine taşınır" demiyor. R4 ile tren=bugün modalsız yol `ovsyncTrenSoruGerekli` doğru (`tren_bugun_mu` ile eşdeğer, M4:602); ama eski görev + tren bugün ⇒ `start` bugün başlar (M4:178-180) ✔.
- **F11 — `start_first_service_protocol` `basladi:false`:** TREN yolunda dönüş `case_id` içermez (M4:185); UB2 (`ovsyncBaslat`, G7/G9 BAGIMSIZ) dönüşten `case_id` varsayarsa kırılır. UA1'de bu kol için metin/yardımcı yok.
- **F12 — `ovsyncTrenAktif(ayarlar)`**: protokol_ayar IDB satırı `ovsync_tren_aktif`+`ovsync_pg_kurallari_aktif` ister; `ovsync_tren_listele.aktif`/`onizle.aktif` ile aynı koşul (M2:37) ✔ ama IDB bayat olabilir (sync gecikmesi); sunucu yanıtı kazanmalı (UA1 `ovsyncTrenSor` `veri.aktif===false` → eski yol ✔, UA1:219).
- **F13 — UB1 RPC_TABLES seti eksik (PLAN :482-483):** PLAN listesi `drug_administrations`'ı içermiyor; `ovsync_bastan_baslat` (ve içinden çağıran `ovsync_tren_ertele`) `start_first_service_protocol`'ü çalıştırır, mevcut harita `drug_administrations`+`diseases`+`drugs`+`tedavi_sablonu` ekler (api.js:418; `protokol_iptal` seti :428-432 `drug_administrations` içerir). `ovsync_pg48_tohumla` `seans_tamamla` ile stok iadesi/uygulama satırı yazar. İnvariant testi (ovsync-pg-pull-haritasi, ovsync-api RPC_TABLES) gerçek kapsama bakar (INFERRED).
- **F14 — CSS sahibi yok:** `_tren-yeni.css` (39 satır, mockup dizininde) hiçbir UB görevinde index.html'e taşınma maddesi olarak yazılı değil (PLAN grep: 0 sonuç; yalnız UA1-report :59 `.ovs-mavi` açık-tema notu); index.html'de `ovs-tren*` 0 eşleşme (OBSERVED `grep -c`). UB5 sonrası görünüm eksik olur. UB brief'ine `index.html <style>` ekleme (renk testleri: sol şerit/zemin yok kuralı) eklenmeli.
- **F15 — `ovsyncDuzenleLinkHtml`/`ovsyncCokluAtlananNot` inline `onclick`:** başlık yorumu "inline onclick yok" der (UA1:11) ama :468/:483 onclick taşır (UB-ekler #3 zaten kayıtlı); `ovsync_atlanan[].kupe_no` null olabilir (LEFT JOIN, M5:549) — UA1 filtreler ✔.
- Uyumlu bulunanlar (CONFIRMED): `ovsyncTrenSoruGerekli/SoruHtml` alanları (M4:600-605); `ovsyncTrenBaslikHtml` (`tren_gunu,ritim_disi,uyeler`, M7:109); `ovsyncAsamaAksiyonHtml` (`sonraki_is.tarih`, `pg_pay`, `asama`, `case_id`, M7:56-58); `ovsyncCokluAtlananNot` (M5:547); `dogumPgHatirlatmaHtml` alanları (M1:214); `ovsyncTrenHataMetni` payload alanları `OVSYNC_ASAMA1_TOLERANS{tolerans,mevcut_kayma,istenen}` (M6:308), `OVSYNC_TREN_SECIM_EKSIK{eksik}` (M7:294), `…DUSTU{dusenler[].kupe_no,hayvan_id,sebep}`, `OVSYNC_TREN_AYAR{anahtar,deger,sebep}`, `OVSYNC_TREN_EKRANI{tren_gunu}` (M2:226/243), `OVSYNC_GOREV_ACILAMADI{sebep}` (M3:906), `OVSYNC_BASTAN_BASLATILAMADI{yeniden_not}` (M6:432).

## Test tabanı

Komut 1 (brief, verbatim): `cd ~/.herdr/worktrees/egesut-erp1/ovsync-tren && NODE_PATH=~/egesut-erp1/node_modules node --test tests/unit/*.test.js 2>&1 | tail -40` — PreToolUse kancası çıplak koşuma izin vermedi; aynı komut `ram-ultracode exec --class test -- bash <betik>` ile koşuldu, çıktı dosyaya alındı (özet satırı aynı).

Sonuç (OBSERVED, dal HEAD d359e4e, D9 çalışma ağacı değişiklikleri açık): `ℹ tests 2281 · suites 61 · pass 2277 · fail 4`.

| # | test (dosya:satır) | kısa neden | main'de? |
|---|---|---|---|
| 1 | LUNA-3 `tests/unit/degisiklikler-etiketler.test.js:88` | canlı DEMO'da haritasız 8 kolon: `cases.close_reason, cases.protocol_family, cases.protocol_snapshot, cases.source_template_id, drug_classes.farmakolojik_sinif_kodu, drug_classes.sistem, gorev_log.takip_kapanis_nedeni, tedavi_sablonu.protokol_ailesi` (canlı DEMO bağlantısı gerektirir) | KIRMIZI (OBSERVED main b9542b1) |
| 2 | EG-7 `tests/unit/erteleme-genel-ui.test.js:262` | `rpcCagri.length 0 !== 1`: test `05.10.2026` sabit tarihi pinliyor; `_erteleKaydet` geçmiş tarihte RPC'siz çıkar (`js/ui.js:3801 tarih < bugün → 'Geçmiş tarih seçilemez'`) — bugün 2026-11-09 (CONFIRMED kod, tarihe bağlı) | KIRMIZI (OBSERVED) |
| 3 | EG-8 `erteleme-genel-ui.test.js:292` | aynı neden (`05.10.2026`), `toastlar` boş | KIRMIZI (OBSERVED) |
| 4 | `ay ‹/›` `tests/unit/vaka-toplu-ac.test.js:2624` (üst suite "bc-tarih takvim" :2605 civarı) | +3 ay etiketi (Şubat 2027) bulunamadı; test bugüne-göre tarih kullanır (yerel saat `new Date()`, :2544-2547), kök neden ölçülmedi — UNKNOWN (tarih/ay bağımlı görünüyor) | KIRMIZI (OBSERVED) |

Main baz koşumu: `~/egesut-erp1` (b9542b1) üzerinde aynı 3 dosya: `ℹ tests 258 · pass 254 · fail 4` (aynı 4 test).

`node scripts/etiket-tazelik.mjs; echo rc=$?` (brief verbatim, NODE_PATH'siz): `rc=1` — `Error: Cannot find module 'espree'` (worktree'de node_modules yok; OBSERVED). `NODE_PATH=~/egesut-erp1/node_modules` ile: `payda 309 satır: DOĞRU 290 | HATALI 15 | DOGRULANAMADI 4`, `rc=1`; main'de **aynı** sayı ve **aynı** liste (diff boş, OBSERVED). HATALI/DOĞRULANAMADI kalemleri: `_pullTablesNow`, `initRealtime`, `semaDiffKontrol`, `hayvan-takip-pencere.js` (`_htAciklar,_htGonder,htAcGonder,htMuayeneGonder,htKapatGonder,htSonucAc,_htAktifVakalariOku,_htAktifVakalariGoster,htVakaBagla,htSonucGonder` — `hayvan_takip` etiketi eksik), `hastalikGunKaydet`, `loadDash`, `loadAnimals`, `_ovsyncAktifBolmeHtml`, `openDet`. **N4 kapısı "etiket-tazelik exit 0" (PLAN :546) bu tabanla ASLA yeşil olamaz** — taban zaten kırmızı (hayvan-takip kaynaklı). Brief'e "yeni HATALI yok (taban 15/4)" yazılmalı ya da önce taban kapatılmalı (UB5 değil).

**N4'te bayatlayacak / dikkat gerektiren testler (INFERRED, kod+grep):**
- `tests/unit/ileri-gebe-duve-siralama.test.js:214` `damgalar.length >= 36` ve `:216` tek ayrık değer: brief'in "sabitliyor" demesi yarım — alt sınır (`>=`), bugün tam 36 (OBSERVED: 35 script + manifest); yeni `<script>` ekleyince 37 ⇒ GEÇER. Tuzak başka: yeni etiketin damgası mevcut `20261031-13` ile AYNI olmalı, aksi `:216` + `vaka-toplu-ac.test.js:2342-2350/2685-2701` + `coklu-kaydir-ui.test.js:597-602` + `hayvan-takip-pencere.test.js:898` + `istatistik-atolye.test.js:103-107` kırılır. UB1 yeni etiketi `?v=20261031-13` ile eklemeli; toplu bump (`20261110-1`) UB5'te tek adımda. UB5'te "eski damga kalmaz" testi (`vaka-toplu-ac.test.js:2694-2701`) yalnız eski sabit değerleri arar — yeni değerle sorun beklenmez.
- `tests/unit/istatistik-atolye.test.js:90-101` (`html_script_sirasi`): YENİ istatistik etiketleri `degisiklikler.js` HEMEN sonrasında ve `app.js` HEMEN öncesinde bitişik olmalı; `js/ovsync-tren.js` `ui.js` ÖNCESİNE (PLAN UB1) konursa etkilenmez; `ui.js` ile `js/istatistik/*` arasına konursa kırılır (`i('js/ui.js') < i(YENI[0])` sağlanır ama bitişiklik `:93` yalnız YENI içinde — ara etiket eklenmemeli). Aynı uyarı `hayvan-takip-pencere.test.js:889-896` (forms<takip<pencere).
- `ovsync-render.test.js`, `ovsync-gezinti.test.js` (`renderOvsyncSayfa`), `erteleme-genel-ui/offline/ovsync-render/ovsync-pg-ui/ovsync-takip/hayvan-takip-ui` (`_erteleBtnHtml`), `coklu-kaydir-ui` (`cokluKaydirOnayla`), `erteleme-kaydir-ui/offline` (`cdKaydirSheetHtml/cdKaydirAc`), `det-tazeleme-forms/ovsync-secici/ovsync-takip/ovsync-api` (`_devamSeciciAc`), `cd-protokol-iptal-ui/erteleme-protokol-iptal-ui/ovsync-api` (`_protokolIptalAkisi`), `vaka-toplu-ac/vaka-toplu-kisir-dusme/ovsync-takip-kapi/hayvan-takip-vaka` (`submitBulkCase`), `pg-kapi-sarmal/vaka-sablon-pg-kapi/pg-kapi-metin` (`caseSablonUygula`/`_vakaBosAtaKanca`), `cila-tutarlilik/ovsync-seans-panel` (`_rozetTopla`), `ovsync-pg-pull-haritasi/ovsync-takip-kapi/erteleme-protokol-iptal-ui/cila-tutarlilik` (`start_first_service_protocol`), `api.test.js/ovsync-pg-karar` (`seans_tamamla`): UB2-UB5 değiştirdiği sembolleri çağıran mevcut testler — bayrak kapalı davranışı birebir korunmalı (PLAN testi var). `erteleme-genel-ui.test.js:350` (EG-10) RPC_TABLES dolu-dizi invariantı: UB1 yeni salt-okuma RPC'leri haritaya KOYMAMALI.
- EG-7/EG-8 UB4'ün dokunacağı `_erteleKaydet`'i (`OVSYNC_TREN_EKRANI` toast) sınar ve ŞİMDİ tarihe bağlı kırmızı; UB4 testleri aynı sahte-ortamı kullanırsa yeşil kanıtı karışır — UB4'ten önce tarihi göreli yapmak (ayrı küçük iş) ya da UB4 brief'inde "EG-7/8 taban kırmızı, sayılmaz" yazmak gerekir. Ayrıca `ui.js:3801` `new Date().toISOString()` UTC günü kullanır (TR 00:00-03:00'te bir gün geride; tz-current-date dersi) — N4 kapsamı dışı, not.
- DM1/N6: demo apply sonrası `cases.ovsync_tren` (+D9 `cases.ovsync_bagimsiz`) LUNA-3 haritasını ek 2 kolonla kırar (INFERRED; `degisiklikler-etiketler.test.js` harita güncellemesi gerekir).

## Toast/XSS ölçümü

- `toast(msg, err=false)` → `~/.herdr/worktrees/egesut-erp1/ovsync-tren/js/utils/helpers.js:219-229` kuyruğa alır; gösterim `_toastPump` içinde `el.textContent = next.msg` (`helpers.js:204`) — **textContent, innerHTML DEĞİL** → `toast(ovsyncTrenHataMetni(e))` güvenli, ek `esc` gerekmez (UB-ekler #1 CONFIRMED). Aynı dosyada `esc()` `textContent→innerHTML` (helpers.js:241-245), `escAttr` tırnak kaçırır.
- Dikkat (davranış, güvenlik değil): `TOAST_MS=3200`, kuyruk üst sınırı 3, tekrar eden mesaj dedupe (`helpers.js:173-175, 223-229`). Uzun `ovsyncTrenHataMetni` (örn. `ERTELE_DUSTU` düşen liste) 3,2 sn'de kaybolur ve `err` argümanı verilmezse hata stili yok; UA1 `ovsyncTrenSor` `toast(ovsyncTrenHataMetni(e))`'yi `err` bayraksız çağırır (UA1:215; çağıran `o.toast` sarmalayıcısına `err=true` bağlamalı). Düşen listeli uzun metin için toast yerine modal içi satır kullanılmalı (3b "düşen hayvan ve nedeni yazılır" cümlesiyle uyumlu).
- `ovsyncTrenHataMetni` çıktısı HTML'e (innerHTML) basılacaksa `esc` zorunlu; UA1'in HTML üreten fonksiyonları `_ovtE`=`esc` kullanıyor (UA1:113-115) ✔.

## Run kanıtı

```
cd ~/.herdr/worktrees/egesut-erp1/ovsync-tren && NODE_PATH=~/egesut-erp1/node_modules node --test tests/unit/*.test.js 2>&1 | tail -40
```
(kanca çıplak koşumu reddetti; `ram-ultracode exec --class test -- bash run-unit.sh` ile aynı komut koşuldu, çıktı dosyadan)
rc: 1
```
ℹ tests 2281
ℹ suites 61
ℹ pass 2277
ℹ fail 4
ℹ cancelled 0
ℹ skipped 0
ℹ todo 0
ℹ duration_ms 11249.990969

✖ failing tests:
test at tests/unit/degisiklikler-etiketler.test.js:88:1  ✖ LUNA-3 …
test at tests/unit/erteleme-genel-ui.test.js:262:1       ✖ EG-7 …
test at tests/unit/erteleme-genel-ui.test.js:292:1       ✖ EG-8 …
test at tests/unit/vaka-toplu-ac.test.js:2624:3          ✖ ay ‹/› …
  AssertionError [ERR_ASSERTION]: +3 ay etiketi (Şubat 2027): <div class="tarih-modal-kart">…
rc=1  (betik satırı; `| tail -40` kullanılan boru satırında sondaki çıkış kodu tail'indir)
```

```
cd ~/.herdr/worktrees/egesut-erp1/ovsync-tren && node scripts/etiket-tazelik.mjs; echo rc=$?
```
rc: 1
```
Error: Cannot find module 'espree'
Require stack:
- ~/.herdr/worktrees/egesut-erp1/ovsync-tren/package.json
    at … scripts/etiket-tazelik.mjs:31:16
  code: 'MODULE_NOT_FOUND'
Node.js v26.10.0
rc=1
```
Aynı komut `NODE_PATH=~/egesut-erp1/node_modules` ile (OBSERVED, dal ve main ayrı koşum):
```
payda 309 satır: DOĞRU 290 | HATALI 15 | DOGRULANAMADI 4
rc=1
```

## Kırıntılar
- measurement: unit 2281/2277 pass/4 fail; dört fail main b9542b1'de aynı (OBSERVED); etiket-tazelik dal=main aynı 15/4, rc=1.
- open_item: 5 BOŞLUK (PG+48 önizleme tarihi, dokunulmaz küpe listesi, bağımsız neden/tarih, baştan başlat önizleme tarihi (kural yok sayma), S0/S1 üye grubu uyumsuzluğu) — UB brief'ine "mockup metnini RPC kaynağına indir ya da RPC genişlet" kararı.
- open_item: UA1 farkları F1-F15 (özellikle F1, F2, F3, F4, F8, F9, F13, F14) — UB brief'lerine bağlayıcı ek.
- doc-drift: brief "ileri-gebe-duve-siralama.test.js:209 ?v= sayısını sabitliyor" → gerçek `:214 >= 36`; asıl risk damga eşitliği.
- assumption: D9 yürütücüsünün düzenlemesi RPC imza/dönüşünü değiştirmiyor (D9-brief RD9-6); satır numaraları ±10 kayabilir.
