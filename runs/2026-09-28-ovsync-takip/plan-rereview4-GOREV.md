# GÖREV — Plan RE-review 4 (codex luna max — ss-lead-codex) — plan v6

İlk iş: /home/melik/.claude/skills/using-superpowers-obra/SKILL.md + references/codex-tools.md oku ve uygula (sahip kuralı).
Salt-okuma review. Commit, kod, plan düzenleme YOK. **ultracode YASAK.** `.ss/` altına yazma YASAK (HANDOFF, BOARD dahil).
Domain kuralları ZORUNLU: /home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/.harness/references/domain-rules.md §14, §18.13–18.17.

## Kapsam — DAR (tam review TEKRARLANMAZ)
Önceki re-review 3 (luna, DÜZELTME): /home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/plan-rereview3.md — (A) C3/C4/C5 KISMİ, (B) 4 KISMİ, (C) yeni #1–#3.
Mimar kararları (YÖN — bunlara uyum denetlenir, bunlara karşı değil): design.md **§10g** (MK9-N, MK9-G, MK9-T, MK9-K, MK9-P, C4, C5).
Yalnız şunları denetle:
1. **rereview3 KISMİ/yeni bulguların kapanışı** — plan v6 GÖVDESİNDE. Hüküm: KAPANDI | KISMİ | AÇIK + kanıt dosya:satır.
   - **MK9-G kilit grafiği (P3b):** hücreleri ÖRNEKLEME ile kaynaktan doğrula — en az 5 satır, bunlardan ikisi "kilit yok / tek-satır güvenli" hükümlü satır olsun (yardımcı zinciri dahil taranmış mı). Grafikte eksik aynı-hayvan yazıcısı var mı (ör. PostgREST doğrudan tablo UPDATE yolları, `js/` içinden `.from('gorev_log'|'tohumlama'|'cases').update/insert` çağrıları) — varsa §10g "tek-satır" kuralına göre hükmet.
   - **Yeni muteks maddeleri:** `tohumlama_sonuc_bos` giriş NKU, `gorev_tamamla` görev→hayvan sırasının düzeltilmesi, `create_case`/`kizginlik_vaka_ac` giriş NKU, `vaka_toplu_ac` onaylı retry `ORDER BY id` — tarif doğru ve davranışı (dönüş/hata sözleşmesi) değiştirmiyor mu; `FOR UPDATE` → `FOR NO KEY UPDATE` geçişleri FK KEY SHARE açısından doğru mu.
   - **MK9-T/MK9-K:** tetikleyiciler bayraktan bağımsız çalışıyorsa muteks alımı bayrak kapalıyken mevcut eski yollarla (MK5 bit-bit eski davranış) yeni bir döngü doğuruyor mu. `pg_application_event` üzerindeki ilk tetikleyici kurulum notu yeterli mi.
   - **MK9-P:** T-72b 5 + 4 çift kabul ölçütü olarak ölçülebilir mi (madde öncesi kırmızı / sonrası yeşil tanımı).
   - **C4:** `kizginlik_vaka_ac` sunucu kapısı tanıdan bağımsız + DB negatif testi. **C5:** `PGRST202`/404 + gerçek yanıt kaydı; `PGRST204` yalnız tarihsel bağlamda mı kaldı.
2. **v6'nın YENİ açtığı kusur** — özellikle yeni eklenen muteks maddelerinin mevcut RPC dönüş sözleşmesini, idempotentliği ya da performansı (toplu yollarda uzun kilit) bozup bozmadığı.

Eski kapanmış konuları (C1, C2, C6 ve önceki turlarda KAPANDI olanlar) yeniden açma. KÜÇÜK bulgu tek başına DÜZELTME gerekçesi değildir.

## Girdiler
- PLAN v6: /home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/docs/plans/2026-09-28-ovsync-takip-ekrani/plan.md
- Yazar DONE: /home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/plan-fix5-DONE.md
- SPEC (OTORİTE): /home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/docs/plans/2026-09-28-ovsync-takip-ekrani/design.md (§10c–§10g)

## Çıktı (yazabileceğin TEK dosyalar)
- /home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/plan-rereview4.md — başta VERDICT: KABUL | DÜZELTME | RED; (A) rereview3 kapanış tablosu; (B) kilit grafiği örneklem doğrulaması (satır · hüküm · kaynak); (C) yeni bulgular numaralı: şiddet · plan madde · kanıt dosya:satır · önerilen düzeltme (tek cümle). Kanıtsız bulgu yazma.
- /home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/plan-rereview4-DONE.md — sonuç (TAMAM|KISMI|BLOKE) + VERDICT + sayılar.
