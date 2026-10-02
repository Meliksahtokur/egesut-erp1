# GÖREV — Plan review (sol / codex) — Ovsync takip + Boş-devam

Salt-okuma review. Commit, kod, plan düzenleme YOK. ultracode YASAK.
Önce: /home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/AGENTS.md ve /home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/.harness/contract.md (kısa); domain kuralları ZORUNLU: /home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/.harness/references/domain-rules.md §18.

## İncelenecek
- PLAN: /home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/docs/plans/2026-09-28-ovsync-takip-ekrani/plan.md (+ yazarın DONE'u: /home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/plan-DONE.md)
## Otorite
- SPEC v3: /home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/docs/plans/2026-09-28-ovsync-takip-ekrani/design.md (§6c, §7, §9, §10, §10b sahip/mimar cevapları dahil)
- Test kataloğu (planın kapsaması gereken davranışlar): /home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/docs/plans/2026-09-28-ovsync-takip-ekrani/test-senaryolari.md
- Mockup'lar: /home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/mockup/bos-devam/*.png, /home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/mockup/v2/*.png

## Sorular
1. Her plan maddesi bir spec §'ine bağlı mı; spec'te olup planda olmayan davranış var mı (özellikle §10b S-3: takip muayenesinde Gebe → son tohumlama Gebe'ye; S-7: ≥21 gün erteleme onayı; S-4 tek birleşik onay; S-5 bayrak kapalı)?
2. Değişmezler karşılandı mı: (a) TAKIP seçiminde OVSYNC_BASLAT doğmaz (_acik_disi_gorev_kur sıralaması + _acik_disi_ovsync_hedef muafiyeti) (b) takip RPC'si RPC_TABLES'a girmez, yazma RPC'si girer (c) TAKIP_ACIK sunucu tarafında PG_KAPI deseni, TÜM Ovsync/PG giriş noktaları (d) otomatik kapanış tablo tetikleyicisiyle (pg_application_event, tohumlama, cases, çıkış) + kapanış nedeni (e) fail-closed (f) kısır/kural günü hard block (g) SECURITY DEFINER + REVOKE PUBLIC/anon (h) muayene eşiği yalnız _ayar(...,40).
3. Planın "Doğrulanan gerçekler"ini NOKTA-KONTROL et. Mimar bir tanesini zaten YANLIŞ buldu: plan-DONE "gebelik_muayene_listele repo migration'larında yok" diyor — oysa supabase/migrations/20260925000002_sessiz_siniflandirma.sql:287'de tanımlı. Diğer 4 gerçeği (a–d) kaynaktan doğrula.
4. SPEC ÇELİŞKİLERİ 1–3 (plan-DONE): yazarın çözümü makul mü; §6c.2 imza genişlemesi (p_secim NULL dry-run, ERTALE) tek-yazma-yolu ilkesini bozuyor mu; 'ERTALE' yazımı.
5. ground_truth.sql'deki eski tohumlama_sonuc_bos gövdesi riski — plan bunu ele almalı mı?
6. Sıralama/bağımlılık: migration → RPC → UI sırası, paralellenebilir işaretler doğru mu; her madde tek oturumda uygulanabilir boyutta mı.
7. Test kataloğundaki senaryoların plan tarafından kapsanmayanları (T-numarasıyla).

## Çıktı (yazabileceğin TEK dosyalar)
- /home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/plan-review.md — başta VERDICT: KABUL | DÜZELTME | RED; sonra bulgular numaralı, her biri: şiddet (KRİTİK/ÖNEMLİ/KÜÇÜK) · plan madde no · kanıt (dosya:satır) · önerilen düzeltme (tek cümle). Kanıtsız bulgu yazma.
- /home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/plan-review-DONE.md — sonuç + bulgu sayıları.
