# İDLE GÖREV: UI Altyapı + Test Derinleşme (Idle-C)

> Omurga: `/home/melik/egesut-erp1/.claude/plans/2026-08-31-fix-roadmap-ve-idle-omurgasi.md` §3/Idle-C.
> Bu worktree: `idle/ui-altyapi` · Ana repo: `/home/melik/egesut-erp1` (main).

## Guardrail'ler (ZORUNLU)

- **Supabase'e hiçbir MCP çağrısı YOK.**
- **Deploy yok, main'e push yok.** Sadece bu worktree'de commit.
- Kod yazımı YALNIZCA: `js/utils/helpers.js` (toast kuyruğu) + `tests/unit/**`. Başka js dosyasına dokunma.
- Rapor: `.claude/idle-reports/<tarih>-ui-altyapi.md` (bu worktree'ye).

## Çıktılar

1. **Aşama 3.4 toast kuyruğu** (`js/utils/helpers.js`):
   - `toast(msg, err)` kuyruk mantığı: aynı anda tek bildirim, yenisi sıraya girer (ya da eskisinin
     yerine geçer — davranışı belirle ve yorumla yaz); tür renkleri mevcut `err` parametresiyle
     uyumlu kalır; mevcut çağrı API'si DEĞİŞMEZ (toast(msg, err) imzası sabit).
   - Unit testler: tests/unit/toast.test.js (loader ile; vm tuzağı: mock timer önce enable,
     sonra modülü yükle — bkz. tests/unit/support/loadModule.js başlık yorumları).
2. **api.js unit derinleşme** (`tests/unit/api.test.js`):
   - `_trErr` eşleme, rpc() arg doğrulaması, ok:false→err.data taşıma (WP-3/B31 sonrası kontrat),
     RPC_TABLES bütünlüğü (bilinen RPC'lerin hepsi map'te mi)
   - api.js vm'de yüklenebilir: `extra: { supabase: { createClient: stub } }` (test kapsamı
     raporundaki not). Offline kuyruk mantığı (syncNow atla-devam/dead-letter) stub ile test edilebilirse et.
3. **Aşama 3.1 render benchmark karar belgesi** (salt-okunur, kod YOK):
   - `.claude/idle-reports/<tarih>-render-benchmark.md`: renderAnimals/filterA innerHTML maliyeti,
     liste boyutları (yasHesapla çağrı sayısı), virtual scroll vs pagination karşılaştırma kriterleri,
     öneri. Ölçüm: test dosyasında `node:test` performance.now() bench (isteğe bağlı) veya koddan
     statik analiz + varsayımlar açıkça yazılmış hesap.

## Kabul Kriterleri

- `npm run test:unit` bu worktree'de yeşil; yeni testler eklenmiş (toast + api)
- toast kuyruğu davranışı yorumla dokümante + test kilitli
- Benchmark belgesi karar niteliğinde (sanal kaydırma önerisi/verisiyle)
- Worktree'de tek commit + rapor
