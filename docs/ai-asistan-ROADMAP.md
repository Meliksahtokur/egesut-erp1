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
| **2** | Yazma + HITL (onaylı aksiyonlar) | 1 | ⬜ Sıradaki — ayrı brainstorming→spec→plan |
| **3** | Toplu import (Excel amiral) | 2 | ⬜ Bekliyor |
| **4** | Dosya tabanı + hafıza (Storage + pgvector RAG) | 0 | ⬜ Bekliyor |
| **5** | Web search (provider-native) | 0 | ⬜ Bekliyor |
| **6** | Multi-model UI (model seçici + reasoning görünümü) | 0 | ⬜ Bekliyor |

## Tool roadmap

**Yapıldı (Faz 0+1):**
1. ✅ `sql_sorgula` — salt-okuma SQL (her okuma sorusu)
2. ✅ `hayvan_detay` — tek hayvan 360° özeti

**Aksiyon tool'ları (Faz 2 — yazma + HITL, RPC'den geçer; SQL read-only kalır):**
3. ⬜ `hizli_uygulama` · 4. ⬜ `tohumlama_kaydet` (state machine) · 5. ⬜ `gorev_tamamla` / `gorev_olustur` · 6. ⬜ `padok_degistir` (tekli/toplu)

**Faz 3:** 7. ⬜ `hayvan_ekle_toplu` (Excel)

**Yetenek tool'ları:** 8. ⬜ `istatistik_hesapla` (edge_stat, Faz 1-2) · 9. ⬜ `web_arama` (Faz 5) · 10. ⬜ `gorsel_analiz`/`belge_oku` (Faz 4) · 11. ⬜ `disa_aktar` (CSV/PDF)

**UX köprüsü:** 12. ⬜ `uygulamada_ac` (deep-link: küpe → hayvan kartı)

**Mansiyon (backlog):** `not_ekle`, `hatirlat` (cron), `belge_ara` (RAG, Faz 4), `uygunluk_kontrol` (state-machine eligibility), `dusuk_stok_uyari`.

> ⚠️ Tool sayısı arttıkça LLM boğulma riski → çözüm: **bağlama göre tool aç** (örn. "veri giriş modu" vs "sorgu modu"). Faz 2 derdi.

## Bitmiş işlerin commit'leri
- MVP (Faz 0+1): `fab8969`
- Cila tutarlılık (prompt yetkilendirme, temp 0.5, stepCount 8): `ee6ff55`
- Cila DUR butonu + textarea + küçük buton: `478cfa2`

## Kritik teknik notlar (Faz 2+ için ezber)
- **SECURITY DEFINER içinde `SET ROLE` YASAK** (PG 42501) → `SET LOCAL transaction_read_only=on` kullan.
- **Çift LIMIT bug:** kullanıcı SQL'i kendi LIMIT'ini içerebilir → `FROM (SELECT * FROM (%s) sub LIMIT 500) t` ile sarmala.
- **MiniMax-M3 `<think>` blokları** — backend (`thinkTemizle`) + frontend (`_asistanStripThink`) eşli/açık/öksüz etiketleri temizler.
- **Deploy:** `export SUPABASE_ACCESS_TOKEN=sbp_...` (token tools-bank/.env) + `supabase functions deploy ai-agent --project-ref zqnexqbdfvbhlxzelzju --no-verify-jwt`. MINIMAX_API_KEY Edge secret.
- **Veri gerçekleri:** cinsiyet='Dişi'/'Erkek', durum='Aktif'/'Ölü'/'Satıldı', tohumlama_durumu karışık case→ILIKE, renk çoğunlukla NULL, uygulama_log.etken_kod: ADEMIN/E_VIT/OKSITOSIN/PG.
- **Prompt dersi:** SDK agentinde model çekingense prompt'u SERTLEŞTİRME (YASAK/ZORUNLU + düşük temp + katı şablon → robotik) → YETKİLENDİR ("araçların var, güvenle kullan").
