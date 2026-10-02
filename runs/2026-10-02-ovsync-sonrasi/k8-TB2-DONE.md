# K8 / TB-2 — `demo_sema_diff` 401 teşhisi (düzeltme YAZILMADI, yalnız öneri)

Tarih: 2026-10-02 · Worktree: /home/melik/.herdr/worktrees/egesut-erp1/ovsync-sonrasi · Yetki: demo+prod yalnız okuma. Yazma yok, git yok, demo sahip şifresine dokunulmadı (yalnız koda gömülü PUBLIC demo kullanıcısıyla `signInWithPassword`).

## Özet

401 bir izin/sahiplik hatası DEĞİL. Fonksiyon demo'da var ve doğru kurulu (yalnız `authenticated` EXECUTE). 401'in kaynağı, `js/demo.js` `semaDiffKontrol`'ün oturum açılmadan ÖNCE (anon JWT ile) çağrılması. Bu yalnız oturumsuz yüklemede olur: yeni tarayıcı bağlamının ilk yüklemesi, ya da giriş ekranında kalan sayfa. Oturumlu yüklemede çağrı `authenticated` ile gider ve 200 döner.

## Kök neden (kanıtlı)

1. Çağrı noktası, tek yer: [CONFIRMED js/demo.js:40-43] `semaDiffKontrol(bar)` içinde `db.rpc('demo_sema_diff')`. Atlas: `rpc demo_sema_diff` → yalnız `js/demo.js:semaDiffKontrol@40` [OBSERVED atlas_query].
2. Tetik zinciri: [CONFIRMED js/demo.js:~76] `injectBar()` sonunda `semaDiffKontrol(bar)`; [CONFIRMED js/demo.js, dosya sonu] `init()` DOMContentLoaded'da (index.html'de `topbar` statik, [CONFIRMED index.html:637]) doğrudan çalışır. Oturum durumuna bakmaz. Aynı anda `app.js:789-791` `authGate()` async ilerler.
3. Client: [CONFIRMED js/api.js:24-28,57-58] `IS_DEMO` ise `createClient(DEMO_URL, DEMO_KEY)`, `DEMO_KEY` rol=anon. Oturum yoksa supabase-js `Authorization: Bearer <anon key>` gönderir.
4. Oturum akışı: [CONFIRMED js/auth.js:322-331] oturum yoksa `authGate` gömülü kullanıcıyla `signInWithPassword` yapar, ardından `location.reload()`. Yani ilk yüklemede demo.js anon çağrıyı otomatik girişten önce atar. Tüm giriş yolları reload eder ([CONFIRMED js/auth.js:106,113,215,328]).
5. Hata ele alma: [CONFIRMED js/demo.js:41-49] `if (error || !data) return;` + boş `catch`. Uygulama sessiz geçer. 401 yalnız tarayıcı konsolu/ağ günlüğünde "Failed to load resource" olarak kalır, bu yüzden "her açılışta konsol hatası" olarak görülüyor.
6. Fonksiyon durumu, demo [OBSERVED Management API `pg_proc`, demo ref vtzqjmazsvurxdeondmi]:
   - `demo_sema_diff()`: sahip `postgres`, `prosecdef=true` (SECURITY DEFINER), `proconfig={search_path=public, pg_temp}`, ACL `{postgres=X, authenticated=X, service_role=X}`, `has_function_privilege('anon')=false`, `('authenticated')=true`.
   - `demo_klonla()` aynı kalıpta.
   - Kaynak: [CONFIRMED demo/03_sema_diff.sql:25-26] `REVOKE ALL ... FROM PUBLIC; GRANT EXECUTE ... TO authenticated;` (commit 9b260f6, 2026-07-02, "D4"). Supabase default-privilege anon ACL tuzağı burada oluşmamış (ACL'de anon yok).
7. Prod [OBSERVED Management API, prod ref zqnexqbdfvbhlxzelzju]: `demo_sema_diff` ve `demo_klonla` YOK (sorgu `[]`). `demo/README.md` zaten demo'ya özgü olduğunu söylüyor.
8. REST kanıtı (aynı çağrı, demo URL, `POST /rest/v1/rpc/demo_sema_diff`):
   - anon key (apikey+Bearer anon): `HTTP/2 401` gövde `{"code":"42501","message":"permission denied for function demo_sema_diff"}` [OBSERVED curl].
   - authenticated JWT (demo@egesut.web ile alınan): `HTTP/2 200` gövde `{"eksik_kolon": [], "eksik_tablo": []}` [OBSERVED curl].
   - Olmayan fonksiyon (`yok_boyle_fn`): `HTTP/2 404` `PGRST202`. Yani fonksiyon-yok = 404, izin-yok (anon) = 401. 401 fonksiyonun var olduğunu ve anon'a kapalı olduğunu kanıtlar.
9. Tarayıcı zaman çizelgesi (Chromium headless, yerel sunucu `?demo`, boş bağlam, istek başlığındaki JWT rolü çözüldü) [OBSERVED ~/tmp/k8/probe.cjs]:
   ```
   424ms  REQ  role=anon           -> 766ms RESP 401   (yükleme 1, oturumsuz)
   1072ms NAV (autologin reload)
   1104ms REQ  role=authenticated  -> 1267ms RESP 200  (yükleme 1'in reload'u)
   9822ms REQ  role=authenticated  -> 9997ms RESP 200  (yükleme 2, oturum localStorage'da)
   ```
   Not: supabase-js `fetchWithAuth` `getSession()`'ı bekler, bu yüzden oturum varsa çağrı doğru JWT'yle gider; sorun yalnız oturum yokken.
10. Tarihçe: `ui-tur-DONE.md` ve eski idle raporları 401'i "bilinen gürültü" diye kayda geçirmiş; `tests/e2e.spec.js:55-57` yorumu ("demo projesinde RPC yok → 401/404") `demo_sema_diff` için YANLIŞ (RPC var, anon'a kapalı) [CONFIRMED tests/e2e.spec.js:55-57 + madde 6]. 2026-09-02 raporu (`.claude/idle-reports/2026-09-02-e2e-gercek.md:40`) 401'i "RPC yok/eski" diye yorumlamış; bu da yanlış teşhis.

