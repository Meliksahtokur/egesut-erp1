# SPEC S1 — Kısır hayvan Ovsync bloğu (DB guard + Başlat muafiyeti + UI kilidi)

> **Tarih:** 2026-09-24 · **Sürüm:** 1.1 (onarım turu revizyonu — bkz. §13) · **Branch:** `ovysch-feature-cila-turu` · **Kaynak:** `reports/plans/ovsync-cila-plan-1.md` + `reports/plans/ovsync-cila-sentez.md` (§3 Adım 1, §5A, §9) + canlı kod/demo şema doğrulaması (bu spec yazımında yeniden ölçüldü)
> **Bant:** Prod'a PUSH/MERGE YOK. Demo DB'ye yazmak sahibin 2026-09-24 onayıyla SERBEST; prod DB'ye dokunulmaz. Commitler yalnız bu branch'e.
> **KANAL KURALI (onarım turu, bağlayıcı):** tools-bank `supabase_*` araçları **PROD**'a bakar (ref `zqnexqbdfvbhlxzelzju` — CONFIRMED `~/tools-bank/mcp_server/server.py:307-312` + `js/api.js:23-24`). DEMO ref'i `vtzqjmazsvurxdeondmi`'dir; demo okuma/apply kanalı: `/home/melik/egesut-erp1/.env` içindeki `SUPABASE_DEMO_REF` + `SUPABASE_DEMO_PAT` ile Mgmt API `POST /v1/projects/$SUPABASE_DEMO_REF/database/query` (kalıcı) veya demo pooler psql. v1.0'da "(demo)" etiketli kanıtların bir kısmı aslında bu PROD kanalından ölçülmüştü — hepsi demo'dan yeniden ölçüldü (§13).
> **Kanıt etiketleri:** CONFIRMED (dosya:satır) / OBSERVED (komut veya salt-okunur sorgu çıktısı) / INFERRED / UNKNOWN.

---

## 0. Özet (tek paragraf)

Kısır (`kisir=true`) işaretli hayvanlara bugün Ovsync ilk-tohumlama görevi üretiliyor ve Başlat'a basılabiliyor. Bu spec, bloğu **tek uygunluk noktasında** (DB), **Başlat muafiyetiyle** (ikinci savunma hattı) ve **UI kilidiyle** (görünür katman) birlikte kurar; kısır işareti kaldırıldığında hayvan otomatik olarak normal kurallara döner (fail-closed yok). Sahibin kararıyla demo'daki üç kısır hayvanın AÇIK senkron zincirleri (184/199/208) ayrı bir temizlik adımında dry-run liste onayıyla kapatılır — bu spec'in migration'ı temizliği BEKLEMEZ.

---

## 1. Amaç

1. Kısır hayvan, üreme planlamasının hiçbir aşamasına girmesin: görev üretilmesin (tarama + olay kancaları), üretilmiş açık görevi Başlat ile zincire çevrilemesin, UI'da Başlat eylemi görünüp çalışmasın.
2. Blok **kalıcı-bağımsız** olsun: kısır işareti kaldırılınca hayvan bir sonraki taramada normal açık-dişi kuralına göre görev alsın (sahibin davranış maddesi; plan-1 §3.4).
3. Blok **tek noktadan** yönetilsin: uygunluk kararı tek fonksiyonda (`_acik_disi_hedef_ic`); Başlat muafiyeti ve UI kilidi onun ikinci/üçüncü savunma hatları (defense-in-depth, plan-1 §4 ilkesi).

## 2. Hedef davranış (ölçülebilir)

| # | Davranış | Ölçüm |
|---|---|---|
| D1 | `kisir=true` hayvana OVSYNC_BASLAT görevi **üretilmez** — üç üretim kanrasında da (cron taraması, `hayvan_ekle`, `tohumlama_sonuc_bos`) | `_acik_disi_hedef_ic(kisir_hayvan)` = NULL; `_acik_disi_gorev_kur(kisir_hayvan)` = NULL (görev açılmaz) |
| D2 | Elle kurulmuş açık OVSYNC_BASLAT'a Başlat → zincir açılmaz | `start_first_service_protocol` → `{ok:true, atlandi:'KISIR', gorev_id}`; görev `iptal=true, tamamlandi=true, kapatan_ref='ILK_TOH_MUAF:KISIR'`; yeni `cases` satırı YOK |
| D3 | UI'da kısır hayvanın Başlat butonu YOK; kilitli rozet + kısa açıklama VAR; ✕ (iptal) çalışmaya devam eder | Görev kartı ve protokol uyarı panelinde: kısır satırda `▶ Başlat` DOM'da yok; `💲 Kısır…` rozetli metin var |
| D4 | Kısır işareti kaldırılınca hayvan normal kurala döner | `kisir=false` sonrası `_acik_disi_ovsync_hedef` uygunsa (taban + temiz zemin) `_acik_disi_gorev_kur` görev açar |
| D5 | Dry-run raporu kısır hayvanı yanlış kategoriye yazmaz | `ilk_tohumlama_zamanlayici(p_dry_run:=true)` çıktısında kısır hayvan ne `acilacaklar`'da ne `duve_tabansiz` sayacında |

## 3. Canlı zemin — kanıt tablosu (spec bu zemine kurulur)

> Uyarı: plan-1'in A4/A6 çapaları (`_acik_disi_ovsync_hedef` gövde satırları) **bayattı** — `20260924000002_dryrun_bayrak_bagimsiz.sql` uygunluk gövdesini `_acik_disi_hedef_ic`'e taşıdı. Bu spec canlı şemadan yeniden doğruladı; M1 hedefi buna göre düzeltildi (§4.1).

