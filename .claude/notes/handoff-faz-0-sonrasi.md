# Handoff — Faz A.1 + BUG-061 + BUG-064 (Yaklaşım 2) Sonrası

**Tarih:** 2026-06-10 (4. oturum güncellemesi)
**Oturum özeti:** Faz A.1 + BUG-061 doğrulama + BUG-060v2 spec (2 revizyon) + Yaklaşım 2 kararı
**Sonraki oturum:** BUG-064 fix uygulaması (2 SQL fix, ~20 dk) VEYA Faz A.2+

---

## ✅ Bu Oturumlarda Yapılanlar

### Oturum 1 — Faz A.1 + BUG-061
1. **Faz A.1 — `js/utils/` envanter + analiz (TAMAMLANDI):**
   - Plan: `.claude/plans/faz-a1-utils-envanter-ve-refactor.md` (445 satır)
   - Rapor: `.claude/notes/faz-a1-envanter-raporu.md` (163 satır)
   - Bulgu: utils/ **5 dosya, 566 satır, 41 fonksiyon** — iyi tasarlanmış, refactor gereksiz
   - Commit: `1ab809e` + push ✅
2. **BUG-061 doğrulama (ÇÖZÜLDÜ — phantom bug):** Spec yazarı eski kodu görmüş, fix zaten 302d6e1'de. Commit: `49aadcf` + push ✅
3. **Handoff ilk versiyonu:** Commit `349d8aa` + push ✅

### Oturum 2 — BUG-060v2 İlk Spec (3 kritik hata)
4. **İlk spec yazıldı:** `f45cbad` + push ✅
   - 3 kritik hata: yanlış fix stratejisi (custom SQL), NULL fallback tehlikesi, "Yağda Eriyen" çok geniş

### Oturum 3 — BUG-060v2 Spec REVİZYON 1
5. **Trigger mimarisi keşfi:** `fn_dinle_uygulama` + `_gorev_dinle` zaten doğru kurulmuş
6. **Review feedback entegre:** NULL fallback kaldırıldı, `v_active_ing` öncelikli, "Yağda Eriyen" eklenmedi
7. **Spec revize (338 satır):** Commit `aa0f593` + push ✅

### Oturum 4 — BUG-060v2 Spec REVİZYON 2 (Yaklaşım 2)
8. **Kullanıcı gözlemi:** "Hizli uygulama audit iz bırakmıyor" + "İki kapı aynı yere varıyor"
9. **3 yaklaşım değerlendirildi:**
   - A: JS handler redirect (race condition + mimari bozulma)
   - **B: 2 fix (_etken_kod_bul + islem_log) — SEÇİLDİ**
   - C: Unified RPC refactor (büyük refactor, ayrı oturum)
10. **Final scope:**
    - Fix #1: `_etken_kod_bul` E_VIT (1 satır)
    - Fix #2: `hizli_uygulama` islem_log (1 INSERT)
    - Bonus: `hizli_uygulama_geri_al` audit simetrisi (1 INSERT)
11. **Spec FINAL (470 satır, 10 bölüm, 2 revizyon notu):** Commit `e0e6a52` + push ✅

---

## 📊 Mevcut Durum (2026-06-10 18:30 — 7. oturum güncellemesi)

| Öğe | Durum |
|---|---|
| Aktif bug | **0** (BUG-064 spec FINAL Rev 7, fix uygulanmadı) |
| BUG-064 spec | ✅ **705 satır, 7 revizyon geçmişi, subagent + Faz 0 doğrulaması onaylandı** |
| BUG-064 plan | ✅ **213 satır, Rev 7 düzeltmesi (v_uyg.aktif_ing kaldırıldı, v_hayvan güvenli)** |
| BUG-064 Faz 0 | ✅ **Doğrulama tamamlandı** — 5 fonksiyon `pg_get_functiondef` ile çekildi, 5/5 L uyuşuyor, kolon varlıkları doğrulandı |
| BUG-064 fix | ⏳ Uygulanmadı, Faz 1 sırada (migration yazımı, ~10 dk) |
| Faz A.1 | ✅ Tamamlandı |
| Faz A.1b backlog | 9 satır `toISOString()` refactor (low risk) |
| Faz A.2+ | Planlanmadı |
| ReFactorRoadmap.md | Okunmadı |
| Son commit | `8c42ccd` (main, push edildi, senkron doğrulandı) |
| Bu oturumda yapılan | Reviewer 3 notu düzeltme (3 eleştiri → 1 Rev 7) + Faz 0 doğrulama (5 fonksiyon) + plan dosyası v_uyg.aktif_ing fix |

