# W-R1 TESLİM — Sahip testi revizyonu: tarih seçimi UI + el girişi (G-20260913-TARIH-SECICI-R1)

Tarih: 2026-09-13 · Worker: W-R1 (glm koltuğu) · Akış: ss_org

## 1. Dal + commit

- **Dal:** `agent/tarih-secici-standardi-R1` (base `46abbc8`; iş `d05e6c7` [goal+zarf docs] üstünde)
- **Uygulama commit'i:** `c888b44` — `feat(tarih): R1 ...` (mesajda `R1`)
- **Teslim/docs commit'i:** bu raporu da taşıyan ikinci `R1` commit'i (dal başı; ekrana yazılır)
- `git merge` KULLANILMADI; main'e dokunulmadı; push yok.

## 2. Değişen dosyalar (git diff --stat d05e6c7)

```text
 index.html                       |  46 ++++----
 js/forms.js                      |  94 ++++++++++++++--
 js/tarih/tarih.js                |  90 ++++++++++++++-
 js/ui.js                         | 231 ++++++++++++++++++++++++++++++++-------
 tests/tarih-secici.spec.js       | 128 +++++++++++++++++++++-
 tests/unit/tarih-saf.test.js     | 217 +++++++++++++++++++++++++++++++++++-
 tests/unit/vaka-toplu-ac.test.js | 101 ++++++++++++++---
 7 files changed, 805 insertions(+), 102 deletions(-)
```

