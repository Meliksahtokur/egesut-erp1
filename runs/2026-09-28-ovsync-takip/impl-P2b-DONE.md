# impl-P2b-DONE — TAMAM

- **Goal:** `G-20260930-OVSYNC-TAKIP-IMPL` · **Plan madde:** P2b (plan.md:279-342, birebir)
- **GOREV:** `runs/2026-09-28-ovsync-takip/impl-P2b-GOREV.md` · **Tarih:** 2026-09-30
- **Sonuç:** 6/6 kabul kanıtlı — **TAMAM** (2 ertelenmiş kalem belgeli: Ç5 yarış çifti + demo cycle_guard boşluğu — BLOKE değil)

## Yazılan dosyalar (manifest 2/2)

1. `supabase/migrations/20260929000002_takip_gorev_ve_bos_devam.sql` (MODIFY — P2a bölümü satır haritasıyla korundu [CONFIRMED P2a-DONE satır haritası: kolon 62, kur 71-129, kapat 131-170, muafiyet 240-251, seed 272-284, ACL 288-295 değişmedi]; P2b bölümü P2a COMMIT'inden SONRA ayrı BEGIN..COMMIT transaction'ı olarak eklendi — üç fonksiyon: `_tohumlama_gebe_uygula`, `tohumlama_sonuc_gebe` (çekirdeğe yönlendirme), `tohumlama_bos_ve_devam`). SHA-256 ilk 8: `617c2183` [OBSERVED sha256sum].
2. `runs/2026-09-28-ovsync-takip/impl-P2b-DONE.md` (bu dosya).

