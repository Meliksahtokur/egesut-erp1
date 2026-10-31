⟦ss-sub model=sonnet effort=medium rol=ss-worker iş=t7 demo apply + veri-eslesme + Playwright UI kapısı (T1-T11)⟧
sonuc: KISMI
progress: koşum bitti; T8 FAIL (kod düzeltmesi brief gereği yazılmadı), sahip kararı bekliyor
BOYUT: bütçe 0 · gerçek 0 · bütçe içinde (kod değişikliği yok)

# t7 — Demo apply + UI kapısı

Kod HEAD: `c916f87` (some-fixes). Demo ref `vtzqjmazsvurxdeondmi`. Prod'a yazılmadı, push/merge/kod değişikliği yok.

## Sonuç tablosu (10 PASS / 1 FAIL)

| # | Madde | Sonuç | Kanıt |
|---|---|---|---|
| T1 | Erkek doğum, boş küpe 511 | PASS | toast "Doğum kaydedildi — 511 sürüye eklendi"; DB: hayvan 511 Aktif + `dogum.buzagi_id` dolu. `T1-form.png`, `T1-sonuc.png` |
| T2 | Dişi doğum, boş küpe 9102 | PASS | toast "9102 sürüye eklendi, 15 görev"; DB'de hayvan+dogum. `T2-sonuc.png` |
| T3 | Ölü küpe 90 (H000156, anne 119), başka anne 181 | PASS | blur notu "Bu numara geçmişte kullanılmış (Ölü) — yeniden kullanılabilir"; kayıt düştü; DB: 90 hem Ölü (H000156) hem Aktif (yeni buzağı). `T3-sonuc.png` |
| T4 | Ölü yavru küpesi 37 (903a1ba4), AYNI anne 153 | PASS | kayıt düştü; DB: 37 hem Ölü hem Aktif, anne 153. `T4-sonuc.png` |
| T5 | Aktif hayvan küpesi 156 | PASS | İki yol: (a) UI blur koruması: "Bu küpe zaten kayıtlı (aktif hayvan)" + toast "Küpe çakışması var", modal açık kaldı (`T5-sonuc.png`); (b) uyarı alanı betikle sıfırlanıp RPC'ye gönderildi: toast "Doğum kaydedilemedi: Bu küpe zaten kayıtlı: 156" ("Bir hata oluştu" değil) (`T5B-sonuc.png`) |
| T6 | Küpe 90 arama / tohumlama / toplu tedavi yapıştırma | PASS | (a) Sürü araması "90" → `_detOpenId` aktif buzağı `95016797…`, ölü H000156 değil (`T6a-arama-90.png`). (b)(c) için demoda ölü ikizi olan yetişkin gerekti: aktif 5638 (456d7c6d) + ölü H000159 küpesi SQL ile 5638 yapıldı, aktife Bekliyor tohumlama eklendi. (b) 💉 Tohumlama Ekle → `_insemInterceptHayvan.id` = aktif 456d7c6d (`T6b-tohumlama-detay.png`). (c) Toplu Taşı → Elle → "5638" Yükle: "1 hayvan eklendi", `_btModalSecilenIds` aktifi içeriyor, H000159'u içermiyor (`T6c-toplu-tedavi-yapistir.png`) |
| T7 | Eski doğum satırı yavru tıklaması | PASS (taze satır) | 511 ölü işaretlendi (SQL), 511 başka anneden (163) yeniden verildi (UI). Eski satır `buzagi_id=b9b7c132` tıklandı → kart ölü buzağı (Durum: Ölü, `_detOpenId=b9b7c132`), yeni 511 değil. `T7a-eski-satir-tikla.png`. Eski veri satırı (buzagi_id NULL, küpe 90) → `gm-kupe` fallback aktif 90'ı açar (`T7b-legacy-satir.png`). t6-raporunda kararlaştırılan davranış, ama sahibe görünür: backfill yok, demoda 83'ten çoğu NULL |
| T8 | Küpesi yeniden verilmiş ölü hayvan kartı: düzenle+kaydet | **FAIL** | Kart açılıyor, "✏️ Bilgileri Düzenle" → kırmızı toast "Hayvan bulunamadı", form hiç açılmıyor (`T8a-dogrudan-tikla.png`). Kök: `js/ui.js:7838` `openAnimalEdit` hayvanı `getState('animals')` içinde arıyor; bu state `loadAnimals` ile yalnız `durum==='Aktif'` (`js/ui.js:5016`). Çıkmış hiçbir hayvan UI'dan düzenlenemiyor (bu yoldan 20261031000001 B maddesine hiç ulaşılmıyor). Ek ölçüm (istemci kapısı aşılarak): ölü hayvan state'e eklendi → form açıldı, küpe 511, uyarı boş, kaydet → "✅ 511 güncellendi", DB: ölü 511 `ayirici_ozellik='T7 test notu'`, aktif 511 dokunulmadı (`T8b-sonuc.png`). Yani DB tarafı (B) çalışıyor, UI girişi kapalı |
| T9 | ILERI_GEBE görevi tamamla → Protokol Uyarıları | PASS | Hayvan 905, görev `8856d31c` (E_VIT, etken_kod dolu). Önce uyarılar: 🔴 Ademin + 🔴 E Vitamini. Görevler/Geciken'den ✓ → görev listeden düştü; 🔔 panelinde E Vitamini 🔴 Gecikmiş'ten çıktı, "✅ Son 24 Saat" bölümüne geçti. `T9-0-uyari-once.png`, `T9-2-tamamla-sonrasi.png`, `T9-3-uyari-sonra.png`. Not: "düşer" = bekleyen bölümünden çıkar, silinmez, tamamlandı satırı olarak kalır |
| T10 | Uyarı → görev: 💉 Uygula | PASS | 905 Ademin satırı → 💉 Uygula → stok "Ademin" → Kaydet → "✅ Uygulama kaydedildi"; panelde ✅'ye geçti (↩ Geri Al çıktı); Görevler/Geciken 905 araması boş. DB: görev `3378463c` tamamlandi=true, `kapatan_ref=uygulama_log:b032c506…`. `T10-0-uygula-modal.png`, `T10-1-kaydet-sonra.png`, `T10-2-gorev-sonra.png` |
| T11 | Küpe 💡 önerisi erkekte | PASS | Cinsiyet Erkek → 💡: 506,507,508,509,510,512…516, hepsi 5xx; öneri sırasında yeni konsol hatası 0. `T11-oneri-erkek.png` |

