# T2 kapı review şablonu (L-DB; her D<k>-review-brief.md bunu doldurur)

## İş
Görev D<k>'nın diff'ini (base..head) PLAN.md "### D<k>" + "Global Constraints" + Ruling'ler (R1–R20) + Kapı tur 2 ekleri + progress.md RL-*
ile karşılaştırarak kapı review'u yap. Odak (DB/RPC/kilit/göç):
1. Gövde değişiklikleri prod gövdesinden mi türetilmiş (yalnız planın söylediği satırlar farklı mı)? `diff` ile kanıtla:
   kanit/fn/<ad>.sql (ya da db/fn/<ad>.sql DRIFT kopyası) ↔ migration'daki gövde.
2. md5 korumaları doğru değer (db/govde-taban.md prod sütunu) ve doğru imza ile mi?
3. ACL: her yeni/yeniden yaratılan fonksiyonda REVOKE PUBLIC/anon (+ iç yardımcıda authenticated), dış RPC GRANT authenticated.
4. Bayrak 0 regresyon eşitliği: bayrak kapalıyken eski davranış birebir mi (kod yolu + test)?
5. TR tarih (CURRENT_DATE yok), fail-closed hata kodları planla aynı ad/payload.
6. Testler planın listelediği her TR-* id'sini kapsıyor mu; assert gerçekten iddiayı ölçüyor mu (fake-arm / vacuous assert avı);
   senaryo izolasyonu sözleşmesine uyuyor mu.
7. Kapsam: diff yalnız brief'in yazılabilir dosyaları mı (scope-violation).
Run komutlarından EN AZ İKİSİNİ kendin koş (kabul koşumu + db-validate), rc ve son satırı report'a ham yaz.
Mekanik sinyal: `~/tools-bank/scripts/ss-kalite-sinyal --repo <repo> --base <base> --head <head> --butce <butce>` koş, çıktıyı report'a koy.

## Çıktı biçimi (zorunlu)
- İlk satır `⟦ss-sub model=opus effort=high rol=ss-reviewer-kapi iş=D<k> T2 review⟧`, sonra `sonuc: TAMAM|KISMI|BLOKE`.
- `VERDICT: PASS | ÇALIŞIR ama DÜZELT (kalite) | FAIL` tek satır.
- Bulgu başına satır: `[KRİTİK|ÖNEMLİ|KÜÇÜK] <dosya:satır> — <bulgu> — kanıt: <komut/çıktı> — dar fix: <talimat>`.
- `OZET sinyal=<n>` satırı (ss-kalite-sinyal SINYAL sayısı) ve her olcum-yok dışı SINYAL için bir `KALİTE:` satırı (+1 toplu olcum-yok satırı).
- `## Kırıntılar`.
- Salt-okuma: dosya düzenleme, commit, DB'ye kalıcı yazma YOK (kabul koşumu BEGIN/ROLLBACK sarmalı, serbest).
