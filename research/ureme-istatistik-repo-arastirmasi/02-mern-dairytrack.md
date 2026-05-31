# MERN-dairy + dairyTrack — Frontend Mimari Analizi

**Kaynaklar:**
- https://github.com/Arnav-Negi/MERN-dairy-farm-management
- https://github.com/T0MM11Y/development-of-dairyTrack-platform
- Web aramaları

---

## MERN-dairy-farm-management

**Stack:** MongoDB, Express, React, Node.js, Material-UI (MUI)
**Kullanıcı tipleri:** Customer (müşteri) ve Vendor (satıcı/çiftçi)
**Amaç:** SaaS süt çiftliği yönetim prototipi

### Dashboard Structure

Repo basit bir prototip olduğu için karmaşık repro analitiği içermiyor. Ancak mimari olarak:
- **Card-bazlı dashboard:** Özet metrikler kartlarda gösteriliyor
- **Hayvan kartı:** Her hayvan için detail sayfası
- **State yönetimi:** React Context veya Redux (MERN stack'te yaygın)
- **Material-UI:** Hazır tablo, kart, form bileşenleri

### API Integration
- Express.js backend → MongoDB
- REST API endpoint'leri: `/api/animals`, `/api/breeding`, vb.
- Frontend axios/fetch ile API çağrıları

### Takeaways for Our Project
- Bizim vanilla JS yaklaşımımız daha hafif ama MUI benzeri bir UI kütüphanesi kullanılabilirdi
- State yönetiminde `js/state.js` AppState pattern'imiz React Context'e benzer
- Kart-bazlı dashboard bizim de kullandığımız bir pattern

---

## dairyTrack Platform

**Stack:** Django, Node.js, React
**Odak:** Sürü sağlığı, süt üretimi, satış takibi

### Dashboard Structure
- **Aktivite/Aksiyon bazlı izleme:** Sürü verileri "yapılacak iş" olarak gruplanıyor
- **Entegre dashboard:** Süt üretimi + üreme + sağlık aynı ekranda
- **Timeline görünümü:** Hayvan olayları zaman çizelgesinde

### Key Features
- Sürü verilerini aksiyon bazlı gruplama → bizim görev sistemi benzer
- Çok modüllü yapı (süt + üreme + stok)

### Takeaways for Our Project
- "Aktivite bazlı izleme" fikri: Dashboard'da "bugün yapılacaklar" + "geciken işler" kartları
- Bizim görev modülümüz bu pattern'i zaten uyguluyor
- Timeline görünümü → hayvan detay sayfasında olay kronolojisi olarak eklenebilir

---

## Her İki Repodan Ortak Pattern'ler

| Pattern | Bizim Durum |
|---------|------------|
| Card-bazlı dashboard | ✅ Mevcut |
| Hayvan detay sayfası | ✅ Mevcut |
| Aktivite/görev listesi | ✅ Mevcut |
| Zaman çizelgesi (timeline) | ❌ Eksik — eklenebilir |
| Chart/grafik (repro trend) | ❌ Eksik — `stat_suru_ozet` bunu besleyebilir |
| Offline-first | ✅ Mevcut (IndexedDB) |
