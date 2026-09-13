# Teslim Raporu — G-20260913-TARIH-SECICI (tek kanonik tarih seçici standardı)

**Dal:** `agent/tarih-secici-standardi` · **Base:** `621f12a` · **Durum:** IN_PROGRESS (iskelet — fazlar kapandıkça dolacak)

Not: Owner görev dosyası rapor yolunu `reports/…` istedi; `reports/` gitignore'da olduğu için (`.gitignore:122`) repo'nun izlenen rapor yüzeyi `.harness/reports/` kullanıldı. Root relocate edebilir.

## Faz başı commit SHA'ları

| Faz | Worker teslim | Lead merge | Kanıt |
|---|---|---|---|
| F1 | `73a6a40` (+rapor `ff70ebd`, dal -W1) | `c220b0f` | lead mekanik ölçüm 824/823/1; subagent denetim KABUL (4 DÜŞÜK) |
| F2 | _pending (W2 dalı `-W2`) | _ | _ |
| F3 | _pending | _ | _ |
| F4 | _pending | _ | _ |

## Grep kanıtları

- Başlangıç: `type="date"` = **15** (index.html 14 + js/ui.js 1 dinamik) — görev dosyasının "14" envanteri burada düzeltildi.
- Hedef: 0 — _fazlar kapandıkça doldurulacak_.

## Test çıktıları

- F1 sonrası (lead yeniden ölçüm): `node --test tests/unit/*.test.js` → **824 tests / 823 pass / 1 fail** (tek fail = bilinen kırmızı `gecmis-pipeline.test.js` `_gmGroupHtml`, task öncesi tabanda mevcut).
- _F2-F4: pending_

## Kalan riskler / açık kalemler

- El girişi taslak/odak davranışı (hata re-render'ında odak kaybı; yazılan metin korunur) — W1 raporu açık kalemi, nit UX, owner kararı bekler.
- Guard testi bypass dayanıklılığı (block-comment + bare `Date`) — F4 zarfında kapanış maddesi.
- Altyapı notu (root'a): bu oturumda `ss-wait` bekleyicileri 3 kez sistem low-memory kill yedi (RAM 20/30Gi + swap 30/64Gi doluyken); `report-on-branch` ölçütüyle elle kontrol döngüsüne geçildi. Ayrıca `superset agents list --local` eski kısa agent id'sini (`8f36f1e5`) tanımadı, tam UUID gerekli.
- _Paket kapanışında: luna review bulguları ve çözümleri burada özetlenecek._
