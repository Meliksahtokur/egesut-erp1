# HANDOFF — ovsync-takip MİMAR (glm-max) — 2026-09-30c (context bütçesi devri)

supersedes: `runs/2026-09-28-ovsync-takip/BASLANGIC-PROMPTU-2026-09-30b.md` devir zincirinin devamı.
Neden bu devir: context-budget stop hook (500k HARD). `.ss/` yazma yasağı sürdüğü için
handoff `runs/` altında (önceki devir deseni — fb08744'te aynı).

## §0 İlk 5 dakika

1. `Skill(using-superpowers-obra)` yükle (koltuk kuralı).
2. Sırayla oku: bu belge; `.harness/contract.md`;
   `.harness/goals/2026/G-20260930-OVSYNC-TAKIP-IMPL.md` (active — latest checkpoint
   güncel durumur); §6 Davranış mirası için `HANDOFF-2026-09-30b-ovsync-takip.md`.
3. Canlı durumu BİR KEZ ölç: `git rev-parse HEAD` + `git status --short`; P8 subagent
   bitiş bildirimi gelmişse DONE'ı oku (aşağıda P8 satırı); polling kurma.

## §1 Ne oldu (bu tur — IMPL yürütmesi)

Sahip onayları 14:25: (1) katalog v3 final → **G-20260929 done**; (2) IMPL aktivasyon →
**G-20260930 active**; (3) akış atlası 5 sorusu onay (varsayılanlarla); (4) mutation
erteleme sahibe açıklandı, itiraz yok.

**SQL zinciri TAMAM (7 madde, 7 commit, hepsi db-validate PASS + demo/izole provalı):**

| Madde | Commit | Özet |
|---|---|---|
| P1 ovsync_takip_listele | `2deec24` | S2=5 predicate birebir; T-45 fark 0/0 |
| P2a TAKIP_MUAYENE şema | `24d241c` | kolon+yardımcılar+muafiyet+seed |
| P2b sarmal RPC + D1 | `345856c` | 28 senaryo; Ç1-4×30 yarış |
| P2c +21/+35 kaldırma | `b3ddbe9` | tek üretici cron |
| P2d veri temizliği | `06e7ae9` | 40 aday→0, idempotent |
| P3a tetikleyiciler | `bd8b729` | 4 olay + cycle_guard muafiyeti |
| P3b giriş kapıları | `0a74570` | 7 RPC imza; **T-72b 5×30=150 tur 0 yasak-olay — ertelenmiş sözleşme KAPANDI** |

**JS zinciri (5 madde teslim, 5 commit, hepsi TDD kırmızı→yeşil):**

| Madde | Commit | Test |
|---|---|---|
| P4 api.js veri katmanı | `466eb0c` | 17/17 |
| P5 iskelet+gezinme | `3b9332b` | 20/20 |
| P6 S0-S4 render | `8c91226` | 37/37 |
| P9b-yardımcı gunFarkiEtiket | `e515713` | 7/7 |
| P7 giriş hücreleri+K14 | `426c4a3` | 39/39 (D6 dahil) |

Tam paket süit: **1309/1312** — 3 kırmızı PRE-EXISTING (2 tarih-duyarlı vaka-toplu-ac
+ LUNA-3 canlı-DB; HEAD baseline'ta kanıtlı).

## §2 Canlı işler (yazma anı ölçümü ~21:00)

- **P8 (devam seçici) SUBAGENT KOŞUYOR** — zarf
  `runs/2026-09-28-ovsync-takip/impl-P8-GOREV.md`, DONE hedef `impl-P8-DONE.md` (yok henüz).
  Bitiş bildirimi bu oturuma gelmedi. Devralan oturum: DONE varsa → nokta-kontrol →
  kırıntı → commit → P9 dispatch. DONE yoksa subagent'in işi ölmüş olabilir → zarfı
  yeniden dispatch et (aynı zarf; model sonnet).
- Başka canlı iş YOK; herdr w14'te yalnız bu mimar tab'ı.

## §3 Sıradaki (tek adım + zincir)

1. **P8 hasat** (§2) → commit.
2. **P9 dispatch** — zarf HAZIR: `runs/2026-09-28-ovsync-takip/impl-P9-GOREV.md`
   (bağlama + GEBELIK_KONTROL özel akışı + kalem 11 iki-satır + P9b bağlaması).
3. **P10 dispatch** — zarf HAZIR: `impl-P10-GOREV.md` (birleşik kapı; H5 alan
   tablosu `impl-P3b-DONE.md`'da — UI bu tabloya bağlanır).
4. P11 (envanter — parçaları madde bazında yazıldı; kalan boşlukları kapat),
   P12 (PW E2E kırmızı→yeşil + glmf-max 25 madde UI kapısı — **önce demo OVSYNC
   şablon seed kararı SAHİP**), P13 (doküman, sıralı en sonda).
5. Hasat düzeni her maddede aynı: nokta-kontrol (1-2 yük taşıyan iddia kaynak
   grep/rapor) → kırıntı → commit → sıradaki dispatch.

## §4 Araçlar ve geçiciler

- Kırıntı: `.crumbs/ovsync-takip.jsonl` (gitignored; bash -c ile yaz — fish apostrophe
  yutuyor, bu turda bir kez bozuldu).
- db-validate WORKTREE-İÇİ yoldan çağırılır (rapor worktree reports/ altına düşsün);
  raporlar `git add -f`.
- Demo DB kimlikleri `/home/melik/egesut-erp1/.env` (değerleri çıktıya basma).
- Kanıt geçicileri: `/home/melik/tmp/agents/` (repo dışı — doğru yer);
  `~/tmp/ovsync-takip-olcum/t72b-rounds30-2026-09-30.txt` SİLME.
- t72b yarış kanıtı: `~/tmp/agents/t72b-mini.py` (repo'daki
  `tests/concurrency/ovsync-takip-t72b.mjs` fixture kusurlu — P12 civarında düzeltme kalemi).

## §5 Tuzaklar (bugünün dersleri)

- LSP false-positive sınıfları: p_* fonksiyon parametreleri CTE'de; yeni nesneler
  ayna-PROD-öncesi görünmez; trigger'lar aynada yok (canlı pg_get_functiondef oku);
  psql `\` meta-komutları parser hatası verir. Runtime kanıtı geçerliyse uyarı kapatılır.
- Canlı gövde ≠ migration kaynağı olabilir — 7 RPC'nin hepsinde canlı okundu (P3b);
  aynı disiplin JS'te atlas_query karşılığı.
- db-validate DATA_MARKERS kör-noktası: şema-nitelemeli UPDATE "veri yok" sayabilir
  (C2 yine koşar — PASS'ı etkilemedi, kayıtlı).
- Sahibin "sabahtan beri bitmedi" sorusu: implementasyon 14:25'te başladı (sabahki tur
  katalog hazırlığıydı, sahip kapısındaydı) — bu çerçeveyle anlat.
- Subagent DONE'larında "bilinçli sapma" gerekçeleriyle geliyor (P2d notlar-kolonu yok →
  kapatan_ref; P7 index.html yerine ui.js senkron köprü) — nokta-kontrolde doğrula, kabul edilebilirse ratifiye et, kırıntıya yaz.
- Sayı iddiaları bağımsız doğrulanır (HANDOFF-2026-09-30b §5 dersi sürüyor).

## §6 Sahip kapısı (devam eden)

- push/merge/deploy/PROD apply HER ZAMAN sahip kapısı.
- **Demo OVSYNC şablon seed** kararı P12 öncesi (demo'da 0 adet; start_first tam-zincir
  provası buna bağlı).
- Mutation erteleme: itiraz yok — erteli kalır.
- Akış atlası: impl bitince pilot (BRIEF §7 varsayılanlarıyla onaylı).

## §7 Yürütmeye dair bağlayıcı davranışlar (HANDOFF-2026-09-30b §6 aynen geçerli)

Review DIŞA (ss-lead-codex luna/max, herdr yan tab — bu hedefte bugün gerekmedi;
IMPL bitince final review için gerekecek); amele/üretim inbuild subagent (sonnet);
kırıntı + kanıt etiketi + board disiplini; sahiplerle Türkçe + TAM mutlak yollar.
