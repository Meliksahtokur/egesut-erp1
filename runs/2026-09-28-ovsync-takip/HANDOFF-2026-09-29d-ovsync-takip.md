# HANDOFF — ovsync-takip / MİMAR — 2026-09-29 18:00

supersedes: `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/.ss/ovsync-takip-mimar-HANDOFF.md` 16:45 sürümü ve `BASLANGIC-PROMPTU-2026-09-29c.md`.

## §0 İlk 5 dakika

1. Bu belgeyi ve `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/.harness/contract.md` dosyasını oku; ardından `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/.harness/goals/2026/G-20260929-OVSYNC-TAKIP-TEST-HAZIRLIK.md` manifestini ve `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/docs/plans/2026-09-28-ovsync-takip-ekrani/design.md` §10h kararını oku.
2. `git rev-parse HEAD`, `git status --short`, `herdr agent list` w14 ve DONE dosyalarını bir kez ölç; aşağıdaki §2 ile karşılaştır. Eski raporlar canlı kanıt değildir.
3. Test kabul sınırı için `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/test-uygulanabilir-DONE.md` ve bu belgenin §3'ünü oku. Sahip yeni iş başlatmadan session update istedi; yeni koltuk/onarım otomatik açılmaz.

## §1 Ne oldu

- Plan v7 re-review5 `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/plan-rereview5.md`: **KABUL** (§10h H9; 5 UYGULANDI, 3 KISMİ, 0 kapsam-içi KRİTİK, 3 ÖNEMLİ). Mimar nokta-kontrolü: `bulk_ilac` JSON anahtarları ile `vaka_toplu_ac` anahtarları gerçekten farklı; T-72b plan oracle'ı “vb.” ile açık kalmış. Üç uygulama notu `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/docs/plans/2026-09-28-ovsync-takip-ekrani/plan.md` Açık kalemler bölümüne yazıldı.
- Sahip yönüyle Full goal açıldı: `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/.harness/goals/2026/G-20260929-OVSYNC-TAKIP-TEST-HAZIRLIK.md`. Test zarfı `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/test-uygulanabilir-GOREV.md`, glmf-max koltuğu `w14:tK` idi; DONE sonrası kapatıldı.
- Test lead DONE `TAMAM` dedi; root bağımsız kabul **PARTIAL**: katalog başlıkları T-01..T-94 (94 adet), üst bilgi/rapor ise T-01..T-96 (96) diyor; T-95/T-96 yok. T-72b Ç3 seans fixture'ı `BLOKE`, beş çift × 30 tur koşulmadı. Test lead manifest dışı `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/test-uygulanabilir-HANDOFF.md` yazdı; korundu, kabul kapsamına alınmadı.
- Root tek seferlik yerel kontrol: iki JS `node --check` PASS; Playwright `--list` 8 test keşfetti; `git diff --check` temiz. Lead'in demo SQL (6 beklenen kırmızı + 4 PASS), T-72b kısa prova ve Docker Playwright (8/8 beklenen kırmızı) koşumları **rapor kanıtıdır**, root tarafından yeniden koşulmadı. Ürün/test/UI nihai PASS değildir; PROD apply/commit/merge/push yapılmadı.

## §2 Canlı işler (kapanış ölçümü)

| İş | Koltuk | Durum | Takip |
|---|---|---|---|
| Plan re-review5 | `w14:tJ` | DONE, tab kapalı | `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/plan-rereview5-DONE.md` |
| Test hazırlığı | `w14:tK` | DONE, tab kapalı; root kabul PARTIAL | `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/test-uygulanabilir-DONE.md` |
| GLM saat bekçisi | `w14:tM` | DONE görünce çıktı, tab kapalı | `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/glm-saat-bekcisi.sh` |
| WAKE | `wake-ovsync-test-glmfmax` | DONE `delivered`, abonelik `DISARM OK` | Herdr `w14:p3` hedefinde metin bara yazıldı; Enter'ın uygulamada işlendiği bağımsız kanıt yok. Tekrar poke etme. |

`w14:t3` bu oturumun mimar pane'i; `w14:tC` bu işe ait değil, dokunma. Kapanışta açık ovsync worker yoktu.

## §3 Sıradaki (otomatik başlatma YOK)

