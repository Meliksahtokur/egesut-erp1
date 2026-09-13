# W4/LEAD — F4 Teslim: Standart kilidi (G-20260913-TARIH-SECICI)

F4, root emriyle LEAD tarafından yapıldı ("yalnız glmf worker ile ya da
kendin bitir" — worker bootstrap maliyeti ve bekleyici kill sorunları
nedeniyle lead seçti). Luna bulgularının çözümüyle birlikte raporlanır.

## 1. Dal + commit

- Dal: `agent/tarih-secici-standardi`
- F4 kod commit'i: `1702126` (guard + karar kaydı + ui-map + domain-rules §17 + red-before log)
- Luna bulgu çözümleri: bu raporu taşıyan commit'in bir öncesi
  (ui.js UTC fix + guard güçlendirmeleri — `f12e8b5` sonrası, `merge:` kapanışından önce)

## 2. Değişen dosyalar (F4 + luna çözümleri)

```text
tests/unit/tarih-saf.test.js                    | guard: +5 test (block-comment soyucu, Date.now, type="date" özyinelemeli tarama, taşıyıcı istisna tüm js/, ad-aileri beyaz listesi)
.harness/decisions/D-20260909-CANONICAL-DATE-PICKER.md | "göç tamamlandı + standart kilitlendi" + API tablosu
.harness/references/ui-map.md                   | kanonik tarih seçimi bölümü güncel gerçekliğe taşındı
.harness/references/domain-rules.md             | §17 alan bazlı tarih kısıtları (cx/sk max=bugun OWNER ONAY notuyla)
.claude/reviews/2026-09-13-tarih-secici-f4-red-before.log | red-before kanıtı
js/ui.js                                        | luna BULGU-4/5: 2× UTC toISOString → bugun() (gece-yarısı kayması)
```

## 3. Test kanıtı

- F4 öncesi: 831/830/1 · F4 sonrası: 836/835/1 (tek kırmızı = bilinen
  `gecmis-pipeline` date-bomb; +5 yeni muhafız, sıfır regresyon)
- Guard'ın kendi koşusu: 40/40
- **Red-before** (`.claude/reviews/2026-09-13-tarih-secici-f4-red-before.log`):
  3 ihlal enjeksiyonu → her muhafız FAIL (index.html type="date" → FAIL;
  tarih.js'e GERÇEK KOD Date.now → FAIL; forms.js'e kopya sembol → FAIL);
  geri alınınca 39/39 yeşil. İlk denemede Date.now'u YORUM içine enjekte
  edilmişti — muhafız doğru şekilde SOYDU (kod değildi); ikinci denemede
  gerçek kod olarak enjekte edildi ve FAIL etti. Nüans raporun parçasıdır.

## 4. Luna bulgularının işlenmesi (BULGU-1..8 → kararı)

| # | Şiddet | Karar | İşlem |
|---|---|---|---|
| 1 | ORTA | DÜZELTİLDİ | F3 denetim raporu lead dalına girmemişti → denetim dalı paketle merge edildi (kapanış `merge:` commit'i) |
| 2 | ORTA | DÜZELTİLDİ | Bu rapor (f4-teslim.md) yazıldı |
| 3 | ORTA | DÜZELTİLDİ | Paket teslim raporu tam dolduruldu (`.harness/reports/2026-09-13-tarih-secici-teslim.md`) |
| 4 | ORTA | DÜZELTİLDİ | ui.js:8111 `i-tarih` UTC doldurma → `bugun()` (yerel); LSP: openPlanliTohumlama 2 çağıran, sözleşme sabit |
| 5 | ORTA | DÜZELTİLDİ | ui.js:2976 `a-dt.max` UTC → `bugun()`; LSP: openAnimalEdit tek nokta; blast-radius hook: gerçek LSP analizi + işaret |
| 6 | ORTA | DÜZELTİLDİ | Guard'a ad-aileri beyaz listesi (26 meşru ad): `Takvim|GunSecim` içeren YENİ `function` adı liste dışıysa FAIL — yeniden adlandırılmış kopya isim düzeyinde yakalanır |
| 7 | DÜŞÜK | BEYAN | `muhafizKaynagi` string-içi yorum metnini soyar → string-içi gizli `Date.now()` kaçar. Statik guard doğal sınırı; string-aware tarama aşırı maliyet. Sınırlılık paket raporunda. |
| 8 | ORTA | DÜZELTİLDİ | Guard özyinelemeli js/ taramasına geçti; runtime istisna sayımı tüm js/ ağacında TOPLAM=1 (ui.js'e özgü değildi) |

## 5. Review notu

`bulgu: luna (codex max gpt-5.6-luna, 23 dk, commit f7ce14e) 8 buldu —
KRİTİK 0, ORTA 7, DÜŞÜK 1; 6'sı DÜZELTİLDİ (bu rapor + paket raporu +
UTC fix ×2 + guard güçlendirme ×2 + denetim dalı merge'i), 1'i BEYAN
(statik guard string sınırı), F3-denetim raporu merge'i kapanış commit'inde.`

## 6. ?v= damga durumu

F4 yalnız test + docs dokundu → bump YAPILMADI (zarf kuralı: runtime
kaynak değişmedikçe damga sabit kalır). Ortak değer `20260913-16`.

## 7. Açık riskler / ertelenenler

- `gecmis-pipeline` date-bomb (bilinen kırmızının kök nedeni `_gmGroupLabel`
  gerçek `new Date()`): bu paketin kapsamı dışı, ayrı onarım adayı.
- cx/sk `max=bugun` + bv tek-aşı hizası: OWNER ONAYI bekliyor
  (domain-rules §17'de belgeli; istenmezse TARIH_ALANLARI'da tek satır geri alma).
- El girişi hata re-render'ında odak kaybı (nit UX) — owner kararı.
