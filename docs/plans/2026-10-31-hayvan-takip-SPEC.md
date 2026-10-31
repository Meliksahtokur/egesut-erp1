# Hayvan Takip (📌 Takipte) — SPEC

- **Tarih:** 2026-10-31
- **Durum:** Sahip incelemesinde
- **Dal:** `hayvan-takipte`, taban `5d3f6a3`
- **Yol:** Architectural (aynı anda birden çok takip kararıyla yükseldi)
- **Model:** Plan, DB ve frontend opus high; Muse ve sonnet yok (sahip, 2026-10-31)

Satır numaraları taban commit'e aittir; plan yazılırken yeniden doğrulanır. Şema bilgileri migration dosyalarından gelir. Canlı şema, DB işinden önce ayrıca doğrulanır.

## 1. Amaç

Sahip, herhangi bir sebeple yakından izlemek istediği hayvanı kartından takibe alır. Takipteki hayvan dashboard'da en başta görünür, böylece unutulmaz. Takibe bağlı muayene planlanabilir; muayene sonucu takibin sürüp sürmeyeceğini belirler.

### Başarı ölçütü

Dashboard'a bakan kişi ilk bakışta şunları görür: hangi hayvan, hangi sebeple, kaç gündür takipte.

### Kapsam dışı

- Takibin üreme akışlarını etkilemesi (Ovsync, sessiz liste, tohumlama uygunluğu)
- Otomatik takip açma
- Sistem görevlerine bağlama (ilaç, Ovsync, bakım görevleri)
- Sebep ile hastalık arasında eşleme
- Toplu takip açma ve kapatma
- Çevrimdışı kuyruk
- Sebep istatistikleri ekranı

## 2. Mevcut "takip" kavramlarıyla ilişki

| Kavram | Nasıl açılır | Bu işle ilişkisi |
|---|---|---|
| `TAKIP_MUAYENE` (§18.15) | Boş sonrası "Takibe bırak" | Dokunulmaz. Yeni tip bunun kontrollerine girmez. |
| Ovsync ekranındaki "🔍 takipte" | Yukarıdakinin rozeti | Dokunulmaz. Yeni özellik görsel olarak 📌 ile ayrılır. |
| Sessiz hayvan takibi (§4) | Sistem hesaplar | İlişkisiz. |

## 3. Sahip kararları

| No | Karar |
|---|---|
| K1 | Bir hayvanda aynı anda birden çok takip olabilir. |
| K2 | Sebep = hazır liste + serbest metin. Başlangıç listesi: Topallık, Süt düşüşü, Zayıflama, İştahsızlık, Diğer. |
| K3 | Dashboard'da hayvan başına tek satır; sebepler yan yana; en eski açık takip üstte. |
| K4 | Kapatırken pencere: tek tek seçim ya da tümü, isteğe bağlı not. |
| K5 | Hayvan sürüden çıkınca bütün takipler kapanır. |
| K6 | Elle tek hayvanlık vaka açılınca açık takipler sorulur; hiçbiri işaretli gelmez, kendiliğinden kapanmaz. |
| K7 | Takibe bağlı, elle planlanan muayene görevi olur. |
| K8 | Muayene görevi sonuçla kapanır: takip sürsün + sonraki muayene ya da takip kapansın; isteğe bağlı not. |
| K9 | `gorev_log`'a `ref_takip_id` kolonu eklenir. |

Sahibin itiraz etmediği tasarım ayrıntıları:

- "Diğer" seçilince açıklama zorunludur.
- Aynı sebepten iki açık takip olamaz; "Diğer" bu kuraldan muaftır.
- Genel Ertele düğmesi yoktur; tarih yalnız "Muayene planla" ya da "Takip sürsün" ile değişir.
- Bir takibin en fazla bir açık muayene görevi olur.

## 4. Veri modeli

### 4.1 `hayvan_takip` tablosu

| Kolon | Tip | Kural |
|---|---|---|
| `id` | `uuid` | PK, `gen_random_uuid()` |
| `farm_id` | `uuid` | `NOT NULL DEFAULT '400b9107-a85e-4126-af2c-fd7fe73fb68e'`, FK yok (§14) |
| `hayvan_id` | `text` | `NOT NULL`, FK `hayvanlar(id)` |
| `sebep_kodu` | `text` | `NOT NULL`, boş olamaz |
| `aciklama` | `text` | `sebep_kodu='DIGER'` ise boş olamaz |
| `acilis_tarihi` | `timestamptz` | `NOT NULL DEFAULT now()` |
| `acan` | `text` | Oturum kullanıcısı; kalıp emsal RPC'den alınır |
| `kapanis_tarihi` | `timestamptz` | `NULL` = açık |
| `kapatan` | `text` | Sistem kapanışında `sistem` |
| `kapanis_nedeni` | `text` | CHECK: `ELLE`, `MUAYENE`, `VAKA`, `CIKIS` |
| `kapanis_notu` | `text` | İsteğe bağlı |
| `kapatan_vaka_id` | `cases.id` tipi | `kapanis_nedeni='VAKA'` iken dolu |

