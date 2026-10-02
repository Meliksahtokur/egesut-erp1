# Akış yürüyüşü kanıtları — 2026-09-29 (plan-fix)

Koşum: Playwright 1.58.2 (docker mcr/playwright), demo (EGESUT_DEMO initScript), viewport 420×900.
Betik: `~/tmp/agents/ovsync-plan-fix/yuruyus.cjs` — **salt-okuma**: hiçbir yazma RPC çağrılmadı;
tek etkileşim `tohSonuc('Boş')` confirm'i → dismiss (RPC çağrısı `confirm` return'üyle engellendi);
W5 PG kapısı örnek payload'la render edildi (`_pgKapiAc('PG_KAPI:REQUIRE_ACK_PENDING', …)`, onaylanmadı).

## W1 — Dashboard (`W1-dashboard.png`)
- `gebelik_muayene_listele` demo sonucu: **0 kayıt** (adet 0) → muayene bandı görünmüyor (fail-closed değil:
  band `muayene.length` koşuluyla gizli — boş liste sessizce yok [OBSERVED]).
- Demo'daki tek Bekliyor tohumlama: küpe 178 · TAI 23.09 (≈6 gün) → 40 g eşiği dolmamış, tutarlı.
- 1 adet 401 konsol hatası (tek kaynak; yürüyüşü etkilemedi — anon kapalı bir RPC artığı, izlenmedi).

## W2 — Sessiz/muayene sheet (`W2-sessiz-muayene-sheet.png`)
- `_showSessizList()` → "❗ Sessiz Hayvanlar (9)"; muayene bölümü liste 0 olduğundan yok [OBSERVED].
- Zincir: band → `_showSessizList` (`js/ui.js:2733`) → rpc `gebelik_muayene_listele` (`:2738`) →
  satır `mRow` onclick `openDet(hayvan_id)` (`:2759`) — **sonuç girme akışı YOK**, hayvan detayına gider.

## W3 — GEBELIK_KONTROL görevi tamamlama (`W3-gebelik-kontrol-gorev-detay.png`) — K15'in asıl delili
- Açık görev VAR: küpe 176 · "35. Gün gebelik kontrolü" · 📅 25.09 ⚠️ Gecikmiş · etiket GEBELIK KONTROL.
- Görev detayı butonu: **"✅ Tamamlandı Olarak İşaretle"** — jenerik `detayTamamla` → `doneTask` →
  `rpc('gorev_tamamla')` zinciri; **muayene sonucu (Gebe/Boş) SORULMUYOR** [OBSERVED + CONFIRMED js/ui.js:8956-8973, js/forms.js:3891-3903].
- Betik notundaki "sonucSoruluyorMu: EVET-İLGİNÇ" yanlış-pozitif: regex, açıklamadaki "Gebelik"
  kelimesine eşleşti; ekranda sonuç GİRİŞİ yok (buton tek, jenerik).
- **Keşif — GEBELIK_KONTROL'ün iki üreticisi:** açıklama "35. Gün gebelik kontrolü" =
  `tohumlama_kaydet` +21/+35g görevi (20260521000003:141-142; TOHUMLAMA_HAZIRLIK→GEBELIK_KONTROL
  yeniden adlandırma, domain-rules ⚠7). Cron `gebelik_muayene_gorev_uret` formatı
  "🔬 Gebelik muayenesi: N. gün Bekliyor" (20260925000002:373). Yani görev tipi aynı, üretici/eşik farklı
  (+21/+35g vs cron +40g) → SPEC SORUSU (DONE'da).

## W4 — Tohumlama sonuç modalı (`W4-tohumlama-sonuc-modali.png`)
- Küpe 178 · Bekliyor · "SONUÇ GÜNCELLE" radios GÖRÜNÜR (✅ Gebe / ❌ Boş / ⏳) [OBSERVED].
- `tohSonuc('Boş')` → confirm "Bu tohumlama kaydı \"Boş\" olarak işaretlenecek. Emin misiniz?" →
  **dismiss** → `rpc('tohumlama_sonuc_bos')` ÇAĞRILMADI [OBSERVED dialog log].
- Zincir: `openTohDet(id)` (js/ui.js:11590) → `tohSonuc` (js/forms.js:4335) → Boş dalı `:4348`.

## W5 — PG kapısı "Boş ata ve uygula" (`W5-pg-kapisi.png`) — örnek payload render (yazma yok)
- `#pg-kapi-bs`: "🚫 PG Güvenlik Kapısı · ⚠️ Son tohumlama sonucu Bekliyor — 197 · 01.08.2026 · deneme 2 ·
  …'Boş ata ve uygula' tohumlamayı Boş yapıp PG'yi aynı zincirde uygular · Gerekçe * ·
  [Vazgeç] [Boş ata ve uygula]" [OBSERVED render].
- Mevcut zincir kod: `_pgKapiAc` (js/ui.js:1384) / `_pgKapiBosAtaUygula` (js/ui.js:1455): ÖNCE
  `tohumlama_sonuc_bos` ayrı çağrı, SONRA `__pgKapiTekrar(true)` ayrı retry — **iki-RPC zinciri**
  [CONFIRMED js/ui.js:1461-1472] → review #2'nin değiştireceği nokta.
