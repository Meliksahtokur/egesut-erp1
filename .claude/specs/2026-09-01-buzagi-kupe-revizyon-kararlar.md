# Buzağı Küpe Revizyonu — KARAR SPEC'İ (kullanıcı onaylı)

> Tarih: 2026-09-01 · Worktree: `idle/buzagi-kupe-revizyon`
> Kaynak rapor: `.claude/plans/2026-09-01-buzagi-kupe-revizyon-arastirma.md`
> Durum: **Onaylı kararlar §1 · §2'deki 3 açık nokta kullanıcı cevabı bekliyor.** Uygulama başlamadı; migration deploy için ayrıca kullanıcı emri gerekir.

## 1. Onaylı kararlar

| # | Karar | Uygulama etkisi |
|---|-------|-----------------|
| K1 | **Recycle paketi ONAY** — çıkmış hayvanın işletme küpesi çıkıştan hemen sonra yeniden kullanılabilir. Zemin: her hayvanın DB'de unique id'si var; tüm log tabloları (tohumlama, dogum, gorev_log, islem_log, uygulama_log) hayvanı **id** ile bağlar, küpe reuse geçmişi bozmaz | `kupe_musait_mi` (GT:2114) ve `dogum_kaydet` inline kontrolüne (GT:~9767) işletme küpesi için `durum='Aktif'` filtresi |
| K2 | **Devlet (TR) küpesi kontrolü GLOBAL kalır** | `devlet_kupe` sorgularında değişiklik yok (TURKVET: numara hayvana ömür boyu) |
| K3 | **DB savunma katmanı** — aktifler üzerinde partial unique index; h11 `p_padok_id` overload'larına (`20260706000006`) küpe kontrolü ekle; `hayvan_guncelle` (GT:7174) sunucu kontrolü ekle | Index string-bazlı: `"002" ≠ "02"` → sıfır-trick kimlikleri doğal korunur |
| K4 | **4 haneli numaralandırma RED** — 3 haneli devam | 1000+ bloğu yok |
| K5 | **Erkek buzağılar (yeni doğan): 500-599 ZORUNLU** + doğum ve kayıt formlarında küpe önerisi bu aralıktan | Doğum formunda cinsiyet=Erkek → 500-599 dışı sayısal küpe reddi; 500-599 canlıda tamamen boş (doğrulandı) |
| K6 | **"Boş küpeleri göster" özelliği YAPILACAK** — yazarken/kayıt açarken pratik liste, tıklayınca doldurma | Doğum formu (b-kupe) + hayvan ekle formu (a-kupe); havuz cinsiyete göre; çıkmış hayvanların numaraları havuza dahil (K1) |
| K7 | **Aktif-öncelik küpe arama** (K1'in zorunlu tamamlayıcısı) — aynı numara geçmişte bir çıkmışta, bugün bir aktifte varsa aktif bulunur | `js/ui.js:2451` `openDetByKupe`, `js/ui.js:2046`, `js/forms.js:169/286/427/550/974/1010/1077`, `asistan_hayvan_detay` (GT:518) `ORDER BY (durum='Aktif') DESC` |
| K8 | **Test hayvanları KALIR** — silme/temizlik yok | Hiçbir migration test kaydına dokunmaz |
| K9 | **002/02 sıfır-normalizasyonu YAPILMAYACAK** — "002-2-02-022" trick'i bilinçli özellik: 1-999 aralığında ek kimlik alanı | Küpe string karşılaştırmaları aynen kalır; hiçbir normalizasyon/trim-politikası girilmez |

## 2. Açık noktalar (karar bekliyor — öneriler hazır)

| # | Soru | Öneri |
|---|------|-------|
| A1 | **Dişi buzağılar hangi havuzdan numara alacak?** (Erkeklere 5xx tanımlandı; dişiler belirtilmedi) | **A (önerim):** 0-99'daki boşlar + recycle edilenler (~35 slot, ~1 yıl) → dolunca 300-399'e geçiş. Küçük numara alışkanlığı korunur, israf yok. **B:** Dişi yeni kayıtlar direkt 300-399'e; 0-99 mevcut aktiflere kalır ve kapanır. Daha temiz yönetim ama alışkanlık kopar |
| A2 | **Erkek 5xx zorunluluğu yalnızca doğum formunda SERT mi, manuel hayvan eklemede de mi?** ("yeni doğan" dendi; satın alınan erkek mevcut küpesiyle girme ihtimali var) | Doğum formunda **sert engel**; manuel hayvan eklemede **uyarı + 5xx önerisi** (engel değil) |
| A3 | **Mevcut ~20 aktif erkek (0-99 ve 200'lerde: 39, 43, 44, 47, 53, 54, 59, 60, 64, 65, 67, 71, 73, 76, 80, 81, 83, 84, 86, 89, 91, 92, 94, 95, 96, 98...) dokunulmaz mı?** | **Evet, dokunulmaz** — kural yalnızca yeni kayıtlar; geriye dönük renumarasyon yok |

## 3. Uygulama paketi (sıra)

1. **Migration (tek dosya, tek transaction):** `kupe_musait_mi` aktif-filtre + `gecmis_kupe_cakisma_id` dönüş alanı · `dogum_kaydet` inline kontrol ayrımı (işletme=aktif, devlet=global) · `CREATE UNIQUE INDEX hayvanlar_kupe_no_key ON hayvanlar(kupe_no) WHERE durum='Aktif' AND kupe_no IS NOT NULL AND kupe_no<>''` · h11 overload'larına kontrol · `hayvan_guncelle` kontrolü · erkek 500-599 doğum zorunluluğu (sunucu tarafı). Deploy öncesi: aktif-küpe dublikasyon taraması (beklenen: 0; `002/02` string farklı olduğundan index'i etkilemez).
2. **JS — doğrulama ve mesajlar:** `_kupeKontrolEt` iki durumlu uyarı ("⚠️ aktif hayvanda var" = engel / "ℹ️ geçmişte kullanılmış" = bilgi); doğum formu buzağı küpesine blur ön kontrolü + erkek cinsiyetinde 5xx zorunluluğu.
3. **JS — öneri/boş küpe özelliği (K5+K6):** küpe girişinin yanında "Boş küpeler" düğmesi → cinsiyete göre havuzdan ilk ~10 boş numara; tıkla-doldur. Havuz = aktif olmayanların elinde olmayan numaralar (çıkmışlarinki dahil — K1). Erkek havuzu 500-599; dişi havuzu A1 kararına göre.
4. **JS — aktif-öncelik sweep (K7).**
5. **Dokümantasyon:** numara planı `.claude/domain-rules.md`'ye (bloklar: dişi=?, erkek=500-599, 0-999 trick notu, recycle kuralı).
6. **Testler:** unit (kontrol fonksiyonları, havuz hesabı) + E2E kilidi: "ölen hayvanın küpesiyle buzağı kaydı açılır + erkek doğumda 5xx dışı red + öneri 5xx'ten gelir".

## 4. Kabul kriterleri

- Ölen/satılan hayvanın küpe numarasıyla yeni kayıt (doğum + manuel) başarıyla açılır.
- İki **aktif** hayvana aynı string küpe verilemez (index + RPC).
- Devlet küpesi, çıkmış hayvanlarda dahi çakışırsa reddedilir.
- Erkek yeni doğum kaydında 500-599 dışı sayısal küpe reddedilir; öneriler 5xx'ten gelir (A2 kararına göre manuel eklemede uyarı).
- Boş küpe listesi doğru havuzdan gelir; çıkmış hayvan numaralarını içerir; aktifinkini içermez.
- Aynı küpe string'i geçmişte varsa arama/detay/asistan **aktif** hayvanı bulur.
- Test kayıtlarına ve `002`/`02` gibi stringlere dokunulmaz.
- Mevcut 302 unit test + yeni testler yeşil; commit öncesi `detect_changes` temiz; migration yalnızca kullanıcı deploy emriyle canlıya gider.
