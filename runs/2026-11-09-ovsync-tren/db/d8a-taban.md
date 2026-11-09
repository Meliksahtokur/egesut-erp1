# D8a — ovsync_pg_kabul.sql regresyon tabanı (serisiz, prod gövdeleri)

Ölçüm: 2026-11-09T09:06Z, DB `egesut_ovsync_kabul`. DB D1'de build.sh ile kuruldu; bu görevde yeniden kurulmadı. Koşum BEGIN/ROLLBACK içinde.
Betik: `supabase/tests/ovsync_pg_kabul.sql`. D8a kurulum ve fixture onarımı ile root ruling SORU-2 A1–A4 uygulanmış hâli. Seri dosyası YOK.
Bölüm ayrıştırma: her bölüm sonunda `NOTICE: BOLUM <ad>: n PASS (kümülatif k)` satırı basılıyor (D8a `pg_temp.kb_bolum`).

## Taban — MEASURED (psql rc 0)

| bölüm | bayrak | PASS |
|---|---|---|
| 0 (şema/katalog) | 0 | 29 |
| **1 (BAYRAK 0, MK5)** | **0** | **31** |
| bayrak1-geçiş (S1-c) | 1 | 1 |
| 2 (S-4 PG kapısı) | 1 | 65 |
| 3 (S-5 +48s) | 1 | 47 |
| 4 (S-6 erteleme) | 1 | 11 |
| 5 (S-7 vaka kapanışı) | 1 | 28 |
| 6 (S-8 ilk tohumlama zinciri) | 1 | 59 |
| 7 (S-9 + ACL) | — | 158 |
| 8 (MK10-ui; ATLANDI değil, koştu) | 1 | 8 |
| 9 (R3.2 SK6–SK10) | 1 (bloklar içinde geçici 0) | 26 |
| S1 (kısır blok) | 1 | 19 |
| **OZET** | | **482** |

Ham son satırlar:
```
NOTICE:  BOLUM 9: 26 PASS (kümülatif 463)
NOTICE:  BOLUM S1: 19 PASS (kümülatif 482)
NOTICE:  OZET: 482 PASS
NOTICE:  KABUL TAMAM: tüm testler PASS
DO
ROLLBACK
```

## D8 için kullanım
- Bayrak 0 bölümü tabanı **Bölüm 1 = 31 PASS** (Bölüm 0 = 29). D8 kabulü bu sayıyla birebir eşitlik ister.
- Toplam taban **OZET 482 PASS**. A1–A4 öncesindeki ara ölçüm (scratch) 473 idi. Fark +9: T31 +2, R32-2 +2 (eski 1 assert yerine 2 assert geldi, scratch'te o 1 assert atlanmıştı), ACL eski imza listesi +5.
- psql çıktısında `OZET` satırından sonra `KABUL TAMAM`, `DO` ve `ROLLBACK` satırları geliyor. Son satırı almak için `tail -6` ya da `grep OZET` kullanın.
