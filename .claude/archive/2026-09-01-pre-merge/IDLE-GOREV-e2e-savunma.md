# İDLE GÖREV: E2E Demo-Mode Savunma Hattı (Idle-B)

> Omurga: `/home/melik/egesut-erp1/.claude/plans/2026-08-31-fix-roadmap-ve-idle-omurgasi.md` §3/Idle-B.
> Bu worktree: `idle/e2e-savunma` · Ana repo: `/home/melik/egesut-erp1` (main).

## Guardrail'ler (ZORUNLU)

- **Prod Supabase'e hiçbir MCP çağrısı YOK.** E2E testler **demo mode** ile çalışır:
  `PLAYWRIGHT_DEMO_MODE=1 npx playwright test` (demo projesi izole klon — yazma güvenli)
  veya `npm run serve:local` + `PLAYWRIGHT_BASE_URL=http://127.0.0.1:8080/ npx playwright test` (test:local).
- **Deploy yok, main'e push yok.** Sadece bu worktree'de commit.
- Kod değişikliği YALNIZCA `tests/` altında (spec dosyaları + gerekirse helper).
- Şüpheli bulguda (fix bekleyen bug) kaynak js düzeltme — rapora yaz.
- Rapor: `.claude/idle-reports/<tarih>-e2e-savunma.md` (bu worktree'ye).
- Testler **veri-agnostic** yazılır (sabit küpe no vb. ASSUME etme; listeden dinamik seç).

## Çıktılar (yeni spec'ler — 2026-08-31 fix oturumunun (commit c096485..5d78587) regresyon kilitleri)

1. **tests/modal-router.spec.js** — B2/B3/B21/B22 fix'lerinin kilitleri:
   - modal aç → Android geri (page.goBack()) → modal kapansın, ALTINDAKİ SAYFA yerinde kalsın (goTo tetiklenmemeli — sürü filtreleri korunur)
   - yığılmış modal (openConfirm üstte) → geri → yalnız confirm kapansın
   - backdrop-tap kapatma → sonra normal tohumlama → eski planlı görev id'sine yazmıyor (B3)
   - proto sheet (protokol uyarıları) aç/kapa → history girdisi öksüz kalmıyor (geri tuşu dash'e atmıyor)
2. **tests/gece-tarih.spec.js** — B4 kilidi: Playwright clock ile saat 01:00'a sabitle →
   yeni kayıt formu aç → tarih default BUGÜN olmalı (dünkü değil); bugünün doğum tarihi "ileri tarih" reddedilmemeli
3. **tests/kritik-akis.spec.js** — tohumlama→sonuç→gebe listesi; görev ekle→tamamla→geri al;
   görev listesi filtreleri (bugün/7gün) B20 sonrası chip davranışı
4. **tests/offline-kuyruk.spec.js** — context.setOffline(true) → kayıt oluştur → online →
   syncNow replay (B17: tek zehirli kayıt diğerlerini bloklamamalı)

## Kabul Kriterleri

- `PLAYWRIGHT_DEMO_MODE=1 npx playwright test` yeşil (ya da ortam engeli varsa local mode)
- Her spec dosyasında başlık yorumu: hangi bulguyu (B#) kilitlediği
- Worktree'de tek commit + rapor (kaç test, neler kapsanamadı, şüpheli davranışlar)
