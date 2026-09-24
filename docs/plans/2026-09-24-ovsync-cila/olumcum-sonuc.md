# ÖLÇÜM SONUC — Ovsync Cila Turu, 5 ölçüm zarfı (2026-09-25)

- **Ajan:** ölçüm ajanı (SALT-OKUNUR — koda ve şemaya yazma yok; tek çıktı bu rapor)
- **Kanal:** DEMO = demo pooler psql (`postgresql://postgres.$SUPABASE_DEMO_REF@$SUPABASE_DEMO_POOLER:5432/…`, ana checkout `.env`). Tek istisna Ö2'deki PROD çapraz-okuması (tools-bank `supabase_query`, salt SELECT — KANAL KURALI gereği açıkça etiketlendi).
- **Ölçüm zamanı:** 2026-09-25 ~20:56–21:10 UTC (psql `now()` OBSERVED 20:56:50). Canlı veri kayar — s3 implementer koşum günü 0c'yi YİNE tazelemelidir (E-2).
- **Demo şema durumu ölçüm anında:** S1 uygulanmamış, S2 uygulanmamış, S3 (`ureme_temizlik_reconcile`) uygulanmamış — kanıtlar aşağıda satır satır.

---

## Ö1 — `tohumlama_sonuc_bos` overload tespiti → **OVERLOAD YOK**

| Soru | Sonuç | Kanıt |
|---|---|---|
| Canlı demo pg_proc'ta kaç imza? | **1** imza: `(p_tohumlama_id text, p_notlar text)` | OBSERVED pg_proc grubu: `tohumlama_sonuc_bos \| 1 \| p_tohumlama_id text, p_notlar text` (2026-09-25) |
| Canlı gövde | SECURITY DEFINER, `sonuc != 'Bekliyor'` guard'ı, `tohumlama+hayvanlar` güncelleme, `GEBELIK_KONTROL/TOHUMLAMA_HAZIRLIK` iptali, islem_log audit + **R3.2 SK8: `PERFORM public._acik_disi_gorev_kur(hayvan_id)`** | OBSERVED `pg_get_functiondef('public.tohumlama_sonuc_bos(text,text)')` |
| Overload nerede öldü? | `DROP FUNCTION IF EXISTS public.tohumlama_sonuc_bos(text)` — tek-argümanlı eski imza bu migration'la kaldırıldı | CONFIRMED `supabase/migrations/20260403000001_fix_tohumlama_sonuc_bos_ambiguity.sql:6` |
| Repo geçmişi | 5 tanımlayıcı: `20260327000001` → `20260330000031` → `20260409000002` (BUG-6b ::uuid cast fix) → `20260403000001` (ambiguity fix, DROP text) → `20260502000001`/`20260512000006` (formal) | CONFIRMED grep `supabase/migrations/` |

**Sonuç:** S5'in "T6/F3 iptal — canlıda overload yok" kararı (commit `972c803`) taze ölçümle **teyit edildi**. Aynı anda sorgulanan yardımcılar da tek-imzalı: `sessiz_hayvanlar_listele(text,integer)=1`, `tohumlama_gorev_ertele(uuid,date,time)=1`; `gorev_ertele` ve `ureme_temizlik_reconcile` demo'da **hiç yok** (Zarf B + S3 henüz apply edilmemiş — beklenen).

---

## Ö2 — Düve/inek hedef-sapma raporu (Y2) + "12 aylık düve" kaynağı

### Y2 ölçümü (spec-s4 §6.2 sorgusu birebir, DEMO, salt-okunur)

- Açık `OVSYNC_BASLAT` görevi: **29** — taban-türü dağılımı: `acik_disi = 29` (kaynak hepsi `ACIK-DISI-<hayvan>-<tarih>`; `ILK-TOH-DUVE/DOGUM/ABORT-*` kaynağı **0**).
- **Sapma (`hedef − _ovsync_kural_tarihi`): min = max = 0** → 29/29 görev kurala birebir. `sapma < 0` satırı **YOK** → spec-s4 U-2 ("12 aylık düve"nin kural/veri ihlali ihtimali) **kapandı: ihlal yok** (OBSERVED 2026-09-25; önceki 0/29 ölçümüyle uyumlu).
- Demo RPC penceresi (`hedef ≤ bugün+2`): **0 satır** — en yakın hedef 2026-10-06 (kupe 188). İlk Tohumlama bölümü demo panelinde ~2026-10-04'e kadar boş (spec V-5/F10 davranışı sürüyor).

