# impl-P2d-DONE — TAMAM

- **Goal:** `G-20260930-OVSYNC-TAKIP-IMPL` · **Plan madde:** P2d (plan.md:360-376, birebir — MADDE DRIFT KAPISI: yalnız P2d; P3a tetikleyici işi YOK)
- **GOREV:** `runs/2026-09-28-ovsync-takip/impl-P2d-GOREV.md` · **Tarih:** 2026-09-30
- **Sonuç:** 6/6 kabul kanıtlı — **TAMAM** (1 self-repair: prova betiği `hayvanlar.id` text-tipi; migration dosyasına dokunulmadı, SHA taslak=final)

## Yazılan dosyalar (manifest 2/2)

1. `supabase/migrations/20260929000005_gebelik_gorev_temizlik.sql` (create — 87 satır). SHA-256: `810f98d4b3001ed74f68cbc06141427e502cf5c2005c2956531650d06c4e2fb1` [OBSERVED sha256sum; db-validate raporuyla birebir eşleşir — dosya taslaktan sonra DEĞİŞMEDİ, tek koşum kanıtı final için geçerli].
2. `runs/2026-09-28-ovsync-takip/impl-P2d-DONE.md` (bu dosya).

Manifest dışı repo yazımı YOK [OBSERVED `git status --porcelain supabase/` → yalnız `?? .../20260929000005_...sql`]. Prova betikleri `/home/melik/tmp/agents/` altında (p2d-say.sql, p2d-say2.sql, p2d-say3.sql, p2d-demo-prova.sql, p2d-demo-prova-cikti.txt, p2d-fn_asip_iade.sql, p2d-fn_parent_kapandi.sql — repo dışı).

## Kabul maddeleri (6/6)

### 1) `scripts/db-validate.sh` (worktree yolu) — PASS

