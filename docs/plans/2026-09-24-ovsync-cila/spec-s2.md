# SPEC S2 — Sessiz sınıflandırma: eşik 55→50, kapsam Boş+bilinmeyen, Bekliyor ≥40g gebelik muayenesi + izole vurgulu liste (M3)

> Spec sürümü: **1.1** (onarım turu revizyonu — bulgular F1-F8, bkz. §12) · Tarih: 2026-09-24
- **Tarih:** 2026-09-24 · **Dal:** `ovysch-feature-cila-turu` · **Tur:** 2 (Adım 2, sentez §3)
- **Revizyon:** v1.1 — 3. tur review onarımı (bulgu listesi orkestrasyona ulaşmadı: `BULGULAR: undefined` → tüm kanıt tablosu repo + canlı demo'dan TEK TEK yeniden doğrulandı; bulgu-işlem tablosu §12)
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

> **KANAL NOTU (onarım turu F7, bağlayıcı):** tools-bank `supabase_*` MCP kanalı **PROD**'a bağlıdır (ref `zqnexqbdfvbhlxzelzju` — CONFIRMED `~/tools-bank/mcp_server/server.py` + `js/api.js:23-24`; S1 fafdda1 + S5 R3/B3 ile aynı kural). Aşağıda "tools-bank sorgusu" etiketli OBSERVED satırları **PROD gözlemidir**; "demo REST" etiketlilerin kanalı bu onarımda doğrulanamadı. DEMO gerçek değerleri uygulamanın Adım 0'ında DEMO kanalından (`SUPABASE_DEMO_PAT` + Mgmt query endpoint / demo pooler psql; ref `vtzqjmazsvurxdeondmi`) ölçülür ve bu tablonun yerine geçer; sapma varsa kanıt zarfına yazılır.

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
| Z12 | 173'ün 21./35. gün GEBELIK_KONTROL'leri TAMAMLANMIŞ ama sonuc hâlâ Bekliyor (onarım turunda canlı yeniden teyit: her iki görev `tamamlandi=true`, `kaynak='TOH-ce96ca6d-…'` — Bekliyor tohumlamasının kendi id'si); 45 açık GEBELIK_KONTROL var (onarım turunda yeniden OBSERVED) (21/35 gün deseni, `ref_tohumlama_id` NULL üretiliyor) | OBSERVED (tools-bank kanalı = PROD, onarım turu 2026-09-24 — F7) + CONFIRMED `20260531200000_faz_b_vwp_enforcement.sql:L101-108` (INSERT kolon listesinde ref_tohumlama_id yok) |
| Z13 | Bekliyor ≥40g tohumlaması (tools-bank kanalı = **PROD**, F7): **kaba 5** (son-tohumlama filtresi olmadan), **son-tohumlama filtreli 3** — önizleme: 180 (91g), 173 (56g), 902 (54g) (2026-09-24 onarım turu ölçümü; sayı zamanla kayar, teslimde Adım 0 DEMO ölçümü esastır) | OBSERVED (tools-bank kanalı = PROD, onarım turu 2026-09-24) |
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

**D7 — UI:** `_dashBands` imzasına **15. parametre** `muayeneList` (mevcut imza 14 parametredir — `js/ui.js:270`, onarım turunda sayıldı: negStk…sutBuzagiHtml; v1.0'daki "16." işaretlemesi off-by-one idi, F1); sessiz bandından HEMEN ÖNCE `🔬 Gebelik Muayenesi Bekleyenler (N)` kırmızı band (satır: kupe + "N. gün Bekliyor" + `openDet`); `_showSessizList` sheet'inde en üstte ayrı `🔬` bölümü (sayaçlı), altında mevcut gruplar; `_sessizGrupla` İMZASI DEĞİŞMEZ (9999-en-altta kuralı korunur, mevcut unit testler bozulmaz); iki "55+ gündür" metni "50+ gündür" olur.

## 4. Dokunulacak dosyalar — TAM liste (tek-yazıcı zarfı)

| # | Dosya | İşlem | Noktalar |
|---|---|---|---|
| 1 | `docs/plans/2026-09-24-ovsync-cila/taslak-s2-migration.sql` | VAR (bu spec ile teslim) | Doğrulanmış migration taslağı — final migration'ın byte-bazlı kaynağı |
| 2 | `supabase/migrations/20260925000002_sessiz_siniflandirma.sql` | **YENİ** | İçerik = (1) dosyası. *(Numara düzeltmesi: plan-s2 sapma-1 — S1 `20260925000001_ovsync_kisir_blok`'u aldığından bu plan `…000002`'yi kullanır; `20260925000001` taslak adı bayat.)* Uygulamadan ÖNCE `scripts/db-validate.sh` final koşumu ZORUNLU (db-validation kapısı) |
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
1. `sessiz_hayvanlar_listele({})` çıktısında `sonuc='Bekliyor'` son-tohumlamalı SIFIR hayvan; 173 (548df203) listede YOK. (Adet + ID ile raporlanır; beklenen ≈ 8 — 180, 173 **ve Test inek 3** listeden çıkar: 180/173'ün son tohumlaması Bekliyor, Test3'ün ise ESKİ bir Bekliyor kaydı var → D1 any-Bekliyor'la düşer; 186/168 kalır — son tohumlamaları Doğum Yaptı, hiç Bekliyor kayıtları yok. PROD verisiyle projeksiyon F9; DEMO ölçümü Adım 0'da esastır.)
2. `gebelik_muayene_listele()` 173'ü İÇERİR (`bekliyor_gun ≈ 56` — 2026-07-30 tohumlamadan bugüne; v1.0'daki "≈ 57" sapması F3 ile düzeltildi), 40 günden genç Bekliyor'lar YOK; her satırda `acik_gorev_var` doğru. Beklenen küçük küme (PROD gözlemi — F7; DEMO ölçümü Adım 0'da): 180 (91g), 173 (56g), 902 (54g).
3. `gebelik_muayene_gorev_uret(true)` dry-run listesi teslim paketinde sahibe sunulur (adet + kupe listesi).
4. `reconcile` koşumu beklentileri (v1.0'daki "173/186/168 hepsi kapanır" beklentisi F10 ile düzeltildi — 186/168'in son tohumlaması Doğum Yaptı, Bekliyor kaydı yok → eligible kalırlar, görevleri AÇIK KALIR): **173'ün** açık `SESSIZ-*` görevi `iptal=true, kapatan_ref='sessiz-noteligible'` olur (ZORUNLU); 186/168'in açık görevleri `iptal=false` olarak KALIR (ZORUNLU — hâlâ 50+ sessizler); `gorev_log`'da (son-tohumlaması-)Bekliyor hayvana açık SESSIZ görev kalmaz (ZORUNLU 0). PROD verisiyle projeksiyon: `kapatilan=1, uretilen=0` (144/149/122/002'nin 30 gün içinde tamamlanmış SESSIZ görevi var → cooldown üretimi engeller — F10 kanıtı); DEMO ölçümü Adım 0'la karşılaştırılır.
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
6. `gitnexus detect_changes` + BUGS.md borç kaydı + teslim özeti (öncesi/sonrası sayaç raporu: sessiz 11→beklenen ≈8 — F9; muayene beklenen 3 — PROD gözlemi, DEMO'da Adım 0).

## 9. Geri-dönüş planı

**Prensip:** yeni nesneler DROP; dört değişen nesne, migration geçmişindeki değişmez dosyalardaki gövdelerin yeniden CREATE OR REPLACE'i (history immutable — dosya:satır referansları kesindir). Aşağıdaki SQL `supabase/migrations/<BOŞ-NUMARA>_sessiz_siniflandirma_geri_al.sql` olarak yazılır (numara koşum anında `ls supabase/migrations/` ile kullanılmayan en düşük `20260925NNNNNN` alınır — İLERİ migration `20260925000002`'yi kullandığından revert'e sabit numara ATANMAZ; plan-s2 rollback bölümüyle aynı kural) ve SADECE demo'da, sahip onayıyla koşulur:

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
- **RISK (düşük):** 50'ye düşüş liste kümesini büyütür (5 gün erken giriş). Bugün 50-54 bandında Bekliyor-olmayan hayvan görünmüyor (OBSERVED: p_min_gun=50 → hâlâ 11); D1 kalkanı sayesinde 50-54 bandındaki Bekliyor hayvanlar (ör. 902: 54g Bekliyor) sessiz listesine GİREMEZ — muayene listesine düşer (onarım turunda OBSERVED). İlk cron sonrası fark dry-run raporuyla izlenir (plan-4 T1-(f)).
- **RISK (düşük):** stat hizalaması sessiz sayısını 9→8'e çıkarırken (9999 ikilisi COALESCE ile sayılmaya başlar), eşik+D1 değişimi listeyi 11→≈8'e indirir (180+173+Test inek 3 çıkar — F9 projeksiyonu; 9999 ikilisi COALESCE ile sayılır) → net beklenen stat=listele≈8. Davranış değişimi, sahibe öncesi/sonrası raporlanır (D5 gerekçesiyle bilinçli).
- **gitnexus indeksi** worktree'yi kapsamıyor (main@d6a41c0, 4 commit geri — OBSERVED; onarım turunda 2026-09-24 yeniden doğrulandı: aynı durum). LSP yerinde çalıştı (§7-C2). **Uygulama kuralı (S4 onarım turuyla hizalı):** `gitnexus analyze` ana checkout yolunda koşarsa main dalını indeksler; implementer analyze'i bu worktree yolunda koşturmalı ki indeks dal ucunu alsın; iş sonrası analyze ZORUNLU (yerel kural).

## 12. Onarım turu bulguları (v1.0 → v1.1, 2026-09-24)

Reviewer onarım-öncesi turda FAIL verdi; bulgu listesi orkestrasyona ulaşmadı (BULGULAR: undefined) →
v1.0'ın TÜM kanıt satırları repo + canlı şemadan TEK TEK yeniden doğrulandı (bu turun canlı sorguları
tools-bank kanalından koşuldu — sonradan o kanalın PROD'a bağlı olduğu kesinleşti, F7; YAZMA yapılmadı:
salt-SELECT + readonly RPC + BEGIN/ROLLBACK probe). Sonuç: Z1-Z12, Z14-Z16, D1-D6, §5 taslak yapısı,
§6 rapor referansları (`e3025b23`, `5c03f108`, `73d7ec2f` — üçü de diskte mevcut) ve §7 kapıları DOĞRULANDI;
aşağıdaki on bulgu düzeltildi/işlendi (F9-F10 eşzamanlı ikinci onarım yazıcısından):

