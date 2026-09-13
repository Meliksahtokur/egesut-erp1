# DENETİM — F3 teslimi (goal G-20260913-TARIH-SECICI)

Sen bağımsız bir deneticisin. TEK TUR. Hiçbir şeyi düzeltmezsin; bulgu
raporlarsın. Yazar özetlerine güvenme — gerçek diff ve gerçek testler
üstünden çalış.

Çalışma alanı: bu koltuğun çalışma dizini (dalda paket mevcut).
Denetim konusu: `git diff agent/tarih-secici-standardi...agent/tarih-secici-standardi-W3`
(dosyalar: index.html, js/forms.js, js/ui.js, js/utils/handlers.js,
tests/unit/tarih-saf.test.js, tests/unit/vaka-toplu-ac.test.js +
rapor). Tam dosyalar: `git show agent/tarih-secici-standardi-W3:<yol>`.

--- BEGIN UNTRUSTED: worker teslim özeti (iddialar — doğrulamadan kabul etme) ---
Worker iddiası: bcTarihTakvim* tamamen kaldırıldı (grep boş), tek prod
çağıran handlers.js:228 bcTarihSeciciAc'a repoint edildi (tek satır);
bcTakvim* ve caseGunModalRender ortak tarihAyIzgara çekirdeğinde; çoklu
seçim + W13 fix korunmuş (impact CRITICAL görülen bcTakvimAyGosterim dönüş
sözleşmesi birebir korunarak); grid sözleşmesi değişmedi (ay-dışı=null);
kapaliGun plumbing F2 carry-over'ı testle kapatmış (+7 DOM test, 35/35);
?v= 20260913-16 TEK değer 23/23; unit 831/830/1 (aynı bilinen date-bomb);
6 DÜŞÜK review bulgusu (3 giderildi 3 beyanlı); 3 davranış delta'sı beyanlı
(açılış ayı değerin ayı; aralık-dışı tık sessiz; Onayla min/max yeniden
doğrulaması); 1900-2100 ampirik grid doğrulaması 0 sapma (eski kod 1-3
yıl arası YANLIŞTI).
--- END UNTRUSTED: worker teslim özeti ---

Maddeler (her biri için kod kanıtı):
1. Kaldırma bütünlüğü: `grep -rn "bcTarihTakvim" index.html js/ tests/` boş
   mu; `bcTarihSecimEkle` prod-öksüzü beyanı doğru mu (yalnız test mi
   çağırıyor)?
2. W13 fix: `bcTakvimAyGosterim`/`bcTakvimdenGunler` akışındaki ay-geçiş
   düzeltmesi F3 sonrası da ay gösterimini aynı hesaplıyor mu (eski/new
   diff'e bak); 8 pini kırıldı mı?
3. caseGunModalRender: grid artık tarihAyIzgara'dan mı; seçim Set davranışı
   değişmemiş mi (ay-İÇI Set beyanı)?
4. handlers.js repoint: tek satır mı gerçekten; rota anahtarı değişmemiş mi
   (index.html:1185 data-action); W21 testi aynı mı?
5. Davranış delta'ları: 3 beyanlı delta gerçekten zarar taşımıyor mu (eski
   davranışla karşılaştır — özellikle Onayla yeniden doğrulaması veri
   kaybı yolu açıyor mu)?
6. ?v= bütünlüğü: 23/23 tek değer mi; damga muhafız testleri -16 güncel mi?
7. Test kalitesi: +7 DOM test gerçek davranışı kilitliyor mu (self-serving
   değil); göreli-tarih hijyeni (bugün+13) gerçekten sabit-pin tuzaklarını
   önledi mi?
8. XSS: yeni/ortak render'da ham interpolasyon var mı?
9. Kapsam: F4 işine sızma var mı (guard testi, karar kaydı, ui-map)?

ÇIKIŞ BİÇİMİ (birebir — bulgular bu biçimle toplanıyor):
Her bulgu için tek satır:
`[ŞIDDET: KRİTİK|ORTA|DÜŞÜK] dosya:satır — kusur — kanıt (kod alıntısı)`
Bulgu yoksa maddenin numarası + `TEMİZ` + tek satır kanıt.
Son satır: `SONUÇ: KABUL | REVİZYON` (KRİTİK → REVİZYON).

Raporu `.claude/reviews/2026-09-13-tarih-secici-f3-denetim.md` dosyasına
yaz ve bulunduğun dalda commit et; sonra turunu bitir.
