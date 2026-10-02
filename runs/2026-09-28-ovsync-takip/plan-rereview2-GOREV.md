# GÖREV — Plan RE-review 2 (codex luna max — ss-lead-codex) — plan v4

İlk iş: /home/melik/.claude/skills/using-superpowers-obra/SKILL.md + references/codex-tools.md oku ve uygula (sahip kuralı).
Salt-okuma review. Commit, kod, plan düzenleme YOK. **ultracode YASAK.** `.ss/` altına yazma yok.
Domain kuralları ZORUNLU: /home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/.harness/references/domain-rules.md §14, §18.13–18.17.

## Kapsam — DAR (tam review TEKRARLANMAZ)
Önceki re-review (luna, VERDICT DÜZELTME): /home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/plan-rereview.md — A tablosunda 7 KISMİ + D1–D8.
Yalnız şunları denetle:
1. **D1–D8 ve 7 KISMİ'nin kapanışı** — plan v4 gövdesinde (yalnız kapanış tablosunda değil). Hüküm: KAPANDI | KISMİ | AÇIK + kanıt dosya:satır.
2. **Yeni eklenenler:**
   - Kalem 11 (D1-UI, SPEC §10e): düzeltilen tohumlama iki satır; Boş giriş tarihi `islem_log` TOHUMLAMA_SONUC kaydının `tarih`'inden (timestamptz DEFAULT now()). Özellikle: timestamptz → **yerel (Europe/Istanbul) tarih** dönüşümü yazılmış mı; `durum='geri_alindi'` kayıtları dışlanıyor mu; birden çok TOHUMLAMA_SONUC kaydı varsa hangisi seçiliyor; offline/IDB'de `islem_log` bu ekran için mevcut mu (yoksa veri kaynağı ne?).
   - Kalem 12 (UI-R1, P9b): `gunFarkiEtiket` yerel gün farkı + test sınır vakaları.
   - #16 ölçümü sonrası `vaka_toplu_ac` ve `create_case` giriş kapı listesinde; `kizginlik_vaka_ac` kapsam dışı gerekçesi makul mü (Ovsync/PG vakası açabiliyor mu?).
   - D8 kararı (mevcut tablolarda farm_id yok → damga/predikat yok) §14 ile uyumlu mu.
3. **Düzeltmenin YENİ açtığı kusur** varsa (ör. D5 kilit sırası `tohumlama → hayvanlar → gorev_log` mevcut RPC'lerin kilit sırasıyla çelişip deadlock riski doğuruyor mu — kaynaktan kontrol et).

Eski kapanmış konuları yeniden açma. KÜÇÜK bulgu tek başına DÜZELTME gerekçesi değildir.

## Girdiler
- PLAN v4: /home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/docs/plans/2026-09-28-ovsync-takip-ekrani/plan.md
- Yazar DONE: /home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/plan-fix3-DONE.md
- SPEC v4 (OTORİTE): /home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/docs/plans/2026-09-28-ovsync-takip-ekrani/design.md (§10c, §10d, §10e)

## Çıktı (yazabileceğin TEK dosyalar)
- /home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/plan-rereview2.md — başta VERDICT: KABUL | DÜZELTME | RED; (A) D1–D8 + 7 KISMİ kapanış tablosu; (B) yeni eklenenler hükmü; (C) yeni bulgular numaralı: şiddet · plan madde · kanıt dosya:satır · önerilen düzeltme (tek cümle). Kanıtsız bulgu yazma.
- /home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/plan-rereview2-DONE.md — sonuç (TAMAM|KISMI|BLOKE) + VERDICT + sayılar.
