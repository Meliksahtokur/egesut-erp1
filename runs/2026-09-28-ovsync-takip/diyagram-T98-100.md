# T-98 / T-99 / T-100 — Mermaid akış diyagramları

Kaynak: `docs/plans/2026-09-28-ovsync-takip-ekrani/test-senaryolari.md` (T-98 satır 819-825, T-99 satır 827-833, T-100 satır 835-841); dayanak `docs/plans/2026-09-28-ovsync-takip-ekrani/plan.md` P2b koşul seti (satır 304) + P3a (satır 385-392). Stil: plan A1/A2 akış haritaları. Sadece katalog/planın söylediği davranış çizildi; fazlası uydurulmadı.

---

## T-98 — `BOS_DUZELTME_KOSUL`: Boş-düzeltme koşul seti sağlanmazsa red

```mermaid
flowchart LR
  subgraph t98_ui["Kullanıcı / UI"]
    t98_u1["Muayene sonuc ekranı — 'Gebe' seçimi"]
  end

  subgraph t98_fix["Fixture — planın 5 koşulundan biri bilinçli KIRIK (her fixture ayrı çağrı)"]
    t98_fa["fixture a — koşul-2 kırık:\nmuayene görevi TAKIP_MUAYENE değil (GEBELIK_KONTROL)\n+ hedef tohumlama sonuc='Boş'"]
    t98_fb["fixture b — koşul-3 kırık, DETERMİNİSTİK kurulum:\nhedef tohumlama hayvanın SON tohumlaması değil —\nüstüne treatment_date ile KESİN daha yeni kayıt girilir\n(eşitlikte created_at belirler)"]
    t98_fc["fixture c — koşul-5 kırık:\no tohumlamaya bağlı AÇIK takip zinciri yok (görev kapalı)"]
  end

  subgraph t98_rpc["RPC: tohumlama_bos_ve_devam — tek transaction"]
    t98_r1["Giriş: p_muayene_gorev_id + p_secim='GEBE' (muayene kolu)"]
    t98_r2["Kilit MK9-N: hayvanlar NKU → tohumlama FU → gorev_log FU (H3 sırası)"]
    t98_k{"p_bos_duzeltme=true koşul seti — HEPSİ zorunlu:
1 yol = sarmal muayene kolu GEBE
2 görev TAKIP_MUAYENE
3 hedef SON tohumlama (tarih DESC, created_at DESC)
4 sonuc='Boş'
5 bağlı AÇIK takip zinciri"}
    t98_red["RAISE 'BOS_DUZELTME_KOSUL:{eksik...}'"]
    t98_izinli["İZİNLİ RED KÜMESİ (fixture a) — koşul-4 dönmesi:\n{ 'TOH_SONUCLU' | 'BOS_DUZELTME_KOSUL' }\niki redten biri gelir; hangisi geldiği sınanmaz,\nİKİSİ DE KABUL"]:::red
    t98_t77["Çekirdek _tohumlama_gebe_uygula p_bos_duzeltme=true"]
    t98_t78["Çekirdek p_bos_duzeltme=false — mevcut yol"]
  end

  subgraph t98_db["DB"]
    t98_d1[("gorev_log — muayene görevi + takip zinciri (kaynak='TAKIP:' + tohumlama_id)")]
    t98_d2[("tohumlama — sonuc")]
    t98_d3[("hayvanlar — tohumlama_durumu")]
    t98_now["Yazma YOK — tohumlama / durum / görev / vaka dokunulmaz"]
  end

  t98_u1 -->|"Kaydet"| t98_r1
  t98_fa -->|"sarmal muayene yolu çağrısı\np_secim='GEBE'"| t98_r1
  t98_fb -->|"sarmal muayene yolu çağrısı\np_secim='GEBE'"| t98_r1
  t98_fc -->|"sarmal muayene yolu çağrısı\np_secim='GEBE'"| t98_r1
  t98_r1 --> t98_r2
  t98_r2 --> t98_k
  t98_k -->|"fixture a: GEBELIK_KONTROL + hedef Boş\n→ koşul-4 dönmesi (plan.md:304)"| t98_izinli
  t98_k -->|"fixture b: SON-tohumlama koşulu KIRIK (deterministik kurulum)"| t98_red
  t98_k -->|"fixture c: açık-takip koşulu KIRIK"| t98_red
  t98_red --> t98_now
  t98_izinli -->|"iki red de: hiçbir yazma yok"| t98_now
  t98_k -->|"koşullar tamam: TAKIP_MUAYENE + Boş + son + açık takip (T-77)"| t98_t77
  t98_k -->|"GEBELIK_KONTROL + Bekliyor (p_bos_duzeltme=false, T-78)"| t98_t78
  t98_t77 -->|"sonuc Boş → Gebe"| t98_d2
  t98_t77 -->|"durum → Gebe"| t98_d3
  t98_t77 -->|"takip kapanışı GEBE_BULUNDU"| t98_d1
  t98_t78 -->|"Bekliyor → Gebe"| t98_d2
  t98_t78 -->|"durum → Gebe"| t98_d3
  class t98_red,t98_izinli,t98_now t98red
  class t98_t77,t98_t78 t98pass
  classDef t98red fill:#fee2e2,stroke:#b91c1c,color:#7f1d1d
  classDef t98pass fill:#dcfce7,stroke:#15803d,color:#14532d
```

