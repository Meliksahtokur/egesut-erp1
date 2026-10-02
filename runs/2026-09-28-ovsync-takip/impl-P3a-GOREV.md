# impl-P3a — GOREV zarfı: otomatik kapanış TABLO TETİKLEYİCİLERİ (4 olay) + cycle_guard muafiyeti

- **Goal:** `G-20260930-OVSYNC-TAKIP-IMPL` (active)
- **Plan madde:** **P3a** — `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/docs/plans/2026-09-28-ovsync-takip-ekrani/plan.md:378-397` (MADDE DRIFT KAPISI: yalnız P3a; P3b guard'ları YOK)
- **EK ZORUNLU MADDE (goal "açık sözleşme girdileri", P2b bulgusu):** `gorev_log_cycle_guard` muafiyeti — plan boşluğu kapanışı, bu dosyaya.
- **GOREV (bu dosya):** `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/impl-P3a-GOREV.md`
- **DONE:** `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/impl-P3a-DONE.md`

## Yazma manifesti (TEK YAZICI — liste dışı YASAK)

1. `supabase/migrations/20260929000003_takip_kapanis_tetikleyicileri.sql` (create)
2. `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/impl-P3a-DONE.md` (create)

Prova betikleri `/home/melik/tmp/agents/` altına (repo dışı).

## Zorunlu davranış protokolü

1. **İLK İŞ:** `/home/melik/.claude/skills/using-superpowers-obra/SKILL.md` oku ve uygula (sahip kuralı; SUBAGENT-STOP geçersiz).
2. **SQL yazmadan ÖNCE:** `.harness/references/domain-rules.md` oku; çelişkide dur.
3. **PostgreSQL LSP zorunlu** (false-positive sınıfları: p_* parametreler, ayna-PROD-öncesi yeni nesneler, `\` meta-komutlar; trigger'lar aynada görünmez — canlı demo `pg_get_functiondef`/`pg_get_triggerdef` ile oku).
4. **db-validation KAPISI:** WORKTREE İÇİ yol; taslakta PASS.
5. **Bitiş kapısı:** `verification-before-completion-obra` — her iddia [CONFIRMED dosya:satır]/[OBSERVED komut] etiketli.

## Görev A — plan P3a birebir (plan.md:385-392)

Migration `20260929000003_takip_kapanis_tetikleyicileri.sql` — her tetikleyici idempotent (`_takip_kapat` zaten-kapalıya dokunmaz; neden kodu yazılır):

1. **Yeni tohumlama → SESSİZ:** AFTER INSERT ON `tohumlama` → açık TAKIP_MUAYENE varsa `_takip_kapat(neden='YENI_TOHUMLAMA')`. Tüm giriş yolları kapsanır — RPC gövdesine GÖMÜLMEZ.
2. **PG olayı → ONAYLI:** BEFORE INSERT ON `pg_application_event` → açık TAKIP_MUAYENE varsa `RAISE 'TAKIP_ACIK:{muayene_tarihi, muayene_saat}'`. `_pg_olay_isle`'e parametre EKLENMEZ; `hizli_uygulama`/`seans_tamamla`/`bulk_ilac` gövde değişikliği YOK.
3. **Ovsync vakası → ONAYLI:** BEFORE INSERT ON `cases` — yalnız Ovsync kaynaklı insert'ler. **Ad-çözümü açık sözleşmesi (goal):** plan `NEW.disease_id` → `diseases.name='Ovsync'` diyor AMA demo gözlemi `Ovsync Protokol` — çözümü DEMO'da ölç (`diseases` tablosunda Ovsync öbekleri + `cases.protocol_family` kullanımı), en sağlam birincil ölçütü seç (`protocol_family='OVSYNC'` varsa onu; yoksa name ölçütünü iki adı da kapsayacak şekilde), kararını kanıtıyla DONE'a yaz. Açık TAKIP_MUAYENE varsa `RAISE 'TAKIP_ACIK:{...}'`.
4. **Hayvan çıkışı → kapanış:** mevcut `trg_hayvan_cikis_gorev_iptal` fonksiyonuna CREATE OR REPLACE ile TAKIP_MUAYENE satırlarına `takip_kapanis_nedeni='CIKIS'` update'i eklenir (canlı gövdeyi pg_get_functiondef ile oku, append-only).
5. Geri-al yolu (`pg_application_event.geri_alindi_at`) takibi YENİDEN AÇMAZ.
6. **Kilit sözleşmesi (§10h H3):** tetikleyiciler hayvan kilidi ALMAZ — yalnız o hayvanın açık TAKIP_MUAYENE gorev_log satır(lar)ını günceller; BEFORE INSERT ret tetikleyicileri yalnız OKUR + RAISE. Tetikleyicilere `p_takip_onay` EKLENMEZ (DEGISMEZ 4).
7. **MK9-K:** tetikleyiciler `ovsync_pg_kurallari_aktif` bayrağını OKUMAZ — bayrak kapalıyken de çalışır.

## Görev B — cycle_guard muafiyeti (goal açık sözleşme girdisi; P2b bulgusu)

- Canlı demo `gorev_log_cycle_guard` BEFORE INSERT fonksiyonunu `pg_get_functiondef` ile oku [kaynak: `runs/2026-09-28-ovsync-takip/impl-P2b-DONE.md:118`]. Mevcut davranış: `ref_tohumlama_id` dolu her görev, bağlı tohumlama `sonuc NOT IN (Bekliyor,Gebe)` ise anında `iptal=true` — TAKIP_MUAYENE tasarım gereği **Boş** tohumlamaya bağlanır → kurulduğu an iptal ediliyor.
- Muafiyet: TAKIP_MUAYENE görevleri iptal koşulundan muaf tut (ör. `AND NEW.gorev_tipi <> 'TAKIP_MUAYENE'` — nihai biçimi canlı gövdeyi okuyarak sen karar ver, davranışı koru). CREATE OR REPLACE bu dosyada.
- **Kanıt şartı:** demo provada Boş tohumlamaya `_takip_gorev_kur` ile TAKIP_MUAYENE kurulur → `iptal=false` kalır (muafiyet öncesi bu senaryo `iptal=t` üretiyordu — önce-sonra kanıtı DONE'da).

## Kabul ölçütleri (plan P3a "Kabul" + görev B)

1. `scripts/db-validate.sh` (worktree yolu) taslakta **PASS**.
2. Demo prova her olay yolu tek tek (T-19..T-24): tohumlama→sessiz + kayıtlı neden; hızlı PG→red, onay akışı→uygulanır + neden=PG; seans/toplu aynı; Ovsync vaka→red, onay→neden=OVSYNC; çıkış→neden=CIKIS.
3. **Çift olay yarışı (T-24):** iki olay aynı anda → tek kapanış; ikinci tetikleyici idempotent no-op.
4. **Görev B kanıtı:** cycle_guard muafiyeti önce-sonra demo provası (TAKIP_MUAYENE `iptal=false` kalır).
5. Ad-çözümü kararının demo ölçüm kanıtı (diseases/cases gözlem çıktısı).
6. `git diff --check` temiz; anon/PUBLIC EXECUTE yok (tetikleyici fonksiyonlarda da).

## Yasaklar

- PROD erişimi/apply; push/merge/deploy; commit atma (mimar toplar).
- `.ss/`, `main`, manifest dışı repo dosyası; P3b guard işi (jenerik gorev_tamamla) YOK.
- Tetikleyicilere yeni parametre; `_pg_olay_isle`/`hizli_uygulama`/`seans_tamamla`/`bulk_ilac` gövde değişikliği.
- Sessiz varsayılan; en fazla 2 self-repair turu sonra DONE'a BLOKE yaz.

## DONE şablonu

Başlık: `impl-P3a-DONE — TAMAM|KISMI|BLOKE` · kabul maddeleri (6) tek tek kanıtlı · ad-çözümü kararı kanıtıyla · cycle_guard önce-sonra kanıtı · yazılan dosyalar · açık kalem.
