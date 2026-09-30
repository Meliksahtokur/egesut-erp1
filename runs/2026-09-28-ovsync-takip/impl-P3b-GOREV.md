# impl-P3b — GOREV zarfı: giriş kapıları — jenerik `gorev_tamamla` guard'ı + onay parametre geçişleri

- **Goal:** `G-20260930-OVSYNC-TAKIP-IMPL` (active)
- **Plan madde:** **P3b** — `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/docs/plans/2026-09-28-ovsync-takip-ekrani/plan.md:399-457` (MADDE DRIFT KAPISI: yalnız P3b; P4+ JS maddeleri YOK). **Bu madde geniş yüzeylidir — plan satırlarını (imza tablosu + MK9-G kilit grafiği + H geri alımları dahil) eksiksiz oku; imzalar ve sözleşmeler oradan KESİN.**
- **GOREV (bu dosya):** `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/impl-P3b-GOREV.md`
- **DONE:** `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/impl-P3b-DONE.md`

## Yazma manifesti (TEK YAZICI — liste dışı YASAK)

1. `supabase/migrations/20260929000003_takip_kapanis_tetikleyicileri.sql` (MODIFY — P3a bölümünü koru, P3b bölümünü ekle)
2. `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/impl-P3b-DONE.md` (create)

Prova betikleri `/home/melik/tmp/agents/` altına (repo dışı).

## Zorunlu davranış protokolü

1. **İLK İŞ:** `/home/melik/.claude/skills/using-superpowers-obra/SKILL.md` oku ve uygula (sahip kuralı; SUBAGENT-STOP geçersiz).
2. **SQL yazmadan ÖNCE:** `.harness/references/domain-rules.md` oku; çelişkide dur.
3. **PostgreSQL LSP zorunlu** (false-positive sınıfları bilinir; trigger'lar aynada görünmez → canlı demo `pg_get_functiondef` ile oku; **7 RPC'nin HER birinin canlı gövdesini oku** — migration-referans ≁ canlı olabilir).
4. **db-validation KAPISI:** WORKTREE İÇİ yol; taslakta PASS.
5. **Bitiş kapısı:** `verification-before-completion-obra` — her iddia [CONFIRMED dosya:satır]/[OBSERVED komut] etiketli.

## Görevin omurgası (ayrıntı + imza tablosu + kilit grafiği plan.md:407-452'de)

**1. `gorev_tamamla` guard'ı (H6):** yalnız TAMAMLAMA dalında (`p_iptal` false/NULL) + `gorev_tipi ∈ (GEBELIK_KONTROL, TAKIP_MUAYENE)` → `RAISE 'MUAYENE_SONUC_GEREKLI:{gorev_tipi}'`. `p_iptal=true` dalı (T5) ve SUTTEN_KESME/padok dalları AYNEN; guard kilitsiz okur, mevcut kilit sırası DEĞİŞMEZ. Üç dal kapsama matrisi kanıtlanacak.

**2. D4 — üç PG yolunda birleşik preflight:** `hizli_uygulama`, `seans_tamamla`, `bulk_ilac` — mevcut `_pg_kapi` çağrı noktası yanına TAKIP_ACIK preflight, İLK YAZMADAN (uygulama_log/islem_log INSERT) ÖNCE; payload birleşik (`PG_KAPI:TAKIP_ACIK:{...}`); retry tek çağrıda iki onay. Bulk: mevcut döngü/kilit DEĞİŞMEZ; `p_takip_onaylar` dışındaki açık-takipli satır İŞLENMEZ + satır sonucu `TAKIP_ACIK` (PG bulk satır-sonucu deseni); onaylılar için `_takip_kapat(neden=PG)` satır öncesi; retry = onaylı alt kümeyle yeni çağrı; boyut sınırı YOK; stok `v_success` üzerinden değişmez.

**3. C2 onay parametre tablosu (7 RPC):** plan.md:413-419 imza tablosu KESİN — `hizli_uygulama`/`seans_tamamla`/`start_first_service_protocol`/`create_case`/`kizginlik_vaka_ac` +`p_takip_onay boolean DEFAULT false`; `bulk_ilac`/`vaka_toplu_ac` +`p_takip_onaylar text[] DEFAULT '{}'::text[]`. Dizi yollarında liste-dışı id → `RAISE 'TAKIP_ONAY_KUME_UYUMSUZ'`.

**4. H4 standart deseni (yeni/değişen yüzeyler):** kilitsiz keşif → hayvan `FOR NO KEY UPDATE` → alt satır `FOR UPDATE` + yeniden doğrulama (mevcut hata sözleşmeleriyle — yeni hata kodu icat edilmez). `create_case`/`vaka_toplu_ac` ESKİ YOL: gövde kilit düzeni DEĞİŞMEZ (H1 geri alımları); takip kapısı kilitsiz keşif + `_takip_kapat` tek satır / satır-sonucu deseni.

