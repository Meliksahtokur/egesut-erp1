# Boş sonrası devam — mockup teslimi

Sonuç: **TAMAM**

## Üretilen dosyalar (mutlak yollar)

Klasör: `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/mockup/bos-devam/`

- `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/mockup/bos-devam/01-bos-devam-secici.html`
- `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/mockup/bos-devam/01-bos-devam-secici.png`
- `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/mockup/bos-devam/02-ovsync-kilitli.html`
- `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/mockup/bos-devam/02-ovsync-kilitli.png`
- `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/mockup/bos-devam/03-pg-secili.html`
- `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/mockup/bos-devam/03-pg-secili.png`
- `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/mockup/bos-devam/04-takip-acik-onay.html`
- `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/mockup/bos-devam/04-takip-acik-onay.png`
- `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/mockup/bos-devam/05-takip-muayene-sonuc.html`
- `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/mockup/bos-devam/05-takip-muayene-sonuc.png`
- `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/mockup/bos-devam/06-takip-ekrani-rozet.html`
- `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/mockup/bos-devam/06-takip-ekrani-rozet.png`
- `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/mockup/bos-devam/07-akis.html`
- `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/mockup/bos-devam/07-akis.png`
- `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/mockup/bos-devam/shot.js` (hepsini tek seferde çeken script)
- `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/mockup/bos-devam/_paylasim.css.html` (referans/ölü dosya — sayfalar arası ortak CSS'in kaynağı, chromium ile doğrudan açılmaz)

## Her PNG ne gösteriyor

1. `01-bos-devam-secici.png` — Tohumlama sonuç modalı: Gebe/Boş çipleri (Boş seçili), altında devam seçici, "🔄 Ovsync uygula" ön seçili, Kaydet "Boş ata + Ovsync başlat".
2. `02-ovsync-kilitli.png` — Aynı modal: Ovsync kartı 🔒 "Kural günü 12.10 — 14 gün var" gerekçesiyle kilitli, Takibe bırak otomatik seçili, PG seçilebilir durumda; altta kilit-gerekçesi deseninin ikinci örneği ("🔒 Kısır hayvan").
3. `03-pg-secili.png` — PG seçili, ürün/doz seçici açık ve "Estrumate 2 ml" ile önceden dolu, Kaydet "Boş ata + PG uygula".
4. `04-takip-acik-onay.png` — App'in kendi bottom-sheet onay penceresi: "Bu hayvan takipte" başlığı, "Evet, takibi kapat ve uygula" / "Vazgeç" butonları; arka planda soluk PG uygulama formu görünür (tarayıcı confirm değil).
5. `05-takip-muayene-sonuc.png` — Takip muayenesi görevi sonucu: "🔍 Takip muayenesi — Küpe 197", "Boş atandı 28.09 · takip 7. gün" bilgisi, devam seçici varyantı (Ovsync / PG / 📅 Muayeneyi ertele +7 gün) + "🐄 Kızgınlıkta → tohumlama kaydına geç" köprü butonu.
6. `06-takip-ekrani-rozet.png` — Takip ekranı "① Başlatılmayı bekleyenler" kesiti: 197 satırı "🔍 takipte" rozetiyle (muayene 05.10 14:35), altında normal 🔒 kilitli/hedef-tarihli satırlar (v1 mockup kart-liste stili).
7. `07-akis.png` — Dikey kutu-ok akış diyagramı: "Boş" → Devam seçici → 3 dal (Ovsync/PG/Takibe bırak) → Takibe bırak dalından "DB otomatik kapatır" (yeni tohumlama, Ovsync/PG başlatma onayı, hayvan çıkışı) → muayene görevi → muayene sonucu ekranı → yine devam seçici (↺ ertele döngüsü) → alt kısımda 2 kural notu (kısır/kural günü kilidi, takip açıkken otomatik Ovsync açılmaz).

## Sorunlar / notlar

- İlk taslakta `04-takip-acik-onay.html`'de arka plandaki soluk PG formu, onay katmanının koyu arka planı altında tamamen görünmez çıkmıştı (iki `position:absolute; inset:0` katmanı üst üste, ikisi de alta hizalı). Düzeltildi: arka form üstten hizalandı, onay katmanının arka plan opaklığı düşürüldü (0.86→0.45); yeniden çekilen PNG'de form net görünüyor. Diğer 6 ekranda ilk çekimde sorun çıkmadı.
- Tüm ekranlar 420px viewport + fullPage ile çekildi, hiçbirinde metin kesilmesi yok (7 PNG de Read ile açılıp gözle kontrol edildi).
- Ürün kodu değişmedi, commit atılmadı, yalnız `bos-devam/` klasörü altına yazıldı.
