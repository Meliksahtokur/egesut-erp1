# PLAN S3 — Zarf A: Stale temizlik koşumu (`ureme_temizlik_reconcile`) + Zarf B borç muhafazası

> **Kaynak spec:** `docs/plans/2026-09-24-ovsync-cila/spec-s3.md` · Girdi planı: `reports/plans/ovsync-cila-plan-2.md` + sentez §3 Adım 3 / §9
> **Dal:** `ovysch-feature-cila-turu` · **Prod'a PUSH/MERGE YASAK.** Commit'ler yalnız bu dala, her anlamlı adımdan sonra. DB yazımı **yalnız DEMO** (sahip onaylı).
> **Zarf B durumu:** Erteleme geneli (spec §8) **BORÇ** — `BUGS.md:183` `BUG-ERTELEME-KURAL-GENEL [open/borç]` (CONFIRMED grep). Bu plan Zarf B'yi **uygulamaz**; yalnız spec §8 tasarım kaydına atıf yapar ve hiçbir adımı ona dokunmaz (E-5).
> **Tek-yazıcı zarf (bu plan):** `supabase/migrations/<boş-numara>_ureme_temizlik_reconcile.sql` (YENİ) + `.harness/references/rpc-reference.md` (yalnız yeni girdi). `reports/ureme-temizlik-kosum-2026-09-25.md` YENİ'dir ama **gitignore'lu — commit DIŞI** (CONFIRMED `.gitignore:122`).
> **Eşzamanlılık disiplini (10 ajan olabilir):** Başka bir lane bu zarf dosyalarında commit görürse plan askıya alınır ve ENGEL olarak raporlanır. `BUGS.md` bu plana DOKUNULMAZ (kapsam-dışı; koşum kaydı reports/'a).

## 0. Yasak listesi (spec §3.1 birebir — her adımda geçerli)

Dokunma: `js/*` (hepsi — Zarf A'da JS YOK), `tohumlama_gorev_ertele` gövdesi, `hayvan_tohumlama_ertele` (SK3),
`sessiz_hayvanlar_reconcile` gövdesi, `protokol_ayar`, `js/config.js`, `index.html` (`?v=` damgası — JS değişmediği için
damga da değişmez), mevcut tüm migration dosyaları (yalnız YENİ dosya), 188'in İLAÇ görevi (`0818cd2e`) ve
tüm aktif OVSYNC TEDAVI zincirleri, `tohumlama` tablosu, `BUGS.md`.

**Taze tespit (bu plan yazılırken, demo salt-okunur sorgular, 2026-09-24 gecesi — OBSERVED):**
- R1 = {168 `5fe2ef8b`, 186 `65012b75`} — üçünün aktif OVSYNC `cases` satırı duruyor (168 `f90731be`, 186 `b284807a`).
- R2 = {173 `e341a0a9`} — son tohumlama 2026-07-30 `sonuc='Bekliyor'` (`ce96ca6d`) duruyor.
- **KISIR baz çizgisi spec'ten büyüdü:** 184/199/208'de artık **27** açık zincir görevi var (24 TEDAVI_GUN/SEANS + **3 TOHUMLAMA_PLANLI** — hayvan başına 1'er, hedef 2026-10-04). Spec taslağı yalnız 24 TEDAVI'yi kapatır (bkz. Adım 1 sapma kaydı D-1).
- **Kısır hayvan sayısı 3→6:** 115, 204, 185 (`kisir=true`) yeni; üçünün de açık görevi ve aktif instance'ı YOK — KISIR dry-run kapsamı değişmez, yalnız rapor notu.
- KISIR_INSTANCE = 2 (`ILERI_GEBE-…184` = `5570df8f`, `ILERI_GEBE-…208` = `9bc82033`; 199'un aktif instance'ı hâlâ yok).

## 1. Adım 0 — Ön uçuş (kod-yazımı YOK)

**0a — gitnexus indeks tazeleme (tüm adımların kapısı).** `gitnexus analyze <repo>` ile indeks HEAD'e eşitlenir.
Kural: indeks HEAD'e eş değilse Adım 1'e başlanmaz. İş bittikten sonra (Adım 7) tekrar analyze edilir.
**0b — E-1 bağımlılık kontrolü (EN KRİTİK KAPI):** Onaylı koşum (Adım 5) yalnız Tur-2 **Adım 1 (S1 kısır blok —
istenen dosya `20260925000001_ovsync_kisir_blok.sql`)** ve **Adım 2 (S2 sessiz sınıflandırma — istenen dosya
`20260925000001_sessiz_siniflandirma.sql`; taslak `taslak-s2-migration.sql`)**
demo'ya uygulandıktan SONRA koşulur. Kontrol: `psql "$SUPABASE_DEMO_DB_URL" -tAc "SELECT version FROM
supabase_migrations.schema_migrations ORDER BY version DESC LIMIT 8"` — S1/S2 dosyalarının version'ları görünüyor mu?
Ayrıca davranışsal çift-kanıt: S2 sonrası `sessiz_hayvanlar_listele` default eşiği 50'dir ve `v_eligible` Bekliyor'u
hariç tutar; S1 sonrası kısır hayvana `_acik_disi_hedef_ic` NULL döner. E-1 sağlanmadıysa: dry-run (Adım 4) serbest
(salt-okunur), **onaylı koşum bekletilir** ve ENGEL olarak raporlanır — 05:00 `sessiz-reconcile-daily` cron'u kapatılan
görevleri yeniden üretir (K7: iptal için cooldown yok; K13: 173 vakası taze kanıt).
**0c — Taze baz çizgisi ölçümü (demo, salt-okunur):** §0'daki OBSERVED kümesini koşum günü yeniden ölç —
(a) açık SESSIZ vet görevleri; (b) `kisir=true` hayvan listesi + her birinin açık OVSYNC_BASLAT/TEDAVI_*/TOHUMLAMA_PLANLI
görev sayısı + aktif UREME instance sayısı; (c) 188 `0818cd2e` İLAÇ görevinin hâlâ açık-dokunulmaz olduğu. Sapma varsa
Adım 4-5 beklenen-etki tabloları taze ölçümle yeniden yazılır (E-2).
**0d — Migration dosya numarası çakışma kontrolü:** spec-s1 `…000001_ovsync_kisir_blok.sql`, spec-s2
`…000001_sessiz_siniflandirma.sql`, plan-s5 `…000001/2/3_cila_t*.sql` istiyor (CONFIRMED üç plan dosyası) —
spec-s3 taslağı da `20260925000001_ureme_temizlik_reconcile.sql` adını taşıyor; **dört lane 001 numarasında
toplanmış durumda**. Kural: temizlik migration'ı koşum anında `ls supabase/migrations/` ile **kullanılmayan en
düşük `20260925NNNNNN` numarasını** alır; beklenen örnek `20260925000004_ureme_temizlik_reconcile.sql`
(S1/S2/S5 gerçekten 001-003'e yerleşmişse). Dosya adı baş yorumundaki `Migration:` satırıyla da eşleşir.
**0e — Trigger kesişim kontrolü (V-3 doğrulaması):** `psql` salt-okunur:
`SELECT trigger_name, event_object_table FROM information_schema.triggers WHERE event_object_table IN ('gorev_log','protokol_instance');`
— listelenen trigger'ların gövdeleri `iptal`/`durum` UPDATE'ine dokunmuyor mu teyit edilir (beklenti: etken_kod guard
trigger'ları yalnız INSERT/tamamlama yönünde; spec V-3 [INFERRED] burada OBSERVED'a çıkar). Tetikleyen bir trigger
görünürse Adım 1'deki UPDATE deseni (yalnız `iptal`+`kapatan_ref` kolon yazımı) yine korunur; bulgu rapora notlanır.
Doğrulama: 0a-0e çıktıları koşum raporunun "Ön uçuş" bölümüne yazılır. **Commit: YOK** (ölçüm adımı).

## 2. Adım 1 — Migration dosyasını yaz (Zarf A tek dosya)

**Dosya:** `supabase/migrations/<0d'de belirlenmiş boş numara>_ureme_temizlik_reconcile.sql` — **YENİ**.
**İçerik:** spec §5.1 taslağı (sha başı `b02f28ff`) **birebir**, şu üç kayıtla:

1. **Baş yorumu:** `SPEC:` satırı bu planın dosya adına işaret eder; dosya adı 0d'deki numaraya göre yazılır.
2. **Sapma kaydı D-1 (plan kararı — spec taslağından tek bilinçli sapma):** KISIR-B sorgusundaki
   `g.gorev_tipi IN ('OVSYNC_BASLAT', 'TEDAVI_GUN', 'TEDAVI_SEANS')` listesi
   `g.gorev_tipi IN ('OVSYNC_BASLAT', 'TEDAVI_GUN', 'TEDAVI_SEANS', 'TOHUMLAMA_PLANLI')` olur.
   **Gerekçe (kanıtlı):** sahibin bağlayıcı kararı "kısır 184/199/208 **zincirleri** kapatılacak" (görev + sentez §9 S1).
   Taze ölçümde her kısır hayvanın zincirinin ucunda 1'er açık `TOHUMLAMA_PLANLI` (hedef 2026-10-04) var (OBSERVED
   `113c327f`/`af9dd507`/`9c3c7180`) — taslak bu üçünü bırakıp 24 TEDAVI'yi kapatıyor; kalan görev işletmeciye
   10-04'te kısır hayvan için tohumlama işi olarak görünürdü. R3 dokunulmazlığı bozulmaz: kapsam `h.kisir IS TRUE`
   hayvanlarla sınırlı; 188 (`kisir=false`) ve tüm aktif OVSYNC zincirleri KISIR filtresine giremez. S1'in M1 üretim
   filtresi kapatılan görevlerin yeniden üretilmesini zaten durdurur.
   **Bedeli:** içerik değişikliği → Adım 2'de db-validate TASLAĞIN yeniden koşulması ZORUNLU (spec §5.1 kuralı).
3. **Gerisi (R1/R2/KISIR-A gövdeleri, kapatan_ref değerleri, islem_log audit, REVOKE/GRANT, NOTIFY) aynen korunur** —
   kapatan_ref: R1=`OVSYNC_KAPLANDI`, R2=`TOHUMLAMA_SONUCU_VAR`, KISIR=`KISIR_TEMIZLIK`; `islem_log` tipi
   `UREME_TEMIZLIK`; `REVOKE … FROM PUBLIC, anon` + `GRANT … TO authenticated` satırları aynen (anon GRANT YOK kuralı).

**Kapılar:** yazmadan önce `code-change-precheck` (migration yazımı tetikleyicisi); 0a indeks kapısı.
**Doğrulama:** `git diff --stat` yalnız YENİ dosyayı gösterir; dosyada `TO anon`/anon GRANT satırı YOK (grep kanıtı);
`UREME_TEMIZLIK` tipi spec §5.1 ile birebir; D-1 listesi 4 tip içerir.
**Commit:** `migration: ureme_temizlik_reconcile — stale sessiz + kısır zincir tek-seferlik dry-run'lı RPC (S-3 Zarf A)`.

## 3. Adım 2 — db-validate kapısı (migration-metni ÜZERİNDE)

**Komut:** `bash scripts/db-validate.sh supabase/migrations/<numara>_ureme_temizlik_reconcile.sql`
**Ortam (E-3):** kapı `scripts/../.env` arar; worktree kökünde yok. Çözüm: ana checkout'taki demo .env'i worktree
köküne kopyala — `cp /home/melik/egesut-erp1/.env .env` (`.gitignore:98` kapsamında, commit riski YOK; sonrasında
silinebilir). Spec §5.2'deki mini-körök workaround'u gerekmez.
**Kabul kriteri (T-A1):** PASS **veya** C2'nin `islem_log` sentetik-tohum kısıtı tekrarlarsa
**INCONCLUSIVE-with-C1-PASS** (C1.migration-apply PASS + C2 apply hatasız — spec E-4 kriteri). FAIL ise migration
düzeltilir ve kapı yeniden koşulur; FAIL ile devam EDİLMEZ.
**Doğrulama:** `reports/db-validation-<sha8>.md` raporu oluşur (gitignore'lu); rapor sha'sı D-1'li yeni dosyanın sha'sıdır
(spec §5.2'deki `b02f28ff` bayattır — o kanıt taslak içindir, final içindir değil).
**Commit:** YOK (rapor gitignore'lu).

## 4. Adım 3 — Demo apply + rpc-reference girdisi + commit

**4a — Demo'ya uygula (prod'a ASLA):**
`psql "$SUPABASE_DEMO_DB_URL" -v ON_ERROR_STOP=1 -f supabase/migrations/<numara>_ureme_temizlik_reconcile.sql`
(demo bağlantısı ana checkout `.env`'inden; demo/projeler karışmama kanıtı T-A8).
**Doğrulama:** `SELECT pronoun…` yerine `SELECT proname FROM pg_proc WHERE proname='ureme_temizlik_reconcile';` → 1 satır;
`SELECT proacl … has_function_privilege('anon', …)` → anon EXECUTE YOK (REVOKE kanıtı); `NOTIFY pgrst` sonrası PostgREST
yeniden yüklenir (RPC tools-bank `supabase_rpc` ile çağrılabilir).
**4b — rpc-reference girdisi:** `.harness/references/rpc-reference.md` → "Sessiz Hayvan (2026-08-31 güncel)" bölümünün
hemen altına yeni alt bölüm `## Üreme Temizlik (tek-seferlik, 2026-09-25)`:

> **`ureme_temizlik_reconcile(p_dry_run?, p_gruplar?)`** → jsonb `{R1, R2, KISIR_INSTANCE, KISIR_GOREV, dry_run, zaman}`
> — stale "Sessiz hayvan" görevleri (R1 aktif protocol_family vakası, R2 son tohumlama Gebe/Bekliyor) + kısır hayvan
> aktif UREME instance'ları ve açık zincir görevleri (KISIR) için tek-seferlik dry-run'lı tasfiye. Silme YOK —
> `iptal=true` + `kapatan_ref` + `islem_log('UREME_TEMIZLIK')` audit. `p_dry_run` default `true`.
> Çağrı yeri: koşum betiği/reports (js çağırmaz). Spec: `docs/plans/2026-09-24-ovsync-cila/spec-s3.md`.

Mevcut satırlara başka dokunuş YOK (spec §3.1: "mevcut satırlara dokunma").
**Kapı:** commit öncesi `git diff --cached --stat` staging kontrolü (yalnız 2 dosya: migration + rpc-reference) —
memory dersi: "git add <dosya> yeterli değil".
**Commit:** `docs(rpc): ureme_temizlik_reconcile referans girdisi + demo apply kanıtı (S-3 Zarf A)`.

## 5. Adım 4 — Dry-run koşumu + koşum raporu (T-A2)

**Koşum:** `SELECT public.ureme_temizlik_reconcile(true);` (default p_gruplar = üç grup; PostgREST/RPC ya da psql).
**Rapor:** `reports/ureme-temizlik-kosum-2026-09-25.md` (gitignore — commit DIŞI) içine:
grup-bazlı tablolar (her satırda gorev_id/instance_id + küpe + açıklama + uygulanacak kapatan_ref) + Adım 0 ön-uçuş
çıktıları + E-1 durumu + sahibin onay damgası satırı (Adım 5'te işlenir).
**Beklenen küme (taze ölçüm, §0 — koşum günü 0c ile tazelenir):**
R1 = 2 (`5fe2ef8b` 168, `65012b75` 186) · R2 = 1 (`e341a0a9` 173) · KISIR_INSTANCE = 2 (`5570df8f` 184, `9bc82033` 208) ·
KISIR_GOREV = 27 (24 TEDAVI_GUN/SEANS + 3 TOHUMLAMA_PLANLI — D-1 ile; taslak olmadan 24 olurdu, bu fark raporda
açıklanır). Sapma > 0 olursa: koşum DURUR değil — sapma rapora yazılır, Adım 5 öncesi sapma nesnel kural dışıysa
(yeni R1/R2 vakası, yeni kısır hayvan) değerlendirme notu düşülür; kuşkulu sapma varsa ENGEL raporlanır ve bekletilir.
**T-A2 doğrulaması:** dry-run öncesi/sonrası
`SELECT count(*) FROM gorev_log WHERE iptal` ve `SELECT count(*) FROM protokol_instance WHERE durum='iptal'` farkı = 0;
dönen jsonb'de yukarıdaki küme satır satır; her R1 kaydında `kupe_no`+`aciklama`+`gorev_id` dolu.
**Commit:** YOK (rapor gitignore'lu).

## 6. Adım 5 — Onaylı koşum (T-A3 + T-A5) — sahibin "kesintisiz koş" talimatı

**Onay durumu:** Sahibin bağlayıcı kararları bugün verilmiş: "kısır 184/199/208 zincirleri kapatılacak" (S1) +
"kararları vermiştik, bir sorun çıkmadığı sürece **kesintisiz koş**, direkt demo-teste hazır teslim et" (user request,
2026-09-24). KISIR grubu ön-onaylı; R1/R2 nesnel kural tabanlı ve dry-run tablosu raporda sunulur. **Sorun/sapma
çıkmadıkça bekletme YOK**; sorun çıkarsa Adım 4'te zaten bekletilmiş olur (ENGEL kaydı).
**Ön şart:** Adım 0b E-1 PASS (S1+S2 migration'ları demo'da) — sağlanmadıysa koşum BEKLETİLİR, ENGEL raporlanır.
**Koşum:** `SELECT public.ureme_temizlik_reconcile(false, ARRAY['R1','R2','KISIR']);`
**Doğrulama (T-A3):**
(a) hedef görevlerde `iptal=true` ve grup-bazlı doğru `kapatan_ref` (R1=`OVSYNC_KAPLANDI`, R2=`TOHUMLAMA_SONUCU_VAR`,
KISIR=`KISIR_TEMIZLIK`); instance'larda `durum='iptal'`, `kapandi_sebep='KISIR_TEMIZLIK'`, `kapandi_at` dolu;
(b) `SELECT count(*) FROM islem_log WHERE tip='UREME_TEMIZLIK'` → **tam 1**; `snapshot.guncellenen` uzunluğu =
kapatılan toplam (beklenti: 32 = 2+1+2+27); `olusturulan`/`silinen` boş;
(c) onay damgası + koşum çıktısı rapora işlenir.
**T-A5 dokunulmazlar (diff kanıtı):** koşum diff'inde YOK: 188 İLAÇ `0818cd2e`; 168/186'nın aktif OVSYNC
TEDAVI_GUN/SEANS zincirleri ve `TOHUMLAMA_PLANLI` görevleri; 186'nın `ILERI_GEBE` instance'ı (kisir=false — K16);
`tohumlama` tablosu; önceden tamamlanmış/iptal hiçbir kayıt. Kontrol sorguları rapora yazılır.
**Commit:** YOK (DB etkisi; rapor gitignore'lu). Zarf B'ye dokunuş: YOK.

## 7. Adım 6 — Yeniden üretim, regresyon, geri-dönüş prova (T-A4 + T-A6 + T-A7)

**6a — T-A4 (E-1 bağımlı):** `SELECT public.sessiz_hayvanlar_reconcile();` → `uretilen=0 AND kapatilan=0`.
S2 view'ı (Bekliyor hariç + eşik 50) 168/173/186'yı üretimden düşürmediği sürece bu test fail eder — fail ise E-1
kontrolü yeniden okunur (koşum erken mi yapıldı?) ve S2'nin view garantisi spec-s2 kabulüne kesin gereksinim olarak
raporlanır (spec V-4). İzleme penceresi: ertesi gün 05:00 `sessiz-reconcile-daily` cron çıktısı da rapora not edilir.
**6b — T-A6 (regresyon):** `git log --oneline -3 -- supabase/migrations/20260923000003_ovsync_pg_yardimcilar.sql` →
bu planın commit'leri görünmüyor (gövde diff YOK kanıtı). Demo'da kapatılmamış, açık bir `TOHUMLAMA_PLANLI` görev
bul (0c ölçümünden; örn. 199 dışı bir hayvanın görevi), `tohumlama_gorev_ertele` ile +1 gün ertele → dönüşte
`ok=true, toplam_erteleme_gun, uyari` alanları gelir → aynı RPC ile eski hedefe geri ertele. İki `TOHUMLAMA_ERTELE`
islem_log satırı oluşur — bu beklenen gürültü, rapora notlanır (temizlik audit'ine karışmaz).
**6c — T-A7 (geri-dönüş prova):** `UREME_TEMIZLIK` satırının `snapshot.guncellenen` listesinden **tek** `tablo=gorev_log`
id seç → §7 geri-açma SQL'i koş (`iptal=false, kapatan_ref=NULL`) → sonra aynı satırı elle eski hâline geri yaz
(`iptal=true, kapatan_ref=<grup ref'i>`) → islem_log `UREME_TEMIZLIK` sayısı **1 kalır** (elle UPDATE audit yazmaz —
beklenen; gerçek geri-dönüşte sahibin bilinçli kararı §7 planına göredir). Prova id'leri rapora yazılır.
**6d — kapatma parity:** `SELECT count(*) FROM gorev_log WHERE kapatan_ref IN ('OVSYNC_KAPLANDI','TOHUMLAMA_SONUCU_VAR','KISIR_TEMIZLIK')`
→ T-A3'teki sayılarla birebir (32; D-1 dahil). Sonra 0c'nin kullandığı `.env` kopyası worktree kökünden silinir (temizlik).
**Commit:** YOK (kod yok; prova yalnız demo veri etiketleri + rapor).

## 8. Adım 7 — Teslim zarfı + son review kapısı + indeks yenileme

**7a — gitnexus analyze yenileme:** iş bittikten sonra indeks dal ucuna eşitlenir (kapı kuralı — repo sözleşmesi).
**7b — gitnexus detect_changes:** `scope=staged/all` dal farkı okunur; beklenti: yalnız migration + rpc-reference
değişimi görünür, proses-etkisi "yeni RPC çağrı zinciri yok (js çağırmaz)".
**7c — Teslim zarfı (son review kapısına):** sahibin talimatı gereği iş sonunda **tekrar review** yapılır ve son review
kapısından geçmesi sağlanır — zarf içeriği: (1) kabul tablosu T-A1…T-A8 her biri kanıt komut çıktısıyla PASS/fail;
(2) koşum raporu yolu `reports/ureme-temizlik-kosum-2026-09-25.md`; (3) db-validation raporu yolu; (4) ENGEL listesi
(§10'dan kapanan/açık durumu); (5) Zarf B borç durumu: **dokunulmadı** — `BUGS.md:183` açık kalır, spec §8 tasarım
kaydı (DDL §8.1 + RPC §8.2 + UI §8.3 + kabul §8.4) borç kapısı açıldığında hazır; (6) ertesi gün 05:00 cron izleme
maddesi (sahibe tek cümle: "yarın 05:00 koşumunda uretilen=0 beklenir").
**7d — Commit:** raporlar gitignore'lu olduğundan plan-cila commit'i gerekmez; rpc-reference/migration commit'leri
Adım 1/3'te atıldı. Zarf B hakkında BUGS.md'ye ek YOK (kapsam-dışı disiplin).
**Review kapısı notu:** review bulgusu çıkarsa fix bu planın zarfına girer (migration gövdesi değişirse Adım 2 kapısı
yeniden koşulur; koşum sonrası gövde değişirse koşum tekrar edilmez — yalnız RPC metni düzeltilir ve sapma raporlanır).

## 9. Bağımlılık haritası

```
Adım 0 (0a indeks; 0b E-1 kontrolü; 0c ölçüm; 0d numara; 0e trigger)
  └─ Adım 1 (migration yaz)      ← 0a, 0d zorunlu
       └─ Adım 2 (db-validate)   ← Adım 1; D-1 içerik değişikliği yüzünden ZORUNLU yeniden koşum
            └─ Adım 3 (demo apply + rpc-reference + commit)
                 └─ Adım 4 (dry-run; salt-okunur — E-1 beklemeden koşulabilir)
                      └─ Adım 5 (onaylı koşum)  ← 0b E-1 PASS + Adım 4 sapmasız
                           └─ Adım 6 (T-A4/T-A6/T-A7)
                                └─ Adım 7 (zarf + review kapısı + analyze)
```

Eşzamanlı S1/S2/S4/S5 lane'leriyle kesişim: dosya seti ayrık; tek temas noktası migration numara uzayı (0d kuralı) ve
demo `schema_migrations` sırası (S1/S2 önce, temizlik sonra). S2 lane'i view'ı değiştirdiği için temizlik koşumu
S2-apply'dan SONRA doğrudur (E-1) — dry-run hariç.

## 10. Engeller (koşum öncesi bilinen)

- **E-1 (sıra bağımlılığı):** S1 + S2 migration'ları demo'da uygulanmadan onaylı koşum yapılırsa 05:00 cron kiri yeniden
  üretir (K7+K13). Plan, Adım 0b kontrolünü Adım 5'e sert ön-şart yaptı.
- **E-2 (bayat spec taban çizgisi):** spec §6 ölçümü bayatladı — taze ölçüm: KISIR_GOREV 24→27 (+3 TOHUMLAMA_PLANLI),
  kısır hayvan 3→6 (+115/204/185; açık kayıt yok, kapsam etkisi sıfır), R1/R2 kümesi değişmedi (OBSERVED, §0).
- **E-3 (db-validate .env):** worktree kökünde `.env` yok → ana checkout kopyası çözümü Adım 2'de.
- **E-4 (C2 tohum kısıtı):** validator `islem_log` sentetik tohumu üretmiyor (araç kısıtı) → INCONCLUSIVE-with-C1-PASS
  kabul kriteri (T-A1).
- **E-5 (Zarf B):** erteleme geneli bu turda UYGULANMAZ (BUGS.md borcu) — plan Zarf B'ye dokunmaz; kapı sahibin "borç
  aç" kararıdır.
- **D-1 sapma kaydı:** KISIR-B'ye `TOHUMLAMA_PLANLI` eklemesi spec taslağından bilinçli sapmadır (gerekçe Adım 1'de);
  bedeli yeniden db-validate (Adım 2, zaten zorunlu adım).

*Plan sonu — bu plan yalnız docs/plans/2026-09-24-ovsync-cila/ altına yazıldı; repo koduna/migration'a dokunulmadı.*
