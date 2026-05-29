# Task 043 — Stok İade Görünürlüğü [FOR OPUS]

**Durum:** Açık  
**Öncelik:** Orta  
**Etiket:** stok, tedavi, ux

## Sorun

Kullanıcı bir tedavi gününü tamamlarken ilaç(ları) ❌ uygulanmadı işaretlediğinde, `treatment_day_tamamla` RPC `stok_hareket.iptal=true` yapar (mevcut kullanım kaydını iptal eder). Bu mekanizma DB'de doğru çalışıyor (test edildi).

Ancak kullanıcı Stok sayfasında hareketlere baktığında:
- **Görmediği şey**: "+1 iade" veya geri dönüş satırı
- **Olan şey**: `iptal=true` olan satır `m=>!m.iptal` filtresinden geçmediği için tamamen gizleniyor
- `guncel_stok` VIEW'dan yeniden hesaplanıyor ve artması gerekiyor, ama kullanıcı bunu fark etmiyor

## Beklenti

Kullanıcı, iade işleminin gerçekleştiğini görsel olarak teyit etmek istiyor. Muhtemelen beklentisi:
- Stok hareket listesinde "↩ İade" satırı görmek (yeni pozitif kayıt)
- VEYA iptal edilen satırın "iptal edildi" görsel göstergesiyle listede kalması

## Tasarım Kararı Gerektiriyor

İki seçenek:

### Seçenek A: iptal kaydını görünür yap
- `stok_hareket` listesinde `m.iptal === true` olanları da göster, farklı stil ver (strikethrough, gri, "❌ İptal")
- Pro: Ledger'da audit trail tam görünür
- Con: Listeyi karmaşıklaştırabilir

### Seçenek B: Yeni pozitif "iade" kaydı ekle
- `treatment_day_tamamla` RPC'de `stok_hareket.iptal=true` yerine (veya ek olarak) yeni bir `miktar = -original_miktar` (negatif) veya `tur='İade'` kaydı ekle
- Pro: Kullanıcı açısından daha anlaşılır
- Con: Ledger tasarımını değiştirir, `geri_al` ve diğer iptal mekanizmalarıyla tutarsız olur

### Seçenek C: Sadece `guncel_stok` değişimini toast'ta belirt
- Tedavi tamamlandığında toast'ta "✅ Tamamlandı — 2 ilaç iade edildi (+2 stok)" gibi görünür bilgi ver
- Pro: Minimal değişiklik
- Con: Kalıcı görsel teyit yok

## Mevcut Durum

- `treatment_day_tamamla`: `UPDATE stok_hareket SET iptal=true WHERE notlar='drug_admin:UUID' AND iptal=false`
- `guncel_stok` VIEW: `baslangic_miktar - SUM(miktar) FILTER (WHERE NOT iptal)`
- Stok hareket listesi: `getData('stok_hareket', m=>!m.iptal)` — iptal olanları gizler
- Toast zaten "N ilaç iade edildi" diyor ama stok sayısını içermiyor

## Öneri

Seçenek A + C kombinasyonu: iptal satırları listede "❌ İptal" olarak göster, toast'ta da stok miktarını belirt.

## Etkilenen Dosyalar

- `js/ui.js` — stok hareket listesi (`openStokDetay` civarı, ~satır 2104, 2238-2252)
- `js/ui.js` — `_tedaviGunExecute` toast (~satır 2625-2628)
- `supabase/migrations/` — RPC değişikliği gerekirse
