# GÖREV — Plan düzeltmesi 5: luna re-review 3 (plan v5 → v6) — glm-max lead

İlk iş: /using-superpowers-obra, sonra Skill(writing-plans-obra). **ultracode YASAK.** Commit, kod, DB YAZMA YOK (demo'da salt-okuma sorgu serbest).
**GLM saat kuralı:** 09:00–13:00 GLM durur; 08:50'yi geçtiyse yeni adım başlatma, /home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/plan-fix5-ILERLEME.md'ye yaz, dur.
**YASAK:** `.ss/` altına (HANDOFF, BOARD dahil) yazma; oturum handoff'u yazma.

## Girdiler
- Review (DÜZELTME): /home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/plan-rereview3.md — (A) C3/C4/C5 KISMİ, (B) 4 KISMİ, (C) yeni #1–#3
- **MİMAR KARARLARI (yön bunlar, değiştirme):** /home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/docs/plans/2026-09-28-ovsync-takip-ekrani/design.md **§10g** (MK9-N, MK9-G, MK9-T, MK9-K, MK9-P, C4, C5)
- Plan (v5 → v6): /home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/docs/plans/2026-09-28-ovsync-takip-ekrani/plan.md
- Domain: /home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/.harness/references/domain-rules.md §14, §18

## Yapılacak (numaralı; DONE birebir sayar)
1. **MK9-N (KRİTİK):** DEGISMEZ 13'ü §10g MK9-N normatif biçimine çevir (hayvan kilidi = hayvan başına muteks, `FOR NO KEY UPDATE`, alt sıra serbest, "görev son katman" harfi iptal; çok-hayvanlı yollar `ORDER BY id`). `start_first_service_protocol` düzeltme tarifinde hayvan kilidi `FOR NO KEY UPDATE` olsun (mevcut `FOR UPDATE` değil).
2. **MK9-G (KRİTİK):** v5 uyum tablosunu **gerçek kilit grafiği** olarak yeniden yaz — §10g sütunlarıyla: yol · bayrak AÇIK kilit dizisi · bayrak KAPALI kilit dizisi · yardımcıdan miras kilit (dosya:satır; en az `_pg_kapi` 20260923000003:187-205) · muteks alt satırdan önce mi · tetikleyiciye giriş · hüküm. Yollar: tohumlama_kaydet, hizli_uygulama, bulk_ilac, seans_tamamla, start_first_service_protocol, create_case/_vaka_ac_tek, vaka_toplu_ac, kizginlik_vaka_ac, gorev_tamamla (jenerik), tohumlama_sonuc_gebe/_bos, yeni sarmal (tohumlama_bos_ve_devam), yeni kapanış tetikleyicileri. KAYNAKTAN ÖLÇ (yardımcı fonksiyon gövdeleri dahil); "kilit yok" ancak yardımcılar tarandıktan sonra. Muteks almayan ve birden fazla alt satır kilitleyen/yazan her yol → madde (muteks ekle) ya da sıra-uyum kanıtı.
3. **MK9-T:** P3 tetikleyici tarifine "takip satırına dokunmadan önce hayvan muteksi" ekle; tetikleyiciyi çalıştıran çağıranlar grafikte (madde 2) — muteks yok + çok-satır olanlara madde.
4. **MK9-K:** bayrak kapalıyken yeni yazma yolları `OZELLIK_KAPALI`; tetikleyiciler bayrak kapalıyken de çalışıyor mu — açıkça yaz (çalışıyorsa MK9-T onlar için de geçerli).
5. **MK9-P:** T-72b çapraz iki-oturum provasını §10g listesine genişlet (en az 5 çift: tohumlama_kaydet × sarmal, start × seans, bulk_ilac × bulk_ilac ters sıra, vaka_toplu_ac onaylı × sarmal, kapanış tetikleyicisi × sarmal) + madde 2'nin ürettiği riskli çiftler; kapsama matrisine işle.
6. **C4:** `kizginlik_vaka_ac` sunucu kapısı — açık takip + `p_takip_onay=false` → `RAISE 'TAKIP_ACIK:…'` TANIDAN BAĞIMSIZ; `true` → aynı tx `_takip_kapat` sonra INSERT; DB negatif testi (authenticated REST, onaysız → TAKIP_ACIK). P3b + P10 + P11/P12.
7. **C5:** PostgREST negatif beklentisi `PGRST202` / HTTP 404 (plan.md'deki `PGRST204` geçen HER yer: ör. :432, :765); test önce demo'da gerçek yanıtı kaydedip assertion'ı ona sabitler; yeni imza çalışır + anon EXECUTE yok ayrı assertion.
8. Review kapanış tablosuna "v6 kapanış" sütunu; kapsama matrisi + izlenebilirlik (§10g satırı); başlık v6. SPEC çelişkisi çıkarsa SPEC SORULARI (uydurma yok).

## Yazabileceğin dosyalar (liste dışı YASAK)
- /home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/docs/plans/2026-09-28-ovsync-takip-ekrani/plan.md
- /home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/plan-fix5-DONE.md, /home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/plan-fix5-ILERLEME.md
- /home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/.crumbs/ovsync-takip.jsonl (yalnız satır ekleme, role "lead")
Okuma alt-ajanları ≤6, dosya yazmaz.

## DONE
/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/plan-fix5-DONE.md — TAMAM|KISMI|BLOKE; 1–8 her kalem ayrı satır; kilit grafiği tablosu (ölçüm kaynaklarıyla); yeni SPEC SORULARI.
Sonra SendMessage ile tek satır: `DONE: <mutlak yol> · sonuc: <...>` → alıcı: seni başlatan prompt'ta yazan "Dağıtan oturum" adı.