### Kural fonksiyonu (canlı, B9 birebir OBSERVED)

`public._ovsync_kural_tarihi(text)` (imza **text**, uuid DEĞİL — Y2 sorgusunun kolon tipiyle uyumlu):
- İnek: `GREATEST(son doğum, son abort) + 51`
- Düve (doğum/abort kaydı yok): `dogum_tarihi + 12 ay 21 gün`
- Taban yoksa NULL (görev açılmaz)

### "12 aylık düve" vakasının kaynağı

**PROD kupe 32 (tools-bank kanalı, salt-SELECT, 2026-09-25):** doğum **2025-09-05**, kategori NULL ("Düve (Büyük)" etiketi panel kaynağı), kisir=false → hedef **2026-09-26 = doğum + 386 gün = 12 ay 21 gün birebir**, sapma 0. Bugünkü yaşı ~12,7 ay.
**Sonuç (INFERRED, iki kanalın çarpışmasıyla):** sahibin "12 aylık düve" gözlemi **veri hatası veya eski-kural görevi DEĞİL** — düve taban kuralının (doğum+12a21g) tasarım davranışıdır: ilk tohumlama hedefi, düve ~12,7 aylıkken düşer ve hayvan o yaşa geldiğinde panelde görünür. Kupe 32 PROD penceresinin tek satırıydı (F10).

### Demo popülasyonunun yaş profili (bilgi)

Açık 29 görevin paydaşı arasında hedefi 2027'ye uzanan çok genç hayvanlar da var (hepsi acik_disi kuralı, sapma 0): kupe 3 "Süt İçen Buzağı" (doğum 2026-09-01, bugün 0,8 ay, hedef 2027-09-22), kupe 97 (1,3 ay), kupe 74/69/68 "Sütten Kesilmiş Buzağı" (7 ay). Yani panel penceresi bu hayvanlara ulaştığında **onlar da ~12,7 aylık** olacak — kural tutarlı. İnek grubu (188, 169, 008, 110: `dogum_tarihi` NULL) tabanını son doğumdan alır; örn. kupe 110: son doğum 2026-08-19 → hedef 2026-10-09 (+51).

---

## Ö3 — Taze açık-sessiz-görev ölçümü + 173 kapanma-kaynağı

### Açık SESSIZ görevler (OBSERVED 2026-09-25, tam liste)

| kupe | gorev_id | hedef | sessiz_gun | kapatan_ref | kaynak |
|---|---|---|---|---|---|
| 173 | `e341a0a9-c391-447b-a3a7-6bf21e815edb` | 2026-09-24 | 56 | NULL | `SESSIZ-548df203…` |
| 186 | `65012b75-702a-4bd4-924f-dfdd8cd0830e` | 2026-09-24 | 56 | NULL | `SESSIZ-cf41ebd4…` |
| 168 | `5fe2ef8b-e717-42ad-908b-66e0af590489` | 2026-09-24 | 60 | NULL | `SESSIZ-bcc67af7…` |

Demo'da açık SESSIZ görev = **3** (spec K13 kümesiyle birebir; 168/173/186'nın dışında açık SESSIZ yok).

### 173'ün kapanma-kaynağı (audit-izli kesin okuma)

