# BUG-050: Duplikat Kontrol Mekanizmaları Haritası

**Tarih:** 2026-06-05
**Kaynak:** gitnexus_query + ast_grep_search + migration analizi

---

## 1. DB Seviyesi Kontrol Noktaları (RAISE EXCEPTION)

### A — tohumlama_kaydet (orijinal)
**Dosya:** `supabase/migrations/20260308000009_sperma_stok_fix.sql`

| Kontrol | Kod | Satır |
|---------|-----|-------|
| Hayvan var mı? | `RAISE EXCEPTION 'Hayvan bulunamadı: %', p_hayvan_id;` | 250 |
| Erkek mi? | `RAISE EXCEPTION 'Erkek hayvana tohumlama yapılamaz';` | 255 |
| Yaş ≥ 365 gün? | `RAISE EXCEPTION '12 aydan küçük hayvana tohumlama yapılamaz (% gün)', v_yas_gun;` | 262 |
| Zaten gebe mi? | `RAISE EXCEPTION 'Hayvan zaten gebe — önce gebeliği kapatın';` | 271 |
| İleri tarih? | `RAISE EXCEPTION 'Tohumlama tarihi ileri tarih olamaz';` | 276 |

### B — tohumlama_kaydet (ek_uygulama_stok ile REPLACE edilmiş)
**Dosya:** `supabase/migrations/20260526000003_ek_uygulama_stok.sql`

| Kontrol | Kod | Satır |
|---------|-----|-------|
| Hayvan var mı? | `RAISE EXCEPTION 'Hayvan bulunamadı: %', p_hayvan_id;` | 39 |
| Erkek mi? | `RAISE EXCEPTION 'Erkek hayvana tohumlama yapılamaz';` | 44 |
| Yaş ≥ 365 gün? | `RAISE EXCEPTION '12 aydan küçük hayvana tohumlama yapılamaz (% gün)', v_yas_gun;` | 51 |
| Zaten gebe mi? | `RAISE EXCEPTION 'Hayvan zaten gebe — önce gebeliği kapatın';` | 60 |
| İleri tarih? | `RAISE EXCEPTION 'Tohumlama tarihi ileri tarih olamaz';` | 65 |

**⚠️ DUPLICATE: A ve B aynı kontrolleri farklı migration'larda tekrar ediyor.** Migration B (`20260526000003`) orijinal migration A'daki (`20260308000009`) kontrolleri aynen kopyalamış. Bu duplikasyon idempotent pattern'in yan etkisi — her `CREATE OR REPLACE` tüm kontrolleri yeniden yazmak zorunda.

### C — dogum_kaydet
**Dosya:** `supabase/migrations/20260603000001_protokol_etken_kod.sql` (latest)

| Kontrol | Kod | Satır |
|---------|-----|-------|
| Anne var mı? | `RETURN jsonb_build_object('ok', false, 'mesaj', 'Anne bulunamadı');` | 163 |
| Küpe kayıtlı mı? | `RETURN jsonb_build_object('ok', false, 'mesaj', 'Bu küpe zaten kayıtlı: ' \|\| p_kupe);` | 168 |

Not: dogum_kaydet RAISE EXCEPTION değil, jsonb hata objesi döndürüyor (farklı pattern).

### D — Diğer RAISE EXCEPTION noktaları
| Mekanizma | Dosya | Ne kontrol ediyor |
|-----------|-------|-------------------|
| Stok yetersiz | `20260312000022_case_management.sql:181` | drug_administrations INSERT |
| Stok yetersiz | `20260331000032_vaccination_module.sql:115` | vaccination INSERT |
| Tedavi günü tamamlandı | `20260403000002_delete_treatment_day.sql` | DELETE prevention |
| Tedavi günü zaten tamam | `20260525000002_treatment_day_done.sql:36` | Duplicate completion |
| Sıralı tedavi | `20260525000002_treatment_day_done.sql:41` | Önceki günler tamam mı |
| görev bulunamadı | `31_kuru_donem_padok_id_fix.sql:28` | gorev_log lookup |

---

## 2. Trigger Seviyesi Kontroller

