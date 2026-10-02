# GÖREV — Plan düzeltmesi 4: luna re-review 2 (plan v4 → v5) — glm-max lead

İlk iş: /using-superpowers-obra, sonra Skill(writing-plans-obra). **ultracode YASAK.** Commit, kod, DB YAZMA YOK (demo'da salt-okuma sorgu serbest).
**GLM saat kuralı:** 09:00–13:00 GLM durur; 08:50'yi geçtiyse yeni adım başlatma, /home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/plan-fix4-ILERLEME.md'ye yaz, dur.
**YASAK:** `.ss/` altına (HANDOFF, BOARD dahil) yazma; oturum handoff'u yazma.

## Girdiler
- Review (DÜZELTME): /home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/plan-rereview2.md — (A) KISMİ/AÇIK satırları + (B) KISMİ'ler + (C) C1–C6
- **MİMAR KARARLARI (yön bunlar, değiştirme):** /home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/docs/plans/2026-09-28-ovsync-takip-ekrani/design.md **§10f**
- Plan (v4 → v5): /home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/docs/plans/2026-09-28-ovsync-takip-ekrani/plan.md
- Domain: /home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/.harness/references/domain-rules.md §14, §18

## Yapılacak (numaralı; DONE birebir sayar)
1. **C3 / D5 / önceki #9 (KRİTİK):** §10f MK9 genel sözleşmesini plana işle — Global Constraints'e DEĞİŞMEZ olarak; P2a/P2b/P3b'deki `tohumlama → hayvanlar → gorev_log` ifadelerini MK9'a çevir; `start_first_service_protocol` düzeltmesini ayrı alt madde + kesin gövde değişikliği tarifi (20260925000017:44-62); takiple çakışan mevcut yolların (tohumlama_kaydet, hizli_uygulama, seans_tamamla, bulk_ilac, create_case/vaka_toplu_ac/kizginlik_vaka_ac) MK9 uyum tablosu — kaynaktan ÖLÇ, uyumsuz olanı madde yap. Çapraz deadlock provası kabul kriteri.
2. **C1 / D1 / kalem 11:** §10f C1 normatif çözücüyü P2b (çekirdek yazar) + P9 (UI okur) + P11 (saf yardımcı testi: geri_alindi dışlama, çoklu kayıt, UTC gece yarısı) olarak yaz. IDB `islem_log` store'unda `durum`/`ref_id`/`tarih` alanlarının bulunduğunu kaynaktan doğrula (js/api.js:30-35,535-546).
3. **C2 / D4 / önceki #1, #4:** bulk `p_takip_onaylar text[]` sözleşmesi, tekil `p_takip_onay`; retry yalnız onaylı id'ler; stok uygulanan satırlardan; P3b/P10 kesin imzalar (eski → yeni tablo).
4. **C4 / #16:** `kizginlik_vaka_ac` kapı envanterine; TAKIP_ACIK onayı; UI çağrı noktası (js/ui.js:5655-5662,5734-5742) P10'a; test.
5. **C5:** imzası değişen her RPC için eski overload DROP + ACL + PostgREST negatif test — P3b'ye tablo.
6. **C6:** P1/P2b dokunulan tablo envanteri + farm_id durumu (demo `information_schema` ile ÖLÇ); farm_id taşıyanlarda `current_farm_id()` filtresi.
7. Review kapanış tablosuna "v5 kapanış" sütunu; kapsama matrisi + izlenebilirlik (§10f satırı); başlık v5. SPEC çelişkisi çıkarsa SPEC SORULARI (uydurma yok).

## Yazabileceğin dosyalar (liste dışı YASAK)
- /home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/docs/plans/2026-09-28-ovsync-takip-ekrani/plan.md
- /home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/plan-fix4-DONE.md, /home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/plan-fix4-ILERLEME.md
- /home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/.crumbs/ovsync-takip.jsonl (yalnız satır ekleme, role "lead")
Okuma alt-ajanları ≤6, dosya yazmaz.

## DONE
/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/plan-fix4-DONE.md — TAMAM|KISMI|BLOKE; 1–7 her kalem ayrı satır; MK9 uyum tablosu + C6 envanter ölçüm çıktıları; yeni SPEC SORULARI.
Sonra SendMessage ile tek satır: `DONE: <mutlak yol> · sonuc: <...>` → alıcı: seni başlatan prompt'ta yazan "Dağıtan oturum" adı.
