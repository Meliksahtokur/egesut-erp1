# Başlangıç promptu — ovsync-takip devir sonrası — 2026-09-29d

supersedes: `BASLANGIC-PROMPTU-2026-09-29c.md`

```
Sen ovsync-takip MİMAR oturumunu devralıyorsun. Worktree: /home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip; dal ovsync-takip @ 40feed3c6b1e5da55b44ba998618fdb24a5ee250 (commit'siz dirty çalışma kopyası).

Önce tam oku: /home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/HANDOFF-2026-09-29d-ovsync-takip.md (§0–§6). Ardından /home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/.harness/contract.md, /home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/.harness/goals/2026/G-20260929-OVSYNC-TAKIP-TEST-HAZIRLIK.md, /home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/test-uygulanabilir-DONE.md ve /home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/docs/plans/2026-09-28-ovsync-takip-ekrani/design.md §10h.

Önce canlı durumu bir kez ölç: git rev-parse HEAD; git status --short; herdr agent list (w14); DONE dosyaları. HANDOFF §2 ile karşılaştır. Test lead DONE=TAMAM, root kabul=PARTIAL (T-95/T-96 katalogda yok, T-72b Ç3 BLOKE ve 30 tur koşulmadı, manifest dışı test-uygulanabilir-HANDOFF.md); bunu ürün PASS'e yükseltme.

Sahip talimatı: aktif işler bittiğinde YENİ iş/koltuk başlatma; session update yap; polling yapma. WAKE aboneliği disarm edildi. Önceki Herdr wake hedefinde metin bara yazıldı fakat Enter etkisi doğrulanmadı; yeni abonelik kurmadan önce güvenli, ayrı doğrulama gerekir.

Bağlayıcı: mimar geniş okuma yapmaz, her DONE'da 1–2 yük taşıyan iddiayı kaynakta nokta-kontrol eder. Commit/dal/merge/push/PROD apply yok; .ss/ovsync-takip-BOARD.md ve .ss/ovsync-takip-HANDOFF.md'ye yazma yok; ultracode yok; w14:tC bu işe ait değil. §10h H9: yalnız kapsam-içi KRİTİK DÜZELTME doğurur. Sahiple Türkçe ve tam mutlak yollar kullan.

Sıradaki karar root/sahibindir: PARTIAL test teslimi için dar onarım zarfı mı, yoksa başka yön mü? Yetki verilmeden otomatik dağıtım yapma. Akış atlası ve B9 ayrı işlerdir.
```
