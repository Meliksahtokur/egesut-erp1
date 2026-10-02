# GÖREV — Ovsync takip ekranı: madde numaralı uygulama planı (glm-max lead)

İlk iş: /using-superpowers-obra, sonra Skill(writing-plans-obra). **ultracode YASAK.** Commit atma, dal açma, kod yazma — çıktı yalnız plan belgesi.

## Girdiler (oku)
- SPEC v3 (sahip onaylı, OTORİTE): /home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/docs/plans/2026-09-28-ovsync-takip-ekrani/design.md
- Domain kuralları (ZORUNLU, §18 özellikle 18.13–16): /home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/.harness/references/domain-rules.md
- Mockup'lar: /home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/mockup/bos-devam/01..07-*.png (Boş-devam), /home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/mockup/ovsync-takip-mockup.png (v1 ekran)
- Raporlar: /home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/w1-kod-raporu.md, /home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/w2-veri-modeli-raporu.md, /home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/db-ovsync-durum-raporu.md
- Harness: /home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/.harness/contract.md, /home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/.harness/acceptance.md

## Çıktı
Plan dosyası: /home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/docs/plans/2026-09-28-ovsync-takip-ekrani/plan.md
- Madde numaralı (P1, P2, …); HER madde: spec § referansı, dokunulan dosya(lar), yapılacak iş, kabul ölçütü (doğrulanabilir), bağımlılık (hangi maddeden sonra), paralellenebilir mi.
- Sıra önerisi: DB migration(lar) → db-validate → takip RPC → §6c yazma RPC + tetikleyiciler → api/önbellek → #pg-ovsync sayfası → girişler (stat hücresi, 🔔 link, Görevler köprüsü) → devam seçici bileşeni + tüm Boş giriş noktaları → gezinme → testler (unit + Playwright demo + glmf-max UI test listesi).
- Spec §9 kabul 1–11'in her biri en az bir plan maddesine bağlanır (sonda izlenebilirlik tablosu).

## DEĞİŞMEZLER — plan bunları açıkça karşılamalı (plan-review bunları arar)
1. Sıralama tuzağı: `tohumlama_sonuc_bos` içindeki `_acik_disi_gorev_kur` Boş'ta OVSYNC_BASLAT açar. TAKIP seçiminde takip görevi ondan ÖNCE kurulur ya da o çağrı bu yolda atlanır; `_acik_disi_ovsync_hedef` muafiyetine "açık takip görevi" eklenir.
2. RPC_TABLES: takip RPC'si (salt-okunur) GİRMEZ (js/api.js:417-420 invariant'ı); §6c yazma RPC'si pull tablolarıyla GİRER.
3. TAKIP_ACIK kapısı sunucu tarafında, PG_KAPI deseniyle (RAISE + p_onay ikinci çağrı); UI uygulamanın kendi onay penceresi, confirm() değil; mevcut Ovsync/PG giriş noktalarının HEPSİ bu kapıdan geçer.
4. Takibin otomatik kapanışı TABLO TETİKLEYİCİSİYLE (tüm giriş yolları; kısır guard deseni): yeni tohumlama → sessiz; Ovsync/PG → onaylı; çıkış → kapanır; kapanış nedeni kaydedilir.
5. Fail-closed: bayrak kapalı → açık mesaj; offline → bayat etiket ya da açık mesaj; tanınmayan değer → "bilinmiyor"; sessiz boş/varsayılan YOK.
6. Ovsync hard block (kısır / kural günü gelmemiş) — §18.3 kapısı ESNETİLMEZ.
7. Muayene eşiği yalnız `_ayar('sessiz_tohumlama_muafiyet_gun',40)`; 21 gün hiçbir yerde yok. Deneme sayısı son doğumdan hesaplanır, `tohumlama.deneme_no` kullanılmaz.
8. Yeni SECURITY DEFINER'lar: search_path sabit, REVOKE PUBLIC+anon, GRANT authenticated; migration append-only, `scripts/db-validate.sh` kapısı; demo/prod ayrı.
9. Takip ekranı yeni yazma yolu içermez (§7.9); tek yeni yazma §6c RPC'si.

## Planın İLK maddesi: kod doğrulama (spec §6c sonu, 4 açık nokta)
Plan yazmadan önce koddan/migration'lardan doğrula ve plan.md başına "Doğrulanan gerçekler" bölümü olarak yaz (dosya:satır kanıtla):
(a) PG uygulamasının yazdığı tablo (hizli_uygulama → ?) — tetikleyici hedefi; (b) "son kullanılan PG ürün+doz" kaynağı; (c) takip görevi için yeni tip mi MUAYENE+kaynak işareti mi (Görevler kategori eşlemesi js/ui.js:63-68 dahil) — öneri + gerekçe; (d) gebelik muayenesi sonucu Boş giriş noktası(ları) (GEBELIK_KONTROL tamamlama yolu).
Spec'le çelişen bir gerçek bulursan planı o noktada durdurma — maddeyi "SPEC ÇELİŞKİSİ" diye işaretle, DONE'da raporla.

## Yazabileceğin dosyalar (liste dışı YASAK)
- /home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/docs/plans/2026-09-28-ovsync-takip-ekrani/plan.md
- /home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/plan-DONE.md
Fan-out serbest (okuma alt-ajanları, ≤6); alt-ajanlar hiçbir dosyaya yazmaz.

## DONE
/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/plan-DONE.md — sonuç TAMAM|KISMI|BLOKE; plan yolu; madde sayısı; doğrulanan 4 gerçek (1'er satır); SPEC ÇELİŞKİSİ listesi; açık sorular.
Sonra dağıtana tek satır: `DONE: /home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/plan-DONE.md · sonuc: <...>`