(write_manifest'ın tamamı; fazlası yok. `.ss/` BOARD dosyası commit dışıdır.)

## 3. Test kanıtı

| Koşum | Sonuç |
|---|---|
| **Baseline** (`NODE_PATH=/home/melik/egesut-erp1/node_modules node --test tests/unit/*.test.js`) | **836/835/1** — tek kırmızı bilinen `_gmGroupHtml` date-bomb; dokunulmadı |
| **Red-before** (saf katman testleri önce yazıldı, impl öncesi koştu) | 13 YENİ test KIRMIZI (`tarihGirisCoz is not a function` vb.), mevcut 40 yeşil |
| **Final unit** (aynı komut, review düzeltmeleri sonrası) | **857/856/1** — tek kırmızı hâlâ yalnız `_gmGroupHtml` (SIFIR yeni kırmızı); +21 test |
| **Playwright** (docker `mcr.microsoft.com/playwright:v1.58.2-noble`, `PLAYWRIGHT_DEMO_MODE=1 PLAYWRIGHT_BASE_URL=http://127.0.0.1:8080/`, `--retries=0`) | `tests/tarih-secici.spec.js` **9/9** |
| **Regresyon e2e** (aynı ortam) | gece-tarih + sutten-kes + offline-kuyruk + sablon → **6/6** |

Playwright kapsamı (kabul maddeleriyle birebir):
- Masaüstü 1920×1080: `.tarih-modal-kart` genişliği 360–440 aralığında (400), yatay+dikey ortalı; nav oku boundingBox ≥40px.
- Mobil 412×915: kart tam-genişlik (> %90) + alta yaslı alt-sheet; gün tıkı + Onayla + `.value` ISO akışı aynı.
- Dropdown: ay/yıl `selectOption` ile Ocak 2018'e atlayıp hücre seçimi → `#b-tarih` = `2018-01-15`, buton `📅 15.01.2018`.
- Maske: `11122026` → input değeri `11.12.2026`; Uygula → Aralık 2026 görünümü + hücre seçimi → `#ta-tarih` = `2026-12-11`.
- Ayraç toleransı: `13,09,2026` → `13.09.2026`; Uygula → Eylül; Onayla → `#i-tarih` = `2026-09-13` (sahibin bugünkü hata örneği).
- Guard'lar final unit'te yeşil: `type="date"`=0, `.type="date"` ataması tüm js/'te 1, kopya-takvim pini, saf-katman yasakları (block-comment soyulmuş).

Ortam notu: worktree'de unit için `NODE_PATH` ana checkout; e2e için `node_modules` symlink + docker'a ana `node_modules` ro-mount (F2 raporundaki yöntem).

## 4. Bulgu → değişiklik tablosu

| Bulgu | Ne yapıldı | Dosyalar |
|---|---|---|
| **1. Nav okları küçük/siyah** | Ay ‹/› `min-width/height:40px`, koyu zemin `var(--ink)` + açık glif `var(--card)` (açık/koyu temada karşılıklı ters çift → iki temada yüksek kontrast); eski ince yıl-ok satırı KALDIRILDI (yıl dropdown'a geçti — beyan aşağıda). `caseGun`'ın inline onclick ay-matematiği `caseGunAyDegistir`'e taşındı (yıl 1..9999 kelepırlı) | js/ui.js (`_takvimNavStil`, `caseGunAyDegistir`), js/forms.js, her üç render |
| **2. Masaüstünde modal ekranı kaplıyor** | Ortak `<style id="tarih-secici-stil">` (idempotent `tarihSeciciStilEnjekte`): `.tarih-modal-tasiyici` + `.tarih-modal-kart`; `@media (min-width:900px)` → kart 400px, `max-width:calc(100vw - 32px)`, yuvarlak, tasiyici `align-items:center;justify-content:center`. Mobil <900px mevcut tam-genişlik alt-sheet DOKUNULMAZ. `align-items` inline'dan çıkarıldı (inline, media kuralını ezecekti); kart inline `width:100%` sınıfa taşındı. Üç yüzeyde aynı | js/ui.js (`tarihSeciciStilEnjekte`), js/ui.js (iki render), js/forms.js (`bcTakvimRender`) |
| **3. Elle giriş çalışmıyor** | Saf: `tarihGirisCoz` (`, / - boşluk`→`.` normalize + tarihParse; mm/dd YOK), `tarihMaskeUygula` (`11122026`→`11.12.2026`; segment taşması hane YUTMADAN anında işaretlenir — "Gün 1-31 olmalı"/"Ay 1-12 olmalı"/"Yıl 4 hane olmalı"; kuyruk-ayraç korunur → silme doğal), `tarihMaskeImlec` (rakam sayısı korur, nokta üstünden atlar). DOM: `tarihSeciciMaskeBagla` — input olayında maske + hata yuvasına ANINDA uyarı (re-render yok, odak/imeç korunur); Enter=Uygula; `inputmode="numeric"`, `autocomplete="off"`. Uygula `tarihGirisCoz`'dan: geçerli giriş takvimi o aya/yıla ATTLAR ve seçer; hata satır içi + yazdığı korunur. ÜÇ yüzeye bağlandı (bcTakvim'de SAF `bcTakvimSecimEkle` kapısından — başlangıç öncesi/31-gün kuralları hücre tıkıyla aynı) | js/tarih/tarih.js, js/ui.js, js/forms.js |
| **4. Ay + yıl dropdown** | Başlıkta `‹ ›` sayfalama korunarak yan yana iki `<select>` (TR ay adları TARIH_AY_ADLARI). Yıl aralığı saf `tarihYilAraligi(min, max, bugunYil)`: ikisi varsa [min,max]; yalnız min → min+120; yalnız max → max-120; hiçbiri → bugun-120..bugun+10 (bu beyandır). bcTakvim: [başlangıç, başlangıç+30 gün] (∪ görünüm yılı — sayfalama dışarı taşırsa liste peşinden gider). Seçim işleyicileri: `tekTarihTakvimAySec/YilSec`, `bcTakvimAySec/YilSec` (offset deltası), `caseGunAySec/YilSec` | js/tarih/tarih.js, js/ui.js, js/forms.js |
| **5. Puntolar** | Başlık .65→.78rem; gün-adları .6→.7rem; hücre .82→.9rem; "Seçilen" .95→1.02rem; ay/yıl seçicileri 1.02rem/kalın; hata metni .72→.9rem; el-girişi inputu 1rem (iOS zoom eşiği) + min-height:40px; Uygula .95rem + min-height:40px | üç render |

**Beyan (yıl-okları):** Zarf bulgu 1 yıl ‹/› oklarının büyütülmesini ister; bulgu 4 ise başlıkta ay+yıl seçicilerini koyar ve yalnız ay oklarının kalacağını söyler. Sahibin taslağı (bulgu 4, "bozmak gerekirse sahibin taslağı tercih edilir") uygulandı: yıl erişimi dropdown'a verildi, yıl-ok satırı kaldırıldı, ay okları büyütüldü.

## 5. Guard beyaz listesine eklenen adlar

`bcTakvimAySec`, `bcTakvimGirisUygula`, `bcTakvimYilSec`, `tekTarihTakvimAySec`, `tekTarihTakvimYilSec`
(çıkarılan: `tekTarihTakvimYilDegistir` — fonksiyon kullanıcısıyla birlikte silindi.
`tarihSeciciStilEnjekte`, `tarihSeciciMaskeBagla`, `caseGunAyDegistir/AySec/YilSec/GirisUygula` adları `/Takvim|GunSecim/i` desenine eşleşmez → liste gerektirmez.)

## 6. `?v=` damga durumu

`index.html` içinde **20260913-17** × 23 nokta (22 script + manifest link); `-16` kalıntısı **0**. Uygulama ile AYNI commit'te. `tests/unit/vaka-toplu-ac.test.js` damga-pinleri `-17`'ye güncellendi.

## 7. Review notu

`bulgu: builtin code-reviewer (max-effort tarama, 39 araç çağrısı) — KRİTİK 0, ÖNEMLİ 1, KÜÇÜK 4.`
- ÖNEMLİ `caseGunEkle` açılışta `_gunSecimGirisMetni/Hatasi` sıfırlamıyordu (bayat metin + kırmızı bant tekrar açılışta) → **DÜZELTİLDİ** (ui.js, kardeş yüzeylerin davranışına bağlandı).
- KÜÇÜK çift `⚠️` (bcTakvim SAF mesajı + render öneki) → **DÜZELTİLDİ** (mesaj öneki soyuldu).
- KÜÇÜK `caseGunAyDegistir` yıl kelepırsız → **DÜZELTİLDİ** (1..9999).
- KÜÇÜK maske ortadan-düzenlemeyi yeniden segmentler → kabul edildi/beyanlı (Uygula reddi güvenli; §8).
- KÜÇÜK bcTakvim metin-girişi toggle-off sessiz → kabul edildi/beyanlı (§8).
- Reviewer ayrıca önceden-var olan `gecmis-pipeline` DÜN time-bomb'u işaretledi (bilinen `_gmGroupHtml` kırmızısının kökeni; bu diff'in dosyalarıyla ilgisiz — §8).

