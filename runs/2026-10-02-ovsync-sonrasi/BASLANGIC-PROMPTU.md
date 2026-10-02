# Başlangıç promptu — ovsync takip SONRASI borç turu (2026-10-02)

Aşağıdaki blok yeni oturuma olduğu gibi yapıştırılır.

```
Sen ovsync takip ekranının canlıya alınmasından sonra kalan işleri yürüten devralan ajansın.
Çalışma yeri: main checkout /home/melik/egesut-erp1 (main, 9af4823 ve sonrası). Eski dal ovsync-takip KAPANDI — ona dönme.

İlk iş: Skill(using-superpowers-obra) yükle. Sonra sırayla oku:
1. /home/melik/egesut-erp1/AGENTS.md ve /home/melik/egesut-erp1/.harness/contract.md
2. /home/melik/egesut-erp1/.harness/references/domain-rules.md (ZORUNLU — plan/SQL/impl'den önce; §18 ovsync/PG kuralları)
3. /home/melik/egesut-erp1/.harness/goals/2026/G-20260930-OVSYNC-TAKIP-IMPL.md — "teknik borç" bölümü (TB-1..TB-7) ve son checkpoint'ler
4. /home/melik/egesut-erp1/runs/2026-09-28-ovsync-takip/KAPANIS-DONE-2026-10-02.md (canlıya alma özeti + açık kalemler)
Bu iş için YENİ bir Full-mode goal aç (.harness/goals/2026/G-20261002-...); kapanmış ovsync goal'üne yazma.
Bu belgedeki iş listesinden başla, sahibe önce sıra/kapsam onayı al.

DURUM: ovsync takip canlıda (prod 6 migration + main 8b1c599 + Pages ?v=20261002-01). Demo DB'de 12 E2E-* test hayvanı
'Satildi' kalıntı (pg_application_event FK silmeyi engeller).

KALAN İŞLER (önerilen sıra; her biri ayrı numaralı kalem, DONE birebir sayar):
1. B9 — gebelik_muayene_gorev_uret cron saati (VERİ DOĞRULUĞU, önce ölç): fonksiyon CURRENT_DATE (UTC) yazıyor; prod cron
   saati TR 00:00–03:00'a düşüyorsa görevler 1 gün kayıyor. Önce yalnız-okuma ölçüm (cron.job zamanlaması + son üretilen
   görevlerin tarihleri); düzeltme gerekiyorsa Istanbul yerel gün kalıbı (bkz. migration 20261001000001) + db-validate + sahip onayı.
   Bellek: tz-current-date-sunucu-dersi.
2. GT yenileme — runbook /home/melik/egesut-erp1/.harness/runbooks/db-migration.md adım 6; talimat
   /home/melik/egesut-erp1/runs/2026-09-28-ovsync-takip/impl-P13-DONE.md "sahibe rapor" bölümü. Mekanik.
3. TB-6 — tests/e2e/ovsync-takip.spec.js temizle() hiç çalışmıyor (hayvanı id LIKE MARKER% arıyor; marker kupe_no'da)
   + silme hataları yutuluyor. Düzelt (kupe_no ile ara, hata raporla, FK'lı hayvanı Satildi'ye çek), sonra e2e 12/12'yi geri getir.
   Geçici el araçları: /home/melik/tmp/agents/uitur-20261001/e2e-artik/{olc,temizle,aktif}.cjs. A/B kanıtı: .../e2e-ab/*.log.
4. TB-1 — eski otomatik ui-tur betiği (/home/melik/tmp/agents/uitur-20261001/uitur.spec.js, 63KB, 7/25): sahibe sor —
   önerim ARŞİVLE (25 madde elle yürüyüşle hükümlendi: runs/2026-09-28-ovsync-takip/ui-tur4-DONE.md); triyaj pahalı.
5. TB-5 — birleşik kapıda (PG_KAPI:TAKIP_ACIK) PG kararı sunucudan gelmiyor; UI şimdilik "Son tohumlama sonucu <sonuc>".
   Gerçek çözüm: _pg_kapi_detay'a karar alanı (migration 20260929000002:989 civarı) → db-validate → demo prova → sahip onayıyla prod.
6. TB-7 — ui-fix1 K6 (S0 kartı "TAI bugün") yalnız birim kanıtlı; TAI-bugün/TAI-yarın fixture'ıyla demo tarayıcı kanıtı.
7. TB-3 — ovsync render zaman aşımsız (js/ui.js loadOvsyncDash → _ovsyncBaglamYukle; IDB okuması bitmezse süresiz spinner):
   küçük sertleştirme (zaman aşımı + hata dalı), TDD.
8. TB-2 — demo'da demo_sema_diff RPC 401 (her açılışta konsol hatası); sahiplik/izin kontrolü.
9. TB-4 — tools-bank ram-pool slot sızıntısı (Agent hook slotu alıyor, kill/Agent hatasında release yok) — BAŞKA REPO
   (tools-bank), bu oturumda değil: ayrı talep olarak root'a ilet.

ÇALIŞMA KURALLARI (sahip, bağlayıcı):
- Sahiple Türkçe; sahibe verilen her dosya TAM mutlak yol.
- Yargısız/mekanik işler (test koşumu, betik onarımı, GT yenileme) sonnet'e: builtin Agent subagent_type "test-runner"
  (sonnet+medium) ya da herdr'de ayrı tab'da ss-worker-sonnet-medium / ss-lead-sonnet-medium koltuğu. Opus/claude koluyla
  worker açma. Ultracode YASAK.
- UI işi: sahibe demo vermeden önce test listesi tarayıcıda koşulur (proje CLAUDE.md "UI testi kapısı"). Büyük tek otomatik
  betik yakınsamazsa madde başına küçük betik + gözle hükümlü elle yürüyüşe geç (bellek: ui-tur-otomatik-betik-dersi).
  e2e kırmızısını ürüne yüklemeden önce A/B (HEAD archive vs çalışma ağacı, temizlik sonrası 2 tur) koş.
- Her yeni migration scripts/db-validate.sh'tan geçer; PROD apply, merge, push SAHİP KAPISI (root üzerinden).
- Hasat düzeni: her DONE'da 1-2 yük taşıyan iddiayı kendin doğrula → kırıntı (.crumbs/<iş>.jsonl, bash -c) → commit
  (staged alanı git diff --cached --stat ile doğrula) → sıradaki.
- Demo sahip şifresine dokunma. Sahibe demo vermeden önce kupe_no LIKE 'E2E-%' aktif test hayvanı sayısını ölç (0 olmalı).
- RAM havuzu "kuyrukta bekleme yok (wait_s=0)" ile Agent'ı reddederse: ram-ultracode status ile kendi oturumunun sızmış
  slotunu bul, `ram-ultracode release --pid <oturum> --key <anahtar>` ile bırak (reap sahip kapısı).

ZARF SÖZLEŞMESİ (koltuk olarak çağrıldıysan):
- GOREV: /home/melik/egesut-erp1/runs/2026-10-02-ovsync-sonrasi/BASLANGIC-PROMPTU.md (bu dosya)
- DONE:  /home/melik/egesut-erp1/runs/2026-10-02-ovsync-sonrasi/DONE.md — kalem tablosu (kalem | durum | commit | kanıt),
  sahip kapısında bekleyenler ayrı başlıkta. İş uzarsa ara durumu ILERLEME.md'ye (aynı dizin) yaz.
- Bitince DONE'u yaz, SONRA seni çağıran root'a SendMessage: `DONE: <DONE yolu> · sonuc: <TAMAM|KISMI|BLOKE>`.
- Merge/push/PROD apply root'un ve sahibin kapısıdır — sen dal + commit + talep belgesiyle teslim edersin.
```
