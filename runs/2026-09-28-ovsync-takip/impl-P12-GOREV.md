# impl-P12 — GOREV zarfı: Playwright demo E2E (kırmızı→yeşil) + T-72b fixture onarımı

- **Goal:** `G-20260930-OVSYNC-TAKIP-IMPL` (active)
- **Plan madde:** **P12** — `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/docs/plans/2026-09-28-ovsync-takip-ekrani/plan.md:685-703` (MADDE DRIFT KAPISI: yalnız P12)
- **D7 (P12'nin 1. adımı) ZATEN KAPALI:** katalog hizalı (fb08744 + `impl-P12a-D7-DONE.md`, mimar doğrulaması `5e15c6f`) — yeniden yapma.
- **DB önkoşulu SAĞLANDI:** demo DB'ye P1–P3b uygulandı (2026-09-30 23:10, `impl-demo-apply-2026-09-30.md`; RPC'ler + tetikleyiciler + kolon canlı). Demo yazma (fixture kurulumı) prova kapsamında serbesttir; sahibin demo geri-alma şifresi ve sahip hesabı DOKUNULMAZ.
- **GOREV (bu dosya):** `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/impl-P12-GOREV.md`
- **DONE:** `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/impl-P12-DONE.md`

## Yazma manifesti (TEK YAZICI — liste dışı YASAK)

1. `tests/e2e/ovsync-takip.spec.js` (create — demo modu)
2. `tests/concurrency/ovsync-takip-t72b.mjs` (MODIFY — fixture psql-protokol kusuru onarımı; gerçek yarış kanıtı `~/tmp/agents/t72b-mini.py`'de, desen oradan alınır)
3. `runs/2026-09-28-ovsync-takip/ui-test-listesi.md` (MODIFY — glmf-max 25 madde listesini teslim edilen UI ile son eşleme; madde sayısı korunur, copy/beklenen görünüm netleştirilir)
4. `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/impl-P12-DONE.md` (create)

Fixture SQL'i gerekiyorsa: `tests/e2e/fixtures/ovsync-demo-*.sql` (create, bu zarf kapsamında) — demo'ya apply/temizlik spec setup'ında betikleşir.

## Zorunlu davranış protokolü

1. **İLK İŞ:** `/home/melik/.claude/skills/using-superpowers-obra/SKILL.md` oku ve uygula (sahip kuralı; SUBAGENT-STOP geçersiz).
2. Kod öncesi: `.harness/references/domain-rules.md` §18 + `ui-map.md`; mockup 07 + K15 akışları (`runs/2026-09-28-ovsync-takip/mockup/`); mevcut e2e desenleri `tests/e2e/` (L4 yürüyüş tekniği: `EGESUT_DEMO` initScript, IDB pull bekleme, gürültü çipi — memory deseni `l4-sahip-yuruyusu`).
3. **Kırmızı ÖNCE:** spec iskeletini koş (hedefli — yalnız yeni spec) → kırmızı kanıt → implementasyon zaten teslim (P4–P10) → yeşile getirme; UI hatası çıkarsa düzeltme DEĞİL, DONE'da hata raporu (kod fixes mimara döner — 2 self-repair tavanı yalnız spec/fixture tarafında).
4. **Playwright koşumu:** Docker `mcr.microsoft.com/playwright:v1.58.2-noble --network host` deseni; worktree node_modules yok → `NODE_PATH=/home/melik/egesut-erp1/node_modules`. **sonuclar.json ezilme tuzağı:** `--only`/hedefli yeniden koşum öncesi mevcut sonuç dosyasını yedekle.
5. **PW kanıtı akış listesi (plan.md:696 birebir):** Boş→Ovsync; Boş→PG (ön-dolu ürün/doz snapshot.miktar dahil); Boş→Takibe bırak (+7g/saat; Görevler'de 🌱; S3'te 🔍); takip muayenesi→ertele (varsayılan SAATSİZ; ≥21g onayı); takip muayenesi→Gebe (GEBE_BULUNDU); **GEBELIK_KONTROL görevi→sonuç ekranı (Gebe / Boş-secici / Ertele — T-04 K15)**; takip açıkken hızlı PG→TAKIP_ACIK onayı (evet/vazgeç); PG_KAPI+birleşik (T-20 K15); takip açıkken ovsyncBaslat→onay; takipli hayvana tohumlama→sessiz kapanış (neden kayıtlı); jenerik gorev_tamamla REST guard (T-73 DB-SQL bu dosyada betikleşir); kızgınlık sorun vaka yolu C4 (+DB negatif iki varyant); D4 üç-yol (seans + toplu PG + bulk karışık satır-seçim); kalem 11 iki-satır PW; kalem 12 göreli gün PW.
6. Ekran/girişler/gezinme (plan.md:697-699): S0–S4 + boş bölüm gizli; dalga grup başlığı; rozetler; muayene sayacı 40g; bayrak kapalı mesaj; offline bayat etiket; 6. stat üç sınıf; 🔔/Görevler köprüleri; KPA≡🔔 alt küme; yatay geçiş; ‹ history.back; modal açıkken geri; scroll+filtre korunumu.
7. **T-72b fixture onarımı (ayrı kalem):** `ovsync-takip-t72b.mjs` psql protokol kusuru (fixture işlenmeden başarı) — `~/tmp/agents/t72b-mini.py` deseniyle onar; 5 çift × N tur koşumu demo DB'de; PASS oracle: 0×40P01/55P03 + sonuçlar izinli kümede (H7).

## Kabul ölçütleri (plan.md:701 + goal)

1. Yeni spec demo modunda yeşil (kırmızı→yeşil çıktıları DONE'da; ekran görüntüleri artifacts dizinine).
2. T-72b fixture onarımı + 5 çift koşumu ölçümü (0 yasak-olay; tur raporu DONE'da).
3. ui-test-listesi.md teslim edilen UI ile eşli (madde→beklenen görünüm→hangi akış).
4. `git diff --check` temiz; yeni kırmızı yok (3 pre-existing e2e/db kırmızısı dışında — e2e tarafında pre-existing kümesi farklı olabilir, baseline'ı önce ölç ve DONE'a yaz).
5. Sahibe demo ÖNCESİ glmf-max 25/25 kapısı ayrı adımdır (bu zarf listeyi hazırlar; koşum değil).

## Yasaklar

- `js/` kaynak dosyalarına yazma (UI hatası → DONE'da rapor); PROD erişim; `.ss/`, `main`; commit atma; sahibin demo şifresi/geri-alma akışına dokunma; sessiz varsayılan; 2 self-repair tavanı (spec/fixture tarafında).

## DONE şablonu

Başlık: `impl-P12-DONE — TAMAM|KISMI|BLOKE` · kırmızı→yeşil çıktıları + ekran görüntüleri · T-72b tur raporu · fixture listesi (kurulum/temizlik) · ui-test-listesi eşleme tablosu · UI hata raporu (varsa) · açık kalem.