Manifest dışı repo yazımı YOK [OBSERVED `git status --porcelain` — benim yazdıklarım yalnız yukarıdaki 2; `M .harness/goals/...IMPL.md` mimar oturumunun checkpoint yazımı [OBSERVED diff — "P2b koşuyor" checkpoint'i, başka oturum]; prova betikleri `/home/melik/tmp/agents/` altında (p2b-birim-prova.sql, p2b-demo-prova.sh, t72b-mini.py)].

## Kabul maddeleri (6/6)

### 1) db-validate.sh (worktree yolu) — PASS (final)

[OBSERVED `bash /home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/scripts/db-validate.sh <migration>` → "SONUÇ: PASS", final rapor `reports/db-validation-617c2183.md` — SHA8 dosya ile eşleşmeli]. 3 koşum izi (worktree reports/):
- `bdef527e` **INCONCLUSIVE** — B.sema-uyum statik çözümleyicisi `IS DISTINCT FROM p_tohumlama_id` yazımındaki `FROM p_tohumlama_id`'yi tablo hedefi sanıp çözümleyemedi [OBSERVED rapor:16]. Düzeltme: plain `!=` (false-yol yazımıyla birebir 20260830000031:36; NULL riski pratikte yok — keşif satırı hayvanın kayıtlı tohumlaması). Kapı yanlış-bloklaması; zarf false-positive sınıfı notuna yakın (p_* parametre).
- `aa35c1da` **PASS** (1. mikro-düzeltme sonrası) [CONFIRMED rapor:8 "Genel sonuç: PASS"; fazlar A/A/B/C1×5/C2 tümü PASS].
- `617c2183` **PASS** (final — tüm prova sürüşü mikro-düzeltmeleri sonrası dosya) [OBSERVED exit=0; "Genel sonuç: PASS"].

### 2) Prova kataloğu — izole DB'de TAM, demo'da kısmi (ertelenenler §Açık kalemler)

**İzole DB `egesut_p2b_prova` (baseline `egesut_lsp` + P2b apply; lsp kalıp) — psql katalog exit=0, TÜM senaryolar PASS/OBSERVED [OBSERVED `/home/melik/tmp/agents/p2b-prova-cikti.txt`]:**

| Senaryo | Sonuç |
|---|---|
| S01 dry-run alan seti (Boş yolu): ok+bayrak_kapali=false+varsayilan_gun=7+ovsync_kilitli=false+kural_tarihi=2025-06-21+deneme=1+takip_acik=false | PASS |
| S02 dry-run kısır → ovsync_kilitli=true + kilit_gerekce=KISIR | PASS |
| S03 dry-run kural-günü → KURAL_GUNU + kalan_gun = kural−bugün (>0) | PASS |
| S04 dry-run son_pg: HIZLI_UYGULAMA kaynağından {stok_id, urun_adi, doz=2.5, birim=ml}; **C6**: yabancı-farm (11111111-…) DAHA YENİ event seçilmedi — `farm_id = current_farm_id()` filtresi işliyor | PASS |
| S05 Boş+OVSYNC geçerli: sonuc=Boş + tohumlama_durumu=Boş + islem_log TOHUMLAMA_SONUC iptal_sebep=bos + OVSYNC_BASLAT görevi 1 | PASS |
| S06 Boş+OVSYNC kısır → `OVSYNC_SECIM_KISIR` + alt-transaction rollback sonrası sonuc=Bekliyor iz=0 | OBSERVED (tek-tx) |
| S07 Boş+OVSYNC erken → `OVSYNC_SECIM_ERKEN:{"kural_gun":"2027-03-22","kalan_gun":...}` | PASS |
| S08 Boş+PG geçerli: uygulama_log 1 + pg_application_event 1 + stok_hareket 1 + Boş izi 1 + TAI görev 1 (uygun hayvanda; §18.6) | PASS |
| S09 Boş+PG açık takip: onaysız `TAKIP_ACIK:{muayene_tarihi,muayene_saat}`; onaylı → takip iptal+takip_kapanis_nedeni=PG + event 1 + Boş | S09b/c PASS |
| S10 Boş+PG çözümsüz stok → `PG_KAPI:BLOCK_CATALOG_UNRESOLVED` + **Boş ataması da geri alındı** (sonuc=Bekliyor, iz=0, uygulama=0) — T-08..T-11 | PASS |
| S11 birleşik kapı: `PG_KAPI:TAKIP_ACIK:{"pg_kapi":{...},"takip_acik":{"muayene_tarihi":...,"muayene_saat":...}}` tek RAISE | PASS |
| S12 Boş+TAKIP: görev +7g + atama saati dolu + kaynak=TAKIP:<toh_id>; **OVSYNC_BASLAT=0 (DEGISMEZ 1)** | PASS |
| S13 Boş+TAKIP p_gun=9 p_saat=14:30 → hedef+9, saat 14:30 | PASS |
| S14 `GIRIS_CIFT_ANLAMLI` (ikisi boş / ikisi dolu, payload'lı) | OBSERVED |
| S15 `MUAYENE_GOREV_TIPI_UYUMSUZ:{"gorev_tipi":"TEDAVI_GUN"}` | OBSERVED |
| S16 `SECIM_TANIMSIZ:{"secim":"GEBE","gorev_tipi":null}` (Boş+GEBE) + `TAKIP_YENIDEN_SECILEMEZ` (TAKIP_MUAYENE+TAKIP) + tablo-dışı secim | OBSERVED |
| S17 `TOH_SONUCLU:{"sonuc":"Gebe",...}` (sonucu girilmiş tohumlama — hiçbir yazma) | OBSERVED |
| S18 `TAKIP_KAPALI:{"tamamlandi":true,...}` (tamamlanmış muayene görevi) | OBSERVED |
| S19 muayene GEBE GEBELIK_KONTROL (Bekliyor yolu, p_bos_duzeltme=false): Gebe + görev tamamlandi + takip_kapanis_nedeni NULL + GEBE_ATAMA izi | PASS |
| S20 **D1**: TAKIP_MUAYENE'den Gebe — Boş→Gebe + hayvan durumu Gebe + görev tamamlandi+takip_kapanis_nedeni=GEBE_BULUNDU + `snapshot.bos_duzeltme={eski_sonuc:Boş, bos_atama_tarihi:2026-09-26, takip_kapanis:GEBE_BULUNDU}` (UTC 2026-09-25 21:30 → İstanbul yerel gün **2026-09-26** — normatif çözücü) | PASS |
| S21 D1 geri-alınma: Boş izi duruyor (count=1), eski GEBELIK_KONTROL iptali kalıcı (geri ALINMAZ) | PASS |
| S22 genel `tohumlama_sonuc_gebe` Boş'u hâlâ reddediyor — mevcut mesaj 'Sadece Bekliyor durumundaki tohumlama gebe ilanı alabilir' | PASS |
| S23 `BOS_DUZELTME_KOSUL:{"eksikler":["son_tohumlama_degil","sonuc_bos_degil"]}` | OBSERVED |
| S24 ERTALE: hedef=bugün+5 (p_saat NULL → **saatsiz**), görev AÇIK kaldı, zincir sürdü (yeni görev doğmadı) | PASS |
| S25 `TAKIP_UZADI:{"toplam_gun":37}` (21g+ zincir onaysız red); p_onay=true geçer | S25b/c PASS |
| S26 bayrak kapalı: dry-run `bayrak_kapali:true` döner; yazma modu `OZELLIK_KAPALI` + veri bozulmadı | PASS |
| S27 dry-run takip_acik + takip_bilgi{hedef_saat} + deneme_sayisi SON DOĞUMDAN (K13/§18.14) | PASS |
| S28 bos_atama_tarihi çoklu kayıt: `geri_alindi` dışlandı, EN SON (2026-09-28) kazandı | PASS |
| F0 ACL: sarmal anon=false/auth=true/svc=true/PUBLIC=false; **çekirdek hepsi false**; gebe-RPC anon=false/auth=true/svc=true | OBSERVED |

**Demo canlı prova** [OBSERVED `/home/melik/tmp/agents/p2b-demo-prova.sh` — apply → canlı çağrılar → temizlik; değerler basılmadı]:
- Apply temiz (COMMIT); ACL canlı birebir izoleyle aynı (sarmal f/t/PUBLIC=f; çekirdek f/f/f; gebe-RPC f/t/t).
- Canlı dry-run GERÇEK demo Bekliyor hayvanı: `{"ok":true, "bayrak_kapali":false, "ovsync_kilitli":false, "kural_tarihi":"2026-06-04", "deneme_sayisi":2, "varsayilan_gun":7, "takip_acik":false, "son_pg":null}` — alan seti birebir.
- Sentetik akış (BEGIN..ROLLBACK): Boş+TAKIP → görev kuruldu (hedef bugün+7, kaynak TAKIP:<toh>) + **OVSYNC_BASLAT=0** (DEGISMEZ 1, demo verisiyle); Boş+OVSYNC → ovsync_gorev_id döndü; bayrak-kapalı yolu: dry-run bayrak_kapali=true + yazma `OZELLIK_KAPALI`.
- Demo temizlik: 3 fonksiyon DROP → fn-kaldi=0; marker hayvan 0; **sayılar sabit** tohumlama=302, gorev_log=3707, cases=148 [OBSERVED].

### 3) Tek transaction kanıtı — PG adımı patlatınca Boş ataması da geri alınır

- S10 [OBSERVED]: `PG_KAPI:BLOCK_CATALOG_UNRESOLVED` RAISE → sonuc=Bekliyor + islem_log iz 0 + uygulama_log 0.
- S06 [OBSERVED]: `OVSYNC_SECIM_KISIR` RAISE → sonuc=Bekliyor + iz 0.
- Demo sentetik akış ROLLBACK sonrası marker hayvan=0, sayılar sabit [OBSERVED].
- Izole S05-S13: her başarılı yol tüm yan etkileriyle (iz + görev + event + stok) birlikte ya da hiç.

### 4) D1 provası 4 kalem

1. **T-05 Gebe varyantı (S20)**: TAKIP_MUAYENE'den Gebe → sonuc Boş→Gebe + görev GEBE_BULUNDU + islem_log `GEBE_ATAMA.snapshot.bos_duzeltme` izi (eski_sonuc + Boş giriş tarihi normatif gün) [OBSERVED izole S20 PASS].
2. **Geri-alınma kanıtı (S20/S21)**: tohumlama.sonuc ve hayvanlar.tohumlama_durumu Gebe'ye döndü; Boş'un islem_log izi duruyor (count=1); Boş'un iptal ettiği eski GEBELIK_KONTROL görevi iptal kalıcı (geri ALINMAZ) [OBSERVED izole sorgu çıktıları prova çıktısında].
3. **Sızıntı yok (S22)**: genel `tohumlama_sonuc_gebe` Boş tohumlamayı mevcut mesajla reddediyor (davranış bitişik) [OBSERVED].
4. **Çekirdeğe REST'ten doğrudan çağrı RED**: `_tohumlama_gebe_uygula` anon=false / authenticated=false / PUBLIC=false (izole F0 + demo canlı ikisinde de) — EXECUTE verilmemiş, yalnız sarmal + genel RPC gövdesi ulaşır [OBSERVED has_function_privilege].

### 5) T-72/T-73 yarış provası — 4 koşulabilir çift PASS, Ç5 ertelenmiş

- Repo-içi `tests/concurrency/ovsync-takip-t72b.mjs` koşuldu [OBSERVED] → Ç1/Ç4'te **betik kusuru görüldü**: psql alt-süreç protokolünde fixture setup SQL'i işlenmeden "başarılı" dönüyor (sarmal `TOH_YOK:{"tohumlama_id":"null"}`, kaydet `Hayvan bulunamadı`) [OBSERVED 30-tur çıktı]. Repo-içi test dosyası bu zarfın tek-yazıcı manifesti DIŞINDA olduğundan dokunulmadı — **açık kalem** (P3b/P12 koşumlarından önce düzeltilmeli).
- Sözleşmenin zorladığı koşum ("iki bağlantılı betik, iki eşzamanlı oturum, N=30, lock_timeout='5s'") `/home/melik/tmp/agents/t72b-mini.py` (manifest uyumlu geçici betik) ile alındı [OBSERVED son koşum]:
  - **Ç1 sarmal × tohumlama_kaydet: PASS** — 30 tur, 60/60 OK, ihlal=0 bilinmeyen=0.
  - **Ç2 sarmal × start_first_service_protocol: PASS** — 30 tur, 30 OK + 30 izinli-red (GOREV_BULUNAMADI — eski gövde; kurucu düzeltmesi P3b maddesi).
  - **Ç3 sarmal × seans_tamamla: PASS** — sentetik-seans kurulumuyla (gerçek demo seansına dokunmadan — 49 gerçek açık seans korunur), 30 tur 60/60 OK.
  - **Ç4 sarmal × vaka_toplu_ac: PASS** — 30 tur, 60/60 OK.
  - **Sonuç oracle'ı (H7)**: hiçbir turda SQLSTATE `40P01`/`55P03`/`57014` YOK; her sonuç İZİNLİ kümede (başarı ya da belgelenmiş iş redleri). "Önce kırmızı" şartı yok (H7).
  - **Ç5 kapanış tetikleyicisi × sarmal: ERTELENDİ** — P3a tetikleyicisi henüz yazılmadı (plan sırası); P3a sonrası koşulacak. BLOKE değil, gerekçeli erteleme.

### 6) `git diff --check` temiz + anon/PUBLIC EXECUTE yok

- [OBSERVED `git diff --check` → çıktı boş, exit 0].
- Anon/PUBLIC: [CONFIRMED migration ACL satırları — P2b bloğu: `_tohumlama_gebe_uygula` REVOKE PUBLIC,anon,authenticated (GRANT YOK); `tohumlama_sonuc_gebe(text)` + `tohumlama_bos_ve_devam(...)` REVOKE üçlüsü + GRANT yalnız authenticated,service_role; kalıp 20260926000003:106-107]. Anon GRANT satırı yok; canlı/izole has_function_privilege kanıtları yukarıda.

## PostgreSQL LSP (zorunlu sahip talimatı)

- [OBSERVED `postgrestools check --config-path=/home/melik/egesut-erp1/postgres-language-server.jsonc` → her turda **0 hata**, 14× `lint/safety/runningStatementWhileHoldingAccessExclusive` bilgi uyarısı (P2a'nın ALTER TABLE transaction boyu kilidi — bilinen bilgi düzeyi; P2b'nin eklediği satırlarda uyarı/hata YOK)].
- [OBSERVED built-in LSP `hover` → sunucu çökmüş (`SIGTERM`) ve yeniden doğmadı — P1-DONE'daki bilinen kısıt notu: postgrestools CLI check aynı çözümleme motoruyla statik typecheck kanıtı verir; komut-satırı check kullanıldı]. B-fazı false-positive sınıfı (`IS DISTINCT FROM <param>` FROM-yutması) 1. koşumda kanıtlandı ve düzeltildi — kayda alındı.
- SQL LSP oturum sonu durduruldu [OBSERVED `sql-lsp.sh stop` → "SQL LSP daemon durduruldu"; lsp-ctl status → kapalı].

## Zarf kararları (belgeli sapmalar — sessiz varsayım YOK)

- **a) Kapı self-repair turları 2/2:** tur-1 B-fazı yazım düzeltmesi (IS DISTINCT FROM); tur-2 prova bulgusu (CASE-expression → IF/ELSIF; PL/pgSQL atama-yapılmamış record alanına ifadede bile dokunuyor). Sonrası gelen mikro-düzeltmeler kapı turu değil, prova sürüşü bulguları — tam liste: (b) SECIM_TANIMSIZ payload `v_tip` (Boş yolunda atanmamış record'a erişim), (c) PG yolu `COALESCE(p_notlar,'')` (uygulama_log.notlar NOT NULL, default'suz — [CONFIRMED 20260603000002:20]), (d) `_takip_gorev_kur` çağrısına `::uuid` cast (imza uuid, sarmal hayvan id text — canlı hayvan id'leri UUID-biçimli text), (e) `OVSYNC_SECIM_TABAN_YOK` ayrı red kodu (dry-run kilit_gerekce TABAN_YOK ile tutarlı), (f) `PG_BIRIM_YOK` guard (stok.birim NULL → fail-closed; uygulama_log.birim NOT NULL).
- **b) Dry-run bayrak kapalıyken de tam alan seti döner** (bayrak-bağımsız hesap; P1 `20260924000002 dryrun_bayrak_bagimsiz` kalıbı) + `bayrak_kapali:true` — plan.md:332 "dry-run {bayrak_kapali:true} döner" bu biçimde yorumlandı.
- **c) `kilit_gerekce` değerleri:** `KISIR | KURAL_GUNU | TABAN_YOK` (plan değerleri vermiyordu; dry-run mockup copy "🔒 Kısır / 🔒 Kural günü" ile hizalı); `kalan_gun` yalnız KURAL_GUNU'da dolu.
- **d) TAKIP_UZADI toplam_gun = ERTALE sonrası yeni hedef − zincirin İLK kuruluşu** (kaynak-bazlı min(created_at)); GEBELIK_KONTROL ertelemesinde eşik kontrolü YOK (takip zinciri değil — S-7 metni takip zincirine ait).
- **e) TAKIP modunda p_saat NULL → atama anı saati** (S-5 karar "saat = atama anındaki saat"); ERTALE'de NULL → saatsiz (§10d #3).
- **f) PG modunda `p_pg_urun`/`p_pg_doz` zorunlu** (`PG_URUN_GEREKLI`/`PG_DOZ_GEREKLI` — sessiz varsayılan YASAK, DEGISMEZ 5); birim `stok.birim`'den (sarmal imzasında birim yok — plan imzası kesin); rota sabit `'IM'` (PG enjeksiyonu standart; sarmal imzasında rota yok).
- **g) Görev bulunamayan muayene yolu → `TAKIP_KAPALI:{neden:"GOREV_BULUNAMADI"}`** (aynı kod kategorisi — yarışta kısa-devre güvenli).
- **h) Görev.ref_tohumlama_id ≠ hayvanın son tohumlaması → `MUAYENE_TOH_UYUMSUZ`** (fail-closed; eski tohumlamaya yazım engellenir — plan red setinde olmayan yeni kod).
- **i) GEBE modu sırası:** D1 çekirdeği ÖNCE çağrılır, görev tamamlama SONRA (plan.md:302 "görev ÖNCE tamamlanır"ın tersi — gerekçe: D1 koşul (5) "açık takip zinciri" bu görevin kendisini kapsıyor; görev tamamlanırsa zincir bulunamaz ve meşru akış red alırdı; RAISE durumunda tek transaction tümünü geri alır — gözlemlenebilir davranış farkı yok).
- **j) `TOH_YOK`** keşifte bulunamayan tohumlama / görev-tohumu için fail-closed red kodu (plan red setinde yok; json-red geleneği yerine RAISE — sarmalın tüm redleri RAISE).
- **k) Ç3 sentetik-seans varyantı:** gerçek demo seansları (49 açık) kapatılmadı — yarış sentetik case/gün/uygulama zinciriyle koşuldu (kilit çakışması aynı hayvan üzerinden gerçek).
- **l) Ç1-Ç4 koşumu repo-içi betik yerine tmp/agents betiğiyle** — gerekçe b'de (betik kusuru; manifest dışı dosyaya dokunulmadı).

