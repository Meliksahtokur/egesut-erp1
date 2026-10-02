# ROOT TALEBİ — ovsync-takip canlıya alma (merge + push + PROD DB apply)

- **Talep eden:** ovsync-takip mimarı (oturum `ovsync-takip-67`)
- **Sahip talimatı (2026-10-02):** "rootta merge ve push talebi gönder, canlıya alalım; DB'de canlıya alınmadıysa onu da talep et."
- **Bu belge:** `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/ROOT-TALEP-2026-10-02-canliya-alma.md`
- **Final rapor:** `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/impl-DONE.md`
- **Goal:** `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/.harness/goals/2026/G-20260930-OVSYNC-TAKIP-IMPL.md`

## Kaynak

- Dal `ovsync-takip`, worktree `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip`, uç `9eeb376` (push edilmedi).
- Base `40feed3`; dalda 33 commit. **main bu arada 47 commit ilerledi** (`git rev-list --count ovsync-takip..origin/main`) → merge çakışması olası.
  Bilinen çakışma adayı: `index.html` `?v=` önbellek damgası (dalda `?v=20261001-01`, 26 yer, tek değer). Çakışırsa
  main'deki damgadan BÜYÜK tek bir değere çözülmeli (damga testleri değerden bağımsız).

## 1. PROD DB apply — ÖNCE BU (sıra kritik)

Bu 6 migration **prod'a uygulanmadı** (goal: "PROD apply SAHİP KAPISIDIR — bu goal kapsamında yok"; demo'ya 2026-09-30 22:57
ve 2026-10-01 00:35'te sahip onayıyla uygulandı, raporlar aynı dizinde `impl-demo-apply-2026-09-30.md`, `impl-P12b-DONE.md`):

1. `supabase/migrations/20260929000001_ovsync_takip_listele.sql`
2. `supabase/migrations/20260929000002_takip_gorev_ve_bos_devam.sql`
3. `supabase/migrations/20260929000003_takip_kapanis_tetikleyicileri.sql`
4. `supabase/migrations/20260929000004_tohumlama_gebelik_gorev_kaldir.sql`
5. `supabase/migrations/20260929000005_gebelik_gorev_temizlik.sql` — **veri temizliği** (demo'da 41→1 açık eski
   +21/+35 GEBELIK_KONTROL). Prod'da önce kuru sayım (kaç satır etkilenecek) ölçülüp sahibe gösterilmeli.
6. `supabase/migrations/20261001000001_takip_yerel_gun_duzeltme.sql` — TZ: 4 gövde Europe/Istanbul yerel gün.

**Sıra gerekçesi:** frontend main'e push edilince GitHub Pages hemen yayınlar; yeni UI `ovsync_takip_listele`,
`tohumlama_bos_ve_devam` vb. RPC'leri çağırır. DB önce gitmezse prod'da ovsync sayfası ve Boş akışı kırılır.
Bu yüzden: **DB apply → canlı doğrulama → sonra merge + push.**

Kurallar ve araçlar:
- Runbook: `.harness/runbooks/db-migration.md` (7 adım) — yedek önce.
- Her dosya apply öncesi `scripts/db-validate.sh` (6/6 daha önce PASS; main'le birleşince yeniden koşulmalı —
  main'in 47 commit'inde yeni migration varsa sıra/çakışma kontrolü).
- Main'deki migration'lar bu dosyalardan daha yeni zaman damgası taşıyorsa uygulama sırası ve bağımlılık gözden geçirilmeli.
- Apply sonrası: `scripts/veri-eslesme-kontrol.py hepsi` (demo→prod sızıntı/işaret kontrolü); `schema_migrations` sayımı.
- `deploy.yml` eski workflow — kırmızı "Deploy to Supabase" beklenen gürültü, kullanılmıyor.
- `protokol_ayar.ovsync_pg_kurallari_aktif` prod'da AÇIK (davranış bayrak arkasında).
- Backlog (sahibe bildirildi): `gebelik_muayene_gorev_uret` (eski gövde) CURRENT_DATE yazar; prod cron saati
  TR 00:00–03:00 penceresine düşüyorsa 1 gün kayma — PROD turunda kontrol.

## 2. Merge + push

- `ovsync-takip` → `main` merge; çakışmalar çözülür; main'de birim süiti (`NODE_PATH=... node --test tests/unit/*.test.js`;
  dalda 1420/1418/2 — kırmızı küme baseline: LUNA-3 canlı-DB + `ay ‹/›`), `node --check js/*.js`, `git diff --check`.
- Push → GitHub Pages yayını; yayın sonrası prod'da ovsync sayfasının açıldığına bakılmalı.
- Merge sonrası dal kapanışı (sahip kuralı: birleşmiş dal sormadan kapatılır, yedek etiketle).

## 3. Ayrı kalem — tools-bank sonnet kolu (commit'lenmedi)

Sahip onaylı (2026-10-01) SARI eklenti: `ss-worker-sonnet-{low,medium}`, `ss-lead-sonnet-{low,medium}`.
Dosyalar (`/home/melik/tools-bank/.superset/`): `bin/ss-role-sonnet`, `bin/ss-role-sonnet-low`, `bin/ss-role-sonnet-medium`
(yeni), `bin/ss-seat`, `bin/ss-role-common`, `bin/ss-conformance`, `roles/matrix`, `roles/compose.map` (değişik).
`/home/melik/tools-bank` checkout'u şu an `report/herdr-koltuk-olcum-2026-09-25` dalında — mimar oraya commit
ATMADI (yanlış dal). Doğru dala commit/push root'un kararı. `ss-conformance --with-superset`: tek FAIL [6/8]
önceden var (superset ikilisi PATH'te yok). Geri alma yedeği: `/home/melik/tmp/ss-sonnet-rollback-1815/`.

## Bilinmesi gerekenler (impl-DONE §2–§5 özeti)

- UI kapısı: 25 madde → 24 PASS + madde 12 ratifiye kısmi (sunucu PG kararı göndermiyor, TB-5). Sahip demo'yu test edecekti.
- e2e: ui-fix1 A/B ile regresyonsuz; akşam demo'da 8–9/12 — kök neden test ortamı (TB-6: `temizle()` hiç çalışmıyor).
- Teknik borç TB-1..TB-7 goal dosyasında.

## Dönüş

Mimar oturumu `ovsync-takip-67` (adres değişebilir — `ListAgents`). Sonuç ya da soru için SendMessage.