1. **Tek gerçek kapanma: kullanıcı tamamlaması.** Eski görev `d6727f0b` (created 2026-06-25, hedef 2026-06-25) → `tamamlandi=true`, `tamamlanma_tarihi=2026-06-26 05:58:18`; islem_log `c1a904d6… tip=GOREV_TAMAMLA ref_id=d6727f0b` ("Görev tamamlandı (stok: hayır, padok: hayır)"). `kapatan_ref` kullanılmamış (tamamlama yolu iptal değildir). (OBSERVED)
2. **Bugünkü görev tek üretim çağrısının ürünü:** `e341a0a9` created **2026-09-24 05:00:00.260896** — 168 (`5fe2ef8b`) ve 186 (`65012b75`) ile **birebir aynı timestamp** → tek `sessiz_hayvanlar_reconcile()` çağrısı üçünü birden üretti. (OBSERVED)
3. **"Kapandı → yeniden açıldı" çıkarımı (spec K13) audit izinde YOK:** `degisim_log` 935 satırla 2026-09-13 → 2026-09-24'ü kapsıyor, `gorev_log` için 370 UPDATE kaydı var; **hiçbiri `e341a0a9`'a dokunmuyor** → görev yaratıldığından beri hiç güncellenmemiş. Doğru okuma: eski görev (Haziran) kapalı kaldı; bugünkü görev bugün 05:00'te ÜRETİLDİ. (OBSERVED; K13'ün INFERRED mekanizması düzeltildi)
4. **Aktör UNKNOWN:** demo'da pg_cron YOK (`pg_extension`'da cron yok, `cron` şeması yok — K18'in 3. teyidi, OBSERVED 2026-09-25). 05:00:00.26'daki çağrı elle ya da dış zamanlayıcıdan geldi. **E-1'i güçlendirir: demo'da yeniden üretim vektörü CANLI ve düzenli çalışıyor.**

### Üretim/kapanma bacaklarının bugünkü simülasyonu (salt-SELECT, çağrı YAPILMADI)

