# HANDOFF — ovsync-takip MİMAR (glm-max) — 2026-10-01a (kapanış devri)

supersedes: `runs/2026-09-28-ovsync-takip/BASLANGIC-PROMPTU-2026-09-30c.md` devir zinciri.
Neden bu devir: sahibin kararı (2026-10-01 ~02:20) — iş bitince devir; UI testleri ve kalan
işler YENİ oturumda. `.ss/` yazma yasağı sürüyor → handoff `runs/` altında.

## §0 İlk 5 dakika

1. `Skill(using-superpowers-obra)` yükle (koltuk kuralı).
2. Sırayla oku: bu belge; `.harness/contract.md`;
   `.harness/goals/2026/G-20260930-OVSYNC-TAKIP-IMPL.md` (latest checkpoint güncel durumu).
3. Canlı durumu BİR KEZ ölç: `git log --oneline -12` + `git status --short`. Polling kurma.

## §1 Ne oldu (bu oturum — 2026-09-30 21:45 → 10-01 02:20)

Plan maddelerinin TAMAMI teslim edildi. Commit zinciri (bu oturum):

| Commit | İçerik |
|---|---|
| `fc6a5de` | P6 artık hasat (index.html CSS +71 + gezinti faz-geçişi — P6 commit'ine girmemişti) |
| `5e15c6f` | D7 katalog önkoşulu KAPANDI (katalog fb08744'te zaten hizalıymış — 17/17 doğrulandı; T-27 saat kalıntısı düzeltildi) |
| `21a0758` | **Demo DB apply** (sahip onayı 22:57): P1–P3b zinciri 5/5, 15 sn; rapor `impl-demo-apply-2026-09-30.md` |
| `2b47f8b` | **P9** Boş/muayene bağlama + GEBELIK_KONTROL (K15) + kalem 11 iki-satır |
| `2e64677` | **P10** birleşik TAKIP_ACIK/PG_KAPI onay zinciri (kapi 21/21; sarmal TEK p_onay canlı-doğrulamalı ratifiye) |
| `8c2b59c` | **P11** D3 migration-CASE kilidi + invalidate envanter 17/17 + kapsama matrisi |
| `f425bea` | **P12** demo E2E 12/12 ×2 + T-72b fixture onarımı (5×30 tur, 0 yasak-olay) + ui-test-listesi eşleme |
| `7678d01` | **P12b** TZ kalıcı-tarih fix (migration `20261001000001`, 4 gövde Istanbul yerel gün; demo'da canlı) + HATA-1 UI fix (kapi 22/22, e2e 12/12) |
| `ef9249d` | **P13** rpc-reference + ui-map ovsync yüzeyleri (canlı gövde bazlı; GT sahibe-raporu DONE'da) |

Süit durumu: unit **1406 test / 1404 pass / 2 kırmızı pre-existing** (LUNA-3 canlı-DB + tarih-duyarlı
`ay ‹/›`); e2e ovsync 12/12; T-72b 5×30 PASS. Sahip onayları bu oturumda: demo apply (22:57),
TZ fix + demo apply (00:35). P10 bir kez 429 rate-limit'ten düştü — sıfır yazma bıraktı, devamla kapandı.

## §2 Canlı işler (devir anı)

- **ui-tur subagent'ı**: `ui-tur-GOREV.md` zarfıyla 25 maddelik glmf-max UI turu dispatch edilmişti
  (~01:20). Devir anında bitiş bildirimi GELMEDİ. Durum:
  - `runs/2026-09-28-ovsync-takip/ui-tur-DONE.md` VARSA mimar (devreden oturum) hasat etmiştir —
    §1'deki commit tablosunda görülür; 25/25 ise kalan tek iş final rapor + sahibe demo.
  - DONE YOKSA: tur yarıda kalmış demektir — YENİ OTURUM yeniden koşturur (zarf hazır:
    `ui-tur-GOREV.md`; P12 spec'inin local-server + EGESUT_DEMO initScript + IDB bekleme + fixture
    temizlik deseni `tests/e2e/ovsync-takip.spec.js`'te). Kısmi kanıt `runs/.../artifacts/uitur-*.png`
    olabilir — yeniden koşumdan önce varsa yedekle (ezilme tuzağı).
- Başka canlı iş YOK; tüm subagent'lar bitti.

## §3 Sıradaki (tek sıra)

1. **ui-tur 25/25** (§2'ye göre koş ya da hasat et). FAIL çıkarsa: fix zarfı yaz (HATA sınıfı
   P12b örneği gibi; ürün koduna subagent düzeltmesi mimar ratifiyesiyle), sonra yeniden koş.
2. **Final rapor** `runs/2026-09-28-ovsync-takip/impl-DONE.md`: madde→commit tablosu, süit
   sayıları, demo apply + TZ apply raporları, ratifiye edilen bilinçli sapmaların özeti
   (P9×3, P10×10, P12×3, doz/gün editable, T-06/D4 glmf-max'a), ui-tur 25/25 sonucu, sahibe
   kapı kalemleri. Commit at (runs/ deseni).
3. **Goal kapanışı**: latest checkpoint'e final satır; sahibin kabulüyle `status: done`.
4. **Sahibe demo**: worktree yerel sunucu `?demo` + 25 maddelik liste linki + yedek/apply rapor
   yolları (TAM mutlak yol kuralı).

## §4 Sahip kapıları (goal sonrası)

- **Merge/push**: `ovsync-takip` dalı → main sahibin elinde (UI merge sahipte).
- **PROD apply**: 6 migration (`20260929000001`..`000005` + `20261001000001` TZ düzeltmesi)
  db-validate'li, demo provalı; runbook `.harness/runbooks/db-migration.md` 7 adım; P2d temizliği
  prod'da ayrı ölçüm ister (demo 41→1 idi).
- **GT yenileme talebi**: `impl-P13-DONE.md` sahibe-rapor bölümü (replay son-kazanan ölçütleri;
  P12b'nin 4 gövdesi GT'de ESKİ kalır — fark BEKLENEN).
- **Backlog (sahip bildirimi yapıldı)**: `gebelik_muayene_gorev_uret` (eski gövde, B9) CURRENT_DATE
  yazar — prod cron saati 00:00–03:00 TR penceresine denk gelmiyorsa etkisiz; PROD turunda bak.
- **Opsiyonel**: demo'da `schema_migrations` tablosu yok (apply raporları sürüm kaydı taşıyor).
- **Akış atlası pilotu**: impl bitti → BRIEF §7 varsayılanları onaylı; ayrı iş.

## §5 Tuzaklar (bu oturumun dersleri)

- Katalog dosya adı: `test-senyolari.md` (ASCII i) — dotless ı ile yazınca dosya bulunamaz;
  plan içindeki satır referansları da karışıyor. Glob ile yakala (`test-sen*.md`).
- `docs/plans` gitignored — `git add -f` şart (repo deseni); plan.md design.md YEREL (commit'lenmez).
- P6 dersi: subagent DONE'ları "yazdım" derken commit kapsamını kontrol et (`git log -1 -- <dosya>`);
  askıda parça HEAD'i kırmızı bırakabilir.
- 429 rate-limit: subagent sıfır yazma bıraktıysa SendMessage ile BAĞLAMIYLA devam et — sıfırdan
  koşturmaktan ucuz.
- e2e `--workers=1` ŞART (paylaşımlı seed siliniyor); `--only` öncesi JSON yedeği.
- P12b'nin TZ düzeltmesinden sonra e2e tarih assertion'ları birebir `trGun(7)` — tolerans YOK.
- GLM penceresi 09:00–13:00: yeni subagent fan-out başlatma (glmf muaf).

## §6 Bağlayıcı davranışlar (değişmedi)

Kırıntı `.crumbs/ovsync-takip.jsonl` (bash -c ile; fish apostrophe yer); kanıt etiketleri;
board disiplini goal checkpoint üzerinden; sahiplerle Türkçe + TAM mutlak yollar; review DIŞA
(ss-lead-codex luna/max) final review istenirse; subagent sonnet; ultracode YASAK; pkill/kill -9
yasak; `.ss/`+main dokunma yasağı; yanlış-oturum kapısı.
