# EgeSüt ERP — SPEC v11
> Operasyonel rehber. Mimari kararlar → ARCHITECTURE.md
> Son güncelleme: 2026-03-12

---

## 0. OTURUM PROTOKOLÜ

1. SPEC'i oku → sıradaki item'ı söyle → onay al → başla
2. Değişiklik formatı: SEARCH/REPLACE veya inline python. Tam dosya sadece büyük refactor'da.
3. Migration her zaman idempotent. Yeni tablo = RLS + SECURITY DEFINER.
4. Oturum sonu SPEC güncelle, push et.

---

## 1. MEVCUT DURUM

### Migration 022 uygulandı mı?
** ✅  UYGULANDI** — `supabase/migrations/20260312000022_case_management.sql` hazır, Supabase'e verildi.

Uygulandıktan sonra bu satırı `✅ UYGULANDI` olarak güncelle.

---

## 2. SPRINT — SIRADAKI GÖREVLER

### ✅ Tamamlanan
| Item | Açıklama |
|------|----------|
| **CLN-01** | Migration 022 Supabase'e uygulandı |
| **CLN-02** | `m-case` modal HTML'e eklendi, `diseases` dropdown DB'den, `create_case()` RPC bağlandı, `openMWithHayvan` + `acMap` güncellendi |
| **CLN-03** | Vaka detay UI zaten tamamlanmıştı (renderCaseTimeline, submitAddDay, submitAddDrug, caseIlacFormAc). Eksik olan `remove_drug_administration` RPC → Migration 023 ile eklendi |

### 🔴 Şu An Yapılacak
| Item | Açıklama | Dosyalar |
|------|----------|----------|
| **CLN-04** | `drugs` ↔ `stok` bağlama UI (hangi ilaç hangi stok kalemi) | ui.js, forms.js |
| **CLN-05** | Hayvan kartında aktif vaka gösterimi (CLN-02'de kısmi var, tamamla) | ui.js |

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
| T-07 İlaç yönetimi (eski sistem) | CLN serisi tamamlanınca re-evaluate |
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

---

## 4. OTURUM NOTLARI — 2026-03-13

| Değişiklik | Durum |
|------------|-------|
| Migration 022 Supabase'de mevcut (diseases, cases, drugs, treatment_days tabloları var) | ✅ |
| api.js: TABLES, pullTables, RPC_TABLES güncellendi | ✅ |
| api.js: pullFromSupabase → pullTables bazlı refactor | ✅ |
| api.js: DB_VER 9 | ✅ |
| forms.js: loadDiseasesDropdown eklendi | ✅ |
| index.html: m-vaka-ac modali eklendi | ✅ |
| index.html: script sırası api→ui→forms→app yapıldı | ✅ |
| ui.js: tab-saglik Vaka Aç butonu eklendi | ✅ |
| **AÇIK SORUN:** Sayfada `loadDash is not defined` hatası — script sırası değişikliğine rağmen devam ediyor, tarayıcı cache'i temizlenince düzelecek mi test edilmedi | 🔴 |

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
| Migration 023 | `remove_drug_administration`: silme değil iptal — ledger `iptal=true`, sonra `DELETE drug_administrations` |
