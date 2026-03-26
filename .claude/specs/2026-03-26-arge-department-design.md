# ArGe Departmanı Tasarımı — EgeSüt ERP
**Tarih:** 2026-03-26

## Özet
Projeyi sürekli geliştirmek için otonom çalışan iki katmanlı ArGe sistemi.
Aktif direktif varsa ona odaklanır, yoksa pasif olarak iyileştirme fırsatı arar.

## Agent Hiyerarşisi

```
Orkestratör
    └── arge-analyst (Sonnet, medium, background)
            ├── arge-web-researcher (Haiku, low) — paralel spawn, teknik web
            └── arge-local-reader   (Haiku, low) — proje dosyaları
```

## Çalışma Modları

### Direktif Modu
Orkestratörden görev gelir → analyst tüm enerjisini o göreve verir.

### Otonom Mod (pasif ArGe)
1. Son kontrol edilen commit hash'i memory'den oku
2. `git log` ile yeni commit var mı bak
3. Yoksa → dur, token harcama
4. Varsa → local reader ile değişiklikleri anla → web researcher ile araştır → knowledge/ yaz

## Bellek Mimarisi

```
.claude/
├── memory/
│   ├── arge-analyst.md          # analistin kişisel öğrenmeleri, son commit hash
│   └── arge-web-researcher.md  # araştırılan sorgular, tekrar önleme
└── knowledge/
    ├── findings.md              # tarihli ham bulgular
    ├── improvement-proposals.md # öncelikli iyileştirme önerileri
    └── applied-improvements.md  # uygulananlar (arşiv)
```

## Tetikleyiciler

| Tetikleyici | Mekanizma | Aksiyon |
|---|---|---|
| Reaktif | PostToolUse / git commit | dirty flag → analyst kontrol eder |
| Otonom | Analyst background aktif | git diff → değişiklik varsa araştır |
| Direktif | Orkestratör mesajı | Direktife odaklan |

## Token Tasarrufu Kuralları
- Web researcher: maks 3 WebSearch + 5 WebFetch / görev
- Araştırma öncesi memory kontrol — bilinen konu → araştırma yok
- Relevans skoru 1 bulgular raporlanmaz
- Local reader Haiku — Sonnet dosya okumaz

## Çıktı Akışı
Detay → `knowledge/findings.md`
Öneri → `knowledge/improvement-proposals.md`
Özet → orkestratöre (önemli ise)
Startup → bekleyen öneri sayısı