| Trigger | Dosya | Ne yapıyor |
|---------|-------|-----------|
| `fn_islem_log` | `20260303000005_triggers.sql` | Her tohumlama UPDATE'ini DOGUM_KAYDI veya ABORT_KAYDI olarak loglar |
| `fn_gebe_gorev_yarat` | `20260603000001_protokol_etken_kod.sql:237` | tohumlama INSERT'te sonuc='Gebe' ise ILERI_GEBE görevleri oluşturur |
| Tohumlama cycle guard | `20260522000002_tohumlama_cycle_iptal.sql` | Cycle geçişlerinde stale görevleri iptal eder |

---

## 3. Frontend Kontrol Noktaları

| Fonksiyon | Dosya:Satır | Ne kontrol ediyor |
|-----------|-------------|-------------------|
| `submitBirth()` | `forms.js:135` | Anne var mı, tarih ileri mi, küpe zorunlu |
| `submitInsem()` | `forms.js:254` | Sperma zorunlu, erişim/state validasyon |
| `tohSonuc()` | `forms.js:1068` | "Gebe" / "Doğum Yaptı" kayıtlarını değiştirmeyi engeller |
| `submitGebelikEkle()` | `forms.js:1240` | Hayvan seçimi + tarih validasyonu |
| `submitAnimal()` | `forms.js:90` (approx) | Küpe çakışma uyarısı |
| `_kupeKontrolEt()` | `forms.js:60` (approx) | Async küpe kontrol (devlet/kupe) |
| `submitKizginlik()` | `forms.js:~350` | Küpe + Tarih zorunlu |
| Frontend: `submitBirth()` | `forms.js:147` | `if (tarih > new Date().toISOString().split('T')[0])` — ileri tarih kontrolü |

---

## 4. Duplikasyon / Çakışma Tespitleri

| ID | Mekanizma 1 | Mekanizma 2 | Açıklama | Risk |
|----|-------------|-------------|----------|------|
| ÇAKIŞMA-1 | `20260308000009` tohumlama_kaydet kontrolleri | `20260526000003` tohumlama_kaydet kontrolleri | Aynı 5 kontrol iki kere yazılmış. Idempotent pattern'in doğal sonucu — gerçek bir çakışma değil, bakım yükü. | DÜŞÜK |
| ÇAKIŞMA-2 | Frontend `submitBirth()` validasyonu | RPC `dogum_kaydet` validasyonu | İkisi de anne/küpe kontrolü yapıyor ama frontend RAISE ile değil toast ile bildiriyor. | DÜŞÜK (defense-in-depth) |
| ÇAKIŞMA-3 | `fn_gebe_gorev_yarat` (trigger) | `gebelik_protokol_kontrol()` (RPC) | İkisi de gebe hayvanlara görev oluşturuyor. Trigger INSERT anında, RPC manuel/periyodik. Potansiyel duplicate görev oluşumu. | **ORTA** |
| ÇAKIŞMA-4 | `tohSonuc()` frontend | `tohumlama_kaydet` RPC kontrolleri | Frontend "Gebe" kaydını değiştirmeyi engelliyor; RPC de gebe kontrolü yapıyor. | DÜŞÜK |

---

## 5. Özet

- **Toplam kontrol noktası:** ~20 (5 DB RPC + 2 trigger + 6 frontend + 7 diğer)
- **Gerçek duplikasyon:** 1 adet (tohumlama_kaydet kontrolleri — idempotent pattern yan etkisi)
- **Potansiyel çakışma:** Gebelik trigger + RPC ikilisi duplicate görev oluşturabilir
- **Kontrol eksikliği:** dogum_kaydet'te CURRENT_DATE karşılaştırması yok (timezone'a duyarlı değil)
- **Refactor potansiyeli:** tohumlama_kaydet kontrolleri ortak bir helper fonksiyona çekilebilir

## 6. BUG-012 Örtüşme Notu

BUG-050, BUG-012 (gebelik protokol duplikasyon) ile aynı domain'de. BUG-012 kapsamında `ileri_gebe_gorev_kontrol` ve `laktasyon_kuru_kontrol` birleştirilmişti (`gebelik_protokol_kontrol`). Bu birleştirme başarılı olmuş — memory kaydına göre `gebelik_protokol_kontrol()` idempotent çalışıyor.
