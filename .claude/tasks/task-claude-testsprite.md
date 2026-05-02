# Task-Claude-TestSprite: TestSprite MCP Entegrasyonu

**Durum:** done
**resolved_date:** 2026-05-02
**resolution_note:** Stale — PRoot limitation still exists, Playwright cannot run in this environment. TestSprite integration incomplete. The use case (automated browser testing in cloud) is not actionable in current environment. This task is closed as not applicable.

**Durum:** bekliyor
**Tarih:** 2026-04-04
**Branch:** fix/tech-debt (veya feature/testsprite-setup)
**Atanan:** Claude (orkestratör)
**Öncelik:** Orta

---

## Problem

Tablet ortamında Playwright çalıştırılamıyor (PRoot/Android kısıtlaması).
TestSprite, AI ile test üretip cloud'da koşan bir alternatif.
MCP server eklendi — şimdi entegre edilmesi gerekiyor.

**MCP durumu:** ✅ Eklendi (`claude mcp add TestSprite ...` — 2026-04-04)
**API Key:** `.claude/CREDENTIALS.md`'de saklanacak (MCP env var olarak set edildi)

---

## Yapılacaklar

### Adım 1 — TestSprite MCP Tool'larını Keşfet

Yeni oturumda TestSprite MCP bağlıyken:
```
Hangi tool'lar mevcut? (generateCodeAndExecute, vs.)
Her tool ne parametre alıyor?
```

### Adım 2 — Proje URL'ini Ayarla

GitHub Pages URL: `https://meliksahtokur.github.io/egesut-erp1/`

TestSprite'ın bu URL'e erişmesi için sayfanın canlıda olması gerekiyor.

### Adım 3 — İlk Smoke Test

EgeSüt ERP'nin en kritik flow'u için test üret:

**Hedef flow: Hayvan Kaydı**
1. Uygulamayı aç
2. "Hayvan Ekle" formuna git
3. Küpe no, tür, cinsiyet, doğum tarihi gir
4. Kaydet → başarı toastı görünmeli
5. Hayvan listesinde görünmeli

TestSprite MCP ile bu flow'u test et:
```
generateCodeAndExecute({
  url: "https://meliksahtokur.github.io/egesut-erp1/",
  testDescription: "Hayvan kayıt flow'u — küpe ekle, listede görün"
})
```

### Adım 4 — Tohumlama Flow Testi

**Hedef flow: Tohumlama Kaydı**
1. Mevcut dişi hayvanı seç (yaş ≥ 12 ay)
2. Tohumlama formunu aç
3. Tarih, boğa bilgisi gir
4. Kaydet → "Tohumlandı" durumu

### Adım 5 — Hata Senaryoları

- Küpe no duplicate → hata toastı
- Tohumlama tarihi ileri gün → validasyon hatası
- Erkek hayvana tohumlama → engellenmeli

### Adım 6 — Sonuçları Raporla

Test sonuçlarını oku, hata varsa:
- UI bug → `.claude/knowledge/bugs.md`'ye ekle
- RPC bug → M2.5'e task yaz

---

## Kabul Kriterleri

- [ ] TestSprite MCP tool'ları keşfedildi ve dokümante edildi
- [ ] En az 1 başarılı smoke test çalıştırıldı
- [ ] Test sonuçları okunabilir durumda (screenshot veya rapor)
- [ ] Varsa yeni bug'lar bugs.md'ye eklendi
- [ ] TestSprite workflow dokümante edildi (`.claude/TESTSPRITE_GUIDE.md`)

---

## Kritik Notlar

- TestSprite cloud'da koşuyor — internet gerekli
- GitHub Pages'in güncel olması gerekiyor (push sonrası ~1 dk bekle)
- API Key: MCP config'de `API_KEY` env var olarak set
- Tablet'te browser açmadan test çalışıyor — asıl avantaj bu

---

## Bağlam

**Neden TestSprite?**
- Playwright tablet'te çalışmıyor (PRoot kısıtlaması)
- Manuel test: kullanıcı test ediyor, Claude ui_logs'u okuyor — ama yavaş
- TestSprite: tam otomasyon, Claude'un isteği üzerine test başlatır

**ui_logs alternatifi (hâlâ aktif):**
```bash
# Son hatalar
curl -s "https://zqnexqbdfvbhlxzelzju.supabase.co/rest/v1/ui_logs?select=level,message,source,created_at&order=created_at.desc&limit=20" \
  -H "apikey: ANON_KEY"
```
TestSprite ile birlikte kullanılabilir.

---

## Tamamlandığında

`task-claude-testsprite-done.md` yaz:
- Hangi tool'lar mevcut
- Hangi test'ler çalıştı
- Sonuçlar ve bulunan bug'lar
- Workflow önerisi (ileride nasıl kullanılmalı)