## 8. Açık riskler / ertelenenler

1. **Maske ortadan-düzenleme:** maskeli değer ortasından yazılınca dizge baştan yeniden segmentlenir (örn. başa '5' → '51.30.9202' + çoklu hata). Veri güvenliği yok — Uygula'da `tarihParse` reddeder; katı maskenin bilinen bedeli, ayrı cilalama işi.
2. **bcTakvim giriş-toggle:** seçili bir tarihin elle yazılıp Uygula'lanması onu seçimden ÇIKARIR (hücre tıkı semantiği — SAF `bcTakvimSecimEkle` tek kapı). Sessizliği hafifletme ("çıkarıldı" geri bildirimi) ertelendi.
3. **`tarihYilKaydir` çağrıcısız kaldı** (yıl-ok satırının silinmesiyle). Saf katman API'si + testleri duruyor; kaldırma/saklama kararı sahibin.
4. **Bilinen kırmızı `_gmGroupHtml`** (gecmis-pipeline.test.js): DÜN etiketi gerçek `new Date()`'ten (gecmis.js:262-264) hesaplanıyor, test sabit tarihe pinli → time-bomb. "DO NOT touch" talimatına uyuldu; onarım ayrı iş olarak önerilir.
5. **ui-map.md § canonical date selection** güncelleme adayı (`tarihGirisCoz`, dropdown başlık, 400px masaüstü kart) — write_manifest DIŞI olduğundan dokunulmadı; root için öneri.
6. **e2e kapsamı:** kritik-akis / modal-router / smoke koşulmadı (takvim yüzeyine dokunmayan F2-bazlı regresyon seti seçildi).
7. Zarf/goal frontmatter'daki `branch: agent/tarih-secici-standardi` alanı eski kopyadır (base_sha 46abbc8 + W-R1 zarfı "YOUR branch" diyor) — iş `agent/tarih-secici-standardi-R1` dalında yapıldı.

---

# REVİZYON TURU (W-R1, denetim: REVİZYON — G-20260913-TARIH-SECICI-R1)

Tarih: 2026-09-14 · Yetki: `.claude/reviews/2026-09-13-tarih-secici-r1-denetim.md` (dal `agent/tarih-secici-r1-denetim`)
Temiz-doğrulanan mevcut durum (üç-yüzey bağlantısı, mobil korunum, guard/damga) DOKUNULMADI.

## Bulgu → düzeltme tablosu