Kısıtlar ve indeksler:

- CHECK: `kapanis_tarihi` ve `kapanis_nedeni` ya ikisi de boş ya da ikisi de dolu.
- Kısmi unique: `(hayvan_id, sebep_kodu) WHERE kapanis_tarihi IS NULL AND sebep_kodu <> 'DIGER'`.
- Index: `(farm_id, hayvan_id)`.
- RLS açık, policy `USING(true)` (§14). `authenticated` yalnız `SELECT` alır; yazma yalnız RPC ile.

Sebep kodları: `TOPALLIK`, `SUT_DUSUSU`, `ZAYIFLAMA`, `ISTAHSIZLIK`, `DIGER`. Liste ve etiketler `js/config.js`'te durur. DB bu listeyi CHECK ile sınırlamaz, böylece liste migration'sız değişir. Etiketi bulunmayan kod ekranda ham haliyle gösterilir, satır gizlenmez.

### 4.2 `gorev_log` değişikliği

- Yeni kolon `ref_takip_id uuid`, FK `hayvan_takip(id)`.
- Yeni görev tipi `HAYVAN_TAKIP_MUAYENE`, `kaynak='HAYVAN_TAKIP:<takip_id>'`.
- Kısmi unique: `(ref_takip_id) WHERE ref_takip_id IS NOT NULL AND NOT tamamlandi AND NOT iptal`. Migration, kolon nullability'sini canlı şemayla doğrular.
- `v_gorev_log_sync` görünümü yeni kolonu içerecek şekilde yeniden yazılır.
- `gorev_tamamla`: yeni tip, `MUAYENE_SONUC_GEREKLI` korumasına eklenir (`20261013000004:65`). `p_iptal=true` dalı değişmez.
- `gorev_ertele_kural`: yeni tip için satır eklenmez; fail-closed gereği Ertele düğmesi çıkmaz (§18.10).

### 4.3 Tetikleyici ve kayıtlar

- **Çıkış:** Hayvan `durum` değeri `Aktif`'ten çıkınca açık takipler `CIKIS` nedeniyle, `kapatan='sistem'` ile kapanır. Ayrı tetikleyicidir. Görev iptalini mevcut `_trg_hayvan_cikis_gorev_iptal` yapar.
- **Değişiklik geçmişi:** `hayvan_takip`, `trg_degisim_log` izleme listesine eklenir (`20260913000001:164-170`).
- **`islem_log` tipleri:** `HAYVAN_TAKIP_ACILDI`, `HAYVAN_TAKIP_KAPANDI`, `HAYVAN_TAKIP_MUAYENE`. Kapanışta takip başına bir satır yazılır.

### 4.4 RPC'ler

Hepsi `SECURITY DEFINER`, `farm_id = current_farm_id()` damgalı. `REVOKE ALL FROM PUBLIC, anon, authenticated`; `GRANT EXECUTE TO authenticated, service_role`. `anon` yetkisi verilmez. Tarih hesabı `Europe/Istanbul` kalıbıyla yapılır; `CURRENT_DATE` kullanılmaz.

| RPC | İş | Reddeder |
|---|---|---|
| `hayvan_takip_ac(p_hayvan_id, p_sebep_kodu, p_aciklama, p_muayene_tarihi?, p_muayene_saati?)` | Takibi ve varsa muayene görevini tek işlemde açar | Hayvan aktif değil; aynı sebep açık; `DIGER` açıklamasız |
| `hayvan_takip_kapat(p_takip_ids[], p_not?, p_kapatan_vaka_id?)` | Seçilenleri kapatır, açık muayeneleri iptal eder. Vaka parametresi doluysa neden `VAKA`, değilse `ELLE` | Boş liste; farklı hayvanların takipleri aynı çağrıda |
| `hayvan_takip_muayene_planla(p_takip_id, p_tarih, p_saat?)` | Açık görev yoksa açar, varsa tarih ve saatini günceller | Takip kapalı; hayvan aktif değil |
| `hayvan_takip_muayene_sonuc(p_gorev_id, p_sonuc, p_not?, p_sonraki_tarih?, p_sonraki_saat?)` | `p_sonuc`: `SURSUN` ya da `KAPANSIN`. Görevi tamamlar; duruma göre sonraki görevi açar ya da takibi `MUAYENE` nedeniyle kapatır | Görev bu tipte değil; görev zaten kapalı; takip kapalı |

