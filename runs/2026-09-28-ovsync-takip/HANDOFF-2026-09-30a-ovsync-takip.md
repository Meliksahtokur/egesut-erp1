# HANDOFF — ovsync-takip / MİMAR — 2026-09-30 07:14

supersedes: `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/HANDOFF-2026-09-29d-ovsync-takip.md`. Bu devir mevcut oturumun kapanışıdır; yeni implementasyon veya test turu başlatılmadı.

## §0 İlk 5 dakika

1. Bu belgeyi, `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/.harness/contract.md` ve aktif `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/.harness/goals/2026/G-20260929-OVSYNC-TAKIP-TEST-HAZIRLIK.md` kaydını oku.
2. Karar için yalnız ilgili kaynakları oku: `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/docs/plans/2026-09-28-ovsync-takip-ekrani/design.md` §10h; `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/plan-rereview5.md`; `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/test-uygulanabilir-DONE.md`.
3. `git rev-parse HEAD`, `git status --short`, seçili runtime'da w14 ajan listesi ve DONE dosyalarını **bir kez** ölç; §2 ile karşılaştır. Bekleyici/polling kurma. Sahip yeni işi ayrıca seçmeden koltuk açma.

## §1 Ne oldu

- Plan v7, Luna re-review5'te **KABUL** (§10h H9: 5 UYGULANDI, 3 KISMİ, 0 kapsam-içi KRİTİK, 3 ÖNEMLİ). Üç ÖNEMLİ uygulama notu planın Açık kalemler bölümünde; bu hüküm ürün kodu veya DB kabulü değildir.
- Test hazırlığı glmf-max DONE'da `TAMAM` dedi. Root kabulü **PARTIAL**: senaryo kataloğunda 94 `### T-` başlığı var, üst bilgi/rapor 96 diyor (T-95/T-96 yok); T-72b Ç3 seans fixture'ı `BLOKE`, 5 çift × 30 tur koşulmadı; worker yazma manifesti dışında `test-uygulanabilir-HANDOFF.md` yarattı. Bu dosya korundu, teslim kapsamına alınmadı.
- Root doğrulaması (2026-09-29): iki JS `node --check` çıkış 0, Playwright `--list` 8 test, `git diff --check` çıkış 0. Demo SQL/REST ve Docker Playwright kırmızı koşumları lead raporu olarak **ATTESTED**; root yeniden çalıştırmadı. Ürün/UI PASS, db-validation ve PROD apply **yok**.
- 2026-09-30 07:14 ölçümü: dal `ovsync-takip`, HEAD `40feed3c6b1e5da55b44ba998618fdb24a5ee250`, commit yok; önceki dirty/untracked çalışma kopyası korunuyor. Yeni plan/test/ürün turu açılmadı.

## §2 Canlı işler (2026-09-30 07:14 ölçümü)

| İş | Koltuk / hedef | Durum | Kanıt |
|---|---|---|---|
| Mimar devir | Herdr `w14:p3`, tab `w14:t3`, Codex | bu oturum çalışıyor; devir sonrası duracak | `herdr agent list` w14: tek ajan |
| Plan re-review5 ve test hazırlığı | eski `w14:tJ`, `w14:tK` | DONE, tablar kapalı; yeni worker yok | DONE dosyaları ve `herdr tab list --workspace w14`: yalnız `w14:t3` |
| GLM saat bekçisi | eski `w14:tM` | kapalı; çalışan zamanlayıcı yok | w14 tab listesi |
| WAKE | `wake-ovsync-test-glmfmax` | abonelik kapalı; ovsync arm 0 | `ss-wake-watch --list --json` ovsync filtresi `[]` |

## §3 Sıradaki (root/sahip kararı; otomatik dağıtım YOK)

