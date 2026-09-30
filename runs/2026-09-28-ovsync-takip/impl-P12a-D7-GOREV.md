# impl-P12a-D7 — GOREV zarfı: Test kataloğunun plan v7'ye hizalanması (P12'nin 1. adımı, erken çıkarıldı)

- **Goal:** `G-20260930-OVSYNC-TAKIP-IMPL` (active)
- **Plan madde:** **P12 adım 1 / D7** — `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/docs/plans/2026-09-28-ovsync-takip-ekrani/plan.md:695` + **KATALOG GÜNCELLEME listesi `plan.md:852-870`**
- **Neden erken:** P12 E2E yazımı katalog hizalı olmadan doğru davranışı doğrulayamaz (plan hükmü); D7 koddan ve P9/P10/P11 dosyalarından bağımsız — paralel kulvar.
- **GOREV (bu dosya):** `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/impl-P12a-D7-GOREV.md`
- **DONE:** `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/impl-P12a-D7-DONE.md`

## Yazma manifesti (TEK YAZICI — liste dışı YASAK)

1. `docs/plans/2026-09-28-ovsync-takip-ekrani/test-senyolari.md` (MODIFY — kanonik ad ASCII `i` ile; dotless `ı` YANLIŞ)
2. `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/impl-P12a-D7-DONE.md` (create)

## Sayı drift çözümü (mimar ratifikasyonu 2026-09-30)

Plan metnindeki "12 madde" ifadesi BAYAT — liste v4/v5/v6/v7 eklemeleriyle **17 maddeye** büyüdü. **LİSTE OTORİTEDİR: 17 maddenin TAMAMI uygulanır** (plan.md:854-870). Yalnız ilk 12'yi uygulayıp bırakmak SILENT-SUCCESS sayılır.

## Zorunlu davranış protokolü

1. **İLK İŞ:** `/home/melik/.claude/skills/using-superpowers-obra/SKILL.md` oku ve uygula (sahip kuralı; SUBAGENT-STOP geçersiz).
2. Yazmadan ÖNCE: `.harness/references/domain-rules.md` (§18 üreme protokolleri) + `docs/plans/2026-09-28-ovsync-takip-ekrani/design.md` §10c–§10h (davranış gerçeği bu iki yerde; katalog bunların türevi).
3. Katalogu BAŞTAN SONA oku (83 KB; mevcut yapıyı ve ID şemasını kavramadan yazma).
4. **Minimal diff:** yalnız 17 maddenin söylediği değişiklikler; katalog tamamını yeniden yazma, yeniden numaralandırma YOK. Mevcut senaryo ID'leri (T-XX/S-XX) korunur.
5. Yeni senaryolar: dosyanın mevcut ID/blok şemasını izleyerek sıradaki boş numaralarla eklenir; madde 6/9/11/14/15/16/17'nin yeni senaryoları tek tek karşılanır.
6. Çelişki görürsen (liste ↔ design/domain-rules ↔ mevcut katalog metni): UYDURMA, KISMI raporla, DONE'da açık kalem olarak yaz (fail-closed).
7. En fazla 2 self-repair turu; aşarsan ESCALATE.

## Görev

`plan.md:852-870`'teki **KATALOG GÜNCELLEME listesi**'nin 17 maddesini `test-senyolari.md`'ye birebir işle. Her maddenin plan satırı: 854 (T-04), 855 (T-05), 856 (T-39), 857 (S-10), 858 (T-61/§10c#13), 859 (yeni K15 senaryoları), 860 (kapsam-dışı notu), 861 (İNSAN-UI 12 — değişiklik YOK, yalnız doğrula), 862 (+21/+35 taraması + 2 yeni senaryo), 863 (T-25/T-26 saat), 864 (dashboard 40g senaryosu), 865 (T-45/D2), 866 (T-61/D8), 867 (v4 yeni senaryolar), 868 (v5), 869 (v6 — v7 güncellemeli), 870 (v7).

## Kabul ölçütleri

1. 17 maddenin her biri DONE'da madde→değişiklik→`test-senyolari.md` satır aralığı tablosuyla kanıtlı; madde 861 "değişiklik yok — doğrulandı" satırıyla.
2. Katalogda 17 madde dışında davranış değişikliği YOK (`git diff` incelemesinde yalnız listelenen değişiklikler görünür).
3. Yeni senaryo ID'leri çakışmasız ve dosya şemasına uyumlu; DONE'da tam listesi.
4. `git diff --check` temiz.
5. Çelişki/uzlaşmazlık varsa DONE KISMI + açık kalem (sessiz geçiştirme YASAK).

## Yasaklar

- Kod yazımı (js/, tests/, supabase/ — hiçbiri); plan.md/design.md/domain-rules.md değişikliği; katalog tamamını yeniden yazma; commit; PROD; `.ss/`, `main`.

## DONE şablonu

Başlık: `impl-P12a-D7-DONE — TAMAM|KISMI|BLOKE` · 17 madde kanıt tablosu · yeni senaryo ID listesi · açık kalem.
