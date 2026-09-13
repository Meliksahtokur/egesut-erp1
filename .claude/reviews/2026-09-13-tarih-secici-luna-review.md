[BULGU-1] [ŞİDDET: ORTA] .harness/goals/2026/G-20260913-TARIH-SECICI.md:18
Kusur: Aktif goal'un zorunlu F3 bağımsız review raporu lead paketinde yok.
Kanıt: `git cat-file -e agent/tarih-secici-standardi:.claude/reviews/2026-09-13-tarih-secici-f3-denetim.md` `EXIT=128` ile “exists on disk, but not in agent/tarih-secici-standardi” döndü; lead `git ls-tree` yalnız f1/f2/f3-teslim ve f4-red-before raporlarını listeliyor.

[BULGU-2] [ŞİDDET: ORTA] .harness/goals/2026/G-20260913-TARIH-SECICI.md:38
Kusur: Goal manifestinde zorunlu F4 delivery raporu tanımlı olmasına rağmen lead paketinde yok.
Kanıt: `git cat-file -e agent/tarih-secici-standardi:.claude/reviews/2026-09-13-tarih-secici-f4-teslim.md` `EXIT=128` verdi; hedef refte yalnız `.claude/reviews/2026-09-13-tarih-secici-f4-red-before.log` mevcut ve F4 zarfı delivery raporunu ister (`.claude/tasks/2026-09-13-tarih-secici-f4.md:68`).

[BULGU-3] [ŞİDDET: ORTA] .harness/reports/2026-09-13-tarih-secici-teslim.md:12
Kusur: Final paket raporu hâlâ iskelet ve F2-F4 fazlarını `pending` gösteriyor; gerekli SHA, grep, test ve residual-risk kanıtı kapanmamış.
Kanıt: Hedef raporda `F2 | _pending`, `F3 | _pending`, `F4 | _pending` ve `_F2-F4: pending` satırları duruyor; aynı dosya `Faz teslim raporları ... f{1,2,3,4}-teslim.md | dalda commit'li` iddiasını da taşıyor.

[BULGU-4] [ŞİDDET: ORTA] js/ui.js:8111
Kusur: Planlı tohumlama yolu `i-tarih` değerini yerel `bugun()` yerine UTC `toISOString()` ile dolduruyor ve Europe/Istanbul gün başlangıcında bir önceki günü kaydedebiliyor.
Kanıt: Kod `setTimeout(... tarih.value=new Date().toISOString().slice(0,10) ...)`; `TZ=Europe/Istanbul` probe sonucu `utc_derived:2026-09-12`, `local_derived:2026-09-13`, `equal:false`.

[BULGU-5] [ŞİDDET: ORTA] js/ui.js:2976
Kusur: Hayvan düzenleme yolu `a-dt.max` sınırını UTC tarihinden kuruyor ve yerel günün ilk saatlerinde bugün geçerli doğum tarihini takvimden kapatıyor.
Kanıt: Kod `document.getElementById('a-dt').max=new Date().toISOString().slice(0,10)`; aynı Europe/Istanbul probe `utc_derived:2026-09-12` ile `local_derived:2026-09-13` farkını gösteriyor.

[BULGU-6] [ŞİDDET: ORTA] tests/unit/tarih-saf.test.js:481
Kusur: F4 kopya muhafızı renderer gövdelerini isimlerine bağlamıyor; yalnız `function bcTarihTakvim*` regexi ve dosya-geneli `tarihAyIzgara` çağrı sayısı, yeniden adlandırılmış/kopya day-loop'u yeşil bırakıyor.
Kanıt: Muhafız `! /function\s+bcTarihTakvim\w*/` ile 481'de ve aggregate sayımla 483-484'te çalışıyor; gerçek guard mantığı probe'u `renamed_copy_guard_would_pass:true`, `renamed_copy_has_day_loop:true`, `aggregate_forms_core_calls:1` döndürdü.

[BULGU-7] [ŞİDDET: DÜŞÜK] tests/unit/tarih-saf.test.js:426
Kusur: `muhafizKaynagi` yorum belirteçlerini lexical string ayrımı yapmadan siliyor ve string içine yerleştirilmiş gerçek `Date.now()` kodunu gizleyebiliyor.
Kanıt: 426-429'daki `.replace(/\/\*[\\s\\S]*?\\*\//g, '')` için probe `actual_string_mutant_date_now:true` fakat `string_hidden_date_now:true` verdi.

[BULGU-8] [ŞİDDET: ORTA] tests/unit/tarih-saf.test.js:437
Kusur: `type="date"` muhafızı tüm `js/` ağacını ve dinamik/runtime yüzeylerini kapsamıyor; yalnız `js` ve `js/tarih` dizinlerinin doğrudan çocuklarını, bitişik literal attribute'u ve runtime atamasını sadece `ui.js` içinde tarıyor.
Kanıt: 437-442 `for (const dizin of ['js', 'js/tarih'])` + doğrudan `readdirSync` kullanıyor; probe `recursive_scan_implemented:false`, `dynamic_type_guard_would_match:false` ve başka dosyadaki `.type = 'date'` için `other_file_runtime_assignment:true` döndürdü; runtime singleton testi 458'de yalnız `require.resolve('../../js/ui.js')` okuyor.

ÖZET: KRİTİK 0, ORTA 7, DÜŞÜK 1
SONUÇ: BULGULU
