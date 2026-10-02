# UI kapısı GÖREV — ovsync sonrası borç turu (kalem 3/5/6/7/8 tarayıcı kanıtı)

- **Koltuk:** ss-worker-sonnet-medium (sahip kararı 2026-10-02: glmf-max yerine; proje CLAUDE.md "UI testi kapısı" bu koltukla karşılanır)
- **GOREV:** /home/melik/egesut-erp1/runs/2026-10-02-ovsync-sonrasi/ui-kapi-GOREV.md (bu dosya)
- **DONE:** /home/melik/egesut-erp1/runs/2026-10-02-ovsync-sonrasi/ui-kapi-DONE.md
- **Goal:** /home/melik/.herdr/worktrees/egesut-erp1/ovsync-sonrasi/.harness/goals/2026/G-20261002-OVSYNC-SONRASI-BORC.md
- **Kod:** worktree /home/melik/.herdr/worktrees/egesut-erp1/ovsync-sonrasi (dal ovsync-sonrasi; HEAD'i DONE'a yaz). Yerel statik sunucu bu worktree'den, demo modu `?demo`. NODE_PATH=/home/melik/egesut-erp1/node_modules.
- **Demo DB — ADIM 0 (senin işin, testlerden ÖNCE):** worktree'deki `supabase/migrations/20261002000002_pg_kapi_detay_karar.sql` dosyasını DEMO'ya uygula (mimar yetkisi: db-validate e98ae410 PASS; demo apply serbest). Tek transaction (`BEGIN; <dosya>; COMMIT;`), demo `supabase_migrations.schema_migrations`'a `20261002000002` kaydı, sonra `pg_get_functiondef('public._pg_kapi_detay(jsonb,text,text)'::regprocedure)` içinde `'karar'` geçtiğini doğrula. Demo bağlantı/Management API deseni: /home/melik/.claude/projects/-home-melik-egesut-erp1/memory/live-schema-verification-mgmt-api.md + supabase-mgmt-token-setup.md (demo proje ref'ini oradan/`.env`'den bul; PROD ref `zqnexqbdfvbhlxzelzju`'ya ASLA yazma). Çıktıları DONE'a koy. HEAD beklenen `b986755` (damga `?v=20261002-02`). U5 (N-1) için ayrı DB gerekmez: birim testle kanıtlı — tarayıcıda ATLA, DONE'da "birim kanıtlı" yaz.

## Kurallar
- Demo sahip şifresine DOKUNMA (bellek: /home/melik/.claude/projects/-home-melik-egesut-erp1/memory/demo-sahip-sifresi-korunur.md). Kodda gömülü herkese açık demo kullanıcısı serbest.
- Madde başına KÜÇÜK betik ya da elle tarayıcı + gözle hüküm (bellek: ui-tur-otomatik-betik-dersi.md). Tek büyük otomatik betik YAZMA.
- Kendi fixture'ların `kupe_no LIKE 'UIK-%'` önekli (E2E- öneki KULLANMA: paralelde e2e temizliği E2E-* hayvanları süpürüyor); iş sonunda temizle (FK'lı hayvanı durum='Satildi'), DONE'da `SELECT count(*) FROM hayvanlar WHERE kupe_no LIKE 'E2E-%' AND durum='Aktif'` = 0 ölçümünü yaz.
- Fixture'ları ürün RPC'leriyle kur (tohumlama_kaydet, hizli_uygulama vb.); doğrudan tablo yazımı yalnız RPC yolu yoksa ve DONE'da gerekçeli.
- Yazabileceğin dosyalar: yalnız DONE + kanıt dizini `/home/melik/egesut-erp1/runs/2026-10-02-ovsync-sonrasi/ui-kapi-kanit/` + $TMPDIR/~/tmp. Repo koduna YAZMA, git YOK. FAIL'i düzeltmeye çalışma — raporla.
- PROD'a dokunma.

## Test listesi (her madde PASS/FAIL + kanıt: ekran görüntüsü / DOM metni / konsol-ağ kaydı)

