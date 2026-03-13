# EgeSüt ERP — SPEC v11.1
> Operasyonel rehber. Mimari kararlar → ARCHITECTURE.md
> Son güncelleme: 2026-03-13

---

## 0. OTURUM PROTOKOLÜ

1. SPEC'i oku → sıradaki item'ı söyle → onay al → başla
2. Değişiklik formatı: SEARCH/REPLACE veya inline python. Tam dosya sadece büyük refactor'da.
3. Migration her zaman idempotent. Yeni tablo = RLS + SECURITY DEFINER.
4. Oturum sonu SPEC güncelle, push et.

---

## 1. MEVCUT DURUM

### Migration Durumu
| Migration | Dosya | DB Durumu |
|-----------|-------|-----------|
| 001–013 | ✅ | ✅ Uygulandı |
| 019–021 | ✅ | ✅ Uygulandı |
| 022 case_management | ✅ | ✅ Uygulandı |
| 023 remove_drug_admin | ✅ | ✅ Uygulandı |
| 024 link_drug_to_stock | ✅ | ✅ Uygulandı |

### Aktif DB Şeması (Tıbbi Sistem)
Yeni (022 ile gelen) tablolar aktif:
- `diseases` — controlled entity, seed data yüklü
- `drugs` — controlled entity, seed data yüklü, `stock_item_id → stok`
- `cases` — vaka kaydı, `animal_id → hayvanlar`, `disease_id → diseases`
- `treatment_days` — günlük tedavi, `case_id → cases`
- `drug_administrations` — ilaç uygulama, `drug_id → drugs`, trigger → `stok_hareket`
- `treatment_timeline` view — frontend için hazır

Eski tablolar (arşiv, readonly):
- `hastalik_log` — eski free-text hastalık kaydı, yeni veri girilmez
- `tedavi` — eski ilaç kaydı, yeni veri girilmez

### Mimari Kararlar (2026-03-13)
1. `hastalik_log` ve `tedavi` taşınmıyor — veriler test verisi, önemli değil. Salt arşiv.
2. Yeni UI tamamen case-based sisteme göre yeniden yazılıyor.
3. `hastalik_kaydet`, `tedavi_ekle`, `tedavi_sil` RPC'leri deprecated — yeni UI bunları çağırmaz.
4. Stok düşümü SADECE `drug_administrations` INSERT trigger'ından gerçekleşir.
5. Free text tani/ilac yasak — `diseases.id` ve `drugs.id` FK zorunlu.

---

## 2. SPRINT — SIRADAKI GÖREVLER

### ⚠️ Yazıldı — Test Geçmedi (CLN Serisi)
| Item | Açıklama | Bilinen Bug |
|------|----------|-------------|
| **CLN-01** | Migration 022 uygulandı | — |
| **CLN-02** | `m-disease` modal, `diseases` dropdown, `create_case()` RPC | `loadDiseasesDropdown` çift tanımlı: biri `d-disease-id`, diğeri `case-disease-id` selector — ikinci versiyon boş çalışır |
| **CLN-03** | Vaka detay UI, `treatment_timeline` render, ilaç ekleme/silme | `openCaseDet` + `renderCaseTimeline` ui.js'de çift tanımlı (~satır 1242 ve ~1374). `_loadCaseDrugsCache` ve `_caseDrugsCache` hiçbir yerde tanımlanmamış → `ReferenceError`, modal açılmaz |
| **CLN-04** | `link_drug_to_stock` RPC + `submitDrugStokLink` | Backend doğru; Ayarlar UI render test edilmedi |
| **CLN-05** | Hayvan kartında aktif vaka chip, tab-saglik | `openCaseDet` çalışmadığı için chip tıklaması da çalışmaz (CLN-03 blocker) |
| **CLN-06** | `pullTables` güncellendi, `hastalik_log` kaldırıldı | ✅ |

