# impl-P2b — GOREV zarfı: `tohumlama_bos_ve_devam` sarmal RPC — modlar

- **Goal:** `G-20260930-OVSYNC-TAKIP-IMPL` (active)
- **Plan madde:** **P2b** — `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/docs/plans/2026-09-28-ovsync-takip-ekrani/plan.md:279-342` (MADDE DRIFT KAPISI: yalnız P2b; P2c/P2d/P3a/P3b YOK). **Bu madde planın en yoğun sözleşmesidir — plan satırlarını eksiksiz oku, imza ve sözleşmeler oradan KESİN alınır; bu zarf yalnız yol gösterir.**
- **GOREV (bu dosya):** `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/impl-P2b-GOREV.md`
- **DONE:** `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/impl-P2b-DONE.md`

## Yazma manifesti (TEK YAZICI — liste dışı YASAK)

1. `supabase/migrations/20260929000002_takip_gorev_ve_bos_devam.sql` (MODIFY — P2a'nın dosyasını devralır; P2a bölümüne dokunma, dosyaya P2b bölümünü ekle)
2. `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/impl-P2b-DONE.md` (create)

Prova betikleri geçici dizine (`/home/melik/tmp/agents/` altına) yazılır — repo içine değil; kanıt çıktıları DONE'a gömülür.

## Zorunlu davranış protokolü

1. **İLK İŞ:** `/home/melik/.claude/skills/using-superpowers-obra/SKILL.md` oku ve uygula (sahip kuralı; SUBAGENT-STOP geçersiz).
2. **SQL yazmadan ÖNCE:** `.harness/references/domain-rules.md` oku; çelişkide dur, DONE'a yaz.
3. **PostgreSQL LSP zorunlu (sahip talimatı):** hover/typecheck/completion. Bilinen false-positive sınıfları (kayda al, engel sayma): p_* fonksiyon parametreleri CTE/gövdede; yeni nesneler PROD-öncesi aynada görünmez; psql `\` meta-komutları parser hatası verir.
4. **db-validation KAPISI:** WORKTREE İÇİ yoldan (`/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/scripts/db-validate.sh`) — rapor worktree `reports/` altına düşmeli. Taslakta PASS şart.
5. **Bitiş kapısı:** `verification-before-completion-obra` — her iddia [CONFIRMED dosya:satır]/[OBSERVED komut] etiketli.

## Görevin omurgası (ayrıntı plan.md:279-342'de — oradan oku)

**1. Sarmal RPC** `tohumlama_bos_ve_devam(p_tohumlama_id, p_muayene_gorev_id, p_secim, p_pg_urun, p_pg_doz, p_gun, p_saat, p_notlar, p_onay) RETURNS jsonb` — SECURITY DEFINER, TEK transaction. İza plan.md:288-297'den birebir.

**2. XOR + tip guard'ları (#9):** `GIRIS_CIFT_ANLAMLI`, `MUAYENE_GOREV_TIPI_UYUMSUZ`, `TOH_SONUCLU:{...}`, `TAKIP_KAPALI:{...}`.

**3. Kilit sözleşmesi (MK9-N + §10h H3 — KURALDIR):** tüm durum kontrollerinden ÖNCE: (1) `hayvanlar` FOR NO KEY UPDATE (İLK erişim, hayvan-başına muteks); (2) `tohumlama` FOR UPDATE; (3) muayene yolunda `gorev_log` FOR UPDATE — İSTİSNA H3: sarmal tohumlamayı takip gorev_log'undan ÖNCE kilitler (AB/BA keser). `tohumlama_sonuc_gebe`'nin kilit-sonra-durum deseni TERS çevrilir: ÖNCE kilit, SONRA durum kararı.

**4. Dry-run (`p_secim=NULL`):** plan.md:300 alan listesi birebir. **C6:** `son_pg` sorgusu `pg_application_event` okur — dokunulan tablolar arasında farm_id TAŞIYAN TEK tablo → `farm_id = public.current_farm_id()` filtresi ZORUNLU (index `(farm_id, hayvan_id, occurred_at DESC)`); diğer tablolara farm_id predikatı YAZILMAZ.

**5. Seçim uzayı (ACIK TABLO):** Boş yolu `{OVSYNC, PG, TAKIP}`; GEBELIK_KONTROL `{GEBE, OVSYNC, PG, TAKIP, ERTALE}`; TAKIP_MUAYENE `{GEBE, OVSYNC, PG, ERTALE}` (TAKIP hariç → `TAKIP_YENIDEN_SECILEMEZ`); tablo dışı → `SECIM_TANIMSIZ:{secim,gorev_tipi}`. DB CASE ifadesiyle; UI tarafı P8'in işi.

**6. GEBE modu + D1 çekirdek:** `_tohumlama_gebe_uygula(p_tohumlama_id, p_bos_duzeltme) RETURNS jsonb` — `tohumlama_sonuc_gebe`'nin ortak gövdesi buraya taşınır; RPC çekirdeği çağırır (Bekliyor-only kural çekirdeğin `p_bos_duzeltme=false` kolunda yaşar; genel RPC davranışı BİTİŞİK kalır). Çekirdek ACL: PUBLIC/anon/authenticated'a KAPALI, yalnız sarmal çağırır. `p_bos_duzeltme=true` 5 koşul seti plan.md:304 (biri eksik → `BOS_DUZELTME_KOSUL:{eksik...}`). D1 yan-etki tablosu plan.md:305-325 (geri ALINMAZLAR dahil); `bos_atama_tarihi` normatif çözücüyle (plan.md:316-324 SQL birebir — Europe/Istanbul yerel gün, `geri_alindi` hariç, EN SON kazanır).

**7. Boş yolu (§10h H1):** Boş çekirdeği davranışı sarmalın gövdesinde YENİ kod (yan etkiler birebir, referans `20260924000001:508-570`); PG kapısı da bu yolu kullanır. **Mevcut `tohumlama_sonuc_bos` RPC'sine DOKUNULMAZ.**

**8. OVSYNC/PG/TAKIP/ERTALE modları:** plan.md:327-330 (kısırlık/erken redler; PG çekirdeği `hizli_uygulama`'dan; TAKIP'te `_acik_disi_gorev_kur` ATLANIR; ERTALE saatsiz varsayılan + `TAKIP_UZADI:{toplam_gun}` 21 g eşiği `p_onay` ile).

**9. TAKIP_ACIK kapısı (DEGISMEZ 3) + birleşik kapı (#4):** plan.md:331 — `PG_KAPI:TAKIP_ACIK:{...}` tek payload, tek `p_onay`.

**10. Bayrak kapalı (#6 + MK9-K):** dry-run `{bayrak_kapali:true}`; yazma modları `RAISE 'OZELLIK_KAPALI'`.

**11. Muayene görevi tamamlanma sözleşmesi:** ERTALE hariç `tamamlandi=true + tamamlanma_tarihi=now()`; jenerik `gorev_tamamla` taşviyesi P3b'nin işi (dokunma).

## Kabul ölçütleri (plan P2b "Kabul" birebir — plan.md:340)

1. `scripts/db-validate.sh` (worktree yolu) taslakta **PASS**.
2. Demo provada: Boş yolu 3 seçim + tüm redler; muayene yolu GEBE/OVSYNC/PG/ERTALE; TAKIP_UZADI eşiği (21 g seed'le); birleşik kapı payload'ı; bayrak-kapalı yolu.
3. **Tek transaction kanıtı:** PG adımı patlatılınca Boş ataması da geri alınır (T-08..T-11 provası).
4. **D1 provası 4 kalem:** (1) TAKIP_MUAYENE'den Gebe — Boş→Gebe + GEBE_BULUNDU + `bos_duzeltme` izi; (2) yan-etki tablosu satır satır geri-alınma kanıtı (SQL çıktısı prova ekine); (3) genel `tohumlama_sonuc_gebe` Boş'u hâlâ REDDEDER (sızıntı yok); (4) çekirdeğe REST'ten doğrudan çağrı RED (authenticated EXECUTE yok).
5. **T-72/T-73 yarış provası** (§10h H7): koşulabilir çiftlerde iki bağlantılı betik, `lock_timeout='5s'`, sonuç oracle'ı: 40P01/55P03 YOK + sonuçlar izinli kümede. Koşulamayan çift (ör. P3a tetikleyicisi henüz yok → 5. çift) DONE'a **ertelenmiş** olarak belgele — BLOKE değil, gerekçesiyle.
6. `git diff --check` temiz; anon/PUBLIC EXECUTE yok (sarmal dahil tüm yeni fonksiyonlar).

## Yasaklar

- PROD erişimi/apply; push/merge/deploy; commit atma (mimar toplar).
- `.ss/`, `main`, manifest dışı repo dosyası.
- `tohumlama_sonuc_bos` ve `tohumlama_sonuc_gebe` gövdelerinde davranış değişikliği (çekirdeğe taşımak hariç — davranış bitişik).
- Sessiz varsayılan; en fazla 2 self-repair turu sonra DONE'a BLOKE yaz.

## DONE şablonu

Başlık: `impl-P2b-DONE — TAMAM|KISMI|BLOKE` · kabul maddeleri (6) tek tek kanıtlı · koşulan prova komutları + çıktı özetleri · ertelenen çiftler gerekçeli · yazılan dosyalar · açık kalem.
