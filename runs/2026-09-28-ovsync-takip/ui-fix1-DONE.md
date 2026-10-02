# ui-fix1-DONE — 6 kalemden 6 tamam (K3 kısmen UYUŞMAZLIK, K6 yalnız birim kanıtlı)

| kalem | dosya:satır | test adı (tests/unit/ovsync-uifix1.test.js) | yürüyüş PNG | durum |
|---|---|---|---|---|
| K1 S4 katlama | js/ui.js:1135 | K1: S4 başlığı .ovs-katla span + onclick…; kapalı ▸ açık ▾ | artifacts/fix1-k1-s4-acik.png (h2: `<span class="ovs-katla" onclick="_ovsyncS4Katla()">▸</span>`, tıklayınca S4 kartı açıldı) | TAMAM |
| K2 🔔 sheet kapanışı | js/ui.js `_protokolOvsyncGit` (yeni, ~4500) + 2 link | K2 ×3 (kapat→goTo sırası, back'li dal, iki link) | artifacts/fix1-k2-link-sonrasi.png (m4: protokolBs 0, ovsyncOn 1) | TAMAM |
| K3 PG kapısı etiketi | js/ui.js:3114-3128 (`_takipAcikAc`) | K3 ×3 | artifacts/fix1-k3-birlesik.png (m12: "PG kapısı: Son tohumlama sonucu Bekliyor") | KISMİ — aşağıda UYUŞMAZLIK |
| K4 bayat saat | js/api.js:1117-1118 | K4 (cache→zaman→"çevrimdışı · 09:05 verisi"; cache yoksa zaman null) | artifacts/fix1-k4-bayat.png (m23: "çevrimdışı · 19:46 verisi"; önbelleksiz: "📡 İnternet yok") | TAMAM |
| K5 Geri → sheet | js/app.js:152-166 (popstate) | K5 ×3 | artifacts/fix1-k5-modal-geri.png (m24: secici 0, ovsyncOn 1, state {pg:ovsync}) | TAMAM |
| K6 S0 BUGÜN TAI | js/ui.js ~946-958 (`_ovsyncS0SatirHtml`) | K6 ×3 (yarın / bugün / hedef_tarih yok) | YOK — demo'da S0 BUGÜN kartı yok (k6 probe: bugun-kartlari=[]) | TAMAM (yalnız birim) |

## Sayılar
- Birim önce: 1406 test / 1404 geçti / 2 kırmızı (LUNA-3 canlı-DB + `ay ‹/›`→bc-tarih takvim). **Sonra: 1420 / 1417 geçti / 3 kırmızı** (NODE_PATH=/home/melik/egesut-erp1/node_modules ile). Yeni testler 14/14 yeşil. Kırmızı küme = baseline 2 + **1 YENİ: `P7-K10: 🔔 … "Tüm takibi aç →" sh-link taşır`** (tests/unit/ovsync-girisler.test.js:198, regex `/goTo\('ovsync'\)/`). Sebep: K2 link onclick'i artık `_protokolOvsyncGit()`; eski test link içinde literal `goTo('ovsync')` arıyor. Manifest dışı olduğu için DOKUNMADIM. Önerilen tek satır: regex → `/_protokolOvsyncGit\(\)/` (mimar karar versin).
- e2e `tests/e2e/ovsync-takip.spec.js`: bu ortamda **10/12** (varsayılan config) — T-01/T-07 ve T-20 kırmızı: "Arama sonucu yok" (fixture hayvan IDB'de yok). **Aynı T-01 testi değişiklikten ÖNCEKİ HEAD arşivinde de kırmızı** (git archive HEAD, ayrı port) → ortam/demo-DB kaynaklı, K1–K6'dan değil. uitur global-setup/teardown'lu config ile 8/12 (fixture çakışması). 12/12 bu oturumda yeniden üretilemedi.
- `node --check js/ui.js js/api.js js/app.js` temiz; `git diff --check` temiz.
- `git diff --stat` (js): js/api.js +2/-1, js/app.js +16, js/ui.js +35/-6.

## UYUŞMAZLIK / sapmalar
1. **K3**: Zarf "karar hata kodu önekinde (PG_KAPI:REQUIRE_ACK_PENDING:…)" diyor; gerçek birleşik RAISE `PG_KAPI:TAKIP_ACIK:{…}` (migration 20260929000002:989) — hata kodunda karar YOK, yükte de `pg_kapi.karar` YOK. Karar bu yoldan çözülemez. Yapılan: `pg_kapi.karar || (detay.pg_kapi_kod önekinden)`; çözülemezse `Son tohumlama sonucu <tohumlama_sonuc>` (canlı yükte bu çalışıyor); o da yoksa "bilinmiyor". `pg_kapi_kod` girdisini şu an hiçbir çağıran doldurmuyor (ölü yol, testli). Ayrı `_pgKapiKararCoz` yazılmadı: mevcut P10 testlerinin fonksiyon listesi onu görmezdi (ReferenceError) → regex inline. Gerçek karar için sunucunun `_pg_kapi_detay`'ına `karar` eklenmesi gerekir (supabase/ yasak, mimar kararı).
2. **K5**: Tarif "mevcut popstate işleyicisi" = js/app.js (manifestte yok); yalnız popstate'e 15 satır eklendi. `#takip-acik-bs` ve `#pg-kapi-bs` aynı kurala bağlandı. Diğer pushState'li sheet'ler (ertele, toplu_sonuc, takip_toplu, protokol…) kapsam dışı bırakıldı (kapatıcıları farklı/unclear).
3. **K2**: Doğrudan `_closeProtokolListe(); goTo()` sıralı çağrı history.back asenkron olduğundan pushState ile yarışırdı → goTo, `_modalBackDevam` ile geri-geçiş tüketildikten sonra koşuyor (mevcut mekanizma). Yeni kapatma yolu yazılmadı.
4. **K6**: Browser kanıtı yok (demo'da S0 BUGÜN satırı yok; TAI-bugün/yarın fixture'ı gerekir). `tai.hedef_tarih` yoksa fail-closed: TAI metni ve buton çizilmez (önceden buton `gorev_id` varsa hep çiziliyordu).
5. m24 yürüyüşünde `geri-tikla` adımı ("[data-action=nav-geri]:visible" bulunamadı) ve m20 `E2E-UITUR-g` kartı timeout: bu turun kalemleri dışı, betik/fixture kaynaklı; raporlandı, düzeltilmedi.
6. İç review (code-reviewer): zarf "alt-ajan açma" dediği için YAPILMADI.
7. Yan etki: e2e'yi uitur config'iyle koşunca global-teardown demo fixture'larını sildi; yürüyüş için `yuruyus-kos-seed.sh` (yalnız /home/melik/tmp/agents/… altı) ile yeniden kuruldu. Yürüyüş betiği değişikliği: m3.spec.js (S4 tık hedefi `.ovs-katla`), yeni k6.spec.js.
8. Commit/push YOK (zarf yasağı). `?v=20260927-09` damgasına dokunulmadı — değişen ui.js/app.js/api.js için damga bump'ı mimar kararı.
