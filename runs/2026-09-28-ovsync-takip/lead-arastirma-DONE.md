sonuc: TAMAM

kalem 1 (ÖN OKUMA): TAMAM — domain-rules.md (§4/§8/§12/§18), rpc-reference.md, ui-map.md okundu;
  uygulanabilir kurallar sentezde kullanıldı (§18 kural günü/pencere/kısır/PG+48s/online-only;
  özellikle §18.8 PG onay kapısı ve §18.11 gebe otoritesi tasarım malzemesine bağlandı).

kalem 2 (W1 kod anatomisi): TAMAM — 8 yüzey (sessiz band+sheet, ileri gebeler, Görevler, Üreme,
  Protokol paneli, belirsiz üreme, ovsync temas noktaları, vaka detay+timeline); her yüzeyde
  veri kaynağı/api.js yolu/render/filtre-sıralama/tıklama akışı [CONFIRMED dosya:satır] ile.
  Kanıt: w1-kod-raporu.md (270 satır).

kalem 3 (W1b parçalar+gap): TAMAM — 14 yeniden kullanılabilir parça + 9 maddelik gap listesi.
  Ana bulgu: zincir-düzeyi takip satırı hiçbir RPC/yüzeyde yok; omurga (band→sheet + uyarı CTE
  modeli) hazır. Kanıt: w1-kod-raporu.md §3-4.

kalem 4 (W2 veri modeli, PROD salt-okuma): TAMAM — 17 nesne envanteri (14 tablo + 3 view),
  vaka/zincir/gün yapısı id referanslarıyla, durum/sonlanma dağılımı (OVSYNC 35: 12 aktif,
  10 TOHUMLAMA, 1 PG, 4 ERKEN_KAPANIS, 1 IPTAL, 7 NULL-eski), açık listesi A1-A10 kanıtlı.
  Kanıt: w2-veri-modeli-raporu.md (~337 satır; tüm PROD erişimi supabase_query SELECT).

kalem 5 (SENTEZ): TAMAM — takip satırı = hayvan×zincir; 4 sabit bölüm (bekleyen başlatma /
  aktif zincir / bugün+geciken / sonlanan); ekran deseni tablosu (A kart-liste+gün-şeridi ÖNERİ,
  B matris FAZ 2, C kanban/D takvim önerilmiyor); veri katmanı: TEK salt-okunur RPC
  `ovsync_takip_listele` (CTE genişletmesi); entegrasyon noktaları tablosu (9 satır, sembol
  düzeyinde); KPA şeridi; 8 sahip-sorusu; 5'li risk listesi.
  Kanıt: sentez-tasarim-malzemesi.md.

fanout özeti: 2 alt-ajan (builtin Agent, model sonnet, paralel) —
  A: W1 → /home/melik/egesut-erp1/runs/2026-09-28-ovsync-takip/w1-kod-raporu.md
  B: W2 → /home/melik/egesut-erp1/runs/2026-09-28-ovsync-takip/w2-veri-modeli-raporu.md
  Tek-yazıcı-per-dosya korundu; worktree HİÇ yazılmadı (git status porcelain boş, @c9122fd).

ana rapor: /home/melik/egesut-erp1/runs/2026-09-28-ovsync-takip/sentez-tasarim-malzemesi.md

acik_kalemler:
  1. Sahip soruları ×8 (sentez §6): yüzeryeri (full-sheet/Üreme-tab/alt-nav), sonlananlar derinliği,
     tohumlama.case_id köprü politikası (A3), toplu işlem fazı, day_no etiket doğrulaması (A10),
     offline politikası, W3 sonrası desen gözden geçirme, matrisin fazı.
  2. Doküman-drift (bu işten bağımsız, root'a taşındı): sessiz eşik canlıda 50 (mig. 20260925000002),
     rpc-reference + domain-rules §4 hâlâ 55 — referans güncelleme ayrı kalem.
  3. W3 dış sektör araştırması sahibin koşacağı prompt'ta bekliyor
     (w3-dis-sektor-arastirmasi-PROMPT.md); sonucu sentez §2/§5'i etkiler.
  4. Bilinmiyorlar (fail-closed, W2): pg_application_event UYGUNSUZ kararı canlıda örneklenmemiş;
     gorev_log.seans_admin_id dolu örnek görülmedi; day_no↔şablon gun_no eşlemesi kanıtsız (INFERRED).

kırıntılar: .crumbs/ovsync-takip.jsonl — 4 kayıt (gate + 2 measurement + 1 decision).
