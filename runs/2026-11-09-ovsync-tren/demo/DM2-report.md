⟦ss-sub model=sonnet effort=medium rol=ss-worker iş=ovsync-tren N6 DM2: 14 maddelik UI kapısı + zaman senaryosu vitrini demo yürüyüşü⟧
sonuc: KISMI
progress: yürüyüş tamam (14 madde × mobil 390×844 + masa 1280×800); 13/14 PASS, madde 7 FAIL + zaman vitrini 1 FAIL (ZV1b). Kod düzeltmesi bu brief'te yok → root kararı. Vitrin demoda duruyor, X kopyaları temizlendi.
BOYUT: bütçe betikler repo dışı ($HOME/tmp/dm2) · gerçek üretim kodu 0 satır · bütçe içinde

## Özet
- 14 madde: **13 PASS / 1 FAIL** (madde 7). Zaman vitrini: ZV1, ZV2-03..07, ZV3, 11r, ANLAM PASS; **ZV1b FAIL**.
- Koşum: 2026-11-09 20:3x–22:xx TR, demo `vtzqjmazsvurxdeondmi`, dal kodu `ovsync-tren` HEAD 7f7b75f yerel sunucudan (:8138), Playwright 1.58.2 (docker), tarayıcı UTC (TR 00:00 öncesi; UI bugünü = TR bugünü = 2026-11-09). Bayrak açık, çapa 2026-11-12 (Per) — koşum öncesi ve sonrası aynı (MEASURED, protokol_ayar okundu).
- Konsol hatası: yalnız madde 10 (çevrimdışı; `ERR_INTERNET_DISCONNECTED` + realtime WebSocket — beklenen). Diğer maddelerde 0 (MEASURED).
- Anlam ölçümü: boş/—/bilinmiyor oranı Ovsync ekranı 0/295, Görevler 1/226 (0.004), vaka kartı 0/49 → çoğunluk-boş yok (MEASURED).

## Gelen iş denetimi
1. Brief'in yolları `ovsync-tren` worktree'sinde, cwd `tedavi-arge`; yazma yalnız brief listesindeki `ovsync-tren/.../DM2-report.md` + `ui-kapisi/` altına yapıldı. Bulgu değil, not.
2. Madde 4–6 "tek onay" adımı: toptan erteleme onayı TÜM treni (gerçek demo hayvanları dahil, ör. 5708) ve çapayı kaydırır; X kopyası ile izole edilemez. Bu yüzden 4–6 yalnız önizleme + Onay düğmesinin durumu (pasif/aktif) ölçüldü, onaya BASILMADI. Onay yolu DM1 e2e'de PASS (toptan +1/+3). (assumption)
3. Bugün Pazartesi; ▶ Başlat penceresi `hedef−2 ≤ bugün`. Gerçek akışta görev doğumu tren−2'de (Salı) başlar; "bekleyen" vitrin görevi için hedef=bugün (09.11) kullanıldı → ekranda ritim dışı başlıkta görünür (Pzt 9 Kas). Bu bir seed yapaylığıdır (gerçekte yeni görev doğrudan Per 12 Kas'a hedeflenir). (assumption)
4. Vitrin vakaları geriye tarihli kuruldu: `create_case` bugün açar, `tedavi_sablon_uygula(p_baslangic_tarihi=geçmiş)` günleri geriye çeker → vaka kartı başlığında "📅 09.11.2026" (açılış), Gün 1 = 05.11 görünür. Üretim akışında (▶ Başlat) başlık D0'dır; kart başlığı farkı seed yapaylığıdır, bulgu SAYILMADI. (assumption)
5. Doğrudan tablo INSERT yalnız şu iki yerde: `hayvanlar` (RPC yok) ve açık `OVSYNC_BASLAT` `gorev_log` satırı (hedefi serbest seçen herkese açık RPC yok: `_ovsync_baslat_gorev_kur` iç/ACL kapalı; DM1 spec aynı yolu kullanıyor). Diğer her şey sunucu RPC'siyle: `create_case`, `tedavi_sablon_uygula`, `seans_tamamla`, `start_first_service_protocol(p_bagimsiz)`, `ovsync_hastalik_gunu_ekle`, `ovsync_hayvan_ertele`, `dogum_kaydet`, `tedavi_sablon_tohumlama_gorev_ekle`. Seans zaman damgası geriye çekmek için `treatment_day_uygulamalar.uygulama_tamamlandi_at` UPDATE (DM1 kalıbı).

