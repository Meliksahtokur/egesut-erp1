# SPEC S2 — Sessiz sınıflandırma: eşik 55→50, kapsam Boş+bilinmeyen, Bekliyor ≥40g gebelik muayenesi + izole vurgulu liste (M3)

- **Tarih:** 2026-09-24 · **Dal:** `ovysch-feature-cila-turu` · **Tur:** 2 (Adım 2, sentez §3)
- **Girdiler:** `reports/plans/ovsync-cila-plan-4.md` (sahip emirleri + skeptik revizyon), `reports/plans/ovsync-cila-sentez.md` (§3 sıra, §5A sınıflandırma kuralı, §9 karar tablosu), canlı kod + canlı demo DB.
- **Uygulayıcı yazma zarfı:** yalnız §4'teki dosyalar. Prod'a push/merge YASAK; migration yalnız DEMO'ya uygulanır (sahip onayı var — 2026-09-24 "demo dbye yazılabilir").
- **Kanıt etiketleri:** CONFIRMED (dosya:satır) / OBSERVED (canlı komut-sorgu, bu oturum) / INFERRED / UNKNOWN.

---

## 1. Amaç

Sahibin sınıflandırma kuralını (sentez §5A, BAĞLAYICI) DB'yi tek-otorite yaparak üçe ayırmak:

