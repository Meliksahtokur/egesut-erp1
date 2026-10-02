# ui-tur-DONE — run6 (resmi config) — 7/25 PASS

Kanıt PNG dizini: /home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/artifacts/

| Madde | Sonuç | Kanıt PNG |
|---|---|---|
| M1 | PASS | uitur-01-dash-6hucre.png |
| M2 | FAIL | — |
| M3 | FAIL | — |
| M4 | FAIL | — |
| M5 | FAIL | — |
| M6 | PASS | uitur-06-devam-secici-ovsync.png |
| M7 | PASS | uitur-07a-pg-on-dolu.png, uitur-07b-pg-secim-gerekli-pasif.png |
| M8 | FAIL | — |
| M9 | FAIL | — |
| M10 | FAIL | — |
| M11 | FAIL | — |
| M12 | FAIL | — |
| M13 | FAIL | — |
| M14 | FAIL | — |
| M15 | FAIL | — |
| M16 | PASS | uitur-16a-ertele-saatsiz-onizleme.png, uitur-16b-21g-onay.png |
| M17 | PASS | uitur-17-iki-satir-tahmini-dogum.png |
| M18 | PASS | uitur-18-goreli-gun.png |
| M19 | PASS | uitur-19a-s2-vakti-plus5g.png, uitur-19b-ayar35-satir-kaydi.png |
| M25 | FAIL | — |
| M20 | FAIL | — |
| M21 | FAIL | — |
| M22 | FAIL | — |
| M23 | FAIL | — |
| M24 | FAIL | — |

## FAIL ilk hata satırları
- M2: Error: expect(received).toContain(expected) // indexOf / Expected substring: "(10 takipte)"
- M3: Error: başlıklar  ⇔ satırlar S2,S3,S4 / expect(received).toEqual(expected) // deep equality
- M4: Error: expect(locator).toBeVisible() failed / Locator: locator('#dash-body').filter({ hasText: '🌱 İlk Tohumlama (' })
- M5: Error: expect(locator).toBeVisible() failed / Locator: locator('#dash-body div').filter({ hasText: '🌱 İlk Tohumlama (' }).first()
- M8: Error: expect(received).toBe(expected) // Object.is equality / Expected: "2026-10-08"
- M9: Error: kural günü gelmemiş hayvanda Ovsync kilitli: {"kilitli":false,"gerekce":null} / expect(received).toBe(expected) // Object.is equality
- M10: Error: expect(locator).toBeVisible() failed / Locator: locator('#proto-mini')
- M11: TimeoutError: page.click: Timeout 10000ms exceeded. / Call log:
- M12: Error: expect(locator).toBeVisible() failed / Locator: locator('#proto-mini')
- M13: Error: expect(locator).toBeVisible() failed / Locator: locator('#pg-ovsync .ovs-takip-satir').filter({ hasText: 'E2E-UITUR-e' })
- M14: Error: expect(locator).toBeVisible() failed / Locator: locator('#pg-ovsync .ovs-takip-satir').filter({ hasText: 'E2E-UITUR-q' })
- M15: TimeoutError: locator.click: Timeout 10000ms exceeded. / Call log:
- M25: Error: expect(locator).toBeVisible() failed / Locator: locator('#pg-ovsync .ovs-s3-satir').filter({ hasText: 'E2E-UITUR-g' }).getByRole('button', { name: /Başlat/ })
- M20: Error: expect(locator).toBeVisible() failed / Locator: locator('#pg-ovsync .ovs-s3-satir').filter({ hasText: 'E2E-UITUR-g' }).getByRole('button', { name: /Başlat/ })
- M21: Error: expect(locator).toContainText(expected) failed / Locator: locator('#pg-ovsync .ovs-kart').filter({ hasText: 'E2E-UITUR-p' }).first().locator('.ovs-rozet-kayma')
- M22: Error: expect(locator).toContainText(expected) failed / Locator: locator('#pg-ovsync')
- M23: Error: expect(locator).toBeVisible() failed / Locator: locator('#pg-ovsync').filter({ hasText: '⚠️ çevrimdışı · ' })
- M24: TimeoutError: locator.click: Timeout 10000ms exceeded. / Call log:

## M3 probe (m3-probe-run6.log)
- HTTP >=400: 401 https://vtzqjmazsvurxdeondmi.supabase.co/rest/v1/rpc/demo_sema_diff (tek satır)
- M3: FAIL — "başlıklar ⇔ satırlar S2,S3,S4" (beklenen S2,S3,S4 başlık/satır kümesi; görülen: #ovsync-root yükleyici, başlık yok). Probe dosyası tüm 25 maddeyi koştu (testMatch dosya düzeyinde); M18 probe'da FAIL, run6'da PASS (kararsız).

## Koşum
Çalışma dizini /home/melik/tmp/agents/uitur-20261001/ ; config playwright-resmi.config.cjs (repo /work/playwright.config.js temel; testDir/testMatch/globalSetup/Teardown/workers=1/retries=0/reporter ezildi); sarmal run6.sh:
`docker run --rm --network host -v $WT:/work -w /work -v /home/melik/tmp/agents/uitur-20261001:/agents -v /home/melik/egesut-erp1:/main:ro -e NODE_PATH=/main/node_modules -e PLAYWRIGHT_DEMO_MODE=1 -e PLAYWRIGHT_BASE_URL=http://127.0.0.1:8137/ -e HOME=/tmp/pwhome mcr.microsoft.com/playwright:v1.58.2-noble /main/node_modules/.bin/playwright test -c /agents/playwright-resmi.config.cjs --workers=1`
Log: run6.log ; JSON: uitur-sonuc-run6.json (npx ilk denemede yanlış playwright@1.63 indirdi; /main/node_modules/.bin kullanıldı). Not: FAIL maddelerinin PNG'si yok (uitur-22 PNG'si önceki koşumdan kalma).

run5 karşılaştırma: 7/25
