# impl-P3b-DONE — TAMAM

- **Goal:** `G-20260930-OVSYNC-TAKIP-IMPL` · **Plan madde:** P3b (plan.md:399-457, birebir; plan satırları imza tablosu + MK9-G kilit grafiği + H geri alımları dahil eksiksiz okundu)
- **GOREV:** `runs/2026-09-28-ovsync-takip/impl-P3b-GOREV.md` · **Tarih:** 2026-09-30
- **Sonuç:** 8/8 kabul kanıtlı — **TAMAM** (2 self-repair turu kullanıldı — sınır 2; her ikisi de prova'da yakalanan gerçek migration hatası, ayrıntı "Self-repair izi"nde)
- **Zorunlu protokol:** domain-rules.md SQL'den önce okundu (çelişki yok — §18.15/§18.17 P3b'nin dayanağı) · canlı zemin: **7 RPC'nin TÜM gövdeleri pg_get_functiondef ile demo'dan okundu** (2026-09-30, `/home/melik/tmp/agents/p3b-live/*.sql`; imzalar plan.md:413-419 tablosuyla birebir [OBSERVED]) · PostgreSQL LSP: `postgrestools check` → "Checked 1 file", exit 0 [OBSERVED] · db-validate worktree içi yol.

## Yazılan dosyalar (manifest 2/2 — TEK YAZICI)

1. `supabase/migrations/20260929000003_takip_kapanis_tetikleyicileri.sql` (MODIFY — P3a bölümü satır 1-312 AYNEN korundu; P3b bölümü satır 315-2048 eklendi; SHA-256 ilk 8: `c22244db` [OBSERVED sha256sum; nihai db-validate raporuyla aynı]). İçerik: H6 gorev_tamamla guard'ı (imza değişmez) · D4 tekil preflight (hizli/seans, birleşik payload dahil) · D4 bulk satır-sonucu (bulk_ilac + vaka_toplu_ac: `takip_acik[]`, bulk'a ek `takip_onay_listesi[]`) · MK9 start_first yeniden-yapısı · C4 kizginlik fail-closed kapısı · C2 7 RPC imza geçişi (eski overload DROP + yeni CREATE) · C5 ACL (7× REVOKE PUBLIC,anon + GRANT authenticated,service_role) · `NOTIFY pgrst, 'reload schema'`.
2. `runs/2026-09-28-ovsync-takip/impl-P3b-DONE.md` (bu dosya).

Manifest dışı repo yazımı YOK [OBSERVED `git status --porcelain` → yalnız yukarıdaki M + zaten-var-untracked GOREV]. Prova betikleri repo dışında: `/home/melik/tmp/agents/p3b-live/` (canlı gövde dökümleri + prova), `/home/melik/tmp/agents/p3b-t72b.sh` + `p3b-t72b-sonuc.txt` (T-72b). [OBSERVED `git diff --check` → boş, exit 0] (kabul 8).

## Kabul maddeleri (8/8)

### 1) db-validate.sh (worktree yolu) — PASS

[OBSERVED `TMPDIR=~/tmp SS_TMP_ROOT=~/tmp bash scripts/db-validate.sh supabase/migrations/20260929000003_….sql --priors supabase/migrations/20260929000002_….sql` → "SONUÇ: PASS"; nihai rapor `reports/db-validation-c22244db.md`, SHA `c22244db` = teslim dosyası]. Kriterler: A sqlfluff-parse PASS · A squawk PASS (0 ihlal) · B şema-uyum PASS · C1 baseline-restore+priors+apply+postcheck-nesne+postcheck-rls+parite PASS (T=55 F=256 V=13, parite uyumlu, PG 17.6/17.6) · C2 sentetik-tohum+veri-uyumluluk PASS. Not: ilk koşum INCONCLUSIVE idi (statik çözümleyici pg_catalog nesnelerini çözemiyordu: `jsonb_array_elements`, `jsonb_to_recordset`, `pg_proc`, `unnest`, `IS DISTINCT FROM true` metni) → P3b bölümünde pg_catalog nitelemesi + `(true)` parantezine geçildi — semantik birebir, 2. koşum PASS [OBSERVED].