| Sınıf | Kural | Yüzey |
|---|---|---|
| **Gebelik muayenesi** | Son tohumlama `sonuc='Bekliyor'` ve üzerinden **≥ 40 gün** geçti (eşik `protokol_ayar`) | `🔬 Gebelik Muayenesi Bekleyenler` izole vurgulu band (dashboard, sessiz bandının HEMEN ÜSTÜ) + sheet'in en üstünde ayrı bölüm + `GEBELIK_KONTROL` görevi |
| **Sessiz** | Kapsam **yalnız "Boş" + "durumu bilinmeyen"**; eşik **50 gün** (55'ten çekildi) | Mevcut `❗ Sessiz Hayvanlar` band/sheet/istatistik — ama artık hiçbir Bekliyor hayvan içermeyecek |
| **Diğer** | Bekliyor <40g, gebe, kısır, aktif-vs | Hiçbir listede yok |

Sahibin kararları (bağlayıcı, sentez §9 S5/S8): sessiz eşiği **50**; kapsam **yalnız Boş+durumu-bilinmeyen**; Bekliyor ≥40g → **gebelik muayenesi görevi**, listede **en üstte, izole, emoji 🔬**; otomatik görev üretimi **EVET** (S2 kararı).

## 2. Kanıtlı zemin (bu spec yazılırken yeniden doğrulandı)

| # | Bulgu | Kanıt |
|---|---|---|
| Z1 | `v_eligible` güncel tanım: yalnız `sonuc='Gebe'` hariç tutulur (L34), eşik sabiti 55 (L35), `durum='Aktif'` (L31), düve 13ay fallback `GREATEST` dahil | CONFIRMED `supabase/migrations/20260831000002_duve_sessiz_13ay.sql:L31-35` |
| Z2 | Sessiz eşiği 55 DÖRT canlı noktada gömülü: `v_eligible` L35; `sessiz_hayvanlar_listele` `p_min_gun DEFAULT 55` (son tanım yalnız bu dosyada); `sessiz_hayvanlar_reconcile` üret L19 + guard L52; `stat_suru_ozet` L24 | CONFIRMED `20260531400000_sessiz_hayvan_yas_filtresi.sql:L44`, `20260625000020_sessiz_reconcile.sql:L19/L52`, `20260625000030_stat_suru_ozet_readonly.sql:L24` (her fonksiyonun SON tanımı bu dosyalardadır — grep ile teyit) |
| Z3 | `sessiz_hayvanlar_gorev_olustur` 20260625000020'den beri ince wrapper — eşik sabiti YOK, değişmez | CONFIRMED `20260625000020:L61-71` |
| Z4 | Reconcile cron `sessiz-reconcile-daily` `0 5 * * *` | CONFIRMED `20260625000020:L80` |
| Z5 | `v_eligible`'ın TÜM tüketicileri: listele, reconcile, stat_suru_ozet (js/tests sıfır doğrudan referans; 20260831000003'teki geçiş yalnız YORUM) | CONFIRMED grep + `js/ui.js` (RPC üzerinden 2 çağrı: L398, L1689) |
| Z6 | UI noktaları: `_dashBands` imza L270 (L411 çağrı), sessiz band L312-317, `_sessizGrupla` L1673 (saf, unit testli), `_showSessizList` L1687 (alt-metin "55+ gündür" L1701), stat bölümü L2683 ("55+ gündür"), `muayene:['MUAYENE','GEBELIK_KONTROL','VETERINER_KONTROL']` L55 | CONFIRMED `js/ui.js` |
| Z7 | `protokol_ayar` + `_ayar(anahtar, varsayilan)` helper; seed deseni | CONFIRMED `20260620000001_protokol_ayar.sql:L18-34` |
| Z8 | Canlı demo `protokol_ayar`: 10 satır, sessiz anahtarı YOK | OBSERVED (tools-bank sorgusu) |
| Z9 | Canlı demo `sessiz_hayvanlar_listele({})`: 11 kayıt, min 56 (173, 186), 9999×2 (906, 2044) → eşik 55 çalışıyor | OBSERVED (demo REST, authenticated) |
| Z10 | 173: son tohumlama 2026-07-30 `Bekliyor` (`ce96ca6d`), açık `VETERINER_KONTROL "Sessiz hayvan: 56 gündür"` (`e341a0a9`, kaynak `SESSIZ-<id>`) — plan-4 S4'ün "kapanmıştı" notundan SONRA reconcile tarafından YENİDEN üretilmiş; 186 ve 168'de de açık SESSIZ görevleri var → canlı cron aktif | OBSERVED (demo REST) · cron aktifliği INFERRED (görev yeniden üretimi) |
| Z11 | Canlı demo `stat_suru_ozet` `sessiz=9` ↔ listele 11: stat `COALESCE`'sız `e.sessiz_gun >= 55` NULL satırları (hiç-kayıt-yok) saymıyor — MEVCUT tutarsızlık | OBSERVED + CONFIRMED `20260625000030:L24` |
| Z12 | 173'ün 21./35. gün GEBELIK_KONTROL'leri TAMAMLANMIŞ ama sonuc hâlâ Bekliyor; demo'da 45 açık GEBELIK_KONTROL var (21/35 gün deseni, `ref_tohumlama_id` NULL üretiliyor) | OBSERVED (demo REST) + CONFIRMED `20260531200000_faz_b_vwp_enforcement.sql:L101-108` (INSERT kolon listesinde ref_tohumlama_id yok) |
| Z13 | Canlı demo'da Bekliyor ≥40g tohumlaması olan ~7 hayvan (kaba ölçüm, son-tohumlama filtresi olmadan) → muayene popülasyonu ~3-7 | OBSERVED (demo REST) |
| Z14 | ACL disiplini: genel kalkan `REVOKE ALL ON ALL FUNCTIONS IN SCHEMA public FROM anon, PUBLIC` + default privilege kapanışı; yeni migration anon GRANT yazmaz | CONFIRMED `20260915000001_anon_execute_geri_al.sql` (kapanış bloğu) + `20260924000001:L47-48/L500-501` deseni |
| Z15 | MK3 gebelik otoritesi `tohumlama.sonuc`'u doğrudan okur (v_eligible kullanmaz) → bu spec MK3'ü etkilemez | CONFIRMED `20260924000001_ovsync_pg_r32_acik_disi.sql:L258-265` |
| Z16 | `?v=` damgası tek değer (`20260924-01`), js değişiminde güncellenir | CONFIRMED `index.html:L2325-2335` |

## 3. Tasarım kararları

