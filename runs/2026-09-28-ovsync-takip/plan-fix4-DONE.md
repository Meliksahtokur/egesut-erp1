# DONE — plan-fix4: luna re-review 2 (plan v4 → v5)

**Sonuç: TAMAM** — 7/7 kalem işlendi; `docs/plans/2026-09-28-ovsync-takip-ekrani/plan.md` başlık v5.
Salt-okuma turu: yalnız plan.md + bu DONE + kırıntı yazıldı; commit/kod/DB/`.ss/` dokunulmadı.

## Kalemler (1–7)

1. **C3/D5/#9 (KRİTİK) — MK9 genel sözleşmesi: TAMAM.** DEGISMEZ 13 olarak Global Constraints'e girdi (hayvan İLK `FOR NO KEY UPDATE` → tohumlama → vaka/seans → görev; toplu `ORDER BY id`; advisory lock YOK; v4 sırası İPTAL). P2a/P2b/P3b'deki `tohumlama → hayvanlar → gorev_log` ifadeleri MK9'a çevrildi (T-72 matris satırı dahil). `start_first_service_protocol` düzeltmesi ayrı alt madde + kesin gövde tarifi (20260925000017:44→:62 bölgesi: görev KİLİTSİZ okunur → hayvan `FOR NO KEY UPDATE` İLK → görev kilit + yeniden doğrulama). MK9 uyum tablosu kaynaktan ÖLÇÜLDÜ (aşağıda) — uyumsuz tek satır: start_first_service_protocol (madde yapıldı). Çapraz iki-oturum deadlock provası kabul kriteri (T-72b — P2b/P3b kabul + kapsama matrisi).
2. **C1/D1/kalem 11 — normatif çözücü: TAMAM.** P2b çekirdek yazan taraf: kesin SQL (`tip='TOHUMLAMA_SONUC' AND ref_tablo='tohumlama' AND ref_id=… AND durum IS DISTINCT FROM 'geri_alindi' AND snapshot->>'iptal_sebep'='bos' ORDER BY tarih DESC, id DESC LIMIT 1`) + `AT TIME ZONE 'Europe/Istanbul'::date` yerel takvim günü; `fmtTarih` ilk-10-kesim YASAĞI; bulunamazsa NULL (sessiz varsayılan değil). P9 UI ikizi (aynı seçim + normalize); P11 üç vaka testi (geri_alindi dışlama / çoklu kayıt / UTC gece yarısı). IDB doğrulaması: `islem_log` `select('*')` tam sayfalı çekiliyor → `durum`/`ref_id`/`tarih` IDB'de mevcut [CONFIRMED js/api.js:30-35 (TABLES), 535-546 (_fetchIslemLogTumu)].
3. **C2/D4 — bulk imza sözleşmesi: TAMAM.** P3b kesin imza tablosu (eski → yeni, 7 RPC): `bulk_ilac` + `p_takip_onaylar text[] DEFAULT '{}'` (`p_pg_onaylar` dizi deseni [20260923000004:361]), `vaka_toplu_ac` + `p_takip_onaylar text[]`; tekil yollar (hizli_uygulama/seans_tamamla/start_first_service_protocol/create_case/kizginlik_vaka_ac) + `p_takip_onay bool`. Retry YALNIZ onaylı id'leri `ORDER BY id` ile kilitler (MK9 toplu-yol hükmü; `v_animal_ids_calisma` deseni korunur) ve uygular; stok düşümü `v_success`'ten (mevcut `UPDATE stok … p_miktar * v_success` değişmez); dizi `p_animal_ids` alt kümesi değilse `TAKIP_ONAY_KUME_UYUMSUZ` red. P10 retry güncellendi (`p_takip_onaylar=[id…]`).
4. **C4/#16 — `kizginlik_vaka_ac` kapıda: TAMAM.** İmza tablosuna girdi (+`p_takip_onay`); (g) bloğunda v4 dışlama gerekçesi ÇÜRÜTÜLDÜ (ölçüm: UI sorun listesi '💊 PG Protokolü' öntanımlı + '+ Serbest Giriş' keyfi `p_tani` [js/ui.js:5655-5662]; rpc `sorunVakaAc` [js/ui.js:5737-5742]). TAKIP_ACIK onayı aynı desen (create_case/vaka_toplu_ac ile); P10 UI noktası + kabul provası; P12 senaryosu; kapsama matrisi satırı.
5. **C5 — imza geçişi tablosu: TAMAM.** P3b'de: her imza-değişen RPC için (1) eski overload `DROP FUNCTION` (kalıp 20260923000004:84-89,193-195,359-361; 20260906120000:250-286,749), (2) ACL yeniden (REVOKE PUBLIC/anon + GRANT authenticated,service_role), (3) PostgREST negatif test (eski imza → PGRST204; anon EXECUTE yok; yeni imza çalışır — T-73b). P13 ground-truth uyarı listesi büyütüldü.
6. **C6 — farm_id envanteri: TAMAM (ölçüldü).** P1/P2b'nin dokunduğu 16 tablo demo `information_schema` ile ÖLÇÜLDÜ (aşağıda): yalnız `pg_application_event` farm_id TAŞIR → P2b dry-run `son_pg` sorgusunda `farm_id = public.current_farm_id()` filtresi ZORUNLU (index uyumlu); kolon taşımayan 15'e predikat/damga YOK (§14); P1 `pg_application_event` okumaz → P1'e filtre düşmez (netliğe bağlandı); (f) bloğu genişletildi, T-61 güncellendi.
7. **Kapanış tablosu + matris + izlenebilirlik + başlık: TAMAM.** "v5 kapanış" sütunu eklendi (19 satır); kapsama matrisine T-72b / C1 üç-vaka / C4 kızgınlık / C5 PostgREST satırları + T-61/T-72 güncellemeleri; izlenebilirliğe "§10f / re-review 2 C1–C6 (v5)" satırı; KATALOG GÜNCELLEME listesine 15. madde; başlık v5; SPEC ÇELİŞKİLERİ #5 (çelişki YOK).

