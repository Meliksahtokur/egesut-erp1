# R1 — Sahip testi revizyonu (tarih seçici) — TESLİM NOTU (W-R1 + LEAD kabul, 2026-09-13/14)

Goal: G-20260913-TARIH-SECICI-R1 · Dal: `agent/tarih-secici-standardi-R1` → lead dalı
`agent/tarih-secici-standardi` · Commit'ler (hepsinde `R1`): `d05e6c7` (goal+zarf) →
`c888b44` (uygulama) → `0c198ee` (teslim raporu) → **`6e0dd64` (revizyon)** → lead merge
**`8899e36` + `ce5e6cb`** · Denetim raporu pakette (`e896072`, `6873f19`)
Bu raporun güncel hali lead kabul bölümüyle son commit'te.

## 5 sahip bulgusu → uygulama (üç tarih yüzeyi: tekTarihTakvimAc, bcTakvim*, caseGunModalRender)

1. **Nav okları:** ‹/› ≥40px dokunma hedefi, koyu zemin (`var(--ink)`) + açık glif
   (`var(--card)`) — iki temada da yüksek kontrast. Eski ince yıl-ok satırı kaldırıldı
   (yıl dropdown'a; sahibin bulgu-4 taslağı tercih edildi — beyan).
2. **Masaüstü kompakt modal:** ortak `<style>` (idempotent enjeksiyon) +
   `.tarih-modal-kart`/`.tarih-modal-tasiyici`; ≥900px'te 400px ortalı kart; <900px'te
   mevcut tam-genişlik alt-sheet değişmedi (Playwright 412×915 pini).
3. **El girişi:** saf `tarihGirisCoz` (`, / - boşluk`→`.`; mm/dd YOK), `tarihMaskeUygula`
   (`11122026`→`11.12.2026`; **taşan segment hane yutmaz — yazılan korunur + hata**
   [revizyon]), `tarihMaskeImlec` (imleç rakam korur); DOM bağı `tarihSeciciMaskeBagla`
   (anında hata yuvası, odak korunur); Enter=Uygula; `inputmode="numeric"`. Geçerli
   giriş takvimi o aya atlar ve seçer. **Uygula durumsuz maske kapısından geçer —
   bekleyen maske hatası `tarihGirisCoz`'dan ÖNCE reddeder** [revizyon, üç yüzeyde].
4. **Ay+yıl dropdown:** başlıkta TR ay + yıl `<select>`, ‹/› kalır; yıl aralığı
   `tarihYilAraligi(min,max,bugunYil)` (ikisi→[min,max]; tek→±120; hiç→bugun−120..+10 —
   beyan). bcTakvim aralığı [başlangıç, başlangıç+30g]. bcTakvim/caseGun kenar
   sayfalama 1..9999'da reddedilir [revizyon].
5. **Puntolar:** başlık/hata/seçici/hücre punto artışı + giriş 1rem (iOS zoom eşiği).

## Denetim turu (codex max, `6873f19` — SONUÇ: REVİZYON) → çözümler (`ce5e6cb`)

| Bulgu | Şiddet | Sonuç |
|---|---|---|
| Maske taşması metni bozup yanlış-geçerli ISO kabul ettiriyordu (`151.12.2026`→`15.11.2202`) | KRİTİK | DÜZELTİLDİ: taşma yazılanı bozmaz + hata; Uygula maske hatasını önce reddeder (pin: `tarihMaskeUygula('151.12.2026').metin === '151.12.2026'`) |
| Rakam-dışı junk sessizce siliniyordu (`05.02.2026abc` kabul) | ORTA | DÜZELTİLDİ: "Rakam girmelisiniz" + metin korunur; yanlış yeşil assertion düzeltildi |
| `00` alt sınırı maske tarafından görülmüyor | DÜŞÜK | DÜZELTİLDİ: 00/0000 → hata |
| bcTakvim offset 9999'u taşıyordu | DÜŞÜK | DÜZELTİLDİ: kenar sayfalama reddi |
| caseGun yıl kelepiri ayı bozuyordu | DÜŞÜK | DÜZELTİLDİ: kenar sayfalama reddi |
| e2e üç-yüzey kapsamı yalnız tekTarih | DÜŞÜK | BEYAN: ölçülmüş sınırlılık (bcTakvim unit katmanında kilitli) |
| Muhafız junk-temizleme bekleyen kusuru yeşil sözleşme yapıyordu | ORTA | DÜZELTİLDİ (yukarıdaki ORTA ile) |

## Kanıt (lead bağımsız ölçüm, kendi dalında — merge sonrası)

- Unit: **863/862/1** — tek kırmızı bilinen `_gmGroupHtml` date-bomb; sıfır yeni kırmızı.
- Playwright `tarih-secici.spec.js`: **9/9** (maske happy-path `11122026` korundu);
  F2-bazlı regresyon 6/6.
- `type="date"` = **0**; `?v=20260913-18` **×23 TEK değer**, `-17` kalıntısı 0.
- Guard'lar yeşil: saf katman yasakları (block-comment soyucu), kopya sembol yasağı,
  ad-aileri beyaz listesi, damga pinleri.
- Red-before: 13 saf test impl öncesi kırmızıydı (W-R1 ilk tur); revizyon pinleri
  denetim sondalarıyla yazıldı.

## Review notları

- W-R1 (ilk tur): `bulgu: KRİTİK 0, ÖNEMLİ 1 (DÜZELTİLDİ), KÜÇÜK 4 (2 DÜZELTİLDİ, 2 beyanlı)`.
- Codex denetim: `SONUÇ: REVİZYON` — yukarıdaki tablo.
- W-R1 (revizyon): `bulgu: ÖNEMLİ 1 (Uygula kapısı expando→durumsuz — DÜZELTİLDİ), KÜÇÜK 2 beyanlı`.

## Risk / ertelenen (owner)

- Maske ortadan-düzenleme kabalığı (Uygula reddiyle güvenli), bcTakvim metin-girişi
  toggle-off sessizliği, `tarihYilKaydir` çağrıcısız kaldı (sil/sakla kararı sahibin),
  ui-map § canonical güncelleme adayı (manifest dışı), `_gmGroupHtml` DÜN time-bomb
  onarımı ayrı iş. Ayrıntı: `.claude/reviews/2026-09-13-tarih-secici-r1-teslim.md`.

Sonra dur — entegrasyon (E1 dalına birleştirme) root'tadır.
