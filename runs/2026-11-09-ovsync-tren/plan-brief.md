[model=opus] [effort=high] [rol=ss-mimar · iş=ovsync-tren-plan]
job_id: j-20261109T073651Z-b3f710
MUSE-YEDEK: tedavi-arge ve halef işleri Muse kullanmaz (sahip 2026-11-07, hafıza tedavi-arge-yalniz-anthropic-codex); plan yazarı Anthropic opus high.
tip: plan

# Brief — Ovsync Treni uygulama planı

## Plan maddesi
Sahip onaylı spec'ten (2026-11-09, "tamam kral yazalım") uygulama planı yaz.
- Spec (bağlayıcı): ~/.herdr/worktrees/egesut-erp1/ovsync-tren/docs/plans/2026-11-09-ovsync-tren/design.md (K1–K11, Faz 0, §5 hesap/veri, §6 ekranlar, §7 hata, §8 test, §9 domain-rules).
- Domain kuralları ZORUNLU: ~/.herdr/worktrees/egesut-erp1/ovsync-tren/.harness/references/domain-rules.md (§5, §18 tamamı, §18.19 yeni).
- Harness: ~/.herdr/worktrees/egesut-erp1/ovsync-tren/AGENTS.md, .harness/contract.md, .harness/acceptance.md, .harness/references/ui-map.md, rpc-reference.md.
- Keşif kanıtı (prod fonksiyon gövdeleri, giriş noktaları G1–G9/V1–V7, tuzaklar T1–T11):
  ~/.herdr/worktrees/egesut-erp1/tedavi-arge/runs/2026-11-09-ovsync-toplu-gun/tren-kesif-report.md
  ~/.herdr/worktrees/egesut-erp1/tedavi-arge/runs/2026-11-09-ovsync-toplu-gun/ovsync-hafta-report.md
  ~/.herdr/worktrees/egesut-erp1/tedavi-arge/runs/2026-11-09-ovsync-toplu-gun/kanit/fn/*.sql
- İlk iş: Skill writing-plans-obra yükle ve uygula. Kod keşfi: atlas (egesut JS) → gitnexus (indeks tazeliğini HEAD ile karşılaştır) → LSP → grep. Değişecek her RPC/JS sembolü için code-change-precheck skill'inin istediği etki listesi plana girsin.

## Model
opus / high (plan). Plandaki görevler için model önerisi: DB/RPC/migration ve UI görevleri opus (sahip 2026-10-02 "UI/UX+DB plan/uygulama opus"), basit mekanik alt işler sonnet-medium; review kademesi T0/T1/T2.

## Yazılabilir dosyalar
~/.herdr/worktrees/egesut-erp1/ovsync-tren/docs/plans/2026-11-09-ovsync-tren/PLAN.md
~/.herdr/worktrees/egesut-erp1/ovsync-tren/runs/2026-11-09-ovsync-tren/plan-report.md
Başka dosya yazma. Kod/migration YOK. Commit: yalnız PLAN.md (`git add -f` — docs/plans gitignore'da; dosya dosya).

## Planın içermesi gerekenler
1. Faz 0 → Faz 1 (DB) → Faz 2 (UI) → demo kapısı → sahip demo → prod runbook sırası; her görev: amaç, dosyalar (yol), test-önce adımları (kırmızı→yeşil), `## Run` kabul komutları, boyut tahmini, model, review kademesi, bağımlılık (DAG).
2. Migration isimlendirme (supabase/migrations/2026111x…; append-only; mevcut seriyle çakışmasın — son migration adını ölç), her migration için `scripts/db-validate.sh` (seri `--priors`) adımı.
3. Supabase default-privilege tuzağı: yeni SECDEF iç yardımcılarda `REVOKE … FROM PUBLIC, anon, authenticated`; dışa açık RPC'lerde anon EXECUTE yok (hafıza anon-execute-acigi).
4. TR saat dilimi (CURRENT_DATE UTC tuzağı — hafıza tz-current-date-sunucu-dersi).
5. `supabase/tests/ovsync_tren_kabul.sql`: K1–K11 pozitif+negatif assert listesi, bayrak kapalı regresyon eşitliği, göç önce/sonra, ACIK-DISI anahtar çakışması senaryosu.
6. Sunucu kilidi K10 (gorev_ertele, vaka_kalan_gunleri_kaydir(_coklu), tohumlama_gorev_ertele) + JS görevler ekranı entegrasyonu; çoklu erteleme atlama dönüşü.
7. K11 geç tamamlama: seans_tamamla PG olay zamanı Ovsync'te gerçek an (T1).
8. Göç: 22 ileri tarihli OVSYNC_BASLAT yeniden hedefleme (kuru-koşu önizleme + uygulama ayrı adım).
9. UI: her ekran için önce PNG mockup görevi + sahip onay kapısı (UI renk minimal: vurgu yalnız yazı rengi); sonra uygulama; js cache-bust (?v=) adımı.
10. Demo kapısı: demo DB apply sırası, gerçek demo e2e (stub değil), worker sonnet-medium tarayıcı UI yürüyüşü test listesi (madde başına beklenen görünüm + sahibin karar sorusu ölçütü).
11. Prod runbook: yedek (scripts/backup-local-state + DB yedek), apply sırası, bayrak açma (çapa 2026-11-12), veri-eslesme-kontrol hepsi, geri alma SQL'i.
12. "Önceden cevaplanmış kararlar" bölümü (spec Kararlar tablosundan) — worker'lar bunlar için soru sormaz.
13. Açık sorular: spec'te plan kararına bırakılanlar (çapa tarihinin numeric tabloda tutuluşu, RPC adları) → kendin `Ruling:` ile karar ver, gerekçe yaz; yalnız spec'i değiştiren konu sahip sorusu olur.

## Boyut bütçesi
Plan tek dosya; gereksiz tekrar yok. Görev başına net dosya listesi.

## Review: T2
Plan kapısı: ss-reviewer-kapi opus high, 6 boyut × 1-5; KABUL = ort ≥ 4.0 ve hiçbir boyut < 3.

## Önceden cevaplanmış kararlar
Spec "## Kararlar" tablosu aynen geçerli (A yolu, öne çekme 2, ritim kayar, PG tolerans 1, aşama 2 erteleme yok, hastalık → bağımsız, K10 sahiplik, C reddedildi, doğum sonrası PG → hatırlatma + arşiv, düve 13 ay beklemez). Çevrimdışı K8 online şartlı; toptan erteleme ya-hep-ya-hiç.

## Rapor
~/.herdr/worktrees/egesut-erp1/ovsync-tren/runs/2026-11-09-ovsync-tren/plan-report.md — plan yolu + commit SHA + görev sayısı + Ruling listesi + açık sahip soruları. Dönüş ≤5 satır.