1. **[root/sahip]** Test hazırlığı `PARTIAL` için dar kapsam belirle: T-95/T-96 iddiasını katalogla uyumla; manifest dışı HANDOFF'u kapsam ihlali olarak işle; T-72b Ç3 fixture ve gerçek N=30 demo provası için ayrı zarf/goal kararı ver. H5 `TAKIP_ACIK` satır JSON sözleşmesi ile demo hastalık adı `Ovsync Protokol` gözlemi implementasyon girdisidir.
2. **[root/sahip]** Ürün implementasyonu ayrı Full goal/manifest ister. Önceki kırmızı testler ürün öncesi kanıttır; UI kapısı glmf-max PASS ve sahip demosu henüz yok. Commit/merge/push/PROD apply ayrı sahip kapılarıdır.
3. Kullanıcının “aktif işler bitince yenisini başlatma, session update yap ve polling yapma” talimatı sürer. Bu devir paketinin yazılması yeni işe başlama yetkisi değildir.

## §4 Araçlar ve geçiciler

- `.ss/ovsync-takip-BOARD.md`, design.md ve domain-rules.md önceden dirty; başka oturumun değişiklikleri korunur. Plan ve katalog `docs/plans/` altında gitignore; `runs/` teslimleri untracked. `git add -A` kullanma. Commit yasağı nedeniyle `session-update` becerisinin P1 commit adımı uygulanmadı.
- Eski Herdr WAKE hedefi `herdr:w14:p3` için kayıt `delivered` olsa da kullanıcı metnin giriş çubuğuna yazılıp Enter'ın işlenmediğini gözledi. Abonelik disarm edildi; `delivered` uygulama düzeyi gönderim kanıtı değildir. Yeniden arm/poke etmeden önce ayrı güvenli doğrulama gerekir.
- Eski `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/glm-saat-bekcisi.sh` DONE ile çıktı; artık açık GLM koltuğu yok. 09:00–13:00 GLM durma kuralı yeni koltuk açılırsa yeniden uygulanır. `/tmp` tmpfs; büyük geçiciler için `TMPDIR` kullan.
- Demo REST ölçüm dosyaları lead raporuna göre `~/tmp/ovsync-takip-olcum/` altında; root silmedi. Eski `inotifywait`/DONE bekleyicisi kapatıldı, polling yok.
- Proje hafıza işaretçisi `/home/melik/.claude/projects/-home-melik-egesut-erp1/memory/ovsync-takip-ekrani-durum.md` ve MEMORY.md index satırı bu belgeye çevrildi; tools-bank vektör notu `id=1440` eklendi. Codex hafızası için yalnız izinli `extensions/ad_hoc/notes/20260930T041648Z-ovsync-takip-devir.md` güncelleme notu yazıldı; kanonik hafıza dosyaları doğrudan düzenlenmedi.

## §5 Dersler

- Worker `TAMAM` hükmünü katalog sayısı ve gerçek prova çıktısıyla bağımsız karşılaştır; 94/96 ve Ç3/N=30 ayrımı `PARTIAL` bırakır.
- WAKE `delivered` yalnız taşıma durumudur; kullanıcı girdisinin Enter ile işlendiğini kanıtlamaz. Sorun güvenli testle çözülene dek bu Herdr wake hedefini yeniden kullanma.
- Bağlayıcı manifest dışı HANDOFF dosyasını sessizce sahiplenme veya silme; gözlemi ve kabul sınırını kaydet.

## §6 Davranış mirası

- Mimar spec/plan yönü ve her DONE'da 1–2 yük taşıyan iddianın kaynak nokta-kontrolünü sahiplenir. §10h H9: yalnız kapsam-içi KRİTİK DÜZELTME doğurur; eski yol kilit denetimi B9 ayrı iş.
- Sahiple Türkçe ve tam mutlak yollar; yeni bağımsız koltukta exact GOREV+DONE, yazma manifesti, ultracode yasağı ve `.ss/` yazma yasağı; idle tab kapanır. `w14` dışı owner seat'lere dokunma.
- Commit/dal/merge/push/PROD apply yok. Sahip yeni iş seçene kadar yeni koltuk veya WAKE aboneliği açma; polling yapma. Oturum yalnız bu devirle kapanır.