### 🔴 Şu An Yapılacak — CLN Bugfix
| Item | Açıklama | Dosyalar |
|------|----------|----------|
| **CLN-FIX-1** | `openCaseDet` + `renderCaseTimeline` çift tanımını sil — ui.js ~satır 1242–1370 eski versiyonu kaldır | ui.js |
| **CLN-FIX-2** | `_loadCaseDrugsCache` / `_caseDrugsCache` tanımsız → `loadDrugsCache()` / `_drugsCache` olarak düzelt (ui.js 3 yer, forms.js 1 yer) | ui.js, forms.js |
| **CLN-FIX-3** | `loadDiseasesDropdown` çift tanımlı — `case-disease-id` selector'lü ikinci versiyonu sil | forms.js |
| **CLN-FIX-4** | `submitAddDay`, `submitAddDrug`, `submitCloseCase` ölü kod — HTML çağırmıyor, sil | forms.js |
| **VAC-01** | Aşılama modülü (vaccines tablosu + protokol + görev) | migration, ui.js, forms.js |

> CLN-01 (022 uygula) tamamlandı — migrations klasöründe mevcut ve DB'de aktif.

### 🟡 Sonraki Sprint
| Item | Açıklama |
|------|----------|
| VAC-01 | Aşılama modülü (vaccines tablosu + protokol + görev) |
| BULK-01 | Toplu işlem paneli |
| S2-05 | Abort akışı |
| S2-07 | Görev renk mantığı (geciken/bugün/yakın/gelecek) |
| S2-09 | Excel import/export |
| S2-10 | Grup/padok/laktasyon yeniden tasarımı + mig-015 |

### ⏸ Bloke / Bekleyen
| Item | Bloke Sebebi |
|------|-------------|
| T-07 İlaç yönetimi (eski sistem) | CLN serisi tamamlandı, deprecated — kapatıldı |
| S3-01 Supabase Realtime | Sprint 3 |
| DEBT-01 Teknik borç temizliği (orphan kolonlar, drift) | Sprint 3 |

---

## 3. TEKNİK REFERANS

### Geliştirme Pipeline
```bash
# SEARCH/REPLACE (standart)
cat > /tmp/r.txt << 'EOF'
SEARCH:
eski metin
REPLACE:
yeni metin
EOF
python3 apply.py --replace js/ui.js /tmp/r.txt

# Çok dosya + commit
python3 << 'PYEOF'
import subprocess, os
os.chdir('/root/egesut-erp1')
changes = [('js/api.js','eski','yeni')]
for f,s,r in changes:
    t=open(f,encoding='utf-8').read()
    open(f,'w',encoding='utf-8').write(t.replace(s,r,1))
subprocess.run(["git","add","."])
subprocess.run(["git","commit","-m","commit"])
subprocess.run(["git","push"])
PYEOF
```

### Git Token
```bash
git remote set-url origin https://Meliksahtokur:TOKEN@github.com/Meliksahtokur/egesut-erp1.git
```

### Kritik Fonksiyonlar
```javascript
pullTables(['tablo'])     // hedefli fetch
renderFromLocal()         // await — kritik işlem sonrası
renderSafe()              // debounce — background
rpcOptimistic(fn,tables)  // toast → rpc → pull + render
```

### Tıbbi Sistem RPC Referansı (Aktif — Case-Based)
```javascript
// Vaka aç
rpc('create_case', { p_animal_id, p_disease_id, p_notes })
// → { ok, case_id }

// Tedavi günü ekle
rpc('add_treatment_day', { p_case_id })
// → { ok, day_id }

// İlaç uygula (trigger → stok_hareket)
rpc('add_drug_administration', { p_day_id, p_drug_id, p_dose, p_unit, p_route })
// → { ok, administration_id }

// İlaç kaydı sil (trigger → stok_hareket iptal)
rpc('remove_drug_administration', { p_admin_id })
// → { ok }

// Vaka kapat
rpc('close_case', { p_case_id })
// → { ok }
```

