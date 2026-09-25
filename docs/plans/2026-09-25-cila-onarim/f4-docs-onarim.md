# F4-DOCS — Onarım kaydı: dal ucu teslim temizliği (gitnexus oto-enjeksiyon revert + stray dosya)

> ROL: **F4-DOCS** · 2026-09-25 (~13:2x +03) · Kalem: F3 bulguları F0/GENEL/K-genel (DOCS kulvarı)
> Girdi: F3 doğrulanmış bulgular (a-db F0, b-guvenlik GENEL, c-ui K-genel) + şüpheci kanıtları.

## Bulgular (üçü aynı kök — hepsi işlendi)

| Bulgu | Şiddet | Öz |
|---|---|---|
| a-db F0 | DUSUK | AGENTS.md + CLAUDE.md'de commit'lenmemiş `<!-- gitnexus:start -->` blokları (+45'er satır) working tree'de asılı |
| b-guvenlik GENEL | DUSUK | Aynı asılı bloklar dal_ucu/DONE teslim kapısını kirletir |
| c-ui K-genel | DUSUK | Aynı + izlenmeyen `runs/` (muaf) notu |

## Karar: revert (seçenek b), commit değil

Şüpheci kanıtının gösterdiği gerekçeler:

1. Bloklar `gitnexus analyze` tam koşumunun makine yan-etkisi (3497 symbols şablon satırı);
   K1..K12 kapsamının hiçbir kaleminin işi değil. Enjeksyonsuz yol `--index-only` idi (AGENTS.md
   routing tablosu); I-UI onu kullanmıştı, sonraki bir tam analyze lead'in 09:09
   "dal diff'ini temiz tutmak için revert edildi" kararını sessizce geçersiz bıraktı.
2. Ana checkout'ta (/home/melik/egesut-erp1) aynı bloklar YİNE commit'lenmemiş duruyor —
   hiçbir yerde commit'lenmemiş boilerplate; revert ana checkout'la uyumlu.
3. Commit seçeneği dal diff'ine cila-onarım dışı 90 satır araç metni eklerdi.

Stray `=` dosyası (0 bayt, izlenmeyen, 13:07 yan-etkisi) zarf muafiyetinde değil (yalnız
`runs/` muaf) → kaldırıldı. `runs/` zarf gereği yerinde, commit edilmedi.

## Kabul ölçütü — SAĞLANDI

DONE yazılmadan önce `git status` temiz (yalnız muaf `runs/`) ve dal ucu = son commit:

```
===KANIT_F4_git_status===   (revert + rm sonrası)
?? runs/
```

- `grep -c "gitnexus:start" AGENTS.md CLAUDE.md` → 0 / 0 (bloklar HEAD e5ecd0c/a15e12b durumuna döndü).
- `ls ./=` → yok.

## Uyarı (merge-kapanış / gelecek turlar için)

`gitnexus analyze` (tam koşum, `--index-only` DEĞİL) bu blokları yeniden üretir. Kapanış
dal-ucu kontrolünden önce tam analyze koşulursa blokların yine commit dışı bırakılması
(revert) ya da bilinçli ayrı `chore` commit'i kararı verilmelidir; indeks tazeliği için
tercih `--index-only` (AGENTS.md: GitNexus satırı).

Değişiklik JS/SQL sembol içeriğine dokunmadı → gitnexus `impact` gerekmedi (zarf kural 87
yalnız sembol değişikliğinde); unit G3 yeniden koşumu kapı ajanındadır (görev zarfı: kapı
yeniden koşumu F4 dışında).
