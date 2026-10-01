# ui-tur4-DONE — 18 maddeden 13 PASS (5 FAIL-ÜRÜN)

Yöntem: her madde için ayrı `m<N>.spec.js` (repo dışı: `/home/melik/tmp/agents/uitur-20261001/yuruyus/`), koşum `yuruyus-kos.sh <N>` (resmi e2e ile aynı docker kurulumu). Betik hüküm vermedi; DOM metni + RPC/DB + ekran görüntüsüyle ben karşılaştırdım. Yükleyici bekleme kuralı (`.loader` 0) + IDB bekleme + ovsync RPC yanıtı bekleme uygulandı (eski betiğin "bayat DOM okuma" yarışı yürüyüşte iki kez yakalandı). Ham gözlemler: `/home/melik/tmp/agents/uitur-20261001/yuruyus/m<N>.obs.json`. Ekran görüntüleri: `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/artifacts/yuruyus-m<N>-*.png` (56 dosya).

A = `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/artifacts/`

| madde | hüküm | beklenen (kısa) | görülen (kısa) | PNG |
|---|---|---|---|---|
| 2 KPA şeridi | PASS | 5 hücre küçük harf, sayı=RPC kpa, bugün>0 `ovs-one`, `(N takipte)` | `0 aktif 0 bugün 0 geciken 8 muayene bekleyen 47 bekleyen başlatma (10 takipte)` = RPC; bugün=1 iken (m20) hücre vurgulu | A/yuruyus-m2-kpa.png |
| 3 S0–S4 | **FAIL-ÜRÜN** | S4 katlanır (varsayılan kapalı, açılabilir) | S0/S1 boşken yok ✓, S2/S3/S4 başlıkları=RPC ✓, S3 ilk 5 + `tümü (47)`→47→`küçült` ✓; **S4 açılamıyor**: `<h2>S4 · Sonlananlar▾</h2>` düz metin, `.ovs-katla` span/onclick yok, kapalıyken de ▾ | A/yuruyus-m3-ilk.png, A/yuruyus-m3-s4-oncesi.png |
| 4 🔔 köprüsü | **FAIL-ÜRÜN** (düşük şiddet) | 🔔→"Tüm takibi aç →" ovsync'e götürür | link var, `#pg-ovsync.on` olur ama 🔔 bottom-sheet (`#protokol-bs`) AÇIK kalıp ovsync'in üstünü kaplar. Görevler "Tüm ovsync takibi →" ✓, takip görevi 🌱 Üreme çipinde ✓ | A/yuruyus-m4-link-sonrasi.png, A/yuruyus-m4-gorevler-ureme.png |
| 5 Sayı eşitliği | PASS | 🔔 🌱 = ovsync bekleyen-başlatma (uyarılar alt kümesi) | 🔔 8 = penceredeki (bugün..+2) S3 satırı 8; KPA toplam 47 ayrı sayı (plan.md:244 okuması: eşitlik yalnız alt küme) | A/yuruyus-m5-dash.png, A/yuruyus-m5-ovsync.png |
| 8 TAKIP kurulumu | PASS | kartta gün girişi yok; görev +7, saat=atama anı; S3 `🔍 takipte`+muayene rozeti; 🌱 Üreme çipi | kart input=0; DB hedef 2026-10-08, saat 21:58:05 (kayıt 21:58); S3 `🔍 takipte muayene 08.10 21:58`; çip ✓ | A/yuruyus-m8-secici-takip.png, A/yuruyus-m8-s3-satir.png, A/yuruyus-m8-gorevler.png |
| 9 Kilitli Ovsync | PASS | kilit gerekçesi, ön seçim Takibe bırak | kural günü: `🔒 Kural günü 26.12 — 86 gün var`; kısır: `🔒 Kısır`; ikisinde seçim=TAKIP, buton `Boş ata + Takibe bırak` | A/yuruyus-m9-kural-gunu-kilitli.png, A/yuruyus-m9-kisir-kilitli.png |
| 10 PG kapısı | PASS | `#pg-kapi-bs`, "Son tohumlama sonucu Bekliyor…", `Boş ata ve uygula` tek sarmal | sheet metni ✓, gerekçesiz pasif; PG geçmişi olan hayvanda tek `tohumlama_bos_ve_devam` → Boş + pg_application_event aynı çağrıda, toast ✓ | A/yuruyus-m10-A-kapi-sheet.png, A/yuruyus-m10-B-sonrasi.png |
| 11 TAKIP_ACIK | PASS | app sheet, 🔍, gerekçe satırı tarih/saat DOLU, Vazgeç yazmasız, Evet kapatır | `Küpe …-b, 08.10 09:00'te rektal muayene takibinde…` + `🔍 Rektal muayene takibi: 08.10 09:00`; native dialog 0; Vazgeç→toh Bekliyor/takip açık; Evet→neden=PG, toh Boş | A/yuruyus-m11-sheet.png, A/yuruyus-m11-evet-sonrasi.png |
| 12 Birleşik kapı | **FAIL-ÜRÜN** | `💉 PG kapısı: <gerekçe>` üstte, `🔍 …` altta, tek onay | tek sheet/tek onay/tarih-saat dolu ✓ ama PG satırı `💉 PG kapısı: bilinmiyor` | A/yuruyus-m12-birlesik.png |
| 13 Sessiz kapanış | PASS* | onay yok, `YENI_TOHUMLAMA`, listeden düşer | onay/dialog 0, neden=YENI_TOHUMLAMA, satır 0 (*tohumlama DB INSERT ile; UI giriş yolu yürünmedi) | A/yuruyus-m13-sonra.png |
| 14 Çıkış kapanışı | PASS* | neden=CIKIS, satır düşer | neden=CIKIS, iptal=true, satır 0 (*çıkış DB UPDATE ile; UI yolu yürünmedi; hayvan Aktif'e geri alındı) | A/yuruyus-m14-sonra.png |
| 15 Birleşik sonuç | PASS | GK 5 kart, TM 4 kart (Takip yok), etiket `Muayene tamam + …`, 3 giriş | GK: GEBE/OVSYNC/PG/TAKIP/ERTALE; TM: GEBE/OVSYNC/PG/ERTALE; `Muayene tamam + Gebe işaretle`; girişler görev detayı (Geciken sekmesi), S2 butonu, dash 40g listesi ✓ | A/yuruyus-m15-gk-5kart.png, A/yuruyus-m15-tm-4kart.png, A/yuruyus-m15-s2-giris.png, A/yuruyus-m15-dash40g.png |
| 20 Gün şeması | PASS (uygulanmadı rengi UNKNOWN) | d0● d7◌ d8◌ d9◌ TAI⏳, renk dili, `N/4 uygulandı · sıradaki…`, nötr etiketler | 01.10/08.10/09.10/10.10/TAI 11.10; etiketler `1./2./3./4. uygulama`; tamam yeşil dolu, plan amber halka, gecikti kırmızı halka, tutarsız sarı ⚠; `1/4 uygulandı · sıradaki: 2. uygulama`. **uygulanmadı soluk** hiçbir ekranda üretilemedi (S4 kartı gün şeridi çizmiyor) | A/yuruyus-m20-A-d1-tamam.png, A/yuruyus-m20-B-gecikti-tutarsiz.png |
| 21 Rozetler | PASS | `hedef GG.AA → fiilen +Ng`, `erken Ng`, `görevsiz`, `erken TAI`, `N. deneme — önceki boş`, Dalga başlığı | hepsi görüldü: `hedef 21.09 → fiilen +3g`, `erken 2g`, `görevsiz`, `erken TAI`, `2. deneme — önceki boş`, `Dalga: hedef 21.09 → fiilen 24.09 · 2 hayvan` (aynı dalgaya iki hayvan DB ile getirildi) | A/yuruyus-m21-p.png, A/yuruyus-m21-pz.png, A/yuruyus-m21-s1.png |
| 22 Bayrak kapalı | PASS | `🔒 Ovsync/PG kuralları kapalı — takip verisi yok`; seçici açılmaz + toast | tam metin ✓, KPA şeridi yok, toast `Ovsync/PG kuralları kapalı — Boş kaydı mevcut akışla yapılır`, seçici 0 | A/yuruyus-m22-bayrak-kapali.png, A/yuruyus-m22-secici-acilmadi.png |
| 23 Offline | **FAIL-ÜRÜN** | bayat: `⚠️ çevrimdışı · HH:MM verisi` | bayat içerik gösteriliyor ✓ ama etiket `⚠️ çevrimdışı veri` (saat YOK). Önbelleksiz `📡 İnternet yok — takip verisi alınamadı` ✓ | A/yuruyus-m23-bayat.png, A/yuruyus-m23-onbelleksiz.png |
| 24 Gezinme | **FAIL-ÜRÜN** | modal açıkken geri yalnız modalı kapatır | Ana⇄Ovsync⇄Görevler ✓, `‹ Geri`=history.back (uzunluk sabit, dash'e döner) ✓, scroll 400→400 geri yüklendi ✓; **modal açıkken geri: history.state `{devam_secici}`→`{pg:ovsync}` tüketiliyor ama `#devam-secici-bs` AÇIK kalıyor** (tarayıcı Geri ve ‹ Geri ile) | A/yuruyus-m24-modal-geri-b.png, A/yuruyus-m24-scroll-restore-b.png |
| 25 Invalidate | PASS | yazma sonrası `__ovsyncTakip=null`, taze, bayat satır yok | UI seçici→Ovsync: yazma sonrası `NULL`; OVSYNC_BASLAT DB'de; ovsync'te g satırı; KPA yenilendi | A/yuruyus-m25-g-s3.png |

(Ek, listede dışı: madde 16 — ertele ön ayarı bu turda da yürüdü: gün 7, saat boş `Saat (boş = saatsiz)`, önizleme `→ 08.10`/`→ 08.10 14:30`, DB hedef 2026-10-08 hedef_saat NULL; 21 g onayı `#m-confirm` "Bu hayvan 26/51 gündür takipte" (= (bugün+7)−takip başlangıcı, TAKIP_UZADI formülü) → PASS.)

## FAIL-ÜRÜN ayrıntıları (çoğaltma)

1. **M3 — S4 katlama bozuk** (`js/ui.js:1135`): `'<span class="ovs-katla" onclick="_ovsyncS4Katla()">'+(…S4)?'▾':'▸'+'</span>'` — `+` ternary'den önce bağlandığı için koşul hep truthy; sonuç `'▾'` (span/onclick atılıyor). Çoğaltma: ovsync → S4 başlığı düz "S4 · Sonlananlar▾", tıklanmıyor; S4 kartları hiç açılamaz. (Parantez eksik: `((…).S4?'▾':'▸')+'</span>'`.)
2. **M4 — 🔔 sheet açık kalıyor**: dashboard → 🔔 → "Tüm takibi aç →" → `goTo('ovsync')` çalışır ama `#protokol-bs` kaldırılmaz; ovsync sayfası sheet'in altında. Çoğaltma: `#bellbtn` tıkla, linke tıkla, ekran görüntüsü.
3. **M12 — "PG kapısı: bilinmiyor"** (`js/ui.js:3115` ← `_takipPgKararEtiket(detay.pg_kapi.karar)`): sunucu `PG_KAPI:TAKIP_ACIK` yükü `{"pg_kapi":{gun,sperma,kupe_no,deneme_no,hayvan_id,urun_durumu,tohumlama_id,tohumlama_sonuc,tohumlama_tarihi},"takip_acik":{…}}` — `pg_kapi.karar` alanı YOK (yalnız `PG_KAPI:REQUIRE_ACK_PENDING:` kod öneki var) → etiket `bilinmiyor`. Çoğaltma: takipli (b/m) hayvana hızlı-PG (Hayvan→Hızlı uygulama, PGs, 5 ml).
4. **M23 — bayat etiketinde saat yok** (`js/api.js:1113`): `ovsyncTakipGetir` catch yolu `{bayat:true, veri}` döner, `zaman` taşımaz → `_ovsyncDashDurum` zaman=null → `_ovsyncBayatEtiket` → `çevrimdışı veri`. Çoğaltma: ovsync'i aç, çevrimdışı yap, dash→ovsync.
5. **M24 — modal-router guard**: ovsync'te S2 `🩺 Muayene sonucu` → seçici açılır (`history.state={devam_secici:true}`) → `page.goBack()` → state `{pg:'ovsync'}` olur, URL `#ovsync` kalır, ama seçici ekranda kalır. İkinci Geri dash'e gider.

## Ek gözlemler (madde dışı, düzeltilmedi)
- **S0 "BUGÜN" kartı yanıltıcı** (js/ui.js ~934): ilaç günü bugün ama TAI bugün değilse bile kart `— TAI bugün 10:00` + `▶ TAI kaydet` basıyor (RPC `tai.hedef_tarih=2026-10-11`; g/pe zincirlerinde görüldü); bu kartta gün şeridi çizilmiyor, yalnız `0/4 ilaç günü tamam`. (A/yuruyus-m20 ilk koşum, A/yuruyus-m21 S0 metni.)
- M10: PG kapısında son-PG geçmişi yoksa "Boş ata ve uygula" `⚠️ PG ürünü çözümlenemedi — Boş ataması yapılmadı` verip yazmıyor; kullanıcı hızlı uygulama formunda ürün+doz seçmiş olsa da kullanılmıyor (tasarım gereği — `_pgKapiBosAtaUygula`, PG_SECIM_GEREKLI ikizi).
- Kartlarda "vaka bağlantısı bilinmiyor" (Gün detayı yerine) yeni açılışta kısa süre görünüyor: vaka eşlemesi IDB `cases` pull'ına bağlı (yarış, kalıcı değil).
- M22: bayrak kapalıyken eski akış native `confirm("Bu tohumlama kaydı \"Boş\" olarak işaretlenecek. Emin misiniz?")` açıyor (eski akış, kapsam dışı).
- Demo'da başka suit artığı `E2E-TAKIP-PW-*` hayvanları ovsync S3'te görünüyor (bu tura ait değil).

## FAIL-KURULUM / kurulum düzeltmeleri
- M9: fixture `z` (düve, doğum −500g) kural günü geçmiş → kilit yoktu; `hayvanlar.dogum_tarihi` −300g (kural günü) ve `kisir=true` (kısır) ile iki varyant yürüdü, **geri alındı** (`kisir=false`, doğum −500g; DB'den okundu: "z geri alindi").
- M10: `k` hayvanına PG geçmişi için toh geçici `Boş` → `hizli_uygulama` → `Bekliyor`'a dönüş (kurulum).
- M20/M21: `g` ve `p/pz/pe` zincirleri ürün RPC'leriyle (sarmal + Başlat) kuruldu; gün tarihleri/tamamlanma DB ile oynatıldı (gecikti/tutarsız durumları için), aynı hayvanlar teardown'da silinir.
- Eski betiğin FAIL'lerinin bir kısmı BETİK kaynaklıydı: 🔔 sheet'i açmadan "İlk Tohumlama" arama (M4/M5), ovsync RPC dönmeden bayat DOM okuma (M3 tümü, M20), `hasText` alt-dize eşleşmesi (`-c`↔`-c2`, `-p`↔`-pe`), GEBELIK_KONTROL'ün Geciken sekmesinde olması, hızlı-PG için `stok` IDB beklememe.

## Madde 22 geri alma kanıtı
Önceki `ovsync_pg_kurallari_aktif=1` (ölçüldü, `m22.obs.json`: `onceki_deger:[{deger:1}]`) → test içinde 0 → `finally` ile 1; DB'den okunan sonrası: `[{"anahtar":"ovsync_pg_kurallari_aktif","deger":1}]`, geri alma hatası `null`.

## Teardown
`global-teardown.cjs` docker'da koşuldu: `TEARDOWN OK` (2 hayvan pg_event-FK nedeniyle silinemedi → `durum=Satildi` bırakıldı; bilinen davranış). Sahip demo şifresine dokunulmadı. Ürün kodu/tests/supabase/.ss'e yazılmadı; commit/push/merge YOK (zarf yasağı) — repoda yalnız `artifacts/yuruyus-*.png` (56) üretildi, ürün diff'i boş olduğundan iç code-review uygulanacak diff yok.
