# Idle-C Raporu — UI Altyapı + Test Derinleşme (ui-altyapi)

**Tarih:** 2026-09-01 · **Worktree:** `/home/melik/egesut-wt/ui-altyapi` (branch `idle/ui-altyapi`)
**Görev zarfı:** `IDLE-GOREV.md` · **Guardrail durumu:** Supabase çağrısı YOK (tamamen local/unit) · push YOK

## Durum: TAMAM — 302 test, 301 geçti, 0 kırmızı, 1 skip (önce: 265/264/0/1)

| Çıktı | Dosya | Özet |
|---|---|---|
| Toast kuyruğu | `js/utils/helpers.js` (Aşama 3.4) | Sözleşme yorumla yazıldı, imza `toast(msg, err)` DEĞİŞMEDİ |
| Toast testleri | `tests/unit/toast.test.js` | 13 test (mock-timer-önce tuzağına uyum) |
| api.js unit | `tests/unit/api.test.js` | 24 test — createClient stub + sahte IndexedDB ile vm yükleme |
| Benchmark belgesi | `.claude/idle-reports/2026-09-01-render-benchmark.md` | Karar niteliğinde; kod YOK |

## Toast sözleşmesi (özet)

Tek görünür bildirim; yenisi FIFO kuyruğa girer (ezmez). Her mesaj 3200ms + 300ms fade-out gap'i
(CSS `.28s`). Kuyruk tavanı 3 bekleyen — taşmada en eski bekleyen düşer. Birebir aynı (msg, err)
görünür/tail'de yutulur (hata fırtını kilidi). `#toast` yoksa sessiz no-op. ~100 çağrı yeri etkilenmez.

## api.test.js kapsamı

- `_trErr` tam eşleme tablosu + case-insensitive + passthrough; rpc() error→Türkçe throw;
  **B31** `ok:false` → `err.data` identity; iletim hatası→"İnternet bağlantısı gerekli";
  **B23** iletim-dışı istisna yeniden adlandırılmaz
- **B16** dbUpdate null/'' gönderir, undefined/id filtreler; **B17** 0-satır→`deadTarget`;
  dbInsert uuid ataması + null/'' temizliği; **B28** `_writePatch` filtre guard'ı
- RPC_TABLES bütünlüğü: değerler TABLES ⊆; kritik write RPC'leri mevcut; js/ taramasıyla
  `rpcOptimistic('...')` literalleri eşlemede (ternary literalleri dahil)
- **B17 syncNow**: drain, atla-devam, 5 hata sonrası denenmez (dead-letter), deadTarget düşürme,
  offline guard, sync-bar spy'ları
- rpcOptimistic: offline/hata/başarı yolları; başarıda RPC_TABLES→FETCHERS zinciri
  (`hayvan_durum_view` çekimi) kanıtlandı
- Güvenlik kilidi: her iki modda da createClient key JWT `role=anon` (B1 kapanış regresyonu)

## Tespitler / notlar

1. **node_modules worktree'de yoktu** → ana repodan symlink (`.gitignore` kapsamında, commit dışı).
2. **`kategori_ekle/guncelle/sil` + `seed_defaults` RPC_TABLES'ta yok** — çağrı yerlerini
   `loadTanimlarPanel()` → `pullTables(['stok_kategorileri'])` telafi ediyor (forms.js:1391);
   testte bilinçli muafiyet listesi. **Ancak** `seed_defaults` p_tip drug_classes/diseases yazıyorsa
   bu tabloların telafisi YOK — merge sonrası ayrı değerlendirme önerilir (kod yazımı bu görevin dışında).
3. **vm cross-realm tuzakları** (test dosyalarına yorumlandı): vm içi `Object.fromEntries` prototype
   farkı → JSON round-trip; vm Error'ı ana realm `instanceof` değil → `constructor.name`; node mock
   timer tek `tick(3500)` zincirli timer'ı atlayabiliyor → adımlı tick.
4. **detect_changes HIGH**: satır-kayması artefaktı — diff'te silinen yalnız eski toast gövdesi
   (4 satır); esc/escAttr/trLower gövdeleri değişmedi, işaretlenen 10 süreç yalnız hunk-mapping
   yanlış pozitifi. Gerçek davranışsal etki: toast çağıran ~100 yer (imza aynı, kuyruklanma bilinçli).
5. Playwright E2E koşulmadı (görev tanımı local/unit kapsamı; CI'da ana repo tarafında koşar).

## Benchmark önerisi (özet)

JS tarafı (string üretimi + filtre + sort + yasHesapla×N) hiçbir ölçekte darboğaz değil
(N=1000'de ~4.7ms masaüstü); darboğaz `innerHTML` tam değişimin parse/layout'u.
**Bugün N≈27 → dokunma; N>150 → pagination (sayfa 50, a-seq global); N>500 + akış UX şartı →
ancak o zaman virtual scroll.**