| # | Bulgu | Kanıt | Çözüm |
|---|---|---|---|
| F1 | "`_dashBands`'e 16. parametre" off-by-one — imzada **14 parametre** var (`negStk…sutBuzagiHtml`), `muayeneList` 15. olur | CONFIRMED `js/ui.js:270` (grep ile sayım) | D7 + plan 3b/3f "15. parametre" olarak düzeltildi |
| F2 | Plan 3f unit test 1-2, 15-parametreli fonksiyona **16 argüman** geçiriyordu; test 2'de liste verisi 16. pozisyonda DISCARD oluyor, `muayeneList=''` kalıyor → test KIRMIZI patlardı | CONFIRMED arg sayımı: `…,[],null,'', m` = 16 öğe | Test çağrıları 15 argümana indirildi (fazlalık `''` kaldırıldı); test 3 zaten 15 argümanla doğruydu |
| F3 | Z13 bayat + A2 bekleyen-gün sapması: canlıda bugün kaba 5 / son-tohumlama filtreli 3 (180:91g, 173:56g, 902:54g); 173 için `bekliyor_gun` bugün **56** (v1.0 "≈57" demişti) | OBSERVED demo SQL 2026-09-24 (`CURRENT_DATE - t.tarih`) | Z13, §7-A1/A2, plan Adım 0/2/5 beklenenleri güncellendi; sessiz liste için beklenen ≈9 eklendi (180+173 çıkar) |
| F4 | Plan Adım 1.4 grep beklentileri taslakla uyumsuzdu: `COALESCE(e.sessiz_gun, 9999) >= 50` gerçek **1** (beklenen "2" yazılmıştı — `listele` eşik-parametreli `>= p_min_gun`, sabit-50 COALESCE yalnız stat'ta); `'>= 50'` yorumu view'i sayıyordu ama view eşiği `< (CURRENT_DATE - 50)` kalıba uymuyor (gerçek 3 = reconcile 2 + stat 1) | CONFIRMED taslak grep koşumu (6/3/0/1/1) | Plan 1.4 yorum+beklenenleri gerçek değerlerle hizalandı; view için ayrı `grep -c 'CURRENT_DATE - 50'` kontrolü eklendi |
| F5 | Z8/Z9/Z10/Z11/Z12 canlı teyitleri tazelendi + tip-güvenlik kanıtı eklendi: `hayvanlar.id`/`tohumlama.hayvan_id`/`gorev_log.hayvan_id` TEXT, `tohumlama.id`/`gorev_log.id` UUID, `gorev_log.ref_tohumlama_id` TEXT; plan A1/A4 sorguları tip-güvenli | OBSERVED tools-bank kanalı = PROD (information_schema, 2026-09-24 — F7) | §2/§7'de kanıt etiketleri "onarım turunda yeniden OBSERVED" olarak tazelendi; tip haritası bu §12'de |
| F6 | gitnexus analyze yolu kuralı eksikti: ana checkout path'inde koşan analyze main'i indeksler, dal ucunu değil (S4 onarım turunun 0a kuralı bu plana işlenmemişti); indeks durumu yeniden OBSERVED (hâlâ `d6a41c0`/main) | OBSERVED `list_repos` 2026-09-24 | §11 + plan Adım 0.2/Adım 6'ya worktree-analyze kuralı işlendi |
| F7 | **KANAL:** tools-bank `supabase_*` kanalı **PROD**'a bağlı (ref `zqnexqbdfvbhlxzelzju`); v1.0'ın Z8-Z13 "canlı demo" etiketleri ve plan Adım 2.1'in "supabase_migrate demo'ya bakar → DEMO apply" emri **PROD-apply riski** taşıyordu — uygulanmış olsaydı migration PROD'a yazılacaktı. Bu onarım turunun kendi canlı sorguları da PROD'da koştu (salt-SELECT/readonly RPC/rollback probe — yazma yok) | CONFIRMED `~/tools-bank/mcp_server/server.py` + `js/api.js:23-24`; S1 fafdda1 (KANAL KURALI) + S5 onarim-r3.md B3 (fdw_prod_srv=0 + schema_migrations=124 prod imzası) ile bağımsız çapraz-teyit | SPEC §2'ye kanal notu; plana KANAL KURALI başlığı + Adım 0.4/2.1/2.2/A3/5.3 + sapma tablosu 2/10 yeniden yazıldı; DEMO kanalı: `SUPABASE_DEMO_REF=vtzqjmazsvurxdeondmi` + `SUPABASE_DEMO_PAT` Mgmt query endpoint / demo pooler psql |
| F8 | taslak `_uret` INSERT uuid→text: `pg_cast`'ta uuid→text satırı YOK; canlı PG 17.6 probe'unda assignment yine de kabul edildi (ASSIGN OK) — ancak sürüm-bağımsız güvenlik için eşzamanlı S2 kulvarı taslağa `v_rec.tohumlama_id::text` sertleştirmesi ekledi; bu, kod tabanının kendi deseniyle örtüşür (`20260522000004:L140-141` `v_toh.id::text`) | OBSERVED probe (PROD PG 17.6) + CONFIRMED `20260522000004_tekrar_asim.sql:L137-141` + taslak diff | taslak sertleştirmesi BENİMSENDİ (bu onarım taslağa dokunmadı — çakışma önleme); T-e PASS bu iki mekanizma ile tutarlı |
| F9 | Post-migration sessiz liste beklentisi ≈9 DEĞİL ≈8: F3 satırı yalnız 180+173'ün düşeceğini yazıyordu; **Test inek 3**'ün son tohumlaması Doğum Yaptı olsa da ESKİ bir `sonuc='Bekliyor'` kaydı VAR → D1 any-Bekliyor ile o da listeden düşer. Yeni-view mantığının birebir SQL kopyasıyla PROD projeksiyonu: kalan küme {2044, 906 (9999), 144, 149, 122, 002, 168, 186} = **8**; (kupe 31: yaş-fallback sessiz_gun=15 < 50 → girmez). stat=listele=8 beklenir | OBSERVED PROD SQL 2026-09-24 (per-hayvan son_sonuc/any_bekliyor dökümü + projection sorgusu) | §7-A1, §11 RISK, plan Adım 2-A1/Adım 5 "≈9"→"≈8" olarak düzeltildi |
| F10 | §7-A4/plan A4 reconcile beklentisi 186/168 için YANLIŞTI ("hepsi kapanır, ZORUNLU 0 satır" — kapı asla yeşile dönmezdi): 186/168'in son tohumlaması Doğum Yaptı, hiç Bekliyor kaydı yok → post-migration v_eligible'da KALIRLAR (sessiz_gun 56/60 ≥50) → görevleri açık kalır. Açık SESSIZ görev bugün yalnız 168/173/186'da (1'er); reconcile projeksiyonu: **kapatilan=1 (yalnız 173), uretilen=0** (144/149/122/002'nin 30 gün içinde tamamlanmış SESSIZ görevi var — cooldown engeller) | OBSERVED PROD SQL 2026-09-24 (son_sonuc dökümü + açık-görev sayımı + cooldown sayımı) | §7-A4 ve plan A4 beklentileri yeniden yazıldı: 173 kapanır (ZORUNLU), 186/168 açık kalır (ZORUNLU), bekliyorlu-açık-SESSIZ=0 (ZORUNLU) |

Onarım turu **kod değişikliği YAPMAZ** — yazma yetkisi yalnız bu dizindeki spec/plan dosyalarına aittir.
Eşzamanlı onarım yazıcılarıyla çakışma yoktur: bu tur yalnız `spec-s2.md` + `plan-s2.md`'ye dokunur.

## 13. Final review onarımı (v1.1 → v1.2, 2026-09-25 — onarım ajanı)

Final review bulgularının işlendiği tur; SAHİP ONAYLI üretim zarfı (Adım 1-5) bu turda uygulanır:

| # | Bulgular → işlenen |
|---|---|
| R1 | §9 revert dosya adına sabit `20260925000002` verilmişti; İLERİ migration aynı numarayı kullanır (plan-s2 Adım 1) → §9 `<BOŞ-NUMARA>` kuralına çevrildi (plan-s3 0d / plan-s5 `<BOŞ-NUMARA>` konvansiyonuyla uyumlu) |
| R2 | `gebelik_muayene_listele`, `_uret`:345-348'deki 30-gün tamamlanmış-cooldown filtresini taşımıyordu (final review DÜŞÜK bulgu) → taslağa AYNI `NOT EXISTS` bloğu eklendi (`kaynak='GEBELIK-KONTROL-' \|\| t.id`, `tamamlandi=true`, `tamamlanma_tarihi >= CURRENT_DATE - 30`); açık görev filtrelenmez (`acik_gorev_var` bayrağı ayrıştırır). §6 T-c kanıtı eski taslak üzerindedir; eklenen blok demo A2 koşumunda doğrudan doğrulanır (apply anında GEBELIK_KONTROL görevi hiç yoktur → filtre no-op, 173 listede kalır — beklenti değişmez) |
| R3 | db-validation kanıtı bayattı: doğrulanan taslak SHA `e3025b23…` ≠ commit'lenen taslak (`::text` fix'i doğrulama SONRASI) → Adım 1 final-db-validate kapısı CAYDIRICI değil BLOKER olarak uygulanır: C1 PASS olmadan apply YOK; rapor final dosyanın SHA'sını taşır |
| R4 | DEMO canlı şema kanalı önceki turlarda doğrudan doğrulanamamıştı → Adım 0 DEMO kanalı ölçümü (Mgmt query endpoint `SUPABASE_DEMO_REF`+`SUPABASE_DEMO_PAT`, fallback demo pooler psql) apply ÖNCESİ ZORUNLU; çapa imzaları + ÖNCE sayaçları kanıt zarfına yazılır |
| R5 | Entegrasyon boşluğu netleştirildi: `gebelik_muayene_listele`/`_uret` için `js/` çağrı noktası S2 Adım 3 (UI) ile gelir; pg_cron'suz demo'da üretim vektörü elle `SELECT public.gebelik_muayene_gorev_uret(false);` (psql/Mgmt, service_role bağlamı — sahibin onaylı koşumu) → plan A7 notu güçlendirildi; UI teslim edilene kadar durum: "cron+şema hazır, UI bekliyor" |
| R6 | **Son review kapısı turu (2026-09-25, PARTIAL→fix):** 8 bulgudan üçü FIX edildi — (a) iki YENİ RPC'ye `SET search_path = public, pg_temp` (ev deseni 20260923000003; yeniden-dbvalidate C1 PASS, rapor `ddf69fa0` + DEMO'ya idempotent yeniden-apply + çekirdek kabul kümesi yeniden-yeşil); (b) sheet başlığı sessiz=0+muayene>0'da "Sessiz Hayvanlar (0)" yerine muayene odaklı; (c) eski damga `20260924-01` test kara listesine eklendi. Beşi belgelendi: #3 reuse `_son_tohumlama`, #4 Promise.all, #5 options-objesi → BUGS.md BUG-S2-REVIEW-TEMIZLIK; #1 ve #2 aşağıda sahibe sunum |
| R7 | **SAHİBE SUNUM (review #1 — sahip kararı):** D1 "Bekliyor tam hariç" ANY-kayıt-basedir; muayene RPC'leri EN-YENİ-tohumlama otoritesidir. "Eski-Bekliyor + en-yeni-Boş" hayvan (ör. ACK_PENDING yolu üretebilir) 50+ sessizlikte İKİ listeden de düşer — sahibin "kapsam Boş+bilinmeyen" kuralının en-yeni-kayıt okumasına göre bu hayvan sessiz KAPSAMINDADIR. DEMO'da bugün bu durum 0 hayvan (OBSERVED); davranış D1+F9 kayıtlarına dayanır. Sahip istemezse delta: v_eligible'da NOT EXISTS'i en-yeni-tohumlama sonucuna bağlamak (tasarı: `latest.sonuc <> 'Bekliyor'`) — ayrı sahip onaylı migration turu |
| R8 | **SAHİBE SUNUM (review #2 — dağıtım sırası):** "50+ gündür" UI metinleri merge ile GitHub Pages prod'a gider; migration DEMO-kilitlidir, prod DB sahibin ayrı apply kapısına kadar 55'te kalır → merge ile prod UI'da 50-54g hayvanlar metinde vaat edilir ama listede görünmez (kısa pencere). Sıra önerisi: prod-apply (sahip kapısı) merge ile aynı dalgada ya da merge'den hemen önce; aksi halde pencere bilinçli kabul edilmeli |