---

## 🧠 Bu Oturumlarda Öğrendiklerimiz (9 kritik pattern)

### 1. Spec doğrulama — "phantom bug" tespiti
- BUG-061: Spec yazarı eski kodu görmüş, fix zaten 302d6e1'de uygulanmış
- **Kural:** Spec'i uygulamadan önce mutlaka spec'teki "AFTER" diff'i mevcut kodla kıyasla

### 2. Reopen commit yanılgısı
- BUG-061 için `f159260` commit'i "reopen" gibi görünüyordu, ama gerçekte sadece docs + cache-bust
- **Kural:** `git log --grep` ile "reopen" kelimesini görünce bile `git show --stat` ile doğrula

### 3. Cache-bust pre-commit hook
- `?v=<timestamp>` `index.html`'de otomatik güncelleniyor (JS dosyası değişince)
- **Kural:** `git status` sırasında `index.html` "modified" görürse panik yapma, timestamp-only değişiklik

### 4. BUG-060v2 — Trigger mimarisi zaten doğru
- `fn_dinle_uygulama` + `_gorev_dinle` DB transaction içinde atomik
- **Kural:** "X RPC Y tablosunu etkilemiyor" derken trigger chain'i kontrol et. Sadece RPC body'sine bakma
- **Kazanım:** İlk yazılan 50 satırlık custom SQL bloğu gereksizdi

### 5. Spec review → ground truth doğrulama
- İlk yazılan spec 3 kritik hata içeriyordu
- **Kural:** Spec yazdıktıran sonra mutlaka "ground truth'ta bu pattern var mı?" kontrolü yap

---

## ✅ BUG-064 — DEPLOY TAMAMLANDI (2026-06-10)

**Faz 0 → Faz 3 başarıyla tamamlandı.** Canlıda 3 fonksiyon güncellendi.

### Deploy Edilen SQL (3 fonksiyon, 1 migration)

| # | Fonksiyon | L (ground truth) | Değişiklik | Doğrulama |
|---|---|---|---|---|
| 1 | `_etken_kod_bul` | L9169-9224 | +1 satır: `v_active_ing ILIKE '%E Vitamini%' → E_VIT` | ✅ `pg_get_functiondef` |
| 2 | `hizli_uygulama` | L9256-9306 | +14 satır: islem_log audit (uygulama_log INSERT sonrası, stok_hareket öncesi) | ✅ `pg_get_functiondef` |
| 3 | `hizli_uygulama_geri_al` | L9309-9342 | +24 satır: islem_log audit (UPDATE öncesi, DELETE sonrası) | ✅ `pg_get_functiondef` |

### Subagent Review #2 — APPROVED (10/10 ✅)

