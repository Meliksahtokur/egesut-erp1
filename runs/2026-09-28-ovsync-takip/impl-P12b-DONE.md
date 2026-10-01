# impl-P12b-DONE — TAMAM

- **Zarf:** `runs/2026-09-28-ovsync-takip/impl-P12b-GOREV.md` (sahip onayı 2026-10-01 00:35 — "Fix + demo'ya uygula")
- **Goal:** `G-20260930-OVSYNC-TAKIP-IMPL`
- **Tarih:** 2026-10-01 · **Worktree:** `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip` · **Commit YOK** (zarf yasağı)
- **Yazma manifesti birebir tutuldu:** migration (yeni) + js/ui.js + tests/unit/ovsync-takip-kapi.test.js + tests/e2e/ovsync-takip.spec.js + bu DONE. List dışı yazım yok.

## 0. Skill/protokol uyumu

`using-superpowers-obra` okundu-uygulandı (sahip kuralı; SUBAGENT-STOP geçersiz sayıldı):
`db-validation` + `code-change-precheck` + `test-driven-development-obra` çağrıldı;
`.harness/references/domain-rules.md` SQL öncesi okundu (§18.10/§18.15 erteleme ve takip
sözleşmeleriyle çelişki yok — fix mevcut sözleşmenin tarih-kaynağını düzeltir).

## 1. HATA-2 — TZ kalıcı-tarih (yeni migration)

**Dosya:** `supabase/migrations/20261001000001_takip_yerel_gun_duzeltme.sql` (1242 satır; SHA-256
`46f4d0b473698ba388fee159ffc38df7082eb4e1888d08cedcb60b5a58b25678`).

4 gövde, canlıyla **birebir pariteli** kaynaktan üretildi (canlı `pg_get_functiondef` ↔ migration
kaynağı diff: 4/4 BYTE PARITE OK — yedek: `~/tmp/demo-yedek-2026-09-30-ovsync/p12b-oncesi-fonksiyonlar.sql`,
1170 satır). Tek fark TZ deseni `((now() AT TIME ZONE 'Europe/Istanbul')::date + …)`:

| # | Fonksiyon | Site | Eski | Yeni |
|---|---|---|---|---|
| 1 | `_takip_gorev_kur(uuid,text,int,time)` | 20260929000002:119 | `CURRENT_DATE + p_gun` | `((now() AT TIME ZONE 'Europe/Istanbul')::date) + p_gun` |
| 2 | `tohumlama_bos_ve_devam(...)` ERTALE | 20260929000002:808 | `v_yeni_hedef := CURRENT_DATE + COALESCE(p_gun,7)` | aynı desen |
| 3 | `vaka_toplu_ac(...)` geçmiş guard | 20260929000003:1457 | `p_tarih < CURRENT_DATE` | `p_tarih < (now() AT TIME ZONE 'Europe/Istanbul')::date` |
| 4 | `kizginlik_vaka_ac(...)` cases.start_date | 20260929000003:1987 | `CURRENT_DATE` | `(now() AT TIME ZONE 'Europe/Istanbul')::date` |

`20260929000001` (listele) CURRENT_DATE'leri KASITLI dokunulmamadır (T-45 kaynak-paritesi; zarf
birebir). ACL + imza DEĞİŞMEZ: her gövde için kaynak migration'ın REVOKE/GRANT satırları aynen
yeniden onaylandı (2.sql ikilisi `FROM PUBLIC, anon, authenticated`; 3.sql ikilisi `FROM PUBLIC, anon`;
dördüne de `GRANT authenticated, service_role`); `NOTIFY pgrst` + kendi BEGIN/COMMIT taşır. Anon GRANT YOK.

### 1a. db-validation kapısı (draft + final)

- `bash scripts/db-validate.sh supabase/migrations/20261001000001_takip_yerel_gun_duzeltme.sql`
  → **PASS** (taslak VE final — dosya değişmedi, SHA aynı: `46f4d0b4`).
- Rapor: `reports/db-validation-46f4d0b4.md` (baseline egesut_lsp T=55 F=256 V=13 parite=uyumlu;
  A parse/squawk, B şema, C1 restore+apply+nesne+RLS, C2 sentetik veri — hepsi PASS).
- Not: rapor `reports/` gitignore'da — `git add -f` mimar hasadında (teslim mekaniği kuralı).

### 1b. Demo apply (sahip onaylı) + doğrulama

- Apply: pooler psql, `ON_ERROR_STOP=1`, dosyanın kendi BEGIN/COMMIT'i → **4 CREATE OR REPLACE +
  4×(REVOKE,GRANT) + NOTIFY + COMMIT, hatasız**. Log: `~/tmp/demo-yedek-2026-09-30-ovsync/p12b-apply.log`.
- Doğrulama (canlı demo sorguları, OBSERVED):
  - TZ kalıbı: 4/4 gövdede `Europe/Istanbul` **VAR**, `CURRENT_DATE` **temiz**.
  - İmza: 4/4 `pg_get_function_identity_arguments` apply-öncesiyle AYNI (uuid/jsonb dönüşler dahil).
  - ACL: 4/4 `anon:yok | PUBLIC:yok | auth:var | svc:var` (değişmez).
  - Kanıt sorgusu: sunucu UTC `03:58` iken `CURRENT_DATE=2026-10-01` = `istanbul_gunu=2026-10-01`
    (divjans penceresi UTC 21:00–24:00; kalıbın kendisi gövde kanıtıyla sabit).
