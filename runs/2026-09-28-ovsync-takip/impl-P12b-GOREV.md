# impl-P12b — GOREV zarfı: TZ kalıcı-tarih düzeltmesi (yeni migration) + yalın TAKIP_ACIK sheet UI fix

- **Goal:** `G-20260930-OVSYNC-TAKIP-IMPL` (active); P12 E2E'nin bulduğu iki gerçek hata.
- **Sahip onayı:** 2026-10-01 00:35 — "Fix + demo'ya uygula" (migration demo apply + e2e re-run dahil).
- **GOREV (bu dosya):** `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/impl-P12b-GOREV.md`
- **DONE:** `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/impl-P12b-DONE.md`

## Yazma manifesti (TEK YAZICI — liste dışı YASAK)

1. `supabase/migrations/20261001000001_takip_yerel_gun_duzeltme.sql` (create)
2. `js/ui.js` (MODIFY — yalın TAKIP_ACIK detay çözümlemesi)
3. `tests/unit/ovsync-takip-kapi.test.js` (MODIFY — yalın sheet alan testi)
4. `tests/e2e/ovsync-takip.spec.js` (MODIFY — ertele Istanbul-yerel assertion + yalın sheet alanları)
5. `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/impl-P12b-DONE.md` (create)

## HATA-2 — TZ kalıcı-tarih (sunucu; 4 yazma noktası)

**Bug:** hedef tarihler `CURRENT_DATE` (sunucu TZ=UTC) ile hesaplanıyor; TR 00:00–08:00
arasında yapılan işlemler bir gün geride KALICI yazılıyor [OBSERVED canlı: 10-08 beklenirken 10-07].
**Fix:** yeni migration, etkilenen fonksiyon gövdelerinde Europe/Istanbul yerel takvim günü:
`((now() AT TIME ZONE 'Europe/Istanbul')::date + p_gun)` kalıbı. Siteler:
- `20260929000002:119` (takip görevi kurulumu hedef_tarih) ve `:808` (erteleme v_yeni_hedef) —
  hangi fonksiyonlar olduğunu migration kaynağından tespit et, yalnız o gövdeleri yeniden tanımla;
- `20260929000003:1457` (geçmiş-tarih guard) ve `:1987` (kızgınlık vaka yolu `cases.start_date`).
**KASITLI OLARAK DOKUNULMAZ:** `20260929000001` (listele) CURRENT_DATE'leri — kaynak fonksiyon
paritesi T-45 gereği kasıtlı (migration kendi yorumu :16, :206); okuma penceresi gece ±1'i
geçici görünümdür, kalıcı veri yazmaz.
**Disiplin:** db-validation kapısı (draft + final; `scripts/db-validate.sh` worktree içinden);
fonksiyon gövdesi değişikliği → anon EXECUTE REVOKE'ları yeni gövdede KORUNUR (şablon); ACL +
imza değişmez; PROD yok. Yeni gövdelerin GT uyarı listesine gireceği P13'e not edilir (DONE'da yaz).

## HATA-1 — yalın TAKIP_ACIK sheet boş tarih/saat (UI)

**Bug:** `js/ui.js:2757-2760` yalın red'te `red.detay?.takip_acik` okuyor; sunucu yalın payload
detayı DOĞRUDAN taşır (`TAKIP_ACIK:{muayene_tarihi, muayene_saat}` — P3b DONE §4 kanıtı; H5
`takip_acik` anahtarı yalnız bulk satır-sonucunda). :3069'daki çözümleyici yalın durumu doğru
işler (`m[1] === 'PG_KAPI:TAKIP_ACIK' ? detay.takip_acik : detay`).
**Fix:** 2757 hattını aynı çözümleyici mantığından geçir (yardımcıyı yeniden kullan; kopya-yapıştır
yok). Birim testi: yalın payload → sheet'te muayene tarihi + saat DOLU; e2e P12-4 assertion'ı güncellenir.

## Zorunlu davranış protokolü

1. **İLK İŞ:** `/home/melik/.claude/skills/using-superpowers-obra/SKILL.md` oku ve uygula (sahip kuralı; SUBAGENT-STOP geçersiz).
2. Kırmızı önce: kapi testine yalın-payload testi (kırmızı) → UI fix → yeşil; e2e assertion'ları fix sonrası.
3. **Demo apply (sahip onaylı):** db-validate sonrası psql (pooler; `/home/melik/egesut-erp1/.env`
   SUPABASE_DEMO_*; değerleri basma), ON_ERROR_STOP, tek transaction (dosya kendi BEGIN/COMMIT
   taşımıyorsa sar). Öncesi şema yedeği: etkilenen 4 fonksiyonun `pg_get_functiondef` çıktısı
   `~/tmp/demo-yedek-2026-09-30-ovsync/p12b-oncesi-fonksiyonlar.sql`'a. Sonrası doğrulama:
   gövdede `Europe/Istanbul` geçiyor (pg_get_functiondef grep) + imza/ACL değişmedi.
4. E2e yeniden koşum: etkilenen testler (`--only` öncesi sonuç JSON yedeği; `--workers=1`).
5. En fazla 2 self-repair; commit ATMA; bilinçli sapma → DONE'da gerekçeli.

## Kabul ölçütleri

1. db-validation PASS (draft + final; rapor `reports/` altına, `git add -f` mimar hasadında).
2. Unit: kapi testleri + yeni yalın-payload testi yeşil; tam unit süit 1405+/3 pre-existing.
3. Demo: apply OK + doğrulama sorguları (TZ kalıbı, imza, ACL) DONE'da.
4. E2e: etkilenen testler yeşil; ertele assertion'ı Istanbul-yerel bekler (gece koşumda bile).
5. `git diff --check` temiz; yeni kırmızı yok.

## Yasaklar

- js/api.js yazımı; 2026092900000*.sql dosyalarına dokunma (tarih sabit); PROD; `.ss/`, `main`; commit; sessiz varsayılan.

## DONE şablonu

Başlık: `impl-P12b-DONE — TAMAM|KISMI|BLOKE` · db-validate raporu · apply + doğrulama çıktıları · kırmızı→yeşil · e2e re-run çıktısı · GT-notu (P13'e) · açık kalem.