Eski `*-hata.png` dosyaları (T2/T3/T4/T6c/T8 `-hata`) sonradan düzeltilen betik hatalarından kalan çöp kanıt, sonuca girmez: ilk koşumda Manuel Gir butonu 2. doğumda yoktu (aşağıda bulgu 2), her vaka ayrı tarayıcı oturumuna alındı.

## Adım 1 — Demo apply

Demo şeması önceden `20261017100001`. Sırayla `database/query` ile uygulandı (dosyalar kendi BEGIN/COMMIT'iyle), her biri `[]` döndü, sonra `schema_migrations(version,name)` kaydı eklendi. Son durum: `20261031000001, 20261030100001, 20261030000001, 20261017100001`. MEASURED

## Adım 2 — veri-eslesme-kontrol `hepsi`

Çıktı: `~/tmp/agents/veri-eslesme-20261031/ozet.json` (UI testlerinden ÖNCE koşuldu).

- `sizinti`: SIZINTI(supheli)=0 (ortak=52, kesişim 5883 klon imzalı, pk_farki=0, ölçülmeyen=13)
- `isaret`: BULGU 58 kombinasyon. 2026-10-17 (`veri-eslesme-20261017/ozet.json`) ile (tablo, kolon, işaret) kümesi birebir aynı (`True`). Satır sayısı 2763 → 2790; artış yalnız 5 `deneme` kombinasyonunda (islem_log.snapshot 1211→1216, islem_log.payload 106→110, hayvan_timeline_view.detay 321→325, degisim_log.yeni 72→81, degisim_log.eski 39→44). Yeni işaret kombinasyonu yok. MEASURED
- `koken`: YETIM=0. `statik`: turetilmis=0.
- Bu bulgu t5'in prod ölçümüyle de aynı küme (t5-report:150). Sayı artışının nedenini tek tek incelemedim. INFERRED: demo tarafında testlerle biriken "deneme" metinli satırlar.

## Run kanıtı

```
python3 scripts/veri-eslesme-kontrol.py hepsi
```
rc: 0
```
[selftest] READ ONLY guard sınanıyor...
[selftest] OK — iki DB'de de yazma reddedildi (salt-okunur kanıtlandı)
[sizinti] ortak=52 kopya_tarihi=2026-07-02T00:00:00+03:00 SIZINTI(supheli)=0 bilgi: kesisim=5883 (klon_imzali=5883) pk_farki=0 demo_dogumlu=8276 prod_only=2524 olculmeyen=13
[isaret] eslesen_kombinasyon=58 eslesen_toplam_satir=2790
[koken] fk=5 doldurulan=1 ad_eslesme=1 YETIM=0 std_dose_dolu=26
[statik] dosya=10 turetilmis=0 sabit=47 rpc_govdesi=38

ÖZET: ~/tmp/agents/veri-eslesme-20261031/ozet.json
HÜKÜM: BULGU: 58
```

Playwright koşum komutu (birebir kalıp; betikler `runs/2026-10-30-some-fixes/t7-kanit/betik/`):
```
cd .
python3 -m http.server 8137 --bind 127.0.0.1 &
docker run --rm --network host -v "$PWD":/work -w /work -v ~/egesut-erp1:/main:ro -v $HOME/tmp/t7:/t7 \
  -e NODE_PATH=/main/node_modules -e HOME=/tmp/pwhome \
  mcr.microsoft.com/playwright:v1.58.2-noble node /t7/<betik>.cjs [vaka]
# betikler: dogum.cjs T1..T5/T5B/T7P/T6X, ust.cjs (T6), d78.cjs (T7,T11), d8b.cjs (T8), gv2.cjs (T9,T10)
```
Kurulum: `EGESUT_DEMO=1`, `EGESUT_DEMO_POPUP_OFF=1` initScript, `?demo`, gerçek tıklama; yalnız T6 kurulumu, T7 "ölü yap" ve T8b istemci kapısı geçişi ayrıca belirtilen yerlerde SQL/evaluate. `sonuclar.json`'a dokunulmadı. Demo sahip şifresine dokunulmadı.

## Bulgular (kırıntı)

1. **T8 FAIL (kök kanıtlı):** `js/ui.js:7838` + `js/ui.js:5016`: çıkmış hayvan kartından "Bilgileri Düzenle" her zaman "Hayvan bulunamadı". Migration 20261031000001 B maddesinin (kupe_musait_mi kendi küpesi) amaçladığı senaryo UI'dan erişilemiyor. Eski bir kısıt (blame 18ae26a), bu işin regresyonu değil. Düzeltme brief gereği yazılmadı. Seçenek: `openAnimalEdit` state yerine IDB'den okusun (`getData('hayvanlar', a=>a.id===id)`) veya çıkmış hayvanda düzenle butonu gizlensin. Sahibe karar.
2. **Doğum formunda Manuel Gir butonu ikinci doğumda yok** (OBSERVED): `js/utils/handlers.js:336` `birth-manual` butonu kendini `display:none` yapıyor, `submitBirth` sıfırlaması (`js/forms.js` formu sıfırla bloğu) bu butonu geri açmıyor. Aynı oturumda ikinci doğumda yalnız "Gebelerden Seç" kalıyor. Küçük, bu işten bağımsız. Bu yüzden her vaka taze oturumda koşuldu.
3. **Eski doğum satırı geriye dönük bağ yok:** `buzagi_id` NULL satırlar (demoda 90, 93 vb.) küpe yeniden verilince `gm-kupe` ile YENİ aktif hayvanı açar. t6-report:25 bunu bilinen sınır olarak yazmıştı. Sahibin T7 cümlesi bu satırlarda sağlanmıyor. Backfill SQL'i (anne+tarih+küpe ile eşleme) sahibe seçenek.
4. **Konsol gürültüsü (karşılaştırılmadı, bu işten kaynaklandığı kanıtlanmadı):** (a) her oturumda `warning: pull failed: Failed to execute 'put' on 'IDBObjectStore': Evaluating the object store's key path did not yield a value` (hangi tablo bilinmiyor); (b) doğum sonrası `HTTP 403 POST …/rest/v1/ui_logs` (telemetri). Doğum, Sürü, görev akışlarının sonucunu etkilemedi. UNKNOWN: değişiklik öncesinde de mi var.
5. Demo dışı veri sızıntısı yok; `sizinti` 0.

## Demoda bıraktığım test verisi

- Yeni hayvanlar: 511 (Erkek, anne 175, **Ölü** yapıldı; ayirici_ozellik 'T7 test notu'), 511 (Erkek, anne 163, Aktif), 9102, 90 (Aktif, anne 181), 37 (Aktif, anne 153), 9103, ve bu doğumların 15/7 görevleri.
- SQL ile: H000159 küpesi 93→5638 (aktif 456d7c6d'nin küpesiyle aynı), 456d7c6d'ye Bekliyor tohumlama (sperma 'T7-TEST', 3 gün önce), 905'in iki ILERI_GEBE görevi tamamlandı, bir uygulama_log satırı.
- Sahip demoyu "Prod'dan Klonla" ile sıfırlayabilir.

## Sahibe verilecek link + liste

NOT: T8 FAIL olduğundan CLAUDE.md UI kapısına göre sahibe teslim edilmemeli; aşağıdaki liste T8 düzeltilene (veya sahip kararına) kadar bekletilir.

Link: `http://127.0.0.1:8137/?demo` (worktree kökünden `python3 -m http.server 8137 --bind 127.0.0.1`; demo hesabı kendiliğinden girer; sunucu şu an çalışıyor).

1. Üreme → Doğum → Doğum Kaydet → Manuel Gir, anne 175, Erkek, küpe 512, kg 38 → "Doğum kaydedildi", Sürü'de 512.
2. Anne 154, Dişi, küpe 9104 → kayıt düşer.
3. Anne 181, Dişi, küpe 37 (ölü hayvan küpesi; bu demoda zaten kullanıldı, başka ölü: 50, 52, 57, 58, 63, 66, 70, 72) → "geçmişte kullanılmış (Ölü) — yeniden kullanılabilir", kayıt düşer.
4. Anne 156, Dişi, küpe 175 (aktif hayvan) → "Bu küpe zaten kayıtlı (aktif hayvan)"; "Bir hata oluştu" yok.
5. Sürü'de "90" ara → açılan kart aktif buzağı. (Ölü 90 buradan açılmaz.)
6. Üreme → Doğum listesi, yeni 511'in annesi 175'in satırında ölü 511'e tıkla → ölü buzağının kartı (Durum: Ölü), yeni 511 değil.
7. Ölü kartta "Bilgileri Düzenle" → şu an kırmızı "Hayvan bulunamadı" (T8 FAIL).
8. 🔔 Protokol Uyarıları'nda 905: Görevler/Geciken'den E Vitamini ✓ → 🔔'de Gecikmiş'ten ✅ Son 24 Saat'e geçer; Ademin 💉 Uygula → Görevler'den düşer.
9. Doğum formu, Erkek, 💡 → yalnız 5xx.