[OBSERVED `bash scripts/db-validate.sh supabase/migrations/20260929000005_gebelik_gorev_temizlik.sql` → "SONUÇ: PASS", exit=0, rapor `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/reports/db-validation-810f98d4.md`; SHA8 `810f98d4` dosyayla eşleşir [CONFIRMED rapor:5 ≡ sha256sum]. Fazlar: A sqlfluff-PASS (15 adet LT05 satır-uzunluğu STİL uyarısı — kapıyı engellemez) / A squawk-PASS (0 ihlal) / B.sema-uyum PASS / C1 schema+data PASS (parite uyumlu, T=55 F=256 V=13, prod_pg=17.6 = yerel_pg=17.6) / C2 sentetik-tohum + veri-uyumluluk PASS.

**Kapı kör-noktası notu (P2c açık kalemiyle aynı sınıf):** rapor başlığı "Data mode: koşulmadı" der; nedeni DATA_MARKERS regex'inin `UPDATE[[:space:]]+[A-Za-z_]+[[:space:]]+SET` kalıbıyla `UPDATE public.gorev_log` şema-nitelemesini tutmaması [CONFIRMED db-validate.sh:310 regex]. C2 fazları BUNA RAĞMEN koştu ve PASS (rapor:23-24) — izole DB'de temizlik no-op koştu (aday yok, NOTICE `iptal-edilen=0`) [OBSERVED rapor:90,96]. Davranış kanıtı demo provadadır (maddeler 2-5).

### 2) Demo SAY çıktısı — temizlik öncesi [OBSERVED 2026-09-30 canlı demo]

Ölçüt (kaynak-öncelikli): `gorev_tipi='GEBELIK_KONTROL' AND NOT tamamlandi AND NOT iptal AND kaynak LIKE 'TOH-%'`

```
1-TOPLAM-OPEN-GK: 41            (kaynak filtresiz tüm açık GEBELIK_KONTROL)
2-TOH-ADAY: 40                  (temizlik adayı)
3-ACIKLAMA-DAGILIM: '21. Gün gebelik kontrolü' => 18
3-ACIKLAMA-DAGILIM: '35. Gün gebelik kontrolü' => 22
4-CAPRAZ-SAPMA-ACIKLAMA: (boş — adayların tümü 21/35 açıklamalı; sapma 0)
5-TERS-CAPRAZ-KAYNAK:   (boş — 21/35 açıklamalı ama TOH- olmayan açık görev yok)
9-TOH-OLMAYAN: kaynak=GEBELIK-KONTROL-08ff8497-... aciklama='🔬 Gebelik muayenesi: 40. gün Bekliyor (176)' (bugün üretilmiş cron görevi — ölçüt onu KORUR)
```

**Eşik dağılımı (tohumlamadan geçen gün × adet):** 21 g: 3g×2, 7g×9, 9g×2, 12g×1, 13g×2, 14g×1, 29g×1 (=18) · 35 g: 3g×2, 7g×9, 9g×2, 12g×1, 13g×2, 14g×1, 23g×4, 29g×1 (=22). Adayların hedefi: 1 geçmiş, 39 gelecek.

**Kaynak-öncelikli ölçüt belgesi:** sapma-0 örneklemi — ama kural yine kaynak-öncelikli kodlandı (açıklama yalnız çapraz doğrulama; islem_log snapshot'ında `aciklama_capraz_dogrulama` listesi durur). Cron görevi (`GEBELIK-KONTROL-` önekli) ölçüte düşmez [OBSERVED — temizlik sonrası cron-kaynaklı açık=1 kaldı].

**42-hizalama nüansı (dürüst not):** P2c-DONE'daki "42 açık eski görev" sayımı kaynak-filtresizdi ve TX2 içindeki cron üretimini de içeriyordu (41 eski + 1 o-an üretimi = 42). Bugün: 40 eski (TOH-) + 1 cron kaynaklı = 41 toplam → P2c'den bugüne 1 eski görev kapanmış (demo canlı akışı; tek-satır farkı). Zarfın "sayım bunu doğrulamalı" beklentisi bu nüansla karşılanır: aday havuzu 40, ölçüt-temizlik tam.

### 3) İptal sonrası açık +21/+35 = 0 [OBSERVED — demo prova, BEGIN..ROLLBACK]

`P2D-TEMIZLIK: iptal-edilen=41` (40 gerçek + 1 sentetik kurulum görevi — prova hedef hayvanına sentetik `TOH-` kaynaklı görev eklendi, bkz. madde 4) → `P2D-SAY-SONRA: aday=0` (aynı ölçütle yeniden sayım) → `P2D-SAY-SONRA-CRON-KAYNAKLI: cron-kaynakli-acik=1` (cron görevi duruyor — doğru kapsam).

### 4) Cron tek görev doğuyor [OBSERVED — demo prova TX içi]

Gerçek demo verisinde "eşik dolmuş (son tohumlama Bekliyor + ≥40g) VE TOH- aday görevli" hayvan yoktu [OBSERVED sorgu-8 boş: aday hayvanların tümünde son tohumlama Bekliyor-değil ya da <40g]. Prova P2c TX2 deseniyle sentetik kurulumla koşuldu (kupe 28 hayvanı `90ff6bde-...`, sentetik 41g-önce Bekliyor tohumlama + sentetik `TOH-` açık GK görevi; kurulum assert'leri: Dişi/Aktif/kısır-değil + son-tohumlama=sentetik [OBSERVED NOTICE kurulum-ok]):

```
P2D-CRON-1: esik=40 hayvan-listede=true uretilen-toplam=1 hedef-hayvan-acik=1 (1 olmali)
P2D-CRON-2: uretilen=0 (0 olmali) hedef-hayvan-acik=1 (hala 1 — cift YOK)
            yeni-gorev-kaynak=GEBELIK-KONTROL-22222222-...-d1
```

— temizlik sonrası `NOT EXISTS` açık-görev koşulu geçer [CONFIRMED 20260925000002:352-354], cron TEK görev doğurur, 2. koşum 0 (çift görev yok). Cron `gebelik_muayene_gorev_uret(false)` service_role-only [CONFIRMED :397-398].

### 5) Idempotency: ikinci koşum 0 satır [OBSERVED]

Aynı transaction'da migration 2. koşum: `P2D-TEMIZLIK: iptal-edilen=0 (idempotent no-op — aday yok)` → `P2D-IDEMPOTENT: aday=0 | iz-sayisi=1` — aday koşulu `iptal=false` gerektirdiğinden ikinci koşum UPDATE yapmaz VE `adet=0` koruması islem_log izi de yazmaz (iz tekil kalır).

### 6) `git diff --check` temiz; islem_log izi snapshot alanlı [OBSERVED]

`git diff --check` → boş çıktı, exit 0. İz kanıtı (prova TX içi): `P2D-IZ: tip=GOREV_GUNCELLENDI | adet=41 | etiket=§10d #1 veri temizliği | iz-sayisi=1` — snapshot: `adet`, `olcut` (birebir ölçüt metni), `kaynak_oncelikli=true`, `aciklama_capraz_dogrulama`, `etiket='§10d #1 veri temizliği'`, `temizlenen_gorev_id` (jsonb listesi), `etkilenen_hayvan` [CONFIRMED migration:63-71]. ROLLBACK sonrası demo kalıcı iz yok: `aday=40` (eski hâl) + `iz-sayisi=0` [OBSERVED].

## Uygulama kararları (planın kelimeleri ↔ canlı şema — sapma-notu, sessiz varsayım YOK)

1. **Plan "SET iptal=true, notlar/iz" → `notlar` kolonu gorev_log'da YOK** [CONFIRMED canlı `\d gorev_log` — 22 kolon listesinde notlar yok]. "İz" iki kanalla uygulandı: satır-içi `kapatan_ref='p2d-veri-temizligi'` (mevcut trigger deseni 'parent-kapandi'/'parent-silindi' ile uyumlu) + islem_log kaydı (plan birebir). Planın "iz" niyeti karşılandı; kolon-ekleme YAPILMADI (şema değişikliği plan kapsamı dışı).
2. **`tip='GOREV_GUNCELLENDI'` birebir yazıldı.** Demo'da mevcut üretilen görev-iz tipi `GOREV_GUNCELLE` (kullanıcı yolu üreticisi) [OBSERVED]; domain-rules §11 `GOREV_EKLENDI/GOREV_GUNCELLENDI` tanımlar. gorev_tipi CHECK kısıtı yok (serbest metin) → çelişki yok; arama disiplini notu: temizlik izi GOREV_GUNCELLENDİ ile aranır.
3. **Trigger emniyeti (önceden doğrulandı, demo canlı):** `trg_gorev_asip_iade` iptal-flip'inde tetiklenir ama yalnız `referans_tipi='asi_plan'` stok hareketine dokunur → GEBELIK_KONTROL'de 0 satır no-op [CONFIRMED canlı fn gövdesi]; `_trg_gorev_parent_kapandi` iptal-flip'inde yalnız görevin çocuğunu iptal eder — adayların tümü ana görev (parent_id dolu = 0) ve çocuksu aday = 0 [OBSERVED] → no-op; `trg_degisim_log` audit; `gorev_log_cycle_guard_trigger` BEFORE INSERT (temizlik INSERT yapmaz).
4. **PROD apply + resmi demo apply YAPILMADI (sahip kapısı):** demo prova BEGIN..ROLLBACK (kalıcı iz 0 [OBSERVED]); demo'da 40 eski görev eski hâliyle bekliyor — toplu apply kapısında bu migration koşulunca 40 satır iptal olur (PROD sayısı PROD verisinde ayrıca SAY ile doğrulanmalı).
5. **PostgreSQL LSP (zorunlu sahip talimatı):** [OBSERVED `postgrestools check --config-path=/home/melik/egesut-erp1/postgres-language-server.jsonc supabase/migrations/20260929000005_gebelik_gorev_temizlik.sql` → exit 0, "Checked 1 file ... 349ms", 0 hata]. Zarfın false-positive sınıflarından (p_*, ayna-öncesi, `\` meta) bu dosyada tetiklenen olmadı.

## Ölçüm komutları (özet)

- `postgrestools check` → 0 hata
- `db-validate.sh` (1 koşum, taslak=final) → `810f98d4` **PASS**
- demo SAY (3 betik, salt-okuma) → aday 40 (18×21g + 22×35g), çapraz sapma 0, eşik dağılımı yukarıda
- demo prova (1 oturum BEGIN..ROLLBACK): kurulum-ok → SAY 41 → migration 41 → SAY 0 → cron 1 → cron-2 0 → iz 1 → migration-2 0 → ROLLBACK → aday 40 / iz 0
- `git diff --check` → temiz; `sha256sum` → `810f98d4…`

## Açık kalemler

1. **db-validate DATA_MARKERS kör-noktası (mimara/kapı sahibine):** şema-nitelemeli `UPDATE public.<tablo>` DML'ini "veri dokmuyor" sayıyor [CONFIRMED db-validate.sh:310]; bu dosyada C2 yine koşup PASS verdi (etki yok) ama C2 atlanacak biçimde regex daraltılırsa veri migration'ı yeterince prova edilmeden geçebilir. Öneri: regex'e `[A-Za-z_]+\.` nitelemesi ekle (ya da `public.` ayrıştır).
2. **P2c "42" hizalama nüansı:** P2c ölçümü kaynak-filtresiz + cron-üretimi-dahildi; bugün eski-TOH- açık 40. Aradaki 1 görevin kapanma yolu bu zarfta araştırılmadı (demo canlı akışı) — temizlik ölçütü ve kapsamı bundan etkilenmez.
3. **Demo 40 eski görev hâlâ açık bekliyor** (bilinçli): resmi temizlik toplu apply kapısında (sahip) koşar; PROD'ta da apply öncesi aynı SAY sorgusu koşulmalı (p2d-say.sql yeniden kullanılabilir).
