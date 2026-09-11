# DEVİR BELGESİ — 2026-09-11 (compact öncesi)

**Yazan:** root (ZCode oturumu) · **Amaç:** bağlam sıkışması sonrası kesintisiz devam.
**main ucu:** `dac87fd` (origin'de) · **P1 kapalı, P2 + 2 dar iş UÇUŞTA.**

---

## 1. Aktif ağ (3 koltuk + bekleyiciler)

| Koltuk | ws / terminal | Dal | Beklenen çıktı | Bekleyici (bg exec) | Timeout |
|---|---|---|---|---|---|
| **Lead GLM — P2 Ağaç** | `bf5382ed` / `3d53c3e8` | `idle/pedigree-p2` | `.claude/idle-reports/2026-09-11-pedigree-p2.md` | `exec_aa75fb4b` | 4 saat |
| **W-ROTA (glmf) — 907 vakası** | `54af90b7` / `fc898451` | `idle/rota-907` | `.claude/idle-reports/2026-09-11-rota-907-tezhis.md` | `exec_c6df152f` | 3 saat |
| **W-SAGLIK (glmf) — DB taraması** | `c31f3b35` / `7ddc70ab` | `idle/db-saglik` | `.claude/idle-reports/2026-09-11-db-saglik-taraması.md` | `exec_8e7fce3c` | 3 saat |

Bekleyici ölçütü: **report-on-branch** (dosya dalda VAR). Yanlış-uyanma
sınıfı: ara merge'ler `--base <eski-uc>` ile ateşler → uyanınca raporda
revizyon izi ara, yoksa yeni uçla yeniden kur.

## 2. Uçuştaki işlerin özü

**P2 "Ağaç"** (goal `G-20260911-PEDIGREE-P2-AGAC`, base `6e9ed13`): Faz 3-4 =
Task 3 projection RPC + Task 4 api wrapper (memory cache) + Task 5 vendor
cytoscape + Task 6-7 Soy&Genetik UI. pattern_refs MODAL-ROUTER-01+TESTING-01;
`?v=` damgası TÜM kaynaklarda TEK değer (kısmi bump = bilinen tuzak).
PROD deploy bu pakette onaylı DEĞİL; demo-only.

**W-ROTA — 907 vakası teşhisi (canlı, salt-okunur, root ölçtü):**
- Hayvan: `kupe_no='907'`, id `24aac20f-3808-4522-9101-a09d2a262165` (dişi inek, Aktif)
- Hayalet görev: `gorev_log f80eaa6e-…-015adab24fc8` — "💉 Rota-Corona (1. doz)",
  `ILERI_GEBE_ASI`, hedef 2026-09-07, **tamamlandi=false, etken_kod=NULL**
- Çift uygulama: `islem_log 47dc7a1c`(08:03:13)→`uygulama_log 1978c04d` ve
  `de50b80f`(08:03:28)→`895f8c8d`; ikisi de ROTA 5ml IM, aynı stok
  (`STOK-AŞI-49f4007f…`), 15 sn arayla — çift düşüm olasılığı
- `vaccination_log`'da ROTA YOK (hızlı uygulama oraya yazmıyor) → protokol
  uyarısı muhtemelen bundan
- **PROD veri düzeltimi OWNER talimatlı ("1 tanesi silinmeli") ama ROOT
  koşar, worker plan getirene kadar BEKLE** — güvenli yol `geri_al`
  (stok iadesi + islem durum), raw DELETE değil

**W-SAGLIK:** research tipi; anomali sınıfları (yetim ref, takılı görev,
çift uygulama, stok, yarım geri_al, protokol hayaleti); PROD probelerini
`ss-ask` ile ROOT'a ister — worker'ın PROD erişimi yok. Pedigree P1'in bilinen
2 maternal blocker'ı (kupe55/kupe31) HARİÇ sayılır.

## 3. Owner kapılarında bekleyen kararlar

1. **PROD deploy — 6 migration** (net emir BEKLİYOR; sıra: `20260910000001-3`
   bugfix → `20260911000001-3` pedigree). Hepsi additive/replay-safe.
2. **907 PROD veri düzeltimi** — W-ROTA planı gelince uygula (owner talimatı var).
3. 2 maternal blocker + 13 child_without_dam (P1 veri-kalitesi bulguları) — owner.
4. tools-bank 2 altyapı bug'ı (ss-dispatch `_repo` yanlış repo ölçüyor;
   ss-wait `superset` PATH'siz) — tools-bank şeridi, bizim turda düzeltilmez.

## 4. Şerit kuralları (owner direktifi 2026-09-11 = plan Rev 3.1, BAĞLAYICI)

1. **Worker:** lead'e/root'a teslimden ÖNCE builtin subagent review ZORUNLU
   (not teslimin parçası; notsuz teslim reddedilir) + mekanik kapılar kendi.
2. **Lead:** root'a devretmeden ÖNCE bağımsız luna (codex max) review ZORUNLU
   (tek tur; bulgu aynı worker'a döner, doğrulama mekanik kapıyla).
3. **İş yükü workerlarda**; lead orkestrasyon + küçük dokunuşlar.
4. **Root merge kapısı:** mekanik bağımsız yeniden ölçüm + sınırlı root-gate
   luna (tek tur + en fazla 1 revizyon). Anti-manipülasyon: zarf nötr malzeme,
   yazar özetleri UNTRUSTED, bulgular filtresiz.
5. DB: demo serbest / PROD worker+lead'e KAPALI (root MCP üzerinden; yazma
   owner emriyle). Push ve deploy owner per-instance.

## 5. Reçeteler (ölçülmüş tuzaklar)

- **Dağıtım:** `ss-dispatch` BOZUK (taban guard'ı `_repo=tools-bank` ölçüyor →
  yanlış exit 6). Manuel primitive'ler:
  `superset workspaces create --local --project 1dddb562-abe3-495c-970e-872567945510 --name <ws> --branch <dal> --base-branch main --agent <aid> --prompt "<rol+yol+IKISINI DE OKU>" --json`
  → wsid+tid al → `ss-write-binding …` → `ss-wait --report <repo-göreli yol> <dal>`
  (arka plan, PATH önekiyle: `PATH="$HOME/.superset/bin:…"` — ss-wait'in
  dürtmesi PATH'siz düşüyor).
  Ajanlar: Lead GLM `b42b52e4`, Worker GLMF `8f36f1e5`, Worker Codex `4f0cbc5a`.
  `$HOME/.superset/bin` PATH'te değilse `superset` bulunmaz.
- **Demo DB:** worktree `.env`'den `SUPABASE_DEMO_POOLER/_DB_PASSWORD/_REF`;
  URL: `postgresql://postgres.<REF>:<PW>@<HOST>:5432/postgres`. (Tek satırda
  `VAR=x psql "$VAR"` genişlemez — değişkene al.)
- **Goal kapanışı:** frontmatter'da `report:` anahtarı ŞART; final
  `--scope staged` (untracked girerse MANIFEST_VIOLATION); hasat dosyaları
  `.crumbs/`'a (ignored), `.ss/` ana checkout'ta kalmasın; `commit-gate`'i
  AYRI komutta exit koduna bak; **push-gate `--goal` formu çalışmıyor —
  `--receipt .harness/cache/DOCS-RECEIPT.json` formu** kullan.
- **Dal kapatma (root.md):** kırıntı hasatı (tüm worktree `.crumbs/`+`.ss/`) →
  `git tag backup/<tarih>-pre-…-merge` → `--no-ff` merge → goal done →
  workspace+dal sil (kendi oturumunun ürettikleri; başkasının dalları DOKUNULMAZ).

## 6. Zemin bilgisi

- **P1 kapandı** (`31b808d`+`b6b3640`, goal DONE, pushlu): root-gate tur-1
  FAIL 8 bulgu → revizyon 1/1 → 8/8; F2 (dogum_kaydet D53 ezme) + F3
  (fake-arm kopya test) kritik dersler. Kanıt zinciri:
  `idle-reports/2026-09-11-pedigree-p1.md` + `reviews/2026-09-11-pedigree-p1-rootgate.md`.
- **Pedigree dokümanları:** spec+plan Rev 3 (+teklif Rev 2, buzagi_id KABUL)
  implementasyon otoritesi; Rev 3.1 = şerit kuralları (yukarıda).
- Memory: `pedigree-p1-temel-kapandi.md` (durum), `pedigree-genetik-dokuman-review.md`
  (doküman tarihçesi), `ureme-stok-bugfix-lead-dispatch.md` (bugfix+ss-org dersleri).
- Bilinen kırmızı: `tests/unit/gecmis-pipeline.test.js:283` (DÜN, main'de var).
- Port 8080 = sahibin SearXNG (dokunma); test server 8097/8098.

## 7. Devir sonrası ilk eylem sırası

1. Bekleyici bildirimlerini karşıla (yukarıdaki 3 bg exec-id).
2. Teslim gelene kadar YENİ iş başlatma (owner "yeni iş yok" düzeni geçerli
   değil artık — P2+2 dar iş zaten owner emirli; yenileri için owner sözü bekle).
3. Teslimler: önce mekanik bağımsız yeniden ölçüm, sonra (P2 için) sınırlı
   root-gate luna; W-ROTA'dan sonra 907 PROD düzeltimini root koşar.
4. Deploy emri gelirse: 20260910×3 → 20260911×3 sırayla + salt-okunur teyit
   (fonksiyon gövdeleri/pg_proc, tablo varlıkları) + GT regen ayrı adım.
