# 📋 Ertelenen Özellikler ve Teknik Borçlar

**Tarih:** 2026-03-30
**Son Güncelleme:** 2026-09-02 — 3. tur revize (REV-1..5) artıkları eklendi (aşağıda son bölüm).

---

## ✅ TAMAMLANMIŞ (Son 30 Gün)

### Tohumlama Modülü RPC Refaktöring — %70 Tamamlandı

**Tamamlanan İşler:**
- ✅ `tohumlama_kaydet` RPC — Event stack + islem_log + geri al desteği (migration 030)
- ✅ `tohumlama_sonuc_gebe` RPC — Yeni kayıt (migration 030)
- ✅ `tohSonucGuncelle` kaldırıldı — Korumasız write path temizlendi
- ✅ `tohSonuc` tek versiyon — ui.js'deki çakışan fonksiyon silindi
- ✅ Geri al butonu — `ref_id` fix (migration 028)
- ✅ Tohumlama modal durum bazlı buton kontrolü
- ✅ Input validation — İleri tarih engeli (forms.js:40,113,155)

**Kalan İşler:**
- 🔴 `tohumlama_sonuc_bos` RPC — `tohSonuc()` hala REST PATCH kullanıyor (forms.js:656)
- 🔴 `tohumlama_abort` RPC — Gebe → Abort için

**Öncelik:** Yüksek — 1 write path kalacak, tüm tohumlama işlemleri RPC üzerinden

---

### SonarCloud Remediation — S2 & S3 Tamamlandı

**Tamamlanan Sprint'ler:**
- ✅ S1 — Gerçek Bug'lar (10 issue) — f8874a0
- ✅ S2 — BLOCKER Globals (28 issue) — 14cda49
- ✅ S3 — Mantık Tutarsızlıkları (~35 issue) — b572e26
- ✅ S4 — Cognitive Complexity + Nested Ternary (~75 issue) — 0f2f0e2
- ✅ S5 — Minor Modernizasyon (Bulk, ~100 issue) — 55e8212

**Kalan:**
- 🟡 WONTFIX katalog (~188 issue) — SonarCloud UI'da manuel işaretleme gerekli
  - Label accessibility (S6853): 64 issue
  - Non-native element (S6848): 24 issue
  - Mouse event (S7726): 24 issue
  - SQL literal duplication: 72 issue
  - Diğer: 4 issue

**Tahmini:** 30-45 dk (manuel)

---

## 🔴 Yüksek Öncelikli (Gelecek Sprint)

### LOGIC-003: Offline Modda Tedavi Günleri Görünmüyor

**Sorun:**  
Offline modda eklenen tedavi günleri ve ilaç uygulamaları, online moda geçilene kadar UI'da görünmüyor.

**Kök Sebep:**  
- `renderCaseTimeline()` fonksiyonu `tedavi` ve `drug_administrations` tablolarını IndexedDB'den okuyor
- Ancak offline modda `write()` ile eklenen kayıtlar timeline render'ından önce cache'e yansımıyor
- Mevcut mimari: RPC → pullTables → render (online-first)
- Offline-first mimari için: write → local cache update → render → background sync

**Çözüm Yaklaşımı:**  
1. `caseDrugKaydet()` fonksiyonunda offline modda:
   - `drug_administrations` tablosuna write() ile ekle
   - `_drugAdminCache` adında local cache oluştur
   - Render fonksiyonunu cache'den besle
2. `renderCaseTimeline()` fonksiyonunu refactor et:
   - Önce IDB'den oku
   - Sonra pending offline kayıtları merge et
   - Birleştirilmiş liste ile render yap

**Tahmini Efor:** 4-6 saat  
**Risk:** Orta (timeline render karmaşık, regression test gerekli)  
**Bağımlılıklar:**  
- `drug_administrations` tablosu IndexedDB'de tam destekli değil
- `renderCaseTimeline()` fonksiyonu yüksek kompleksite (S3776)

**Not:** Bu özellik şu anki sprint kapsamı dışında. Klinik modülü stabil çalışıyor, online modda sorun yok. Offline-first destek bir sonraki sprint'te eklenecek.

---

## 🟡 Orta Öncelikli

### UI-003: Hayvan Listeleme — Input Odaklı Arama

**Durum:** Kısmen çalışıyor  
**Açıklama:**  
- Kızgınlık ve Doğum modallarında spesifik hayvan listesi çalışıyor (tohumlanabilir / anne adayları)
- Tohumlama ve Hastalık modallarında tüm hayvanlar listeleniyor (rakam tuşlamak gerekiyor)

**Öneri:**  
- Tohumlama modalı: `tohumlanabilir_hayvanlar` view'ını kullan (zaten var)
- Hastalık modalı: Aktif dişi hayvanları filtrele (erkek hariç)

**Öncelik:** Düşük — mevcut kullanım akışını bozmuyor

---

## 🟢 Düşük Öncelikli (İyileştirme)

### PERF-001: Hayvan Arama — Otomatik Tamamlama İyileştirmesi

**Sorun:** Kullanıcılar hala rakam tuşlamak zorunda

