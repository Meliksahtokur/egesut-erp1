# EgeSüt AI Asistan — Yol Haritası (Roadmap)

> **Tek kaynak doğruluk (single source of truth).** Asistan özelliğinin fazları, durumu ve tool planı.
> İlgili: tasarım `docs/superpowers/specs/2026-06-21-ai-asistan-mvp-design.md` · MVP plan `docs/superpowers/plans/2026-06-21-ai-asistan-mvp.md` · memory `project_ai_asistan`.
> Son güncelleme: 2026-06-22.

## Ne işe yarar
Uygulamaya gömülü AI asistan: çiftçi/operatör doğal dille (Türkçe) veritabanına soru sorar, asistan canlı veriye dayanarak cevaplar. **Asistan = builder DEĞİL** — son kullanıcı için. Builder işini Pi/Goose yapar.

## Mimari (kilitli kararlar)
- **Runtime:** Supabase Edge Function (Deno + Vercel AI SDK `npm:ai@6`). `supabase/functions/ai-agent/`.
- **Model:** MiniMax-M3 default (reasoning modeli — `<think>` blokları temizleniyor). Multi-provider altyapı hazır.
- **UI:** GitHub Pages'te ince frontend — `js/ai-asistan.js` + `index.html` (topbar 🤖 → `#pg-asistan`).
- **Güvenlik:** salt-okuma SQL (`transaction_read_only`) + whitelist + RLS + statement_timeout 5s + LIMIT 500. Yazmada (Faz 2+) HITL zorunlu.
- **Hafıza:** kalıcı thread'ler (`agent_threads` + `agent_messages` + RLS), pg_cron auto-prune (90 gün / 200 konuşma).
- **Çekirdek prensip:** LLM yorumlar/eşler · kod toplu işi yapar · insan PLANI onaylar (satırı değil).

## Faz haritası

| Faz | Alt-proje | Bağımlılık | Durum |
|---|---|---|---|
| **0** | Asistan Runtime (Edge loop + provider + auth + streaming + sayfa + tool/audit iskeleti) | — | ✅ **BİTTİ** (2026-06-21) |
| **1** | Salt-okuma Soru-Cevap (sql_sorgula + hayvan_detay) | 0 | ✅ **BİTTİ** (2026-06-21) |
| **1.5** | Cila: tutarlılık (prompt) + DUR butonu + input/buton UX | 1 | ✅ **BİTTİ** (2026-06-22, kullanıcı onaylı) |
| **2** | Yazma + HITL (onaylı aksiyonlar) | 1 | ✅ **BİTTİ** (2026-06-22) — plan motoru + 7 step + diff kartı |
| **2.5** | Cila: undo + mutfak gizleme + niyet eşleme + zengin kart | 2 | ✅ **BİTTİ** (2026-06-22) — kullanıcı "güven vermedi" geri bildirimi sonrası |
| **2.6** | stok_durum tool + güncel stok fix + UI (son promtu düzenle/iptal · işlem sayacı · tek tık kopyala) | 2.5 | ✅ **BİTTİ** (2026-06-23, commit 46a50d2) — agent baslangic_miktar'ı mevcut stok sanıyordu (Sefanel 0 dedi, gerçek 939); stok_tuketim_view.guncel_stok + stok_durum tool ile düzeltildi |
| **3** | Toplu import (Excel amiral) | 2 | ⬜ Bekliyor |
| **4** | Dosya tabanı + hafıza (Storage + pgvector RAG) | 0 | ⬜ Bekliyor |
| **5** | Web search (provider-native) | 0 | ⬜ Bekliyor |
| **6** | Multi-model UI (model seçici + reasoning görünümü) | 0 | ⬜ Bekliyor |

## Tool roadmap

**Yapıldı (Faz 0+1):**
1. ✅ `sql_sorgula` — salt-okuma SQL (her okuma sorusu)
2. ✅ `hayvan_detay` — tek hayvan 360° özeti

**Aksiyon tool'ları (Faz 2 — yazma + HITL, RPC'den geçer; SQL read-only kalır):** ✅ BİTTİ
Mimari: 2 generic tool (`aksiyon_plani` plan oluştur · `plani_uygula` onaylı uygula) + DB step registry.
7 step tipi: ✅ `gorev_kapat` · ✅ `hizli_uygulama` · ✅ `vaka_ac` (+`tedavi_gun_ekle`, $ref) · ✅ `tohumlama_kaydet` (state machine + VWP) · ✅ `padok_toplu` · ✅ `dogum_kaydet` (kalın RPC).

**Faz 3:** 7. ⬜ `hayvan_ekle_toplu` (Excel)

**Yetenek tool'ları:** 8. ⬜ `istatistik_hesapla` (edge_stat, Faz 1-2) · 9. ⬜ `web_arama` (Faz 5) · 10. ⬜ `gorsel_analiz`/`belge_oku` (Faz 4) · 11. ⬜ `disa_aktar` (CSV/PDF)

**UX köprüsü:** 12. ⬜ `uygulamada_ac` (deep-link: küpe → hayvan kartı)

**Mansiyon (backlog):** `not_ekle`, `hatirlat` (cron), `belge_ara` (RAG, Faz 4), `uygunluk_kontrol` (state-machine eligibility), `dusuk_stok_uyari`.

> ⚠️ Tool sayısı arttıkça LLM boğulma riski → çözüm: **bağlama göre tool aç** (örn. "veri giriş modu" vs "sorgu modu"). Faz 2 derdi.

