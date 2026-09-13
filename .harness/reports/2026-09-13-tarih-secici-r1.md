# R1 — Sahip testi revizyonu (tarih seçici) — TESLİM NOTU (W-R1, 2026-09-13)

Goal: G-20260913-TARIH-SECICI-R1 · Dal: `agent/tarih-secici-standardi-R1` · Uygulama commit'i: c888b44 (mesajda `R1`)

5 sahip bulgusu üç tarih yüzeyine (tekTarihTakvimAc, bcTakvim*, caseGunModalRender) indirildi:

1. **Nav okları:** ‹/› ≥40px dokunma hedefi, koyu zemin (`var(--ink)`) + açık glif (`var(--card)`) — iki temada da yüksek kontrast. Eski ince yıl-ok satırı kaldırıldı (yıl dropdown'a; sahibin bulgu-4 taslağı tercih edildi — beyan).
2. **Masaüstü kompakt modal:** ortak `<style>` + `.tarih-modal-kart`/`.tarih-modal-tasiyici`; ≥900px'te 400px ortalı kart; <900px'te mevcut tam-genişlik alt-sheet değişmedi (Playwright 412×915 pin).
3. **El girişi:** saf `tarihGirisCoz` (`, / - boşluk`→`.`; mm/dd YOK), `tarihMaskeUygula` (`11122026`→`11.12.2026`; taşan segment anında işaretlenir — hane yutulmaz, sessiz düzeltme yok), `tarihMaskeImlec` (imleç rakam korur); DOM bağı `tarihSeciciMaskeBagla` (anında hata yuvası, odak korunur); Enter=Uygula; inputmode=numeric. Geçerli giriş takvimi o aya atlar ve seçer. Üç yüzeyde.
4. **Ay+yıl dropdown:** başlıkta TR ay + yıl `<select>`, ‹/› ay sayfalaması kalır; yıl aralığı `tarihYilAraligi(min,max,bugunYil)` (ikisi→[min,max]; tek→±120; hiç→bugun−120..+10 — beyan). bcTakvim aralığı [başlangıç, başlangıç+30g].
5. **Puntolar:** başlık/hata/seçici/hücre punto artışı + giriş 1rem (iOS zoom eşiği).

Kanıt: unit baseline 836/835/1 → final **857/856/1** (tek kırmızı bilinen `_gmGroupHtml`; 13 saf test red-before kanıtlı); Playwright (docker v1.58.2, demo-mode) tarih-secici **9/9** + regresyon (gece-tarih, sutten-kes, offline-kuyruk, sablon) **6/6**; guard'lar yeşil (`type="date"`=0, `.type="date"`=1, beyaz liste +5/−1, saf katman yasakları). Damga `?v=20260913-17` × 23/23 tek değer, uygulamayla aynı commit'te.

Review: builtin code-reviewer — `bulgu: KRİTİK 0, ÖNEMLİ 1 (caseGunEkle giriş-durumu sıfırlaması — DÜZELTİLDİ), KÜÇÜK 4 (çift ⚠️ ve yıl kelepırı DÜZELTİLDİ; maske orta-düzenleme ve giriş-toggle-off beyanlı)`.

Risk/ertelenen: maske ortadan-düzenleme kabalığı (Uygula reddiyle güvenli), bcTakvim metin-girişi toggle-off sessizliği, `tarihYilKaydir` çağrıcısız kaldı (karar sahibin), ui-map § canonical güncelleme adayı (manifest dışı), `_gmGroupHtml` DÜN time-bomb onarımı ayrı iş. Ayrıntı: `.claude/reviews/2026-09-13-tarih-secici-r1-teslim.md`.

Sonra dur — entegrasyon root'tadır.
