# Ovsync/PG/Tohumlama Kuralları — TAMAMLANDI ✅

**Tarih:** 2026-09-24 · **Durum:** Bitti — prod'da canlı, bayrak AÇIK
**Dal:** `feature/ovsync-tohumlama-tedavi-kapanisi` → main uç commit `201dc1e`
**Tetikleyici:** Hayvan 121 — Ovsync sürerken tohumlandı (17.09.2026), tedavi
kapanmadı, PG dahil seanslar devam etti, zigot kaybı şüphesi.

## Ne yapıldı (özet)

| # | Bileşen | Ne |
|---|---|---|
| 1 | **DB kuralları** | Tohumlama açık senkronizasyon vakasını "TOHUMLAMA ile sonlandırıldı" ile kapatır (tek audit: `CASE_CLOSED_BY_TOHUMLAMA`); Gebe'de PG **hard block**; Bekliyor'da gerekçeli onay + tek ekranda [Boş ata ve uygula]; bağımsız PG +48s'de tohumlama görevi (VWP 55g filtreli, açık TAI'nin yerine geçer); görev erteleme RPC'si |
| 2 | **İlk tohumlama zinciri (0 gün kaybı)** | Her açık dişi: inek doğum/abort **+51**, düve **+12 ay 21 gün** Ovsync'e girer, TAI +10 gün 10:00; tetikler: doğum (anne + dişi buzağı)/abort/Boş-sonucu/hayvan kaydı; cron yedek + dry-run önizleme; SK10 geçiş: 10 eski vaka kapandı |
| 3 | **Katalog güvenliği** | 6 hormon etken maddesi sistem kaydı (silinemez); PG kimliği `farmakolojik_sinif_kodu='PGF2A'` (kloprostenol NULL tuzaktan arındı) |
| 4 | **UI (P1–P10)** | PG_KAPI hata ayrıştırma (jenerik ezme yok), pull haritası, 🌱 Üreme kategorisi, kaynak etiketleri (PG+48s/Şablon TAI/İlk tohumlama), protokol panelinde İlk Tohumlama bölümü (hedef−2g, [Başlat]/[İptal]), PG kapısı modalı, erteleme modalı (pencere canlı önizleme), toplu sonuç modalı (tekrar yalnız requires_ack), uygulama saati, kapanış özeti, bildirimler (B1–B3) |

## Kanıt zinciri

- **Kabul betiği:** `supabase/tests/ovsync_pg_kabul.sql` — **456 PASS lokal / 445 demo** (9 assert sahip-şifresi tablosu yüzünden atlanır; koşum: README)
- **Migration'lar:** `supabase/migrations/20260923000001..6` + `20260924000001..2` (append-only; 000002 = kapı-5 dry-run bug fix'i)
- **Prod ilk koşum (2026-09-24):** 41 rota + **11 zincir otomatik başladı** (vaka+seans+TAI) + 30 gelecek görev; SK10 = 10 vaka (ölçümle birebir); `veri-eslesme-kontrol.py hepsi` → sızıntı/yetim/türetilmiş **0**
- **Yayın:** GitHub Pages canlı (`?v=20260924-01`); bonus fix: `vendor/` Pages whitelist'inde yoktu → cytoscape 404 kapatıldı (`4bc8d98`)
- **Demo:** migration'lar + bayrak açık + 18 zincir (sahip UI testi için)

## Detaylar — belge referansları

| Konu | Belge |
|---|---|
| **SPEC (kanonik, DB kontratları)** | `docs/plans/2026-09-23-ovsync-pg-tohumlama-SPEC.md` (R3 + R3.1 + R3.2/SK6–SK10) |
| **UI PLAN (P1–P10)** | `docs/plans/2026-09-24-ovsync-pg-PLAN.md` |
| Sahip kararı süreç belgeleri | `docs/plans/2026-09-23-ovsync-pg-tohumlama-kurallari-design.md` (R0), `…design-R2-sahip-kararlari.md`, `egesut-ovsync-pg-review/-tibbi-review/-design-R1-…md` (dış incelemeler) |
| Root görev tanımı | `docs/plans/2026-09-24-ovsync-pg-root-ultracode-prompt.md` (kapılar + D backlog) |
| Kabul DB kurulumu | `scripts/kabul-db/build.sh` + `supabase/tests/README.md` |
| Veri eşleşme ölçümü | `~/tmp/agents/veri-eslesme-20260924/ozet.json` (lokal) |
| Tailscale DNS bug'ı (lokal geliştirme) | `BUGS.md` → BUG-TAILSCALE-DNS |

## Operasyonel notlar ve kalan işler

→ Claude memory: **`ovsync-pg-sahip-kararlari`** ve **`ovsync-pg-teslim-2026-09-24`**
(`~/.claude/projects/-home-melik-egesut-erp1/memory/`) — demo org dışı/psql yolu,
worktree NODE_PATH, damga testi eşgüncellemesi, UTC fixture tuzağı, temel sayılar.

**Açık (sıradaki):** 24 saatlik izleme raporu (pg_application_event / OVSYNC_BASLAT /
CASE_CLOSED_BY_TOHUMLAMA sayıları); D backlog — D11 artığı, `tohumlama_durumu`
uzlaştırma (13 gebe kalıntısı + dogum_kaydet kök nedeni), `_vaka_ac_tek` ACL,
bulk_ilac stok guard, seans geri almada PG event, ground-truth-audit parser
artifact'ı (40 fark sahte, gerçek drift 0), api.js offline kuyruk 3 high bulgusu.

**Bayrak kapatma (acil durum):** `UPDATE protokol_ayar SET deger=0 WHERE
anahtar='ovsync_pg_kurallari_aktif';` — temizlik/geri alma yolları çalışmaya devam eder (MK8).
