# REV-4 — idle/sessiz-9999-analiz: stat_suru_ozet ↔ sessiz liste 9999 sayım tutarsızlığı

**Tarih:** 2026-09-02 · **Taban:** main `a71b7a0` · **Branch:** `idle/sessiz-9999-analiz` (worktree: `/home/melik/egesut-wt/sessiz-9999-analiz`)
**Kaynak:** docs-hatti raporu "Sonraki Adımlar 3" + `.claude/domain-rules.md:136-138`

## ZORUNLU GUARDRAIL

- **PROD DB: YALNIZ READ-ONLY** (`SELECT`, `pg_get_functiondef`) — DEPLOY/DDL/UPDATE YASAK.
  Migration TASLAĞI yazılır, canlıya dokunulmaz.
- Push YOK · tek commit · js/ DOKUNMA (öneri raporda) · rapor: `.claude/idle-reports/2026-09-02-sessiz-9999-analiz.md`

## Bilinen tutarsızlık (domain-rules:136-138 + canlı doğrulandı 2026-09-02)

- `sessiz_gun` sentinel: ne event'i ne doğum bilgisi olan hayvanlarda NULL → RPC `COALESCE(...,9999)` → 9999.
- Dashboard bandı + modal: sentinel-son sıralama (9999'lar en altta — commit bb4ea92).
- **Kök neden CANLIDAN doğrulandı (2026-09-02, orchestratör ölçümü):**
  - Canlı `stat_suru_ozet` gövdesinde sessiz sayacı `e.sessiz_gun >= 55` — **COALESCE YOK** → NULL'ları saymaz.
    (Repo'daki `20260614000002_stat_suru_ozet_v3.sql` COALESCE'liydi; canlıyı yeniden yazan
    `20260625000030_stat_suru_ozet_readonly.sql` gövdesinde COALESCE düşmüş. Bunu YENİDEN doğrulamana gerek yok.)
  - Liste (`sessiz_hayvanlar_listele`): `COALESCE(e.sessiz_gun,9999) >= 55` → 9999'ları DAHİL eder.
  - Bugünkü sayılar: **liste 24 / stat 18 / NULL 6** → dashboard'ta kart "18", band başlığı "24" — aynı ekranda iki sayı.
  - 6 NULL hayvan: **204, 2044, 207, 23, 4019, 906** — hepsinde `dogum_tarihi` NULL, 0 tohumlama, 0 doğum kaydı;
    4'ü Düve (Büyük), biri Sağmal (Laktasyonda, 2044), biri Sağmal (Kuru, 906). Yani bunlar "55+ gün sessiz"
    ölçümü DEĞİL — **veri eksiği** (yaş/üreme geçmişi hiç girilmemiş). 906 (kuru inek, sıfır üreme kaydı) en riskli örnek.
- Karar matrisi başlangıç noktası: (a) stat'a COALESCE'i geri koy (liste=kart; repo v3'te zaten vardı — restore),
  (b) stat'a ayrı `kayitsiz` sayacı EKLE (sessiz gerçek ölçüm kalır, "kayıtsız" ayrı görünür) + UI bandında ayır,
  (c) veri tamamlama (migration değil, operasyon). **Tek öner** seç.

## Kapsam — üç adım

1. **Canlı ölçüm (read-only):**
   - `pg_get_functiondef('stat_suru_ozet')` ve sessiz sayımını besleyen view/fn zinciri
     (`v_eligible`, `sessiz_hayvanlar_listele`, `sessiz_hayvanlar_reconcile`) — NULL/9999'un her
     katmanda nasıl ele alındığı tablo halinde.
   - Canlı dağılım: kaç hayvan 55+ günde, kaç tanesi NULL→9999 (yani sayacın attığı ve listenin
     aldığı fark somut sayılarla).
2. **Karar matrisi (öneri):** (a) sayaca 9999'ları dahil et (kart=liste; band kaçHayvan ile uyumlu),
   (b) listeden 9999'ları ayır ("hiç kayıt yok" ayrı grup/sayaç), (c) statüs quo + UI etiket notu.
   Her seçeneğin UI/rapor etkisini yaz; **tek öner**.
3. **Migration TASLAĞI:** seçilen öneriye göre `supabase/migrations/2026MMDD000000_....sql` taslağı
   (fn yeniden tanımı — mevcut migration pattern'ine uy: ground_truth tarzı tam gövde, `_revize/_fix` yok).
   Taslak repoda kalır, **DEPLOY EDİLMEZ**. Blast radius notu: `pg_depend` ile stat_suru_ozet'i okuyan
   view/fn listesi (read-only).

## Teslim

Tek commit (migration taslağı + rapor), ölçüm tabloları, karar matrisi + tekil öneri, pg_depend çıktısı.
Kullanıcı sonraki oturumda taslağı denetleyip deploy emrini verir.
