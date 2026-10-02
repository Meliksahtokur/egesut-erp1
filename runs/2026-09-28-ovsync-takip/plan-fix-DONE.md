# plan-fix DONE — 2026-09-29

**Sonuç: TAMAM** — `docs/plans/2026-09-28-ovsync-takip-ekrani/plan.md` **v2** olarak yerinde düzeltildi
(17/17 bulgu uygulandı; K14+K15 yeni kapsamla işlendi; kod + demo tarayıcı yürüyüşüyle doğrulandı).
Commit/kod/DB yazılmadı (zarf gereği). Kırıntı: `.crumbs/ovsync-takip.jsonl` (4 kayıt).

## 17 bulgu kapanış özeti (birebir tablo plan.md'de "Review kapanış tablosu")

| # | Kapanış | Yer |
|---|---|---|
| 1 | 4 olay idempotent TABLO tetikleyicisi (tohumlama/pg_application_event/cases Ovsync/çıkış), neden kodlu; RPC gövdesine gömme kalktı | P3a |
| 2 | PG kapısı "Boş ata ve uygula" → `tohumlama_bos_ve_devam` tek transaction; eski iki-RPC zinciri kalktı | P2b + P9 |
| 3 | GEBE modu: `tohumlama_sonuc_gebe` çekirdeği + takip `GEBE_BULUNDU` | P2b + P8 |
| 4 | Birleşik kapı: tek RAISE payload + tek bottom-sheet + tek `p_onay` | P2b + P10 |
| 5 | GEBELIK_KONTROL Boş girişi SAHİP'le EKLENDİ (K15); jenerik kapanış kalktı | P8('muayene') + P9 + P3b guard |
| 6 | Bayrak kapalı: dry-run alanı + yazma `OZELLIK_KAPALI` + seçici açılmaz | P2b + P8 |
| 7 | ERTALE: `p_saat` düzenlenebilir (ön ayar önceki saat) + takip ≥21 g `TAKIP_UZADI` tek onay | P2b + P8 |
| 8 | KPA: `bekleyen_baslatma` toplam + `bekleyen_baslatma_takipte` ayrı; 🔔 eşitliği yalnız uyarılar alt kümesi | P1 + P6/P7 |
| 9 | XOR guard, `FOR UPDATE`, `TOH_SONUCLU`/`TAKIP_KAPALI` sözleşme, yarış testleri (T-72/T-73) | P2b + P12 |
| 10 | Son PG: TOPLU_ILAC `islem_log.snapshot.miktar`; "doz belirsiz" iddiası silindi | Gerçekler (b) + P2b |
| 11 | `gebelik_muayene_listele` VAR (20260925000002:287-324 + ACL :395-396); yanlış açık kalem silindi; S2 aynı küme CTE | P1 |
| 12 | Ground-truth: replay son-kazanan gövde+ACL doğrulaması kabul kriteri; yenileme manifest/sahip kapısı | P13 |
| 13 | farm_id §14: yalnız yeni nesne damgası + kolonlu kaynakta predikat; retrofit/iki-farm testi YOK | P1 + P2a |
| 14 | Kategori = K14 (sahip): GEBELIK_KONTROL+TAKIP_MUAYENE 🌱 Üreme; filtre hastalık-ad kümesi | P7 + T-57 |
| 15 | T-01..T-73 kapsama matrisi (katman sahipli: DB/PW/UNIT/İNSAN + sahip P) | plan.md matris |
| 16 | P2 → P2a(şema/çekirdek)+P2b(sarmal modlar); P3 → P3a(tetikleyiciler)+P3b(kapılar); kesin imzalar | madde yapısı |
| 17 | Kırmızı test iskeletleri ilgili P'nin ön adımı; P13 SIRALI en sonda | P4-P10 + P11 + P13 |
| copy | Muayene ekranı "Muayene tamam + …" (S-10; mockup-05 çelişkisi kapandı) | P8 |

## K14/K15 için eklenen / değişen P maddeleri

