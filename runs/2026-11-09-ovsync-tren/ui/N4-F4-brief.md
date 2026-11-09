# N4-F4 — Tren ekranı yerleşimi mockup'a uymuyor + düzenle linki (DM2 bulguları + root göz kontrolü)
job_id: j-20261109T181854Z-55a8e5

report: ~/.herdr/worktrees/egesut-erp1/ovsync-tren/runs/2026-11-09-ovsync-tren/ui/N4-F4-report.md

## Plan maddesi
PLAN UB3 (tren başlıkları), UB4 (Ovsync TAI "Ovsync ekranında düzenle →"), DM2 madde 1/7 ve zaman vitrini ZV1b.
Kanıt: ~/.herdr/worktrees/egesut-erp1/ovsync-tren/runs/2026-11-09-ovsync-tren/demo/DM2-report.md "BULGU listesi"; canlı ekran ~/.herdr/worktrees/egesut-erp1/ovsync-tren/runs/2026-11-09-ovsync-tren/demo/ui-kapisi/ZV1b-mobil-FAIL.png, 01-mobil-ovsync.png, 07-mobil-FAIL.png. HEDEF görünüm (sahip onaylı): ~/.herdr/worktrees/egesut-erp1/ovsync-tren/runs/2026-11-09-ovsync-tren/mockup/02a-ovsync-tren-ekrani.png + .html, 02b-ovsync-ritim-disi-bagimsiz.png + .html, 05a-gorevler-ovsync-baglanti.png.
Worktree: ~/.herdr/worktrees/egesut-erp1/ovsync-tren (dal ovsync-tren). Ana brief kuralları + ROOT RULING'ler: aynı klasör N4-brief.md (tuzaklar, renk kuralı, bayrak kapalı birebir), N4-F2-brief.md, N4-F3-report.md.

## ROOT RULING (root PNG ↔ mockup karşılaştırması, 2026-11-09)
Canlı S1 (ZV1b-mobil-FAIL.png): tren başlıkları düz metin satırı; "bugün: <iş>" yok; "Per 12 Kas · 3 hayvan" altında kart yok; aşama aksiyonu ("PG 05.11: PG'yi ertele") kartın DIŞINDA, iki başlık arasında yetim; aşama 0 üyeler eski "S3 · Başlatılmayı bekleyenler"de. Mockup 02a ile uyuşmuyor.
- Y1 Tren bloğu: `_ovsyncTrenGovdeHtml` (js/ui.js ~2090-2120) + `ovsyncTrenGrupla`/`ovsyncTrenBaslikHtml` (js/ovsync-tren.js): her tren = başlık satırı + altında o trenin TÜM üyelerinin kartları. Başlık mockup 02a'daki gibi: "Tren · <Gün gg Ay> · N hayvan" kalın, ardından iş etiketi; aynı satırın sağında (yalnız F9 ilk ritim treni) "Tren gününü ertele…" link görünümünde. Stil uygulamanın mevcut başlık/kart sınıflarıyla; YENİ zemin/şerit/çerçeve rengi YOK (sahip kuralı: vurgu yalnız yazı rengi).
- Y2 İş etiketi: üyelerin `sonraki_is` en erken günü bugünse "bugün: <iş>" (iş: başlangıç günü / PG günü / PG+48 tohumlama), değilse "<Gün gg Ay>: <iş>" (ör. "Per 12 Kas: PG günü"). Kaynak alanlar sözleşme raporundan (ui/UB-sozlesme-report.md); uydurma alan YOK. Böylece "Perşembe kaç hayvanla ne iş" iki başlıktan okunur (ör. "Per 5 Kas · 2 hayvan · Per 12 Kas: PG günü" ve "Per 12 Kas · 3 hayvan · Per 12 Kas: başlangıç günü").
- Y3 Üye kartları: S0 (bugün işi), S1 (aktif zincir) VE aşama 0 başlatma bekleyen üyeler (OVSYNC_BASLAT görevli, trende) trenin altında kart olarak; mockup 02a'daki "Başlamadı: Sonraki trene aktar → <gün>" satırı kartın içinde. Bayrak açıkken bu üyeler eski "S3 · Başlatılmayı bekleyenler" listesinde TEKRAR görünmez (trende olmayanlar orada kalır). Başlık N = trenin altındaki kart sayısı (sunucu `uyeler.length` ile eşit; değilse görünür uyarı + konsol, sessiz değil).
- Y4 Aksiyonlar (`ovsyncAsamaAksiyonHtml`) yalnız kendi kartının İÇİNDE; kart dışında aksiyon satırı kalmaz.
- Y5 Ritim dışı ve bağımsızlar: mockup 02b düzeni (ritim dışı tren kendi başlığıyla + açıklama; "Bağımsız (N)" bloğu).
- B1 (DM2 BULGU-1) "Ovsync ekranında düzenle →": tıklama görev kartının onclick'ine sızmaz (`stopPropagation` + varsayılan engel), görev alt sayfası AÇILMAZ; Ovsync ekranı açılınca `_ovsyncOdakHayvan` TÜKETİLİR: ilgili hayvanın kartına kaydırılır (`scrollIntoView`) ve kart başlığı yazı rengiyle kısa vurgulanır (zemin yok), sonra değişken temizlenir.
- Bayrak kapalı/trenVeri yok → eski "Dalga:" görünümü birebir (mevcut testler kilitler).
- Testler (adlı): `tren bloğu: başlık altında tüm üyelerin kartı, N=kart sayısı`, `aşama 0 üye trende kart + Sonraki trene aktar, S3'te tekrar yok`, `aksiyon kart içinde, yetim satır yok`, `iş etiketi bugün / ileri gün`, `düzenle linki görev sheet açmaz`, `odak hayvana kaydırır ve temizlenir`. Mutant: (m13) Y3 aşama-0 üyelerini gruptan çıkar → adlı test kırmızı; (m14) B1 stopPropagation'ı kaldır → adlı test kırmızı.
- GÖRSEL KABUL (zorunlu): demo vitrini (DM2 vitrin verisi, ref `vtzqjmazsvurxdeondmi`; başka ref YASAK) üzerinde Ovsync ekranı mobil 390×844 tam sayfa + masaüstü 1280×800 ekran görüntüsü; DM2 betiği `$HOME/tmp/dm2/` yeniden kullanılabilir. PNG'leri `runs/2026-11-09-ovsync-tren/ui/f4/` altına koy ve report'ta mockup 02a ile madde madde (Y1–Y5) karşılaştır: "mockup'ta X → canlıda X" satırları. Ayrıca madde 7 akışı (Görevler → link → Ovsync ekranında hayvan görünür alanda) PNG.

