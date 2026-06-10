# Handoff — Faz A.1 + BUG-061 + BUG-060v2 Sonrası

**Tarih:** 2026-06-10 (üçüncü oturum güncellemesi)
**Oturum özeti:** Faz A.1 + BUG-061 doğrulama + BUG-060v2 spec yazımı + review sonrası revizyon
**Sonraki oturum:** BUG-060v2 fix uygulaması (sadece `_etken_kod_bul` değişikliği) VEYA Faz A.2+

---

## ✅ Bu Oturumlarda Yapılanlar

### Oturum 1 — Faz A.1 + BUG-061
1. **Faz A.1 — `js/utils/` envanter + analiz (TAMAMLANDI):**
   - Plan: `.claude/plans/faz-a1-utils-envanter-ve-refactor.md` (445 satır)
   - Rapor: `.claude/notes/faz-a1-envanter-raporu.md` (163 satır)
   - Bulgu: utils/ **5 dosya, 566 satır, 41 fonksiyon** — iyi tasarlanmış, refactor gereksiz
   - Commit: `1ab809e` + push ✅
2. **BUG-061 doğrulama (ÇÖZÜLDÜ — phantom bug):** Spec `docs/specs/2026-06-09-bug061-gecmis-onclick-fix.md` (✅ ÇÖZÜLDÜ). Fix 302d6e1'de zaten uygulanmış, f159260 sadece docs. Commit: `49aadcf` + push ✅
3. **Handoff ilk versiyonu:** Commit `349d8aa` + push ✅

### Oturum 2 — BUG-060v2 İlk Spec
4. **BUG-060v2 araştırma (ilk spec yazıldı, sonra REVİZE edildi):**
   - **Bildirim:** "60) 135 numaranın e vitamini görevi..."
   - **İlk yanlış tespit:** `hizli_uygulama` `gorev_log`'a dokunmuyor + `_etken_kod_bul` E_VIT tanımıyor (2 ayrı bug)
   - **İlk spec'te hata:** Custom SQL bloğu önerilmişti, NULL fallback tehlikeli, "Yağda Eriyen" çok geniş
   - Commit: `f45cbad` + push ✅ (bu commit REVİZE edilmiş haliyle değiştirildi)

### Oturum 3 — BUG-060v2 Spec REVİZYON
5. **Review sonrası kritik düzeltmeler:**
   - **Trigger mimarisi keşfi:** `fn_dinle_uygulama` trigger'ı ZATEN `_gorev_dinle`'yi çağırıyor (L9463-9470)
   - **Asıl fix:** Sadece `_etken_kod_bul` düzeltilince → `etken_kod` dolu kaydedilecek → trigger çalışacak → görev kapanacak
   - **060a için ek kod GEREKMEZ** (sadece 060b fix yeterli)
   - **Review feedback'ler entegre:** NULL fallback kaldırıldı, "Yağda Eriyen" eklenmedi, `v_active_ing` öncelikli yapıldı
6. **BUG-060v2 spec revize (338 satır, 10 bölüm):**
   - Spec: `docs/specs/2026-06-10-bug060-protokol-stok-gorev-uyumsuzluk.md`
   - **İsim çakışması notu:** Eski BUG-060 (e0f563d) = UUID cast, farklı bug. Bu BUG-060v2
   - Commit: `aa0f593` + push ✅

---

## 📊 Mevcut Durum (2026-06-10 öğleden sonra)

| Öğe | Durum |
|---|---|
| Aktif bug | **0** (BUG-060v2 spec yazıldı, fix uygulanmadı) |
| BUG-060v2 spec | ✅ Yazıldı + review sonrası REVİZE edildi (`aa0f593`) |
| BUG-060v2 fix | ⏳ Uygulanmadı, sırada |
| Faz A.1 | ✅ Tamamlandı |
| Faz A.1b backlog | 9 satır `toISOString()` refactor (low risk) |
| Faz A.2+ | Planlanmadı |
| ReFactorRoadmap.md | Okunmadı |
| Son commit | `aa0f593` (main, push edildi) |

---

## 🧠 Bu Oturumlarda Öğrendiklerimiz (5 kritik pattern)

### 1. Spec doğrulama — "phantom bug" tespiti
- BUG-061: Spec yazarı eski kodu görmüş, fix zaten 302d6e1'de uygulanmış
- **Kural:** Spec'i uygulamadan önce mutlaka spec'teki "AFTER" diff'i mevcut kodla kıyasla

### 2. Reopen commit yanılgısı
- BUG-061 için `f159260` commit'i "reopen" gibi görünüyordu, ama gerçekte sadece docs + cache-bust
- **Kural:** `git log --grep` ile "reopen" kelimesini görünce bile `git show --stat` ile doğrula

### 3. Cache-bust pre-commit hook
- `?v=<timestamp>` `index.html`'de otomatik güncelleniyor (JS dosyası değişince)
- **Kural:** `git status` sırasında `index.html` "modified" görürse panik yapma, timestamp-only değişiklik

### 4. BUG-060v2 — Trigger mimarisi zaten doğru (yeni pattern)
- `hizli_uygulama` `gorev_log`'a direkt dokunmuyor ama `fn_dinle_uygulama` trigger'ı INSERT sonrası `_gorev_dinle` çağırıyor
- **Kural:** "X RPC Y tablosunu etkilemiyor" derken trigger chain'i kontrol et. Sadece RPC body'sine bakma
- **Bulgu kaynağı:** ground truth'ta `grep -n "fn_dinle\|trg_dinle" → 5 trigger bulundu`
- **Kazanım:** İlk yazılan 50 satırlık custom SQL bloğu gereksizdi