**Önerilen Çözüm:**  
```javascript
// acHayvan() fonksiyonunu geliştir
if (!q) {
  // Boş sorguda tüm hayvanları göster (ilk 20)
  filtered = src.slice(0, 20);
} else {
  // Küpe, ID, ırk bazlı filtrele
  filtered = src.filter(/* ... */);
}
```

**Risk:** Çok fazla hayvan varsa dropdown performansı düşebilir

---

## 📊 Sprint Özeti

| Özellik | Durum | Öncelik | Sprint |
|---------|-------|---------|--------|
| UI-001: Gebe Ata buton boyutu | ✅ Tamamlandı | Yüksek | chore/bug-001-resolved |
| UI-002: Modal ilk tıklama focus | ✅ Tamamlandı (kısmi) | Yüksek | chore/bug-001-resolved |
| LOGIC-001: Offline ilaç ekleme | ✅ Tamamlandı | Yüksek | chore/bug-001-resolved |
| LOGIC-002: Online sync | ✅ Tamamlandı | Yüksek | chore/bug-001-resolved |
| FEAT-001: Stok hareketleri listesi | ✅ Tamamlandı | Orta | chore/bug-001-resolved |
| TOHUMLAMA: Event Stack + RPC | ✅ Tamamlandı (70%) | Yüksek | tohumlama-rpc-030 |
| SONARCLOUD: S2-S5 fixleri | ✅ Tamamlandı (~250 issue) | Yüksek | sonarcloud-remediation |
| LOGIC-003: Offline tedavi günleri | 🔴 Ertelendi | Yüksek | **Sonraki** |
| TOHUMLAMA: `tohumlama_sonuc_bos` RPC | 🔴 Ertelendi | Yüksek | **Sonraki** |
| TOHUMLAMA: `tohumlama_abort` RPC | 🟠 Ertelendi | Orta | Backlog |
| SONARCLOUD: WONTFIX işaretleme | 🟡 Ertelendi | Düşük | Backlog |
| UI-003: Hayvan arama iyileştirme | 🟢 Ertelendi | Düşük | Backlog |

---

## 🎯 Sonraki Sprint Önerisi

**Sprint Adı:** `feat/tohumlama-bos-rpc`

**Hedefler:**
1. `tohumlama_sonuc_bos` RPC ekle (migration)
2. `tohSonuc()` fonksiyonunu RPC'ye çevir (forms.js:656)
3. Basit test: Tohumlama modal → "Boş" butonu → islem_log kontrolü

**Tahmini Süre:** 30-45 dk

---

**Sprint Adı:** `feat/offline-first-clinical`

**Hedefler:**
1. LOGIC-003: Offline tedavi günleri görünür olması
2. `_drugAdminCache` local cache oluştur
3. `renderCaseTimeline()` cache + DB merge refactor

**Tahmini Süre:** 2-3 saat

---

**Sprint Adı:** `chore/sonarcloud-wontfix`

**Hedefler:**
1. SonarCloud UI'da ~188 issue'yu "Won't Fix" olarak işaretle
2. Her kategori için açıklama ekle

**Tahmini Süre:** 30-45 dk (manuel)

---

## 🔄 ERTELENDİ — 2026-09-01 Küpe Revizyonu Artıkları (bilinçli, review onaylı)

- **17-param `hayvan_guncelle` overload'una (p_padok_id'li, p_kisir'siz) küpe kontrolü yok** (yalnız 18-param p_kisir'li overload'a eklendi). Partial unique index DB seviyesinde koruyor; eski overload'u ön yüz kullanmıyor. Takip: overload envanteri temizlenince (RPC consolidation) eklenir.
- **Aktif-öncelik dışı kalan find'ler:** `openInsemSafe` ve ui.js içindeki çeşitli dahili join noktaları (satır numaraları kayar — `rg -n "find(a =>" js/ui.js`) — pratikte id-key erişim, çakışma yalnız küpe-string girişinde mümkün.
- **`devlet_kupe` index** — sürü ~160 satır, seq-scan sorun değil; büyürse eklenir.
- **`extractFunctionSource` (test loader) regex literal tokenize etmiyor** — hata verirse yüksek sesle patlıyor (false-green riski düşük).
- **GT yenileme** — `20260901000002_kupe_revizyon.sql` (ve ikiz `...000001`) GT'de yok → gt-taslak işi. **+ 2026-09-06:** `20260906000001_postpartum_d53_e_vitamin_tek.sql` canlıya deploy edildi (postpartum d53 tek E Vitamini; commit 434c142) — dogum_kaydet + protokol_eksik_tara canlı gövdeleri değişti, GT regen kapsamına eklenecek (GT'de eski d53 Ademin/Yeldif + d54 satırları duruyor).

---

## 🔄 ERTELENDİ — 2026-09-02 3. Tur Revize (REV-1..5) Artıkları (bilinçli, review onaylı)

**Kaynak:** `.claude/idle-reports/2026-09-02-*.md` (5 rapor) + doğrulama turu. Hepsi merge edildi (aa5ceb8..27e5b0b arası); aşağıdakiler bilinçli kapsam dışı bırakılanlar.

