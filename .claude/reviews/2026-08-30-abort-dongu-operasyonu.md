# Operasyon Raporu — Abort → Üreme Döngüsüne Dönüş (2026-08-30)

**Tetik:** Kullanıcı raporu — abort yapılan hayvanlar (147, 150) döngüye geri girmiyor, sessiz hayvanlar listesinde görünmüyor.
**Yöntem:** ilan-arastirma goal disiplini + 2 paralel glmf worker (`glm-53-flash-max`, tb-worker broker, worktree-per-lane). Lead: ölçüm, goal dosyaları, review, canlı uygulama, push.

## Teşhis (kanıtla)

| Bulgu | Kanıt |
|---|---|
| `v_eligible`'ın "aktif vaka yok" filtresi hayvanı sessiz takipten kalıcı sürgün ediyordu | 147: 2026-05-24 post-abort tedavi vakası açık kaldı → 6 ay SESSIZ görevi üretilmedi |
| Abort sonrası hiçbir takip mekanizması yoktu | `tohumlama_abort` yalnız sonuc='Abort' yazıyordu; 150 v_ureme_dongusu'nda açık Abort cycle'ında donmuştu |
| Dashboard bandı 9999'luk sinyalsizlerle doluyordu | `sessizList.slice(0,5)` + RPC DESC sıralama |
| islem_log'a çift ABORT_KAYDI düşüyordu | `tohumlama_abort` RPC + `trg_islem_tohumlama_abort` trigger ikisi de yazıyordu (147, 150'de birebir doğrulandı) |

## Değişiklikler (a5a2571 → 541a686)

| Commit | İçerik |
|---|---|
| `508f5e1` | **G2** (worker W1): `tohumlama.abort_tarihi` kolonu + islem_log backfill + `tohumlama_kaydet` VWP çapası (`ABORT_VWP_VIOLATION:gun:55`) + `tohumlama_abort` 3-param + forms.js tarih prompt'u ve confirm akışı |
| `2082842` | **G1+G3** (worker W2): `v_eligible`'dan vaka filtresi kaldırıldı + dashboard bandı (9999 sona, limit 8) |
| `59d03c2` içinde | **G4**: `_islem_log_yaz` trigger'ının tohumlama UPDATE kolu sessizleştirildi (çifte log fix) |
| `2fabd90` | gebe-sonrası-abort mesajı (`tohumlama_sonuc_gebe` CASE) + `tohSonuc` catch spesifik mesaj + `openIslemDetay` ABORT_KAYDI yönlendirme düzeltmesi |
| `2fb3610` | toh-det modalına "↩ Abort İşlemini Geri Al" butonu (ABORT_KAYDI log hedefli) |
| `541a686` | `geri_al` guncellenen döngüsüne uuid PK fallback (`operator does not exist: uuid = text` fix) |

Migrations: `20260830000010`, `...20`, `...30`, `...31`, `...32` — hepsi canlıya uygulandı (Mgmt API, curl).

## Canlı doğrulama (tümü geçti)

- `sessiz_hayvanlar_listele` → 147 (194g) + 178/174/144/200 listede; 150 (286g) duruyor
- Reconcile elle tetiklendi → `uretilen: 5` (kurtarılan 5 hayvana VETERINER_KONTROL)
- Negatif test: 150'ye bugün tohumlama → `ABORT_VWP_VIOLATION:4:55` (satır 46), kayıt sayısı değişmedi
- Regresyon: 110'a (11g önce doğum) → eski `VWP_VIOLATION:11:55` (satır 51) — iki yol ayrık
- Test inek 2 gerçek abort → TEK ABORT_KAYDI logu, `abort_tarihi` default bugün
- Abort sonrası gebe işaretleme → açıklayıcı mesaj döndü, kayıt bozulmadı
- `geri_al` uuid fallback sonrası abort undo: `ok:true`, sonuc='Gebe' restore, log `geri_alindi`

## Dersler