### 5. Spec review → ground truth doğrulama
- İlk yazılan spec 3 kritik hata içeriyordu (yanlış fix stratejisi, tehlikeli fallback, çok geniş class eşleşmesi)
- **Kural:** Spec yazdıktan sonra mutlaka "ground truth'ta bu pattern var mı?" kontrolü yap
- **Kazanım:** 30 dk tahmini iş 20 dk'ya düştü, risk önemli ölçüde azaldı

---

## 🛠️ Araç Kullanım Kalıbı (Büyük Dosya Yazımı)

**Sorun:** `write` aracı büyük dosyalarda (~25-30 KB+) parse hatası verebiliyor. SQL `$$` blokları + Markdown code fence + Türkçe unicode kombinasyonu JSON payload'u parse edilemez yapabiliyor.

**Çözüm kalıbı:**

1. **>20 KB tahmini boyut** → parçala
2. **Adım 1:** `write` ile ilk parça (başlık + metadata + ilk 1-2 bölüm)
3. **Adım 2:** `shell` + `cat >> file.md << 'EOF'` (heredoc) ile devamını ekle
4. **Adım 3:** `shell` + `wc -l` + `grep` ile doğrulama
5. **Asla:** Tek seferde 400+ satırlık spec yazma

**Araç seçim tablosu:**

| Dosya türü | Boyut | Araç |
|------------|-------|------|
| Yeni dosya, <20 KB | Tek seferde | `write` |
| Yeni dosya, >20 KB | Parçalı | `write` + `cat >>` |
| Mevcut dosya, küçük değişiklik | Find-replace | `edit` |
| Mevcut dosya, büyük değişiklik | Parçalı | `edit` veya `cat >>` |

---

## 📋 Açılışta Yapılacaklar (Sıralı)

### Seçenek A — BUG-060v2 fix'i uygula (önerilen)
- **Süre:** ~20 dakika
- **Adımlar:**
  1. Migration dosyasını yaz: `supabase/migrations/20260610000001_bug060v2_etken_kod_vitamin.sql`
  2. Ground truth'taki `_etken_kod_bul` L9210 güncelle (`v_active_ing` öncelikli)
  3. `supabase_migrate` ile deploy et
  4. 4 test senaryosu çalıştır (Senaryo A: 135 ile normal, B: geri alma, C: gorev_tamamla regression, D: NULL etken_kod edge case)
  5. Spec'i "ÇÖZÜLDÜ" işaretle
  6. `.claude/knowledge/bugs.md`'ye **yeni ID** ile (BUG-064+) ekle (eski BUG-060 ile karışmaması için)
  7. Commit + push

### Seçenek B — Faz A.2+ planlaması
- **Süre:** ~1 saat
- **Adımlar:**
  1. `ReFactorRoadmap.md` oku
  2. Faz A.1b (9 satır toISOString refactor) veya Faz A.2 (büyük refactor) teklifi
  3. Spec yaz + onay al

### Seçenek C — Yeni bug/spec bildirimi varsa
- Bekleyen: yok
- Kullanıcı yeni bug bildirirse bu yola sap

---

## 📁 Referanslar Tablosu (hızlı erişim)

| Dosya | İçerik | Satır |
|-------|--------|-------|
| `docs/specs/2026-06-09-bug061-gecmis-onclick-fix.md` | BUG-061 ✅ ÇÖZÜLDÜ | 180+ |
| `docs/specs/2026-06-10-bug060-protokol-stok-gorev-uyumsuzluk.md` | BUG-060v2 spec (fix bekliyor) | 338 |
| `.claude/notes/faz-a1-envanter-raporu.md` | Faz A.1 utils analiz | 163 |
| `.claude/plans/faz-a1-utils-envanter-ve-refactor.md` | Faz A.1 plan | 445 |
| `.claude/knowledge/bugs.md` | Aktif + çözülmüş bug listesi | 90+ |
| `supabase/migrations/...ground_truth.sql:6556-6645` | `gorev_tamamla` RPC | 90 |
| `supabase/migrations/...ground_truth.sql:9169-9224` | `_etken_kod_bul` (060b fix yeri) | 56 |
| `supabase/migrations/...ground_truth.sql:9224-9251` | `_gorev_dinle` helper | 28 |
| `supabase/migrations/...ground_truth.sql:9256-9298` | `hizli_uygulama` RPC | 43 |
| `supabase/migrations/...ground_truth.sql:9320-9355` | `hizli_uygulama_geri_al` (simetri) | 35 |
| `supabase/migrations/...ground_truth.sql:9463-9473` | `fn_dinle_uygulama` trigger | 10 |
| `js/ui.js:1080-1102` | `_hayvanHizliUygulaKaydet` | 23 |
| `js/ui.js:940-970` | `_protokolUygulaKaydet` | 30 |
| `js/ui.js:3982` | Görevler sekmesi `gorev_tamamla` çağrısı | - |

---

## 🔑 Son Commit'ler (main)

```
aa0f593 docs: BUG-060v2 spec — review sonrası revize
f45cbad docs: BUG-060 spec — protokol uygulama stok/gorev uyumsuzluk
349d8aa docs: handoff güncelleme — Faz A.1 + BUG-061 tamamlandı
49aadcf docs: BUG-061 spec kapatildi — fix 302d6e1'de uygulanmis
1ab809e docs: faz a.1 plan + utils envanter analiz raporu
```

---

**Handoff durumu:** ✅ Güncel, 3 oturum kapsıyor (Faz A.1 + BUG-061 + BUG-060v2)