| # | Kanıt | Etiket |
|---|---|---|
| K1 | Demo'da 184/199/208: `kisir=true`, Aktif, Dişi, Sağmal (Laktasyonda); 184 ve 199'da `tohumlama_durumu='gebe'` (küçük harf), 208'de NULL | OBSERVED demo kanalı `hayvanlar kupe_no IN ('184','199','208')` — onarım turu 2026-09-24'te demo'da birebir doğrulandı (v1.0'daki ölçüm tools-bank PROD kanalındandı, değerler demo ile aynı çıktı) |
| K2 | Üç hayvanın OVSYNC_BASLAT görevleri KAPALI: `0c698720` (184), `bb1fee13` (199), `aec39359` (208) — `tamamlandi=true, iptal=false, kapatan_ref='case:…'` | OBSERVED demo kanalı `gorev_log` JOIN `hayvanlar` — onarım turu 2026-09-24'te demo'da birebir doğrulandı (3/3 id + kapatan_ref eşleşti) |
| K3 | Üç açık senkron vakası: `cases f72f320c-5955…` (184), `37b98c0c-fb4f…` (208), `19febaa1-ff69…` (199) — `status='active'`; **düzeltme:** `protocol_family` PROD'da `'OVSYNC'`, **demo'da NULL** (onarım turu ölçümü). Sonuç: demo'da `_acik_disi_hedef_ic`'in "aktif protocol_family vakası" muafiyeti bu üç hayvanı DÜŞÜRMEZ — S1'in M1 kısır kontrolü yine bloklar (kisir kontrolü vaka kontrolünden önce, §11.1) | OBSERVED demo kanalı `cases id IN (…)` → 3/3 `status='active', protocol_family=NULL`; PROD kanalı aynı id'ler → `protocol_family='OVSYNC'` (ikisi de 2026-09-24). v1.0'daki `'OVSYNC'` değeri PROD'dan geliyordu, demo etiketi yanlıştı |
| K4 | Uygunluk gövdesi `_acik_disi_hedef_ic`'te; `SELECT durum, cinsiyet` — `kisir` sorgulanmıyor; muafiyetler: Aktif/Dişi, son tohumlama Gebe/Bekliyor, aktif protocol_family vakası, açık OVSYNC_BASLAT, kural tabanı | CONFIRMED `supabase/migrations/20260924000002_dryrun_bayrak_bagimsiz.sql:L33-59` + OBSERVED demo kanalı `pg_get_functiondef('_acik_disi_hedef_ic')` repo bloğu (:L21-68) ile birebir (onarım turu 2026-09-24, normalize-diff) |
| K5 | `_acik_disi_ovsync_hedef` artık yalnız bayrak kapısı + delegasyon (`RETURN _acik_disi_hedef_ic(...)`) | CONFIRMED `20260924000002:L74-90` + OBSERVED demo kanalı delegasyon imzası doğrulandı (onarım turu 2026-09-24) |
| K6 | `start_first_service_protocol` muafiyet yapısı: `IF … AKTIF_DEGIL THEN … ELSE <MK3 iç-IF: GEBE → BEKLIYOR → AKTIF_SENKRONIZASYON (:L719-728)> END IF` — **KISIR yok**; hayvan okuma `SELECT * INTO v_h FROM hayvanlar … FOR UPDATE` (:L710, kisir alanı zaten `v_h`'te taşıyor); muafiyet yolu :L731-744: görev `iptal=true, tamamlandi=true, kapatan_ref='ILK_TOH_MUAF:<neden>'` + instance `iptal` + `FIRST_SERVICE_SKIPPED` audit + dönüş `{ok:true, atlandi:<neden>}` | CONFIRMED `20260924000001_ovsync_pg_r32_acik_disi.sql:L709-744` + OBSERVED demo kanalı gövde repo bloğu (:L662-845) ile birebir (onarım turu 2026-09-24, normalize-diff) |
| K7 | `ilk_tohumlama_zamanlayici`: gerçek tarama dalı `_acik_disi_ovsync_hedef` çağırır (:L246), dry-run dalı `_acik_disi_hedef_ic` çağırır (:L140, :L154); dry-run tarama SELECT'i :L128-134 (WHERE :L132); gerçek-dal `duve_tabansiz` sayacı :L262-277 (WHERE :L264) inline koşullu (kısırdan habersiz) | CONFIRMED `20260924000002:L99-295` (gövde; ACL :L300-301) + OBSERVED demo kanalı gövde repo ile birebir (onarım turu 2026-09-24, normalize-diff) |
| K8 | `ovsync_baslat_uyarilari()` dönüş alanları: gorev_id, hayvan_id, kupe_no, kategori, hedef_tarih, hedef_saat, tai_tarihi, kaynak, taban_turu — `kisir` YOK; `hayvanlar h` JOIN'i mevcut (alan ekleme mekanik) | CONFIRMED `20260924000001:L1089-1120` + OBSERVED demo kanalı gövde repo bloğu ile birebir (onarım turu 2026-09-24, normalize-diff) |
| K9 | UI'da iki Başlat-buton üreticisi, ikisi de `kisir` okumuyor: `_ovsyncBaslatBtnHtml` (görev kartı; `renderTask` içinde :L1259'da kullanılır) ve `_ovSatir` (protokol uyarı paneli) | CONFIRMED `js/ui.js:L1162-1166` ve `js/ui.js:L1834-1844` |
| K10 | `ovsyncBaslat()` global yalnız iki yerde butonlanıyor (`ui.js:L1164`, `ui.js:L1841`) → hayvan kartında ovsync başlatma eylemi YOK; hayvan kartında kısır rozeti zaten var | CONFIRMED `grep -n ovsyncBaslat js/ui.js` (2 buton noktası + fonksiyon :L1173) + `js/ui.js:L1588` |
| K11 | Başlat dönüşü `atlandi` için UI desteği zaten var: `ovsyncBaslat` içinde `if(r&&r.atlandi){ toast('Atlandı: '+r.atlandi,true); }` → M2 tek başına "Atlandı: KISIR" toast'u basar | CONFIRMED `js/ui.js:L1177` |
| K12 | AÇIK OVSYNC_BASLAT görevi sahiplerinin **hiçbirinde** `kisir=true` yok; 188 açık OVSYNC_BASLAT hedef 2026-10-06, `kisir=false` — sahibin "çift zincir KASITLI" kararının canlı çapası. Sayı tarih-bağımlıdır: açık görev adedi **PROD'da 31** (v1.0 ölçümü — tools-bank kanalı), **demo'da 29** (onarım turu ölçümü); her iki kanalda da `kisir=true` açık görevli = 0 | OBSERVED demo kanalı agregat sorgu: `acik_toplam=29, kisir_acik=0, 188 açık hedef=2026-10-06`; PROD kanalı: 31 satır (ikisi de 2026-09-24). Sabit sayı beklentisi T9'a YAZILMAZ — yalnız `kisir_acik=0` şartı |
| K13 | Üretim kancaları uygunluk fonksiyonunu canlıda çağırıyor: `hayvan_ekle` (overload'lardan biri) ve `tohumlama_sonuc_bos` gövdeleri `_acik_disi%` içeriyor | OBSERVED demo kanalı `pg_proc` taraması → 2/2 fonksiyon eşleşti (onarım turu 2026-09-24) |
| K14 | Kısır guard'ı öncülleri canlıda mevcut (desen tekrarı değil, aynı ailenin genişletmesi): `hayvan_tohumlanabilir_onayla` → `RAISE 'Kısır hayvan tohumlanamaz'`; `hayvan_guncelle` overload'ından biri kısır validation'ı taşıyor; `_yeniDogumGun` kısırı UI'da atlıyor | OBSERVED demo kanalı — kısır guard'ı `hayvan_guncelle` + `hayvan_tohumlanabilir_onayla` gövdelerinde doğrulandı (onarım turu 2026-09-24) + CONFIRMED `js/ui.js:L1551-1552` |
| K15 | Kabul altyapısı hazır: `pg_temp.kb_hayvan(p_yas_gun, p_durum, p_kisir DEFAULT false)` — kısır test hayvanı tek parametre; betik sözleşmesi: sarmalayıcı `BEGIN…ROLLBACK`, her test DO bloğu, `kb_ok` sayaçlı | CONFIRMED `supabase/tests/ovsync_pg_kabul.sql:L19-60` |
| K16 | Kapılar mevcut: `scripts/db-validate.sh` (statik+izole-apply, çıkış 0/1/2); ui.js sürüm damgası `js/ui.js?v=20260924-01` (tek-değer kuralı) | CONFIRMED `scripts/db-validate.sh:L1-30`, `index.html:L2336` |

## 4. Tasarım kararları

### 4.1 M1 hedefi `_acik_disi_hedef_ic` (wrapper DEĞİL) — plan-1'e göre düzeltme
Uygunluk hesabı K5 gereği `_ic`'te; `_acik_disi_ovsync_hedef` yalnız bayrak kapısı. Kısır kontrolü `_ic`'e konursa tek değişiklikle (i) gerçek üretim (wrapper→`_ic`; `_acik_disi_gorev_kur` :L314, zamanlayıcı gerçek dal :L246), (ii) dry-run önizleme (dal :L140/:L154 doğrudan `_ic`) ve (iii) olay kancaları (K13) birlikte kapanır. Wrapper'a konulsaydı dry-run dalı kısırları görmeye devam ederdi. **Kanıt: K4/K5/K7.**

### 4.2 M2'de KISIR muafiyeti ELSIF zincirinin İLK şartı (GEBE'den önce)
Sıra: `AKTIF_DEGIL → KISIR → GEBE → BEKLIYOR → AKTIF_SENKRONIZASYON`. Nedeni: K1'deki 184/199'ın `tohumlama` sonucu normalize-edilmemiş küçük harfli olabilir; ayrıca S3 açık sorusu (kısır mı, tohumlama kaydı mı otorite — sentez §9 madde 9) henüz kapanmadı. KISIR-first her iki cevapta da güvenli: kısır işareti kaldırılırsa akış normal kurallara döner (D4); kısırsa neden kodu her zaman `KISIR` olur (yanlış-atıf yok). **Kanıt: K1, K6. INFERRED (sıralamanın davranışsal nötrlüğü).**

### 4.3 M3 — dry-run rapor doğruluğu (küçük, kapsamda)
Dry-run tarama SELECT'ine ve gerçek-dal `duve_tabansiz` sayacına `AND NOT COALESCE(h.kisir,false)` eklenmezse: kısır+tabansız hayvan `_ic`'ten NULL aldığı için :L137-153 koşul zincirinde "tabansız düve" olarak **yanlış sayılır** (rapor sahibi yanıltır); kısır+tabanlı hayvan zaten `ELSIF _ic IS NOT NULL` dalına girmez. Filtre iki SELECT noktasına eklenir; `taranan` sayacı kısır hayvanları artık içermez (rapor anlamı: taranan = aday-popülasyon). **Kanıt: K7.**

### 4.4 U1 — `kisir` alanı RPC dönüşüne eklenir, frontend ek sorgu yapmaz
`ovsync_baslat_uyarilari` zaten `hayvanlar h` JOIN'liyor; `jsonb_build_object`'e tek satır eklenir. Görev kartı tarafında görev satırı hayvan alanı taşımadığından kısıra `getState('animals')` üzerinden bakılır (kalıp zaten `renderTask` :L1244'te var). **Kanıt: K8, K9.**

### 4.5 U3 — hayvan kartında ek işlem YOK (doğrulama maddesi)
`ovsyncBaslat` global yalnız iki buton üreticisinde çağrılıyor (K10); kartta çelişen buton yok, kısır rozeti mevcut. Spec bir doğrulama kabul maddesi taşır (§8 T13), kod değişikliği taşımaz.

## 5. Tek-yazıcı zarfı — dokunulacak dosyaların TAM listesi

> Eşzamanlı ajan sayısı 10 olabilir; S1 implementeri AŞAĞIDAKİ 4 DOSYADAN BAŞKASINA YAZMAZ. `js/ui.js` bu turun tek-yazıcı dosyasıdır: Plan 3'ün ui.js kulvarı (sentez §3 Adım 4) S1'in ui.js commit'i MERGE/commit edilmeden başlamaz.

| # | Dosya | İşlem | Nokta |
|---|---|---|---|
| 1 | `supabase/migrations/20260925000001_ovsync_kisir_blok.sql` | **YENİ** (ad: plan-1 §4 adabı; koşum öncesi `ls supabase/migrations/` ile numara çakışması kontrolü — 20260925000001 bugün boş) | M1 + M2 + M3 + U1, tek dosya |
| 2 | `supabase/tests/ovsync_pg_kabul.sql` | **APPEND** (yalnız ekleme; ÖZET bölümünden ÖNCE `S1-T1…T6` blokları — `R32-11` etiketi dosyada dolu: CONFIRMED `supabase/tests/ovsync_pg_kabul.sql:L1682-1696`) | §8 T1-T7 |
| 3 | `js/ui.js` | **İKİ LOKAL NOKTA**: `_ovsyncBaslatBtnHtml` (:L1162-1166) ve `_ovSatir` (:L1834-1844, yalnız buton hücresi :L1840-1843) | §7 |
| 4 | `index.html` | `js/ui.js?v=20260924-01` → `?v=20260925-01` (tek-değer damga kuralı gereği 26 tektip satırın TAMAMINA sed ile uygulanır — plan sapma-2; çapa :L2336) | :L2336 |

**DokunULmayacaklar (zarf dışı):** `js/api.js`, `js/forms.js`, `js/state.js`, `js/app.js`; mevcut tüm migration dosyaları (yalnız YENİ dosya yazılır); `BUGS.md` (S1'de borç kaydı yok — T9/erteleme borcu başka planların); `supabase/tests/README.md`; Plan 2/3/4/5'in zarf dosyaları. `_ovsync_kural_tarihi`, `_acik_disi_gorev_kur`, `_vaka_ac_tek` gövdeleri DEĞİŞMEZ (kısır filtresi `_ic`'teki tek noktadan düşer).

## 6. Migration taslağı — `20260925000001_ovsync_kisir_blok.sql` (SQL gövde seviyesi)

Dosya adabı (plan-1 §4 + 000002 örneği): başlıkta amaç/otorite/ROLLBACK yorumu; her fonksiyon `CREATE OR REPLACE` (imzalar DEĞİŞMEZ — overload riski yok; `hayvan_ekle`'nin 2 overload'u var, bu spec onlara dokunmaz); ACL satırları idempotent tekrarlanır; **anon'a GRANT YOK** (kural); dosya sonu `NOTIFY pgrst, 'reload schema';`. Uygulama öncesi ve taslak aşamasında `bash scripts/db-validate.sh <dosya>` koşulur (db-validation kapısı; DML/UNIQUE/FK içermediğinden data-mode gerekmez — aracın kendi kararı).

### 6.1 M1 — `_acik_disi_hedef_ic` (kısır kontrolü Aktif/Dişi kontrolünün hemen ardından)

Tam gövde = canlı gövdenin (K4) birebir kopyası + aşağıdaki iki diff. Implementer gövdeyi canlıdan alır: `SELECT pg_get_functiondef(oid) FROM pg_proc WHERE proname='_acik_disi_hedef_ic'` (bugün repo `20260924000002:L21-68` ile birebir — K4).

```sql
-- DIFF 1 (sorgu): kisir kolonunu da çek
--   ESKİ: SELECT durum, cinsiyet INTO v_h FROM public.hayvanlar WHERE id = p_hayvan_id;
--   YENİ:
  SELECT durum, cinsiyet, COALESCE(kisir, false) AS kisir
    INTO v_h FROM public.hayvanlar WHERE id = p_hayvan_id;

-- DIFF 2 (guard): Aktif/Dişi IF bloğunun hemen ardından
  IF v_h.kisir THEN
    RETURN NULL;
  END IF;
```

 COMMENT güncellenir: `'R3.2 SK7 bayrak-yoksayan uygunluk (yalnız dry-run önizleme; iş yaratmaz). Muaf: kısır, Aktif değil/Dişi değil, Gebe/Bekliyor, aktif senkronizasyon vakası, açık OVSYNC_BASLAT, tabansız.'` — `REVOKE ALL ON FUNCTION public._acik_disi_hedef_ic(text) FROM PUBLIC, anon, authenticated;` aynen korunur.

### 6.2 M2 — `start_first_service_protocol` muafiyet setine KISIR

Tam gövde = canlı gövdenin (K6) birebir kopyası + tek diff. `SELECT * INTO v_h FROM public.hayvanlar … FOR UPDATE` satırı DEĞİŞMEZ (kisir alanı `v_h`'te zaten taşıyor — K6).

```sql
-- DIFF (muafiyet bloğu): mevcut IF/ELSE zinciri içine ELSIF eklenir
  IF NOT FOUND OR v_h.durum IS DISTINCT FROM 'Aktif' THEN
    v_neden := 'AKTIF_DEGIL';
  ELSIF COALESCE(v_h.kisir, false) THEN
    v_neden := 'KISIR';
  ELSE
    -- MK3: gebelik otoritesi = son tohumlamanın sonucu (mevcut blok AYNEN KORUNUR:
    -- son_sonuc Gebe → GEBE; Bekliyor → BEKLIYOR; aktif protocol_family vakası →
    -- AKTIF_SENKRONIZASYON)
    ...
  END IF;
```

Kapanış yolu mevcut mekanizmayı kullanır, yeni mekanizma YOK: görev `iptal=true, tamamlandi=true, kapatan_ref='ILK_TOH_MUAF:KISIR'`; instance `durum='iptal'`; `FIRST_SERVICE_SKIPPED` audit (`neden: KISIR`); dönüş `jsonb_build_object('ok', true, 'atlandi', 'KISIR', 'gorev_id', p_gorev_id)`. ACL aynen: `GRANT EXECUTE … TO authenticated, service_role;` (`REVOKE … FROM PUBLIC, anon;` ile birlikte).

**Canlı yapı notu (onarım turu):** canlı zincir `IF AKTIF_DEGIL THEN … ELSE <MK3 iç-IF (GEBE/BEKLIYOR/AKTIF_SENKRON, :L719-728)> END IF` biçimindedir — düz bir ELSIF zinciri DEĞİL. DIFF'in mekaniği: mevcut `ELSE` satırı `ELSIF COALESCE(v_h.kisir,false) THEN v_neden := 'KISIR'; ELSE`'ye bölünür; MK3 iç-IF bloğu ELSE içinde AYNEN kalır. Görünür sıra `AKTIF_DEGIL → KISIR → GEBE → BEKLIYOR → AKTIF_SENKRONIZASYON` ile uyumlu (§4.2).

### 6.3 M3 — `ilk_tohumlama_zamanlayici` (yalnız iki SELECT'e filtre)

Tam gövde = canlı gövdenin (K7, repo `20260924000002:L99-295`) birebir kopyası + iki diff; imza korunur (`p_dry_run boolean DEFAULT false`), `DROP FUNCTION` YAPILMAZ (pg_cron'un `select public.ilk_tohumlama_zamanlayici()` çağrısı kesilmez — INFERRED, tek-arg default ile çözülür).

```sql
-- DIFF A (dry-run tarama SELECT'i, 20260924000002:L131-133):
   WHERE h.durum = 'Aktif' AND h.cinsiyet = 'Dişi'
     AND NOT COALESCE(h.kisir, false)
   ORDER BY h.id

-- DIFF B (gerçek-dal duve_tabansiz sayacı, 20260924000002:L263-264):
   FROM public.hayvanlar h
  WHERE h.durum = 'Aktif' AND h.cinsiyet = 'Dişi'
    AND NOT COALESCE(h.kisir, false)
    AND public._ovsync_kural_tarihi(h.id) IS NULL
    ...
```

ACL aynen: `REVOKE ALL … FROM PUBLIC, anon; GRANT EXECUTE … TO authenticated, service_role;`

### 6.4 U1 — `ovsync_baslat_uyarilari` dönüşüne `kisir`

SQL fonksiyon, tam gövde kısa; canlı gövdenin (K8) birebir kopyası + tek satır:

```sql
CREATE OR REPLACE FUNCTION public.ovsync_baslat_uyarilari()
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path = public, pg_temp
AS $fn$
  SELECT jsonb_build_object(
    'ok', true,
    'uyarilar', COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
               'gorev_id', g.id,
               'hayvan_id', g.hayvan_id,
               'kupe_no', h.kupe_no,
               'kategori', COALESCE(h.kategori, h.grup),
               'kisir', COALESCE(h.kisir, false),          -- S1/U1: YENİ ALAN
               'hedef_tarih', g.hedef_tarih,
               'hedef_saat', g.hedef_saat,
               'tai_tarihi', g.hedef_tarih + 10,
               'kaynak', g.kaynak,
               'taban_turu', CASE WHEN g.kaynak LIKE 'ILK-TOH-DUVE-%' THEN 'duve'
                                  WHEN g.kaynak LIKE 'ILK-TOH-DOGUM-%' THEN 'dogum'
                                  WHEN g.kaynak LIKE 'ILK-TOH-ABORT-%' THEN 'abort'
                                  ELSE 'acik_disi' END)
               ORDER BY g.hedef_tarih, g.id)
        FROM public.gorev_log g
        JOIN public.hayvanlar h ON h.id = g.hayvan_id
       WHERE g.gorev_tipi = 'OVSYNC_BASLAT'
         AND COALESCE(g.tamamlandi, false) = false
         AND COALESCE(g.iptal, false) = false
         AND g.hedef_tarih <= ((now() AT TIME ZONE 'Europe/Istanbul')::date + 2)
    ), '[]'::jsonb)
  );
$fn$;

COMMENT ON FUNCTION public.ovsync_baslat_uyarilari() IS
  'R3.2 SK9: hedef−2 günden itibaren açık OVSYNC_BASLAT görevleri (protokol uyarıları ekranı verisi). S1: kisir alanı eklendi (UI kilidi için). Salt-okuma.';
REVOKE ALL ON FUNCTION public.ovsync_baslat_uyarilari() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.ovsync_baslat_uyarilari() TO authenticated, service_role;
```

### 6.5 Dosya iskeleti

```sql
-- ============================================================================
-- Migration: 20260925000001_ovsync_kisir_blok
-- SPEC: docs/plans/2026-09-24-ovsync-cila/spec-s1.md
-- Amaç: kisir=true hayvanda ovsync üretim/başlatma bloğu (M1 uygunluk + M2
--       Başlat muafiyeti + M3 dry-run rapor doğruluğu + U1 RPC kisir alanı).
-- Kapsam: yalnız bu dört fonksiyon; şema/d privilej değişikliği yok; anon GRANT yok.
-- ROLLBACK: §9 (dört gövdenin canlı-kopyası öncesi halleri repo migration'larında).
-- ============================================================================
-- <M1>  CREATE OR REPLACE _acik_disi_hedef_ic + COMMENT + REVOKE
-- <M2>  CREATE OR REPLACE start_first_service_protocol + ACL
-- <M3>  CREATE OR REPLACE ilk_tohumlama_zamanlayici + ACL
-- <U1>  CREATE OR REPLACE ovsync_baslat_uyarilari + COMMENT + ACL
NOTIFY pgrst, 'reload schema';
-- EOF 20260925000001
```

## 7. UI değişiklikleri — `js/ui.js` (iki lokal nokta) + damga

### 7.1 `_ovsyncBaslatBtnHtml` (:L1162-1166, görev kartı)

Kısır kontrolü state üzerinden (`getState('animals')` — kalıp `renderTask` :L1244'te mevcut); ✕ butonu her durumda çizilir:

```js
function _ovsyncBaslatBtnHtml(t){
  if(t.gorev_tipi!=='OVSYNC_BASLAT'||t.tamamlandi||t.iptal) return '';
  const _h=getState('animals').find(a=>a.id===t.hayvan_id);
  const _ipt=`<button data-g="${escAttr(t.id)}" onclick="event.stopPropagation();ovsyncIptal(this.dataset.g)" style="font-size:.65rem;padding:4px 8px;border-radius:8px;border:1px solid #999;background:transparent;color:#999;cursor:pointer">✕</button>`;
  if(_h&&_h.kisir) return `<span style="font-size:.62rem;font-weight:700;color:var(--amber)">💲 Kısır işaretli — başlatılamaz</span>${_ipt}`;
  return `<button data-g="${escAttr(t.id)}" onclick="event.stopPropagation();ovsyncBaslat(this.dataset.g)" style="/* mevcut Başlat stili aynen */">▶ Başlat</button>${_ipt}`;
}
```

### 7.2 `_ovSatir` (:L1840-1843, protokol uyarı paneli — buton hücresi)

`u.kisir` U1'den gelir (RPC alanı); kart-yaklaşımı aynen:

```js
${u.kisir
  ? `<span style="font-size:.62rem;font-weight:700;color:var(--amber)">💲 Kısır işaretli — üreme planı yok</span>
     <button data-g="${escAttr(u.gorev_id)}" onclick="ovsyncIptal(this.dataset.g)" style="/* mevcut ✕ stili */">✕</button>`
  : `<button data-g="${escAttr(u.gorev_id)}" onclick="ovsyncBaslat(this.dataset.g)" style="/* mevcut Başlat stili */">▶ Başlat</button>
     <button data-g="${escAttr(u.gorev_id)}" onclick="ovsyncIptal(this.dataset.g)" style="/* mevcut ✕ stili */">✕</button>`}
```

### 7.3 Değişmeyen UI davranışları (kasıtlı)

- `ovsyncBaslat` :L1177 `atlandi` toast'u: D2'de kullanıcı `Atlandı: KISIR` görür — ek JS YOK (K11). Metnin insan-dili çevirisi Plan 3'ün metin turuna (Adım 4) aittir, bu zarfta değil.
- `ovsyncIptal` :L1190-1199 aynen kalır — kısır hayvanın üret-olmuş açık görevini kapatma yolu (plan-1 §5 U2).
- Hayvan kartı (`_animalCardHtml`, js/ui.js:L1595) dokunulmaz (U3 — §4.5).
- Damga: `index.html:L2336` `?v=20260925-01`.

## 8. Kabul testi maddeleri (ölçülebilir)

**Ortam notu:** T1-T7 izole ortamda koşulur (`supabase/tests/ovsync_pg_kabul.sql` sözleşmesi: sarmalayıcı `BEGIN…ROLLBACK`, `kb_ok` OZET sayacı — K15). Demo-apply sonrası T8-T10 **demo kanalından** (§13 kanal kuralı: `SUPABASE_DEMO_REF`/`SUPABASE_DEMO_PAT` Mgmt API veya demo pooler psql — tools-bank `supabase_*` KULLANILMAZ, o PROD'dur) salt-okunur koşar (demo yazma sahibin onayıyla serbest; yine de test betiği varsayılan olarak izole baseline'da koşar). T11-T13 sahip yürüyüşüdür (browser testi ajan koşmaz — plan bandı).

**DB — `S1-T1…T6` kabul blokları (tests/ovsync_pg_kabul.sql'e APPEND, ÖZET'ten önce; T7 = mevcut blokların koşumu. `R32-11` etiketi :L1682-1697'de zaten kullanımda olduğundan yeni bloklar `S1-` öneki taşır):**

- [ ] **T1 (üretim bloğu):** `kb_hayvan(p_kisir:=true)` → (a) `SELECT public._acik_disi_hedef_ic(id)` IS NULL; (b) `_acik_disi_ovsync_hedef(id)` IS NULL (bayrak açıkken de); (c) `_acik_disi_gorev_kur(id)` IS NULL ve `gorev_log`'da bu hayvana yeni OVSYNC_BASLAT satırı = 0. — D1
- [ ] **T2 (Başlat bloğu):** kısır test hayvanına elle açık OVSYNC_BASLAT görevi INSERT (R32-9 adabı: instance'sız görev muafiyet yoluyla uyumlu — K6) → `start_first_service_protocol(gorev_id)` dönüşü `ok=true AND atlandi='KISIR'`; görev satırı `iptal=true AND tamamlandi=true AND kapatan_ref='ILK_TOH_MUAF:KISIR'`; bu hayvana `cases`'te aktif OVSYNC vakası = 0; `islem_log`'da `FIRST_SERVICE_SKIPPED` + `payload->>'neden'='KISIR'` kaydı = 1. — D2
- [ ] **T3 (fail-closed DEĞİL):** T2'deki hayvan `UPDATE … SET kisir=false` → taban var (kb_hayvan 800 günlük — plan S1-T3 ile aynı fixture; düve tabanı dogum_tarihi+12a21g, 800>386) ve zemin temizse `_acik_disi_gorev_kur(id)` IS NOT NULL (görev açılır). — D4
- [ ] **T4 (RPC alanı):** `ovsync_baslat_uyarilari()` çıktısındaki her uyarı nesnesi `kisir` anahtarını boolean taşıyor (`jsonb_typeof = 'boolean'`); kapalı görevli kısır hayvan listede yok (mevcut açık-görev filtresi — davranış değişmedi). — D3 veri zemini
- [ ] **T5 (dry-run raporu):** `ilk_tohumlama_zamanlayici(p_dry_run:=true)` → kısır hayvan `acilacaklar` listesinde yok; kısır+tabansız hayvan `duve_tabansiz` sayacına katkı vermiyor; `taranan` sayısı kısır hayvanları içermiyor (sayı, kisir filtresiz koşumla kıyaslandığında kısır-adedi kadar düşük). — D5
- [ ] **T6 (öncelik/atıf):** kisir=true + son tohumlaması 'Gebe' olan hayvanda Başlat → `atlandi='KISIR'` (GEBE değil; §4.2 sıra kararının kilitlenmesi). — D2
- [ ] **T7 (regresyon):** `kisir=false` normal hayvanlar için mevcut R32-* blokları değişmeden PASS (özet `OZET: N PASS` — N, yeni bloklarla artar; mevcut N düşmez).

**Canlı demo — salt-okunur doğrulama (apply sonrası):**

- [ ] **T8:** 184/199/208 için `SELECT _acik_disi_ovsync_hedef(id)` üçünde de NULL (3/3); `_acik_disi_gorev_kur` dry önizlemesi NULL (koşum değil, salt fonksiyon çağrısı).
- [ ] **T9:** Açık OVSYNC_BASLAT sahiplerinde `kisir=true` sayısı = 0 (K12'nin migration sonrası tekrarı; **açık görev toplamı sabit beklenti DEĞİLDİR** — OBSERVED 2026-09-24: demo 29, prod 31, tarih-bağımlı; tek şart `kisir_acik=0`); `ovsync_baslat_uyarilari()` çıktısında tüm `uyarilar[].kisir=false`.
- [ ] **T10:** `ilk_tohumlama_zamanlayici(p_dry_run:=true)` çıktısında `acilacaklar` içinde kısırlı hayvan yok (184/199/208 kupe_no taraması).

**UI — sahip yürüyüşü (Plan 5 §3 checklist'ine ek madde):**

- [ ] **T11:** Protokol uyarı panelinde kısır hayvan satırında `▶ Başlat` YOK; `💲 Kısır işaretli — üreme planı yok` metni VAR; `✕` tıklaması görevi iptal ediyor ve listeden düşüyor. — D3
- [ ] **T12:** Görev listesinde OVSYNC_BASLAT kartı: kisir hayvanda Başlat yerine rozet; `kisir=false` hayvanda buton eskisi gibi. (Görünmez-durum testi: `ovsync_baslat_uyarilari` sadece hedef−2 günü listeler; kart tarafı her açık görevi gösterir.)
- [ ] **T13:** Hayvan kartında kısır rozet + ovsync başlatma butonu ÇELİŞKİSİZLİĞİ (U3 — kartta buton yokluğunun regresyon kontrolü).
- [ ] **T14:** `npm run test:unit` yeşil; ovsync unit testleri bozulmadı (plan-1 §8.5).

## 9. Geri-dönüş planı

1. **Sıra:** önce UI revert, sonra DB revert (görünüş önce düşer, davranış tek transaction'da döner).
2. **UI rollback:** `git revert <S1 ui.js+index.html commit'i>`; damga geri alınmazsa bile `?v=` eski değere döner (tek-değer kuralı).
3. **DB rollback (tek psql script, tek transaction):** dört gövdenin kisir-ÖNCESİ halleri `CREATE OR REPLACE` ile geri yazılır:
   - `_acik_disi_hedef_ic` → `20260924000002:L21-68` gövdesi (DIFF 1+2 geri);
   - `start_first_service_protocol` → `20260924000001:L662-845` gövdesi (KISIR ELSIF'i çıkarılmış mevcut zincir);
   - `ilk_tohumlama_zamanlayici` → `20260924000002:L99-295` gövdesi (DIFF A+B geri);
   - `ovsync_baslat_uyarilari` → `20260924000001:L1089-1120` gövdesi (`kisir` satırı çıkarılmış);
   - ACL satırları aynen; `NOTIFY pgrst, 'reload schema';`.
   Gövdeler repo'da mevcut olduğundan rollback script'i gerektiğinde anında yazılabilir; migration'ın kendisi DML/veri taşımaz → veri geri-dönüşü GEREKMEZ (INFERRED: yalnız fonksiyon tanımı; T2'deki test görevleri izole/ROLLBACK içinde).
4. **Doğrulama:** rollback sonrası T1(a) tersine döner (kısır hayvan kural tabanlıyken `_ic` NULL döndürmez), T4'te `kisir` alanı kaybolur, T8/T9 eskisine döner.
5. **Veri izi:** migration veri yazmadığından geri-dönüşte demo verisi temiz kalır; ileride koşulacak temizlik (Adım 3) iptal-işaretli kapamalar kullandığından (silme değil) onun da tersi `iptal=false` geri-alımıyla mümkündür — temizlik bu spec'in kapsamı değildir (§11).

## 10. Varsayımlar ve UNKNOWN

| # | Varsayım | Etiket |
|---|---|---|
| V1 | `kisir=true`, üreme planını bastıran otorite olarak alınır (S3 açık sorusu "kısır mı, tohumlama kaydı mı" sentez §9 madde 9'da sahibe Tur 2 başında sorulacak); M1/M2 tasarımı her iki cevapta güvenli — işaret kaldırılınca akış normal kurala döner | INFERRED (sahibin öneriye onayı beklemede; tasarım karara bağımlı değil) |
| V2 | 184/199'ın `hayvanlar.tohumlama_durumu='gebe'` (küçük harf) alanı MK3 otoritesi DEĞİL — otorite `tohumlama.sonuc` (K6'daki `v_son` sorgusu); bu alanların çelişkisi Plan 4 §5 normalizasyonuna ait | CONFIRMED (kod: K6) + UNKNOWN (demo `tohumlama` satırlarındaki gerçek sonuc değerleri — Adım 0 ölçümü bakar) |
| V3 | `hayvan_guncelle`'in "gebe hayvan kısır olamaz" validation'ı canlıda geçerli (K14) → demo'da kısır+Gebe(Büyük harf) kombinasyonu UI'dan kurulamaz; mevcut 184/199 çelişkisi geçmiş-veri | OBSERVED (canlı overload taraması) |
| V4 | pg_cron'un `ilk_tohumlama_zamanlayici()` çağrısı M3 sonrası sorunsuz çözülür (imza default'lu korunur, DROP yok) | INFERRED |
| V5 | Prod ortamında aynı dört fonksiyonun gövdeleri demo ile aynı — **bu tur doğrulamadı**; S1 demo-scope, prod apply ayrı sahip kararı | UNKNOWN (kapsam-dışı) |
| V6 | `cases`/`gorev_log` yazan üçüncü bir kısır-yolu yok (ör. başka RPC kısır hayvana ovsync vakası açmıyor): repo-grepti `_vaka_ac_tek`'in üç çağıranı var — (1) `start_first_service_protocol` (20260923000006:L528; gövde :L421-625 — M2 KISIR muafiyeti vakayı BURADA açılmadan bloklar), (2) `create_case` RPC sarmalayıcısı (20260906120000:L257 — vaka-açılış UI yolu), (3) `vaka_toplu_ac` toplu yolu (20260906120000:L522). (2)/(3) manuel operatör eylemleridir ve blok dışıdır (kullanıcı hayvanı elle vaka-aç'tan kurtaramaz varsayımı YOK — bilinçli kapsam kararı, manuel vaka açma operatör eylemidir; S3 temizlik dry-run'ı bu yollardan kalanları da görür) | CONFIRMED (grep: `20260923000006:L528`, `20260906120000:L257,L522`) + kapsam kararı |
| V7 | Eşzamanlı 10 agent: zarf-dışı dosyaya S1 yazmaz; migration numarası tek-atama (koşum anında `ls` ile boş numara alınır); ui.js Plan 3 ile sıralı (§5 not) | kural |
| V8 | TÜM demo ölçüm/apply işlemleri demo kanalından yapılır (`/home/melik/egesut-erp1/.env` → `SUPABASE_DEMO_REF`+`SUPABASE_DEMO_PAT` Mgmt API query endpoint veya demo pooler psql); tools-bank `supabase_*` araçları PROD ref'ine (zqnexqbdfvbhlxzelzju) bağlıdır ve S1'de HİÇBİR adımda kullanılmaz (okuma dâhil) | CONFIRMED `~/tools-bank/mcp_server/server.py:307-312` + `js/api.js:23-24` (onarım turu) |

## 11. Kapsam-dışı bağlantılar (çakışma emniyeti)

1. **Kısır temizliği (sahibin "evet" kararı, sentez §9 S1):** üç AÇIK vaka `f72f320c` (184), `37b98c0c` (208), `19febaa1` (199) + bağlı "Gun 1" TEDAVI_GUN/SEANS görevleri — Tur 2 **Adım 3**'te dry-run liste onaylı koşum (sentez §3). **Demo/prod sapması (onarım turu):** üç vaka PROD'da `protocol_family='OVSYNC'`, DEMO'da `protocol_family=NULL` — demo tarafında bunlar "aktif senkron vakası" muafiyetini TETİKLEMEZ; Adım 3 temizlik spec'i dry-run listesini family alanından bağımsız (id + animal_id üzerinden) kurmalı. Bu migration temizliği BEKLEMEZ: M1 kısır kontrolünü aktif-vaka kontrolünden ÖNCE koyduğu için kısırla işaretli hayvan vaka durumundan bağımsız üretim dışında kalır. Temizlik ayrı operasyon-spec (Adım 3 zarfı); silme değil `iptal`/`closed` işaretlemesi.
2. **188 çift zincir KASITLI (sahip kararı):** S1 yalnız OVSYNC_BASLAT üretim/başlatma/UI'ya dokunur; ILAC/PG zincirlerine ve 188'in açık OVSYNC_BASLAT'ına (demo OBSERVED: `bcd5fe9d…`, hedef 2026-10-06; v1.0'daki `f5124a14` id'si bayat — iki kanalın açık listesinde de yok) dokunmaz (K12).
3. **S3 (gebe/kısır otorite), sessiz eşiği 50, Bekliyor ≥40 muayene görevi, "Ovsynch-56" adı + TAI balonu, erteleme geneli, T9 kuyruk borcu:** sırasıyla Plan 4 / Plan 3 / Plan 2 / BUGS.md borç kayıtları — bu spec'in zarfında DEĞİL.

## 12. Uygulama sırası ve kapılar (implementer için)

1. **Pre-check:** `code-change-precheck` + gitnexus indeks-HEAD eş kontrolü; impact: `start_first_service_protocol`, `ovsync_baslat_uyarilari`, `_acik_disi_hedef_ic`, `_ovsyncBaslatBtnHtml` (upstream).
2. **Migration taslağı** (§6) → `bash scripts/db-validate.sh supabase/migrations/20260925000001_ovsync_kisir_blok.sql` (taslak) — db-validation kapısı.
3. **Kabul blokları** (§8 T1-T7) tests dosyasına APPEND → izole koşum PASS (sarmalayıcı `BEGIN…ROLLBACK`; `OZET` sayacı).
4. **Demo apply** (sahip onaylı) → T8-T10 salt-okunur doğrulama → **final dosyada db-validate tekrar** (apply-öncesi final şartı).
5. **UI** (§7 iki nokta + damga) → `gitnexus detect_changes` → commit (branch: `ovysch-feature-cila-turu`; mesaj sonuna Co-Authored-By satırı).
6. **Commit** her anlamlı adımdan sonra; son review kapısı ayrı ajanın — bu spec'i uygulayan, review'ı beklemeden teslim paketini (migration + tests + ui + kanıt çıktıları) tamamlar.

---

## 13. Onarım turu kaydı (1.1 — 2026-09-24; iki geçişli onarım, BULGULAR alanı boş dönünce çift-kanal yeniden doğrulama)

Review bulguları orkestratöre düşmediğinden (BULGULAR alanı boş) spec+plan repodan ve canlı şemadan TEK TEK yeniden doğrulandı. İki geçiş birleştirildi: ilk geçiş repo çapalarını (R1-R6, plan tarafında), ikinci geçiş **kanal doğrulamasını** getirdi — tools-bank `supabase_*` kanalının PROD olduğu (demo sanılmıştı) tespit edildi ve tüm "(demo)" etiketli OBSERVED kanıtlar gerçek demo kanalından yeniden ölçüldü.

| # | Sapma (v1.0) | Düzeltme (v1.1) | Kanıt |
|---|---|---|---|
| 1 | §5/§8'de kabul blok etiketi "R32-11" olarak kalmıştı; o etiket dosyada zaten dolu | §5 satır 2 ve §8 başlığı `S1-T1…T6` etiketine alındı (T7 ayrı blok değil); R32-11 blok aralığı `:1682-1697` | CONFIRMED `supabase/tests/ovsync_pg_kabul.sql:L1682-1697` (grep: `-- R32-11` :1682, `PASS R32-11` NOTICE :1696, takip blok yorumu :1699) |
| 2 | §7.3 hayvan kartı çapası :L1597 (fonksiyon içi satır) | `:L1595` (fonksiyon tanım satırı) olarak netleştirildi | CONFIRMED `js/ui.js:L1595` (grep) |
| 3 | §8 T3 "kb_hayvan 1500 günlük" örneği planla (800 günlük) çelişiyordu | T3 tek değere (800 günlük, plan S1-T3 ile aynı fixture) standardize edildi; her iki değerin de düve tabanı (dogum_tarihi+12a21g) verdiği ayrıca doğrulandı | CONFIRMED `supabase/tests/ovsync_pg_kabul.sql:L49-57` (dogum_tarihi = CURRENT_DATE − p_yas_gun) |
| 4 | **KANAL HATASI:** v1.0'ın "(demo, 2026-09-24)" etiketli OBSERVED kanıtları (K1-K3, K12-K14 ve canlı gövde ölçümleri) tools-bank `supabase_*` üzerinden alınmıştı; o kanal **PROD**'a bağlı — demo değil | Kanal kuralı bağlayıcı yazıldı (başlık + V8 + §8 ortam notu + plan Adım 0/3/5): demo okuma/apply yalnız `SUPABASE_DEMO_REF`+`SUPABASE_DEMO_PAT` Mgmt API veya demo pooler psql ile; tools-bank `supabase_*` S1'de hiçbir adımda kullanılmaz | CONFIRMED `~/tools-bank/mcp_server/server.py:307-312` (`SB_PROJECT="zqnexqbdfvbhlxzelzju"`) + `js/api.js:23-24` (PROD_URL=zqnex…, DEMO_URL=vtzq…); demo kanalı `/home/melik/egesut-erp1/.env:10-14` |
| 5 | K3 demo'da YANLIŞTI: üç vakanın `protocol_family='OVSYNC'` olduğu yazılıyordu; demo'da üçü de `protocol_family=NULL` ('OVSYNC' değeri PROD'dan geliyordu) | K3 ve §11.1 düzeltildi: demo'da bu vakalar "aktif protocol_family" muafiyetini TETİKLEMEZ; M1 kısır kontrolü yine bloklar; S3 temizlik spec'ine family-bağımsız dry-run notu düşüldü | OBSERVED demo kanalı `cases id IN (f72f320c…,37b98c0c…,19febaa1…)` → 3/3 `status='active', protocol_family=NULL`; PROD kanalı aynı id'ler → `protocol_family='OVSYNC'` (2026-09-24) |
| 6 | K12 "tam 31 görev" sabit-sayı gibi yazılmıştı; 31 PROD sayısıydı (kanal hatası) | K12 ve T9 düzeltildi: adet tarih-bağımlı (OBSERVED demo 29, prod 31); tek şart `kisir_acik=0`; 188 açık hedef 2026-10-06 iki kanalda da doğrulandı | OBSERVED demo kanalı agregat: `acik_toplam=29, kisir_acik=0, 188 hedef=2026-10-06`; PROD kanalı: 31 satır (2026-09-24) |
| 7 | Canlı gövde "birebir (demo)" iddiaları kanalsızdı | Dört fonksiyon gövdesi (dördüncü olarak wrapper delegasyonu) demo kanalından çekilip repo bloklarıyla normalize-diff ile karşılaştırıldı: **birebir aynı** — M1/M2/M3/U1 kopya-temelleri sağlam | OBSERVED demo `pg_get_functiondef` (`~/tmp/s1-onarim-demo-govdeler.json`, 2026-09-24) vs `20260924000002:L21-68,L99-295` + `20260924000001:L662-845,L1089-1120` |
| 8 | S1-T5'in elle `hayvanlar` INSERT'i (dogum_tarihi'siz) şema riski taşıyordu (kabul DB'si prod-şemadan kuruluyor) | Güvenli: `hayvanlar`'da default'suz NOT NULL tek kolon `id` — INSERT kolon seti yeterli; `gorev_log`/`tohumlama`'da zorunlu kolon yok; `cases`/`islem_log`/`protokol_ayar` zorunluları testlerin sadece okuduğu/UPDATE'tlediği alanlar | OBSERVED demo `information_schema.columns` (is_nullable='NO' AND column_default IS NULL), 2026-09-24 |
| 9 | §9 rollback `start_first_service_protocol` çapası :L662-846 (boş satırı içeriyordu) | `:L662-845` ($fn$; satırı) olarak netleştirildi | CONFIRMED `20260924000001:L844-845` |
| 10 | V6 `_vaka_ac_tek` çağıran-enumerasyonu eksikti ("yalnız start_first_service_protocol + vaka-açılış UI"): `create_case` sarmalayıcısına ek olarak `vaka_toplu_ac` toplu yolu (20260906120000:L522) da çağırıyor; plan Adım 0'daki `start_first_service_protocol` beklenen-arayan satırı da `js/forms.js` diyordu — gerçek çağıran `js/ui.js:1176` (`ovsyncBaslat`), forms.js'te arayan yok (yalnız `js/api.js:320` RPC→tablo etki haritası) | V6 üç çağıranı da açık numaralandı (2)/(3) manuel-yol kapsam kararı korunarak; plan Adım 0 satırı düzeltildi | CONFIRMED `20260923000006:L528` (start gövdesi :L421-625), `20260906120000:L257,L522`, `grep -n ovsyncBaslat js/ui.js` (:L1176 rpc; forms.js/api.js'de çağrı yok) — üçüncü onarım geçişi 2026-09-24 |

İlk geçişte ölçülüp SAĞLAM çıkan kanıtlar (değişiklik gerekmedi): K1 (184/199/208 `kisir=true`, Aktif, Dişi — demo'da birebir), K2 (üç kapalı görev id+kapatan_ref — demo'da birebir), K4/K6/K7/K8 repo çapaları, K9-K11/K15/K16 UI/kabul/damga çapaları, K13/K14 demo kanalında teyitli (`hayvan_ekle`+`tohumlama_sonuc_bos` kancaları; `hayvan_guncelle`+`hayvan_tohumlanabilir_onayla` kısır guard'ları), `?v=20260924-01`=26 tektip satır + `fe5f91d` öncekilği, unit-sandbox `getState` yokluğu (plan 4a sapması CONFIRMED), `20260925` migration-numarası boş, bayrak anahtarı `ovsync_pg_kurallari_aktif` (`20260923000002:L64`), `kaynak LIKE 'ACIK-DISI-%'` (`20260924000001:L334`). Plan tarafındaki karşılık giderimler: plan-s1.md §"Onarım turu kaydı" (R1-R6 repo-çapa geçişi; R7 kanal doğrulaması + T9 beklentisi; R8 M2 yapı notu; R9 kabul-şema/S1-T5 INSERT güvenliği — bu tablonun 4/6/8. satırlarının plan karşılığı).

---

*Spec sonu. Yazım yetkisi yalnız `docs/plans/2026-09-24-ovsync-cila/` ile sınırlıydı; koda dokunulmadı. Kanıtlar 2026-09-24 tarihinde canlı repo (HEAD: bacf648 üstü çalışma kopyası) + salt-okunur DB sorgularıyla toplandı; 1.1 onarım turunda repo çapaları ve tüm DB kanıtları çift kanalla (demo `vtzqjmazsvurxdeondmi` + karşılaştırma için prod `zqnexqbdfvbhlxzelzju`, yalnız SELECT) yeniden doğrulandı.*