Kapanan takipte `hayvan_takip_kapat` hata vermez; kapalı satırı atlar ve kaç satırın kapandığını döner. Muayene görevleri `kapatan_ref='hayvan-takip-kapandi'` ile iptal olur.

## 5. Arayüz

Renk kuralı: vurgu yalnız yazı rengiyle yapılır, satır zemini ya da şerit eklenmez.

### 5.1 Hayvan kartı (`openDet`)

- Rozetler kısır rozetiyle aynı satırda: `📌 <sebep>` (`js/ui.js:5107-5112`).
- Düğmeler (`js/ui.js:7225-7240` kalıbı): **📌 Takibe al** her aktif hayvanda; **🔍 Muayene planla** ve **✓ Takibi kapat** yalnız açık takip varken.
- Kart gövdesi her açık takibi süre ve varsa planlı muayene tarihiyle listeler.

### 5.2 Pencereler

- **Takibe al:** Sebep listesi, açıklama, isteğe bağlı muayene tarihi ve saati.
- **Muayene planla:** Birden çok açık takip varsa önce takip seçilir.
- **Takibi kapat:** Açık takipler işaretlenebilir liste olarak, "Tümünü seç", isteğe bağlı not. Karttan açılınca tek açık takip işaretli gelir. Vaka sonrası açılınca hiçbiri işaretli gelmez ve "Açık kalsın" düğmesi görünür.
- **Muayene sonucu:** "Takip sürsün" + sonraki muayene (hazır +3 gün, boş bırakılabilir) ya da "Takip kapansın"; isteğe bağlı not.
- Tarih alanları `TARIH_ALANLARI` üzerinden kanonik seçiciye bağlanır ve gelecek tarihe izin verir (§17).

### 5.3 Dashboard (`_dashBands`)

- Band `let h='';` ile negatif stok arasına eklenir (`js/ui.js:561-562`).
- Başlık: `📌 Takipteki hayvanlar (N)`; N hayvan sayısıdır.
- Satır: `<küpe>  <sebep> · <gün> gün | <sebep> · <gün> gün`. Satıra basınca `openDet`.
- Sıra: hayvanın en eski açık takibi en üstte.
- Gün sayısı `Europe/Istanbul` takvim gününe göre hesaplanır.
- Yalnız aktif hayvanlar listelenir; açık takip yoksa band çizilmez.

### 5.4 Görev akışı

- Görev açıklaması: `<Sebep> takibi muayenesi`, kategori `muayene` (`js/ui.js:66-68`).
- Yeni tip, tamamlama yerine sonuç penceresine yönlenir. Dokunulacak dallanma noktaları: `js/ui.js:4254`, `4649`, `11561`, `11611`, `11818`.
- Plan, görevi kapatabilen diğer bütün UI yollarını da (toplu tamamlama dahil) tarar. Sonuç penceresini atlayan yol kalmamalıdır.

### 5.5 Vaka sonrası pencere

`submitCase` başarılı olduktan sonra (`js/forms.js:~845`) hayvanın açık takibi varsa pencere açılır; `caseTakipRetry` kolu da aynı noktaya gelir (`js/forms.js:869`). `vaka_toplu_ac`, `kizginlik_vaka_ac` ve otomatik yollar pencere açmaz. `TAKIP_ACIK` onayı değişmez; vaka öncesinde kalır.

### 5.6 Geçmiş

Üç yeni `islem_log` tipi `js/gecmis.js`'te etiket ve emoji haritalarına, `_GM_ISLEM_TIPLERI` izin listesine eklenir; not metni görünür.

### 5.7 İstemci verisi

- `js/api.js`: `TABLES`, `DB_VER` artışı, `FETCHERS`, RPC sonrası tazeleme haritaları, `REALTIME_TABLES`.
- Tablo tümüyle çekilir; tarih aralıklı çekim yasak (`js/api.js:598-604`).
- Merge öncesi `DB_VER` değeri, paralel dallarla çakışmaya karşı yeniden kontrol edilir.

## 6. Hata durumları