### 2) gorev_tamamla üç dal kapsama matrisi — 5/5

[OBSERVED demo prova (`p3b-live/prova1.sh`), tümü ROLLBACK'li blokta]:

| Dal | Sonuç |
|---|---|
| (1) tamamlama + GEBELIK_KONTROL | `MUAYENE_SONUC_GEREKLI:GEBELIK_KONTROL` (P0001) — guard [CONFIRMED migration:396-407, kilitsiz okuma FOR UPDATE'ten ÖNCE] |
| (1b) tamamlama + TAKIP_MUAYENE | `MUAYENE_SONUC_GEREKLI:TAKIP_MUAYENE` (P0001) |
| (2) `p_iptal=true` (T5) | `{ok:true, iptal:true}` + db `iptal=t, tamamlandi=t, tamamlanma_tarihi dolu` — T5 dalı AYNEN (js/ui.js:1841-1844 offline replay) |
| (3) SUTTEN_KESME | `{ok:true, sutten_kesme:true}` — dal AYNEN |
| (3b) padok dalı (PADOK_DEGISIM + p_padok_hedef) | `{ok:true, padok_guncellendi:true}` + hayvan `padok='Sağmal Padok'`, `padok_id dolu` — dal AYNEN |

**REST kanıtı (kabul sözü "REST'ten"):** authenticated demo token ile [OBSERVED `p3b-live/rest.sh`]: POST `/rest/v1/rpc/gorev_tamamla {p_gorev_id}` (gerçek GEBELIK_KONTROL fikstürü) → **HTTP 400, `{"code":"P0001","message":"MUAYENE_SONUC_GEREKLI:GEBELIK_KONTROL"}`**; aynı görev `p_iptal:true` ile → **HTTP 200 `{ok:true, iptal:true}`** + db doğrulandı; fikstür sonrası silindi.

### 3) D4 — üç yol preflight İLK YAZMADAN ÖNCE — PASS

[OBSERVED demo prova (`prova1/prova2/prova3.sh`), ROLLBACK'li]:

| Yol | Onaysız (takip açık) | İlk-yazma kanıtı | Onaylı retry |
|---|---|---|---|
| `hizli_uygulama` | `TAKIP_ACIK:{"muayene_saat":"09:30:00","muayene_tarihi":"2026-10-07"}` (P0001) | `uygulama_log` satır sayısı **0** | `p_takip_onay=true` → `{ok:true}` + uygulama_log **1** + takip `iptal=t, neden=PG` |
| `seans_tamamla` | `TAKIP_ACIK:{...}` (P0001) | `tdu.uygulama_tamamlandi_at IS NULL` + `uygulanmadi=f` (yazma yok) | `p_takip_onay=true` → `{ok:true, seans_done:true, gun_tamam:true}` + neden=PG |
| `bulk_ilac` | satır İŞLENMEZ (aşağıda) | `islem_log` B1 **0** | alt-küme retry → B1 applied **1** + neden=PG |

**Birleşik payload (D4, `PG_KAPI:TAKIP_ACIK`):** takip açık + son tohumlama `Bekliyor` + PG ürünü hayvanında onaysız çağrı → `PG_KAPI:TAKIP_ACIK:{"pg_kapi":{gun:5, sperma:null, kupe_no:…, deneme_no:1, hayvan_id:…, urun_durumu:"PG", tohumlama_id:…, tohumlama_sonuc:"Bekliyor", tohumlama_tarihi:…}, "takip_acik":{"muayene_saat":"09:40:00","muayene_tarihi":"2026-10-07"}}` [OBSERVED] — P2b sarmal deseniyle birebir [CONFIRMED 20260929000002:986-998 karşılaştırması]. Tek çağrı retry `p_pg_onay=true + p_takip_onay=true` → `{ok:true}` + neden=**PG** [OBSERVED] — "tek onay penceresi iki gerekçe" sözleşmesi. Red anında uygulama_log 0 (ilk-yazmadan-önce [CONFIRMED migration:590-625 hizli, 758-800 seans — _pg_kapi çağrı noktasının yanı; sıra korunur]).

**Bulk satır-sonucu deseni:** `bulk_ilac([B1(onaysız-takipli), B2(onaylı)], …, p_takip_onaylar=[B2])` → `success=1`, `applied` yalnız B2, `takip_acik[]` = `[{hayvan_id:B1, kupe_no:…, kod:"TAKIP_ACIK", muayene_saat:…, muayene_tarihi:…}]`, `takip_onay_listesi` = `[{hayvan_id:B1, pg_kapi_karar:"ALLOW", takip_acik:true, takip_bilgi:{muayene_saat:…, muayene_tarihi:…}}, {hayvan_id:B2, …}]` [OBSERVED — alan adları H5 tablosunda sabit]; islem_log B1=0 / B2=1; B1 takibi AÇIK kaldı, B2 `neden=PG`. **Retry = onaylı alt kümeyle yeni çağrı** `bulk_ilac([B1], …, p_takip_onaylar=[B1])` → success=1 + B1 takibi kapandı [OBSERVED]. Stok `v_success` üzerinden (mevcut UPDATE [CONFIRMED gövde] değişmedi); döngü/kilit davranışı değişmedi (ön-geçiş + kapı yalnız EK adım — kilitsiz keşif [CONFIRMED migration:898-1005]). `vaka_toplu_ac` aynı desen: onaysız → `ok:true, basari=0, acilan=[], takip_acik:[{hayvan_id, kupe, kod:"TAKIP_ACIK", …}]`, cases'e satır DÜŞMEZ, takip açık kaldı; onaylı retry → basari=1 + vaka + neden=OVSYNC [OBSERVED]. **Küme uyuşmazlığı:** liste-dışı id → `TAKIP_ONAY_KUME_UYUMSUZ:{"liste_disi_id":"…"}` her iki dizi yolunda [CONFIRMED migration:917-922, 1618-1624; OBSERVED bulk RAISE].

### 4) C4 — kizginlik_vaka_ac tanıdan-bağımsız fail-closed kapı — PASS

[OBSERVED demo prova]: takipli hayvanda `kizginlik_vaka_ac('e2e-p3b-kiz-1', 'Mastit')` (onaysız) → `TAKIP_ACIK:{muayene_saat:…, muayene_tarihi:…}` red + cases'e satır **DÜŞMEZ** (count 0) — tanıdan bağımsız (Mastit, Ovsync-olmayan tanıyla red — tetikleyici ağı bu yolda KAÇARDI, kapı gövdede [CONFIRMED migration:1948-1968]). Onaylı (`p_takip_onay=true`) → `{ok:true, case_id:…}` + vaka 1 + takip `iptal=t, takip_kapanis_nedeni=OVSYNC` [OBSERVED]. H4 deseni gövdede: kilitsiz keşif + aynı hızlı ret → hayvan NKU → kızgınlık satırı FOR UPDATE + yeniden doğrulama → eski kaskad birebir [CONFIRMED migration:1924-1990].

### 5) C5 — imza geçişi — PASS (kayıtlı gerçek yanıtlar)

- **Eski overload yok:** `to_regprocedure` ile 7 eski imzanın HEPSI NULL (uygulama sonrası) [OBSERVED]; `pg_proc` sayısı 7 RPC'de 7×1 (tek imza) [OBSERVED]. Yeni imzalar 7/7 mevcut [OBSERVED].
- **anon EXECUTE yok:** 7 RPC × `has_function_privilege('anon'|'public', …) → f` [OBSERVED, apply sonrası]; REST anon çağrı → **HTTP 401 `{"code":"42501","message":"permission denied for function gorev_tamamla"}`** [OBSERVED, kayıtlı].
- **Yeni imza çalışır:** `p_takip_onay` DEĞERİNİN etki ettiği redler REST'ten değil SQL prova'sından 6 yüzeyde kanıtlandı (§3, §4); REST yeni-imza çağrıları fonksiyona ulaşıyor (aşağıdaki kayıtlar).
- **Kayıtlı gerçek PostgREST yanıtları (demo, authenticated token; assertion bu kayıtlara sabitlendi — plan.md:450 "kayıt öncelikli" maddesi):**
  1. `gorev_tamamla` eski-argüman-seti (bogus id) → **HTTP 400, 22P02** "invalid input syntax for type uuid" — fonksiyona ulaştı (tek imza; guard'lı yeni gövde).
  2. `hizli_uygulama` ESKİ 9-arg seti (bogus hayvan) → **HTTP 200** `{ok:false, mesaj:"Hayvan bulunamadı veya aktif değil"}`.
  3. `create_case` ESKİ 3-arg seti (bogus hayvan) → **HTTP 200** `{ok:false, mesaj:"Hayvan bulunamadı veya aktif değil"}`.
  4. `hizli_uygulama` + bilinmeyen argüman (`p_yok_argument`) → **HTTP 404, `PGRST202`** "Could not find the function public.hizli_uygulama(p_hayvan_id, p_yok_argument) in the schema cache" — planın öngördüğü PGRST202/404 red BİLİNMEYEN-argüman çağrısında kaydedildi.
  - **Ruling (plan.md:450 öngörü düzeltmesi):** plan "eski parametre setiyle REST çağrı → PGRST202/404" öngörüyordu; gerçek: 7 imza geçişinin hepsi EKLEMELİ + DEFAULT'lu olduğu için eski set, yeni imzaya DEFAULT ile çözünüyor (200/iş hatası — 2/3. kayıtlar). PGRST202 sadece eşleşmeyen imzada üretiliyor (4. kayıt). Eski overload'un gerçekten kalktığı kanıtı SQL kataloğundadır (to_regprocedure 7/7 NULL) — REST yüzeyinde eski-set çağıran (mevcut JS) hiçbir kırılma yaşamaz (C2'nin geriye-uyumluluk amacıyla uyumlu). Maliyeti: P10'da eski-set çağrının sessizce yeni davranışa düşmesi — beklenen davranış.

### 6) T-72b NİHAİ 5 çift × 30 tur — PASS (0 yasak-olay)

[OBSERVED `/home/melik/tmp/agents/p3b-t72b.sh` → `p3b-t72b-sonuc.txt`; demo DB, her tur taze fikstür + iki bağlantılı psql oturumu, `SET lock_timeout='5s'`, oturum-başı sıra A/B döner, SQLSTATE yakalayan DO blokları]:

| Çift | Sonuç |
|---|---|
| sarmal × `tohumlama_kaydet` | 30/30 tur — **0× 40P01/55P03** |
| sarmal × `start_first_service_protocol` (düzeltilmiş gövde) | 30/30 — **0×** |
| sarmal × `seans_tamamla` | 30/30 — **0×** |
| sarmal × `vaka_toplu_ac` | 30/30 — **0×** |
| kapanış tetikleyicisi × sarmal | 30/30 — **0×** |

**TOPLAM: 0 yasak-olay (40P01/55P03/oturum-arızası) — 150 tur** [OBSERVED `ÇİFT n: 0 yasak-olay / 30 tur` ×5 + `TOPLAM: 0`]. **İzinli küme dağılımı [OBSERVED uniq]:** `OK` (başarı; 30+17+16+14+16+14 taraf-çifti) ve `P0001 TAKIP_ACIK:ZATEN_ACIK` (belgelenmiş iş hatası — sarmalın `_takip_gorev_kur` guard'ı) — küme dışı sonuç yok. Oracle hedefi goal'in ertelenmiş sözleşmesi (§10h H7); "önce kırmızı" şartı yok (H7) — uygulanmadı.

### 7) H5 — TAKIP_ACIK alan adı tablosu (makine-okunur; P10 bu tabloya bağlanır)

| # | Yüzey | Mesaj kalıbı | Payload alanları (tümü sabit) |
|---|---|---|---|
| 1 | P2b sarmal (değişmedi) | `TAKIP_ACIK:{json}` | `muayene_tarihi` (date), `muayene_saat` (time) |
| 2 | P2b sarmal birleşik (değişmedi) | `PG_KAPI:TAKIP_ACIK:{json}` | `{pg_kapi: {…_pg_kapi_detay}, takip_acik: {muayene_tarihi, muayene_saat}}` |
| 3 | P3a tetikleyiciler (değişmedi) | `TAKIP_ACIK:{json}` | `muayene_tarihi`, `muayene_saat` |
| 4 | P3b D4 tekil — yalnız takip engeli (hizli/seans) | `TAKIP_ACIK:{json}` | `muayene_tarihi`, `muayene_saat` |
| 5 | P3b D4 tekil — birleşik (hizli/seans) | `PG_KAPI:TAKIP_ACIK:{json}` | `{pg_kapi: {…detay; seans'ta +`seans_admin_id`, `case_id`}, takip_acik: {muayene_tarihi, muayene_saat}}` |
| 6 | P3b vaka yolları (`create_case`, `vaka_toplu_ac`, `kizginlik_vaka_ac`, `start_first_service_protocol`) | `TAKIP_ACIK:{json}` | `muayene_tarihi`, `muayene_saat` |
| 7 | `bulk_ilac` dönüş anahtarı **`takip_acik[]`** (satır sonucu) | satır objesi | `{hayvan_id, kupe_no, kod:"TAKIP_ACIK", muayene_tarihi, muayene_saat}` |
| 8 | `vaka_toplu_ac` dönüş anahtarı **`takip_acik[]`** (satır sonucu) | satır objesi | `{hayvan_id, kupe, kod:"TAKIP_ACIK", muayene_tarihi, muayene_saat}` (mevcut listelerle aynı `kupe` adı) |
| 9 | `bulk_ilac` dönüş anahtarı **`takip_onay_listesi[]`** (hayvan-bazlı birleşik onay listesi) | satır objesi | `{hayvan_id, pg_kapi_karar, takip_acik (bool), takip_bilgi ({muayene_tarihi, muayene_saat} \| null)}` |
| 10 | `gorev_tamamla` guard | `MUAYENE_SONUC_GEREKLI:{gorev_tipi}` | düz-metin suffix: `GEBELIK_KONTROL` \| `TAKIP_MUAYENE` |
| 11 | dizi-yolu küme uyuşmazlığı | `TAKIP_ONAY_KUME_UYUMSUZ:{json}` | `{liste_disi_id}` |

Notlar: (a) jsonb çıktısında anahtar sırası alfabetiktir (`muayene_saat` önce basılır — P3a-DONE açık kalem 2 aynen); (b) takip nedeniyle İŞLENMEYEN bulk satırı `blocked[]`/`requires_ack[]`'e GİRMEZ — yalnız `takip_acik[]` (P10 için sözleşme notu); (c) kapanış nedeni değerleri: D4 yolları `PG`, vaka yolları `OVSYNC` (P2a sözleşmesi; `_takip_kapat` tek yazıcı).

### 8) `git diff --check` — TEMİZ

[OBSERVED exit 0, boş çıktı].

## MK9-G / kilit sözleşme doğrulamaları (zarf maddeleri)

- **H1 geri alımları:** `create_case`/`vaka_toplu_ac`/`gorev_tamamla`/`tohumlama_sonuc_bos` gövdelerinde kilit düzeni DEĞİŞMEDİ — create_case yalnız kapı öncesi kilitsiz keşif aldı [CONFIRMED migration:1362-1395]; vaka_toplu_ac döngü/kilit aynen (yalnız başta kilitsiz keşif döngüsü + CONTINUE) [CONFIRMED migration:1631-1700]; gorev_tamamla yalnız guard (kilit sırası: gorev_log FU ilk — aynen) [CONFIRMED migration:396-419].
- **MK9 start_first (plan.md:424-428):** görev KİLİTSİZ okunur → hızlı retler aynı sırada (`GOREV_BULUNAMADI` [OBSERVED], `GOREV_TIPI_UYUMSUZ` [OBSERVED], zaten-kapalı dönüşü aynı şekil `{"ok":true,"iptal":false,"zaten":true,…}` [OBSERVED], `OVSYNC_ERKEN` [OBSERVED]) → hayvan `FOR NO KEY UPDATE` İLK kilit → protokol_instance okuması hayvan kilidinden sonra → görev `FOR NO KEY UPDATE` + tip/tamamlandi/iptal yeniden doğrulama → muafiyet zinciri birebir → akış `v_g2` üzerinden birebir [CONFIRMED migration:1146-1215]. Eski AB/BA dizisi (görev FU→hayvan FU) kalktı; kanıt: T-72b çift 2 (sarmal × start_first) 30/30 temiz.
- **MK9-N:** hayvan kilidi her yeni/değişen yüzeyde `FOR NO KEY UPDATE` (start_first, kizginlik) — `FOR UPDATE` yok [CONFIRMED gövdeler].
- **Dizi yolu kısıtları:** `p_takip_onaylar` ⊆ `p_animal_ids` (sessiz yok-sayma yok); boyut/satır sınırı YOK eklendi (mevcut 200 aynen); stok `v_success` üzerinden aynen [CONFIRMED].

## Self-repair izi (2/2 tur; her ikisi prova'da yakalandı, migration değişti)

1. **Tur 1 — FOUND-ezilmesi:** bulk_ilac ve seans_tamamla'nın taze preflight'ında takip SELECT'inden sonraki ara `SELECT kupe_no` FOUND'u eziyordu (birleşik/yalnız-takip dalları yanlış karar verirdi). FOUND `v_takip_var` boolean'ına SELECT'ten hemen sonra yakalandı. Demo apply'dan ÖNCE yakalandı (statik inceleme), prova öncesi düzeltildi.
2. **Tur 2 — bulk İŞLENMEZ bozuk:** 1. prova koşumunda onaysız-açık-takipli hayvan `v_pg_kapilar`'a girip İŞLENİYORDU (applied'da görünmesi, islem_log 1, satır-sonucu sözleşmesi ihlali — [OBSERVED ilk koşum]). Düzeltme: `v_takip_islenenmez` kümesi + ALLOW dalında işlem dışı bırakma [CONFIRMED migration:981-1005]. 2. koşum: applied yalnız onaylı, islem_log B1=0, takip açık kaldı [OBSERVED]. Sonrasında dosya sabit (`c22244db`, nihai validate bu SHA'da).

Prova-betik tarafı düzeltmeler (migration sabit, sayaç dışı — P3a örneği): T-72b setup'ında eksik `COMMIT` (fikstür görünmez oluyordu; 1. koşum çöp üretti, 2. koşum temiz); birleşik-red fikstüründe tohumlama/takip sırası (tohumlama SONRA gelirse P3a YENI_TOHUMLAMA tetikleyicisi takibi fixture-anında kapatıyor — gerçek akış sırasıyla "önce tohumlama, sonra takip" kuruldu).

## Rulings (executing-plans; her biri kayıtlı)

1. **C5 PGRST202 öngörüsü vs gerçek** — yukarıda kabul 5; kayıt-öncelikli madde uygulandı.
2. **start_first onaylı kapanışın tam-zincir kanıtı demo'da yok** — demo `tedavi_sablonu` OVSYNC aktif **0** [OBSERVED] → onaylı çağrı kapıyı geçip şablon red'ine düşüyor (OVSYNC_SABLON_BELIRSIZ) ve transactional olarak kapanış geri alınıyor. Kapının RED yolu [OBSERVED TAKIP_ACIK], onaylı kapanış primitifi `_takip_kapat(neden='OVSYNC')` 6 diğer yüzeyde [OBSERVED] ve kod-sırası [CONFIRMED migration:1233-1250] ile kanıtlı. Maliyeti: demo E2E (P12) öncesi şablon seed'i gerekir — mimar karar noktası (aşağıda açık kalem).
3. **gorev_tamamla guard'ı zaten-kapalı muayene görevine de uygulanır** (fonksiyon başında, FOR UPDATE'ten önce): "bu tipler yalnız muayene RPC'siyle kapanır" sözleşmesinin tamamlayıcısı; re-call artık `MUAYENE_SONUC_GEREKLI` döner (eski: 'zaten tamamlanmış'). Tek kilitsiz okuma; T5/iptal ve diğer tipler etkilenmez. Maliyeti: muayene tipi kapanmış görevin tekrar-tamamlama çağrısı farklı mesaj alır (UI P10 mesajı zaten bu koda bağlanacak).
4. **vaka_toplu_ac küme-doğrulaması mevcut fail-fast'lerden SONRA** — mevcut hata öncelikleri (boş liste → 200 → şablon/manuel → tarih → tohumlama → çakışma → items) korunur; liste-dışı onay yalnız diğerleri geçen çağrıda raise eder. Maliyeti: ikisi birden bozuksa önce mevcut mesaj görülür.
5. **D4 preflight bayrak-açık dalında** (hizli/seans, `_pg_kapi` çağrı noktasının yanı — plan.md:408 "yanına"); bayrak kapalıyken RPC'ler eski davranışta (MK5) ve sarmal bayrak-kapalıyken takip görevi kuramadığından (P2b) ileriye açık takip oluşamaz. Maliyeti: bayrak kapatılıp açık takip bırakılırsa RPC yolları kapısız yazar — P3a tetikleyicileri + MK9-K kapsamında (bilinen tasarım).
6. **start_first gövde sırası fizikselleştirmesi:** hayvan NKU → görev NKU + revalidate → protokol okuma → muafiyet → takip kapısı → şablon/zincir. Planın adım listesi (kilitsiz okuma → hayvan İLK kilit → görev yeniden kilit → muafiyet güncellemeleri) birebir; protokol okumasının hayvan kilidinden sonra kalması (plan.md:426) ve revalidate'in ilk yazmadan önce olması her iki metinle uyumlu.

## Açık kalemler (BLOKE değil)

1. **Demo restore tamamlandı ve doğrulandı:** P3a/P3b nesneleri DROP; 7 RPC eski gövdeleri + eski imzalar geri (yeni-imza kalan 0 [OBSERVED]); `_trg_hayvan_cikis_gorev_iptal`/`gorev_log_cycle_guard` P3a-öncesi gövdelere döndü [OBSERVED `TAKIP_MUAYENE`/`takip_kapanis_nedeni` konum=0]; sarmal/`_tohumlama_gebe_uygula`/`tohumlama_sonuc_gebe` DROP (P3b-öncesi demo'da yoktular); P2a yardımcıları (`_takip_gorev_kur`, `_takip_kapat`) P3a-DONE'daki gibi DURUYOR [OBSERVED]; baseline 302/3707/148/0/E2E-marker 0 [OBSERVED — P3a-DONE baseline'ıyla birebir]. P12 demo E2E öncesi SQL zincirinin (P1..P5) bütünsel apply kararı mimarda (P3a-DONE açık kalem 1 aynen).
2. **Demo'da OVSYNC aktif şablon yok** (tedavi_sablonu protokol_ailesi='OVSYNC' aktif = 0 [OBSERVED]) — start_first tam zincir prova'sı (vaka+şablon+TAI) demo'da koşamaz; prod'da mevcut. Ruling 2.
3. **T-72b islem_log izleri:** T-72b/prova kalıcı satırları temizlendi (hayvan bazlı); kalıcı iz kalmadı [OBSERVED baseline sayıları]. `islem_log` toplam sayısı commit'li RPC çağrılarından (ör. pair-2 muafiyet kayıtları) değişebilir — islem_log doğal app-log akışı, baseline kontrolü dışıdır.
4. **PGRST202 kayıtları** PostgREST şema-önbelleği metnidir — sürüm değişirse metin değişir; assertion'lar kayıtlı yanıta sabitlendi (plan.md:450 kayıt-öncelikli hüküm).
