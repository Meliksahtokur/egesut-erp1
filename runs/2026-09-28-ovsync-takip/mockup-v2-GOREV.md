# GÖREV — Takip ekranı mockup v2 güncellemesi (glm-max)

İlk iş: /using-superpowers-obra. **ultracode YASAK.** Commit atma. Atılabilir taslak, ürün kodu değil.

## Girdiler
- SPEC v3 §3, §4, §4b, §6c.5: /home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/docs/plans/2026-09-28-ovsync-takip-ekrani/design.md
- v1 mockup (başlangıç noktası, kopyala-düzenle): /home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/mockup/ovsync-takip-mockup.html (+ .png), /home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/mockup/yasam-dongusu-mockup.html
- Stil referansı: /home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/mockup/bos-devam/06-takip-ekrani-rozet.html
- Screenshot şablonu: /home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/mockup/mockup-shot.js (chromium executablePath oradaki; viewport 420, fullPage); NODE_PATH=/home/melik/egesut-erp1/node_modules; /tmp'ye yazma.

## Yapılacak v2 farkları
1. Bölümler ekran sırasıyla S0 Bugün&Geciken · S1 Aktif zincirler · S2 Sonuç bekleyenler · S3 Başlatılmayı bekleyenler · S4 Sonlananlar (son 60 gün, katlanır) — ②⑤①④ numaraları kalkar.
2. S2: "kontrol 08.10 · 10 gün" yerine "muayeneye N gün" (TAI+40 gün); süresi dolan satırda "muayene vakti" rozeti. 21 gün HİÇBİR yerde geçmez.
3. S2'de 197 "boş çıktı yeni deneme bekliyor" satırı KALDIRILIR; 197 S3'te "🔍 takipte · muayene 05.10 14:35" rozetiyle görünür.
4. Deneme rozeti "2. deneme — önceki boş" (902 örneği) — "bu laktasyon" anlamında.
5. Gün noktalarında 5. durum: ⚠ tutarsız (bir örnek satırda, küpe 19 benzeri "gelecek tarihli tamamlandı").
6. Başlıkta ‹ geri + KPA şeridi: Aktif · Bugün · Geciken · Muayene bekleyen · Bekleyen başlatma.
7. Dashboard giriş mockup'ı: 2 kolonlu grid'de 5 mevcut hücre + yeni 6. hücre "🔄 Ovsync ›" (son satırı tamamlar) — /home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/mockup/dashboard-giris-mockup.html'i kopyala-düzenle.

## Yazabileceğin dosyalar (liste dışı YASAK)
Yalnız /home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/mockup/v2/ klasörü altı: ovsync-takip-v2.html/.png, dashboard-giris-v2.html/.png, shot.js, DONE.md.
Her PNG'yi üretince aç ve metin kesilmesini kontrol et.

## DONE
/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/mockup/v2/DONE.md — TAMAM|KISMI|BLOKE; dosyaların mutlak yolları; her PNG 1 satır; sorunlar.
Sonra dağıtana tek satır: `DONE: /home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/mockup/v2/DONE.md · sonuc: <...>`
