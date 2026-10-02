# PART-02 — Keşifsel UI tarama ve model-based testing

## 1. Crawljax: aranan kavramın en saf örneği

**CONFIRMED:** Crawljax, event-driven dinamik crawler olarak JavaScript SPA'ları gezip DOM state'leri ve event transition'larından **state-flow graph** üretmek üzere tasarlanmış. Akademik yöntem DOM'daki candidate event elementlerini çalıştırıp state değişikliklerinden incremental state machine çıkarıyor. [S10][S13]

### Uygun tarafları

- URL'siz SPA state'leri için tasarlanmış.
- Modal aç/kapa gibi DOM state farklarını teorik olarak node/edge haline getirebilir.
- Plugin mimarisi var; custom state comparator ve click rules eklenebilir.
- Çıktı doğrudan “state graph” fikrine yakın.

### Sorunları

- Son yayımlanmış 5.2.3 sürümü **2023-06-01**. [S11]
- 2024'te “Chrome version not supported” issue'su listeleniyor. [S12]
- Modern uygulamalarda dynamic DOM state equality yanlış ayarlanırsa state explosion oluşur. Literatür, Crawljax benzeri exhaustive DFS/BFS keşfin DOM equality ve guide eksikliği nedeniyle patlayabildiğini açıkça tartışıyor. [S14]
- egeSüt'te timestamp, hayvan listesi, badge sayıları, toast, offline queue gibi her değişim state hash'ini bozabilir.

**Sonuç:** 2026'da ana platform değil. 2–4 saatlik PoC ile “bizim modal SPA'da kaç anlamlı state buluyor?” benchmark'ı yapılmalı. İyi sonuç verirse algoritması/çıktı formatı alınır; gerekirse yalnız crawler katmanı fork edilir.

## 2. GraphWalker: discovery değil execution

**CONFIRMED:** GraphWalker model-based testing aracıdır; model verildiğinde graph üzerinde path üretir/çalıştırır. Son release 4.3.3, 26 Eylül 2024. [S19]

Bu yüzden ilk soruyu çözmez: uygulamayı kendi gezip modeli güvenilir biçimde çıkarmıyor. Fakat atlas oluşturulduktan sonra güçlü olabilir:

`flow.json -> GraphML/model -> coverage criterion -> Playwright edge executor`

Örnek hedefler:
- every-edge coverage
- random path + seed
- belirli state'e ulaşana kadar yürütme

**Uygun kullanım:** “atlas çıktıktan sonra coverage motoru”. İlk gün kurulması gerekmiyor.

## 3. LLM-guided exploration

2026'da klasik crawler yerine LLM/browser agent yaklaşımı hızla gelişiyor. Bunlar semantik hedefleri (“gebelik kontrol akışını bul”) anlayıp forms/modal'larda daha esnek ilerler. Fakat iki problem var:

1. Aynı prompt aynı coverage'ı garanti etmez.
2. Gezdiği state'lerin tam kümesini otomatik olarak “complete graph” diye kanıtlamaz.

Bu yüzden LLM agent **explorer**, Playwright recorder **witness** olmalıdır.

## 4. State canonicalization önerisi

Her DOM'u full hashlemek yerine:

```text
state_fingerprint = hash(
  screen_key,
  visible_dialog_roles_and_names,
  visible_bottom_sheet_id,
  selected_entity_type/id_class,
  enabled_primary_actions,
  normalized_form_schema,
  offline_queue_class,
  db_scenario_label
)
```

Ignore list:
- timestamps
- toast text'in nonce/id kısmı
- random generated ids
- animation styles
- network spinner
- list order (domain gerektirmiyorsa)

### State budget

- Flow başına max 30–50 semantic state.
- State başına max 10 candidate action.
- Destructive action allowlist.
- Aynı fingerprint 2 kez görüldüğünde loop break.
- Her action sonrası stabilizasyon: DOM/ARIA + network idle yerine domain-specific “settled” predicate; offline-first'ta `networkidle` tek başına yeterli değil.
