# impl-P2a — GOREV zarfı: TAKIP_MUAYENE tipi + şema + çekirdek yardımcıları + muafiyet

- **Goal:** `G-20260930-OVSYNC-TAKIP-IMPL` (active)
- **Plan madde:** **P2a** — `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/docs/plans/2026-09-28-ovsync-takip-ekrani/plan.md:255-277` (MADDE DRIFT KAPISI: yalnız P2a; P2b modları bu zarfta YOK — aynı dosyayı P2b devralır)
- **GOREV (bu dosya):** `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/impl-P2a-GOREV.md`
- **DONE:** `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/impl-P2a-DONE.md`

## Yazma manifesti (TEK YAZICI — liste dışı YASAK)

1. `supabase/migrations/20260929000002_takip_gorev_ve_bos_devam.sql` (create)
2. `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/impl-P2a-DONE.md` (create)

Bu iki dosya dışında HİÇBİR dosyaya yazma (etiket sözlükleri P9 tesliminde — DB değil).

## Zorunlu davranış protokolü

1. **İLK İŞ:** `/home/melik/.claude/skills/using-superpowers-obra/SKILL.md` oku ve uygula (sahip kuralı; SUBAGENT-STOP bu kural için geçersiz).
2. **SQL yazmadan ÖNCE:** `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/.harness/references/domain-rules.md` oku; çelişkide dur, DONE'a yaz.
3. **PostgreSQL LSP zorunlu (sahip talimatı):** SQL yazarken postgrestools LSP hover/typecheck/completion; sembol ilişkisi gerekirse GitNexus/Atlas. Not: fonksiyon parametresi (p_*) CTE/gövde içi kullanımında LSP "column does not exist" false-positive verebiliyor — runtime kanıtı (apply/prova) geçerliyse uyarıyı kapatma gerekçesiyle DONE'a kaydet.
4. **db-validation KAPISI:** `scripts/db-validate.sh`'i WORKTREE İÇİ yoldan çağır (`/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/scripts/db-validate.sh`) — ana checkout yolundan çağırma (P1 ders kaydı; rapor worktree `reports/` altına düşmeli). Taslakta PASS şart.
5. **Bitiş kapısı:** `verification-before-completion-obra` — her iddia [CONFIRMED dosya:satır]/[OBSERVED komut] etiketli.

## Görev (plan P2a birebir — plan.md:255-277)

Migration `20260929000002_takip_gorev_ve_bos_devam.sql`:

- `gorev_log.takip_kapanis_nedeni text NULL` ADD COLUMN (değerler: `YENI_TOHUMLAMA|PG|OVSYNC|CIKIS|GEBE_BULUNDU` — CHECK değil, serbest text; değer listesi sözleşme).
- `_takip_gorev_kur(p_hayvan_id uuid, p_tohumlama_id text, p_gun int, p_saat time) RETURNS uuid` — guard'lı kurucu: hayvan yok → `RAISE 'TAKIP_HAYVAN_YOK'`; açık TAKIP_MUAYENE → `RAISE 'TAKIP_ACIK:ZATEN_ACIK:{...}'`; INSERT: `gorev_tipi='TAKIP_MUAYENE'`, `kaynak='TAKIP:'||p_tohumlama_id`, `hedef_tarih=CURRENT_DATE+p_gun`, `hedef_saat=p_saat`, `ref_tohumlama_id=p_tohumlama_id`. **farm_id damgası YOK (D8):** gorev_log'da kolon yok, INSERT'ten damga çıkarma; §14 gereği mevcut tabloya kolon EKLENMEZ.
- `_takip_kapat(p_gorev_id uuid, p_neden text) RETURNS void` — idempotent: görev zaten `iptal`/`tamamlandi` ise DOKUNMAZ; değilse `iptal=true` + `takip_kapanis_nedeni=p_neden`.
- **MK9-N kilit sözleşmesi (§10h H1/H3 + D5, v7):** bu iki yardımcı DEGISMEZ 13 kapsam (a) — RPC yollarından çağrıldığında çağıran sarmal `hayvanlar` satırını İLK `FOR NO KEY UPDATE` ile kilitler (hayvan başına muteks — P2b sözleşmesi); istisna H3 yön kuralı: tohumlama satırı takip `gorev_log` satırından ÖNCE kilitlenir. `_takip_kapat` tetikleyici yolundan (P3a) tek başına çağrıldığında hayvan kilidi ALMAZ — yalnız hedef gorev_log satırını kilitler/günceller.
- `_acik_disi_hedef_ic` muafiyet genişletmesi: açık TAKIP_MUAYENE görevi olan hayvan → NULL (DEGISMEZ 1; zamanlayıcı/reconcile yolları dahil — S2c). Kalıp: `supabase/migrations/20260925000007_*.sql` satır 110-116.
- `gorev_ertele_kural` seed: `('TAKIP_MUAYENE', true, 'yok', NULL, 7, NULL, NULL)` [kalıp `20260925100003_*.sql`:64-88]. **GEBELIK_KONTROL için seed EKLENMEZ** (§10d #3 karar: erteleme yalnız birleşik sonuc ekranından, varsayılan SAATSIZ).
- ACL: DEGISMEZ 8 kalıbı — yardımcılarda anon/PUBLIC EXECUTE yok; REVOKE + GRANT authenticated/service_role kalıbı (`20260926000003`:106-107 deseni). Yeni migration anon GRANT yazmaz.

## Kabul ölçütleri (plan P2a "Kabul" birebir — DONE'da tek tek kanıtla)

1. `scripts/db-validate.sh` (worktree yolu) taslakta **PASS** — rapor çıktısı DONE'a; rapor dosyası worktree `reports/` altında.
2. Yardımcıların birim provası psql'de (izole/local veya demo rollback içinde): `_takip_gorev_kur` → geçerli kurulum döner uuid; aynı hayvan ikinci kur → `TAKIP_ACIK:ZATEN_ACIK` RED; olmayan hayvan → `TAKIP_HAYVAN_YOK` RED. `_takip_kapat` → kapatır; ikinci çağrı → değişiklik YOK (idempotent kanıt: satır md5/alan karşılaştırması).
3. anon/PUBLIC EXECUTE yok (canlı/izole sorgu kanıtı).
4. `git diff --check` temiz; farm_id gövde grep 0 (yorum hariç — D8).

## Yasaklar

- PROD erişimi/apply, push/merge/deploy (sahip kapısı); commit atma (mimar toplar).
- `.ss/`, `main` dalı, manifest dışı dosya.
- P2b modlarını (tohumlama_bos_ve_devam) bu dosyaya yazma — P2b ayrı zarf.
- Bilinmeyen yapıda sessiz varsayılan; en fazla 2 self-repair turu sonra DONE'a BLOKE yaz.

## DONE şablonu

Başlık: `impl-P2a-DONE — TAMAM|KISMI|BLOKE` · kabul maddeleri (4) tek tek kanıtlı · yazılan dosyalar · ölçüm komutları + çıktı özetleri · açık kalem.