1. **ground_truth.sql'in RPC gövdeleri bayat** — canlı `tohumlama_kaydet` 172 satırdı (protokol entegrasyonu, otomatik Boş temizleme). RPC yeniden tanımlamadan önce canlı gövde Mgmt API `pg_get_functiondef` ile çekilip asset olarak goal'e gömüldü; worker yalnız hedef bloğu değiştirdi. Asset'ler: `.claude/goals/assets/*_canli.sql`.
2. **Regex alt-dize tuzağı:** `ABORT_VWP_VIOLATION`, `VWP_VIOLATION` içerir → abort dalı önce test edilmeli.
3. glmf worker'lar goal disipliniyle (ölçülmüş olgular + yazma manifesti + §Kabul + attempts.md) tek seferde kabul edildi; W2 `grep -c cases` tuzağını ve blast-radius hook'unu kendi çözdü.

## Review turu (code-reviewer subagent, bağımsız)

Verdict: **With fixes** — 14 bulgu + 1 regresyon notu. İşlenenler (`7964157` + `a1cb780`, migration 33+34):

| # | Şiddet | Bulgu | Durum |
|---|---|---|---|
| 1 | High | geri_al crafted-snapshot → keyfi tablo DELETE/UPDATE (uuid fallback freni kaldırmıştı) | ✅ whitelist öndoğrulama (15 tablo, üretim envanterinden) |
| 2 | Medium | EXCEPTION WHEN others her şeyi yutuyordu | ✅ SQLSTATE 42883/22P02 ile daraltıldı |
| 5 | High | **Band comparator artan sıralıydı** — en az sessiz 8 hayvanı gösteriyordu (lead review'ı da kaçırmıştı) | ✅ azalan + 9999 son bucket |
| 6 | High | Eski abort'u restore etmek hayalet gebelik üretiyordu (son-cycle guard yok) | ✅ isSonToh + durum!=='geri_alindi' guard (server-side RPC kuralı — sonraki tur) |
| 7 | Medium | p_abort_tarihi valide edilmemişti (negatif VWP → override'sız kilit) | ✅ server validasyon + `-?` regex backstop |
| 8 | Medium | Abort override'ı audit edilmüyordu | ✅ anchor_tip/anchor_date ile audit |
| 9 | Medium | legacy abort_kaydet bypass (tarihsiz, logsuz) | ✅ REVOKE authenticated/anon |
| 10 | Medium | Abort açık gebelik-kontrol görevlerini bırakıyordu | ✅ gorev iptal + protokol iptal |
| 11 | Low | 6 trigger-yazması abortta abort_tarihi fallback tohumlama tarihiydi | ✅ snapshot'tan düzeltildi (kalan NULL: 0) |
| 12 | Low | Bayat _vwpOverride flag'i başka submit'i geçiyordu | ✅ catch'te reset |
| 14 | Low | attempts.md repo köküne commitlenmişti | ✅ git rm |
| 3,4,13 | Low | anon grant (25 migration'lık konvansiyon), onclick interpolasyonu (önceden var), prompt Cancel/UTC default | 📋 kayıtlı — refactor turlarına |
| Reg. | Medium | v_eligible filtre kaldırmanın reconcile/KPI'ya etkisi | ✅ bilinçli tasarım — kullanıcı kararı (vaka sürgün istenmedi) |

Canlı doğrulama: ileri-tarihli abort reddi ✓, kalan NULL abort 0 ✓, re-abort→undo tam döngü `ok:true` + Gebe restore ✓.

## Açık

- "Sistem geçmişi" ekranı (loadGecmis) islem_log listelemiyor — abort undo yüzeyi hayvan kartında (toh-det modalı + geçmiş paneli). Sistem geneli undo istenirse ayrı iş.
- Eski çift ABORT_KAYDI satırları (147/150) temizlenmedi — audit append-only, dokunulmadı.
- #6'nın server-side kurallı hali (`tohumlama_abort_geri_al` RPC) sonraki tur için öneri.
