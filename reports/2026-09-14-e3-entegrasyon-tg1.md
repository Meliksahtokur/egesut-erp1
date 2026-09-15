# E3 — Entegrasyon: TG1 merge çakışma çözümü (teslim raporu)

- **Tarih:** 2026-09-14
- **İş:** `.ss/tasks/E3-entegrasyon-tg1-cakisma.md` zarfı
- **Dal:** `agent/entegrasyon-tarih-surum` · Merge: `agent/tarihe-git-faz1` (TG1, 89eade1) → L1+L2+R1 (`fddf5d0`)
- **Merge commit:** `3263e7b` — `merge: TG1 tarihe-git faz1 → entegrasyon (E3 teslim) — damga 20260914-03, unit 914/914/0`
- `git merge` / `git merge --abort` çalıştırılmadı; merge root tarafından başlatılmış haldeydi, yalnız çakışmalar çözülüp `git commit` ile bitirildi.

## 1. Çakışma çözümleri

### 1.1 `index.html` — script bloğu (beklenen çakışma)

- **HEAD (entegrasyon):** 25 script satırı, damga `20260913-18` — TG1 listesinden ekstra olarak
  `js/degisiklikler/etiketler.js`, `js/degisiklikler/diff.js`, `js/degisiklikler/degisiklikler.js` içeriyor.
- **TG1:** 22 script satırı, damga `20260914-02` — degisiklikler modülleri yok.
- **Çözüm:** İki tarafın birleşimi = HEAD'in 25 satırlık listesi (TG1'in 22 satırı bunun alt kümesi;
  TG1 tarafında listeye yeni script satırı eklenmemiş — üç-nokta diff ile doğrulandı).
  Tüm damgalar `20260914-03`'e çekildi.

### 1.2 `index.html` — manifest linki (çakışmasız ama damga kapsamı)

TG1 tarafı `manifest.json?v=`'yi `20260913-18 → 20260914-02` çekmişti (temiz birleşmişti);
zarfın "damga her yerde tek değer" gereği `20260914-03`'e alındı.

### 1.3 `tests/unit/vaka-toplu-ac.test.js` — damga-pin testi (beklenen çakışma)

- **Çakışma hunk'ı:** `manifest link de damgalı` testi. Çözüm:
  - Beklenen damga: `manifest.json?v=20260914-03`.
  - `eski` listesi = iki tarafın birleşimi + entegrasyonun eskiyen damgası:
    `20260914-02` (TG1-W3), `20260914-01` (TG1), `20260913-18` (R1, artık eski),
    `20260913-17`, `20260913-16` (yalnız HEAD listesindeydi — korundu), `20260913-15`,
    `20260911-14` (yalnız HEAD — korundu), `20260911-13`, `20260909-12…-1`, `20260908-1`, `20260907-4`.
- **Hunk dışı damga-pin noktaları** (unit 0-fain kriteri için `20260914-03`'e çekildi; zarfın
  "tek değeri 20260914-03 yap" maddesi kapsamında):
  - Test adı: `…her yerel script ?v=20260914-03 damgalı` (eski: -02)
  - `damgasiz` filtre regex'i: `/\?v=20260914-03$/`
  - Test adı: `manifest link de damgalı: manifest.json?v=20260914-03`
  - Damga geçmişine yorum satırı eklendi: `20260914-03: E3 entegrasyon — TG1 faz1 … damga tek değere çekildi`
- İki tarafın diğer tüm test eklemeleri korundu (değiştirilmedi).

### 1.4 Başka çakışma

Çıkmadı — `git status` başta yalnız iki `UU` gösteriyordu, stage sonrası unmerged kalmadı.
Anlamı belirsiz çözüm yapılmadı; soru gerekmedi.

## 2. Kabul ölçümleri (kendim ölçtüm)

| Kriter | Komut | Sonuç |
|---|---|---|
| Damga tek değer | `grep -o '?v=[0-9-]*' index.html \| sort \| uniq -c` | `1 ?v=` (yorum, main'de de var) + `26 ?v=20260914-03` — başka değer YOK |
| Çakışma işaretçisi | `grep -c '<<<<<<<\|>>>>>>>' index.html tests/unit/vaka-toplu-ac.test.js` | her ikisi `0` |
| Unit | `NODE_PATH=/home/melik/egesut-erp1/node_modules node --test tests/unit/*.test.js` | **914 pass / 914 total / 0 fail** (57 suite, ~3,7 sn) |
| Native date | `grep -rn 'type="date"' index.html js/` | 0 satır |
| Playwright | — | KOŞULMADI (sahip kuralı: belgelenmiş koşum var) |
| Whitespace | `git diff --check` + `git diff --cached --check` | temiz |

## 3. Teslim

- Merge commit: `3263e7b` (mesaj zarf formatında: `…damga 20260914-03, unit 914/914/0`)
- Bu rapor: `reports/2026-09-14-e3-entegrasyon-tg1.md` — ayrı commit, `git add -f` ile.
- Sonraki adım root'a ait: merge sonrası entegrasyon dalı durumu / kapatma.