- **Blocker:** 0
- **Critical:** 0
- **Major:** 0
- **Minor:** 2 (post-deploy iyileştirme, deploy'u bloke etmiyor)

**Minor #1:** Satır 218 `v_hayvan.kupe_no` NULL riski → `COALESCE(v_hayvan.kupe_no, v_uyg.hayvan_id)` önerisi (audit kalitesi)

**Minor #2:** Audit snapshot "ne vardı" semantiği (UPDATE öncesi `eski=true`) — doğru audit pattern

### v1 WRONG-11param Backup (öğrenme arşivi)

- **Yol:** `supabase/migrations/backup/20260610000001_bug064_etken_kod_vitamin_audit.WRONG-11param-v1.sql`
- **Neden yanlış:** Spec Rev 7'de 11 parametreli varsayımsal API uydurulmuş, gerçek 6 parametreli imzadan tamamen farklı
- **Korunma nedeni:** Gelecekte "spec'te API yazarken ground truth'a bak" dersinin somut kanıtı

### 11-Parametreli Genişletilmiş İmza Fikri (İleride)

- **Yol:** `docs/ideas/2026-06-10-hizli-uygulama-genisletilmis-imza.md` (107 satır)
- **Fikir:** `uygulama_tipi, uygulayan, protokol_id, gun_no, padok_hedef, kullanici_notu` ek parametreleri
- **Kullanım:** Tedavi planı entegrasyonu, audit trail, personel atama — refactor yol haritasında değerlendirilebilir

### `uygulama_log` Şema Doğrulaması (Subagent Review #1)

- **Kolonlar (8):** id, hayvan_id, stok_id, etken_kod, doz, birim, rota, notlar, tarih
- **Tip:** uuid PK + 9 text + 4 numeric/timestamptz
- **KRİTİK:** `gorev_id` kolonu YOK — `v_uyg.gorev_id` her zaman NULL
- **Ters yönlü arama:** `gorev_log WHERE kapatan_ref = 'uygulama_log:' || id` (mevcut pattern)
- **Ders:** `information_schema.columns` her zaman doğrula, ground truth CREATE TABLE'a güvenme

### Reviewer Recipe Standardı

- **Source adı:** `reviewer` (canonical)
- **Tip:** type-aware task verifier (research/code/docs) + self-repair + auto-retry
- **Telsiz/Blackboard mode:** var
- **Subagent çalıştırma:** `delegate(source="reviewer", async=true)` → `load(source=task_id)` ile bekle
- **BUG-064'te 2 tur:** Review #1 (kritik: `gorev_id` subquery + `SET search_path`), Review #2 (APPROVED 10/10)

### 4 Düzeltme Süreci (deploy öncesi)

| # | Düzeltme | Neden | Kaynak |
|---|---|---|---|
| 1 | Fonksiyon 3'te UPDATE + DELETE + `v_uyg.gorev_id` eksikti | v1 backup'tan kopyalarken mevcut yapıyı atlamışım | Subagent review |
| 2 | 3 fonksiyona `SET search_path = public, pg_temp` | SECURITY DEFINER + schema hijacking koruması | Subagent review |
| 3 | `v_uyg.gorev_id` → subquery (Bonus) | `uygulama_log` tablosunda `gorev_id` kolonu YOK | Subagent review |
| 4 | Fonksiyon 3'te `guncellenen` subquery (UPDATE öncesi semantik) | ters yönlü arama (`kapatan_ref = 'uygulama_log:'||id`) | Subagent review |

### Sonraki Adım: Faz 4 — 5 Test Senaryosu

- 4.0 Canlı veri ID çekme (hayvan 135, E/A/C vit stokları, açık E vit görevi)
- 4.A 135 numaralı hayvan + E Vitamini (ana test)
- 4.B Geri alma (Bonus simetri)
- 4.C gorev_tamamla regression
- 4.D NULL etken_kod edge case
- 4.E C vitamini NULL kontrolü

**Kural:** Spec yazdıktıran sonra mutlaka "ground truth'ta bu pattern var mı?" kontrolü yap

**Pattern 10 (YENİ - 2026-06-10):** Faz 0 doğrulaması her zaman ÖNCE yapılmalı
- `pg_get_functiondef` ile **canlı DB'den** fonksiyon imzalarını çek (PostgREST `pg_proc`'a erişemez, `supabase_migrate` ile)
- `ground_truth.sql` L referansları + imzalar + return type + DECLARE bölümleri + kolon varlıkları teyit et
- `information_schema.columns` ile tablo şeması (ALTER TABLE eklenen kolonlar CREATE TABLE'da görünmez!)
- **Kural:** Migration yazmadan önce 5-10 dakika bu doğrulamaya harca. 6 revizyon geçmişimiz var, 1 Faz 0 ile hepsi önlenebilirdi

**Pattern 11 (YENİ - 2026-06-10):** Fonksiyon imza çakışması — ground truth'tan birebir kopyala
- Spec'te "olması gereken API" yazmak YANLIŞ — gerçek imzayı yaz
- 6 parametreli mi 11 parametreli mi: `pg_get_functiondef` çıktısı kesindir
- JS caller sayısı (grep ile) → gerçekte kaç yerde kullanılıyor → ground truth karşılığı
- v1 WRONG-11param migration backup'ı repoda tutuluyor (`supabase/migrations/backup/`) — gelecekte referans

### 6. "İki kapı, aynı yer" — Mimari felsefe (YENİ — Oturum 4)
- Görevler, protokol, hızlı uygulama → hepsi `uygulama_log`'a yazar → trigger otomatik `gorev_log` kapatır
- **Kural:** JS handler'a "görev bul → gorev_tamamla redirect" ekleme YANLIŞ MİMARİ:
  - Race condition (iki call arası)
  - İş mantığı frontend'e kaçar
  - Trigger mimarisini bozar
- **Doğru yaklaşım:** Tetikleyici mimariyi KORU, sadece beslenecek veriyi düzelt + audit boşluğunu kapat

### 7. Spec yazımında SQL kolon adı tuzağı (YENİ — Oturum 5)
- BUG-064 spec Rev 2'de `islem_log` INSERT'i uydurma kolonlarla yazılmıştı (hayvan_id, islem_tipi, aciklama, referans_id)
- **Gerçek:** tip, ana_hayvan_id, kullanici_notu, ref_id+ref_tablo (2 ayrı), snapshot jsonb NOT NULL
- **Kural:** Spec'te SQL bloğu yazarken mutlaka `information_schema.columns` veya ground truth'tan kolon adlarını doğrula. `gorev_tamamla` gibi benzer pattern'i kopyala-ya-pıştır yap, ama kolon adlarını ASLA varsayma
- **Kazanç:** Rev 3'te reviewer sayesinde deploy-fail önlendi

### 8. Subquery yerleşim sırası kritik (YENİ — Oturum 5)
- `hizli_uygulama_geri_al` audit INSERT'i L9338'den SONRA yerleştirilseydi → `SELECT ... FROM uygulama_log` subquery boş dönerdi → ana_hayvan_id NULL
- **Kural:** DELETE'den sonra subquery ile aynı kayda erişmeye çalışma. Önceden record'a alınmış değişkenleri kullan (`v_uyg.hayvan_id` gibi)
- **Pratik kalıp:** INSERT'i "kayıt silinmeden hemen önce" yerleştir, ardından DELETE gelir

### 9. İmplementasyon planı yazarken Faz 0 = Doğrulama (YENİ — Oturum 6)
- Spec yazıldı, satır referansları 6 revizyonda düzeltildi — ama hâlâ canlı DB'den doğrulanmadı
- **Kural:** Migration yazmadan önce mutlaka `pg_proc` + `pg_get_functiondef` ile canlı imzaları çek, spec L referanslarıyla karşılaştır
- **Kazanım:** 5 dakika doğrulama, potansiyel "yanlış satıra uyguladım" hatasını sıfırlar (6 revizyonda düzeltilen line referansları tekrar kayarsa tüm test senaryoları geçersiz olur)
- **Plan dosyası kalıbı:** `.claude/plans/<tarih>-<bug>-impl.md` (210 satır, 5 faz + riskler + kabul kriterleri)
- **Referans:** `.claude/plans/2026-06-10-bug064-impl.md`

### 10. `pg_get_functiondef` PostgREST kısıtı (YENİ — Oturum 7, Faz 0 doğrulaması)
- `supabase_query` `pg_proc`, `pg_get_functiondef` gibi sistem kataloglarına **erişemez** (PostgREST sadece public schema)
- **Doğru araç:** `supabase_migrate({sql: "SELECT pg_get_functiondef('func'::regproc)"})` (Management API, DDL yetkisi var)
- **Kazanım:** Faz 0'da `v_hayvan` DECLARE kontrolü + `v_uyg.aktif_ing` kolon varlığı + trigger ref format doğrulandı
- **Bulgu:** Spec'te `v_uyg.aktif_ing` hiç yoktu (zaten doğruydu), ama **plan dosyamda** vardı — Rev 7 ile düzeltildi

### 11. Kolon varlığı doğrulama — subagent uyarısı (YENİ — Oturum 7)
- Kullanıcı plan review'inde 3 sorun buldu: (1) `pg_proc` PostgREST erişemez, (2) `v_hayvan` DECLARE kontrolü, (3) test UUID'leri placeholder
- **Kural:** Spec/plan yazarken `format(...)` içinde kullanılan her kolon için `pg_get_functiondef` ile DECLARE + record kolon listesi doğrula
- **Pratik kalıp:** Subagent veya kullanıcı review'i → **3 eleştiri = 1 spec revizyonu** (Rev 7 standardı)
- **Araç:** Plan dosyasında `⚠️ Rev 7 düzeltme` notu ile inline gerekçe bırak

---

## 🏆 BUG-064 Final Scope (Yaklaşım 2)

**2 fix, 1 migration, ~20 dakika:**

1. **`_etken_kod_bul` E_VIT düzeltmesi** (ground_truth L9210):
   - `v_active_ing ILIKE '%E Vitamini%'` öncelikli eklenecek
   - Mevcut `v_class_name ILIKE '%E Vit%'` + `v_stok_ad` fallback'leri korunacak

2. **`hizli_uygulama` islem_log INSERT** (ground_truth L9256-9298):
   - `uygulama_log` INSERT'ten sonra, `stok_hareket` INSERT'ten önce eklenecek
   - `islem_tipi='HIZLI_UYGULAMA'`, `referans_id=v_id` (uygulama_log.id)

3. **Bonus — `hizli_uygulama_geri_al` audit simetrisi** (ground_truth L9320-9355):
   - `islem_tipi='HIZLI_UYGULAMA_GERI_AL'`, `referans_id=v_uygulama_id`

**Test senaryoları (5):**
- A: 135 ile normal akış (etken_kod='E_VIT' + gorev_log kapanır + islem_log var)
- B: Geri alma simetrisi (islem_log da geri alınır)
- C: gorev_tamamla regression (etkilenmemeli)
- D: NULL etken_kod edge case (görev kapatılmaz, audit hâlâ yazılır)
- E: C vitamini girilirse E_VIT görevi açık kalır (yanlış kapama yok)

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

### Seçenek A — BUG-064 fix'i uygula (önerilen)
- **Süre:** ~37 dakika kaldı (Faz 0 = 5 dk tamamlandı, kalan: Faz 1-5 = ~32 dk)
- **Plan:** `.claude/plans/2026-06-10-bug064-impl.md` (213 satır, Rev 7 düzeltmesi dahil)
- **Faz 0 tamamlandı:** 5 fonksiyon `pg_get_functiondef` ile çekildi (PostgREST `pg_proc`'a erişemez, Management API ile çalışıyor). Bulgular:
  - 5/5 L referansı uyuşuyor ✅
  - `v_hayvan` DECLARE L8'de mevcut (`hizli_uygulama_geri_al`) ✅
  - `v_uyg.aktif_ing` kolonu YOK → plan dosyası Rev 7 ile düzeltildi ✅
- **Kalan adımlar:**
  1. **Faz 1 (10 dk):** Migration yaz + SQL syntax dry-run
  2. **Faz 2 (5 dk):** Ground truth senkron + `git diff` kontrol
  3. **Faz 3 (2 dk):** `supabase_migrate` ile deploy
  4. **Faz 4 (15 dk):** 5 test senaryosu (A: 135 + E vit, B: geri al simetri, C: regression, D: NULL edge, E: C vit NULL) + Adım 4.0 canlı ID çekme
  5. **Faz 5 (5 dk):** Commit + push + memory + handoff + bugs.md güncelle

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
| `docs/specs/2026-06-10-bug060-protokol-stok-gorev-uyumsuzluk.md` | BUG-064 spec FINAL (2 fix, Yaklaşım 2) | 665 |
| `.claude/plans/2026-06-10-bug064-impl.md` | BUG-064 implementasyon planı (5 faz, hibrit araç seti) | 210 |
| `.claude/notes/faz-a1-envanter-raporu.md` | Faz A.1 utils analiz | 163 |
| `.claude/plans/faz-a1-utils-envanter-ve-refactor.md` | Faz A.1 plan | 445 |
| `.claude/knowledge/bugs.md` | Aktif + çözülmüş bug listesi (BUG-064 entry var) | 110+ |
| `supabase/migrations/...ground_truth.sql:6556-6645` | `gorev_tamamla` RPC | 90 |
| `supabase/migrations/...ground_truth.sql:9169-9224` | `_etken_kod_bul` (Fix #1 yeri) | 56 |
| `supabase/migrations/...ground_truth.sql:9224-9251` | `_gorev_dinle` helper | 28 |
| `supabase/migrations/...ground_truth.sql:9256-9298` | `hizli_uygulama` RPC (Fix #2 yeri) | 43 |
| `supabase/migrations/...ground_truth.sql:9320-9355` | `hizli_uygulama_geri_al` (bonus simetri) | 35 |
| `supabase/migrations/...ground_truth.sql:9463-9473` | `fn_dinle_uygulama` trigger | 10 |
| `js/ui.js:1080-1102` | `_hayvanHizliUygulaKaydet` | 23 |
| `js/ui.js:940-970` | `_protokolUygulaKaydet` | 30 |
| `js/ui.js:3982` | Görevler sekmesi `gorev_tamamla` çağrısı | - |

---

## 🔑 Son Commit'ler (main)

```
6d16040 docs: BUG-064 spec Rev 6 — line referans duzeltmeleri
42aea2f docs: BUG-064 spec Rev 5 — subagent review + cift islem vaka calismasi
edd1e6d docs: BUG-064 spec Rev 4 — hizli_uygulama_geri_al subquery + 3 kalıntı duzeltme
8260a3a docs: BUG-064 spec Rev 3 — islem_log kolon adları + snapshot NOT NULL duzeltme
e0e6a52 docs: BUG-060v2 spec FINAL — Yaklaşım 2 (2 fix, 1 migration, audit trail)
aa0f593 docs: BUG-060v2 spec — review sonrası revize
104ba35 docs: handoff + bugs.md — Faz A.1 + BUG-061 + BUG-064 (v2) tamamlandı
```

---

**Handoff durumu:** ✅ Güncel, 5 oturum kapsıyor (Faz A.1 + BUG-061 + BUG-064 6 revizyon)