## Model
opus / high (ss-worker-high). MUSE-YEDEK: N4'te Muse 3 tur kullandı.

## Boyut bütçesi
Üretim net ≤ +150 satır (eski S3 tekrarını kaldırma ve yetim aksiyon silme düşer).

## Yazılabilir dosyalar
~/.herdr/worktrees/egesut-erp1/ovsync-tren/js/ui.js
~/.herdr/worktrees/egesut-erp1/ovsync-tren/js/ovsync-tren.js
~/.herdr/worktrees/egesut-erp1/ovsync-tren/index.html
~/.herdr/worktrees/egesut-erp1/ovsync-tren/tests/unit/ovsync-tren.test.js
~/.herdr/worktrees/egesut-erp1/ovsync-tren/tests/unit/ovsync-tren-entegrasyon.test.js
~/.herdr/worktrees/egesut-erp1/ovsync-tren/runs/2026-11-09-ovsync-tren/ui/N4-F4-report.md
~/.herdr/worktrees/egesut-erp1/ovsync-tren/runs/2026-11-09-ovsync-tren/ui/f4

## Run
cd ~/.herdr/worktrees/egesut-erp1/ovsync-tren && NODE_PATH=~/egesut-erp1/node_modules node --test tests/unit/*.test.js 2>&1 | tail -6
cd ~/.herdr/worktrees/egesut-erp1/ovsync-tren && NODE_PATH=~/egesut-erp1/node_modules node scripts/etiket-tazelik.mjs 2>&1 | tail -3
ls ~/.herdr/worktrees/egesut-erp1/ovsync-tren/runs/2026-11-09-ovsync-tren/ui/f4/

## Kabul
- Tam suit fail 4 = taban dördü; pass > 2387. etiket-tazelik 15/4.
- Yeni testler kırmızı→yeşil; m13/m14 adlı testte kırmızı (yedekten geri yükleme + cmp IDENTICAL).
- f4/ altında mobil + masaüstü Ovsync ekranı ve madde 7 PNG'leri; report'ta Y1–Y5 mockup↔canlı karşılaştırması.
- Commit dosya dosya `ovsync-tren N4-F4: <özet>`; report + PNG'ler commit; push YOK. Report'ta `## Run kanıtı`.

## Review: root (PNG göz kontrolü)

## Önceden cevaplanmış kararlar
- Muse çağırma. Sunucu/SQL değişmez; RPC alanı yoksa uydurma, report'a `Varsayım:` ya da SORU.
- Demo verisine yalnız ekran görüntüsü için okuma; vitrin verisini değiştirme.
- `/tmp` yasak; `$HOME/tmp/n4f4/`. Ağır koşum `ram-ultracode exec --class test --wait 1800 -- bash <betik>`.
