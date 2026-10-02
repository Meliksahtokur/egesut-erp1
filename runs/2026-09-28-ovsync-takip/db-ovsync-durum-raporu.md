# Ovsync Vaka Durum ve Sonlanma Envanteri — EgeSüt ERP PROD

- **Tarih:** 2026-09-28 (tüm gecikme hesapları buna göre)
- **Ortam:** PROD (canlı) Supabase — yalnızca salt-okuma PostgREST SELECT (`supabase_query`)
- **Kapsam:** `protocol_family='OVSYNC'` olan TÜM vakalar + OVSYNC_BASLAT / TOHUMLAMA_PLANLI görev zincirleri + tohumlama sonlanmaları
- **Kanıt etiketleri:** `[CONFIRMED dosya:satır]` kod/referans · `[OBSERVED sorgu]` canlı DB · `[INFERRED]` veriden çıkarım

---

## 1. Ovsync Veri Modeli Özeti

| Nesne | Rol | Kanıt |
|---|---|---|
| `cases.protocol_family` = 'OVSYNC' | Ovsync vakasının kendisi; `protocol_snapshot` (şablon kopyası), `close_reason` (TOHUMLAMA/PG/IPTAL/ERKEN_KAPANIS/null), `source_template_id` | [OBSERVED `cases?protocol_family=not.is.null` → 35 satır] |
| `diseases` id `c346e115…` = **"Ovsync Protokol"** (Üreme kategorisi) | Vakanın hastalık kimliği | [OBSERVED `diseases?id=eq.c346e115…`] |
| `tedavi_sablonu` id `a152f7fe…` = **"Sağmal inek: Ovsynch-56 + çift PGs"**, `protokol_ailesi='OVSYNC'` | Tek ovsync şablonu; `tohumlama_plani={gun_ofset:10, planned_time:'10:00'}` | [OBSERVED `tedavi_sablonu` — protokol_ailesi dolu tek satır] |
| Şablon kalemleri (snapshot) | Gün1 Buserin (alke) 2,5 ml IM 10:00 · Gün8 PGs (alke) 2 ml IM 10:00 · Gün9 PGs 2 ml IM 10:00 · Gün10 Buserin 2,5 ml IM **18:00** · TAI gün başlangıç+10 | [OBSERVED `cases.protocol_snapshot` + `drug_products` c2f9f08f=Buserin, ef49ec29=PGs] |
| `sablon_hastalik_eslem` | Şablon ↔ hastalık eşlemesi (a152f7fe → c346e115) | [OBSERVED sorgu] |
| `protokol_ayar.ovsync_pg_kurallari_aktif` = **1** (2026-09-23'ten beri açık) | Kural bayrağı | [OBSERVED `protokol_ayar`] |
| `gorev_log` tip `OVSYNC_BASLAT` | Protokol doğum görevi (kural günü doğar, hedef−2 günden önce ▶ Başlat çizilmez); `kaynak` önekleri `ACIK-DISI-`, `ILK-TOH-DOGUM-`, `PROTOKOL-IPTAL-`; `protokol_instance_id` dolu | [OBSERVED `gorev_log?gorev_tipi=eq.OVSYNC_BASLAT` → 44 satır] + [CONFIRMED js/ui.js:1736-1743, 1751-1755] |
| `gorev_log` tip `TOHUMLAMA_PLANLI` | TAI görevi; `kaynak` önekleri `TEDAVI_SABLON_TOHUMLAMA:case:şablon|MANUEL` ve `PG_TOHUMLAMA:uygulama_id`; `kapatan_ref='PG_YERINE:…'` = sonraki PG görevi devraldı ("son PG kazanır") | [OBSERVED `gorev_log?kaynak=like.*TOHUMLAMA*` → 39 satır] + [CONFIRMED domain-rules.md §18.6] |
| `treatment_days` (case'e bağlı) | Protokol ilaç günleri (day_no 1..4 = şablon gün 1/8/9/10; kimi vakada day_no 5 = vaka_tohumlama_ekle TAI günü 08:00) | [OBSERVED iki kohort sorgusu] + [CONFIRMED rpc-reference.md vaka_tohumlama_ekle] |
| `protokol_instance` | Görevlerin zincir instance'ı (tip=UREME, alttip=DOGUM gözlendi; **alttip=OVSYNC instance gözlenmedi — bilinmiyor**) | [OBSERVED `protokol_instance?alttip=eq.OVSYNC` → 0] |
| RPC `start_first_service_protocol(p_gorev_id)` | Atomik başlatma: vaka + günler + TAI görevi + bildirim | [CONFIRMED js/ui.js:1799-1814] |
| RPC `protokol_iptal(p_vaka_id,…)` | Vaka IPTAL kapanışı + gün/seans kapanışı + stok iade + isteğe bağlı yeniden-başlat görevi | [CONFIRMED js/ui.js:1857-1876] |
| RPC `ovsync_baslat_uyarilari` | Kural günü yaklaşan/başlayan hayvan uyarıları | [CONFIRMED js/ui.js:1921-1928] |
| RPC `vaka_kalan_gunleri_kaydir` | Gün kaydırma; `islem_log tip='VAKA_KAYDIR'` audit yazar | [OBSERVED `islem_log?tip=eq.VAKA_KAYDIR` → 18 kayıt] |
| Kural günü `_ovsync_kural_tarihi` | Düve: dogum+12ay21g; doğum/abort geçmişi olan: son doğum/abort +51g | [CONFIRMED domain-rules.md:437-438] |
| Kısır hard-block (`trg_cases_kisir_ovsync`) | kisir=true hayvan hiçbir yoldan Ovsync'e giremez (2026-09-26 p5b) | [CONFIRMED domain-rules.md:449-450] |

**TAI = başlangıç + 10 gün** kuralı canlı veriyle kanıtlandı: 09-13 kohortunda start 09-13 → TAI tohumlamaları 09-23; 07-22 kohortunda start 07-22 → TAI 08-01 [OBSERVED]. Ovsynch-56 dizilimi canlıda: GnRH(d0) → PG(d7) → PG(d8) → GnRH(d9 18:00) → TAI(d10) [OBSERVED treatment_days].

---

## 2. Vaka Envanteri (35 vaka / 31 benzersiz hayvan)

4 hayvanda 2'şer vaka var: küpe 902, 121, 180, "Test inek 3". Tüm hayvanlar Aktif + Dişi [OBSERVED `hayvanlar` sorgusu].

### 2.1 DEVAM EDEN (12 vaka)

"İlaç" = şablonun 4 ilaç günü. TAI hedefi açık görev satırından [OBSERVED].

| # | Vaka (case_id öneki) | Küpe | Grup | Başlangıç | İlaç durumu | Mevcut adım + beklenen sonraki uygulama | TAI hedefi | Gecikme |
|---|---|---|---|---|---|---|---|---|
| 1 | f90731be | 168 | Sağmal | 2026-09-24 hedef → gün1 09-27 uygulandı | 1/4 | Gün8 PGs#1 — **2026-10-04 10:00** | 2026-10-07 10:00 (görev 8384790b açık) | 0 |
| 2 | c065e94e | 002 | Sağmal | 2026-09-18 (elle açılmış) | **4/4** (09-18/25/26/27) | **TAI BUGÜN — 2026-09-28 19:00** (görev 82df084d açık; PG_TOHUMLAMA zinciri, son PG kazanır) | 2026-09-28 19:00 | 0 (bugün) |
| 3 | 25a638aa | 122 | Sağmal | 09-24 hedef → gün1 09-27 | 1/4 | Gün8 — 10-04 10:00 | 10-07 (71a58da1) | 0 |
| 4 | bf9644c7 | 144 | Sağmal | 09-24 → 09-27 | 1/4 | Gün8 — 10-04 | 10-07 (32944e4f) | 0 |
| 5 | aa786467 | 31 | Düve (Büyük) | 09-24 → 09-27 | 1/4 | Gün8 — 10-04 | 10-07 (1db0c4d0) | 0 |
| 6 | 1b5c2a83 | 149 | Sağmal | 09-24 → 09-27 | 1/4 | Gün8 — 10-04 | 10-07 (b7d6ef6f) | 0 |
| 7 | b709072f | 902 | Sağmal | 2026-09-27 (elle) | 1/4 (gün1 09-27 ✓) | Gün8 — 10-04 | 10-07 (0247291b) | 0 |
| 8 | b284807a | 186 | Sağmal | 09-24 → 09-27 | 1/4 | Gün8 — 10-04 | 10-07 (07c867a4) | 0 |
| 9 | 03b10e2a | 28 | Düve (Büyük) | 09-24 → 09-27 | 1/4 | Gün8 — 10-04 | 10-07 (267a8a03) | 0 |
| 10 | 51adfd85 | 32 | Düve (Büyük) | 2026-09-26 (cron, hedef gününde) | 1/4 (gün1 09-27 ✓) | Gün8 — 10-04 | 10-07 (3dfe14c0) | 0 |
| 11 | 22b64b3b | 180 | Sağmal | 2026-09-27 | 1/4 (gün1 09-27 ✓) | Gün8 — 10-04 | 10-07 (9f37bc5b) | 0 |
| 12 | baa6eb33 | 121 | Sağmal | 2026-09-27 (elle) | 1/4 (gün1 09-27 ✓) | Gün8 — 10-04 | 10-07 (d8edef35) | 0 |

Notlar:
- #1,3-6,8,9 (7 vaka): 09-24 hedefli batch; günler 09-25'te +2, 09-27'de +1 kaydırıldı (islem_log VAKA_KAYDIR, 09-25 13:17 ve 09-27 05:01; eski ilk 09-24 → yeni ilk 09-27) [OBSERVED]. Gün1 09-27 06:41-08:42 arasında toplu uygulandı.
- #2 (küpe 002): gün4 sonrası ardışık PG uygulamaları TAI görevini `PG_YERINE` zinciriyle 09-27 10:00'tan 09-28 19:00'a taşıdı [OBSERVED kapatan_ref zinciri].
- #12 (küpe 121): hayvanda 2026-09-17 tarihli **Bekliyor** tohumlama duruyor (bkz. A4).

### 2.2 SONLANAN (23 vaka)

| # | Vaka | Küpe | Başlangıç→Kapanış | İlaç durumu | Sonlanma şekli | Tohumlama sonucu / detay |
|---|---|---|---|---|---|---|
| 13 | 46ad7840 | 119 | 09-13 → 09-23 | 4/4 + TAI görevi 09-23 tamam | **TAI ile kapandı** (close_reason=TOHUMLAMA) | 09-23 Darius, **Bekliyor** |
| 14 | 9a049855 | 200 | 09-13 → 09-23 | 4/4 + TAI ✓ | TAI (TOHUMLAMA) | 09-23 Darius, Bekliyor |
| 15 | 0eefbc18 | 14 | 09-13 → 09-23 | 4/4 + TAI ✓ | TAI (TOHUMLAMA) | 09-23 Darius, Bekliyor |
| 16 | 1d177526 | 04 | 09-13 → 09-23 | 4/4 + TAI ✓ | TAI (TOHUMLAMA) | 09-23 Darius, Bekliyor |
| 17 | 41257751 | 178 | 09-13 → 09-23 | 4/4 + TAI ✓ | TAI (TOHUMLAMA) | 09-23 Darius, Bekliyor |
| 18 | 4600ec46 | 23 | 09-13 → 09-23 | 4/4; TAI görevi iptal edildi | TAI (TOHUMLAMA) | 09-23 görevsiz girildi, Bekliyor |
| 19 | 93d76e6f | 135 | 09-13 → 09-23 | 4/4; TAI görevi 09-21'de kapandı | TAI (TOHUMLAMA) | **09-21** Darius (2 gün erken), Bekliyor |
| 20 | a0e8f3e8 | 136 | 09-13 → 09-23 | 4/4 + TAI ✓ | TAI (TOHUMLAMA) | 09-23 Darius, Bekliyor |
| 21 | b7ec6509 | 121 | 09-13 → 09-23 | 4/4 + gün5 TAI 09-23 08:00 planlı | TAI (TOHUMLAMA) | **09-17** Darius (6 gün erken), Bekliyor |
| 22 | d31d7245 | 02 | 09-13 → 09-23 | 4/4; TAI görevi 09-17'de iptal | TAI (TOHUMLAMA) | 09-23 görevsiz girildi, Bekliyor |
| 23 | 3681c010 | 51 | 09-13 → 09-23 | 4/4; **TAI görevi 09-23 07:30 iptal, tohumlama YOK** | **Kesildi** (close_reason=null) | TAI'sız kapatıldı — anomali A1 |
| 24 | a89d77a1 | 19 | 09-23 → 09-23 | 1/4; gün2-4 gelecek tarihli toplu kapatıldı | Kesildi/manuel (null); TAI protokolden erken girildi | 09-23 Darius, Bekliyor — anomali A7 |
| 25 | 3e6ce4e9 | 173 | 07-22 → 07-30 | 3/4 (gün4 uygulanmadan); TAI görevi iptal | **Gebe−** (null) | 07-30 Fresh **Boş**; 09-27'de yeni deneme Bekliyor |
| 26 | 05190e0a | 148 | 07-22 → 08-03 | 4/4 + TAI 08-01 görevle ✓ | **Gebe+** (null) | 08-01 Fresh **Gebe**; tahmini doğum ~2027-05-08 [INFERRED +280g] |
| 27 | 170465fd | 197 | 07-22 → 08-11 | 4/4 + TAI 08-01 ✓ | **Gebe−** (null) | 08-01 Fresh Boş; 08-25 yeni deneme hâlâ Bekliyor |
| 28 | 6c5f2a7e | 183 | 07-22 → 09-10 | 4/4 + TAI 08-01 ✓ | **Gebe+** (null) | 08-01 Fresh **Gebe**; vaka Gebe sonucundan 40 gün sonra kapatıldı |
| 29 | e0343041 | 902 | 07-22 → 09-10 | 4/4 + TAI 08-01 ✓ | **Gebe−** (null) | 08-01 Fresh Boş; yeniden deneme = aktif vaka #7 |
| 30 | 1e9b93a9 | Test inek 3 | 09-24 → 09-26 | günler toplu kapatıldı (uygulanmadı) | **PG** | Bağımsız PG vakayı kapattı; TAI zinciri PG_YERINE |
| 31 | a1cc01da | Test inek 3 | 09-26 → 09-27 | gün1 09-30 planlıydı; iptalde kapandı | **IPTAL** | protokol_iptal; 09-27 bağımsız Campus tohumlaması Bekliyor |
| 32 | f72f320c | 184 **kısır** | 09-24 → 09-25 | günler uygulanmadan kapatıldı | **ERKEN_KAPANIS** | 09-25 13:16 kısır temizliği (anomali A2) |
| 33 | 19febaa1 | 199 **kısır** | 09-24 → 09-25 | aynı | **ERKEN_KAPANIS** | aynı batch |
| 34 | 37b98c0c | 208 **kısır** | 09-24 → 09-25 | aynı | **ERKEN_KAPANIS** | aynı batch |
| 35 | 86a8e23c | 180 | 09-27 → 09-27 (8 dk) | gün1 uygulanmadan kapatıldı | **ERKEN_KAPANIS** | Yanlış açılış; hemen yerine vaka #11 açıldı |

### 2.3 Bekleyen OVSYNC_BASLAT görevleri (vaka henüz açılmamış adaylar)

44 görevin 14'ü tamamlandı/iptal; **30'u açık** (iptal=false, tamamlandi=false), hedef tarihler **2026-10-06 … 2027-09-22** arası — hepsi gelecekte, gecikme 0 [OBSERVED]. 1 görev iptal (Test inek 3, PROTOKOL-IPTAL kaynaklı yeniden-başlat görevi). Kaynaklar: `ACIK-DISI-` (çoğunluk), `ILK-TOH-DOGUM-` (1 adet, hedef 2026-11-14).

---

## 3. Özet

### 3.1 Sayılar [OBSERVED]

| Ölçüm | Değer |
|---|---|
| Toplam ovsync vakası | **35** (31 benzersiz hayvan) |
| Devam eden | **12** |
| Sonlanan | **23** |
| — TAI ile kapanan (close_reason=TOHUMLAMA) | 10 (hepsi sonuç **Bekliyor**; 8'i 09-23, 1'i 09-21, 1'i 09-17 tarihli tohumlama) |
| — Gebe+ | 2 (küpe 148, 183 — 08-01 TAI) |
| — Gebe− (Boş TAI) | 3 (küpe 173, 197, 902 — 07-22 kohortu) |
| — PG sonlanması | 1 (Test inek 3) |
| — IPTAL | 1 (Test inek 3) |
| — ERKEN_KAPANIS | 4 (3 kısır temizliği + küpe 180 yanlış açılış) |
| — Kesildi/manuel (TAI'sız veya yarım) | 2 (küpe 51 TAI'sız; küpe 19 yarım protokol + erken TAI) |
| Bekleyen gebelik sonucu (ovsync kaynaklı tohumlama, sonuc=Bekliyor) | 11 kayıt (09-13 kohortu) — 21. gün kontrolleri 10-08…10-14 penceresinde [INFERRED +21g] |
| Gecikmiş uygulama (aktif vakalarda geçmiş tarihli açık gün/görev) | **0** |
| Bugün yapılacak | Küpe 002 TAI — 2026-09-28 19:00; küpe 168/122/144/31/149/186/28/32/180/902/121 kohortunun PG#1'i 10-04 |

### 3.2 Anomaliler ve Notlar

- **A1 — Küpe 51 (Düve Küçük, doğum 2025-11-17, kural günü 2026-12-08):** kural gününden ~3 ay önce 09-13'te vaka açıldı (elle yol; §18.4 bilinçli serbest), 4 ilaç günü uygulandı, TAI görevi 09-23 07:30'da iptal edildi, tohumlama hiç girilmedi, vaka 10:13'te sebepsiz kapatıldı. Tam bir ilaç-israfı + kayıp döngü örneği. [OBSERVED]
- **A2 — Kısır trio (184/199/208):** 09-23 22:56 ACIK-DISI otomatik kurulumu kısır hayvanlara da vaka açtırdı; 09-25 13:16 temizliğinde ERKEN_KAPANIS ile kapatıldı (kısır hard-block 20260926000002'den önceki durum). [OBSERVED]
- **A3 — Test inek 3 (ba865063):** 3 vakalık kaotik test döngüsü (başlat→PG kapanış→yeni vaka→IPTAL→iptal edilen yeniden-başlat görevi→görevsiz Campus tohumlaması 09-27 Bekliyor). Şu an aktif ovsync vakası yok. [OBSERVED]
- **A4 — Küpe 121 (aktif vaka #12):** hayvanda 09-17 tarihli **Bekliyor** tohumlama dururken 09-27'de yeni ovsync vakası açıldı (elle görünüyor; §18.12'deki Bekliyor muafiyeti otomatik yollar için). [OBSERVED]
- **A5 — Görev/tohumlama uyumsuzluğu (09-13 kohortu):** 121 ve 135'te TAI görevi "iptal+completed" kapandı ama tohumlama girildi (09-17/09-21, hedeften erken); 23 ve 02'de TAI görevi iptal edilip tohumlama 09-23'te görevsiz girildi. [OBSERVED]
- **A6 — Sorgu aracı notu:** `gorev_tipi=eq.TOUMLAMA_PLANLI` PostgREST filtresi bu oturumda 0 satır döndürdü (OVSYNC_BASLAT/TEDAVI_GUN aynı söz dizimiyle çalışıyor); veri `kaynak=like.*TOHUMLAMA*` ile alındı (39 satır). Nedeni çözülemedi — araç/bağlantı davranışı. [OBSERVED]
- **A7 — Küpe 19 (a89d77a1):** vaka açılış günü (09-23) tohumlama girildi, protokolün gün2-4'ü hiç uygulanamadan gelecek tarihli günler tamamlandı=true ile toplu kapatıldı; vaka aynı gün null reason ile kapandı. [OBSERVED]
- **A8 — `hayvanlar.tohumlama_durumu` tutarsız:** "gebe"/"Gebe"/"Boş" karışık; küpe 168'de "gebe" yazıyor ama aktif ovsync vakası açık (alan zaten gebelik otoritesi değil, §18.11). [OBSERVED]
- **A9 — Başlatma/kaydırma gecikmesi:** 09-24 hedefli 9 vakanın günleri 09-25 (+2) ve 09-27 (+1) kaydırmalarıyla fiilen 09-27'ye taşındı (18 VAKA_KAYDIR kaydı); gün1 o gün toplu uygulandı. Protokol içi gecikme yok; başlangıç hedefe göre 3 gün kaydı. [OBSERVED]
- **A10 — protokol_instance:** görevlerde protokol_instance_id dolu, ancak `alttip='OVSYNC'` instance 0 satır; gözlenen instance'lar UREME/DOGUM tipinde. Ovsync instance satırlarının gerçek alttip değeri doğrulanamadı — **bilinmiyor**. [OBSERVED]

### 3.3 Kaynak Sorgular (he salt-okuma SELECT)

1. `cases?protocol_family=not.is.null` (35) · 2. `protokol_ayar` (bayrak=1) · 3. `tedavi_sablonu` (1 OVSYNC şablonu) · 4. `sablon_hastalik_eslem` · 5. `hayvanlar?id=in.(31)` · 6. `gorev_log?gorev_tipi=eq.OVSYNC_BASLAT` (44) · 7. `tohumlama?hayvan_id=in.(31)` · 8-9. `treatment_days?case_id=in.(…)` (aktif 12 + kapalı 23) · 10. `diseases?id=c346e115…` · 11. `drug_products?id=in.(Buserin,PGs)` · 12. `islem_log?tip=eq.VAKA_KAYDIR` (18) · 13. `gorev_log?hayvan_id=in.(12 aktif)&tamamlandi=eq.false` · 14. `gorev_log?kaynak=like.*TOHUMLAMA*` (39 TAI görevi) · 15. `protokol_instance?alttip=eq.OVSYNC` (0)

Kod referansları: `js/ui.js` (ovsyncBaslat 1799, ovsyncIptal 1830, _ovsyncBaslatKilitHtml 1736, ovsyncAcilisOzeti 1921), `js/forms.js` (_ovsyncAileHastalikIdleri 598), `.harness/references/domain-rules.md` §18, `.harness/references/rpc-reference.md`.
