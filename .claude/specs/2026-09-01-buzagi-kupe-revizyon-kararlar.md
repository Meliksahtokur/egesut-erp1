# Buzağı Küpe Revizyonu — KARAR SPEC'İ (kullanıcı onaylı, TÜM KARARLAR FİNAL)

> Tarih: 2026-09-01 (2. revizyon — tüm açık noktalar kapandı) · Worktree: `idle/buzagi-kupe-revizyon`
> Kaynak rapor: `.claude/plans/2026-09-01-buzagi-kupe-revizyon-arastirma.md`
> Implementasyon planı: `.claude/plans/2026-09-01-buzagi-kupe-revizyon-impl.md`
> Akış: implementasyon (subagent) → review → merge → kullanıcı canlı test → worktree kapanır.

## 1. Onaylı kararlar (FİNAL)

| # | Karar | Uygulama etkisi |
|---|-------|-----------------|
| K1 | **Recycle** — çıkmış hayvanın işletme küpesi çıkıştan hemen sonra yeniden kullanılabilir (unique id zaten her hayvanı bağlar; loglar id ile bağlı) | `kupe_musait_mi` + `dogum_kaydet` işletme küpesi kontrolüne `durum='Aktif'` filtresi |
| K2 | **Devlet (TR) küpesi kontrolü GLOBAL kalır** (TURKVET: hayvana ömür boyu) | `devlet_kupe` sorgularına dokunma |
| K3 | **DB savunma katmanı** — aktifler üzerine partial unique index; h11 `p_padok_id` overload'larına kontrol; `hayvan_guncelle` kontrolü | Index string-bazlı (`"002"≠"02"`) → sıfır-trick doğal korunur |
| K4 | **4 haneli RED** — 3 haneli devam | 1000+ bloğu yok |
| K5 | **Erkek yeni doğanlar: 500-599 zorunlu** (sayısal küpeler için). Doğum formunda SERT engel; manuel hayvan eklemede UYARI + 5xx önerisi (engel değil). Sunucu tarafında `dogum_kaydet` zorlar | Erkek + sayısal küpe + 500-599 dışı → red (doğum) / uyarı (manuel) |
| K6 | **"Boş küpeler" öneri özelliği** — doğum formu (`b-kupe`) + hayvan ekle formu (`a-kupe`) yanında buton; tıklayınca boş numaralar listelenir, tıkla-doldur | Havuz K10/K11'e göre; çıkmış hayvanların numaraları havuzda (K1) |
| K7 | **Aktif-öncelik küpe arama** — aynı numara geçmişte çıkmışta + bugün aktifte varsa aktif bulunur | `openDetByKupe`, detay resolver, 7 form resolver'ı, `asistan_hayvan_detay` |
| K8 | **Test hayvanları KALIR** | Migration test kaydına dokunmaz |
| K9 | **002/02 sıfır-trick KORUNUR** — normalizasyon YOK | String karşılaştırmalar aynen; öneri hesabı SAYISAL uzayda yapar ("02" ve "002" aynı 2'yi işgal eder sayılır) |
| K10 | **Dişi buzağılar: 500-599 hariç 1-999 içinde her numara serbest.** Öneri listesi KÜÇÜKTEN BÜYÜĞE — en küçük boş numara ilk sırada (var olan sıra disiplini teşvik edilir) | `bosKupeOner` dişi havuzu = 1..999 \ 500..599, ascending |
| K11 | **Erkekler yalnızca kendi havuzundan (500-599) öneri alır** | `bosKupeOner` erkek havuzu = 500..599 |
| K12 | **Mevcut erkeklere müdahale YOK** — kural sadece yeni kayıtlar; mevcutlar sürüden çıkınca numaraları otomatik havuza döner | Geriye dönük renumarasyon/data migration YASAK |

## 2. Uygulama paketi sırası

1. **Migration** `supabase/migrations/20260901000002_kupe_revizyon.sql` (tek transaction): `kupe_musait_mi` aktif-filtre + `kupe_gecmis_id/durum` dönüş alanları · `dogum_kaydet` kontrol ayrımı (işletme=aktif, devlet=global) + erkek 5xx sunucu kuralı · partial unique index `hayvanlar_kupe_no_key` · h11 `hayvan_ekle`/`hayvan_guncelle` overload'larına `kupe_musait_mi` çağrısı · `asistan_hayvan_detay` aktif-öncelik ORDER BY · `NOTIFY pgrst`. Deploy öncesi aktif-küpe dublikasyon taraması (beklenen: 0).
2. **JS doğrulama:** `_kupeKontrolEt` üç durumlu (aktif çakışma=engel / geçmiş kullanım=bilgi / temiz) + `b-kupe` blur ön kontrolü; `submitBirth` erkek sert engel; `submitAnimal` erkek uyarısı.
3. **JS öneri:** `js/config.js` sabitler + saf hesap fonksiyonları (`bosKupeOner`, `erkekKupeUygunMu`); formlarda "Boş küpeler" butonu (HTML attribute onclick — modal router kuralı).
4. **JS aktif-öncelik sweep (K7).**
5. **Dokümantasyon:** `.claude/domain-rules.md` numara planı; `.claude/rpc-reference.md` güncellenmiş imzalar.
6. **Testler:** unit (öneri hesabı, erkek kuralı, kontrol mesajları) + mevcut 302 test yeşil; E2E stub imkân dahilinde.

## 3. Kabul kriterleri

- Ölen/satılan hayvanın küpesiyle yeni kayıt (doğum + manuel) açılır.
- İki **aktif** hayvana aynı string küpe verilemez (index + RPC); devlet küpesi çıkmışda dahi çakışırsa red.
- Erkek yeni doğum kaydında sayısal küpe 500-599 dışı → red (JS + RPC çift katman).
- Öneri: erkek → yalnız 500-599; dişi → 1-999 (5xx hariç), her ikisi de küçükten büyüğe; aktiflerin elindeki numaralar (sayısal uzayda, sıfır-trick dahil) havuzda YOK; çıkmışların numaraları havuzda VAR.
- Aynı küpe string'i geçmişte varsa arama/detay/asistan **aktif** hayvanı bulur.
- Test kayıtlarına ve `002`/`02` stringlerine dokunulmaz; mevcut erkekler aynen kalır.
- 302+ unit test yeşil; `detect_changes` commit öncesi temiz; migration **yalnızca kullanıcı onayıyla** canlıya gider (merge sonrası, canlı test öncesi).
