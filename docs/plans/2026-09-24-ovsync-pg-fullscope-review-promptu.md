# ULTRACODE KOŞUCU PROMPTU — Ovsync/PG full-scope review turu

> Bu dosya bir **yönlendirme zarfıdır**: koşucuya NEYİ inceleyeceğini ve hangi
> çapalara bakacağını söyler. Nasıl inceleyeceğine, hangi workflow/lensa
> koşacağına koşucu karar verir. Bulgular serbest — beklenen sonuç şekli
> tanımlıdır, sonuca dair hiçbir beklenti DAYATILMAZ.

## Görev

EgeSüt ERP'de (repo kökü bu dosyanın bulunduğu worktree/repo) **X işleri
yapıldı ve prod'a çıkarıldı** (2026-09-24): Ovsync/PG/tohumlama kuralları —
DB migration'ları, kabul betiği, UI implementasyonu, Pages yayını, iki
ortamda bayrak açıldı. **Full-scope review turu koş:** biten işin tamamını,
iddia edilenlerle gerçekleri karşılaştırarak incele.

Kapsam (hepsi — eksiksiz):

1. **DB:** `supabase/migrations/20260923000001..6` + `20260924000001..2`,
   SPEC'teki S-1..S-10 + R3.1 + R3.2/SK6-SK10 maddelerinin koda gerçekte
   yansıyışı, ACL/REVOKE iddiaları, trigger'lar, idempotency.
2. **Kabul betiği:** `supabase/tests/ovsync_pg_kabul.sql` (456 lokal /
   445 demo PASS iddiası) — betiğin kendisi de inceleme konusu: zayıf assert,
   kendi kendini doğrulayan fixture, kapsanmamış yol.
3. **UI:** `docs/plans/2026-09-24-ovsync-pg-PLAN.md` P1-P10'un
   implementasyonu (js/ui.js, js/forms.js, js/api.js, js/config.js,
   js/utils/errorHandler.js, js/utils/handlers.js, index.html) — PLAN DRIFT
   (madde dışına çıkılmış mı), escAttr/XSS, modal-router invariant'ları,
   bayrak-kapalı davranış aynası (MK5), offline kuyruk etkileşimleri.
4. **Yayın:** `.github/workflows/pages.yml` vendor/ fix'i, `?v=20260924-01`
   damgası tutarlılığı, Pages'te yayınlanan set ile repo farkı.
5. **Operasyonel iddialar** (reports/2026-09-24-ovsync-pg-tamamlandi.md):
   SK10=10 vaka, 41 rota / 11 zincir, veri-eşleşme temiz — bunlar ÖLÇÜM
   iddialarıdır; kanıtı yeniden ölçülebilir yerlerde yeniden ölç.

## Çapalar (kanıt noktaları)

- SPEC (kanonik): `docs/plans/2026-09-23-ovsync-pg-tohumlama-SPEC.md`
- UI PLAN: `docs/plans/2026-09-24-ovsync-pg-PLAN.md`
- Teslim raporu: `reports/2026-09-24-ovsync-pg-tamamlandi.md`
- Root görev tanımı (kapılar, D backlog): `docs/plans/2026-09-24-ovsync-pg-root-ultracode-prompt.md`
- Kabul koşum komutu: `supabase/tests/README.md` (lokal DB: `scripts/kabul-db/build.sh`)
- Kırıntı/board: `.crumbs/ovsync-pg-sql.jsonl`, `.ss/ovsync-pg-sql-BOARD.md`

## Kurallar

- **Salt-okunur:** kod/DB'ye DÜZELTME yok; bulgu raporu üret. (Lokal kabul
  betiği ROLLBACK'li koşulabilir; canlı DB'lere yalnız SELECT.)
- **Kanıt zorunlu:** her bulgu dosya+satır ya da sorgu+çıktı ile; KANIT
  etiketi disiplini (repo skill'i `ultracode-rehber`).
- İddialara GÜVENME, yeniden ölç ("bayrak kapalıyken davranış bit-bit aynı"
  gibi) — ama görüşü koşucunun kurması gerekmiyorsa kurma: sadece ölç.
- MAX_CONC=6 (repo sabiti); `js/ui.js` monolit incelemesi `ss-parallel-review`
  kalıbına uyar; hangi workflow'un koşacağı koşucunun kararı.
- Çıktı: `reports/2026-09-25-ovsync-pg-fullscope-review.md` — bulgu listesi
  (kritiklik sıralı, kanıtlı), "iddia ↔ gerçek" çelişki tablosu, kapsanmayan
  alanların açık beyanı. findings boş olabilir; boş sonuç = bulunamadı, üstünü
  doldurma.

## Açık uçlar (koşucunun özellikle gezmesi beklenen — ama listeyla sınırlı değil)

- dry-run bayrak-yoksayan eligiblelik (`20260924000002`) — kapı-5 bug fix'inin
  yan etkileri
- UI P5 "Boş ata ve uygula" zincirinin yarış koşulları (çift dokunuş, offline)
- api.js offline kuyruğun yeni RPC'lerle etkileşimi (pull setleri vs replay sırası)
- SK10 geçişinin kapattığı vakalarda iptal edilen seansların stok etkisi
- demo ile prod arasındaki davranış farkları (pg_cron demo'da yok vb.)
