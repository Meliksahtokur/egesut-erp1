# GÖREV — Plan RE-review 3 (codex luna max — ss-lead-codex) — plan v5

İlk iş: /home/melik/.claude/skills/using-superpowers-obra/SKILL.md + references/codex-tools.md oku ve uygula (sahip kuralı).
Salt-okuma review. Commit, kod, plan düzenleme YOK. **ultracode YASAK.** `.ss/` altına yazma YASAK (HANDOFF, BOARD dahil).
Domain kuralları ZORUNLU: /home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/.harness/references/domain-rules.md §14, §18.13–18.17.

## Kapsam — DAR (tam review TEKRARLANMAZ)
Önceki re-review 2 (luna, VERDICT DÜZELTME): /home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/plan-rereview2.md — (A) KISMİ/AÇIK satırları, (B) KISMİ'ler, (C) C1–C6.
Mimar kararları (YÖN — bunlara karşı değil, bunlara uyum denetlenir): design.md **§10f**.
Yalnız şunları denetle:
1. **C1–C6 kapanışı** — plan v5 GÖVDESİNDE (yalnız kapanış tablosunda değil). Hüküm: KAPANDI | KISMİ | AÇIK + kanıt dosya:satır. Özellikle:
   - **C3 (KRİTİK) MK9:** Global Constraints'te DEĞİŞMEZ olarak var mı (hayvan `FOR NO KEY UPDATE` ilk → tohumlama → vaka/seans → görev; toplu yollar `ORDER BY id`; advisory lock YOK). MK9 uyum tablosundaki her mevcut yol için "uyumlu" iddiasını KAYNAKTAN doğrula (tohumlama_kaydet, hizli_uygulama, seans_tamamla, bulk_ilac, create_case, vaka_toplu_ac, kizginlik_vaka_ac, start_first_service_protocol). `start_first_service_protocol` düzeltme tarifi (görev kilitsiz oku → hayvan kilitle → görev kilitle + yeniden doğrula) doğru ve yeterli mi. Çapraz iki-oturum deadlock provası kabul kriteri olarak yazılı mı.
   - **C1:** çözücü (`tip='TOHUMLAMA_SONUC' AND ref_tablo='tohumlama' AND ref_id=<toh> AND durum IS DISTINCT FROM 'geri_alindi'` + snapshot Boş, `ORDER BY tarih DESC, id DESC LIMIT 1`, Europe/Istanbul yerel tarih) P2b + P9 + P11'de aynı; IDB `islem_log` alan iddiası (js/api.js) doğru mu; `fmtTarih` ilk-10-karakter kesimi timestamptz için kullanılmıyor mu.
   - **C2:** bulk `p_takip_onaylar text[]`, tekil scalar `p_takip_onay`; retry yalnız onaylı id'ler; stok uygulanan satırlardan; eski→yeni imza tablosu kesin mi.
   - **C4:** `kizginlik_vaka_ac` kapı envanterinde + UI çağrı noktası + test.
   - **C5:** her imzası değişen RPC için eski overload DROP + ACL + PostgREST negatif test tablosu eksiksiz mi (C2'nin değiştirdiği imzalar dahil).
   - **C6:** dokunulan tablo envanteri + farm_id durumu ölçümle; `pg_application_event` ve yeni nesnelerde `current_farm_id()` filtresi; kolonsuz tablolara predikat/damga YOK.
2. **rereview2 (A)/(B)'deki KISMİ/AÇIK satırlar** (D1, D4, D5, önceki #1/#4/#9/#16, kalem 11, #16 kapı listesi) — C'lerle kapanıyorsa tek satırda belirt.
   - **Mimar nokta-kontrol notu:** `tohumlama_kaydet`'in hayvan kilidi yalnız `IF public._ovsync_pg_aktif()` iken alınıyor (20260923000005:326-328); bayrak kapalıyken tohumlama `FOR UPDATE` ilk kilittir. v5 "UYUMLU" hükmü bu dalı kapsıyor mu, bayrak kapalıyken sarmal/takip yolları gerçekten kapalı mı (MK9 ihlali doğmaz) — kaynaktan hükmet.
3. **v5'in YENİ açtığı kusur** — özellikle MK9'a çevrilen sıranın yeni bir çağrı yolunda (sarmal modlar, tablo tetikleyicileri, toplu yol) ters sıra doğurup doğurmadığı; tetikleyici içinden hayvan kilidi alınması gibi.

Eski kapanmış konuları yeniden açma. KÜÇÜK bulgu tek başına DÜZELTME gerekçesi değildir.

## Girdiler
- PLAN v5: /home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/docs/plans/2026-09-28-ovsync-takip-ekrani/plan.md
- Yazar DONE: /home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/plan-fix4-DONE.md
- SPEC (OTORİTE): /home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/docs/plans/2026-09-28-ovsync-takip-ekrani/design.md (§10c–§10f)

## Çıktı (yazabileceğin TEK dosyalar)
- /home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/plan-rereview3.md — başta VERDICT: KABUL | DÜZELTME | RED; (A) C1–C6 kapanış tablosu; (B) rereview2 KISMİ/AÇIK kapanışı; (C) yeni bulgular numaralı: şiddet · plan madde · kanıt dosya:satır · önerilen düzeltme (tek cümle). Kanıtsız bulgu yazma.
- /home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/plan-rereview3-DONE.md — sonuç (TAMAM|KISMI|BLOKE) + VERDICT + sayılar.
