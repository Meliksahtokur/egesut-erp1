# EgeSüt ERP — DB Schema Snapshot
> Çekilme tarihi: 2026-03-25 (MCP ile gerçek Supabase DB'den)
> Bu dosya repo migration'larından değil, canlı DB'den üretilmiştir.
> Migration'lar ile çelişirse **bu dosya doğrudur.**

---

## TABLOLAR

### hayvanlar
| Kolon | Tip | Nullable | Default |
|---|---|---|---|
| id | text | NO | — |
| kupe_no | text | YES | — |
| cins | text | YES | — |
| irk | text | YES | — |
| dogum_tarihi | date | YES | — |
| dogum_kg | numeric | YES | — |
| kesim_kg | numeric | YES | — |
| grup | text | YES | — |
| padok | text | YES | 'P1' |
| durum | text | YES | 'Aktif' |
| cikis_tarihi | date | YES | — |
| cikis_sebebi | text | YES | — |
| satis_fiyati | numeric | YES | — |
| created_at | timestamptz | YES | now() |
| cinsiyet | text | YES | — |
| anne_id | text | YES | — |
| baba_bilgi | text | YES | — |
| canli_agirlik | numeric | YES | — |
| boy | numeric | YES | — |
| renk | text | YES | — |
| ayirici_ozellik | text | YES | — |
| devlet_kupe | text | YES | — |
| kategori | text | YES | — |
| suttten_kesme_tarihi | date | YES | — |
| tohumlama_onay_tarihi | date | YES | — |
| tohumlama_durumu | text | YES | — |
| cikis_tipi | text | YES | — |
| notlar | text | YES | — |
| abort_sayisi | integer | YES | 0 |

### cases
| Kolon | Tip | Nullable | Default |
|---|---|---|---|
| id | uuid | NO | gen_random_uuid() |
| animal_id | text | NO | — |
| disease_id | uuid | NO | — |
| start_date | date | NO | CURRENT_DATE |
| status | text | NO | 'active' |
| notes | text | YES | — |
| created_at | timestamptz | YES | now() |
| closed_at | timestamptz | YES | — |

### treatment_days
| Kolon | Tip | Nullable | Default |
|---|---|---|---|
| id | uuid | NO | gen_random_uuid() |
| case_id | uuid | NO | — |
| day_no | integer | YES | — |
| treatment_date | date | NO | CURRENT_DATE |
| notes | text | YES | — |
| created_at | timestamptz | YES | now() |
| **treatment_time** | **time** | **YES** | **—** |

### drug_administrations
| Kolon | Tip | Nullable | Default |
|---|---|---|---|
| id | uuid | NO | gen_random_uuid() |
| treatment_day_id | uuid | NO | — |
| dose | numeric | NO | — |
| unit | text | NO | — |
| route | text | YES | — |
| notes | text | YES | — |
| created_at | timestamptz | YES | now() |
| drug_product_id | uuid | YES | — |
| stok_id | text | YES | — |
> ⚠️ `drug_id` kolonu YOK — repo migration 022 ile çelişiyor. Gerçek şema bu.

### diseases
| Kolon | Tip |
|---|---|
| id | uuid |
| name | text |
| category | text |
| created_at | timestamptz |

### drugs
| Kolon | Tip |
|---|---|
| id | uuid |
| name | text |
| created_at | timestamptz |
| description | text |

### drug_classes
| Kolon | Tip |
|---|---|
| id | uuid |
| drug_id | uuid |
| group_name | text |
| class_name | text |
| active_ingredient | text |
| created_at | timestamptz |

### drug_products
| Kolon | Tip |
|---|---|
| id | uuid |
| drug_class_id | uuid |
| brand_name | text |
| concentration | numeric |
| concentration_unit | text |
| default_route | text |
| default_unit | text |
| created_at | timestamptz |

### stok
| Kolon | Tip | Default |
|---|---|---|
| id | text | — |
| urun_adi | text | — |
| tur | text | — |
| birim_turu | text | — |
| birim | text | — |
| baslangic_miktar | numeric | 0 |
| esik | numeric | 0 |
| maliyet | numeric | 0 |
| notlar | text | — |
| created_at | timestamptz | now() |
| kategori | text | — |
| drug_product_id | uuid | — |

### stok_hareket
| Kolon | Tip |
|---|---|
| id | uuid |
| stok_id | text |
| tarih | timestamptz |
| tur | text |
| miktar | numeric |
| notlar | text |
| iptal | boolean |
| created_at | timestamptz |
| referans_tipi | text |
| referans_id | text |

### tohumlama
| Kolon | Tip | Default |
|---|---|---|
| id | uuid | gen_random_uuid() |
| hayvan_id | text | — |
| tarih | date | — |
| sperma | text | — |
| irk_bilgisi | text | — |
| tohumlayan | text | — |
| kontrol_tarihi | date | — |
| sonuc | text | 'Bekliyor' |
| deneme_no | integer | 1 |
| created_at | timestamptz | now() |
| hekim_id | text | — |
| dogum_tarihi | date | — |
| buzagi_kupe | text | — |
| abort_notlar | text | — |

### hastalik_log
| Kolon | Tip |
|---|---|
| id | uuid |
| hayvan_id | text |
| tarih | date |
| kategori | text |
| tani | text |
| siddet | text |
| semptomlar | text |
| ilac_stok_id | text |
| ilac_miktar | numeric |
| durum | text (default 'Aktif') |
| kapanis_tarihi | date |
| veteriner_notu | text |
| created_at | timestamptz |
| hekim_id | text |
| kapanma_tarihi | date |
| lokasyon | text |

### tedavi
| Kolon | Tip |
|---|---|
| id | uuid |
| hayvan_id | text |
| tarih | date |
| tani | text |
| ilac_stok_id | text |
| miktar | numeric |
| sut_yasagi_bitis | date |
| aktif | boolean |
| vaka_id | text |
| created_at | timestamptz |
| uygulama_yolu | text |
| hekim_id | text |
| bekleme_suresi_gun | integer |
| notlar | text |

### gorev_log
| Kolon | Tip | Default |
|---|---|---|
| id | uuid | gen_random_uuid() |
| hayvan_id | text | — |
| gorev_tipi | text | — |
| aciklama | text | — |
| hedef_tarih | date | — |
| tamamlandi | boolean | false |
| tamamlanma_tarihi | timestamptz | — |
| padok_hedef | text | — |
| stok_id | text | — |
| miktar | numeric | — |
| stok_dusuldu | boolean | false |
| kaynak | text | — |
| created_at | timestamptz | now() |
| parent_id | uuid | — |
| iptal | boolean | false |
| hekim_id | text | — |

### dogum
| Kolon | Tip |
|---|---|
| id | uuid |
| anne_id | text |
| tarih | date |
| yavru_cins | text |
| yavru_kupe | text |
| yavru_irk | text |
| dogum_tipi | text (default 'Normal') |
| created_at | timestamptz |
| hekim_id | text |
| dogum_kg | numeric |
| baba_bilgi | text |

### kizginlik_log
| Kolon | Tip |
|---|---|
| id | text |
| hayvan_id | text |
| tarih | date |
| belirti | text |
| notlar | text |
| olusturma | timestamptz |

### bildirim_log
| Kolon | Tip |
|---|---|
| id | text |
| hayvan_id | text |
| tip | text |
| mesaj | text |
| durum | text (default 'bekliyor') |
| erteleme_tarihi | date |
| olusturma | timestamptz |
| guncelleme | timestamptz |

### islem_log
| Kolon | Tip |
|---|---|
| id | text |
| tip | text |
| ana_hayvan_id | text |
| tarih | timestamptz |
| kullanici_notu | text |
| durum | text (default 'aktif') |
| geri_alma_tarihi | timestamptz |
| snapshot | jsonb |
| ref_id | text |
| ref_tablo | text |

### irk_esik
| Kolon | Tip | Default |
|---|---|---|
| id | text | gen_random_uuid() |
| irk | text | — |
| tohumlama_gun | integer | 365 |
| suttten_kesme_gun | integer | 60 |
| guncelleme | timestamptz | now() |
| kullanim_sayisi | integer | 0 |

### buzagi_takip
| Kolon | Tip |
|---|---|
| id | uuid |
| kupe_no | text |
| cinsiyet | text |
| irk | text |
| dogum_tarihi | date |
| anne_id | text |
| sut_kesme_tarihi | date |
| besi_satis_notu | text |
| created_at | timestamptz |

### hayvan_override
| Kolon | Tip | Default |
|---|---|---|
| kupe_no | text | — |
| pasif_mi | boolean | false |
| notlar | text | — |
| guncelleme_tarihi | date | CURRENT_DATE |

### cop_kutusu
| Kolon | Tip |
|---|---|
| id | text |
| kaynak_tablo | text |
| kaynak_id | text |
| veri | jsonb |
| silme_tarihi | timestamptz |
| otomatik_silme_tarihi | timestamptz (+30 gün) |
| geri_yuklendi | boolean |
| silme_sebebi | text |

---

## VIEW'LAR

### treatment_timeline
```sql
SELECT h.id AS animal_id, h.kupe_no,
  c.id AS case_id, c.status AS case_status, c.start_date AS case_start,
  dis.name AS disease, dis.category AS disease_category,
  td.id AS day_id, td.day_no, td.treatment_date,
  dp.id AS drug_id,
  COALESCE(dp.brand_name, s.urun_adi, '?') AS drug,
  da.id AS administration_id, da.dose, da.unit, da.route,
  da.notes AS admin_notes, da.stok_id
FROM treatment_days td
  JOIN cases c ON c.id = td.case_id
  JOIN hayvanlar h ON h.id = c.animal_id
  JOIN diseases dis ON dis.id = c.disease_id
  LEFT JOIN drug_administrations da ON da.treatment_day_id = td.id
  LEFT JOIN drug_products dp ON dp.id = da.drug_product_id
  LEFT JOIN stok s ON s.id = da.stok_id
```
> Migration 026 ile `td.treatment_time` sona eklendi (2026-03-25).

### hayvan_durum_view
Hayvanların yaş, tohumlama durumu, aktif hastalık sayısı, hesap_kategori (sut_icen/suttten_kesilmis/besi/duve_kucuk/duve_buyuk/sagmal) birleşik view'ı.

### stok_tuketim_view
`stok` + `stok_hareket` JOIN — `guncel_stok = baslangic_miktar - toplam_kullanim`

### tedavi_view
`tedavi` + `stok` JOIN — `ilac_adi, ilac_birim, ilac_kategori` ekler.

### tohumlanabilir_hayvanlar
`hayvan_durum_view` WHERE `tohumlama_durumu_hesap = 'tohumlanabilir'`

### gebelik_ozet_view, hastalik_istatistik_view, hayvan_durum_analizi
İstatistik view'ları.

---

## RPC'LER (public fonksiyonlar)

| Fonksiyon | Açıklama |
|---|---|
| `update_treatment_time(p_day_id uuid, p_treatment_time time)` | ✅ treatment_days.treatment_time günceller |
| `add_treatment_day(p_case_id, p_date)` | Yeni tedavi günü ekler |
| `add_drug_administration(p_day_id, p_drug_product_id, p_stok_id, p_dose, p_unit, p_route)` | İlaç uygulama kaydı |
| `remove_drug_administration(p_admin_id)` | İlaç kaydı siler, stok iade eder |
| `update_drug_administration(p_admin_id, p_dose, p_unit, p_route)` | İlaç kaydı günceller |
| `delete_treatment_day(p_day_id)` | Tedavi günü + ilaçları siler |
| `create_case(p_animal_id, p_disease_id, p_notes)` | Yeni vaka açar |
| `close_case(p_case_id)` | Vakayı kapatır |
| `hayvan_ekle(...)` | Hayvan ekle + küpe kontrol |
| `hayvan_guncelle(p_id, ...)` | Hayvan güncelle |
| `hayvan_not_ekle(p_hayvan_id, p_not)` | Hayvan notuna satır ekle |
| `dogum_kaydet(...)` | Doğum + buzağı + görevler |
| `tohumlama_kaydet(...)` | Tohumlama + görevler + sperma stok |
| `abort_kaydet(p_tohumlama_id, p_notlar)` | Abort kaydı |
| `hastalik_kaydet(...)` | Hastalık + tedavi + stok + görevler |
| `hastalik_guncelle(...)` | Hastalık kaydı güncelle |
| `hastalik_kapat(p_id)` | Hastalık kaydı kapat |
| `hastalik_sil(p_id)` | Hastalık + tedaviler + stok iade |
| `tedavi_ekle(...)` | Tedavi ekle + stok düş |
| `tedavi_guncelle(...)` | Tedavi güncelle + stok fark |
| `tedavi_sil(p_tedavi_id)` | Tedavi sil + stok iade |
| `kizginlik_kaydet(...)` | Kızgınlık kaydı |
| `kupe_musait_mi(p_kupe_no, p_devlet_kupe, p_hayvan_id)` | Küpe çakışma kontrolü |
| `irk_listesi()` | Irk listesi |
| `link_drug_to_stock(p_drug_id, p_stock_item_id)` | İlaç-stok bağla |

---

## ÖNEMLİ NOTLAR

- `drug_administrations.drug_id` **YOK** — eski migration 022'deki kolon silinmiş. `drug_product_id` ve `stok_id` kullanılıyor.
- `treatment_days.treatment_time` (time) **VAR** — migration 025 başarıyla uygulandı.
- `update_treatment_time` RPC **VAR** — JS tarafı çağırabilir.
- `stok.miktar` kolonu **YOK** — `stok_tuketim_view.guncel_stok` = `baslangic_miktar - SUM(stok_hareket.miktar)` hesabı kullanılıyor.
