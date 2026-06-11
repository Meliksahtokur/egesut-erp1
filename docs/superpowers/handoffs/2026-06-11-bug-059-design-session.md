# BUG-059 Saat Bazlı Tedavi Seans — Design Session Handoff

> **Tarih:** 2026-06-11
> **Oturum:** Goose worker, ACP recipe `egesut-telsiz`, session_id `2026-06-11-bug059-design`
> **Süre:** ~6 saat (research → brainstorm → spec → review → plan)
> **Sonraki oturum:** Faz 0'dan implementation başlatılacak (subagent-driven-development)

---

## 1. Bug Özeti (BUG-059)

**Sorun:** EgeSüt ERP tedavi modülünde 1 gün içinde 1'den fazla seans yapılamıyor. Mevcut sistem `seans_sayisi` kolonu olmadan tek seans varsayıyor, reçete değişikliği reaktif değil.

**Çözüm:** Her seans = 1 satır (`treatment_day_uygulamalar` tablosu), saat+ilaç+doz+yol bazlı, reaktif reçete güncellemesi, geriye uyumlu (4 mevcut vaka etkilenmez).

**Etkilenen dosyalar:**
- `supabase/migrations/99999999999999_ground_truth.sql` (canonical referans, Faz 3'te güncellenecek)
- `js/api.js` (5 RPC helper)
- `js/ui.js` (tedavi modal + renderTask + vaka modal — 6828 satırlık devasa dosya, refactor riski)
- `js/forms.js` (form submit handler)

## 2. Mimari Kararlar (7 Brainstorming Cevabı)

| # | Karar | Açıklama |
|---|---|---|
| 1 | **Realtime chain** (seçenek A) | Plan değişikliği → RPC 3 + fn_dinle trigger → gorev_log sync. Eager/hybrid reddedildi. |
| 2 | **Saat bazlı, N serbest seans** | Şablon/slot yok, her gün istenilen sayıda seans + serbest saat (UNIQUE(time) ile çakışma koruması) |
| 3 | **Per-session done tracking** | Her seansın kendi `uygulama_tamamlandi_at` + `uygulanmadi` boolean'ı |
| 4 | **Backward compat: C** | Yeni tablo + eski 4 vaka korunur, `seans_sayisi` kolonu ile dual-path dispatch |
| 5 | **drug_admin = single source of truth** | Tedavi planı drug_admins'te, seans sadece "zaman + sıra" metadata |
| 6 | **Modal: A+B hibrit** | Mevcut UI + yeni saat/seans accordion birlikte |
| 7 | **Sadece vaka modal'da plan** | Dashboard'da sadece görev kartı, plan detayı vaka modal'da |

## 3. 5 RPC Özeti (Faz 2'de yazılacak)

| RPC | Tip | Amaç | Kritik Kural |
|---|---|---|---|
| `add_treatment_day_with_sessions` | YENİ | Tek gün + N seans ekle (atomik stok düşümü ile) | K1: stok_hareket.id TEXT, K2: stok INSERT atomik, K5: drug_admins.seans_admin_id FK |
| `seans_tamamla` | YENİ | Tek seans done + uygulanmadi sync | SELECT FOR UPDATE + WHERE guard (race) + GET DIAGNOSTICS |
| `recete_guncelle` | YENİ | Tüm planı sil + yeniden yaz (DRY) | `add_treatment_day_with_sessions`'a delege eder (`p_existing_day_id`) |
| `close_case_with_remaining` | YENİ | Vaka erken kapatma + kalan seansları iptal | Stok iade + `uygulanmadi=true` (done DEĞİL) |
| `treatment_day_tamamla` | GÜNCELLE | Gün done + tüm seanslar done sayılır | Idempotent (zaten done ise noop) + Y-v3-1: stok_hareket_ref direkt |

**Yardımcı kolonlar (4 ALTER):**
- `treatment_days.seans_sayisi smallint` (1=eski, N=yeni)
- `gorev_log.seans_admin_id uuid` (FK → treatment_day_uygulamalar.id, NULL olabilir)
- `gorev_log.hedef_saat time` (UI'da saat rozeti)
- `drug_administrations.seans_admin_id uuid` (FK → treatment_day_uygulamalar.id, K5 bağlantısı)

## 4. Review Geçmişi (Toplam 41 Bulgu Giderildi)

### Spec (1065 satır, 3 commit, v4 ONAY)
- **v1** sub-agent async: 12 bulgu (K1-5, Y1-4, O1-3) — hepsi uygulandı
- **Self-review**: 1 bulgu (treatment_day_tamamla idempotent değildi)
- **v2** inline: 4 bulgu (K-NEW-1, Y-NEW-1/2, D1)
- **v3** inline: 5 bulgu (Y-v3-1, O-v3-1, D-v3-1/2/3)
- **v4** ONAY: 0 kritik, 0 yüksek, 0 orta, 0 düşük
- **Toplam: 22 bulgu**

### Plan (1297 satır, 2 commit, v3 ONAY)
- **v1** sub-agent sync: 8 bulgu (Y1 smoke FK, O1 UUID LIKE, O2 stok count, O3 placeholder SQL, O4 ground truth stratejisi, D1 çift commit, D2 22→21 sayısı, D3 dual close path)
- **v2** inline: 6 bulgu (Y-v2-1 Step 4.7 Y1 kopyası, O-v2-1 created_at tarih hatası, O-v2-2 commit sayısı, O-v2-3 hayalet 2. SQL dosyası, D-v2-1 pullTables yanlış, D-v2-2 senaryo C "2→3")
- **v3** inline: 5 bulgu (D-v3-1 Step 2.13→2.12, D-v3-2 çift "Değişen Dosyalar" başlığı, D-v3-3 senaryo C beklenen, D-v3-4 stok cleanup sıralama + JOIN tarih, D-v3-5 state.js pullTables kontrol notu)
- **Toplam: 19 bulgu**

**Genel toplam: 41 review bulgusu (22 spec + 19 plan), 0 açık.**

## 5. tools-bank / GitNexus Kullanımı (Hangi Araç Ne Zaman)

| Faz | Birincil Araç | Yedek | Neden |
|---|---|---|---|
| **0** Pre-check | `memory_search` (kritik kurallar) | `supabase_query` (information_schema), `semantic_search`, `gitnexus_impact` | Pato 12: ground truth sync, schema drift önleme |
| **1** Schema | `supabase_migrate` (DDL çalıştır) | `supabase_query` (verify) | DDL = canlıya yansır, dikkat |
| **2** RPC | `supabase_migrate` (CREATE FUNCTION) | `supabase_rpc` (smoke), `gitnexus_detect_changes` | 5 RPC atomik, sonra JS çağrıları eşle |
| **3** Ground truth sync | `edit` (canonical SQL) + sentinel pattern | `repomix__pack_codebase` (mimari özet) | Tek canonical referans, write 3 parçaya böl |
| **4** Deploy verify | `supabase_query` (snapshot) | `supabase_rpc` (smoke — opsiyonel) | canlı doğrulama |
| **5** UI | `ast_grep_search` (js pattern bul) | `gitnexus_context` (sembol 360°), `edit` + sentinel | 6828 satırlık ui.js'te hedefli değişiklik |
| **6** Test | `supabase_rpc` (10 senaryo) | `supabase_query` (doğrulama) | canlı uçtan uca |
| **7** Handoff | `memory_add` (kritik kararlar) | `todo_write` (kapat) | sonraki oturum için bilgi bankası |

**Pato 12 (asla unutma):** Migration dosyalarında `*_revize.sql`, `*_fix.sql` ara referans DEĞİL. Canonical = `99999999999999_ground_truth.sql`. Spec'te yazılan ile canlıdaki arasında drift olabilir — her zaman `information_schema.columns` ile doğrula.

## 6. Bilinen Tuzaklar (Implementation'da Dikkat)

1. **stok_hareket.id = TEXT** (uuid değil!) — FK referanslarında `text` kullan
2. **drug_admins ↔ seans K5 FK** — `seans_admin_id` üzerinden bağlanır, doğrudan ID eşleşmesi YOK
3. **stok_hareket_ref** — yeni seanslarda dolu, eski tek-seans vakalarda NULL (dual path zorunlu)
4. **treatment_days.tamamlandi_at IS NULL** — "done" semantiği, ama seanslar `uygulama_tamamlandi_at` ile takip edilir
5. **`seans_tamamla(admin_id, true, 'stok iade')`** — `true` = `uygulanmadi=true` (yapılmadı, stok iade). `false` = normal done.
6. **Senaryo C: 3→2 seans, ilaç X silinir, ilaç Y eklenir** — D-v3-3 fix, metin "2→3" değil "3→2"
7. **Stok cleanup sıralama** — D-v3-4 fix: önce UPDATE iade (drug_admins var), sonra DELETE CASCADE
8. **write aracı 3 parçaya böl** — SQL + Türkçe unicode + markdown fence bir arada parse hatası verir
9. **js/ui.js 6828 satır** — refactor riski, hedefli değişiklik (`ast_grep_search` ile bul, `gitnexus_context` ile blast radius ölç)
10. **PWA CDN-only** — Vite/React ekleme, vanilla JS koru, onaysız feature ekleme

## 7. Commit Geçmişi (Bu Oturum, 6 Push)

```
14aada1  spec: BUG-059 saat bazlı tedavi seans (v1, 3 parça yazım)
161391f  docs: BUG-059 spec review düzeltmeleri (K1-5, Y1-4, O1-3)
9f22982  docs: BUG-059 spec review v3 düzeltmeleri (v4 ONAY)
19f77b5  docs: BUG-059 implementation plan v1 (1269 satır, 8 Faz)
ab417e7  docs: BUG-059 plan v1+v2 polish (14 fix)
4232955  docs: BUG-059 plan v3 polish fix (5 fix)  ← SON PUSH
```

**Branch:** main (direkt push, branch kullanılmadı — kural)

## 8. Sonraki Oturum İçin Yapılacaklar (Implementation Handoff)

**Faz 0 — Pre-Check** (10 dk):
1. `memory_search("BUG-059 saat bazli seans")` → kritik kuralları getir
2. `supabase_query(information_schema.columns, treatment_days)` → şema doğrula
3. `supabase_query(information_schema.columns, drug_administrations)` → K5 FK doğrula
4. `gitnexus_impact(target="add_treatment_day")` → blast radius ölç
5. Snapshot: `treatment_days`, `drug_administrations`, `gorev_log`, `stok_hareket` COUNT

**Faz 1 — Schema Migration** (30 dk):
- Yeni tablo: `treatment_day_uygulamalar` (5 partial index ile)
- 4 ALTER (yukarıdaki kolonlar)
- Migration dosyası: `20260611000001_bug059_treatment_sessions.sql`
- DOĞRULAMA: `supabase_query` ile yeni tablo + 4 kolon görünür

**Faz 2 — 5 RPC** (60 dk):
- Aynı migration dosyasına ekle (D1 fix: tek commit)
- DOĞRULAMA: `pg_proc WHERE proname IN (...)` ile 5 RPC görünür

**Faz 3 — Ground Truth Sync** (20 dk):
- `99999999999999_ground_truth.sql` dosyasına inline ekle (O4 fix)
- CREATE TABLE içine yeni kolonları ekle, ALTER bloğu OLUŞTURMA
- DOĞRULAMA: diff temiz

**Faz 4 — Deploy + Validate** (15 dk):
- Migration'ı canlıya gönder (`supabase_migrate`)
- Snapshot karşılaştır (veri kaybı yok)
- Smoke test: gerçek bir stok_id ile `add_treatment_day_with_sessions` (Y1 fix)
- Eski 4 vakayı aç, `treatment_day_uygulamalar` BOŞ olmalı (F uyumluluğu)

**Faz 5 — UI** (90 dk, en riskli):
- `ast_grep_search` ile `caseGunEkleOnayla`, `caseKapat`, `renderTask` bul
- `gitnexus_context` ile 360° görünüm
- Tedavi modal: saat+seans accordion (A+B hibrit)
- renderTask: saat rozeti (`hedef_saat`)
- Vaka modal: plan accordion (accordion item başına gün)
- D3 fix: `caseKapat` seans_sayisi bazlı dispatch

**Faz 6 — 10 Test Senaryosu** (60 dk):
- A: 1 gün × 1 seans (geriye uyumlu)
- B: 1 gün × 3 seans (multi)
- C: 5 gün × 3 seans, recete_guncelle 3→2 ilaç değişimi
- D: vaka erken kapatma (1 done, 2 done, 1 uygulanmadi)
- E: aynı seans, uygulanmadi (stok iade)
- F: 4 mevcut vakaya dokunulmamış
- G: race condition (2 sekme aynı anda)
- H: stok yetersiz → hata
- I: saat çakışması → UNIQUE violation
- J: idempotency (treatment_day_tamamla 2x çağrı)

**Faz 7 — Session Update** (10 dk):
- `memory_add` ile yeni kritik kararlar
- Handoff bu dosyayı güncelle (commit + push)

**Toplam tahmini: ~5 saat implementation + 1 saat test = 6 saat**

## 9. Onay Geçmişi

- ✅ Spec REVIEW v4 — ONAY (22 bulgu, 0 açık)
- ✅ Plan REVIEW v3 — ONAY (19 bulgu, 0 açık)
- ✅ Commit + Push (6/6 commit main'de, 5e6b2f8 working tree clean)
- ✅ Session update (3 memory notu, bu handoff dosyası)

