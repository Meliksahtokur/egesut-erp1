# GÖREV — Plan düzeltmesi 6: MK9 kapsam daraltması (plan v6 → v7) — glm-max lead

İlk iş: /using-superpowers-obra, sonra Skill(writing-plans-obra). **ultracode YASAK.** Commit, kod, DB YAZMA YOK (demo'da salt-okuma sorgu serbest).
**GLM saat kuralı:** 09:00–13:00 GLM durur; 08:50'yi geçtiyse yeni adım başlatma, /home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/plan-fix6-ILERLEME.md'ye yaz, dur.
**YASAK:** `.ss/` altına (HANDOFF, BOARD dahil) yazma; oturum handoff'u yazma.

## Girdiler
- Review (DÜZELTME): /home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/plan-rereview4-DONE.md — (C) 7 bulgu
- **MİMAR KARARI (yön bu, değiştirme; §10g ile çelişkide §10h kazanır):** /home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/docs/plans/2026-09-28-ovsync-takip-ekrani/design.md **§10h (H1–H9)**
- Plan (v6 → v7): /home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/docs/plans/2026-09-28-ovsync-takip-ekrani/plan.md
- Domain: /home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/.harness/references/domain-rules.md §14, §18

## Amaç
Bu tur KAPSAMI DARALTIR, genişletmez. Yeni kilit analizi, yeni envanter ajanı, yeni eski-yol taraması YAPMA. Yalnız §10h'yi plana işle.

## Yapılacak (numaralı; DONE birebir sayar)
1. **H1:** DEGISMEZ 13'ü daralt — MK9-N yalnız yeni nesneler + değişen RPC'lerin yeni kısmı. v6'nın eski yollara eklediği kilit maddelerini GERİ AL: `tohumlama_sonuc_bos` giriş NKU, `gorev_tamamla` görev→hayvan sıra düzeltmesi, `create_case` genel giriş NKU (ve bunlara bağlı kabul/prova/katalog satırları). `start_first_service_protocol` düzeltmesi KALIR.
2. **H2:** MK9-G kilit grafiği tablosunun başına "BİLGİ amaçlı — kabul ölçütü değil; eski-yol bulguları backlog B9" notu. Planın backlog/kapsam-dışı bölümüne **B9 "MK9 eski yol kilit denetimi"** satırı (girdi: plan-rereview3.md + plan-rereview4-DONE.md eski-yol bulguları: SUTTEN_KESME, hizli_uygulama_geri_al çok-satır, ham REST yazıcıları, tohumlama_sonuc_bos, gorev_tamamla sırası).
3. **H3:** MK9-T maddesini GERİ AL ve yerine yaz: tetikleyiciler hayvan kilidi ALMAZ; yalnız o hayvanın açık TAKIP_MUAYENE `gorev_log` satır(lar)ını günceller, idempotent, bayraktan bağımsız; BEFORE INSERT ret tetikleyicileri yalnız okur + RAISE. Yeni yollarda hayvan muteksinden sonra **tohumlama satırı takip `gorev_log` satırından ÖNCE** kilitlenir (P2b sarmal kilit sözleşmesine işle).
4. **H4:** yeni/değişen giriş noktalarında (sarmal muayene/takip modları, `kizginlik_vaka_ac` kapısı, start düzeltmesi) standart desen: kilitsiz keşif → hayvan `FOR NO KEY UPDATE` → alt satır `FOR UPDATE` + yeniden doğrulama; mevcut dönüş/hata/idempotentlik sözleşmesi korunur (her biri için tek cümle).
5. **H5:** `vaka_toplu_ac` ve `bulk_ilac` için v6'nın `ORDER BY id` retry kilit maddesini GERİ AL; yerine: mevcut döngü/kilit DEĞİŞMEZ; fonksiyon başında açık-takipli hayvanlar okunur; `p_takip_onaylar` dışında kalan açık-takipli satır işlenmez, satır sonucu `TAKIP_ACIK` (PG bulk `p_pg_onaylar` satır-sonucu deseniyle aynı — kaynaktaki desene referans ver); içindekiler için `_takip_kapat` o satır işlenmeden hemen önce; retry = onaylı alt kümeyle yeni çağrı; yeni boyut sınırı YOK. P3b imza tablosu + P10 retry + testler buna göre.
6. **H6:** `gorev_tamamla` guard'ı yalnız tamamlama dalı (`p_iptal` false/NULL) + yalnız GEBELIK_KONTROL/TAKIP_MUAYENE; `p_iptal=true` (T5, js/ui.js:1841-1844) ve SUTTEN_KESME/padok dalları aynen; guard yalnız görev tipini okur, kilit sırasını değiştirmez. Üç dal için davranış testi (kapsama matrisi).
7. **H7:** T-72b'yi sonuç oracle'ına çevir: 5 çift (sarmal × tohumlama_kaydet, sarmal × start, sarmal × seans_tamamla, sarmal × vaka_toplu_ac, kapanış tetikleyicisi × sarmal), iki bağlantılı betik, her çift N=30 eşzamanlı tur, `lock_timeout='5s'`; PASS = hiç `40P01`/`55P03` yok + her sonuç izinli kümede; "önce kırmızı" şartı KALDIRILIR; demo DB. v6'daki 5+4 çift listesi bununla değişir.
8. **H8:** istemci `40P01`/`55P03` → "İşlem başka bir kayıtla çakıştı, tekrar deneyin" (otomatik retry yok) — hangi JS hata-eşleme noktasına ekleneceğini kaynaktan bul (P9/P10), tek madde + birim test.
9. Review kapanış tablosuna "v7 kapanış" sütunu (rereview4 7 bulgu: H-kararıyla kapandı / B9'a devredildi); izlenebilirlik (§10h satırı); başlık v7; v6'dan kalan ve §10h ile çelişen her cümleyi temizle (grep: `MK9-T`, `tohumlama_sonuc_bos` NKU, `gorev_tamamla` sıra, `ORDER BY id` retry, "önce kırmızı"). SPEC çelişkisi çıkarsa SPEC SORULARI (uydurma yok).

## Yazabileceğin dosyalar (liste dışı YASAK)
- /home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/docs/plans/2026-09-28-ovsync-takip-ekrani/plan.md
- /home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/plan-fix6-DONE.md, /home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/plan-fix6-ILERLEME.md
- /home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/.crumbs/ovsync-takip.jsonl (yalnız satır ekleme, role "lead")
Okuma alt-ajanları ≤3, dosya yazmaz (bu tur ölçüm turu değil).

## DONE
/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/plan-fix6-DONE.md — TAMAM|KISMI|BLOKE; 1–9 her kalem ayrı satır; geri alınan maddelerin listesi; §10h çelişki grep'inin çıktısı (kalan eşleşmeler yalnız tarihsel bağlamda mı); yeni SPEC SORULARI.
Sonra SendMessage ile tek satır: `DONE: <mutlak yol> · sonuc: <...>` → alıcı: seni başlatan prompt'ta yazan "Dağıtan oturum" adı.