**5. MK9 düzeltmesi — `start_first_service_protocol`:** görev KİLİTSİZ okunur (hızlı retler aynı sırada) → hayvan İLK kilit NKU → görev yeniden `FOR NO KEY UPDATE` + tip/kapanış yeniden doğrulama; akışın kalanı birebir (plan.md:424-428 tarif).

**6. C4 — `kizginlık_vaka_ac` kapısı (tanıdan BAĞIMSIZ, fail-closed):** H4 deseniyle gövde yeniden tanımlanır; açık takip + onaysız → `TAKIP_ACIK` red (tanıdan bağımsız — tetikleyici ağı bu yolda KAÇAR, kapı gövdede ZORUNLU); onaylı → önce `_takip_kapat(neden='OVSYNC')` sonra vaka INSERT.

**7. C5 — imza geçişi (her imza-değişen RPC):** eski overload DROP + yeni CREATE OR REPLACE + ACL yeniden (`REVOKE PUBLIC,anon` + `GRANT authenticated,service_role`; mevcut grant'ler korunur) + PostgREST negatif testi: eski imzayla REST çağrı → `PGRST202`/HTTP 404 (demo'da GERÇEK yanıtı KAYDET, assertion'ı o yanıta sabitle) + yeni imza çalışır + `anon` EXECUTE yok — AYRI assertion'lar.

**8. H5 (goal açık sözleşme girdisi):** `TAKIP_ACIK` satır JSON **alan adlarını DONE'da makine-okunur tablo olarak sabitle** (tekil + dizi + birleşik payload varyantları) — P10 JS tarafı bu tabloya bağlanacak.

**9. T-72b NİHAİ 5 çift (kabule dahil — §10h H7):** sarmal × `tohumlama_kaydet`; sarmal × `start_first_service_protocol` (düzeltilmiş gövde); sarmal × `seans_tamamla`; sarmal × `vaka_toplu_ac`; kapanış tetikleyicisi × sarmal. Her çift: iki bağlantılı betik, `lock_timeout='5s'`, N=30 eşzamanlı tur, demo DB. PASS = 0×`40P01`/`55P03` + her sonuç izinli kümede. "Önce kırmızı" şartı YOK.

## Kabul ölçütleri (plan.md:455 birebir + H5)

1. `scripts/db-validate.sh` (worktree yolu) taslakta **PASS**.
2. REST `gorev_tamamla(GEBELIK_KONTROL)` → `MUAYENE_SONUC_GEREKLI` red; iptal dalı + SUTTEN_KESME/padok dalları AYNEN (üç dal matrisi kanıtı).
3. D4: üç yolun her birinde preflight İLK YAZMADAN önce red üretir (takipli hayvanda hızlı/seans/toplu çağrı → uygulama_log/islem_log'a satır DÜŞMEZ); bulk onay listesi payload doğru; onaylı retry yalnız onaylanan satırları uygular.
4. C4: kızgınlık yolu onaysız → `TAKIP_ACIK` red (tanıdan bağımsız) + cases'e satır düşmez; onaylı → vaka + `OVSYNC` kapanışı.
5. C5: her imza-değişen RPC'de eski-imza REST red (kayıtlı gerçek yanıta sabitlenmiş) + `anon` EXECUTE yok + yeni imza çalışır.
6. **T-72b 5/5 çift × 30 tur PASS** (0×40P01/55P03; izinli küme) — goal'in ertelenmiş sözleşmesi bu maddeyle kapanır.
7. H5 alan adı tablosu DONE'da.
8. `git diff --check` temiz.

## Yasaklar

- PROD erişimi/apply; push/merge/deploy; commit atma (mimar toplar).
- `.ss/`, `main`, manifest dışı repo dosyası; P4+ JS işi; `tests/concurrency/ovsync-takip-t72b.mjs` düzeltmesi (ayrı kalem — kanıtını geçici betiklerle al).
- Eski yol gövdelerinde kilit düzeni değişikliği (H1 geri alımları plan.md:421); `tohumlama_sonuc_bos`/`tohumlama_sonuc_gebe`/`gorev_tamamla`/`create_case`/`vaka_toplu_ac` kilit düzenleri DOKUNULMAZ (yalnız tarif edilen yeni kısımlar).
- Sessiz varsayılan; en fazla 2 self-repair turu sonra DONE'a BLOKE yaz.

## DONE şablonu

Başlık: `impl-P3b-DONE — TAMAM|KISMI|BLOKE` · kabul maddeleri (8) tek tek kanıtlı · H5 alan adı tablosu · T-72b 5 çift oracle çıktıları · C5 kayıtlı PostgREST yanıtları · yazılan dosyalar · açık kalem.
