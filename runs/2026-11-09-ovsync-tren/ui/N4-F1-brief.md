# N4-F1-brief — N4 eksik kalan iki PLAN maddesi: K8 kancaları (V3–V6, G7, G9) + vaka kartı kaydır aşama dalları
job_id: j-20261109T140948Z-efc082

tip: is
effort: xhigh (sinyal f-turu + UI)
job: ovsync-tren N4-F1
workspace: tedavi-arge
report: ~/.herdr/worktrees/egesut-erp1/ovsync-tren/runs/2026-11-09-ovsync-tren/ui/N4-F1-report.md
repo/dal: ~/.herdr/worktrees/egesut-erp1/ovsync-tren (dal ovsync-tren, uç 26e653e). Açılışta `git branch --show-current` → `ovsync-tren` (detached YAPMA, rebase/merge YAPMA).

girdi (BAĞLAYICI):
- Ana brief (tüm ROOT RULING'leri, tuzaklar, Yazılabilir kuralları AYNEN geçerli): ~/.herdr/worktrees/egesut-erp1/ovsync-tren/runs/2026-11-09-ovsync-tren/ui/N4-brief.md
- Önceki tur report'u (self-review tablosu, "Kalan açıklar"): ~/.herdr/worktrees/egesut-erp1/ovsync-tren/runs/2026-11-09-ovsync-tren/ui/N4-report.md
- PLAN UB2 :492-507, UB4 :522-534: ~/.herdr/worktrees/egesut-erp1/ovsync-tren/docs/plans/2026-11-09-ovsync-tren/PLAN.md
- Veri sözleşmesi: ~/.herdr/worktrees/egesut-erp1/ovsync-tren/runs/2026-11-09-ovsync-tren/ui/UB-sozlesme-report.md
- Mockup: ~/.herdr/worktrees/egesut-erp1/ovsync-tren/runs/2026-11-09-ovsync-tren/mockup/01a-trene-bin-modal.html, 01b-trene-bin-bugun-R4.html, 04a-vaka-karti-asama2.html, 04b-vaka-karti-asama1-kaydir.html

## ROOT RULING (N4 tur 1 sonrası, 2026-11-09)

Önceki tur `sonuc: TAMAM` dedi ama PLAN içi iki madde kaldı (report self-review "Kalan açıklar"). Bu tur yalnız onları kapatır; bütçe gerekçesi bu turda geçerli değil.

- D1 (BLOKLAYAN) K8 kancaları — PLAN UB2 :494-505 davranışı birebir, soru çekirdeği mevcut `ovsyncTrenSor` (kopya YAZMA):
  - V3 `submitCase`: Ovsync şablonu/hastalığı seçiliyse önce soru; `TREN` → `tedavi_sablon_uygula(p_baslangic_tarihi: tarih)`; `BAGIMSIZ` → mevcut çağrı. Offline + Ovsync → toast "İnternet yok", kuyruğa YAZMA.
  - V4 `submitBulkCase`: Ovsync şablonluysa soru; `TREN` → `p_tarih = tren tarihi`; `BAGIMSIZ` → kullanıcının seçtiği tarih.
  - V5 `caseSablonUygula`, V6 `_vakaBosAtaKanca`: OVSYNC şablonunda soru; `TREN` → `p_baslangic_tarihi = tren tarihi`.
  - G7 `_devamSeciciAc` → Ovsync uygula: `TREN` → mevcut `tohumlama_bos_ve_devam`; `BAGIMSIZ` → dönüşteki `ovsync_gorev_id` ile `start_first_service_protocol({p_gorev_id, p_bagimsiz:true})`; hata → görev açık kalır, toast "Görev açıldı, başlatılamadı: <ovsyncTrenHataMetni>", throw yok. `OVSYNC_GOREV_ACILAMADI` (UB-sozlesme F7 listesi) metinli.
  - G9 `_protokolIptalAkisi` "yeniden başlat: Evet": `TREN` → `ovsync_bastan_baslat(case)`; `BAGIMSIZ` → `ovsync_bastan_baslat(case, true)`; sonuç metni ana brief BOŞLUK-4 (eylem sonrası `hedef_tarih`/`basladi`).
  - R4: tren = bugün → modal yok, doğrudan trene. Bayrak kapalı → hiçbir kancada soru yok, eski parametreler birebir. Kullanıcı modalı kapatırsa (Vazgeç) → hiçbir RPC çağrılmaz, form açık kalır.
  - Test (adlı, her yol ayrı): `V3 TREN p_baslangic_tarihi`, `V3 BAGIMSIZ eski çağrı`, `V3 offline Ovsync kuyruğa yazmaz`, `V4 TREN p_tarih`, `V4 BAGIMSIZ kullanıcı tarihi`, `V5 TREN`, `V6 TREN`, `G7 TREN tohumlama_bos_ve_devam`, `G7 BAGIMSIZ start p_bagimsiz`, `G7 BAGIMSIZ hata → toast, throw yok`, `G9 TREN`, `G9 BAGIMSIZ true`, `<her yol> bayrak kapalı → soru yok` (tek parametreli test tablosu kabul), `Vazgeç → rpc yok`.
  - Mutant: (m5) V3'te `TREN` dalındaki `p_baslangic_tarihi`'ni sil → `V3 TREN` kırmızı; (m6) G7 BAGIMSIZ try/catch'i kaldır → `G7 BAGIMSIZ hata` kırmızı; (m7) V4 bayrak kapalı kontrolünü kaldır → `V4 bayrak kapalı` kırmızı.
- D3(ii) (BLOKLAYAN) `cdKaydirAc` OVSYNC vaka aşama dalları — PLAN UB4 :528-530: bayrak açık + aktif OVSYNC vaka:
  - Veri: online → `ovsync_tren_listele` (mevcut api sarmalı), `case_id` eşleşen üyenin `asama`'sı; aşama 0 → "Sonraki trene aktar" (`ovsync_hayvan_ertele`, ana brief F3 tarih kuralı); 1 → yalnız "+N" seçici 1..`pg_pay` (`ovsync_hayvan_ertele`); 2 → kaydır düğmesi YOK + (a) "PG1 + 48 s'te tohumla" (`ovsync_pg48_tohumla`, BOŞLUK-1) / (b) "Baştan başlat" (`ovsync_bastan_baslat`, BOŞLUK-4); belirsiz (NULL) ya da üye bulunamadı → yalnız "Baştan başlat".
  - Offline ya da listele hatası → kaydır YOK, "İnternet yok — Ovsync vakası çevrimiçi kaydırılır" metni + "Ovsync ekranında düzenle →" bağlantısı (sessiz eski kaydır'a DÜŞME; sunucu K10 zaten reddeder).
  - OVSYNC olmayan vaka ve bayrak kapalı → mevcut sheet birebir.
  - Test: `aşama 0 → Sonraki trene aktar`, `aşama 1 → +N max pg_pay`, `aşama 2 → kaydır yok, (a)(b) var`, `belirsiz → yalnız Baştan başlat`, `offline OVSYNC → kaydır yok + bağlantı`, `OVSYNC değil → eski sheet`, `bayrak kapalı → eski sheet`. Mutant (m8) aşama 2 dalında kaydır düğmesini geri getir → `aşama 2` kırmızı.
- BOYUT: önceki report iki sayı veriyor (+737 başlıkta, +650 Kabul'de). Bu report tek sayı + komut verir (taban fb41bbf, üretim dosyaları). Toplam N4 üretim bütçesi ≤ +1000 net.
- Report sonucu dürüst: kalan madde varsa `sonuc: KISMI` + madde listesi; TAMAM yalnız PLAN UB1–UB5 maddelerinin hepsi kodda ve testliyse.
- Kapsam DIŞI: ana brief "Kapsam DIŞI" listesi + `_ovsyncK8GunAd`/`_ovsyncTrenTarihAd` birleştirmesi (önceki tur gerekçesi kabul) + supabase/**.

## Kabul

- Yeni testler kırmızı→yeşil + m5–m8 ADLI testte kırmızı (MEASURED; komut + çıktı, cmp IDENTICAL).
- Tam birim suit: `fail 4`, fail edenler TAM OLARAK taban dördü (LUNA-3, EG-7, EG-8, vaka-toplu-ac "ay ‹/›"); pass > 2333.
- `etiket-tazelik`: HATALI 15 / DOĞRULANAMADI 4 listesi tabanla birebir.
- Report: `## Fan-out`, `## Self-review` (tek reviewer çocuğu), D1/D3(ii) madde → dosya:satır → test adı tablosu, `## Run kanıtı`; son commit SHA = dal ucu. Commit öneki `ovsync-tren N4-F1:`; dosya dosya `git add`, push YOK. TUI son satırı `DONE <report yolu>` / `SORU <report yolu>`.

Yazılabilir:
~/.herdr/worktrees/egesut-erp1/ovsync-tren/js/api.js
~/.herdr/worktrees/egesut-erp1/ovsync-tren/js/ui.js
~/.herdr/worktrees/egesut-erp1/ovsync-tren/js/forms.js
~/.herdr/worktrees/egesut-erp1/ovsync-tren/js/ovsync-tren.js
~/.herdr/worktrees/egesut-erp1/ovsync-tren/tests/unit/ovsync-tren.test.js
~/.herdr/worktrees/egesut-erp1/ovsync-tren/tests/unit/ovsync-tren-entegrasyon.test.js
~/.herdr/worktrees/egesut-erp1/ovsync-tren/runs/2026-11-09-ovsync-tren/ui/N4-F1-report.md
~/tmp/muse-ovsync-n4f1

## Bilinen tuzaklar

- Ana brief "Bilinen tuzaklar" aynen (NODE_PATH, ram-ultracode exec, atlas `etki` her değişen sembolde, loadExtractedFunction imza koruma, TR günü, JSON.parse try/catch, stash/checkout YASAK).
- `submitCase`/`submitBulkCase`/`caseSablonUygula`/`_vakaBosAtaKanca`/`_devamSeciciAc`/`_protokolIptalAkisi` çağıran mevcut testleri çok (UB-sozlesme "Test tabanı" listesi): bayrak kapalı dalı birebir kalmalı; o testlere DOKUNMA.
- Özet/ara dosyaları yalnız `~/tmp/muse-ovsync-n4f1` altına (runs/ altına yalnız report).

## Fan-out planı (zorunlu)

İç review + self-review TEK reviewer çocuğu.

cocuk-model: spark

Parça 1 (alt ajan): D1 forms.js kancaları V3/V4/V5/V6 + testleri. Parça 2 (alt ajan, Parça 1'den sonra — aynı dosya): G7/G9 (forms.js/ui.js) + testleri. Parça 3 (alt ajan, ui.js'e Parça 2 bittikten sonra): D3(ii) cdKaydirAc.
Sen: entegrasyon, m5–m8, tam suit + etiket-tazelik, report, tek reviewer çocuğu.