| Durum | Davranış |
|---|---|
| Aynı sebep açık | Takip açılmaz; "Bu sebeple zaten takipte" uyarısı |
| `DIGER` açıklamasız | Form gönderilmez; RPC de reddeder |
| Çıkmış hayvan | RPC reddeder, kart tazelenir |
| Takip başka biri tarafından kapatılmış | Hata yok, liste tazelenir |
| Kapalı takibin muayene sonucu | Reddedilir, liste tazelenir |
| Vaka sonrası takip kapatma başarısız | Vaka kayıtlı kalır, yalnız takip için uyarı çıkar |
| Çevrimdışı | Uyarı çıkar, RPC çağrılmaz |

## 7. Açık ölçümler

Bu maddeler kapanmadan ilgili faz kabul edilmez.

| No | Soru | Nasıl kapanır |
|---|---|---|
| Ö1 | `degisim_geri_al`, çıkışı geri alınca kapanan takibi ve iptal olan görevi geri açıyor mu? | Demoda test edilir. Geri açmıyorsa takip kapalı kalır, karttan yeniden açılır; görülen davranış bu spec'e ve domain kuralına yazılır. |
| Ö2 | Canlı `gorev_log`, `cases.id`, `gorev_tamamla` tanımları migration'larla uyuşuyor mu? | DB işi öncesi canlı şema okuması |
| Ö3 | Demo klonuna yeni tablo FDW içe aktarması sonrası doğru giriyor mu? | Demo uygulaması sırasında `demo/01_fdw_bridge.sql` ve `demo/03_sema_diff.sql` ile ölçüm |

### Sonuçlar (2026-10-31)

| No | Durum | Sonuç |
|---|---|---|
| Ö1 | Kapandı (demo) | Çıkışı `islem` seviyesinde geri almak hayvanı `Aktif` yapar; kapanan takipleri ve iptal olan görevi geri açar. `satir` seviyesi yalnız seçilen satırı döndürür: `hayvanlar` satırında takip kapalı kalır ve karttan yeniden açılır. Ayrıntı: `domain-rules.md` §20.9. |
| Ö2 | Kapandı (prod ve demo okuması) | Canlı `gorev_log`, `cases.id` ve `gorev_tamamla` tanımları beklenenle eş. Spec davranışını değiştiren sapma yok. |
| Ö3a | Kapandı (demo) | `demo_klonla()` işlem içinde `ok=true`, 2BP01 yok; `hayvan_takip` boşaltılan ek tablolar arasında ve boş kalıyor. `demo_sema_diff()` yalnız prod'da olup demo'da olmayanı bildirdiği için bu demo fazında fark göstermez. |
| Ö3b | Açık | Prod uygulamasından sonra ölçülür (sahip onaylı ayrım, 2026-10-31). |

Şema demo'da uygulandı; prod bekliyor.

## 8. Test ve kabul

1. **Migration:** Her migration `scripts/db-validate.sh` kapısından geçer.
2. **DB testleri:**
   - RPC başarı ve ret yolları (§4.4)
   - Aynı sebep kuralı ve `DIGER` istisnası
   - Çıkışta kapanma; takip kapanınca görevin iptali
   - Tek açık görev kuralı
   - `gorev_tamamla` korumasının yeni tipte çalışması
3. **Karşı test (zorunlu):** `HAYVAN_TAKIP_MUAYENE` açıkken `TAKIP_ACIK` tetiklenmez, `OVSYNC_BASLAT` üretimi ve `sessiz_hayvanlar_listele` sonucu değişmez; `TAKIP_MUAYENE` akışı aynen çalışır.
4. **Birim testleri:** Dashboard gruplama, sıralama ve gün hesabı; pencere ön seçim kuralları; bilinmeyen sebep kodu.
5. **UI kapısı:** Akış haritası (mermaid) ile demoda tarayıcı yürüyüşü: açma, band, muayene planlama, iki sonuç kolu, vaka sonrası pencere, seçmeli ve toplu kapatma, geçmiş. Opus koltuğunda PASS olmadan sahibe verilmez. Liste DOM'a ek olarak şu soruyu ölçer: band ilk bakışta "kim, neden, kaç gündür" sorusunu cevaplıyor mu?
6. **Kapsam dışı:** Prod DB uygulaması, merge ve push sahip kararındadır, ayrıca istenir.

## 9. Teslim yöntemi

DB işi içerdiği için `.harness/task-modes.md` gereği Full goal açılır. Sıra: plan (opus high), DB fazı, frontend fazı, kapı review'u (`ss-reviewer-kapi`), UI kapısı, sahip testi.
