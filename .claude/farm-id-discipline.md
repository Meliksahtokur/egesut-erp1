# farm_id İleri-Disiplini (Faz 2 Hazırlığı)

> **Kanonik kural belgesi.** Diğer dokümanlar (skill, agent, CLAUDE.md, domain-rules) buraya link verir — kural gövdesini kopyalama. **DRY.**

## Durum

- Sistem **KASITLI tek-tenant**: tüm RLS `USING(true)`. Kaynak: `docs/superpowers/specs/2026-06-14-login-auth-gate-design.md` §İzolasyon (24, 37, 67).
- Multi-tenant (`farm_id` kolonu + RLS + `profiles` tablosu + JWT) **Faz 2'ye planlı**. Demo hesabı Faz 2'de "demo çiftlik" olacak (aynı spec, satır 37).
- Bu disiplin, bugünden yeni yazılan her şeyi "farm_id-hazır" yapıp Faz 2 multi-tenant migration'ını "41 tabloyu retrofit et"ten "RLS'i flip et + donmuş eski seti tek backfill"e indirgemek için var.

## Sabitler (her yerde AYNEN kullan)

| Sabit | Değer | Not |
|---|---|---|
| `REAL_FARM_ID` | `400b9107-a85e-4126-af2c-fd7fe73fb68e` | Mevcut tüm gerçek veri bu çiftliğe ait sayılır |
| `public.current_farm_id()` | `STABLE` SQL fn | Şimdilik `REAL_FARM_ID` döner; Faz 2'de JWT/`profiles`'tan okuyacak |

```sql
-- Faz 2'de gövde değişecek, imza STABLE kalır.
SELECT public.current_farm_id();  -- → 400b9107-... (şimdi); JWT claim (Faz 2)
```

## Kurallar — YALNIZCA YENİ NESNELERE UYGULANIR

> Mevcut 41 tablo + ~170 fonksiyon bu disiplinin kapsamı DIŞINDA — Faz 2 retrofit işidir. Yeni yazılan her şey aşağıdaki kurallara uyar.

### 1. Yeni TENANT-SCOPED tablo → `farm_id` kolonu şart

```sql
CREATE TABLE public.<yeni_tablo> (
  ...
  farm_id uuid NOT NULL DEFAULT '400b9107-a85e-4126-af2c-fd7fe73fb68e'
  -- FK YOK — public.farms tablosu Faz 2'de oluşacak.
);
CREATE INDEX ... ON public.<yeni_tablo> (farm_id, ...);  -- tenant-filtreli sorgular için
```

### 2. Yeni YAZMA fonksiyonu tenant-scoped tabloya INSERT ediyorsa → damgala

```sql
INSERT INTO public.<tenant_tablo> (..., farm_id, ...) VALUES (..., public.current_farm_id(), ...);
```

### 3. RLS: `USING(true)` KALIR (Faz 2'ye kadar)

Enforcement değişmez → sıfır davranış değişikliği. Faz 2'de flip edilir: `USING(farm_id = public.current_farm_id())`.

### 4. `farm_id` ALMAYAN nesneler (kapsam dışı)

| Kategori | Örnekler |
|---|---|
| Global katalog / referans | `drug_classes`, `diseases`, `irk_esik`, `hastalik_kategorileri`, `protokol_sablon` |
| Sistem / altyapı | `entity_graph`, `memory_notes`, `goose_embeddings`, `agent_threads`, `agent_messages`, `agent_plans`, `chat_*` |
| Zaten kullanıcı-scoped | `agent_threads`/`messages`/`plans` (kullanici_id alıyor) |
| Faz 2'de `farms`'a dönüşecek | (henüz yok) |

### 5. Emin değilsen varsayılan

> **Operasyonel sürü verisi** (örn. süt ölçümleri, hareket günlüğü) = **tenant-scoped** varsay.
> **Katalog / tanım** (örn. hastalık listesi, ilaç etken madde) = **global** varsay.

## Neden

Bugün yeni yazılan nesne `farm_id` almadan büyürse, Faz 2'de 41 + N tablonun retrofit'i + backfill'i gerekir. Disiplin aktifken: retrofit 41'e, N sıfıra iner. **Teknik borcun kemikleşmesini bugün kesmek.**

## İlgili

- `docs/superpowers/specs/2026-06-14-login-auth-gate-design.md` — Faz 2 multi-tenant kaynağı
- `memory/project_auth_gate_faz1.md` — singleton-user → multi-tenant yol haritası
- `.claude/agents/erp-implementer.md` — bu disiplini yazan ajan (MUST)
- `.claude/skills/code-change-precheck/SKILL.md` — migration/SQL ön-kontrol akışında madde
