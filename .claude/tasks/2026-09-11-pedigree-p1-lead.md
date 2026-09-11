# Lead görevi — G-20260911-PEDIGREE-P1-TEMEL (P1 "Temel" paketi)

Rol sözleşmen: `/home/melik/tools-bank/.superset/roles/lead.md`
Goal zarfı: `/home/melik/egesut-erp1/.harness/goals/2026/G-20260911-PEDIGREE-P1-TEMEL.md`
İKİSİNİ DE OKU. Çelişki görürsen goal kazanır; ikisi de plana atıf yapar.

## İlk iş — stale-base düzeltmesi (ölçülmüş tuzak)

Dalın `origin/main`'den açıldı; local `main`'de push'suz commitler var.
Worktree'ler aynı object DB'yi paylaşır:

```bash
git -C <worktree> merge --ff-only main
git -C <worktree> merge-base --is-ancestor main HEAD && echo TABAN-TAM
```

TABAN-TAM görmeden işe başlama. Goal'daki base_sha ile merge-base örtüşmeli.

## Otorite dokümanları (okuma sırası)

1. Goal zarfı (kabul kriterleri + dalga planı + DB kuralları)
2. `/home/melik/egesut-erp1/.claude/plans/2026-09-10-pedigree-genetics-impl.md`
   — implementasyon otoritesi; P1 kapsamı: Task 0.1-0.5, Task 1, Task 2.
   Task 3+ P2 bandındadır — DOKUNMA.
3. `/home/melik/egesut-erp1/.claude/specs/2026-09-10-pedigree-genetics-architecture.md`
   — mimari otorite (DDL §4, kurallar).
4. `/home/melik/egesut-erp1/.claude/specs/2026-09-11-dogum-buzagi-id-teklif.md`
   — Task 0.5'in birebir kontratı (SET NULL + partial unique + konservatif backfill).

## Görev — gelen iş denetimi + parçalama + koordinasyon

1. **Gelen iş denetimi (zorunlu):** planın P1 bölümünü kusur avma gözüyle oku
   (mimari hata? ileride ne patlar? adımlar doğrulanabilir mi?). Bulgu yoksa
   "bulgu yok" de ve başla — kusur uydurma. Bulgu varsa kırıntıya `gate` yaz,
   root'a ss-ask (`--class cross`).
2. **Parçalama — glmf worker'lar** (`ss-dispatch worker glmf <ws> <dal> <dosya>`):
   - **W1 = Task 0.5** (dogum.buzagi_id foundation) — bağımsız, hemen paralel.
   - **W2 = Task 1** (foundation migration + helpers + RLS/grants + SQL fixture).
   - **W3 = Task 2** (farm backfill + maternal edge + integrity_report 18 kod) —
     W2'nin migration'ına bağımlı; W2 tesliminden sonra aç.
   Her worker'a dar zarf yaz (mekanizma başına, ≤3 adım, kabul komutu,
   dokunulacak dosyalar). Görevi YOL ile ver, yapıştırma.
3. **Gelen iş denetimi her katmanda:** worker'ın planını/goal'i sen denetlersin;
   worker senin goal'ini denetler. Kod katmanı: mekanik kabul (demo DB'de
   tests/sql yeşil) + KOŞULLU bağımsız review (Task 1 mimari/arayüz değişikliği
   sayılır → lead olarak SEN bir codex luna max review turu açarsın; worker
   kendi review'unu çağırmaz. TEK TUR — bulgu aynı worker'a döner, doğrulama
   mekanik kapıyla).
4. **Kendi dalına merge et** (idle/pedigree-p1), raporu yaz, teslim.

## DB erişim kuralları (owner direktifi)

- **Demo DB:** migration + test koşumu SERBEST (psql $DATABASE_URL;
  `scripts/db-dry-run.sh` tracked değil — kullanılırsa TMPDIR'e saygılı kendi
  kopyan). Demo satırları KULLANICI verisidir: temizlik/restore öncesi liste.
- **Canlı PROD:** ERİŞİMİN YOK. Gerekli canlı ölçümü `ss-ask --class cross`
  ile root'a iste (root MCP ile ölçer, cevabı kırıntıya işlenmiş döner).
  PROD'a yazmak owner kapısıdır — sıfır tolerans.
- Migration dosyaları repoya yazılır; **deploy owner onayıyla ayrıca** —
  "migration commit'lendi" ≠ "deploy edildi".

## Teslim (dal ucu ölçütü)

- `idle/pedigree-p1`, main'in ilerisinde; W1+W2+W3 merge'leri + lead raporu:
  `/home/melik/egesut-erp1/.claude/idle-reports/2026-09-11-pedigree-p1.md`
- Kırıntı disiplini (`.crumbs/`) + BOARD güncel.
- Goal'daki kabul kriterlerinin hepsi için kanıt satırı (komut çıktısı/SHA).

## Bekleyeni kurma

Worker'a sen de bekleyici kurarsın (`scripts/ss-wait`); teslim ölçütü git'tir.
Root tarafında ana bekleyici zaten kurulu — çakışma yok.
