# DONE — test-GOREV (senaryo test kataloğu)

- **Sonuç: TAMAM**
- **Çıktı:** `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/docs/plans/2026-09-28-ovsync-takip-ekrani/test-senaryolari.md` (686 satır)
- **Tarih:** 2026-09-28 · Kural: ultracode koşulmadı, commit atılmadı, ürün kodu yazılmadı, DB'ye yazılmadı, PROD'a erişilmedi.

## Senaryo sayısı ve katman kırılımı

- **Toplam 73 senaryo (T-01..T-73)**, 15 alan grubu = zarfın 15 kapsam maddesinin tamamı.
- Katmanlar (kesişimli; bir senaryo birden çok katman taşıyabilir): **DB-SQL 52 · UI-Playwright 58 · İnsan-UI 9** + İNSAN-UI ayrı glmf-max listesi (12 madde, beklenen görünüm açık).
- Her senaryo: spec § + kabul # referansı · katman · ön koşul · adımlar · BEKLENEN (DB satırları ve ekran görünümü ayrı) · ters kanıt.
- Sonda: kabul 1–11 × senaryo izlenebilirlik tablosu.

## Kapsamın tamamı karşılandı (zarf maddesi → bölüm)

1 seçenek×giriş noktası matrisi (A) · 2 atomiklik (B) · 3 TAKIP→OVSYNC_BASLAT doğmaz (C) · 4 hard block 4 varyant (D) · 5 kapanış 3 olay + neden kaydı + çift olay (E) · 6 erteleme döngüsü (F) · 7 deneme sayacı 4 varyant (G) · 8 §4b tüm 8 satır + S0/S4/dalga (H) · 9 eşik-40 ayar kaynaklı (I) · 10 bayrak/offline×2/RPC hata/invalidate (J) · 11 gezinme §6b 5 madde (K) · 12 giriş hücresi + sayı tutarlılığı (L) · 13 güvenlik 3 madde (M) · 14 PROD kenar vakaları küpe 51/19/902/183/197/121 + A3/A5/A6/A9 replikaları demo-seed olarak (N) · 15 eşzamanlılık 2 madde (O).

## SPEC SORULARI — 10 madde (plan/sahip cevaplayacak, katalog uydurma cevap yazmadı)

S-1 kısır+kural-günü birleşik gerekçe önceliği · S-2 ertelemede saat düzenlenebilirliği · S-3 takip muayenesinde Gebe sonucu yolu · S-4 PG kapısında çift onay zinciri (PG_KAPI + TAKIP_ACIK) · S-5 bayrak kapalıyken §6c davranışı · S-6 "Bekleyen başlatma" KPA sayısına takip dahil mi · S-7 takip görevi erteleme tavanı · S-8 zaten-sonuçlanmış tohumlamaya ikinci çağrı hata sözleşmesi · S-9 "muayene vakti" alt sınırı (kalan_gun=0) · S-10 takip muayenesi Kaydet etiketi ("Boş ata + …" öneki bağlamdışı mı).

## Kapsam dışı bırakılanlar

- Kabul 2'nin "KPA sayıları PROD verisiyle nokta-doğrulama" yarısı — zarf PROD erişimini yasakladı (okuma yalnız demo); uygulama sonrası ayrı salt-okuma tur önerisi katalogda yazılı.
- FAZ 2 özellikleri, backlog B1–B8, performans/yük, tarayıcı matrisi, görsel regresyon.
- `gebelik_muayene_listele` yüzeyinin kendi senaryoları (yalnız eşik kesişimi T-45).

## Açık teknik notlar (katalogda işaretli)

- RPC/görev-tipi adları spec çalışma adlarıdır (`ovsync_takip_listele`, `tohumlama_bos_ve_devam`, `TAKIP_MUAYENE`); plan kesinleşince bul-değiştir — senaryo davranışları ad-bağımsız yazıldı.
- "2. deneme (bu laktasyon)" rozet metni mockup kaynaklı; nihai metin planla kesinleşecek (T-31'de notlu).
