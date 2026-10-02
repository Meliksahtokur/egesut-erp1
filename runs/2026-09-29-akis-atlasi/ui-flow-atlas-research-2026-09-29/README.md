# UI Flow Atlas Araştırması — 2026-09-29

Bu paket, `arastirma-PROMPT.md` içindeki soruyu yanıtlar: AI kodlama ajanlarının bir Vanilla JS + Supabase + IndexedDB uygulamasının **gerçek UI akışlarını keşfetmesi, kanıtlaması ve kalıcı/makine-okunur bir akış atlasına dönüştürmesi** için güncel araç ve yöntemler.

## Kısa sonuç

Tek bir araç bütün zinciri güvenilir biçimde çıkarmıyor. En uygulanabilir çözüm dört katmanlı:

1. **Keşif / test planı:** Playwright Test Agents + gerektiğinde Playwright MCP.
2. **Runtime kanıt:** Playwright trace + HAR/network eventleri + dialog kaydı + IndexedDB diff.
3. **Derin tarayıcı teşhisi:** Chrome DevTools MCP; özellikle network, console ve performans/trace doğrulaması.
4. **Backend zinciri:** `plpgsql_check` + PostgreSQL katalogları (`pg_trigger`, `pg_proc`) + `cron.job` / `cron.job_run_details`.

GitNexus mevcut statik call graph katmanı olarak korunur; runtime izleriyle birleştirilir. Crawljax'ın state-flow graph fikri doğrudan değerlidir ancak son Maven sürümü 1 Haziran 2023 olduğundan 2026 için ana motor olarak önerilmez.

## Kanıt etiketleri

- **CONFIRMED:** resmî doküman, güncel kaynak kodu veya sürüm kaydıyla doğrulandı.
- **REPORTED:** GitHub issue/discussion veya kullanıcı raporu.
- **INFERRED:** kaynaklardan türetilmiş mimari/uygunluk değerlendirmesi; bu oturumda uygulama üzerinde ölçülmedi.
- **UNVERIFIED:** doğrulama tamamlanamadı.

Bu araştırmada egeSüt uygulaması canlı olarak çalıştırılmadı; dolayısıyla performans ve kapsama oranları **TESTED-LOCAL** değildir.

## Paket

- `SENTEZ.md`: karar odaklı ana sonuç.
- `parts/PART-01..08.md`: ayrıntılı araştırma.
- `SOURCES.md`: kaynak kayıtları ve erişim tarihleri.
- `EVIDENCE.md`: ana iddia → kaynak → güven tablosu.
- `diagrams/*.mmd`: düzenlenebilir Mermaid diyagramları.
- `data/candidates.csv`: aday araç matrisi.
- `tests/PILOT-1DAY.md`: 1 günlük pilot reçetesi.
- `MANIFEST.sha256`: paket bütünlük özeti.

## GitTrend kontrolü

GitTrend ana sayfasına erişildi ve aktif proje sinyali olarak kontrol edildi. Araç bazlı doğrudan repo URL kalıbı bu web ortamında erişilemedi; bu nedenle GitTrend üzerinden adaylara sıralama/puan atfedilmedi. GitTrend kalite kanıtı olarak değil trend sinyali olarak ele alındı.


## Mermaid render notu

Bu çalışma ortamında `mmdc` bulunmadığından `.mmd` dosyaları SVG’ye render edilmedi. Diyagramların düzenlenebilir Mermaid kaynakları ZIP içinde korunmuştur; render başarısı iddiası yapılmamıştır.