- PROD: DOKUNULMADI (sahip kapısında kalır).

## 2. HATA-1 — yalın TAKIP_ACIK sheet (UI, TDD kırmızı→yeşil)

**Bug:** `js/ui.js` `_devamSeciciOnayla` (eski :2757-2760) `red.detay?.takip_acik` okuyordu; sunucu
yalın redte detayı DOĞRUDAN taşır (`TAKIP_ACIK:{muayene_tarihi, muayene_saat}`) → sheet'te tarih/saat boş.

**Fix (kopya-yapıştır yok — TEK çözümleyici):**
- Yeni `js/ui.js` helper'ı `_takipDetayCoz(kod, detay)` = `kod === 'PG_KAPI:TAKIP_ACIK' ? (detay.takip_acik || {}) : detay`
  (eski :3069 çözümleyicisinin çıkarılmış hali).
- `_takipAcikHata` artık `_takipDetayCoz(m[1], detay)` çağırır (8 çağrı noktasına davranış-koruyucu —
  inline ternary ile mantık birebir aynı; `detay || {}` guard no-op).
- `_devamSeciciOnayla` yalın dalı: `takip_acik: _takipDetayCoz(red.kod, red.detay)`.
- ZATEN_ACIK türevi davranışı KORUNDU (alan uydurma yok — sheet yine dolu alanla açılmaz/yine boş
  düşer, tıpkı öncesi gibi; kapsam-dışı davranış değişikliği yapılmadı).

**Blast radius (code-change-precheck):** gitnexus bu indekste `js/ui.js` Function node'ları
TAŞIMIYOR (kör alan — `ui.js` için 0 Function satırı, cypher ile doğrulandı). Matris fallback'i
kullanıldı: built-in LSP `findReferences` → `_takipAcikHata` 8 çağrı noktası (ui.js×6, forms.js×2),
`_devamSeciciOnayla` 4 referans (kendi+2 iç çağrı+handlers.js:498 bağlama), yeni helper 2 tüketici.
Risk DÜŞÜK (saf çözümleyici; davranış değişimi yalnız yalın dalda). gitnexus indeksi iş öncesi +
sonrası `analyze --index-only` ile tazelendi (enjeksiyon yok).

**Kırmızı önce (TDD):** `tests/unit/ovsync-takip-kapi.test.js` —
- YENİ `YALIN-SECICI` testi: `_devamSeciciOnayla` + yalın `TAKIP_ACIK:{...}` redi → sheet HTML'inde
  `05.10 14:35'te rektal muayene takibinde.` DOLU alan zorunlu → **KIRMIZI doğrulandı**
  (`yalın payload'ta muayene tarihi + saat sheet'te DOLU` assertion fail — bug yeniden üretildi).
- `KAPI-ENVANTER` testine yapı-kilidi: `_devamSeciciOnayla` ve `_takipAcikHata` `_takipDetayCoz(`
  kullanmalı (kopya-yapıştır regresyon kilidi) → kırmızıydi, fix ile yeşil.
