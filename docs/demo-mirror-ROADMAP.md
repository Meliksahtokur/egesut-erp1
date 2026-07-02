# Demo-Mirror (Demo Hesap) — Yol Haritası

> **Seçilen mimari: Seçenek D** — ayrı Supabase projesi + FDW köprüsü + tek-tık/saatlik klon.
> Araştırma: `research/2026-07-01-demo-hesap-mirror-arastirma/rapor.md` (+ `rapor-L-rpc-drift-audit.md`)
> İlgili disiplin: `.claude/farm-id-discipline.md` (D, aynı zamanda Faz 2 staging'i olarak ikiye katlanır)
> Durum: **PLAN — implementasyon başlamadı** (2026-07-02). Ön-koşul olan farm_id ileri-disiplini ✅ BİTTİ (commit `0e421f3`).

## Amaç

Login ekranında "🧪 Demo Girişi" butonu → ayrı Supabase projesinde gerçek verinin **kopyası**. Demo'daki yazmalar **geçici**: prod → demo klon her tetiklendiğinde üzerine yazılır. Tetik iki yoldan: **pg_cron (saatlik)** + **UI "↻ Prod'dan Klonla" butonu**.

## Mimari Özet

```
KULLANICI ──┬─ gerçek giriş ──▶ PROD PROJESİ (canlı, read-only kaynak)
            └─ 🧪 demo giriş ─▶ DEMO PROJESİ (klon şema, geçici yazma)
                                     │
                                     └─ postgres_fdw ──▶ PROD'u OKUR (pull)
                                        (yön: demo→prod; prod demo'yu GÖRMEZ
                                         → canlı veri asla kirlenmez)
```

- Prod ↔ Demo **iki ayrı proje** — şema birebir aynı (`ground_truth.sql`).
- Köprü tek yönlü: demo, prod'u **okur**. Prod demo'ya erişmez.
- **service_role ASLA client-side** — demo de anon key + RLS `USING(true)` ile çalışır (prod ile aynı model).
- FDW auth için prod'da **read-only rol** (demo yanlışlıkla prod'a yazamaz).

## Fazlar

| Faz | İş | Efor | Durum |
|---|---|---|---|
| **D0** | Yeni Supabase projesi + şema taşı (`ground_truth.sql`) + demo@ kullanıcısı + uzantı doğrula | ½ gün | ⬜ |
| **D1** | FDW köprüsü: `CREATE SERVER`/`USER MAPPING`/`IMPORT FOREIGN SCHEMA` + read testi | ½ gün | ⬜ |
| **D2** | `demo_klonla()` RPC: FK-ters TRUNCATE + FK-düz INSERT..SELECT + `setval` — tek transaction + `demo_klon_log` | 1 gün | ⬜ |
| **D3** | pg_cron saatlik + **şema-senkron adımı** (prod migration'ı demo'ya replay) | ½ gün | ⬜ |
| **D4** | UI: `config.js` `IS_DEMO` host-tespiti + demo client + login butonu + demo bandı + "↻ Klonla" | 1 gün | ⬜ |
| **D5** | Sağlamlaştırma: yazma-geçicilik teyidi, service_role client'ta yok kontrolü, klon sırası UI kilidi, deploy | ½ gün | ⬜ |

**Toplam: ~4 gün efor (≈1 hafta takvim).** Faz 2 multi-tenant (~3-4 hafta) DEĞİL — D bilinçli olarak hafif tutuldu.

## Klon RPC Mantığı (D2)

1. **FK-ters sırayla TRUNCATE** (çocuk→ebeveyn: gorev_log, tohumlama, tedavi… önce).
2. **FK-düz sırayla `INSERT..SELECT FROM prod_fdw.*`** (ebeveyn→çocuk: hayvanlar, padoklar… sonra).
3. Her tablo için `setval(seq, max(id))` sequence senkron.
4. Tamamı **tek transaction** (BEGIN..COMMIT — ya hep ya hiç, yarım-klon yok).
5. `demo_klon_log` audit tablosu (tarih, süre, satır sayısı) — **farm_id disiplini**: `farm_id uuid NOT NULL DEFAULT REAL_FARM_ID`.

FK sırası **elle değil**, `ground_truth.sql` tablo bağımlılık grafiğinden topolojik türetilir.

## Kritik Kararlar / Tuzaklar

| Konu | Karar | Neden |
|---|---|---|
| Köprü yönü | demo → prod OKUR | Prod görmez → canlı veri kirlenmez |
| service_role | ASLA client-side | RLS bypass eder (Supabase maintainer uyarısı) |
| FDW auth | prod read-only rol | Demo prod'a yazamaz |
| Klon atomikliği | tek transaction | Yarım-klon = tutarsız demo |
| FK sırası | ground_truth graph'tan | Elle sıralama = kaçınılmaz FK hatası |
| Demo yazma | kalıcılık YOK | Sonraki klon üzerine yazar (istenen) |

## ⚠️ Tek Uzun-Vade Riski: Şema Drift

Prod'a yeni tablo/migration eklenince demo şeması eskir → `demo_klonla()` yeni tabloyu bilmez → klon eksik/patlar. **Çözüm (D3):** prod migration'larını demo'ya da replay eden basit senkron script (veya haftalık `ground-truth-audit.sh` benzeri şema-diff denetimi).

## Faz 2 Bağlantısı

D'nin ayrı projesi, ileride **Faz 2 multi-tenant staging'i** olarak kullanılabilir — farm_id disiplini bugün aktif olduğu için yeni nesneler zaten tenant-hazır doğuyor. Bkz `ReFactorRoadmap.md` Faz 2.
