---
id: G-20260913-SURUM-GECMISI
status: in_progress
report_type: lead-teslim
created: 2026-09-13
lead_lane: agent/surum-gecmisi-diff
workers: [agent/surum-gecmisi-diff-W1, agent/surum-gecmisi-diff-W2]
goal: .harness/goals/2026/G-20260913-SURUM-GECMISI.md
---

# L2 Sürüm geçmişi + diff + biletli geri al — Lead teslim raporu (İSKELET)

> Bu dosya lead teslim iskeletidir; teslimde doldurulur. TODO işaretleri
> teslim öncesi kanıtla doldurulacak — boş TODO ile teslim YAPILMAZ.

## 0. Özet
- TODO: tek paragraf — ne teslim edildi, kabul 1-6 sonucu (PASS/PARTIAL).

## 1. Faz başı SHA'lar
| Faz | Dal | Son SHA | Merge (lead dalında) |
|---|---|---|---|
| Goal açılış | agent/surum-gecmisi-diff | f2027d1 | — (taban 621f12a) |
| Sözleşme düzeltmesi | agent/surum-gecmisi-diff | 3674e62 | — |
| F1+F2 DB | agent/surum-gecmisi-diff-W1 | TODO | TODO |
| F3 UI | agent/surum-gecmisi-diff-W2 | TODO | TODO |
| Entegrasyon | agent/surum-gecmisi-diff | TODO | — |

## 2. Kapsam tablosu (F1 tablo envanteri) + gerekçe
- TODO: W1 raporundan — dahil/hariç her tablo için tek satır gerekçe
  (canlı DEMO şema kanıtı: sorgu + çıktı referansı).

## 3. Kabul yeniden-ölçüm sonuçları (lead tekrarı; worker raporu kanıt değil)
- K1 I/U/D log + immutability: **ÇEKİRDEK BAĞIMSIZ ÖLÇÜLDÜ (2026-09-13, demo, rollback-sarmalı probe)** —
  (a) 5 RPC SECURITY DEFINER; ACL: 4 RPC authenticated+service_role, sahip_sifresi_ayarla yalnız postgres+service_role;
  (b) degisim_log şeması goal ile birebir (11 kolon);
  (c) no-op kuralı ✓ (kupe_no=kupe_no → kayıt yok);
  (d) teknikal_mi ✓ (updated_at → t, degisen_alanlar={updated_at});
  (e) immutability ✓ (`ERROR: degisim_log degistirilemez (UPDATE reddedildi)`, BEFORE U+D + TRUNCATE trigger'ları).
  KALAN: tam tablo-matris betiği (W1) + DELETE/TRUNCATE reddi satırı.
- K2 tek txid + trigger yükü: **ÖLÇÜLDÜ** — 100 satır tek tx UPDATE → 100 log satırı / 1 txid ✓;
  yük: açık ~237ms vs kapalı ~141ms / 100 satır ≈ **~1ms/satır** (pooler taban ~90-110ms/komut; oran anlamlı, mutlak süreler pooler'lı).
  KALAN: W1'in formal ölçümü (insert-yönlü) rapora.
- K3 revert matrisi (alan/satır/işlem, çakışma, bağımlılık, bilet, revert-of-revert): TODO — bilinçli ertelendi (W1 betik yazımına karışmamak için); teslimde lead tekrarı.
- K4 unit (taban **796/795/1** — lead bağımsız teyidi; W2 ölçümüyle aynı; 1 fail bilinen kırmızı gecmis-pipeline:283): TODO yeni testler + nihai sayı.
- K5 UI açılış (port 8097/8098, demo DB, ekran görüntüsü): TODO.
- K6 bu rapor: doluyor.

## 4. Sözleşme sapmaları ve kararlar
- degisim_listele eklendi (lead, gerekçe goal'de).
- c9f7fd34: pk biçimi (S1) + opsiyonel txid (S2) — goal 3674e62; çakışma
  kuralı değişmedi.
- sahip_sifresi_ayarla erişimi W1 tarafından service_role ile sınırlandı
  (sözleşmeden sıkı) — TODO: W1 kanıt satırı.
- TODO: W1/W2 raporlarındaki diğer yorumlar.

## 5. Test çıktıları (ham)
- TODO: W1 demo betik çıktısı, W2 unit çıktısı, entegrasyon dumanı.

## 6. Kalan riskler
- TODO.

## 7. PROD DEPLOY ADIMLARI (AYRI BÖLÜM — HİÇBİRİ UYGULANMADI, owner kapısı)
- Önceki borç: 7 migration (devir belgesi §3.1: 20260910000001-3 bugfix →
  20260911000001-3 pedigree P1 → 20260911000004 P2; additive/replay-safe).
- Bu işten: TODO (W1 migration dosya listesi; sıra; her adımın salt-okunur
  teyit komutu; GT regen ayrı adım).
- UYARI: Bu bölüm bir TALİMAT DEĞİL, plan taslağıdır; uygulama yalnız
  owner emriyle, root koşturur.
