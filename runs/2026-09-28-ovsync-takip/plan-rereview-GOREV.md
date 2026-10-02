# GÖREV — Plan RE-review (codex luna max — ss-lead-codex) — Ovsync takip + Boş-devam + birleşik muayene sonucu

İlk iş: /home/melik/.claude/skills/using-superpowers-obra/SKILL.md + references/codex-tools.md oku ve uygula (sahip kuralı).
Salt-okuma review. Commit, kod, plan düzenleme YOK. **ultracode YASAK.**
Domain kuralları ZORUNLU: /home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/.harness/references/domain-rules.md §14, §18 (18.13–18.17 yeni).

## Kapsam — DAR (tam review TEKRARLANMAZ)
Önceki review (codex sol yazdı; sen ilk kez bakıyorsun — bulguları oradan oku): /home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/plan-review.md (17 bulgu, VERDICT DÜZELTME).
Yalnız şu üç şeyi denetle:
1. **17 bulgunun kapanışı** — her bulgu için plan'daki "Review kapanış tablosu" satırını SPEC v4 §10c kararıyla karşılaştır; düzeltme plan gövdesinde gerçekten var mı (yalnız tabloda değil). Hüküm: KAPANDI | KISMİ | AÇIK.
2. **Yeni kapsam K14 + K15** (SPEC v4) — K15: GEBELIK_KONTROL ve TAKIP_MUAYENE aynı muayene sonuç bileşeni (Gebe · Boş→devam seçici · Muayeneyi ertele); GEBELIK_KONTROL sonuçsuz kapanamaz; cron (gebelik_muayene_gorev_uret) / dashboard 40 g listesi (gebelik_muayene_listele) ile takip ekranı S2 aynı kaynak; tetikleyici kapanışlarla çakışma (tohumlama_sonuc_bos açık GEBELIK_KONTROL'ü iptal ediyor) tasarlanmış mı; eski sistemin değişen davranışı ayrı P maddesi mi. K14: _katTipMap eşlemesi, hastalık kataloğu değişmeden.
2b. **Sahip kararları §10d (plan v3)** — +21/+35 GEBELIK_KONTROL üretiminin kaldırılması (tohumlama_kaydet gövdesi, `TOH-` kaynaklı görev iptallerine etkisi, cron görevinin Gebe/Boş ile kapanması, çift görev riski) + ayrı veri-temizliği maddesi; ertele saati varsayılanı NULL; dashboard 40 g satırı → birleşik ekran.
3. **"Mevcut akış haritası" bölümü** — mermaid + ekran→fonksiyon→RPC→tablo zincirlerini 2–3 noktada kaynaktan nokta-kontrol et (dosya:satır doğru mu, zincir halkası eksik mi). Ekran görüntüleri: /home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/akis-yuruyus/.

Yeni bulgu yalnız bu üç kapsamda ya da düzeltmenin YENİ açtığı bir kusurda yazılır; önceki review'da görmediğin eski konuları açma.

## Girdiler
- PLAN (düzeltilmiş): /home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/docs/plans/2026-09-28-ovsync-takip-ekrani/plan.md
- Yazarın DONE'ları: /home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/plan-fix-DONE.md, /home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/plan-fix2-DONE.md
- SPEC v4 (OTORİTE): /home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/docs/plans/2026-09-28-ovsync-takip-ekrani/design.md (§10b, §10c, §10d, K14, K15)
- Test kataloğu: /home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/docs/plans/2026-09-28-ovsync-takip-ekrani/test-senaryolari.md (kapsama matrisi T-01..T-73 planda)

## Çıktı (yazabileceğin TEK dosyalar)
- /home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/plan-rereview.md — başta VERDICT: KABUL | DÜZELTME | RED; sonra (A) 17 satırlık kapanış tablosu (bulgu # · hüküm · kanıt dosya:satır); (B) K14/K15 bulguları; (C) akış haritası nokta-kontrolleri; (D) yeni bulgular numaralı: şiddet (KRİTİK/ÖNEMLİ/KÜÇÜK) · plan madde no · kanıt (dosya:satır) · önerilen düzeltme (tek cümle). Kanıtsız bulgu yazma. KÜÇÜK bulgular tek başına DÜZELTME gerekçesi değildir.
- /home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/plan-rereview-DONE.md — sonuç (TAMAM|KISMI|BLOKE) + VERDICT + sayılar (kapandı/kısmi/açık, yeni KRİTİK/ÖNEMLİ/KÜÇÜK).
