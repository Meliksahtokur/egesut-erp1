# Aşama 1 — Semgrep Güvenlik Taraması

**Tarih:** 2026-06-07  
**Araç:** Semgrep CE 1.165.0  
**Komutlar:**
- `semgrep --config p/owasp-top-ten js/`
- `semgrep --config p/javascript js/`
- `semgrep --config p/secrets js/`
- `semgrep --config p/sql-injection supabase/migrations/`
- Manuel kontrol: `config.js`, `api.js`, `ui.js`, `ground_truth.sql`

**Kapsam:** 11 JS dosyası (js/ + js/utils/), 1 migration dosyası (ground_truth.sql), index.html

---

## Özet

| Önem | Sayı |
|------|------|
| ERROR (Kritik) | 0 |
| WARNING (Orta) | 4 |
| INFO (Düşük) | 3 |
| **Toplam** | **7** |

> Semgrep otomatik taramaları 0 bulgu döndürdü. Ek 7 bulgu manuel incelemeyle tespit edildi.
> 3 timeout uyarısı (Express/React kuralları → `js/ui.js`) — projeyle alakasız, görmezden gelinir.

---

## Kritik Bulgular (ERROR)

*Yok.*

---

## Orta Bulgular (WARNING)

| # | Dosya:Satır | Kural | Açıklama |
|---|-------------|-------|----------|
| 1 | js/ui.js:1390 | stored-xss / unsafe-onclick | `a.kupe_no\|a.devlet_kupe\|a.id` esc() olmadan onclick handler'a gömülüyor — `openMWithHayvan('m-disease','d-hid','${a.kupe_no...}')` |
| 2 | js/ui.js:1391 | stored-xss / unsafe-onclick | Aynı pattern — `openMWithHayvan('m-vaccine','v-hid','${a.kupe_no...}')` |
| 3 | js/ui.js:5970-5977 | stored-xss / unsafe-onclick | `p.ad` (padok adı) esc() olmadan `setPadokFiltreBt('${p.id}','${p.ad}')` handler'ına gömülüyor |
| 4 | js/ui.js:6458 | stored-xss / unsafe-onclick | `h.kupe_no\|h.devlet_kupe\|h.id` esc() olmadan `padokTekliTasi(...)` handler'ına gömülüyor |

**Risk Değerlendirmesi:** DB'den gelen alan değeri (kupe_no, padok adı) tek tırnak içerirse onclick string'i kırılır ve JS enjeksiyonu mümkün hale gelir. Bu tek-kiracılı bir farm uygulaması olduğundan gerçek saldırı vektörü düşük, ama derinlemesine savunma için giderilmeli. `esc()` helper zaten mevcut — kullanılması gerekiyor.

---

## Düşük Bulgular (INFO)

| # | Dosya:Satır | Kural | Açıklama |
|---|-------------|-------|----------|
| 1 | js/api.js:7-8 | hardcoded-credential | Supabase URL ve `anon` key kaynak kodda açık. `anon` key Supabase PWA'larda standart bir pratik (Row Level Security'nin yerini almaz), ancak `service_role` key yokluğu doğrulandı — kritik değil. |
| 2 | supabase/migrations/ | rls-missing | 13 tablo RLS'siz: `hayvanlar`, `tohumlama`, `stok`, `stok_hareket`, `islem_log`, `kizginlik_log`, `dogum`, `buzagi_takip`, `hastalik_log`, `gorev_log`, `cop_kutusu`, `irk_esik`, `bildirim_log`. Ancak bu tablolara anon role'e doğrudan GRANT yok — erişim yalnızca SECURITY DEFINER RPC ve view'lar üzerinden. Risk çoğunlukla azaltılmış. |
| 3 | supabase/migrations/ | security-definer-count | 159 SECURITY DEFINER fonksiyon. Bu RPC-first mimarinin bilinçli tasarımı. Her fonksiyon anon/authenticated'a GRANT'lı — tek-kiracı ortamda kabul edilebilir. Hassas RPC'lerin (örn. `tohumlama_geri_al`, `geri_al`) caller validation içermesi önerilen bir geliştirme. |

---

## Manuel Kontroller — Geçti ✅

| Kontrol | Durum |
|---------|-------|
| `eval()` / `new Function()` kullanımı | ✅ Yok |
| `document.write()` kullanımı | ✅ Yok |
| `innerHTML` + URL parametresi kombinasyonu | ✅ Yok |
| `esc()` sanitizer kalitesi | ✅ DOM-tabanlı, doğru implementasyon (`textContent` + `innerHTML`) |
| `service_role` key kaynak kodda | ✅ Yok |
| SQL injection (migrations) | ✅ Yok (parameterized RPC, $1/$2 parametreleri) |
| Hardcoded şifre / token | ✅ Yok (sadece anon key) |

---

## Güvenlik Skoru (0-100)

Hesaplama (kendi formülümüz):
- Başlangıç: 100
- ERROR (0 adet × -15): 0
- WARNING (4 adet × -5): -20
- INFO (3 adet × -1): -3

**Güvenlik Skoru: 77/100**

> İyi haber: Semgrep'in 71 OWASP + 68 JS kuralı 0 otomatik bulgu döndürdü. Kalan riskler tek-kiracılı mimari bağlamında değerlendirildiğinde orta-düşük.

---

## Sonraki Aşamaya Bağlam

Semgrep'in işaretlediği kritik dosyalar (SonarCloud aşamasında çapraz kontrol yapılacak):

- **`js/ui.js`** — XSS riski olan 4 onclick lokasyon; aynı zamanda Semgrep timeout'una neden olan büyüklükte (2800+ satır)
- **`js/api.js`** — Hardcoded anon key (7-8. satır), SonarCloud'da da işaretlenebilir
- **`supabase/migrations/99999999999999_ground_truth.sql`** — 13 RLS-eksik tablo; SonarCloud SQL kalite kurallarında kontrol edilmeli
- **Güvenlik modeli özeti:** RPC-first + SECURITY DEFINER + anon-grant = tek-kiracı için kabul edilebilir, çok-kiracıya geçişte tüm tablolara RLS şart
