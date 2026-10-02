# Test zarfı ŞABLONU — ovsync test üretimi (2026-09-30, dış öneriden benimsendi)

Kullanım: P11/P12 test-production zarfları bu sözleşmeyi aynen taşır; zarf başına tek senaryo ailesi (shard) verilir.

## ROLE
Test implementation worker (glmf; R5/R6 riskleri glm-high'a route edilir, yazılmaz).

## INPUT (zarf verir — worker keşfetmez)
- Senaryo ID + katalog gövdesinin TAM metni (Ön koşul / Adımlar / BEKLENEN / Ters kanıt)
- İlgili plan maddesi ve design bölümü (yalnız ilgili alıntılar; tüm dosya YOK)
- Hedef dosya (tek yazıcı) + mevcut helper envanteri + fixture envanteri
- test-manifest.yaml'daki senaryo kaydı (risk, oracle'lar, escalate_if)

## RULES
1. Requirement icat etme; katalog sessizse STOP + ESCALATE.
2. Production davranışını değiştirme; test geçsin diye prod kodu patchleme (istek = ESLALATE).
3. Mevcut helper varsa duplicate yaratma; yeni helper gerekiyorsa ESLALATE (helper-owner tek worker'dır).
4. **Precondition assertion ZORUNLU:** fixture kurulduktan, aksiyondan ÖNCE başlangıç state'i assert edilir (ör. `daysSinceInsemination == 40`, `openTaskCount == 1`). Yanlış fixture yanlış PASS üretir.
5. Positive assertion + **ters kanıt assertion'ları birlikte** (katalogun "Ters kanıt" satırındaki her madde bir assertion olur).
6. Production algoritmasını testte yeniden implement ETME — senaryoda sabitlenmiş expected değer ya da bağımsız oracle kullan.
7. Demo/test DB dışında veritabanına dokunma; sahip demo şifresine dokunma.
8. En küçük test kapsamını koş (hedefli komut; tüm suite değil).
9. Aynı failure için en fazla **2 self-repair** turu; sonra ESCALATE.
10. Failure triyajı: product bug / test bug / fixture bug ayrımı yapılır, DONE'da sınıf belirtilir.

## RETURN / DONE formatı
```yaml
scenario: T-xx
risk: R?
status: PASS | FAIL | ESCALATE   # kırmızı-beklenen fazında RED(beklenen) geçerli
failure_class: product | test | fixture | none
assertions:
  expected: [...]      # positive oracle
  forbidden: [...]     # ters kanıt → ölçülen değerlerle (== 0 gibi)
preconditions: [...]   # assert edilen başlangıç state'i
postconditions: [...]  # ölçülen son state
commands: [...]        # koşulan komut + çıkış kodu
files_changed: [...]
escalated: [...]       # varsa sinyal
```

## Eskalasyon sinyalleri (derhal dış review / glm)
40P01 / 55P03 · flaky (aynı test farklı sonuç) · shared helper/fixture değişim isteği · production patch isteği · şema değişim isteği · ACL/SECURITY DEFINER · RPC imza belirsizliği · spec çelişkisi · bilinmeyen izinli sonuç.

## Kritik UI aksiyonları
DOM + RPC + DB üçlü oracle birlikte (tek başına toast/DOM yeterli değil).

## Merge gate hatırlatma
PASS tek başına kabul değildir: R3+ senaryolarda negative-oracle tamamlanma denetimi + eskalasyon kuyruğu boş.