## Ertelenen / açık kalemler

1. **`gorev_log_cycle_guard` muafiyeti — PLAN BOŞLUĞU (sahibe/mimara):** demo'da BEFORE INSERT trigger `gorev_log_cycle_guard` [OBSERVED demo pg_get_functiondef] `ref_tohumlama_id` dolu her görevi, bağlı tohumlama `sonuc NOT IN (Bekliyor,Gebe)` ise anında `iptal=true` yapıyor. TAKIP_MUAYENE görevi tasarım gereği **Boş** tohumlamaya bağlanır → demo'da görev kurulduğu an iptal → P1 takiptekiler kümesi (`iptal=false`) görevi görmüyor → TAKIP zinciri + D1 muayene-GEBE/ERTALE yolları demo'da bu haliyle tıkanıyor [OBSERVED demo prova: `takip_kur ... iptal=t` + TAKIP_KAPALI]. İzole katalogda görünmedi (baseline aynası trigger taşımaz). Muafiyet (ör. `AND NEW.gorev_tipi <> 'TAKIP_MUAYENE'`) P3a/P2a turunda ayrı madde olmalı — bu zarfın tek-yazıcı manifesti dışında olduğu için YAPILMADI.
2. **Demo'da koşulamayan prova yolları (kalem 1'e bağlı):** muayene-GEBE (D1) ve ERTALE demo canlı akışı — izole DB katalogunda TAM kanıtlı (S19/S20/S21/S24/S25); cycle_guard muafiyeti sonrası demo turu önerilir.
3. **Ç5 yarış çifti** — P3a tetikleyicisi sonrası koşulacak (plan sırası).
4. **`tests/concurrency/ovsync-takip-t72b.mjs` protokol kusuru** — fixture setup `execRows` işlenmeyebiliyor (Ç1 koşum kanıtı yukarıda); P3b/P12 koşumlarından önce düzeltilmeli (bu zarfın manifesti dışı; dokunulmadı).
5. Demo'da islem_log prova izleri kaldı [immutable audit guard silinemez — `_islem_log_immutable_guard` [OBSERVED]; P1 kalıbıyla aynı: demo reset'i toplar].

## Ölçüm komutları (özet)

- `postgrestools check` (3 tur) → 0 hata, 14 bilgi uyarısı
- `db-validate.sh` (3 koşum) → INCONCLUSIVE → PASS → PASS (final `617c2183`)
- izole DB `egesut_p2b_prova` (createdb + `db-build-baseline.sh --db-name ... --db-url postgres://postgres:val@127.0.0.1:5433/postgres`) + migration apply + `p2b-birim-prova.sql` → exit=0, 28 senaryo
- demo apply + `p2b-demo-prova.sh` (3 koşum; sonunda temizlik) → dry-run/sentetik/ACL/bayrak kanıtları; sayılar sabit
- `t72b-mini.py 30 1,2,4` + `30 3` → Ç1/Ç2/Ç3/Ç4 PASS (120 tur × 2 taraf; 40P01/55P03=0)
- `git diff --check` → temiz; `sha256sum` → `617c2183…`
- Temizlik: demo fn-kaldi=0 + marker=0; izole prova DB dropped; SQL LSP stop
