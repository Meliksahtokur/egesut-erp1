# Pedigree — Legacy semen / baba identity mapping (DRAFT — owner review pending)

**Durum:** TASLAK — root ölçümü (2026-09-11, canlı PROD, salt-okunur).  
**Tüketici:** implementasyon planı Task 8 (P3 bandı) — materializasyon
`pedigree_legacy_identity_map` tablosuna iner (plan Task 8 Rev-3 sözleşmesi).  
**Kapı:** owner bu listeyi onaylamadan Task 8 zarfı yazılamaz. P1'i bloklamaz.

Ölçüm sorguları (canlı, 2026-09-11):

```sql
SELECT btrim(sperma), count(*) FROM tohumlama
 WHERE sperma IS NOT NULL AND btrim(sperma)<>'' GROUP BY 1 ORDER BY 2 DESC;
SELECT btrim(baba_bilgi), count(*) FROM hayvanlar
 WHERE baba_bilgi IS NOT NULL AND btrim(baba_bilgi)<>'' GROUP BY 1 ORDER BY 2 DESC;
```

## A. `tohumlama.sperma` — 38 ayrı metin, 207 satır

| # | sperma_metni | adet | öneri (owner onayına açık) |
|--:|---|--:|---|
| 1 | Starred \| Usared \| Holstein | 65 | canonical bull "Starred" |
| 2 | Armada red \| 09856565 \| Holstein | 63 | canonical bull "Armada red" |
| 3 | PascoRed \| 8558588 \| Holstein | 28 | canonical bull "PascoRed" |
| 4 | Fresh | 20 | AYRIŞTIR: "Fresh \| Hjuoo9986hu \| Montofon" (7) ile aynı boğa mı? |
| 5 | Darius | 13 | AYRIŞTIR: "Darius \| Hjuoo9986 \| Montofon" (8) ile aynı boğa mı? |
| 6 | Fresco Red noncorn \| Jdeıeııek \| Holstein | 13 | canonical "Fresco Red noncorn" — DİKKAT: noktasız ı varyantı (B tablosundaki `Jdeieiek` ile yazım farkı — eşleşme Türkçe-duyarsız olmalı) |
| 7 | Darius \| Hjuoo9986 \| Montofon | 8 | #5 ile birleştirme kararı owner'ın |
| 8 | Campus | 7 | canonical bull "Campus" |
| 9 | Fresh \| Hjuoo9986hu \| Montofon | 7 | #4 ile birleştirme kararı owner'ın |
| 10 | Naika red \| Naika red \| Holstein | 5 | canonical bull "Naika red" |
| 11 | Bale red \| 2024.02.28 \| Holstein | 5 | kod alanında TARİH var — veri kalitesi bulgusu |
| 12 | Starred | 4 | #1 ile aynı boğa (kısa form) — birleştir |
| 13 | Miller \| Jj09usa \| Holstein | 3 | canonical |
| 14 | Baymax red \| 090909 \| Holstein | 3 | canonical |
| 15 | Molotov \| De0909 \| Holstein | 3 | canonical |
| 16 | Overtop \| 223355 \| Holstein | 3 | canonical |
| 17 | Maeruce \| 12719098 \| Holstein | 3 | canonical |
| 18 | Fercey \| 09090909 \| Holstein | 3 | canonical |
| 19-38 | Crowntown, Junas red, Glomoris, Bonum, Dana, Backstage, İmperial, Alcow dişi, Popstar, Bale red keyif, Simmental, Marcrest, Erice, Redhead, "Benim arkasaşlar", Matchball, Björk, Savant dişi, Bonus red, Sincleir (hepsi ≤2) | 21 | tek adaylar; "Alcow **dişi**" / "Savant **dişi**" cinsiyet şüphesi bulgusu; "Benim arkasaşlar" yazım kaydı |

## B. `hayvanlar.baba_bilgi` — 8 ayrı metin, 54 satır

| # | baba_metni | adet | not |
|--:|---|--:|---|
| 1 | Armada red \| 09856565 \| Holstein | 25 | A2 ile aynı boğa |
| 2 | Starred \| Usared \| Holstein | 19 | A1 ile aynı boğa |
| 3 | Fresco Red noncorn \| Jdeieiek \| Holstein | 5 | A6'nın noktalı-`i` varyantı — aynı boğa, yazım farkı |
| 4 | Marcrest \| 151515 \| Holstein | 1 | A19 grubunda var |
| 5 | Campus | 1 | A8 ile aynı |
| 6 | PascoRed \| 8558588 \| Holstein | 1 | A3 ile aynı |
| 7 | Starred | 1 | A12 kısa form |
| 8 | Backstage \| 010101 \| Holstein | 1 | A24 grubunda var |

## Veri kalitesi gözlemleri (integrity raporuna girecek sınıflar)

1. **Türkçe `ı/i` varyantı:** `Jdeıeııek` (tohumlama) ↔ `Jdeieiek` (baba_bilgi)
   — aynı boğanın iki yazımı; exact eşleşme kaçırır.
2. **Kısa/uzun form:** "Starred" ↔ "Starred | Usared | Holstein"; "Fresh" ↔
   "Fresh | Hjuoo9986hu | Montofon"; "Darius" ↔ "Darius | Hjuoo9986".
3. **Kod alanında tarih:** "Bale red | 2024.02.28".
4. **Cinsiyet şüphesi:** "Alcow dişi", "Savant dişi" — sperma adı dişi içeriyor.
5. **Serbest metin artığı:** "Benim arkasaşlar" — canonical boğa adı değil.

**Owner karar listesi (bu dosya onaylanırken):** (a) kısa/uzun form
birleştirmeleri (#4/#5/#7/#9/#12); (b) 19-38 arası tek adayların canonical
boğa adları; (c) cinsiyet şüphesi taşıyan iki satırın akıbeti; (d) registry
kodları (regno) biliniyorsa external node'lara yazılacak.