| # | Bulgu (seviye) | Ne değişti | Dosyalar | Test pini |
|---|---|---|---|---|
| 1a | KRİTİK — maske taşması `151.12.2026` → `15.11.2202` yanlış-geçerli ISO | `tarihMaskeUygula` yeniden yazıldı: taşan bölük YENİDEN BÖLÜNMEZ, taşan hane YUTULMAZ, ayraç dışı metin YENİDEN YAZILMAZ — hatalı girişte metin ayraç-normalizasyonu dışında birebir korunur + `hata` döner | js/tarih/tarih.js | `tarihMaskeUygula('151.12.2026')` → metin aynen + `/Gün 1-31/`; `151.12.26`, `05.12.20265`, `111220261` benzer; eski yutma pinleri tersine çevrildi |
| 1b | KRİTİK — Uygula maske hatasını görmeden `tarihGirisCoz`'a düşüyor | Üç Uygula yolu da (`tekTarihTakvimGirisUygula`, `caseGunGirisUygula`, `bcTakvimGirisUygula`) `tarihGirisCoz`'dan ÖNCE `tarihSeciciMaskeHatasiAl` kapısından geçer. Kapı **DURUMSUZDUR** (aşağıda review notu): mevcut input değerinden `tarihMaskeUygula`'yı yeniden hesaplar | js/ui.js, js/forms.js | DOM pini: maske hatası beklerken Uygula → onSec ESKİ değeri alır (taşma sızmaz) + ikinci Uygula da maske hatasıyla reddedilir + kurtarma akışı |
| 2 | ORTA — `05.02.2026abc` junk sessiz siliniyordu | Ayraç kümesi (`., / - boşluk`) dışındaki HER rakam-dışı karakter `Rakam girmelisiniz` hatası verir, metin korunur | js/tarih/tarih.js | `05.02.2026abc`, `12,34x2026`, `ab?!12cd2026` → metin aynen + `/Rakam girmelisiniz/`; eski yanlış-kabul pini (tarih-saf.test.js `ab?!12cd2026 → 12.20.26`) hataya çevrildi; `13 09 2026` meşru kalır |
| 3 | DÜŞÜK — `00` alt sınırı görünmüyordu | Gün/ay segment değeri `< 1` → segment hatası; yıl tavanı `null` yerine `9999` → `0000` da yakalanır (`Yıl 1-9999 olmalı`) | js/tarih/tarih.js | `00` → `/Gün 1-31/`; `01.00` → `/Ay 1-12/`; `05.12.0000` → `/Yıl 1-9999/`; `01.01.2026` hatasız |
| 4 | DÜŞÜK — bcTakvim `9999-12 ›` → yıl 10000 + boş ızgara | `bcTakvimAyDegistir`: offset güncellemesi sonrası hedef ay/yıl `bcTakvimAyGosterim` ile denetlenir; 1..9999 dışıysa adım RED (offset geri alınır, render atlanır) | js/forms.js | `9999-12-01` › → Aralık 9999 korunur, `10000` hiçbir yerde doğmaz; ‹ Kasım 9999 çalışır; `0001-01-01` ‹ → Ocak 0001 korunur |
| 5 | DÜŞÜK — caseGun yıl kelepiri ayı bozuyordu (1-Ocak ‹ → Aralık-1) | `caseGunAyDegistir`: hedef yıl 1..9999 dışındaysa FONKSİYONDAN ÇIKILIR — ham modulo uygulanmaz, bulunduğun kenar ay/yıl korunur. **Beyan:** poliçe "kenarda sayfalama reddi" (ay/yıl tutarlı korunur; modulo-yeniden-hesap seçeneği uygulanmadı) | js/ui.js | `Ocak 0001` ‹ → Ocak-1 kalır; `Aralık 9999` › → Aralık-9999 kalır (Ocak-9999 bozması yok) |
| 6 | DÜŞÜK — e2e üç-yüzey kapsamı | **Ölçülmüş sınırlılık olarak BEYAN** (test istenmedi): R1 tarayıcı testleri yalnız tekTarih yüzeyini sürer; bcTakvim ünite katmanında (vaka-toplu-ac DOM pinleri), caseGun çalışma-zamanı e2e kapsamı ertelenmiş boşluk | tests/ | — |

## Kapı çıktıları (worker koştu)

