# İkiz Doğum Desteği

## Sorun
`dogum_kaydet` her çağrıda 9 anne görevi + buzağı görevleri oluşturuyor.
İkiz doğumda aynı gün 2 kere çağrılınca:
- 18 anne görevi (duplike)
- dogum tablosunda 2 kayıt → scanner her adımı çift gösteriyor
- gorev_log'da duplike protokol görevleri

## Beklenen Davranış
Aynı anne için aynı gün ikinci `dogum_kaydet` çağrısı:
- Yeni buzağı kaydı oluşturmalı (kendi görevleriyle)
- Anne görevlerini TEKRAR oluşturMAMALI (zaten var)
- dogum tablosuna 2. kayıt giriyor — bu doğru (2 buzağı = 2 doğum)
- Scanner sadece 1 doğum event'i olarak görmeli

## Etkilenen Alanlar
- `dogum_kaydet` RPC — `WHERE NOT EXISTS` kontrolü eklenebilir
- `protokol_eksik_tara` scanner — `DISTINCT ON (d.anne_id)` ile korunuyor (fix-v2'de yapılacak)
- UI doğum formu — ikiz bilgisi gösterilebilir

## Notlar
- 2026-06-03'te tespit edildi (protokol uyarı sistemi review sırasında)
- Şimdilik scanner DISTINCT ON ile duplikasyonu engelliyor
- Tam çözüm ayrı bir spec/plan gerektirir
