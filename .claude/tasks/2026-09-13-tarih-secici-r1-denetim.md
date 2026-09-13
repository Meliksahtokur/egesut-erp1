# DENETİM — R1 teslimi (goal G-20260913-TARIH-SECICI-R1)

Sen bağımsız bir deneticisin. TEK TUR. Hiçbir şeyi düzeltmezsin; bulgu
raporlarsın. Yazar özetlerine güvenme — gerçek diff ve gerçek testler
üstünde çalış.

Denetim konusu: `git diff agent/tarih-secici-standardi...agent/tarih-secici-standardi-R1`
(dosyalar: index.html, js/ui.js, js/forms.js, js/tarih/tarih.js,
tests/tarih-secici.spec.js, tests/unit/tarih-saf.test.js,
tests/unit/vaka-toplu-ac.test.js). Tam dosyalar:
`git show agent/tarih-secici-standardi-R1:<yol>`.
Sahip bulguları (hedef sözleşme):
`/home/melik/egesut-erp1/.ss/tasks/R1-tarih-secici-revizyon.md`.

--- BEGIN UNTRUSTED: worker teslim özeti (iddialar — doğrulamadan kabul etme) ---
Worker iddiası: (1) nav okları ≥40px koyu zemin açık glif, iki tema kontrastlı,
yıl-ok satırı kaldırıldı (bulgu 4 dropdown'a gitti — sahip taslağı hükmü);
(2) ortak `<style id="tarih-secici-stil">` idempotent enjeksiyon, ≥900px'te
400px merkezli kart, <900px mevcut alt-sheet DOKUNULMAYAN, align-items
inline'dan çıkarıldı (media kuralı ezilmesin diye); (3) maske
`tarihMaskeUygula` + `tarihMaskeImlec` (kuyruk-ayraç korunur, silme doğal),
`tarihGirisCoz` (,/ / -/boşluk → .), segment taşması hane YUTMADAN işaretli,
inputmode=numeric, Enter=Uygula, geçerli giriş takvimi atlatıp seçer,
mm/dd YOK; üç yüzeye bağlı (bcTakvim SAF bcTakvimSecimEkle kapısından);
(4) ay+yıl dropdown, `tarihYilAraligi(min,max)` (yalnız-min→+120, yalnız-max→-120,
hiçbiri→bugun-120..bugun+10 BEYANLI; bcTakvim [başlangıç, başlangıç+30gün]);
(5) puntolar büyütüldü (input 1rem = iOS zoom eşiği, 40px hedefler).
Guard beyaz liste +5/−1; ?v=20260913-17 ×23 TEK (−16 kalıntı 0); unit
857/856/1 (red-before: 13 test impl öncesi kırmızıydı); Playwright 9/9
(1920×1080 400px + 412×915 alt-sheet + dropdown + maske) + regresyon 6/6.
Review: 1 ÖNEMLİ (caseGun açılış bayat hata metni) + 4 KÜÇÜK — düzeltildi/beyanlı.
--- END UNTRUSTED: worker teslim özeti ---

Maddeler (kod kanıtıyla):
1. Sahip bulguları 1-5 gerçekten üç yüzeyde de (tekTarihTakvimAc + bcTakvim* +
   caseGunModalRender) uygulandı mı, yoksa yalnız kanonikte mi?
2. Mobil korunumu: <900px davranışı gerçekten eski halinde mi (inline
   align-items çıkarımı doğru yerde mi); masaüstü 400px media kuralı çalışır mı?
3. Maske güvenliği: girişte caret/imeç korunumu; maskenin Uygula reddi ile
   veri güvenliği; mm/dd yolu AÇIK MI (tarihGirisCoz'da 4/8 haneli yıl-önce
   yorumu imkansız mı)?
4. Dropdown: yıl aralığı beyanındaki varsayılanlar makul mu; bcTakvim
   offset mantığı sayfalamayla çelişki kuruyor mu; selectOption hatalı yıl
   (1..9999 dışı) imkansız mı?
5. Guard: beyaz liste +5/−1 doğru adlar mı; eski muhafızlar (type="date",
   kopya sembol, saf katman, damga -17) gerçekten yeşil mi (testleri koştur);
   yeni stiller damga-bump ile AYNI commit'te mi?
6. Regresyon: bcTakvim çoklu-seçim + W13 fix + caseGun akışları davranış
   değişimi taşıyor mu (piksel-stili değişim dışında anlamsal değişim)?
7. Kapsam: manifest dışı dosya; F-scope dışı dokunuş; guard'ın kendi
   whitelist güncellemesinin dışında test zayıflatma var mı?

ÇIKIŞ BİÇİMİ (birebir):
Her bulgu için tek satır:
`[ŞIDDET: KRİTİK|ORTA|DÜŞÜK] dosya:satır — kusur — kanıt (kod alıntısı)`
Bulgu yoksa maddenin numarası + `TEMİZ` + tek satır kanıt.
Son satır: `SONUÇ: KABUL | REVİZYON` (KRİTİK → REVİZYON).

Raporu `.claude/reviews/2026-09-13-tarih-secici-r1-denetim.md` dosyasına
yaz ve bulunduğun dalda commit et; sonra turunu bitir.