1. **[root/sahip]** Test hazırlığı kabulünü `PARTIAL` olarak ele al: katalog T-95/T-96 sayımını düzeltme/rapor iddiasını uyumlama; manifest dışı HANDOFF kapsamını karara bağlama; T-72b Ç3 fixture ve 30-tur gerçek demo provası için ayrı dar zarf belirleme. H5 satır JSON sözleşmesi ve demo hastalık adı `Ovsync Protokol` gözlemini implementasyon girdisi yap.
2. **[root/sahip]** Ürün implementasyonu ancak ayrı Full goal/yazma manifestiyle; test kırmızıları uygulama öncesi kanıttır. UI kapısı glmf-max PASS ve sahip demosu henüz yok.
3. Sahip bu oturum için “aktif işler bitince yenisini başlatma, session update yap ve polling yapma” dedi. Bu belge sonrasında yeni iş/koltuk/WAKE aboneliği açma.

## §4 Araçlar ve geçiciler

- Dal `ovsync-takip` @ `40feed3c6b1e5da55b44ba998618fdb24a5ee250`, commit'siz ve önceden dirty. Bu oturumda yalnız manifestli goal/plan/zarf/test teslimi/devir yüzeyleri yazıldı; başka oturumların `.ss/ovsync-takip-BOARD.md`, design/domain değişiklikleri korunur.
- `ss-wake-watch --arm` hedef `herdr:w14:p3` ile çalıştı; `ss-wake pending` kayıt `delivered` dedi. Herdr bacağı kaynakta `send-text` ardından `send-keys return` çağırıyor; kullanıcı metnin bara yazılıp Enter'ın basılmadığını gözledi. `delivered` sonucu uygulama düzeyinde gönderim kanıtı değildir. `wake-ovsync-test-glmfmax` disarm edildi. WAKE yolunu yeniden kullanmadan önce ayrı güvenli test gerekir.
- `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/glm-saat-bekcisi.sh` ilk sürüm sessizdi; kullanıcı `^C` ile durdurdu. Heartbeat eklendi, Herdr süreç+ekranla yeniden çalıştığı doğrulandı ve DONE sonrası kendisi çıktı. Artık çalışan zamanlayıcı yok.
- `inotifywait` ilk kurulumda `-m` yoktu ve ilk ilgisiz olayda çıktı; ardından `-m` ile olay aboneliği kuruldu, kullanıcı WAKE istediğinde durduruldu. Dosya/koltuk polling döngüsü yok. Geçici demo REST yanıtları lead raporuna göre `~/tmp/ovsync-takip-olcum/` altında; root temizlemedi.
- Commit yasağı sürüyor; `session-update` becerisinin commit adımı bu yüzden uygulanmadı. PROD DB/şema canlı kabulü yapılmadı.

## §5 Dersler

- DONE `TAMAM` ve test keşfi, hedef senaryo sayısı veya gerçek 30-tur prova PASS'i değildir; T-95/T-96 ve Ç3 sınırını bağımsız say.
- WAKE `delivered`, uygulama input-submit onayı değildir; hedef pane'de Enter etkisini ayrı ölçmeden teslim alındı sayma.
- Sessiz saat bekçisine görünür heartbeat koy; teslim bekleyişinde polling yerine doğrulanmış WAKE kullan.

## §6 Davranış mirası

- Mimar spec/plan yönü ve yük taşıyan nokta-kontrolü sahiplenir; commit/dal açma yok. Eski yol B9 kapsam dışı; §10h H9 yalnız kapsam-içi KRİTİK bulguyla DÜZELTME doğurur.
- Sahiple Türkçe ve tam mutlak yollar; her koltuk ayrı Herdr tab'ı; zarf GOREV+DONE, tam yazma listesi, ultracode ve `.ss/` yazma yasağı; idle koltuk teslim sonrası kapanır.
- GLM 09:00–13:00 durur; yeni GLM koltuğu açılırsa saat koruması yeniden kurulur. Yalnız w14 ovsync koltukları hedeflenir; `w14:tC` ve diğer owner seat'lere dokunulmaz.
- Sahip yeni iş başlatmadan session update ve polling'siz kapanış istedi; bu devirden sonra onarım turu kendiliğinden açılmaz.
