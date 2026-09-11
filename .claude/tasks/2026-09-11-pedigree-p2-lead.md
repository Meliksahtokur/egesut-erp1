# Lead görevi — G-20260911-PEDIGREE-P2-AGAC (P2 "Ağaç" paketi)

Rol sözleşmen: `/home/melik/tools-bank/.superset/roles/lead.md`
Goal zarfı: `/home/melik/egesut-erp1/.harness/goals/2026/G-20260911-PEDIGREE-P2-AGAC.md`
İKİSİNİ DE OKU. Çelişkide goal kazanır; ikisi de plana atıf yapar.

## İlk iş — stale-base düzeltmesi

```bash
git -C <worktree> merge --ff-only main
git -C <worktree> merge-base --is-ancestor main HEAD && echo TABAN-TAM
```
TABAN-TAM görmeden başlama. (P1'de ss-dispatch taban guard'ı yanlış repoyu
ölçüyordu; dağıtımlar `superset workspaces create` primitive'leriyle yapılıyor
— sen de öyle yap, dalları sabitle + merge-base doğrula.)

## Otorite dokümanlar

1. Goal zarfı (kabul + ÜÇ YENİ ŞERİT KURALI — aşağıya bak)
2. Plan `.claude/plans/2026-09-10-pedigree-genetics-impl.md` Rev 3.1 — P2 =
   Faz 3-4: Task 3 (projection RPC), Task 4 (api wrapper + memory cache),
   Task 5 P2-bandı (vendor cytoscape), Task 6 (frontend boundary),
   Task 7 (Soy & Genetik sekmesi). Task 8+ P3 — DOKUNMA.
3. Pattern kataloğu: `.harness/patterns/index.yaml` — goal `pattern_refs`
   MODAL-ROUTER-01 + TESTING-01 bildirir; sapma = pattern_exceptions kaydı.

## OWNER ŞERİT KURALLARI (2026-09-11 — plan Rev 3.1, ZORUNLU)

1. **Worker subagent review:** her GLMF worker teslimden ÖNCE kendi diff'ine
   builtin subagent review koşturur (bulgu notu / "bulgu yok" teslimde).
   Worker zarflarına bunu şart koş; notsuz teslimi reddet.
2. **Lead luna review:** tüm teslimler + düzeltmeler bitince root'a devretmeden
   ÖNCE paket geneline bağımsız Codex (luna max) review — tek tur, bulgular
   aynı worker'a döner, doğrulama mekanik kapıyla. (P1'de yaptın — artık
   yazılı kural.)
3. **İş yükü WORKERLARDA:** sen orkestrasyon + triage + küçük dokunuşlar.
   Implementasyon, test yazımı, zarf TASLAĞI bile worker'ın işi olabilir;
   sen finalize edersin. Kendi başına task implementasyonu açma.

## Görev

1. **Gelen iş denetimi:** goal + plan P2 bölümü kusur avma gözüyle (tek tur).
2. **Parçalama — glmf worker'lar** (öneri; sen kararlaştırırsın):
   - W1 = Task 3 (projection RPC + SQL fixture) — DB tarafı, W2'den bağımsız.
   - W2 = Task 4 + 5 (pedigree-api.js memory cache + vendor cytoscape spike).
   - W3 = Task 6 + 7 (adapter/style/view/controller + index.html sekmesi +
     stub-backend) — W1'in RPC kontratına bağımlı; zarfına kontratı yaz.
   Worker'lara dar zarf (≤3 adım, kabul komutu, dosya listesi, subagent
   review şartı). Görevi YOL ile ver.
3. **Denetim zinciri:** worker planını sen denetle; worker goal'ini; kod
   katmanı mekanik + koşullu bağımsız. `?v=` damgası TEK ortak değer —
   worker zarflarında özel uyar (repo dersi: kısmi bump damga testini kırar).
4. **Luna turu** (kural 2) → düzeltmeler → kendi dalına merge → rapor
   `.claude/idle-reports/2026-09-11-pedigree-p2.md` + kırıntı + BOARD.

## DB kuralları

Demo SERBEST; PROD YOK (ss-ask cross). Bu pakette PROD deploy ONAYLI DEĞİL —
migration'lar repoya, demo'ya uygulanır.

## Teslim ölçütü

`idle/pedigree-p2` main'in ilerisinde; W1+W2+W3 (+luna turu +düzeltmeler)
merge'li; rapor dalda. Dal root kapanışına açık bırakılır.
