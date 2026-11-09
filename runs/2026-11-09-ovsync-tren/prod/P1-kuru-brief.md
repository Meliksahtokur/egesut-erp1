# N7 P1 — prod kuru ölçüm (SALT-OKUMA)
job_id: j-20261109T190140Z-68caa5

İlk iş: ~/.claude/skills/using-superpowers-obra/SKILL.md oku ve uygula (sahip kuralı; SUBAGENT-STOP bu kural için geçersiz).
Sonra oku: ~/.herdr/worktrees/egesut-erp1/ovsync-tren/.harness/references/domain-rules.md, PLAN N7 (~/.herdr/worktrees/egesut-erp1/ovsync-tren/docs/plans/2026-11-09-ovsync-tren/PLAN.md:614-633) ve D0 bölümü (16 fonksiyon md5 tablosu), ~/.herdr/worktrees/egesut-erp1/ovsync-tren/.harness/runbooks/db-migration.md, prod erişim yolu: ~/.claude/projects/-home-melik-egesut-erp1/memory/live-schema-verification-mgmt-api.md ve ~/.claude/projects/-home-melik-egesut-erp1/memory/supabase-mgmt-token-setup.md.

## Plan maddesi
PLAN N7 P1 (a)-(d) + (e):
(a) 16 fonksiyonun prod `md5(prosrc)` (ya da D0'daki ölçüt neyse) = D0 tablosu; uyuşmayan varsa ad + iki değer.
(b) 2026-11-09'dan sonra açılmış açık d2/d25/d39 doğum sonrası PG görevleri listesi (hayvan küpe, görev id, hedef tarih).
(c) Eski `ACIK-DISI` çakışmasıyla takılı, apply sonrası görev doğacak hayvanlar (PLAN/D3'teki `TR-ANAH-GOC` sorgusu).
(d) Aktif OVSYNC vakaları + D0 tarihleri + aşama (aşaması belirlenemeyenler ayrı "belirsiz_asama" listesi).
(e) Sahip sorusu (birebir: "örn 12 kasımdan 2 sonra tren varsa ikisi birleşmeli"): açık OVSYNC_BASLAT görevlerinin hedef tarihleri 2026-11-09..2026-11-26 aralığında gün gün liste (küpe, hedef, görev id) + 12 Kasım'da eski yolla başlayacak 4 hayvanın (36/38/169/5708) bugünkü görev/vaka durumu. Amaç: çapa 2026-11-12 ile hangi hayvanın 12 Kas trenine, hangisinin 19 Kas trenine düşeceğini göstermek (yorum: tren her Perşembe; 12 Kas Perşembe).

## Model
opus (ss-worker-high) — canlı prod yüzeyi

## Yazılabilir dosyalar
~/.herdr/worktrees/egesut-erp1/ovsync-tren/runs/2026-11-09-ovsync-tren/prod/P1-kuru-report.md

## Önceden cevaplanmış kararlar
- YALNIZ SELECT / pg_get_functiondef / catalog sorgusu. INSERT/UPDATE/DELETE/DDL/fonksiyon çağrısı (yan etkili RPC) KESİNLİKLE YOK. Şüphede sorgulama, report'a yaz.
- Hiçbir şeyi commit etme; report repo içinde izlenmeyen dosya olarak kalır (root commitler).
- Sır/parola/token/proje ref'ini report'a yazma (public repo); prod satır id'leri report'ta kalabilir ama hayvan sahibi kişisel veri yok.
- Sahip N7 zamanlaması: demo onayından sonra hemen (12 Kasım öncesi). Bu brief yalnız ölçüm.

## Run
(salt-okuma ölçüm; report'ta her sorgunun birebir metni + satır sayısı)

## Review: T0

## DONE
Report: ~/.herdr/worktrees/egesut-erp1/ovsync-tren/runs/2026-11-09-ovsync-tren/prod/P1-kuru-report.md — `sonuc: TAMAM|KISMI|BLOKE`, (a)-(e) tabloları, her birinde 1 satırlık "sahip için anlamı", teknik engel görülürse `ENGEL:` satırı (N7'yi 12 Kasım öncesi yapmaya mani olan her şey).