### 🔴 Karar/işlem bekleyenler (kullanıcı)

- **9999 COALESCE taslağı deploy** — `.claude/draft-migrations/20260902000000_stat_suru_ozet_sessiz_coalesce.sql` (migrations/ DIŞINDA, otomatik-deploy emniyeti; deploy emrinde taşı+uygula). Sonrası canlı test: dashboard kart 24 = liste 24.
- **O1 — demo anon GRANT restore EDİLMESİN** önerisi (REV-1 raporu artı/eksi tablosu) — onay bekler.
- **GT v5 denetimli regen oturumu** — 21 madde + REV-1 drift bulguları (fark-matrisi §E): prod `gorev_tamamla`'daki dosyasız ASI_PLANLI hotfix'inin repo'ya migration olarak işlenmesi, demo'daki 3 legacy fn, 20260730000002 versiyon çakışması (2 dosya).
- **CLAUDE.md:299 bayat satırı** — kural gereği kullanıcı bizzat düzeltir.
- **DEMO_ANON_KEY GitHub secret'ı** — eklenirse CI demo health check tam doğrulamaya geçer (key'siz dal çalışıyor, 401=ayakta sayıyor).

### 🟡 CI sağlamlaştırma revizesi (REV-3 takibi — ortam kaynaklı kırmızı)

- İlk tam CI koşumu (run 33596164502): shard 2/3 YEŞİL; shard 1/3 (20m), 3/3, demo-e2e KIRMIZI — **hepsi tek-tip 20-30s ilk-yükleme timeout'u; kod regresyonu değil** (aynı kod lokalde 384/384 unit + 13/13 stub E2E + 66/0/1 gerçek-demo; Pages tazeliği doğrulandı). Neden: deploy'dan 1 dk sonra başlayan shard'larda muhtemel CDN gecikmesi + runner IP'lerine free-tier kısıtı. CI E2E kırmızısı zaten pre-existing (09-01 21:40 koşumu da failure).
- Önerilen fix: demo job + shard'lara `--retries=2`, timeout 60s (veya demo job'ı scheduled/dispatch-only), shard'ları Pages deploy bitişinden sonra tetikleme, `DEMO_ANON_KEY` secret.

### 🟢 Kod-içi küçük borçlar (sonraki idle/kod turu)

- **REV-2:** `_dcEditInline`/`_dcDeleteGroup`/`_dcDeleteClass` üçlüsü rpcOptimistic try/catch'siz (zarf dışı bırakıldı, rapor §2); 4 kalan escAttr-inline onclick ui.js:220/253/5651/5652 (yalnız uuid taşıyor, tehdit modeli dışı); `tests/smoke.spec.js:27` + `tests/e2e.spec.js:57` IGNORED_LOCATIONS'taki 'agent-telemetry' girdisi ölü (tag kaldırıldı — sonraki E2E turunda silinir); seed_defaults statik map over-pull + loadTanimlarPanel ile çift pull (bilinçli, yorumlu — tablolar küçük).
- **REV-5:** `sessiz_gun` null gelirse `_sessizGrupla` "diğer"e düşer, NaN-sıra çökmez (RPC COALESCE(...,9999) garantisiyle pratikte ulaşılamaz); `existedBefore` çift-tık yarış yolunda sheet yeniden inşa edilir → o nadir yolda scroll sıfırlanır (normal det-dönüşü display-toggle, scroll'u korur); `belirsiz-bs` sheet'i hâlâ ham-desen (router'a kayıtlı değil) — sessiz-bs'e yapılan dönüş/kapanış iyileştirmesinin belirsiz listesine de uygulanması ileride değerlendirilir.
- **kod-temizlik 1. tur kalıntısı:** `tumStokHareketleriniGoster` iade dalı esc'siz (MINOR); ui.js:8453/8503/8548/8606'da 4 erişilemez `ok===false` kontrolü.
- **ui-map.md regen** — son üretim 2026-09-01; REV-5 (ui.js +~70 satır: _sessizGrupla/_sessizSheetGizle/_sessizSheetKapat) ve kupe-arama işleri haritada yok; bölüm aralıklarını kaydırır, yanıltmaz.

---

## 2026-09-06 — bulk_ilac çifte stok düşümü (G-20260906-TOPLU-VAKA kapsamı dışı bırakıldı)

- `bulk_ilac` (migration 20260427000011) hem `stok.baslangic_miktar`'ı düşürüyor hem de pozitif bir `stok_hareket` kaydı yazıyor; `stok_tuketim_view` ikisini de saydığı için görüntülenen stok her toplu ilaç uygulamasında 2× düşüyor.
- G-20260906-TOPLU-VAKA araştırması sırasında keşfedildi; fix bilinçli olarak ertelendi (owner kararı 2026-09-06).
- Yeni yazılan `vaka_toplu_ac` RPC'si doğru deseni izliyor: yalnız pozitif ledger (`stok_hareket`), `baslangic_miktar` çift-düşümü yok (E2E doğrulandı: 30 pozitif stok_hareket, çift-düşüm yok).
