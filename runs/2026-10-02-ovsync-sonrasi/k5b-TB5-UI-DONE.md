# K5B — TB-5 UI ayağı DONE (2026-10-02)

Goal: /home/melik/.herdr/worktrees/egesut-erp1/ovsync-sonrasi/.harness/goals/2026/G-20261002-OVSYNC-SONRASI-BORC.md kalem 5b. Worktree HEAD bf35723, git YOK.
Okundu: k5a-TB5-SQL-DONE.md; domain-rules §18.8/§18.15 (çelişki yok, yeni davranış icat edilmedi). Atlas: atlas_status taze (ffdc342), `etki _takipAcikAc` = 13 çağıran (aşağıda). gitnexus_impact MCP `Permission denied: '/root/egesut-erp1'` verdi (araç ortamı); ui.js yorum-düzenlemesi blast-radius kapısı ikinci denemede geçti, yalnız yorum değişti.

## 1. Bulgu [OBSERVED]
UI mantığı zaten hazırdı: `_takipAcikAc` `_pgk.karar || önek-regex` okuyor, `_takipPgKararEtiket` üç değeri biliyor. Yeni test seti yazıldığı anda YEŞİL çıktı (davranış mevcut; "kırmızı" doğal olarak gözlenemedi). Testlerin ayırt ediciliği MUTASYONLA kanıtlandı (ui.js yedeği ~/tmp/k5b/ui.js.orig, her mutasyon sonrası geri yüklendi, diff -q RESTORED):
- Mutasyon A (`_pgk.karar ||` kaldırıldı = eski H5 davranışı): 6 test KIRMIZI (3 karar değeri, karar>tohumlama_sonuc önceliği, CATALOG tohumlamasız, seans yolu), pass 5/fail 6. Çıktı ~/tmp/k5b/mutA.out.
- Mutasyon B (tohumlama_sonuc N-1 yedeği kaldırıldı): 2 N-1 testi KIRMIZI, pass 9/fail 2. Çıktı ~/tmp/k5b/mutB.out.
- Yeşil: `node --test tests/unit/ovsync-pg-karar.test.js` -> 11/11 pass.

