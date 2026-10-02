# ui-fix1 — GOREV zarfı: yürüyüşte bulunan 6 ürün hatasının düzeltmesi

- **GOREV:** `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/ui-fix1-GOREV.md`
- **DONE:** `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/ui-fix1-DONE.md`
- **Koltuk:** `ss-worker-sonnet-medium`
- **Kaynak bulgular:** `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/ui-tur4-DONE.md` (FAIL-ÜRÜN 1–5 + ek gözlem "S0 BUGÜN kartı")
- **Yürüyüş betikleri (yeniden doğrulama için hazır):** `/home/melik/tmp/agents/uitur-20261001/yuruyus/m<N>.spec.js` + `yuruyus-kos.sh <N>`
- **Worktree / dal:** `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip` · `ovsync-takip`

## İlk iş

1. `.harness/references/domain-rules.md` §18 oku (proje kuralı; çelişki görürsen DUR, DONE'a yaz).
2. Her JS sembolünü değiştirmeden önce `code-change-precheck` skill'ini uygula (blast radius).
3. TDD: her kalem için önce kırmızı birim testi yaz (mevcut `tests/unit/ovsync-*.test.js` desenleri, vm extract),
   sonra düzeltme, sonra yeşil.

## Kalemler (mimar kararı — tasarımı DEĞİŞTİRME, birebir uygula)

**K1 — S4 katlama (M3)** · `js/ui.js:1135`
Üçlü operatörde parantez eksik; `+` önce bağlandığı için span/onclick üretilmiyor. Düzeltme:
`'<span class="ovs-katla" onclick="_ovsyncS4Katla()">'+(((window._curOvsyncBolum||{}).acik||{}).S4?'▾':'▸')+'</span>'`
Test: S4 başlık HTML'i `.ovs-katla` span'ı ve `onclick="_ovsyncS4Katla()"` içerir; kapalıyken `▸`, açıkken `▾`.

**K2 — 🔔 sheet ovsync'e geçişte kapanmıyor (M4)**
"Tüm takibi aç →" linki `goTo('ovsync')` çağırırken `#protokol-bs` açık kalıyor. Düzeltme: linkin handler'ı,
`goTo`'dan ÖNCE 🔔 sheet'i **mevcut kapatma fonksiyonuyla** kapatır (yeni kapatma yolu yazma; 🔔 sheet'in
kendi kapatma fonksiyonunu bul ve onu çağır). Test: handler'ın kapatma fonksiyonunu goTo'dan önce çağırdığı.

**K3 — Birleşik kapıda "PG kapısı: bilinmiyor" (M12)** · `js/ui.js:3115`
Sunucu `PG_KAPI:TAKIP_ACIK` yükünde `pg_kapi.karar` alanı YOK; karar hata kodunun önekinde
(`PG_KAPI:REQUIRE_ACK_PENDING:…` gibi). Düzeltme: `karar = detay.pg_kapi.karar || <hata kodundan çıkarılan karar>`.
Kodu çözen yardımcı varsa (yalnız-PG kapısı `_pgKapiHata` zinciri) onu kullan; yoksa küçük saf bir
`_pgKapiKararCoz(kod)` yaz. İkisi de yoksa etiket `bilinmiyor` kalır (fail-closed, uydurma yok).
Ayrıca karar hiç çözülemiyorsa `pg_kapi.tohumlama_sonuc` mevcutsa `Son tohumlama sonucu <sonuc>` göster
(`#pg-kapi-bs`'deki yalnız-PG metniyle aynı dil). Test: karar alansız yük + `REQUIRE_ACK_PENDING` kodu →
etiket `bilinmiyor` DEĞİL.

**K4 — Bayat etikette saat yok (M23)** · `js/api.js` `ovsyncTakipGetir` catch dalı
Düzeltme: catch dönüşü önceki önbelleğin zamanını da taşır:
`{ bayat: true, veri: c ? c.veri : null, zaman: c ? c.zaman : null }` (`c = window.__ovsyncTakip`).
Test: önbellek varken catch → `zaman` dolu → `_ovsyncBayatEtiket` `çevrimdışı · HH:MM verisi` üretir.
Not: invalidate (`__ovsyncTakip=null`) sonrası offline'da önbelleksiz yol (`📡 İnternet yok`) doğru davranıştır.

**K5 — Modal açıkken Geri modalı kapatmıyor (M24)**
`#devam-secici-bs` açılınca `history.state={devam_secici:true}` itiliyor; Geri bu state'i tüketiyor ama sheet
açık kalıyor. Düzeltme: mevcut `popstate` işleyicisinde (modal guard — T-55) yeni state `devam_secici`
değilse ve `#devam-secici-bs` açıksa, sheet'i **mevcut kapatma fonksiyonuyla** kapat. Aynı itme desenini
kullanan başka ovsync sheet'i varsa (`#takip-acik-bs`, `#pg-kapi-bs` — `history.pushState` ara) aynı kurala
bağla; olmayan için ekleme yapma. Test: popstate simülasyonu → sheet kapanır; ikinci Geri sayfa değiştirir.

**K6 — S0 "BUGÜN" kartı yanlış TAI tarihi (ek gözlem)** · `js/ui.js` ~934 (S0 kart render)
İlaç günü bugün ama TAI bugün DEĞİLken kart `— TAI bugün 10:00` + `▶ TAI kaydet` basıyor (RPC
`tai.hedef_tarih` farklı). Düzeltme: TAI metni ve `▶ TAI kaydet` butonu YALNIZ `tai.hedef_tarih === bugün`
iken çizilir; aksi hâlde TAI satırı RPC'nin `tai.hedef_tarih`'ini göreli gün etiketiyle gösterir
(mevcut `gunFarkiEtiket`/`_ovsyncGorelGun` ailesinden hangisi varsa) ve buton çizilmez. Tarih/saat RPC'den
okunur, JS'te hesaplanmaz (design §18.13: eşik/tarih RPC'den). Test: TAI yarın → kartta "TAI bugün" yok,
`▶ TAI kaydet` yok; TAI bugün → ikisi de var.

## Doğrulama

1. `node --check js/ui.js js/api.js`
2. Birim: `node --test "tests/unit/*.test.js"` → baseline 1406/1404/2 (2 pre-existing kırmızı: LUNA-3 canlı-DB +
   tarih-duyarlı `ay ‹/›`). Yeni testler eklenir; yeni kırmızı = 0 olmalı. Kırmızı kümesini baseline'la birebir kıyasla.
3. Resmi e2e: `tests/e2e/ovsync-takip.spec.js` 12/12 (komut: `/home/melik/tmp/agents/uitur-20261001/p12-e2e-run.log` başı; workers=1).
4. Yürüyüş tekrarı: `yuruyus-kos.sh` ile m3, m4, m12, m23, m24 + S0 için m20 → ekran görüntüsü + hüküm.
   Yürüyüş betiğini düzeltmek gerekirse yalnız `/home/melik/tmp/agents/uitur-20261001/yuruyus/` altında.
5. `git diff --check` temiz.

## Yazma manifesti (TEK YAZICI)

1. `js/ui.js`, `js/api.js` (yalnız K1–K6'nın dokunduğu fonksiyonlar)
2. `tests/unit/ovsync-uifix1.test.js` (yeni)
3. `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/ui-fix1-DONE.md`
4. `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/artifacts/fix1-*.png`
5. `/home/melik/tmp/agents/uitur-20261001/**` (repo dışı)

YASAK: commit/push/merge (commit'i mimar atar), `supabase/`, `index.html`, `.ss/`, sahip demo hesabı/şifresi,
pkill / kill -9, alt-ajan. `?v=` önbellek damgasına dokunma (ayrı kalem, mimar karar verir).
Bir kalemde düzeltme tarifi gerçek koda uymuyorsa (fonksiyon yok, davranış farklı): o kalemi YAPMA,
DONE'a "UYUŞMAZLIK" olarak yaz, diğerleriyle devam et. En fazla 2 self-repair turu.

## DONE

Başlık `ui-fix1-DONE — 6 kalemden N tamam`. Tablo: kalem | dosya:satır | test adı | yürüyüş PNG | durum.
Altına: birim sayıları (önce/sonra, kırmızı küme), e2e N/12, `git diff --stat`, UYUŞMAZLIK'lar.
Bitince DONE'u yaz, SONRA `SendMessage` ile dağıtana: `DONE: <bu DONE yolu> · sonuc: <TAMAM|KISMI|BLOKE>`
(adres koltuk açılışında bildirilir). Üst sınır 90 dakika.
