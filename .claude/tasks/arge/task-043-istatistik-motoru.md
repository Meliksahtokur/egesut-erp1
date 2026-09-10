# Task #43 — İstatistik Motoru

**Durum:** Bekliyor
**Öncelik:** Yüksek (portföy hedefi)
**Bağımlılık:** task-037 (MVP stat kartı ✅), sürü stat kartı taşıma (devam ediyor)

---

## Vizyon

Kapsamlı istatistik hesaplama motoru — sadece gebelik değil, tüm sürü metrikleri:

### Gebelik & Üreme
- Yaş × ırk × gebelik oranı (ör: 24 aylıktan büyük Montafon ineklerin gebelik oranı)
- Laktasyondaki inekler kaçıncı tohumlamada gebe kaldı
- Sperma bazlı gebelik istatistikleri ve karşılaştırma
- Düve vs inek başarı oranları

### Hastalık & Tedavi
- Hastalık iyileşme oranları
- Hangi hastalıkta hangi antibiyotiğe daha hızlı cevap alınmış
- Sürüdeki laminit oranı, mastitis oranları
- Tedavi süresi analizi

### Sürü Sağlığı
- Kısırlık oranları (yaş/ırk kırılımı)
- Abort oranları ve korelasyonları
- Hastalık × üreme korelasyonu

### Cross-Analiz
- Yaş × ırk × gebelik
- Hastalık × üreme performansı
- Padok × sağlık metrikleri

---

## Teknik Prensipler

- **Tüm hesaplamalar PostgreSQL'de** — UI'da asla hesaplama yapılmaz
- Multi-RPC mimari denenecek (tek RPC sorun yaratırsa)
- Dedicated istatistik sekmesi (faz 2+)
- Dönem karşılaştırma (bu yıl vs geçen yıl)

---

## Fazlar

1. **Sürü stat kartı** — demografik + gebelik (task-037 devamı, şimdi yapılıyor)
2. **Hastalık istatistikleri** — iyileşme oranı, antibiyotik etkinliği
3. **Cross-analiz** — yaş × ırk × gebelik, hastalık × üreme
4. **Dedicated istatistik sekmesi** — tüm metriklerin bir arada olduğu ekran
5. **Dönem karşılaştırma** — zaman dilimi analizi

---

## Notlar

- Bu portföy için kritik — "standart yazılımla kaliteli yazılımı ayıran şeyler bunlar"
- Remote job başvurularında gösterilecek
- Detaylı spec: `docs/superpowers/specs/2026-05-30-suru-stat-karti-design.md`
- Orijinal fikir analizi: `.claude/ideas/alfa-istatistik.md`
