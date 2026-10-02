# GÖREV — Ovsync takip + Boş-devam: SENARYO TEST KATALOĞU (glm-max lead)

İlk iş: /using-superpowers-obra. **ultracode YASAK.** Commit atma, ürün kodu yazma.
Sahip: "her ihtimali düşünen senaryo testleri yazılmalı, script testleri yetersiz."

## Girdiler
- SPEC v3 (OTORİTE): /home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/docs/plans/2026-09-28-ovsync-takip-ekrani/design.md (§4b matris, §5, §6b, §6c, §7, §9, §10)
- Domain kuralları §18 (özellikle 18.1–18.16): /home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/.harness/references/domain-rules.md
- Mockup'lar: /home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/mockup/bos-devam/*.png
- PROD envanter (gerçek vaka örnekleri, kenar durum kaynağı): /home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/db-ovsync-durum-raporu.md, /home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/w2-veri-modeli-raporu.md
- Mevcut test düzeni (desen için kısa bak): /home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/tests/ ; UI test kapısı: /home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/CLAUDE.md "UI testi kapısı"
- Plan paralel yazılıyor (/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/docs/plans/2026-09-28-ovsync-takip-ekrani/plan.md) — bu turda ona BAĞLANMA; RPC/fonksiyon adlarını spec'teki gibi kullan, "ad plana göre kesinleşir" notu düş.

## Çıktı
/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/docs/plans/2026-09-28-ovsync-takip-ekrani/test-senaryolari.md
- Numaralı senaryolar (T-xx). Her biri: başlık · spec § + kabul # referansı · katman (DB-SQL | UI-Playwright | İnsan-UI listesi) · ön koşul (hayvan/vaka/görev durumu, bayrak, çevrim) · adımlar · BEKLENEN sonuç (DB satırları + ekran görünümü ayrı ayrı) · ters kanıt (olmaması gereken şey).
- Kapsam en az: (1) devam seçici her seçenek × her Boş giriş noktası (sonuç modalı, gebelik muayenesi, takip muayenesi, PG kapısı "Boş ata ve uygula") (2) tek-işlem atomikliği: her alt adım düşerken Boş'un da geri alınması (3) sıralama tuzağı: TAKIP seçiminde OVSYNC_BASLAT DOĞMAMALI (4) hard block: kısır, kural günü gelmemiş (düve + doğum+51), ikisi birden (5) takip otomatik kapanış: yeni tohumlama (sessiz), Ovsync/PG (TAKIP_ACIK onay: evet/vazgeç), çıkış; kapanış nedeni kaydı; aynı anda iki olay (6) muayene ertele döngüsü (çoklu erteleme, saat korunur) (7) deneme sayısı: doğum sonrası sıfırlanır, doğumsuz düve, ömür boyu deneme_no ile karışmaz (8) takip ekranı bölüm geçişleri §4b matrisinin HER satırı (9) muayene eşiği 40 ayarından (ayar değişince sayaç değişir; 21 hiçbir yerde yok) (10) bayrak kapalı, offline (önbellekli / önbelleksiz), RPC hata (11) gezinme sözleşmesi §6b (geri tuşu, modal üstünde geri, kaydırma/filtre koruma, ‹) (12) sayı tutarlılığı: ovsync sayfası = 🔔 🌱 (13) güvenlik: anon/PUBLIC EXECUTE yok, başka farm verisi yok (14) PROD'daki gerçek kenar vakalar (küpe 51, 19, 902, 183, 197, 121) senaryo olarak (15) eşzamanlılık: aynı hayvana iki cihazdan Boş; takip kapanırken muayene sonucu girilmesi.
- Sonda: kabul 1–11 × senaryo izlenebilirlik tablosu; glmf-max UI test listesi için "İnsan-UI" senaryolarının ayrı özet listesi (her madde beklenen görünüm açık).
- Spec'te belirsiz/çelişkili bulduğun noktalar ayrı bölüm "SPEC SORULARI" (uydurma cevap YOK).

## Yazabileceğin dosyalar (liste dışı YASAK)
- /home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/docs/plans/2026-09-28-ovsync-takip-ekrani/test-senaryolari.md
- /home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/test-DONE.md
Okuma alt-ajanları serbest (≤6), hiçbir dosyaya yazmaz. DB'ye YAZMA yok; okumak gerekirse yalnız demo, salt-okunur.

## DONE
/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/test-DONE.md — TAMAM|KISMI|BLOKE; senaryo sayısı (katman kırılımı); SPEC SORULARI; kapsam dışı bıraktıkların.
Sonra SendMessage ile ovsync-takip-09 oturumuna tek satır: `DONE: /home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/test-DONE.md · sonuc: <...>`
