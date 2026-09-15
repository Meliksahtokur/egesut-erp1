# W6 DEMO uygulama kılavuzu — 20260914000004_l4_stok_uyari_txid.sql

**Durum:** W6 koltuğunda DEMO DB erişimi yoktu (bkz. teslim raporu §Engel);
migration + probe hazır, apply/replay/kanıt adımları DSN tutan koltukta
(lead/root) koşulmalıdır. Komutlar `psql` ile W4'ün `m3_uygula*` deseninin
birebiridir. **Hedef yalnız DEMO (`vtzqjmazsvurxdeondmi`); PROD asla.**

## Adımlar

```bash
# 1) Uygulama (1. koşum)
psql "$DEMO_DSN" -v ON_ERROR_STOP=1 \
  -f supabase/migrations/20260914000004_l4_stok_uyari_txid.sql \
  2>&1 | tee reports/2026-09-14-geri-alma-akisi-W6/uygula1.out
# Beklenen: BEGIN / CREATE FUNCTION ×2 / REVOKE / COMMIT — EXIT=0

# 2) Replay (replay-safe kanıtı — CREATE OR REPLACE, idempotent)
psql "$DEMO_DSN" -v ON_ERROR_STOP=1 \
  -f supabase/migrations/20260914000004_l4_stok_uyari_txid.sql \
  2>&1 | tee reports/2026-09-14-geri-alma-akisi-W6/uygula2_replay.out
# Beklenen: EXIT=0

# 3) Canlı fonksiyonel probe (ROLLBACK-tabanlı; iz bırakmaz)
psql "$DEMO_DSN" -v ON_ERROR_STOP=1 \
  -f reports/2026-09-14-geri-alma-akisi-W6/probe_stok_uyari.sql \
  2>&1 | tee reports/2026-09-14-geri-alma-akisi-W6/probe_stok_uyari.out
# Beklenen: W6-A | t  —  W6-B | t  —  W6-C | t   (tümü t = PASS)
```

## Probe notları

- `probe_stok_uyari.sql` tek tx içinde sentetik `degisim_log` satırları yazar
  ve `ROLLBACK` ile biter → DEMO'ya kalıcı satır yazmaz.
- LSP typecheck'i sözdizimi hatası vermedi; ancak **canlı koşum yapılmadı**
  (koltukta DEMO erişimi yok). İlk koşumda beklenmedik hata olursa
  `ON_ERROR_STOP=1` zaten durdurur; raporu buna göre yorumlayın.
- W6-C iki fonksiyonun CANLI tanımında `(txid %s)` kalmadığını bağımsız
  ölçer (pg_get_functiondef) — sentetik veriden bağımsız kalıcı kanıt.

## Geri alma (gerekirse)

Migration yalnız `CREATE OR REPLACE FUNCTION` içerir → geri almak için
`20260914000003_l4_onarim.sql`'in ilgili iki fonksiyonu aynı komutla
yeniden uygulanabilir (0003 replay-safe). Veri şeması değişmez (sütun yok).
