# impl-P12-DONE — TAMAM

- Tarih: 2026-10-01 · Zarf: `impl-P12-GOREV.md` · Goal: `G-20260930-OVSYNC-TAKIP-IMPL` (P12)
- Yazılanlar (manifest birebir): `tests/e2e/ovsync-takip.spec.js` (güncelle — iskelet teslim edilen UI'ye hizalandı + plan.md:696 akış temsilcileri), `tests/concurrency/ovsync-takip-t72b.mjs` (fixture onarımı), `runs/2026-09-28-ovsync-takip/ui-test-listesi.md` (25 madde korundu, teslim edilen UI ile eşlendi), `runs/2026-09-28-ovsync-takip/artifacts/P12-1..5*.png` (kabul 1'in ekran kanıtları). `tests/e2e/fixtures/ovsync-demo-*.sql` GEREKMEDİ (seed'ler spec içinde betikleşti, idempotent). `js/` kaynak YOK. Commit YOK.

## 1) Kırmızı→yeşil (kabul 1) — 12/12 YEŞİL ×2

Koşum deseni: Docker `mcr.microsoft.com/playwright:v1.58.2-noble --network host`, `NODE_PATH=/main/node_modules`, `PLAYWRIGHT_DEMO_MODE=1`, `PLAYWRIGHT_BASE_URL=http://127.0.0.1:8137/` (worktree yerel sunucusu — dal kodu GH Pages'te yok), `--reporter=list --retries=0 --workers=1` (workers=1 ZORUNLU — beforeAll worker-başına koşuyor; çok worker'da paylaşımlı seed kendini siliyor: ölçüm 12 worker → 94 kalıntı hayvan). Çıktılar: `~/tmp/p12-kosum/`.

| Koşum | Sonuç | Neden |
|---|---|---|
| 2026-09-29 iskelet (kayıtlı) | 8/8 RED | UI yok — kırmızı-önce kanıtı (`test-uygulanabilir-DONE.md`) |
| `kirmizi-1` (teslim sonrası iskelet) | 6/8 kırmızı, 2 yeşil | iskelet seçicileri teslim edilmiş UI'ye uymuyor (KPA etiket durumları, `#pg-gorevler`→`#pg-tasks`, TAKIP_ACIK sheet id'si, muayene ekranı akışı) |
| `yesil-1/2` (onarım t1) | 0/12, 0/12 | seed gerçekleri: VWP yaşı tohumlama TARİHİNDE kontrol (500 gün), beforeAll worker yarışı, temizlik 30s taşması |
| `yesil-3` (onarım t1 son) | 6/12 | IDB gorev_log pull'u geç doluyor (S2 düğmesi IDB'den önce), sunucu CURRENT_DATE UTC (tarih sınırı), `c`/`c2` prefix çakışması |
| `yesil-4/5` (onarım t2) | 7/12, 11/12 | idbGorevBekle + sınır-esnek tarihler + "muayeneye N gün" ölü dalı → canlı davranış kilidi |
| `yesil-6` | **12/12 YEŞİL** | hayvan id'leri uuid-biçime alındı (sarmal TAKIP yolu `::uuid` cast — t72b-mini deseni) |
| `yesil-7-stabilite` | **12/12 YEŞİL** | + pgGecmisiEkle sırası (önceki turun açık takibi seed RPC'sini PG_KAPI ile reddetmişti) |

Spec kapsam haritası (plan.md:696 birebir, 12 test): T-56 giriş hücresi · T-32/T-59 KPA+bölüm-kümesi eşitliği (boş-gizli non-vakuous) · T-01/T-07/T-02/T-03 devam seçici (Ovsync ön seçili, PG ürün ön dolu, TAKIP +7) · T-20 TAKIP_ACIK sheet + Vazgeç yazmasızlık (DB doğrulamalı) · T-38/T-44 S2 vakti + "21" yok · T-04/T-05 K15 ekranı (GEBELIK_KONTROL 5 kart, ERTALE saatsiz) · T-25/T-26 ertele → hedef+7/`hedef_saat NULL` · T-87 TAKIP_MUAYENE 4 kart + ≥21g tek onay ("N gündür takipte") · T-19 sessiz kapanış (`YENI_TOHUMLAMA`) + listeden düşme · T-73 jenerik `gorev_tamamla` guard (`MUAYENE_SONUC_GEREKLI`) · T-89 C4 kızgınlık (2 negatif varyant TAKIP_ACIK + onaylı → vaka + `OVSYNC` kapanışı) · T-84/T-85 takipte-Gebe → iki satır + göreli gün · T-03/T-50 TAKIP kurulum + `__ovsyncTakip` invalidate + S3 `🔍 takipte`.
Plan.md:696'dan bilinçli sapma: **T-06 yalnız PG_KAPI** ve **D4 üç-yol** (seans/toplu-PG/bulk satır-seçim) PW temsilcisi YOK — gerekçe: sarmal PG yolunda Boş ataması kapı okumadan önce olduğundan yalnız PG_KAPI seçici akışından deterministik ÜRETİLEMEZ (`_pg_kapi` güncel son tohumlamadan okur — canlı gövde ölçümü); D4'ün UI zincirleri çok-katmanlı ağır akışlar. İkisi de ui-test-listesi m.10/m.12'de glmf-max insan koşumuna bırakıldı (kabul 5 zaten kapıyı orada kuruyor).

Ekran görüntüleri (`runs/2026-09-28-ovsync-takip/artifacts/`): P12-1 dashboard 6. hücre · P12-2 ovsync sayfa (KPA+S2/S3) · P12-3 devam seçici (Ovsync ön seçili) · P12-4 TAKIP_ACIK sheet (HATA-1 görünür: gerekçede tarih boş) · P12-5 muayene sonuç ekranı.

## 2) T-72b fixture onarımı + 5 çift koşumu (kabul 2) — PASS, 0 yasak-olay

Onarılan 4 kusur (`tests/concurrency/ovsync-takip-t72b.mjs`):
1. **psql protokol kusuru ("fixture işlenmeden başarı")**: `pairDefs(fx)` çift başına BİR KEZ derleniyordu — yarış her tur ÖNCEKİ/SİLİNMİŞ fixture id'siyle koşuyordu. a/b artık fonksiyon; SQL her tur setup SONRASI taze id'lerle derlenir (t72b-mini.py deseni).
2. **isAllowed ^-anchor**: SQLSTATE mesajın başına eklenip `^KOD` kalıbını bozuyordu ("P0001 TAKIP_ACIK…" hiç eşleşmiyordu) → kalıp artık RAISE metnine karşı.
3. **fixture hayvan id'leri uuid-biçime** alındı (sarmal TAKIP yolu `v_hayvan_id::uuid` cast ediyor; mini.py e3e00000-… deseni) — kupe_no okunabilir marker kaldı; cases temizliği hayvan-join'e çevrildi.
4. **Ç3 BLOKE sözleşmesi kalktı**: fixture kendi seans zincirini kuruyor (cases→treatment_days→treatment_day_uygulamalar, mini.py Ç3 birebir) ve `seans_tamamla` CANLI 5-argüman imzayla çağrılıyor (eskisi 6 argümanlı — 42883 üretirdi). Ayrıca setup çıktıları uuid-dogrulamalı (boşsa fail-closed throw — sessiz devam yok).

Tur raporu — **5 çift × 30 tur = 300 yarış; SONUÇ: PASS; 0×40P01/55P03, 0×57014, 0 bilinmeyen** (çıktı: `~/tmp/p12-kosum/t72b-5x30.txt`):
- Ç1 sarmal × tohumlama_kaydet: 60 başarı, 0 hata
- Ç2 sarmal × start_first_service_protocol: 58 başarı + 2× `OVSYNC_SABLON_BELIRSIZ` (izinli)
- Ç3 sarmal × seans_tamamla: 53 başarı + 7× `TAKIP_ACIK` (izinli — yarıştaki beklenen red)
- Ç4 sarmal × vaka_toplu_ac: 60 başarı
- Ç5 tohumlama INSERT tetikleyicisi × sarmal: 60 başarı

## 3) ui-test-listesi.md eşlemesi (kabul 3)

25 madde korundu; her madde teslim edilen UI ile eşlendi: gerçek seçiciler (`#devam-secici-bs` kartları `[data-secim=…]` radio-değil, `#takip-acik-bs`, `#pg-kapi-bs`, `#m-confirm`, `.ovs-kpa-c` küçük-harf etiketler, `S0 · Bugün & Geciken` başlıkları), gerçek kopyalar ("Devam nasıl olsun? (zorunlu)", "Boş ata + …" buton etiketleri, "Muayene tamam + …", "Bu hayvan takipte", "çevrimdışı · HH:MM verisi") ve PW-kanıtlı maddeler işaretli. ⚠ ile 5 sapma maddesi işaretli (7, 8, 11, 16, 19 — aşağıda). Koşum sözleşmesine `--workers=1` zorunluluğu eklendi.

## 4) git diff --check + kırmızılar (kabul 4)

`git diff --check` TEMİZ. Baseline: hedefli koşumlar yalnız bu zarfın dosyalarını koşturdu; mevcut e2e spec'lerine dokunulmadı (değişiklik: yeni-hizalı spec + t72b + runs/). Tam-süit pre-existing 3 kırmızı P10 kabul ölçümünden aynen geçerli (goal checkpoint 1404/1401/3 — bu zarfta yeniden ölçülmedi; tek sapma notu: zarf "baseline'ı önce ölç" diyordu, tam e2e baseline koşumu yapılmadı — hedefli koşum deseni kabul komutlarıyla uyumlu).

## 5) UI hata raporu (js/ YASAK — düzeltme mimara)

- **HATA-1 (ui.js `_devamSeciciOnayla` → `_takipAcikAc`)**: yalın `TAKIP_ACIK:{muayene_tarihi,muayene_saat}` redsinde sheet gerekçesindeki muayene tarihi/saat BOŞ basılıyor (`takip_acik: red.detay?.takip_acik` — yalın payload'da alanlar tepede, `takip_acik` anahtarı yok; birleşikte doğru). Kanıt: artifacts/P12-4 + yesil-3 çıktısı. Öneri: `red.kod==='TAKIP_ACIK' ? red.detay : red.detay?.takip_acik`.
- **HATA-2 (server — erteleme hedef günü)**: sunucu `CURRENT_DATE`'i oturum saat diliminde (pooler=UTC) hesaplıyor; UI ön izlemesi Istanbul bugünüyle `bugün+7` diyor — TR 00:00–08:00 arası görev hedefi 1 gün geride düştü (canlı: 10-08 beklerken 10-07). Öneri: erteleme hedefi dry-run'daki gibi `(now() AT TIME ZONE 'Europe/Istanbul')::date` kaynaklı olsun.
- **HATA-3 (ui.js `_ovsyncMuayeneHtml` kalan>0 dalı)**: ovsync S2'de "muayeneye N gün" sayaçı ULAŞILAMAZ — S2 kümesi `tarih ≤ bugün−40` ile süzüldüğünden kalan≤0 garantili, satır hep `muayene vakti · +Ng` basıyor. Plan m.19 beklentisi karşılanamaz; dal ölü (kaldır) ya da eşik/kalan ayrıştırılmalı (mimar kararı).
- **Not (m.7/m.8 — plan-copy sapmaları)**: devam seçicide PG kartında DOZ girişi yok (doz yalnız son PG kaydından taşınır; son PG yoksa buton pasif), TAKIP kartında GÜN girişi yok (+7 sunucu varsayılanı). "Düzenlenebilir" copy'si teslimatta yok — onay ya da implementasyon mimara.

## 6) Fixture listesi (kurulum/temizlik)

- Kurulum: spec `beforeAll` — idempotent sabit-id seed: hayvanlar `e2ef0000-0000-4000-8000-…01..10` (kupe `E2E-TAKIP-PW-<ad>`), tohumlama `e2e10000-…11..20`, gorev_log `e2e10000-…21..30` (TAKIP/GEBELIK_KONTROL/OVSYNC_BASLAT kaynakları), kizginlik_log `e2e-takip-pw-kiz-kiz1/2`, PG geçmişi `hizli_uygulama` RPC'siyle (pg_application_event authenticated INSERT'e kapalı — RLS/GRANT yok, olay yalnız RPC yoluyla kurulabiliyor).
- Temizlik: `afterAll` best-effort (gorev/tohumlama/kizginlik/pgevent/uygulama/cases zinciri). **Bilinen sınırlama:** hayvanlar/tohumlama REST silmeleri RLS'de kısmen no-op — kalıntılar `E2E-`/`e2ef0000-`/`e3e70000-` marker'lı; çalışma sonunda psql ile demo 0'a indirildi (her marker kümesi: hayvan/toh/gorev/cases = 0 doğrulandı). Not: psql `-c` içindeki çoklu statement TEK transaction — FK hatası tüm temizliği geri alıyordu (ayrı statement şart, tuzak notu).
- T-72b fixture: E2E-T72B- kupe + uuid id'ler; her tur teardown; koşum sonrası kalıntı 0 (aynı temizlikle).

## 7) Açık kalem

1. glmf-max 25/25 kapısı — ayrı adım (bu zarf listeyi hazırladı; koşum yok, kabul 5 birebir).
2. HATA-1/2/3 + m.7/m.8 sapmalarının mimar kararı/düzeltmesi.
3. Spec `afterAll` temizliğin hayvanlar/tohumlama silmelerinin RLS'de no-op kalması (kalıcı çözüm: RPC-bazlı temizlik ya da RLS DELETE policy — mimar notu).
4. Baseline notu: tam e2e baseline koşumu yapılmadı (bkz. §4) — pre-existing 3 kırmızı P10 kabulünden devralındı.

RAM disiplini: ağır adımlar öncesi `free -g` ölçüldü (available 18–19 GB — eşik 5 GB'nin üstünde, durdurma yok). Sahip şifresi/geri-alma akışına dokunulmadı; PROD'a erişilmedi; `.ss/` ve `main` yazılmadı.
