# Hastalık filtresi "telefonda çalışmıyor" teşhisi (2026-09-07)

**Durum:** KAPANDI — kullanıcı "başarılı hotfix" onayı verdi. **Kod değişikliği YOK** (salt araştırma oturumu); kök neden telefonda eski sekme/JS, çözüm sekme kapat + yenile. Canlıda hiçbir şey bozulmamıştı.

**Tetik:** Kullanıcı raporu — T2 dinamik hastalık filtresi (e72beec, 02.09.2026, main) PC'de çalışıyor, telefonda çalışmıyor (ekran görüntüsü: PC görünümü, dropdown açık).

## Araştırma akışı (systematic-debugging, düzeltmesiz kanıt toplama)

1. **Feature tespiti:** `js/ui.js` `_hastaHastalikFiltreHtml` (hh-drop-btn, data-action `hasta-hastalik-drop`), handler `js/utils/handlers.js:67`, konteyner `index.html:634` — çip satırının **kardeşi** (overflow clipping riski yok), outside-click closer `#hasta-hastalik-filtre` içini muaf tutuyor.
2. **Canlı deploy doğrulaması:** `meliksahtokur.github.io/egesut-erp1` → `js/ui.js?v=20260907-4`, index HTML'de `hasta-hastalik-filtre` var, canlı ui.js'te feature grep=3. GH Pages `cache-control: max-age=600`.
3. **Kod katmanı taraması:** Event delegasyonu (`js/utils/events.js`, document-level click), veri yolu (`aktifVakalar` = IDB `cases` status='active' + `diseases`, ikisi de TABLES pull listesinde) — dokunmatik-kırıcı nokta bulunamadı. `cases`/`diseases` boş olsaydı Hasta çipi de çalışmazdı (kullanıcı yalnız yeni özelliği şikâyet etti → veri hipotezi zayıf).
4. **Service worker arkeolojisi (asıl şüpheli, elendi):** Gerçek cache-first SW yalnız 05–08.03.2026 yaşadı (3dbf34d→54471bc); `sw.js` o günden beri **stub** — fetch handler yok, activate'te tüm cache'leri siler. Tek-seferlik unregister temizliği (`ege_sw_temizlendi`) 06.07.2026'da eklendi (e2c66a6, M-10). SW'li telefon en fazla bir yenilemede güncel koda düşer; kalıcı kilitlenme imkânsız.
5. **Mobil emülasyon uçtan uca test (IAB, 390×844, canlı site, demo hesap):** localStorage `EGESUT_DEMO=1` + autologin → Sürü → 🏥 Hasta çipi → kutu geldi → dropdown **25 seçenekle açıldı** → "Aspirasyon" seçimi → buton "🦠 Hastalık: 1 ▾", ✕ Temizle geldi, liste **44→1** filtrelendi. Kod cihaz-bağımsız **PASS**.
6. **Kök neden:** Telefon 02.09.2026 akşamından (feature deploy) önce yüklenmiş bir sekme/JS çalıştırıyordu. Mobil tarayıcı sekmeyi haftalarca bellekte tutar; sekmeye geri dönmek yeniden fetch tetiklemez. Çözüm: sekme kapat + sayfayı yenile → kullanıcı onayladı.

## Elenen hipotezler

| Hipotez | Sonuç | Kanıt |
|---|---|---|
| Service worker eski shell'i kilitledi | ❌ elendi | sw.js 08.03.2026'dan beri stub; temizlik 06.07.2026'da |
| Telefonun IDB verisi (cases/diseases) eksik | ❌ elendi | Hasta çipi ve liste aynı `hastaLogs` kaynağını kullanıyor; ikisi de çalışıyordu |
| Dokunma katmanı / event delegation mobil kırığı | ❌ elendi | Mobil emülasyonda uçtan uca PASS; delegasyon cihaz-bağımsız |
| Çok eski tarayıcı (parse hatası) | ❌ elendi | Bu durumda tüm uygulama (ui.js) yüklenmezdi, yalnız bu özellik değil |
| **Telefonda eski sekme/JS** | ✅ **kök neden** | Deploy 02.09.2026; yenileme kullanıcıda sorunu çözdü |

## Otomasyon ortamı dersi (IAB arka plan sekmesi)

Test sırasında üç "sahte bulgu" üretildi ve doğru teşhis edildi: arka plan sekmesinde rAF durur → (1) Playwright click actionability/stability kontrolü hiç tamamlanmaz (timeout), (2) `cua.click` koordinat tıklaması sayfaya click event'i ulaştırmaz (capture-phase `clickLog` boş döner), (3) rAF tabanlı evaluate zaman aşımı. Bunlar **uygulama hatası değil, otomasyon ortamı belirtisi**. Geçerli ikame: `evaluate` içinden `.click()` — aynı click event'ini delegasyona verir; yalnız fiziksel dokunma katmanı test edilemez (o katman evrensel tarayıcı davranışı).

## Etki yüzeyi ve docs-update kararı

- **Kod:** değişiklik yok. **SQL:** yok. **Deploy:** yok (deploy zaten günceldi).
- **Bellek:** ZCode auto-memory (`hastalik-filtre-mobil-sorunu`) + tools-bank #1403 yazıldı; bu rapor + `.claude/session-learnings.md` 2026-09-07 bölümü kalıcı ders taşıyor; `.harness/memory/` bilinçli boş kaldı (ders zaten raporla temsil ediliyor — README sınırına uygun).
- **docs-update receipt:** üretilmedi — receipt commit/checkpoint'e bağlıdır; bu oturumda Git değişikliği ve commit yok, değerlendirilecek staged scope boş. Durable kayıt bu rapordur.
