# DONE — Ovsync takip ekranı: uygulama planı

- **Sonuç:** TAMAM
- **Plan yolu:** /home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/docs/plans/2026-09-28-ovsync-takip-ekrani/plan.md
- **Madde sayısı:** 13 (P1–P13: 3 migration + api katmanı + sayfa/gezınme + render + giriş noktaları + devam seçici + bağlama + TAKIP_ACIK zinciri + 3 test/doküman) + izlenebilirlik tablosu (spec §9 kabul 1–11'in her biri maddelere bağlı)
- **Yöntem:** 6 salt-okunur doğrulama alt-ajanı (Explore/sonnet, hiçbiri dosya yazmadı) → doğrulanan gerçekler plan başına yazıldı (file:satır kanıtlı) → plan yazıldı. ultracode KULLANILMADI; commit atılmadı; kod yazılmadı.

## Doğrulanan 4 gerçek (1'er satır)

- **(a)** PG olayının kanonik tablosu `pg_application_event` — üç yol (hızlı/seans/toplu) `_pg_olay_isle` tek boğazından yazar, `UNIQUE(source_type, source_id)`; tetikleyici hedefi bu [20260923000002:471-496; 20260925100005:292-316].
- **(b)** Son PG ürün+dozu: `pg_application_event` + `uygulama_log`(doz/birim) / `treatment_day_uygulamalar`(dose/unit) join + `stok.urun_adi`; `(farm_id, hayvan_id, occurred_at DESC)` index hazır; TOPLU_ILAC dalında doz belirsiz → fail-closed boş.
- **(c)** Öneri: yeni tip `TAKIP_MUAYENE` — gorev_tipi serbest text (CHECK yok), `_katTipMap.muayene`'ye tek satır (GEBELIK_KONTROL ile aynı çip), ertele kural seed satırı; MUAYENE+kaynak-işareti alternatifi manuel MUAYENE görevleriyle karışma + string-ayrıştırma kırılganlığı nedeniyle elendi.
- **(d)** GEBELIK_KONTROL tamamlama yolunda Boş atama YOK (jenerik `gorev_tamamla`); Boş'un tek mevcut yüzeyi `m-toh-det` (`tohSonuc`, forms.js:4347) + PG kapısı (muaf).

## SPEC ÇELİŞKİLERİ

1. **(d) — spec §6c.1'in saydığı "gebelik muayenesi sonucu (GEBELIK_KONTROL)" Boş giriş noktası kodda mevcut değil.** Plan P9'da "SPEC ÇELİŞKİSİ" damgasıyla işaretli; kapsam m-toh-det + PG kapısı (muaf, S7) + yeni 6c.4 ekranı olarak bağlandı. Plan durmadı (zarf kuralına uygun).
2. **(bildirimsel) §6c.2 imza genişlemesi:** `p_takip_gorev_id` + `p_secim='ERTALE'` + `p_secim=NULL` (yan etkisiz dry-run ön-bilgi) eklendi — tek-sarmal-RPC ve §7.9 tek-yeni-yazma-yolu ilkesi korunur; seçicinin kilit/ön-dolum bilgisi sunucu doğrusu olmadan hesaplanamaz.
3. **(copy) Mockup-05** muayene ekranında ana buton "Boş ata + …" diyor; atanacak yeni Boş yok — plan "Muayene tamam + …" pinler; sahip onayı bekleyen açık kalem.

## Açık kalemler (plan kapsamı dışı, sahibe)

- `supabase/migrations/99999999999999_ground_truth.sql` eski gövdeli `tohumlama_sonuc_bos` taşıyor (PERFORM'suz, anon GRANT'lı; ad-sırası 20260924000001'den sonra koşar) → `db reset` ortamında ovsync sürümünü ezebilir.
- `gebelik_muayene_listele` RPC repo migration'larında yok (UI çağırıyor, catch "yoksa bantsız devam" diyor) — muhtemelen yalnız canlıda; plan bağımlı değil (eşik doğrudan `_ayar`).
- Elle vaka aç RPC adı implementasyonda canlı şema teyidiyle sabitlenecek (P3).
- PROD apply sahip kapısı (plan yalnız demo provası içerir).

## Kanıt

- Plan: docs/plans/2026-09-28-ovsync-takip-ekrani/plan.md (bu worktree, commit'siz — teslim dal dışına çıkmadı)
- Kırıntılar: .crumbs/ovsync-takip.jsonl (bu oturumun 3 satırı)
- Alt-ajan kanıtları plan gövdesine file:satır olarak işlendi
