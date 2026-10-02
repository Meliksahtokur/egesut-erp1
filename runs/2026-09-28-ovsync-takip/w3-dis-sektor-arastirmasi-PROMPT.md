# W3 — Dış sektör araştırması: süt çiftliği senkronizasyon (Ovsync) takip sistemleri

> Bu dosya SAHİBİN kendisinin koşuturacağı harici araştırma promptudur (ana oturum dışında
> yapıştırıp kullan). Ana oturum bunu koşmaz.

## Bağlam

EgeSüt ERP, bir süt işletmesinin (sağmal dane) sürü yönetimi için vanilla JS + Supabase/PostgreSQL tabanlı bir uygulamadır. Üreme yönetiminde Ovsync/Presynch benzeri hormon protokolleri (zincir şeklinde gün-gün uygulama planları: GnRH, PG+48 saat vb.) hayvan bazında VAKALAR olarak izlenir; her vaka bir protokol zincirinden adımlarını gün gün alır ve bir şekilde sonlanır (gebe / boş / çıkış / kesinti). Dashboard'da "ileri gebeler", "sessiz hayvanlar" gibi BASİT tablolar mevcut; protokol takibi için TEK EKRANDAN bir izleme sistemi tasarlanıyor: hangi hayvan hangi adımda, beklenen uygulama tarihi geçti mi, protokol sonlandı mı, nasıl sonlandı.

## Görev

Süt çiftliği yazılımlarında (BoviSync, DairyComp 305, PCDart, Uniform-Agri, Afimilk, Bovi-Trackr vb. ve modern web tabanlı araçlar) senkronizasyon/protokol takibi nasıl yapılıyor — araştır ve şu soruları cevapla:

1. **Ekran desenleri:** liste/tablo, zaman çizelgesi, kanban, takvim, hayvan×gün matrisi — hangi desen ne için kullanılıyor?
2. **Durum modeli:** bir protokol vakası yazılımda nasıl temsil ediliyor — adımlar, bekleyen/geçmiş uygulama, sonlanma türleri (gebe/boş/çıkış/kesinti)?
3. **Uyarı/öncelik mantığı:** geciken uygulama, kaçırılan adım, "bugün yapılacaklar" listesi nasıl kurgulanıyor?
4. **Toplu işlem:** bugünün listesinden çoklu kayıt/hızlı veri girişi desenleri neler?
5. **KPI'lar:** senkronizasyon başarı oranı, protokol tamamlanma oranı, 21./42. gün gebelik oranı gibi metrikler nasıl sunuluyor?

## Çıktı biçimi

- Madde madde bulgular; her bulgunun yanında kaynak URL.
- Sonda: "EgeSüt için uygulanabilir 5-10 fikir" listesi — mevcut basit dashboard tablolarından farkını açıkça vurgulayarak.
- Yorumları veriden ayır; bir iddia kaynaksız kalmasın.