Kapsam netliği: "her sayfa açılışı" doğru değil, "her oturumsuz yükleme". Playwright/ui-tur koşumları her seferinde yeni bağlam açtığı için hep ilk yüklemeyi görür. Gerçek kullanıcıda ilk demo açılışında bir kez, çıkış sonrası ya da giriş ekranında kalındığında görünür.

## Seçenekler

| # | Seçenek | Değişen | Blast radius | Güvenlik/domain uyumu | Sonuç |
|---|---|---|---|---|---|
| A | demo.js'te oturum yoksa RPC'yi atma (`getSession()` kapısı) | `js/demo.js` (1 satır + `?v=` damgası) | Yalnız IS_DEMO yolu; DB/prod/migration yok. Oturumlu yüklemede davranış aynı. Oturumsuz yüklemede drift uyarısı zaten gösterilemezdi (RPC 401'di), kayıp yok. | Uygun. Yeni grant yok. | ÖNERİLEN |
| B | `GRANT EXECUTE ... TO anon` (demo migration) | demo DB | Anonim herkes prod_fdw tablo/kolon adlarını görür (SECURITY DEFINER, FDW şema bilgisi sızar). Demo anon key herkese açık. | `anon-execute-acigi.md` kuralı: yeni anon GRANT yazılmaz. İHLAL. | REDDEDİLDİ |
| C | Çağrıyı ve uyarıyı tamamen kaldır | `js/demo.js`, (opsiyonel `demo/03_sema_diff.sql`) | Drift uyarısı özelliği kaybolur (demo-mirror ROADMAP D-şema). Şema senkron adımı hâlâ elle. | Güvenli ama özellik kaybı. | Gereksiz |
| D | Hiçbir şey yapma, e2e `IGNORED_LOCATIONS`'ta kalsın | yok | Konsol 401 sürer; ui-tur gürültüsü sürer; yanlış yorum kalır | Kabul kriterini (demo'da konsol 401 yok) karşılamaz | Yetersiz |
| E | Sorguyu SECURITY INVOKER yapıp `authenticated`'a bırakmak vb. | demo DB | Sorun grant değil zamanlama; çözmez | - | Geçersiz |

## Önerilen düzeltme (A)

Dosya: `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-sonrasi/js/demo.js`, `semaDiffKontrol` (~satır 40-42):

```diff
   async function semaDiffKontrol(bar) {
     try {
+      // demo_sema_diff yalnız `authenticated` (demo/03_sema_diff.sql:26). Oturum yokken
+      // (autologin reload'undan önceki ilk yükleme / giriş ekranı) anon çağrı 401 verir.
+      const { data: { session } } = await db.auth.getSession();
+      if (!session) return;
       const { data, error } = await db.rpc('demo_sema_diff');
       if (error || !data) return;
```

Ek uygulama notları:
- `index.html` içindeki tüm `?v=` damgası tek değerle bump edilmeli (proje kuralı: `?v=` tek değer + damga-koruma testleri).
- Düzeltme sonrası `tests/e2e.spec.js:57` `IGNORED_LOCATIONS`'tan `'rpc/demo_sema_diff'` çıkarılıp yorum düzeltilebilir (RPC "yok" değil, "oturumsuz anon'a kapalı"); `hekim_listesi` kalır. Ayrı küçük adım, riskli değil. Bu tek başına gerekli değil; kaldırılırsa e2e düzeltmeyi bekçiler.
- Doğrulama önerisi (UI testi kapısı geçerli, glmf-max): boş bağlamda `?demo` aç, ağ günlüğünde `rpc/demo_sema_diff` YA hiç yok (yükleme 1) YA 200 (reload sonrası); konsolda 401 yok. `~/tmp/k8/probe.cjs` aynı ölçümü rol çözümüyle yapar (yeniden kullanılabilir, `chrome-headless-shell-1228` executablePath ister).
- Bu fix, ürün koduna dokunur (js/demo.js) ve `code-change-precheck` kapsamı: demo.js yalnız IS_DEMO'da çalışır, atlas etkisi: `semaDiffKontrol` yalnız `injectBar` çağırır.

## Yan bulgular

- `demo/README.md` "authenticated ... GRANT" ve kod uyumlu; hiç migration/ACL düzeltmesi gerekmiyor. Demo DB'ye yazma yapılmadı.
- Eski raporlardaki "RPC yok/eski" teşhisi ve e2e yorumu yanlış; düzeltilmeli (önerilen fix ile birlikte kayıt).
- Temizlik: geçici yerel http sunucusu kapatıldı; geçici dosyalar `~/tmp/k8/` (q1.json, run.sh, probe.cjs).

SONUC: KOK_BULUNDU
