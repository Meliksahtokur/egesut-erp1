# N4-F2-brief — Tren ekranı bağlaması (UB3 çekirdeği): veri çekimi, toptan erteleme, aşama eylemleri, tren ayarı + review küçükleri
job_id: j-20261109T145839Z-3903f2

tip: is
effort: xhigh (sinyal f-turu + UI; Muse 3. tur — geçmezse iş Opus'a gider)
job: ovsync-tren N4-F2
workspace: tedavi-arge
report: ~/.herdr/worktrees/egesut-erp1/ovsync-tren/runs/2026-11-09-ovsync-tren/ui/N4-F2-report.md
repo/dal: ~/.herdr/worktrees/egesut-erp1/ovsync-tren (dal ovsync-tren, uç f5a61ea ya da üstündeki root kayıt commit'i). Açılışta `git branch --show-current` → `ovsync-tren` (detached YAPMA, rebase/merge YAPMA).

girdi (BAĞLAYICI):
- Kulvar review'u (DÜZELT, satır nolar buradan): ~/.herdr/worktrees/egesut-erp1/ovsync-tren/runs/2026-11-09-ovsync-tren/ui/N4-R-review.md
- Ana brief (tüm ROOT RULING'ler, tuzaklar AYNEN): ~/.herdr/worktrees/egesut-erp1/ovsync-tren/runs/2026-11-09-ovsync-tren/ui/N4-brief.md ; F1 brief: aynı klasör N4-F1-brief.md
- Önceki report'lar: aynı klasör N4-report.md, N4-F1-report.md
- PLAN UB3 :509-520: ~/.herdr/worktrees/egesut-erp1/ovsync-tren/docs/plans/2026-11-09-ovsync-tren/PLAN.md
- Veri sözleşmesi: aynı klasör UB-sozlesme-report.md
- Mockup: ~/.herdr/worktrees/egesut-erp1/ovsync-tren/runs/2026-11-09-ovsync-tren/mockup/02a-ovsync-tren-ekrani.html, 02b-ovsync-ritim-disi-bagimsiz.html, 03a-toptan-erteleme-n1-secim-yok.html, 03b-toptan-erteleme-n2-secimli.html, 06-tren-ayari.html

## ROOT RULING (N4 kulvar review DÜZELT, 2026-11-09 — root nokta-ölçümüyle CONFIRMED)

Önceki iki tur HTML üreticilerini yazdı ama ekrana bağlamadı; report'lar UB3'ü PASS saydı. Bu turun ölçütü: **kullanıcı tıklamasından RPC'ye ve geri ekrana kadar zincir** testli.

- B1 (BLOKLAYAN, review 1) js/ui.js:675,679 `loadOvsyncDash`: bayrak açıkken `ovsync_tren_listele` takip çağrısıyla PARALEL çekilir (`Promise.all`/allSettled); sonuç `aktif===true` ise `renderOvsyncSayfa(veri, bugunIso, trenVeri)` (bayat-etiketli dal :679 dahil); hata/`aktif!==true`/offline → 3. argüman `undefined`, eski "Dalga:" yolu birebir. Bayrak kapalıyken `ovsync_tren_listele` ÇAĞRILMAZ.
  - Test: `loadOvsyncDash bayrak açık → ovsync_tren_listele çağrılır, render 3. argüman = yanıt` (sahte rpc + sahte root), `bayrak kapalı → listele çağrılmaz, eski html`, `listele hata → eski html, takip ekranı yine çizilir`.
- B2 (BLOKLAYAN, review 2) eylem bağlaması — delegated dinleyici (`_ovsyncTrenAksiyonTikla`) UA1'in çizdiği HER `data-` eylemine kol alır; inline onclick YOK:
  - `TOPTAN` → `ovsyncToptanAc(trenGunu)`: N seçici (1..7) → `ovsync_tren_ertele_onizle(p_tarih, p_n)` → `_ovsyncToptanGovdeHtml(plan, secimler, bugun)` modalda; SECIM satırlarında PG48/BASTAN seçimi `secimler`'e yazılır ve gövde yeniden çizilir; onay düğmesi `ovsyncToptanOnayAcikMi` false iken disabled + neden metni; `ONAYLA` → `ovsync_tren_ertele(p_tarih, p_n, p_secimler)`; başarı → sonuç metni (F5: `ileri_vakalar`, `iptal_tai`, `basladi:false`+`yeniden_hedef`) + modal kapanır + `_ovsyncTakipInvalidate()` + ekran yeniden yüklenir; `OVSYNC_TREN_ERTELE_DUSTU` → modal AÇIK kalır, düşen küpeler + sebep metni (`ovsyncTrenHataMetni`) görünür; diğer hata → toast metni.
  - `ERTELE` / `SONRAKI_TREN` → `ovsync_hayvan_ertele(p_hayvan_id, p_gun)`: aşama 1'de 1..`pg_pay`, aşama 0 bağımsızda 1..7 seçici (F3; `ovsyncTekErteleAraligi` kullanılır — şu an çağıransız), aşama 0 trende `SONRAKI_TREN` gün farkını sunucuya bırakır (PLAN D6 sözleşmesi); sonuç `yeni_tarih` toast'ta.
  - `PG48` → `ovsync_pg48_tohumla(p_case_id)`; sonuç `tai_hedef` toast'ta (BOŞLUK-1 sonrası kısım).
  - `BASTAN`, `DUZENLE` mevcut kollar korunur.
  - "Tren ayarı" paneli (mockup 06): ekran üstünde açılır panel; aktif anahtarı + çapa tarihi; "Önizle" → `ovsync_tren_yeniden_hedefle(true)` (kuru) özet (yeniden hedeflenecek görev sayısı, `belirsiz_asama` listesi küpeleriyle); "Kaydet" → `ovsync_tren_ayar_guncelle(p_aktif, p_capa)`; hata `OVSYNC_TREN_AYAR` metinli. RPC adı/parametre adları sözleşme raporundan BİREBİR (uydurma = RED).
  - Tüm yazmalardan sonra `_ovsyncTakipInvalidate()` + ekran tazelenir. Offline (`_ertelemeOnline()` false) → TOPTAN/ERTELE/SONRAKI_TREN/PG48/ayar düğmeleri ÇİZİLMEZ (PLAN UB3).
  - Test (adlı, tıklama simülasyonu ile — HTML üreticisini doğrudan çağırmak YETMEZ): `TOPTAN tık → ertele_onizle(p_tarih,p_n)`, `SECIM seçilmeden ONAYLA → rpc yok`, `SECIM seçilince ONAYLA → ovsync_tren_ertele p_secimler dolu`, `ERTELE_DUSTU → modal açık, düşen küpe görünür`, `ERTELE tık → ovsync_hayvan_ertele p_gun`, `PG48 tık → ovsync_pg48_tohumla`, `ayar Önizle → yeniden_hedefle(true)`, `ayar Kaydet → ayar_guncelle`, `offline → eylem düğmeleri yok`, `yazma sonrası invalidate + yeniden yükleme`.
  - Mutant (ADLI testte kırmızı): (m9) `loadOvsyncDash`'te 3. argümanı sil → `loadOvsyncDash bayrak açık` kırmızı; (m10) ONAYLA kolunda `ovsyncToptanOnayAcikMi` kontrolünü kaldır → `SECIM seçilmeden ONAYLA → rpc yok` kırmızı; (m11) ERTELE_DUSTU'da modalı kapat → ilgili test kırmızı; (m12) ayar Kaydet kolunu sil → `ayar Kaydet` kırmızı.
- B3 (review 3) yukarıdaki zincir testleri bunu karşılar.
- Çağıransız kontrol (zorunlu, report'a tablo): PLAN UB3'teki her RPC (`ovsync_tren_listele`, `ovsync_tren_ertele_onizle`, `ovsync_tren_ertele`, `ovsync_hayvan_ertele`, `ovsync_pg48_tohumla`, `ovsync_bastan_baslat`, `ovsync_tren_yeniden_hedefle`, `ovsync_tren_ayar_guncelle`) ve N4'te eklenen her `_ovsync*`/`ovsync*` fonksiyon için `grep -n` ile üretim çağrı yeri (test dosyası sayılmaz). Çağıransız kalan fonksiyon ya bağlanır ya silinir; tablo boş-çağıranlı satır içeremez (UA1 saf modülünün yalnız testte kullanılan dışa açık yardımcıları gerekçesiyle listelenir).
- K4 (review 4) js/ovsync-tren.js `_ovtHataMetniImpl`: tüm büyük harfli token'lar `matchAll` ile gezilir, `_OVT_HATA`'da ilk bulunan seçilir. Test: `'P0001: OVSYNC_TREN_KAPALI'`, `'HTTP 400 OVSYNC_TREN_KAPALI'` → Türkçe metin.
- K5 (review 5) yardımcı fonksiyonlar JSDoc ile asıl fonksiyon arasından çıkarılır (JSDoc hemen kendi fonksiyonunun üstünde).
- K6 (review 6) `cdKaydirAc`: `_ertelemeOfflineGuard('kaydir')` eski sırasıyla en başta (bayrak kapalı yol birebir); OVSYNC çevrimdışı metni bunun içinde değil sonrasında kalabilir — bayrak kapalı/OVSYNC değil yolda eski sıra.
- K7 (review 7) `submitCase`: offline kontrolü `_ovsyncKancaDurumu` IDB okumasından ÖNCE.
- K8 (review 8) `_ovsyncKartKararBaglami` filtresindeki ölü `TEDAVI_GUN`/`TEDAVI_SEANS` kolu kaldırılır.
- Kalite (review KALİTE, bu turda): (q1) üç K8 soru kurulumu (`_ovsyncBaslatSecimi`, `_ovsyncG7G9Sor` ui.js, `_ovsyncKancaSor` forms.js) tek ortak yardımcıya iner (dosyalar arası çağrı mevcut global kalıbıyla; `loadExtractedFunction` testlerini kırmamak için gerekirse ince sarmalayıcı adları korunur); (q2) `_ovsyncV5Sargili`/`_ovsyncV5KancaKur` global yeniden atama kaldırılır, `caseSablonUygula` başına erken dal (V2/V3/V4/V6 gibi inline). `_ovsyncTrenTarihAd`/`_ovsyncK8GunAd` birleştirmesi KAPSAM DIŞI (karar korunur).
- BOYUT: N4 toplam üretim net ≤ +1250 (taban fb41bbf, tek sayı + komut). q1/q2 ve ölü kod silinmesi bu bütçeye karşı sayılır.
- Report dürüstlüğü: `sonuc: TAMAM` yalnız B1/B2 zincir testleri + çağıransız tablosu temizse; değilse `KISMI` + liste. UB tablosunda "PASS" yalnız ekran zinciri testli satıra yazılır.
- Kapsam DIŞI: supabase/**, ana brief kapsam dışı listesi, EG-7/EG-8, LUNA-3, `.harness/**`.

## Kabul

- B1/B2/K4 yeni testleri kırmızı→yeşil; m9–m12 ADLI testte kırmızı (MEASURED, ham log + cmp IDENTICAL); önceki m1–m8'den en az m1, m5, m8 yeniden kırmızı (refaktör sonrası hâlâ anlamlı).
- Tam birim suit `fail 4`, fail edenler tam olarak taban dördü (LUNA-3 degisiklikler-etiketler.test.js:88, EG-7 erteleme-genel-ui.test.js:262, EG-8 :292, vaka-toplu-ac.test.js:2624); pass > 2359.
- `etiket-tazelik` HATALI 15 / DOĞRULANAMADI 4, liste tabanla aynı.
- Çağıransız tablosu report'ta, boş-çağıranlı satır yok.
- Report: `## Fan-out`, `## Self-review` (tek reviewer çocuğu; reviewer'a B1/B2 zincirini ve çağıransız tablosunu ayrıca doğrulat), bulgu → dosya:satır → test tablosu, `## Run kanıtı`; commit öneki `ovsync-tren N4-F2:`; dosya dosya `git add`, push YOK. Report da commit'lenir. TUI son satırı `DONE <report yolu>` / `SORU <report yolu>`.

Yazılabilir:
~/.herdr/worktrees/egesut-erp1/ovsync-tren/js/api.js
~/.herdr/worktrees/egesut-erp1/ovsync-tren/js/ui.js
~/.herdr/worktrees/egesut-erp1/ovsync-tren/js/forms.js
~/.herdr/worktrees/egesut-erp1/ovsync-tren/js/ovsync-tren.js
~/.herdr/worktrees/egesut-erp1/ovsync-tren/index.html
~/.herdr/worktrees/egesut-erp1/ovsync-tren/tests/unit/ovsync-tren.test.js
~/.herdr/worktrees/egesut-erp1/ovsync-tren/tests/unit/ovsync-tren-entegrasyon.test.js
~/.herdr/worktrees/egesut-erp1/ovsync-tren/runs/2026-11-09-ovsync-tren/ui/N4-F2-report.md
~/tmp/muse-ovsync-n4f2

## Bilinen tuzaklar

- Ana brief "Bilinen tuzaklar" aynen (NODE_PATH, ram-ultracode exec, atlas `etki` her değişen sembolde, loadExtractedFunction imza koruma, TR günü, JSON.parse try/catch, stash/checkout YASAK, mutant yedekten geri yükleme + cmp).
- `loadOvsyncDash` ve `renderOvsyncSayfa`'yı çağıran mevcut testler (ovsync-render.test.js, ovsync-gezinti.test.js): bayrak kapalı/trenVeri yok dalı birebir; o testlere DOKUNMA.
- "HTML üreticisi testi geçiyor" ≠ "ekranda çalışıyor": bu turun her eylem testi tıklama → dinleyici → sahte rpc çağrısı → DOM sonucunu ölçer.
- Özet/ara dosyaları yalnız `~/tmp/muse-ovsync-n4f2` altına.

## Fan-out planı (zorunlu)

İç review + self-review TEK reviewer çocuğu.

cocuk-model: spark

Parça 1 (alt ajan): B1 `loadOvsyncDash` + testleri (ui.js). Parça 2 (alt ajan, Parça 1'den sonra — aynı dosya): B2 toptan akışı + ERTELE/SONRAKI_TREN/PG48 kolları. Parça 3 (alt ajan, Parça 2'den sonra): tren ayarı paneli. Parça 4 (alt ajan, paralel — ayrı dosya): K4/K5 js/ovsync-tren.js + ovsync-tren.test.js. Parça 5 (alt ajan, Parça 3'ten sonra): K6/K7/K8 + q1/q2 (ui.js/forms.js).
Sen: entegrasyon, m9–m12 + m1/m5/m8 yeniden, çağıransız tablosu, tam suit + etiket-tazelik, report, tek reviewer çocuğu.