## 2. Değişen / eklenen
- YENİ /home/melik/.herdr/worktrees/egesut-erp1/ovsync-sonrasi/tests/unit/ovsync-pg-karar.test.js (11 test): `_takipAcikHata` ile GERÇEK sunucu mesaj biçimi (`PG_KAPI:TAKIP_ACIK:{pg_kapi:{10 anahtar},takip_acik}`) -> sheet "💉 PG kapısı: <etiket>"; 3 karar değeri; karar>tohumlama_sonuc önceliği; `_pgKapiAc` seans_tamamla birleşik yolu (seans_admin_id'li) 3 değer; N-1: karar yok / karar JSON null + tohumlama_sonuc -> "Son tohumlama sonucu Bekliyor", ikisi de yok -> "bilinmiyor"; onay yolu karardan bağımsız (retry closure aynen saklı, birlesik=true, 4 durum); yalın TAKIP_ACIK PG satırı basmaz.
- DEĞİŞEN fonksiyon: `_takipAcikAc` yalnız YORUM (js/ui.js ~3163-3167; "karar YOK (H5)" bayat yorumu -> "karar sunucudan gelir; N-1 yedeği kalır"). Kod satırı DEĞİŞMEDİ. `git diff --stat -- js/ui.js`: 1 file, 5 insertions(+), 3 deletions(-).
- Mevcut `ovsync-uifix1.test.js` K3 testlerine dokunulmadı (tamamlayıcı).
- index.html ?v= DEĞİŞMEDİ; tests/e2e dokunulmadı; demo DB'ye apply YOK.
- "Boş ata ve uygula" / BLOCK_* kapı kuralı DEĞİŞMEDİ: tekil `_pgKapiAc` (REQUIRE_ACK_PENDING'de düğme; BLOCK_*'ta yalnız Tamam) ve birleşik sheet (tek onay, retry closure) aynen; kapıyı açıp açmama sunucuda (K5A-6: onaylı bile BLOCK_PREGNANT).
- Not (dokunulmadı, mimar kararı): `_takipAcikHata` `pg_kapi_kod` hiç doldurmuyor -> o yedek ölü yol; yalnız doğrudan `_takipAcikAc({pg_kapi_kod})` çağrıları (K3 testi) çalıştırıyor. N-1'de gerçek yedek `tohumlama_sonuc`. Atlas etki `_takipAcikAc` çağıranları: `_devamSeciciOnayla`, `_pgKapiAc`, `_takipAcikHata`; ikinci halka: seansTamamla, submitCase, _gorevStokTamamlaSubmit, _hayvanHizliUygulaKaydet, _pgKapiBosAtaUygula, _pgKapiHata, _protokolUygulaKaydet, ovsyncBaslat, sorunVakaAc, devam-secici-onayla.
- Ek gözlem (kapsam dışı): `js/forms.js:3295` vaka_toplu_ac `pgKarar: null` (toplu sheet satırında PG etiketi yok); `bulk_ilac` yolu `r.pg_kapi_karar` ile dolu. İstenirse ayrı kalem.
- Ek gözlem: `_devamSeciciOnayla` yolu (ui.js ~2792) `red.detay?.pg_kapi`'yi aynen `_takipAcikAc`'a geçirir, ayrı testlenmedi [INFERRED: aynı fonksiyon, test kapsamı `_takipAcikAc` + `_pgKapiAc`].

## 3. Doğrulama
- `node --check js/ui.js` OK; yeni test dosyası OK.
- Tam birim süit (`node --test tests/unit/*.test.js`, NODE_PATH ana checkout): tests 1511 / pass 1509 / fail 2 (önceki 1500/1498/2 + 11 yeni; yeni kırmızı YOK). 2 fail ÖNCEDEN VAR, orig ui.js ile aynı sayı: (a) tests/unit/degisiklikler-etiketler.test.js:88 LUNA-3 canlı demo information_schema haritasız kolon (demo'da yeni kolonlar: cases.close_reason, protocol_family, protocol_snapshot, source_template_id, drug_classes.farmakolojik_sinif_kodu/sistem, gorev_log.takip_kapanis_nedeni, tedavi_sablonu.protokol_ailesi), (b) tests/unit/vaka-toplu-ac.test.js:2606 "ay ‹/›" tarih-sabit takvim etiketi (Ekim 2026).

## 4. UI kapısı için tarayıcı test maddeleri (glmf-max, demo, migration 20261002000002 uygulanmış demo gerekir; apply mimarda)
Fixture ortak: PG ürünü + son tohumlama durumu + AÇIK rektal muayene takibi olan hayvan (E2E-TAKIP-K5A* tarifi: tests/sql/ovsync_takip_test.sql S9). Eylem: hızlı uygulama / görev stok tamamla ile PG ürünü uygula (birleşik yol).
- U1 REQUIRE_ACK_PENDING: hayvan = son tohumlama Bekliyor, onay yok. Beklenen: "Bu hayvan takipte" sheet'i; "💉 PG kapısı: Son tohumlama sonucu Bekliyor — PG onayı gerekli"; "🔍 Rektal muayene takibi: <gg.aa SS:DD>"; tek buton "Evet, takibi kapat ve uygula" + "Vazgeç"; "bilinmiyor" YOK.
- U2 BLOCK_PREGNANT: son tohumlama Gebe. Beklenen: "💉 PG kapısı: Gebe inekte PG uygulanamaz". Onaylayınca sunucu yine reddeder (K5A-6): hata toast'u, sheet açık kalır, uygulama OLUŞMAZ (uygulama_log satırı yok).
- U3 BLOCK_CATALOG_UNRESOLVED: PG adlı ama katalog bağsız ürün (S9 K5A-9). Beklenen: "💉 PG kapısı: Ürünün PG katalog bağı belirsiz".
- U4 seans_tamamla birleşik yolu (seans_admin_id'li, `_pgKapiAc`->TAKIP_ACIK): U1-U3 etiketleri aynen.
- U5 N-1 (migration UYGULANMAMIŞ demo/prod): U1 fixture'ında etiket "Son tohumlama sonucu Bekliyor" (yedek), hata yok.
- U6 tekil takipsiz PG (takip yok): eski `_pgKapiAc` ekranı (REQUIRE_ACK_PENDING'de "Boş ata ve uygula", BLOCK_*'ta "Tamam") değişmemiş.
- Kanıt: her madde için ekran görüntüsü + `#takip-acik-bs` innerHTML + konsol hatasız. Playwright tekrarı yok kuralı; demo sahip şifresine dokunulmaz.

## 5. Kanıt etiketleri
[OBSERVED] 11/11 yeşil, mutasyon A/B kırmızıları, süit sayıları, 2 önceden-var fail (orig ui.js ile aynı), diff --stat. [INFERRED] devam-secici yolu `red.detay.pg_kapi` aktarımı. [UNMEASURED] gerçek sunucu yükünde tarayıcı görünümü (migration demo'da uygulanmadı; UI kapısı maddeleri yukarıda).

SONUC: TAMAM
