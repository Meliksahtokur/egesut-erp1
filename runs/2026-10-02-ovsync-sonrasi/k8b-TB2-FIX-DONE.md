# K8b / TB-2 DÜZELTME — demo_sema_diff 401 (seçenek A, geliştirilmiş)

Worktree: /home/melik/.herdr/worktrees/egesut-erp1/ovsync-sonrasi · Skiller: using-superpowers-obra, test-driven-development-obra. Git yok, DB yazma yok, demo sahip şifresine dokunulmadı, `index.html ?v=` DEĞİŞMEDİ.

## Değişen dosyalar (diff --stat, yalnız benim)
- /home/melik/.herdr/worktrees/egesut-erp1/ovsync-sonrasi/js/demo.js — +20 satır
- /home/melik/.herdr/worktrees/egesut-erp1/ovsync-sonrasi/tests/e2e.spec.js — +5/-3 (IGNORED_LOCATIONS + yorum)
- /home/melik/.herdr/worktrees/egesut-erp1/ovsync-sonrasi/tests/unit/demo-sema-diff.test.js — yeni (4 test)

## Fix
`semaDiffKontrol(bar)`: `db.auth.getSession()` oturum VARSA `semaDiffCalistir` doğrudan koşar; YOKSA RPC çağrılmaz, `db.auth.onAuthStateChange` ile SIGNED_IN/INITIAL_SESSION (session dolu) beklenir; olayda abonelik kapatılır, `setTimeout(0)` ile (supabase geri çağrısında await kilitlenme riski) `semaDiffCalistir` koşar. Çift koşum yok: `semaDiffKosuldu` bayrağı sayfa başına tek koşum. Mevcut desen: auth.js `onAuthStateChange` kullanıyor (olay adı SIGNED_IN); ayrı bir "oturum-hazır" olayı yok, o yüzden aynı API. Hata yutma korundu; konsola satır EKLENMEDİ (demo.js idiomu sessiz catch, `semaDiffKontrol` hata durumunda zaten sessiz kalıyordu).

## TDD kanıtı (birim; demo.js tüm dosya vm'de yüklenebiliyor: loadBrowserModule + sahte db)
- KIRMIZI (fix öncesi): oturumsuz -> `actual ['demo_sema_diff'] expected []`; SIGNED_IN testi `abone 0 != 1`; `durum.aboneler[0] is not a function` [OBSERVED]. (4. test "oturum varsa tek RPC" mevcut davranışı doğruladı, baştan yeşil, regresyon koruması.)
- YEŞİL (fix sonrası): 4/4 geçti [OBSERVED `node --test tests/unit/demo-sema-diff.test.js`]. Testler: oturumsuz -> RPC yok; SIGNED_IN (2x tekrar) -> tam 1 çağrı + drift bandı + unsubscribe; SIGNED_OUT/session=null -> çağrı yok; oturum varsa -> doğrudan 1 çağrı, abonelik yok.
- Stub notu: testte `#demo-klonla/#demo-cikis` düğmeleri, `insertAdjacentElement` ve `EGESUT_DEMO_POPUP_OFF=1` elle kuruldu (demo.js init gövdesi çalışsın diye).

## Tarayıcı kanıtı (Chromium headless shell, boş bağlam, yerel statik sunucu `?demo`, istek JWT rolü çözüldü; betik /home/melik/tmp/k8b/probe.cjs) [OBSERVED]
Kontrol (HEAD js/demo.js): `368ms REQ role=anon -> 830ms RESP 401` + `CONSOLE.error Failed to load resource ... 401 ... rpc/demo_sema_diff`; sonra reload `authenticated 200`, 2. yükleme `authenticated 200`. Özet: req=anon,authenticated,authenticated resp=401,200,200.
Fix: HİÇ anon istek yok, 401 yok, `CONSOLE.error` YOK. Otomatik giriş sonrası SIGNED_IN'de `authenticated` istek (autologin reload'u onu iptal eder, yanıt gelmez), reload sonrası `authenticated -> 200`, 2. yüklemede `authenticated -> 200`. Özet: req=authenticated x3 resp=200,200 (üçüncü istek yanıtsız = reload ile iptal, sayfa başına tek koşum korunuyor).
Not: bu uygulamada her giriş yolu `location.reload()` yapar (auth.js:106,113,215,328), bu yüzden SIGNED_IN yolu fiilen reload ile iptal olur; kalıcı koşum reload sonrası "oturum var" yolundadır. Abonelik yine de oturum reload'suz açılırsa özelliği korur.

## e2e
tests/e2e.spec.js:57 `IGNORED_LOCATIONS` -> `['agent-telemetry', 'rpc/hekim_listesi']`; yanlış "demo'da RPC yok" yorumu düzeltildi (RPC var, yalnız authenticated; 401 artık regresyon). Playwright e2e süiti bu turda KOŞULMADI (tek seferlik tarayıcı kanıtı yukarıda; UI kapısı glmf-max koltuğundadır).

## Süit
`node --check js/demo.js` ve e2e.spec.js temiz. Birim süit: tests 1500 / pass 1498 / fail 2 (baseline 1491/1489/2; +4 benim, +5 ağaçtaki diğer koltuk değişiklikleri). 2 kırmızı baseline ile aynı sayıda, demo.js ile ilgisiz: bc-tarih/ay takvim (tarih-bağımlı) ve LUNA-3 (canlı DEMO information_schema ↔ harita). Yeni kırmızı yok.

## Etiketler
[CONFIRMED] kod okuma (demo.js, auth.js). [OBSERVED] test çıktıları, tarayıcı ağ kaydı. [INFERRED] LUNA-3/bc-tarih'in baseline'dan geldiği (sayı eşit, demo.js ile ilgisiz; adlarını baseline ile bire bir karşılaştırmadım).

SONUC: TAMAM
