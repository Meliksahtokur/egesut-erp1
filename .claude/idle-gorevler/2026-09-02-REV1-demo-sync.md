# REV-1 — idle/demo-sync: Demo projesine eksik migration'lar + kritik-akis skip'lerinin açılması

**Tarih:** 2026-09-02 · **Taban:** main `a71b7a0` · **Branch:** `idle/demo-sync` (worktree: `/home/melik/egesut-wt/demo-sync`)
**Kaynak:** e2e-gercek raporu (`.claude/idle-reports/2026-09-02-e2e-gercek.md`) açık kalemler O2 + skip notu

## ZORUNLU GUARDRAIL — önce oku

- **PROD DB'YE SIFIR YAZMA/DEPLOY.** Prod'a karşı yalnız READ-ONLY sorgu serbest
  (information_schema, pg_get_functiondef).
- **Yazma yalnız DEMO projesine:** `vtzqjmazsvurxdeondmi` (ayrı hesap, izole klon — yazması bilinçli serbest).
  Token ayrımı: **demo** token `.mcp.json` → `supabase-demo` env (Management API
  `POST /v1/projects/vtzqjmazsvurxdeondmi/...`); **prod** token `tools-bank/.env` — KARIŞTIRMA.
  Karışıklık riski varsa dur, rapora yaz.
- Başlamadan DNS kontrolü: `getent hosts vtzqjmazsvurxdeondmi.supabase.co` çözünmüyorsa demo PAUSE →
  restore runbook: `.claude/session-learnings.md` Oturum 2026-09-01. Restore edemezsen raporla dur.
- Push YOK · tek commit · rapor: `.claude/idle-reports/2026-09-02-demo-sync.md`
- GitNexus: kod tarafı düzenlemeden önce `impact` (yalnız tests/kritik-akis.spec.js'e dokunulacak — LOW beklenir).

## Sorun (ölçülmüş — yeniden ölçme, doğrula)

e2e-gercek turunda demo şemasının eskimiş olduğu kesinleşti:
1. UI uyarısı: "Şema drift: prod'a **3 tablo / 0 kolon** eklenmiş, demo eskimiş. Migration'ı demo'ya uygula + FDW yenile."
2. `tohumlama_sonuc_gebe` demo'da ESKİ sürüm: sahte UUID → `{"ok":false,"error":"Tohumlama bulunamadı"}` (fn VAR),
   ama gerçek kayıtla **mesajsız** `ok:false` → UI "❌ Sonuç kaydedilemedi". Bu yüzden
   `tests/kritik-akis.spec.js`'te 2 test gerekçeli SKIP'te (46fbb4d).
3. `rpc/demo_sema_diff` demo'da 401; `rpc/hekim_listesi` demo'da 404 (bilinen).
4. Dashboard stat'leri demo'da 0 (FDW/eski şema).

## Kapsam — dört adım, fazlası yok

1. **Eksik envanteri çıkar:** prod (read-only) ve demo `information_schema.tables` + `pg_proc` karşılaştırması;
   `supabase/migrations/` listesinden demo'da uygulanmamış adayları belirle (beklenen: 20260831000003 tablo
   guard trigger'ları, 20260902000001/2 aşı stok + tohumlama_sonuc RPC güncelleyen migration'lar — KENDİN DOĞRULA).
2. **Demo'ya uygula:** eksik migration'ları sırayla demo projesine deploy et (Management API, demo token).
   Migration dosyasını DEĞİŞTİRME; uygulanamayan varsa rapora hata + gerekçe.
3. **FDW yenile:** demo `demo_klonla` FDW foreign tablolarını refresh et (UI uyarı metnindeki prosedür;
   `information_schema.foreign_tables` ile önce liste). Doğrula: demo'da dashboard stat'leri 0'dan dönüyor.
4. **Skip'leri aç + tam koşum:** `tests/kritik-akis.spec.js`'teki 2 gerekçeli skip'i kaldır
   (46fbb4d'te O2 gerekçesiyle eklenmişti). Ardından GERÇEK demo modunda tam koşum:

```bash
docker run --rm -e PLAYWRIGHT_DEMO_MODE=1 -e PLAYWRIGHT_BASE_URL=http://127.0.0.1:8080/ \
  -v "$PWD":/work -v /home/melik/egesut-erp1/node_modules:/home/melik/egesut-erp1/node_modules \
  -w /work mcr.microsoft.com/playwright:v1.58.2-noble \
  npx playwright test tests/e2e.spec.js tests/smoke.spec.js tests/sablon.spec.js \
    tests/sutten-kes.spec.js tests/modal-router.spec.js tests/kritik-akis.spec.js \
    tests/gece-tarih.spec.js tests/offline-kuyruk.spec.js --workers=1 --reporter=list
```

Hedef: **66 passed / 0 failed / 2 skipped** (gece-tarih'teki 1 veri-race skip kalabilir — gerekçelendir).

## Rapor zorunlulukları

- Uygulanan migration listesi + her birinin demo doğrulaması (tablo/fn varlık kanıtı)
- FDW refresh kanıtı + dashboard stat öncesi/sonrası
- Tam koşum çıktısı (pass/fail/skip tablosu)
- **O1 ÖNERİSİ (uygulama YOK):** demo'da anon rolün tablo GRANT'ları restore edilmeli mi,
  yoksa "yalnız authenticated" mi kalsın? Artı/eksi yaz, kararı kullanıcıya bırak.
- `root`-sahipli `test-results/` bırakma: `docker run --rm -v "$PWD":/wt alpine rm -rf /wt/test-results`