Canlı `sessiz_hayvanlar_reconcile()` gövdesi (OBSERVED): üretim bacağı `v_eligible WHERE sessiz_gun >= 55` + iki guard (açık görev var mı / 30 gün içinde kullanıcı-tamamlaması var mı); kapanma bacağı `v_eligible@55'te olmayan` açık SESSIZ görevleri `kapatan_ref='sessiz-noteligible'` ile kapatır. **Üretim filtresinde ovsync/case/kısır muafiyeti YOK** (R32 muafiyetleri yalnız `_acik_disi_gorev_kur`'da).

- `v_eligible sessiz_gun>=55` bugün: **9 hayvan** = 002, 122, 144, 149, 168, 173, 180, 186, Test inek 3.
- Bunların 6'sı 30-gün kullanıcı-tamamlama cooldown'unda, 3'ünün (168/173/186) açık görevi var → **bugün çağrılsa `uretilen=0`, `kapatilan=0`** (tüm 9 eligible; kapanma bacağı kimseye dokunmaz).
- 50–54 bandı: **0 hayvan** → S2'nin eşik 50'ye çekmesi bugün kimseyi eklemez.

### R2 çapaları canlıda birebir (koşum-baz-çizgisi)

168 → son tohumlama 2025-09-12 `'Doğum Yaptı'`; 173 → 2026-07-30 `'Bekliyor'`; 186 → 2025-10-29 `'Doğum Yaptı'` (OBSERVED, MK3 sıralamasıyla). → plan-s3 birinci senaryo doğrulandı: **R1=0 (pf NULL), R2={173 `e341a0a9`}, 168/186 açık kalır.**

### YENİ BULGU (S2 implementer'ına zorunlu not) — reconcile gövdesinin kendi sabitleri

Canlı gövdede **view'dan bağımsız iki sabit `55`** var: üretim bacağı `WHERE e.sessiz_gun >= 55` ve kapanma bacağı `NOT EXISTS(… e.sessiz_gun >= 55)`. S2 eşiği yalnız view + `sessiz_hayvanlar_listele` default'ta değiştirip bu gövdeyi bırakırsa: 50–54 bandındaki bir hayvanda üretim bacağı (view@50) görev üretir, kapanma bacağı (55) aynı çağrıda `sessiz-noteligible` ile kapatır → **her çağrıda üret/kapat savaşı**. Bugün band boş olduğundan etkisiz, ama S2'nin eşik değişimi **3 yüzeyi birden** kapsamalı: (1) `v_eligible` view, (2) `sessiz_hayvanlar_listele` default, (3) `sessiz_hayvanlar_reconcile` gövdesindeki iki sabit. (OBSERVED gövde; band durumu OBSERVED 0)

### T-A4 projeksiyonu (ölçüm-tabanlı, plan-s3 §7a ile uyumlu)

Koşum 173'ü kapatır → S2 uygulanmışsa 173 (`Bekliyor`) `v_eligible`'dan düşer (üretilemez); 168/186'nın görevleri temizlik-dışı olduğundan açık kalır (guard-1 üretimi bloklar) ve eligible kaldıklarından kapanma bacağı da dokunmaz; cooldown'lu 6 hayvan zaten üretilmez → **`uretilen=0 AND kapatilan=0` BEKLENİR.** T-A4'ün S2'nin Bekliyor-hariç view'ına bağımlılığı (spec V-4) ölçüyle teyit edildi. 168/186'nın açık OVSYNC_BASLAT'ı **yoktur** (yalnız açık `TOHUMLAMA_PLANLI` 8384790b/07c867a4) → R32 "açık OVSYNC_BASLAT" muafiyeti onları kurtarmaz; onları üretimden koruyan şey açık SESSIZ görevlerinin temizlik-dışı kalmasıdır — koşum 168/186'ya dokunmazsa T-A4 sağlamdır.

---

## Ö4 — `protokol_eksik_tara` repo-düzeyi okuması

| Yüzey | Bulgu | Kanıt |
|---|---|---|
| Tanım zinciri | 5 migration: `20260603000004` (orijinal scanner) → `20260603000005` (fix v2) → `20260624000001` (postpartum D11–D39) → `20260624000020` (null guard fix) → **`20260718000001` (görev-otoritesi, SON tanımlayıcı)** | CONFIRMED grep `supabase/migrations/` |
| Kurallar | A. DOĞUM SONRASI PROTOKOL (0–63 gün) · B. İLERİ GEBE PROTOKOL (240–265 gün; aktif gebelik instance'ındaki gerçek görev tarihi OTORİTE, legacy görevlerde kanonik-tarih fallback) · C. KIZGINLIK TAKİBİ (55–70 gün) | CONFIRMED `20260718000001_protokol_scanner_task_authority.sql:25,127,160-183,264` |
| Canlı-drift | **YOK** — canlı `pg_get_functiondef` kelime-kümesi ⊆ repo `20260718000001` kelime-kümesi; canlı-özel kelime 0 (repo-özel kelimeler yalnız yorum Türkçesi + GRANT/NOTIFY satırları) → canlı = 20260718000001 gövdesi | OBSERVED karşılaştırma 2026-09-25 |
| Canlı imza | `protokol_eksik_tara()` — 0 argüman, SECURITY DEFINER, plpgsql | OBSERVED pg_proc |
| JS çağrıcıları | `js/ui.js:415`, `:1794`, `:2446` (+2 catch/yorum satırı :423, :1796, :2392) | CONFIRMED grep |
| rpc-reference | `.harness/references/rpc-reference.md:239` girdisi VAR ama satır çapaları **BAYAT** ("ui.js:301, 1060, 1367" → gerçek: 415/1794/2446). S3 tek-yazıcı disiplini ("mevcut satırlara dokunma") gereği bu raporda notlanır, dosyaya dokunulmadı | CONFIRMED okuma |
| Anon EXECUTE | Demo'da **KAPALI** (`has_function_privilege('anon',…)=false`; `tohumlama_sonuc_bos` için de false). Repo'daki `20260624000001:305` ve `20260624000020:311` `TO anon, authenticated` GRANT satırları canlıyı YANSITMAZ — "yeni migration anon GRANT yazmaz" kuralının canlı gerekçesi | OBSERVED demo has_function_privilege |

---

## Ö5 — Kısır 184/199/208 açık zincir envanteri (dry-run listesi — s3 implementer'ı kullanacak)

### Kısır hayvanlar: 6 (OBSERVED)

`115` d9e1838e… (tdm=gebe) · `184` e61f6151… (gebe) · `185` 0b353d36… (gebe) · `199` e31a60e5… (gebe) · `204` d18bed0f… (tdm='-') · `208` de370be4… (tdm='-')

### KISIR-A — aktif UREME instance'ları: 2 (birebir K15)

| kupe | instance_id | kaynak_ref | baslangic |
|---|---|---|---|
| 184 | `5570df8f-637a-48d4-8c20-d991a0936329` | `ILERI_GEBE-e61f6151…` | 2025-09-24 |
| 208 | `9bc82033-eae5-42fa-a13e-521ebb98e578` | `ILERI_GEBE-de370be4…` | 2026-02-10 |

199'un aktif instance'ı YOK (KISIR-B hayvan-bazlı kapatma bunu zaten karşılıyor). 115/185/204'ün aktif instance'ı YOK.

### KISIR-B — açık zincir görevleri: **27** (D-1 listesiyle: 3 × [4 GUN + 4 SEANS + 1 TOHUMLAMA_PLANLI])

Tümü `protokol_instance_id = NULL` (**U-1 kapandı: 27/27 NULL**) ve OVSYNC_BASLAT açık kısırda YOK.

**kupe 184 (e61f6151-5636-46bf-b05d-330498b1efb2):**

| gorev_tipi | gorev_id | hedef | parent_id |
|---|---|---|---|
| TOHUMLAMA_PLANLI | `113c327f-73e2-40f4-936c-94b947fca950` | 2026-10-04 10:00 | NULL |
| TEDAVI_SEANS | `3f5e3ed1-0ca7-47e8-9b6f-aa38271d6649` | 2026-09-24 10:00 | `8c73e316…`(G1) |
| TEDAVI_SEANS | `b614ae4f-f7f7-40af-945a-7b032f9fbb18` | 2026-10-01 10:00 | `5de6a1d8…`(G2) |
| TEDAVI_SEANS | `554abe7d-5547-4eed-a561-13fff31ff3a1` | 2026-10-02 10:00 | `3b5dd914…`(G3) |
| TEDAVI_SEANS | `c01af4ef-0e7a-417b-a742-a623b60993ff` | 2026-10-03 18:00 | `c83bbf01…`(G4) |
| TEDAVI_GUN | `8c73e316-28d8-45fb-a06a-57bd4820e0d6` (G1) | 2026-09-24 | NULL |
| TEDAVI_GUN | `5de6a1d8-64bb-4217-a884-334dc3f2317f` (G2) | 2026-10-01 | G1 |
| TEDAVI_GUN | `3b5dd914-ee04-49c0-a47f-2bcc453923ec` (G3) | 2026-10-02 | G2 |
| TEDAVI_GUN | `c83bbf01-ffdb-4745-8be3-f80d366c311d` (G4) | 2026-10-03 | G3 |

**kupe 199 (e31a60e5-0fe8-4a1a-882b-3b0ab0bd61f5):**

| gorev_tipi | gorev_id | hedef | parent_id |
|---|---|---|---|
| TOHUMLAMA_PLANLI | `9c3c7180-44f8-4586-93d5-f315e1a2704e` | 2026-10-04 10:00 | NULL |
| TEDAVI_SEANS | `41b694b0-fb80-4af3-a9e3-9c3e2b65e4be` | 2026-09-24 10:00 | `44834291…`(G1) |
| TEDAVI_SEANS | `a6e769d2-6cc5-434d-b0c8-3a94d305a44d` | 2026-10-01 10:00 | `109adb31…`(G2) |
| TEDAVI_SEANS | `c454f702-6972-441e-9ae1-f38703558dca` | 2026-10-02 10:00 | `aec4f54f…`(G3) |
| TEDAVI_SEANS | `b1ac55b3-4b8f-46ae-9547-e75913829c9f` | 2026-10-03 18:00 | `93a2ec88…`(G4) |
| TEDAVI_GUN | `44834291-8162-46f4-a5de-35635b863000` (G1) | 2026-09-24 | NULL |
| TEDAVI_GUN | `109adb31-8485-48ee-aa5c-e0402be8ccb6` (G2) | 2026-10-01 | G1 |
| TEDAVI_GUN | `aec4f54f-5d92-4bf4-9e1c-c929e54e7194` (G3) | 2026-10-02 | G2 |
| TEDAVI_GUN | `93a2ec88-9b2d-4615-b923-2bd68822774e` (G4) | 2026-10-03 | G3 |

**kupe 208 (de370be4-723c-4acf-88db-a9060f993209):**

| gorev_tipi | gorev_id | hedef | parent_id |
|---|---|---|---|
| TOHUMLAMA_PLANLI | `af9dd507-20b9-4c84-ba52-62a23494e01f` | 2026-10-04 10:00 | NULL |
| TEDAVI_SEANS | `9caf9982-4d45-4eae-a2a7-9ef247a1d6db` | 2026-09-24 10:00 | `b2c197e6…`(G1) |
| TEDAVI_SEANS | `5563b536-e58f-46ec-b231-36e812482c24` | 2026-10-01 10:00 | `2c5d23d1…`(G2) |
| TEDAVI_SEANS | `cbd9a558-82a5-4425-95b1-3ae5026d0f09` | 2026-10-02 10:00 | `c893febc…`(G3) |
| TEDAVI_SEANS | `29e0b49e-d924-43aa-8b45-913cbca76a3f` | 2026-10-03 18:00 | `68d8da70…`(G4) |
| TEDAVI_GUN | `b2c197e6-a987-4700-88bf-85081de0bcd3` (G1) | 2026-09-24 | NULL |
| TEDAVI_GUN | `2c5d23d1-8769-4674-9651-8a99111bf9bb` (G2) | 2026-10-01 | G1 |
| TEDAVI_GUN | `c893febc-37d0-4cda-919b-f7346c50a226` (G3) | 2026-10-02 | G2 |
| TEDAVI_GUN | `68d8da70-4be7-469d-b1e1-61772a45eff3` (G4) | 2026-10-03 | G3 |

### Parent-yapısı ölçümü (D-2 doğrulaması)

- Açık **SEANS→GUN çapraz-tip çifti: 12** (3 hayvan × 4) — her SEANS, aynı tarihli GUN'ün çocuğu; K24 doğru. GUN zinciri (G2→G1→…) **aynı-tip** olduğundan `trg_gorev_parent_kapandi`'nın çapraz-tip cascade'ine girmez.
- Dikkat-notu (ölçüm içi): kabaca sayılan "22 çift"e, **185'in eski TAMAMLANMIŞ zincirinden 10 SEANS** karıştı (`tamamlandi=true`, iptal=false; Ağustos 2026 tarihli) — hedef kümenin DIŞINDADIR (KISIR-B `tamamlandi=false` ister). Hedef küme 12 açık çiftle sınırlı; D-2 sıralaması geçerli.
- Tetik kanıtı: `gorev_log` üzerinde `gorev_log_cycle_guard_trigger`, `trg_degisim_log`, `trg_gorev_asip_iade`, **`trg_gorev_parent_kapandi`** — dördü de canlıda duruyor (D-2 önşartı tamam). (OBSERVED pg_trigger)

### Kapsam-dışı kanıtları (T-A5 ön-doldurma)

- **188 dokunulmaz:** `kisir=false`; açık görevleri: İLAÇ `0818cd2e-ff43-40f8-90a3-22443c198466` (2026-09-24, spec'teki `0818cd2e` kısa çapası birebir), İLAÇ `573544f7…` (2026-10-08), OVSYNC_BASLAT `bcd5fe9d-6193-4bc8-a352-cfdad9e6f06d` (2026-10-06 — demo panel penceresine giren İLK aday), DİĞER `738d5ace…` (2026-10-13). KISIR filtresi (`h.kisir IS TRUE`) 188'i zaten dışlar.
- 115/185/204: açık zincir görevi YOK, aktif instance YOK (185'in eski zinciri tamamen tamamlanmış) → KISIR dry-run kapsamına etki sıfır.

### Taze baz-çizgisi (s3 implementer 0c için, 2026-09-25)

| Ölçü | Değer | Senaryoya etkisi |
|---|---|---|
| `cases` toplam / pf dolu / aktif | 132 / **0** / 25 | **R1=0 senaryosu geçerli** (pf hâlâ NULL ×132 — K20 sürüyor) |
| 168'in case'i | `f90731be-cce6-4420-b52a-6accec556868` `active`, pf NULL | K14 çapası doğru |
| 186'nın case'i | `b284807a-828d-42eb-b1f2-c276be8f9f2f` `active`, pf NULL | K14 çapası doğru |
| E-1 kapısı (S1) | `_acik_disi_hedef_ic(kısır 184)` → **2026-09-25 dolu döndü** | S1 uygulanmamış → **onaylı koşum bekletilir** |
| E-1 kapısı (S2) | `sessiz_hayvanlar_listele` default **55** (`DEFAULT 50` yok); `v_eligible` tanımında Bekliyor-filtresi YOK | S2 uygulanmamış → dry-run serbest, koşum bekletilir |
| Beklenen koşum | R1=0 · R2=1 (`e341a0a9`) · KISIR_INSTANCE=2 · KISIR_GOREV=27 → **toplam 30** | plan-s3 §5 birinci senaryo teyitli |

---

## ENGEL ve NOT listesi (orkestratör için)

1. **ENGEL (beklenen, plan-dahili): E-1 hâlâ AÇIK** — demo'da S1 (`_acik_disi_hedef_ic` kısır için dolu dönüyor) ve S2 (eşik 55, Bekliyor filtresi yok) UYGULANMAMIŞ; `ureme_temizlik_reconcile` de yok. Dry-run serbest; **onaylı koşum S1+S2 apply'ına kadar bekletilmeli** (plan-s3 §1 0b).
2. **ENGEL DEĞİL ama izlenmeli — demo'da üretim vektörü canlı:** 168/173/186 görevleri 2026-09-24 05:00:00.26'da tek elle/dış çağrıyla üretilmiş; demo'da pg_cron yok, aktör UNKNOWN. Tur boyunca `sessiz_hayvanlar_reconcile()` çağıran her lane T-A4 ölçümünü kirletebilir — T-A4 ölçümü koşum-danımıza sıkıştırılmalı.
3. **S2 implementer'ına zorunlu not (yeni bulgu):** `sessiz_hayvanlar_reconcile` gövdesinde view'dan bağımsız İKİ sabit `55` var (üretim + kapanma bacakları). Eşik değişimi 3 yüzeyi (view, listele default, reconcile gövdesi) birden kapsamazsa 50–54 bandında üret/kapat savaşı doğar (bugün band boş — gizli tuzak).
4. **pf veri-borcu sürüyor:** `cases.protocol_family` 132/132 NULL (R1=0); 0f sentetik kanıt adımı plan-s3 §1'de duruyor. Sahibin U-6 kararı (backfill mi klon-borcu kaydı mı) bekleniyor.
5. **rpc-reference bayat çapaları:** `protokol_eksik_tara` girdisindeki ui.js satırları (301/1060/1367) gerçek konumları yansıtmıyor (415/1794/2446). Bu turda dokunulmadı (tek-yazıcı disiplin); bir sonraki rpc-reference yazıcısı düzeltebilir.
6. **Ölçüm zaman-sapması:** Tüm DEMO değerleri 2026-09-25 ~21:00 UTC kesitidir; s3 koşum günü 0c tazeleme ŞART (E-2).

*Rapor sonu — ölçüm ajanı yalnız bu dosyayı yazdı; koda, migration'a ve DB'ye yazma yapılmadı (tüm DB erişimi salt-SELECT; tek çapraz-okuma PROD kupe 32 salt-SELECT).*