**Kaplama notu:** Üç fixture düğümü (`t98_fa`/`t98_fb`/`t98_fc`) katalog ön koşulundaki üç kırık koşulu taşır; her fixture sarmal muayene yolu `p_secim='GEBE'` ile AYRI çağrılır (`t98_fa/fb/fc → t98_r1 → t98_r2 → t98_k`). Fixture (a)'nın kenarı tek `BOS_DUZELTME_KOSUL` düğümüne DEĞİL, izinli red kümesi düğümü `t98_izinli`'ye bağlanır: koşul-4 dönmesi (`GEBELIK_KONTROL` + hedef Boş) `{TOH_SONUCLU, BOS_DUZELTME_KOSUL}` kümesinden iki redten birini verir, hangisi geldiği sınanmaz, İKİSİ DE KABUL (plan.md:304). Fixture (b) düğümü "son değil" ifadesinin yerini DETERMİNİSTİK kuruluma bıraktı: hedefin üstüne `treatment_date` ile KESİN daha yeni kayıt girilir, eşitlikte `created_at` belirler — koşul-3 kırığı belirsizliğe yer bırakmadan kurulur; (b) ve (c) `t98_red`'e (`BOS_DUZELTME_KOSUL`) akar. Kontrast meşru yollar: T-77 Boş-düzeltme `t98_t77`, T-78 mevcut Bekliyor yolu `t98_t78`; tüm redlerde yazma yokluğu `t98_now` (`t98_izinli` de oraya akar — iki red de tohumlamaya dokunmaz).

---

## T-99 — PG geri alımı takibi YENİDEN AÇMAZ (kapanış kalıcı)

```mermaid
flowchart LR
  subgraph t99_ui["Kullanıcı / UI"]
    t99_u1["PG uygulama ekranı (hızlı PG / seans)"]
    t99_u2["TAKIP_ACIK onayı — Evet"]
    t99_u3["Aynı PG uygulamasını geri al"]
  end

  subgraph t99_rpc["RPC: hizli_uygulama / seans_tamamla + geri-al yolu"]
    t99_r1["PG uygulama çağrısı"]
    t99_r2["RAISE 'TAKIP_ACIK:{muayene_tarihi, muayene_saat}'"]
    t99_r3["Onaylı retry (T-20 yolu): önce _takip_kapat(neden='PG'), sonra INSERT"]
    t99_r4["Mevcut geri-al yolu: UPDATE pg_application_event"]
  end

  subgraph t99_db["DB"]
    t99_t1{"BEFORE INSERT tetikleyici pg_application_event: açık TAKIP_MUAYENE var?"}
    t99_d1[("gorev_log — takip görevi KAPANIR: tamamlandi + takip_kapanis_nedeni='PG'")]
    t99_d2[("pg_application_event — INSERT geçer")]
    t99_d3[("pg_application_event.geri_alindi_at doldurulur")]
    t99_kal["Takip KAPALI KALIR: neden='PG' bozulmaz; yeni TAKIP_MUAYENE DOĞMAZ; OVSYNC_BASLAT / _acik_disi_gorev_kur üretilmez"]
    t99_x["HATA (ters kanıt): geri alım takibi yeniden açar / çift takip görevi doğar"]
  end

  t99_u1 -->|"Uygula"| t99_r1
  t99_r1 --> t99_t1
  t99_t1 -->|"açık takip var"| t99_r2
  t99_r2 -->|"onay iste"| t99_u2
  t99_u2 -->|"evet"| t99_r3
  t99_r3 -->|"kapanış"| t99_d1
  t99_r3 -->|"sonra INSERT — tetikleyici açık takip görmez, geçer"| t99_d2
  t99_t1 -->|"açık takip yok → geçer"| t99_d2
  t99_u3 -->|"geri al"| t99_r4
  t99_r4 --> t99_d3
  t99_d3 -->|"hiçbir takip yazması YOK"| t99_kal
  t99_d3 -.->|"yasak dal"| t99_x
  class t99_r2,t99_x t99red
  class t99_kal,t99_d1 t99pass
  classDef t99red fill:#fee2e2,stroke:#b91c1c,color:#7f1d1d
  classDef t99pass fill:#dcfce7,stroke:#15803d,color:#14532d
```