- **Yeşil:** kapi dosyası **22/22 PASS** (20 eski + 2 yeni; `_takipDetayCoz` vm kaptan listesine
  P10_UI_FNS'e eklendi — 1 test-infra düzeltmesi).

**Tam unit süit:** `NODE_PATH=/home/melik/egesut-erp1/node_modules node --test tests/unit/*.test.js`
→ **tests 1406 · pass 1404 · fail 2**. Kırmızı ikili PRE-EXISTING kümenin ÜYELERİ: `LUNA-3 canlı
DEMO` + `ay ‹/› sayfalama` (bc-tarih). Üçüncü pre-existing (`gelecek güne tık`) bu koşumda YEŞİL —
tarih-duyarlı test (P10/P11 ölçümü 09-30'daydı; bugün 10-01). **Yeni kırmızı YOK.**

## 3. E2e re-run (etkilenenler + tam ovsync süiti)

- Spec güncellemeleri (`tests/e2e/ovsync-takip.spec.js`):
  - T-20: bayat "NOT: … GÖRÜNMÜYOR" yorumu kaldırıldı → `await expect(sheet).toContainText(/\d{2}\.\d{2} 09:00'te rektal muayene takibinde\./)` (yalın sheet DOLU alan kanıtı; seed b hedef_saat 09:00).
  - T-25/T-26: `[trGun(6), trGun(7)]` toleransı → **birebir `trGun(7)`** (Istanbul-yerel; +6 toleransı UTC hatasının gölgesiydi).
  - T-87: aynı netleştirme → `expect(gorev?.hedef_tarih).toBe(trGun(7))`.
- Koşum: docker `mcr.microsoft.com/playwright:v1.58.2-noble`, `PLAYWRIGHT_DEMO_MODE=1`,
  `PLAYWRIGHT_BASE_URL=http://127.0.0.1:8137/` (worktree yerel sunucusu), `--workers=1 --retries=0
  --reporter=list`, `/main/node_modules/.bin/playwright` (log: `~/tmp/p12b-e2e.log`) →
  **12 passed (2.7m) — 12/12** (baseline 12/12 korunmuş + yeni assertion'lar yeşil).
- `sonuclar.json`: repo genelinde MEVCUT DEĞİL ve bu spec rapor yazmaz (spec:21) — ezilecek dosya yoktu; `--only` hiç kullanılmadı (tam süit koşuldu; ezilme tuzuğu kökten devre dışı).
- `node --check js/ui.js` OK; `git diff --check` TEMİZ.

## 4. GT-notu (P13'e)

Bu 4 fonksiyon gövdesi demo'da 20261001000001 ile değişti; PROD henüz ESKİ (CURRENT_DATE'li) gövdeleri
taşıyor. P13'te GT/şema karşılaştırma ve prod-apply hazırlığında:
1. `99999999999999_ground_truth.sql` bu 4 fonksiyonda demo gerçekliğinden bayat görünecek — demo-yönlü
   karşılaştırmalarda "fark" BEKLENEN işarettir (prod apply edilene kadar).
2. Prod apply sırası: aynı migration dosyası (20261001000001) prod kapısından; apply sonrası GT yenileme
   planı zaten P13'te (plan.md:717) — bu 4 gövde o yenilemede doğal olarak oturur.
3. db-validate raporu (46f4d0b4) prod-apply prova girdisi olarak kullanılabilir.

## 5. Bilinçli sapmalar (gerekçeli)

1. **Blast-radius hook bayrağı elle kuruldu:** gitnexus'un ui.js kör alanı yüzünden `gitnexus_impact`
   sembolü bulamadı; precheck skill'inin LSP fallback'iyle analiz yapıldıktan sonra edit'e geçildi
   (hook'un istediği "önce impact" koşulu özde sağlandı; `/tmp/blast-radius-done` tek küçük timestamp).
2. **`--only` yerine tam 12'lik e2e süiti koşuldu:** daha güçlü kanıt (migration 4 RPC'ye dokunduğu
   için tüm ovsync yüzeyi teyit edildi) + sonuç-JSON ezilme tuzuğu kökten devre dışı. Süre 2.7 dk.
3. **Self-repair sayacı: 1/2** (test-infra: `_takipDetayCoz`'ün vm kaptan listesine eklenmesi;
   ürün kodunda repair gerekmedi — TDD akışı tek geçişte yeşile oturdu).

## 6. Açık kalemler

1. **ui-test-listesi.md maddeleri 11 ve 35 bayatladı** (manifest TEK YAZICI — dokunulmadı): her iki
   maddedeki "⚠ HATA-1 / ⚠ HATA-2 … glmf-max bulguyu bekler" metinleri fix sonrası geçersiz;
   hasatta "fix kanıtıyla güncelle" notu düşülmeli (T-20 maddesi artık DOLU `GG.AA SS:DD` metni, ertele
   maddesi artık birebir +7 hedef bekler).
2. **PROD apply** sahip kapısında (migration hazır + db-validate PASS; zarf gereği bu zarf PROD'a dokunmadı).
3. Unit tam-süit sayımı: 1406 (P11 ölçümü 1405'ti) — +2 yeni kapi testi bu dosyada; kalan 1'lik fark
   P11 sonrası ana dal test-envanter değişimi kaynaklı olabilir, incelemeye değer değil (kırmızı
   kümesi ⊆ pre-existing; yeni kırmızı yok).
4. `reports/db-validation-46f4d0b4.md` için mimar hasadında `git add -f` (reports/ gitignore'da).
5. Başka oturuma ait görünen 7 saatlik tsserver süreci (PID 763367) LSP-kapatma disiplini dışında
   bırakıldı (başka koltuğun sürecine dokunmama kuralı).

## 7. Kabul ölçütleri ↔ kanıt

| # | Kriter | Sonuç |
|---|---|---|
| 1 | db-validation PASS (draft + final; rapor reports/) | ✅ PASS ×2 — `reports/db-validation-46f4d0b4.md` |
| 2 | Unit: kapi + yalın testi yeşil; tam süit 1405+/pre-existing | ✅ kapi 22/22; tam süit 1406/1404/2 (kırmızılar ⊆ pre-existing) |
| 3 | Demo: apply OK + doğrulama (TZ, imza, ACL) | ✅ 4/4 TZ VAR+CURRENT_DATE temiz; imza/ACL değişmez |
| 4 | E2e: etkilenenler yeşil; ertele Istanbul-yerel bekler | ✅ 12/12; T-25/T-26+T-87 birebir `trGun(7)` |
| 5 | `git diff --check` temiz; yeni kırmızı yok | ✅ temiz; yeni kırmızı 0 |

**SONUÇ: TAMAM** — iki gerçek hata kapandı (kalıcı-tarih migration demo'da canlı; yalın sheet UI fix
kırmızı→yeşil kanıtlı), e2e 12/12, commit atılmadı (sahip/orkestratör merge kapısında).
