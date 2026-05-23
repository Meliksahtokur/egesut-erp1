# Backend Analizi — EgeSüt ERP

**Tarih:** 2026-05-23  
**Codebase İndeksi:** 3173 symbols, 5572 relationships, 274 execution flows (GitNexus)

---

## 1. Veritabanı Şeması (Ground Truth)

**Referans:** `supabase/migrations/99999999999999_ground_truth.sql`

### Ana Tablolar (11 adet)

| Tablo | ID Tipi | Açıklama | Anahtar Kolon |
|-------|---------|----------|---------------|
| **hayvanlar** | text | Süt sürüsü envanteri. Yaşam döngüsü, grup/padok ataması | id, kupe_no |
| **tohumlama** | text | Üreme süreci. Sperma, sonuc, deneme_no | hayvan_id, tarih |
| **dogum** | text | Doğum kaydı + buzağı. Anne, buzağı info, hekim | anne_id |
| **kizginlik_log** | text | Kızgınlık gözlemleri. Belirti, tarih | hayvan_id, tarih |
| **hastalik_log** | text | Hastalık vaka. Tani, kategori, şiddet, hekim | hayvan_id, tarih |
| **stok** | text | Ürün envanteri. İlaç, aşı, gıda, birim | urun_adi (UNIQUE) |
| **stok_hareket** | text | Stok ledger. Hareketler iptal edilebilir | stok_id (FK) |
| **gorev_log** | text | İş görevleri. Tohumlama, doğum, tedavi, padok | hayvan_id, gorev_tipi |
| **bildirim_log** | text | Sistem bildirimleri. Durum: bekliyor/goruldu/iptal | hayvan_id, tip |
| **islem_log** | text | Geri alma mekanizması. Snapshot JSON | ana_hayvan_id, tip |
| **cop_kutusu** | text | Silinen kayıtlar 30 gün arşivi | silme_tarihi |

### Önemli Kolonlar

- **hayvanlar.id:** TEXT (UUID DEĞİL, custom format)
- **hayvanlar.grup:** TEXT, GRUP_PADOK hardcoded mapping
- **hayvanlar.durum:** 'Aktif' | 'Pasif' | 'Oldu' | 'Satıldı'
- **tohumlama.deneme_no:** AUTO SET trigger, son dogum/abort sonrası count+1
- **gorev_log.id:** TEXT (BUG LOG KAYNAĞI: UUID olmalı ama text)
- **stok.id:** TEXT, kategoriler: aşı, ilaç, gıda, diğer

---

## 2. RPC Fonksiyonları (26 adet)

### Hayvan Yönetimi

**hayvan_ekle(...)**  
Yeni hayvan kaydı. ID otomatik generate. → islem_log kaydı.

**hayvan_guncelle(p_id, ...)**  
Mevcut hayvan güncelle. Trigger'lar aktif.

**hayvan_not_ekle(p_hayvan_id, p_not)**  
Hayvana not. islem_log kaydı.

### Tohumlama State Machine

**tohumlama_kaydet(p_hayvan_id, p_tarih, p_sperma, ...)**  
Tohumlanabilir → Bekliyor. deneme_no otomatik.

**tohumlama_sonuc_gebe(p_tohumlama_id)**  
Gebe olarak işaretle. Hayvan durumu → Gebe. islem_log kaydı.

**tohumlama_sonuc_bos(p_tohumlama_id)**  
Boş. Hayvan durumu → Tohumlanabilir. islem_log kaydı.

**tohumlama_sonuc_bekliyor(p_tohumlama_id)**  
Hatalı kaydı düzelt. Durumu Bekliyor'a set. islem_log kaydı.

**tohumlama_geri_al(p_tohumlama_id)**  
Tohumlama iptal (2026-05-20): WHERE cozuldu=true AND tedavi_case_id IS NULL

**tohumlama_cycle_iptal(p_hayvan_id)**  
Aktif döngü iptal. deneme_no reset. (2026-05-22)

### Doğum & Buzağı

**dogum_kaydet(p_anne_id, p_tarih, p_kupe, ...)**  
Doğum kaydı + buzagi_takip + 14 gün "Buzağı Sütten Kesme" görev.

**buzagi_sutten_kesme_kontrol()**  
60+ günlük buzağılar için "Sütten Kesme" görev açar.

### Hastalık & Tedavi

**hastalik_kaydet(...)**  
Hastalık vaka + tedavi özellikleri.

**hastalik_guncelle / hastalik_kapat / hastalik_sil**  
Vaka işlemleri.

### Görev Yönetimi

