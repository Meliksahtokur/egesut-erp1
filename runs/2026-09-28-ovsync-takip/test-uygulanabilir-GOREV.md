# GÖREV — Plan v7 sonrası çalıştırılabilir senaryo testleri (glmf-max lead)

İlk iş: `/using-superpowers-obra`; sonra `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/.harness/contract.md`, `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/.harness/references/domain-rules.md` (§14, §18), `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/.harness/goals/2026/G-20260929-OVSYNC-TAKIP-TEST-HAZIRLIK.md` ve bu zarfı oku. **ultracode YASAK.** Bu işin tek yazıcısı sensin; başka koltukların dosyalarını geri alma. Commit/dal/merge/push/PROD apply ve `.ss/` yazması YASAK.

## Girdiler ve sınır

- Otorite: `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/docs/plans/2026-09-28-ovsync-takip-ekrani/design.md` (§9 ve §10c–§10h; §10h, §10g'yi daraltır).
- Plan: `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/docs/plans/2026-09-28-ovsync-takip-ekrani/plan.md` (v7; P12'nin 1. adımı, KATALOG GÜNCELLEME 1–17, T-72b). Re-review5 KABUL raporu: `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/plan-rereview5.md` — üç ÖNEMLİ uygulama notu planın Açık kalemler bölümüne işlendi.
- Mevcut katalog: `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/docs/plans/2026-09-28-ovsync-takip-ekrani/test-senaryolari.md`. Mevcut test desenleri: `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/tests/`, özellikle `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/tests/support/`.
- Yalnız demo hedefi. Her DB bağlantısında hedefi ayrıca doğrula; PROD bağlantısı/açık veri üzerinde test yazması yok. Demo sahip şifresini değiştirme veya çıktıya basma. Her fixture'ın geri alım/temizlik yolunu belirt. `/tmp`'ye büyük veya sabit yol yazma; `TMPDIR`'i kullan.
- Bu tur ürün kodu, migration, plan, domain-rules, `.ss/` ve goal dosyalarını YAZMAZ. Ürün implementasyonu başlamadan testlerin kırmızı olması beklenir; bu durumu açık raporla, PASS diye adlandırma. B9 eski-yol kilit denetimi kapsam dışı.

## Yapılacaklar

1. Kataloğu plan P12 altındaki **KATALOG GÜNCELLEME 1–17** listesine tek tek hizala. Eski T-01..T-73 numaralarını koru; yeni varyantlara benzersiz kimlik ver. Her değişen/yeni senaryoda ön koşul, adımlar, DB sonucu, UI sonucu, ters kanıt ve spec/kabul referansı olsun. `SPEC SORULARI` yalnız gerçekten açık kalanları içersin; kapatılmış S-10 ve iki üretici kararını soru gibi bırakma.
2. Demo DB-SQL senaryolarını çalıştırılabilir dosyada yaz: Boş+seçim atomikliği, ≥40 g tek üretici, TAKIP_ACIK kapıları (authenticated REST `kizginlik_vaka_ac` tanıdan bağımsız negatif dahil), takip otomatik kapanış, muayene guard üç dalı, bulk/vaka_toplu karışık listede onaysız satırın `TAKIP_ACIK` dönüşü, eski/yeni imza ve anon ACL ayrı assertion'ları. PostgREST `PGRST202`/HTTP 404 beklentisini demo gerçek yanıtıyla sabitle; canlı şema veya response ölçülmediyse assertion'ı uydurma, KISMI de. Test fixture'ları demo ile sınırlı ve tekrar koşulabilir olsun.
3. Demo Playwright senaryolarını mevcut uygulama/test deseniyle yaz. Katalogdan UI katmanının temsilci pozitif/negatif akışlarını gerçek assertion'larla kapsa; yalnız `test.skip` veya boş iskelet teslim etme. Henüz UI yoksa beklenen kırmızı sonucu kaydet. Var olan `sonuclar.json` veya başka kullanıcı artefaktlarını ezme.
4. T-72b için iki gerçek DB bağlantılı, beş çift × N=30 eşzamanlı tur çalıştıran betik yaz: her bağlantıda `lock_timeout='5s'`; çiftler sarmal × `tohumlama_kaydet`, sarmal × `start_first_service_protocol`, sarmal × `seans_tamamla`, sarmal × `vaka_toplu_ac`, kapanış tetikleyicisi × sarmal. Çift başına **sonlu** izinli başarı/hata kodları ve tur raporu yaz; `40P01`, `55P03`, bilinmeyen kod veya timeout asla PASS değil. Planın `vb.` boşluğunu sessizce genişletme: kaynakla kapatamadığın çift için betiği fail-closed bırak ve DONE'da kesin açık sözleşmeyi bildir.
5. `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/ui-test-listesi.md` dosyasında glmf-max UI kapısı için madde madde beklenen görünümü ve kanıt türünü (DOM/ekran/konsol) yaz. Bu tur henüz tamamlanmamış UI'yı PASS sayma; sahip demosu için link verme.

## Yazabileceğin TEK dosyalar

- `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/docs/plans/2026-09-28-ovsync-takip-ekrani/test-senaryolari.md`
- `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/tests/sql/ovsync_takip_test.sql`
- `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/tests/concurrency/ovsync-takip-t72b.mjs`
- `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/tests/e2e/ovsync-takip.spec.js`
- `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/ui-test-listesi.md`
- `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/test-uygulanabilir-ILERLEME.md` (yalnız 09:00–13:00 duraklama özeti)
- `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/test-uygulanabilir-DONE.md`
- `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/.crumbs/ovsync-takip.jsonl` (yalnız satır ekleme, `role: lead`)

## Teslim ve kontrol

`node --check` ile iki JS dosyasının sözdizimi, `npx playwright test tests/e2e/ovsync-takip.spec.js --list` ile keşif, hedefli kırmızı test çıktısı, SQL betiğinin çalıştırma komutu/sonucu, T-72b betiğinin komutu/sonucu ve `git diff --check` çıktısı DONE'da olsun. Çalıştırılmayan katman `UNMEASURED`, beklenen kırmızı `RED`/`KISMI` olarak ayrı yazılsın. Test koşusu demo DB'ye erişemiyorsa kodun çalıştırılabilirliğini yerelde denetle, bağlantı sonucunu `UNMEASURED` bırak.

`/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/test-uygulanabilir-DONE.md` dosyasına `SONUÇ: TAMAM|KISMI|BLOKE`, değişen dosyalar, katalog 1–17 tablosu, senaryo/test sayısı, komut+çıkış, kırmızı nedenleri, açık H5/H7 sözleşmesi, yeni SPEC sorusu ve sınırları yaz. DONE'dan sonra dağıtan oturuma tek satır bildirim gönder; mesaj kanalı yoksa DONE dosyası teslim kanalıdır.