**Kaplama notu:** Adım 1 (PG uygula → TAKIP_ACIK → evet) `t99_u1 → t99_r1 → t99_t1 → t99_r2 → t99_u2 → t99_r3 → t99_d1 → t99_d2` zinciri; Adım 2 (geri al) `t99_u3 → t99_r4 → t99_d3`. BEKLENEN'in üç maddesi (kapalı kalır / görev doğmaz / ürün üretilmez) `t99_kal` tek düğümde; ters kanıt kesikli `t99_x` yasak dalı.

---

## T-100 — Kapanış tetikleyicileri bayraktan bağımsız (MK9-K): bayrak KAPALIyken de çalışır

```mermaid
flowchart LR
  subgraph t100_on["Ön koşul kurulumu"]
    t100_u0["Bayrak AÇIKken takip kuruldu (T-03 yolu)"]
    t100_f0[("protokol_ayar.ovsync_pg_kurallari_aktif = 0 (demo)")]
  end

  subgraph t100_ui["Kullanıcı / UI — bayrak kapalıyken"]
    t100_u1["Yeni tohumlama girişi — ESKİ yol (tohumlama kaydı)"]
    t100_u2["Sarmal devam seçici (yazma denemesi)"]
  end

  subgraph t100_db["DB — kapanış tetikleyicileri (MK9-K bayrak-bağımsız)"]
    t100_d0[("gorev_log — açık TAKIP_MUAYENE görevi")]
    t100_i1[("tohumlama — INSERT (RPC ya da REST; tüm giriş yolları kapsanır)")]
    t100_t1{"AFTER INSERT tohumlama tetikleyici: açık TAKIP_MUAYENE var?"}
    t100_t2["_takip_kapat(neden='YENI_TOHUMLAMA') — SESSİZ, idempotent; hayvan kilidi ALMAZ (H3)"]
    t100_d1[("gorev_log UPDATE — takip_kapanis_nedeni='YENI_TOHUMLAMA'")]
    t100_h3["H3 KAYNAK KANITI (adım 2): pg_get_functiondef ile kapanış tetikleyici\nfonksiyon gövdesi okunur → 'FOR UPDATE' / 'LOCK' kalıbı İÇERMEZ"]:::pass
    t100_ok["DESTEKLEYİCİ KANIT: kapanış 40P01 / 55P03 OLMADAN tamamlanır\n— tek başına kanıt DEĞİL; H3 kaynak kanıtıyla birlikte değerlendirilir"]:::pass
    t100_s2["RAISE 'OZELLIK_KAPALI' (T-97) — tetikleyiciye yeni-yol girişi olmaz"]
    t100_x1["HATA (ters kanıt): bayrak kapalıyken kapanış atlanır — takip açık kalır"]
    t100_x2["HATA (ters kanıt): tetikleyici hayvan satırı kilidi alır (H3 ihlali)"]
  end

  t100_u0 --> t100_d0
  t100_u1 -->|"kaydet"| t100_i1
  t100_i1 --> t100_t1
  t100_f0 -.->|"tetikleyici bayrağı OKUMAZ"| t100_t1
  t100_t1 -->|"var"| t100_t2
  t100_t2 --> t100_d1
  t100_d1 -->|"gözlem: kapanış tamamlanır"| t100_ok
  t100_t2 -->|"adım 2: kaynak kanıtı"| t100_h3
  t100_h3 -.->|"iki kanıt birlikte H3'ü gösterir"| t100_ok
  t100_u2 -->|"sarmal yazma modu"| t100_s2
  t100_d0 -.->|"yasak dal"| t100_x1
  t100_t2 -.->|"yasak dal"| t100_x2
  class t100_t2,t100_d1,t100_h3,t100_ok t100pass
  class t100_s2,t100_x1,t100_x2 t100red
  classDef t100red fill:#fee2e2,stroke:#b91c1c,color:#7f1d1d
  classDef t100pass fill:#dcfce7,stroke:#15803d,color:#14532d
```

**Kaplama notu:** Adım 1 (bayrak kapalıyken eski yoldan yeni tohumlama) `t100_u1 → t100_i1 → t100_t1 → t100_t2 → t100_d1`; "tetikleyici bayrağı okumaz" kesikli `t100_f0 → t100_t1` kenarı, H3 "hayvan kilidi almaz" `t100_t2` etiketi, takip_kapanis_nedeni `t100_d1`. Adım 2 — katalogdaki H3 kaynak kanıtı — `t100_h3`: `pg_get_functiondef` ile kapanış tetikleyici fonksiyon gövdesi okunur, gövde `FOR UPDATE`/`LOCK` kalıbını İÇERMEZ (birincil kanıt; `t100_t2 → t100_h3` kenarı). `t100_ok` DESTEKLEYİCİ kanıt olarak yeniden etiketlendi: 40P01/55P03 yokluğu gözlemi tek başına kanıt değildir, `t100_h3` ile birlikte değerlendirilir (kesikli kenar). BEKLENEN'in sarmal dalı `t100_u2 → t100_s2` (OZELLIK_KAPALI); ters kanıt kesikli `t100_x1` / `t100_x2` yasak dalları.
