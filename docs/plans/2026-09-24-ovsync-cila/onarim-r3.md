# ONARIM R3 — S5 spec/plan kanıt yeniden-doğrulama kaydı (2026-09-24)

- **Tetik:** reviewer 3. tur FAIL. Workflow'tan bulgu listesi gelmedi (`BULGULAR: undefined`) → tüm kanıt iddiaları onarım ajanınca repodan + canlı şemadan tek tek yeniden doğrulandı.
- **Yetki zarfı:** yalnız bu dizindeki dosyalara yazıldı (spec-s5.md, plan-s5.md, bu kayıt); koda dokunulmadı.
- **Yöntem:** satır iddiaları `awk/grep` ile repo-düzeyi; canlı iddialar demo Mgmt query endpoint ile (`fdw_prod_srv=1` ile demo teyitli). Baseline `npm run test:unit` koşuldu.

## 1. Kesinleşen bulgular (onarımda işlendi)

| # | Bulgu | Kanıt | İşlem |
|---|---|---|---|
| B1 | **T6/F3 İPTAL:** canlı `tohumlama_sonuc_bos` tek imza `(text,text)`; legacy `(text)` overload YOK (prod'da da tek imza — yan gözlem). Repo: `20260403000001:L6` DROP, `20260512000006` yeniden CREATE; canlı nihai durum tek imza | OBSERVED demo `pg_proc` (fdw=1) 2026-09-24 | spec §5.1/§5.3/§5.4/§12-V4/§13-4/§14 + plan §0/Adım 12/ENGEL-3 güncellendi: F3 koşulsuz atlanır, `20260925000003_*` yazılmaz |
| B2 | **V3 damga VAR:** `kaynak/aciklama ILIKE '%senkron%'` → 16 satır (tamamı ILAC, "39. Gün PG (Presynch-14 senkron)", kaynak 'DOGUM-<uuid>'), 2'si açık. Damga `aciklama` alanında → F2 geniş-kapsam filtresi uyumlu | OBSERVED demo `gorev_log` 2026-09-24 | spec §7.2/§12-V3 + plan §0/Adım 1/Adım 11/ENGEL-4 güncellendi: ENGEL-4 kalktı |
| B3 | **`supabase_migrate` MCP → PROD hedefli:** fdw_prod_srv=0 + schema_migrations=124 (prod imzası; demo imzası fdw≥1). Planın eski K-7'si bu MCP'yi demo ölçüm yolu sayıyordu — prod okuma/yazma riski | OBSERVED iki bağlantı discriminators; memory: "schema_migrations=124" prod kontrolü | plan K-7 + §0 MCP uyarısı + ENGEL-5 yeniden yazıldı; demo yolu: `SUPABASE_DEMO_PAT` query endpoint (bu onarımda kullanıldı, çalıştı) / psql-demo |
| B4 | **Spec satır-no drift'leri:** erteleme toast :1064-1059→:1058-1059; pull seti :321→:320; dbUpdate :546-548→:548-550; ovsyncIptal write :1193→:1195; flushPendingDone :585-602→:583-597; recoverPendingDone :604-612→:598-605; panel :1835→:1832 (+aralık :1829-1847); tek-kayıt ↑ :9240→:9220; _pgKapiBosAtaUygula :988-1004→:990-1005; vaka bloğu :265-271→:266-271 | CONFIRMED repo satır okumaları 2026-09-24 | spec §2/§4.1/§6.1/§6.2/§8.1/§8.2/§9.2 tazelendi; plan zaten günceldi |
| B5 | **D6 metin çifti netleştirildi:** nil-uuid çağrısı "Tohumlama bulunamadı" (:522) döner; "Sadece Bekliyor…" (:526) için sonucu-'Bekliyor'-değil gerçek kayıt gerekir | CONFIRMED `20260924000001:519-527` | spec §6.3-5 + plan Adım 10-D6 güncellendi |
| B6 | **BUGS.md borç girdileri commit'siz:** BUG-ERTELEME-KURAL-GENEL (:183) + BUG-KUYRUK-SHEMA-VERSIYONU (:195) çalışma ağacında, commit edilmemiş; spec referansları satır olarak doğru | OBSERVED `git diff BUGS.md` | plan Adım 14-3 + spec §14-8'e not: içerik değişmeden teslim kulvarınca commit edilecek (onarım yetki zarfı dışında) |

## 2. Doğrulanıp değişmeyenler (özet)

- JS davranış iddialarının tamamı teyitli: ölü dal `ui.js:997`, rpc ok:false-throw `api.js:86-90` (yalnız `data.mesaj`), seansTamamla toast `forms.js:4014`, ölü fallback `forms.js:346`, rpcSeansTamamla `_pgKapi` dönüşü `api.js:693-701`, rozet `ui.js:413-424` (filtre :417), TZ `ui.js:2340`, buildRpcParams `ui.js:9426-9427` (imza `(rpcName, data, op)` :9295 — U1 testi uyumlu), dataTrafficGonder `ui.js:9229-9235`, RPC_MAP `ui.js:9245`, USER_FRIENDLY 5 anahtar + döngü `errorHandler:54-56`; `GOREV_ERTELENEMEZ`/`GECMIS_TARIH` `config.js:183` sözlüğünde de yok (çakışma riski yok).
- Migration iddiaları teyitli: `20260902000003:189` (imza + SET-yok), `20260915000001:64`, `20260512000006:4/:44`, `20260924000001:237/266-280/281/293/508/522/526/535-536`, `20260924000002:21-26/53-59/61/72/74-90/93-95/246`, `20260923000003:560-578/623`, `20260923000005:528-538`, `20260718000001:25/127/264/344` + OVSYNC-yok.
- Altyapı: package.json:18, index.html `?v=20260924-01` (:11/:2325+), `tests/unit/support/loadModule.js` (loadBrowserModule :125, expose :170, loadExtractedFunction :214).
- Baseline: 1089 test / 1086 pass / 3 fail — LUNA-3 canlı DEMO şema + 2 bc-tarih tarih-seçici UI regresyonu (plan beklentisiyle birebir; kayıt plan Adım 0-2'ye işlendi).
- Demo ön-şartlar: açık OVSYNC_BASLAT 29 satır (D7 yürütülebilir), `ovsync_baslat_uyarilari` + `tohumlama_gorev_ertele` canlı, `gorev_ertele_kural` tablosu yok (borç-tasarım; bu turda kurulmuyor — tutarlı).

## 3. ENGEL durumu

- ENGEL-1 (drift hedefi): çözülmüştü — değişiklik yok.
- ENGEL-2 (D9 ertelenmiş): değişiklik yok.
- ENGEL-3 (T6 onay kapısı): **kapandı** (B1).
- ENGEL-4 (F2 damga): **kapandı** (B2).
- ENGEL-5 (araç): **tanı kesinleşti** — PGRST205 + MCP-prod; çalışan yol kanıtlandı (B3).
- ENGEL-6 (sahip yürüyüşü): değişiklik yok.
- ENGEL-7 (tek yazıcı): değişiklik yok.
- YENİ RAPOR KALEMİ: BUGS.md commit'siz borç girdileri (B6) — teslim kulvarına.

## 4. Sıradaki adım

Implementasyon kulvarı (F1-F2, F4-F8, JS sıralı) planın güncel haliyle koşmaya hazırdır: DB ön-ölçümlerinin R3'te kapanan bölümleri (V1/V3/V4 imza-düzeyi, damga, baseline) tekrar koşulmaz; Adım 1'den kalan tek DB işi 'Boş/Bos' dağılımı + anon ayrıcalık sayımı + D7 ön-ölçüm kaydıdır.
