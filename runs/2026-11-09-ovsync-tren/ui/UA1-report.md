⟦ss-sub model=opus effort=high rol=ss-worker-high iş=UA1 — js/ovsync-tren.js saf modülü ve birim testleri (PLAN N3 + kapı tur 2 ekleri)⟧
sonuc: TAMAM

- Commit: `192570a` (dal `ovsync-tren`), 2 dosya: `~/.herdr/worktrees/egesut-erp1/ovsync-tren/js/ovsync-tren.js`, `~/.herdr/worktrees/egesut-erp1/ovsync-tren/tests/unit/ovsync-tren.test.js` (`git diff --cached --stat` commit öncesi yalnız bu 2 dosya — MEASURED).
- BOYUT: bütçe 400 · gerçek 628 · plan "~400 satır" kod gövdesi; fark JSDoc (her fn), UTC tarih yardımcıları (TZ güvenliği) ve plan listesinde olmayan 7 ek hata kodu metni (D6/D7 RAISE'leri: TREN_KAPALI, N_GECERSIZ, GUNU_DEGIL, TREN_BOS, VAKA_YOK, ASAMA2_DEGIL, BASTAN_BASLATILAMADI) — sessiz ham kod göstermemek için.
- Brief denetimi: bulgu yok.

## Ne yapıldı

Plan "Interfaces — Produces" listesindeki 15 fonksiyonun hepsi (CONFIRMED, testli): `ovsyncTrenAktif`, `ovsyncTrenSoruGerekli`,
`ovsyncTrenSoruHtml`, `ovsyncTrenSor`, `ovsyncTrenBaslikHtml`, `ovsyncTrenGrupla`, `ovsyncToptanOnizlemeHtml`, `ovsyncToptanOnayAcikMi`,
`ovsyncTrenGorevMu`, `ovsyncDuzenleLinkHtml`, `ovsyncCokluAtlananNot`, `ovsyncGecTamamlamaUyariHtml`, `ovsyncAsamaAksiyonHtml`,
`dogumPgHatirlatmaHtml`, `ovsyncTrenHataMetni`. Ek iki global: `ovsyncToptanTarih(tren, bugunIso)` (R7 X tarihi: trenin bugün/sonraki
ritim günü D0 ya da D7; ritim dışı/işi geçmiş → null) ve `ovsyncEkranindaDuzenle(hayvanId)` (`window._ovsyncOdakHayvan` + `goTo('ovsync')`).

Kapı tur 2 ekleri:
- **Ritim dışı başlık varyantı** (mockup 2b): `ritim_disi:true` → "ritim dışı" etiketi (`.ovs-tren-ritimdisi`), "Tren gününü ertele…" yok,
  `.ovs-tren-not` açıklaması. Test: `başlık: ritim_disi → …` (CONFIRMED).
- **JSON.parse try/catch**: `ovsyncTrenGorevMu` bozuk `aciklama`da `false` döner ve hata bildirir — `opts.hata(mesaj, t)` verilmişse o,
  yoksa `console.error('[ovsync-tren] …')`; mesajda görev id ve tip var. Test: `görev mu: bozuk aciklama sessiz geçmez` (CONFIRMED).
  `ovsyncTrenHataMetni` de bozuk JSON gövdesinde metni üretir ve ham ayrıntıyı ekler (sessiz değil).

İmza genişletmeleri (opsiyonel, plan imzalarıyla geriye uyumlu):
- `ovsyncTrenBaslikHtml(tren, bugunIso, online)` — `online === false` → ertele düğmesi yok (spec §6 çevrimdışı kuralı).
- `ovsyncToptanOnizlemeHtml(plan, secimler, bugunIso)` — "Bugünün Ovsync işleri" ve grup başlığındaki "bugün …" için.
- `ovsyncAsamaAksiyonHtml(uye, online, bugunIso)` — "PG bugün:" etiketi için.
- `ovsyncTrenSor({…, aktif})` — `aktif === false` (yerel bayrak) → rpc'siz eski yol `{TREN, null}`; çevrimdışıda da eski yol bozulmaz.
  `online` yalnız `=== true` iken çevrimiçi sayılır (fail-closed). `rpc` hem düz veri hem `{data, error}` dönüşünü kabul eder.

Aksiyon sözleşmesi (UB3/UB4 bağlar): düğmeler satır içi onclick taşımaz; `data-ovt-aksiyon` ∈ VAZGEC, BASLAT, TOPTAN (+`data-tarih`),
ONAYLA, ERTELE/SONRAKI_TREN (+`data-hayvan`, `data-case`), PG48/BASTAN (+`data-case`, `data-hayvan`), DEVAM; seçenekler `data-secim`
(TREN/BAGIMSIZ; toptan radyolarında PG48/BASTAN + `data-case`), N seçici `data-n`. Tek istisna: düzenle bağlantıları
`onclick="…ovsyncEkranindaDuzenle(this.dataset.hayvan)"` (AGENTS data-x + this.dataset kalıbı).

Başlıktaki "bugün: …" parçası tren (D0) gününe göre gün farkından türetilir (0 başlangıç · 7 PG · 8 2. PG · 9 2. GnRH · 10 tohumlama),
R3 etiket kuralı sayesinde kaymalardan sonra da doğru (INFERRED, R3'e dayanır). Tarih aritmetiği yalnız `Date.UTC`/ISO; TZ testi üç saat
diliminde (Kiritimati +14, Los Angeles −8, İstanbul) alt süreçle koşuldu (MEASURED).

## Mockup'tan sapmalar

Mockup metinleri ve `_tren-yeni.css` sınıfları birebir kullanıldı; aşağıdakiler RPC sözleşmesinde (PLAN D4/D6/D7) karşılığı olmayan
veri yüzünden ya isteğe bağlı alana bağlandı ya da genelleştirildi:

1. **1a K8 modalı**: "▶ Ovsync başlat — 212", "Kural günü Sal 17 Kas", "Bu trende: 36 · 38 · 169 · 5708." `ovsync_tren_onizle` dönüşünde
   yok (`kupe_no`, `kural_tarihi`, `uye_kupeler`). Çağıran bu alanları eklerse çizilir, yoksa o parça atlanır.
2. **2b ritim dışı notu**: mockup'taki "(PG +1 gün)" parantezi veride yok → "Tek hayvan ertelemesiyle ritimden çıktı. Toptan ertelemeye
   girmez; kendi satırından düzenlenir."
3. **2a/2b aşama düğmeleri**: "en çok +1 gün" ve "PG payı doldu (1 gün kullanıldı)" isteğe bağlı `uye.pg_pay`'e bağlı (`ovsync_tren_listele`
   dönüşünde yok); yoksa yalnız "PG'yi ertele". Pay ≤ 0 → "PG payı doldu:" + "Baştan başlat → trene bin" (parantezsiz). Bağımsız aşama 0'da
   (tren yok) "Başlangıcı ertele…" (mockup'ta bu durum çizilmemiş).
4. **3a/3b toptan modalı**: tren grup başlıkları ("Tren · Per 19 Kas — bugün PG günü") üyede `tren_gunu`/`ovsync_tren` alanı varsa çıkar;
   D7 `uyeler` biçiminde yok → düz liste, "…işleri: 6 hayvan. Kaç gün?" ("2 tren" parçası yok). Aşama etiketleri veriden: "aşama 1 · 1.
   uygulama yapıldı", "aşama 2 · PG yapıldı" (mockup "PG bugündü", "PG yapıldı 09:40" — saat yok). Satır nedenleri: yalnız SECIM ve BASTAN
   için genel metin (pay ayrıntısı yok). "Dokunulmaz: 2 bağımsız · 1 ritim dışı" satırı yok (plan dönüşünde yok). Ek: `ileri_gorevler` doluysa
   "Ayrıca N ileri başlatma görevi yeni ritme taşınır." PG48 seçiliyse "tohumla → PG1 + 48 s" (tarih yalnız `yeni_tarih` doluysa).
5. **7b geç tamamlama**: "PG planı Per 26 Kas idi, Cmt 28 Kas'ta yapıldı. PG en çok 1 gün geç kalabilir." → R13 `ovsync_uyari` yalnız
   `gecikme_gun` taşır; metin "PG planlanan günden 2 gün sonra yapıldı. Kayıt alındı, protokol şu an devam ediyor." Küpe yalnız
   `uyari.kupe_no` varsa; "(Per 3 Ara)" yok.
6. **7a hatırlatma**: mavi vurgu inline `#8ec6ff` yerine `.ovs-mavi` sınıfı (`_tren-yeni.css`'te yalnız `body.dark` için tanımlı) —
   UB5 index.html'e taşırken açık tema kuralı (`.ovs-mavi{color:var(--blue)}`) eklenmeli.
7. **Toptan grup başlığı**: "— bugün başlangıç günü" (mockup "— bugün başlangıç"), başlıkla aynı etiket tablosu.

## Run kanıtı

`node --test tests/unit/ovsync-tren.test.js` (önce FAIL — modül yokken)

```
rc: 1
  code: 'ENOENT',
  syscall: 'open',
  path: '~/.herdr/worktrees/egesut-erp1/ovsync-tren/js/ovsync-tren.js'
}

Node.js v26.10.0
✖ tests/unit/ovsync-tren.test.js (59.627448ms)
ℹ tests 1
ℹ suites 0
ℹ pass 0
ℹ fail 1
ℹ cancelled 0
ℹ skipped 0
ℹ todo 0
ℹ duration_ms 71.401913

✖ failing tests:

test at tests/unit/ovsync-tren.test.js:1:1
✖ tests/unit/ovsync-tren.test.js (59.627448ms)
  'test failed'
```

`node --test tests/unit/ovsync-tren.test.js` (sonra PASS)

```
rc: 0
✔ aşama aksiyon: 2 → kaydır yok, PG48+BASTAN var; 1 → ertele; 0 → sonraki tren; offline → "" (0.800243ms)
✔ doğum PG hatırlatma: başlık sayısı, d2/d25 satırları, boş → "" (0.359753ms)
✔ hata metni: OVSYNC_TREN_ERTELE_DUSTU düşen küpeleri listeler (0.25527ms)
✔ hata metni: plan kodlarının hepsi tanınır; bozuk JSON ve bilinmeyen sessiz değil (0.470173ms)
✔ renk: üretilen HTML'de background/border-left şerit yok (0.947469ms)
ℹ tests 28
ℹ suites 0
ℹ pass 28
ℹ fail 0
ℹ cancelled 0
ℹ skipped 0
ℹ todo 0
ℹ duration_ms 314.627098
```

`node --test tests/unit/`

```
rc: 1
ℹ tests 2281
ℹ suites 61
ℹ pass 2277
ℹ fail 4
ℹ cancelled 0
ℹ skipped 0
ℹ todo 0
ℹ duration_ms 11486.539142
✖ failing tests:
test at tests/unit/degisiklikler-etiketler.test.js:88:1
✖ LUNA-3: canlı DEMO information_schema ↔ harita (haritasız canlı kolon = KIRMIZI) (1902.339366ms)
test at tests/unit/erteleme-genel-ui.test.js:262:1
✖ EG-7: _erteleKaydet — rpc("gorev_ertele") çağrısı + toplam_erteleme_gun ve uyari toast'ta (57.746885ms)
test at tests/unit/erteleme-genel-ui.test.js:292:1
✖ EG-8: _erteleKaydet — toplam 0 / uyari yok → ek metin YOK (kirli süreç yok) (37.434495ms)
test at tests/unit/vaka-toplu-ac.test.js:2624:3
✖ ay ‹/› : etiket değişir, seçim korunur (kanonik sayfalama — W20 dili; bugüne-göre, tarihe sabit DEĞİL) (1.454447ms)
```
(ham çıktının özet satırları + başarısız test listesi; çıktının son satırları vaka-toplu-ac AssertionError yığınıdır.)

Taban koşumu — UA1'in iki dosyası çalışma ağacından geçici çıkarılıp aynı 3 dosya koşuldu (dosyalar geri kondu, commit'lendi):
`node --test tests/unit/degisiklikler-etiketler.test.js tests/unit/erteleme-genel-ui.test.js tests/unit/vaka-toplu-ac.test.js`

```
rc: 1
ℹ tests 258
ℹ pass 254
ℹ fail 4
✖ LUNA-3: canlı DEMO information_schema ↔ harita (haritasız canlı kolon = KIRMIZI) (1067.800418ms)
✖ EG-7: _erteleKaydet — rpc("gorev_ertele") çağrısı + toplam_erteleme_gun ve uyari toast'ta (12.195984ms)
✖ EG-8: _erteleKaydet — toplam 0 / uyari yok → ek metin YOK (kirli süreç yok) (9.835624ms)
✖ ay ‹/› : etiket değişir, seçim korunur (kanonik sayfalama — W20 dili; bugüne-göre, tarihe sabit DEĞİL) (1.481755ms)
```
Sonuç: 4 kırmızı UA1'den bağımsız, önceden var (MEASURED; hiçbiri `ovsync-tren`e başvurmuyor — grep boş). UA1 yeni kırmızı eklemez.
Kabuldeki "tamamı kırmızı değil" ifadesi "UA1 yeni kırmızı eklemez" diye okundu (assumption kırıntısı).

Mutant kontrolü (ek, MEASURED): 8 mutant — çevrimdışı kontrolü silme, ritim dışında ertele düğmesi, SECIM onayını her zaman açma,
JSON hata bildirimini susturma, TOHUMLAMA_PLANLI'yı hep true yapma, aşama düğmelerinin çevrimdışı kapısını silme, R4 kısa yolunu silme,
UTC yerine yerel saat Date — hepsi en az 1 testi düşürdü (8/8 OLDU); dosya özgün haline geri yazıldı (`git status` temiz).

## Kırıntılar

- measurement: UA1 28/28 PASS, 8/8 mutant öldü, commit 192570a.
- assumption: kabul "tüm paket kırmızı değil" = yeni kırmızı yok; 4 taban kırmızısı UA1 dışı.
- decision: aksiyon sözleşmesi `data-ovt-aksiyon` + `data-*` (UB3/UB4 bağlar).
- open_item: onizle `kupe_no/kural_tarihi/uye_kupeler`, D7 plan üyesinde `tren` alanı, üyede `pg_pay`, uyarıda `kupe_no` RPC'de yok —
  kapanış: UB1–UB4 ya da D4/D6/D7 bu alanları sağlar ya da sapma kabul edilir.
- Kod keşfi: gitnexus `status` → bu worktree indekslenmemiş ("Repository not indexed"); yeni dosya oluşturuldu, mevcut sembol
  değişmedi (etki analizi gerekmedi). `analyze --index-only` koşulmadı: worktree hiç indekslenmemiş, sıfırdan indeks kurmak brief dışı.
