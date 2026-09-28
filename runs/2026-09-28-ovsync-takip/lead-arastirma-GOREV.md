# GOREV — Ovsync takip ekranı araştırması (W1+W2, salt-ARAŞTIRMA)

- DONE (MUTLAK): `/home/melik/egesut-erp1/runs/2026-09-28-ovsync-takip/lead-arastirma-DONE.md`
- Çalışma ağacı: `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip` (dal: `ovsync-takip` @ c9122fd)
- Bu iş %100 araştırmadır: **KOD YAZMA YOK, COMMIT YOK, PUSH/MERGE YOK, DB'YE YAZMA YOK.**
- Yazabileceğin dosyalar (tek-yazıcı; liste dışı YASAK — worktree'ye HİÇ yazma, ağaç temiz kalır):
  - `/home/melik/egesut-erp1/runs/2026-09-28-ovsync-takip/w1-kod-raporu.md`
  - `/home/melik/egesut-erp1/runs/2026-09-28-ovsync-takip/w2-veri-modeli-raporu.md`
  - `/home/melik/egesut-erp1/runs/2026-09-28-ovsync-takip/sentez-tasarim-malzemesi.md`
  - `/home/melik/egesut-erp1/runs/2026-09-28-ovsync-takip/lead-arastirma-DONE.md`
  - Alt-ajan fanout açarsan her alt-ajan YALNIZ kendi rapor dosyasına yazar.

## Kalem tablosu

| # | Kalem | Kabul ölçütü |
|---|---|---|
| 1 | ÖN OKUMA: worktree içinde `.harness/references/domain-rules.md`, `rpc-reference.md`, `ui-map.md` | raporda "okundu" notu + uygulanabilir kural alıntıları |
| 2 | W1: "ileri gebeler" ve "sessiz hayvanlar" dahil dashboard'daki mevcut takip tablolarının anatomisi: veri kaynağı (tablo/RPC/view), sorgu yolu (api.js), render (ui.js), filtre/sıralama, kullanıcı tıklama akışı | her yüzey için dosya:satır kanıtı |
| 3 | W1b: bu desenlerden ovsync takip ekranına yeniden kullanılabilir parçalar + neden yetersiz kaldıkları | madde madde gap listesi (ne eksik) |
| 4 | W2: ovsync vakalarının veri modeli — PROD canlı şema (yalnız okuma): tablolar, vaka/zincir/tedavi-günü yapısı, durum ve sonlanma alanları; takip ekranının ihtiyaç duyacağı alan/sorgu açıkları | alan listesi + eksikler kanıt etiketiyle |
| 5 | SENTEZ: tek-ekran ovsync protokol takip sistemi için tasarım malzemesi (sahiple brainstorm girdisi): ekran deseni seçenekleri + net öneri + mevcut koda entegrasyon noktaları | seçenekler + öneri + entegrasyon noktaları |

## Kurallar (bağlayıcı)

- **ultracode YASAK, Workflow aracı YASAK** — paralellik yalnız builtin Agent fanout (≤4 alt-ajan; tek-yazıcı-per-dosya; farklı dosyalara çoklu yazar serbest, aynı dosyaya tek yazar).
- Kod keşfinde Read/Grep'ten ÖNCE tools-bank MCP `atlas_query` kullan (repo="egesut-erp1"; komutlar: tanim/modul/tablo/rpc/secici). JSDoc yorumları günceldir — dosya okurken başlıklardaki dokümantasyondan yararlan.
- PROD DB yalnız OKUNUR: tools-bank `supabase_query` (SELECT). `supabase_insert/upsert/delete/migrate/rpc` YASAK. Demo DB'ye hiç dokunma.
- Şema sorusunda canlı şema tek yetkili; tanınmayan yapı/alan → "bilinmiyor" diye raporla, varsayma (sessiz varsayılan YASAK).
- AGENTS.md/CLAUDE.md'ye dokunma; Playwright koşma; pkill/kill -9 yok.
- Kanıt etiketleri: `[CONFIRMED dosya:satır]` / `[OBSERVED komut]` / `[INFERRED]` — etiketsiz iddia uydurmadır.
- Kırıntı: her kalem bitiminde `/home/melik/egesut-erp1/.crumbs/ovsync-takip.jsonl`'ye tek satır JSON (type: measurement|decision|open_item).

## DONE şablonu

```
sonuc: TAMAM|KISMI|BLOKE
kalem 1..5: durum + kanıt (rapor dosyası + satır/ölçüm)
fanout özeti: kaç alt-ajan, hangi dosyalar
ana rapor: sentez-tasarim-malzemesi.md yolu
acik_kalemler: varsa
```