## Vitrin (demoda KALICI) — kurulum ve temizlik
- Kurulum: `~/tmp/dm2/vitrin.mjs` (+ düzeltme `~/tmp/dm2/fix07.mjs`); kimlik çıktısı `~/tmp/dm2/vitrin-idler.json`.
- Temizlik (KOŞULMADI): `node ~/tmp/dm2/temizle.mjs ALL` (tüm `E2E-TREN-UI-%`; hayvan FK nedeniyle silinemezse Satıldı'ya çeker — DM1 kalıbı). X kopyaları için `node ~/tmp/dm2/temizle.mjs X` (koşuldu: 6 hayvan temizlendi, `E2E-TREN-UI-X-%` Aktif kalmadı — MEASURED).

| küpe | hayvan_id | vaka/görev id | rol (beklenen kural) |
|---|---|---|---|
| E2E-TREN-UI-01 | e2e40000-0000-4000-8000-000000000001 | 67876ada-8329-4e40-b7a3-9b2b0141b3c8 | aşama 0, Per 12 Kas treni (OVSYNC_BASLAT hedef 12.11) |
| E2E-TREN-UI-02 | e2e40000-0000-4000-8000-000000000002 | 32a96a51-e6c0-42c4-9438-abe5299e12de | aşama 0, Per 12 Kas treni |
| E2E-TREN-UI-03 | e2e40000-0000-4000-8000-000000000003 | a256ed4c-5be4-46c8-9d9a-f3712f5d4aba | geçen hafta treni (Per 5 Kas), aşama 1, PG1 12.11, pg_pay=1 |
| E2E-TREN-UI-04 | e2e40000-0000-4000-8000-000000000004 | b203d3e1-0d0c-4906-ba95-27fc9612840d | geçen hafta treni (Per 5 Kas), aşama 2 (PG1 3 gün erken yapıldı), PG48 seçeneği |
| E2E-TREN-UI-05 | e2e40000-0000-4000-8000-000000000005 | d20e4e17-d807-40e3-8d14-d81c1d4a1434 | bağımsız başlatılmış (▶ Başlat, p_bagimsiz=true, D0 bugün) |
| E2E-TREN-UI-06 | e2e40000-0000-4000-8000-000000000006 | fb81816c-2d49-4dcc-9f8e-ad691dd669ab | hastalık günü girilmiş → bağımsız (K9), PG1 12.11 |
| E2E-TREN-UI-07 | e2e40000-0000-4000-8000-000000000007 | 5faa4b58-7e5a-4f35-9e26-628297a949ff | ritim dışı (aşama 1 + ovsync_hayvan_ertele(+1) → etiket Cum 6 Kas) |
| E2E-TREN-UI-08 | e2e40000-0000-4000-8000-000000000008 | 5903a30e-1ac6-4950-9a48-551a3d0a2e06 | başlatma bekleyen OVSYNC_BASLAT (hedef bugün 09.11) — madde 2/10 |
| E2E-TREN-UI-D2 | e2e40000-0000-4000-8000-000000000009 |  | doğum 2 gün önce (🔔 d2) |
| E2E-TREN-UI-D25 | e2e40000-0000-4000-8000-000000000010 |  | doğum 25 gün önce (🔔 d25) |

Not: D2/D25 doğumları `dogum_kaydet` ile buzağı kaydı da oluşturdu (`E2E-TREN-UI-D2-BUZ`, `-D25-BUZ`); temizlik betiği kapsar. Bu iki hayvan için `dogum_kaydet` eski DOGUM_PROTOKOL görevlerini de (12 görev) doğurdu (bkz. madde 11 notu).
Önceden demoda: 4 aktif OVSYNC vakası + 25 açık OVSYNC_BASLAT (gerçek demo verisi) → Ovsync ekranında vitrinle birlikte görünür; toplam açık OVSYNC_BASLAT şimdi 28 (25 + 01, 02, 08).

## 14 madde (G-UI) — mobil 390×844 + masa 1280×800
PNG dizini: `~/.herdr/worktrees/egesut-erp1/ovsync-tren/runs/2026-11-09-ovsync-tren/demo/ui-kapisi/` (adlar `<madde>-<mobil|masa>-<ad>.png`). "Karar" = sahibin sorusuna ekrandan okunan cevap.

| # | Adım | Sonuç | Karar sorusu → ekrandan okunan | PNG |
|---|---|---|---|---|
| 1 | Ovsync ekranı aç | PASS (mobil ✓ / masa ✓) | Bu hafta hangi gün kaç hayvanla iş var? → Ekrandan: "Tren · Per 12 Kas · 3 hayvan" ve "Tren · Pzt 9 Kas · 2 hayvan · ritim dışı · bugün: başlangıç günü" okunuyor; Bağımsız bölümü ayrı. | 01-masa-ovsync.png, 01-mobil-ovsync.png |
| 2 | Başlatma bekleyen hayvanda ▶ Başlat | PASS (mobil ✓ / masa ✓) | Bu hayvan hangi güne biner? → Modal: "▶ Ovsync başlat — E2E-TREN-UI-08 | Görev Pzt 9 Kas yerine Per 12 Kas trenine taşınır. | Kural günü Cmt 18 Tem · tren her Perşembe | 🚆 Trene bin — Per 12 Kas (3" → hayvan Per 12 Kas trenine biner, sayı yazıyor. | 02-masa-k8-modal.png, 02-mobil-k8-modal.png |
| 3 | Trene bin → onay | PASS (mobil ✓ / masa ✓) | Hayvan doğru trende mi → Ekran: "Tren · Per 12 Kas · 3 hayvan" → "Tren · Per 12 Kas · 4 hayvan"; X-1 satırı "(X-1 adı Ovsync ekranında yok; yalnız başlık sayısı +1)" (görev kartı hedefi 2026-11-12 = tren günü; DB görev hedefi 2026-11-09→2026-11-12). | 03-masa-ovsync-X1-gorunum.png, 03-masa-ovsync-X1.png, 03-mobil-ovsync-X1-gorunum.png, 03-mobil-ovsync-X1.png |
| 4 | Tren gününü ertele… N=1 önizleme | PASS (mobil ✓ / masa ✓) | Ertelersem kim ne olur? → Her hayvan için: 03 aşama 1 · 1. uygulama yapıldıkayar → Cum 13 Kas; 04 aşama 2 · PG yapıldıseçim gerekli PG yapıldı, ertelenemez. Seçin: (a) PG1 + 48 s'te tohumla (b) Baştan başlat → Cum 13 Kas treni; 01 aşama 0 · başlamadıkayar → Cum 13 Kas; 02 aşama 0 · baş | 04-masa-toptan-n1.png, 04-mobil-toptan-n1.png |
| 5 | N=3 önizleme | PASS (mobil ✓ / masa ✓) | Tolerans aşımı açıkça görünüyor mu → Ekran: "E2E-TREN-UI-03 aşama 1 · 1. uygulama yapıldıbaştan başlar → Paz 15 Kas PG erteleme payı yetmiyor. Vaka kapanır, yeni trende yeniden başlar." — tolerans aşımı açıkça yazıyor ("PG erteleme payı yetmiyor..."). | 05-masa-toptan-n3.png, 05-mobil-toptan-n3.png |
| 6 | Aşama 2 hayvanlı trende önizleme | PASS (mobil ✓ / masa ✓) | Seçim zorunluluğu anlaşılıyor mu → Ekran: "E2E-TREN-UI-04 aşama 2 · PG yapıldıseçim gerekli PG yapıldı, ertelenemez. Seçin: (a) PG1 + 48 s'te tohumla (b) Baştan başlat → Paz 15 Kas treni"; Onay düğmesi pasif → seçmeden ilerlenmiyor. | 06-masa-toptan-asama2.png, 06-mobil-toptan-asama2.png |
| 7 | Görevler ekranında Ovsync TAI | FAIL (mobil ✗ / masa ✗) | Nereden düzenleyeceğim belli mi → ASSERT: link tıklanınca görev detay sheet'i de açıldı: E2E-TREN-UI-X-5 | Planlı tohumlama | 📅 09.11.2026 | 🏷 TOHUMLAMA PLANLI | 🐄 Tohumlamayı Kaydet | ✏️ Görevi Düzenle | 🗑 Görevi İptal Et | Kapat | 07-masa-FAIL.png, 07-mobil-FAIL.png |
| 8 | Çoklu kaydır (Ovsync + mastit) | PASS (mobil ✓ / masa ✓) | Atlanan görev sessiz kalmıyor mu → Ekran: "⏭ 1 Ovsync görevi atlandı (E2E-TREN-UI-X-5)" + "Ovsync ekranı →" bağlantısı; mastit görevi 2026-11-09→2026-11-10, Ovsync görevi 2026-11-09 (değişmedi). | 08-masa-onay.png, 08-masa-sonuc.png, 08-mobil-onay.png, 08-mobil-sonuc.png |
| 9 | Aşama 2 vaka kartı | PASS (mobil ✓ / masa ✓) | Doğru seçenekler mi → Sheet: "🚆 Ovsync kaydırma | PG yapıldı · erteleme yok | ≈ 11 Kas Çar 10:00 | PG1 + 48 s'te tohumla | Baştan başlat | Vazgeç" | 09-masa-kaydir-sheet.png, 09-mobil-kaydir-sheet.png |
| 10 | Çevrimdışı | PASS (mobil ✓ / masa ✓) | Çevrimdışı yanlış iş yazılabiliyor mu → Çevrimdışı: Ertele/Baştan başlat düğmesi yok (0/0); ▶ Başlat toast'ı "İnternet yok"; kuyruk {"egesut_v12":0} (değişmedi) → yanlış iş yazılamıyor. | 10-masa-baslat-offline.png, 10-mobil-baslat-offline.png |
| 11 | 🔔 panel d2/d25 | PASS (mobil ✓ / masa ✓) | Hatırlatma görülüyor mu, görev listesini kirletiyor mu → Panel: "E2E-TREN-UI-D2 · doğumun 2. günü | PG hatırlatması · doğum Cmt 7 Kas" ; "E2E-TREN-UI-D25 · doğumun 25. günü | PG hatırlatması · doğum Per 15 Eki" (kapatma/etkileşim düğmesi yok). Not: aynı hayvanlar için eski DOGUM_PROTOKOL satırı 11 adet de ayrıca lis | 11-masa-bildirim-hatirlatma.png, 11-mobil-bildirim-hatirlatma.png |
| 12 | Renk taraması | PASS (mobil ✓ / masa ✓) | UI renk minimal kuralı → Hesaplanmış background-color: tren-yeni öğelerde nötr dışı zemin/şerit 0 (462 öğe). Tren dışı (eski Ovsync takip) 50 renkli öğe: ovs-kpa-c.ovs-one, ovs-kart.ovs-geciken-kart, ovs-rozet.ovs-rozet-kayma, ovs-etiket, ovs-kart.ovs-bugun-kart, ovs-rozet.ovs-rozet-m | 12a-masa-ovsync-renk.png, 12a-mobil-ovsync-renk.png |
| 13 | Vaka Aç → Ovsync şablonu (V3) | PASS (mobil ✓ / masa ✓) | Elle açtığım Ovsync hangi gün başlar → Kaydet'e basınca vaka kaydedilmeden modal: "▶ Ovsync başlat — E2E-TREN-UI-X-2 | Kural günü Cmt 18 Tem · tren her Perşembe | 🚆 Trene bin — Per 12 Kas (5 hayvan) | Bu trende: 5708 · E2E-TREN-UI-01 · E2E-TREN-UI-02 ·"; seçince vaka kartında ilk gün 12 Kas (DB gün | 13-masa-k8-modal.png, 13-masa-vaka-karti.png, 13-mobil-k8-modal.png, 13-mobil-vaka-karti.png |
| 14 | Boş → Ovsync uygula (G7) | PASS (mobil ✓ / masa ✓) | Boş sonrası hayvan treni bekliyor mu, kaç gün → Modal: "▶ Ovsync başlat | tren her Perşembe | 🚆 Trene bin — Per 12 Kas (4 hayvan) | Bu trende: 5708 · E2E-TREN-UI-01 · E2E-TREN-UI-02 · E2E-TREN-UI-X-1. Per 12 Kas'ta onlarla birlikte başlar (3 gün sonra). E"; Trene bin sonrası görev hedefi 2026-11-12 (Per 12  Bağımsız → vaka bugün (2026-11-09) başladı, bağımsız=true. | 14a-masa-k8.png, 14a-mobil-k8.png, 14b-masa-sonrasi.png, 14b-mobil-sonrasi.png |

Not (madde 11): 🔔 panelde "💉 Doğum sonrası PG hatırlatma (2)" satırları görünür, düğme/tıklama yok, Görevler listesinde D2/D25 için PG kartı çıkmaz (11b PASS). OBSERVED: aynı iki hayvan için eski `DOGUM_PROTOKOL` satırları (11 adet, "2. Gün PG · 0 gün gecikmiş", "25. Gün PG · 23 gün gecikmiş" dahil) panelde ayrıca durur → PG aynı panelde iki ayrı satırda iki kez anılır. Bayrak (`dogum_sonrasi_pg_gorev_aktif`=0) davranışı budur; sahibe bilgi.
Not (madde 12): kapsam Ovsync ekranı (462 görünür öğe). Tren-yeni sınıflarda nötr dışı zemin/şerit 0. Tren DIŞI (eski Ovsync takip) 50 öğede renkli zemin/sol şerit var (`ovs-geciken-kart` kalın sol şerit, `ovs-kpa-c.ovs-one` renkli zemin, `ovs-rozet-*`, `ovs-etiket`, `ovs-bugun-kart`) — bu tren işinden önce vardı; renk-minimal kuralıyla çelişir, sahibe bilgi (detay `sonuc.json` 12a-detay).
Not (madde 3): X-1 görevi hedef bugün olduğu için "Trene bin" vakayı değil GÖREVİ Per 12 Kas'a taşır ("Görev Pzt 9 Kas yerine Per 12 Kas trenine taşınır" modalda yazıyor); başlık 3→4 hayvan oldu. Ekranda hayvan adı başlık altında yok (bkz. BULGU-2). Vaka D0=tren günü sonucu madde 13'te (V3) ve DM1 e2e'de doğrulandı.
Not (madde 13, masaüstü): Vaka Aç modalındaki hastalık listesi uygulama açıldıktan ~11 sn sonra hâlâ boştu (modal açıldığında); veri çekimi tamamlanınca (≈90 sn) doluydu → test bekledi. OBSERVED, tren değişikliğiyle ilgisi yok.

## BULGU listesi
- **BULGU-1 (madde 7, FAIL, mobil+masa):** madde 7 — beklenen: "Ertele yok, 'Ovsync ekranında düzenle →' var; tıklayınca ilgili tren" ≠ görülen: Ertele yok, link var ✓; link tıklanınca Ovsync ekranı açılıyor ama (a) aynı tıklama görev kartının `onclick`'ine de düşüp **"Planlı tohumlama — Tohumlamayı Kaydet / Görevi Düzenle / Görevi İptal Et" alt sayfasını** açıyor (Ovsync ekranının üstünde), (b) `window._ovsyncOdakHayvan` yazılıyor ama hiçbir yerde okunmuyor → ekran ilgili tren/hayvana kaymıyor/vurgulamıyor (X-5 satırı görünür alanın 2746 px altında). PNG `07-mobil-FAIL.png`, `07-masa-FAIL.png`, ayrıntı `sonuc.json` 07-detay. Tahmini dosya:satır: `js/ovsync-tren.js:548-551` (düğmede `stopPropagation` yok; kart `onclick` bubbling), `js/ovsync-tren.js:538-541` (odak değişkeni tüketicisi yok; `grep _ovsyncOdakHayvan js/` = yalnız bu satır), `js/ui.js:2396-2397` (document dinleyicisi).
- **BULGU-2 (madde 1 / zaman vitrini ZV1b, FAIL, mobil+masa):** "bu hafta hangi gün kaç hayvanla ne iş var" — beklenen (R7/K2/K4/K5): Per 12 Kas'ta işe giren 4 hayvan = GnRH1 3 (01, 02, 5708) + PG1 1 (03) ≠ görülen: başlık "Tren · Per 12 Kas · 3 hayvan" (yalnız D0 kümesi) ve bu başlığın ALTINDA hayvan satırı YOK (aşama-0 üyeler "S3 · Başlatılmayı bekleyenler" bölümünde, 01/02 "tümü (29)" arkasında); PG1 işi (03: "PG 12.11: PG'yi ertele") Per 12 Kas değil **"Tren · Per 5 Kas · 2 hayvan"** başlığı altında. Sahip tek bakışta "Perşembe 4 hayvan: 3 GnRH1 + 1 PG" okuyamıyor; hangi 3 hayvanın trende olduğunu da başlıktan görmüyor. PNG `ZV1b-mobil-FAIL.png`, `ZV1b-masa-FAIL.png`, `01-mobil-ovsync.png`. Tahmini dosya:satır: `js/ui.js:2090-2120` (`_ovsyncTrenGovdeHtml`: gruplar yalnız S0/S1 satırlarını `ovsyncTrenGrupla` ile gruplar), `js/ovsync-tren.js:~395-420` (`ovsyncTrenGrupla`; aşama-0 üyeler satır üretmez). Not: madde 1 PASS'ı planın kendi tanımına göre ("Tren · <gün> · N hayvan · bugün: <iş>" başlığı, tarih sırası, bağımsız ayrı) verildi; BULGU-2 zaman senaryosu ekinin sorusuna (UB-ekler N6 eki madde 2) göredir — root yorumu bekler.
- OBSERVED (bulgu değil): 🔔 PG hatırlatma + eski DOGUM_PROTOKOL PG satırı çift anılıyor (madde 11 notu); eski Ovsync takip'te renkli zemin/şerit (madde 12 notu); ilk render'da (IDB `cases` pull'u bitmeden) satırlarda "vaka bağlantısı bilinmiyor" etiketi — pull sonrası 0/5 (INFERRED, `_ovsyncS0SatirHtml` `bag.vakaAktif`; sahip yavaş açılışta kısa süre görebilir).

## Zaman senaryosu vitrini (UB-ekler N6 eki madde 2)
Beklenen kaynak: PLAN R1–R20, design K1–K11. Hayvan başına (Ovsync ekranı + vaka kartı + Görevler):

| hayvan | beklenen (kural) | ekrandan okunan | sonuç |
|---|---|---|---|
| 01, 02 (aşama 0) | Per 12 Kas trenine GnRH1 (R7-i, K2, K4); başlık sayısına girer | başlık "Per 12 Kas · 3 hayvan" (01, 02, 5708) | PASS (sayı) / FAIL (üyeler başlık altında yok — BULGU-2) |
| 03 (aşama 1) | D0 Per 5 Kas etiketi, PG1 12.11, ≤1 gün ertelenebilir (R3, R18, K5) | "Per 5 Kas · 2 hayvan" altında, "PG 12.11: PG'yi ertele · en çok +1 gün"; vaka kartı Gün1 05.11 ✓, Gün2 12.11 | PASS |
| 04 (aşama 2) | ertelenemez; (a) PG1+48 s ya da (b) baştan (K6) | "PG yapıldı · erteleme yok: PG1 + 48 s'te tohumla · Baştan başlat ≈ 11 Kas Çar 10:00"; TAI 11.11 | PASS |
| 05 (bağımsız) | tren dışı, D0 bugün (R4, K8) | "Bağımsız" bölümünde, "GnRH1 09.11", vaka kartı 9 Kas | PASS |
| 06 (hastalık günü) | trenden ayrılır, bağımsız (K9, §18.18) | "Bağımsız" bölümünde, "PG 12.11" | PASS |
| 07 (ritim dışı) | etiket ritimde değil → toptana girmez, kendi başlığı (R3, R7, R18) | "Tren · Cum 6 Kas · 1 hayvan · ritim dışı" + "Toptan ertelemeye girmez; kendi satırından düzenlenir" | PASS |
| 08 (bekleyen) | ▶ Başlat → hangi gün (K8, R8) | modal "Görev Pzt 9 Kas yerine Per 12 Kas trenine taşınır"; Görevler bugün listesinde görünür | PASS |
| D2, D25 | 🔔 d2/d25 satırı (R15) | "doğumun 2. günü", "doğumun 25. günü" | PASS |
| Per 12 Kas günü toplam iş | 4 hayvan: 3 GnRH1 + 1 PG1 (R7) | başlık 3; PG1 başka başlıkta | FAIL (BULGU-2) |
| Görevler "bugün" | 05 + 08 görünür, 06 (PG1 12.11) görünmez (K10/R8) | 05:true, 08:true, 06:false | PASS |

Ayrıntılı satır dökümü (mobil+masa, ZV kodlarıyla):
| kod | görünüm | sonuç | adım | okunan | PNG |
|---|---|---|---|---|---|
| ZV1 | mobil | PASS | Zaman vitrini: Ovsync ekranı satırları | Hayvan→başlık haritası: {"03":"Tren · Per 5 Kas · 2 hayvan","04":"Tren · Per 5 Kas · 2 hayvan","07":"Tren · Cum 6 Kas · 1 hayvan · ritim dışı","05":"Bağımsız","06":"Bağımsız","X-5":"Bağımsız","08":"S3 · Başlatılmayı bekleyenler","X-1":"S3 · Başlatılmayı bekleyenler"} | ZV1-mobil-vitrin-ovsync.png |
| ZV1 | masa | PASS | Zaman vitrini: Ovsync ekranı satırları | Hayvan→başlık haritası: {"03":"Tren · Per 5 Kas · 2 hayvan","04":"Tren · Per 5 Kas · 2 hayvan","07":"Tren · Cum 6 Kas · 1 hayvan · ritim dışı","05":"Bağımsız","06":"Bağımsız","X-5":"Bağımsız","08":"S3 · Başlatılmayı bekleyenler","X-1":"S3 · Başlatılmayı bekleyenler"} | ZV1-masa-vitrin-ovsync.png |
| ZV1b | mobil | FAIL | Zaman vitrini: Per 12 Kas günü iş sayısı (beklenen R7: GnRH1 3 (01,02,5708) + PG1 1 (03)) | ASSERT: 12 Kas başlığı altında hayvan satırı yok (n=0); aşama-0 hayvanlar "Başlatılmayı bekleyenler"de, PG1 ("PG 12.11" satır sayısı 0) 5 Kas başlığı altında | ZV1b-mobil-FAIL.png |
| ZV1b | masa | FAIL | Zaman vitrini: Per 12 Kas günü iş sayısı (beklenen R7: GnRH1 3 (01,02,5708) + PG1 1 (03)) | ASSERT: 12 Kas başlığı altında hayvan satırı yok (n=0); aşama-0 hayvanlar "Başlatılmayı bekleyenler"de, PG1 ("PG 12.11" satır sayısı 0) 5 Kas başlığı altında | ZV1b-masa-FAIL.png |
| ZV2-03 | mobil | PASS | Vaka kartı: vitrin 03 | Beklenen (R3/R6/K5): D0 Per 5 Kas (GnRH1 yapıldı), PG1 Per 12 Kas. Ekran: "E2E-TREN-UI-03 | 🏥 Ovsync Protokol | Aktif | 📂 Üreme | 📅 09.11.2026 | ↩ Geri Al | E2E-TREN-UI-03 | ➕ Tedavi Günü Ekle | 🐄 Planlı Tohumlama Ekle | 📋 Şablondan Plan Ekle ▾ | ⏩ Kalan Günleri Kaydır | 🛑 Protokolü İptal" (boş/bilinmiyor 0/49) | ZV2-03-mobil-vaka-karti.png |
| ZV2-03 | masa | PASS | Vaka kartı: vitrin 03 | Beklenen (R3/R6/K5): D0 Per 5 Kas (GnRH1 yapıldı), PG1 Per 12 Kas. Ekran: "E2E-TREN-UI-03 | 🏥 Ovsync Protokol | Aktif | 📂 Üreme | 📅 09.11.2026 | ↩ Geri Al | E2E-TREN-UI-03 | ➕ Tedavi Günü Ekle | 🐄 Planlı Tohumlama Ekle | 📋 Şablondan Plan Ekle ▾ | ⏩ Kalan Günleri Kaydır | 🛑 Protokolü İptal" (boş/bilinmiyor 0/49) | ZV2-03-masa-vaka-karti.png |
| ZV2-04 | mobil | PASS | Vaka kartı: vitrin 04 | Beklenen (R6/K6): aşama 2: GnRH1 5 Kas; PG2 13 Kas. Ekran: "E2E-TREN-UI-04 | 🏥 Ovsync Protokol | Aktif | 📂 Üreme | 📅 09.11.2026 | ↩ Geri Al | E2E-TREN-UI-04 | ➕ Tedavi Günü Ekle | 🐄 Planlı Tohumlama Ekle | 📋 Şablondan Plan Ekle ▾ | ⏩ Kalan Günleri Kaydır | 🛑 Protokolü İptal" (boş/bilinmiyor 0/34) | ZV2-04-mobil-vaka-karti.png |
| ZV2-04 | masa | PASS | Vaka kartı: vitrin 04 | Beklenen (R6/K6): aşama 2: GnRH1 5 Kas; PG2 13 Kas. Ekran: "E2E-TREN-UI-04 | 🏥 Ovsync Protokol | Aktif | 📂 Üreme | 📅 09.11.2026 | ↩ Geri Al | E2E-TREN-UI-04 | ➕ Tedavi Günü Ekle | 🐄 Planlı Tohumlama Ekle | 📋 Şablondan Plan Ekle ▾ | ⏩ Kalan Günleri Kaydır | 🛑 Protokolü İptal" (boş/bilinmiyor 0/34) | ZV2-04-masa-vaka-karti.png |
| ZV2-05 | mobil | PASS | Vaka kartı: vitrin 05 (bağımsız başlatılmış) | Beklenen (R4/K8 Bağımsız → bugün): D0 9 Kas. Ekran: "E2E-TREN-UI-05 | 🏥 Ovsync Protokol | Aktif | 📂 Üreme | 📅 09.11.2026 | ↩ Geri Al | İlk tohumlama zinciri | ➕ Tedavi Günü Ekle | 🐄 Planlı Tohumlama Ekle | 📋 Şablondan Plan Ekle ▾ | ⏩ Kalan Günleri Kaydır | 🛑 Protokol" | ZV2-05-mobil-vaka-karti.png |
| ZV2-05 | masa | PASS | Vaka kartı: vitrin 05 (bağımsız başlatılmış) | Beklenen (R4/K8 Bağımsız → bugün): D0 9 Kas. Ekran: "E2E-TREN-UI-05 | 🏥 Ovsync Protokol | Aktif | 📂 Üreme | 📅 09.11.2026 | ↩ Geri Al | İlk tohumlama zinciri | ➕ Tedavi Günü Ekle | 🐄 Planlı Tohumlama Ekle | 📋 Şablondan Plan Ekle ▾ | ⏩ Kalan Günleri Kaydır | 🛑 Protokol" | ZV2-05-masa-vaka-karti.png |
| ZV2-06 | mobil | PASS | Vaka kartı: vitrin 06 | Beklenen (K9/§18.18): hastalık günü eklendi → bağımsız; PG1 12 Kas. Ekran: "E2E-TREN-UI-06 | 🏥 Ovsync Protokol | Aktif | 📂 Üreme | 📅 09.11.2026 | ↩ Geri Al | E2E-TREN-UI-06 | ➕ Tedavi Günü Ekle | 🐄 Planlı Tohumlama Ekle | 📋 Şablondan Plan Ekle ▾ | ⏩ Kalan Günleri Kaydır | 🛑 Protokolü İptal" (boş/bilinmiyor 0/52) | ZV2-06-mobil-vaka-karti.png |
| ZV2-06 | masa | PASS | Vaka kartı: vitrin 06 | Beklenen (K9/§18.18): hastalık günü eklendi → bağımsız; PG1 12 Kas. Ekran: "E2E-TREN-UI-06 | 🏥 Ovsync Protokol | Aktif | 📂 Üreme | 📅 09.11.2026 | ↩ Geri Al | E2E-TREN-UI-06 | ➕ Tedavi Günü Ekle | 🐄 Planlı Tohumlama Ekle | 📋 Şablondan Plan Ekle ▾ | ⏩ Kalan Günleri Kaydır | 🛑 Protokolü İptal" (boş/bilinmiyor 0/52) | ZV2-06-masa-vaka-karti.png |
| ZV2-07 | mobil | PASS | Vaka kartı: vitrin 07 | Beklenen (R3/R18/K5): PG1 +1 gün (13 Kas), ritim dışı. Ekran: "E2E-TREN-UI-07 | 🏥 Ovsync Protokol | Aktif | 📂 Üreme | 📅 09.11.2026 | ↩ Geri Al | E2E-TREN-UI-07 | ➕ Tedavi Günü Ekle | 🐄 Planlı Tohumlama Ekle | 📋 Şablondan Plan Ekle ▾ | ⏩ Kalan Günleri Kaydır | 🛑 Protokolü İptal" (boş/bilinmiyor 0/34) | ZV2-07-mobil-vaka-karti.png |
| ZV2-07 | masa | PASS | Vaka kartı: vitrin 07 | Beklenen (R3/R18/K5): PG1 +1 gün (13 Kas), ritim dışı. Ekran: "E2E-TREN-UI-07 | 🏥 Ovsync Protokol | Aktif | 📂 Üreme | 📅 09.11.2026 | ↩ Geri Al | E2E-TREN-UI-07 | ➕ Tedavi Günü Ekle | 🐄 Planlı Tohumlama Ekle | 📋 Şablondan Plan Ekle ▾ | ⏩ Kalan Günleri Kaydır | 🛑 Protokolü İptal" (boş/bilinmiyor 0/34) | ZV2-07-masa-vaka-karti.png |
| ZV3 | mobil | PASS | Görevler ekranı (bugün): vitrin hayvanları | Beklenen: bugün (9 Kas) 05 GnRH1 + 08 başlatma görünür, 06 (PG1 12 Kas) görünmez. Ekran: 05:true, 06:false, 08:true, D2:false | ZV3-mobil-gorevler.png |
| ZV3 | masa | PASS | Görevler ekranı (bugün): vitrin hayvanları | Beklenen: bugün (9 Kas) 05 GnRH1 + 08 başlatma görünür, 06 (PG1 12 Kas) görünmez. Ekran: 05:true, 06:false, 08:true, D2:false | ZV3-masa-gorevler.png |
| 11b | mobil | PASS | 🔔 hatırlatma görev listesini kirletmiyor | Görevler ekranında D2/D25 için PG kartı yok (hatırlatma yalnız 🔔). | 11b-mobil-gorevler.png |
| 11b | masa | PASS | 🔔 hatırlatma görev listesini kirletmiyor | Görevler ekranında D2/D25 için PG kartı yok (hatırlatma yalnız 🔔). | 11b-masa-gorevler.png |
| ANLAM | mobil | PASS | Anlam ölçümü: boş/—/bilinmiyor hücre oranı | Boş/—/bilinmiyor oranı: Ovsync 0/295 (0), Görevler 1/226 (0.004), vaka kartı 0/49 (0); "vaka bağlantısı bilinmiyor" 0 kartta (vitrin vakalı 0/5). | ANLAM-mobil-vaka-karti.png |
| ANLAM | masa | PASS | Anlam ölçümü: boş/—/bilinmiyor hücre oranı | Boş/—/bilinmiyor oranı: Ovsync 0/295 (0), Görevler 1/226 (0.004), vaka kartı 0/49 (0); "vaka bağlantısı bilinmiyor" 0 kartta (vitrin vakalı 0/5). | ANLAM-masa-vaka-karti.png |

## Kırıntılar
- assumption: madde 4–6 yalnız önizleme (onay tüm treni kaydırır); gerekçe "Gelen iş denetimi" 2.
- assumption: bekleyen görev hedefi=bugün seed yapaylığı; vaka kartı başlık tarihi seed yapaylığı.
- decision: madde 3 görevi-taşıma semantiği (hedef bugün, tren gelecek) beklenen kabul edildi; vaka D0=tren kanıtı madde 13 + DM1.
- open_item: BULGU-1 ve BULGU-2 için kod düzeltmesi root kararı (bu brief kod yazmaz).
- open_item: vitrin demoda kalıcı; sahip demosundan sonra `temizle.mjs ALL`.
- hijyen: betikler `~/tmp/dm2/` (`wlib.cjs`, `wA.cjs`, `wB.cjs`, `wZ.cjs`, `run.sh`, `lib.mjs`, `vitrin.mjs`, `xkur.mjs`, `temizle.mjs`); arka plan işi yok (chain betikleri bitti, sunucu run.sh içinde kapatılıyor).

## Run kanıtı

ls ~/.herdr/worktrees/egesut-erp1/ovsync-tren/runs/2026-11-09-ovsync-tren/demo/ui-kapisi/*.png | wc -l
rc: 0
```
68
```

grep -c "^| *[0-9]* *|.*PASS" ~/.herdr/worktrees/egesut-erp1/ovsync-tren/runs/2026-11-09-ovsync-tren/demo/DM2-report.md
rc: 0
```
13
```

## ROOT göz kontrolü (2026-11-09)
ZV1b-mobil-FAIL.png ↔ mockup 02a: tren başlıkları düz metin, "bugün: <iş>" yok, başlık altında kart yok, aşama aksiyonu kart dışında yetim, aşama 0 üyeler eski S3'te → madde 1 de görsel olarak FAIL sayılır (DOM ölçütü yetmedi). Sahibe demo VERİLMEZ. Düzeltme N4-F4 (Opus, MUSE-YEDEK): ui/N4-F4-brief.md. Sonra DM2 yalnız madde 1, 7 ve ZV1b yeniden.

## Tekrar koşumu (N4-F4 sonrası)

Dal kodu uç ddade2a (yerel sunucu), demo, mobil 390×844 + masa 1280×800, yalnız madde 1, madde 7, ZV1b. Mockup `02a-ovsync-tren-ekrani.png` ile `R-01-mobil-ovsync-ust.png` / `R-01-masa-ovsync-ust.png` Read ile karşılaştırıldı: kalın "Tren · gün · N hayvan · gün: iş" başlığı, kartlar başlık altında, aksiyon satırı kartın içinde, sağda tek "Tren gününü ertele…" (OBSERVED). Madde 7 için X-5 TAI kopyası kuruldu, sonda temizlendi (`E2E-TREN-UI-X-%` Aktif kalmadı).

| # | Madde | Sonuç | Ekrandan okunan karar cevabı | PNG |
|---|---|---|---|---|
| R-01 mobil | Madde 1 | PASS | Ekran: 8 tren bloğu, her başlıkta "gün: iş" ve N=kart sayısı (1/1/2/1/1/2/3/2); yetim satır 0; "Tren gününü ertele…" 1 adet ve "Tren · Per 12 Kas · 3 hayvan · Per 12 Kas: başlangıç günü Tren gününü ertele…" başlığında. | R-01-mobil-ovsync.png, R-01-mobil-ovsync-ust.png |
| R-01 masa | Madde 1 | PASS | Ekran: 8 tren bloğu, her başlıkta "gün: iş" ve N=kart sayısı (1/1/2/1/1/2/3/2); yetim satır 0; "Tren gününü ertele…" 1 adet ve "Tren · Per 12 Kas · 3 hayvan · Per 12 Kas: başlangıç günü Tren gününü ertele…" başlığında. | R-01-masa-ovsync.png, R-01-masa-ovsync-ust.png |
| R-07 mobil | Madde 7 | PASS | Link tıklandı: görev alt sayfası açılmadı; Ovsync ekranında X-5 kartı görünür alanda (üst 358px, alt 527px / 844px); kartta Ertele yok. | R-07-mobil-gorevler.png, R-07-mobil-ovsync.png |
| R-07 masa | Madde 7 | PASS | Link tıklandı: görev alt sayfası açılmadı; Ovsync ekranında X-5 kartı görünür alanda (üst 375px, alt 526px / 800px); kartta Ertele yok. | R-07-masa-gorevler.png, R-07-masa-ovsync.png |
| R-ZV1b mobil | ZV1b | PASS | Ekran: "Tren · Per 12 Kas · 3 hayvan · Per 12 Kas: başlangıç günü Tren gününü ertele…" (altında 3 kart) + "Tren · Per 5 Kas · 2 hayvan · Per 12 Kas: PG günü" → Per 12 Kas: 3 hayvan başlangıç + 5 Kas treninden 2 hayvan PG günü (başlıkta "Per 12 Kas: PG günü"). | R-ZV1b-mobil.png |
| R-ZV1b masa | ZV1b | PASS | Ekran: "Tren · Per 12 Kas · 3 hayvan · Per 12 Kas: başlangıç günü Tren gününü ertele…" (altında 3 kart) + "Tren · Per 5 Kas · 2 hayvan · Per 12 Kas: PG günü" → Per 12 Kas: 3 hayvan başlangıç + 5 Kas treninden 2 hayvan PG günü (başlıkta "Per 12 Kas: PG günü"). | R-ZV1b-masa.png |

Ölçüt notları: madde 1 başlık biçimi regex + N = başlık altındaki `[data-ovs-hayvan]` kart sayısı (8/8 blok, mobil+masa), Trenler bölümünde kart dışı `.ovs-asama/.ovs-bagimsiz-alt/.ovs-aksiyon` = 0, `[data-ovt-aksiyon="TOPTAN"]` = 1 (yalnız Per 12 Kas; "Tren ayarı ›" da `.ovs-tren-ertele` sınıfını taşıdığı için ilk koşuda yanlış sayıldı, ölçüt düzeltildi). Madde 7: görev sheet (`#m-task-det.on`) yok; X-5 kartı `getBoundingClientRect` ile görünür alanda. Önceki BULGU-1 ve BULGU-2 kapandı. Konsol hatası 0.
