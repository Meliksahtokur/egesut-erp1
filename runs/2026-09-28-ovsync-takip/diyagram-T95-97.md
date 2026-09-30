# T-95 / T-96 / T-97 senaryo akış diyagramları

Kaynaklar (birebir kaplama; uydurma davranış yok):
- Katalog: `docs/plans/2026-09-28-ovsync-takip-ekrani/test-senaryolari.md` §S (T-95, T-96, T-97)
- Sözleşmeler: `docs/plans/2026-09-28-ovsync-takip-ekrani/plan.md` P2b — seçim uzayı (#3/K15+D3), XOR guard (#9), bayrak kapalı (#6 + §10g MK9-K)
- Stil: aynı plan.md A1/A2 akış haritaları (flowchart LR, katman ayrımı bu dosyada alt graflarla)

Renk sınıfları: `pass` = beklenen kabul/dönüş yolu · `red` = hata kodlu red yolu · `safe` = yazma-yok kanıtı / kapsam-dışı not.

---

## T-95 — Sarmal seçim tablosu guard'ı: TAKIP_MUAYENE'de TAKIP red + tablo-dışı seçim red

```mermaid
flowchart LR
  classDef red fill:#fee2e2,stroke:#dc2626,color:#7f1d1d
  classDef pass fill:#dcfce7,stroke:#16a34a,color:#14532d
  classDef safe fill:#f1f5f9,stroke:#64748b,color:#0f172a

  subgraph t95_l_ui["Kullanıcı / UI"]
    t95_ui["Sarmal muayene yolu çağrısı\np_muayene_gorev_id + p_secim"]
    t95_js["_muayeneSecimleri(gorevTipi) seçici seti (P8)\nGEBELIK_KONTROL: GEBE/OVSYNC/PG/TAKIP/ERTALE\nTAKIP_MUAYENE: GEBE/OVSYNC/PG/ERTALE"]
  end

  subgraph t95_l_rpc["RPC — tohumlama_bos_ve_devam"]
    t95_rpc["muayene kolu gövdesi"]
    t95_set{"p_secim ∈ set(gorev_tipi)?\n— DB CASE tablosu (P2b seçim uzayı)"}
    t95_ok["KABUL — seçim işlenir"]:::pass
    t95_red1["RAISE 'TAKIP_YENIDEN_SECILEMEZ'\n— takip zinciri zaten takiptir"]:::red
    t95_red2["RAISE 'SECIM_TANIMSIZ:{secim,gorev_tipi}'\n— sessiz varsayılan YOK"]:::red
  end

  subgraph t95_l_db["DB — tek transaction"]
    t95_gorev["gorev_log — muayene görevi satırı\nGEBELIK_KONTROL | TAKIP_MUAYENE"]
    t95_takip["_takip_gorev_kur →\nmuayene sonrası YENİ takip zinciri"]:::pass
    t95_yok["HİÇBİR yazma — görev sonucu girilmez,\nikinci takip zinciri doğmaz"]:::safe
  end

  t95_ui -->|"adım 1–3"| t95_rpc
  t95_rpc -->|"görev satırı + tip oku"| t95_gorev
  t95_gorev -->|"gorev_tipi"| t95_set
  t95_set -->|"GEBELIK_KONTROL + 'TAKIP' → sette (adım 1)"| t95_ok
  t95_set -->|"'TAKIP_MUAYENE' + 'TAKIP' → set dışı (adım 2)"| t95_red1
  t95_set -->|"'DIGER' — her iki görev tipinde set dışı (adım 3)"| t95_red2
  t95_ok --> t95_takip
  t95_red1 --> t95_yok
  t95_red2 --> t95_yok
  t95_js -.->|"P11 senkron UNIT: JS çıktı ↔ DB CASE birebir"| t95_set
```

**Kaplama notu:** Adım 1 (GEBELIK_KONTROL + `TAKIP`) → `t95_ok` → `t95_takip` (kabul dalı); adım 2 (TAKIP_MUAYENE + `TAKIP`) → `t95_red1`; adım 3 (`DIGER`, iki tip) → `t95_red2`. BEKLENEN'deki UNIT satırı `t95_js` ↔ `t95_set` kesikli kenarıdır. Ters kanıt: ikinci zincir doğmaması `t95_yok`, sessiz OVSYNC'e çökmemesi `t95_red2`, UI seti ayrışmaması P11 kenarı.

---

## T-96 — Sarmal giriş kimliği guard'ları: XOR (`GIRIS_CIFT_ANLAMLI`) + muayene-tip (`MUAYENE_GOREV_TIPI_UYUMSUZ`)

```mermaid
flowchart LR
  classDef red fill:#fee2e2,stroke:#dc2626,color:#7f1d1d
  classDef pass fill:#dcfce7,stroke:#16a34a,color:#14532d
  classDef safe fill:#f1f5f9,stroke:#64748b,color:#0f172a

  subgraph t96_l_ui["Kullanıcı / UI"]
    t96_ui["Sarmal çağrı — kimlik parametreleri\np_tohumlama_id | p_muayene_gorev_id"]
  end

  subgraph t96_l_rpc["RPC — tohumlama_bos_ve_devam"]
    t96_xor{"XOR guard (#9):\n(p_tohumlama_id IS NULL) =\n(p_muayene_gorev_id IS NULL)?"}
    t96_red_xor["RAISE 'GIRIS_CIFT_ANLAMLI'\n— ikisi birden dolu da, ikisi birden boş da red"]:::red
    t96_tip{"Muayene görevi tipi IN\n('GEBELIK_KONTROL','TAKIP_MUAYENE')?"}
    t96_red_tip["RAISE 'MUAYENE_GOREV_TIPI_UYUMSUZ'"]:::red
    t96_devam["Geçerli kimlik → sarmal yolu\n(bu senaryonun kapsamı dışı)"]:::safe
    t96_t87["Not: GIRIS_CIFT_ANLAMLI, T-87 yarış\noracle'ının izinli iş-hatası kümesinde geçerli"]:::safe
  end

  subgraph t96_l_db["DB — tek transaction"]
    t96_gorev["gorev_log — görev satırı\n(SUTTEN_KESME = muayene tipi DEĞİL)"]
    t96_dokun["HİÇBİR yazma: tohumlama.sonuc,\ngorev_log, cases değişmez"]:::safe
  end

  t96_ui -->|"adım 1: ikisi birden DOLU"| t96_xor
  t96_ui -->|"adım 2: ikisi birden BOŞ"| t96_xor
  t96_ui -->|"adım 3: yalnız p_muayene_gorev_id\n(SUTTEN_KESME görev id)"| t96_xor
  t96_xor -->|"eşit → çift anlam (adım 1 ve 2)"| t96_red_xor
  t96_xor -->|"tam biri dolu"| t96_tip
  t96_tip -->|"görev tipi sorgusu"| t96_gorev
  t96_tip -->|"uyumsuz tip (adım 3)"| t96_red_tip
  t96_tip -->|"GEBELIK_KONTROL / TAKIP_MUAYENE"| t96_devam
  t96_red_xor --> t96_dokun
  t96_red_tip --> t96_dokun
  t96_red_xor -.-> t96_t87
```

**Kaplama notu:** Adım 1 ve 2 (ikisi dolu / ikisi boş) XOR'da eşit çıkar → `t96_red_xor`; adım 3 (SUTTEN_KESME id) XOR'u geçer, tip kararında `t96_red_tip`'e düşer (`t96_gorev` sorgusu). BEKLENEN'deki "hiçbir yazma" satırı `t96_dokun`, "T-87 oracle izinli küme" cümlesi `t96_t87` not düğümü. Ters kanıt: kimlik-belirsiz çağrıda sessiz default yok (`t96_red_xor`), muayene-olmayan id ile işlem yok (`t96_red_tip`).

---

## T-97 — Bayrak kapalıyken sarmal YAZMA modları → `OZELLIK_KAPALI` (hiçbir yazma yok)

```mermaid
flowchart LR
  classDef red fill:#fee2e2,stroke:#dc2626,color:#7f1d1d
  classDef pass fill:#dcfce7,stroke:#16a34a,color:#14532d
  classDef safe fill:#f1f5f9,stroke:#64748b,color:#0f172a

  subgraph t97_l_fix["Ön koşul / fixture"]
    t97_fix["H'de geçerli Boş-yolu tohumlaması:\ntohumlama satırı sonuc='Bekliyor'\n→ sarmala TAM p_tohumlama_id verilir"]
    t97_ayar[("protokol_ayar.ovsync_pg_kurallari_aktif = 0\n(demo; koşum sonrası geri açılır — T-46 ile aynı seed)")]
  end

  subgraph t97_l_ui["Kullanıcı / UI — S-5"]
    t97_ui["Sarmal çağrı modları — dry-run VE üç yazma modu HEPSİ\nAYNI tam p_tohumlama_id ile çağrılır:\ndry-run p_secim=NULL | 'OVSYNC' | 'PG' | 'TAKIP'"]
    t97_secici["Devam seçici ekranı AÇILMAZ (S-5)"]:::red
  end

  subgraph t97_l_rpc["RPC — tohumlama_bos_ve_devam"]
    t97_xor["Kimlik XOR'u (#9) GEÇİLİR:\np_tohumlama_id dolu + p_muayene_gorev_id boş"]:::safe
    t97_rpc["bayrak kontrolü"]
    t97_kar{"p_secim?"}
    t97_dry["Dönüş {bayrak_kapali:true} —\ndry-run, yan etki YOK"]:::pass
    t97_red["RAISE 'OZELLIK_KAPALI'"]:::red
  end

  subgraph t97_l_db["DB — tek transaction"]
    t97_yok["HİÇBİR yazma: tohumlama sonuc='Bekliyor' kalır;\ntakip görevi / vaka / olay doğmaz"]:::safe
  end

  t97_fix -->|"aynı tam p_tohumlama_id —\ndört çağrıya da"| t97_ui
  t97_ui -->|"adım 1: dry-run · adım 2: üç yazma modu\n(hepsi aynı kimlikle)"| t97_xor
  t97_xor -->|"XOR geçildi → GIRIS_CIFT_ANLAMLI red'i BURADAN gelmez"| t97_rpc
  t97_rpc -->|"bayrak oku"| t97_ayar
  t97_ayar -->|"bayrak = 0 (kapalı) — red kapısı BURASI"| t97_kar
  t97_kar -->|"NULL → dry-run (adım 1)"| t97_dry
  t97_kar -->|"'OVSYNC' / 'PG' / 'TAKIP' (adım 2)"| t97_red
  t97_dry -->|"{bayrak_kapali:true} döner"| t97_ui
  t97_red --> t97_yok
  t97_red -.->|"seçici ekranı açılmaz"| t97_secici
```

**Kaplama notu:** Katalog ön koşulu `t97_fix` fixture düğümündedir (Boş-yolu tohumlaması `sonuc='Bekliyor'` → sarmala TAM `p_tohumlama_id` verilir); `t97_fix → t97_ui` kenarı ve `t97_ui` etiketi, dry-run (adım 1) VE üç yazma modunun (adım 2) HEPSİNİN AYNI tam `p_tohumlama_id` ile çağrıldığını gösterir. Bu kimlikle kimlik XOR'u (#9) geçilir (`t97_xor`) — red `GIRIS_CIFT_ANLAMLI` beklenMEZ; red bayrak kapısından gelir: `t97_ayar` (bayrak=0 okunur) → `t97_kar` → `t97_red` (`RAISE 'OZELLIK_KAPALI'`). Adım 1 `t97_dry` dönüşüyle biter (yan etki YOK); BEKLENEN'in "sonuc='Bekliyor' kalır, takip görevi/vaka/olay doğmaz" satırı `t97_yok`, "devam seçici ekranı açılmaz (S-5)" satırı `t97_secici` (T-46 yalnız okuma yolu + ekrandır; bu diyagram onun YAZMA dalıdır).