| # | Kalem | Adım | Beklenen |
|---|---|---|---|
| T1 | 8 TB-2 | Boş tarayıcı bağlamında `?demo` aç; ağ+konsol kaydı | `rpc/demo_sema_diff` için anon 401 YOK, konsolda 401 hatası YOK; oturum açıldıktan sonra (otomatik giriş/reload) en fazla bir `authenticated` 200 |
| T2 | 7 TB-3 | Ovsync takip sayfası normal aç | Normal render (KPA şeridi + bölümler), hata kutusu YOK |
| T3 | 7 TB-3 | IDB okumasını askıya al (ör. sayfa betiğinde `getData`'yı asla çözülmeyen promise ile override) → ovsync takip aç | ~15 sn sonra spinner gider; "⚠️ Yerel veri okunamadı — takip ekranı hazırlanamadı" + "Tekrar Dene" butonu görünür |
| T4 | 7 TB-3 | Override'ı kaldır → "Tekrar Dene" tıkla | Normal render, hata kutusu kaybolur |
| T5 | 5 TB-5 U1 | Fixture: hayvanın son tohumlaması Bekliyor + açık takip (TAKIP_MUAYENE, Boş sonrası "Takibe bırak") → PG uygula (hızlı uygulama) | "Bu hayvan takipte" sheet'i; "💉 PG kapısı: Son tohumlama sonucu Bekliyor — PG onayı gerekli" metni; "Evet, takibi kapat ve uygula" + "Vazgeç"; "bilinmiyor" YOK |
| T6 | 5 TB-5 U2 | Fixture: son tohumlama Gebe + açık takip → PG uygula; onayla | "💉 PG kapısı: Gebe inekte PG uygulanamaz"; onay sonrası sunucu reddeder: hata toast'u, uygulama OLUŞMAZ (DB: yeni uygulama satırı yok) |
| T7 | 5 TB-5 U3 | Fixture: PG adlı ama katalog bağsız ürün + açık takip → uygula | "💉 PG kapısı: Ürünün PG katalog bağı belirsiz" (fixture kurulamıyorsa BLOKE + gerekçe; SQL testi S9 K5A-9 kanıtlı) |
| T8 | 5 TB-5 U4 | Seans tamamla yolu (seans_admin_id'li PG seansı, açık takipli hayvan) | T5–T7 etiketleri aynen |
| T9 | 5 TB-5 U6 | Takipsiz hayvanda tekil PG kapısı (Bekliyor) | Eski `_pgKapiAc` ekranı değişmemiş: "Boş ata ve uygula" / Vazgeç |
| T10 | 6 TB-7 | Fixture: S0 bölümüne düşen hayvan, TAI (TOHUMLAMA_PLANLI) hedef_tarih = BUGÜN (TR günü) | Ovsync takip S0 kartında "TAI bugün" metni + buton (ayrıntı: /home/melik/egesut-erp1/runs/2026-09-28-ovsync-takip/ui-fix1-DONE.md K6; js/ui.js `_ovsyncS0SatirHtml`) |
| T11 | 6 TB-7 | Aynı, hedef_tarih = YARIN | "TAI yarın" (K6 birim testindeki metin) |
| T12 | 3 TB-6 | İş sonu (kendi UIK-* temizliğinden sonra) | `kupe_no LIKE 'E2E-%' AND durum='Aktif'` ve `kupe_no LIKE 'UIK-%' AND durum='Aktif'` = 0 (sorgu + çıktı) |

## DONE biçimi
Tablo: # | PASS/FAIL/BLOKE | kanıt yolu | not. Fixture kurulum tarifleri (tekrar üretilebilir). Son satır `SONUC: PASS|FAIL|KISMI`.
Bitince DONE'u yaz, SONRA mimar oturumuna (seni açan) SendMessage: `DONE: /home/melik/egesut-erp1/runs/2026-10-02-ovsync-sonrasi/ui-kapi-DONE.md · sonuc: <PASS|FAIL|KISMI>`.