## Bitmiş işlerin commit'leri
- MVP (Faz 0+1): `fab8969`
- Cila tutarlılık (prompt yetkilendirme, temp 0.5, stepCount 8): `ee6ff55`
- Cila DUR butonu + textarea + küçük buton: `478cfa2`
- Faz 2 (Yazma + HITL): `888dd25` agent_plans · `5369695` motor/$ref · `5369695` tool+rehber · `6c0bf01` diff kartı · hizli_uygulama · vaka/tedavi · ureme/padok/dogum step'leri (migration'lar `20260622000001..05`)

## Faz 2 mimari notları (ezber)
- **2 generic tool + DB step registry:** `aksiyon_plani`→`asistan_plan_olustur` (valide+pending, YAZMAZ), `plani_uygula`→`asistan_plan_uygula` (atomik, $ref çözer). Yeni aksiyon = `_asistan_step_dogrula` + `_asistan_step_calistir`'a 2 CASE dalı + rehber satırı.
- **Atomiklik:** `asistan_plan_uygula` adımları `EXCEPTION WHEN OTHERS` subtransaction'da sarar → herhangi step RAISE ederse hepsi geri sarılır, plan `failed`.
- **$ref bağımlılık:** bağımlı adım önceki çıktıya `"$N.anahtar"` ile başvurur (`_asistan_ref_coz`). Örn vaka_ac→tedavi_gun_ekle: `case_id:"$1.case_id"`.
- **HITL:** olustur pending bırakır; frontend diff kartı (Onayla/Vazgeç) → onay mesajı → LLM `plani_uygula` çağırır. Onaysız asla uygulanmaz (kanıtlandı).
- **RPC dönüş tuzağı:** `padok_degistir_toplu` `{success,error}` döner (ok değil) — runner success kontrol eder. `tohumlama_kaydet` 2 overload → named notation + `p_vwp_override` ile disambiguate.
- **Güvenlik duvarı:** DDL/migration/pg_cron/tanım düzenleme YASAK — agent reddedip uygulamada nereye gidileceğini söyler (test edildi).
- **Tablo:** `agent_plans` (pending/applied/cancelled/failed/expired + geri_alindi/kismen_geri_alindi) + RLS + 15dk prune cron (30dk bayat→expired).

## Faz 2.5 cila notları (kullanıcı "çalışıyor ama güven vermedi" geri bildirimi)
- **Undo (`asistan_plan_geri_al`):** kısmi undo + uyarı. Adımları TERS sırada, her biri kendi subtransaction'ında, SPESİFİK geri_al RPC'leriyle: gorev_geri_al / hizli_uygulama_geri_al / case_geri_al / tohumlama_geri_al. tedavi_gun_ekle+padok_toplu+dogum_kaydet **geri alınamaz → atlanır + raporlanır**. ⚠️ **Generic `geri_al(islem_id)` KULLANMA** — uygulama_log'u siler ama stok_hareket'i bırakır (stok sızıntısı); spesifik RPC'ler "İade" telafi hareketi ekler (stok doğru). Ampirik test edildi.
- **Frontend undo:** uygulanan plan → metadata.applied={plan_id} → "↩ Geri Al" kartı → `window.db.rpc('asistan_plan_geri_al')` DOĞRUDAN (LLM'e gitmez, hızlı).
- **Mutfak gizleme:** prompt "Sessiz çalış" — süreç/şema/araç anlatma yok ("şunu sorgulayayım", "şemaya bakayım" yasak). Kök neden: veri sözlüğünde cases/diseases/treatment_days yoktu → information_schema yokluyordu → eklendi.
- **aksiyon_plani ZORUNLU:** model bazen planı metin yazıp tool çağırmıyordu (kart çıkmıyor). Prompt: "tool çağırmadan plan/onay yazma".
- **Niyet eşleme:** "tedavi/tedavisine ekle" + aktif vaka (cases.status='active') → tedavi_gun_ekle (mevcut case_id); hizli_uygulama sadece vakasız bağımsız uygulama.
- **Zengin önizleme:** `_asistan_step_dogrula` ilaç adı+doz+vaka adı+grup özeti döner ("Buzağı İshali vakasına tedavi günü: Ademin 1ml IM @08:00"). Kart numaralı + "🔒 onaylamadan kaydedilmez" güvencesi.

## Kritik teknik notlar (Faz 2+ için ezber)
- **SECURITY DEFINER içinde `SET ROLE` YASAK** (PG 42501) → `SET LOCAL transaction_read_only=on` kullan.
- **Çift LIMIT bug:** kullanıcı SQL'i kendi LIMIT'ini içerebilir → `FROM (SELECT * FROM (%s) sub LIMIT 500) t` ile sarmala.
- **MiniMax-M3 `<think>` blokları** — backend (`thinkTemizle`) + frontend (`_asistanStripThink`) eşli/açık/öksüz etiketleri temizler.
- **Deploy:** `export SUPABASE_ACCESS_TOKEN=sbp_...` (token tools-bank/.env) + `supabase functions deploy ai-agent --project-ref zqnexqbdfvbhlxzelzju --no-verify-jwt`. MINIMAX_API_KEY Edge secret.
- **Veri gerçekleri:** cinsiyet='Dişi'/'Erkek', durum='Aktif'/'Ölü'/'Satıldı', tohumlama_durumu karışık case→ILIKE, renk çoğunlukla NULL, uygulama_log.etken_kod: ADEMIN/E_VIT/OKSITOSIN/PG.
- **Prompt dersi:** SDK agentinde model çekingense prompt'u SERTLEŞTİRME (YASAK/ZORUNLU + düşük temp + katı şablon → robotik) → YETKİLENDİR ("araçların var, güvenle kullan").
