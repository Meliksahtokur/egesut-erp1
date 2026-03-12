# EgeSüt ERP — SPEC v10
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
**🔜 UYGULANMADI** — `supabase/migrations/20260312000022_case_management.sql` hazır, Supabase'e verildi.

Uygulandıktan sonra bu satırı `✅ UYGULANDI` olarak güncelle.

---

## 2. SPRINT — SIRADAKI GÖREVLER

### 🔴 Şu An Yapılacak
| Item | Açıklama | Dosyalar |
|------|----------|----------|
| **CLN-01** | Migration 022'yi Supabase'e uygula | SQL Editor |
| **CLN-02** | Vaka açma UI: `diseases` dropdown (DB'den), `create_case()` RPC | forms.js, index.html |
| **CLN-03** | Vaka detay: gün + ilaç ekleme UI, `treatment_timeline` view | ui.js, forms.js |
| **CLN-04** | `drugs` ↔ `stok` bağlama UI (hangi ilaç hangi stok kalemi) | ui.js, forms.js |
| **CLN-05** | Vaka kapatma + hayvan kartında aktif vaka gösterimi | ui.js |

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