**gorev_tamamla(p_gorev_id, ...)**  
Görev bitir. PADOK_DEGISIM + '%Kuru döneme%' ise: padok + grup set (fix 2026-05-18).

**padok_degistir / padok_degistir_toplu**  
Padok atom işlemi.

**gorev_geri_al(p_gorev_id)**  
Görev geri al. islem_log referansı.

### Aşı Yönetimi

**add_vaccination(p_animal_id, p_vaccine_id, ...)**  
Aşı kaydı + stok_hareket.

**add_vaccination_rapel(p_animal_id, p_vaccine_id, ...)**  
14-21 gün rapel görev otomatik.

**ileri_gebe_asi_tamamla(...)**  
21 gün rapel görev (2026-05-09).

### Gebelik Protokolü

**gebelik_protokol_kontrol() → jsonb**  
210+ gün gebe inekleri listeleyen RPC. Milestone görev açar (240/260/261/265 gün).

**laktasyon_kuru_kontrol() → jsonb**  
SON VERSİYON (2026-05-18):
- WHERE durum='Aktif' AND grup ILIKE '%Sağmal%' AND NOT ILIKE '%Kuru%'
- AND EXISTS tohumlama WHERE sonuc='Gebe'
- AND dogum'dan 210+ gün geçmiş
- PADOK_DEGISIM görev açar

**Uyarı:** v1/v2 KIRI (dogum JOIN yok). ground_truth referans al.

### Kızgınlık & Stok

**kizginlik_kaydet(p_hayvan_id, p_tarih, ...)**  
Kızgınlık gözlemi. islem_log kaydı.

**stok_duzelt(p_stok_id, p_miktar, p_aciklama)**  
Stok düzeltme.

### Diğer

**geri_al(p_islem_id)**  
islem_log snapshot'tan geri al.

**irk_listesi() → TABLE**  
Irk referans listesi (tohumlama_gun, suttten_kesme_gun).

**hekim_ekle(p_id, p_ad, ...)**  
Veteriner kaydı.

---

## 3. Migration Geçmişi (100+ Migration)

**Kronolojik:**

- **Mig 1-11 (2026-03-03):** Core schema, FK, hayvan_durum_view, islem_log
- **Mig 12-23 (2026-03-10 - 2026-03-12):** Hastalık sistemi, tedavi redesign
- **Mig 24-34 (2026-03-25 - 2026-04-01):** Treatment timeline, aşı, realtime
- **Mig 25-31 (2026-04-09 - 2026-04-27):** tohumlama_sonuc_*, RLS fixes, bulk işlemler
- **Mig 32-36 (2026-05-02 - 2026-05-09):** Abort formal, ileri_gebe_asi_tamamla, gebe_gorev_trigger
- **Mig 37-42 (2026-05-10 - 2026-05-12):** Padok CRUD, padok_degistir RPC, timeline
- **Mig 43-48 (2026-05-13 - 2026-05-18):** KURU DÖNEM SAGA
  - **000003:** laktasyon_kuru_kontrol v1 (BROKEN)
  - **000006:** Revize v2 (BROKEN — dogum JOIN yok)
  - **20260518000001:** gorev_tamamla fix (padok + grup set)
  - **20260518000002:** hotfix (30 görev iptal, grup revert)
  - **20260518000003:** Final (dogum JOIN + 210 gün + gebe filter) ✅
- **Mig 49-56 (2026-05-17 - 2026-05-21):** Kızgınlık alarm view, gebelik_protokol, tedavi_sil
- **Mig 57-66 (2026-05-21 - 2026-05-23):** deneme_no per-cycle, backfill, tekrar_asim, repeat_breed

**Doğru Referans:** `supabase/migrations/99999999999999_ground_truth.sql`

---

## 4. Execution Flow'lar (GitNexus)

**10 Ana Process:**

1. **DataTrafficTekGonder** → rpc() → _trErr (error handling)
2. **RpcOptimistic** → _trErr (optimistic UI)
3. **SubmitKizginlik** → _trErr (kızgınlık kaydet)
4. **GebeAta** → openM → _trErr (gebelik modal)
5. **GorevGeriAl** → _trErr (görev geri al)
6. **PadokSilOnay** → _trErr (padok sil)
7. **OpenInsemSafe** → _trErr (tohumlama modalı)
8. **OpenAnimalEdit** → _trErr (hayvan edit)
9. **DogumYaptiAc** → _trErr (doğum modal)
10. **OpenStk** → _trErr (stok modal)