- **P1:** `kpa.bekleyen_baslatma_takipte`; satır alanı **`muayene_gorev_id`**; S2 CTE'si `gebelik_muayene_listele` birebir kriterleri (aynı küme — T-45).
- **P2a (yeni):** `takip_kapanis_nedeni` kolonu (`GEBE_BULUNDU` dahil), `_takip_gorev_kur`/`_takip_kapat` (idempotent, FOR UPDATE), muafiyet kolu, seed.
- **P2b (yeni):** `tohumlama_bos_ve_devam(p_tohumlama_id, p_muayene_gorev_id, p_secim ∈ {NULL,OVSYNC,PG,TAKIP,ERTALE,GEBE}, …)` — XOR guard, birleşik kapı, bayrak-kapalı, TAKIP_UZADI, GEBE modu (görev tamam → `tohumlama_sonuc_gebe` çekirdeği).
- **P3a/P3b (yeni):** 4 tetikleyici + `gorev_tamamla` guard (`MUAYENE_SONUC_GEREKLI`) + `p_takip_onay` onay-emri parametreleri.
- **P7:** K14 eşleme (`_katTipMap.ureme` +4 tip, `muayene`'den GEBELIK_KONTROL çıkışı; `_uremeVakaCaseIds` → {Ovsync, Kistik Over, Anoestrus} hastalık-ad kümesi, C3 sızıntı güveni korunur).
- **P8:** 'muayene' modu — iki görev tipi AYNI ekran (Gebe / Boş→seçici / Ertele; GEBELIK_KONTROL'de Takibe bırak da).
- **P9:** GEBELIK_KONTROL özel tamamlama akışı (exclusion + `_muayeneSonucAc`); PG kapısı gövdesi değişti (tek RPC).
- **P10:** birleşik TAKIP_ACIK+PG_KAPI sheet.
- **P11/P12:** kırmızı-önce sırası + K15 senaryoları (guard, ekran özdeşliği, Gebe, erteleme saati, ≥21g).

## Yürünen akışlar + kanıt yolları

`runs/2026-09-28-ovsync-takip/akis-yuruyus/` (NOTLAR.md + PNG'ler; Playwright 1.58.2 docker, demo, **salt-okuma** — tek confirm dismiss, örnek-payload render; hiçbir yazma RPC çağrılmadı):
- **A1 Tohumlama sonuç modalı** — `W4-tohumlama-sonuc-modali.png` (radios görünür; Boş confirm dismiss → RPC yok).
- **A2 PG kapısı** — `W5-pg-kapisi.png` (gerekçe + "Boş ata ve uygula"; mevcut iki-RPC zinciri kod kanıtıyla).
- **A3 GEBELIK_KONTROL tamamlama** — `W3-gebelik-kontrol-gorev-detay.png` (**sonuç SORULMADAN jenerik butonla kapanabiliyor — K15'in değiştirdiği nokta; "35. Gün" görevi = tohumlama_kaydet üreticisi**).
- **A4 Dashboard muayene listesi** — `W1-dashboard.png`, `W2-sessiz-muayene-sheet.png` (liste 0 → band yok; satır → hayvan detayı).
- Plan.md başında "Mevcut akış haritası" bölümü: 4 mermaid + ekran→fonksiyon→RPC→tablo zincirleri + kanıt yolları.

## KATALOG GÜNCELLEME listesi (test-senyolari.md sahibine — plan düzeltmedi)

T-04 (K15 tam set + ekran özdeşliği) · T-05 (+Gebe) · T-39 (birleşik ekran + ertele) · S-10 (kapandı) · T-61 (§14: iki-farm testi Faz 2) · yeni K15 senaryoları (gorev_tamamla guard, GEBELIK_KONTROL erteleme, ekran özdeşliği, Gebe yolları, cron entegrasyonu, iki üretici tutarlılığı) · kapsam-dışı notu (satır 681) güncellemesi. İNSAN-UI 12 zaten uyumlu.

## Yeni SPEC SORULARI (sahibe — uydurma cevap yok)

1. **GEBELIK_KONTROL'ün iki üreticisi:** `tohumlama_kaydet` +21/+35g (20260521000003; demo'da yaşıyor) ↔ cron +40g (§18.13). +21/+35g üretimi kapatılır mı / cron'a devrolur mu / kalır mı? (Plan varsayımı: kalır; guard+ekran tip bazlı.)
2. **S2 "muayene vakti" satırında görev doğmamışsa** aksiyon: hayvan detayı (varsayım) mı, görev anında doğurma mı?
3. **GEBELIK_KONTROL jenerik erteleme butonu:** kural seed'i eklenmiyor → buton yok; erteleme yalnız sonuç ekranından. Onay?
4. **Dashboard 40g bandı satır tıklaması** hayvan detayında kalıyor (varsayım); birleşik muayene ekranına bağlansın mı?

## Notlar

- Zarfın dosya listesi dar olduğundan kalıcı BOARD.md güncellenmedi; kırıntı JSONL'una kayıt düşüldü (kayıt yüzeyi).
- Okuma alt-ajanı 1 adet (test kataloğu taraması, sonnet); süreç limitleri aşılmadı.
- Saat 06:38–07:25 çalışma penceresi (GLM durma saati 09:00 öncesi tamamlandı).