| Kapı | Sonuç |
|---|---|
| Unit tam (`node --test tests/unit/*.test.js`) | **863 test / 862 pass / 1 fail** — tek kırmızı hâlâ yalnız bilinen `_gmGroupHtml` (≥857 şartı sağlandı; +6 net test) |
| Yeni pinler (B1a taşma / B2 junk / B3 `00`) | Üstteki tabloda; hepsi yeşil |
| Playwright `tests/tarih-secici.spec.js` | **9/9 passed** (43.1s) — `11122026` happy path dahil; koşum Docker `mcr.microsoft.com/playwright:v1.58.2-noble`, `PLAYWRIGHT_DEMO_MODE=1 PLAYWRIGHT_BASE_URL=http://127.0.0.1:8080/`, konteyner-içi webServer bu worktree'yi servis etti (host 8080 docker-proxy'de; host tarayıcı dep bağımlılığı CachyOS'ta yok). Not: `test-results/`+`tests/report` root-sahipli eski Docker kalıntısı — çıktı `--output=/tmp/pw-out` ile konteyner-içine alındı, host'a root-artığı yazılmadı |
| `?v=` damga | **20260913-18** tek ortak değer: `index.html` × 23 (22 script + manifest), `-17` kalıntı **0** (kalan tek `-17` referansı testteki negatif-substring koruma listesinde — doğru yer); damga testleri `-18`'e güncellendi; uygulama ile AYNI commit'te |
| Guard beyaz liste | Değişmedi (beklentiye uygun): yeni ad `tarihSeciciMaskeHatasiAl` `/Takvim|GunSecim/i` desenine eşleşmez → liste gerektirmez; F4 muhafız testi yeşil |

## Zorunlu review notu (sahip daimi kuralı)

`bulgu: builtin code-reviewer (diff-scope tarama, 14 araç çağrısı, 20+ maske→çöz sondası) — KRİTİK 0, ÖNEMLİ 1, KÜÇÜK 2.`
- ÖNEMLİ `tarihSeciciMaskeHatasiAl` depolanan expando'ya (`inp._tarihMaskeSonuc`) yaslanıyordu; tarayıcıda Uygula-hata yeniden-render'ı input'u innerHTML ile yeniden doğurduğu için kapı ikinci Uygula'da ölüyordu (bugün sızma yok — tüm maske-hata dizgelerini `tarihParse`'ın anchored regex'i reddediyor; mesaj farkı kozmetikti). **DÜZELTİLDİ:** kapı durumsuz yapıldı — mevcut değerden yeniden hesaplar (ui.js). İkinci-Uygula pini eklendi; yan etkisi: maske-geçersiz metin Apply'da artık önce maske mesajıyla reddedilir (`90,09,2026` pini buna göre güncellendi — iki mesaj da reddiydi, maske mesajı birinci hat oldu).
- KÜÇÜK ayracı-bölük kısmi segmentlerinde (`0.5.2026`) 0-alt-sınır uyarısı satır içinde görünmez (red Apply'da '…yok' mesajıyla gelir; veri riski yok) → kabul edildi/beyanlı.
- KÜÇÜK tam 10 karakterden sonraki kuyruk ayracı başarı yolunda sessizce düşer (kuyruk politikası — fonksiyon başlığındaki belgelenmiş tasarım; B2 ilkesiyle gerilim yorumlandı) → kabul edildi/beyanlı.
- Reviewer kararı: beş denetim bulgusunun fix'i doğru ve testlerle kilitli; kritik-yanlış-geçerli-ISO üretimi taranan tüm uçlarda doğrulanamadı → **birleştirmeye hazır**.

## Önceki teslimdeki açık-riskler durumu (§8 → güncel)

- Madde 1 (maske ortadan-düzenleme) geçerli; ek kısıt artık sert: hatalı düzenlemede metin AYNEN korunur + Uygula kapıda (veri güvenliği önceki turdakinden güçlü).
- Madde 6'ya ekleme: caseGun çalışma-zamanı e2e kapsamı ertelenmiş (bu turun BEYAN'ı, bulgu 6).

## Revizyon turu değişen dosyalar (git diff --stat 0c198ee..çalışma-ağacı)

```text
 index.html                       |  46 ++++----
 js/forms.js                      |  18 +++
 js/tarih/tarih.js                |  80 ++++++++++----
 js/ui.js                         |  40 ++++++-
 tests/unit/tarih-saf.test.js     | 116 ++++++++++++++++++++-
 tests/unit/vaka-toplu-ac.test.js |  30 ++++--
 (kod+test: 6 dosya; ayrıca bu raporun kendisi 7. dosya olarak aynı commit'te)
```

`.ss/` BOARD dosyası commit dışıdır (önceki teslimle aynı). Merge YOK, push YOK.
