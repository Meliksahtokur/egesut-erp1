# Toplu Padok Transfer Aracı — Araştırma

**Tarih:** 2026-06-02  
**Durum:** Araştırma tamamlandı  
**Kapsam:** Mevcut altyapı envanteri, eksikler, önerilen çözüm

## Özet

EgeSüt ERP'de toplu padok değiştirme altyapısı büyük ölçüde **tamamlanmış** durumda:

- **Backend:** `padok_degistir` (tekli) ve `padok_degistir_toplu` (toplu) RPC'leri çalışıyor, transactional + islem_log
- **Frontend:** `m-padok-det` modal'ı içinde checkbox seçimi → "Toplu Taşı" → `m-padok-transfer` modal → onay akışı çalışıyor
- **Handler bağlantıları:** `handlers.js`'de kayıtlı

**Kritik eksikler:**
1. **Kapasite kontrolü YOK** — hedef padok dolu olsa bile transfer eder
2. **Filtre + toplu seçim YOK** — "Bu padoktaki tüm gebeleri taşı" gibi kriter bazlı otomatik seçim yok
3. **Cross-padok YOK** — birden fazla padoktan hayvan seçip dağıtma yok
4. **Grup→padok otomatik atama YOK** — grup değişince padok otomatik güncellenmez (Besi hariç)
5. **UX katman fazlalığı** — 3 modal geçişi, kullanıcı deneyimi zayıf

## İçindekiler

| Dosya | İçerik |
|-------|--------|
| `00-mevcut-durum.md` | Backend + frontend altyapı envanteri (RPC'ler, JS fonksiyonları, HTML, handler'lar) |
| `01-eksikler.md` | Tespit edilen eksikler, zayıf noktalar, riskler |
| `02-oneri.md` | Önerilen çözüm mimarisi, değişmesi gereken dosyalar, adımlar |

## İlgili Kaynaklar

| Kaynak | İçerik |
|--------|--------|
| `.claude/notes/padok-transfer-arastirma.md` | Önceki araştırma (2026-05-21) |
| `.claude/ideas/padok-transfer-ux.md` | UX fikir dokümanı (2026-05-25) |
| `docs/feature-status-2026-05-13.md` | Özellik durum raporu |
| `docs/superpowers/plans/2026-05-13-asama3-ui.md` | Aşama 3 UI planı (handler tanımları) |