## MK9 uyum tablosu (kaynak ölçümü — plana P3b'de işlendi)

| Yol | Ölçülen kilit deseni [kaynak] | Hüküm | İş |
|---|---|---|---|
| `tohumlama_kaydet` | hayvanlar `FOR NO KEY UPDATE` [20260923000005:327] → tohumlama `FOR UPDATE` [:373] | UYUMLU | yok |
| `seans_tamamla` | hayvan kilitsiz çöz → hayvanlar `FOR NO KEY UPDATE` [20260923000004:225] → seans/tdu `FOR UPDATE` [:232] | UYUMLU (MK9 kaynağı :43-46) | yok |
| `hizli_uygulama` | hayvanlar KİLİTSİZ okuma [20260923000004:106] | kilit yok → ihlal yok | preflight eklenir, kilit eklenmez |
| `bulk_ilac` | satır kilidi yok; sıralı döngü `v_animal_ids_calisma` [:455-458] + alt-transaction [:461-496] | kilit yok → ihlal yok | C2 retry: onaylananlar `ORDER BY id` kilidi |
| `start_first_service_protocol` | gorev_log `FOR UPDATE` [20260925000017:44] → hayvanlar `FOR UPDATE` [:62] | **İHLAL** | P3b düzeltme tarifi |
| `create_case`/`_vaka_ac_tek` | satır kilidi yok [20260906120000:191-250] | kilit yok → ihlal yok | `p_takip_onay` |
| `vaka_toplu_ac` | satır kilidi yok [:275+] | kilit yok → ihlal yok | `p_takip_onaylar text[]` |
| `kizginlik_vaka_ac` | satır kilidi yok [20260526000002:15-53] | kilit yok → ihlal yok | C4: kapıya girer |
| `tohumlama_bos_ve_devam` (yeni) | — | MK9 sırasıyla yazılır | P2b |

## C6 envanter ölçüm çıktısı (demo DB, information_schema, salt-okuma, 2026-09-29)

```
table_name              | kolon | farm_id
cases                   |    13 |      0
diseases                |     4 |      0
gorev_log               |    22 |      0
hayvanlar               |    34 |      0
islem_log               |    12 |      0
pg_application_event    |    16 |      1   ← TEK farm_id'li tablo
protokol_ayar           |     7 |      0
protokol_instance       |    10 |      0
sablon_hastalik_eslem   |     4 |      0
stok                    |    12 |      0
stok_hareket            |    10 |      0
tedavi_sablonu          |     8 |      0
tohumlama               |    21 |      0
treatment_day_uygulamalar|    18 |      0
treatment_days          |    12 |      0
uygulama_log            |    10 |      0
```
(16/16 tablo döndü — liste-dışı tablo yok; v4 (f) ölçümündeki 8 tabloyla tutarlı, 8 tablo genişletildi.)

## Yeni SPEC SORULARI

**YOK** — v5 turunda SPEC (design.md v4 + §10f) ile çelişki çıkmadı; §10f mimar kararları plana birebir işlendi (SPEC ÇELİŞKİLERİ #5).

## Kanıtlar

- Plan v5: `docs/plans/2026-09-28-ovsync-takip-ekrani/plan.md` (başlık v5; DEGISMEZ 13; P3b imza/uyum/C5 tabloları; (f)/(g) v5 ölçümleri; v5 kapanış sütunu).
- Kaynak ölçümleri: `supabase/migrations/20260923000005:327,373`; `20260923000004:43-46,89,106,195,225,232,361,455-496,500-502`; `20260925000017:14,44-62`; `20260906120000:191,251,275`; `20260526000002:15`; `js/api.js:24-35,535-546`; `js/ui.js:5651-5662,5728-5742`.
- Kırıntılar: `.crumbs/ovsync-takip.jsonl` (gate + MK9 ölçümü + C6 ölçümü, role "lead").
