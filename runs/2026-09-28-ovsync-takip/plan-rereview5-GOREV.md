# GÖREV — Plan RE-review 5 (codex luna max — ss-lead-codex) — plan v7

İlk iş: /home/melik/.claude/skills/using-superpowers-obra/SKILL.md + references/codex-tools.md oku ve uygula (sahip kuralı).
Salt-okuma review. Commit, kod, plan düzenleme YOK. **ultracode YASAK.** `.ss/` altına yazma YASAK (HANDOFF, BOARD dahil).
Domain kuralları ZORUNLU: /home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/.harness/references/domain-rules.md §14, §18.13–18.17.

## Kapsam — ÇOK DAR (§10h H9 yakınsama kuralı BAĞLAYICI)
Mimar kararı: /home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/docs/plans/2026-09-28-ovsync-takip-ekrani/design.md **§10h (H1–H9)** — MK9 kapsam daraltması. §10g ile çelişkide §10h kazanır.
Bu tur YALNIZ §10h'nin plan v7'ye doğru işlenip işlenmediğini denetler:
1. **H1–H8 her biri:** plan v7 GÖVDESİNDE uygulanmış mı. Hüküm: UYGULANDI | KISMİ | UYGULANMADI + kanıt `plan.md:satır`.
   - H1: eski yollara v6'da eklenen kilit maddeleri (`tohumlama_sonuc_bos` giriş NKU, `gorev_tamamla` sıra düzeltmesi, `create_case` genel giriş NKU) planda kalmış mı; `start_first_service_protocol` düzeltmesi duruyor mu.
   - H3: tetikleyiciler hayvan kilidi ALMIYOR mu; yeni yollarda tohumlama → takip `gorev_log` sırası yazılı mı; bu sıra ile tetikleyicinin (AFTER INSERT ON tohumlama → gorev_log) yönü gerçekten aynı mı — kaynakla (mevcut `tohumlama_kaydet` bayrak açık/kapalı dalları) çelişen bir AB/BA **bu işin yeni kodu içinde** kaldı mı.
   - H4: giriş deseni (kilitsiz keşif → hayvan NKU → alt satır FOR UPDATE + yeniden doğrulama) yeni/değişen giriş noktalarında; mevcut dönüş/hata sözleşmesi korunuyor mu.
   - H5: `vaka_toplu_ac`/`bulk_ilac` mevcut kilit davranışı değişmiyor; satır sonucu `TAKIP_ACIK` mevcut PG bulk satır-sonucu deseniyle uyumlu mu (kaynak).
   - H6: `gorev_tamamla` guard yalnız tamamlama dalı; `p_iptal=true` ve SUTTEN_KESME/padok dalları korunuyor mu.
   - H7: T-72b sonuç oracle'ı ölçülebilir mi (N, lock_timeout, SQLSTATE, izinli sonuç kümesi).
   - H8: 40P01/55P03 istemci mesajının JS eşleme noktası doğru yer mi (kaynak).
2. **§10h ile çelişen artık cümle** plan v7'de kaldı mı (MK9-T, "önce kırmızı", ORDER BY id retry vb. — tarihsel bağlam hariç).
3. **v7'nin bu işin kapsamında YENİ açtığı KRİTİK kusur** varsa.

**YAPMA:** eski yolların (H1/H2 kapsam dışı; backlog B9) kilit davranışını denetleme/bulgu yazma — görürsen (D) bölümüne "B9 notu" olarak tek satır yaz, DÜZELTME gerekçesi değildir. Önceki turlarda KAPANDI olan konuları yeniden açma. ÖNEMLİ/KÜÇÜK bulgu tek başına DÜZELTME gerekçesi DEĞİLDİR — yalnız bu işin kapsamındaki KRİTİK bulgu DÜZELTME doğurur; aksi hâlde VERDICT KABUL (bulgular "uygulama sırasında düzelt" notu olarak listelenir).

## Girdiler
- PLAN v7: /home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/docs/plans/2026-09-28-ovsync-takip-ekrani/plan.md
- Yazar DONE: /home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/plan-fix6-DONE.md
- Önceki review: /home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/plan-rereview4-DONE.md
- SPEC (OTORİTE): /home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/docs/plans/2026-09-28-ovsync-takip-ekrani/design.md (§10c–§10h)

## Çıktı (yazabileceğin TEK dosyalar — İKİSİ DE ZORUNLU)
- /home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/plan-rereview5.md — başta VERDICT: KABUL | DÜZELTME | RED; (A) H1–H8 uygulama tablosu; (B) artık çelişkili cümleler; (C) bu işin kapsamında yeni bulgular numaralı: şiddet · plan madde · kanıt dosya:satır · önerilen düzeltme (tek cümle); (D) B9 notları (kapsam dışı eski yol gözlemleri, tek satır). Kanıtsız bulgu yazma.
- /home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/plan-rereview5-DONE.md — sonuç (TAMAM|KISMI|BLOKE) + VERDICT + sayılar (rapor dosyasına işaret eder; raporun yerine geçmez).
