# DONE — ovsync sonrası borç turu (2026-10-02)

- **Sonuç:** TAMAM (dal teslimi). PROD apply / merge / push sahip kapısında — aşağıda talep.
- **Goal:** /home/melik/.herdr/worktrees/egesut-erp1/ovsync-sonrasi/.harness/goals/2026/G-20261002-OVSYNC-SONRASI-BORC.md (status: delivered)
- **Dal / worktree:** `ovsync-sonrasi` @ `c142492` — /home/melik/.herdr/worktrees/egesut-erp1/ovsync-sonrasi (taban `ffdc342`, 11 commit)
- **Sahip kararları (2026-10-02):** önerilen sıra tümü; TB-1 arşivle; UI kapısı ss-worker-sonnet-medium koltuğu; prod yalnız-okuma serbest; "tamam gönder" (UI kapısı bekletilmeden açıldı).

## Kalem tablosu

| # | Kalem | Durum | Commit | Kanıt |
|---|---|---|---|---|
| 1 | B9 `gebelik_muayene_gorev_uret` cron saati | TAMAM — **kayma YOK**: cron `10 5 * * *` GMT = TR 08:10; TR≠UTC gün satırı 0/134; migration gerekmedi | — | /home/melik/egesut-erp1/runs/2026-10-02-ovsync-sonrasi/k1-B9-DONE.md (+ mimar spot-check cron.job [OBSERVED]) |
| 2 | GT refresh (runbook adım 6) | TAMAM — 21 fn (md5 canlı=GT 21/21), 3 trigger, 1 kolon; audit farkı 92→79 | `9ecd6a0` | /home/melik/egesut-erp1/runs/2026-10-02-ovsync-sonrasi/k2-GT-DONE.md |
| 3 | TB-6 e2e `temizle()` | TAMAM — kupe_no ile arama, fail-closed hata, FK'lı hayvan Satıldı; E2E aktif 0 (×6); e2e **12/12 ×2** (T-01/T-20 = test IDB-pull beklemesi; T-84/T-85 regresyon değil, A/B 4/4) | `626e3ee`, `5e8466e` | k3-TB6-DONE.md, e2e-triyaj-DONE.md (aynı dizin) |
| 4 | TB-1 ui-tur betiği | TAMAM — arşivlendi (kopya, kaynak silinmedi) | — | /home/melik/egesut-erp1/runs/2026-10-02-ovsync-sonrasi/arsiv-tb1/ARSIV-NOTU.md |
| 5 | TB-5 `_pg_kapi_detay.karar` | TAMAM — migration `20261002000002` (yalnız ekleme), db-validate e98ae410 PASS, demo prova 3/17→17/17; UI zaten okuyordu → 11 birim test; demo'ya kalıcı apply + schema_migrations kaydı | `bf35723`, `20766cb` | k5a-TB5-SQL-DONE.md, k5b-TB5-UI-DONE.md, /home/melik/egesut-erp1/reports/db-validation-e98ae410.md |
| 6 | TB-7 S0 TAI bugün/yarın | TAMAM — tarayıcı T10/T11 PASS ("TAI bugün 10:00" + ▶ TAI kaydet; "TAI 1 gün sonra 10:00") | — | ui-kapi-DONE.md |
| 7 | TB-3 render zaman aşımı | TAMAM — 15 sn zaman aşımı/ret → hata + Tekrar Dene; birim 5/5 kırmızı→yeşil; tarayıcı T2–T4 PASS | `d6ea1dd` | k7-TB3-DONE.md |
| 8 | TB-2 `demo_sema_diff` 401 | TAMAM — kök: oturumsuz anon çağrı (fn demo-özel, yalnız authenticated); js/demo.js oturum sonrası bir kez; birim 4/4; tarayıcı T1 PASS (401 yok) | `f9ca7b6` | k8-TB2-DONE.md, k8b-TB2-FIX-DONE.md |
| 9 | TB-4 ram-pool (tools-bank) | KAPSAM DIŞI — ram-pool 2026-10-01 deaktif; root'a bildirildi | — | crumb |
| — | Damga | `?v=20261002-02` (26 yer) | `b986755` | — |
| — | UI kapısı | **PASS 12/12** (ss-worker-sonnet-medium koltuğu, demo) | — | /home/melik/egesut-erp1/runs/2026-10-02-ovsync-sonrasi/ui-kapi-DONE.md + ui-kapi-kanit/ |

Genel ölçümler: birim 1511/1509/2 (2 = baseline kırmızılar: takvim etiketi tarih-sabit + LUNA-3 canlı demo şeması) [OBSERVED mimar koşumu]; demo `kupe_no LIKE 'E2E-%'`/`'UIK-%'` aktif = 0 [OBSERVED koltuk T12].

## Sahip kapısında bekleyenler (root üzerinden talep)

1. **PROD apply `supabase/migrations/20261002000002_pg_kapi_detay_karar.sql`** — runbook /home/melik/egesut-erp1/.harness/runbooks/db-migration.md adım 2–7: yedek → dry run → tek transaction apply → `schema_migrations` kaydı → GT'ye `_pg_kapi_detay` gövdesi (adım 6) → doğrulama. Yalnız ekleme; UI N-1 uyumlu (UI önce yayınlanırsa yedek metin gösterir) — sıra: önce DB önerilir.
2. **Merge** `ovsync-sonrasi` @ `c142492` → main (+ `veri-eslesme-kontrol.py hepsi` prod apply sonrası).
3. **Push** (Pages yayını; damga `?v=20261002-02`).
4. Merge sonrası dal kapanışı + hasat: `runs/2026-10-02-ovsync-sonrasi/` (gitignore → `git add -f`), `.crumbs/ovsync-sonrasi.jsonl`.

## Açık kalemler / backlog (bu turda düzeltilmedi)

- **GT bakiyesi:** 2026-09-15–09-27 dönemi 79 audit farkı (2 eksik tablo `gorev_ertele_kural`, `pg_application_event`; 34 fn; 41 trigger bağı) — ayrı GT senkron kalemi.
- **UX:** ilk IDB pull sırasında Üreme/Tohumlama listesi "Arama sonucu yok" gösteriyor ("yükleniyor" ayrımı yok).
- Boş bağlam ilk pull'da `IDBObjectStore put key path` konsol uyarısı (kök UNKNOWN).
- Vaka detayında seans ✓ (`seansTamamla`) butonu tarayıcıda bulunamadı (T8 fonksiyon doğrudan çağrılarak kanıtlandı) — kontrol önerilir.
- `js/forms.js:3295` `vaka_toplu_ac` satırında `pgKarar: null` → o yolda PG etiketi yok.
- TB-3: yeniden yüklemede spinner yerine eski içerik kalıyor (hata dalı zamanında geliyor); `ovsyncTakipGetir` ağ çağrısı askıda kalma riski kapsam dışı.
- B9 savunma: elle TR 00–03 çağrısına karşı Istanbul kalıbı opsiyonel (bugün çağrı yok).
- `gitnexus_impact` `/root/egesut-erp1` izin hatası (araç).

## Rol notu
Mimar rolü "dal açmaz/commit atmaz" der; zarf "dal + commit ile teslim" istedi — zarf izlendi (crumb'da kayıtlı). İmplementasyon builtin sonnet alt-ajanları + herdr sonnet-medium koltuklarıyla yazdırıldı; mimar her teslimde yük taşıyan iddiayı kendisi doğrulayıp commit'ledi.
