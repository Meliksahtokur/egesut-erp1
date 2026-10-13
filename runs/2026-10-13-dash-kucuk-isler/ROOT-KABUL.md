# ROOT-KABUL — dash-kucuk-isler (2026-10-13)

Kapsam: (1) aktif OVSYNC vakalı hayvanlar sessiz listeden dışlanır (`sessiz_hayvanlar_listele`, migration 20261013000001); (2) ileri gebeler bandı — tüm düvelerde D-n mavi, alt satır amber yazı; kuru padoğa alınmış düve ineklerle gün sırasında, diğer düveler en altta (sahip nihai kuralı, F2).

| Bulgu / kapı | Sonuç | Commit | Ölçüm |
|---|---|---|---|
| Sessiz liste OVSYNC dışlama | TAMAM | 283bc85 | SQL testi kırmızı→yeşil, mutant kırmızı; canlı salt-SELECT: 110, 188 düşer, başka düşen 0; canlı gövdeyle tek fark dışlama (verifier) |
| İleri gebe ilk tur | yerine F2 geçti | 139418a, 14631f9 | — |
| F1 (satır zemini/şerit) | sahip reddetti → F2 | 6d42e2a | — |
| F2 sahip nihai kuralı | TAMAM | 79feea2 | 12 test yeşil + mutant kırmızı; unit suit 1523: yalnız 4 pre-existing fail (LUNA-3, EG-7, EG-8, ay-etiketi; tabanda f566ffa'da da kırık, MEASURED); F2-dark.png root göz kontrolü |
| Review | KABUL (ss-reviewer opus) | 14631f9 | KUCUK-review.md |
| UI kapısı | 7/7 PASS + F2 PNG | — | ui-kapi/UI-KAPI-report.md, F2-dark.png; sahip demoda onayladı ("tamamdır bu kadar") |

Ruling: db-validate INCONCLUSIVE (PG 17.6/18.6 + ayna paritesi), C1 apply + squawk + RLS PASS — kabul; 4 pre-existing unit fail istisnası.
Sahip kararı (SAHIP-KARARLARI 9): merge + push EVET; migration canlıya EVET.
