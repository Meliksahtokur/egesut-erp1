# Goal B — Sessiz takipten vaka sürgününü kaldır + dashboard bandı sıralaması

**Tip:** backend view (migration) + frontend band · **Hat:** external worker + izole worktree
**Öncelik:** P1 · **Sahip:** glmf worker W2

## Zorunlu okuma (sadece bu aralıklar — dosyaların tamamını OKUMA)

1. `.claude/goals/assets/v_eligible_canli.sql` — **canlı prod view tanımı** (30 satır). Bu gerçekliktir; `ground_truth.sql` ve `supabase/migrations/20260531*.sql` içindeki kopyalar BAYAT, onlara bakma.
2. `js/ui.js` satır **205-235** — `_dashBands()` içindeki Sessiz Hayvanlar bandı (`sessizList.slice(0,5)`)

## Ölçülmüş olgular — bunları ARAMA, doğrula ve kullan

| olgu | kaynak |
|---|---|
| Canlı `v_eligible` içinde `AND NOT (EXISTS ( SELECT 1 FROM cases c WHERE c.animal_id = h.id AND c.status = 'active'::text))` filtresi VAR | asset dosyası (tek `cases` referansı) |
| Bu filtre yüzünden kupe 147 (id `3b8b66ba-3c29-4e20-b494-043737125fef`, ~194 gün sessiz, tek engel bu filtre) listede yok | canlı prod doğrulandı |
| `sessiz_hayvanlar_reconcile()` ve `stat_suru_ozet` bu view'ı okur; filtre kalkınca 147 otomatik listeye/göreve düşer | `supabase/migrations/20260625000020_sessiz_reconcile.sql` |
| RPC `sessiz_hayvanlar_listele` listeyi `sessiz_gun DESC` sıralar → 9999'luklar (hiç sinyali olmayan hayvanlar) her zaman üstte | `supabase/migrations/20260531400000_sessiz_hayvan_yas_filtresi.sql` |
| Dashboard bandı `sessizList.slice(0,5)` — 9999'luklar yer işgal edince gerçek vakalar görünmez | js/ui.js:216 |
| `stat_suru_ozet`'te eşik zaten 55 (20260625000030) — DOKUNMA | migration |

## Sorun

1. **Aktif vaka, hayvanı sessiz takipten kalıcı sürgüne gönderiyor.** Vaka kapatılmayı unutulursa (147 vakası — Mayıs'tan beri açık) hayvan hiçbir güvenlik ağına düşmüyor. Üreme takibi hastalık/tedavi durumundan bağımsız çalışmalı.
2. **Dashboard bandında sinyalsiz hayvanlar (sessiz_gun=9999) gerçek vakaları eziyor** — abort yapmış sağımalılar bandda hiç görünmüyor.

## Kapsam — iki adım, fazlası değil

### Adım 1 — Migration: `supabase/migrations/20260830000020_sessiz_vaka_filtresi_kaldir.sql`

- Asset dosyasındaki canlı `v_eligible` tanımını **birebir** al, TEK farkla: `AND NOT (EXISTS ( SELECT 1 FROM cases c ...))` satırını çıkar.
- Başka hiçbir satıra dokunma (sessiz_gun CASE'i, yaş filtresi, LATERAL join'ler, tüm filtreler aynı kalsın).
- Dosya sonuna: `NOTIFY pgrst, 'reload schema';`
- Uyarı: view tanımında `CREATE OR REPLACE VIEW public.v_eligible AS` + asset'teki SELECT'in aynısını yaz; kolon sırası DEĞİŞMEZ.

### Adım 2 — `js/ui.js` sessiz bandı (satır ~213-225)

- `sessizList.slice(0,5)` çağrısını şununla değiştir: kopya liste üzerinde 9999'lar EN SONA gelecek şekilde sayısal artan sırala (`sessiz_gun===9999` en son), `slice(0,8)`.
- Bandın başlığındaki sayaç (`sessizList.length`) olduğu gibi kalsın — sadece görünen sıra/limit değişiyor.

## Yazma manifesti

```
supabase/migrations/20260830000020_sessiz_vaka_filtresi_kaldir.sql (YENİ)
js/ui.js
```
Manifest dışında HİÇBİR dosyaya yazma. `ground_truth.sql`'e DOKUNMA.

## §Kabul

1. `node --check js/ui.js` → exit 0
2. `grep -c "cases" supabase/migrations/20260830000020_sessiz_vaka_filtresi_kaldir.sql` → **0**
3. Migration'da `CREATE OR REPLACE VIEW public.v_eligible` var
4. `git diff --stat` → yalnız manifest'teki dosyalar
5. `attempts.md` dolu (başarısız yaklaşım yoksa içi tam olarak `## no failed attempts`)
6. Canlı DB erişim denemesi yok

## Sınır

- Commit: kendi worktree'inde tek commit (`fix: drop case filter from v_eligible, reorder sessiz band`); **push YASAK**
- Canlı prod'a erişim YASAK
- Max elapsed: 15 dakika