### Deprecated RPC'ler (eski sistem — çağrılmaz)
- `hastalik_kaydet` — eski free-text hastalık
- `hastalik_guncelle` — eski
- `hastalik_kapat` — eski
- `hastalik_sil` — eski
- `tedavi_ekle` — eski
- `tedavi_sil` — eski

### pullTables Tabloları (güncel)
```javascript
// Aktif
['hayvanlar', 'cases', 'diseases', 'drugs',
 'stok', 'stok_hareket', 'tohumlama',
 'dogum', 'gorev_log', 'islem_log', 'bildirim_log']

// Arşiv (çekilmez artık)
// 'hastalik_log', 'tedavi'
```

---

## 4. KISA DERS LİSTESİ

| Konu | Kural |
|------|-------|
| View güncelleme | `DROP VIEW IF EXISTS ... CASCADE` zorunlu |
| Trigger | `DROP TRIGGER IF EXISTS` tüm varyantlar |
| Kritik render | `renderSafe()` değil, `await renderFromLocal()` |
| hastalik_log id | `id::text = p_id` cast et |
| gorev_log kolon | `notlar` yok, `aciklama` var |
| Stok ledger | `stok_hareket` asla silinmez — yeni hareket ekle |
| Ledger işareti | Kullanım = POZİTİF, iade = NEGATİF (frontend SUM'dan düşürür) |
| Controlled entity | diseases, drugs, hayvanlar → asla free text, FK zorunlu |
| Stok düşümü | SADECE `drug_administrations` INSERT trigger'ından — başka yol yok |
| Eski tıbbi tablolar | `hastalik_log`, `tedavi` → arşiv, yeni veri girilmez, UI göstermez |
| Çift tanım | JS'de aynı isimli iki `async function` → son tanım kazanır, ilk sessizce ezilir — kaçınılacak |
| Cache isimlendirme | ui.js ilaç cache: `_drugsCache` + `loadDrugsCache()` — başka alias (`_caseDrugsCache` vb.) üretilmez |
| `tedavi_view` | Bu view mevcut değil — eski sistem kalıntısı, `renderHstIlaclar` kullanılmaz |

---

## CLN Oturum-2 Bulgular & Canlı Durum (2026-03-13)

### Bu oturumda düzeltilen
- `hastalik_log` IDB transaction hatası → `buildDiseaseFreq` ve `acDisease` temizlendi
- `loadDiseasesDropdown` yanlış selector (`case-disease-id` → `d-disease-id`)
- `openM('m-case')` → `openM('m-disease')` (HTML + openMWithHayvan)
- `openMWithHayvan` içindeki `m-case` bloğu kaldırıldı
- Tab-saglik eski `hastalik_log` render bloğu kaldırıldı
- `openHstDet` tanımsız — 3 çağrı kaldırıldı/güvenli hale getirildi
- IDB adı `egesut_v9` → `egesut_v10` (yeni store'lar için zorla upgrade)

### Canlı durum (test edilen)
- ✅ Vaka açma modalı açılıyor (`m-disease`)
- ✅ Vaka kapatma çalışıyor
- ❌ Tab-saglik'te vakalar `?` isimle görünüyor (disease_id eşleşmiyor veya openDet exception'a düşüyor)
- ❌ Gün ekleme çalışmıyor (renderCaseTimeline'a ulaşamıyor)
- ❌ Debug sarı kutu hiç görünmedi → `openDet` `renderCasesForAnimal`'a ulaşamıyor
- ✅ Supabase'den `diseases` ve `cases` verisi geliyor (curl ile doğrulandı)
- ✅ `getData` tek tanımlı, sorun değil

### Sonraki oturumda
- `openDet` içine try/catch + visible hata göstergesi ekle
- `openDet`'in tam olarak nerede durduğunu tespit et
- `renderCaseTimeline` Supabase direkt sorgu — `treatment_timeline` view erişimi doğrula