**D1 — `v_eligible`'da Bekliyor TAM hariç (plan-4 M3 pencere-formundan bilinçli sadeleştirme).**
Plan-4 M3 taslağı pencere-formundaydı (`NOT EXISTS (... sonuc='Bekliyor' AND t.tarih > CURRENT_DATE - 40)`). Bu spec **koşulsuz hariç tutmayı** seçer (`NOT EXISTS (... sonuc='Bekliyor')`) çünkü:
1. Pencere-formda Bekliyor ≥50g hayvan sessiz havuzuna GERİ girer → stat sayacı onları sessiz sayar, gece reconcile'u onlara "Sessiz hayvan" görevi açar (Z10'daki 173 vakası üretmeye devam eder) — sahibin "Bekliyor ≥40g → gebelik muayenesi görevi, sessiz listesinde asıl grupta yok" kuralını DB katmanında kırar, reconcile'a ek yama gerektirir.
2. Pencere-formda 41-50 gündeki Bekliyor ne sessizdir ne listede görünür; muayene akışı zaten `tohumlama`'dan doğrudan okumak ZORUNDA kalır (yeni RPC şart) — o zaman `v_eligible`'daki pencereye gerek kalmaz.
3. Koşulsuz hariç, sahibin kapsam cümlesinin ("sessiz kapsam yalnız Boş+durumu bilinmeyen") birebir DB karşılığıdır ve dört tüketiciyi tek satırla birlikte doğruya çevirir (plan-4'ün kendi Seçenek-1 gerekçesi). 40 günlük eşik `protokol_ayar`'da muayene RPC'sinde yaşar (D3).
*Sapma sahibe raporlanır; ayrı onay gerektirmez (kuralın doğrudan uygulaması). Kabul testi A3/A5 bunu kanıtlar.*

**D2 — Eşik mekânı: SEÇENEK A (view-gömülü sabit 50, dört nokta birlikte).** Sentez §9-11'de sahip "ikisi de olabilir" dedi; plan-4 M1 (A) ile yazıldı → bu spec (A) ile devam eder. (B) seçilirse delta §9'da.
Dört nokta (Z2): `v_eligible` L35 → 50; `listele` default → 50; `reconcile` L19 + L52 → 50; `stat_suru_ozet` L24 → 50. **`listele` imzası `(text, integer)` AYNEN korunur** (default değişimi overload yaratmaz — Z2).

**D3 — Muayene veri kaynağı = iki YENİ RPC.** `gebelik_muayene_listele()` (band/sheet verisi) ve `gebelik_muayene_gorev_uret(p_dry_run boolean DEFAULT true)` (görev üretimi, dry-run varsayılan — S9 "dry-run liste onaylı koşum" kararı). İkisi de `tohumlama`'dan doğrudan okur: son-tohumlama-tipli Bekliyor + `tarih <= CURRENT_DATE - _ayar('sessiz_tohumlama_muafiyet_gun', 40)::int` + Aktif dişi + kısır-değil. Dedup `kaynak='GEBELIK-KONTROL-<tohumlama_id>'` (reconcile'un `SESSIZ-<id>` deseni; `ref_tohumlama_id` kolonu da doldurulur — Z12'de 21/35 gün görevlerinin bu kolonu boş bıraktığı görüldü, bu yüzden dedup kolon değil kaynak-üzerinden). Kullanıcı-tamamlama cooldown'u 30 gün (reconcile deseni) — Z12'deki "tamamlanmış ama sonuc güncellenmemiş" vakasında ping-pongu önler. Açık GEBELIK_KONTROL varsa üretim yok.

**D4 — Cron `gebelik-muayene-daily` `10 5 * * *`** (reconcile 05:00'ten sonra: önce bayat SESSIZ kapanır, sonra muayene görevi üretilir). pg_cron-koruyan DO bloğu ile (doğrulama baseline'ında pg_cron yok — §6).

**D5 — `stat_suru_ozet` sentinel hizalaması:** `e.sessiz_gun >= 55` → `COALESCE(e.sessiz_gun, 9999) >= 50`. Canlıda bugün listele 11 ↔ stat 9 tutarsızlığı var (Z11); aynı satır zaten değiştiği için hizalama bu zarftadır ve T1-(e) testini geçilebilir kılar.

**D6 — ACL:** üç değişen fonksiyon + iki yeni fonksiyon için `REVOKE ... FROM PUBLIC, anon` + `GRANT ... TO authenticated, service_role`; `_uret` authenticated'a kapalı (yalnız cron+service_role; dry-run raporu psql/MCP service_role bağlamından alınır) — Z14.

**D7 — UI:** `_dashBands` imzasına 16. parametre `muayeneList`; sessiz bandından HEMEN ÖNCE `🔬 Gebelik Muayenesi Bekleyenler (N)` kırmızı band (satır: kupe + "N. gün Bekliyor" + `openDet`); `_showSessizList` sheet'inde en üstte ayrı `🔬` bölümü (sayaçlı), altında mevcut gruplar; `_sessizGrupla` İMZASI DEĞİŞMEZ (9999-en-altta kuralı korunur, mevcut unit testler bozulmaz); iki "55+ gündür" metni "50+ gündür" olur.

## 4. Dokunulacak dosyalar — TAM liste (tek-yazıcı zarfı)

| # | Dosya | İşlem | Noktalar |
|---|---|---|---|
| 1 | `docs/plans/2026-09-24-ovsync-cila/taslak-s2-migration.sql` | VAR (bu spec ile teslim) | Doğrulanmış migration taslağı — final migration'ın byte-bazlı kaynağı |
| 2 | `supabase/migrations/20260925000001_sessiz_siniflandirma.sql` | **YENİ** | İçerik = (1) dosyası. Uygulamadan ÖNCE `scripts/db-validate.sh` final koşumu ZORUNLU (db-validation kapısı) |
| 3 | `js/ui.js` | DÜZENLE | (a) L270 `_dashBands` imzası sonuna `muayeneList` parametresi; (b) L411 çağrıya `muayeneList` geçişi; (c) L397-398 yanına `muayeneList` fetch'i (`rpc('gebelik_muayene_listele',{})`, try/catch aynı desen); (d) L312 `if((sessizList||[]).length){` bloğunun HEMEN ÖNCESİNE muayene bandı; (e) L1687-1707 `_showSessizList`: ikinci rpc fetch + sheet üstünde `🔬` bölümü + L1701 alt-metin "55+ gündür"→"50+ gündür"; (f) L2683 "55+ gündür"→"50+ gündür" |
| 4 | `index.html` | DÜZENLE | `?v=` damgası tek değer yükseltme (ör. `20260925-01`) — ui.js değiştiği için zorunlu (Z16) |
| 5 | `tests/unit/ui-pure.test.js` | DÜZENLE | `_sessizGrupla` regresyon testleri AYNEN kalır; §7-B2 maddeleri için yeni saf-test blokları (muayene sıralaması yardımcısı eklenirse) |
| 6 | `BUGS.md` / borç kaydı | DÜZENLE | §9-B'deki kapı-aracı borçları (baseline PK eksikliği, C2 seeder hatası) kayda alınır |

**Dokunulmaz (bu spec kapsamında YASAK):** `js/api.js`, `js/forms.js`, `js/state.js`, `js/config.js`, `supabase/migrations/` altındaki mevcut dosyalar, `tohumlama_kaydet`/MK3/ovsync zincir fonksiyonları, 188 çift zinciri (KASITLI), kısır zincir temizliği (Adım 3'ün işi), T9/erteleme-geneli (BORÇ — bu turda fix yok).

## 5. Migration / RPC taslağı (SQL gövde seviyesi)

Tam gövde: **`docs/plans/2026-09-24-ovsync-cila/taslak-s2-migration.sql`** (§6'daki kapı + fonksiyonel testlerden geçmiş byte'lar). Yapı:

1. `SET LOCAL lock_timeout/statement_timeout` (squawk hijyeni)
2. `protokol_ayar` seed: `sessiz_tohumlama_muafiyet_gun = 40` (min 0, max 120) — **PK-bağımsız idempotent desen** (UPDATE-önce / INSERT-eksikse; gerekçe §6)
3. `v_eligible` CREATE OR REPLACE — **baz = güncel canlı tanım (`20260831000002:L4-35`, baz-tanım kuralı; `20260531400000` gövdesi BAZ ALINMAZ)** + iki delta:
   ```sql
   AND NOT EXISTS (SELECT 1 FROM tohumlama t WHERE t.hayvan_id = h.id AND t.sonuc = 'Bekliyor'::text)  -- D1
   AND (son_event.tarih IS NULL OR son_event.tarih < (CURRENT_DATE - 50))                              -- D2
   ```
4. `sessiz_hayvanlar_listele(text, integer DEFAULT 50)` — gövde değişmez, yalnız default
5. `sessiz_hayvanlar_reconcile()` — gövde birebir, iki sabit 55→50 (üret + guard)
6. `stat_suru_ozet(text, boolean)` — gövde birebir, tek satır delta: `'sessiz', (... AND COALESCE(e.sessiz_gun, 9999) >= 50)` (D5)
7. `gebelik_muayene_listele()` — YENİ; döndürdüğü alanlar: `hayvan_id, kupe_no, grup, padok, tohumlama_id, son_tohumlama_tarihi, bekliyor_gun, acik_gorev_var`; sıralama `bekliyor_gun DESC`
8. `gebelik_muayene_gorev_uret(p_dry_run boolean DEFAULT true)` — YENİ; döndürür `{dry_run, esik_gun, adet, uretilen, liste[], zaman}`; üretim koşulları: son-tohumlama Bekliyor + ≥eşik + Aktif dişi + kısır-değil + açık GK yok + 30g kaynak-esleşmeli cooldown yok; INSERT `gorev_log(gorev_tipi='GEBELIK_KONTROL', aciklama=format('🔬 Gebelik muayenesi: %s. gün Bekliyor (%s)', ...), hedef_tarih=CURRENT_DATE, kaynak='GEBELIK-KONTROL-'||tohumlama_id, ref_tohumlama_id=tohumlama_id)`
9. ACL bloğu (D6)
10. `cron.schedule('gebelik-muayene-daily','10 5 * * *','SELECT public.gebelik_muayene_gorev_uret(false)')` — pg_cron-koruyan DO bloğu (D4)

Kritik gövde detayı (fonksiyonel testte yakalanan): `_ayar` `numeric` döndürür, `date - numeric` GEÇERSİZDİR → eşik okuma her yerde `::int` cast'li:
```sql
AND t.tarih <= CURRENT_DATE - public._ayar('sessiz_tohumlama_muafiyet_gun', 40)::int
```

## 6. db-validation kapısı sonucu + fonksiyonel test kanıtı

**Kapı koşumları** (taslak üzerinde — kapı kuralı: yazmadan önce taslakta koşulur):
- Rapor: `~/egesut-erp1/reports/db-validation-e3025b23.md` (son koşum, bugünün byte'ları). Önceki: `5c03f108`, `73d7ec2f` (iterasyonlar).
- Sonuç: **A PASS (sqlfluff + squawk 0 ihlal) · C1 TAM PASS** (baseline parite uyumlu+taze; apply hatasız; tüm nesneler oluştu; RLS farkı yok). **Genel: INCONCLUSIVE** — yalnızca:
  - `B.sema-uyum` INCONCLUSIVE: statik çözümleyici CTE/lateral/CTE-alias'larını çözemiyor ("C1'e bırakıldı" — C1 PASS) — tasarım gereği engel değil.
  - `C2` INCONCLUSIVE: kapının sentetik seeder'ı text-PK tablolarda bozuk SQL üretiyor (`INSERT ... VALUES ()` syntax error). **Aracı borç** — §9-B. Boşluğu §6-altındaki manuel fonksiyonel testler kapladı (C2'nin amacı olan unique/FK/NOT-NULL kanıtı: seed INSERT'leri temiz geçti, RPC'ler çalıştı).
- İlk koşumda yakalanan ve düzeltilen İKİ gerçek hata: (1) `ON CONFLICT (anahtar)` baseline'da PK olmadığından patlıyor → PK-bağımsız desene geçildi; (2) `cron.job` baseline'da yok → pg_cron-koruyan blok. + (3) `date - numeric` hatası fonksiyonel testte yakalandı.

**Fonksiyonel testler** (izole baseline DB `egesut_val_tmp`, 10 sentetik hayvan + tohumlama/görev verisi; hepsi PASS):

| Test | İddia | Sonuç |
|---|---|---|
| T-a | `sessiz_hayvanlar_listele()` = yalnız Boş(60,52)+hiç-kayıt; **sıfır Bekliyor** | PASS |
| T-b | `stat_suru_ozet` sessiz = listele adeti (3=3, sentinel hizalı) | PASS |
| T-c | `gebelik_muayene_listele()`: 70/56/45g Bekliyor'lar; 20g muafiyet-İÇİNDEKİ yok; `acik_gorev_var` doğru | PASS |
| T-d | `_uret(true)`: `uretilen=0`, liste/adet doğru, `esik_gun=40` | PASS |
| T-e | `_uret(false)`: görev üretilir; `kaynak='GEBELIK-KONTROL-'||tohumlama_id` ve `ref_tohumlama_id` eşleşme true | PASS |
| T-f | İkinci `_uret(false)` → `uretilen=0` (idempotens) | PASS |
| T-g | `reconcile`: bayat SESSIZ görevi (173-senaryosu) `iptal=true, kapatan_ref='sessiz-noteligible'` ile kapanır; yeni SESSIZ yalnız gerçek sessizlere | PASS |
| T-h | İkinci `reconcile` → 0/0 | PASS |
| T-i | 45g Boş hayvan 50 eşiğinde listede YOK | PASS |
| T-j | `protokol_ayar` eşiği 40→50 değişince liste anında daralır (config canlı etkili) | PASS |
| T-k | Sessiz listesinde 4 Bekliyor hayvanın tamamı artık yok | PASS |
| T-l/m | Cooldown: taze tamamlama üretimi engeller (0); 31 gün sonra yeniden üretir (1) | PASS |

## 7. Kabul testleri (implementer demo apply sonrası işaretler; ölçülebilir)

**A — DB katmanı (demo, service_role bağlantı):**
1. `sessiz_hayvanlar_listele({})` çıktısında `sonuc='Bekliyor'` son-tohumlamalı SIFIR hayvan; 173 (548df203) listede YOK. (Adet + ID ile raporlanır.)
2. `gebelik_muayene_listele()` 173'ü İÇERİR (`bekliyor_gun ≈ 57`), 40 günden genç Bekliyor'lar YOK; her satırda `acik_gorev_var` doğru.
3. `gebelik_muayene_gorev_uret(true)` dry-run listesi teslim paketinde sahibe sunulur (adet + kupe listesi).
4. `reconcile` sonrası 173/186/168'in açık `SESSIZ-*` görevleri `iptal=true, kapatan_ref='sessiz-noteligible'`; `gorev_log`'da Bekliyor-hayvana açık SESSIZ görev kalmamış.
5. `stat_suru_ozet()->'hayvan'->>'sessiz'` = `jsonb_array_length(sessiz_hayvanlar_listele())` (eşitlik zorunlu — D5).
6. Dört tüketici tutarlılığı: `v_eligible`'da `EXISTS (sonuc='Bekliyor')` satır sayısı = 0 (doğrudan SQL sayımı).
7. Cron: `SELECT * FROM cron.job WHERE jobname='gebelik-muayene-daily'` 1 satır, schedule `10 5 * * *`; ertesi sabah koşumunda `_uret` görevleri görünür ve dry-run listesiyle tutarlı.
8. ACL: `has_function_privilege('anon', 'public.gebelik_muayene_gorev_uret(boolean)', 'EXECUTE') = false`, `authenticated = true` (listele için de).

**B — UI katmanı (unit + sahibin browser yürüyüşü):**
1. `node --test tests/unit/` yeşil; `_sessizGrupla` mevcut testleri hiç bozulmadan geçer.
2. Yeni saf-test: muayene listesi `bekliyor_gun DESC` sıralı; 9999/boş liste kenarları tanımlı davranır.
3. (Sahip yürüyüşü — Plan 5 §3'e ek madde) Dashboard'da `🔬 Gebelik Muayenesi Bekleyenler (N)` bandı `❗ Sessiz Hayvanlar` bandının TAM ÜSTÜNDE, kırmızı vurgulu; N = DB listele adedi; satırlar "N. gün Bekliyor" metinli.
4. (Sahip) Sheet'te muayene bölümü en üstte ayrı başlıkla; altındaki gruplar "50+ gündür" alt-metniyle; "Hiç kayıt yok" en altta (bb4ea92 kuralı korunur).
5. (Sahip) Stat kartında sessiz bölüm alt-metni "50+ gündür tohumlama/kızgınlık kaydı yok".

**C — Süreç kapıları (implementer):**
1. Final migration dosyasına `scripts/db-validate.sh` (C1 PASS zorunlu; INCONCLUSIVE yalnız §6'daki bilinen araç borçlarından gelebilir, rapor linkiyle teslime eklenir).
2. `ui.js` değişimi öncesi LSP findReferences/impact (tarama: `_dashBands` 2 referans, `_showSessizList` 2 referans — bu spec yazılırken OBSERVED); `code-change-precheck` skill'i.
3. Commit'ler yalnız `ovysch-feature-cila-turu` dalına, her anlamlı adımdan sonra; `gitnexus detect_changes` commit öncesi.
4. **Son review kapısı:** iş bitiminde ayrı bir review koşumu (sahibin isteği) — diff bu §4 zarfıyla karşılaştırılır; zarf-dışı dosya = RED.

## 8. Uygulama sırası (tek seans)

1. Migration'ı (1)→(2) kopyala, db-validate final koş (C1 PASS) → commit.
2. DEMO'ya apply (psql; demo dışarıdan psql ile — kanal kaydı teslim notuna). → commit (yalnız migration dosyası).
3. Demo doğrulama seti §7-A 1-8 koş, çıktılar `reports/`'a (teslim kanıtı). Dry-run listesi sahibe.
4. `ui.js` + `index.html` + unit testler → `node --test tests/unit/` → commit.
5. Lokal smoke: `?demo` ile aç, dashboard bantlarını gör (ajan koşmazsa sahibin yürüyüşü için checklist §7-B3-5).
6. `gitnexus detect_changes` + BUGS.md borç kaydı + teslim özeti (öncesi/sonrası sayaç raporu: sessiz 11→beklenen, muayene ~3-7).

## 9. Geri-dönüş planı

**Prensip:** yeni nesneler DROP; dört değişen nesne, migration geçmişindeki değişmez dosyalardaki gövdelerin yeniden CREATE OR REPLACE'i (history immutable — dosya:satır referansları kesindir). Aşağıdaki SQL `supabase/migrations/20260925000002_sessiz_siniflandirma_geri_al.sql` olarak yazılır ve SADECE demo'da, sahip onayıyla koşulur:

```sql
BEGIN;
SET LOCAL lock_timeout = '5s';
-- 1) cron ve yeni fonksiyonlar
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_extension WHERE extname='pg_cron') THEN
    PERFORM cron.unschedule('gebelik-muayene-daily');
  END IF;
END $$;
DROP FUNCTION IF EXISTS public.gebelik_muayene_gorev_uret(boolean);
DROP FUNCTION IF EXISTS public.gebelik_muayene_listele();
-- 2) üretilmiş muayene görevleri (karar: veri kaybı değil, görev iptali)
UPDATE gorev_log SET iptal=true, kapatan_ref='s2-geri-al'
 WHERE gorev_tipi='GEBELIK_KONTROL' AND kaynak LIKE 'GEBELIK-KONTROL-%' AND tamamlandi=false;
-- 3) seed geri
DELETE FROM protokol_ayar WHERE anahtar='sessiz_tohumlama_muafiyet_gun';
-- 4) dört değişen nesne → önceki tanımlar (birebir, 55'li halleri):
--    v_eligible                = 20260831000002_duve_sessiz_13ay.sql:L4-35
--    sessiz_hayvanlar_listele  = 20260531400000_sessiz_hayvan_yas_filtresi.sql:L42-54 (default 55)
--    sessiz_hayvanlar_reconcile= 20260625000020_sessiz_reconcile.sql:L5-58 (L19/L52: 55)
--    stat_suru_ozet            = 20260625000030_stat_suru_ozet_readonly.sql:L4-136 (L24: >= 55, COALESCE'siz)
--    (GÖVDELER O DOSYALARDAN aynen alınır; eski dosyalardaki "GRANT ... TO anon" satırları
--     KOPYALANMAZ — ACL bugünkü disiplinde kalır: authenticated+service_role.)
NOTIFY pgrst, 'reload schema';
COMMIT;
```

UI geri dönüşü: `git revert <ui-commit>` (+ `?v=` damgası yeniden). Data: `GEBELIK_KONTROL` görevleri silinmez, iptal işaretlenir (audit izi korunur). Demo'dan sonra prod'a asla otomatik: prod taşıma ayrı sahip kapısı.

## 10. Varsayımlar ve açık noktalar

- **INFERRED:** canlı demo'da pg_cron aktif (Z10 — reconcile görevlerinin plan-4 yazımından sonra yeniden üretilmesi). Kapı apply'ı cron.schedule'ı canlıda çalıştırır; T-A7 ile doğrulanır.
- **UNKNOWN:** canlı demo/prod'daki `protokol_ayar_pkey` bu oturumda doğrudan okunamadı (REST pg_catalog vermez); canlı-PK kanıtı `20260923000002_ovsync_pg_sema.sql:L60` ("canlı pg_constraint: protokol_ayar_pkey", 2026-09-23 okuması). Taslak bu yüzden PK-bağımsız yazıldı — her iki dünyada da geçerli.
- **UNKNOWN:** canlı fonksiyon gövdelerinin migration geçmişiyle birebirliği tam metin olarak okunamadı (aynı kanal sınırlı); DAVRANIŞSAL teyit yapıldı (Z9-Z11). Implementer psql/SQL-mirastan `pg_get_functiondef` ile apply öncesi üç fonksiyonu diff'ler; sapma varsa gövdeyi CANLI baz alır ve delta'yı yeniden uygular.
- **AÇIK (kapsam dışı, sahip sorusu):** "Hiç kayıt yok" (9999) alt-grup görüntüsü (sentez açık-soru 6) — bu spec yalnız 50-eşikli stat hizalamasını yapar, gruplama değişmez.
- **AÇIK (kapsam dışı):** ovsync-AKTİF vaka sürgününün view'a geri getirilmemesi (plan-4 M1 baz-tanım kuralı; sahibin "ovsync'te olanlar" cümlesinin yorumu ayrı soru — sentez açık-soru 7 ile bağlaşık).
- **Emoji:** 🔬 sabit (bağlayıcı kural metninde geçiyor).

## 11. ENGEL / riskler (çözülemeyen yok; borçlar kayıtlı)

- **ENGEL değil, BORÇ (kapı aracı):** db-validate baseline'ı (a) PK/unique'ları yeniden kurmuyor (ON CONFLICT ilk koşumu kırdı), (b) pg_cron yok, (c) C2 seeder text-PK tablolarda bozuk SQL üretiyor. Üçü de taslakta deseni değiştirerek aşıldı; `BUGS.md`/borç kaydına işlenmelidir (§4-6).
- **RISK (düşük):** 50'ye düşüş liste kümesini büyütür (5 gün erken giriş). Bugün 50-54 bandında hayvan yok (OBSERVED: p_min_gun=50 → hâlâ 11); ilk cron sonrası fark dry-run raporuyla izlenir (plan-4 T1-(f)).
- **RISK (düşük):** stat hizalaması sessiz sayısını 9→11'e çıkarır (davranış değişimi, sahibe öncesi/sonrası raporlanır — D5 gerekçesiyle bilinçli).
- **gitnexus indeksi** worktree'yi kapsamıyor (main@d6a41c0, 4 commit geri — OBSERVED); LSP yerinde çalıştı (§7-C2). Implementer yerel kural gereği iş sonrası `gitnexus analyze` koşar.
