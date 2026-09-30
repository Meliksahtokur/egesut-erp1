# impl-P1 — GOREV zarfı: `ovsync_takip_listele` salt-okunur RPC migration

- **Goal:** `G-20260930-OVSYNC-TAKIP-IMPL` (active, 2026-09-30 sahip onayı)
- **Plan madde:** **P1** — `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/docs/plans/2026-09-28-ovsync-takip-ekrani/plan.md:229-253` (MADDE DRIFT KAPISI: yalnız P1 kapsamı; P2+ maddelerine girme)
- **GOREV (bu dosya):** `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/impl-P1-GOREV.md`
- **DONE:** `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/impl-P1-DONE.md`

## Yazma manifesti (TEK YAZICI — liste dışı YASAK)

1. `supabase/migrations/20260929000001_ovsync_takip_listele.sql` (create)
2. `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/impl-P1-DONE.md` (create)

Bu iki dosya dışında HİÇBİR dosyaya yazma. Mevcut dosyaları değiştirme/geri alma.

## Zorunlu davranış protokolü

1. **İLK İŞ:** `/home/melik/.claude/skills/using-superpowers-obra/SKILL.md` oku ve uygula (sahip kuralı; SUBAGENT-STOP bu kural için geçersiz).
2. **SQL yazmadan ÖNCE:** `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/.harness/references/domain-rules.md` oku (AGENTS.md Start here #2 — zorunlu); çelişkide dur ve DONE'a yaz, yorumlama.
3. **PostgreSQL LSP zorunlu (sahip talimatı 2026-09-30):** SQL yazarken postgrestools LSP'yi (yerel Postgres şema aynası) hover/typecheck/completion için kullan — var olmayan kolon/tablo referansı, tip uyuşmazlığı yakalar. LSP'de goto/references yok; sembol ilişkisi gerekirse GitNexus/Atlas.
4. **db-validation KAPISI:** `scripts/db-validate.sh` taslak üzerinde PASS almadan teslim RED sayılır (sahip kuralı 2026-09-24).
5. **Bitiş kapısı:** `verification-before-completion-obra` — DONE'daki her iddia komut çıktısıyla kanıtlı; kanıtsız iddia yazma; her yük taşıyan iddiaya `[CONFIRMED dosya:satır]` / `[OBSERVED komut]` etiketi.

## Görev (plan P1 birebir — kaynak plan.md:229-253)

`ovsync_takip_listele(p_padok text DEFAULT NULL, p_sonlanan_gun int DEFAULT 60)` `RETURNS jsonb` salt-okunur RPC migration'ı:

- Çıktı: `{ok, bayrak_kapali, kpa{aktif, bugun, geciken, muayene_bekleyen, bekleyen_baslatma, bekleyen_baslatma_takipte}, esikler{muayene_gun, pencere_gun}, satirlar[]}`
- Satır alanları spec §5 birebir (plan.md:238'deki tam liste — `takip{gorev_id, hedef_tarih, hedef_saat}` §6c.5 ve `muayene_gorev_id` K15 dahil).
- CTE modeli: `ovsync_baslat_uyarilari` (migration `20260926000003`:38-104) üzerine genişletme — gorevli ∪ gorevsiz ∪ aktif-zincir ∪ sonuc-bekleyen ∪ kapalı.
- **S2 = 40 g sistemiyle AYNI küme (K15/#11 + D2):** sonuc-bekleyen CTE'si `gebelik_muayene_listele`'nin 5 predicate'ının TAMAMINI taşır (kaynak migration `20260925000002`:305-320, birebir): (1) `t.sonuc='Bekliyor'`; (2) `t.tarih <= CURRENT_DATE - _ayar('sessiz_tohumlama_muafiyet_gun',40)`; (3) `h.cinsiyet='Dişi' AND h.durum='Aktif' AND h.kisir IS NOT TRUE`; (4) son tohumlama `ORDER BY t2.tarih DESC NULLS LAST, t2.created_at DESC NULLS LAST LIMIT 1`; (5) 30 g tamamlanmış-cooldown `NOT EXISTS (gorev_log g WHERE g.kaynak='GEBELIK-KONTROL-'||t.id AND g.tamamlandi AND g.tamamlanma_tarihi >= CURRENT_DATE-30)`.
- Dalga anahtarı: vakayı açan OVSYNC_BASLAT görevinin `hedef_tarih`'i; gorevsiz `cases.start_date`; tekiller "tekil baslangiclar".
- KPA (§10c #8): `bekleyen_baslatma` = TOPLAM (adaylar ∪ açık TAKIP_MUAYENE sahipleri); `bekleyen_baslatma_takipte` ayrı sayı. 🔔🌱 eşitliği yalnız uyarılar alt kümesi.
- Doğruluk kuralları §7.1-8 gövdede (yalnız aktif TAI; gelecek "tamamlandi" → `tutarsiz`; `close_reason=NULL` → 'ESKI'; K6 köprüsü `hayvan_id + tohumlama tarihi ∈ [start_date, kapanis+2g]`, eşleşmezse `toh_sonuc='bilinmiyor'`; tanınmayan değer → 'bilinmiyor').
- Bayrak kapalı yolu: `{ok:true, bayrak_kapali:true, satirlar:[]}`.
- **farm_id (#13):** dokunulan tablolarda farm_id kolonu yok [OBSERVED 2026-09-29] → CTE'lere farm_id predikatı YAZILMAZ. P1 `pg_application_event` OKUMAZ (C6 netliği).
- ACL: `STABLE SECURITY DEFINER`, `SET search_path TO 'public','pg_temp'`, `REVOKE ALL ... FROM PUBLIC, anon` + `GRANT EXECUTE TO authenticated, service_role` (kalıp `20260926000003`:106-107). Yeni migration anon GRANT yazmaz (bilinen açık engeli).

## Kaynaklar (mutlak yollar, worktree: /home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip)

- Plan P1: `docs/plans/2026-09-28-ovsync-takip-ekrani/plan.md:229-253`
- Spec §5/§6c.5/§10c: `docs/plans/2026-09-28-ovsync-takip-ekrani/design.md` (hedefli oku; tüm dosyayı değil)
- CTE model kaynağı: `supabase/migrations/20260926000003_ovsync_baslat_uyarilari.sql` (satır 38-104 model, 106-107 ACL kalıbı)
- S2 predicate kaynağı: `supabase/migrations/20260925000002_*.sql` satır 305-320
- PROD envanter karşılaştırma kaynağı: `runs/2026-09-28-ovsync-takip/db-ovsync-durum-raporu.md`
- Demo DB kimlikleri: `/home/melik/egesut-erp1/.env` → `SUPABASE_DEMO_REF/_DB_PASSWORD/_POOLER` (değerleri ekrana/pane basma; betiğe kaynak olarak oku)

## Kabul ölçütleri (plan P1 "Kabul" birebir — DONE'da tek tek kanıtla)

1. `scripts/db-validate.sh` taslak üzerinde **PASS** (rapor çıktısı DONE'a).
2. **Demo prova** (db-validation PASS'ten SONRA): migration demo provada apply → `bayrak_kapali` yolu hem açık hem kapalı bayrakta ölçülür (kanıt: iki koşum çıktısı) → rollback ölçümü.
3. **Anon EXECUTE yok** canlı sorgu kanıtı (demo).
4. KPA sayıları `runs/2026-09-28-ovsync-takip/db-ovsync-durum-raporu.md`'deki mevcut envanterle nokta-doğrulanır — **PROD canlı sorgu YOK** (yalnız mevcut raporla karşılaştırma).
5. **T-45 SQL provası:** `ovsync_takip_listele` S2 kümesi ≡ `gebelik_muayene_listele` kümesi (demo verisinde fark=0); prova verisi COOLDOWN'A GİREN ve GİRMEYEN hayvanı ikisini de içerir; farm_id predikatı yok (grep kanıtı).
6. `node --check` gerekmiyor (SQL-only); `git diff --check` temiz.

## Yasaklar

- PROD erişimi, PROD apply, push/merge/deploy (sahip kapısı).
- `.ss/` ve `main` dalına dokunma; manifest dışı dosya yazma.
- Demo sahip şifresini değiştirme; değerleri hiçbir dosyaya/çıktıya yazma.
- Bilinmeyen yapıda sessiz varsayılan: tanınmayan değer/alan → 'bilinmiyor' işaretle ve DONE'a kaydet; hata gizleme.
- En fazla 2 self-repair turu; sonrasında dur, DONE'a BLOKE yaz.

## DONE şablonu

Başlık: `impl-P1-DONE — TAMAM|KISMI|BLOKE` · madde bazlı kabul kanıtları (yukarıdaki 6 madde) · yazılan dosya listesi · ölçüm komutları + çıktı özetleri · açık kalem/varsa.