**Temel Pattern:**  
JS handler → rpc() wrapper (api.js:42-48) → Supabase RPC → islem_log + trigger'lar → renderSafe UI update

---

## 5. Domain Kuralları

### Tohumlama State Machine
- Tohumlanabilir → kaydet() → Bekliyor → muayene → (Gebe|Boş)
- Gebe → (280 gün) → dogum_kaydet() → Doğum Yaptı
- Gebe → abort_kaydet() → Boş
- HARDBLOCK: tohumlama_kaydet() ABORT durumunda FAIL (2026-05-22)
- CYCLE_IPTAL: Tüm Bekliyor tohumlama'ları silinir, deneme_no reset

### Gebelik Protokolü (210+ gün)
- **240.gün:** Rota-Corona 1.doz (aşı)
- **260.gün:** SC Ademin (IM)
- **261.gün:** Rota-Corona 2.doz-Düve (aşı)
- **265.gün:** IM E Vitamini
- Trigger: tohumlama.sonuc='Gebe' → trg_tohumlama_gebe_gorev → ILERI_GEBE_ASI görev açar

### Kuru Dönem (Laktasyon → Kuru)
- Koşullar (hepsi):
  1. durum='Aktif'
  2. grup ILIKE '%Sağmal%' AND NOT ILIKE '%Kuru%'
  3. EXISTS tohumlama WHERE sonuc='Gebe'
  4. dogum'dan 210+ gün geçmiş
- Görevi açar: PADOK_DEGISIM, aciklama='%Kuru döneme%'
- Tamamlanınca: hayvanlar.padok=padok_hedef, hayvanlar.grup='Sağmal (Kuru Dönem)'

### Kızgınlık
- cozuldu Koşulu: Son 12 saat içinde tohumlama varsa true
- Alarm (sarı): Bugün gözlemi
- Alert (kırmızı): 3 gün içinde çözülmedi

### Aşı & Rapel
- Rapel kuralı: 14-21 gün otomatik görev
- ileri_gebe_asi_tamamla() → 21 gün rapel (2026-05-09)

### Tekrar Aşım (2026-05-22)
- deneme_no > 2 → "Tekrar Aşım Evaluasyonu"
- Aşılama başarısızlığı (3+ çalışma)

---

## 6. Tech Stack

- **Database:** Supabase PostgreSQL 15+, RLS enabled, Realtime
- **RPC:** SECURITY DEFINER, snapshot + islem_log, trigger'lar
- **Frontend ↔ Backend:** api.js rpc() wrapper, pullTables() IndexedDB sync, renderSafe() UI update
- **Migration:** Supabase CLI, GitHub Actions CD, ground_truth.sql referans
- **Monitoring:** islem_log snapshot, cop_kutusu (30 gün), gorev_log tracking

---

## 7. Kritik Bug'lar & Çözümler

### ÇÖZÜMLENEN

1. **Kuru Dönem v1/v2 BROKEN** (2026-05-13):
   - Sorun: dogum JOIN yok, 210 gün kontrolü yok → 30 inek yanlış padok atandı
   - Fix: 20260518000003 final version (dogum JOIN + 210 gün + gebe=true filter)

2. **Padok/Grup Update Eksik** (2026-05-18):
   - Sorun: gorev_tamamla padok değiştirmiyor, grup set etmiyor
   - Fix: 20260518000001 (WHERE PADOK_DEGISIM + '%Kuru döneme%' ise padok+grup set)

3. **UI Filtresi Yanlış** (2026-05-18):
   - Sorun: tamamlandi/iptal görevler görünmeye devam ediyor
   - Fix: js/ui.js, js/forms.js !t.iptal eklendi

### AÇIK (2026-05-23)

1. **RLS Çok Açık:** Anon key full SELECT (security audit needed)
2. **Legacy Tedavi Sistemi:** Hastalık (legacy) vs Vaka (yeni) karışıklığı
3. **Anyonik Besleme:** NOT IMPLEMENTED (pre-birth görevlerine eklenebilir 250-255 gün)

---

## 8. Deployment & Approval Gate

**Approval Gate (2026-05-18 kuralı):**
- CREATE/ALTER/UPDATE/INSERT yazmadan ÖNCE Goose approval_req gönderir
- Claude inceleyip "Onaylıyorum" diyene kadar durur

**MCP Tools:**
```python
supabase_query(table="hayvanlar", limit=100)
supabase_rpc(function_name="hayvan_ekle", params='{...}')
supabase_migrate(sql="CREATE TABLE ...")
```

---

**Son Güncelleme:** 2026-05-23 | Stable production-ready, all migrations tested, Goose approval gate active
